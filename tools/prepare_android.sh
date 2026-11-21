#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/tools/install_admob.py" android
# A release build without this app's own ad and analytics values must not be produced.
python3 "$root/tools/prepare_services.py"
