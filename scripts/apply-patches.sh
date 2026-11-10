#!/usr/bin/env bash
set -euo pipefail
SRC="${1:?usage: apply-patches.sh <frida-source>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for repo in frida-core frida-gum; do
  git -C "$SRC/subprojects/$repo" checkout -- . 2>/dev/null || true
  for patch in "$ROOT/patches/$repo"/*.patch; do
    [ -e "$patch" ] || continue
    echo "apply $repo/$(basename "$patch")"
    git -C "$SRC/subprojects/$repo" apply "$patch"
  done
done
python3 "$ROOT/scripts/patch-helper-artifacts.py" "$SRC"
