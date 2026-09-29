# Let's Encrypt IP 证书 Docker Compose 示例

提供两套独立示例：`compose.static.yaml` 运行 Nginx 静态页面，`compose.wordpress.yaml` 运行 WordPress、MariaDB 和 Nginx。两套配置共用证书脚本，但各自使用独立的 Compose 项目和数据卷。**同一台机器同一时间只能启动其中一套**，因为两套都占用宿主机的 80 和 443 端口。

Let’s Encrypt 的 IP 证书有效期为 160 小时，必须使用 `shortlived` 证书配置。这里使用 Certbot 5.4 的 `--ip-address` 和 `webroot` 模式：Nginx 始终在 80 端口提供 HTTP 验证文件；Certbot 每 6 小时检查续期；Nginx 每分钟检查证书内容并在变更后重载。首次申请完成前，HTTP 验证路径正常工作，HTTPS 尚未开放。

## 准备

1. 安装 Docker Engine 和 Docker Compose 插件。
2. 将一个**公网 IPv4 地址**分配到这台服务器，并确保互联网能访问该地址的 **TCP 80 和 443**。检查云安全组、系统防火墙及其他占用端口的程序。此示例按 IPv4 URL 编写。
3. 复制配置并填写实际 IP 和邮箱：

   ```sh
   cp .env.example .env
   nano .env
   ```

   `203.0.113.10` 是文档保留地址，不能用来申请证书。`CERTBOT_EMAIL` 是 Let's Encrypt 注册邮箱。使用 WordPress 时，也要把 `WP_SITE_URL` 改为 `https://你的公网IP`，并更换两个数据库密码。

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
