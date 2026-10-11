#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

load_env

FORCE=0
SITES_LIST="${DEFAULT_SITES_LIST}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--force] [sites.list]

Выпуск или перевыпуск Let's Encrypt сертификатов по списку сайтов.
  --force   принудительный перевыпуск (--force-renewal)

После успеха перегенерирует conf.d и делает reload nginx.
По умолчанию: ${DEFAULT_SITES_LIST}

Нужен запущенный nginx (bootstrap или HTTP-конфиги) на порту 80
и реальный email (в строке списка или CERTBOT_EMAIL в .env).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --force)
      FORCE=1
      shift
      ;;
    *)
      SITES_LIST="$1"
      shift
      ;;
  esac
done

issue_one() {
  local domain="$1"
  local email="$2"
  local upstream="$3"
  local http_port="$4"
  local chat_port="$5"
  local extra=()
  local ec=0

  if [[ -z "$email" ]]; then
    echo "Нет email для ${domain}: укажите в sites.list или CERTBOT_EMAIL в .env" >&2
    return 1
  fi

  if [[ "$FORCE" -eq 1 ]]; then
    extra+=(--force-renewal)
  fi

  echo "Сертификат: ${domain} (${email})..."
  set +e
  docker compose -f "${ROOT}/docker-compose.yml" run --rm -T --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    -d "${domain}" \
    --email "${email}" \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    "${extra[@]+"${extra[@]}"}"
  ec=$?
  set -e

  if [[ "$ec" -eq 0 ]]; then
    return 0
  fi

  # Уже выпущен и не требует renew — не роняем весь список
  if has_certificate "$domain"; then
    echo "  сертификат уже есть (или не требует обновления), продолжаем"
    return 0
  fi

  echo "  ошибка выпуска сертификата для ${domain} (exit ${ec})" >&2
  return "$ec"
}

echo "Выпуск сертификатов из ${SITES_LIST}..."
cd "$ROOT"
iter_sites "$SITES_LIST" issue_one

echo
echo "Перегенерация nginx-конфигов..."
"${ROOT}/scripts/generate-sites.sh" "$SITES_LIST"
echo "Готово."
