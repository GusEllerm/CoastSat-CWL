#!/usr/bin/env python3
"""
Simple filter script to filter input GeoJSON files to include only representative sites.
This version uses only the json module, no geopandas required.
"""

import json
import sys
from pathlib import Path

# Representative sites for minimal workflow
REPRESENTATIVE_NZ_SITES = ['nzd0001', 'nzd0002', 'nzd0003']
REPRESENTATIVE_SAR_SITES = ['sar0001']
REPRESENTATIVE_SITES = REPRESENTATIVE_NZ_SITES + REPRESENTATIVE_SAR_SITES

def filter_geojson_simple(input_path, output_path, site_ids, id_key='id'):
    """
    Filter GeoJSON file to include only specified site IDs.
    Uses only the json module, no geopandas required.
    
    Args:
        input_path: Path to input GeoJSON file
        output_path: Path to output GeoJSON file
        site_ids: List of site IDs to include
        id_key: Key for site ID in properties (default: 'id' or 'site_id')
    """
    print(f"Reading {input_path}...")
    
    with open(input_path, 'r') as f:
        geojson_data = json.load(f)
    
    # Filter features
    filtered_features = []
    for feature in geojson_data.get('features', []):
        props = feature.get('properties', {})
        
        # Check if this feature belongs to one of our sites
        # For polygons and shorelines, use 'id'
        # For transects, use 'site_id'
        site_id = props.get('id') or props.get('site_id')
        
        if site_id in site_ids:
            filtered_features.append(feature)
    
    # Create filtered GeoJSON
    filtered_geojson = {
        'type': geojson_data.get('type', 'FeatureCollection'),
        'crs': geojson_data.get('crs'),
        'name': geojson_data.get('name'),
        'features': filtered_features
    }
    
    # Save filtered GeoJSON
    with open(output_path, 'w') as f:
        json.dump(filtered_geojson, f, indent=2)
    
    print(f"  Saved {len(filtered_features)} features to {output_path}")
    return filtered_features

def main():
    """Main function to filter all input GeoJSON files."""
    # Paths (go up 3 levels from file to project root: file -> setup -> scripts -> root)
    coastsat_dir = Path(__file__).parent.parent.parent / 'CoastSat'
    inputs_dir = Path(__file__).parent.parent.parent / 'inputs'
    inputs_dir.mkdir(exist_ok=True)
    
    # Filter polygons.geojson
    print("\n=== Filtering polygons.geojson ===")
    filter_geojson_simple(
        coastsat_dir / 'polygons.geojson',
        inputs_dir / 'polygons.geojson',
        REPRESENTATIVE_SITES,
        id_key='id'
    )
    
    # Filter shorelines.geojson
    print("\n=== Filtering shorelines.geojson ===")
    filter_geojson_simple(
        coastsat_dir / 'shorelines.geojson',
        inputs_dir / 'shorelines.geojson',
        REPRESENTATIVE_SITES,
        id_key='id'
    )
    
    # Filter transects_extended.geojson
    print("\n=== Filtering transects_extended.geojson ===")
    # For transects, we need to filter by site_id
    # First, read and filter by site_id
    print(f"Reading {coastsat_dir / 'transects_extended.geojson'}...")
    with open(coastsat_dir / 'transects_extended.geojson', 'r') as f:
        transects_data = json.load(f)
    
    filtered_transects = []
    for feature in transects_data.get('features', []):
        props = feature.get('properties', {})
        site_id = props.get('site_id')
        if site_id in REPRESENTATIVE_SITES:
            filtered_transects.append(feature)
    
    filtered_transects_geojson = {
        'type': transects_data.get('type', 'FeatureCollection'),
        'crs': transects_data.get('crs'),
        'name': transects_data.get('name'),
        'features': filtered_transects
    }
    
    with open(inputs_dir / 'transects_extended.geojson', 'w') as f:
        json.dump(filtered_transects_geojson, f, indent=2)
    
    print(f"  Saved {len(filtered_transects)} transects to {inputs_dir / 'transects_extended.geojson'}")
    
    print("\n=== Summary ===")
    print(f"Filtered inputs for {len(REPRESENTATIVE_SITES)} sites:")
    print(f"  NZ sites: {REPRESENTATIVE_NZ_SITES}")
    print(f"  SAR sites: {REPRESENTATIVE_SAR_SITES}")
    print(f"\nFiltered files saved to: {inputs_dir}")

if __name__ == '__main__':
    main()

