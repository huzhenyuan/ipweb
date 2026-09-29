# Let's Encrypt IP 证书 Podman 示例

两套配置任选其一：静态页面用 `compose.static.yaml`，WordPress 用 `compose.wordpress.yaml`。服务器需要公网 IPv4，且 TCP 80、443 端口可从互联网访问。两套配置占用相同端口，不能同时运行。

## 安装与配置

```sh
sudo apt install podman podman-compose
cp -n .env.example .env
nano .env
```

将 `.env` 中的 IP、邮箱改为真实值；运行 WordPress 时还要修改 `WP_SITE_URL` 和数据库密码。需要国内镜像时，把 `.env.cn.example` 中的四个 `*_IMAGE` 配置复制到 `.env`。`203.0.113.10` 只是占位地址。

## 静态页面

```sh
sudo podman compose --env-file .env -f compose.static.yaml up -d
sudo podman compose --env-file .env -f compose.static.yaml logs -f certbot nginx
```

签发成功后访问 `https://你的公网IP/`。页面文件是 [html/index.html](html/index.html)。

## WordPress

如果已启动静态页面，先运行 `sudo podman compose --env-file .env -f compose.static.yaml down`。

```sh
sudo podman compose --env-file .env -f compose.wordpress.yaml up -d
sudo podman compose --env-file .env -f compose.wordpress.yaml logs -f certbot nginx
```

签发成功后访问 `https://你的公网IP/`，完成 WordPress 安装。

## 续期

Certbot 每 6 小时检查一次证书，Nginx 检测到新证书后自动重载。可用下面的命令测试续期；WordPress 用户将文件名换成 `compose.wordpress.yaml`：

```sh
sudo podman compose --env-file .env -f compose.static.yaml exec certbot certbot renew --dry-run
sudo systemctl enable podman-restart.service
```

第二条命令用于宿主机重启后恢复容器。
