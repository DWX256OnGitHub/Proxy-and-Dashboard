<div align="center">

# Mihomo Proxy & Dashboard

基于 Mihomo 的代理服务镜像，内置 MetaCubeX Dashboard，并由 Caddy 提供 Web 服务。

[![Last commit](https://img.shields.io/github/last-commit/DWX256OnGitHub/Proxy-and-Dashboard)](https://github.com/DWX256OnGitHub/Proxy-and-Dashboard/commits/main)
[![Build](https://img.shields.io/github/actions/workflow/status/DWX256OnGitHub/Proxy-and-Dashboard/docker-build.yml?branch=main)](https://github.com/DWX256OnGitHub/Proxy-and-Dashboard/actions/workflows/docker-build.yml)
[![GHCR](https://img.shields.io/badge/GHCR-proxy--and--dashboard-blue?logo=docker)](https://github.com/DWX256OnGitHub/Proxy-and-Dashboard/pkgs/container/proxy-and-dashboard)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./License)

</div>

## 功能特点

- 将 Mihomo 核心与 MetaCubeX Dashboard 集成在一个容器中。
- 发布 `linux/amd64` 和 `linux/arm64` 多架构镜像；ARM64 主机可直接运行对应镜像。
- 首次启动时根据环境变量生成 Mihomo 配置，并将配置保存在挂载目录中。
- 直接读取返回 Clash/Mihomo YAML 格式的订阅，并使用 ACL4SSR Full AdblockPlus 规则集，无需订阅转换器。
- 启动时自动刷新订阅和 ACL4SSR 规则，之后每 24 小时更新；已有缓存时若更新失败，会继续使用缓存。
- Dashboard 由 Caddy 提供，通过同一 Web 端口访问面板和代理 API。

## 快速开始

需要 Docker Compose 和一个可用的订阅链接。

```bash
git clone https://github.com/DWX256OnGitHub/Proxy-and-Dashboard.git
cd Proxy-and-Dashboard
```

创建或编辑 `docker-compose.yml`，填入订阅地址和控制器密钥：

```yaml
services:
  mihomo:
    image: ghcr.io/dwx256ongithub/proxy-and-dashboard:latest
    container_name: mihomo
    restart: unless-stopped
    environment:
      TZ: Asia/Shanghai
      SUBSCRIBE_URL: "https://example.com/your-subscription"
      SUBSCRIBE_NAME: default
      CLASH_SECRET: "请替换为强密码"
      LOG_LEVEL: info
    ports:
      - "7890:7890"
      - "7891:7891"
      - "7892:7892"
      - "7893:7893"
      - "7894:7894"
      - "8080:8080"
      - "9090:9090"
    volumes:
      - ./clash-config:/root/.config/mihomo
      - ./metacubexd-config:/config/caddy
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
```

项目默认配置启用了 TUN；上面的 Compose 示例已包含所需的 `NET_ADMIN` 权限和 `/dev/net/tun` 设备映射。启动服务并查看状态：

```bash
docker compose up -d
docker compose logs -f mihomo
```

Dashboard 地址：`http://<服务器IP>:8080`

> 若不需要 TUN，请从 Compose 配置中移除 `cap_add` 和 `devices`，并在首次启动生成配置后，将 `clash-config/config.yaml` 中的 `tun.enable` 改为 `false`，然后重启容器。

### 使用 `docker run`

也可以不使用 Compose，直接运行容器。Linux 主机启用 TUN 时需要 `NET_ADMIN` 权限和 `/dev/net/tun` 设备：

```bash
mkdir -p clash-config metacubexd-config

docker run -d \
  --name mihomo \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -p 7890:7890 \
  -p 7891:7891 \
  -p 7892:7892 \
  -p 7893:7893 \
  -p 7894:7894 \
  -p 8080:8080 \
  -p 9090:9090 \
  -e TZ=Asia/Shanghai \
  -e SUBSCRIBE_URL="https://example.com/your-subscription" \
  -e SUBSCRIBE_NAME=default \
  -e CLASH_SECRET="请替换为强密码" \
  -e LOG_LEVEL=info \
  -v "$(pwd)/clash-config:/root/.config/mihomo" \
  -v "$(pwd)/metacubexd-config:/config/caddy" \
  ghcr.io/dwx256ongithub/proxy-and-dashboard:latest
```

若不使用 TUN，移除 `--cap-add` 和 `--device` 参数，并在首次生成的 `clash-config/config.yaml` 中设置 `tun.enable: false`。已有 `clash-config/config.yaml` 时，更新环境变量不会自动修改该文件。

## 镜像与架构

```bash
docker pull ghcr.io/dwx256ongithub/proxy-and-dashboard:latest
```

镜像支持 `linux/amd64` 和 `linux/arm64`。Docker 会依据主机架构自动拉取对应版本，不需要手动指定架构。

- `latest`：最近一次成功构建的镜像。
- `vX.Y.Z`：按 Mihomo 核心版本标记的镜像，例如 `v1.19.32`。

更新现有 Compose 部署：

```bash
docker compose pull
docker compose up -d
```

## 端口

| 端口 | 用途 |
| --- | --- |
| `7890` | 混合代理（HTTP + SOCKS5） |
| `7891` | SOCKS5 代理 |
| `7892` | HTTP 代理 |
| `7893` | Redir 代理 |
| `7894` | TProxy 代理 |
| `8080` | Dashboard Web 界面 |
| `9090` | Mihomo 外部控制 API |

请勿将 `9090` 控制 API 直接暴露到不可信网络。设置 `CLASH_SECRET`，并通过防火墙限制访问。

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SUBSCRIBE_URL` | 空 | 返回 Clash/Mihomo YAML 格式的订阅 URL，内容需包含 `proxies`；首次生成配置时写入订阅提供者。 |
| `SUBSCRIBE_NAME` | `default` | 订阅提供者名称；自动刷新时仅支持字母、数字、点、下划线和连字符。 |
| `CLASH_SECRET` | 空 | Mihomo 控制 API 密钥；建议设置强密码。 |
| `LOG_LEVEL` | `info` | Mihomo 日志级别，例如 `silent`、`error`、`warning`、`info`、`debug`。 |
| `TZ` | 镜像默认时区 | 容器时区，例如 `Asia/Shanghai`。 |

## 配置与数据

Compose 文件会将以下目录挂载到项目目录，容器首次启动时会自动创建：

- `./clash-config`：Mihomo 配置及运行数据。首次启动生成 `config.yaml`；之后环境变量不会覆盖已有配置。
- `./metacubexd-config`：Caddy 配置数据。

### 订阅与规则更新

容器使用 Mihomo 的 `proxy-providers` 直接拉取订阅，并通过远程 `rule-providers` 加载 ACL4SSR Full AdblockPlus 规则列表。规则按 Mihomo 原生 `classical` 文本格式读取，无需把订阅交给转换服务。

入口脚本会在 Mihomo 控制 API 就绪后主动刷新订阅和 ACL4SSR 规则；Mihomo 也会按配置每 24 小时自动检查更新。首次启动需要容器能访问订阅地址和 ACL4SSR 规则源。后续更新失败时会记录警告，并继续使用已有缓存；若首次拉取失败且本地没有缓存，相关 provider 将无法加载。

本次更新的模板只会在首次生成 `config.yaml` 时生效。已有部署若要切换到 ACL4SSR 规则，请先备份 `clash-config/config.yaml`，再删除该文件并重启容器以按新模板重新生成；自定义设置需要重新合并。

修改配置后重启：

```bash
docker compose restart mihomo
```

如果修改了 `SUBSCRIBE_URL`、`SUBSCRIBE_NAME`、`CLASH_SECRET` 或 `LOG_LEVEL`，请同时按需更新已有的 `clash-config/config.yaml`，再重启容器。自动刷新使用 `CLASH_SECRET` 调用控制 API，因此环境变量和配置文件中的密钥需保持一致。

## 常见问题

- **Dashboard 无法访问：**确认 `8080` 已映射，并检查 `docker compose logs mihomo`。
- **订阅或节点未加载：**检查订阅链接、容器网络连接和 `clash-config/config.yaml`。
- **TUN 启动失败：**确认宿主机支持 TUN，并按快速开始部分配置 `NET_ADMIN` 和 `/dev/net/tun`；也可以关闭 `tun.enable`。
- **GHCR 拉取提示未授权：**如果镜像包设为私有，先运行 `docker login ghcr.io`；公开分发请将 GHCR 包可见性设为 Public。

## 项目与许可

- 仓库：[DWX256OnGitHub/Proxy-and-Dashboard](https://github.com/DWX256OnGitHub/Proxy-and-Dashboard)
- 原仓库：[daitcl/mihomo](https://github.com/daitcl/mihomo)
- 原作者：[daitcl](https://github.com/daitcl)
- 上游项目：[Mihomo](https://github.com/MetaCubeX/mihomo) · [MetaCubeX Dashboard](https://github.com/MetaCubeX/metacubexd)
- 许可：[MIT](./License)
