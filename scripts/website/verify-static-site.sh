#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

required=(
  website/index.html
  website/privacy/index.html
  website/support/index.html
  website/en/index.html
  website/en/privacy/index.html
  website/en/support/index.html
)

for file in "${required[@]}"; do
  test -s "$file" || { echo "missing site file: $file" >&2; exit 1; }
done

grep -q "https://bearoster.com/privacy" website/index.html
grep -q "https://bearoster.com/support" website/support/index.html
grep -q "support@bearoster.com" website/privacy/index.html
grep -q "macOS 14" website/en/support/index.html

echo "static site checks passed"
