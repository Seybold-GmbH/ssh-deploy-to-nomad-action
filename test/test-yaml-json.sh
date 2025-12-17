#!/bin/bash
# Test YAML to JSON conversion logic

set -e

echo "========================================="
echo "Testing YAML/JSON Env Vars Parsing"
echo "========================================="
echo ""

# Test 1: YAML format
echo "Test 1: YAML format"
ENV_VARS_INPUT="ENV_DATACENTER: dc1
ENV_SERVICE_COUNT: 3
ENV_DEBUG: true
ENV_SERVICE_HOST: my-service.example.com"

echo "Input (YAML):"
echo "$ENV_VARS_INPUT"
echo ""

# Convert YAML to JSON
if echo "$ENV_VARS_INPUT" | grep -q '^[[:space:]]*{'; then
  ENV_VARS_JSON="$ENV_VARS_INPUT"
  echo "Detected as JSON (no conversion needed)"
else
  echo "Detected as YAML, converting to JSON..."
  if command -v yq &> /dev/null; then
    ENV_VARS_JSON=$(echo "$ENV_VARS_INPUT" | yq -o=json '.')
    echo "Used yq for conversion"
  else
    ENV_VARS_JSON=$(python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin)))" <<< "$ENV_VARS_INPUT")
    echo "Used Python for conversion"
  fi
fi

echo "Output (JSON):"
echo "$ENV_VARS_JSON" | jq '.'
echo ""

# Test 2: JSON format
echo "Test 2: JSON format"
ENV_VARS_INPUT='{
  "ENV_DATACENTER": "dc1",
  "ENV_SERVICE_COUNT": "3",
  "ENV_DEBUG": "true"
}'

echo "Input (JSON):"
echo "$ENV_VARS_INPUT"
echo ""

if echo "$ENV_VARS_INPUT" | grep -q '^[[:space:]]*{'; then
  ENV_VARS_JSON="$ENV_VARS_INPUT"
  echo "Detected as JSON (no conversion needed)"
else
  echo "Converting YAML to JSON..."
  if command -v yq &> /dev/null; then
    ENV_VARS_JSON=$(echo "$ENV_VARS_INPUT" | yq -o=json '.')
  else
    ENV_VARS_JSON=$(python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin)))" <<< "$ENV_VARS_INPUT")
  fi
fi

echo "Output (JSON):"
echo "$ENV_VARS_JSON" | jq '.'
echo ""

# Test 3: Convert to export statements
echo "Test 3: Converting to export statements"
ENV_EXPORTS=$(echo "$ENV_VARS_JSON" | jq -r 'to_entries | map("export \(.key)=\"\(.value)\"") | join(" && ")')
echo "$ENV_EXPORTS"
echo ""

echo "========================================="
echo "✅ YAML/JSON Parsing Test Complete!"
echo "========================================="
