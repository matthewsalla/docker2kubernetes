#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Monitoring Stack..."

# Create Namespace
kubectl create namespace monitoring || true

echo "🔑 Import Grafana Secrets..."
kubectl apply -f "$SECRETS_PATH/grafana-admin-credentials-sealed-secret.yaml"

# Deploy Grafana
helm dependency update "$HELM_PATH/charts/monitoring"
helm upgrade --install grafana "$HELM_PATH/charts/monitoring" \
    --namespace monitoring \
    --values "$HELM_PATH/values/grafana-values.yaml"

echo "✅ Monitoring Stack Deployed Successfully!"
