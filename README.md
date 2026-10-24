# static-build

基于 Docker 与 GitHub Actions 的静态二进制与 Debian (.deb) 软件包构建仓库，所有任务统一在 `main` 分支维护。

## 支持组件

| 组件 | 构建产物 | 架构 | 构建脚本 | GitHub Actions 工作流 |
|------|----------|------|----------|----------------------|
| **Nginx** | 静态 `.deb` 安装包（含 HTTP/3 QUIC、TLS、Stream、fancyindex 等模块） | `amd64`, `arm64` | `nginx.sh` | `.github/workflows/nginx.yml` |
| **shadowsocks-libev** | 静态二进制压缩包 `.tar.gz` 及 SHA256 校验码（ss-local/ss-server 等） | `amd64`, `arm64` | `ss-libev.sh` | `.github/workflows/shadowsocks-libev.yml` |
| **shadowsocks-rust** | 静态 `.deb` 安装包（含 systemd/init 服务配置） | `amd64`, `arm64` | `ss-rust.sh` | `.github/workflows/shadowsocks-rust.yml` |

---

## 本地构建指南（需 Docker）

### 1. Nginx

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -e VER_NGINX=1.31.8 \
  alpine:3.20 sh -ec 'apk add --no-cache bash; bash /work/nginx.sh'
```

产物输出至 `dist/nginx_<version>_<arch>.deb`。

### 2. shadowsocks-libev

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -e BUILD_TAG=v3.3.6 \
  alpine:latest sh -ec 'apk add --no-cache bash; bash /work/ss-libev.sh'
```

产物输出至 `dist/shadowsocks-libev-<version>-linux-<arch>.tar.gz` 及 `.sha256`。

### 3. shadowsocks-rust

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -e VER_SSRUST=1.24.0 \
  alpine:3.20 sh -ec 'apk add --no-cache bash; bash /work/ss-rust.sh'
```

产物输出至 `dist/shadowsocks-rust-server_<version>_<arch>.deb` 及 `.sha256`。

---

## 自动化触发规则

所有工作流均统一在 `main` 分支触发：

- **路径变更**：推送到 `main` 分支时，仅改动的组件目录或脚本会触发对应工作流构建并上传 Artifact。
- **手动调度**：支持在 GitHub Actions 页面使用 `workflow_dispatch` 手动触发任一组建构建，并可自定义版本号。
- **标签发布**：推送版本标签时自动构建并发布 GitHub Release：
  - Nginx: `nginx-v*` 或 `v1.3*`
  - shadowsocks-libev: `ss-libev-v*`, `shadowsocks-libev-v*` 或 `v3.*`
  - shadowsocks-rust: `ss-rust-v*`, `shadowsocks-rust-v*` 或 `v1.2*`
