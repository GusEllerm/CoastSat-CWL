#!/usr/bin/env python3
"""
Wrapper script for batch-process-nz CWL tool.
Downloads satellite imagery from Google Earth Engine and extracts shorelines
for a single NZ site. Generates transect time series CSV file.
"""

import os
import sys
from pathlib import Path
import numpy as np
import warnings
warnings.filterwarnings("ignore")
import pandas as pd
from coastsat import SDS_download, SDS_preprocess, SDS_shoreline, SDS_tools, SDS_transects
import geopandas as gpd
from tqdm.auto import tqdm
import ee
from shapely.ops import split
from datetime import datetime, timedelta
from shapely import line_merge
import argparse

CRS = 2193


def process_site(
    site_id: str,
    polygons_path: Path,
    shorelines_path: Path,
    transects_path: Path,
    output_dir: Path,
    start_date: str = '1984-01-01',
    end_date: str = '2030-12-30',
    sat_list: list = None,
    gee_service_account: str = None,
    gee_private_key_path: str = None,
    force_start_date: str = None,
    cloud_thresh: float = 0.1,
    dist_clouds: int = 300,
):
    """
    Process a single NZ site: download imagery, extract shorelines, compute transect intersections.
    
    Args:
        site_id: Site ID (e.g., "nzd0001")
        polygons_path: Path to polygons.geojson
        shorelines_path: Path to shorelines.geojson
        transects_path: Path to transects_extended.geojson
        output_dir: Directory to save outputs (will create data/{site_id}/ subdirectory)
        start_date: Start date for image download (YYYY-MM-DD)
        end_date: End date for image download (YYYY-MM-DD)
        sat_list: List of satellites to use (e.g., ['L8', 'L9'])
        gee_service_account: Google Earth Engine service account email
        gee_private_key_path: Path to GEE private key JSON file
        force_start_date: Force start date (for validation mode), ignores existing data
        cloud_thresh: Cloud coverage threshold (0-1)
        dist_clouds: Distance around clouds where shoreline can't be mapped (meters)
    """
    # Authenticate with Google Earth Engine
    # Priority: 1) Command-line args, 2) Environment variables, 3) Default auth
    service_account = gee_service_account or os.getenv('GEE_SERVICE_ACCOUNT')
    
    if gee_private_key_path:
        private_key_path = Path(gee_private_key_path)
    else:
        # Try to get from environment variable
        env_key_path = os.getenv('GEE_PRIVATE_KEY_PATH')
        if env_key_path:
            private_key_path = Path(env_key_path)
        else:
            private_key_path = None
    
    if service_account and private_key_path:
        # Use service account authentication
        if not private_key_path.is_absolute():
            # If relative, assume it's in the working directory
            private_key_path = Path.cwd() / private_key_path
        
        if not private_key_path.exists():
            print(f"Error: Private key file not found: {private_key_path}", file=sys.stderr)
            sys.exit(1)
        
        credentials = ee.ServiceAccountCredentials(service_account, str(private_key_path))
        ee.Initialize(credentials)
        print(f"Authenticated with GEE using service account: {service_account}", file=sys.stderr)
    else:
        # Try to initialize with default credentials (if already authenticated)
        try:
            ee.Initialize()
            print("Using default GEE credentials", file=sys.stderr)
        except Exception as e:
            print(f"Error: GEE authentication required.", file=sys.stderr)
            print(f"  Provide --gee-service-account and --gee-private-key", file=sys.stderr)
            print(f"  Or set GEE_SERVICE_ACCOUNT and GEE_PRIVATE_KEY_PATH environment variables", file=sys.stderr)
            sys.exit(1)
    
    # Load polygons
    poly = gpd.read_file(polygons_path)
    poly = poly[poly.id.str.startswith("nzd")]
    poly.set_index("id", inplace=True)
    
    if site_id not in poly.index:
        print(f"Error: Site {site_id} not found in polygons", file=sys.stderr)
        sys.exit(1)
    
    # Load shorelines
    shorelines = gpd.read_file(shorelines_path)
    shorelines = shorelines[shorelines.id.str.startswith("nzd")].to_crs(CRS)
    shorelines.set_index("id", inplace=True)
    
    if site_id not in shorelines.index:
        print(f"Error: Site {site_id} not found in shorelines", file=sys.stderr)
        sys.exit(1)
    
    # Load transects
    transects_gdf = gpd.read_file(transects_path).to_crs(CRS).drop_duplicates(subset="id")
    transects_gdf.set_index("id", inplace=True)
    
    print(f"Processing {site_id}", file=sys.stderr)
    
    # CWL mounts output_dir as read-only, so write to current working directory instead
    workdir = Path.cwd()
    actual_output_dir = workdir / "data"
    
    # Determine start date
    if force_start_date:
        df = pd.DataFrame()
        min_date = force_start_date
        print(f"  FORCE_START_DATE: Starting fresh from {min_date} (validation mode)", file=sys.stderr)
    else:
        # Check for existing data (in the actual output location we'll write to)
        output_file = actual_output_dir / site_id / 'transect_time_series.csv'
        if output_file.exists():
            try:
                df = pd.read_csv(output_file)
                df.dates = pd.to_datetime(df.dates)
                # Start from last processed date + 1
                min_date = str(df.dates.max().date() + timedelta(days=1))
                print(f"  Found existing data, starting from {min_date}", file=sys.stderr)
            except Exception as e:
                print(f"  Warning: Could not read existing data: {e}", file=sys.stderr)
                df = pd.DataFrame()
                min_date = start_date
        else:
            df = pd.DataFrame()
            min_date = start_date
    
    # Ensure min_date doesn't go before start_date
    if min_date < start_date:
        min_date = start_date
    
    # Default satellite list
    if sat_list is None:
        sat_list = ['L5','L7','L8','L9']
    else:
        # Handle case where sat_list might be a list with a single space-separated string
        if isinstance(sat_list, list) and len(sat_list) == 1 and isinstance(sat_list[0], str) and ' ' in sat_list[0]:
            # Split the single string into multiple satellites
            sat_list = sat_list[0].split()
        elif isinstance(sat_list, str):
            # Handle case where sat_list is passed as a single string (e.g., "L8 L9")
            sat_list = sat_list.split()
        # Otherwise, sat_list is already a list of strings, use as-is
    
    print(f"  Date range: {min_date} to {end_date}", file=sys.stderr)
    print(f"  Satellites: {sat_list}", file=sys.stderr)
    
    # CWL mounts output_dir as read-only, so write to current working directory instead
    # CWL will handle copying outputs to the correct location
    workdir = Path.cwd()
    actual_output_dir = workdir / "data"
    
    # Prepare inputs for CoastSat
    inputs = {
        "polygon": list(poly.geometry[site_id].exterior.coords),
        "dates": [min_date, end_date],
        "sat_list": sat_list,
        "sitename": site_id,
        "filepath": str(actual_output_dir),
        "landsat_collection": 'C02',
    }
    
    # Download and process images
    print(f"  Downloading and processing images...", file=sys.stderr)
    try:
        metadata = SDS_download.retrieve_images(inputs)
    except Exception as e:
        print(f"Error downloading images: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
    
    if not metadata or len(metadata) == 0:
        print(f"  No images found for {site_id} in date range {min_date} to {end_date}", file=sys.stderr)
        return
    
    # Settings for shoreline extraction
    settings = {
        'cloud_thresh': cloud_thresh,
        'dist_clouds': dist_clouds,
        'output_epsg': CRS,
        'check_detection': False,
        'adjust_detection': False,
        'save_figure': True,
        'min_beach_area': 1000,
        'min_length_sl': 500,
        'cloud_mask_issue': False,
        'sand_color': 'default',
        'pan_off': False,
        's2cloudless_prob': 40,
        'inputs': inputs
    }
    
    # Get transects for this site
    transects_at_site = transects_gdf[transects_gdf.site_id == site_id]
    if len(transects_at_site) == 0:
        print(f"  Warning: No transects found for {site_id}", file=sys.stderr)
        return
    
    transects = {}
    for transect_id in transects_at_site.index:
        transects[transect_id] = np.array(transects_at_site.geometry[transect_id].coords)
    
    # Get reference shoreline for this site
    ref_sl = np.array(line_merge(split(shorelines.geometry[site_id], transects_at_site.unary_union)).coords)
    
    settings["max_dist_ref"] = 300
    settings["reference_shoreline"] = np.flip(ref_sl)
    
    # Extract shorelines
    print(f"  Extracting shorelines...", file=sys.stderr)
    output = SDS_shoreline.extract_shorelines(metadata, settings)
    
    print(f"  Found {len(output['shorelines'])} shorelines for {site_id}", file=sys.stderr)
    if not output["shorelines"]:
        print(f"  No shorelines extracted for {site_id}", file=sys.stderr)
        return
    
    # Flip to get x,y
    output['shorelines'] = [np.flip(s) for s in output['shorelines']]
    
    # Quality control
    output = SDS_tools.remove_duplicates(output)
    output = SDS_tools.remove_inaccurate_georef(output, 10)
    
    # Compute transect intersections
    settings_transects = {
        'along_dist': 25,
        'min_points': 3,
        'max_std': 15,
        'max_range': 30,
        'min_chainage': -100,
        'multiple_inter': 'auto',
        'auto_prc': 0.1,
    }
    
    print(f"  Computing transect intersections...", file=sys.stderr)
    cross_distance = SDS_transects.compute_intersection_QC(output, transects, settings_transects)
    
    # Create output DataFrame
    out_dict = {
        'dates': output['dates'],
        'satname': output['satname']
    }
    for key in transects.keys():
        out_dict[key] = cross_distance[key]
    
    new_results = pd.DataFrame(out_dict)
    if len(new_results) == 0:
        print(f"  No valid intersections computed for {site_id}", file=sys.stderr)
        return
    
    # Combine with existing data
    df = pd.concat([df, new_results], ignore_index=True)
    df.sort_values("dates", inplace=True)
    
    # Save output (to working directory - CWL will copy to output location)
    output_file = actual_output_dir / site_id / 'transect_time_series.csv'
    output_file.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_file, index=False, float_format='%.2f')
    
    print(f"  Saved transect time series: {output_file}", file=sys.stderr)
    print(f"  Total points: {len(df)}", file=sys.stderr)
    print(f"{site_id} is done!", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Process a single NZ site: download imagery and extract shorelines.")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--polygons", required=True, help="Path to polygons.geojson")
    parser.add_argument("--shorelines", required=True, help="Path to shorelines.geojson")
    parser.add_argument("--transects-extended", required=True, help="Path to transects_extended.geojson")
    parser.add_argument("--output-dir", required=True, help="Output directory (will create data/{site_id}/ subdirectory)")
    parser.add_argument("--start-date", default='1984-01-01', help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end-date", default='2030-12-30', help="End date (YYYY-MM-DD)")
    parser.add_argument("--sat-list", nargs='+', help="Satellite list (e.g., L8 L9)")
    parser.add_argument("--gee-service-account", help="Google Earth Engine service account email")
    parser.add_argument("--gee-private-key", help="Path to GEE private key JSON file")
    parser.add_argument("--force-start-date", help="Force start date (for validation mode)")
    parser.add_argument("--cloud-thresh", type=float, default=0.1, help="Cloud coverage threshold (0-1)")
    parser.add_argument("--dist-clouds", type=int, default=300, help="Distance around clouds (meters)")
    
    args = parser.parse_args()
    
    try:
        process_site(
            args.site_id,
            Path(args.polygons),
            Path(args.shorelines),
            Path(args.transects_extended),
            Path(args.output_dir),
            start_date=args.start_date,
            end_date=args.end_date,
            sat_list=args.sat_list,
            gee_service_account=args.gee_service_account,
            gee_private_key_path=args.gee_private_key,
            force_start_date=args.force_start_date,
            cloud_thresh=args.cloud_thresh,
            dist_clouds=args.dist_clouds,
        )
        
        return 0
        
    except Exception as e:
        print(f"Error processing site: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

