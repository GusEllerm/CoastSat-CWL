#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Reusable workflow for loading credentials securely.
  
  This workflow abstracts the credential loading process into a single reusable
  component that can be called from other workflows. It:
  1. Loads GEE credentials from .private-key.json
  2. Loads environment variables from .env file
  3. Outputs credential file paths and status markers for use in downstream steps
  
  CRITICAL: All credential file inputs use loadContents: false to prevent
  credential contents from appearing in provenance records.
  
  Usage in other workflows:
    load_creds:
      run: load_credentials_workflow.cwl
      in:
        private_key_file: private_key_file
        env_file: env_file
        load_gee_script: load_gee_script  # optional, has defaults
        load_env_script: load_env_script  # optional, has defaults
      out: [gee_credential_file, env_vars_file, credentials_status]

label: Load Credentials Workflow

requirements:
  - class: InlineJavascriptRequirement
  - class: SubworkflowFeatureRequirement
  - class: StepInputExpressionRequirement
  - class: MultipleInputFeatureRequirement

inputs:
  
  # Credential files - ALWAYS use loadContents: false when providing these
  private_key_file:
    type: File
    doc: |
      GEE service account private key file.
      IMPORTANT: When providing this input, use loadContents: false to prevent
      credentials from appearing in provenance.
  
  env_file:
    type: File
    doc: |
      Environment file containing API keys (e.g., NIWA_API_KEY).
      IMPORTANT: When providing this input, use loadContents: false to prevent
      credentials from appearing in provenance.

outputs:
  gee_credential_file:
    type: File
    outputSource: load_gee_creds/credential_file_path
    doc: Path to the GEE credential file (for use in downstream tools)
  
  env_vars_file:
    type: File
    outputSource: load_env_creds/env_vars_file
    doc: Shell script file that can be sourced to set environment variables
  
  credentials_status:
    type: File[]
    outputSource: [load_gee_creds/credentials_ready, load_env_creds/credentials_ready]
    doc: Marker files indicating credentials were loaded successfully

steps:
  # Step 1: Load GEE credentials
  # This step verifies credentials and makes them available for downstream tools
  load_gee_creds:
    run: ../tools/load_gee_credentials/load_gee_credentials.cwl
    in:
      private_key_file: private_key_file
    out: [credentials_ready, credential_file_path]
    doc: |
      Loads and verifies GEE service account credentials.
      The credential file is made available for downstream tools that need GEE access.
  
  # Step 2: Load environment variables
  # This step parses .env file and creates environment variable exports
  load_env_creds:
    run: ../tools/load_env_credentials/load_env_credentials.cwl
    in:
      env_file: env_file
    out: [env_vars_file, credentials_ready]
    doc: |
      Loads environment variables from .env file.
      Creates a shell script that can be sourced to set environment variables.

