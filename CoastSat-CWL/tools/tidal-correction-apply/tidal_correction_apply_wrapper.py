#!/usr/bin/env python3
"""
Wrapper script for tidal-correction-apply CWL tool.
Applies tidal correction to transect time series using beach slopes.
"""

import sys
import argparse
from pathlib import Path
import pandas as pd
import geopandas as gpd
from coastsat import SDS_transects


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
    chainage, dates = SDS_transects.identify_outliers(chainage.tolist(), chainage.index.tolist(), threshold)
    return pd.Series(chainage, index=dates)


def main():
    parser = argparse.ArgumentParser(description="Apply tidal correction to transect time series for a single site.")
    parser.add_argument("--transect-time-series", required=True, help="Path to transect_time_series.csv")
    parser.add_argument("--tides", required=True, help="Path to tides.csv")
    parser.add_argument("--transects-extended", required=True, help="Path to transects_extended.geojson")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--output", help="Output CSV file path (default: {site_id}_transect_time_series_tidally_corrected.csv)")
    
    args = parser.parse_args()
    
    try:
        # Determine output file
        if args.output:
            output_file = Path(args.output)
        else:
            output_file = Path(f"{args.site_id}_transect_time_series_tidally_corrected.csv")
        
        # Load transects (need CRS 2193 for calculations)
        transects = gpd.read_file(args.transects_extended).to_crs(2193).drop_duplicates(subset="id")
        transects.set_index("id", inplace=True)
        
        # Get transects for this site
        transects_at_site = transects[transects.site_id == args.site_id]
        if len(transects_at_site) == 0:
            print(f"Warning: No transects found for {args.site_id}", file=sys.stderr)
            sys.exit(1)
        
        # Load raw intersects
        raw_intersects = pd.read_csv(args.transect_time_series)
        sat_times = pd.to_datetime(raw_intersects.dates).dt.round("10min")
        raw_intersects.set_index("dates", inplace=True)
        raw_intersects.index = pd.to_datetime(raw_intersects.index)
        
        # Load tides
        tides = pd.read_csv(args.tides)
        tides.set_index("dates", inplace=True)
        tides.index = pd.to_datetime(tides.index)
        tides = tides[tides.index.isin(sat_times)]
        
        if len(tides) == 0:
            print(f"Error: No matching tides found for {args.site_id}", file=sys.stderr)
            sys.exit(1)
        
        # Apply tidal correction
        # Calculate corrections: tide / beach_slope for each transect
        # Get beach slopes for transects at this site
        beach_slopes = transects_at_site.beach_slope.interpolate().bfill().ffill()
        
        # Create corrections: for each tide value, divide by each beach_slope
        # This creates a DataFrame with tides as rows (indexed by tide dates) and transects as columns
        corrections = tides.tide.apply(lambda tide: tide / beach_slopes)
        
        # Align corrections with raw_intersects index
        corrections = corrections.reindex(raw_intersects.index, fill_value=0)
        
        # Ensure column names match (should already match, but just in case)
        corrections.columns = corrections.columns.astype(str)
        
        # Apply corrections (matches original logic: raw_intersects + corrections)
        tidally_corrected = raw_intersects + corrections
        
        # Remove satname column before despiking (if it exists)
        if "satname" in tidally_corrected.columns:
            satname_col = tidally_corrected["satname"].copy()
            tidally_corrected = tidally_corrected.drop(columns="satname")
        else:
            satname_col = None
        
        # Apply despike to remove outliers (apply to all transect columns)
        tidally_corrected = tidally_corrected.apply(despike, axis=0)
        
        tidally_corrected.index.name = "dates"
        
        if len(tidally_corrected) == 0:
            print(f"Warning: Despike removed all points for {args.site_id}", file=sys.stderr)
            sys.exit(1)
        
        # Add satname back if it existed
        if satname_col is not None:
            tidally_corrected["satname"] = raw_intersects["satname"]
        
        # Save results
        tidally_corrected.to_csv(output_file)
        print(f"Saved tidally corrected data for {args.site_id}: {len(tidally_corrected)} points", file=sys.stderr)
        
        return 0
        
    except Exception as e:
        print(f"Error applying tidal correction: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

