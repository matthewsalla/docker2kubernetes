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
# kubectl apply -f "$TRILIUM_APP_PATH/trilium-restored.yaml"
kubectl apply -f "$TRILIUM_APP_PATH/trilium-restored-pv.yaml"
kubectl apply -f "$TRILIUM_APP_PATH/trilium-restored-pvc.yaml"
echo "✅ Persistent Data Volume Restored!"

# Deploy Trilium
helm upgrade --install trilium "$HELM_PATH/charts/trilium" \
  --namespace trilium \
  --values "$HELM_PATH/values/trilium-values.yaml"

# Apply TLS Certificates for Trilium
echo "🔐 Deploying Trilium TLS Certificates..."
cat "$CERTS_PATH/trilium-certificate.yaml" | envsubst | kubectl apply -f -
echo "✅ Certificates Deployed!"

# Apply Ingress Routes for Trilium
echo "🔐 Deploying IngressRoutes..."
kubectl apply -f "$TRILIUM_APP_PATH/trilium-ingressroute.yaml"
echo "✅ IngressRoutes Deployed!"

echo "✅ Trilium Deployed Successfully!"
