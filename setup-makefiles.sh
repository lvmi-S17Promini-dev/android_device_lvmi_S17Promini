#!/bin/bash
set -euo pipefail
DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd -- "${DEVICE_DIR}/../../.." && pwd)"
PATCH="${DEVICE_DIR}/patches/build-make-prebuilt-target-files.patch"
if git -C "${ANDROID_ROOT}/build/make" apply --check "${PATCH}" 2>/dev/null; then
    git -C "${ANDROID_ROOT}/build/make" apply "${PATCH}"
elif ! git -C "${ANDROID_ROOT}/build/make" apply --reverse --check "${PATCH}" 2>/dev/null; then
    echo "Cannot apply prebuilt target-files support to build/make; check local changes." >&2
    exit 1
fi
python3 "${DEVICE_DIR}/tools/vendor-blobs.py" setup
