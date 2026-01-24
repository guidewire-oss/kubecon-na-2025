#!/bin/bash
# Simple LocalStack test without aws-cli
set -e

ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"

echo "Test 1: LocalStack pod is running"
kubectl get pods -n localstack-system -l app.kubernetes.io/name=localstack

echo ""
echo "Test 2: LocalStack service exists"
kubectl get svc -n localstack-system localstack

echo ""
echo "Test 3: LocalStack service is reachable"
if kubectl run test-curl --image=curlimages/curl --rm --restart=Never -- \
  curl -s $ENDPOINT/health > /dev/null 2>&1; then
    echo "✓ Service is responding"
else
    echo "✗ Service is not responding"
    exit 1
fi

echo ""
echo "✓ LocalStack is ready!"
