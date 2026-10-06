#!/bin/bash
set -euo pipefail
DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python3 "${DEVICE_DIR}/tools/vendor-blobs.py" setup
