#!/usr/bin/env bash
# Общие функции для generate-sites.sh и issue-certs.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF_D="${ROOT}/conf.d"
TEMPLATES="${ROOT}/templates"
CERT_LIVE="${ROOT}/certbot/conf/live"
DEFAULT_SITES_LIST="${ROOT}/sites.list"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

load_env() {
  if [[ -f "${ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "${ROOT}/.env"
    set +a
  fi
}

# Вызывает callback: on_site DOMAIN EMAIL UPSTREAM HTTP_PORT CHAT_PORT
# Usage: iter_sites "$file" my_callback
iter_sites() {
  local file="$1"
  local callback="$2"
  local line domain email upstream http_port chat_port
  local n=0

  if [[ ! -f "$file" ]]; then
    echo "Файл списка не найден: ${file}" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    IFS=';' read -r domain email upstream http_port chat_port <<<"$line"
    domain="$(trim "${domain:-}")"
    email="$(trim "${email:-}")"
    upstream="$(trim "${upstream:-}")"
    http_port="$(trim "${http_port:-}")"
    chat_port="$(trim "${chat_port:-}")"

    if [[ -z "$domain" || -z "$upstream" || -z "$http_port" || -z "$chat_port" ]]; then
      echo "Пропуск некорректной строки: ${line}" >&2
      continue
    fi

    if [[ -z "$email" ]]; then
      email="${CERTBOT_EMAIL:-}"
    fi

    n=$((n + 1))
    "$callback" "$domain" "$email" "$upstream" "$http_port" "$chat_port"
  done <"$file"

  if [[ "$n" -eq 0 ]]; then
    echo "В ${file} нет ни одной валидной строки сайта." >&2
    return 1
  fi
}

has_certificate() {
  local domain="$1"
  [[ -f "${CERT_LIVE}/${domain}/fullchain.pem" && -f "${CERT_LIVE}/${domain}/privkey.pem" ]]
}

render_template() {
  local template="$1"
  local dest="$2"
  # DOMAIN UPSTREAM HTTP_PORT CHAT_PORT уже в окружении
  if ! command -v envsubst >/dev/null 2>&1; then
    echo "Нужен envsubst (пакет gettext)." >&2
    return 1
  fi
  envsubst '${DOMAIN} ${UPSTREAM} ${HTTP_PORT} ${CHAT_PORT}' <"$template" >"$dest"
}

nginx_reload_if_running() {
  if docker compose -f "${ROOT}/docker-compose.yml" ps --status running --services 2>/dev/null | grep -qx nginx; then
    docker compose -f "${ROOT}/docker-compose.yml" exec -T nginx nginx -t
    docker compose -f "${ROOT}/docker-compose.yml" exec -T nginx nginx -s reload
    echo "nginx: config OK, reloaded"
  else
    echo "nginx не запущен — reload пропущен (docker compose up -d nginx)"
  fi
}
