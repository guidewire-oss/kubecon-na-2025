# AWS CDK + LocalStack Integration Guide

**Reference:** https://github.com/aws-samples/localstack-aws-cdk-example

This guide explains how to integrate AWS CDK with LocalStack for local infrastructure development.

---

## Overview

AWS CDK (Cloud Development Kit) with LocalStack enables:
- **Write Once, Deploy Twice**: Same code deploys locally via LocalStack and to AWS
- **Local Development**: No AWS account needed for development
- **Cost-Free Testing**: Develop and test infrastructure locally
- **Production Parity**: Test exact infrastructure code before cloud deployment

---

## Architecture

```
TypeScript/Python CDK Code
    ↓
cdklocal (LocalStack CDK wrapper)
    ↓
CloudFormation
    ↓
LocalStack Services (DynamoDB, Lambda, etc.)
```

vs.

```
TypeScript/Python CDK Code
    ↓
cdk (AWS CDK CLI)
    ↓
CloudFormation
    ↓
AWS Services (DynamoDB, Lambda, etc.)
```

**Same code, different deployment target.**

---

## Setup Requirements

### Prerequisites
```bash
# Docker (for LocalStack)
docker --version

# Node.js and TypeScript
npm install -g typescript

# AWS CDK
npm install -g aws-cdk

# LocalStack tools
npm install -g @localstack/core
pip install localstack awslocal cdklocal
```

### LocalStack Startup
```bash
# Start LocalStack (if not already running)
localstack start -d

# Check status
awslocal dynamodb list-tables
```

---

## Key Development Patterns

### 1. Unified Code, Conditional Logic

Instead of separate codebases for local vs cloud, use TypeScript to conditionally configure:

```typescript
import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';

export class MyStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const isLocalStack = process.env.ENVIRONMENT === 'localstack';

    // Same DynamoDB table definition for both local and cloud
    const table = new dynamodb.Table(this, 'SessionTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Conditional endpoint configuration (if needed)
    if (isLocalStack) {
      // LocalStack-specific configuration
      table.addGlobalSecondaryIndex({
        indexName: 'userIdIndex',
        partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      });
    }
  }
}
```

### 2. Nested Stacks for Large Deployments

For deployments exceeding CloudFormation's 500-resource limit:

```typescript
// Parent Stack
export class ParentStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Infrastructure split by domain
    new DatabaseStack(this, 'DatabaseStack');
    new ComputeStack(this, 'ComputeStack');
    new ApiStack(this, 'ApiStack');
  }
}

// Individual Nested Stack
export class DatabaseStack extends cdk.NestedStack {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.table = new dynamodb.Table(this, 'DynamoDBTable', {
      // ... table definition
    });
  }
}
```

### 3. Code Organization

Organize infrastructure by technical concern:

```
cdk/
├── stacks/
│   ├── database-stack.ts      # Database resources
│   ├── compute-stack.ts       # Lambda, containers, etc.
│   ├── networking-stack.ts    # VPC, subnets, etc.
│   └── api-stack.ts           # API Gateway, etc.
├── constructs/
│   ├── session-table.ts       # Reusable DynamoDB construct
│   ├── api-handler.ts         # Reusable Lambda construct
│   └── database.ts            # Database patterns
├── app.ts                      # Main CDK App
└── cdk.json                    # CDK config
```

Each file exports reusable constructs that compose into stacks.

### 4. Hot Reload Development

LocalStack supports hot reload for Lambda functions:

```bash
# Deploy with hot reload enabled
cdklocal deploy --profile localstack

# Change your Lambda code
# Changes automatically reflect without redeployment
# Verify with:
awslocal lambda get-function --function-name MyFunction
```

---

## Deployment Workflow

### Local Development
```bash
# Set environment to LocalStack
export ENVIRONMENT=localstack

# Ensure LocalStack is running
localstack start -d

# Synthesize CDK (generate CloudFormation)
cdklocal synth

# Deploy to LocalStack
cdklocal deploy

# Verify deployment
awslocal dynamodb describe-table --table-name SessionTable
awslocal lambda list-functions
```

### AWS Deployment
```bash
# Switch to AWS
unset ENVIRONMENT

# Configure AWS credentials
export AWS_PROFILE=default

# Synthe size for AWS
cdk synth

# Deploy to AWS
cdk deploy

# Verify deployment
aws dynamodb describe-table --table-name SessionTable
aws lambda list-functions
```

---

## Integration with KubeCon Demo

### Option 1: CDK-Generated Manifests for KRO

Generate Kubernetes-compatible manifests from CDK:

```typescript
// CDK generates CloudFormation → Convert to KRO RGD
export class CDKToKROBridge extends cdk.Stack {
  constructor(scope: cdk.App, id: string) {
    super(scope, id);

    // CDK definitions
    const table = new dynamodb.Table(this, 'Table', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
    });

    // Export as KRO ResourceGraphDefinition input
    new cdk.CfnOutput(this, 'TableArn', { value: table.tableArn });
    new cdk.CfnOutput(this, 'TableName', { value: table.tableName });
  }
}
```

### Option 2: Parallel Deployment

Run both CDK (LocalStack) and KRO (Kubernetes) stacks:

```bash
# Terminal 1: CDK LocalStack
export ENVIRONMENT=localstack
cdklocal deploy --profile localstack

# Terminal 2: KRO Kubernetes
export KUBECONFIG=./kubeconfig-host
vela up -f definitions/examples/session-api-app-kro.yaml
```

Both stacks provision DynamoDB tables independently, useful for comparison.

### Option 3: CDK Lambda Layer for KRO

Use CDK to build Lambda layers deployable to KRO:

```typescript
export class LambdaLayerStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string) {
    super(scope, id);

    // Create reusable layer
    const sharedLayer = new lambda.LayerVersion(this, 'SharedLayer', {
      code: lambda.Code.fromAsset('layers/shared'),
      compatibleRuntimes: [lambda.Runtime.NODEJS_18_X],
    });

    // Use in Lambda function
    const fn = new lambda.Function(this, 'SessionHandler', {
      runtime: lambda.Runtime.NODEJS_18_X,
      code: lambda.Code.fromAsset('handlers'),
      handler: 'sessions.handler',
      layers: [sharedLayer],
    });
  }
}
```

---

## Comparing CDK vs KRO vs ACK

| Aspect | CDK | KRO | ACK |
|--------|-----|-----|-----|
| Language | TypeScript/Python | YAML | YAML |
| Deployment Target | AWS / LocalStack | Kubernetes | Kubernetes |
| State Management | CloudFormation | Kubernetes CRDs | Kubernetes CRDs |
| Learning Curve | Moderate | Steep | Moderate |
| Infrastructure-as-Code | Yes | Yes | Yes |
| Local Development | LocalStack | Kubernetes | Kubernetes |
| Production Ready | Yes | Alpha | Yes |

### When to Use Each

- **CDK**: AWS-focused, programmatic IaC, strong typing
- **KRO**: Kubernetes-native, multi-cloud via CRDs, orchestration-focused
- **ACK**: AWS resources as Kubernetes objects, kubectl-friendly

---

## Example: Session API with CDK + LocalStack

### CDK Stack Definition

```typescript
import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';

export class SessionAPIStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // DynamoDB Table
    const sessionsTable = new dynamodb.Table(this, 'SessionsTable', {
      partitionKey: {
        name: 'sessionId',
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Lambda Handler
    const handler = new lambda.Function(this, 'SessionHandler', {
      runtime: lambda.Runtime.NODEJS_18_X,
      code: lambda.Code.fromAsset('handlers'),
      handler: 'sessions.handler',
      environment: {
        TABLE_NAME: sessionsTable.tableName,
      },
    });

    sessionsTable.grantReadWriteData(handler);

    // API Gateway
    const api = new apigateway.RestApi(this, 'SessionAPI', {
      restApiName: 'Session Service',
    });

    const sessionResource = api.root.addResource('sessions');
    const integration = new apigateway.LambdaIntegration(handler);

    sessionResource.addMethod('GET', integration);
    sessionResource.addMethod('POST', integration);

    // Outputs
    new cdk.CfnOutput(this, 'APIEndpoint', {
      value: api.url,
      description: 'Session API Endpoint',
    });

    new cdk.CfnOutput(this, 'TableName', {
      value: sessionsTable.tableName,
      description: 'DynamoDB Table Name',
    });
  }
}

// App
const app = new cdk.App();
new SessionAPIStack(app, 'SessionAPIStack');
app.synth();
```

### Deployment

```bash
# Local with LocalStack
export ENVIRONMENT=localstack
cdklocal deploy

# To AWS
cdk deploy
```

**Same code, different targets.**

---

## Troubleshooting

### LocalStack Not Responding
```bash
# Check LocalStack status
localstack logs

# Restart LocalStack
localstack stop && localstack start -d
```

### CDK Deploy Fails
```bash
# Clear CloudFormation cache
rm -rf cdk.out

# Synthesize and deploy
cdklocal synth
cdklocal deploy --profile localstack
```

### Table Already Exists
```bash
# LocalStack keeps state; delete if needed
awslocal dynamodb delete-table --table-name SessionTable

# Or use RemovalPolicy.DESTROY in CDK
```

---

## Conclusion

CDK + LocalStack provides:
- ✓ Write-once infrastructure code
- ✓ Local development without AWS account
- ✓ Production-like testing
- ✓ Faster feedback loop
- ✓ Lower development costs

Perfect for KubeCon demo showing multiple infrastructure paradigms (CDK, KRO, ACK, Kratix).

---

## Resources

- **LocalStack AWS CDK Example**: https://github.com/aws-samples/localstack-aws-cdk-example
- **AWS CDK Documentation**: https://docs.aws.amazon.com/cdk/
- **LocalStack Documentation**: https://docs.localstack.cloud/
- **cdklocal Tool**: https://github.com/localstack/aws-cdk-local
