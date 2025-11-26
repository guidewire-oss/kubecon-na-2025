#!/bin/bash
set -e

echo "=== Updating S3 Storage App Dashboards ==="
echo ""

# Get Grafana password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d)
if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD="admin"
fi

# Wait for Grafana API
echo "Checking Grafana API..."
MAX_RETRIES=10
for i in $(seq 1 $MAX_RETRIES); do
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✓ Grafana is accessible"
        break
    fi
    echo "  Waiting for Grafana API..."
    sleep 2
done
echo ""

# Import multi-environment dashboard
echo "Importing S3 Storage Application - Multi-Environment Dashboard..."
DASHBOARD_JSON=$(cat s3-storage-app-dashboard.json | jq '{dashboard: ., overwrite: true, inputs: [{name: "DS_PROMETHEUS", type: "datasource", pluginId: "prometheus", value: "Prometheus"}]}' 2>/dev/null)

if [ -n "$DASHBOARD_JSON" ]; then
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "admin:${GRAFANA_PASSWORD}" \
        -d "$DASHBOARD_JSON" \
        http://localhost:3000/api/dashboards/import 2>/dev/null)

    if echo "$RESPONSE" | grep -q "success" 2>/dev/null; then
        echo "✓ Multi-Environment dashboard imported successfully"
    else
        echo "⚠ Failed to import Multi-Environment dashboard"
    fi
else
    echo "✗ Failed to prepare Multi-Environment dashboard JSON"
fi
echo ""

# Import single view dashboard
echo "Importing S3 Storage Application - Single View Dashboard..."
DASHBOARD_JSON=$(cat s3-storage-app-dashboard-single.json | jq '{dashboard: ., overwrite: true, inputs: [{name: "DS_PROMETHEUS", type: "datasource", pluginId: "prometheus", value: "Prometheus"}]}' 2>/dev/null)

if [ -n "$DASHBOARD_JSON" ]; then
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "admin:${GRAFANA_PASSWORD}" \
        -d "$DASHBOARD_JSON" \
        http://localhost:3000/api/dashboards/import 2>/dev/null)

    if echo "$RESPONSE" | grep -q "success" 2>/dev/null; then
        echo "✓ Single View dashboard imported successfully"
    else
        echo "⚠ Failed to import Single View dashboard"
    fi
else
    echo "✗ Failed to prepare Single View dashboard JSON"
fi
echo ""

echo "=== Update Complete! ==="
echo ""
echo "View the dashboards at:"
echo "  Multi-Environment: http://localhost:3000/d/s3-storage-app/s3-storage-application-multi-environment"
echo "  Single View:       http://localhost:3000/d/s3-storage-app-single/s3-storage-application-single-view"
echo ""
