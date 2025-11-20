# Handling Credentials in CWL Workflows

This document explains how to handle credentials (API keys, service account files) in CWL workflows in a way that prevents them from appearing in CWLProv provenance records.

## Overview

When using CWLProv to generate provenance records, any file contents that are loaded into the workflow document will appear in the provenance. To prevent sensitive credentials from appearing in provenance:

1. **Always use `loadContents: false`** when referencing credential files
2. Use dedicated credential loading tools that handle credentials securely
3. Pass credential file paths (not contents) between workflow steps

## Credential Tools

### 1. `load_gee_credentials` - Google Earth Engine Credentials

Loads and verifies GEE service account credentials from `.private-key.json`.

**Location:** `tools/load_gee_credentials/load_gee_credentials.cwl`

**Inputs:**
- `private_key_file` (File): The `.private-key.json` file (must use `loadContents: false`)
- `service_account_name` (string, optional): Service account email (auto-detected if not provided)

**Outputs:**
- `credentials_ready` (File): Marker file indicating credentials are ready
- `credential_file_path` (string): Path to credential file in execution directory

**Usage in workflow:**

```yaml
steps:
  load_gee_creds:
    run: ../tools/load_gee_credentials/load_gee_credentials.cwl
    in:
      script:
        class: File
        path: ../tools/load_gee_credentials/load_gee_credentials.py
      private_key_file:
        class: File
        path: .private-key.json
        loadContents: false  # CRITICAL: Prevents credentials from appearing in provenance
    out: [credentials_ready, credential_file_path]
```

### 2. `load_env_credentials` - Environment Variables from .env

Loads environment variables from a `.env` file (e.g., NIWA_API_KEY, GEE_SERVICE_ACCOUNT).

**Location:** `tools/load_env_credentials/load_env_credentials.cwl`

**Inputs:**
- `env_file` (File): The `.env` file (must use `loadContents: false`)

**Outputs:**
- `env_vars_file` (File): Shell script with exported environment variables
- `credentials_ready` (File): Marker file indicating credentials are ready

**Usage in workflow:**

```yaml
steps:
  load_env_creds:
    run: ../tools/load_env_credentials/load_env_credentials.cwl
    in:
      script:
        class: File
        path: ../tools/load_env_credentials/load_env_credentials.py
      env_file:
        class: File
        path: .env
        loadContents: false  # CRITICAL: Prevents credentials from appearing in provenance
    out: [env_vars_file, credentials_ready]
```

## Complete Example Workflow

Here's a complete example showing how to use both credential tools in a workflow:

```yaml
#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: Workflow with Secure Credentials

inputs:
  # Regular workflow inputs
  polygons_geojson:
    type: File
  
  # Credential files - ALWAYS use loadContents: false
  private_key_file:
    type: File
    default:
      class: File
      path: .private-key.json
      loadContents: false  # Prevents credentials in provenance
  
  env_file:
    type: File
    default:
      class: File
      path: .env
      loadContents: false  # Prevents credentials in provenance

steps:
  # Step 1: Load GEE credentials
  load_gee_creds:
    run: ../tools/load_gee_credentials/load_gee_credentials.cwl
    in:
      script:
        class: File
        path: ../tools/load_gee_credentials/load_gee_credentials.py
      private_key_file: private_key_file
    out: [credentials_ready, credential_file_path]
  
  # Step 2: Load environment variables
  load_env_creds:
    run: ../tools/load_env_credentials/load_env_credentials.cwl
    in:
      script:
        class: File
        path: ../tools/load_env_credentials/load_env_credentials.py
      env_file: env_file
    out: [env_vars_file, credentials_ready]
  
  # Step 3: Use credentials in your processing step
  process_sites:
    run: ../tools/process_site/process_site.cwl
    in:
      site_id: ...
      # Pass credential file path or use environment variables
      gee_credential_file: load_gee_creds/credential_file_path
      env_vars_script: load_env_creds/env_vars_file
    out: [result]
```

## Using Credentials in Tools

### Option 1: Pass Credential File Path

In your tool that needs GEE credentials, accept the credential file path:

```yaml
inputs:
  gee_credential_file:
    type: string
    doc: Path to GEE credential file

baseCommand: [python3, my_script.py]

arguments:
  - --gee-credentials
  - $(inputs.gee_credential_file)
```

### Option 2: Use Environment Variables

For tools that need environment variables, source the env_vars.sh file:

```yaml
inputs:
  env_vars_script:
    type: File
    doc: Shell script with environment variables

baseCommand: [bash, -c]

arguments:
  - |
    source $(inputs.env_vars_script.path) && \
    python3 my_script.py
```

Or use CWL's `env` field (but note: this may still appear in provenance if values are set directly):

```yaml
inputs:
  niwa_api_key:
    type: string
    doc: NIWA API key (from env file)

env:
  NIWA_API_KEY: $(inputs.niwa_api_key)
```

**Note:** If you use the `env` field with direct values, those values may appear in provenance. It's safer to use the env_vars.sh file approach.

## Best Practices

1. **Always use `loadContents: false`** for credential files
2. **Never hardcode credentials** in CWL files
3. **Use credential loading tools** as separate workflow steps
4. **Pass file paths, not contents** between steps
5. **Verify credentials are loaded** by checking for marker files before using them
6. **Document credential requirements** in workflow documentation

## CWLProv and Provenance

When you run CWLProv to generate provenance records:

- ✅ Files with `loadContents: false` will appear as file references only (no contents)
- ✅ Credential file paths will be recorded, but not their contents
- ❌ Files with `loadContents: true` (or default) will have their contents included
- ❌ Direct string values in `env` fields may appear in provenance

## Security Notes

- Credential files should be in `.gitignore` (already configured)
- Never commit `.private-key.json` or `.env` files to version control
- Use environment-specific credential files for different deployments
- Rotate credentials regularly
- Use least-privilege service accounts

## Troubleshooting

### Credentials not found
- Ensure credential files exist in the expected location
- Check file paths are correct (relative to workflow execution directory)
- Verify `loadContents: false` is set correctly

### Credentials appear in provenance
- Verify `loadContents: false` is set on all credential file inputs
- Check that credential loading tools are used (not direct file references)
- Review CWLProv output to identify where credentials are being included

### Environment variables not available
- Ensure `env_vars.sh` is sourced before running tools that need them
- Check that `.env` file format is correct (KEY=value)
- Verify environment variable names match what your tools expect

