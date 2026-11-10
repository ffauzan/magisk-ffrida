#!/usr/bin/env python3
import argparse
import concurrent.futures
import json
import lzma
import os
import re
import shutil
import zipfile
from pathlib import Path

import requests

ROOT = Path(__file__).parent.resolve()
BASE = ROOT / "base"
BUILD = ROOT / "build"
TMP = BUILD / "tmp"
DOWNLOADS = ROOT / "downloads"
CONFIG = json.loads((ROOT / "versions.json").read_text())
BIN_NAME = CONFIG["binary_name"]
ARCHS = ["arm", "arm64", "x86", "x86_64"]
REPO = os.getenv("GITHUB_REPOSITORY", "falfal/magisk-ffrida")


def version_code(tag: str) -> int:
    return int("".join(f"{int(p):02d}" for p in re.split("[-.]", tag)))


def replace_placeholders(path: Path):
    text = path.read_text()
    if "__BIN_NAME__" not in text:
        return
    path.write_text(text.replace("__BIN_NAME__", BIN_NAME))


def create_module(project_tag: str):
    if TMP.exists():
        shutil.rmtree(TMP)
    shutil.copytree(BASE, TMP)
    for path in TMP.rglob("*"):
        if path.is_file():
            replace_placeholders(path)
    (TMP / "module.prop").write_text(
        f"""id={CONFIG['module_id']}
name={CONFIG['module_name']}
version={project_tag}
versionCode={version_code(project_tag)}
author={CONFIG['author']}
updateJson=https://github.com/{REPO}/releases/latest/download/updater.json
description=Frida stealth server: starting
"""
    )


def download(name: str, project_tag: str) -> Path:
    path = DOWNLOADS / name
    if path.exists():
        return path
    url = f"https://github.com/{REPO}/releases/download/{project_tag}/{name}"
    print(f"Downloading {url}")
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    path.write_bytes(r.content)
    return path


def extract_xz(src: Path, dest: Path):
    with lzma.open(src) as f:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(f.read())


def fill_module(arch: str, frida_tag: str, project_tag: str):
    name = f"frida-server-{frida_tag}-android-{arch}.xz"
    src = download(name, project_tag)
    files = TMP / "files"
    files.mkdir(exist_ok=True)
    dest = files / f"frida-server-{arch}"
    extract_xz(src, dest)
    dest.chmod(0o755)
    print(f"Prepared {dest.name}")


def create_updater(project_tag: str):
    updater = {
        "version": project_tag,
        "versionCode": version_code(project_tag),
        "zipUrl": f"https://github.com/{REPO}/releases/download/{project_tag}/MagiskFrida-{project_tag}.zip",
        "changelog": f"https://raw.githubusercontent.com/{REPO}/master/CHANGELOG.md",
    }
    (BUILD / "updater.json").write_text(json.dumps(updater, indent=2) + "\n")


def package(project_tag: str):
    zip_path = BUILD / f"MagiskFrida-{project_tag}.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, _, names in os.walk(TMP):
            for name in names:
                if name in ("placeholder", ".gitkeep"):
                    continue
                src = Path(root) / name
                zf.write(src, src.relative_to(TMP))
    shutil.rmtree(TMP)
    print(zip_path)


def do_build(frida_tag: str, project_tag: str, archs=ARCHS):
    DOWNLOADS.mkdir(exist_ok=True)
    BUILD.mkdir(exist_ok=True)
    create_module(project_tag)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
        futures = [ex.submit(fill_module, arch, frida_tag, project_tag) for arch in archs]
        for future in concurrent.futures.as_completed(futures):
            future.result()
    package(project_tag)
    create_updater(project_tag)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--frida-tag", required=True)
    parser.add_argument("--project-tag", required=True)
    parser.add_argument("--arch", action="append", choices=ARCHS)
    args = parser.parse_args()
    do_build(args.frida_tag, args.project_tag, args.arch or ARCHS)
