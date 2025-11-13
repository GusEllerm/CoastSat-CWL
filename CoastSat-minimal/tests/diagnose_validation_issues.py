#!/usr/bin/env python3
"""
Diagnose validation issues by analyzing how data is accumulated and compared.

This script helps understand:
1. Whether data is appended or overwritten
2. Date range differences between original and new data
3. Potential causes of validation discrepancies
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent


def analyze_csv_processing():
    """Analyze how transect_time_series.csv is processed."""
    print("=" * 80)
    print("CSV Processing Analysis")
    print("=" * 80)
    
    original_path = PROJECT_ROOT / "CoastSat" / "data" / "nzd0001" / "transect_time_series.csv"
    new_path = PROJECT_ROOT / "data" / "nzd0001" / "transect_time_series.csv"
    
    if not original_path.exists():
        print(f"❌ Original file not found: {original_path}")
        return
    
    if not new_path.exists():
        print(f"❌ New file not found: {new_path}")
        return
    
    orig = pd.read_csv(original_path)
    new = pd.read_csv(new_path)
    
    orig['dates'] = pd.to_datetime(orig['dates'])
    new['dates'] = pd.to_datetime(new['dates'])
    
    print(f"\nOriginal data:")
    print(f"  Rows: {len(orig)}")
    print(f"  Date range: {orig['dates'].min()} to {orig['dates'].max()}")
    print(f"  Satellites: {sorted(orig['satname'].unique())}")
    print(f"  Unique dates: {orig['dates'].nunique()}")
    
    print(f"\nNew data:")
    print(f"  Rows: {len(new)}")
    print(f"  Date range: {new['dates'].min()} to {new['dates'].max()}")
    print(f"  Satellites: {sorted(new['satname'].unique())}")
    print(f"  Unique dates: {new['dates'].nunique()}")
    
    # Find missing/extra dates
    orig_dates = set(zip(orig['dates'], orig['satname']))
    new_dates = set(zip(new['dates'], new['satname']))
    
    missing_in_new = orig_dates - new_dates
    extra_in_new = new_dates - orig_dates
    
    print(f"\n📊 Date Comparison:")
    print(f"  Dates in original but not in new: {len(missing_in_new)}")
    if missing_in_new:
        print(f"    Examples: {sorted(list(missing_in_new))[:5]}")
    
    print(f"  Dates in new but not in original: {len(extra_in_new)}")
    if extra_in_new:
        print(f"    Examples: {sorted(list(extra_in_new))[:5]}")
    
    # Check for duplicates
    orig_dupes = orig.duplicated(subset=['dates', 'satname']).sum()
    new_dupes = new.duplicated(subset=['dates', 'satname']).sum()
    
    print(f"\n🔍 Duplicate Detection:")
    print(f"  Duplicates in original: {orig_dupes}")
    print(f"  Duplicates in new: {new_dupes}")
    
    # Analyze incremental processing behavior
    print(f"\n📝 Incremental Processing Analysis:")
    print(f"  Original CoastSat workflow:")
    print(f"    - Reads existing CSV if present")
    print(f"    - Appends new results: df = pd.concat([df, new_results])")
    print(f"    - Sorts by date and saves")
    print(f"  This means original data may have been built up over multiple runs!")
    
    # Check if dates are sorted
    orig_sorted = orig['dates'].is_monotonic_increasing
    new_sorted = new['dates'].is_monotonic_increasing
    
    print(f"\n📈 Data Ordering:")
    print(f"  Original dates sorted: {orig_sorted}")
    print(f"  New dates sorted: {new_sorted}")


def analyze_transects_geojson():
    """Analyze how transects_extended.geojson is updated."""
    print("\n" + "=" * 80)
    print("GeoJSON Update Analysis")
    print("=" * 80)
    
    original_path = PROJECT_ROOT / "CoastSat" / "transects_extended.geojson"
    new_path = PROJECT_ROOT / "inputs" / "transects_extended.geojson"
    
    try:
        import geopandas as gpd
        
        if not original_path.exists():
            print(f"❌ Original file not found: {original_path}")
            return
        
        if not new_path.exists():
            print(f"❌ New file not found: {new_path}")
            return
        
        orig = gpd.read_file(original_path)
        new = gpd.read_file(new_path)
        
        print(f"\nOriginal transects:")
        print(f"  Total transects: {len(orig)}")
        if 'site_id' in orig.columns:
            print(f"  Sites: {sorted(orig['site_id'].unique())}")
        if 'beach_slope' in orig.columns:
            print(f"  Transects with beach_slope: {orig['beach_slope'].notna().sum()}")
        if 'trend' in orig.columns:
            print(f"  Transects with trend: {orig['trend'].notna().sum()}")
        
        print(f"\nNew transects:")
        print(f"  Total transects: {len(new)}")
        if 'site_id' in new.columns:
            print(f"  Sites: {sorted(new['site_id'].unique())}")
        if 'beach_slope' in new.columns:
            print(f"  Transects with beach_slope: {new['beach_slope'].notna().sum()}")
        if 'trend' in new.columns:
            print(f"  Transects with trend: {new['trend'].notna().sum()}")
        
        print(f"\n📝 GeoJSON Update Behavior:")
        print(f"  - slope_estimation.py: Updates 'beach_slope', 'cil', 'ciu' columns")
        print(f"  - linear_models.py: Updates 'trend', 'intercept', 'r2_score', etc.")
        print(f"  - Both scripts READ existing file, UPDATE specific columns, WRITE back")
        print(f"  - This is an UPDATE operation, not an append")
        print(f"  - Multiple runs will overwrite previous values")
        
    except ImportError:
        print("⚠️  geopandas not available, skipping GeoJSON analysis")


def analyze_validation_issues():
    """Analyze potential causes of validation discrepancies."""
    print("\n" + "=" * 80)
    print("Validation Issue Analysis")
    print("=" * 80)
    
    print("\n🔍 Potential Issues:")
    print("\n1. Incremental Processing:")
    print("   - Original data may have been built up over multiple workflow runs")
    print("   - Each run appends new data to transect_time_series.csv")
    print("   - When using FORCE_START_DATE, we still read existing data and append")
    print("   - This could lead to duplicate dates or overlapping data")
    
    print("\n2. Date Range Mismatches:")
    print("   - Original data might have been processed in chunks")
    print("   - Some dates might be missing due to image availability")
    print("   - New processing might find different images or use different filters")
    
    print("\n3. Library/Algorithm Differences:")
    print("   - Different versions of coastsat library")
    print("   - Different processing parameters (cloud thresholds, etc.)")
    print("   - Different image selection criteria")
    
    print("\n4. Floating Point Precision:")
    print("   - CSV files saved with float_format='%.2f' (2 decimal places)")
    print("   - Small differences could accumulate over multiple processing steps")
    
    print("\n💡 Recommendations:")
    print("\n1. For exact validation:")
    print("   - Start with clean data directory (delete existing data)")
    print("   - Use FORCE_START_DATE to match original start date")
    print("   - Ensure same date range and satellite list")
    
    print("\n2. For downstream-only validation:")
    print("   - Copy original transect_time_series.csv")
    print("   - Run only downstream steps (tides, slope, correction, models)")
    print("   - Compare downstream outputs")
    
    print("\n3. Acceptable differences:")
    print("   - Small differences (< 10m) might be acceptable")
    print("   - Due to library updates or processing improvements")
    print("   - Focus on functional correctness, not exact bit-for-bit matching")


def main():
    """Run all diagnostic analyses."""
    print("CoastSat Validation Diagnostic Tool")
    print("=" * 80)
    
    analyze_csv_processing()
    analyze_transects_geojson()
    analyze_validation_issues()
    
    print("\n" + "=" * 80)
    print("Diagnostic complete")
    print("=" * 80)


if __name__ == "__main__":
    main()

