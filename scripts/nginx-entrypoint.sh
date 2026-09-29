#!/bin/sh
set -eu

: "${PUBLIC_IP:?PUBLIC_IP is required}"

cert_dir="/etc/letsencrypt/live/$PUBLIC_IP"
mkdir -p /etc/nginx/tls
nginx

trap 'nginx -s quit; exit 0' INT TERM
last_hash=""

while :; do
    if [ -s "$cert_dir/fullchain.pem" ] && [ -s "$cert_dir/privkey.pem" ]; then
        current_hash="$(cat "$cert_dir/fullchain.pem" "$cert_dir/privkey.pem" | sha256sum | cut -d ' ' -f 1)"
        if [ "$current_hash" != "$last_hash" ]; then
            cp "$cert_dir/fullchain.pem" /etc/nginx/tls/fullchain.pem
            cp "$cert_dir/privkey.pem" /etc/nginx/tls/privkey.pem
            chmod 600 /etc/nginx/tls/privkey.pem
            cp /config/https.conf /etc/nginx/conf.d/https.conf
            if nginx -t && nginx -s reload; then
                last_hash="$current_hash"
                echo "Nginx loaded certificate for $PUBLIC_IP"
            else
                echo "Nginx certificate reload failed; retrying" >&2
            fi
        fi
    fi
    sleep 60 & wait $!
done
