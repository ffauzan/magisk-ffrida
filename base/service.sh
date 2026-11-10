#!/bin/sh
# Runs in late_start service mode.
MODPATH=${0%/*}
PATH="$MODPATH/bin:$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin"

exec 2> "$MODPATH/logs/service.log"
set -x

. "$MODPATH/utils.sh" || exit $?

wait_for_boot
start_frida_server || exit $?
check_frida_is_up
