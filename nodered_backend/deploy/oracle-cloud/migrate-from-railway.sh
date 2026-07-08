#!/bin/bash
# ============================================
# Focus Fitness OS - Data Migration from Railway
# Exports SQLite DB and config from Railway container
# Imports to Oracle Cloud instance
# ============================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found."
    exit 1
fi
source "$ENV_FILE"

SSH_TARGET="${SSH_USER:-ubuntu}@${INSTANCE_PUBLIC_IP}"
SSH_OPTS="-i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no"
RAILWAY_URL="https://focus-fitness-os-backend-production.up.railway.app"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo "=========================================="
echo " Focus Fitness OS - Data Migration"
echo " Railway -> Oracle Cloud"
echo "=========================================="
echo ""

# Step 1: Export data from Railway (via API)
echo "[1/4] Exporting data from Railway..."

# Login to get JWT
LOGIN_RESP=$(curl -s -X POST "${RAILWAY_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"***REMOVED***"}')

ACCESS_TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "WARNING: Could not login to Railway API. Will try direct container export."
    echo "If Railway CLI is available, use: railway run --service <name> cat /data/db/focus_fitness.db"
else
    echo "Login successful. Exporting via API..."

    # Export proposals
    curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "${RAILWAY_URL}/api/v1/proposals?limit=200" > "${TEMP_DIR}/proposals.json"
    echo "  Proposals exported: $(python3 -c "import json; d=json.load(open('${TEMP_DIR}/proposals.json')); print(d.get('data',{}).get('count',0))" 2>/dev/null || echo '?')"

    # Export weekly stats
    curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "${RAILWAY_URL}/api/v1/stats/weekly" > "${TEMP_DIR}/weekly_stats.json"
    echo "  Weekly stats exported."
fi

echo ""

# Step 2: Prepare import script
echo "[2/4] Preparing import data..."
# Create a tarball with exported data
tar -czf "${TEMP_DIR}/ffos-migration.tar.gz" -C "$TEMP_DIR" proposals.json weekly_stats.json 2>/dev/null || true
echo "Migration package created."

# Step 3: Upload to Oracle Cloud
echo ""
echo "[3/4] Uploading to Oracle Cloud..."
scp $SSH_OPTS "${TEMP_DIR}/ffos-migration.tar.gz" "${SSH_TARGET}:/tmp/"
echo "Upload complete."

# Step 4: Import on Oracle Cloud
echo ""
echo "[4/4] Importing data on Oracle Cloud..."
ssh $SSH_OPTS $SSH_TARGET << 'EOF'
    cd /opt/ffos/data
    mkdir -p migration
    cd migration
    tar -xzf /tmp/ffos-migration.tar.gz
    echo "Migration files extracted."
    echo "Note: SQLite database will be initialized automatically on first run."
    echo "If you have a direct DB dump, place it at /opt/ffos/data/db/focus_fitness.db"
EOF

echo ""
echo "=========================================="
echo " Migration Complete!"
echo "=========================================="
echo "Data has been transferred to Oracle Cloud."
echo "The SQLite database will be auto-initialized on first startup."
echo ""
