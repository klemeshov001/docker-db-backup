#!/bin/bash

# Test script for Yandex Lockbox integration
echo "Testing Yandex Lockbox integration..."

# Set environment
export YANDEX_LOCKBOX_SECRET_IDS="test-secret-1, test-secret-2"
export YANDEX_LOCKBOX_AUTH_TYPE="metadata"
export YANDEX_LOCKBOX_METADATA_URL="http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token"
export YANDEX_LOCKBOX_API_URL="https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets"
export DEBUG_YANDEX_LOCKBOX="TRUE"

# Mock functions
print_notice() { echo "[NOTICE] $1"; }
print_debug() { echo "[DEBUG] $1"; }
print_error() { echo "[ERROR] $1"; }
print_warn() { echo "[WARN] $1"; }
var_true() { [[ "${1,,}" =~ ^(true|yes|1|on)$ ]]; }
debug() { :; }

# Load functions
source ../../install/assets/functions/09-yandex-lockbox
source ../../install/assets/defaults/09-yandex-lockbox

echo "Environment variables:"
echo "  YANDEX_LOCKBOX_SECRET_IDS: $YANDEX_LOCKBOX_SECRET_IDS"
echo "  YANDEX_LOCKBOX_AUTH_TYPE: $YANDEX_LOCKBOX_AUTH_TYPE"
echo "  YANDEX_LOCKBOX_METADATA_URL: $YANDEX_LOCKBOX_METADATA_URL"
echo "  YANDEX_LOCKBOX_API_URL: $YANDEX_LOCKBOX_API_URL"
echo "  DEBUG_YANDEX_LOCKBOX: $DEBUG_YANDEX_LOCKBOX"

echo -e "\n--- Testing connectivity ---"
if test_yandex_lockbox_connectivity; then
    echo "✓ Yandex Lockbox connectivity test passed"
else
    echo "✗ Yandex Lockbox connectivity test failed"
    echo "Note: This is expected if not running in Yandex Cloud"
fi

echo -e "\n--- Testing IAM token retrieval ---"
iam_token=$(get_iam_token)
if [ $? -eq 0 ] && [ -n "$iam_token" ]; then
    echo "✓ IAM token retrieved successfully"
    echo "  Token preview: ${iam_token:0:20}..."
else
    echo "✗ IAM token retrieval failed"
    echo "Note: This is expected if not running in Yandex Cloud"
fi

echo -e "\n--- Testing secret loading ---"
echo "Note: This will fail if not running in Yandex Cloud with proper IAM permissions"
load_yandex_lockbox_secrets

echo -e "\n--- Testing individual secret retrieval ---"
echo "Testing with invalid secret ID (should fail gracefully):"
if get_secret "invalid-secret-id"; then
    echo "✓ Secret retrieval succeeded (unexpected)"
else
    echo "✗ Secret retrieval failed (expected)"
fi

echo -e "\n--- Testing with empty secret IDs ---"
export YANDEX_LOCKBOX_SECRET_IDS=""
if load_yandex_lockbox_secrets; then
    echo "✓ Empty secret IDs handled correctly"
else
    echo "✗ Empty secret IDs not handled correctly"
fi

echo -e "\n--- Testing with whitespace in secret IDs ---"
export YANDEX_LOCKBOX_SECRET_IDS="  secret1  ,  secret2  "
echo "Secret IDs with whitespace: '$YANDEX_LOCKBOX_SECRET_IDS'"
load_yandex_lockbox_secrets

echo -e "\n--- Testing key authentication ---"
echo "Testing with key authentication (should fail without valid key):"
export YANDEX_LOCKBOX_AUTH_TYPE="key"
export YANDEX_LOCKBOX_SERVICE_ACCOUNT_KEY=""
if test_yandex_lockbox_connectivity; then
    echo "✓ Key authentication test passed (unexpected)"
else
    echo "✗ Key authentication test failed (expected without valid key)"
fi

echo -e "\n--- Testing invalid authentication type ---"
echo "Testing with invalid authentication type:"
export YANDEX_LOCKBOX_AUTH_TYPE="invalid"
if test_yandex_lockbox_connectivity; then
    echo "✓ Invalid auth type test passed (unexpected)"
else
    echo "✗ Invalid auth type test failed (expected)"
fi

echo -e "\nTest completed!"
echo "Note: Most tests will fail if not running in Yandex Cloud environment"
echo "This is normal behavior for local testing."
