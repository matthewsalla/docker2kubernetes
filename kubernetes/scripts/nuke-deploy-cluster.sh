#!/bin/bash
set -euo pipefail

# Load sensitive configuration from .env
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

# Check for required commands
for cmd in jq hcl2json; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed. Please install $cmd (e.g., 'brew install $cmd' on macOS)."
    exit 1
  fi
done

echo "All required commands (jq and hcl2json) are installed."
TFVARS_FILE="../../terraform/terraform.tfvars"
TFVARS_JSON=$(hcl2json "$TFVARS_FILE")
CONTROL_PLANE_IP=$(echo "$TFVARS_JSON" | jq -r '.k3s_nodes["atlasmalt-control-plane"].ip_address')

if [[ -z "$CONTROL_PLANE_IP" || "$CONTROL_PLANE_IP" == "null" ]]; then
  echo "Error: Control plane IP not found in $TFVARS_FILE."
  exit 1
fi

DEPLOYMENT_MODE=${1:-staging}
# Check for "staging" argument
if [[ "$1" == "staging" ]]; then
    CERT_ISSUER="letsencrypt-staging"
    echo "⚠️  Using Let's Encrypt Staging Mode!"
else
    CERT_ISSUER="letsencrypt-prod"
    echo "🚀  Using Let's Encrypt Production Mode!"
fi

# Pass DEPLOYMENT_MODE and CERT_ISSUER to other scripts
export DEPLOYMENT_MODE
export CERT_ISSUER

echo "🔄 Nuke and Deploy K3s Cluster"

echo "⚠️ WARNING: This will destroy and redeploy your entire cluster!"
read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Operation cancelled."
    exit 1
fi

echo "⚠️ WARNING: Would you like to first create a backup of the persistent volumes?"
read -p "Create Backups? (yes/no): " confirm
if [[ "$confirm" = "yes" ]]; then
    echo "🚀 Backing up volumes on the cluster..."
    ./longhorn-automation.sh backup trilium
    ./longhorn-automation.sh backup grafana
    ./longhorn-automation.sh backup mealie
    echo "🚀 Volumes backed up"
fi

echo "🔥 Destroying existing cluster..."
(cd ../../terraform && terraform destroy --auto-approve)

echo "🚀 Rebuilding the cluster..."
(cd ../../terraform && terraform apply --auto-approve)

for i in {25..1}; do
  echo "⏳ Waiting... $i seconds left"
  sleep 1
done

echo "Done!"

echo "Control plane IP: $CONTROL_PLANE_IP"
echo "🛑 Import K3s KUBECONFIG..."

if [ -f "$TF_KUBECONFIG" ]; then
  rm "$TF_KUBECONFIG"
fi

ssh -o StrictHostKeyChecking=no ubuntu@"$CONTROL_PLANE_IP" "sudo cat /etc/rancher/k3s/k3s.yaml" > "$TF_KUBECONFIG"
sed -i '' "s/127.0.0.1/$CONTROL_PLANE_IP/g" "$TF_KUBECONFIG"
echo "✅ Done!"

echo "🎉 K3s Cluster is deployed!"

bash main.sh
