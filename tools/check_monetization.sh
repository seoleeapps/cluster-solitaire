#!/usr/bin/env bash
# Validate the monetization profile with the in-house framework (local release gate).
# The framework is not part of this repository, so the check exits 2 when it is missing
# instead of passing silently.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK="${BM_FRAMEWORK_ROOT:-${AGENT_HOME:-$HOME/.agent}/skills/game-monetization-framework}"
PROFILE="$ROOT/godot/data/monetization/bm-profile.json"
if [ ! -f "$FRAMEWORK/scripts/validate_bm.py" ]; then
  echo "monetization framework not found at $FRAMEWORK (set BM_FRAMEWORK_ROOT)" >&2
  exit 2
fi
python3 "$FRAMEWORK/scripts/validate_bm.py" "$PROFILE" --root "$FRAMEWORK" --strict
