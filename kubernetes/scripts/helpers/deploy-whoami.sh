#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "🚀 Deploying Whoami..."

echo "📂 Creating demo namespace..."
kubectl create namespace demo || true

# Define paths to manifests
WHOAMI_APP_PATH="$APPS_PATH/whoami"

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
cat "$CERTS_PATH/whoami-certificate.yaml" | envsubst | kubectl apply -f -

echo "✅ Whoami deployment completed successfully!"
