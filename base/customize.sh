#!/bin/sh
##########################################################################################
# Magisk / KernelSU / APatch module installer
##########################################################################################

SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true
REPLACE=""
SKIPUNZIP=1

PATH="$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin"

print_modname() {
  ui_print " "
  ui_print "    ********************************************"
  ui_print "    *        Frida Stealth Server               *"
  ui_print "    ********************************************"
  ui_print " "
}

on_install() {
  case $ARCH in
    arm64) F_ARCH=arm64;;
    arm)   F_ARCH=arm;;
    x64)   F_ARCH=x86_64;;
    x86)   F_ARCH=x86;;
    *)     abort "! Unsupported architecture: $ARCH";;
  esac
  ui_print "- Detected architecture: $F_ARCH"

  if [ "$BOOTMODE" = true ] && [ "$KSU" = true ]; then
    ui_print "- Installing from KernelSU"
  elif [ "$BOOTMODE" = true ] && [ -n "$APATCH" ]; then
    ui_print "- Installing from APatch"
  elif [ "$BOOTMODE" = true ] && [ -n "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk"
  else
    abort "! Install from Magisk, KernelSU, or APatch app"
  fi

  ui_print "- Extracting module files..."
  unzip -oq "$ZIPFILE" -x "META-INF/*" "files/*" -d "$MODPATH" \
    || abort "! Failed to extract module files"

  rm -rf "$MODPATH/files" "$MODPATH/system/bin"
  rmdir "$MODPATH/system" 2>/dev/null
  touch "$MODPATH/skip_mount" || abort "! Failed to create skip_mount marker"

  F_BINDIR="$MODPATH/bin"
  mkdir -p "$F_BINDIR" || abort "! Failed to create bin directory"
  unzip -ojq "$ZIPFILE" "files/frida-server-$F_ARCH" -d "$F_BINDIR" \
    || abort "! Failed to extract server binary"
  mv -f "$F_BINDIR/frida-server-$F_ARCH" "$F_BINDIR/__BIN_NAME__" \
    || abort "! Failed to install server binary"
  chmod 0755 "$F_BINDIR/__BIN_NAME__"

  # Keep an existing custom port across updates. Fresh installs get a random port.
  F_CUSTOM_PORT="/data/adb/modules/${MODPATH##*/}/port"
  if [ -f "$F_CUSTOM_PORT" ] && [ "$F_CUSTOM_PORT" != "$MODPATH/port" ]; then
    cp -f "$F_CUSTOM_PORT" "$MODPATH/port" || abort "! Failed to keep custom port"
    ui_print "- Keeping port $(cat "$MODPATH/port")"
  elif [ ! -f "$MODPATH/port" ]; then
    RAND="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' \t\r\n')"
    case "$RAND" in ''|*[!0-9]*) RAND=11337;; esac
    echo $((30000 + RAND % 30000)) > "$MODPATH/port"
    ui_print "- Generated port $(cat "$MODPATH/port")"
  fi

  mkdir -p "$MODPATH/logs"
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644 \
    || abort "! Failed to set default permissions"
  set_perm "$MODPATH/bin/__BIN_NAME__" 0 2000 0755 u:object_r:system_file:s0 \
    || abort "! Failed to set binary permissions"
}

mkdir -p "$MODPATH/logs"
exec 3>&2 2>"$MODPATH/logs/custom.log"
set -x
print_modname
on_install
set_permissions
set +x
exec 2>&3 3>&-

[ -f "$MODPATH/disable" ] && {
  sed -i "s/^description=.*/description=Frida stealth server: disabled/g" "$MODPATH/module.prop"
}
return 0
