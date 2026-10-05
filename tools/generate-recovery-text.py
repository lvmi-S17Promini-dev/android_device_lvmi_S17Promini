#!/usr/bin/env python3
"""Regenerate private narrow-screen PNGs using the built Lineage generator jar.
First run m RecoveryImageGenerator from the Lineage build environment.
"""
from pathlib import Path
import subprocess
import tempfile
import sys

DEVICE = Path(__file__).resolve().parents[1]
LINEAGE = DEVICE.parents[2]
jar = LINEAGE / 'out/host/linux-x86/framework/RecoveryImageGenerator.jar'
assert jar.exists(), 'Build RecoveryImageGenerator first'
with tempfile.TemporaryDirectory(prefix='s17-recovery-fonts-') as directory:
    fonts = Path(directory)
    for family in ['roboto-fonts', 'noto-fonts']:
        for font in sorted((LINEAGE / 'external' / family).rglob('*')):
            if font.suffix.lower() in ['.ttf', '.otf', '.ttc'] and not (fonts / font.name).exists():
                (fonts / font.name).symlink_to(font)
    subprocess.run([
        str(LINEAGE / 'prebuilts/jdk/jdk11/linux-x86/bin/java'),
        '-Djava.awt.headless=true', '--class-path', str(jar),
        str(DEVICE / 'tools/GenerateRecoveryText.java'), str(fonts),
        str(LINEAGE / 'bootable/recovery/tools/recovery_l10n/res'),
        str(DEVICE / ('recovery/res-extra/images' if '--full' in sys.argv else 'recovery/res/images')),
        *(['full'] if '--full' in sys.argv else []),
    ], check=True)
