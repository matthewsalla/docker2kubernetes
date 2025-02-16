#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "Deploying Longhorn..."
kubectl create namespace longhorn-system || true

echo "Importing Longhorn auth key"
kubectl apply -f "$SECRETS_PATH/longhorn-auth-sealed-secret.yaml"
echo "Longhorn Auth Key Imported Successfully!"

echo "Importing Longhorn middlewares auth"
kubectl apply -f "$MIDDLEWARES_PATH/longhorn-auth-middleware.yaml"
echo "Longhorn Middlewares Auth Imported Successfully!"

helm repo add longhorn https://charts.longhorn.io
helm repo update

helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values "$HELM_PATH/values/longhorn-values.yaml"

# Apply the Longhorn TLS Certificate
echo "🔐 Deploying longhorn Certificate..."
kubectl apply -f "$CERTS_PATH/longhorn-certificate.yaml"
kubectl apply -f "$APPS_PATH/longhorn/longhorn-ingressroute.yaml"
echo "✅ Longhorn deployment completed successfully!"

echo "🎉 Longhorn deployed!"
