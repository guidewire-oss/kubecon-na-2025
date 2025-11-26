#!/bin/bash
set -e  # Exit on error

echo "=== KubeVela Observability Setup (Local Development) ==="
echo ""

# Activate virtual environment if it exists
if [ -d "../../.venv" ]; then
    echo "Activating virtual environment..."
    source ../../.venv/bin/activate
    echo "✓ Virtual environment activated"
    echo ""
fi

# Step 1: Check prerequisites
echo "=== Step 1: Checking Prerequisites ==="
echo ""

if ! command -v vela &> /dev/null; then
    echo "✗ vela CLI not found. Please install it first."
    exit 1
fi
echo "✓ vela CLI found"

if ! command -v kubectl &> /dev/null; then
    echo "✗ kubectl not found. Please install it first."
    exit 1
fi
echo "✓ kubectl found"

if ! command -v helm &> /dev/null; then
    echo "✗ helm not found. Please install it first."
    exit 1
fi
echo "✓ helm found"

echo ""

# Step 2: Enable KubeVela core metrics
echo "=== Step 2: Enabling KubeVela Core Metrics ==="
echo ""

echo "Upgrading vela-core with metrics enabled..."
helm upgrade kubevela kubevela/vela-core \
    -n vela-system \
    --reuse-values \
    --set core.metrics.enabled=true \
    --set core.metrics.serviceMonitor.enabled=true \
    --set featureGates.enableApplicationStatusMetrics=true \
    --wait

echo "✓ KubeVela core metrics enabled"
echo ""

# Step 3: Enable observability addon or install kube-prometheus-stack
echo "=== Step 3: Installing Observability Stack ==="
echo ""

# Check if addon is already enabled
if vela addon status observability &>/dev/null 2>&1; then
    echo "⚠ Observability addon is already enabled"
    echo ""
else
    # Check if observability addon exists in the catalog
    if ! vela addon list | grep -q "^observability"; then
        echo "⚠ Observability addon not available in registries"
        echo ""
        echo "Installing kube-prometheus-stack via Helm instead..."
        echo ""

        # Add prometheus-community and grafana helm repos
        echo "Adding Helm repositories..."
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
        helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
        helm repo update

        # Create namespace
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

        # Install kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager)
        echo ""
        echo "Installing kube-prometheus-stack (this may take a few minutes)..."
        helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
            -n monitoring \
            --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
            --set grafana.adminPassword=admin \
            --wait \
            --timeout 10m

        echo "✓ kube-prometheus-stack installed"
        OBSERVABILITY_NS="monitoring"
        echo ""

        # Install Loki stack (Loki + Promtail for log collection)
        echo "Installing Loki stack for log aggregation..."
        helm upgrade --install loki grafana/loki-stack \
            -n monitoring \
            --set loki.enabled=true \
            --set promtail.enabled=true \
            --set grafana.enabled=false \
            --set prometheus.enabled=false \
            --wait \
            --timeout 5m

        echo "✓ Loki stack installed"
        echo ""
    else
        echo "Enabling observability addon..."
        vela addon enable observability
        echo "✓ Observability addon enabled"
        echo ""
        echo "Waiting for observability addon to be ready..."
        sleep 10

        # Wait for addon to be fully enabled
        MAX_RETRIES=30
        for i in $(seq 1 $MAX_RETRIES); do
            if vela addon status observability | grep -q "enabled"; then
                echo "✓ Observability addon ready"
                break
            fi

            if [ $i -eq $MAX_RETRIES ]; then
                echo "✗ Timeout waiting for observability addon"
                exit 1
            fi

            echo "  Waiting... ($i/$MAX_RETRIES)"
            sleep 10
        done
    fi
fi
echo ""

# Step 4: Detect observability namespace and wait for pods
echo "=== Step 4: Detecting Observability Stack ==="
echo ""

# Always detect the namespace where observability is installed
echo "Detecting observability namespace..."
OBSERVABILITY_NS="vela-system"

# Check monitoring namespace first (kube-prometheus-stack)
if kubectl get namespace monitoring &>/dev/null; then
    # Check for any Grafana deployment variant
    if kubectl get deployment -n monitoring 2>/dev/null | grep -q grafana; then
        OBSERVABILITY_NS="monitoring"
        echo "✓ Found observability stack in 'monitoring' namespace"
    # Or check for any Prometheus statefulset variant
    elif kubectl get statefulset -n monitoring 2>/dev/null | grep -q prometheus; then
        OBSERVABILITY_NS="monitoring"
        echo "✓ Found observability stack in 'monitoring' namespace"
    fi
fi

# Check observability namespace (vela addon)
if kubectl get namespace observability &>/dev/null; then
    if kubectl get deployment -n observability grafana &>/dev/null 2>&1 || \
       kubectl get deployment -n observability prometheus &>/dev/null 2>&1; then
        OBSERVABILITY_NS="observability"
        echo "✓ Found observability stack in 'observability' namespace"
    fi
fi

# Check vela-system as fallback
if [ "$OBSERVABILITY_NS" = "vela-system" ]; then
    if kubectl get deployment -n vela-system grafana &>/dev/null 2>&1; then
        echo "✓ Found observability stack in 'vela-system' namespace"
    else
        echo "⚠ Using default namespace: vela-system"
    fi
fi

echo "Using observability namespace: $OBSERVABILITY_NS"
echo ""

echo "=== Waiting for Observability Pods ==="
echo ""

# Wait for Prometheus
echo "Waiting for Prometheus..."
# Try kube-prometheus-stack label first
if kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=prometheus \
    -n $OBSERVABILITY_NS \
    --timeout=300s 2>/dev/null; then
    echo "✓ Prometheus is ready"
elif kubectl wait --for=condition=ready pod \
    -l app=prometheus \
    -n $OBSERVABILITY_NS \
    --timeout=300s 2>/dev/null; then
    echo "✓ Prometheus is ready"
else
    echo "⚠ Prometheus pod not found or not ready yet"
fi
echo ""

# Wait for Grafana
echo "Waiting for Grafana..."
# Try kube-prometheus-stack label first
if kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=grafana \
    -n $OBSERVABILITY_NS \
    --timeout=300s 2>/dev/null; then
    echo "✓ Grafana is ready"
elif kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kube-prometheus-stack-grafana \
    -n $OBSERVABILITY_NS \
    --timeout=300s 2>/dev/null; then
    echo "✓ Grafana is ready"
else
    echo "⚠ Grafana pod not found or not ready yet"
fi
echo ""

# Wait for Loki (if installed)
if kubectl get deployment -n $OBSERVABILITY_NS loki 2>/dev/null | grep -q loki; then
    echo "Waiting for Loki..."
    if kubectl wait --for=condition=ready pod \
        -l app=loki \
        -n $OBSERVABILITY_NS \
        --timeout=300s 2>/dev/null; then
        echo "✓ Loki is ready"
    else
        echo "⚠ Loki pod not found or not ready yet"
    fi
    echo ""
fi

# Wait for Promtail (if installed)
if kubectl get daemonset -n $OBSERVABILITY_NS loki-promtail 2>/dev/null | grep -q promtail; then
    echo "Waiting for Promtail..."
    if kubectl wait --for=condition=ready pod \
        -l app=promtail \
        -n $OBSERVABILITY_NS \
        --timeout=300s 2>/dev/null; then
        echo "✓ Promtail is ready"
    else
        echo "⚠ Promtail pod not found or not ready yet"
    fi
    echo ""
fi

# Step 5: Get Grafana credentials
echo "=== Step 5: Retrieving Grafana Credentials ==="
echo ""

# Try to get Grafana password from different secret names
GRAFANA_PASSWORD=$(kubectl get secret -n $OBSERVABILITY_NS grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d)

if [ -z "$GRAFANA_PASSWORD" ]; then
    # Try kube-prometheus-stack secret
    GRAFANA_PASSWORD=$(kubectl get secret -n $OBSERVABILITY_NS kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d)
fi

if [ -z "$GRAFANA_PASSWORD" ]; then
    echo "⚠ Could not retrieve Grafana password from secret"
    echo "Using default password: admin"
    GRAFANA_PASSWORD="admin"
else
    echo "✓ Grafana password retrieved from secret"
fi
echo ""

# Step 6: Set up port-forwards
echo "=== Step 6: Setting Up Port Forwards ==="
echo ""

# Kill any existing port-forwards
echo "Stopping any existing port-forwards..."
pkill -f "port-forward.*grafana" 2>/dev/null && echo "  Killed existing Grafana port-forward" || true
pkill -f "port-forward.*prometheus" 2>/dev/null && echo "  Killed existing Prometheus port-forward" || true
pkill -f "port-forward.*loki" 2>/dev/null && echo "  Killed existing Loki port-forward" || true
sleep 2
echo ""

# Find Grafana service
GRAFANA_SVC=""
echo "Looking for Grafana service in namespace: $OBSERVABILITY_NS"
if kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-stack-grafana &>/dev/null; then
    GRAFANA_SVC="kube-prometheus-stack-grafana"
    echo "✓ Found service: $GRAFANA_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-grafana &>/dev/null; then
    GRAFANA_SVC="kube-prometheus-grafana"
    echo "✓ Found service: $GRAFANA_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS grafana &>/dev/null; then
    GRAFANA_SVC="grafana"
    echo "✓ Found service: $GRAFANA_SVC"
else
    echo "✗ No Grafana service found in $OBSERVABILITY_NS"
fi

# Start Grafana port-forward
if [ -n "$GRAFANA_SVC" ]; then
    echo "Starting port-forward for Grafana on port 3000..."
    nohup kubectl port-forward -n $OBSERVABILITY_NS svc/$GRAFANA_SVC 3000:80 > /tmp/grafana-port-forward.log 2>&1 &
    GRAFANA_PID=$!
    sleep 3

    if ps -p $GRAFANA_PID > /dev/null 2>&1; then
        echo "✓ Grafana port-forward started (PID: $GRAFANA_PID)"
    else
        echo "✗ Failed to start Grafana port-forward"
        echo "  Check logs: tail /tmp/grafana-port-forward.log"
    fi
fi
echo ""

# Find Prometheus service
PROMETHEUS_SVC=""
echo "Looking for Prometheus service in namespace: $OBSERVABILITY_NS"
if kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-stack-prometheus &>/dev/null; then
    PROMETHEUS_SVC="kube-prometheus-stack-prometheus"
    echo "✓ Found service: $PROMETHEUS_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-kube-prome-prometheus &>/dev/null; then
    PROMETHEUS_SVC="kube-prometheus-kube-prome-prometheus"
    echo "✓ Found service: $PROMETHEUS_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS prometheus-operated &>/dev/null; then
    PROMETHEUS_SVC="prometheus-operated"
    echo "✓ Found service: $PROMETHEUS_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS prometheus &>/dev/null; then
    PROMETHEUS_SVC="prometheus"
    echo "✓ Found service: $PROMETHEUS_SVC"
else
    echo "✗ No Prometheus service found in $OBSERVABILITY_NS"
fi

# Start Prometheus port-forward
if [ -n "$PROMETHEUS_SVC" ]; then
    echo "Starting port-forward for Prometheus on port 9090..."
    nohup kubectl port-forward -n $OBSERVABILITY_NS svc/$PROMETHEUS_SVC 9090:9090 > /tmp/prometheus-port-forward.log 2>&1 &
    PROMETHEUS_PID=$!
    sleep 3

    if ps -p $PROMETHEUS_PID > /dev/null 2>&1; then
        echo "✓ Prometheus port-forward started (PID: $PROMETHEUS_PID)"
    else
        echo "✗ Failed to start Prometheus port-forward"
        echo "  Check logs: tail /tmp/prometheus-port-forward.log"
    fi
fi
echo ""

# Find Loki service
LOKI_SVC=""
echo "Looking for Loki service in namespace: $OBSERVABILITY_NS"
if kubectl get svc -n $OBSERVABILITY_NS loki &>/dev/null; then
    LOKI_SVC="loki"
    echo "✓ Found service: $LOKI_SVC"
elif kubectl get svc -n $OBSERVABILITY_NS loki-gateway &>/dev/null; then
    LOKI_SVC="loki-gateway"
    echo "✓ Found service: $LOKI_SVC"
else
    echo "⚠ No Loki service found in $OBSERVABILITY_NS (Loki is optional)"
fi

# Start Loki port-forward
if [ -n "$LOKI_SVC" ]; then
    echo "Starting port-forward for Loki on port 3100..."
    nohup kubectl port-forward -n $OBSERVABILITY_NS svc/$LOKI_SVC 3100:3100 > /tmp/loki-port-forward.log 2>&1 &
    LOKI_PID=$!
    sleep 3

    if ps -p $LOKI_PID > /dev/null 2>&1; then
        echo "✓ Loki port-forward started (PID: $LOKI_PID)"
    else
        echo "✗ Failed to start Loki port-forward"
        echo "  Check logs: tail /tmp/loki-port-forward.log"
    fi
fi
echo ""

# Step 7: Verify metrics endpoints
echo "=== Step 7: Verifying Metrics Endpoints ==="
echo ""

echo "Checking KubeVela core metrics..."
if kubectl get svc -n vela-system kubevela-vela-core-metrics &>/dev/null; then
    echo "✓ KubeVela metrics service found"
else
    echo "⚠ KubeVela metrics service not found"
fi
echo ""

# Step 8: Configure Loki datasource in Grafana
echo "=== Step 8: Configuring Loki Datasource in Grafana ==="
echo ""

# Wait a bit for Grafana to be fully ready
sleep 5

if [ -n "$LOKI_SVC" ]; then
    echo "Configuring Loki datasource in Grafana..."

    # Wait for Grafana API
    MAX_RETRIES=30
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
            break
        fi
        if [ $i -eq 1 ]; then
            echo "  Waiting for Grafana API to be ready..."
        fi
        sleep 2
    done

    # Check if Loki datasource already exists
    LOKI_EXISTS=$(curl -s -u "admin:${GRAFANA_PASSWORD}" http://localhost:3000/api/datasources/name/Loki 2>/dev/null | grep -q '"name":"Loki"' && echo "yes" || echo "no")

    if [ "$LOKI_EXISTS" = "no" ]; then
        # Create Loki datasource
        LOKI_DATASOURCE_JSON='{
          "name": "Loki",
          "type": "loki",
          "access": "proxy",
          "url": "http://loki:3100",
          "isDefault": false,
          "jsonData": {}
        }'

        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "admin:${GRAFANA_PASSWORD}" \
            -d "$LOKI_DATASOURCE_JSON" \
            http://localhost:3000/api/datasources 2>/dev/null)

        if echo "$RESPONSE" | grep -q '"message":"Datasource added"' 2>/dev/null; then
            echo "✓ Loki datasource configured successfully"
        else
            echo "⚠ Could not configure Loki datasource"
            echo "  You can manually add it in Grafana: Configuration → Data Sources"
        fi
    else
        echo "✓ Loki datasource already exists"
    fi
else
    echo "⚠ Skipping Loki datasource configuration (Loki not installed)"
fi
echo ""

# Step 9: Import dashboards to Grafana
echo "=== Step 9: Importing Dashboards to Grafana ==="
echo ""

echo "Importing dashboards to Grafana..."

# Get Grafana service details (reuse detection from Step 6)
if [ -z "$GRAFANA_SVC" ]; then
    if kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-stack-grafana &>/dev/null; then
        GRAFANA_SVC="kube-prometheus-stack-grafana"
    elif kubectl get svc -n $OBSERVABILITY_NS kube-prometheus-grafana &>/dev/null; then
        GRAFANA_SVC="kube-prometheus-grafana"
    elif kubectl get svc -n $OBSERVABILITY_NS grafana &>/dev/null; then
        GRAFANA_SVC="grafana"
    fi
fi

# Function to import dashboard via Grafana API
import_dashboard() {
    local DASHBOARD_FILE=$1
    local DASHBOARD_NAME=$2

    if [ ! -f "$DASHBOARD_FILE" ]; then
        echo "⚠ $DASHBOARD_FILE not found, skipping..."
        return
    fi

    echo "Importing $DASHBOARD_NAME..."

    # Wait for Grafana API to be ready
    MAX_RETRIES=30
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
            break
        fi
        if [ $i -eq 1 ]; then
            echo "  Waiting for Grafana API to be ready..."
        fi
        sleep 2
    done

    # Prepare dashboard JSON for import
    DASHBOARD_JSON=$(cat $DASHBOARD_FILE | jq '{dashboard: ., overwrite: true, inputs: [{name: "DS_PROMETHEUS", type: "datasource", pluginId: "prometheus", value: "Prometheus"}]}' 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$DASHBOARD_JSON" ]; then
        # Import via API
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "admin:${GRAFANA_PASSWORD}" \
            -d "$DASHBOARD_JSON" \
            http://localhost:3000/api/dashboards/import 2>/dev/null)

        if echo "$RESPONSE" | grep -q "success" 2>/dev/null; then
            echo "✓ $DASHBOARD_NAME imported successfully"
        else
            echo "⚠ Could not auto-import $DASHBOARD_NAME via API"
            echo "  Manual import: Upload $DASHBOARD_FILE in Grafana"
        fi
    else
        echo "⚠ jq not found or JSON invalid, creating ConfigMap instead..."
        # Fallback: Create ConfigMap
        kubectl create configmap $(basename $DASHBOARD_FILE .json) \
            --from-file=$DASHBOARD_FILE \
            -n $OBSERVABILITY_NS \
            --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        echo "  ConfigMap created, manual import required"
    fi
}

# Import all dashboards
import_dashboard "kubevela-dashboard.json" "KubeVela Applications Dashboard"
echo ""
import_dashboard "s3-storage-app-dashboard.json" "S3 Storage Application - Multi-Environment Dashboard"
echo ""
import_dashboard "s3-storage-app-dashboard-single.json" "S3 Storage Application - Single View Dashboard"
echo ""

echo "Dashboard import complete!"
echo ""

# Step 9: Display summary
echo "=== Setup Complete! ==="
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                  Observability Dashboard                    │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│                                                             │"
echo "│  🎯 Grafana                                                 │"
echo "│     URL:      http://localhost:3000                         │"
echo "│     Username: admin                                         │"
echo "│     Password: $GRAFANA_PASSWORD"
echo "│                                                             │"
echo "│  📊 Prometheus                                              │"
echo "│     URL:      http://localhost:9090                         │"
echo "│                                                             │"
if [ -n "$LOKI_SVC" ]; then
echo "│  📝 Loki (Logs)                                             │"
echo "│     URL:      http://localhost:3100                         │"
echo "│                                                             │"
fi
echo "│  🔍 Metrics Endpoints                                       │"
echo "│     KubeVela: http://kubevela-vela-core.vela-system:8080/metrics"
echo "│                                                             │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "📝 Next Steps:"
echo ""
echo "  1. Open Grafana:  http://localhost:3000"
echo "  2. Login with credentials above"
echo "  3. View Pre-loaded Dashboards:"
echo "     → Dashboards → Browse"
echo "     → Look for:"
echo "       • KubeVela Applications (Platform overview)"
echo "       • S3 Storage Application - Multi-Environment (Per-env health & metrics)"
echo "       • S3 Storage Application - Single View (Aggregate view)"
echo ""
echo "  4. Deploy your S3 app to see metrics:"
echo "     ./deploy-s3-app.sh"
echo ""
echo "  5. Query Prometheus directly: http://localhost:9090"
if [ -n "$LOKI_SVC" ]; then
echo ""
echo "  6. View Logs in Grafana:"
echo "     → Explore → Select 'Loki' datasource"
echo "     → Use LogQL queries like: {namespace=\"dev\", pod=~\"storage-api.*\"}"
fi
echo ""
echo "📊 KubeVela Dashboard Panels:"
echo "  • Application Health Status"
echo "  • Applications by Phase"
echo "  • Application Reconcile Time"
echo "  • Workflow Completion Time"
echo "  • Workflow Steps by Phase"
echo ""
echo "📊 S3 Storage App Dashboard Panels:"
echo "  • App Health & Workflow Phase"
echo "  • Pods by Environment (dev/staging/prod)"
echo "  • CPU & Memory Usage"
echo "  • Network I/O"
echo "  • Pod Restarts"
echo "  • HTTP Metrics (if app exposes them)"
echo ""
echo "📚 For more information, see OBSERVABILITY.md"
echo ""
echo "⚠️  Port-forwards are running in the background"
if [ -n "$LOKI_SVC" ]; then
echo "    To stop them: pkill -f 'port-forward.*(grafana|prometheus|loki)'"
else
echo "    To stop them: pkill -f 'port-forward.*(grafana|prometheus)'"
fi
echo ""
