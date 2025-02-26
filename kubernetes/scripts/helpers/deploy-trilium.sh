#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Define paths to manifests
TRILIUM_APP_PATH="$APPS_PATH/trilium"

echo "📡 Deploying Trilium..."

# Create Namespace
kubectl create namespace trilium || true

# Restore Persistent Volume from backup for Trilium
echo "🔐 Restoring Data Volume..."
./longhorn-automation.sh restore
echo "✅ Persistent Data Volume Restored!"

# Deploy Trilium
helm upgrade --install trilium "$HELM_PATH/charts/trilium" \
  --namespace trilium \
  --values "$HELM_PATH/values/trilium-values.yaml"

echo "✅ Trilium Deployed Successfully!"
