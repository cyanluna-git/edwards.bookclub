#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
SERVER_HOST="10.82.37.79"
SERVER_USER="geraldpark"
APP_DIR="/home/geraldpark/edwards-bookclub"
IMAGE_NAME="edwards-bookclub:prod"
CONTAINER_NAME="bookclub-web"
STORAGE_MOUNT="/home/geraldpark/edwards-bookclub/storage:/rails/storage"

# Load secrets from local .env (never committed to git)
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "${LOCAL_DIR}/.env" ]; then
  echo "ERROR: .env file not found at ${LOCAL_DIR}/.env"
  echo "Create it with ENTRA_TENANT_ID, ENTRA_CLIENT_ID, ENTRA_CLIENT_SECRET"
  exit 1
fi
source "${LOCAL_DIR}/.env"

# Read server password from server.md
SERVER_PW=$(grep "^PW=" "${LOCAL_DIR}/server.md" | cut -d= -f2)

# Existing env vars (from current container)
RAILS_MASTER_KEY="504dd413693ea9fb674a0a81c456ca14"
SECRET_KEY_BASE="6ca4fb90b10bda52a68a21f01b404134cb079fd8eb1b0b3ce353cca028fcb51effe3612f3818c8a8b39ced337edc6defd3729648a63b792c44ac006dd6825b2e"

run_remote() {
  sshpass -p "${SERVER_PW}" ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "${SERVER_USER}@${SERVER_HOST}" "$1"
}

echo "═══════════════════════════════════════════"
echo "  Edwards Bookclub — Production Deploy"
echo "═══════════════════════════════════════════"

# ── Step 1: Sync code to server ────────────────────────────────
echo ""
echo "▶ Step 1/5: Syncing code to server via rsync..."
sshpass -p "${SERVER_PW}" rsync -az --delete \
  --exclude='.git' \
  --exclude='storage/' \
  --exclude='tmp/' \
  --exclude='log/' \
  --exclude='.env' \
  --exclude='node_modules/' \
  --exclude='vendor/bundle/' \
  -e "ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no" \
  "${LOCAL_DIR}/" "${SERVER_USER}@${SERVER_HOST}:${APP_DIR}/"
echo "  ✓ Code synced"

# ── Step 2: Build Docker image ─────────────────────────────────
echo ""
echo "▶ Step 2/5: Building Docker image (this may take a few minutes)..."
run_remote "cd ${APP_DIR} && docker build -t ${IMAGE_NAME} ."
echo "  ✓ Image built"

# ── Step 3: Stop old container ─────────────────────────────────
echo ""
echo "▶ Step 3/5: Stopping old container..."
run_remote "docker stop ${CONTAINER_NAME} 2>/dev/null || true && docker rm ${CONTAINER_NAME} 2>/dev/null || true"
echo "  ✓ Old container removed"

# ── Step 4: Start new container ────────────────────────────────
echo ""
echo "▶ Step 4/5: Starting new container with SSO..."
run_remote "docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  -v ${STORAGE_MOUNT} \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=${RAILS_MASTER_KEY} \
  -e SECRET_KEY_BASE=${SECRET_KEY_BASE} \
  -e ALADIN_TTB_KEY=${ALADIN_TTB_KEY:-} \
  -e RAILS_LOG_TO_STDOUT=true \
  -e RAILS_SERVE_STATIC_FILES=true \
  -e BOOKCLUB_SSO_ENABLED=true \
  -e BOOKCLUB_SSO_AUTO_REDIRECT=false \
  -e ENTRA_TENANT_ID=${ENTRA_TENANT_ID} \
  -e ENTRA_CLIENT_ID=${ENTRA_CLIENT_ID} \
  -e 'ENTRA_CLIENT_SECRET=${ENTRA_CLIENT_SECRET}' \
  ${IMAGE_NAME}"
echo "  ✓ Container started"

# ── Step 5: Verify ─────────────────────────────────────────────
echo ""
echo "▶ Step 5/5: Verifying..."
sleep 5
run_remote "docker ps --filter name=${CONTAINER_NAME} --format '{{.Status}}'"
run_remote "docker exec ${CONTAINER_NAME} env | grep ENTRA | sed 's/=.*/=***/' || true"
echo ""
echo "═══════════════════════════════════════════"
echo "  Deploy complete!"
echo "  https://bookclub.10.82.37.79.sslip.io"
echo "═══════════════════════════════════════════"
