#!/bin/bash
# Dev helper: run the game under Wine on a virtual X display and take a
# screenshot after N seconds.  usage: tools/wine_shot.sh out.png [seconds] [xdotool cmds...]
OUT=${1:-shot.png}; SECS=${2:-6}; shift 2 2>/dev/null
export DISPLAY=:99 WINEDEBUG=-all
pgrep -f "Xvfb :99" >/dev/null || { Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 2; }
wine RollerCoasterCraft.exe >/tmp/wine_game.log 2>&1 &
sleep "$SECS"
WID=$(xdotool search --name "RollerCoasterCraft" | head -1)
for c in "$@"; do eval "xdotool $c"; sleep 0.5; done
if [ -n "$WID" ]; then import -window "$WID" "$OUT"; else import -window root "$OUT"; echo "window not found"; fi
wineserver -k; sleep 1
