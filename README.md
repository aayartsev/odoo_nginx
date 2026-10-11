# odoo_nginx

Nginx перед Odoo в Docker: сайты из списка, генерация конфигов, Let's Encrypt, сеть `odoo-net`.

## Состав

| Путь | Назначение |
|------|------------|
| `docker-compose.yml` | `nginx` + `certbot` |
| `sites.list` | список сайтов (домен;email;host;ports) |
| `templates/` | шаблоны HTTP/HTTPS для генерации |
| `conf.d/00-map.conf` | общие `map` для websocket |
| `conf.d/00-bootstrap.conf` | конфиг по умолчанию (без доменов) |
| `conf.d/<domain>.conf` | генерируются скриптом |
| `scripts/generate-sites.sh` | создать/обновить конфиги nginx (`envsubst` / gettext-base) |
| `scripts/issue-certs.sh` | выпуск/перевыпуск сертификатов |
| `.env` | сеть, email по умолчанию |

## Формат `sites.list`

```text
# domain;email;upstream_host;http_port;longpolling_port
erp.hostcheckinfo.com;admin@example.com;odoo;8069;8072
erp-dev.hostcheckinfo.com;;odoo-dev;8070;8073
```

Пустой `email` → берётся `CERTBOT_EMAIL` из `.env`.  
`upstream_host` — имя контейнера в сети `odoo-net`.

Пример: `sites.list.example`.

## Подготовка

```bash
docker network create odoo-net   # если ещё нет
cp sites.list.example sites.list # при необходимости
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

По умолчанию работает только `00-bootstrap.conf` (порт 80, ACME, заглушка).

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

### Обновление (cron)

Фоновый `certbot renew` в compose + раз в сутки:

```bash
0 3 * * * /home/yartsev/projects/odoo_nginx/scripts/renew-and-reload.sh >> /home/yartsev/projects/odoo_nginx/logs/renew.log 2>&1
```

## Типичный сценарий с нуля

```bash
docker network create odoo-net
# заполнить sites.list и .env
docker compose up -d nginx
./scripts/generate-sites.sh    # HTTP-конфиги + ACME на доменах
./scripts/issue-certs.sh       # сертификаты → HTTPS-конфиги + reload
docker compose up -d           # поднять certbot renew loop
```

## Правка вручную

Шаблоны — в `templates/`. После правок:

```bash
./scripts/generate-sites.sh
```
