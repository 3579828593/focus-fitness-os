#!/bin/bash
# ============================================
# Focus Fitness OS - Deploy to Oracle Cloud
# Run from local machine to deploy updates
# Usage: ./deploy-oracle.sh [image-tag]
# Default tag: latest
# ============================================
set -euo pipefail

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found. Copy .env.example to .env and fill in values."
    exit 1
fi

source "$ENV_FILE"

IMAGE_TAG="${1:-latest}"
IMAGE="ghcr.io/3579828593/focus-fitness-os-backend:${IMAGE_TAG}"
SSH_TARGET="${SSH_USER:-ubuntu}@${INSTANCE_PUBLIC_IP}"
SSH_OPTS="-i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "=========================================="
echo " Focus Fitness OS - Oracle Cloud Deploy"
echo "=========================================="
echo "Image:  ${IMAGE}"
echo "Target: ${SSH_TARGET}"
echo "Time:   $(date)"
echo ""

# Step 1: Copy deploy files to remote
echo "[1/5] Syncing deploy files to remote..."
scp $SSH_OPTS -r \
    "${SCRIPT_DIR}/docker-compose.yml" \
    "${SCRIPT_DIR}/nginx.conf" \
    "${SSH_TARGET}:/opt/ffos/deploy/"

if [[ -f "${SCRIPT_DIR}/settings.oracle.js" ]]; then
    scp $SSH_OPTS \
        "${SCRIPT_DIR}/settings.oracle.js" \
        "${SSH_TARGET}:/opt/ffos/deploy/"
fi

echo "Files synced."

# Step 2: Pull new image on remote
echo ""
echo "[2/5] Pulling Docker image on remote..."
ssh $SSH_OPTS $SSH_TARGET "docker pull ${IMAGE}"
echo "Image pulled."

# Step 3: Update docker-compose with specific tag
echo ""
echo "[3/5] Updating image tag in docker-compose..."
ssh $SSH_OPTS $SSH_TARGET \
    "cd /opt/ffos/deploy && sed -i 's|ghcr.io/3579828593/focus-fitness-os-backend:.*|${IMAGE}|' docker-compose.yml"
echo "Tag updated to ${IMAGE_TAG}."

# Step 4: Restart services
echo ""
echo "[4/5] Restarting services..."
ssh $SSH_OPTS $SSH_TARGET \
    "cd /opt/ffos/deploy && docker compose down && docker compose up -d"
echo "Services restarted."

# Step 5: Health check
echo ""
echo "[5/5] Running health check..."
sleep 10

HEALTH_URL="https://${INSTANCE_PUBLIC_IP}/health"
if command -v curl &> /dev/null; then
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
else
    HTTP_CODE="000"
fi

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Health check PASSED (HTTP 200)"
else
    echo "Health check FAILED (HTTP $HTTP_CODE)"
    echo "Checking remote logs..."
    ssh $SSH_OPTS $SSH_TARGET "cd /opt/ffos/deploy && docker compose logs --tail=20 nodered"
    exit 1
fi

echo ""
echo "=========================================="
echo " Deploy Successful!"
echo "=========================================="
echo "Health:  ${HEALTH_URL}"
echo "API:     https://${INSTANCE_PUBLIC_IP}/api/v1/"
echo "Image:   ${IMAGE}"
echo ""
