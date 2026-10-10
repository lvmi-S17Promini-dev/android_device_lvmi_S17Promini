#!/usr/bin/env python3
"""Wrap one compiled FDT in the board's validated stock DT table layout."""
import argparse
from pathlib import Path
import struct


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--dtb", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    template = args.template.read_bytes()
    header = struct.unpack_from(">8I", template)
    if header[0] != 0xD7B7AB1E or header[2:6] != (32, 32, 1, 32):
        raise ValueError("Expected the stock single-entry, 32-byte-header DT table")
    if header[1] != len(template) or header[7] != 0:
        raise ValueError("Invalid stock template length/version")
    entry = struct.unpack_from(">8I", template, 32)
    if entry[1] != 64 or entry[0] + 64 != len(template):
        raise ValueError("Unexpected stock DT entry layout")
    dtb = args.dtb.read_bytes()
    magic, size = struct.unpack_from(">2I", dtb)
    if magic != 0xD00DFEED or size != len(dtb):
        raise ValueError("Invalid compiled FDT")
    wrapped = bytearray(template[:64])
    struct.pack_into(">I", wrapped, 4, 64 + len(dtb))
    struct.pack_into(">I", wrapped, 32, len(dtb))
    wrapped.extend(dtb)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(wrapped)


if __name__ == "__main__":
    main()
