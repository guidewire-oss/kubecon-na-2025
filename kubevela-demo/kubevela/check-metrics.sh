#!/bin/bash
set -e

echo "=== Checking KubeVela Metrics Availability ==="
echo ""

# Check if Prometheus is accessible
echo "1. Testing Prometheus connectivity..."
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo "✓ Prometheus is accessible at http://localhost:9090"
else
    echo "✗ Prometheus is not accessible. Is port-forward running?"
    echo "  Run: kubectl port-forward -n monitoring svc/kube-prometheus-kube-prome-prometheus 9090:9090"
    exit 1
fi
echo ""

# Check KubeVela metrics endpoint
echo "2. Checking KubeVela metrics endpoint..."
VELA_METRICS=$(kubectl get svc -n vela-system kubevela-vela-core-metrics -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$VELA_METRICS" ]; then
    echo "✓ KubeVela metrics service exists: $VELA_METRICS"
else
    echo "✗ KubeVela metrics service not found"
fi
echo ""

# Check if ServiceMonitor exists
echo "3. Checking ServiceMonitor for KubeVela..."
if kubectl get servicemonitor -n vela-system kubevela-vela-core 2>/dev/null; then
    echo "✓ ServiceMonitor exists"
else
    echo "⚠ ServiceMonitor not found. Prometheus may not be scraping KubeVela metrics."
    echo "  This is normal if not using Prometheus Operator"
fi
echo ""

# Query Prometheus for KubeVela metrics
echo "4. Querying Prometheus for KubeVela application metrics..."
echo ""

# Check for kubevela_application_health_status
echo "Query: kubevela_application_health_status"
RESULT=$(curl -s 'http://localhost:9090/api/v1/query?query=kubevela_application_health_status' | jq -r '.data.result | length')
if [ "$RESULT" -gt 0 ]; then
    echo "✓ Found $RESULT application(s) with health status"
    curl -s 'http://localhost:9090/api/v1/query?query=kubevela_application_health_status' | jq -r '.data.result[] | "  - \(.metric.name) (namespace: \(.metric.namespace)): \(.value[1])"'
else
    echo "✗ No kubevela_application_health_status metrics found"
fi
echo ""

# Check for s3-storage-app specifically
echo "Query: kubevela_application_health_status{name=\"s3-storage-app\"}"
RESULT=$(curl -s 'http://localhost:9090/api/v1/query?query=kubevela_application_health_status{name="s3-storage-app"}' | jq -r '.data.result | length')
if [ "$RESULT" -gt 0 ]; then
    echo "✓ Found s3-storage-app health metric"
    curl -s 'http://localhost:9090/api/v1/query?query=kubevela_application_health_status{name="s3-storage-app"}' | jq '.data.result[]'
else
    echo "✗ No metrics found for s3-storage-app"
fi
echo ""

# Check all available kubevela metrics
echo "5. Listing all available KubeVela metrics..."
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | jq -r '.data[] | select(startswith("kubevela") or startswith("application") or startswith("workflow"))' | head -20
echo ""

# Check Prometheus targets
echo "6. Checking Prometheus targets (scrape endpoints)..."
echo "Looking for vela-system targets..."
curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.namespace=="vela-system") | "  - \(.labels.job): \(.health) (\(.scrapeUrl))"' | head -10
echo ""

echo "=== Troubleshooting Tips ==="
echo ""
echo "If metrics are not found:"
echo "1. Check if KubeVela metrics are enabled:"
echo "   kubectl get svc -n vela-system kubevela-vela-core-metrics"
echo ""
echo "2. Test metrics endpoint directly:"
echo "   kubectl port-forward -n vela-system svc/kubevela-vela-core-metrics 8080:8080"
echo "   curl http://localhost:8080/metrics | grep kubevela_application"
echo ""
echo "3. Check if Prometheus is configured to scrape vela-system:"
echo "   kubectl get configmap -n monitoring kube-prometheus-kube-prome-prometheus -o yaml | grep vela"
echo ""
echo "4. Check application status:"
echo "   vela status s3-storage-app"
echo ""
