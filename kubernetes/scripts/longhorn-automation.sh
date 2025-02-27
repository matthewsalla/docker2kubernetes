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

# Check for required commands
for cmd in jq hcl2json; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed. Please install $cmd (e.g., 'brew install $cmd' on macOS)."
    exit 1
  fi
done

echo "All required commands (jq and hcl2json) are installed."
# The volume name you want to backup/restore
VOLUME_NAME="trilium-pv"
# The backup mode – "incremental" or "full"
BACKUP_MODE="incremental"
# File to store the backup ID
BACKUP_ID_FILE="backup_id.txt"
# The original volume ID that was backed up (this value comes from the volume that was originally backed up)
ORIGINAL_VOLUME_ID="trilium-pv"
# The output file for the restore manifest
RESTORE_OUTPUT="../helm/values/trilium-restored-volume.yaml"

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

  # Wait for backup volume to become available
  for i in {1..30}; do
    BACKUP_VOLUME_ID=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" https://${LONGHORN_MANAGER}/v1/backupvolumes | jq -r '.data[] | select(.volumeName=="trilium-pv") | .id')
    if [ -n "$BACKUP_VOLUME_ID" ] && [ "$BACKUP_VOLUME_ID" != "null" ]; then
      echo "Backup volume found: $BACKUP_VOLUME_ID"
      break
    fi
    echo "Backup volume not yet available, waiting 10 seconds... ($i/30)"
    sleep 10
  done

  echo "Backup Volume ID: $BACKUP_VOLUME_ID"
  
  # Step 5: Wait for the backup target to be healthy and backups available
  echo "Waiting for backup ID '$BACKUP_ID' to reach Completed state..."
  for i in {1..30}; do
      CURRENT_RESPONSE=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST "https://${LONGHORN_MANAGER}/v1/backupvolumes/${BACKUP_VOLUME_ID}?action=backupList")
      
      # Check if the response appears to be valid JSON (starts with '{')
      if [[ "$CURRENT_RESPONSE" != \{* ]]; then
          echo "Received non-JSON response: $CURRENT_RESPONSE. Retrying... ($i/30)"
          sleep 10
          continue
      fi

      echo "Current backupvolumes response:"
      echo "$CURRENT_RESPONSE"

      # Use jq to extract the state for our backup ID
      CURRENT_STATE=$(echo "$CURRENT_RESPONSE" | jq -r --arg bid "$BACKUP_ID" '.data[] | select(.id==$bid) | .state')
      echo "Current backup state: ${CURRENT_STATE}"
      
      if [ "$CURRENT_STATE" == "Completed" ]; then
          echo "Backup $BACKUP_ID is completed."
          break
      fi
      echo "Backup $BACKUP_ID is not yet complete (state: $CURRENT_STATE). Waiting 10 seconds... ($i/30)"
      sleep 10
  done

  if [ "$CURRENT_STATE" != "Completed" ]; then
      echo "Error: Backup did not reach 'Completed' state within expected time."
      exit 1
  fi

  echo "Backup is now ready for restore."

  cat > "$RESTORE_OUTPUT" <<EOF
persistence:
  fromBackup: "s3://longhorn-backups@192.168.14.222:9900/longhorn?backup=${BACKUP_ID}&volume=${ORIGINAL_VOLUME_ID}"
EOF

  echo "Restore manifest generated in '$RESTORE_OUTPUT'"

  exit 0
else
  echo "Invalid mode. Use 'backup' or 'restore'."
  exit 1
fi
