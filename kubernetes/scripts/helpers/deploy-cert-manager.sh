#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "Deploying Cert Manager"

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  -f "$HELM_PATH/values/cert-manager-values.yaml" \
  --set global.leaderElection.namespace=cert-manager

echo "Cert Manager deployed!"

echo "🔑 Import CloudFlare api key"
kubectl apply -f "$SECRETS_PATH/cert-manager-cloudflare-api-credentials-sealed-secret.yaml"
echo "🎯 Key successfully imported!"

# Deploy correct ClusterIssuer based on DEPLOYMENT_MODE
if [[ "$DEPLOYMENT_MODE" == "staging" ]]; then
    echo "⚠️  Deploying Let's Encrypt Staging ClusterIssuer..."
    kubectl apply -f "$CLUSTERISSUERS_PATH/cluster-issuer-staging.yaml"
else
    echo "🚀 Deploying Let's Encrypt Production ClusterIssuer..."
    kubectl apply -f "$CLUSTERISSUERS_PATH/cluster-issuer-prod.yaml"
fi

echo "🎉 Cluster Issuer deployed successfully!"
