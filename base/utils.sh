#!/bin/sh
MODPATH=${0%/*}
FRIDA_BIN="$MODPATH/bin/__BIN_NAME__"
FRIDA_PORT_FILE="$MODPATH/port"
PATH="$MODPATH/bin:$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin"

set_frida_status() {
  sed -i "s/^description=.*/$1/g" "$MODPATH/module.prop" 2>/dev/null
}

read_port() {
  [ -f "$FRIDA_PORT_FILE" ] || return 1
  P="$(tr -d ' \t\r\n' < "$FRIDA_PORT_FILE")"
  case "$P" in
    ''|*[!0-9]*) return 1;;
  esac
  [ "$P" -ge 1 ] && [ "$P" -le 65535 ] || return 1
  echo "$P"
}

start_frida_server() {
  if [ ! -x "$FRIDA_BIN" ]; then
    echo "[-] binary missing: $FRIDA_BIN"
    set_frida_status "description=Frida stealth server: missing binary"
    return 1
  fi
  PORT="$(read_port)" || {
    echo "[-] invalid port file"
    set_frida_status "description=Frida stealth server: invalid port"
    return 1
  }
  echo "[-] starting on 127.0.0.1:$PORT"
  "$FRIDA_BIN" -l "127.0.0.1:$PORT" -D
}

check_frida_is_up() {
  LIMIT=${1:-4}
  i=0
  while [ "$i" -lt "$LIMIT" ]; do
    if [ -n "$(busybox pgrep '__BIN_NAME__' 2>/dev/null)" ]; then
      echo "[-] server is running"
      set_frida_status "description=Frida stealth server: active on port $(read_port)"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  set_frida_status "description=Frida stealth server: failed to start"
  return 1
}

wait_for_boot() {
  while true; do
    [ "$(getprop sys.boot_completed)" = "1" ] && break
    sleep 3
  done
}
