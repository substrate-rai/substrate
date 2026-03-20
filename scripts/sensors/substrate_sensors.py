#!/usr/bin/env python3
"""substrate_sensors.py — System metrics daemon for Desktop 3D.

Polls CPU/GPU temp, RAM, battery, network, weather, audio levels.
Sends JSON over UDP to Godot on port 9778 every second.
Listens for D-Bus desktop notifications and sends burst signals.
Captures PipeWire audio via pw-record for spectrum analysis.
"""

import json
import math
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
            ["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw",
             "--format=csv,noheader,nounits"],
            timeout=2
        ).decode().strip()
        parts = [p.strip() for p in out.split(",")]
        return {
            "temp": float(parts[0]),
            "util": float(parts[1]),
            "vram_mb": float(parts[2]),
            "vram_total_mb": float(parts[3]),
            "power_w": float(parts[4]),
        }
    except Exception:
        return {"temp": -1, "util": 0, "vram_mb": 0, "vram_total_mb": 8192, "power_w": 0}

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

def read_git_commits():
    """Count git commits in the last hour."""
    try:
        out = subprocess.check_output(
            ["git", "-C", "/home/operator/substrate", "log",
             "--since=1 hour ago", "--oneline"],
            timeout=3, stderr=subprocess.DEVNULL
        ).decode().strip()
        if not out:
            return 0
        return len(out.splitlines())
    except Exception:
        return 0

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

# ── Audio Capture (PipeWire) ────────────────────────────────────────────────

AUDIO_RATE = 22050  # lower rate = less data, still enough for spectrum
AUDIO_CHANNELS = 2  # stereo capture (sink monitor requires stereo)
AUDIO_CHUNK = 1024  # samples per channel per analysis frame (~46ms at 22050Hz)
AUDIO_BYTES_PER_FRAME = AUDIO_CHUNK * AUDIO_CHANNELS * 2  # 16-bit signed LE stereo
AUDIO_UDP_INTERVAL = 0.033  # send audio UDP at ~30Hz (every 33ms)

# Per-band rolling-max auto-normalization (replaces flat scale=50.0)
BAND_NAMES = ["sub_bass", "bass", "low_mid", "mid", "upper_mid", "treble", "presence", "brilliance"]
band_max = {name: 0.01 for name in BAND_NAMES}
BAND_MAX_DECAY = 0.998  # slow decay — adapts over ~500 frames

# Spectral flux tracking
prev_spectrum = None

# Multi-band beat detection state
beat_kick = 0.0   # sub_bass onset
beat_snare = 0.0  # mid onset
beat_hihat = 0.0  # treble onset
beat_val = 0.0    # composite beat (spectral flux)
prev_band_values = {name: 0.0 for name in BAND_NAMES}
last_beat_time = 0.0

# Shared audio state (written by audio thread, read by main loop for fallback)
audio_lock = threading.Lock()
audio_levels = {
    "bass": 0.0, "mid": 0.0, "treble": 0.0, "energy": 0.0,
    "beat": 0.0, "sub_bass": 0.0, "low_mid": 0.0,
    "upper_mid": 0.0, "presence": 0.0, "brilliance": 0.0,
    "beat_kick": 0.0, "beat_snare": 0.0, "beat_hihat": 0.0,
    "spectral_flux": 0.0,
}

def _goertzel_mag(samples, n, k):
    """Single-frequency Goertzel magnitude."""
    w = 2.0 * math.pi * k / n
    coeff = 2.0 * math.cos(w)
    s1 = 0.0
    s2 = 0.0
    for x in samples:
        s0 = x + coeff * s1 - s2
        s2 = s1
        s1 = s0
    return math.sqrt(s1 * s1 + s2 * s2 - coeff * s1 * s2) / n

def _band_power(samples, n, freq_res, lo_hz, hi_hz, step=3):
    """Average magnitude in a frequency band using sparse Goertzel bins."""
    lo_bin = max(1, int(lo_hz / freq_res))
    hi_bin = min(n // 2, int(hi_hz / freq_res))
    if lo_bin >= hi_bin:
        return 0.0
    power = 0.0
    count = 0
    for k in range(lo_bin, hi_bin + 1, step):
        mag = _goertzel_mag(samples, n, k)
        power += mag * mag
        count += 1
    return math.sqrt(power / max(count, 1)) if count > 0 else 0.0

def _find_default_sink_id():
    """Find the default audio sink node ID via wpctl."""
    try:
        r = subprocess.run(["/run/current-system/sw/bin/wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"],
                           capture_output=True, text=True, timeout=3)
        for line in r.stdout.split("\n"):
            line = line.strip()
            if line.startswith("id:"):
                return line.split(":")[1].strip().rstrip(",")
    except Exception:
        pass
    return "58"  # fallback

def _normalize_band(name, raw_value):
    """Per-band rolling-max auto-normalization. Each band independently fills 0-1."""
    band_max[name] = max(band_max[name] * BAND_MAX_DECAY, raw_value)
    return min(1.0, raw_value / max(band_max[name], 0.001))


def _compute_spectral_flux(current_bands):
    """Spectral flux = sum of positive energy changes across all bands."""
    global prev_band_values
    flux = 0.0
    for name in BAND_NAMES:
        diff = current_bands[name] - prev_band_values.get(name, 0.0)
        if diff > 0:
            flux += diff
    prev_band_values = dict(current_bands)
    return min(1.0, flux)


def _detect_beats(current_bands, dt):
    """Multi-band onset detection with exponential decay."""
    global beat_kick, beat_snare, beat_hihat, beat_val

    # Exponential decay (exp(-12*dt) gives ~0.67 at 33ms, fast falloff)
    decay = math.exp(-12.0 * dt)
    beat_kick *= decay
    beat_snare *= decay
    beat_hihat *= decay
    beat_val *= decay

    # Onset thresholds — spike relative to previous value
    sub_diff = current_bands["sub_bass"] - prev_band_values.get("sub_bass", 0.0)
    mid_diff = current_bands["mid"] - prev_band_values.get("mid", 0.0)
    treble_diff = current_bands["treble"] - prev_band_values.get("treble", 0.0)

    if sub_diff > 0.15:
        beat_kick = min(1.0, beat_kick + sub_diff * 2.0)
    if mid_diff > 0.12:
        beat_snare = min(1.0, beat_snare + mid_diff * 2.0)
    if treble_diff > 0.10:
        beat_hihat = min(1.0, beat_hihat + treble_diff * 2.0)

    # Composite beat from spectral flux
    flux = _compute_spectral_flux(current_bands)
    if flux > 0.2:
        beat_val = min(1.0, beat_val + flux * 1.5)

    return beat_kick, beat_snare, beat_hihat, beat_val, flux


def audio_capture_thread():
    """Continuously read PCM from PipeWire default sink monitor and compute spectrum.

    Sends its own UDP packets at ~30Hz directly to Godot, bypassing the 1Hz sensor loop.
    This is critical for beat detection — 120 BPM = 2Hz, so 1Hz sampling misses beats.
    """
    global beat_kick, beat_snare, beat_hihat, beat_val

    audio_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    last_send = 0.0
    last_time = time.time()

    while True:
        try:
            sink_id = _find_default_sink_id()
            proc = subprocess.Popen(
                ["/run/current-system/sw/bin/pw-cat", "--record",
                 "--target", sink_id,
                 "--format", "s16", "--rate", str(AUDIO_RATE),
                 "--channels", "2", "-"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            print("Audio capture started (pw-record → 30Hz UDP)")

            while True:
                data = proc.stdout.read(AUDIO_BYTES_PER_FRAME)
                if len(data) < AUDIO_BYTES_PER_FRAME:
                    break  # pw-record died, will restart

                # Decode 16-bit signed LE stereo, mix to mono
                raw = struct.unpack(f"<{AUDIO_CHUNK * AUDIO_CHANNELS}h", data)
                samples = [(raw[i] + raw[i + 1]) / 2 for i in range(0, len(raw), 2)]
                # Normalize to -1..1 and apply Hann window
                n = len(samples)
                windowed = [
                    (samples[i] / 32768.0) * (0.5 - 0.5 * math.cos(2 * math.pi * i / n))
                    for i in range(n)
                ]

                freq_res = AUDIO_RATE / n

                # Compute raw band energies
                raw_bands = {
                    "sub_bass": _band_power(windowed, n, freq_res, 20, 60, step=1),
                    "bass": _band_power(windowed, n, freq_res, 20, 300, step=2),
                    "low_mid": _band_power(windowed, n, freq_res, 250, 500, step=2),
                    "mid": _band_power(windowed, n, freq_res, 300, 4000, step=4),
                    "upper_mid": _band_power(windowed, n, freq_res, 2000, 4000, step=4),
                    "treble": _band_power(windowed, n, freq_res, 4000, 11000, step=6),
                    "presence": _band_power(windowed, n, freq_res, 4000, 6000, step=4),
                    "brilliance": _band_power(windowed, n, freq_res, 6000, 11000, step=6),
                }

                # Per-band auto-normalization (replaces flat scale=50.0)
                norm_bands = {name: _normalize_band(name, val) for name, val in raw_bands.items()}
                energy = (norm_bands["bass"] + norm_bands["mid"] + norm_bands["treble"]) / 3.0

                # Beat detection with exponential decay
                now = time.time()
                dt = now - last_time
                last_time = now
                kick, snare, hihat, beat, flux = _detect_beats(norm_bands, dt)

                # Update shared state for fallback
                with audio_lock:
                    audio_levels["bass"] = norm_bands["bass"]
                    audio_levels["mid"] = norm_bands["mid"]
                    audio_levels["treble"] = norm_bands["treble"]
                    audio_levels["energy"] = energy
                    audio_levels["beat"] = beat
                    audio_levels["sub_bass"] = norm_bands["sub_bass"]
                    audio_levels["low_mid"] = norm_bands["low_mid"]
                    audio_levels["upper_mid"] = norm_bands["upper_mid"]
                    audio_levels["presence"] = norm_bands["presence"]
                    audio_levels["brilliance"] = norm_bands["brilliance"]
                    audio_levels["beat_kick"] = kick
                    audio_levels["beat_snare"] = snare
                    audio_levels["beat_hihat"] = hihat
                    audio_levels["spectral_flux"] = flux

                # Send audio UDP at 30Hz (every ~33ms)
                if now - last_send >= AUDIO_UDP_INTERVAL:
                    last_send = now
                    packet = json.dumps({
                        "t": "audio",
                        "audio_bass": round(norm_bands["bass"], 4),
                        "audio_mid": round(norm_bands["mid"], 4),
                        "audio_treble": round(norm_bands["treble"], 4),
                        "audio_energy": round(energy, 4),
                        "audio_beat": round(beat, 2),
                        "audio_sub_bass": round(norm_bands["sub_bass"], 4),
                        "audio_low_mid": round(norm_bands["low_mid"], 4),
                        "audio_upper_mid": round(norm_bands["upper_mid"], 4),
                        "audio_presence": round(norm_bands["presence"], 4),
                        "audio_brilliance": round(norm_bands["brilliance"], 4),
                        "beat_kick": round(kick, 3),
                        "beat_snare": round(snare, 3),
                        "beat_hihat": round(hihat, 3),
                        "audio_flux": round(flux, 4),
                    })
                    audio_sock.sendto(packet.encode(), (UDP_HOST, UDP_PORT))

        except FileNotFoundError:
            print("pw-record not found, audio capture disabled", file=sys.stderr)
            return
        except Exception as e:
            print(f"Audio capture error: {e}, restarting in 3s", file=sys.stderr)
            time.sleep(3)

def read_audio():
    """Return current audio levels (thread-safe read)."""
    with audio_lock:
        return dict(audio_levels)

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

    # Start audio capture in background
    audio_thread = threading.Thread(target=audio_capture_thread, daemon=True)
    audio_thread.start()

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
            git_commits = read_git_commits()

            now = time.time()
            dt = max(now - prev_time, 0.001)

            # Network rate (KB/s)
            net_rx_rate = (net["rx"] - prev_net["rx"]) / dt / 1024.0
            net_tx_rate = (net["tx"] - prev_net["tx"]) / dt / 1024.0
            prev_net = net
            prev_time = now

            # Decay notification burst
            notification_burst = max(0.0, notification_burst - dt * 2.0)

            # Audio data is now sent at 30Hz by the audio thread directly.
            # Sensor loop only sends system metrics at 1Hz.
            packet = json.dumps({
                "t": "sensors",
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
                "gpu_vram_total": round(gpu["vram_total_mb"], 0),
                "git_commits_1h": git_commits,
            })

            sock.sendto(packet.encode(), (UDP_HOST, UDP_PORT))

        except Exception as e:
            print(f"Sensor loop error: {e}", file=sys.stderr)

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
