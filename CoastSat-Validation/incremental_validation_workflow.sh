#!/bin/bash
# Incremental validation workflow
# Runs the pipeline for each commit in the range, replicating the original behavior

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Incremental Validation Workflow${NC}"
echo "========================================"
echo ""

# Load config
CONFIG_FILE="$SCRIPT_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    BASELINE_COMMIT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('baseline_commit', 'HEAD~1'))" 2>/dev/null || echo "HEAD~1")
    VALIDATION_SITES=$(python3 -c "import json; print(' '.join(json.load(open('$CONFIG_FILE')).get('validation_sites', ['nzd0001', 'sar0001'])))" 2>/dev/null || echo "nzd0001 sar0001")
else
    BASELINE_COMMIT="HEAD~1"
    VALIDATION_SITES="nzd0001 sar0001"
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Baseline commit: $BASELINE_COMMIT"
echo "  Validation sites: $VALIDATION_SITES"
echo ""

# Get list of commits from baseline to HEAD (inclusive of HEAD)
cd "$SCRIPT_DIR/../CoastSat-Original"
# Get commits between baseline and HEAD, then append HEAD if not already included
COMMITS=($(git rev-list --reverse ${BASELINE_COMMIT}..HEAD))
HEAD_HASH=$(git rev-parse HEAD)
# Append HEAD if it's not already in the list (git rev-list excludes HEAD by default)
if [ ${#COMMITS[@]} -eq 0 ]; then
    COMMITS=("$HEAD_HASH")
else
    # Get last element using length-1 (compatible with all shells)
    LAST_COMMIT="${COMMITS[${#COMMITS[@]}-1]}"
    if [ "$LAST_COMMIT" != "$HEAD_HASH" ]; then
        COMMITS+=("$HEAD_HASH")
    fi
fi
cd "$SCRIPT_DIR"

if [ ${#COMMITS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No commits found between $BASELINE_COMMIT and HEAD${NC}"
    exit 1
fi

echo -e "${YELLOW}Found ${#COMMITS[@]} commits to process incrementally${NC}"
echo ""

# Determine docker compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo -e "${RED}Error: Docker Compose not found${NC}"
    exit 1
fi

# Step 1: Extract baseline data
echo -e "${YELLOW}[Step 1] Extracting baseline data...${NC}"
if [ ! -f "baseline/transects_extended.geojson" ]; then
    ./setup_validation.sh
else
    echo "  ✓ Baseline data already exists"
fi
echo ""

# Step 2: Prepare initial workflow state
echo -e "${YELLOW}[Step 2] Preparing initial workflow state...${NC}"
./prepare_workflow.sh
echo ""

# Step 3: Run incremental updates
echo -e "${YELLOW}[Step 3] Running incremental updates...${NC}"
echo "This will process each commit incrementally:"
echo ""

WORKFLOW_DIR="$SCRIPT_DIR/workflow"
CURRENT_COMMIT="$BASELINE_COMMIT"

for i in "${!COMMITS[@]}"; do
    NEXT_COMMIT="${COMMITS[$i]}"
    COMMIT_NUM=$((i + 1))
    
    echo -e "${BLUE}--- Incremental Update $COMMIT_NUM/${#COMMITS[@]} ---${NC}"
    echo "  Processing: $CURRENT_COMMIT -> $NEXT_COMMIT"
    
    # Get commit info
    cd "$SCRIPT_DIR/../CoastSat-Original"
    COMMIT_MSG=$(git log -1 --format="%s" "$NEXT_COMMIT")
    COMMIT_DATE=$(git log -1 --format="%ci" "$NEXT_COMMIT")
    cd "$SCRIPT_DIR"
    
    echo "  Commit: $NEXT_COMMIT"
    echo "  Date: $COMMIT_DATE"
    echo "  Message: $COMMIT_MSG"
    echo ""
    
    # Update MAX_DATE to the max date from the NEXT commit's data
    # This ensures we only process data up to what was in that commit
    # For HEAD (last commit), we need to use HEAD's max date, not HEAD~1's
    cd "$SCRIPT_DIR/../CoastSat-Original"
    
    # Try to get max date from validation sites
    # Extract only the date part (YYYY-MM-DD) from the datetime string
    MAX_DATE=""
    for site in $VALIDATION_SITES; do
        if [[ "$site" =~ ^nzd ]]; then
            SITE_MAX_RAW=$(git show "$NEXT_COMMIT:data/$site/transect_time_series.csv" 2>/dev/null | tail -1 | cut -d',' -f1 | head -1 || echo "")
            if [ -n "$SITE_MAX_RAW" ]; then
                # Extract just the date part (YYYY-MM-DD) - handle both date-only and datetime formats
                SITE_MAX=$(echo "$SITE_MAX_RAW" | sed 's/ .*//' | sed 's/T.*//' | head -c 10)
                if [ -n "$SITE_MAX" ] && [ ${#SITE_MAX} -eq 10 ]; then
                    if [ -z "$MAX_DATE" ] || [ "$SITE_MAX" \> "$MAX_DATE" ]; then
                        MAX_DATE="$SITE_MAX"
                    fi
                fi
            fi
        fi
    done
    
    # Also check SAR sites for completeness
    for site in $VALIDATION_SITES; do
        if [[ "$site" =~ ^sar ]]; then
            SITE_MAX_RAW=$(git show "$NEXT_COMMIT:data/$site/transect_time_series.csv" 2>/dev/null | tail -1 | cut -d',' -f1 | head -1 || echo "")
            if [ -n "$SITE_MAX_RAW" ]; then
                SITE_MAX=$(echo "$SITE_MAX_RAW" | sed 's/ .*//' | sed 's/T.*//' | head -c 10)
                if [ -n "$SITE_MAX" ] && [ ${#SITE_MAX} -eq 10 ]; then
                    if [ -z "$MAX_DATE" ] || [ "$SITE_MAX" \> "$MAX_DATE" ]; then
                        MAX_DATE="$SITE_MAX"
                    fi
                fi
            fi
        fi
    done
    cd "$SCRIPT_DIR"
    
    if [ -n "$MAX_DATE" ]; then
        echo "$MAX_DATE" > "$WORKFLOW_DIR/MAX_DATE.txt"
        echo "  Updated MAX_DATE to: $MAX_DATE (from commit $NEXT_COMMIT)"
    else
        echo "  ⚠️  Could not determine MAX_DATE, using existing"
    fi
    
    # Run the workflow (this will only process new data since CURRENT_COMMIT)
    echo "  Running workflow..."
    $DOCKER_COMPOSE_CMD run --rm coastsat-validation bash -c 'cd /app && ./update_validation.sh' 2>&1 | tee "workflow_incremental_${COMMIT_NUM}.log" | tail -20
    
    WORKFLOW_EXIT=${PIPESTATUS[0]}
    
    if [ $WORKFLOW_EXIT -ne 0 ]; then
        echo -e "${RED}  ✗ Workflow failed for commit $NEXT_COMMIT${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ Incremental update $COMMIT_NUM complete${NC}"
    echo ""
    
    # Update current commit for next iteration
    CURRENT_COMMIT="$NEXT_COMMIT"
done

# Step 4: Compare final results
echo -e "${YELLOW}[Step 4] Comparing final results...${NC}"
./compare_results.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Incremental Validation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  - Processed ${#COMMITS[@]} incremental updates"
echo "  - Each update processed only new data since previous commit"
echo "  - Final results compared against validation data"
echo ""

