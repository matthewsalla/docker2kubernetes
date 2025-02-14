#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "🔄 Nuke and Deploy K3s Cluster"

echo "⚠️ WARNING: This will destroy and redeploy your entire cluster!"
read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Operation cancelled."
    exit 1
fi

echo "🛑 Removing old SSH known_hosts entry for 192.168.14.80..."
sed -i '' '/192.168.14.80/d' ~/.ssh/known_hosts
echo "✅ Done!"

echo "🔥 Destroying existing cluster..."
(cd ../../terraform && terraform destroy --auto-approve)

echo "🚀 Rebuilding the cluster..."
(cd ../../terraform && terraform apply --auto-approve)

for i in {15..1}; do
  echo "⏳ Waiting... $i seconds left"
  sleep 1
done

echo "Done!"

echo "🛑 Import K3s KUBECONFIG..."
rm ~/.kube/atlasmalt_config
ssh -o StrictHostKeyChecking=no ubuntu@192.168.14.80 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/atlasmalt_config
sed -i '' 's/127.0.0.1/192.168.14.80/g' ~/.kube/atlasmalt_config
echo "✅ Done!"

echo "🎉 K3s Cluster is deployed!"

bash main.sh
