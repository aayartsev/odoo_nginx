# odoo_nginx

Nginx перед Odoo в Docker: сайты из списка, генерация конфигов, Let's Encrypt, сеть `odoo-net`.

## Состав

| Путь | Назначение |
|------|------------|
| `docker-compose.yml` | `nginx` + `certbot` |
| `sites.list` | список сайтов (локальный, в git не коммитится) |
| `sites.list.example` | пример списка |
| `html/` | страница bootstrap по умолчанию |
| `templates/` | шаблоны HTTP/HTTPS для генерации |
| `conf.d/00-map.conf` | общие `map` для websocket |
| `conf.d/00-bootstrap.conf` | default server (ACME + HTML) |
| `conf.d/<domain>.conf` | генерируются скриптом |
| `scripts/generate-sites.sh` | создать/обновить конфиги (`envsubst` / gettext-base) |
| `scripts/issue-certs.sh` | выпуск/перевыпуск сертификатов |
| `scripts/reset-bootstrap.sh` | сброс к bootstrap (удалить сгенерированные conf) |
| `.env` | сеть, email по умолчанию |

## Формат `sites.list`

```text
# domain;email;upstream_host;http_port;longpolling_port
erp.example.com;admin@example.com;odoo;8069;8072
erp-dev.example.com;;odoo-dev;8070;8073
```

Пустой `email` → берётся `CERTBOT_EMAIL` из `.env`.  
`upstream_host` — имя контейнера в сети `odoo-net`.

## Подготовка

```bash
docker network create odoo-net   # если ещё нет
cp sites.list.example sites.list
# отредактируйте sites.list и CERTBOT_EMAIL в .env
```

В конфиге каждого Odoo:

```ini
proxy_mode = True
```

## Запуск

```bash
docker compose up -d
```

По умолчанию: `00-bootstrap.conf` + страница `html/index.html` (порт 80, ACME).

### Добавить сайты

```bash
./scripts/generate-sites.sh
```

Создаёт `conf.d/<domain>.conf`. Пока сертификата нет — HTTP-прокси; после выпуска — HTTPS.

### Сертификаты

Nginx должен слушать 80; DNS доменов → этот сервер.

```bash
./scripts/issue-certs.sh          # выпуск по sites.list
./scripts/issue-certs.sh --force  # принудительный перевыпуск
```

После успеха скрипт сам перегенерирует конфиги и сделает reload.

### Сброс к bootstrap

```bash
./scripts/reset-bootstrap.sh              # удалить сгенерированные conf
./scripts/reset-bootstrap.sh --purge-certs  # + очистить сертификаты (с подтверждением)
```

### Обновление (cron)

Фоновый `certbot renew` в compose + раз в сутки на хосте:

```bash
0 3 * * * /path/to/odoo_nginx/scripts/renew-and-reload.sh >> /path/to/odoo_nginx/logs/renew.log 2>&1
```

## Типичный сценарий с нуля

```bash
docker network create odoo-net
cp sites.list.example sites.list   # заполнить
docker compose up -d nginx
./scripts/generate-sites.sh
./scripts/issue-certs.sh
docker compose up -d
```

## Правка вручную

Шаблоны — в `templates/`, страница bootstrap — в `html/`. После правок шаблонов:

```bash
./scripts/generate-sites.sh
```
