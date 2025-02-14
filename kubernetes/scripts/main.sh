#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "🚀 Starting Kubernetes Deployment..."

# Step 1: Deploy Sealed Secrets
bash helpers/deploy-sealed-secrets.sh

# Step 2: Restore Sealed Secrets Key (if available)
bash helpers/restore-sealed-secrets.sh

# Step 3: Deploy Cert-Manager
bash helpers/deploy-cert-manager.sh

# Step 4: Deploy Traefik v3
bash helpers/deploy-traefik.sh

# Step 5: Deploy a test app (Whoami)
bash helpers/deploy-whoami.sh

echo "✅ Deployment Completed Successfully!"
