#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Mealie..."

# Create Namespace
kubectl create namespace mealie || true

# Deploy Mealie
helm dependency update "$HELM_PATH/charts/mealie"
helm upgrade --install mealie "$HELM_PATH/charts/mealie" \
  --namespace mealie \
  --values "$HELM_PATH/values/mealie-values.yaml"

echo "✅ Mealie Deployed Successfully!"
