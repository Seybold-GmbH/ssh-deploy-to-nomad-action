# GitHub Action: SSH Deploy to Nomad

## Purpose
This is a **composite GitHub Action** that deploys HashiCorp Nomad jobs via SSH with intelligent environment variable substitution. It enables CI/CD workflows to securely deploy to remote Nomad clusters without requiring direct network access.

## Architecture

### Two-Phase Execution Model
1. **Local Phase** (`action.yml`): Runs in GitHub Actions runner
   - SSH setup and authentication (plain text or base64-encoded keys)
   - File synchronization via rsync to remote workspace
   - YAML/JSON env-vars parsing and conversion
   
2. **Remote Phase** (`deploy.sh`): Executes on SSH host
   - Variable substitution in HCL files (replaces `[[VAR_NAME]]` placeholders)
   - Nomad CLI commands (`run`, `stop`, `restart`, `status`)
   - Type-aware value formatting (strings quoted, numbers/bools/arrays unquoted)

### File Naming Convention
Files are prefixed with sanitized service names to enable concurrent deployments:
- `<service-name>.template.hcl` (from `hcl-template` input)
- `<service-name>.variables.hcl` (from `hcl-variables` input)
- Sanitization: non-alphanumeric chars → dashes (e.g., `my/service` → `my-service`)

## Critical Patterns

### Variable Substitution Logic (`deploy.sh`)
- Scans `.vars.hcl` line-by-line for `[[VAR_NAME]]` placeholders (pattern: `\[\[([A-Z_][A-Z0-9_]*)\]\]`)
- Ignores comments and empty lines
- Type detection determines quoting:
  ```bash
  # Booleans/numbers/JSON: unquoted
  debug_enabled = true
  count = 3
  tags = ["web", "api"]
  
  # Strings: quoted and escaped
  image = "nginx:latest"
  api_key = "secret\"with\"quotes"
  ```
- Processes file line by line, replacing all `[[VAR]]` patterns on each line
- Creates temporary file for substitution, cleans up via trap on exit

### Dual Format Support (YAML/JSON)
Action detects format by checking if `env-vars` starts with `{`:
- **YAML** (recommended): Cleaner syntax, converted via `yq` or Python's `yaml` module
- **JSON**: Direct passthrough
- Both are normalized to JSON for shell export statements via `jq`

Example YAML input:
```yaml
env-vars: |
  SERVICE_COUNT: 3
  DEBUG: true
```

### SSH Key Handling
Supports both formats in `ssh-key` input:
```bash
# Plain text (contains "BEGIN")
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----

# Base64-encoded (auto-detected and decoded)
LS0tLS1CRUdJTi...
```

## Testing Approach

Run tests locally without Nomad server:
```bash
cd test/
./test.sh                # Core substitution logic
./test-yaml-json.sh      # YAML/JSON parsing
./test-filenames.sh      # Service name sanitization
./test-multi-service.sh  # Concurrent deployment simulation
```

Tests verify:
- Variable substitution correctness (types, quoting)
- Format detection and conversion
- File naming collisions
- Environment variable propagation

## Common Modifications

### Adding New Actions
Edit `deploy.sh` case statement:
```bash
case "$ACTION" in
    run|stop|restart|status)
        # existing
        ;;
    validate)  # new action
        nomad job validate -var-file="$VARS_FILE_TMP" "$TEMPLATE_FILE"
        ;;
esac
```

### Supporting New Variable Formats
Modify format detection in `action.yml` step "Deploy to Nomad via SSH":
```bash
if echo "$ENV_VARS_INPUT" | grep -q '^[[:space:]]*{'; then
    # JSON
elif echo "$ENV_VARS_INPUT" | grep -q '^<'; then
    # XML (new)
else
    # YAML
fi
```

### Custom Variable Patterns
Change regex in `deploy.sh` if you need a different placeholder pattern:
```bash
# Current: [[VAR_NAME]]
# Alternative: {{VAR_NAME}}
while [[ "$processed_line" =~ \{\{([A-Z_][A-Z0-9_]*)\}\} ]]; do
    # ... substitution logic
done
```

## Key Files

- `action.yml`: Composite action definition, all GitHub Actions integration
- `deploy.sh`: Core deployment logic, variable substitution engine
- `test/template.nomad.hcl`: Example Nomad job spec using variables
- `test/variables.vars.hcl`: Example showing `[[VAR]]` placeholder usage

## Dependencies

### GitHub Actions Runner
- `bash`, `ssh`, `rsync`, `jq`
- `yq` or `python3` + PyYAML (for YAML→JSON conversion)

### SSH Host
- Nomad CLI installed and in PATH
- Network connectivity to Nomad server (default: `localhost:4646`)
- Write access to workspace path (default: `~/nomad-deploy`)

## Gotchas

1. **Variable quoting**: Incorrect type detection breaks HCL parsing. Test substitution with `./test/test.sh` before deploying.
2. **Service name characters**: Special chars in `service-name` are sanitized to dashes. Ensure Nomad job name matches.
3. **Concurrent deployments**: Safe for different services, but same service + same workspace = race condition.
4. **SSH host key verification**: Auto-accepts via `ssh-keyscan`. For strict security, pre-populate `known_hosts`.
