#!/usr/bin/env python3
"""substrate_sensors.py — System metrics daemon for Desktop 3D.

Polls CPU/GPU temp, RAM, battery, network, weather.
Sends JSON over UDP to Godot on port 9778 every second.
Listens for D-Bus desktop notifications and sends burst signals.
"""

import json
import os
import socket
import struct
import subprocess
import sys
import time
import threading

# ── Config ──────────────────────────────────────────────────────────────────

UDP_HOST = "127.0.0.1"
UDP_PORT = 9778
POLL_INTERVAL = 1.0
WEATHER_INTERVAL = 1800  # 30 minutes
WEATHER_CACHE = "/tmp/substrate-weather.json"

# Location (operator can override via env)
LATITUDE = os.environ.get("SUBSTRATE_LAT", "40.71")
LONGITUDE = os.environ.get("SUBSTRATE_LON", "-74.01")

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# ── Sensor Readers ──────────────────────────────────────────────────────────

def find_hwmon(name):
    """Find hwmon path by sensor name."""
    base = "/sys/class/hwmon"
    try:
        for entry in os.listdir(base):
            name_path = os.path.join(base, entry, "name")
            if os.path.exists(name_path):
                with open(name_path) as f:
                    if f.read().strip() == name:
                        return os.path.join(base, entry)
    except OSError:
        pass
    return None

def read_sysfs_temp(hwmon_path):
    """Read temperature from hwmon in degrees C."""
    if not hwmon_path:
        return -1.0
    try:
        with open(os.path.join(hwmon_path, "temp1_input")) as f:
            return float(f.read().strip()) / 1000.0
    except (OSError, ValueError):
        return -1.0

def read_cpu_temp():
    """Read CPU temp — try k10temp (AMD) then coretemp (Intel)."""
    for sensor in ["k10temp", "coretemp", "acpitz"]:
        path = find_hwmon(sensor)
        if path:
            t = read_sysfs_temp(path)
            if t > 0:
                return t
    return -1.0

def read_gpu_temp():
    """Read NVIDIA GPU temp via nvidia-smi."""
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,memory.used,power.draw",
             "--format=csv,noheader,nounits"],
            timeout=2
        ).decode().strip()
        parts = [p.strip() for p in out.split(",")]
        return {
            "temp": float(parts[0]),
            "util": float(parts[1]),
            "vram_mb": float(parts[2]),
            "power_w": float(parts[3]),
        }
    except Exception:
        return {"temp": -1, "util": 0, "vram_mb": 0, "power_w": 0}

def read_ram():
    """Read RAM usage from /proc/meminfo."""
    try:
        info = {}
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    info[parts[0].rstrip(":")] = int(parts[1])
        total = info.get("MemTotal", 1)
        avail = info.get("MemAvailable", 0)
        return round((1.0 - avail / total) * 100, 1)
    except Exception:
        return 0.0

def read_battery():
    """Read battery percentage and charging status."""
    try:
        with open("/sys/class/power_supply/BAT0/capacity") as f:
            pct = int(f.read().strip())
        with open("/sys/class/power_supply/BAT0/status") as f:
            status = f.read().strip()
        return {"pct": pct, "charging": status == "Charging"}
    except Exception:
        return {"pct": 100, "charging": True}

def read_focused_app():
    """Read focused window class via xdotool."""
    try:
        wid = subprocess.check_output(
            ["xdotool", "getactivewindow"], timeout=1, stderr=subprocess.DEVNULL
        ).strip()
        name = subprocess.check_output(
            ["xdotool", "getactivewindow", "getwindowclassname"],
            timeout=1, stderr=subprocess.DEVNULL
        ).strip()
        return name.decode().lower()
    except Exception:
        return ""

def read_network():
    """Read network bytes sent/received."""
    try:
        with open("/proc/net/dev") as f:
            lines = f.readlines()
        total_rx = 0
        total_tx = 0
        for line in lines[2:]:  # skip headers
            parts = line.split()
            iface = parts[0].rstrip(":")
            if iface == "lo":
                continue
            total_rx += int(parts[1])
            total_tx += int(parts[9])
        return {"rx": total_rx, "tx": total_tx}
    except Exception:
        return {"rx": 0, "tx": 0}

# ── Weather ─────────────────────────────────────────────────────────────────

last_weather_fetch = 0
cached_weather = {"code": 0, "temp": 20, "cloud": 0, "wind": 0, "precip": 0, "is_day": 1}

def fetch_weather():
    """Fetch weather from Open-Meteo (free, no API key)."""
    global last_weather_fetch, cached_weather

    # Return cache if fresh
    if time.time() - last_weather_fetch < WEATHER_INTERVAL:
        return cached_weather

    # Try loading disk cache
    if os.path.exists(WEATHER_CACHE):
        try:
            with open(WEATHER_CACHE) as f:
                disk = json.load(f)
            if time.time() - disk.get("_ts", 0) < WEATHER_INTERVAL:
                cached_weather = disk
                last_weather_fetch = disk["_ts"]
                return cached_weather
        except Exception:
            pass

    try:
        import requests
        resp = requests.get("https://api.open-meteo.com/v1/forecast", params={
            "latitude": LATITUDE,
            "longitude": LONGITUDE,
            "current": "temperature_2m,weather_code,cloud_cover,wind_speed_10m,precipitation,is_day",
        }, timeout=10)
        data = resp.json().get("current", {})
        cached_weather = {
            "code": data.get("weather_code", 0),
            "temp": data.get("temperature_2m", 20),
            "cloud": data.get("cloud_cover", 0),
            "wind": data.get("wind_speed_10m", 0),
            "precip": data.get("precipitation", 0),
            "is_day": data.get("is_day", 1),
            "_ts": time.time(),
        }
        with open(WEATHER_CACHE, "w") as f:
            json.dump(cached_weather, f)
        last_weather_fetch = time.time()
    except Exception as e:
        print(f"Weather fetch failed: {e}", file=sys.stderr)

    return cached_weather

# ── D-Bus Notification Listener ─────────────────────────────────────────────

notification_burst = 0  # decays over time, spikes on notification

def dbus_listener():
    """Listen for desktop notifications via dbus-monitor."""
    global notification_burst
    try:
        proc = subprocess.Popen(
            ["dbus-monitor", "--session",
             "interface='org.freedesktop.Notifications',member='Notify'"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        for line in proc.stdout:
            if b"member=Notify" in line:
                notification_burst = 1.0
    except Exception:
        pass  # D-Bus not available, silently skip

# ── Main Loop ───────────────────────────────────────────────────────────────

def main():
    global notification_burst

    print(f"Substrate sensors daemon starting — UDP {UDP_HOST}:{UDP_PORT}")

    # Start D-Bus listener in background
    dbus_thread = threading.Thread(target=dbus_listener, daemon=True)
    dbus_thread.start()

    prev_net = read_network()
    prev_time = time.time()

    while True:
        try:
            cpu_temp = read_cpu_temp()
            gpu = read_gpu_temp()
            ram_pct = read_ram()
            battery = read_battery()
            net = read_network()
            weather = fetch_weather()
            app = read_focused_app()

            now = time.time()
            dt = max(now - prev_time, 0.001)

            # Network rate (KB/s)
            net_rx_rate = (net["rx"] - prev_net["rx"]) / dt / 1024.0
            net_tx_rate = (net["tx"] - prev_net["tx"]) / dt / 1024.0
            prev_net = net
            prev_time = now

            # Decay notification burst
            notification_burst = max(0.0, notification_burst - dt * 2.0)

            packet = json.dumps({
                "cpu_temp": round(cpu_temp, 1),
                "gpu_temp": round(gpu["temp"], 1),
                "gpu_util": round(gpu["util"], 1),
                "gpu_vram": round(gpu["vram_mb"], 0),
                "gpu_power": round(gpu["power_w"], 1),
                "ram_pct": ram_pct,
                "bat_pct": battery["pct"],
                "bat_charging": battery["charging"],
                "net_rx": round(net_rx_rate, 1),
                "net_tx": round(net_tx_rate, 1),
                "weather_code": weather["code"],
                "weather_temp": weather["temp"],
                "weather_cloud": weather["cloud"],
                "weather_wind": weather["wind"],
                "weather_precip": weather["precip"],
                "weather_day": weather["is_day"],
                "notify": round(notification_burst, 2),
                "focused_app": app,
            })

            sock.sendto(packet.encode(), (UDP_HOST, UDP_PORT))

        except Exception as e:
            print(f"Sensor loop error: {e}", file=sys.stderr)

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
