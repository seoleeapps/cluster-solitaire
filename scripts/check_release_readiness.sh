#!/usr/bin/env bash
set -euo pipefail
python3 tools/check_native.py
printf '%s\n' 'Android build inputs are configured. The approved test plan and its evidence must be verified before build and upload. Signed artifacts, track state and store review require separate readback from Google Play.'
