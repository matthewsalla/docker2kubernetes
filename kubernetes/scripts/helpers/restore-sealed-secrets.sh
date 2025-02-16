#!/bin/bash

# Delete current sealed secret
echo "❌ Delete sealed secret"
kubectl delete secret -n kube-system $(kubectl get secret -n kube-system | grep sealed-secrets-key | awk '{print $1}')
echo "✅ Completed!"

#Clear any existing session (critical!)
bw logout || true

# Configure Bitwarden CLI to use self-hosted server
bw config server https://bitwarden.galacticrailways.com

# Load API Credentials from macOS Keychain
export BW_CLIENTID=$(security find-generic-password -a "$USER" -s "Bitwarden_Client_ID" -w)
export BW_CLIENTSECRET=$(security find-generic-password -a "$USER" -s "Bitwarden_Client_Secret" -w)
export BW_PASSWORD=$(security find-generic-password -a "$USER" -s "Bitwarden_Master_Password" -w)

if [ -z "$BW_CLIENTID" ] || [ -z "$BW_CLIENTSECRET" ] || [ -z "$BW_PASSWORD" ]; then
    echo "❌ Bitwarden Password, Client ID or Secret not found in macOS Keychain!"
    exit 1
fi

# Log in to Bitwarden using API Key
bw login --apikey

echo "✅ Login BW Completed!"

# Unlock vault
echo "🔓 Unlocking Bitwarden Vault..."
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
echo "✅ Unlock Vault Completed!"

echo "🔍 Retrieving Sealed Secrets private key..."
SEALED_SECRET_KEY=$(bw get item "K3s Sealed Secrets Private Key" --session "$BW_SESSION" | jq -r '.notes')

if [ -z "$SEALED_SECRET_KEY" ]; then
    echo "❌ Could not retrieve the Sealed Secrets private key from Bitwarden."
    exit 1
fi

# Apply the key to Kubernetes
echo "⚙️ Importing Sealed Secrets private key into the cluster..."
echo "$SEALED_SECRET_KEY" | kubectl create --save-config -f - 

# Logout from Bitwarden
bw logout
export BW_CLIENTID=""
export BW_CLIENTSECRET=""
export BW_PASSWORD=""
export BW_SESSION=""
unset BW_CLIENTID
unset BW_CLIENTSECRET
unset BW_PASSWORD
unset BW_SESSION

echo "✅ Sealed Secrets private key restored successfully!"

# Restart sealed-secrets to load the new key
echo "🔄 Restarting Sealed Secrets deployment"
kubectl rollout restart deployment sealed-secrets -n kube-system
echo "✅ Sealed Secrets restarted!"
