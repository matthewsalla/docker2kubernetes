#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/config.sh"

echo "🔑 SECRETS_PATH: $SECRETS_PATH"
echo "📜 CERTS_PATH: $CERTS_PATH"
echo "📦 APPS_PATH: $APPS_PATH"
echo "🛠  MIDDLEWARES_PATH: $MIDDLEWARES_PATH"
echo "📂 HELM_PATH: $HELM_PATH"

echo "🚀 Starting Kubernetes Deployment..."

# Step 1: Deploy Sealed Secrets
bash helpers/deploy-sealed-secrets.sh

# Step 2: Restore Sealed Secrets Key (if available)
bash helpers/restore-sealed-secrets.sh

# Step 3: Deploy Cert-Manager
bash helpers/deploy-cert-manager.sh

# Step 4: Deploy Traefik v3
bash helpers/deploy-traefik.sh

# Step 5: Deploy a test app (Whoami)
bash helpers/deploy-whoami.sh

# Step 6: Deploy Longhorn
bash helpers/deploy-longhorn.sh

# Step 7: Deploy Monitoring Tools
bash helpers/deploy-monitoring.sh

echo "✅ Deployment Completed Successfully!"
