#!/bin/bash
# Complete validation workflow orchestrator
# This script: prepares workflow, runs it, and compares results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}CoastSat Validation Workflow${NC}"
echo "================================"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if baseline data exists
if [ ! -f "baseline/transects_extended.geojson" ]; then
    echo -e "${RED}Error: Baseline data not found.${NC}"
    echo "Run ./setup_validation.sh first to extract baseline and validation data."
    exit 1
fi

# Check if validation data exists
if [ ! -f "validation/transects_extended.geojson" ]; then
    echo -e "${RED}Error: Validation data not found.${NC}"
    echo "Run ./setup_validation.sh first to extract baseline and validation data."
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found.${NC}"
    echo "Docker is required to run the validation workflow."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose not found.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Step 1: Prepare workflow
echo -e "${YELLOW}[Step 1/3] Preparing workflow...${NC}"
echo "----------------------------------------"
if [ -f "./prepare_workflow.sh" ]; then
    ./prepare_workflow.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Workflow preparation failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: prepare_workflow.sh not found${NC}"
    exit 1
fi
echo ""

# Step 2: Run workflow
echo -e "${YELLOW}[Step 2/3] Running validation workflow...${NC}"
echo "----------------------------------------"
echo "This will take 20-60 minutes depending on GEE data download..."
echo ""

# Determine docker compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Run workflow and capture output
WORKFLOW_LOG="workflow_execution.log"
echo "Workflow output will be logged to: $WORKFLOW_LOG"
echo ""

$DOCKER_COMPOSE_CMD run --rm coastsat-validation bash -c 'cd /app && ./update_validation.sh' 2>&1 | tee "$WORKFLOW_LOG"

WORKFLOW_EXIT_CODE=${PIPESTATUS[0]}

if [ $WORKFLOW_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}Error: Workflow execution failed (exit code: $WORKFLOW_EXIT_CODE)${NC}"
    echo "Check $WORKFLOW_LOG for details."
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Workflow execution complete${NC}"
echo ""

# Step 3: Compare results
echo -e "${YELLOW}[Step 3/3] Comparing results...${NC}"
echo "----------------------------------------"
if [ -f "./compare_results.sh" ]; then
    ./compare_results.sh
    COMPARE_EXIT_CODE=$?
    
    if [ $COMPARE_EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Comparison complete${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ Comparison completed with differences${NC}"
        echo "Review the output above for details."
    fi
else
    echo -e "${RED}Error: compare_results.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Validation Workflow Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Summary:"
echo "  - Workflow prepared"
echo "  - Workflow executed (see $WORKFLOW_LOG for details)"
echo "  - Results compared (see output above)"
echo ""
echo "Next steps:"
echo "  - Review comparison results"
echo "  - Check workflow outputs in workflow/ directory"
echo "  - Review $WORKFLOW_LOG for execution details"

