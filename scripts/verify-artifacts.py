#!/usr/bin/env python3
import json
import sys
from pathlib import Path

MACHINES = {"arm": 40, "arm64": 183, "x86": 3, "x86_64": 62}


def main():
    path = Path(sys.argv[1])
    arch = sys.argv[2]
    data = path.read_bytes()
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"FAIL {path}: not an ELF")
    machine = int.from_bytes(data[18:20], "little")
    if machine != MACHINES[arch]:
        raise SystemExit(f"FAIL {path}: e_machine={machine}, expected {MACHINES[arch]}")
    markers = json.loads((Path(__file__).parent.parent / "versions.json").read_text())["markers"]
    hits = [m for m in markers if m.encode() in data]
    if hits:
        raise SystemExit(f"FAIL {path}: markers {hits}")
    print(f"PASS {path}: {arch}, size={len(data)}")


if __name__ == "__main__":
    main()
