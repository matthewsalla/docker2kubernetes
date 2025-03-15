#!/bin/bash
set -e  # Exit on error

# Determine the script's directory and source config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Define paths to manifests
LONGHORN_APP_PATH="$APPS_PATH/longhorn"

echo "Deploying Longhorn..."
kubectl create namespace longhorn-system || true

echo "Importing Longhorn auth key"
kubectl apply -f "$SECRETS_PATH/longhorn-auth-sealed-secret.yaml"
echo "Longhorn Auth Key Imported Successfully!"

echo "Importing MinIO Credentials"
kubectl apply -f "$SECRETS_PATH/minio-credentials-sealed-secret.yaml"
echo "MinIO Credentials Imported Successfully!"

echo "⌛ Waiting for at least one worker node with label longhorn-true to be Ready..."
until kubectl get nodes -l longhorn-true -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do
  echo "No Ready node found with label 'longhorn-true'. Retrying in 5s..."
  sleep 5
done

echo "✅ Found a Ready worker node labeled 'longhorn-true'. Proceeding with Longhorn install..."

helm dependency update "$HELM_PATH/charts/longhorn"
helm upgrade --install longhorn "$HELM_PATH/charts/longhorn" \
  --namespace longhorn-system \
  --values "$HELM_PATH/values/longhorn-values.yaml"

# Update local-path to not be default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "Waiting for Longhorn to be fully available..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n longhorn-system

echo "Applying patch to disable scheduling on the control-plane node..."
kubectl apply -f "$LONGHORN_APP_PATH/disable-longhorn-scheduling.yaml"

echo "Applying backup target settings..."
kubectl apply -f "$LONGHORN_APP_PATH/longhorn-settings.yaml"

echo "Patching nodes with Longhorn tag..."
kubectl get nodes -l longhorn-true -o name | while read node; do
  echo "Patching $node..."
  kubectl patch "$node" --type=merge -p '{"metadata": {"annotations": {"longhorn.io/node-tags": "[\"longhorn-true\"]"}}}'
done

for node in $(kubectl get nodes -l longhorn-true -o name | awk -F'/' '{print $2}'); do
  echo "Tagging Longhorn node: $node..."

  for attempt in {1..25}; do
    # Check if the Longhorn node is ready by querying its Ready condition
    node_ready=$(kubectl get -n longhorn-system nodes.longhorn.io "$node" -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}")
    
    if [ "$node_ready" != "True" ]; then
      echo "⏳ Node $node is not ready (Ready status: $node_ready). Retrying in 5 seconds (attempt $attempt/10)..."
      sleep 5
      continue
    fi

    # If node is ready, attempt to patch the node with the Longhorn tag
    if kubectl patch -n longhorn-system nodes.longhorn.io "$node" \
      --type=merge \
      -p '{"spec": {"tags": ["longhorn-true"]}}'; then
      echo "✔️  Tagged $node successfully."
      break
    else
      echo "⏳ Patch for node $node failed. Retrying in 5 seconds (attempt $attempt/10)..."
      sleep 5
    fi
  done
done

echo "Longhorn node tags applied."

echo "✅ Longhorn deployment completed successfully!"

echo "🎉 Longhorn deployed!"
