#!/bin/sh
MODPATH=${0%/*}
pids="$(busybox pgrep '__BIN_NAME__' 2>/dev/null)"
[ -n "$pids" ] && busybox kill -9 $pids
exit 0
