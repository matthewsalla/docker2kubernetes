#!/bin/bash

# Delete current sealed secret
echo "❌ Delete sealed secret"
kubectl delete secret -n kube-system $(kubectl get secret -n kube-system | grep sealed-secrets-key | awk '{print $1}')
echo "✅ Completed!"

# Configure Bitwarden CLI to use self-hosted server
bw config server https://bitwarden.galacticrailways.com

# Login to Bitwarden
echo "🔑 Logging into Bitwarden..."
export BW_SESSION=$(bw login --raw)

if [ -z "$BW_SESSION" ]; then
    echo "❌ Failed to log in to Bitwarden."
    exit 1
fi

echo "🔍 Retrieving Sealed Secrets private key..."
SEALED_SECRET_KEY=$(bw get item "Atlas Malt K3s Sealed Secrets Key" --session "$BW_SESSION" | jq -r '.notes')

if [ -z "$SEALED_SECRET_KEY" ]; then
    echo "❌ Could not retrieve the Sealed Secrets private key from Bitwarden."
    exit 1
fi

# Apply the key to Kubernetes
echo "⚙️ Importing Sealed Secrets private key into the cluster..."
echo "$SEALED_SECRET_KEY" | kubectl create --save-config -f - 

echo "✅ Sealed Secrets private key restored successfully!"

# Logout from Bitwarden
bw logout
unset BW_SESSION

# Restart sealed-secrets to load the new key
echo "🔄 Restarting Sealed Secrets deployment"
kubectl rollout restart deployment sealed-secrets -n kube-system
echo "✅ Sealed Secrets restarted!"
