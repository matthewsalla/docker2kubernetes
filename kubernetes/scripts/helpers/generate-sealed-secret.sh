#!/bin/bash
set -e  # Stop script on any error

# Usage instructions
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <namespace> <secret-name> <key=value> [<key=value> ...]"
    echo "Example: $0 default traefik-auth 'users=admin:$apr1$5WlW3dUX$5J8Lq5DvRWDZ97jV4a3po1' 'password=supersecret'"
    exit 1
fi

NAMESPACE=$1
SECRET_NAME=$2
shift 2

# Build the data block for the secret
DATA_LINES=""
for PAIR in "$@"; do
    # Split each key=value pair
    IFS='=' read -r KEY VALUE <<< "$PAIR"
    if [ -z "$KEY" ]; then
        echo "Error: Each key=value pair must have a key."
        exit 1
    fi
    # If the value is literally '""', set it to empty string
    if [ "$VALUE" = '""' ]; then
        VALUE=""
    fi
    # Encode the value in base64 (using echo -n to avoid a trailing newline)
    ENCODED_VALUE=$(echo -n "$VALUE" | base64)
    DATA_LINES+="  $KEY: $ENCODED_VALUE"$'\n'
done

# Create the secret YAML file
cat > temp-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
$DATA_LINES
EOF

# Seal the secret using kubeseal
kubeseal --format yaml \
  --cert=../certs/sealed-secret-controller-cert.pem \
  < temp-secret.yaml > "../secrets/$SECRET_NAME-sealed-secret.yaml"

rm temp-secret.yaml
echo "✅ Created: ../secrets/$SECRET_NAME-sealed-secret.yaml"
