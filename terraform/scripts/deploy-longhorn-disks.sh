#!/usr/bin/env bash
# deploy-longhorn-disks.sh

# Load environment variables from .env (which you have configured)
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

# Convert comma-separated values to arrays
IFS=',' read -r -a POOL_NAMES_ARRAY <<< "$POOL_NAMES"
IFS=',' read -r -a POOL_PATHS_ARRAY <<< "$POOL_PATHS"
IFS=',' read -r -a DISK_NAMES_ARRAY <<< "$DISK_NAMES"

# Function to execute remote commands via SSH
execute_remote() {
  ssh -t "$SSH_USER@$SSH_HOST" "export LIBVIRT_DEFAULT_URI=qemu:///system; $1"
}

echo "🚀 Setting up Longhorn storage on cloudstation..."

# Step 1: Create storage pools (unchanged)
for ((i=0; i<${#POOL_NAMES_ARRAY[@]}; i++)); do
  pool_name="${POOL_NAMES_ARRAY[$i]}"
  pool_path="${POOL_PATHS_ARRAY[$i]}"

  execute_remote "
    mkdir -p \"$pool_path\" && chown libvirt-qemu:kvm \"$pool_path\"
    if ! virsh pool-info \"$pool_name\" >/dev/null 2>&1; then
      virsh pool-define-as \"$pool_name\" --type dir --target \"$pool_path\"
      virsh pool-autostart \"$pool_name\"
      virsh pool-start \"$pool_name\"
      echo \"✅ Storage pool $pool_name created at $pool_path\"
    else
      echo \"✅ Storage pool $pool_name already exists\"
    fi
  "
done

# Step 2: Create QCOW2 disks using a heredoc for correct variable substitution
for ((i=0; i<${#POOL_NAMES_ARRAY[@]}; i++)); do
  pool_name="${POOL_NAMES_ARRAY[$i]}"
  pool_path="${POOL_PATHS_ARRAY[$i]}"
  disk_name="${DISK_NAMES_ARRAY[$i]}"

  cmd=$(cat <<EOF
if [ ! -f "$pool_path/$disk_name" ]; then
  qemu-img create -f qcow2 "$pool_path/$disk_name" 1024G
  echo "✅ Created 1TB disk: $pool_path/$disk_name"
  virsh pool-refresh "$pool_name"
else
  echo "✅ Disk $disk_name already exists"
fi
EOF
)
  execute_remote "$cmd"
done

echo "🎉 All Longhorn disks and storage pools have been successfully set up!"
