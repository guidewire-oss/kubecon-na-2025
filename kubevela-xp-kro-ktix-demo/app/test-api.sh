#!/bin/bash

# Test script for Session Management API
# Usage: ./test-api.sh [API_URL]

set -e

API_URL="${1:-http://localhost:8080}"

echo "🧪 Testing Session Management API at ${API_URL}"
echo ""

# Test 1: Health check
echo "✅ Test 1: Health Check"
curl -s "${API_URL}/health" | jq '.'
echo ""

# Test 2: Readiness check
echo "✅ Test 2: Readiness Check"
curl -s "${API_URL}/ready" | jq '.'
echo ""

# Test 3: Create a session
echo "✅ Test 3: Create Session"
SESSION_RESPONSE=$(curl -s -X POST "${API_URL}/sessions" \
  -H "Content-Type: application/json" \
  -d '{"userId": "testuser123", "data": {"theme": "dark", "language": "en", "notifications": true}}')
echo "$SESSION_RESPONSE" | jq '.'
SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.sessionId')
if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
  echo "❌ Failed to create session: sessionId not found in response"
  exit 1
fi
echo "Created session ID: ${SESSION_ID}"
echo ""

# Test 4: Get the session
echo "✅ Test 4: Get Session"
curl -s "${API_URL}/sessions/${SESSION_ID}" | jq '.'
echo ""

# Test 5: Update the session
echo "✅ Test 5: Update Session"
curl -s -X PUT "${API_URL}/sessions/${SESSION_ID}" \
  -H "Content-Type: application/json" \
  -d '{"data": {"theme": "light", "language": "es", "notifications": false}}' | jq '.'
echo ""

# Test 6: Get updated session
echo "✅ Test 6: Get Updated Session"
curl -s "${API_URL}/sessions/${SESSION_ID}" | jq '.'
echo ""

# Test 7: Create another session for the same user
echo "✅ Test 7: Create Second Session for Same User"
SESSION_RESPONSE_2=$(curl -s -X POST "${API_URL}/sessions" \
  -H "Content-Type: application/json" \
  -d '{"userId": "testuser123", "data": {"theme": "auto", "language": "fr"}}')
echo "$SESSION_RESPONSE_2" | jq '.'
SESSION_ID_2=$(echo "$SESSION_RESPONSE_2" | jq -r '.sessionId')
if [ -z "$SESSION_ID_2" ] || [ "$SESSION_ID_2" = "null" ]; then
  echo "❌ Failed to create second session: sessionId not found in response"
  exit 1
fi
echo ""

# Test 8: Get all sessions for user
echo "✅ Test 8: Get All Sessions for User"
curl -s "${API_URL}/sessions/user/testuser123" | jq '.'
echo ""

# Test 9: List all sessions
echo "✅ Test 9: List All Sessions"
curl -s "${API_URL}/sessions" | jq '.'
echo ""

# Test 10: Delete first session
echo "✅ Test 10: Delete Session"
curl -s -X DELETE "${API_URL}/sessions/${SESSION_ID}" | jq '.'
echo ""

# Test 11: Try to get deleted session (should fail)
echo "✅ Test 11: Try to Get Deleted Session (Should Return 404)"
curl -s -w "\nHTTP Status: %{http_code}\n" "${API_URL}/sessions/${SESSION_ID}"
echo ""

# Test 12: Cleanup - delete second session
echo "✅ Test 12: Cleanup - Delete Second Session"
curl -s -X DELETE "${API_URL}/sessions/${SESSION_ID_2}" | jq '.'
echo ""

echo "✅ All tests completed!"
