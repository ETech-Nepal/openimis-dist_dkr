#!/usr/bin/env bash
# Upserts conf/fe-core-config.json (theme colours + logo) into core_ModuleConfiguration.
# The frontend reads it at page load; no container rebuild/restart needed.
# Usage: ./apply_fe_core_config.sh [path/to/config.json]
set -euo pipefail
cd "$(dirname "$0")"

CONFIG_FILE="${1:-conf/fe-core-config.json}"
DB_CONTAINER="${DB_CONTAINER:-openimis-dist_dkr-db-1}"
DB_USER="${DB_USER:-IMISuser}"
DB_NAME="${DB_NAME:-IMIS}"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CONFIG_FILE"
CONFIG_JSON="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$CONFIG_FILE")"

docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
  -v cfg="$CONFIG_JSON" <<'SQL'
DELETE FROM "core_ModuleConfiguration" WHERE module = 'fe-core' AND layer = 'fe';
INSERT INTO "core_ModuleConfiguration" (id, module, layer, version, config, is_exposed, is_disabled_until)
VALUES (md5(random()::text || clock_timestamp()::text)::uuid, 'fe-core', 'fe', '1', :'cfg', true, NULL);
SELECT module, layer, is_exposed, length(config) AS config_length FROM "core_ModuleConfiguration" WHERE module = 'fe-core';
SQL

echo "Applied $CONFIG_FILE. Hard-refresh the browser (Ctrl+Shift+R) to see changes."
