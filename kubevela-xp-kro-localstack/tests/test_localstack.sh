#!/bin/bash
# Test LocalStack deployment and connectivity
set -e

ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
REGION="us-west-2"

echo "Test 1: LocalStack pod is running"
kubectl get pods -n localstack-system -l app.kubernetes.io/name=localstack

echo "Test 2: LocalStack service is accessible"
kubectl run test-connectivity --image=amazon/aws-cli --rm -it --restart=Never -- \
  --endpoint-url=$ENDPOINT --region=$REGION dynamodb list-tables

echo "Test 3: Can create table in LocalStack"
kubectl run test-create-table --image=amazon/aws-cli --rm -it --restart=Never -- \
  --endpoint-url=$ENDPOINT --region=$REGION \
  dynamodb create-table --table-name test-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo "Test 4: Can list tables"
kubectl run test-list-tables --image=amazon/aws-cli --rm -it --restart=Never -- \
  --endpoint-url=$ENDPOINT --region=$REGION dynamodb list-tables

echo "✓ All LocalStack tests passed"
