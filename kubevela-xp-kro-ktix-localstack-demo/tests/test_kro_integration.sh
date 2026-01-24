#!/bin/bash
# Test KRO + ACK with LocalStack
set -e

ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
REGION="us-west-2"

echo "Test: Deploy SimpleDynamoDB via KRO"
KUBECONFIG=./kubeconfig-internal kubectl apply -f - <<EOF
apiVersion: kro.run/v1alpha1
kind: SimpleDynamoDB
metadata:
  name: test-simple-table
  namespace: default
spec:
  tableName: test-simple
  region: us-west-2
EOF

echo "Wait for table to be ready"
sleep 30

echo "Verify table exists in LocalStack"
kubectl run verify-table --image=amazon/aws-cli --rm -it --restart=Never -- \
  --endpoint-url=$ENDPOINT \
  --region=$REGION \
  dynamodb describe-table --table-name test-simple

echo "✓ KRO integration test passed"
