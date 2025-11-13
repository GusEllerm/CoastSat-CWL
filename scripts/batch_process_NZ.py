#!/usr/bin/env python3

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
import time
from tqdm.contrib.concurrent import process_map
from dotenv import load_dotenv

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

# Load environment variables from .env file
load_dotenv()

start = time.time()

CRS = 2193

# Earth engine service account
# Get from environment variable or use default (for backward compatibility)
service_account = os.getenv(
    'GEE_SERVICE_ACCOUNT',
    'service-account@iron-dynamics-294100.iam.gserviceaccount.com'
)
private_key_path = os.getenv('GEE_PRIVATE_KEY_PATH', '.private-key.json')

# Check if private key file exists
if not os.path.exists(private_key_path):
    raise FileNotFoundError(
        "Google Earth Engine private key (.private-key.json) not found. "
        "See docs/setup.md for credential setup guidance."
    )

credentials = ee.ServiceAccountCredentials(service_account, private_key_path)
ee.Initialize(credentials)

print(f"{time.time() - start}: Logged into EE")

# These polygon bounding boxes define where to download imagery
# Use filtered inputs from inputs/ directory
poly = gpd.read_file("inputs/polygons.geojson")
poly = poly[poly.id.str.startswith("nzd")]
poly.set_index("id", inplace=True)

# These are reference shorelines
shorelines = gpd.read_file("inputs/shorelines.geojson")
shorelines = shorelines[shorelines.id.str.startswith("nzd")].to_crs(CRS)
shorelines.set_index("id", inplace=True)

# Transects, origin is landward
transects_gdf = gpd.read_file("inputs/transects_extended.geojson").to_crs(CRS).drop_duplicates(subset="id")
transects_gdf.set_index("id", inplace=True)

# Test mode configuration (for limiting data download)
TEST_MODE = os.getenv('TEST_MODE', 'false').lower() == 'true'
TEST_START_DATE = os.getenv('TEST_START_DATE', '2023-01-01')
TEST_END_DATE = os.getenv('TEST_END_DATE', '2024-12-31')
TEST_SITES = [s.strip() for s in os.getenv('TEST_SITES', '').split(',') if s.strip()] if os.getenv('TEST_SITES') else []
TEST_SATELLITES = [s.strip() for s in os.getenv('TEST_SATELLITES', 'L8,L9').split(',') if s.strip()] if os.getenv('TEST_SATELLITES') else ['L8', 'L9']

# Filter sites if test mode and TEST_SITES is set
if TEST_MODE and TEST_SITES:
    # Store original sites for warning message
    original_sites = list(poly.index)
    poly = poly[poly.index.isin(TEST_SITES)]
    if len(poly) == 0:
        print(f"⚠️  WARNING: TEST_SITES={TEST_SITES} doesn't match any NZ sites!")
        print(f"   Available NZ sites: {original_sites}")
        print(f"   Note: NZ sites must start with 'nzd' prefix (e.g., 'nzd0001')")
        print(f"   Processing all NZ sites instead...")
        # Reset to all NZ sites if TEST_SITES doesn't match
        poly = gpd.read_file("inputs/polygons.geojson")
        poly = poly[poly.id.str.startswith("nzd")]
        poly.set_index("id", inplace=True)
    else:
        print(f"TEST MODE: Processing only {len(poly)} site(s): {list(poly.index)}")

print(f"{time.time() - start}: Reference polygons and shorelines loaded")
print(f"Processing {len(poly)} NZ site(s): {list(poly.index)}")

if TEST_MODE:
    print("=" * 60)
    print("TEST MODE ENABLED - Limited data download")
    print(f"  Date Range: {TEST_START_DATE} to {TEST_END_DATE}")
    print(f"  Satellites: {TEST_SATELLITES}")
    print("=" * 60)
    print()

def process_site(sitename):
    print(f"Now processing {sitename}")

    # Check if we should force start date (for validation against original data)
    FORCE_START_DATE = os.getenv('FORCE_START_DATE', '').strip()
    
    # If FORCE_START_DATE is set, start fresh (don't read existing data)
    # This ensures we process the exact date range for validation
    if FORCE_START_DATE:
        df = pd.DataFrame()
        min_date = FORCE_START_DATE
        print(f"  FORCE_START_DATE: Starting fresh from {min_date} (validation mode)")
    else:
        # Normal incremental processing: read existing data and append new results
        try:
            df = pd.read_csv(f"data/{sitename}/transect_time_series.csv")
            df.dates = pd.to_datetime(df.dates)
            # Start from last processed date + 1
            min_date = str(df.dates.max().date() + timedelta(days=1))
            # In test mode, ensure we don't go before test start date
            if TEST_MODE and min_date < TEST_START_DATE:
                min_date = TEST_START_DATE
                print(f"  TEST MODE: Using test start date: {min_date}")
        except FileNotFoundError:
            df = pd.DataFrame()
            # Use test date range if in test mode
            if TEST_MODE:
                min_date = TEST_START_DATE
                print(f"  TEST MODE: Using test start date: {min_date}")
            else:
                min_date = '1984-01-01'

    # Determine end date and satellite list
    if TEST_MODE:
        end_date = TEST_END_DATE
        sat_list = TEST_SATELLITES
        print(f"  TEST MODE: Date range {min_date} to {end_date}, Satellites: {sat_list}")
    else:
        end_date = '2030-12-30'
        sat_list = ['L5','L7','L8','L9']

    inputs = {
        "polygon": list(poly.geometry[sitename].exterior.coords),
        "dates": [min_date, end_date],
        "sat_list": sat_list,
        "sitename": sitename,
        "filepath": 'data',
        "landsat_collection": 'C02',
    }
    # Check images available first (doesn't download, just checks metadata)
    if TEST_MODE:
        print(f"  Checking available images from {min_date} to {end_date}...")
        try:
            result = SDS_download.check_images_available(inputs)
            print(f"  Found {len(result) if result else 0} available images")
        except Exception as e:
            print(f"  Warning: Could not check available images: {e}")
    
    # Download and process images
    print(f"  Downloading and processing images...")
    metadata = SDS_download.retrieve_images(inputs)

    # settings for the shoreline extraction
    settings = {
        # general parameters:
        'cloud_thresh': 0.1,        # threshold on maximum cloud cover
        'dist_clouds': 300,         # ditance around clouds where shoreline can't be mapped
        'output_epsg': CRS,       # epsg code of spatial reference system desired for the output
        # quality control:
        'check_detection': False,    # if True, shows each shoreline detection to the user for validation
        'adjust_detection': False,  # if True, allows user to adjust the postion of each shoreline by changing the threhold
        'save_figure': True,        # if True, saves a figure showing the mapped shoreline for each image
        # [ONLY FOR ADVANCED USERS] shoreline detection parameters:
        'min_beach_area': 1000,     # minimum area (in metres^2) for an object to be labelled as a beach
        'min_length_sl': 500,       # minimum length (in metres) of shoreline perimeter to be valid
        'cloud_mask_issue': False,  # switch this parameter to True if sand pixels are masked (in black) on many images
        'sand_color': 'default',    # 'default', 'latest', 'dark' (for grey/black sand beaches) or 'bright' (for white sand beaches)
        'pan_off': False,           # True to switch pansharpening off for Landsat 7/8/9 imagery
        's2cloudless_prob': 40,      # threshold to identify cloud pixels in the s2cloudless probability mask
        # add the inputs defined previously
        'inputs': inputs
    }

    # [OPTIONAL] preprocess images (cloud masking, pansharpening/down-sampling)
    #SDS_preprocess.save_jpg(metadata, settings, use_matplotlib=True)

    transects_at_site = transects_gdf[transects_gdf.site_id == sitename]
    transects = {}
    for transect_id in transects_at_site.index:
        transects[transect_id] = np.array(transects_at_site.geometry[transect_id].coords)

    ref_sl = np.array(line_merge(split(shorelines.geometry[sitename], transects_at_site.unary_union)).coords)

    settings["max_dist_ref"] = 300
    settings["reference_shoreline"] = np.flip(ref_sl)

    output = SDS_shoreline.extract_shorelines(metadata, settings)
    print(f"Have {len(output['shorelines'])} new shorelines for {sitename}")
    if not output["shorelines"]:
        return

    # Have to flip to get x,y?
    output['shorelines'] = [np.flip(s) for s in output['shorelines']]

    output = SDS_tools.remove_duplicates(output) # removes duplicates (images taken on the same date by the same satellite)
    output = SDS_tools.remove_inaccurate_georef(output, 10) # remove inaccurate georeferencing (set threshold to 10 m)

    settings_transects = { # parameters for computing intersections
                          'along_dist':          25,        # along-shore distance to use for computing the intersection
                          'min_points':          3,         # minimum number of shoreline points to calculate an intersection
                          'max_std':             15,        # max std for points around transect
                          'max_range':           30,        # max range for points around transect
                          'min_chainage':        -100,      # largest negative value along transect (landwards of transect origin)
                          'multiple_inter':      'auto',    # mode for removing outliers ('auto', 'nan', 'max')
                          'auto_prc':            0.1,       # percentage of the time that multiple intersects are present to use the max
                        }
    cross_distance = SDS_transects.compute_intersection_QC(output, transects, settings_transects) 

    # save a .csv file for Excel users
    out_dict = dict([])
    out_dict['dates'] = output['dates']
    out_dict["satname"] = output["satname"]
    for key in transects.keys():
        out_dict[key] = cross_distance[key]

    #df = pd.DataFrame(out_dict)
    new_results = pd.DataFrame(out_dict)
    if len(new_results) == 0:
        return
    df = pd.concat([df, new_results], ignore_index=True)
    df.sort_values("dates", inplace=True)
    fn = os.path.join(settings['inputs']['filepath'],settings['inputs']['sitename'],
                      'transect_time_series.csv')
    os.makedirs(os.path.dirname(fn), exist_ok=True)
    df.to_csv(fn, index=False, float_format='%.2f')
    print(f'{sitename} is done! Time-series of the shoreline change along the transects saved as:{fn}')

# Process sites (use fewer workers for test mode or minimal version)
if TEST_MODE:
    # In test mode, process sequentially to avoid multiprocessing issues
    for sitename in poly.index:
        process_site(sitename)
else:
    max_workers = min(4, len(poly.index))
    process_map(process_site, poly.index, max_workers=max_workers)

if TEST_MODE:
    print()
    print("=" * 60)
    print("TEST MODE COMPLETED")
    print("=" * 60)
    print(f"Data downloaded for {len(poly)} site(s):")
    for site_id in poly.index:
        data_dir = Path('data') / site_id
        if data_dir.exists():
            size = sum(f.stat().st_size for f in data_dir.rglob('*') if f.is_file())
            print(f"  {site_id}: {size / 1024 / 1024:.2f} MB")
    print("=" * 60)

