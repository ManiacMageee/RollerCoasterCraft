#!/bin/bash
# Dev helper: run the game under Wine on a virtual X display and take a
# screenshot after N seconds of play.
# usage: tools/wine_shot.sh out.png [seconds] [xdotool commands...]
# ($WID inside a command expands to the game window id)
OUT=${1:-shot.png}; SECS=${2:-6}; shift 2 2>/dev/null
export DISPLAY=:99 WINEDEBUG=${WD:--all}
pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 2; }
wineserver -k 2>/dev/null; sleep 0.5
wine RollerCoasterCraft.exe >/tmp/wine_game.log 2>&1 &
sleep "$SECS"
WID=$(xdotool search --name "^RollerCoasterCraft$" | head -1)
for c in "$@"; do eval "timeout 10 xdotool $c"; sleep 0.5; done
WID2=$(xdotool search --name "^RollerCoasterCraft$" | head -1)
if [ -n "$WID2" ]; then timeout 10 import -window "$WID2" "$OUT"; else echo "GAME WINDOW GONE (crash?)"; cat /tmp/wine_game.log | head -5; fi
wineserver -k 2>/dev/null; sleep 0.5
