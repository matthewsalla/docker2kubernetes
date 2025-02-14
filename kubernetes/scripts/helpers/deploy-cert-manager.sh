#!/bin/bash
set -e  # Exit on error

echo "Deploying Cert Manager"
# kubectl create namespace cert-manager || true

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  -f ../helm/values/cert-manager-values.yaml

echo "Cert Manager deployed!"

echo "🔑 Import CloudFlare api key"
kubectl apply -f ../secrets/cert-manager-cloudflare-api-credentials-sealed-secret.yaml
echo "🎯 Key successfully imported!"

echo "⚙️ Deploy Cluster Issuer"
kubectl apply -f ../cluster-issuers/cluster-issuer.yaml
echo "🎉 Cluster Issuer deployed successfully!"
