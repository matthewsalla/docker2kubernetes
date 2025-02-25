#!/bin/bash
set -e

# Load sensitive configuration from .env
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi


# Configuration variables
VOLUME_NAME="trilium-pv"
BACKUP_MODE="incremental"          # Change to "full" if needed
OUTPUT_FILE="backup_id.txt"

echo "Creating snapshot for volume '${VOLUME_NAME}'..."
# We send an empty JSON body so the API can auto-generate the snapshot name
SNAPSHOT_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST -H "Content-Type: application/json" \
  -d '{}' \
  https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME}?action=snapshotCreate)

echo "Snapshot creation response:"
echo "$SNAPSHOT_RESPONSE"

# Extract the snapshot name (or id) from the response.
# We assume the response includes a field "id" that holds the snapshot's name.
SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESPONSE" | jq -r '.id')

if [ -z "$SNAPSHOT_NAME" ] || [ "$SNAPSHOT_NAME" == "null" ]; then
    echo "Error: Failed to extract snapshot name from response."
    exit 1
fi

echo "Using snapshot name: ${SNAPSHOT_NAME}"

# Allow a few seconds for the snapshot to be registered
sleep 15

echo "Triggering backup for snapshot '${SNAPSHOT_NAME}' with backup mode '${BACKUP_MODE}'..."
BACKUP_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST -H "Content-Type: application/json" \
  -d "{\"name\":\"${SNAPSHOT_NAME}\",\"backupMode\":\"${BACKUP_MODE}\"}" \
  https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME}?action=snapshotBackup)
echo "Initial backup response:"
echo "$BACKUP_RESPONSE"

echo "Waiting for backup to complete..."
for i in {1..30}; do
    CURRENT_RESPONSE=$(curl -u "$LONGHORN_USER:$LONGHORN_PASS" https://${LONGHORN_MANAGER}/v1/volumes/${VOLUME_NAME})
    echo "${CURRENT_RESPONSE}"
    BACKUP_ID=$(echo "$CURRENT_RESPONSE" | jq -r '.backupStatus[] | select(.snapshot=="'"${SNAPSHOT_NAME}"'" and .state=="Completed") | .id')
    if [ -n "$BACKUP_ID" ] && [ "$BACKUP_ID" != "null" ]; then
        echo "Backup completed with ID: $BACKUP_ID"
        echo "$BACKUP_ID" > "$OUTPUT_FILE"
        echo "Backup ID stored in $OUTPUT_FILE"
        exit 0
    fi
    echo "Backup not yet complete. Waiting 10 seconds..."
    sleep 10
done

echo "Error: Backup did not complete in expected time."
exit 1
