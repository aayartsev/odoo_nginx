#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose run --rm -T --entrypoint certbot certbot renew --webroot -w /var/www/certbot --quiet
./scripts/generate-sites.sh
echo "renew + generate-sites + nginx reload OK"
