#!/usr/bin/env python3
"""Reject missing platform privileged permissions before packaging the IMS app."""
import argparse
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aapt2", type=Path, required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--allowlist", type=Path, required=True)
    args = parser.parse_args()
    output = subprocess.check_output(
        [str(args.aapt2), "dump", "permissions", str(args.apk)], text=True)
    package = re.search(r"^package: (\S+)$", output, re.MULTILINE)
    if not package or package[1] != "com.mediatek.ims":
        raise SystemExit("Expected com.mediatek.ims APK")
    requested = set(re.findall(r"^uses-permission: name='([^']+)'", output, re.MULTILINE))
    privileged = {
        node.attrib[ANDROID + "name"]
        for node in ET.parse(args.manifest).getroot().findall("permission")
        if "privileged" in node.get(ANDROID + "protectionLevel", "").split("|")
    }
    allowed = set()
    for node in ET.parse(args.allowlist).getroot().findall("privapp-permissions"):
        if node.get("package") == package[1]:
            allowed.update(child.attrib["name"] for child in node
                           if child.tag in ("permission", "deny-permission"))
    required = requested & privileged
    missing = required - allowed
    if missing:
        raise SystemExit("IMS privileged permissions missing from allowlist: "
                         + ", ".join(sorted(missing)))
    print(f"IMS allowlist covers all {len(required)} requested platform privileged permissions")


if __name__ == "__main__":
    main()
