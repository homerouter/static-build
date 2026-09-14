#!/usr/bin/env bash
set -euo pipefail

VER_SSLIBEV="${BUILD_TAG:?Set BUILD_TAG to a release tag such as v3.3.6}"
VER_SSLIBEV="${VER_SSLIBEV#ss-libev-}"
export VER_SSLIBEV="${VER_SSLIBEV#v}"
if [[ ! "$VER_SSLIBEV" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid release tag: $BUILD_TAG (expected vX.Y.Z)" >&2
    exit 1
fi
export VER_SIPOBFS="0.0.5"
export VER_MBEDTLS="3.6.7"
export VER_SODIUM="1.0.22"
export VER_PCRE2="10.48"
export VER_EV="4.33"
export VER_CARES="1.34.8"
export PKG_BUILD="curl build-base linux-headers autoconf automake libtool cmake git"
export CFLAGS="-Os"
export LDFLAGS="-static -s"

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
apk add --no-cache $PKG_BUILD
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

curl -fLsS --retry 3 "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$VER_MBEDTLS/mbedtls-$VER_MBEDTLS.tar.bz2" | tar xj -C "$BUILD_DIR"
curl -fLsS --retry 3 "https://download.libsodium.org/libsodium/releases/libsodium-$VER_SODIUM.tar.gz" | tar xz -C "$BUILD_DIR"
curl -fLsS --retry 3 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$VER_PCRE2/pcre2-$VER_PCRE2.tar.gz" | tar xz -C "$BUILD_DIR"
curl -fLsS --retry 3 "https://dist.schmorp.de/libev/Attic/libev-$VER_EV.tar.gz" | tar xz -C "$BUILD_DIR"
curl -fLsS --retry 3 "https://github.com/c-ares/c-ares/releases/download/v$VER_CARES/c-ares-$VER_CARES.tar.gz" | tar xz -C "$BUILD_DIR"
# The 3.3.6 release tarball omits libcork, libipset and libbloom.
git clone --depth 1 --branch "v$VER_SSLIBEV" --recurse-submodules --shallow-submodules \
    https://github.com/shadowsocks/shadowsocks-c.git "$BUILD_DIR/shadowsocks-libev-$VER_SSLIBEV"

cd "$BUILD_DIR/libsodium-$VER_SODIUM"
./configure --prefix=/usr --disable-ssp --disable-shared
make -j"$(nproc)"
make install

cmake -S "$BUILD_DIR/mbedtls-$VER_MBEDTLS" -B "$BUILD_DIR/mbedtls-build" \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF -DUSE_SHARED_MBEDTLS_LIBRARY=OFF
cmake --build "$BUILD_DIR/mbedtls-build" --parallel "$(nproc)"
cmake --install "$BUILD_DIR/mbedtls-build"

cd "$BUILD_DIR/pcre2-$VER_PCRE2"
./configure --prefix=/usr --enable-jit --enable-unicode --disable-shared \
    --with-match-limit-depth=8192
make -j"$(nproc)"
make install

cd "$BUILD_DIR/libev-$VER_EV"
./configure --prefix=/usr --disable-shared
make -j"$(nproc)"
make install

cd "$BUILD_DIR/c-ares-$VER_CARES"
./configure --prefix=/usr --disable-shared
make -j"$(nproc)"
make install

# 3.3.6 uses CMake; explicitly select static libraries for its feature checks too.
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
