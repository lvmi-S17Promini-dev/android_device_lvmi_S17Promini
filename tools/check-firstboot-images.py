#!/usr/bin/env python3
"""Inspect first-boot images without flashing or changing them."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import subprocess

DEVICE = Path(__file__).resolve().parents[1]
LINEAGE = DEVICE.parents[2]
SYSTEM_CURRENT_SIZE = 3063197696
SYSTEM_MAX_SIZE = 7132241920 - 1427996672 - 204660736


def expanded_size(path):
    with path.open('rb') as stream:
        header = stream.read(28)
    if len(header) >= 28 and struct.unpack_from('<I', header)[0] == 0xED26FF3A:
        _, major, _, file_header, chunk_header, block, total, _, _ = struct.unpack('<I4H4I', header)
        if major != 1 or file_header < 28 or chunk_header < 12 or not block or block % 512:
            raise ValueError('Invalid Android sparse header')
        return block * total
    return path.stat().st_size


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--images', type=Path, default=LINEAGE / 'out/target/product/S17Promini')
    args = parser.parse_args()
    system, vbmeta = args.images / 'system.img', args.images / 'vbmeta.img'
    for path in [system, vbmeta]:
        if not path.is_file():
            parser.error(f'Image not built: {path}')
    size = expanded_size(system)
    if not size or size > SYSTEM_MAX_SIZE:
        parser.error(f'System expanded size {size} exceeds the stock group budget {SYSTEM_MAX_SIZE}')
    tool = LINEAGE / 'external/avb/avbtool.py'
    system_info = subprocess.check_output(['python3', str(tool), 'info_image', '--image', str(system)], text=True)
    if not re.search(r'Partition Name:\s+system\s*$', system_info, re.MULTILINE):
        parser.error('System AVB partition descriptor is missing')
    vbmeta_info = subprocess.check_output(['python3', str(tool), 'info_image', '--image', str(vbmeta)], text=True)
    flags = re.search(r'^Flags:\s+(\d+)\s*$', vbmeta_info, re.MULTILINE)
    if not flags or int(flags.group(1)) != 3:
        parser.error('Bring-up vbmeta must have flags=3')
    print(f'system expanded bytes: {size}')
    print(f'stock system bytes:    {SYSTEM_CURRENT_SIZE}')
    print(f'stock group budget:   {SYSTEM_MAX_SIZE}')
    print(f'resize needed:        {size > SYSTEM_CURRENT_SIZE}')
    print('vbmeta flags:         3')
    for path in [system, vbmeta]:
        print(f'SHA256 {path.name}: {sha256(path)}')
    print('Image checks passed; device boot and compatibility remain unverified.')


if __name__ == '__main__':
    main()
