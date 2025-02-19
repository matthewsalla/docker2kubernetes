#!/bin/bash
set -e  # Stop script on any error

# Simple usage instructions
if [ $# -ne 3 ]; then
    echo "Usage: $0 <namespace> <secret-name> \"<key=value>\""
    echo "Example: $0 default traefik-auth 'users=admin:$apr1$5WlW3dUX$5J8Lq5DvRWDZ97jV4a3po1'"
    exit 1
fi

NAMESPACE=$1
SECRET_NAME=$2
SECRET_DATA=$3

# Split input into key/value pair
IFS='=' read -r KEY VALUE <<< "$SECRET_DATA"

# Create basic secret template
cat > temp-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  $KEY: $(echo -n "$VALUE" | base64)
EOF

# Create sealed secret
kubeseal --format yaml \
  --cert=../certs/sealed-secret-controller-cert.pem \
  < temp-secret.yaml > "../secrets/$SECRET_NAME-sealed-secret.yaml"

# Cleanup and report
rm temp-secret.yaml
echo "✅ Created: ../secrets/$SECRET_NAME-sealed-secret.yaml"
