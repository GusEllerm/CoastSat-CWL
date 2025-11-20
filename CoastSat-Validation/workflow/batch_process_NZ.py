#!/usr/bin/env python3

import os
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

start = time.time()

CRS = 2193

# Earth engine service account
service_account = 'service-account@iron-dynamics-294100.iam.gserviceaccount.com'
credentials = ee.ServiceAccountCredentials(service_account, '.private-key.json')
ee.Initialize(credentials)

print(f"{time.time() - start}: Logged into EE")

# Load validation sites from config
import sys
import os
import json

# Try multiple paths for load_config
config_paths = [
    os.path.join(os.path.dirname(__file__), '..', 'scripts', 'load_config.py'),
    os.path.join(os.path.dirname(__file__), '..', '..', 'scripts', 'load_config.py'),
    '/app/../scripts/load_config.py',
]
load_config_found = False
for path in config_paths:
    if os.path.exists(path):
        sys.path.insert(0, os.path.dirname(path))
        try:
            from load_config import get_validation_sites
            validation_sites = get_validation_sites()
            nz_sites = [s for s in validation_sites if s.startswith("nzd")]
            load_config_found = True
            break
        except ImportError:
            continue

# Fallback: read config.json directly
if not load_config_found:
    # Try multiple possible locations for config.json
    config_file_candidates = [
        '/app/config.json',  # Docker mount location
        os.path.join(os.path.dirname(__file__), '..', 'config.json'),  # Relative from script
        os.path.join(os.path.dirname(__file__), '..', '..', 'config.json'),  # Parent of parent
        '/app/../config.json',  # Alternative Docker path
    ]
    config_file = None
    for candidate in config_file_candidates:
        if os.path.exists(candidate):
            config_file = candidate
            break
    
    if config_file:
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
            validation_sites = config.get('validation_sites', ['nzd0001', 'sar0001'])
            nz_sites = [s for s in validation_sites if s.startswith("nzd")]
            print(f"Loaded validation sites from config.json ({config_file}): {validation_sites}")
        except Exception as e:
            print(f"Error loading config.json from {config_file}: {e}")
            nz_sites = ["nzd0001"]
    else:
        print("Warning: config.json not found in any expected location, using default nzd0001")
        print(f"  Checked paths: {config_file_candidates}")
        nz_sites = ["nzd0001"]

# Ensure nz_sites is defined (fallback if all above failed)
if 'nz_sites' not in locals() or not nz_sites:
    nz_sites = ["nzd0001"]

# These polygon bounding boxes define where to download imagery
poly = gpd.read_file("polygons.geojson")
poly = poly[poly.id.isin(nz_sites)]  # Use config sites instead of hardcoded filter
poly.set_index("id", inplace=True)

# These are reference shorelines
shorelines = gpd.read_file("shorelines.geojson")
shorelines = shorelines[shorelines.id.isin(nz_sites)].to_crs(CRS)  # Use config sites
shorelines.set_index("id", inplace=True)

# Transects, origin is landward
transects_gdf = gpd.read_file("transects_extended.geojson").to_crs(CRS).drop_duplicates(subset="id")
transects_gdf.set_index("id", inplace=True)

print(f"{time.time() - start}: Reference polygons and shorelines loaded")

def process_site(sitename):
    print(f"Now processing {sitename}")

    try:
        # Check if file exists and is not empty
        csv_file = f"data/{sitename}/transect_time_series.csv"
        if os.path.exists(csv_file) and os.path.getsize(csv_file) > 0:
            df = pd.read_csv(csv_file)
            if not df.empty and 'dates' in df.columns:
                df.dates = pd.to_datetime(df.dates)
                min_date = str(df.dates.max().date() + timedelta(days=1))
            else:
                # File exists but is empty or invalid, treat as new site
                df = pd.DataFrame()
                min_date = '1984-01-01'
        else:
            # File doesn't exist or is empty, treat as new site
            df = pd.DataFrame()
            min_date = '1984-01-01'
    except (FileNotFoundError, pd.errors.EmptyDataError, KeyError) as e:
        # File doesn't exist, is empty, or invalid - treat as new site
        df = pd.DataFrame()
        min_date = '1984-01-01'

    # Read MAX_DATE.txt if it exists (validation date constraint)
    max_date = "2030-12-30"  # Default: all available imagery
    max_date_file = "MAX_DATE.txt"
    if os.path.exists(max_date_file):
        with open(max_date_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    max_date = line
                    print(f"Using validation max date: {max_date}")
                    break

    inputs = {
        "polygon": list(poly.geometry[sitename].exterior.coords),
        "dates": [min_date, max_date],  # Constrained by validation max date if MAX_DATE.txt exists
        "sat_list": ['L5','L7','L8','L9'],
        "sitename": sitename,
        "filepath": 'data',
        "landsat_collection": 'C02',
    }
    #result = SDS_download.check_images_available(inputs)
    metadata = SDS_download.retrieve_images(inputs)
    #metadata = SDS_download.get_metadata(inputs)

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
    df.to_csv(fn, index=False, float_format='%.2f')
    print(f'{sitename} is done! Time-series of the shoreline change along the transects saved as:{fn}')

process_map(process_site, poly.index, max_workers=32)