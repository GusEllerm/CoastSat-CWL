#!/bin/bash
# Test script for coastsat-workflow.cwl
# Loads credentials from .env file and runs the workflow

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from .env file
if [ -f "../../../.env" ]; then
    echo "Loading credentials from .env file..."
    set -a
    source ../../../.env
    set +a
else
    echo "⚠️  Warning: .env file not found at ../../../.env"
    echo "   Please ensure credentials are set as environment variables"
fi

# Ensure GEE_PRIVATE_KEY_PATH is set correctly if not already set
if [ -z "$GEE_PRIVATE_KEY_PATH" ]; then
    if [ -f "../../../.private-key.json" ]; then
        GEE_PRIVATE_KEY_PATH="$(cd ../../.. && pwd)/.private-key.json"
        export GEE_PRIVATE_KEY_PATH
        echo "Found .private-key.json: $GEE_PRIVATE_KEY_PATH"
    fi
fi

# Verify credentials are set
if [ -z "$GEE_SERVICE_ACCOUNT" ]; then
    echo "❌ Error: GEE_SERVICE_ACCOUNT not set"
    exit 1
fi

if [ -z "$GEE_PRIVATE_KEY_PATH" ] || [ ! -f "$GEE_PRIVATE_KEY_PATH" ]; then
    echo "❌ Error: GEE_PRIVATE_KEY_PATH not set or file not found: $GEE_PRIVATE_KEY_PATH"
    exit 1
fi

if [ -z "$NIWA_TIDE_API_KEY" ]; then
    echo "⚠️  Warning: NIWA_TIDE_API_KEY not set (optional but recommended)"
fi

echo ""
echo "========================================="
echo "Running CoastSat CWL Workflow"
echo "========================================="
echo "GEE Service Account: $GEE_SERVICE_ACCOUNT"
echo "GEE Private Key: $GEE_PRIVATE_KEY_PATH"
echo "NIWA API Key: ${NIWA_TIDE_API_KEY:+SET (hidden)}"
echo ""

# Activate virtual environment if it exists
if [ -f "../../../.venv/bin/activate" ]; then
    source ../../../.venv/bin/activate
fi

# Run workflow with preserved environment variables
cwltool \
    --preserve-environment GEE_SERVICE_ACCOUNT,GEE_PRIVATE_KEY_PATH,NIWA_TIDE_API_KEY \
    --outdir outputs \
    ../../workflows/coastsat-workflow.cwl \
    workflow_test_input.yml

echo ""
echo "✅ Workflow completed successfully"

