#!/bin/sh
MODPATH=${0%/*}
exec 2> "$MODPATH/logs/post-fs-data.log"
set -x
