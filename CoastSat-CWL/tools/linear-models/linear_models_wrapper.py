#!/usr/bin/env python3
"""
Wrapper script for linear-models CWL tool.
Calculates linear trends for tidally corrected transect time series data.
Processes a single site and outputs updated transects for that site with trend statistics.
"""

import sys
import argparse
from pathlib import Path

import geopandas as gpd
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
from coastsat import SDS_transects


def calculate_trends_for_site(
    site_id: str,
    transect_time_series_path: Path,
    transects_path: Path,
    output_path: Path
):
    """
    Calculate linear trends for transects at a single site.
    
    Args:
        site_id: Site ID (e.g., "nzd0001")
        transect_time_series_path: Path to transect_time_series_tidally_corrected.csv
        transects_path: Path to transects_extended.geojson
        output_path: Path to output GeoJSON file with updated trends
    """
    # Load transects
    transects = gpd.read_file(transects_path).set_index("id")
    
    # Get transects for this site
    transects_at_site = transects[transects.site_id == site_id]
    
    if len(transects_at_site) == 0:
        print(f"Warning: No transects found for {site_id}", file=sys.stderr)
        # Output empty file or existing transects for this site?
        transects_at_site = transects[transects.site_id == site_id].copy()
        transects_at_site.to_file(output_path)
        return
    
    # Load transect time series
    try:
        df = pd.read_csv(transect_time_series_path)
        if "dates" not in df.columns:
            print(f"Warning: {transect_time_series_path} does not have 'dates' column", file=sys.stderr)
            transects_at_site.to_file(output_path)
            return
        
        df.dates = pd.to_datetime(df.dates)
        df.set_index("dates", inplace=True)
    except Exception as e:
        print(f"Error reading {transect_time_series_path}: {e}", file=sys.stderr)
        transects_at_site.to_file(output_path)
        return
    
    # Convert index to years since first date
    df.index = (df.index - df.index.min()).days / 365.25
    
    # Drop non-transect columns
    df.drop(columns=["satname", "Unnamed: 0"], inplace=True, errors="ignore")
    
    # Calculate trends for each transect
    trends = []
    
    # Only process transects that are in both the time series and transects file
    transect_ids_to_process = [t for t in transects_at_site.index if t in df.columns]
    
    for transect_id in transect_ids_to_process:
        sub_df = df[transect_id].dropna()
        if len(sub_df) == 0:
            continue
        
        x = sub_df.index.to_numpy().reshape(-1, 1)
        y = sub_df
        
        # Fit linear model
        try:
            linear_model = LinearRegression().fit(x, y)
            pred = linear_model.predict(x)
            
            # Calculate metrics
            trends.append({
                "transect_id": transect_id,
                "trend": linear_model.coef_[0],
                "intercept": linear_model.intercept_,
                "n_points": len(df[transect_id]),
                "n_points_nonan": len(sub_df),
                "r2_score": r2_score(y, pred),
                "mae": mean_absolute_error(y, pred),
                "mse": mean_squared_error(y, pred),
                "rmse": np.sqrt(mean_squared_error(y, pred)),
            })
        except Exception as e:
            print(f"Warning: Failed to calculate trend for {transect_id}: {e}", file=sys.stderr)
            continue
    
    if len(trends) == 0:
        print(f"Warning: No trends calculated for {site_id}", file=sys.stderr)
        # Output existing transects for this site
        transects_at_site.to_file(output_path)
        return
    
    # Convert trends to DataFrame
    trends_df = pd.DataFrame(trends).set_index("transect_id")
    print(f"Calculated trends for {len(trends_df)} transects at {site_id}", file=sys.stderr)
    
    # Update transects with trends
    updated_transects = transects_at_site.copy()
    
    # Update existing columns
    common_columns = trends_df.columns[trends_df.columns.isin(updated_transects.columns)]
    if len(common_columns) > 0:
        updated_transects.update(trends_df[common_columns])
    
    # Join new columns that don't exist in transects
    new_columns = trends_df.columns[~trends_df.columns.isin(updated_transects.columns)]
    if len(new_columns) > 0:
        updated_transects = updated_transects.join(trends_df[new_columns], how="left")
    
    # Save updated transects for this site
    updated_transects.to_file(output_path)
    print(f"Saved updated transects for {site_id} to {output_path}", file=sys.stderr)
    print(f"Updated {len(trends_df)} transects with trend statistics", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Calculate linear trends for transects at a single site.")
    parser.add_argument("--transect-time-series", required=True, help="Path to transect_time_series_tidally_corrected.csv")
    parser.add_argument("--transects-extended", required=True, help="Path to transects_extended.geojson")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--output", help="Output GeoJSON file path (default: {site_id}_transects_with_trends.geojson)")
    
    args = parser.parse_args()
    
    try:
        # Determine output file
        if args.output:
            output_file = Path(args.output)
        else:
            output_file = Path(f"{args.site_id}_transects_with_trends.geojson")
        
        calculate_trends_for_site(
            args.site_id,
            Path(args.transect_time_series),
            Path(args.transects_extended),
            output_file
        )
        
        return 0
        
    except Exception as e:
        print(f"Error calculating trends: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

