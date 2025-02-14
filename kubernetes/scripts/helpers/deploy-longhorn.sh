#!/bin/bash
set -e  # Exit on error

echo "Deploying Longhorn..."
kubectl create namespace longhorn-system || true

helm repo add longhorn https://charts.longhorn.io
helm repo update

helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values ../helm/values/longhorn-values.yaml

echo "🎉 Longhorn deployed!"

# kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


# # Wait for the Sealed Secret Key to be created
# echo "⏳ Waiting for sealed secret key to be created..."
# SECRETS_KEY=""
# for i in {1..100}; do
#   kubectl get secrets -n kube-system > /dev/null 2>&1  # Force refresh

#   SECRETS_KEY=$(kubectl get secret -n kube-system | grep sealed-secrets-key | awk '{print $1}' || true)

#   if [[ -n "$SECRETS_KEY" ]]; then
#     echo "✅ Sealed secret key detected: $SECRETS_KEY"
#     break
#   fi

#   echo "🔄 Still waiting for secret... $((100-i)) seconds left"
#   sleep 1
# done

# if [[ -z "$SECRETS_KEY" ]]; then
#   echo "❌ ERROR: Sealed secret key not found after 30 seconds!"
#   exit 1
# fi
