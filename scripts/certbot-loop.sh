#!/bin/sh
set -eu

: "${PUBLIC_IP:?PUBLIC_IP is required}"
: "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required}"

cert_dir="/etc/letsencrypt/live/$PUBLIC_IP"

while :; do
    if [ -s "$cert_dir/fullchain.pem" ] && [ -s "$cert_dir/privkey.pem" ]; then
        certbot renew --non-interactive --quiet || echo "Certbot renewal failed; retrying in 6 hours" >&2
        sleep 21600
    else
        if certbot certonly --non-interactive --agree-tos \
            --email "$CERTBOT_EMAIL" \
            --preferred-profile shortlived \
            --webroot --webroot-path /var/www/certbot \
            --ip-address "$PUBLIC_IP" --cert-name "$PUBLIC_IP"; then
            echo "Certificate issued for $PUBLIC_IP"
        else
            echo "Initial issuance failed; retrying in 1 hour" >&2
            sleep 3600
        fi
    fi
done
