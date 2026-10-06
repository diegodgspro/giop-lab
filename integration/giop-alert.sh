#!/bin/sh
# Zabbix Script media type: one synthetic JSON argument, never a secret argument.
set -eu
test "$#" -eq 1 || exit 1
# Zabbix does not guarantee inherited environment for custom alert scripts.
# Read only the scoped, ignored runtime file prepared from the existing .env.
if [ -r /run/giop/alert.env ]; then
  IFS= read -r secret_line < /run/giop/alert.env
  case "$secret_line" in
    GIOP_WEBHOOK_SECRET=*) GIOP_WEBHOOK_SECRET=${secret_line#GIOP_WEBHOOK_SECRET=} ;;
    *) exit 1 ;;
  esac
fi
test -n "${GIOP_WEBHOOK_SECRET:-}" || exit 1
case "$GIOP_WEBHOOK_SECRET" in *[!A-Za-z0-9_-]*) exit 1 ;; esac
# Zabbix 7.0 DATE macros emit yyyy.mm.dd; FastAPI expects ISO date separators.
payload=$(printf '%s' "$1" | sed -E 's/("event_time"[[:space:]]*:[[:space:]]*"[0-9]{4})\.([0-9]{2})\.([0-9]{2}T)/\1-\2-\3/')
# Header via stdin config keeps the shared secret out of process arguments.
# Use only a generated hexadecimal secret in .env (no quotes/newlines).
status=$(printf 'header = "X-GIOP-Webhook-Secret: %s"\n' "$GIOP_WEBHOOK_SECRET" |
  curl --config - --silent --output /dev/null --write-out '%{http_code}' --max-time 35 \
    --header 'Content-Type: application/json' --data-binary "$payload" \
    http://integration:8090/api/v1/zabbix/events) || exit 1
test "$status" = 202 || { echo 'GIOP delivery not accepted; inspect integration state.' >&2; exit 1; }
