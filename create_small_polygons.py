#!/usr/bin/env python3
"""
Create a smaller version of polygons.geojson with only 2 sites per prefix.
This is useful for testing workflows without processing the full dataset.
"""

import json
import sys
from collections import defaultdict


def extract_prefix(site_id):
    """Extract the prefix from a site ID (everything before the first digit)."""
    for i, char in enumerate(site_id):
        if char.isdigit():
            return site_id[:i]
    return site_id


def main():
    input_file = 'CoastSat-CWL/data/input/polygons.geojson'
    output_file = 'CoastSat-CWL/data/input/small_polygons.geojson'
    sites_per_prefix = 2
    
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    if len(sys.argv) > 3:
        sites_per_prefix = int(sys.argv[3])
    
    print(f"Reading {input_file}...")
    with open(input_file, 'r') as f:
        data = json.load(f)
    
    if data.get('type') != 'FeatureCollection':
        print(f"Error: Expected FeatureCollection, got {data.get('type')}", file=sys.stderr)
        sys.exit(1)
    
    # Group features by prefix
    grouped = defaultdict(list)
    for feature in data.get('features', []):
        properties = feature.get('properties', {})
        site_id = properties.get('id')
        if site_id:
            prefix = extract_prefix(site_id)
            grouped[prefix].append(feature)
    
    # Keep only the first N sites per prefix
    selected_features = []
    for prefix in sorted(grouped.keys()):
        prefix_features = grouped[prefix][:sites_per_prefix]
        selected_features.extend(prefix_features)
        print(f"  {prefix}: {len(prefix_features)} sites (from {len(grouped[prefix])} total)")
    
    # Create output GeoJSON
    output_data = {
        'type': 'FeatureCollection',
        'name': data.get('name', 'polygons'),
        'crs': data.get('crs'),
        'features': selected_features
    }
    
    print(f"\nWriting {output_file}...")
    print(f"Total features: {len(selected_features)} (from {len(data.get('features', []))} original)")
    
    with open(output_file, 'w') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Done! Created {output_file}")


if __name__ == '__main__':
    main()

