# static-build-shadowsocks-rust/libev deb package

## shadowsocks-libev

GitHub Actions 使用 `ss-libev.sh` 在 Alpine 3.23 中编译 Linux x86_64 静态二进制。
依赖使用 Alpine 提供的静态库，源码版本在脚本的 `VER_SSLIBEV` 中指定。

- 推送 `shadowsocks-libev` 分支的脚本或工作流变更、提交相关 PR，或手动运行工作流，均会上传 Actions Artifact。
- 推送 `ss-libev-v*` 标签（例如 `ss-libev-v3.3.6-1`）会构建并创建 GitHub Release，附加 `.tar.gz` 和 SHA-256 校验文件。标签应指向包含此工作流的提交。
- 压缩包包含 `ss-local`、`ss-server`、`ss-tunnel`、`ss-manager`、`ss-redir` 和许可证文件。

本地验证（需要 Docker）：

```sh
docker run --rm -v "$PWD:/work" -w /work alpine:3.23 \
  sh -ec 'apk add --no-cache bash; bash ss-libev.sh'
```

产物输出到 `dist/`；脚本会检查静态链接并运行各程序的帮助命令。
