#!/bin/bash
# Detective Mode — Cyberpunk 2077-style scanner overlay
# Shows PID, CPU%, MEM, class for every visible window
# Toggle: run again to dismiss

PIDFILE="/tmp/substrate-detective.pid"

# If already running, kill all notify windows
if [ -f "$PIDFILE" ]; then
    # Kill the notification process and clean up
    kill $(cat "$PIDFILE") 2>/dev/null
    rm -f "$PIDFILE"
    # Kill any remaining detective notifications
    pkill -f "detective-overlay" 2>/dev/null
    echo "Detective mode OFF"
    exit 0
fi

echo $$ > "$PIDFILE"

# Play scan sound
paplay ~/substrate/assets/sounds/notify.wav 2>/dev/null &

# Get all visible windows from i3
windows=$(i3-msg -t get_tree 2>/dev/null)

# Parse and display info for each window
python3 -c "
import json, subprocess, sys, os

tree = json.loads('''$windows''')

def walk(node, depth=0):
    results = []
    if node.get('window') and node.get('visible', False):
        wp = node.get('window_properties', {})
        wclass = wp.get('class', '')
        if wclass and wclass != 'Godot' and wclass != 'Polybar':
            pid = node.get('window', 0)
            title = node.get('name', '')[:40]
            rect = node.get('rect', {})
            x, y = rect.get('x', 0), rect.get('y', 0)
            w, h = rect.get('width', 0), rect.get('height', 0)

            # Get actual PID from window
            try:
                r = subprocess.run(['xdotool', 'getactivewindow', 'getwindowpid'],
                                   capture_output=True, text=True, timeout=1)
                actual_pid = r.stdout.strip()
            except:
                actual_pid = '?'

            # Get process stats
            try:
                r = subprocess.run(['ps', '-p', str(actual_pid), '-o', 'pid=,pcpu=,rss=', '--no-headers'],
                                   capture_output=True, text=True, timeout=1)
                stats = r.stdout.strip()
            except:
                stats = ''

            results.append({
                'class': wclass,
                'title': title,
                'x': x, 'y': y, 'w': w, 'h': h,
                'pid': actual_pid,
                'stats': stats,
            })

    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        results.extend(walk(child, depth+1))
    return results

windows = walk(tree)

# Create a summary for rofi display
lines = []
for w in windows:
    cpu = mem = '?'
    if w['stats']:
        parts = w['stats'].split()
        if len(parts) >= 3:
            cpu = parts[1]
            mem = f\"{int(parts[2])//1024}MB\"
    lines.append(f\"[{w['class'].upper()}]  PID:{w['pid']}  CPU:{cpu}%  MEM:{mem}  {w['title']}\")

# Also add system summary
import shutil
disk = shutil.disk_usage('/')
disk_pct = int(disk.used / disk.total * 100)

r = subprocess.run(['uptime', '-p'], capture_output=True, text=True)
uptime = r.stdout.strip().replace('up ', '')

r = subprocess.run(['nvidia-smi', '--query-gpu=temperature.gpu,utilization.gpu,memory.used',
                     '--format=csv,noheader,nounits'], capture_output=True, text=True)
gpu_info = r.stdout.strip()

lines.insert(0, f'--- SYSTEM SCAN ---  Uptime: {uptime}  Disk: {disk_pct}%  GPU: {gpu_info}')
lines.insert(1, '')

output = '\n'.join(lines)
print(output)
" | DISPLAY=:0 rofi -dmenu -p "SCAN" -theme death-stranding -no-custom 2>/dev/null

rm -f "$PIDFILE"
