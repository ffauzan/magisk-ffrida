#!/usr/bin/env bash
set -euo pipefail

PKG="${1:?usage: device-check.sh <package> [frida-ps]}"
FRIDA_PS="${2:-frida-ps}"
FRIDA_PY="${FRIDA_PY:-$(dirname "$FRIDA_PS")/python}"
MOD=/data/adb/modules/magisk-ffrida
PORT="$(adb shell su -c "cat $MOD/port" | tr -d '\r')"
[ -n "$PORT" ] || { echo "no port file"; exit 1; }

echo "== server =="
adb shell su -c "ps -A -o PID,NAME,ARGS | grep medcodec | grep -v grep; cat /proc/\$(pgrep medcodec | head -1)/comm; cat /proc/\$(pgrep medcodec | head -1)/cmdline | tr '\\0' ' '; echo" || true

echo "== client =="
adb forward tcp:27042 "tcp:$PORT" >/dev/null
"$FRIDA_PS" -H 127.0.0.1:27042 | sed -n '1,10p'

echo "== attach =="
PID="$(adb shell pidof "$PKG" | tr -d '\r' | awk '{print $1}')"
[ -n "$PID" ] || { echo "package not running: $PKG"; exit 1; }
"$FRIDA_PY" "$(dirname "$0")/attach-check.py" 127.0.0.1:27042 "$PID"

echo "== maps =="
adb shell su -c "grep -Eai -e frida -e codecache -e odex-helper /proc/$PID/maps" || echo "clean"

echo "== threads =="
adb shell su -c "cat /proc/$PID/task/*/comm" | grep -Eai -e frida -e gum-js -e gmain -e gdbus -e pool-frida -e pool-spawner -e event- || echo "clean"

echo "== unix sockets =="
adb shell su -c "cat /proc/net/unix" | grep -Eai -e frida -e zymbiote || echo "clean"

echo "== port 27042 =="
adb shell su -c "cat /proc/net/tcp" | grep -i ':69A2' || echo "closed"
