#!/usr/bin/env python3
"""Add an early cache kmsg collector to the stock boot ramdisk."""
import argparse
import gzip
import shlex
import re
from pathlib import Path
import subprocess

DEVICE = Path(__file__).resolve().parents[1]
LINEAGE = DEVICE.parents[2]
WORK = Path.home() / 'S17Promini_LineageOS'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, help='Base boot image; preserve its kernel, DTB and cmdline')
parser.add_argument('--output', type=Path, default=WORK / 'artifacts/boot-kmsg-debug.img')
parser.add_argument('--work-dir', type=Path, default=WORK / 'extracted/boot-kmsg-debug')
parser.add_argument('--tag', default='r8', help='Marker in cmdline and collector header')
parser.add_argument('--permissive', action='store_true',
                    help='Temporary userdebug capture across SELinux policy loading')
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_.-]+', args.tag):
    parser.error('tag must contain only letters, digits, dot, underscore or hyphen')
OUT = args.work_dir
OUT.mkdir(parents=True, exist_ok=True)
wrapper = OUT / 'init-wrapper'
subprocess.run([
    str(Path.home() / 'arm-linux-musleabi-cross/bin/arm-linux-musleabi-gcc'),
    '-static', '-Os', '-s', '-march=armv7-a', '-mfloat-abi=soft',
    '-Wall', '-Wextra', '-Werror', f'-DS17_BOOTLOG_TAG="{args.tag}"',
    str(DEVICE / 'tools/boot-kmsg-init.c'), '-o', str(wrapper),
], check=True)

if args.input:
    unpacked = OUT / 'base'
    flags = shlex.split(subprocess.check_output([
        'python3', str(LINEAGE / 'system/tools/mkbootimg/unpack_bootimg.py'),
        '--boot_img', str(args.input.resolve()), '--out', str(unpacked.resolve()),
        '--format=mkbootimg',
    ], text=True))
    ramdisk_input = Path(flags[flags.index('--ramdisk') + 1])
else:
    ramdisk_input = WORK / 'extracted/boot/ramdisk'
    flags = [
        '--kernel', str(WORK / 'extracted/boot/kernel'),
        '--dtb', str(WORK / 'extracted/boot/dtb'), '--header_version', '2',
        '--pagesize', '2048', '--base', '0x40078000', '--kernel_offset', '0x8000',
        '--ramdisk_offset', '0x11a88000', '--tags_offset', '0x07808000',
        '--dtb_offset', '0x07808000', '--os_version', '12.0.0', '--os_patch_level', '2024-03',
        '--cmdline', 'bootopt=64S3,32N2,64N2 buildvariant=user loglevel=8',
    ]
if args.permissive:
    kernel_data = Path(flags[flags.index('--kernel') + 1]).read_bytes()
    if kernel_data.startswith(b'\x1f\x8b'):
        kernel_data = gzip.decompress(kernel_data)
    start = kernel_data.find(b'IKCFG_ST')
    end = kernel_data.find(b'IKCFG_ED', start + 8)
    if start < 0 or end < 0:
        parser.error('permissive mode requires a verifiable embedded kernel config')
    config = gzip.decompress(kernel_data[start + 8:end]).decode()
    if 'CONFIG_SECURITY_SELINUX_DEVELOP=y\n' not in config:
        parser.error('rebuild kernel with CONFIG_SECURITY_SELINUX_DEVELOP=y first')
raw = gzip.decompress(ramdisk_input.read_bytes())
entries, offset = [], 0
while True:
    assert raw[offset:offset+6] == b'070701', 'Expected stock newc archive'
    values = [int(raw[offset+6+i*8:offset+14+i*8], 16) for i in range(13)]
    name = raw[offset+110:offset+110+values[11]-1].decode()
    data_start = (offset+110+values[11]+3) & ~3
    data = raw[data_start:data_start+values[6]]
    entries.append([name, values, data])
    offset = (data_start+values[6]+3) & ~3
    if name == 'TRAILER!!!': break
original = [entry for entry in entries if entry[0].removeprefix('./') == 'init']
assert len(original) == 1 and original[0][1][1] & 0o170000 == 0o100000
original[0][0] = 'init.stock'
values = original[0][1].copy()
values[0] = max(entry[1][0] for entry in entries)+1
values[4], values[12] = 1, 0
entries.insert(-1, ['init', values, wrapper.read_bytes()])
rebuilt = bytearray()
for name, values, data in entries:
    values = values.copy()
    encoded = name.encode()+b'\0'
    values[6], values[11] = len(data), len(encoded)
    rebuilt += b'070701'+b''.join(f'{value:08x}'.encode() for value in values)
    rebuilt += encoded
    rebuilt += bytes((-len(rebuilt)) % 4)
    rebuilt += data
    rebuilt += bytes((-len(rebuilt)) % 4)
ramdisk = OUT / 'ramdisk'
ramdisk.write_bytes(gzip.compress(bytes(rebuilt), mtime=0))
image = args.output
image.parent.mkdir(parents=True, exist_ok=True)
if '--ramdisk' in flags:
    flags[flags.index('--ramdisk') + 1] = str(ramdisk)
else:
    flags += ['--ramdisk', str(ramdisk)]
cmdline_idx = flags.index('--cmdline') + 1
# Retain the base image's blacklist and diagnostics, replace only these switches.
cmdline = [word for word in flags[cmdline_idx].split()
           if not word.startswith(('printk.disable_uart=', 'printk.devkmsg=', 's17.bootlog='))]
if args.permissive:
    cmdline = [word for word in cmdline
               if not word.startswith(('enforcing=', 'androidboot.selinux='))]
    # Keep the collector alive at the instant policy loads, before init applies its setting.
    cmdline += ['enforcing=0', 'androidboot.selinux=permissive']
flags[cmdline_idx] = ' '.join(cmdline + ['printk.disable_uart=0', 'printk.devkmsg=on',
                                      f's17.bootlog={args.tag}'])
subprocess.run([
    'python3', str(LINEAGE / 'system/tools/mkbootimg/mkbootimg.py'),
    *flags, '--output', str(image),
], check=True)
subprocess.run([
    'python3', str(LINEAGE / 'external/avb/avbtool.py'), 'add_hash_footer',
    '--image', str(image), '--partition_name', 'boot', '--partition_size', '33554432',
], check=True)
print(image)
