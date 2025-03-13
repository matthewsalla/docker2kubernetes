#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "📡 Deploying ArgoCD..."

# Create Namespace
kubectl create namespace argocd || true

# Restore Persistent Volume from backup for ArgoCD
echo "🔐 Restoring Data Volume..."
# ./longhorn-automation.sh restore argocd
echo "✅ Persistent Data Volume Restored!"

# Deploy ArgoCD
# helm repo add argo https://argoproj.github.io/argo-helm
# helm repo update
# helm install argocd argo/argo-cd \
#   --namespace argocd --create-namespace \
#   --values "$HELM_PATH/values/argocd-values.yaml" \

helm dependency update "$HELM_PATH/charts/argocd"
helm upgrade --install argocd "$HELM_PATH/charts/argocd" \
  --namespace argocd \
  --values "$HELM_PATH/values/argocd-values.yaml" \
  # --values "$HELM_PATH/values/argocd-restored-volume.yaml"

echo "✅ ArgoCD Deployed Successfully!"
