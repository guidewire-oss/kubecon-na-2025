# Observability Guide for KubeVela Applications

This guide explains how to monitor your KubeVela applications using Prometheus and Grafana in a local k3d development environment.

## Quick Start

### 1. Setup Observability Stack

```bash
./setup-observability.sh
```

This script will:
- Enable KubeVela core metrics
- Install the observability addon (Prometheus + Grafana + Loki)
- Set up port-forwards for local access
- Display access credentials

### 2. Access Grafana

Open your browser to: **http://localhost:3000**

**Default Credentials:**
- Username: `admin`
- Password: Retrieved from secret (displayed by setup script)

### 3. Access Prometheus

Open your browser to: **http://localhost:9090**

No authentication required for Prometheus.

## Available Metrics

### KubeVela Platform Metrics

KubeVela exposes comprehensive platform metrics at: `http://kubevela-vela-core.vela-system:8080/metrics`

| Metric | Type | Description |
|--------|------|-------------|
| `kubevela_application_health_status` | Gauge | Overall health status (1=healthy, 0=unhealthy) |
| `kubevela_application_phase` | Gauge | Application phase (numeric representation) |
| `kubevela_application_workflow_phase` | Gauge | Workflow phase (numeric representation) |
| `application_reconcile_time_seconds` | Histogram | Time taken to reconcile applications |
| `workflow_finished_time_seconds` | Histogram | Time taken for workflows to complete |
| `apply_component_time_seconds` | Histogram | Time taken to apply components |
| `workflow_step_phase_number` | Gauge | Number of workflow steps in each phase |
| `application_phase_number` | Gauge | Number of applications in each phase |

### Application Metrics

If your application exposes metrics on `/metrics` endpoint:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

Common application metrics (if implemented):
- HTTP request rates
- Request latency/duration
- Error rates
- Custom business metrics

### Kubernetes Metrics

Standard Kubernetes metrics from kube-state-metrics:
- Pod CPU/Memory usage
- Container restarts
- Node resources
- Deployment replicas

## Useful Prometheus Queries

### Application Health

```promql
# All applications health status
kubevela_application_health_status

# Unhealthy applications
kubevela_application_health_status{name="s3-storage-app"} == 0

# Applications by phase
kubevela_application_phase
```

### Workflow Monitoring

```promql
# Workflow completion time (95th percentile)
histogram_quantile(0.95, sum(rate(workflow_finished_time_seconds_bucket[5m])) by (le))

# Workflow steps by phase
workflow_step_phase_number

# Failed workflow steps
workflow_step_phase_number{phase="failed"}
```

### Application Performance

```promql
# Application reconcile time
histogram_quantile(0.95, sum(rate(application_reconcile_time_seconds_bucket[5m])) by (le))

# Component apply time
histogram_quantile(0.95, sum(rate(apply_component_time_seconds_bucket[5m])) by (le))
```

### S3 Storage App Specific

```promql
# S3 app health
kubevela_application_health_status{name="s3-storage-app"}

# S3 app workflow status
kubevela_application_workflow_phase{name="s3-storage-app"}

# Pod CPU usage for storage-api
container_cpu_usage_seconds_total{pod=~"storage-api.*"}

# Pod memory usage for storage-api
container_memory_working_set_bytes{pod=~"storage-api.*"}
```

### HTTP Metrics (if app exposes them)

```promql
# Request rate
rate(http_requests_total[5m])

# Request duration (95th percentile)
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
```

## Grafana Dashboards

### Built-in Dashboards

The observability addon may include pre-configured dashboards for:
- KubeVela Application Overview
- Workflow Execution Metrics
- Kubernetes Cluster Overview
- Pod Resource Usage

### Creating Custom Dashboards

1. **Login to Grafana** (http://localhost:3000)
2. **Click "+" → Dashboard**
3. **Add Panel**
4. **Select Prometheus as Data Source**
5. **Enter your PromQL query**
6. **Configure visualization (Graph, Gauge, Table, etc.)**
7. **Save Dashboard**

### Example Dashboard: S3 Storage App

Create a dashboard with these panels:

**Panel 1: Application Health**
```promql
kubevela_application_health_status{name="s3-storage-app"}
```
Visualization: Stat (show 1=healthy, 0=unhealthy)

**Panel 2: Workflow Phase**
```promql
kubevela_application_workflow_phase{name="s3-storage-app"}
```
Visualization: Stat with color thresholds

**Panel 3: Pod CPU Usage**
```promql
sum(rate(container_cpu_usage_seconds_total{pod=~"storage-api.*"}[5m])) by (pod)
```
Visualization: Time series graph

**Panel 4: Pod Memory Usage**
```promql
sum(container_memory_working_set_bytes{pod=~"storage-api.*"}) by (pod)
```
Visualization: Time series graph

**Panel 5: Application Reconcile Time**
```promql
histogram_quantile(0.95, sum(rate(application_reconcile_time_seconds_bucket{name="s3-storage-app"}[5m])) by (le))
```
Visualization: Gauge

## Monitoring Multi-Environment Deployments

Since the S3 app deploys to dev/staging/prod namespaces:

```promql
# Health by environment
kubevela_application_health_status{name="s3-storage-app", namespace=~"dev|staging|prod"}

# Pod count by environment
count(kube_pod_info{namespace=~"dev|staging|prod", pod=~"storage-api.*"}) by (namespace)

# CPU usage by environment
sum(rate(container_cpu_usage_seconds_total{namespace=~"dev|staging|prod", pod=~"storage-api.*"}[5m])) by (namespace)
```

## Alerting (Optional)

### Example Alert Rules

Create a file `alerts.yaml`:

```yaml
groups:
  - name: kubevela_alerts
    interval: 30s
    rules:
      - alert: ApplicationUnhealthy
        expr: kubevela_application_health_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Application {{ $labels.name }} is unhealthy"
          description: "Application {{ $labels.name }} in namespace {{ $labels.namespace }} has been unhealthy for more than 5 minutes"

      - alert: WorkflowFailed
        expr: kubevela_application_workflow_phase{phase="failed"} == 1
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Workflow failed for {{ $labels.name }}"
          description: "Workflow for application {{ $labels.name }} has failed"

      - alert: HighReconcileTime
        expr: histogram_quantile(0.95, sum(rate(application_reconcile_time_seconds_bucket[5m])) by (le)) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High application reconcile time"
          description: "95th percentile reconcile time is above 10 seconds"
```

Apply alerts to Prometheus (if using Prometheus Operator):

```bash
kubectl apply -f alerts.yaml -n vela-system
```

## Troubleshooting

### Can't Access Grafana

**Check port-forward is running:**
```bash
ps aux | grep port-forward
```

**Restart port-forward:**
```bash
pkill -f 'port-forward.*grafana'
kubectl port-forward -n vela-system svc/grafana 3000:80
```

**Check Grafana pod:**
```bash
kubectl get pods -n vela-system -l app.kubernetes.io/name=grafana
kubectl logs -n vela-system -l app.kubernetes.io/name=grafana
```

### No Metrics Showing Up

**Check Prometheus targets:**
1. Open http://localhost:9090/targets
2. Look for `kubevela-vela-core` and your application pods
3. Status should be "UP"

**Check application annotations:**
```bash
kubectl get pod -n dev -l app=storage-api -o jsonpath='{.items[0].metadata.annotations}'
```

Should include:
```json
{
  "prometheus.io/scrape": "true",
  "prometheus.io/port": "8080",
  "prometheus.io/path": "/metrics"
}
```

**Test metrics endpoint directly:**
```bash
# KubeVela core metrics
kubectl port-forward -n vela-system svc/kubevela-vela-core 8080:8080
curl http://localhost:8080/metrics

# Application metrics
kubectl port-forward -n dev pod/storage-api-xxx 8080:8080
curl http://localhost:8080/metrics
```

### Observability Addon Not Installing

**Check addon status:**
```bash
vela addon status observability
```

**Check addon logs:**
```bash
kubectl logs -n vela-system -l app.kubernetes.io/name=vela-core --tail=100
```

**Reinstall addon:**
```bash
vela addon disable observability
vela addon enable observability
```

### Missing ServiceMonitor

If using Prometheus Operator, ensure ServiceMonitor is enabled:

```bash
helm upgrade kubevela kubevela/vela-core \
  -n vela-system \
  --reuse-values \
  --set core.metrics.serviceMonitor.enabled=true
```

## Advanced Configuration

### Custom Scrape Configs

Add custom Prometheus scrape configs to `prometheus.yaml`:

```yaml
scrape_configs:
  - job_name: 's3-storage-app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - dev
            - staging
            - prod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
```

### Loki for Logs

If Loki is included in the observability addon:

**Access Loki:** http://localhost:3100

**Query logs in Grafana:**
1. Go to Explore
2. Select Loki as data source
3. Use LogQL queries:

```logql
# All logs from storage-api
{namespace="dev", app="storage-api"}

# Error logs only
{namespace="dev", app="storage-api"} |= "error"

# Logs from last 5 minutes
{namespace="dev", app="storage-api"} [5m]
```

## Stopping Observability Stack

### Stop Port-Forwards

```bash
pkill -f 'port-forward.*(grafana|prometheus)'
```

### Disable Addon

```bash
vela addon disable observability
```

This will remove Prometheus, Grafana, and Loki from your cluster.

### Disable KubeVela Metrics

```bash
helm upgrade kubevela kubevela/vela-core \
  -n vela-system \
  --reuse-values \
  --set core.metrics.enabled=false
```

## Resources

- [KubeVela Observability Documentation](https://kubevela.io/docs/platform-engineers/system-operation/observability)
- [Prometheus Query Language (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [KubeVela Metrics Reference](https://kubevela.io/docs/platform-engineers/system-operation/observability#metrics)

## Summary

You now have:
- ✅ Prometheus scraping KubeVela platform metrics
- ✅ Grafana for visualization and dashboards
- ✅ Prometheus annotations on your S3 storage app
- ✅ Port-forwards for easy local access
- ✅ Example queries and dashboard templates

**Quick Links:**
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Setup Script: `./setup-observability.sh`
