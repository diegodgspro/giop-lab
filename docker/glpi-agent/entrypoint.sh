#!/bin/sh
set -eu

: "${GLPI_AGENT_SERVER:?GLPI_AGENT_SERVER is required}"
: "${GLPI_INVENTORY_OAUTH_CLIENT_ID:?GLPI_INVENTORY_OAUTH_CLIENT_ID is required}"
: "${GLPI_INVENTORY_OAUTH_CLIENT_SECRET:?GLPI_INVENTORY_OAUTH_CLIENT_SECRET is required}"

exec glpi-agent \
  --server="$GLPI_AGENT_SERVER" \
  --oauth-client-id="$GLPI_INVENTORY_OAUTH_CLIENT_ID" \
  --oauth-client-secret="$GLPI_INVENTORY_OAUTH_CLIENT_SECRET" \
  --no-httpd \
  --force \
  --logger=stderr
