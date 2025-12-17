# Nomad Deploy SSH Action

A reusable GitHub Action for deploying Nomad jobs via SSH with automatic environment variable substitution.

## Features

- 🚀 Deploy, stop, restart, or check status of Nomad jobs
- 🔐 Secure SSH-based deployment
- 🔄 Automatic variable substitution in HCL files
- ✅ Built-in deployment verification
- 📦 Composite action (no Docker required)

## Usage

### Basic Example (YAML format - recommended)

```yaml
- name: Deploy to Nomad
  uses: ./.github/actions/nomad-deploy-ssh
  with:
    ssh-host: ${{ secrets.NOMAD_HOST }}
    ssh-user: ${{ secrets.NOMAD_USER }}
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
    service-name: my-service
    hcl-template: nomad/templates/my-service.nomad.hcl
    hcl-variables: nomad/variables/my-service.vars.hcl
    action: run
    env-vars: |
      ENV_DATACENTER: dc1
      ENV_SERVICE_COUNT: 3
      ENV_SERVICE_HOST: my-service.example.com
```

### Basic Example (JSON format - also supported)

```yaml
- name: Deploy to Nomad
  uses: ./.github/actions/nomad-deploy-ssh
  with:
    ssh-host: ${{ secrets.NOMAD_HOST }}
    ssh-user: ${{ secrets.NOMAD_USER }}
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
    service-name: my-service
    hcl-template: nomad/templates/my-service.nomad.hcl
    hcl-variables: nomad/variables/my-service.vars.hcl
    action: run
    env-vars: |
      {
        "ENV_DATACENTER": "dc1",
        "ENV_SERVICE_COUNT": "3",
        "ENV_SERVICE_HOST": "my-service.example.com"
      }
```

### Full Example with All Options

```yaml
- name: Deploy to Nomad
  uses: ./.github/actions/nomad-deploy-ssh
  with:
    # SSH Configuration (Required)
    ssh-host: ${{ secrets.NOMAD_HOST }}
    ssh-user: ${{ secrets.NOMAD_USER }}
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
    
    # Nomad Configuration
    nomad-addr: http://127.0.0.1:4646
    
    # Deployment Configuration (Required)
    action: run
    service-name: my-service
    hcl-template: nomad/templates/my-service.nomad.hcl
    hcl-variables: nomad/variables/my-service.vars.hcl
    
    # Environment Variables (Required - YAML or JSON format)
    env-vars: |
      ENV_DATACENTER: ${{ vars.DATACENTER }}
      ENV_SERVICE_IMAGE: ${{ vars.SERVICE_IMAGE }}
      ENV_SERVICE_COUNT: ${{ vars.SERVICE_COUNT }}
      ENV_API_KEY: ${{ secrets.API_KEY }}
    
    # Optional Settings
    verify-deployment: 'true'
    workspace-path: '~/nomad-deploy'
```

## Inputs

### Required Inputs

| Input | Description |
|-------|-------------|
| `ssh-host` | SSH host to connect to |
| `ssh-user` | SSH user for authentication |
| `ssh-key` | SSH private key (plain text or base64 encoded) |
| `service-name` | Name of the Nomad job/service |
| `hcl-template` | Path to HCL template file (e.g., `nomad/templates/service.nomad.hcl`) |
| `hcl-variables` | Path to HCL variables file (e.g., `nomad/variables/service.vars.hcl`) |
| `action` | Action to perform: `run`, `stop`, `restart`, or `status` |
| `env-vars` | Environment variables as YAML dict or JSON object (YAML recommended) |

### Optional Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `nomad-addr` | Nomad server address | `http://127.0.0.1:4646` |
| `verify-deployment` | Whether to verify deployment after running | `true` |
| `workspace-path` | Remote workspace path on SSH host | `~/nomad-deploy` |

## Outputs

| Output | Description |
|--------|-------------|
| `deployment-status` | Status of the deployment (`success` or `failed`) |
| `job-status` | Full Nomad job status output (if verification enabled) |

## Environment Variable Substitution

The action automatically substitutes environment variables in your HCL variable files:

### Variable File (variables.vars.hcl)
```hcl
datacenters = ["ENV_DATACENTER"]
service_image = "ENV_SERVICE_IMAGE"
service_count = ENV_SERVICE_COUNT
service_cpu = 100
```

### GitHub Actions Workflow (YAML format)
```yaml
env-vars: |
  ENV_DATACENTER: dc1
  ENV_SERVICE_IMAGE: myapp:latest
  ENV_SERVICE_COUNT: 3
```

Or JSON format:
```yaml
env-vars: |
  {
    "ENV_DATACENTER": "dc1",
    "ENV_SERVICE_IMAGE": "myapp:latest",
    "ENV_SERVICE_COUNT": "3"
  }
```

### Result After Substitution
```hcl
datacenters = ["dc1"]
service_image = "myapp:latest"
service_count = 3
service_cpu = 100
```

## Environment Variable Formats

### YAML Format (Recommended)

YAML format is cleaner and more readable:

```yaml
env-vars: |
  ENV_DATACENTER: dc1
  ENV_SERVICE_COUNT: 3
  ENV_DEBUG: true
  ENV_HOST: my-service.example.com
```

**Benefits:**
- ✅ Cleaner syntax (no quotes or braces needed)
- ✅ Better readability
- ✅ Native GitHub Actions YAML integration
- ✅ Automatic type detection (strings, numbers, booleans)

### JSON Format (Also Supported)

JSON format works but is more verbose:

```yaml
env-vars: |
  {
    "ENV_DATACENTER": "dc1",
    "ENV_SERVICE_COUNT": "3",
    "ENV_DEBUG": "true",
    "ENV_HOST": "my-service.example.com"
  }
```

The action automatically detects the format and converts as needed.

## Variable Formatting

The action automatically formats variables based on type:

- **Strings**: `"value"` (quoted)
- **Numbers**: `123` (unquoted)
- **Booleans**: `true` or `false` (unquoted)
- **JSON Arrays**: `["value1", "value2"]` (unquoted)
- **JSON Objects**: `{"key": "value"}` (unquoted)

## Actions

### `run`
Deploys or updates a Nomad job.

```yaml
action: run
```

### `stop`
Stops a running Nomad job.

```yaml
action: stop
```

### `restart`
Stops and then redeploys a Nomad job (stop + run).

```yaml
action: restart
```

### `status`
Checks the status of a Nomad job without making changes.

```yaml
action: status
```

## How It Works

1. **Setup SSH**: Configures SSH authentication with the provided key
2. **Sync Files**: Transfers HCL template and variables file to remote host with service-specific names (e.g., `my-service.template.hcl`, `my-service.variables.hcl`)
3. **Variable Substitution**: Replaces `ENV_*` placeholders with actual values from `env-vars`
4. **Execute Action**: Runs the Nomad command (run, stop, restart, or status)
5. **Verify**: Checks job status if `verify-deployment` is enabled (only for `run` action)

### Service-Specific Files

To avoid conflicts when deploying multiple services, files are named using the service name:
- Template: `<service-name>.template.hcl`
- Variables: `<service-name>.variables.hcl`

This allows safe concurrent or sequential deployments of different services to the same workspace.

## Requirements

- Nomad CLI must be installed on the SSH host
- SSH host must have network access to Nomad server
- HCL template and variable files must exist in repository

## Security Notes

- SSH keys can be provided as plain text or base64 encoded
- Sensitive values should be stored in GitHub Secrets
- The action creates a temporary workspace on the remote host
- Temporary variable files are automatically cleaned up

## Complete Workflow Example

See [deploy-example.yml](../../workflows/deploy-example.yml) for a complete working example.

## License

MIT License - See repository LICENSE file for details.
