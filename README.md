# static-build

基于 Docker 与 GitHub Actions 的静态二进制与 Debian (.deb) 软件包构建仓库，所有任务统一在 `main` 分支维护。

## 支持组件与版本

| 组件 | 当前版本 | 构建产物 | 架构 | 构建脚本 | GitHub Actions 工作流 |
|------|----------|----------|------|----------|----------------------|
| **Nginx** | `1.31.8` (Mainline)<br>`fancyindex 0.6.0` | 静态 `.deb` 安装包（含 HTTP/3 QUIC、TLS、Stream、fancyindex） | `amd64`, `arm64` | `nginx.sh` | `.github/workflows/nginx.yml` |
| **shadowsocks-libev** | `3.3.6`<br>`mbedtls 3.6.7`<br>`pcre2 10.49`<br>`c-ares 1.34.9` | 静态二进制压缩包 `.tar.gz` 及 SHA256 校验码 | `amd64`, `arm64` | `ss-libev.sh` | `.github/workflows/shadowsocks-libev.yml` |
| **shadowsocks-rust** | `1.25.0` | 静态 `.deb` 安装包（含 systemd/init 服务配置） | `amd64`, `arm64` | `ss-rust.sh` | `.github/workflows/shadowsocks-rust.yml` |

---

## Release Tag 规则 (YYMMDD)

为统一多组件的发布流程，Release Tag 统一推荐使用日期格式 **`YYMMDD`**（如 `261024` 或 `v261024`）：

- **标签发布**：打上并推送日期标签即可统一触发全部组件并汇总发布到同一 Release：
  ```bash
  git tag 261024
  git push origin 261024
  ```
  工作流会并发出包，将 Nginx、shadowsocks-libev、shadowsocks-rust 的产物自动汇总归并至同一 Release（例如 `261024`）。
- **手动调度**：在 GitHub Actions 页面使用 `workflow_dispatch` 手动触发任一组件构建，`tag` 留空时默认自动采用当前日期的 `YYMMDD`。
- **路径变更**：推送到 `main` 分支时，仅改动的组件目录或脚本会触发对应工作流构建并上传 Actions Artifact。

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
  -e BUILD_TAG=261024 \
  alpine:latest sh -ec 'apk add --no-cache bash; bash /work/ss-libev.sh'
```

产物输出至 `dist/shadowsocks-libev-<version>-linux-<arch>.tar.gz` 及 `.sha256`。

### 3. shadowsocks-rust

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -e VER_SSRUST=1.25.0 \
  alpine:3.20 sh -ec 'apk add --no-cache bash; bash /work/ss-rust.sh'
```

产物输出至 `dist/shadowsocks-rust-server_<version>_<arch>.deb` 及 `.sha256`。
