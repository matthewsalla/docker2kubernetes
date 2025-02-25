#!/bin/bash
set -euo pipefail

# Usage: ./longhorn_automation.sh {backup|restore}
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 {backup|restore}"
  exit 1
fi

MODE="$1"

# Load sensitive configuration from .env
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

# Configuration variables – adjust as needed
# Ensure LONGHORN_MANAGER is reachable (e.g., via port-forwarding if necessary)
# LONGHORN_MANAGER="localhost:9500"
# The volume name you want to backup/restore
VOLUME_NAME="trilium-pv"
# The backup mode – "incremental" or "full"
BACKUP_MODE="incremental"
# File to store the backup ID
BACKUP_ID_FILE="backup_id.txt"
# The original volume ID that was backed up (this value comes from the volume that was originally backed up)
ORIGINAL_VOLUME_ID="trilium-pv"
# The output file for the restore manifest
RESTORE_OUTPUT="trilium-restored.yaml"

if [ "$MODE" == "backup" ]; then
  echo "=== Starting Backup Process for volume '$VOLUME_NAME' ==="

  # Step 1: Create a snapshot
  echo "Creating snapshot for volume '$VOLUME_NAME'..."
  SNAPSHOT_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST -H "Content-Type: application/json" \
    -d '{}' \
    https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME}?action=snapshotCreate)
  echo "Snapshot creation response:"
  echo "$SNAPSHOT_RESPONSE"

  # Extract the snapshot name (assumed to be in the "id" field)
  SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESPONSE" | jq -r '.id')
  if [ -z "$SNAPSHOT_NAME" ] || [ "$SNAPSHOT_NAME" = "null" ]; then
    echo "Error: Failed to extract snapshot name from response."
    exit 1
  fi
  echo "Using snapshot name: $SNAPSHOT_NAME"

  # Wait a few seconds for the snapshot to be registered
  sleep 5

  # Step 2: Trigger a backup for that snapshot
  echo "Triggering backup for snapshot '$SNAPSHOT_NAME' with mode '$BACKUP_MODE'..."
  BACKUP_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${SNAPSHOT_NAME}\",\"backupMode\":\"${BACKUP_MODE}\"}" \
    https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME}?action=snapshotBackup)
  echo "Initial backup response:"
  echo "$BACKUP_RESPONSE"

  # Step 3: Poll for backup completion and extract the backup ID
  echo "Waiting for backup to complete..."
  for i in {1..30}; do
      CURRENT_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME})
      BACKUP_ID=$(echo "$CURRENT_RESPONSE" | jq -r '.backupStatus[] | select(.snapshot=="'"${SNAPSHOT_NAME}"'" and .state=="Completed") | .id')
      if [ -n "$BACKUP_ID" ] && [ "$BACKUP_ID" != "null" ]; then
          echo "Backup completed with ID: $BACKUP_ID"
          echo "$BACKUP_ID" > "$BACKUP_ID_FILE"
          echo "Backup ID stored in $BACKUP_ID_FILE"
          exit 0
      fi
      echo "Backup not yet complete. Waiting 10 seconds... ($i/30)"
      sleep 10
  done

  echo "Error: Backup did not complete in expected time."
  exit 1

elif [ "$MODE" == "restore" ]; then
  echo "=== Starting Restore Process ==="
  
  # Step 4: Read the backup ID from file
  if [ ! -f "$BACKUP_ID_FILE" ]; then
    echo "Error: Backup ID file '$BACKUP_ID_FILE' does not exist. Run backup mode first."
    exit 1
  fi
  BACKUP_ID=$(cat "$BACKUP_ID_FILE")
  if [ -z "$BACKUP_ID" ]; then
    echo "Error: Backup ID file is empty."
    exit 1
  fi
  echo "Using backup ID: $BACKUP_ID"

  # Step 5: Generate the restore manifest (Volume CR)
  cat > "$RESTORE_OUTPUT" <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: trilium-pv
  namespace: longhorn-system
spec:
  numberOfReplicas: 3
  frontend: blockdev
  backupTargetName: default
  fromBackup: "s3://longhorn-backups@192.168.14.222:9900/longhorn?backup=${BACKUP_ID}&volume=${ORIGINAL_VOLUME_ID}"
EOF

  echo "Restore manifest generated in '$RESTORE_OUTPUT'"
  
  # Step 6: Apply the restore manifest
  echo "Applying restore manifest..."
  kubectl apply -f "$RESTORE_OUTPUT"
  echo "Restore manifest applied."

  exit 0
else
  echo "Invalid mode. Use 'backup' or 'restore'."
  exit 1
fi
