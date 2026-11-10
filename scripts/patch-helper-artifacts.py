#!/usr/bin/env python3
import sys
from pathlib import Path

OLD = b"/frida-zymbiote-"
NEW = b"/.virt-sessions-"


def main():
    source = Path(sys.argv[1])
    count = 0
    for path in (source / "subprojects/frida-core/src/linux/helpers/artifacts").rglob("zymbiote.elf"):
        data = path.read_bytes()
        n = data.count(OLD)
        if n:
            path.write_bytes(data.replace(OLD, NEW))
            count += n
            print(f"{path}: {n} replaced")
    print(f"total: {count}")


if __name__ == "__main__":
    main()
