#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Stop at the package-manager boundary, before installing or downloading anything.
printf '#!/bin/sh\nprintf "%%s" "$VER_SSLIBEV"\nexit 77\n' > "$tmp/apk"
chmod +x "$tmp/apk"
for tag in v3.3.6 v3.3.7 ss-libev-v3.3.6; do
    status=0
    actual="$(BUILD_TAG="$tag" OUTPUT_DIR="$tmp/out" PATH="$tmp:$PATH" \
        bash "$repo/ss-libev.sh")" || status=$?
    expected="${tag#ss-libev-}"
    test "$status" = 77
    test "$actual" = "${expected#v}"
done
for tag in '' vbad 'v3.3.6/../../other'; do
    status=0
    BUILD_TAG="$tag" OUTPUT_DIR="$tmp/out" PATH="$tmp:$PATH" \
        bash "$repo/ss-libev.sh" > /dev/null 2>&1 || status=$?
    test "$status" = 1
done
echo 'Version checks passed'
