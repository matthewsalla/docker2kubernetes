#!/usr/bin/env bash
# destroy-longhorn-disks.sh

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

echo "⚠️ WARNING: This will destroy your longhorn disks!  I hope you have a backup..."
read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Operation cancelled."
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

echo "🚀 Cleaning Longhorn resources on cloudstation..."

# First: Destroy and undefine pools
for ((i=0; i<${#POOL_NAMES_ARRAY[@]}; i++)); do
  pool_name="${POOL_NAMES_ARRAY[$i]}"
  
  execute_remote "
    if virsh pool-info \"$pool_name\" >/dev/null 2>&1; then
      virsh pool-destroy \"$pool_name\" && echo \"🛑 Stopped $pool_name\"
      virsh pool-undefine \"$pool_name\" && echo \"🗑️ Removed definition for $pool_name\"
    else
      echo \"✅ Pool $pool_name was already removed\"
    fi
  "
done

# Second: Delete physical files
for ((i=0; i<${#POOL_NAMES_ARRAY[@]}; i++)); do
  pool_path="${POOL_PATHS_ARRAY[$i]}"
  disk_name="${DISK_NAMES_ARRAY[$i]}"

  execute_remote "
    # Delete disk file
    if [ -f \"$pool_path/$disk_name\" ]; then
      rm -f \"$pool_path/$disk_name\" && echo \"🗑️ Deleted: $pool_path/$disk_name\"
    else
      echo \"✅ Disk $disk_name was already removed\"
    fi

    # Remove directory
    if [ -d \"$pool_path\" ]; then
      rm -rf \"$pool_path\" && echo \"🗑️ Removed directory $pool_path\"
    else
      echo \"✅ Directory $pool_path was already removed\"
    fi
  "
done

echo "🎉 All Longhorn resources cleaned successfully!"
