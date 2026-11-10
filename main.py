#!/usr/bin/env python3
import os

import build
import util


def main():
    frida_tag = util.get_last_frida_tag()
    last_tag = util.get_last_project_tag()
    force = os.getenv("FORCE_RELEASE", "false").lower() == "true"
    needs_update = util.strip_revision(last_tag) != frida_tag if last_tag else True

    if not needs_update and not force:
        print("All good!")
        return

    project_tag = util.get_next_revision(frida_tag)
    if force and not needs_update:
        project_tag = util.get_next_revision(frida_tag)
    print(f"Building {project_tag}")
    (build.BUILD).mkdir(exist_ok=True)
    (build.BUILD / "NEW_TAG.txt").write_text(project_tag)
    build.do_build(frida_tag, project_tag)


if __name__ == "__main__":
    main()
