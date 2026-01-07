# LocalStack Demo Architecture

## Component Chains

### KRO Path: VeLa App → SimpleDynamoDB → KRO RGD → ACK Table → LocalStack

```
┌─────────────────────────────────────────────────────────────────┐
│  VeLa Application: session-api-app-kro                          │
│  (definitions/examples/session-api-app-kro.yaml)                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  VeLa Component:      │
         │  aws-dynamodb-simple- │
         │  kro                  │
         │  (CUE definition)     │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  SimpleDynamoDB       │
         │  (Custom Resource)    │
         │  metadata:            │
         │    name: ...          │
         │  spec:                │
         │    tableName: ...     │
         │    region: us-west-2  │
         └───────────┬───────────┘
                     │
                     │ (KRO watches this)
                     ▼
    ┌──────────────────────────────┐
    │  KRO ResourceGraphDefinition  │
    │  (definitions/kro/            │
    │   simple-dynamodb-rgd.yaml)   │
    │                               │
    │  Transforms SimpleDynamoDB →  │
    │  into Table resource          │
    └──────────────┬────────────────┘
                   │
                   ▼
         ┌───────────────────────┐
         │  ACK Table Resource   │
         │  (DynamoDB Service)   │
         │  table.dynamodb.      │
         │  services.k8s.aws     │
         └───────────┬───────────┘
                     │
                     │ (ACK controller watches)
                     ▼
    ┌──────────────────────────────┐
    │  ACK Controller              │
    │  (ack-system namespace)      │
    │  - Reads AWS credentials     │
    │  - Gets LocalStack endpoint  │
    │  - Calls AWS API             │
    └──────────────┬────────────────┘
                   │
                   ▼
         ┌───────────────────────┐
         │  LocalStack Service   │
         │  (DynamoDB emulator)  │
         │  :4566                │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  DynamoDB Table       │
         │  Created in LocalStack│
         └───────────────────────┘
```

### Crossplane Path: VeLa App → Table → Crossplane Provider → LocalStack

```
┌─────────────────────────────────────────────────────────────────┐
│  VeLa Application: session-api-app-xp                           │
│  (definitions/examples/session-api-app-xp.yaml)                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  VeLa Component:      │
         │  aws-dynamodb-simple- │
         │  xp                   │
         │  (CUE definition)     │
         └───────────┬───────────┘
                     │
                     ▼
    ┌──────────────────────────────┐
    │  Crossplane Table Resource   │
    │  (DynamoDB Upbound provider) │
    │  table.dynamodb.aws.         │
    │  upbound.io                  │
    │                              │
    │  spec:                       │
    │    forProvider:              │
    │      region: us-west-2       │
    │      attribute:              │
    │        - name: id            │
    │          type: S             │
    │      hashKey: id             │
    │    providerConfigRef:        │
    │      name: default           │
    └──────────────┬────────────────┘
                   │
                   │ (Crossplane watches this)
                   ▼
    ┌──────────────────────────────┐
    │  Crossplane AWS Provider     │
    │  (crossplane-system)         │
    │                              │
    │  Reads ProviderConfig:       │
    │  - Endpoint: LocalStack URL  │
    │  - Credentials: test/test    │
    │  - Skip validation: true     │
    └──────────────┬────────────────┘
                   │
                   ▼
         ┌───────────────────────┐
         │  LocalStack Service   │
         │  (DynamoDB emulator)  │
         │  :4566                │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  DynamoDB Table       │
         │  Created in LocalStack│
         └───────────────────────┘
```

## Debugging Points (Where Things Can Break)

### Point 1: VeLa Component Not Creating Resource

**Chain:** VeLa App → (BREAK) → SimpleDynamoDB/Table

**Symptoms:**
- No SimpleDynamoDB resources: `kubectl get simpledynamodb -A` (empty)
- No Crossplane Table resources: `kubectl get table.dynamodb.aws.upbound.io -A` (empty)
- Applications deployed but unhealthy

**Check:**
```bash
vela status session-api-app-kro
# Look for component creation status
```

**Possible Causes:**
1. Component definition not deployed
2. VeLa component syntax error
3. Component parameters not provided

**Fix:**
```bash
vela def apply definitions/components/aws-dynamodb-simple-kro.cue
vela def apply definitions/components/aws-dynamodb-simple-xp.cue
```

---

### Point 2: KRO Not Converting SimpleDynamoDB to Table

**Chain:** SimpleDynamoDB → (BREAK) → ACK Table

**Symptoms:**
- SimpleDynamoDB exists: `kubectl get simpledynamodb -A` (has resources)
- No ACK Table resources: `kubectl get table.dynamodb.services.k8s.aws -A` (empty)
- KRO ResourceGraphDefinition exists

**Check:**
```bash
kubectl get resourcegraphdefinitions
kubectl logs -n kro-system -l app.kubernetes.io/instance=kro | grep -i simple
```

**Possible Causes:**
1. ResourceGraphDefinition deployed AFTER SimpleDynamoDB (ordering issue)
2. RGD not watching SimpleDynamoDB CRD
3. KRO controller not running

**Fix:**
```bash
# Redeploy in correct order: RGD first, then components
kubectl apply -f definitions/kro/simple-dynamodb-rgd.yaml
sleep 5
vela def apply definitions/components/aws-dynamodb-simple-kro.cue
```

---

### Point 3: ACK Controller Not Syncing Table to LocalStack

**Chain:** ACK Table → (BREAK) → LocalStack

**Symptoms:**
- ACK Table exists: `kubectl get table.dynamodb.services.k8s.aws -A` (has resources)
- No table in LocalStack: `aws dynamodb list-tables ...` (empty)
- ACK pod running but with errors

**Check:**
```bash
kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i error
kubectl get table.dynamodb.services.k8s.aws -A -o yaml | grep -A 20 status:
```

**Possible Causes:**
1. ACK not configured with LocalStack endpoint
2. Incorrect credentials
3. ACK controller networking issue

**Fix:**
```bash
# Reinstall ACK with correct configuration
./install-ack.sh
```

---

### Point 4: Crossplane Provider Not Syncing Table to LocalStack

**Chain:** Crossplane Table → (BREAK) → LocalStack

**Symptoms:**
- Crossplane Table exists: `kubectl get table.dynamodb.aws.upbound.io -A` (has resources)
- No table in LocalStack: `aws dynamodb list-tables ...` (empty)
- Crossplane pod running but with errors

**Check:**
```bash
kubectl logs -n crossplane-system -l app=crossplane | grep -i error
kubectl get providerconfig default -o yaml | grep endpoint
kubectl get table.dynamodb.aws.upbound.io -A -o yaml | grep -A 20 status:
```

**Possible Causes:**
1. ProviderConfig endpoint wrong
2. Credentials not configured
3. Crossplane controller networking issue

**Fix:**
```bash
# Update ProviderConfig with correct endpoint
kubectl delete providerconfig default 2>/dev/null || true
kubectl apply -f - <<'EOF'
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: localstack-credentials
      key: credentials
  endpoint:
    url:
      type: Static
      static: "http://localstack.localstack-system.svc.cluster.local:4566"
    hostnameImmutable: true
  skip_credentials_validation: true
  skip_requesting_account_id: true
  skip_metadata_api_check: true
  s3_use_path_style: true
EOF
```

---

## Control Plane Components

### LocalStack (Fake AWS)

```
┌─────────────────────────────────────────────┐
│  LocalStack                                 │
│  Namespace: localstack-system               │
│  Image: localstack/localstack:latest        │
│  Port: 4566 (edge service port)             │
│                                             │
│  Provides:                                  │
│  - DynamoDB emulation                       │
│  - Mock AWS credentials                     │
│  - API endpoint compatible with AWS SDK    │
└─────────────────────────────────────────────┘
```

### KubeVela (Component Platform)

```
┌─────────────────────────────────────────────┐
│  KubeVela                                   │
│  Namespace: vela-system                     │
│                                             │
│  Responsibilities:                          │
│  - Manage applications as OAM               │
│  - Create components from definitions       │
│  - Orchestrate component deployment         │
└─────────────────────────────────────────────┘
```

### Crossplane (Infrastructure as Code)

```
┌─────────────────────────────────────────────┐
│  Crossplane                                 │
│  Namespace: crossplane-system               │
│                                             │
│  Responsibilities:                          │
│  - Watch Table resources                    │
│  - Call AWS API via ProviderConfig          │
│  - Sync desired state to actual state       │
│  - Manage Table lifecycle                   │
└─────────────────────────────────────────────┘
```

### KRO (Kubernetes Resource Orchestration)

```
┌─────────────────────────────────────────────┐
│  KRO                                        │
│  Namespace: kro-system                      │
│                                             │
│  Responsibilities:                          │
│  - Watch SimpleDynamoDB resources           │
│  - Transform via ResourceGraphDefinition    │
│  - Create ACK Table resources               │
│  - Manage resource composition              │
└─────────────────────────────────────────────┘
```

### ACK (AWS Controllers for Kubernetes)

```
┌─────────────────────────────────────────────┐
│  ACK DynamoDB Controller                    │
│  Namespace: ack-system                      │
│                                             │
│  Responsibilities:                          │
│  - Watch DynamoDB Table resources           │
│  - Call DynamoDB API                        │
│  - Sync table state                         │
│  - Handle table lifecycle                   │
│  - Use LocalStack endpoint instead of AWS   │
└─────────────────────────────────────────────┘
```

## Data Flow

### Creating a KRO-based DynamoDB Table

```
1. User applies session-api-app-kro.yaml
   ↓
2. KubeVela reads application manifest
   ↓
3. KubeVela creates SimpleDynamoDB component instance
   ↓
4. KRO sees SimpleDynamoDB resource
   ↓
5. KRO applies ResourceGraphDefinition transformations
   ↓
6. KRO creates ACK Table resource
   ↓
7. ACK controller sees Table resource
   ↓
8. ACK reads ProviderConfig (default)
   ↓
9. ACK calls DynamoDB API at LocalStack endpoint
   ↓
10. LocalStack creates DynamoDB table
    ↓
11. ACK writes table status to Table resource
    ↓
12. Application can now access table via LocalStack
```

### Creating a Crossplane-based DynamoDB Table

```
1. User applies session-api-app-xp.yaml
   ↓
2. KubeVela reads application manifest
   ↓
3. KubeVela creates Table component instance
   ↓
4. Crossplane sees Table resource
   ↓
5. Crossplane reads ProviderConfig (default)
   ↓
6. Crossplane calls DynamoDB API at LocalStack endpoint
   ↓
7. LocalStack creates DynamoDB table
   ↓
8. Crossplane writes table status to Table resource
   ↓
9. Application can now access table via LocalStack
```

## Configuration Files

### Key Configuration Points

1. **LocalStack Endpoint** - Configured in:
   - ACK environment variables (Phase 6)
   - Crossplane ProviderConfig (Phase 4)
   - Application environment variables (app/session-api.py)

2. **AWS Credentials** - Configured in:
   - Kubernetes secrets (test/test)
   - ACK pod environment
   - Crossplane ProviderConfig

3. **Component Definitions** - Located in:
   - `definitions/components/*.cue` - VeLa component definitions
   - `definitions/kro/*.yaml` - KRO ResourceGraphDefinition
   - `definitions/examples/*.yaml` - Example applications

## Verification Steps

After complete setup, verify each layer:

```bash
# Layer 1: LocalStack running?
kubectl get pods -n localstack-system

# Layer 2: KubeVela deployed?
kubectl get pods -n vela-system

# Layer 3: Crossplane deployed?
kubectl get pods -n crossplane-system

# Layer 4: KRO deployed?
kubectl get pods -n kro-system

# Layer 5: ACK deployed?
kubectl get pods -n ack-system

# Layer 6: Components defined?
vela def ls | grep dynamodb

# Layer 7: Application deployed?
vela ls -A

# Layer 8: SimpleDynamoDB/Table resources created?
kubectl get simpledynamodb -A
kubectl get table.dynamodb.aws.upbound.io -A

# Layer 9: Table in LocalStack?
kubectl run -it --rm test --image=amazon/aws-cli --restart=Never -- \
  --endpoint-url=http://localstack.localstack-system.svc.cluster.local:4566 \
  --region=us-west-2 \
  dynamodb list-tables
```

## Troubleshooting by Layer

| Layer | Resource | Check | Fix |
|-------|----------|-------|-----|
| LocalStack | Pod | `kubectl get pods -n localstack-system` | `./setup.sh` |
| KubeVela | Pod | `kubectl get pods -n vela-system` | `./setup.sh` |
| Crossplane | Pod | `kubectl get pods -n crossplane-system` | `./setup.sh` |
| KRO | Pod | `kubectl get pods -n kro-system` | `./setup.sh` |
| ACK | Pod | `kubectl get pods -n ack-system` | `./install-ack.sh` |
| Components | Definitions | `vela def ls \| grep dynamodb` | `./setup.sh` |
| Application | Resources | `vela ls -A` | `vela up -f ...` |
| SimpleDynamoDB | Resource | `kubectl get simpledynamodb` | See DEBUGGING.md |
| Table (Crossplane) | Resource | `kubectl get table.dynamodb.aws.upbound.io` | See DEBUGGING.md |
| ACK Table | Resource | `kubectl get table.dynamodb.services.k8s.aws` | See DEBUGGING.md |
| LocalStack Table | Table | AWS CLI list-tables | See DEBUGGING.md |

