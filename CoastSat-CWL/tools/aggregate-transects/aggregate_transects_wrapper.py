#!/usr/bin/env python3
"""
Wrapper script for aggregate-transects CWL tool.
Aggregates per-site transect GeoJSON files into a single transects_extended.geojson file.

This tool is used after slope-estimation and linear-models steps to merge
per-site outputs back into the main transects_extended.geojson file.
"""

import os
import sys
from pathlib import Path
import argparse
import geopandas as gpd
import pandas as pd
import numpy as np

def aggregate_transects(
    base_transects: Path,
    per_site_transects: list,
    output_file: Path,
    update_columns: list = None,
):
    """
    Aggregate per-site transect GeoJSON files into a single transects_extended.geojson.
    
    Args:
        base_transects: Path to the base transects_extended.geojson file (contains all transects)
        per_site_transects: List of paths to per-site transect GeoJSON files (e.g., from slope-estimation or linear-models)
        output_file: Path to output aggregated transects_extended.geojson file
        update_columns: List of column names to update from per-site files (if None, updates all numeric columns)
    """
    print(f"Loading base transects from: {base_transects}", file=sys.stderr)
    base_gdf = gpd.read_file(base_transects).set_index("id")
    print(f"  Loaded {len(base_gdf)} transects", file=sys.stderr)
    
    if not per_site_transects:
        print("Warning: No per-site transect files provided, copying base file", file=sys.stderr)
        base_gdf.reset_index().to_file(output_file, driver="GeoJSON")
        return
    
    # Track which transects were updated
    updated_ids = set()
    
    # Process each per-site file
    for site_file in per_site_transects:
        site_file = Path(site_file)
        if not site_file.exists():
            print(f"Warning: Per-site file not found: {site_file}, skipping", file=sys.stderr)
            continue
        
        print(f"Processing per-site file: {site_file}", file=sys.stderr)
        site_gdf = gpd.read_file(site_file).set_index("id")
        print(f"  Loaded {len(site_gdf)} transects from site file", file=sys.stderr)
        
        # Determine which columns to update
        if update_columns is None:
            # Auto-detect numeric columns (excluding geometry)
            numeric_cols = site_gdf.select_dtypes(include=[np.number]).columns.tolist()
            # Common columns to update (based on tool outputs)
            # For slope-estimation: beach_slope, cil, ciu
            # For linear-models: trend, intercept, r2_score, mae, mse, rmse, n_points
            update_cols = numeric_cols
        else:
            update_cols = update_columns
        
        # Only update columns that exist in both dataframes
        cols_to_update = [col for col in update_cols if col in site_gdf.columns and col in base_gdf.columns]
        
        if not cols_to_update:
            print(f"  Warning: No matching columns to update from {site_file}", file=sys.stderr)
            continue
        
        print(f"  Updating columns: {cols_to_update}", file=sys.stderr)
        
        # Update base transects with values from site file
        # Only update transects that exist in the site file
        common_ids = base_gdf.index.intersection(site_gdf.index)
        if len(common_ids) == 0:
            print(f"  Warning: No matching transect IDs between base and {site_file}", file=sys.stderr)
            continue
        
        for transect_id in common_ids:
            for col in cols_to_update:
                # Only update if the value is not NaN in the site file
                if pd.notna(site_gdf.loc[transect_id, col]):
                    base_gdf.loc[transect_id, col] = site_gdf.loc[transect_id, col]
                    updated_ids.add(transect_id)
        
        print(f"  Updated {len(common_ids)} transects from this site file", file=sys.stderr)
    
    print(f"Total transects updated: {len(updated_ids)}", file=sys.stderr)
    print(f"Saving aggregated transects to: {output_file}", file=sys.stderr)
    
    # Save aggregated transects
    base_gdf.reset_index().to_file(output_file, driver="GeoJSON")
    print(f"Aggregation complete. Output file: {output_file}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Aggregate per-site transect GeoJSON files into a single transects_extended.geojson file.")
    parser.add_argument("--base-transects", required=True, help="Path to base transects_extended.geojson file")
    parser.add_argument("--per-site-transects", nargs="+", required=True, help="Paths to per-site transect GeoJSON files")
    parser.add_argument("--output", required=True, help="Path to output aggregated transects_extended.geojson file")
    parser.add_argument("--update-columns", nargs="+", help="List of column names to update (default: all numeric columns)")
    
    args = parser.parse_args()
    
    try:
        aggregate_transects(
            Path(args.base_transects),
            [Path(p) for p in args.per_site_transects],
            Path(args.output),
            args.update_columns,
        )
        return 0
        
    except Exception as e:
        print(f"Error aggregating transects: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

