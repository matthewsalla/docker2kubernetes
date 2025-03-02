#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Define paths to manifests
LONGHORN_APP_PATH="$APPS_PATH/longhorn"

echo "Deploying Longhorn..."
kubectl create namespace longhorn-system || true

echo "Importing Longhorn auth key"
kubectl apply -f "$SECRETS_PATH/longhorn-auth-sealed-secret.yaml"
echo "Longhorn Auth Key Imported Successfully!"

echo "Importing MinIO Credentials"
kubectl apply -f "$SECRETS_PATH/minio-credentials-sealed-secret.yaml"
echo "MinIO Credentials Imported Successfully!"

helm dependency update "$HELM_PATH/charts/longhorn"
helm upgrade --install longhorn "$HELM_PATH/charts/longhorn" \
  --namespace longhorn-system \
  --values "$HELM_PATH/values/longhorn-values.yaml"

# Update local-path to not be default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "Waiting for Longhorn to be fully available..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n longhorn-system

echo "Applying patch to disable scheduling on the control-plane node..."
kubectl apply -f "$LONGHORN_APP_PATH/disable-longhorn-scheduling.yaml"

echo "Applying backup target settings..."
kubectl apply -f "$LONGHORN_APP_PATH/longhorn-settings.yaml"

echo "✅ Longhorn deployment completed successfully!"

echo "🎉 Longhorn deployed!"
