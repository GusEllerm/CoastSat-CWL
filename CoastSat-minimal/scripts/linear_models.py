#!/usr/bin/env python3
"""
Linear models script for CoastSat project.

This script calculates linear trends for shoreline change using tidally corrected
transect time series data. It processes all available transect time series files
and updates the transects_extended.geojson file with trend statistics.
"""

import os
import sys
from pathlib import Path
from glob import glob

import geopandas as gpd
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
from tqdm.auto import tqdm
from coastsat import SDS_transects

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)


def despike(chainage, threshold=40):
    """
    Remove outliers from chainage data.
    
    Args:
        chainage: pandas Series with chainage values
        threshold: Threshold for outlier detection
        
    Returns:
        pandas Series: Chainage with outliers removed
    """
    chainage = chainage.dropna()
    if len(chainage) == 0:
        return pd.Series(dtype=float)
    chainage, dates = SDS_transects.identify_outliers(
        chainage.tolist(), chainage.index.tolist(), threshold
    )
    return pd.Series(chainage, index=dates)


def get_trends(filepath):
    """
    Calculate linear trends for a transect time series file.
    
    Args:
        filepath: Path to transect time series CSV file
        
    Returns:
        pandas DataFrame: Trends for each transect with statistics
    """
    try:
        df = pd.read_csv(filepath)
        if "dates" not in df.columns:
            print(f"Warning: {filepath} does not have 'dates' column")
            return pd.DataFrame()
        df.dates = pd.to_datetime(df.dates)
        df.set_index("dates", inplace=True)
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return pd.DataFrame()
    
    # Handle SAR/BER files with smoothing (optional - only if needed)
    if "sar" in filepath or "ber" in filepath:
        smoothed_filename = filepath.replace(".csv", "_smoothed.csv")
        if os.path.exists(smoothed_filename):
            try:
                df = pd.read_csv(smoothed_filename)
                df.dates = pd.to_datetime(df.dates)
                df.set_index("dates", inplace=True)
            except Exception as e:
                print(f"Error reading smoothed file {smoothed_filename}: {e}")
        else:
            # Create smoothed version (only if needed)
            # For now, skip smoothing for minimal version
            pass
    
    # Convert index to years since first date
    df.index = (df.index - df.index.min()).days / 365.25
    df.drop(columns=["satname", "Unnamed: 0"], inplace=True, errors="ignore")
    
    # Calculate trends for each transect
    trends = []
    for transect_id in df.columns:
        sub_df = df[transect_id].dropna()
        if len(sub_df) == 0:
            continue
        
        x = sub_df.index.to_numpy().reshape(-1, 1)
        y = sub_df
        
        # Fit linear model
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
            "rmse": np.sqrt(mean_squared_error(y, pred)),  # root mean squared error
        })
    
    return pd.DataFrame(trends)


def calculate_linear_models(sites=None):
    """
    Calculate linear trends for all transect time series files.
    
    Args:
        sites: Optional list of site IDs to process. If None, processes all sites.
    """
    print("=" * 60)
    print("Calculating linear trends")
    print("=" * 60)
    
    # Load transects
    print("Loading transects...")
    transects = gpd.read_file("inputs/transects_extended.geojson")
    transects.set_index("id", inplace=True)
    print(f"Loaded {len(transects)} transects")
    
    # Find all transect time series files
    print("Finding transect time series files...")
    my_files = pd.Series(sorted(glob("data/*/transect_time_series_tidally_corrected.csv")))
    
    # Filter by sites if specified
    if sites:
        pattern = "|".join(sites)
        my_files = my_files[my_files.str.contains(pattern)]
    
    if len(my_files) == 0:
        print("No transect time series files found")
        return
    
    print(f"Found {len(my_files)} files to process")
    
    # Calculate trends for all files
    print("Calculating trends...")
    all_trends = []
    for filepath in tqdm(my_files, desc="Processing files"):
        trends = get_trends(filepath)
        if len(trends) > 0:
            all_trends.append(trends)
    
    if len(all_trends) == 0:
        print("No trends calculated")
        return
    
    # Combine all trends
    trends = pd.concat(all_trends).set_index("transect_id")
    print(f"Calculated trends for {len(trends)} transects")
    
    # Update transects with trends
    print("Updating transects with trends...")
    
    # Update existing columns
    transects.update(trends.drop_duplicates())
    
    # Join new columns that don't exist in transects
    new_columns = trends.columns[~trends.columns.isin(transects.columns)]
    if len(new_columns) > 0:
        transects = transects.join(trends[new_columns])
    
    # Save updated transects
    print("Saving updated transects...")
    transects.to_file("inputs/transects_extended.geojson")
    
    print("=" * 60)
    print("Linear models completed")
    print(f"Updated {len(trends)} transects with trend statistics")
    print("=" * 60)


def main():
    """Main function to run linear models."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Linear models script for CoastSat")
    parser.add_argument(
        "--sites",
        nargs="+",
        help="Specific site IDs to process (e.g., nzd0001 nzd0002). If not specified, processes all sites."
    )
    
    args = parser.parse_args()
    
    calculate_linear_models(sites=args.sites)


if __name__ == "__main__":
    main()

