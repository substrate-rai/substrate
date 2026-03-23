#!/bin/bash
# Substrate power optimization — run once with sudo
# Configures: lid suspend, battery governor, power save

echo "=== Substrate Power Setup ==="

# 1. Lid close = suspend on battery, ignore on AC (for docked use)
sed -i 's/^HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/elogind/logind.conf
# Uncomment and set HandleLidSwitch to suspend
sed -i 's/^#HandleLidSwitch=.*/HandleLidSwitch=suspend/' /etc/elogind/logind.conf
echo "[OK] Lid close: suspend on battery, ignore on AC"

# 2. Create battery/AC power scripts
cat > /etc/local.d/power-battery.sh << 'BEOF'
#!/bin/bash
# Called by udev when switching to battery
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo powersave > "$cpu" 2>/dev/null
done
# GPU power save
nvidia-smi -pm 0 2>/dev/null
# WiFi power save on
iw dev wlo1 set power_save on 2>/dev/null
BEOF
chmod +x /etc/local.d/power-battery.sh

cat > /etc/local.d/power-ac.sh << 'AEOF'
#!/bin/bash
# Called by udev when switching to AC
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu" 2>/dev/null
done
# GPU persistence
nvidia-smi -pm 1 2>/dev/null
# WiFi performance
iw dev wlo1 set power_save off 2>/dev/null
AEOF
chmod +x /etc/local.d/power-ac.sh

# 3. Udev rule to auto-switch on AC/battery
cat > /etc/udev/rules.d/99-power.rules << 'UEOF'
# Auto power profile switching
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/etc/local.d/power-battery.sh"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/etc/local.d/power-ac.sh"
UEOF
echo "[OK] Auto power switching: performance on AC, powersave on battery"

# 4. Set current state based on AC status
if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || cat /sys/class/power_supply/AC0/online 2>/dev/null || echo 1)" = "1" ]; then
    /etc/local.d/power-ac.sh
    echo "[OK] Currently on AC — performance mode"
else
    /etc/local.d/power-battery.sh
    echo "[OK] Currently on battery — powersave mode"
fi

# 5. Reload elogind to pick up lid switch changes
pkill -HUP elogind 2>/dev/null || rc-service elogind restart 2>/dev/null
echo "[OK] elogind reloaded — lid close now suspends on battery"

echo ""
echo "=== Done ==="
echo "On battery: CPU powersave, GPU sleep, WiFi power save, lid = suspend"
echo "On AC: CPU performance, GPU persist, WiFi full power, lid = ignore"
