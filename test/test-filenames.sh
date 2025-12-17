#!/bin/bash
# Test script for service-specific filenames

set -e

echo "========================================="
echo "Testing Service-Specific Filenames"
echo "========================================="
echo ""

cd "$(dirname "$0")"

# Test service names including ones that need sanitization
TEST_SERVICES=("my-service" "test@app" "web.frontend" "api_v2")

echo "📋 Testing service name sanitization:"
for service in "${TEST_SERVICES[@]}"; do
    SAFE_NAME=$(echo "$service" | sed 's/[^a-zA-Z0-9_-]/-/g')
    echo "  $service → $SAFE_NAME"
done

echo ""
echo "🔧 Testing deployment script with custom filenames..."
echo ""

# Set up test environment
export ENV_DATACENTERS='["dc1"]'
export ENV_SERVICE_NAME="test-app"
export ENV_SERVICE_IMAGE="nginx:latest"
export ENV_SERVICE_COUNT=1
export ENV_SERVICE_CPU=100
export ENV_SERVICE_MEMORY=128
export ENV_ENVIRONMENT="test"
export ENV_DEBUG_ENABLED=false
export ENV_API_KEY="test-key"
export ENV_SERVICE_TAGS='["test"]'

# Copy deploy script
cp ../deploy.sh ./deploy-test.sh
chmod +x ./deploy-test.sh

# Test with service-specific filenames
SERVICE_NAME="my-service"
SAFE_NAME=$(echo "$SERVICE_NAME" | sed 's/[^a-zA-Z0-9_-]/-/g')

# Create service-specific copies
cp template.nomad.hcl "${SAFE_NAME}.template.hcl"
cp variables.vars.hcl "${SAFE_NAME}.variables.hcl"

echo "Created files:"
ls -la ${SAFE_NAME}.*

echo ""
echo "Running deployment script with custom filenames..."
echo "Command: ./deploy-test.sh $SERVICE_NAME status ${SAFE_NAME}.template.hcl ${SAFE_NAME}.variables.hcl"
echo ""

# Mock nomad command for testing
cat > nomad << 'EOF'
#!/bin/bash
echo "[MOCK] nomad job run -var-file=$2 $3"
echo "[MOCK] Job registered successfully"
exit 0
EOF
chmod +x nomad
export PATH="$PWD:$PATH"

# Run the script (status action so we don't need actual Nomad)
if ./deploy-test.sh "$SERVICE_NAME" status "${SAFE_NAME}.template.hcl" "${SAFE_NAME}.variables.hcl" 2>&1 | grep -q "Checking status"; then
    echo "✅ Script accepts custom filenames"
else
    echo "❌ Script failed with custom filenames"
fi

# Check if temp file is created with correct name
if [[ -f "${SAFE_NAME}.variables.hcl.tmp" ]]; then
    echo "✅ Temp file created with service-specific name"
    echo ""
    echo "Contents of ${SAFE_NAME}.variables.hcl.tmp:"
    head -n 20 "${SAFE_NAME}.variables.hcl.tmp"
else
    echo "❌ Temp file not created"
fi

# Cleanup
rm -f deploy-test.sh nomad "${SAFE_NAME}".* variables.vars.hcl.tmp

echo ""
echo "========================================="
echo "✅ Service-Specific Filename Test Complete!"
echo "========================================="
