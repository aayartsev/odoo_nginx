#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source .env

EMAIL="${CERTBOT_EMAIL:?Задайте CERTBOT_EMAIL в .env}"
DOMAIN="${DOMAIN:?Задайте DOMAIN в .env}"

issue_cert() {
  local domain="$1"
  echo "Выпуск сертификата для ${domain}..."
  docker compose run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    -d "${domain}" \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --non-interactive
}

issue_cert "${DOMAIN}"

if [[ -n "${DOMAIN_DEV:-}" ]]; then
  issue_cert "${DOMAIN_DEV}"
fi

echo
echo "Готово. Включите HTTPS-конфиг и перезагрузите nginx:"
echo "  cp conf.d/odoo.conf.https.example conf.d/odoo.conf"
echo "  docker compose exec nginx nginx -t"
echo "  docker compose exec nginx nginx -s reload"
