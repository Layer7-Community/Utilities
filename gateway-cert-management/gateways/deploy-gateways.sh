#!/bin/bash
set -e

# Apply kustomization
kubectl apply -k .

# Deploy gateways
export CLUSTER_HOSTNAME="gateway-prod.brcmlabs.com"
envsubst < gateway-values.yaml | helm upgrade --install gateway-prod layer7/gateway -f -

export CLUSTER_HOSTNAME="gateway-staging.brcmlabs.com"
envsubst < gateway-values.yaml | helm upgrade --install gateway-staging layer7/gateway -f -

export CLUSTER_HOSTNAME="gateway-dev.brcmlabs.com"
envsubst < gateway-values.yaml | helm upgrade --install gateway-dev layer7/gateway -f -

echo "Deployment complete!"
