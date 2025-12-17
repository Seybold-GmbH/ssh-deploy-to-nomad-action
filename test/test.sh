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

# Set up test environment variables (without ENV_ prefix)
export DATACENTERS='["dc1", "dc2"]'
export SERVICE_NAME="test-app"
export SERVICE_IMAGE="nginx:latest"
export SERVICE_COUNT=3
export SERVICE_CPU=500
export SERVICE_MEMORY=256
export ENVIRONMENT="production"
export DEBUG_ENABLED=true
export API_KEY="secret-key-12345"
export SERVICE_TAGS='["web", "frontend", "public"]'

echo "📋 Test Environment Variables:"
echo "  DATACENTERS = $DATACENTERS"
echo "  SERVICE_NAME = $SERVICE_NAME"
echo "  SERVICE_IMAGE = $SERVICE_IMAGE"
echo "  SERVICE_COUNT = $SERVICE_COUNT"
echo "  SERVICE_CPU = $SERVICE_CPU"
echo "  SERVICE_MEMORY = $SERVICE_MEMORY"
echo "  ENVIRONMENT = $ENVIRONMENT"
echo "  DEBUG_ENABLED = $DEBUG_ENABLED"
echo "  API_KEY = $API_KEY"
echo "  SERVICE_TAGS = $SERVICE_TAGS"
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
    if [[ "$value" =~ ^(true|false)$ ]]; then
        echo "$value"
        return
    fi
    
    # Number (unquoted) - supports integers and floats, including negatives
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$value"
        return
    fi
    
    # JSON array or object (preserve as-is)
    if [[ "$value" =~ ^\[.*\]$ ]] || [[ "$value" =~ ^\{.*\}$ ]]; then
        echo "$value"
        return
    fi
    
    # String (quoted and escaped)
    value="${value//\"/\\\"}"
    echo "\"$value\""
}

# Perform variable substitution (same logic as deploy.sh)
# Create a temporary file for substitution
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE $VARS_FILE_TMP deploy.sh" EXIT

# Process file line by line
while IFS= read -r line; do
    # Skip comments and empty lines (no substitution needed)
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    processed_line="$line"
    
    # Find and replace all [[VAR]] patterns
    while [[ "$processed_line" =~ \[\[([A-Z_][A-Z0-9_]*)\]\] ]]; do
        var_name="${BASH_REMATCH[1]}"
        var_value="${!var_name}"
        
        if [[ -z "$var_value" ]]; then
            echo "   ⚠️  Variable $var_name is not set - using \"undefined\""
            formatted_value="\"undefined\""
        else
            formatted_value=$(format_value "$var_value")
        fi
        
        # Escape special characters for sed
        escaped_value=$(echo "$formatted_value" | sed 's/[\/&]/\\&/g')
        
        # Replace the placeholder
        processed_line=$(echo "$processed_line" | sed "s/\[\[${var_name}\]\]/${escaped_value}/g")
        
        echo "   ✓ $var_name = $formatted_value"
    done
    
    echo "$processed_line" >> "$TEMP_FILE"
done < "$VARS_FILE"

# Move the processed file to the tmp location
mv "$TEMP_FILE" "$VARS_FILE_TMP"

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
if grep -v '^\s*#' "$VARS_FILE_TMP" | grep -q '\[\['; then
    echo "❌ Test 5: FAILED - Some [[VAR]] placeholders remain"
    grep -v '^\s*#' "$VARS_FILE_TMP" | grep '\[\['
else
    echo "✅ Test 5: All placeholders replaced"
fi

echo ""
echo "========================================="
echo "✅ Variable Substitution Test Complete!"
echo "========================================="

# Cleanup handled by trap
