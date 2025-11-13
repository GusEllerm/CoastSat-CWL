#!/usr/bin/env python3
"""
Slope estimation script for CoastSat project.

This script estimates beach slopes for transects using spectral analysis.
It processes sites that don't have beach_slope values yet and updates
the transects_extended.geojson file with the estimated slopes.
"""

import os
import sys
from pathlib import Path
from datetime import datetime
import pytz

import geopandas as gpd
import pandas as pd
import numpy as np
from tqdm.auto import tqdm
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt

import SDS_slope

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)


def estimate_slopes(sites=None):
    """
    Estimate beach slopes for transects.
    
    Args:
        sites: Optional list of site IDs to process. If None, processes all NZ sites that need slopes.
    """
    print("=" * 60)
    print("Estimating beach slopes")
    print("=" * 60)
    
    # Load transects
    print("Loading transects...")
    transects = gpd.read_file("inputs/transects_extended.geojson").set_index("id")
    print(f"Loaded {len(transects)} transects")
    
    # Filter for NZ sites that need slope estimation
    # Only process sites that don't have beach_slope yet
    if sites:
        # Filter by specified sites
        new_transects = transects[
            transects.index.str.startswith("nzd") & 
            transects.index.str.contains("|".join(sites)) &
            transects.beach_slope.isna()
        ]
    else:
        # Filter for NZ sites without beach_slope
        new_transects = transects[
            transects.index.str.startswith("nzd") & 
            transects.beach_slope.isna()
        ]
    
    if len(new_transects) == 0:
        print("No transects need slope estimation")
        return
    
    print(f"Processing {len(new_transects)} transects from {len(new_transects.site_id.unique())} sites")
    
    # Process each site
    for site_id in tqdm(new_transects.site_id.unique(), desc="Processing sites"):
        print(f"\nProcessing site: {site_id}")
        
        # Load transect time series
        transect_file = f"data/{site_id}/transect_time_series.csv"
        if not os.path.exists(transect_file):
            print(f"Warning: {transect_file} not found, skipping {site_id}")
            continue
        
        df = pd.read_csv(transect_file)
        df.index = pd.to_datetime(df.dates)
        df.drop(columns=["dates", "satname"], inplace=True, errors="ignore")
        
        # Load tides
        tides_file = f"data/{site_id}/tides.csv"
        if not os.path.exists(tides_file):
            print(f"Warning: {tides_file} not found, skipping {site_id}")
            continue
        
        tides = pd.read_csv(tides_file)
        tides.dates = pd.to_datetime(tides.dates)
        tides.set_index("dates", inplace=True)
        
        # Verify that dates align
        if not all(pd.to_datetime(df.index).round("10min") == tides.index):
            print(f"Warning: Date mismatch for {site_id}, attempting to align...")
            # Try to align by rounding
            df.index = pd.to_datetime(df.index).round("10min")
            tides.index = pd.to_datetime(tides.index).round("10min")
            # Only keep overlapping dates
            common_dates = df.index.intersection(tides.index)
            df = df.loc[common_dates]
            tides = tides.loc[common_dates]
        
        # Slope estimation settings
        days_in_year = 365.2425
        seconds_in_day = 24 * 3600
        settings_slope = {
            'slope_min': 0.01,                  # minimum slope to trial
            'slope_max': 0.2,                    # maximum slope to trial
            'delta_slope': 0.005,                  # slope increment
            'date_range': [1999, 2020],            # range of dates over which to perform the analysis
            'n_days': 8,                      # sampling period [days]
            'n0': 50,                     # parameter for Nyquist criterium in Lomb-Scargle transforms
            'freqs_cutoff': 1. / (seconds_in_day * 30), # 1 month frequency
            'delta_f': 100 * 1e-10,              # deltaf for identifying peak tidal frequency band
            'prc_conf': 0.05,                   # percentage above minimum to define confidence bands in energy curve
        }
        settings_slope['date_range'] = [
            pytz.utc.localize(datetime(settings_slope['date_range'][0], 5, 1)),
            pytz.utc.localize(datetime(settings_slope['date_range'][1], 1, 1))
        ]
        beach_slopes = SDS_slope.range_slopes(
            settings_slope['slope_min'],
            settings_slope['slope_max'],
            settings_slope['delta_slope']
        )
        
        # Analyze timestep distribution (optional visualization)
        t = np.array([_.timestamp() for _ in df.index]).astype('float64')
        delta_t = np.diff(t)
        
        # Find tidal peak frequency
        settings_slope['n_days'] = 7
        settings_slope['freqs_max'] = SDS_slope.find_tide_peak(df.index, tides.tide, settings_slope)
        
        # Estimate beach-face slopes along the transects
        slope_est = {}
        cis = {}
        
        for key in tqdm(df.keys(), desc=f"Estimating slopes for {site_id}", leave=False):
            # Remove NaNs
            idx_nan = np.isnan(df[key])
            if np.all(idx_nan):
                continue
            
            dates = [df.index[_] for _ in np.where(~idx_nan)[0]]
            tide = tides.tide.to_numpy()[~idx_nan]
            composite = df[key][~idx_nan]
            
            # Apply tidal correction
            tsall = SDS_slope.tide_correct(composite, tide, beach_slopes)
            
            # Estimate slope
            try:
                slope_est[key], cis[key] = SDS_slope.integrate_power_spectrum(dates, tsall, settings_slope)
                print(f'Beach slope at transect {key}: {slope_est[key]:.3f}')
            except Exception as e:
                print(f"Warning: Failed to estimate slope for {key}: {e}")
                continue
        
        # Update transects with estimated slopes
        if slope_est:
            # Update using direct assignment to avoid FutureWarning
            for key, value in slope_est.items():
                transects.loc[key, 'beach_slope'] = value
            for key, value in cis.items():
                transects.loc[key, 'cil'] = value[0]
                transects.loc[key, 'ciu'] = value[1]
            print(f"Updated {len(slope_est)} transects with beach slopes")
    
    # Save updated transects
    print("\nSaving updated transects...")
    transects.to_file("inputs/transects_extended.geojson")
    print("=" * 60)
    print("Slope estimation completed")
    print("=" * 60)


def main():
    """Main function to run slope estimation."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Slope estimation script for CoastSat")
    parser.add_argument(
        "--sites",
        nargs="+",
        help="Specific site IDs to process (e.g., nzd0001 nzd0002). If not specified, processes all sites that need slopes."
    )
    
    args = parser.parse_args()
    
    estimate_slopes(sites=args.sites)


if __name__ == "__main__":
    main()

