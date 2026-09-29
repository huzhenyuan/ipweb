# Let's Encrypt IP 证书 Docker / Podman Compose 示例

提供两套独立示例：`compose.static.yaml` 运行 Nginx 静态页面，`compose.wordpress.yaml` 运行 WordPress、MariaDB 和 Nginx。两套配置共用证书脚本，但各自使用独立的 Compose 项目和数据卷。**同一台机器同一时间只能启动其中一套**，因为两套都占用宿主机的 80 和 443 端口。

Let’s Encrypt 的 IP 证书有效期为 160 小时，必须使用 `shortlived` 证书配置。这里使用 Certbot 5.4 的 `--ip-address` 和 `webroot` 模式：Nginx 始终在 80 端口提供 HTTP 验证文件；Certbot 每 6 小时检查续期；Nginx 每分钟检查证书内容并在变更后重载。首次申请完成前，HTTP 验证路径正常工作，HTTPS 尚未开放。

## 准备

1. 安装 Docker Engine 和 Docker Compose 插件，或安装 Podman 和一个 Compose 提供者（Docker Compose 插件或 `podman-compose`）。`podman compose` 本身会调用这个外部提供者。
2. 将一个**公网 IPv4 地址**分配到这台服务器，并确保互联网能访问该地址的 **TCP 80 和 443**。检查云安全组、系统防火墙及其他占用端口的程序。此示例按 IPv4 URL 编写。
3. 复制配置并填写实际 IP 和邮箱：

   ```sh
   cp -n .env.example .env
   nano .env
   ```

   如果 `.env` 已存在，直接编辑原文件。`203.0.113.10` 是文档保留地址，不能用来申请证书。`CERTBOT_EMAIL` 是 Let's Encrypt 注册邮箱。使用 WordPress 时，也要把 `WP_SITE_URL` 改为 `https://你的公网IP`，并更换两个数据库密码。

## 用 Podman 启动

这两份 Compose 文件也可直接给 Podman 使用。因为宿主机要监听 80/443，下面以 **rootful Podman** 为例。若 `podman compose` 使用 Docker Compose 作为外部提供者，先启用 Podman API socket：

```sh
sudo systemctl enable --now podman.socket
cp -n .env.example .env
# 编辑 .env 中的 IP、邮箱、WordPress URL 和密码
sudo podman compose --env-file .env -f compose.static.yaml up -d
# WordPress 则将文件名改为 compose.wordpress.yaml
sudo podman compose --env-file .env -f compose.static.yaml logs -f certbot nginx
```

`restart: unless-stopped` 负责容器意外退出后的重启。为了让 Podman 容器在宿主机重启后也恢复运行，启用系统提供的重启服务：

```sh
sudo systemctl enable podman-restart.service
```

如果想使用 rootless Podman，需要先让普通用户能够绑定 80 端口。以下设置会把**整台宿主机**的非特权端口起点改为 80；确认符合你的主机策略后再执行：

```sh
printf 'net.ipv4.ip_unprivileged_port_start=80\n' | sudo tee /etc/sysctl.d/90-podman-low-ports.conf
sudo sysctl --system
systemctl --user enable --now podman.socket  # 使用 Docker Compose 提供者时需要
systemctl --user enable podman-restart.service
sudo loginctl enable-linger "$USER"
podman compose --env-file .env -f compose.static.yaml up -d
```

项目中的宿主机绑定挂载已加 `:z`，以适配启用 SELinux 的 Podman 主机。Docker 与 Podman 的镜像、命名卷各自独立；已有 WordPress 数据不会自动迁移。

## 改用国内镜像源

最直接的方法是使用完整的国内镜像地址，无需修改系统的全局镜像配置：

```sh
cp -n .env.cn.example .env
# 编辑 .env 中的 IP、邮箱、WordPress URL 和密码
sudo podman compose --env-file .env -f compose.static.yaml pull
sudo podman compose --env-file .env -f compose.static.yaml up -d
```

`.env.cn.example` 将 Nginx、WordPress、MariaDB 和 Certbot 的镜像指向 DaoCloud 的 `m.daocloud.io`。如果 `.env` 已存在，不要覆盖它；将国内示例中的四个 `*_IMAGE` 值复制到现有 `.env` 即可。切换 WordPress 时，把命令中的 Compose 文件名换成 `compose.wordpress.yaml`。若镜像地址不可用，可以在 `.env` 中分别修改 `NGINX_IMAGE`、`WORDPRESS_IMAGE`、`MARIADB_IMAGE`、`CERTBOT_IMAGE`，填入其他已验证的仓库完整地址。**Certbot 必须为 5.4 或更新版本**，因为较早版本不支持 IP 证书的 webroot 验证。DaoCloud 的公开仓库列表未列出 `certbot/certbot`；本示例的 Certbot 镜像曾成功拉取，但该地址未来是否持续可用取决于镜像站。如果无法拉取，可将相同版本的官方镜像同步到自己的国内仓库，再修改 `CERTBOT_IMAGE`。

Podman 也支持在 `registries.conf` 中配置 Docker Hub 镜像站；该方式会影响当前用户或整台机器的镜像拉取。此项目采用 `.env` 中的逐镜像地址，便于核对每个镜像的来源。镜像源只影响**容器镜像下载**；申请和续期证书时仍需让 Certbot 访问 Let's Encrypt 的 ACME 服务。

## 静态页面

```sh
docker compose --env-file .env -f compose.static.yaml up -d
docker compose --env-file .env -f compose.static.yaml logs -f certbot nginx
```

证书签发后，访问 `https://你的公网IP/`。编辑 [html/index.html](html/index.html) 即可更改页面。首次申请通常需要一点时间；日志中出现 `Certificate issued` 和 `Nginx loaded certificate` 后，HTTPS 才可用。

## WordPress

如果已经启动静态示例，先停止它：

```sh
docker compose --env-file .env -f compose.static.yaml down
docker compose --env-file .env -f compose.wordpress.yaml up -d
docker compose --env-file .env -f compose.wordpress.yaml logs -f certbot nginx
```

证书签发后，访问 `https://你的公网IP/` 完成 WordPress 安装。WordPress 和数据库数据保存在 Docker 命名卷中，普通 `down` 不会删除数据。

## 查看与验证续期

以静态示例为例；使用 WordPress 时将 Compose 文件名换为 `compose.wordpress.yaml`：

```sh
docker compose --env-file .env -f compose.static.yaml exec certbot certbot certificates
docker compose --env-file .env -f compose.static.yaml exec certbot certbot renew --dry-run
openssl s_client -connect 你的公网IP:443 -servername 你的公网IP </dev/null 2>/dev/null | openssl x509 -noout -dates -ext subjectAltName
```

`renew --dry-run` 会走 Let's Encrypt 测试环境，不会替换现有正式证书。正式续期由 Certbot 容器自动执行，Nginx 容器检测到新证书后约一分钟内重载。保持证书数据卷、80 端口和两个容器持续可用；短期证书需要频繁续期。

如果申请失败，先查看 `certbot` 日志，确认 IP 地址正确且外网能通过 80 端口访问 `/.well-known/acme-challenge/`。首次申请失败后脚本会每小时重试。不要对占位 IP 启动示例；失败的真实请求可能触发 Let's Encrypt 速率限制。

参考：[Let’s Encrypt IP 证书公告](https://letsencrypt.org/2026/01/15/6day-and-ip-general-availability)、[Certbot IP 证书说明](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)。
