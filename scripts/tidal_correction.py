#!/usr/bin/env python3
"""
Tidal correction script for CoastSat project.

This script performs two main operations:
1. Fetch tides: Downloads tide data from NIWA API for sites that don't have tides.csv
2. Apply correction: Applies tidal correction to transect time series using beach slopes

The script is designed to be run twice in the workflow:
- First pass: Fetch tides (run after batch processing)
- Second pass: Apply correction (run after slope estimation)
"""

import os
import sys
import time
from pathlib import Path
from glob import glob
from typing import Optional

import pandas as pd
import geopandas as gpd
import requests
from tqdm.auto import tqdm
from dotenv import load_dotenv
from coastsat import SDS_transects

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

# Load environment variables
load_dotenv()

# Check for required environment variable
if not os.getenv("NIWA_TIDE_API_KEY"):
    raise ValueError("NIWA_TIDE_API_KEY not found in environment variables. Please set it in .env file.")


def get_tide_for_dt(point, datetime, max_retries=5):
    """
    Get tide value for a specific datetime and point.
    
    Args:
        point: Shapely Point object with lat/long
        datetime: pandas Timestamp for the datetime
        max_retries: Maximum number of retries on error
        
    Returns:
        float: Tide value in meters
    """
    retries = 0
    while retries < max_retries:
        try:
            r = requests.get(
                "https://api.niwa.co.nz/tides/data",
                params={
                    "lat": point.y,
                    "long": point.x,
                    "numberOfDays": 2,
                    "startDate": str(datetime.date()),
                    "datum": "MSL",
                    "interval": 10,  # 10 minute resolution
                    "apikey": os.environ["NIWA_TIDE_API_KEY"]
                },
                timeout=(30, 30)
            )
            
            if r.status_code == 200:
                df = pd.DataFrame(r.json()["values"])
                df.index = pd.to_datetime(df.time)
                return df.value[datetime]
            elif r.status_code == 429:
                sleep_seconds = 30
                print(f'Rate limit exceeded. Sleeping for {sleep_seconds} seconds...')
                time.sleep(sleep_seconds)
                retries += 1
            else:
                print(f"Error: Status code {r.status_code}, Response: {r.text}")
                retries += 1
                time.sleep(5)
                
        except Exception as e:
            print(f"Exception occurred: {e}")
            retries += 1
            time.sleep(5)
    
    raise RuntimeError(f"Failed to get tide data after {max_retries} retries")


def fetch_tides(sites: Optional[list] = None):
    """
    Fetch tide data from NIWA API for sites that don't have tides.csv.
    
    Args:
        sites: Optional list of site IDs to process. If None, processes all NZ sites.
    """
    print("=" * 60)
    print("Fetching tides from NIWA API")
    print("=" * 60)
    
    # Load polygons
    print("Loading polygons...")
    poly = gpd.read_file("inputs/polygons.geojson")
    poly = poly[poly.id.str.startswith("nzd")]
    poly.set_index("id", inplace=True)
    print(f"Loaded {len(poly)} NZ polygons")
    
    # Find sites that need tides
    print("Finding sites that need tides...")
    files = pd.DataFrame({"filename": sorted(glob("data/nzd*/transect_time_series.csv"))})
    if len(files) == 0:
        print("No transect time series files found. Run batch processing first.")
        return
    
    files["sitename"] = files.filename.str.split("/").str[1]
    files["have_tides"] = files.sitename.apply(lambda s: os.path.isfile(f"data/{s}/tides.csv"))
    
    # Filter sites if specified
    if sites:
        files = files[files.sitename.isin(sites)]
        if len(files) == 0:
            print(f"No matching sites found in {sites}")
            return
    
    sites_to_process = files[~files.have_tides].sitename.tolist()
    
    if len(sites_to_process) == 0:
        print("All sites already have tides.csv")
        return
    
    print(f"Processing {len(sites_to_process)} sites: {sites_to_process}")
    
    # Fetch tides for each site
    for sitename in tqdm(sites_to_process, desc="Fetching tides"):
        print(f"\nProcessing {sitename}...")
        
        # Load transect time series
        dates = pd.to_datetime(pd.read_csv(f"data/{sitename}/transect_time_series.csv").dates).dt.round("10min")
        point = poly.geometry[sitename].centroid
        
        # Fetch tides for each date
        results = []
        for date in tqdm(dates, desc=f"Fetching tides for {sitename}", leave=False):
            try:
                result = get_tide_for_dt(point, date)
                results.append({
                    "dates": date,
                    "tide": result
                })
            except Exception as e:
                print(f"Error fetching tide for {date}: {e}")
                continue
        
        if len(results) == 0:
            print(f"Warning: No tides fetched for {sitename}")
            continue
        
        # Save tides
        df = pd.DataFrame(results)
        df.set_index("dates", inplace=True)
        df.to_csv(f"data/{sitename}/tides.csv")
        print(f"Saved {len(df)} tides to data/{sitename}/tides.csv")


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


def apply_correction(sites: Optional[list] = None, use_multiprocessing: bool = False):
    """
    Apply tidal correction to transect time series using beach slopes.
    
    Args:
        sites: Optional list of site IDs to process. If None, processes all NZ sites.
        use_multiprocessing: Whether to use multiprocessing (not recommended, may cause issues)
    """
    print("=" * 60)
    print("Applying tidal correction")
    print("=" * 60)
    
    # Load polygons
    print("Loading polygons...")
    poly = gpd.read_file("inputs/polygons.geojson")
    poly = poly[poly.id.str.startswith("nzd")]
    poly.set_index("id", inplace=True)
    print(f"Loaded {len(poly)} NZ polygons")
    
    # Load transects
    print("Loading transects...")
    transects = gpd.read_file("inputs/transects_extended.geojson").to_crs(2193).drop_duplicates(subset="id")
    transects.set_index("id", inplace=True)
    print(f"Loaded {len(transects)} transects")
    
    # Find sites to process
    print("Finding sites to process...")
    files = pd.DataFrame({"filename": sorted(glob("data/nzd*/transect_time_series.csv"))})
    if len(files) == 0:
        print("No transect time series files found. Run batch processing first.")
        return
    
    files["sitename"] = files.filename.str.split("/").str[1]
    files["have_tides"] = files.sitename.apply(lambda s: os.path.isfile(f"data/{s}/tides.csv"))
    
    # Filter sites if specified
    if sites:
        files = files[files.sitename.isin(sites)]
        if len(files) == 0:
            print(f"No matching sites found in {sites}")
            return
    
    # Only process sites that have tides
    sites_to_process = files[files.have_tides].sitename.tolist()
    
    if len(sites_to_process) == 0:
        print("No sites with tides.csv found. Run fetch_tides first.")
        return
    
    print(f"Processing {len(sites_to_process)} sites: {sites_to_process}")
    
    # Process each site
    for sitename in tqdm(sites_to_process, desc="Applying correction"):
        try:
            process_site(sitename, poly, transects)
        except Exception as e:
            print(f"Error processing {sitename}: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    print("=" * 60)
    print("Tidal correction completed")
    print("=" * 60)


def process_site(sitename: str, poly: gpd.GeoDataFrame, transects: gpd.GeoDataFrame):
    """
    Process a single site: apply tidal correction and save results.
    
    Args:
        sitename: Site ID (e.g., "nzd0001")
        poly: GeoDataFrame with polygon geometries
        transects: GeoDataFrame with transect geometries and beach slopes
    """
    # Get transects for this site
    transects_at_site = transects[transects.site_id == sitename]
    if len(transects_at_site) == 0:
        print(f"Warning: No transects found for {sitename}")
        return
    
    # Load raw intersects
    raw_intersects = pd.read_csv(f"data/{sitename}/transect_time_series.csv")
    sat_times = pd.to_datetime(raw_intersects.dates).dt.round("10min")
    raw_intersects.set_index("dates", inplace=True)
    raw_intersects.index = pd.to_datetime(raw_intersects.index)
    
    # Load tides
    tides = pd.read_csv(f"data/{sitename}/tides.csv")
    tides.set_index("dates", inplace=True)
    tides.index = pd.to_datetime(tides.index)
    tides = tides[tides.index.isin(sat_times)]
    
    # Check if we need to fetch missing tides
    if not all(sat_times.isin(tides.index)):
        dates = sat_times[~sat_times.isin(tides.index)]
        print(f"Fetching {len(dates)} missing tides for {sitename}")
        point = poly.geometry[sitename].centroid
        results = []
        for date in tqdm(dates, desc=f"Fetching tides for {sitename}", leave=False):
            try:
                result = get_tide_for_dt(point, date)
                results.append({
                    "dates": date,
                    "tide": result
                })
            except Exception as e:
                print(f"Error fetching tide for {date}: {e}")
                continue
        
        if len(results) > 0:
            new_tides = pd.DataFrame(results)
            new_tides.dates = pd.to_datetime(new_tides.dates)
            new_tides.set_index("dates", inplace=True)
            tides = pd.concat([tides, new_tides])
            tides.sort_index(inplace=True)
            tides.to_csv(f"data/{sitename}/tides.csv")
    
    # Apply tidal correction
    # Calculate corrections: tide / beach_slope for each transect
    # The notebook does: tides.tide.apply(lambda tide: tide / transects_at_site.beach_slope.interpolate().bfill().ffill())
    # This creates a DataFrame where each row is a tide date, each column is a transect
    beach_slopes = transects_at_site.beach_slope.interpolate().bfill().ffill()
    
    # Create corrections: for each tide value, divide by each beach_slope
    # This creates a DataFrame with tides as rows (indexed by tide dates) and transects as columns
    corrections = tides.tide.apply(lambda tide: tide / beach_slopes)
    
    # Align corrections with raw_intersects index
    # The notebook uses .set_index(raw_intersects.index), but we'll use reindex to align
    corrections = corrections.reindex(raw_intersects.index, fill_value=0)
    
    # Ensure column names match (should already match, but just in case)
    corrections.columns = corrections.columns.astype(str)
    
    # Apply corrections
    tidally_corrected = raw_intersects + corrections
    
    # Remove satname column before despiking (if it exists)
    if "satname" in tidally_corrected.columns:
        satname_col = tidally_corrected["satname"]
        tidally_corrected = tidally_corrected.drop(columns="satname")
    else:
        satname_col = None
    
    # Apply despike to remove outliers
    tidally_corrected = tidally_corrected.apply(despike, axis=0)
    tidally_corrected.index.name = "dates"
    
    if len(tidally_corrected) == 0:
        print(f"Warning: Despike removed all points for {sitename}")
        return
    
    # Add satname back if it existed
    if satname_col is not None:
        tidally_corrected["satname"] = raw_intersects["satname"]
    
    # Save results
    tidally_corrected.to_csv(f"data/{sitename}/transect_time_series_tidally_corrected.csv")
    print(f"Saved tidally corrected data for {sitename}: {len(tidally_corrected)} points")


def main():
    """Main function to run tidal correction."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Tidal correction script for CoastSat")
    parser.add_argument(
        "--mode",
        choices=["fetch", "apply", "both"],
        default="both",
        help="Operation mode: 'fetch' to fetch tides, 'apply' to apply correction, 'both' to do both"
    )
    parser.add_argument(
        "--sites",
        nargs="+",
        help="Specific site IDs to process (e.g., nzd0001 nzd0002). If not specified, processes all sites."
    )
    
    args = parser.parse_args()
    
    # Run operations based on mode
    if args.mode == "fetch" or args.mode == "both":
        fetch_tides(sites=args.sites)
    
    if args.mode == "apply" or args.mode == "both":
        apply_correction(sites=args.sites)


if __name__ == "__main__":
    main()

