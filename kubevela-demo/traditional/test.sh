#!/bin/bash
# Traditional Approach - Test Script (Dagger Wrapper)
# Thin wrapper that calls Dagger pipeline for testing

set -e

ENVIRONMENT="${1:-dev}"

echo "=== Traditional Approach: API Testing (via Dagger) ==="
echo "Environment: $ENVIRONMENT"
echo ""

# Load AWS credentials
if [ -f "../../.env.aws" ]; then
    source ../../.env.aws
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    export AWS_DEFAULT_REGION
fi

# Run Dagger test function
export ENVIRONMENT="$ENVIRONMENT"

cd dagger
go run main.go test
