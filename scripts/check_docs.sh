#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "docs/README.md"
  "docs/design/README.md"
  "docs/design/2026-11-21-four-alike-launch/design.md"
  "docs/design/2026-11-21-four-alike-launch/test-plan.json"
  "docs/02-decisions/0001-docs-as-source-of-truth.md"
  "docs/03-architecture/clean-architecture.md"
  "docs/05-markets/google-play.md"
  "docs/06-release/release-checklist.md"
  "docs/07-qa/test-strategy.md"
  "docs/08-ops/dependencies.md"
  "docs/qa/feature-inventory.json"
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    echo "Missing docs source file: ${file}" >&2
    exit 1
  fi
done

echo "Docs source-of-truth structure check passed."
