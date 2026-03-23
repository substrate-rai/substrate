#!/bin/bash
# Current shader name from Godot via TCP
name=$(echo '{"type":"status","params":{}}' | nc -w1 127.0.0.1 9877 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('items',[{}])[-1].get('name','--'))" 2>/dev/null)
if [ -n "$name" ] && [ "$name" != "--" ]; then
    echo "${name^^}"
else
    echo ""
fi
