#!/bin/bash
# Traditional Approach - Acceptance Testing
# This script runs functional API tests against the deployed application

set -e

ENVIRONMENT="${1:-dev}"

echo "=== Traditional Approach - API Acceptance Testing ==="
echo "Environment: ${ENVIRONMENT}"
echo ""

# Check if namespace exists
if ! kubectl get namespace ${ENVIRONMENT} &>/dev/null; then
    echo "Error: Namespace ${ENVIRONMENT} does not exist"
    echo "Please deploy the application first with: ./deploy-local.sh ${ENVIRONMENT}"
    exit 1
fi

# Check if service exists
if ! kubectl get service product-catalog-api -n ${ENVIRONMENT} &>/dev/null; then
    echo "Error: Service product-catalog-api not found in namespace ${ENVIRONMENT}"
    echo "Please deploy the application first with: ./deploy-local.sh ${ENVIRONMENT}"
    exit 1
fi

SERVICE_URL="http://product-catalog-api.${ENVIRONMENT}.svc.cluster.local"

# Test 1: Health check
echo "Test 1: Health Check"
echo "  Checking /health endpoint..."

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl run test-health-$$-$RETRY_COUNT --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
        curl -f -s "${SERVICE_URL}/health" > /dev/null 2>&1; then
        echo "  ✓ Health check passed"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "  ✗ Health check failed after ${MAX_RETRIES} attempts"
        exit 1
    fi
    echo "  Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

# Test 2: Readiness check
echo ""
echo "Test 2: Readiness Check"
echo "  Checking /ready endpoint..."

READY_RESPONSE=$(kubectl run test-ready-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" "${SERVICE_URL}/ready")

READY_HTTP_CODE=$(echo "$READY_RESPONSE" | tail -n1)

if [ "$READY_HTTP_CODE" != "200" ]; then
    echo "  ✗ Readiness check failed with HTTP ${READY_HTTP_CODE}"
    exit 1
fi

echo "  ✓ Readiness check passed"

# Test 3: List products (initial state)
echo ""
echo "Test 3: List Products"
echo "  Testing GET /products..."

LIST_RESPONSE=$(kubectl run test-list-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" "${SERVICE_URL}/products")

LIST_HTTP_CODE=$(echo "$LIST_RESPONSE" | tail -n1)

if [ "$LIST_HTTP_CODE" != "200" ]; then
    echo "  ✗ List products failed with HTTP ${LIST_HTTP_CODE}"
    exit 1
fi

echo "  ✓ List products succeeded"

# Test 4: Create a product (POST)
echo ""
echo "Test 4: Create Product"
echo "  Testing POST /products..."

CREATE_RESPONSE=$(kubectl run test-create-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -X POST "${SERVICE_URL}/products" \
    -H "Content-Type: application/json" \
    -d '{"name":"acceptance-test-product","description":"Automated acceptance test","price":99.99}')

if [ $? -ne 0 ]; then
    echo "  ✗ POST request failed"
    exit 1
fi

# Extract product ID from response
PRODUCT_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PRODUCT_ID" ]; then
    echo "  ✗ Failed to extract product ID from response"
    echo "  Response: $CREATE_RESPONSE"
    exit 1
fi

echo "  ✓ Product created successfully"
echo "  Product ID: $PRODUCT_ID"

# Test 5: Retrieve the product (GET)
echo ""
echo "Test 5: Retrieve Product"
echo "  Testing GET /products/${PRODUCT_ID}..."

GET_RESPONSE=$(kubectl run test-get-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" "${SERVICE_URL}/products/${PRODUCT_ID}")

HTTP_CODE=$(echo "$GET_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$GET_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "  ✗ GET request failed with HTTP ${HTTP_CODE}"
    echo "  Response: $RESPONSE_BODY"
    exit 1
fi

# Verify the retrieved product matches
RETRIEVED_ID=$(echo "$RESPONSE_BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
RETRIEVED_NAME=$(echo "$RESPONSE_BODY" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

if [ "$RETRIEVED_ID" != "$PRODUCT_ID" ]; then
    echo "  ✗ Product ID mismatch: expected $PRODUCT_ID, got $RETRIEVED_ID"
    exit 1
fi

if [ "$RETRIEVED_NAME" != "acceptance-test-product" ]; then
    echo "  ✗ Product name mismatch: expected 'acceptance-test-product', got '$RETRIEVED_NAME'"
    exit 1
fi

echo "  ✓ Product retrieved successfully"
echo "  Verified: ID=$RETRIEVED_ID, Name=$RETRIEVED_NAME"

# Test 6: Delete the product (DELETE)
echo ""
echo "Test 6: Delete Product"
echo "  Testing DELETE /products/${PRODUCT_ID}..."

DELETE_RESPONSE=$(kubectl run test-delete-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" -X DELETE "${SERVICE_URL}/products/${PRODUCT_ID}")

DELETE_HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)

if [ "$DELETE_HTTP_CODE" != "200" ]; then
    echo "  ✗ DELETE request failed with HTTP ${DELETE_HTTP_CODE}"
    exit 1
fi

echo "  ✓ Product deleted successfully"

# Test 7: Verify product is gone (GET should return 404)
echo ""
echo "Test 7: Verify Deletion"
echo "  Testing GET /products/${PRODUCT_ID} (should return 404)..."

VERIFY_RESPONSE=$(kubectl run test-verify-$$ --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" "${SERVICE_URL}/products/${PRODUCT_ID}")

VERIFY_HTTP_CODE=$(echo "$VERIFY_RESPONSE" | tail -n1)

if [ "$VERIFY_HTTP_CODE" != "404" ]; then
    echo "  ✗ Expected 404 but got HTTP ${VERIFY_HTTP_CODE}"
    exit 1
fi

echo "  ✓ Product deletion verified (404 as expected)"

echo ""
echo "=== All Acceptance Tests Passed ==="
echo ""
echo "Summary:"
echo "  ✓ Health check"
echo "  ✓ Readiness check"
echo "  ✓ List products"
echo "  ✓ Create product (POST)"
echo "  ✓ Retrieve product (GET)"
echo "  ✓ Delete product (DELETE)"
echo "  ✓ Verify deletion (404)"
echo ""
echo "Total: 7 tests passed"
echo ""
