#!/usr/bin/env bash
# -*- coding: utf-8 -*-
set -euo pipefail

VER_NGINX="${VER_NGINX:-1.31.8}"
VER_FANCYINDEX="${VER_FANCYINDEX:-0.6.0}"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  DEB_ARCH="amd64" ;;
  aarch64) DEB_ARCH="arm64" ;;
  *)       DEB_ARCH="${DEB_ARCH:-$ARCH}" ;;
esac

echo "==> Building Nginx $VER_NGINX for $ARCH ($DEB_ARCH)"

# Install build dependencies
apk add --no-cache \
    gcc g++ make curl linux-headers \
    openssl-dev openssl-libs-static \
    pcre2-dev zlib-dev zlib-static \
    ruby ruby-dev build-base file tar xz

gem install --no-document fpm

BUILD_DIR="$(mktemp -d)"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR" "$STAGING_DIR"' EXIT

cd "$BUILD_DIR"
echo "==> Downloading sources..."
curl -fsSL "https://nginx.org/download/nginx-$VER_NGINX.tar.gz" | tar xz
curl -fsSL "https://github.com/aperezdc/ngx-fancyindex/releases/download/v$VER_FANCYINDEX/ngx-fancyindex-$VER_FANCYINDEX.tar.xz" | tar xJ

cd "nginx-$VER_NGINX"

echo "==> Configuring Nginx with static modules..."
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nobody \
    --group=nogroup \
    --with-file-aio \
    --with-threads \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_dav_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-pcre-jit \
    --add-module="../ngx-fancyindex-$VER_FANCYINDEX" \
    --with-cc-opt="-static" \
    --with-ld-opt="-static"

echo "==> Compiling Nginx..."
make -j"$(nproc)"
make install DESTDIR="$STAGING_DIR"

echo "==> Stripping binary and verifying static linkage..."
strip "$STAGING_DIR/usr/sbin/nginx"

if readelf -l "$STAGING_DIR/usr/sbin/nginx" | grep -qi INTERP; then
    echo "ERROR: nginx binary is dynamically linked!" >&2
    exit 1
fi
"$STAGING_DIR/usr/sbin/nginx" -V

echo "==> Setting up directory layout..."
mkdir -p "$STAGING_DIR/var/cache/nginx"
mkdir -p "$STAGING_DIR/var/log/nginx"
mkdir -p "$STAGING_DIR/var/www/html"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/nginx/script/nginx.service"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/dist}"
mkdir -p "$OUTPUT_DIR"

echo "==> Packaging Nginx deb with FPM..."
fpm -s dir -t deb \
    -n "nginx" \
    -v "$VER_NGINX" \
    -a "$DEB_ARCH" \
    --description "High performance web server and reverse proxy server (static musl build with HTTP/3 QUIC, TLS, Stream, and fancyindex)" \
    --maintainer "debiansid <repo@tlle.eu.org>" \
    --vendor "homerouter" \
    --license "2-clause BSD-like" \
    --category "httpd" \
    --provides "nginx" \
    --provides "httpd" \
    --provides "httpd-cgi" \
    --conflicts "nginx-full,nginx-light,nginx-extras,nginx-core,nginx-custom" \
    --replaces "nginx-full,nginx-light,nginx-extras,nginx-core,nginx-custom" \
    --config-files "/etc/nginx/nginx.conf" \
    --config-files "/etc/nginx/mime.types" \
    --config-files "/etc/nginx/fastcgi.conf" \
    --config-files "/etc/nginx/fastcgi_params" \
    --config-files "/etc/nginx/scgi_params" \
    --config-files "/etc/nginx/uwsgi_params" \
    --deb-systemd "$SERVICE_FILE" \
    -p "$OUTPUT_DIR/nginx_${VER_NGINX}_${DEB_ARCH}.deb" \
    -C "$STAGING_DIR" .

echo "==> Successfully created $OUTPUT_DIR/nginx_${VER_NGINX}_${DEB_ARCH}.deb"
