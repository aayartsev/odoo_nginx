#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/scripts/renew-and-reload.sh"
LOG="${ROOT}/logs/renew.log"
MARKER="# odoo-nginx-renew"
SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--remove] [--schedule '0 3 * * *']

Устанавливает (или удаляет) crontab-задачу renew сертификатов.
Пути вычисляются от каталога проекта автоматически.

  --remove              убрать задачу
  --schedule 'EXPR'     cron-выражение (по умолчанию: 0 3 * * *)
  CRON_SCHEDULE=...     то же через переменную окружения
EOF
}

ACTION=install

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --remove)
      ACTION=remove
      shift
      ;;
    --schedule)
      SCHEDULE="${2:?Укажите cron-выражение после --schedule}"
      shift 2
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

LINE="${SCHEDULE} ${SCRIPT} >> ${LOG} 2>&1 ${MARKER}"

if [[ ! -f "$SCRIPT" ]]; then
  echo "Не найден ${SCRIPT}" >&2
  exit 1
fi
chmod +x "$SCRIPT" 2>/dev/null || true
mkdir -p "${ROOT}/logs"

current="$(crontab -l 2>/dev/null || true)"
filtered="$(printf '%s\n' "$current" | grep -vF "$MARKER" || true)"
# убрать лишние пустые строки в конце
filtered="$(printf '%s\n' "$filtered" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ "$ACTION" == "remove" ]]; then
  if ! printf '%s\n' "$current" | grep -qF "$MARKER"; then
    echo "Задача ${MARKER} в crontab не найдена."
    exit 0
  fi
  if [[ -z "${filtered//[[:space:]]/}" ]]; then
    crontab -r 2>/dev/null || true
  else
    printf '%s\n' "$filtered" | crontab -
  fi
  echo "Задача ${MARKER} удалена из crontab."
  exit 0
fi

{
  [[ -n "${filtered//[[:space:]]/}" ]] && printf '%s\n' "$filtered"
  printf '%s\n' "$LINE"
} | crontab -

echo "Crontab обновлён:"
echo "  ${LINE}"
echo
echo "Проверка: crontab -l | grep odoo-nginx-renew"
