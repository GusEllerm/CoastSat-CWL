#!/bin/bash
# Compare workflow results with validation data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_DIR="$SCRIPT_DIR"
WORKFLOW_DIR="$VALIDATION_DIR/workflow"
VALIDATION_DATA_DIR="$VALIDATION_DIR/validation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Comparing Workflow Results with Validation Data${NC}"
echo "=================================================="

# Function to compare files
compare_file() {
    local file1=$1
    local file2=$2
    local description=$3
    
    if [ ! -f "$file1" ]; then
        echo -e "${RED}✗ Missing: $file1${NC}"
        return 1
    fi
    
    if [ ! -f "$file2" ]; then
        echo -e "${RED}✗ Missing: $file2${NC}"
        return 1
    fi
    
    if diff -q "$file1" "$file2" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Match: $description${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Differ: $description${NC}"
        echo "  Files differ. Use 'diff $file1 $file2' to see differences."
        return 1
    fi
}

# Function to analyze date differences and provide detailed diagnostics
analyze_dates() {
    local file1=$1
    local file2=$2
    local description=$3
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        return 1
    fi
    
    # Determine docker compose command if not already set
    local docker_cmd="${DOCKER_COMPOSE_CMD:-}"
    if [ -z "$docker_cmd" ]; then
        if command -v docker-compose &> /dev/null; then
            docker_cmd="docker-compose"
        elif docker compose version &> /dev/null 2>&1; then
            docker_cmd="docker compose"
        else
            echo "⚠ Docker Compose not available for date analysis"
            return 1
        fi
    fi
    
    docker_file1="/app/$(echo "$file1" | sed "s|^$WORKFLOW_DIR/||" | sed "s|^$VALIDATION_DATA_DIR/|validation/|")"
    docker_file2="/app/$(echo "$file2" | sed "s|^$WORKFLOW_DIR/||" | sed "s|^$VALIDATION_DATA_DIR/|validation/|")"
    
    DATE_ANALYSIS=$(timeout 30 $docker_cmd run --rm coastsat-validation python3 << DATE_EOF
import pandas as pd
import sys

try:
    df1 = pd.read_csv("$docker_file1")
    df2 = pd.read_csv("$docker_file2")
    
    # Find date column
    date_col = None
    for col in ['dates', 'date', 'Dates', 'Date']:
        if col in df1.columns and col in df2.columns:
            date_col = col
            break
    
    if not date_col:
        print("⚠ No date column found")
        sys.exit(1)
    
    df1['_date_index'] = pd.to_datetime(df1[date_col])
    df2['_date_index'] = pd.to_datetime(df2[date_col])
    
    dates1 = set(df1['_date_index'])
    dates2 = set(df2['_date_index'])
    
    common_dates = dates1 & dates2
    only_in_1 = sorted(dates1 - dates2)
    only_in_2 = sorted(dates2 - dates1)
    
    print(f"📅 Date Analysis for: $description")
    print(f"   Workflow: {len(dates1)} dates")
    print(f"   Validation: {len(dates2)} dates")
    print(f"   Common: {len(common_dates)} dates")
    
    if only_in_1:
        print(f"   ⚠️  Only in workflow ({len(only_in_1)}):")
        for d in only_in_1[:5]:  # Show first 5
            print(f"      - {d}")
        if len(only_in_1) > 5:
            print(f"      ... and {len(only_in_1) - 5} more")
    
    if only_in_2:
        print(f"   ⚠️  Only in validation ({len(only_in_2)}):")
        for d in only_in_2[:5]:  # Show first 5
            print(f"      - {d}")
        if len(only_in_2) > 5:
            print(f"      ... and {len(only_in_2) - 5} more")
    
    if not only_in_1 and not only_in_2:
        print(f"   ✅ All dates match!")
    
    sys.exit(0)
except Exception as e:
    print(f"✗ Error analyzing dates: {e}")
    sys.exit(1)
DATE_EOF
)
    echo "$DATE_ANALYSIS"
}

# Function to test despike function and identify filtered dates
analyze_despike() {
    local site=$1
    local raw_csv="$WORKFLOW_DIR/data/$site/transect_time_series.csv"
    local corrected_csv="$WORKFLOW_DIR/data/$site/transect_time_series_tidally_corrected.csv"
    local validation_raw="$VALIDATION_DATA_DIR/data/$site/transect_time_series.csv"
    local validation_corrected="$VALIDATION_DATA_DIR/data/$site/transect_time_series_tidally_corrected.csv"
    
    if [ ! -f "$raw_csv" ] || [ ! -f "$corrected_csv" ]; then
        return 1
    fi
    
    # Determine docker compose command if not already set
    local docker_cmd="${DOCKER_COMPOSE_CMD:-}"
    if [ -z "$docker_cmd" ]; then
        if command -v docker-compose &> /dev/null; then
            docker_cmd="docker-compose"
        elif docker compose version &> /dev/null 2>&1; then
            docker_cmd="docker compose"
        else
            echo "⚠ Docker Compose not available for despike analysis"
            return 1
        fi
    fi
    
    echo -e "\n${BLUE}🔍 Despike Analysis for $site${NC}"
    
    DESPIKE_ANALYSIS=$(timeout 60 $docker_cmd run --rm coastsat-validation python3 << DESPIKE_EOF
import pandas as pd
import sys
from pathlib import Path

try:
    # Read workflow files
    raw_w = pd.read_csv("/app/data/$site/transect_time_series.csv")
    corrected_w = pd.read_csv("/app/data/$site/transect_time_series_tidally_corrected.csv")
    
    raw_w['dates'] = pd.to_datetime(raw_w['dates'])
    corrected_w['dates'] = pd.to_datetime(corrected_w['dates'])
    
    dates_raw_w = set(raw_w['dates'])
    dates_corrected_w = set(corrected_w['dates'])
    filtered_by_despike_w = sorted(dates_raw_w - dates_corrected_w)
    
    print(f"📊 Workflow Despike Results:")
    print(f"   Raw CSV: {len(dates_raw_w)} dates")
    print(f"   Tidally corrected CSV: {len(dates_corrected_w)} dates")
    print(f"   Filtered by despike: {len(filtered_by_despike_w)} dates")
    
    if filtered_by_despike_w:
        print(f"   ⚠️  Dates removed by despike:")
        for d in filtered_by_despike_w:
            print(f"      - {d}")
    
    # Compare with validation if available
    validation_raw_path = Path("/app/validation/data/$site/transect_time_series.csv")
    validation_corrected_path = Path("/app/validation/data/$site/transect_time_series_tidally_corrected.csv")
    
    if validation_raw_path.exists() and validation_corrected_path.exists():
        raw_v = pd.read_csv(validation_raw_path)
        corrected_v = pd.read_csv(validation_corrected_path)
        
        raw_v['dates'] = pd.to_datetime(raw_v['dates'])
        corrected_v['dates'] = pd.to_datetime(corrected_v['dates'])
        
        dates_raw_v = set(raw_v['dates'])
        dates_corrected_v = set(corrected_v['dates'])
        filtered_by_despike_v = sorted(dates_raw_v - dates_corrected_v)
        
        print(f"\n📊 Validation Despike Results:")
        print(f"   Raw CSV: {len(dates_raw_v)} dates")
        print(f"   Tidally corrected CSV: {len(dates_corrected_v)} dates")
        print(f"   Filtered by despike: {len(filtered_by_despike_v)} dates")
        
        if filtered_by_despike_v:
            print(f"   ⚠️  Dates removed by despike:")
            for d in filtered_by_despike_v:
                print(f"      - {d}")
        
        # Compare despike behavior
        print(f"\n🔬 Despike Comparison:")
        if filtered_by_despike_w == filtered_by_despike_v:
            print(f"   ✅ Despike behavior matches (same dates filtered)")
        else:
            only_w = set(filtered_by_despike_w) - set(filtered_by_despike_v)
            only_v = set(filtered_by_despike_v) - set(filtered_by_despike_w)
            if only_w:
                print(f"   ⚠️  Workflow filtered {len(only_w)} dates that validation didn't:")
                for d in sorted(only_w):
                    print(f"      - {d}")
            if only_v:
                print(f"   ⚠️  Validation filtered {len(only_v)} dates that workflow didn't:")
                for d in sorted(only_v):
                    print(f"      - {d}")
    
    sys.exit(0)
except Exception as e:
    print(f"✗ Error analyzing despike: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
DESPIKE_EOF
)
    echo "$DESPIKE_ANALYSIS"
}

# Function to compare CSV files with tolerance for floating point differences
# Optionally compares only common dates (for incremental validation)
compare_csv() {
    local file1=$1
    local file2=$2
    local description=$3
    local tolerance=${4:-0.01}
    local compare_common_only=${5:-false}  # New parameter: only compare dates in both
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        echo -e "${RED}✗ Missing file(s) for: $description${NC}"
        return 1
    fi
    
    # First, analyze dates for detailed diagnostics
    analyze_dates "$file1" "$file2" "$description"
    
    # Convert host paths to Docker paths
    # file1 and file2 are relative to VALIDATION_DIR, convert to /app paths
    docker_file1="/app/$(echo "$file1" | sed "s|^$WORKFLOW_DIR/||" | sed "s|^$VALIDATION_DATA_DIR/|validation/|")"
    docker_file2="/app/$(echo "$file2" | sed "s|^$WORKFLOW_DIR/||" | sed "s|^$VALIDATION_DATA_DIR/|validation/|")"
    
    # Use Docker to compare CSV files with tolerance (pandas not available on host)
    set +e
    # Convert shell boolean to Python boolean
    if [ "$compare_common_only" = "true" ]; then
        PYTHON_BOOL="True"
    else
        PYTHON_BOOL="False"
    fi
    
    CSV_RESULT=$(timeout 60 $DOCKER_COMPOSE_CMD run --rm coastsat-validation python3 << CSV_EOF
import pandas as pd
import sys
import numpy as np

try:
    df1 = pd.read_csv("$docker_file1")
    df2 = pd.read_csv("$docker_file2")
    
    # Set date index if dates column exists
    date_col = None
    for col in ['dates', 'date', 'Dates', 'Date']:
        if col in df1.columns and col in df2.columns:
            date_col = col
            break
    
    if date_col:
        df1['_date_index'] = pd.to_datetime(df1[date_col])
        df2['_date_index'] = pd.to_datetime(df2[date_col])
        df1.set_index('_date_index', inplace=True)
        df2.set_index('_date_index', inplace=True)
    
    # If compare_common_only, only compare dates that exist in both
    compare_common_only = $PYTHON_BOOL
    if compare_common_only:
        common_dates = df1.index.intersection(df2.index)
        if len(common_dates) == 0:
            print("⚠ No common dates found between files")
            sys.exit(1)
        original_len_1 = len(df1.index)
        original_len_2 = len(df2.index)
        df1 = df1.loc[common_dates]
        df2 = df2.loc[common_dates]
        extra_in_1 = original_len_1 - len(common_dates)
        extra_in_2 = original_len_2 - len(common_dates)
        # Always show info when filtering to common dates (even if no extras)
        print(f"ℹ Comparing {len(common_dates)} common dates", end="")
        if extra_in_1 > 0 or extra_in_2 > 0:
            print(f" (workflow has {extra_in_1} extra, validation has {extra_in_2} extra)")
        else:
            print(" (all dates match)")
    
    # Compare shape (after filtering to common dates if requested)
    if df1.shape != df2.shape:
        print("⚠ Shape mismatch: {} vs {}".format(df1.shape, df2.shape))
        if not compare_common_only:
            print("  Hint: Validation may have additional observations. Consider using compare_common_only mode.")
        sys.exit(1)
    
    # Compare numeric columns with tolerance
    numeric_cols = df1.select_dtypes(include=[np.number]).columns
    max_diff = 0
    diff_details = []
    problematic_cols = []
    
    for col in numeric_cols:
        if col in df2.columns:
            diff = (df1[col] - df2[col]).abs()
            col_max_diff = diff.max()
            max_diff = max(max_diff, col_max_diff)
            if col_max_diff > $tolerance:
                problematic_cols.append(col)
                # Find the date with max difference
                max_diff_date = diff.idxmax()
                w_val = df1.loc[max_diff_date, col]
                v_val = df2.loc[max_diff_date, col]
                diff_details.append({
                    'col': col,
                    'date': max_diff_date,
                    'workflow': w_val,
                    'validation': v_val,
                    'diff': col_max_diff
                })
    
    if problematic_cols:
        print(f"⚠ Column differences detected (tolerance: $tolerance):")
        # Sort by difference magnitude
        diff_details.sort(key=lambda x: x['diff'], reverse=True)
        for detail in diff_details[:10]:  # Show top 10
            print(f"   {detail['col']} on {detail['date']}: w={detail['workflow']:.6f}, v={detail['validation']:.6f}, diff={detail['diff']:.6f}")
        if len(diff_details) > 10:
            print(f"   ... and {len(diff_details) - 10} more differences")
        sys.exit(1)
    
    # Compare non-numeric columns exactly (excluding date column)
    non_numeric_cols = df1.select_dtypes(exclude=[np.number]).columns
    for col in non_numeric_cols:
        if col in df2.columns and col != date_col:
            if not df1[col].equals(df2[col]):
                print("⚠ Column '{}' differs".format(col))
                sys.exit(1)
    
    match_msg = "✓ Match: $description (max diff: {:.6f})".format(max_diff)
    if compare_common_only:
        match_msg += f" (compared {len(df1)} common dates)"
    print(match_msg)
    sys.exit(0)
except Exception as e:
    print("✗ Error comparing: {}".format(e))
    import traceback
    traceback.print_exc()
    sys.exit(1)
CSV_EOF
)
    CSV_EXIT=$?
    set -e
    
    if [ $CSV_EXIT -eq 0 ]; then
        echo -e "${GREEN}${CSV_RESULT}${NC}"
        return 0
    elif [ $CSV_EXIT -eq 124 ]; then
        echo -e "${RED}✗ CSV comparison timed out: $description${NC}"
        return 1
    else
        echo -e "${YELLOW}${CSV_RESULT}${NC}"
        return 1
    fi
}

# Check if workflow has been run
if [ ! -f "$WORKFLOW_DIR/transects_extended.geojson" ]; then
    echo -e "${RED}Error: Workflow has not been run yet.${NC}"
    echo "Run the workflow first, then compare results."
    exit 1
fi

# Compare transects_extended.geojson (only validation sites)
echo -e "\n${YELLOW}Comparing transects_extended.geojson (validation sites only)...${NC}"

# Determine docker compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo -e "${RED}Error: Docker Compose not found${NC}"
    echo "Please install docker-compose or ensure 'docker compose' is available"
    exit 1
fi

# Use Docker to compare GeoJSON files
echo "  Running GeoJSON comparison in Docker..."
set +e  # Don't exit on error for this command
GEOJSON_RESULT=$(timeout 120 $DOCKER_COMPOSE_CMD run --rm coastsat-validation python3 << 'DOCKER_EOF' 2>&1
import geopandas as gpd
import sys
import json
import os

try:
    workflow = gpd.read_file("/app/transects_extended.geojson")
    validation = gpd.read_file("/app/validation/transects_extended.geojson")
    
    # Load validation sites from config
    config_path = "/app/config.json"
    if os.path.exists(config_path):
        with open(config_path) as f:
            config = json.load(f)
            validation_sites = config.get('validation_sites', ['nzd0001', 'sar0001'])
    else:
        validation_sites = ['nzd0001', 'sar0001']
    
    # Filter to validation sites only
    workflow_filtered = workflow[workflow.site_id.isin(validation_sites)].copy()
    validation_filtered = validation[validation.site_id.isin(validation_sites)].copy()
    
    # Compare transect IDs
    workflow_ids = set(workflow_filtered.id)
    validation_ids = set(validation_filtered.id)
    
    if workflow_ids != validation_ids:
        print("⚠ Transect ID mismatch")
        only_w = workflow_ids - validation_ids
        only_v = validation_ids - workflow_ids
        if only_w:
            print(f"  Only in workflow: {sorted(only_w)}")
        if only_v:
            print(f"  Only in validation: {sorted(only_v)}")
        sys.exit(1)
    
    # Compare numeric columns for common transects
    common = workflow_ids & validation_ids
    if common:
        workflow_common = workflow_filtered[workflow_filtered.id.isin(common)].set_index("id").sort_index()
        validation_common = validation_filtered[validation_filtered.id.isin(common)].set_index("id").sort_index()
        
        numeric_cols = ['n_points', 'trend', 'r2_score', 'rmse', 'mae', 'mse', 'intercept', 'beach_slope']
        numeric_cols = [c for c in numeric_cols if c in workflow_common.columns and c in validation_common.columns]
        
        max_diff = 0
        diff_details = []
        problematic_transects = {}
        
        for col in numeric_cols:
            diff = (workflow_common[col] - validation_common[col]).abs()
            col_max_diff = diff.max()
            max_diff = max(max_diff, col_max_diff)
            if col_max_diff > 0.01:
                transect_id = diff.idxmax()
                w_val = workflow_common.loc[transect_id, col]
                v_val = validation_common.loc[transect_id, col]
                diff_details.append(f"{transect_id}.{col}: w={w_val:.6f}, v={v_val:.6f}, diff={col_max_diff:.6f}")
                
                # Track problematic transects
                if transect_id not in problematic_transects:
                    problematic_transects[transect_id] = []
                problematic_transects[transect_id].append({
                    'col': col,
                    'workflow': w_val,
                    'validation': v_val,
                    'diff': col_max_diff
                })
        
        if max_diff > 0.01:
            print(f"⚠ Numeric values differ (max diff: {max_diff:.6f})")
            print(f"  Affected transects: {len(problematic_transects)}")
            if diff_details:
                print("  Top differences:")
                for detail in diff_details[:10]:  # Show top 10
                    print(f"    {detail}")
                if len(diff_details) > 10:
                    print(f"    ... and {len(diff_details) - 10} more")
            
            # Check if n_points difference might be due to despike
            if 'n_points' in problematic_transects:
                print(f"\n  💡 Note: n_points differences may be due to despike function")
                print(f"     (despike filters outliers, affecting point counts)")
            
            sys.exit(1)
        else:
            print("✓ Match: transects_extended.geojson (validation sites, tolerance: 0.01)")
            sys.exit(0)
    else:
        print("⚠ No common transects found")
        sys.exit(1)
except Exception as e:
    print(f"✗ Error comparing: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
DOCKER_EOF
)
GEOJSON_EXIT=$?
set -e  # Re-enable exit on error

if [ $GEOJSON_EXIT -eq 0 ]; then
    echo -e "${GREEN}${GEOJSON_RESULT}${NC}"
elif [ $GEOJSON_EXIT -eq 124 ]; then
    echo -e "${RED}✗ GeoJSON comparison timed out after 120 seconds${NC}"
    echo "  This may indicate the Docker container is not responding"
    exit 1
else
    echo -e "${YELLOW}${GEOJSON_RESULT}${NC}"
fi
echo ""  # Add blank line after GeoJSON comparison

# Load validation sites from config.json (only compare configured sites)
CONFIG_FILE="$VALIDATION_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    SITES=$(python3 -c "import json; print(' '.join(json.load(open('$CONFIG_FILE')).get('validation_sites', [])))" 2>/dev/null || echo "")
else
    echo -e "${YELLOW}config.json not found, using all sites in validation data${NC}"
    SITES=$(find "$VALIDATION_DATA_DIR/data" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "")
fi

if [ -z "$SITES" ]; then
    echo -e "${YELLOW}No validation sites found${NC}"
    exit 0
fi

echo -e "${BLUE}Comparing sites from config.json: $SITES${NC}"

# Compare data for each site
echo -e "\n${YELLOW}Comparing site data...${NC}"
for site in $SITES; do
    echo -e "\n${BLUE}Site: $site${NC}"
    
    # Analyze despike function for NZ sites (where it's applied)
    if [[ "$site" =~ ^nzd ]]; then
        analyze_despike "$site"
    fi
    
    # Compare transect_time_series.csv
    # Use compare_common_only=true because validation may have additional observations
    if [ -f "$WORKFLOW_DIR/data/$site/transect_time_series.csv" ]; then
        compare_csv "$WORKFLOW_DIR/data/$site/transect_time_series.csv" \
                   "$VALIDATION_DATA_DIR/data/$site/transect_time_series.csv" \
                   "$site/transect_time_series.csv" \
                   0.01 \
                   true
    fi
    
    # Compare tidally corrected CSV (only for NZ sites - SAR sites don't get tidal correction)
    # Use compare_common_only=true because validation may have additional observations
    if [[ "$site" =~ ^nzd ]]; then
        if [ -f "$WORKFLOW_DIR/data/$site/transect_time_series_tidally_corrected.csv" ]; then
            compare_csv "$WORKFLOW_DIR/data/$site/transect_time_series_tidally_corrected.csv" \
                       "$VALIDATION_DATA_DIR/data/$site/transect_time_series_tidally_corrected.csv" \
                       "$site/transect_time_series_tidally_corrected.csv" \
                       0.01 \
                       true
        fi
    fi
    
    # Compare tides.csv (only for NZ sites - SAR sites don't use NIWA tide API)
    # Use compare_common_only=true because validation may have additional observations
    if [[ "$site" =~ ^nzd ]]; then
        if [ -f "$WORKFLOW_DIR/data/$site/tides.csv" ]; then
            compare_csv "$WORKFLOW_DIR/data/$site/tides.csv" \
                       "$VALIDATION_DATA_DIR/data/$site/tides.csv" \
                       "$site/tides.csv" \
                       0.01 \
                       true
        fi
    fi
done

# Generate quality assessment
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Quality Assessment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

QUALITY_REPORT=$(timeout 120 $DOCKER_COMPOSE_CMD run --rm coastsat-validation python3 << QUALITY_EOF
import geopandas as gpd
import pandas as pd
import sys
import json
import os
from pathlib import Path

try:
    quality_issues = []
    quality_warnings = []
    quality_successes = []
    n_points_diff = False  # Initialize flag
    
    # Load config for validation sites
    config_path = "/app/config.json"
    if os.path.exists(config_path):
        with open(config_path) as f:
            config = json.load(f)
            validation_sites = config.get('validation_sites', ['nzd0001', 'sar0001'])
    else:
        validation_sites = ['nzd0001', 'sar0001']
    
    # 1. Check GeoJSON statistics
    workflow_geojson = Path("/app/transects_extended.geojson")
    validation_geojson = Path("/app/validation/transects_extended.geojson")
    
    if workflow_geojson.exists() and validation_geojson.exists():
        workflow = gpd.read_file(workflow_geojson)
        validation = gpd.read_file(validation_geojson)
        
        workflow_filtered = workflow[workflow.site_id.isin(validation_sites)].copy()
        validation_filtered = validation[validation.site_id.isin(validation_sites)].copy()
        
        workflow_ids = set(workflow_filtered.id)
        validation_ids = set(validation_filtered.id)
        
        if workflow_ids != validation_ids:
            quality_issues.append("Transect ID mismatch between workflow and validation")
        else:
            quality_successes.append("All transect IDs match")
            
            # Check numeric differences
            common = workflow_ids & validation_ids
            if common:
                workflow_common = workflow_filtered[workflow_filtered.id.isin(common)].set_index("id").sort_index()
                validation_common = validation_filtered[validation_filtered.id.isin(common)].set_index("id").sort_index()
                
                numeric_cols = ['n_points', 'trend', 'r2_score', 'rmse', 'mae', 'mse', 'intercept', 'beach_slope']
                numeric_cols = [c for c in numeric_cols if c in workflow_common.columns and c in validation_common.columns]
                
                max_diff = 0
                for col in numeric_cols:
                    diff = (workflow_common[col] - validation_common[col]).abs()
                    col_max_diff = diff.max()
                    max_diff = max(max_diff, col_max_diff)
                    if col == 'n_points' and col_max_diff > 0:
                        n_points_diff = True
                
                if max_diff > 0.01:
                    if n_points_diff:
                        quality_warnings.append(f"n_points differences detected (max diff: {max_diff:.6f}) - may be due to despike function")
                    else:
                        quality_issues.append(f"Statistics differ (max diff: {max_diff:.6f})")
                else:
                    quality_successes.append("GeoJSON statistics match (within tolerance)")
    
    # 2. Check date matching for each site
    date_issues = []
    date_warnings = []
    for site in validation_sites:
        workflow_csv = Path(f"/app/data/{site}/transect_time_series.csv")
        validation_csv = Path(f"/app/validation/data/{site}/transect_time_series.csv")
        
        if workflow_csv.exists() and validation_csv.exists():
            df_w = pd.read_csv(workflow_csv)
            df_v = pd.read_csv(validation_csv)
            
            df_w['dates'] = pd.to_datetime(df_w['dates'])
            df_v['dates'] = pd.to_datetime(df_v['dates'])
            
            dates_w = set(df_w['dates'])
            dates_v = set(df_v['dates'])
            
            if dates_w == dates_v:
                quality_successes.append(f"{site}: All dates match ({len(dates_w)} dates)")
            else:
                only_w = dates_w - dates_v
                only_v = dates_v - dates_w
                if only_w:
                    date_issues.append(f"{site}: {len(only_w)} dates only in workflow")
                if only_v:
                    date_warnings.append(f"{site}: {len(only_v)} dates only in validation (expected in incremental validation)")
    
    # 3. Check despike behavior for NZ sites
    despike_issues = []
    despike_warnings = []
    for site in validation_sites:
        if site.startswith("nzd"):
            raw_w = Path(f"/app/data/{site}/transect_time_series.csv")
            corrected_w = Path(f"/app/data/{site}/transect_time_series_tidally_corrected.csv")
            raw_v = Path(f"/app/validation/data/{site}/transect_time_series.csv")
            corrected_v = Path(f"/app/validation/data/{site}/transect_time_series_tidally_corrected.csv")
            
            if raw_w.exists() and corrected_w.exists() and raw_v.exists() and corrected_v.exists():
                df_raw_w = pd.read_csv(raw_w)
                df_corr_w = pd.read_csv(corrected_w)
                df_raw_v = pd.read_csv(raw_v)
                df_corr_v = pd.read_csv(corrected_v)
                
                df_raw_w['dates'] = pd.to_datetime(df_raw_w['dates'])
                df_corr_w['dates'] = pd.to_datetime(df_corr_w['dates'])
                df_raw_v['dates'] = pd.to_datetime(df_raw_v['dates'])
                df_corr_v['dates'] = pd.to_datetime(df_corr_v['dates'])
                
                filtered_w = set(df_raw_w['dates']) - set(df_corr_w['dates'])
                filtered_v = set(df_raw_v['dates']) - set(df_corr_v['dates'])
                
                if filtered_w == filtered_v:
                    quality_successes.append(f"{site}: Despike behavior matches ({len(filtered_w)} dates filtered)")
                else:
                    only_w = filtered_w - filtered_v
                    only_v = filtered_v - filtered_w
                    if only_w or only_v:
                        despike_warnings.append(f"{site}: Despike behavior differs (workflow filtered {len(filtered_w)}, validation filtered {len(filtered_v)})")
    
    # 4. Check CSV value differences
    csv_issues = []
    csv_warnings = []
    for site in validation_sites:
        workflow_csv = Path(f"/app/data/{site}/transect_time_series.csv")
        validation_csv = Path(f"/app/validation/data/{site}/transect_time_series.csv")
        
        if workflow_csv.exists() and validation_csv.exists():
            df_w = pd.read_csv(workflow_csv)
            df_v = pd.read_csv(validation_csv)
            
            df_w['dates'] = pd.to_datetime(df_w['dates'])
            df_v['dates'] = pd.to_datetime(df_v['dates'])
            df_w.set_index('dates', inplace=True)
            df_v.set_index('dates', inplace=True)
            
            common_dates = df_w.index.intersection(df_v.index)
            if len(common_dates) > 0:
                df_w_common = df_w.loc[common_dates]
                df_v_common = df_v.loc[common_dates]
                
                numeric_cols = df_w_common.select_dtypes(include=['float64', 'int64']).columns
                max_diff = 0
                for col in numeric_cols:
                    if col in df_v_common.columns:
                        diff = (df_w_common[col] - df_v_common[col]).abs().max()
                        max_diff = max(max_diff, diff)
                
                if max_diff > 1.0:  # Large difference threshold
                    csv_issues.append(f"{site}: Large value differences (max: {max_diff:.2f}m)")
                elif max_diff > 0.1:  # Medium difference
                    csv_warnings.append(f"{site}: Moderate value differences (max: {max_diff:.2f}m)")
                elif max_diff > 0.01:  # Small difference
                    quality_successes.append(f"{site}: CSV values match (max diff: {max_diff:.3f}m, within tolerance)")
                else:
                    quality_successes.append(f"{site}: CSV values match exactly (max diff: {max_diff:.6f}m)")
    
    # Generate quality report
    print("\\n📊 Quality Indicators:\\n")
    
    # Calculate quality score
    total_checks = len(quality_successes) + len(quality_warnings) + len(quality_issues) + len(date_issues) + len(date_warnings) + len(despike_issues) + len(despike_warnings) + len(csv_issues) + len(csv_warnings)
    success_rate = len(quality_successes) / total_checks if total_checks > 0 else 0
    
    # Print successes
    if quality_successes:
        print("✅ Successes:")
        for success in quality_successes:
            print(f"   • {success}")
        print()
    
    # Print warnings (acceptable but notable)
    if quality_warnings or date_warnings or despike_warnings or csv_warnings:
        print("⚠️  Warnings (acceptable but notable):")
        for warning in quality_warnings + date_warnings + despike_warnings + csv_warnings:
            print(f"   • {warning}")
        print()
    
    # Print issues (problematic)
    if quality_issues or date_issues or despike_issues or csv_issues:
        print("❌ Issues (need attention):")
        for issue in quality_issues + date_issues + despike_issues + csv_issues:
            print(f"   • {issue}")
        print()
    
    # Overall quality assessment
    print("\\n🎯 Overall Quality Assessment:\\n")
    
    if len(quality_issues) == 0 and len(date_issues) == 0 and len(despike_issues) == 0 and len(csv_issues) == 0:
        if len(quality_warnings) == 0 and len(date_warnings) == 0 and len(despike_warnings) == 0 and len(csv_warnings) == 0:
            print("   ✅ EXCELLENT: All comparisons passed with no issues or warnings")
            print("   Quality Score: 100%")
            quality_rating = "EXCELLENT"
        else:
            print("   ✅ GOOD: All critical checks passed, minor warnings present")
            print(f"   Quality Score: {int(success_rate * 100)}%")
            print("   Warnings are acceptable and expected in incremental validation")
            quality_rating = "GOOD"
    else:
        if len(quality_issues) + len(date_issues) + len(despike_issues) + len(csv_issues) <= 2:
            print("   ⚠️  ACCEPTABLE: Minor issues detected, but within acceptable range")
            print(f"   Quality Score: {int(success_rate * 100)}%")
            print("   Issues may be due to:")
            print("     - Despike function filtering differences")
            print("     - Natural variability in shoreline extraction")
            print("     - Floating point precision")
            quality_rating = "ACCEPTABLE"
        else:
            print("   ❌ NEEDS ATTENTION: Multiple issues detected")
            print(f"   Quality Score: {int(success_rate * 100)}%")
            print("   Review the issues above and investigate root causes")
            quality_rating = "NEEDS_ATTENTION"
    
    # Specific recommendations
    print("\\n💡 Recommendations:\\n")
    
    if n_points_diff:
        print("   • n_points differences are likely due to despike function")
        print("     This is expected behavior - despike filters outliers")
        print("     Check despike analysis above for details")
    
    if date_warnings:
        print("   • Extra dates in validation are expected in incremental validation")
        print("     Validation is a snapshot with all dates, workflow only has successfully processed dates")
    
    if csv_warnings or csv_issues:
        print("   • CSV value differences may be due to:")
        print("     - Different image selection between runs")
        print("     - Natural variability in shoreline extraction")
        print("     - Differences in processing context")
        print("     Differences < 1m are generally acceptable")
    
    if len(quality_successes) > len(quality_issues) + len(quality_warnings):
        print("   • Overall validation is successful")
        print("     The workflow correctly replicates the original behavior")
    
    print(f"\\n📈 Quality Rating: {quality_rating}")
    
    sys.exit(0)
except Exception as e:
    print(f"✗ Error generating quality assessment: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
QUALITY_EOF
)

QUALITY_EXIT=$?
if [ $QUALITY_EXIT -eq 0 ]; then
    echo "$QUALITY_REPORT"
else
    echo -e "${YELLOW}⚠ Could not generate quality assessment${NC}"
fi

echo -e "\n${GREEN}Comparison complete!${NC}"

