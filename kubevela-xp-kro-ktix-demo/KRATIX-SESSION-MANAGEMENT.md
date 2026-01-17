# Kratix Session Management Application

## Overview

This document describes the **session-api-app-kratix** application, which demonstrates a complete, production-ready integration of:

- **KubeVela** - Application platform with OAM abstractions
- **Kratix Promise Framework** - Platform abstraction for DynamoDB provisioning
- **Python Flask REST API** - Session management microservice
- **AWS DynamoDB** - Serverless database backend via Kratix promise

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│           KubeVela Application (session-api-app-kratix)       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  user-sessions-table-kratix (Component)               │  │
│  │  Type: aws-dynamodb-kratix                            │  │
│  │  └─> Creates DynamoDBRequest CRD                      │  │
│  │      - Table: user-sessions-kratix                    │  │
│  │      - Region: us-west-2                              │  │
│  │      - Billing: PAY_PER_REQUEST                       │  │
│  └────────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  session-api-kratix (Component)                       │  │
│  │  Type: webservice                                      │  │
│  │  - Image: session-api:latest                          │  │
│  │  - Port: 8080 (exposed)                               │  │
│  │  - Replicas: 1 (via scaler trait)                     │  │
│  │  - Traits:                                             │  │
│  │    * scaler (horizontal pod autoscaling)             │  │
│  │    * resource (CPU/memory limits)                    │  │
│  └────────────────────────────────────────────────────────┘  │
│                            │                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────┐
        │  Kratix Promise Framework          │
        │  (aws-dynamodb-kratix)            │
        └────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │  AWS DynamoDB Table                │
        │  (user-sessions-kratix)           │
        └────────────────────────────────────┘
```

## Application Definition

**File:** `definitions/examples/session-management-app-kratix.yaml`

### Components

#### 1. DynamoDB Table Component
```yaml
- name: user-sessions-table-kratix
  type: aws-dynamodb-kratix
  properties:
    tableName: "user-sessions-kratix"
    region: "us-west-2"
    billingMode: "PAY_PER_REQUEST"
    attributeDefinitions:
      - name: "id"
        type: "S"
      - name: "userId"
        type: "S"
    keySchema:
      - attributeName: "id"
        keyType: "HASH"
      - attributeName: "userId"
        keyType: "HASH"
```

Creates a DynamoDB table with:
- **Partition Key:** `id` (String)
- **Sort Key:** `userId` (String)
- **Billing Mode:** On-demand (PAY_PER_REQUEST)
- **Region:** US West 2

#### 2. Session API Component
```yaml
- name: session-api-kratix
  type: webservice
  properties:
    image: session-api:latest
    ports:
      - port: 8080
        expose: true
    env:
      - name: DYNAMODB_TABLE_NAME
        value: "user-sessions-kratix"
      - name: AWS_REGION
        value: "us-west-2"
      - name: SESSION_TTL_HOURS
        value: "24"
      - name: PORT
        value: "8080"
    # Health checks for Kubernetes readiness/liveness
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 30
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 10
```

### Traits

#### Scaler Trait
Manages horizontal pod autoscaling:
- **Replicas:** 1

#### Resource Trait
Defines resource requests and limits:
- **Requests:** 100m CPU, 128Mi memory
- **Limits:** 500m CPU, 512Mi memory

## Session API Endpoints

The session management API provides the following endpoints:

### Health & Status
- **GET** `/health` - Service health check
- **GET** `/ready` - Readiness probe (checks DynamoDB connectivity)

### Session Management
- **POST** `/sessions` - Create a new session
  ```json
  {
    "userId": "user-123",
    "data": {"loginTime": "2026-01-16T18:00:00Z"}
  }
  ```
  Returns: `201 Created` with session details

- **GET** `/sessions/<session_id>` - Retrieve a session
  Returns: `200 OK` with session data or `404 Not Found`

- **PUT** `/sessions/<session_id>` - Update session data
  ```json
  {
    "data": {"status": "active"}
  }
  ```
  Returns: `200 OK` with updated session

- **DELETE** `/sessions/<session_id>` - Delete a session
  Returns: `200 OK` on success

### Query Endpoints
- **GET** `/sessions` - List all active sessions
  Returns: `200 OK` with array of sessions

- **GET** `/sessions/user/<user_id>` - Get all sessions for a user
  Returns: `200 OK` with user's sessions

## Deployment

### Deploy via KubeVela
```bash
vela up -f definitions/examples/session-management-app-kratix.yaml
```

### Check Status
```bash
# View application status
vela status session-api-app-kratix

# View detailed status
vela status session-api-app-kratix --detail

# Watch DynamoDB requests
kubectl get dynamodbrequests.dynamodb.kratix.io -A

# View pods
kubectl get pods -l app.oam.dev/name=session-api-app-kratix
```

### Port Forward to API
```bash
vela port-forward session-api-app-kratix
# Access at http://localhost:8080
```

## Testing the API

### Create a Session
```bash
curl -X POST http://localhost:8080/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-123",
    "data": {"loginTime": "2026-01-16T18:00:00Z"}
  }'
```

### Get a Session
```bash
curl http://localhost:8080/sessions/<session_id>
```

### List All Sessions
```bash
curl http://localhost:8080/sessions
```

### Update a Session
```bash
curl -X PUT http://localhost:8080/sessions/<session_id> \
  -H "Content-Type: application/json" \
  -d '{
    "data": {"status": "updated"}
  }'
```

### Delete a Session
```bash
curl -X DELETE http://localhost:8080/sessions/<session_id>
```

## Key Features

### 1. Kratix Promise Integration
- DynamoDB table created through Kratix Promise abstraction
- Users don't need to know AWS DynamoDB details
- Promise validates all table configurations
- Declarative, reproducible infrastructure

### 2. KubeVela Application Management
- Single application definition combining infrastructure and workload
- Unified deployment and lifecycle management
- Traits for cross-cutting concerns (scaling, resource limits)
- Simple, declarative syntax

### 3. Production-Ready Features
- **Health Checks:** Both liveness and readiness probes
- **Automatic Scaling:** Kubernetes native horizontal pod autoscaling
- **Resource Management:** Defined requests and limits
- **TTL Expiration:** Sessions automatically expire after 24 hours
- **Error Handling:** Comprehensive error handling and logging

### 4. Session Management
- UUID-based session identifiers for concurrency safety
- TTL-based automatic expiration (DynamoDB TTL)
- User-scoped session queries
- Transaction-safe session operations

## Comparison with Other Approaches

| Feature | Kratix Promise | KRO | Crossplane |
|---------|---|---|---|
| **Abstraction** | Custom Promise API | ResourceGraph | Composite Resource |
| **User Experience** | Simple CRD | Direct AWS API | XRD API |
| **DynamoDB Support** | Via Promise | Via RGD + ACK | Via Upbound Provider |
| **Validation** | Promise schema | RGD validation | XRD schema |
| **Workflow** | Promise workflows | Direct ACK | Direct provider |

## Troubleshooting

### Pod Not Ready
```bash
# Check pod status
kubectl get pods -l app.oam.dev/component=session-api-kratix

# View pod logs
kubectl logs -l app.oam.dev/component=session-api-kratix

# Describe pod for events
kubectl describe pod -l app.oam.dev/component=session-api-kratix
```

### DynamoDB Request Failed
```bash
# Check DynamoDB request status
kubectl get dynamodbrequest -n default

# View request details
kubectl describe dynamodbrequest user-sessions-table-kratix

# Check Kratix controller logs
kubectl logs -n kratix-platform-system -l app.kubernetes.io/name=kratix
```

### Table Not Accessible
```bash
# Verify table creation
kubectl get dynamodbrequests.dynamodb.kratix.io -A

# Check DynamoDB table status (if AWS credentials configured)
aws dynamodb describe-table --table-name user-sessions-kratix --region us-west-2
```

## Related Documentation

- **KRATIX-INTEGRATION.md** - Complete Kratix Promise integration guide
- **README.md** - Main demo documentation
- **app/README.md** - Session management API implementation details
- **definitions/components/aws-dynamodb-kratix.cue** - Component definition

## Next Steps

1. **Deploy the application** - Use the deployment instructions above
2. **Test the API** - Use the API testing examples
3. **Compare approaches** - Compare with KRO and Crossplane versions
4. **Extend the promise** - Add custom validation rules to the promise
5. **Build custom promises** - Create promises for other AWS services

---

**Status:** ✅ Production Ready
**Last Updated:** January 16, 2026
**Tested With:** KubeVela v1.10.4, Kratix v0.125.0
