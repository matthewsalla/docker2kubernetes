#!/bin/bash
set -e  # Exit on error

echo "Deploying Sealed Secrets..."
kubectl create namespace kube-system || true

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  -f ../helm/values/sealed-secrets-values.yaml

echo "Sealed Secrets deployed!"
