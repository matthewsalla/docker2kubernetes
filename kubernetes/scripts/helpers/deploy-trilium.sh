#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Trilium..."

# Create Namespace
kubectl create namespace trilium || true

# Restore Persistent Volume from backup for Trilium
echo "🔐 Restoring Data Volume..."
./longhorn-automation.sh restore trilium
echo "✅ Persistent Data Volume Restored!"

# Deploy Trilium
helm dependency update "$HELM_PATH/charts/trilium"
helm upgrade --install trilium "$HELM_PATH/charts/trilium" \
  --namespace trilium \
  --values "$HELM_PATH/values/trilium-values.yaml" \
  --values "$HELM_PATH/values/trilium-restored-volume.yaml"

echo "✅ Trilium Deployed Successfully!"
