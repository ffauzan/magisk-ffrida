#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:?usage: build-frida.sh <arm|arm64|x86|x86_64> <frida-tag> [source-dir]}"
VERSION="${2:?missing frida tag}"
SRC="${3:-${FRIDA_SRC:-/tmp/frida-src}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NDK="${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is required}"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch "$VERSION" --recurse-submodules --shallow-submodules https://github.com/frida/frida "$SRC"
fi

CURRENT="$(git -C "$SRC" describe --tags --exact-match 2>/dev/null || true)"
if [ "$CURRENT" != "$VERSION" ]; then
  echo "source is at '$CURRENT', expected '$VERSION'" >&2
  exit 1
fi

export STEALTH_RENAMER="${STEALTH_RENAMER:-$ROOT/scripts/anti-anti-frida.py}"

for repo in frida-core frida-gum; do
  git -C "$SRC/subprojects/$repo" checkout -- . 2>/dev/null || true
  for patch in "$ROOT/patches/$repo"/*.patch; do
    [ -e "$patch" ] || continue
    git -C "$SRC/subprojects/$repo" apply "$patch"
  done
done

python3 "$ROOT/scripts/patch-helper-artifacts.py" "$SRC"

cd "$SRC"
BUILD_DIR="build-android-$ARCH"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
../configure --host="android-$ARCH"
NODE_PATH="$(npm root -g 2>/dev/null || true)" make -j"$(nproc)"

OUT="$SRC/$BUILD_DIR/subprojects/frida-core/server/frida-server"
python3 "$ROOT/scripts/anti-anti-frida.py" "$OUT"
python3 "$ROOT/scripts/verify-artifacts.py" "$OUT" "$ARCH"
cp "$OUT" "$ROOT/downloads/frida-server-$VERSION-android-$ARCH"
