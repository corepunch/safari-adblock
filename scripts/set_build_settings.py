#!/usr/bin/env python3
"""Add build settings to the Xcode project that `make xcode` generates.

Apple's converter leaves the signing team and the app category empty, and it
overwrites the project every time, so they are put back in here.

Usage: scripts/set_build_settings.py PROJECT.xcodeproj KEY=VALUE...
"""
import pathlib
import re
import sys

project = pathlib.Path(sys.argv[1])
settings = dict(arg.split("=", 1) for arg in sys.argv[2:])
settings = {k: v for k, v in settings.items() if v}

new = project / "project.xcproj"      # Xcode 27: JSON-like, settings shared by all targets at the end
old = project / "project.pbxproj"     # earlier Xcode: one settings block per target and configuration
if new.exists():
    text = new.read_text()
    at = text.rindex('\n  "build-settings": {') + len('\n  "build-settings": {')
    lines = "".join(f'\n    "{k}": "{v}",' for k, v in settings.items())
    new.write_text(text[:at] + lines + text[at:])
elif old.exists():
    lines = "".join(f'\n\t\t\t\t{k} = "{v}";' for k, v in settings.items())
    old.write_text(re.sub(r"(\n\t\t\tbuildSettings = \{)", lambda m: m.group(1) + lines, old.read_text()))
else:
    sys.exit(f"no project file in {project}")
print("Set " + ", ".join(f"{k}={v}" for k, v in settings.items()))
