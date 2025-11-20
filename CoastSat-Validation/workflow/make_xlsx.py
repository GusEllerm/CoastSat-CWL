#!/usr/bin/env python3

import geopandas as gpd
import pandas as pd
import os
from tqdm.auto import tqdm
from tqdm.contrib.concurrent import process_map
from shapely import line_interpolate_point

# Load validation sites from config and filter to NZ sites only
import sys
sys.path.insert(0, '/app/../scripts' if os.path.exists('/app/../scripts') else '.')
try:
    from load_config import get_validation_sites
    validation_sites = get_validation_sites()
    # Filter to NZ sites only (matching original behavior)
    nz_sites = [s for s in validation_sites if s.startswith("nzd")]
except ImportError:
    # Fallback if config not available
    nz_sites = ["nzd0001"]

transects = gpd.read_file("transects_extended.geojson").drop_duplicates(subset="id")
transects.set_index("id", inplace=True)
# Only process NZ sites (matching original make_xlsx.py behavior)
transects = transects[transects.site_id.str.startswith("nzd")].copy()
# Further filter to validation sites if config is available
if 'nz_sites' in locals() and nz_sites:
    transects = transects[transects.site_id.isin(nz_sites)].copy()
transects["land_x"] = transects.geometry.apply(lambda x: x.coords[0][0])
transects["land_y"] = transects.geometry.apply(lambda x: x.coords[0][1])
transects["sea_x"] = transects.geometry.apply(lambda x: x.coords[-1][0])
transects["sea_y"] = transects.geometry.apply(lambda x: x.coords[-1][1])
transects["center_x"] = (transects["land_x"] + transects["sea_x"]) / 2
transects["center_y"] = (transects["land_y"] + transects["sea_y"]) / 2
transects.to_excel("transects.xlsx")

transects_2193 = transects.to_crs(2193)

def process_site(site_id):
  # Check if required files exist
  tidally_corrected_file = f"data/{site_id}/transect_time_series_tidally_corrected.csv"
  tides_file = f"data/{site_id}/tides.csv"
  
  if not os.path.exists(tidally_corrected_file):
    print(f"Skipping {site_id}: transect_time_series_tidally_corrected.csv not found")
    return
  if not os.path.exists(tides_file):
    print(f"Skipping {site_id}: tides.csv not found")
    return
  
  # Check if files are empty
  try:
    if os.path.getsize(tidally_corrected_file) == 0:
      print(f"Skipping {site_id}: transect_time_series_tidally_corrected.csv is empty")
      return
    if os.path.getsize(tides_file) == 0:
      print(f"Skipping {site_id}: tides.csv is empty")
      return
  except OSError:
    print(f"Skipping {site_id}: Error checking file sizes")
    return
  
  try:
    # Try to read the CSV files
    intersects = pd.read_csv(tidally_corrected_file)
    if intersects.empty:
      print(f"Skipping {site_id}: transect_time_series_tidally_corrected.csv has no data")
      return
    
    tides = pd.read_csv(tides_file)
    if tides.empty:
      print(f"Skipping {site_id}: tides.csv has no data")
      return
  except pd.errors.EmptyDataError:
    print(f"Skipping {site_id}: CSV file is empty or invalid")
    return
  except Exception as e:
    print(f"Skipping {site_id}: Error reading CSV files: {e}")
    return
  
  # All checks passed, create Excel file
  with pd.ExcelWriter(f'data/{site_id}/{site_id}.xlsx') as writer:
    intersects.set_index("dates", inplace=True)
    intersects.to_excel(writer, sheet_name="Intersects")
    tides.to_excel(writer, sheet_name="Tides", index=False)
    transects_at_site = transects[transects.site_id == site_id]
    if len(transects_at_site) > 0:
        transects_at_site.to_excel(writer, sheet_name="Transects")
        transect_ids = list(transects_at_site.index)
        for transect_id in transect_ids:
            if transect_id in intersects.columns:
                intersects[transect_id] = gpd.GeoSeries(line_interpolate_point(transects_2193.geometry[transect_id], intersects[transect_id]), crs=2193).to_crs(4326).apply(lambda p: f"{p.y},{p.x}" if p else None)
    intersects.to_excel(writer, sheet_name="Intersect points")

process_map(process_site, transects.site_id.unique(), max_workers=32)