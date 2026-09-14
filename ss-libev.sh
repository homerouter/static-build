#!/usr/bin/env bash
set -euo pipefail

VER_SSLIBEV="3.3.6"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

apk add --no-cache build-base cmake git linux-headers \
    libsodium-dev libsodium-static mbedtls-dev mbedtls-static \
    c-ares-dev pcre2-dev pcre2-static libev-dev

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
# The release tarball omits the bundled libraries; fetch the tag and its submodules.
git clone --depth 1 --branch "v$VER_SSLIBEV" --recurse-submodules --shallow-submodules \
    https://github.com/shadowsocks/shadowsocks-c.git "$BUILD_DIR/shadowsocks-libev-$VER_SSLIBEV"
cmake -S "$BUILD_DIR/shadowsocks-libev-$VER_SSLIBEV" -B "$BUILD_DIR/build" \
    -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -no-pie -s" \
    -DMBEDTLS_CRYPTO_LIBRARY=/usr/lib/libmbedcrypto.a \
    -DSODIUM_LIBRARY=/usr/lib/libsodium.a \
    -DWITH_STATIC=ON -DBUILD_TESTING=OFF -DWITH_DOC_MAN=OFF -DWITH_DOC_HTML=OFF
cmake --build "$BUILD_DIR/build" --parallel "$(nproc)" \
    --target ss-local ss-server ss-tunnel ss-manager ss-redir

for binary in ss-local ss-server ss-tunnel ss-manager ss-redir; do
    test -x "$BUILD_DIR/build/bin/$binary"
    if readelf -l "$BUILD_DIR/build/bin/$binary" | grep -q INTERP; then
        echo "$binary is not statically linked" >&2
        exit 1
    fi
    "$BUILD_DIR/build/bin/$binary" -h > /dev/null 2>&1
done

ARCHIVE="shadowsocks-libev-$VER_SSLIBEV-linux-$(uname -m).tar.gz"
cp "$BUILD_DIR/shadowsocks-libev-$VER_SSLIBEV/"{COPYING,LICENSE} "$BUILD_DIR/build/bin/"
tar czf "$OUTPUT_DIR/$ARCHIVE" -C "$BUILD_DIR/build/bin" \
    ss-local ss-server ss-tunnel ss-manager ss-redir COPYING LICENSE
cd "$OUTPUT_DIR"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
