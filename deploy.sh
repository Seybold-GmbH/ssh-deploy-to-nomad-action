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

# Perform variable substitution
echo "[INFO] Performing variable substitution..."
cp "$VARS_FILE" "$VARS_FILE_TMP"

# Find all ENV_ placeholders and substitute them (excluding comments)
PLACEHOLDERS=$(grep -v '^\s*#' "$VARS_FILE" | grep -oP 'ENV_[A-Z0-9_]+' | sort -u || true)

if [[ -z "$PLACEHOLDERS" ]]; then
    echo "[INFO] No ENV_ placeholders found in variables file"
else
    for placeholder in $PLACEHOLDERS; do
        var_name="$placeholder"
        var_value="${!var_name}"
        
        if [[ -z "$var_value" ]]; then
            echo "[WARN] Variable $var_name is not set, using 'undefined'" >&2
            var_value="undefined"
        fi
        
        formatted_value=$(format_value "$var_value")
        
        # Escape forward slashes and special characters for sed
        escaped_value=$(echo "$formatted_value" | sed 's/[\/&]/\\&/g')
        
        # Replace placeholder with value
        # Use word boundaries to avoid replacing parts of strings
        # Also handle both quoted and unquoted placeholders
        sed -i "s/\"${placeholder}\"/${escaped_value}/g; s/\b${placeholder}\b/${escaped_value}/g" "$VARS_FILE_TMP"
        
        echo "[INFO] Substituted $var_name = $formatted_value"
    done
fi

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
