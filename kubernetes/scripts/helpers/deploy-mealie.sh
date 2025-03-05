#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Mealie..."

# Create Namespace
kubectl create namespace mealie || true

# Restore Persistent Volume from backup for Mealie
echo "🔐 Restoring Data Volume..."
./longhorn-automation.sh restore mealie
echo "✅ Persistent Data Volume Restored!"

# Deploy Mealie
helm dependency update "$HELM_PATH/charts/mealie"
helm upgrade --install mealie "$HELM_PATH/charts/mealie" \
  --namespace mealie \
  --values "$HELM_PATH/values/mealie-values.yaml" \
  --values "$HELM_PATH/values/mealie-restored-volume.yaml"

echo "✅ Mealie Deployed Successfully!"
