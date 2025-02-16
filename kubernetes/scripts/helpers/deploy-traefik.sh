#!/bin/bash
set -e  # Exit on error

echo "🚀 Deploying Traefik"

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  -f ../helm/values/traefik-values.yaml \
  --set certIssuer=$CERT_ISSUER

echo "✅ Traefik deployed using $CERT_ISSUER!"

echo "Importing CloudFlare API Key"
kubectl apply -f ../secrets/traefik-cloudflare-api-credentials-sealed-secret.yaml
echo "CloudFlare API Key Imported Successfully!"

echo "Adding Traefik Middleware"
kubectl apply -f ../apps/traefik/hsts-middleware.yaml
echo "Done deploying Traefik Middleware!"

echo "Restarting Traefik now..."
kubectl rollout restart deployment traefik -n traefik
echo "Traefik has been restarted!"

for i in {15..1}; do
  echo "⏳ Waiting... $i seconds left"
  sleep 1
done

echo "Done!"