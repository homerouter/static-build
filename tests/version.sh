#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Stop at the package-manager boundary, before installing or downloading anything.
printf '#!/bin/sh\nprintf "%%s" "$VER_SSLIBEV"\nexit 77\n' > "$tmp/apk"
chmod +x "$tmp/apk"
for tag in v3.3.6 v3.3.7 ss-libev-v3.3.6 261024 v261024; do
    status=0
    actual="$(BUILD_TAG="$tag" OUTPUT_DIR="$tmp/out" PATH="$tmp:$PATH" \
        bash "$repo/ss-libev.sh")" || status=$?
    if [[ "$tag" =~ [0-9]{6} ]]; then
        expected="3.3.6"
    else
        expected="${tag#ss-libev-}"
        expected="${expected#v}"
    fi
    test "$status" = 77
    test "$actual" = "$expected"
done
for tag in '' vbad 'v3.3.6/../../other'; do
    status=0
    BUILD_TAG="$tag" OUTPUT_DIR="$tmp/out" PATH="$tmp:$PATH" \
        bash "$repo/ss-libev.sh" > /dev/null 2>&1 || status=$?
    test "$status" = 1
done
echo 'Version checks passed'
