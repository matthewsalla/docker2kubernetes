#!/bin/bash

# Define common paths for all scripts
export SECRETS_PATH="../secrets"
export CERTS_PATH="../certs"
export CLUSTERISSUERS_PATH="../cluster-issuers"
export APPS_PATH="../apps"
export MIDDLEWARES_PATH="../middlewares"
export HELM_PATH="../helm"

# Default values for environment variables
export CERT_ISSUER=${CERT_ISSUER:-letsencrypt-prod}

echo "🔧 Using ClusterIssuer: $CERT_ISSUER"
