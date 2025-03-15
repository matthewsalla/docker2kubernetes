#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "Deploying Sealed Secrets..."
kubectl create namespace kube-system || true

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  -f "$HELM_PATH/values/sealed-secrets-values.yaml"

echo "🎉 Sealed Secrets deployed!"

# Wait for the Sealed Secret Key to be created
echo "⏳ Waiting for sealed secret key to be created..."
SECRETS_KEY=""
for i in {1..120}; do
  kubectl get secrets -n kube-system > /dev/null 2>&1  # Force refresh

  SECRETS_KEY=$(kubectl get secret -n kube-system | grep sealed-secrets-key | awk '{print $1}' || true)

  if [[ -n "$SECRETS_KEY" ]]; then
    echo "✅ Sealed secret key detected: $SECRETS_KEY"
    break
  fi

  echo "🔄 Still waiting for secret... $((120-i)) seconds left"
  sleep 1
done

if [[ -z "$SECRETS_KEY" ]]; then
  echo "❌ ERROR: Sealed secret key not found after 120 seconds!"
  exit 1
fi
