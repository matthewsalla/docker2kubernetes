#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Define paths to manifests
GRAFANA_APP_PATH="$APPS_PATH/grafana"

echo "📡 Deploying Monitoring Stack..."

# Create Namespace
kubectl create namespace monitoring || true

echo "🔑 Import Grafana Secrets..."
kubectl apply -f "$SECRETS_PATH/grafana-admin-credentials-sealed-secret.yaml"

# Deploy Grafana
# helm dependency update "$HELM_PATH/charts/monitoring"
# helm upgrade --install grafana "$HELM_PATH/charts/monitoring" \
#     --namespace monitoring \
#     --values "$HELM_PATH/values/grafana-values.yaml"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values "$HELM_PATH/values/grafana-values.yaml"

# # Apply TLS Certificates for Grafana
echo "🔐 Deploying Grafana TLS Certificates..."
cat "$CERTS_PATH/grafana-certificate.yaml" | envsubst | kubectl apply -f -
echo "✅ Certificates Deployed!"

# # Apply Ingress Routes for Grafana
echo "🔐 Deploying IngressRoutes..."
kubectl apply -f "$GRAFANA_APP_PATH/grafana-ingressroute.yaml"
echo "✅ IngressRoutes Deployed!"

echo "✅ Monitoring Stack Deployed Successfully!"
