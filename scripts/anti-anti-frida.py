#!/usr/bin/env python3
"""Rename fixed-length runtime identifiers in frida binaries.

Only same-length ASCII replacements are used, so ELF offsets and section
sizes never change. This keeps the stock frida client/server protocol intact.
"""
import sys
from pathlib import Path

REPLACEMENTS = {
    b"zymbiote": b"sessions",
    b"frida-main-loop": b"event-main-loop",
    b"frida-agent-container": b"runtime-session-thrdx",
    b"frida-agent": b"codec-agent",
    b"frida-server": b"virt-serverx",
    b"frida-android-helper": b"virtx-android-helper",
    b"/frida-zymbiote-": b"/.virt-zymbiote-",
    b"gum-js-loop": b"wqk-js-loop",
    b"gmain": b"wmain",
    b"gdbus": b"wdbus",
    b"pool-frida": b"pool-virtx",
    b"pool-spawner": b"pool-workerx",
    b"jit-cache": b"codecache",
}


def rewrite(path: Path):
    data = path.read_bytes()
    total = 0
    for old, new in REPLACEMENTS.items():
        assert len(old) == len(new), old
        count = data.count(old)
        if count:
            data = data.replace(old, new)
            total += count
    path.write_bytes(data)
    print(f"{path}: {total} identifiers renamed")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: anti-anti-frida.py FILE...", file=sys.stderr)
        raise SystemExit(2)
    for arg in sys.argv[1:]:
        rewrite(Path(arg))
