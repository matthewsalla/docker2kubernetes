#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Define paths to manifests
MEALIE_APP_PATH="$APPS_PATH/mealie"

echo "📡 Deploying Mealie..."

# Create Namespace
kubectl create namespace mealie || true

# Deploy Mealie
helm repo add mealie https://jvalskis.github.io/mealie-helm/
helm repo update
helm upgrade --install mealie mealie/mealie \
  --namespace mealie \
  --values "$HELM_PATH/values/mealie-values.yaml"

# Apply TLS Certificates for Mealie
echo "🔐 Deploying Mealie TLS Certificates..."
cat "$CERTS_PATH/mealie-certificate.yaml" | envsubst | kubectl apply -f -
echo "✅ Certificates Deployed!"

# Apply Ingress Routes for Mealie
echo "🔐 Deploying IngressRoutes..."
kubectl apply -f "$MEALIE_APP_PATH/mealie-ingressroute.yaml"
echo "✅ IngressRoutes Deployed!"

echo "✅ Mealie Deployed Successfully!"
