#!/usr/bin/env python3
"""
Filter input GeoJSON files to include only representative sites for minimal workflow.
This script extracts a subset of sites from polygons.geojson, shorelines.geojson, and transects_extended.geojson.
"""

import geopandas as gpd
import sys
from pathlib import Path

# Representative sites for minimal workflow
# NZ sites (nzd)
REPRESENTATIVE_NZ_SITES = ['nzd0001', 'nzd0002', 'nzd0003']
# SAR sites (sar)  
REPRESENTATIVE_SAR_SITES = ['sar0001']

# All representative sites
REPRESENTATIVE_SITES = REPRESENTATIVE_NZ_SITES + REPRESENTATIVE_SAR_SITES

def filter_geojson(input_path, output_path, site_ids, id_column='id'):
    """
    Filter GeoJSON file to include only specified site IDs.
    
    Args:
        input_path: Path to input GeoJSON file
        output_path: Path to output GeoJSON file
        site_ids: List of site IDs to include
        id_column: Column name for site ID (default: 'id')
    """
    print(f"Reading {input_path}...")
    gdf = gpd.read_file(input_path)
    
    # Filter by site IDs
    # For polygons and shorelines, filter by exact match
    # For transects, filter by site_id column (transects have a site_id column)
    if 'site_id' in gdf.columns:
        # Transects: filter by site_id
        filtered = gdf[gdf['site_id'].isin(site_ids)]
        print(f"  Found {len(filtered)} transects for sites {site_ids}")
    else:
        # Polygons and shorelines: filter by id
        filtered = gdf[gdf[id_column].isin(site_ids)]
        print(f"  Found {len(filtered)} features for sites {site_ids}")
    
    # Save filtered GeoJSON
    filtered.to_file(output_path, driver='GeoJSON')
    print(f"  Saved {len(filtered)} features to {output_path}")
    return filtered

def main():
    """Main function to filter all input GeoJSON files."""
    # Paths (go up 3 levels from file to project root: file -> setup -> scripts -> root)
    coastsat_dir = Path(__file__).parent.parent.parent / 'CoastSat'
    inputs_dir = Path(__file__).parent.parent.parent / 'inputs'
    inputs_dir.mkdir(exist_ok=True)
    
    # Filter polygons.geojson
    print("\n=== Filtering polygons.geojson ===")
    filter_geojson(
        coastsat_dir / 'polygons.geojson',
        inputs_dir / 'polygons.geojson',
        REPRESENTATIVE_SITES
    )
    
    # Filter shorelines.geojson
    print("\n=== Filtering shorelines.geojson ===")
    filter_geojson(
        coastsat_dir / 'shorelines.geojson',
        inputs_dir / 'shorelines.geojson',
        REPRESENTATIVE_SITES
    )
    
    # Filter transects_extended.geojson
    print("\n=== Filtering transects_extended.geojson ===")
    filter_geojson(
        coastsat_dir / 'transects_extended.geojson',
        inputs_dir / 'transects_extended.geojson',
        REPRESENTATIVE_SITES,
        id_column='site_id'  # Transects use site_id column
    )
    
    print("\n=== Summary ===")
    print(f"Filtered inputs for {len(REPRESENTATIVE_SITES)} sites:")
    print(f"  NZ sites: {REPRESENTATIVE_NZ_SITES}")
    print(f"  SAR sites: {REPRESENTATIVE_SAR_SITES}")
    print(f"\nFiltered files saved to: {inputs_dir}")

if __name__ == '__main__':
    main()

