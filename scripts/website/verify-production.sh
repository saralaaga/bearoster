#!/usr/bin/env bash
set -euo pipefail

check() {
  local path="$1" expected="$2" body
  body="$(curl --fail --silent --show-error --location --retry 6 --retry-delay 3 --retry-all-errors "https://bearoster.com$path")"
  grep -q "$expected" <<<"$body" || {
    echo "production check failed at $path: missing $expected" >&2
    exit 1
  }
}

check /privacy "我们不收集任何数据"
check /support "support@bearoster.com"
check /en/privacy "we collect no data"
check /en/support "macOS 14 or later"

echo "production legal URLs passed"
