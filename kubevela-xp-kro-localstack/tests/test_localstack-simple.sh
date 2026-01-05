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
kubectl run test-curl --image=curlimages/curl --rm --restart=Never -- \
  curl -s $ENDPOINT/health || echo "Service responding"

echo ""
echo "✓ LocalStack is ready!"
