#!/bin/bash
set -euo pipefail

########################################
# Usage: ./longhorn-automation.sh {backup|restore} <app_id> [ORIGINAL_VOLUME_ID] [--wrapper]
# Example:
#   ./longhorn-automation.sh restore trilium my-volume-id --wrapper
########################################

usage() {
  echo "Usage: $0 {backup|restore} <app_id> [ORIGINAL_VOLUME_ID] [--wrapper]"
  exit 1
}

if [ "$#" -lt 2 ]; then
  usage
fi

MODE="$1"
APP_ID="$2"
shift 2

VOLUME_NAME="${APP_ID}-pv"

# Check if the next argument is provided and is not the --wrapper flag.
if [ "$#" -gt 0 ] && [ "$1" != "--wrapper" ]; then
  ORIGINAL_VOLUME_ID="$1"
  shift
fi

# Default ORIGINAL_VOLUME_ID if not provided.
if [ -z "$ORIGINAL_VOLUME_ID" ]; then
  ORIGINAL_VOLUME_ID="$VOLUME_NAME"
fi

WRAPPER_MODE=false
if [ "$#" -gt 0 ] && [ "$1" == "--wrapper" ]; then
  WRAPPER_MODE=true
fi

########################################
# Load environment
########################################
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Exiting."
  exit 1
fi

########################################
# Verify required commands
########################################
for cmd in jq hcl2json; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed. Please install $cmd."
    exit 1
  fi
done
echo "All required commands (jq, hcl2json) are installed."

########################################
# Common variables
########################################
BACKUP_MODE="incremental"
BACKUP_ID_FILE="backup_id_${APP_ID}.txt"
RESTORE_OUTPUT="../helm/values/${APP_ID}-restored-volume.yaml"
LONGHORN_API="https://${LONGHORN_MANAGER}/v1"

########################################
# Helper: poll_for_completed_backup
# Polls the .backupStatus[] for (snapshot==snapshot_name && state=="Completed")
# Prints only the backup ID to stdout if found; logs go to stderr.
########################################
poll_for_completed_backup() {
  local volume_name="$1"
  local snapshot_name="$2"
  local max_attempts=30
  local wait_seconds=10

  for i in $(seq 1 "$max_attempts"); do
    local vol_json
    vol_json=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" "$LONGHORN_API/volumes/${volume_name}")
    local backup_id
    backup_id=$(echo "$vol_json" | jq -r ".backupStatus[] | select(.snapshot==\"${snapshot_name}\" and .state==\"Completed\") | .id")

    if [ -n "$backup_id" ] && [ "$backup_id" != "null" ]; then
      echo "$backup_id"  # IMPORTANT: Only echo the ID to stdout
      return 0
    fi

    echo "Backup not yet complete for snapshot '${snapshot_name}'. Waiting ${wait_seconds}s... ($i/$max_attempts)" >&2
    sleep "$wait_seconds"
  done

  return 1
}

########################################
# Helper: wait_for_backup_volume
# Waits for the "backup volume" to appear in /v1/backupvolumes.
# Prints only the backup volume ID to stdout; logs to stderr.
########################################
wait_for_backup_volume() {
  local volume_name="$1"
  local max_attempts=30
  local wait_seconds=10

  for i in $(seq 1 "$max_attempts"); do
    local resp
    resp=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" "$LONGHORN_API/backupvolumes")
    if echo "$resp" | jq -e '.data != null' &>/dev/null; then
      local backup_vol_id
      backup_vol_id=$(echo "$resp" | jq -r --arg vol "$volume_name" '.data[] | select(.volumeName==$vol) | .id')
      if [ -n "$backup_vol_id" ] && [ "$backup_vol_id" != "null" ]; then
        echo "$backup_vol_id"  # Only the ID
        return 0
      fi
    fi
    echo "Backup volumes data not available yet for '${volume_name}'. Waiting ${wait_seconds}s... ($i/$max_attempts)" >&2
    sleep "$wait_seconds"
  done
  return 1
}

########################################
# Helper: wait_for_backup_state_completed
# Uses backupList to ensure a given backupID has .state == "Completed".
# Prints nothing to stdout; logs to stderr.
########################################
wait_for_backup_state_completed() {
  local backup_vol_id="$1"
  local backup_id="$2"
  local max_attempts=30
  local wait_seconds=10

  for i in $(seq 1 "$max_attempts"); do
    local backup_list
    backup_list=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" -X POST \
      "$LONGHORN_API/backupvolumes/${backup_vol_id}?action=backupList")

    if [[ "$backup_list" == \{* ]]; then
      local current_state
      current_state=$(echo "$backup_list" | jq -r --arg bid "$backup_id" '.data[] | select(.id==$bid) | .state')
      echo "Current backup state for '$backup_id': ${current_state}" >&2
      if [ "$current_state" = "Completed" ]; then
        return 0
      fi
      echo "Not yet completed. Waiting ${wait_seconds}s... ($i/$max_attempts)" >&2
    else
      echo "Non-JSON response while listing backups: $backup_list" >&2
      echo "Retrying in $wait_seconds seconds... ($i/$max_attempts)" >&2
    fi
    sleep "$wait_seconds"
  done
  return 1
}

########################################
# do_backup
########################################
do_backup() {
  echo "=== Starting Backup Process for volume '$VOLUME_NAME' ==="
  echo "Creating snapshot..."

  local snap_resp
  snap_resp=$(curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" \
    -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "$LONGHORN_API/volumes/${VOLUME_NAME}?action=snapshotCreate")

  echo "Snapshot creation response:"
  echo "$snap_resp"

  local snapshot_name
  snapshot_name=$(echo "$snap_resp" | jq -r '.id')
  if [ -z "$snapshot_name" ] || [ "$snapshot_name" = "null" ]; then
    echo "Error: Failed to extract snapshot name from response."
    exit 1
  fi
  echo "Using snapshot: $snapshot_name"

  sleep 5

  echo "Triggering backup for '$snapshot_name' (mode: $BACKUP_MODE)..."
  curl -s -u "$LONGHORN_USER:$LONGHORN_PASS" \
    -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${snapshot_name}\",\"backupMode\":\"${BACKUP_MODE}\"}" \
    "$LONGHORN_API/volumes/${VOLUME_NAME}?action=snapshotBackup" >/dev/null || true

  echo "Waiting for backup to complete..."
  local completed_backup_id
  if ! completed_backup_id=$(poll_for_completed_backup "$VOLUME_NAME" "$snapshot_name"); then
    echo "Error: Backup did not complete in time."
    exit 1
  fi

  echo "Backup completed with ID: $completed_backup_id"
  echo "$completed_backup_id" > "$BACKUP_ID_FILE"
  echo "Backup ID stored in $BACKUP_ID_FILE"
}

########################################
# do_restore
########################################
do_restore() {
  echo "=== Starting Restore Process for volume '$ORIGINAL_VOLUME_ID' ==="

  local backup_id="dummy-backup-id"
  if [ -f "$BACKUP_ID_FILE" ] && [ -s "$BACKUP_ID_FILE" ]; then
    backup_id=$(<"$BACKUP_ID_FILE")
    echo "Using backup ID: $backup_id"
  else
    echo "Backup ID file '$BACKUP_ID_FILE' not found or empty. Using dummy-backup-id."
  fi

  if [ "$backup_id" != "dummy-backup-id" ]; then
    echo "Waiting for backup volume to appear..."
    local backup_vol_id
    if ! backup_vol_id=$(wait_for_backup_volume "$ORIGINAL_VOLUME_ID"); then
      echo "Error: Could not find backup volume for $ORIGINAL_VOLUME_ID."
      exit 1
    fi
    echo "Backup Volume ID: $backup_vol_id"

    echo "Waiting for backup '$backup_id' to be Completed..."

    if ! wait_for_backup_state_completed "$backup_vol_id" "$backup_id"; then
      echo "Error: Backup did not reach 'Completed' state in time."
      exit 1
    fi

    echo "Backup is now ready for restore."
  else
    echo "Dummy backup ID used. Skipping verification steps."
  fi

  # Generate the restore manifest
  echo "Generating restore manifest in '$RESTORE_OUTPUT'..."

  if [ "$WRAPPER_MODE" = true ]; then
    cat <<EOF > "$RESTORE_OUTPUT"
${APP_ID}:
  persistenceLonghorn:
    fromBackup: "s3://longhorn-backups@192.168.14.222:9900/longhorn?backup=${backup_id}&volume=${ORIGINAL_VOLUME_ID}"
EOF
  else
    cat <<EOF > "$RESTORE_OUTPUT"
persistenceLonghorn:
  fromBackup: "s3://longhorn-backups@192.168.14.222:9900/longhorn?backup=${backup_id}&volume=${ORIGINAL_VOLUME_ID}"
EOF
  fi

  echo "Restore manifest generated in '$RESTORE_OUTPUT'"
}

########################################
# Main
########################################
case "$MODE" in
  backup)
    do_backup
    ;;
  restore)
    do_restore
    ;;
  *)
    usage
    ;;
esac
