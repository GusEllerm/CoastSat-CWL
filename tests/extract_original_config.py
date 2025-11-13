#!/usr/bin/env python3
"""
Extract configuration from original CoastSat data to match validation.

This script analyzes the original CoastSat data to determine the exact
configuration used (date range, satellites, etc.) so we can configure
the new workflow to produce identical results.
"""

import os
import sys
from pathlib import Path
import pandas as pd
import geopandas as gpd
import json

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

def extract_original_config(site_id: str = "nzd0001"):
    """
    Extract configuration from original CoastSat data.
    
    Args:
        site_id: Site ID to analyze
        
    Returns:
        dict: Configuration extracted from original data
    """
    original_data_dir = project_root / "CoastSat" / "data" / site_id
    
    config = {
        "site_id": site_id,
        "date_range": None,
        "satellites": None,
        "num_rows": None,
        "num_transects": None,
        "landsat_collection": "C02",  # Assume C02 based on original script
    }
    
    # Read transect time series
    transect_file = original_data_dir / "transect_time_series.csv"
    if not transect_file.exists():
        print(f"Error: {transect_file} not found")
        return config
    
    df = pd.read_csv(transect_file)
    df['dates'] = pd.to_datetime(df['dates'])
    
    # Extract date range
    config["date_range"] = {
        "start": str(df.dates.min().date()),
        "end": str(df.dates.max().date()),
        "start_datetime": str(df.dates.min()),
        "end_datetime": str(df.dates.max()),
        "days": (df.dates.max() - df.dates.min()).days
    }
    
    # Extract satellites
    config["satellites"] = {
        "list": sorted(df.satname.unique().tolist()),
        "counts": df.satname.value_counts().to_dict()
    }
    
    # Extract other information
    config["num_rows"] = len(df)
    config["num_unique_dates"] = df.dates.nunique()
    
    # Count transects (exclude dates and satname columns)
    transect_columns = [col for col in df.columns if col not in ['dates', 'satname']]
    config["num_transects"] = len(transect_columns)
    config["transect_ids"] = transect_columns
    
    # Read tides file if it exists
    tides_file = original_data_dir / "tides.csv"
    if tides_file.exists():
        tides_df = pd.read_csv(tides_file)
        if 'dates' in tides_df.columns:
            tides_df['dates'] = pd.to_datetime(tides_df['dates'])
            config["tides"] = {
                "num_rows": len(tides_df),
                "date_range": {
                    "start": str(tides_df.dates.min().date()),
                    "end": str(tides_df.dates.max().date())
                }
            }
    
    return config


def generate_validation_config(config: dict) -> str:
    """
    Generate .env configuration for validation.
    
    Args:
        config: Configuration extracted from original data
        
    Returns:
        str: Configuration string for .env file
    """
    env_config = f"""# Validation Configuration for {config['site_id']}
# This configuration matches the original CoastSat data

# Disable test mode (use full date range)
TEST_MODE=false

# Or use exact date range from original data
# TEST_MODE=true
# TEST_START_DATE={config['date_range']['start']}
# TEST_END_DATE={config['date_range']['end']}

# Process only this site
TEST_SITES={config['site_id']}

# Use same satellites as original
TEST_SATELLITES={','.join(config['satellites']['list'])}

# Original data configuration:
# - Date range: {config['date_range']['start']} to {config['date_range']['end']}
# - Satellites: {', '.join(config['satellites']['list'])}
# - Number of rows: {config['num_rows']}
# - Number of transects: {config['num_transects']}
# - Landsat collection: {config['landsat_collection']}
"""
    return env_config


def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Extract configuration from original CoastSat data")
    parser.add_argument(
        "--site",
        default="nzd0001",
        help="Site ID to analyze (default: nzd0001)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="validation_config.env",
        help="Output file for validation configuration (default: validation_config.env)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output configuration as JSON"
    )
    
    args = parser.parse_args()
    
    print("=" * 80)
    print("Extracting Original CoastSat Configuration")
    print("=" * 80)
    print(f"Site: {args.site}")
    print()
    
    # Extract configuration
    config = extract_original_config(args.site)
    
    # Print configuration
    print("Configuration extracted from original data:")
    print(f"  Site ID: {config['site_id']}")
    print(f"  Date range: {config['date_range']['start']} to {config['date_range']['end']}")
    print(f"  Date range (days): {config['date_range']['days']}")
    print(f"  Satellites: {', '.join(config['satellites']['list'])}")
    print(f"  Satellite counts: {config['satellites']['counts']}")
    print(f"  Number of rows: {config['num_rows']}")
    print(f"  Number of unique dates: {config['num_unique_dates']}")
    print(f"  Number of transects: {config['num_transects']}")
    print(f"  Landsat collection: {config['landsat_collection']}")
    
    if 'tides' in config:
        print(f"  Tides: {config['tides']['num_rows']} rows")
        print(f"  Tides date range: {config['tides']['date_range']['start']} to {config['tides']['date_range']['end']}")
    
    print()
    
    # Generate validation configuration
    if args.json:
        # Output as JSON
        output_path = project_root / args.output
        with open(output_path, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"Configuration saved to: {output_path}")
    else:
        # Output as .env file
        env_config = generate_validation_config(config)
        output_path = project_root / args.output
        with open(output_path, 'w') as f:
            f.write(env_config)
        print(f"Validation configuration saved to: {output_path}")
        print()
        print("To use this configuration:")
        print(f"  cp {args.output} .env")
        print("  # Or merge with existing .env file")
    
    print()
    print("=" * 80)
    print("Next steps:")
    print("=" * 80)
    print("1. Review the extracted configuration")
    print("2. Update .env file with validation configuration")
    print("3. Run new workflow: ./workflow/workflow.sh")
    print("4. Compare results: python3 tests/compare_with_original.py --sites", args.site)
    print()
    
    return config


if __name__ == "__main__":
    main()

