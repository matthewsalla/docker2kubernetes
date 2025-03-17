#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Gitea..."

# Create Namespace
kubectl create namespace gitea || true

echo "Importing Gitea Actions Token"
kubectl apply -f "$SECRETS_PATH/gitea-actions-token-sealed-secret.yaml"
echo "Gitea Actions Token Imported Successfully!"

# Restore Persistent Volume from backup for Gitea
echo "🔐 Restoring Data Volume..."
./longhorn-automation.sh restore gitea
./longhorn-automation.sh restore gitea-actions-docker --wrapper
echo "✅ Persistent Data Volume Restored!"

# Deploy Gitea
helm dependency update "$HELM_PATH/charts/gitea"
helm upgrade --install gitea "$HELM_PATH/charts/gitea" \
  --namespace gitea \
  --values "$HELM_PATH/values/gitea-values.yaml" \
  --values "$HELM_PATH/values/gitea-restored-volume.yaml" \
  --values "$HELM_PATH/values/gitea-actions-docker-restored-volume.yaml"

echo "✅ Gitea Deployed Successfully!"
