#!/bin/bash
set -euo pipefail
DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STOCK_VENDOR="${1:-${HOME}/S17Promini_LineageOS/extracted/super/vendor.img}"
python3 "${DEVICE_DIR}/tools/make-vendor-image.py" "${STOCK_VENDOR}"
"${DEVICE_DIR}/setup-makefiles.sh"
