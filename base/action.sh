#!/system/bin/sh
MODPATH=${0%/*}
PATH="$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin"

exec 2> "$MODPATH/logs/action.log"
set -x

. "$MODPATH/utils.sh" || exit $?

if [ -f "$MODPATH/disable" ]; then
  echo "[-] module disabled"
  set_frida_status "description=Frida stealth server: disabled"
  exit 0
fi

PIDS="$(busybox pgrep '__BIN_NAME__' 2>/dev/null)"
if [ -n "$PIDS" ]; then
  echo "[-] stopping server"
  busybox kill -9 $PIDS
  set_frida_status "description=Frida stealth server: stopped (port $(read_port))"
  echo "[-] port: $(read_port)"
  exit 0
fi

echo "[-] starting server"
start_frida_server || exit $?
sleep 1
check_frida_is_up 1
echo "[-] port: $(read_port)"
