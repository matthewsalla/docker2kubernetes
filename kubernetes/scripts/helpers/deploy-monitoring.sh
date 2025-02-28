#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying Monitoring Stack..."

# Create Namespace
kubectl create namespace monitoring || true

echo "🔑 Import Grafana Secrets..."
kubectl apply -f "$SECRETS_PATH/grafana-admin-credentials-sealed-secret.yaml"

# Deploy Prometheus
helm dependency update "$HELM_PATH/charts/monitoring/prometheus"
helm upgrade --install prometheus "$HELM_PATH/charts/monitoring/prometheus" \
    --namespace monitoring \
    --values "$HELM_PATH/values/prometheus-values.yaml"

# Deploy Grafana
helm dependency update "$HELM_PATH/charts/monitoring/grafana"
helm upgrade --install grafana "$HELM_PATH/charts/monitoring/grafana" \
    --namespace monitoring \
    --values "$HELM_PATH/values/grafana-values.yaml"

echo "✅ Monitoring Stack Deployed Successfully!"
