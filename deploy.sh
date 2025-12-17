#!/bin/bash
# Nomad deployment script for SSH-based deployments
# This script handles variable substitution and Nomad job operations
# Usage: ./deploy.sh <service-name> <action> [template-file] [vars-file]

set -e

SERVICE_NAME=$1
ACTION=${2:-run}
TEMPLATE_FILE=${3:-"template.nomad.hcl"}
VARS_FILE=${4:-"variables.vars.hcl"}

if [[ -z "$SERVICE_NAME" ]]; then
    echo "Error: Service name is required" >&2
    echo "Usage: $0 <service-name> <action> [template-file] [vars-file]" >&2
    exit 1
fi

# Generate temp file name based on vars file
VARS_FILE_TMP="${VARS_FILE}.tmp"

# Check if required files exist
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template file not found: $TEMPLATE_FILE" >&2
    exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
    echo "Error: Variables file not found: $VARS_FILE" >&2
    exit 1
fi

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

# Perform variable substitution using [[VAR_NAME]] pattern
echo "[INFO] Performing variable substitution..."

# Create a temporary file for substitution
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

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
            echo "[WARNING] Variable $var_name is not set - using \"undefined\"" >&2
            formatted_value="\"undefined\""
        else
            formatted_value=$(format_value "$var_value")
        fi
        
        # Escape special characters for sed
        escaped_value=$(echo "$formatted_value" | sed 's/[\/&]/\\&/g')
        
        # Replace the placeholder
        processed_line=$(echo "$processed_line" | sed "s/\[\[${var_name}\]\]/${escaped_value}/g")
        
        echo "[INFO] Substituted $var_name = $formatted_value"
    done
    
    echo "$processed_line" >> "$TEMP_FILE"
done < "$VARS_FILE"

# Move the processed file to the tmp location
mv "$TEMP_FILE" "$VARS_FILE_TMP"

# Perform the requested action
case "$ACTION" in
    run)
        echo "[INFO] Deploying job: $SERVICE_NAME"
        if nomad job run -var-file="$VARS_FILE_TMP" "$TEMPLATE_FILE"; then
            echo "✅ Successfully deployed $SERVICE_NAME"
        else
            echo "❌ Failed to deploy $SERVICE_NAME" >&2
            exit 1
        fi
        ;;
    
    stop)
        echo "[INFO] Stopping job: $SERVICE_NAME"
        if nomad job stop "$SERVICE_NAME"; then
            echo "✅ Successfully stopped $SERVICE_NAME"
        else
            echo "❌ Failed to stop $SERVICE_NAME" >&2
            exit 1
        fi
        ;;
    
    restart)
        echo "[INFO] Restarting job: $SERVICE_NAME"
        if nomad job stop "$SERVICE_NAME" && sleep 2 && nomad job run -var-file="$VARS_FILE_TMP" "$TEMPLATE_FILE"; then
            echo "✅ Successfully restarted $SERVICE_NAME"
        else
            echo "❌ Failed to restart $SERVICE_NAME" >&2
            exit 1
        fi
        ;;
    
    status)
        echo "[INFO] Checking status of job: $SERVICE_NAME"
        nomad job status "$SERVICE_NAME"
        ;;
    
    *)
        echo "Error: Unknown action: $ACTION" >&2
        echo "Valid actions: run, stop, restart, status" >&2
        exit 1
        ;;
esac

# Cleanup
rm -f "$VARS_FILE_TMP"
