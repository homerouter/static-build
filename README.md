# static-build-shadowsocks-rust/libev deb package

## shadowsocks-libev

GitHub Actions 使用 `ss-libev.sh` 在 `alpine:latest` 中编译 Linux x86_64 静态二进制。
主程序版本由构建标签去掉 `v` 得到，例如 `v3.3.6` 对应 shadowsocks-libev 3.3.6；脚本通过 `BUILD_TAG` 接收标签。
依赖仍从固定版本源码构建：libsodium 1.0.22、libev 4.33、c-ares 1.34.8。
为兼容 3.3.6，将原 PCRE 8.45 换成 PCRE2 10.48，将 Mbed TLS 4.2.0 降为 3.6.7；不使用 Alpine 预编译的依赖静态库。

- 推送 `shadowsocks-libev` 分支的脚本或工作流变更、提交相关 PR，或手动运行工作流，均会上传 Actions Artifact。
- 分支、PR 及未指定标签的手动构建使用当前提交可达的最近一个 `vX.Y.Z` 标签。
- 推送 `v*` 或 `ss-libev-v*` 标签（例如 `v3.3.6`）会构建并创建 GitHub Release，附加 `.tar.gz` 和 SHA-256 校验文件。标签应指向包含此工作流的提交。
- 已有标签可手动补发：运行工作流时在 `tag` 输入标签名，将检出该标签并发布；留空则仅上传 Artifact。
- 压缩包包含 `ss-local`、`ss-server`、`ss-tunnel`、`ss-manager`、`ss-redir` 和许可证文件。

本地验证（需要 Docker）：

```sh
docker run --rm -e BUILD_TAG=v3.3.6 -v "$PWD:/work" -w /work alpine:latest \
  sh -ec 'apk add --no-cache bash; bash ss-libev.sh'
```

产物输出到 `dist/`；脚本会检查静态链接并运行各程序的帮助命令。
