#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "🚀 Deploying Whoami..."

echo "📂 Creating demo namespace..."
kubectl create namespace demo || true

# Define paths to manifests
WHOAMI_APP_PATH="../apps/whoami"
WHOAMI_CERT_PATH="../certificates"

# Apply the Whoami Deployment
echo "📦 Deploying Whoami Deployment..."
kubectl apply -f "$WHOAMI_APP_PATH/whoami-deployment.yaml"

# Apply the Whoami Service
echo "🔗 Deploying Whoami Service..."
kubectl apply -f "$WHOAMI_APP_PATH/whoami-service.yaml"

# Apply the Whoami IngressRoute
echo "🌐 Deploying Whoami IngressRoute..."
kubectl apply -f "$WHOAMI_APP_PATH/whoami-ingressroute.yaml"

# Apply the Whoami TLS Certificate
echo "🔐 Deploying Whoami Certificate..."
kubectl apply -f "$WHOAMI_CERT_PATH/whoami-certificate.yaml"

echo "✅ Whoami deployment completed successfully!"
