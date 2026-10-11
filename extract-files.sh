#!/bin/bash
set -euo pipefail
DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STOCK_VENDOR="${1:-${HOME}/S17Promini_LineageOS/extracted/super/vendor.img}"
python3 "${DEVICE_DIR}/tools/vendor-blobs.py" extract "${STOCK_VENDOR}"
if [[ $# -ge 2 ]]; then
    python3 "${DEVICE_DIR}/tools/prepare-ims.py" "$2"
fi
"${DEVICE_DIR}/setup-makefiles.sh"
