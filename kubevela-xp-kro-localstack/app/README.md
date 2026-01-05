# Session Management API

A Flask-based REST API for managing user sessions with AWS DynamoDB, featuring automatic TTL expiration.

## Features

- **Session Management**: Create, read, update, and delete user sessions
- **Automatic Expiration**: Sessions automatically expire using DynamoDB TTL
- **Health Checks**: Built-in health and readiness probes for Kubernetes
- **User Session Lookup**: Query all sessions for a specific user
- **Admin Endpoints**: List all active sessions

## Architecture

```
┌─────────────────┐
│  Session API    │ ←→ DynamoDB Table
│  (Flask App)    │     (user-sessions)
└─────────────────┘
```

## API Endpoints

### Health & Readiness

- `GET /health` - Health check
- `GET /ready` - Readiness check (verifies DynamoDB connectivity)

### Session Operations

- `POST /sessions` - Create a new session
  ```json
  {
    "userId": "user123",
    "data": {
      "theme": "dark",
      "language": "en"
    }
  }
  ```

- `GET /sessions/<session_id>` - Get a session by ID

- `PUT /sessions/<session_id>` - Update a session's data
  ```json
  {
    "data": {
      "theme": "light",
      "language": "es"
    }
  }
  ```

- `DELETE /sessions/<session_id>` - Delete a session

- `GET /sessions/user/<user_id>` - Get all sessions for a user

- `GET /sessions` - List all active sessions (admin)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DYNAMODB_TABLE_NAME` | DynamoDB table name | `tenant-atlantis-user-sessions` |
| `AWS_REGION` | AWS region | `us-west-2` |
| `SESSION_TTL_HOURS` | Session TTL in hours | `24` |
| `PORT` | Server port | `8080` |

## Local Development

### Prerequisites

- Python 3.11+
- AWS credentials configured
- DynamoDB table created

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DYNAMODB_TABLE_NAME=tenant-atlantis-user-sessions
export AWS_REGION=us-west-2
export SESSION_TTL_HOURS=24

# Run the application
python session-api.py
```

### Test the API

```bash
# Health check
curl http://localhost:8080/health

# Create a session
curl -X POST http://localhost:8080/sessions \
  -H "Content-Type: application/json" \
  -d '{"userId": "user123", "data": {"theme": "dark"}}'

# Get a session (replace SESSION_ID)
curl http://localhost:8080/sessions/SESSION_ID

# List all sessions
curl http://localhost:8080/sessions
```

## Docker Build

```bash
# Build the image
docker build -t session-api:v1.0.0 .

# Run the container
docker run -p 8080:8080 \
  -e DYNAMODB_TABLE_NAME=tenant-atlantis-user-sessions \
  -e AWS_REGION=us-west-2 \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  session-api:v1.0.0
```

## Kubernetes Deployment with KubeVela

### Deploy with KubeVela

```bash
# Build and load image into k3d
docker build -t session-api:v1.0.0 .
k3d image import session-api:v1.0.0 -c kubevela-demo

# Deploy the application (includes DynamoDB table + API)
kubectl apply -f ../definitions/examples/session-management-app.yaml

# Check status
vela status session-management

# Check components
kubectl get simpledynamodb
kubectl get table.dynamodb.services.k8s.aws
kubectl get pods -l app.oam.dev/component=session-api
```

### Access the API

```bash
# Port forward to access locally
kubectl port-forward svc/session-api 8080:8080

# Test the API
curl http://localhost:8080/health
```

## DynamoDB Table Schema

The application expects a DynamoDB table with:

- **Partition Key**: `id` (String) - Session ID
- **TTL Attribute**: `ttl` (Number) - Unix timestamp for automatic expiration
- **Billing Mode**: PAY_PER_REQUEST

The table is automatically created by KubeVela using the `aws-dynamodb-simple-kro` component.

## Session Data Structure

Sessions are stored with the following attributes:

```json
{
  "id": "session-user123-1234567890",
  "userId": "user123",
  "data": "{\"theme\": \"dark\", \"language\": \"en\"}",
  "createdAt": "2025-12-24T10:00:00.000000",
  "ttl": 1735142400
}
```

## Error Handling

- `400` - Bad Request (missing required fields)
- `404` - Session Not Found
- `410` - Session Expired (Gone)
- `500` - Internal Server Error
- `503` - Service Unavailable (DynamoDB not ready)

## Security Considerations

1. **AWS Credentials**: Use IAM roles for service accounts (IRSA) in production
2. **Network Policies**: Restrict access to the API using Kubernetes NetworkPolicies
3. **Authentication**: Add authentication/authorization middleware for production use
4. **Rate Limiting**: Implement rate limiting to prevent abuse
5. **Input Validation**: Always validate and sanitize user input

## Monitoring

The application logs all operations to stdout with structured logging:

```
INFO:__main__:Created session session-user123-1234567890 for user user123
INFO:__main__:Updated session session-user123-1234567890
INFO:__main__:Deleted session session-user123-1234567890
```

## Troubleshooting

### Application can't connect to DynamoDB

**Check**: AWS credentials and network connectivity
```bash
kubectl logs -l app.oam.dev/component=session-api
```

### Sessions not expiring

**Check**: DynamoDB TTL is enabled on the `ttl` attribute
```bash
aws dynamodb describe-time-to-live \
  --table-name tenant-atlantis-user-sessions \
  --region us-west-2
```

### Application stuck in "Not Ready"

**Check**: DynamoDB table status
```bash
kubectl get table.dynamodb.services.k8s.aws user-sessions -o yaml
```
