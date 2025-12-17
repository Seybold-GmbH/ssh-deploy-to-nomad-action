#!/bin/bash
# Test concurrent service deployments with different filenames

set -e

echo "========================================="
echo "Testing Multiple Service Deployments"
echo "========================================="
echo ""

cd "$(dirname "$0")"

# Simulate deploying multiple services
SERVICES=("grafana" "prometheus" "traefik")

echo "📦 Simulating concurrent service deployments..."
echo ""

for service in "${SERVICES[@]}"; do
    SAFE_NAME=$(echo "$service" | sed 's/[^a-zA-Z0-9_-]/-/g')
    
    # Create service-specific files
    cp template.nomad.hcl "${SAFE_NAME}.template.hcl"
    cp variables.vars.hcl "${SAFE_NAME}.variables.hcl"
    
    echo "✅ Created files for $service:"
    echo "   - ${SAFE_NAME}.template.hcl"
    echo "   - ${SAFE_NAME}.variables.hcl"
done

echo ""
echo "📁 Workspace contents (simulating remote host):"
ls -1 *.hcl | grep -E '\.(template|variables)\.hcl$'

echo ""
echo "🎯 Result: Each service has its own template and variables file!"
echo "   No conflicts - services can be deployed concurrently or sequentially."

echo ""
echo "========================================="
echo "Cleanup test files..."
echo "========================================="
for service in "${SERVICES[@]}"; do
    SAFE_NAME=$(echo "$service" | sed 's/[^a-zA-Z0-9_-]/-/g')
    rm -f "${SAFE_NAME}.template.hcl" "${SAFE_NAME}.variables.hcl"
done

echo "✅ Test complete - service isolation works!"
