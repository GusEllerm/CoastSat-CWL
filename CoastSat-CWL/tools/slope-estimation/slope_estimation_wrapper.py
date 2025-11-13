#!/usr/bin/env python3
"""
Wrapper script for slope-estimation CWL tool.
Estimates beach slopes for transects using spectral analysis.
Processes a single site and outputs updated transects for that site.
"""

import sys
import argparse
from pathlib import Path
from datetime import datetime
import pytz

import geopandas as gpd
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend

# SDS_slope is a local module, we'll copy it via InitialWorkDirRequirement
# For now, try importing from coastsat package or add path if needed
try:
    from coastsat import SDS_slope
except ImportError:
    # If not in package, try direct import (will work if copied via InitialWorkDirRequirement)
    import SDS_slope


def estimate_slopes_for_site(
    site_id: str,
    transect_time_series_path: Path,
    tides_path: Path,
    transects_path: Path,
    output_path: Path
):
    """
    Estimate beach slopes for transects at a single site.
    
    Args:
        site_id: Site ID (e.g., "nzd0001")
        transect_time_series_path: Path to transect_time_series.csv
        tides_path: Path to tides.csv
        transects_path: Path to transects_extended.geojson
        output_path: Path to output GeoJSON file with updated slopes
    """
    # Load transects
    transects = gpd.read_file(transects_path).set_index("id")
    
    # Filter for transects at this site that need slope estimation
    transects_at_site = transects[
        (transects.site_id == site_id) &
        (transects.beach_slope.isna())
    ]
    
    if len(transects_at_site) == 0:
        print(f"No transects at {site_id} need slope estimation (all have beach_slope)", file=sys.stderr)
        # Output empty file or existing transects for this site?
        # For now, output all transects at the site (even if they already have slopes)
        transects_at_site = transects[transects.site_id == site_id].copy()
        transects_at_site.to_file(output_path)
        return
    
    print(f"Processing {len(transects_at_site)} transects from {site_id}", file=sys.stderr)
    
    # Load transect time series
    df = pd.read_csv(transect_time_series_path)
    df.index = pd.to_datetime(df.dates)
    df.drop(columns=["dates", "satname"], inplace=True, errors="ignore")
    
    # Load tides
    tides = pd.read_csv(tides_path)
    tides.dates = pd.to_datetime(tides.dates)
    tides.set_index("dates", inplace=True)
    
    # Verify that dates align
    if not all(pd.to_datetime(df.index).round("10min") == tides.index):
        print(f"Warning: Date mismatch for {site_id}, attempting to align...", file=sys.stderr)
        # Try to align by rounding
        df.index = pd.to_datetime(df.index).round("10min")
        tides.index = pd.to_datetime(tides.index).round("10min")
        # Only keep overlapping dates
        common_dates = df.index.intersection(tides.index)
        df = df.loc[common_dates]
        tides = tides.loc[common_dates]
    
    if len(df) == 0:
        print(f"Error: No overlapping dates between time series and tides for {site_id}", file=sys.stderr)
        sys.exit(1)
    
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
    
    # Only process transects that are in both the time series and need slopes
    transect_ids_to_process = [t for t in transects_at_site.index if t in df.columns]
    
    for key in transect_ids_to_process:
        # Remove NaNs
        idx_nan = np.isnan(df[key])
        if np.all(idx_nan):
            print(f"Warning: All values are NaN for transect {key}, skipping", file=sys.stderr)
            continue
        
        dates = [df.index[_] for _ in np.where(~idx_nan)[0]]
        tide = tides.tide.to_numpy()[~idx_nan]
        composite = df[key][~idx_nan]
        
        # Apply tidal correction
        tsall = SDS_slope.tide_correct(composite, tide, beach_slopes)
        
        # Estimate slope
        try:
            slope_est[key], cis[key] = SDS_slope.integrate_power_spectrum(dates, tsall, settings_slope)
            print(f'Beach slope at transect {key}: {slope_est[key]:.3f}', file=sys.stderr)
        except Exception as e:
            print(f"Warning: Failed to estimate slope for {key}: {e}", file=sys.stderr)
            continue
    
    # Update transects with estimated slopes
    if slope_est:
        # Create a copy of transects for this site
        updated_transects = transects[transects.site_id == site_id].copy()
        
        # Update slopes
        for key, value in slope_est.items():
            if key in updated_transects.index:
                updated_transects.loc[key, 'beach_slope'] = value
        
        # Update confidence intervals
        for key, value in cis.items():
            if key in updated_transects.index:
                updated_transects.loc[key, 'cil'] = value[0]
                updated_transects.loc[key, 'ciu'] = value[1]
        
        print(f"Updated {len(slope_est)} transects with beach slopes for {site_id}", file=sys.stderr)
        
        # Save updated transects for this site
        updated_transects.to_file(output_path)
        print(f"Saved updated transects for {site_id} to {output_path}", file=sys.stderr)
    else:
        print(f"Warning: No slopes estimated for {site_id}", file=sys.stderr)
        # Output existing transects for this site
        transects_at_site = transects[transects.site_id == site_id].copy()
        transects_at_site.to_file(output_path)


def main():
    parser = argparse.ArgumentParser(description="Estimate beach slopes for transects at a single site.")
    parser.add_argument("--transect-time-series", required=True, help="Path to transect_time_series.csv")
    parser.add_argument("--tides", required=True, help="Path to tides.csv")
    parser.add_argument("--transects-extended", required=True, help="Path to transects_extended.geojson")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--output", help="Output GeoJSON file path (default: {site_id}_transects_updated.geojson)")
    
    args = parser.parse_args()
    
    try:
        # Determine output file
        if args.output:
            output_file = Path(args.output)
        else:
            output_file = Path(f"{args.site_id}_transects_updated.geojson")
        
        estimate_slopes_for_site(
            args.site_id,
            Path(args.transect_time_series),
            Path(args.tides),
            Path(args.transects_extended),
            output_file
        )
        
        return 0
        
    except Exception as e:
        print(f"Error estimating slopes: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

