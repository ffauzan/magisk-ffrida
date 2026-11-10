import os
import re
import subprocess

import requests

REPO = os.getenv("GITHUB_REPOSITORY", "falfal/magisk-ffrida")


def strip_revision(tag: str) -> str:
    return tag.split("-", 1)[0]


def get_last_github_tag(project_name: str) -> str:
    r = requests.get(f"https://api.github.com/repos/{project_name}/releases/latest", timeout=30)
    r.raise_for_status()
    return r.json()["tag_name"]


def get_last_frida_tag() -> str:
    tag = get_last_github_tag("frida/frida")
    print(f"Last frida tag: {tag}")
    return tag


def sort_tags(tags):
    return sorted(tags, key=lambda s: [int(x) for x in re.split(r"[.-]", s)])


def get_last_tag(patterns) -> str:
    tags = exec_git_command(["tag", "-l"] + list(patterns)).splitlines()
    return "" if not tags else sort_tags(tags)[-1]


def get_last_project_tag() -> str:
    tag = get_last_tag([])
    print(f"Last project tag: {tag}")
    return tag


def exec_git_command(args) -> str:
    return subprocess.run(["git"] + args, capture_output=True, text=True).stdout


def get_next_revision(frida_tag: str) -> str:
    i = 1
    while get_last_tag([f"{frida_tag}-{i}"]) != "":
        i += 1
    return f"{frida_tag}-{i}"


def generate_version_code(project_tag: str) -> int:
    return int("".join(f"{int(part):02d}" for part in re.split("[-.]", project_tag)))
