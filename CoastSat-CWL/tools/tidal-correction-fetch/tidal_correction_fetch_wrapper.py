#!/usr/bin/env python3
"""
Wrapper script for tidal-correction-fetch CWL tool.
Fetches tide data from NIWA API for a single site.
"""

import sys
import argparse
import os
import time
from pathlib import Path
import pandas as pd
import geopandas as gpd
import requests
from tqdm import tqdm


def get_tide_for_dt(point, datetime, api_key, max_retries=5):
    """
    Get tide value for a specific datetime and point.
    
    Args:
        point: Shapely Point object with lat/long
        datetime: pandas Timestamp for the datetime
        api_key: NIWA Tide API key
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
                    "apikey": api_key
                },
                timeout=(30, 30)
            )
            
            if r.status_code == 200:
                df = pd.DataFrame(r.json()["values"])
                df.index = pd.to_datetime(df.time)
                return df.value[datetime]
            elif r.status_code == 429:
                sleep_seconds = 30
                print(f'Rate limit exceeded. Sleeping for {sleep_seconds} seconds...', file=sys.stderr)
                time.sleep(sleep_seconds)
                retries += 1
            else:
                print(f"Error: Status code {r.status_code}, Response: {r.text}", file=sys.stderr)
                retries += 1
                time.sleep(5)
                
        except Exception as e:
            print(f"Exception occurred: {e}", file=sys.stderr)
            retries += 1
            time.sleep(5)
    
    raise RuntimeError(f"Failed to get tide data after {max_retries} retries")


def main():
    parser = argparse.ArgumentParser(description="Fetch tide data from NIWA API for a single site.")
    parser.add_argument("--polygons", required=True, help="Path to polygons.geojson")
    parser.add_argument("--transect-time-series", required=True, help="Path to transect_time_series.csv")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--api-key", help="NIWA Tide API key (or use NIWA_TIDE_API_KEY env var)")
    parser.add_argument("--output", help="Output CSV file path (default: {site_id}_tides.csv)")
    
    args = parser.parse_args()
    
    # Get API key from argument or environment variable
    api_key = args.api_key or os.getenv("NIWA_TIDE_API_KEY")
    if not api_key:
        print("Error: NIWA Tide API key required. Provide --api-key or set NIWA_TIDE_API_KEY environment variable", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Determine output file
        if args.output:
            output_file = Path(args.output)
        else:
            output_file = Path(f"{args.site_id}_tides.csv")
        
        # Load polygons
        poly = gpd.read_file(args.polygons)
        poly = poly[poly.id.str.startswith("nzd")]
        poly.set_index("id", inplace=True)
        
        if args.site_id not in poly.index:
            print(f"Error: Site {args.site_id} not found in polygons", file=sys.stderr)
            sys.exit(1)
        
        # Get site centroid
        point = poly.geometry[args.site_id].centroid
        
        # Load transect time series to get dates
        dates = pd.to_datetime(pd.read_csv(args.transect_time_series).dates).dt.round("10min")
        
        if len(dates) == 0:
            print(f"Error: No dates found in transect time series", file=sys.stderr)
            sys.exit(1)
        
        print(f"Fetching tides for {len(dates)} dates...", file=sys.stderr)
        
        # Fetch tides for each date
        results = []
        for date in tqdm(dates, desc=f"Fetching tides for {args.site_id}", leave=False):
            try:
                result = get_tide_for_dt(point, date, api_key)
                results.append({
                    "dates": date,
                    "tide": result
                })
            except Exception as e:
                print(f"Error fetching tide for {date}: {e}", file=sys.stderr)
                continue
        
        if len(results) == 0:
            print(f"Error: No tides fetched for {args.site_id}", file=sys.stderr)
            sys.exit(1)
        
        # Save tides
        df = pd.DataFrame(results)
        df.set_index("dates", inplace=True)
        df.to_csv(output_file)
        print(f"Saved {len(df)} tides to {output_file}", file=sys.stderr)
        
        return 0
        
    except Exception as e:
        print(f"Error fetching tides: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

