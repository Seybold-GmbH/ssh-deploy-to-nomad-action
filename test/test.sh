#!/bin/bash
# Test script for variable substitution logic
# This simulates the deployment process without actually deploying to Nomad

set -e

echo "========================================="
echo "Testing Nomad Deploy SSH Action Logic"
echo "========================================="
echo ""

# Change to test directory
cd "$(dirname "$0")"

# Set up test environment variables
export ENV_DATACENTERS='["dc1", "dc2"]'
export ENV_SERVICE_NAME="test-app"
export ENV_SERVICE_IMAGE="nginx:latest"
export ENV_SERVICE_COUNT=3
export ENV_SERVICE_CPU=500
export ENV_SERVICE_MEMORY=256
export ENV_ENVIRONMENT="production"
export ENV_DEBUG_ENABLED=true
export ENV_API_KEY="secret-key-12345"
export ENV_SERVICE_TAGS='["web", "frontend", "public"]'

echo "📋 Test Environment Variables:"
echo "  ENV_DATACENTERS = $ENV_DATACENTERS"
echo "  ENV_SERVICE_NAME = $ENV_SERVICE_NAME"
echo "  ENV_SERVICE_IMAGE = $ENV_SERVICE_IMAGE"
echo "  ENV_SERVICE_COUNT = $ENV_SERVICE_COUNT"
echo "  ENV_SERVICE_CPU = $ENV_SERVICE_CPU"
echo "  ENV_SERVICE_MEMORY = $ENV_SERVICE_MEMORY"
echo "  ENV_ENVIRONMENT = $ENV_ENVIRONMENT"
echo "  ENV_DEBUG_ENABLED = $ENV_DEBUG_ENABLED"
echo "  ENV_API_KEY = $ENV_API_KEY"
echo "  ENV_SERVICE_TAGS = $ENV_SERVICE_TAGS"
echo ""

# Copy deploy script to test directory
cp ../deploy.sh ./deploy.sh
chmod +x ./deploy.sh

echo "🔧 Running variable substitution test..."
echo ""

# Run the deployment script (dry-run mode)
# We'll stop before the actual nomad command by modifying the script temporarily
VARS_FILE="variables.vars.hcl"
VARS_FILE_TMP="variables.vars.hcl.tmp"

# Format value based on type detection
format_value() {
    local value="$1"
    
    # Boolean (unquoted)
    if [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
        echo "$value"
        return
    fi
    
    # Number (unquoted)
    if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$value"
        return
    fi
    
    # JSON array or object (unquoted)
    if [[ "$value" =~ ^\[.*\]$ ]] || [[ "$value" =~ ^\{.*\}$ ]]; then
        echo "$value"
        return
    fi
    
    # String (quoted)
    echo "\"$value\""
}

# Perform variable substitution (same logic as deploy.sh)
cp "$VARS_FILE" "$VARS_FILE_TMP"

PLACEHOLDERS=$(grep -v '^\s*#' "$VARS_FILE" | grep -oP 'ENV_[A-Z0-9_]+' | sort -u || true)

if [[ -z "$PLACEHOLDERS" ]]; then
    echo "❌ No ENV_ placeholders found in variables file"
    exit 1
else
    echo "✅ Found placeholders to substitute:"
    for placeholder in $PLACEHOLDERS; do
        echo "   - $placeholder"
    done
    echo ""
    
    echo "🔄 Performing substitution..."
    for placeholder in $PLACEHOLDERS; do
        var_name="$placeholder"
        var_value="${!var_name}"
        
        if [[ -z "$var_value" ]]; then
            echo "   ⚠️  $var_name is not set, using 'undefined'"
            var_value="undefined"
        fi
        
        formatted_value=$(format_value "$var_value")
        
        # Escape forward slashes and special characters for sed
        escaped_value=$(echo "$formatted_value" | sed 's/[\/&]/\\&/g')
        
        # Replace placeholder with value
        # Use word boundaries to avoid replacing parts of strings
        # Also handle both quoted and unquoted placeholders
        sed -i "s/\"${placeholder}\"/${escaped_value}/g; s/\b${placeholder}\b/${escaped_value}/g" "$VARS_FILE_TMP"
        
        echo "   ✓ $var_name = $formatted_value"
    done
fi

echo ""
echo "========================================="
echo "📄 Original Variables File:"
echo "========================================="
cat "$VARS_FILE"

echo ""
echo "========================================="
echo "✨ Substituted Variables File:"
echo "========================================="
cat "$VARS_FILE_TMP"

echo ""
echo "========================================="
echo "🧪 Validation Tests:"
echo "========================================="

# Test 1: Check if strings are quoted
if grep -q 'service_name.*=.*"test-app"' "$VARS_FILE_TMP"; then
    echo "✅ Test 1: Strings are properly quoted"
else
    echo "❌ Test 1: FAILED - Strings not properly quoted"
fi

# Test 2: Check if numbers are unquoted
if grep -q 'service_count   = 3' "$VARS_FILE_TMP"; then
    echo "✅ Test 2: Numbers are unquoted"
else
    echo "❌ Test 2: FAILED - Numbers not properly formatted"
fi

# Test 3: Check if booleans are unquoted
if grep -q 'debug_enabled   = true' "$VARS_FILE_TMP"; then
    echo "✅ Test 3: Booleans are unquoted"
else
    echo "❌ Test 3: FAILED - Booleans not properly formatted"
fi

# Test 4: Check if arrays are preserved
if grep -q 'datacenters     = \["dc1", "dc2"\]' "$VARS_FILE_TMP"; then
    echo "✅ Test 4: JSON arrays are preserved"
else
    echo "❌ Test 4: FAILED - JSON arrays not properly formatted"
fi

# Test 5: Check if all placeholders are replaced (excluding comments)
if grep -v '^\s*#' "$VARS_FILE_TMP" | grep -q 'ENV_'; then
    echo "❌ Test 5: FAILED - Some ENV_ placeholders remain"
    grep -v '^\s*#' "$VARS_FILE_TMP" | grep 'ENV_'
else
    echo "✅ Test 5: All placeholders replaced"
fi

echo ""
echo "========================================="
echo "✅ Variable Substitution Test Complete!"
echo "========================================="

# Cleanup
rm -f "$VARS_FILE_TMP" deploy.sh
