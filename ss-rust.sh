#!/usr/bin/env bash
# -*- coding: utf-8 -*-
set -euo pipefail

VER_SSRUST="${VER_SSRUST:-${BUILD_TAG:-${GITHUB_REF_NAME:-1.24.0}}}"
VER_SSRUST="${VER_SSRUST#ss-rust-}"
VER_SSRUST="${VER_SSRUST#v}"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)
    DEB_ARCH="amd64"
    RUST_TARGET="x86_64-unknown-linux-musl"
    ;;
  aarch64)
    DEB_ARCH="arm64"
    RUST_TARGET="aarch64-unknown-linux-musl"
    ;;
  *)
    DEB_ARCH="${DEB_ARCH:-$ARCH}"
    RUST_TARGET="${RUST_TARGET:-${ARCH}-unknown-linux-musl}"
    ;;
esac

echo "==> Building shadowsocks-rust-server $VER_SSRUST for $ARCH ($DEB_ARCH / $RUST_TARGET)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Install dependencies if running in Alpine container
if command -v apk >/dev/null 2>&1; then
  apk add --no-cache curl binutils bash ruby ruby-dev build-base tar xz file
fi

if ! command -v fpm >/dev/null 2>&1; then
  gem install --no-document fpm
fi

BUILD_DIR="$(mktemp -d)"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR" "$STAGING_DIR"' EXIT

RELEASE_TAR="shadowsocks-v${VER_SSRUST}.${RUST_TARGET}.tar.xz"
DOWNLOAD_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${VER_SSRUST}/${RELEASE_TAR}"

echo "==> Downloading $DOWNLOAD_URL..."
curl -fsSL --retry 3 "$DOWNLOAD_URL" -o "$BUILD_DIR/$RELEASE_TAR"

echo "==> Extracting release archive..."
mkdir -p "$BUILD_DIR/extracted"
tar -xJf "$BUILD_DIR/$RELEASE_TAR" -C "$BUILD_DIR/extracted"

mkdir -p "$STAGING_DIR/usr/bin"
mkdir -p "$STAGING_DIR/etc/shadowsocks-rust"

if [ -f "$BUILD_DIR/extracted/ssserver" ]; then
  cp "$BUILD_DIR/extracted/ssserver" "$STAGING_DIR/usr/bin/"
else
  echo "ERROR: ssserver binary not found in archive" >&2
  exit 1
fi

if [ -f "$BUILD_DIR/extracted/ssservice" ]; then
  cp "$BUILD_DIR/extracted/ssservice" "$STAGING_DIR/usr/bin/"
fi

echo "==> Stripping binaries and verifying static linkage..."
for bin in "$STAGING_DIR/usr/bin"/*; do
  [ -f "$bin" ] || continue
  strip "$bin" || true
  if readelf -l "$bin" | grep -qi INTERP; then
    echo "ERROR: $bin is dynamically linked!" >&2
    exit 1
  fi
done

# Copy configurations
CONFIG_SRC="$SCRIPT_DIR/shadowsocks-rust-server/etc/shadowsocks-rust"
if [ -d "$CONFIG_SRC" ]; then
  cp -r "$CONFIG_SRC"/* "$STAGING_DIR/etc/shadowsocks-rust/"
fi

# Download example configs if not present
if [ ! -f "$STAGING_DIR/etc/shadowsocks-rust/config.json.example" ]; then
  curl -fsSL --retry 3 "https://raw.githubusercontent.com/shadowsocks/shadowsocks-rust/v${VER_SSRUST}/examples/config.json" \
    -o "$STAGING_DIR/etc/shadowsocks-rust/config.json.example" 2>/dev/null || true
fi

SERVICE_FILE="$SCRIPT_DIR/shadowsocks-rust-server/script/shadowsocks-rust.service"
INIT_FILE="$SCRIPT_DIR/shadowsocks-rust-server/script/shadowsocks-rust.init"
DEFAULT_FILE="$SCRIPT_DIR/shadowsocks-rust-server/script/shadowsocks-rust.default"
POSTINST_FILE="$SCRIPT_DIR/shadowsocks-rust-server/script/shadowsocks-rust.postinst"

FPM_EXTRA_ARGS=()
[ -f "$SERVICE_FILE" ] && FPM_EXTRA_ARGS+=(--deb-systemd "$SERVICE_FILE")
[ -f "$INIT_FILE" ] && FPM_EXTRA_ARGS+=(--deb-init "$INIT_FILE")
[ -f "$DEFAULT_FILE" ] && FPM_EXTRA_ARGS+=(--deb-default "$DEFAULT_FILE")
[ -f "$POSTINST_FILE" ] && FPM_EXTRA_ARGS+=(--after-install "$POSTINST_FILE")
[ -f "$STAGING_DIR/etc/shadowsocks-rust/config.json" ] && FPM_EXTRA_ARGS+=(--config-files "/etc/shadowsocks-rust/config.json")

PKG_NAME="shadowsocks-rust-server_${VER_SSRUST}_${DEB_ARCH}.deb"
echo "==> Packaging deb package with FPM..."
fpm -s dir -C "$STAGING_DIR" -t deb \
  -n "shadowsocks-rust-server" \
  -v "$VER_SSRUST" \
  -a "$DEB_ARCH" \
  -f \
  --description "High performance lightweight shadowsocks-rust server (statically linked musl binary)" \
  --maintainer "debiansid <repo@tlle.eu.org>" \
  --vendor "homerouter" \
  --category "net" \
  --provides "shadowsocks-rust-server" \
  --exclude 'script' \
  --deb-no-default-config-files \
  "${FPM_EXTRA_ARGS[@]}" \
  -p "$OUTPUT_DIR/$PKG_NAME" \
  .

cd "$OUTPUT_DIR"
sha256sum "$PKG_NAME" > "$PKG_NAME.sha256"
echo "==> Successfully created $OUTPUT_DIR/$PKG_NAME and $PKG_NAME.sha256"
