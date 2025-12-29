#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🏗️  Building Docker image..."
cd "${SCRIPT_DIR}"
docker build -t session-api:latest .

echo "📦 Importing image into k3d cluster..."
k3d image import session-api:latest -c kubevela-demo

echo "🚀 Deploying KubeVela application..."
kubectl apply -f "${PROJECT_ROOT}/definitions/examples/session-management-app.yaml"

echo "⏳ Waiting for application to be ready..."
echo "   You can check status with: vela status session-management"
echo ""
echo "To access the API:"
echo "  kubectl port-forward svc/session-api 8080:8080"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:8080/health"
echo "  curl -X POST http://localhost:8080/sessions -H 'Content-Type: application/json' -d '{\"userId\":\"user123\",\"data\":{\"theme\":\"dark\"}}'"
