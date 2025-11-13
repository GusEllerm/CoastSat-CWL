#!/usr/bin/env python3
"""
Wrapper script for make-xlsx CWL tool.
Creates Excel file from CSV data and transects for a single site.
"""

import sys
import argparse
from pathlib import Path
import geopandas as gpd
import pandas as pd
from shapely import line_interpolate_point


def main():
    parser = argparse.ArgumentParser(description="Create Excel file from CoastSat outputs for a single site.")
    parser.add_argument("--transects", required=True, help="Path to transects_extended.geojson")
    parser.add_argument("--time-series", required=True, help="Path to transect_time_series_tidally_corrected.csv")
    parser.add_argument("--tides", required=True, help="Path to tides.csv")
    parser.add_argument("--site-id", required=True, help="Site ID (e.g., nzd0001)")
    parser.add_argument("--output", help="Output Excel file path (default: {site_id}.xlsx)")
    
    args = parser.parse_args()
    
    # Determine output file
    if args.output:
        output_file = Path(args.output)
    else:
        output_file = Path(f"{args.site_id}.xlsx")
    
    try:
        # Load transects
        transects = gpd.read_file(args.transects).drop_duplicates(subset="id")
        transects.set_index("id", inplace=True)
        
        # Filter for the specific site
        transects_at_site = gpd.GeoDataFrame(
            transects.loc[transects.site_id == args.site_id].copy(),
            crs=transects.crs,
        )
        
        if transects_at_site.empty:
            print(f"Error: No transects found for {args.site_id}", file=sys.stderr)
            sys.exit(1)
        
        # Compute helper columns
        transects_at_site["land_x"] = transects_at_site.geometry.apply(lambda x: x.coords[0][0])
        transects_at_site["land_y"] = transects_at_site.geometry.apply(lambda x: x.coords[0][1])
        transects_at_site["sea_x"] = transects_at_site.geometry.apply(lambda x: x.coords[-1][0])
        transects_at_site["sea_y"] = transects_at_site.geometry.apply(lambda x: x.coords[-1][1])
        transects_at_site["center_x"] = (transects_at_site["land_x"] + transects_at_site["sea_x"]) / 2
        transects_at_site["center_y"] = (transects_at_site["land_y"] + transects_at_site["sea_y"]) / 2
        
        # Convert to NZGD2000 / New Zealand Transverse Mercator 2000 (EPSG:2193) for calculations
        transects_2193 = transects_at_site.to_crs(2193)
        
        # Load CSV files
        intersects = pd.read_csv(args.time_series)
        if "dates" not in intersects.columns:
            print("Error: 'dates' column not found in time series CSV", file=sys.stderr)
            sys.exit(1)
        intersects.set_index("dates", inplace=True)
        
        tides = pd.read_csv(args.tides)
        
        # Create Excel file
        with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
            # Sheet 1: Intersects
            intersects.to_excel(writer, sheet_name="Intersects")
            
            # Sheet 2: Tides
            tides.to_excel(writer, sheet_name="Tides", index=False)
            
            # Sheet 3: Transects
            transects_at_site.to_excel(writer, sheet_name="Transects")
            
            # Sheet 4: Intersect points (computed)
            transect_ids = list(transects_at_site.index)
            intersects_with_points = intersects.copy()
            
            for transect_id in transect_ids:
                if transect_id in intersects_with_points.columns:
                    intersects_with_points[transect_id + '_point'] = (
                        gpd.GeoSeries(
                            line_interpolate_point(
                                transects_2193.geometry[transect_id],
                                intersects_with_points[transect_id]
                            ),
                            crs=2193,
                        )
                        .to_crs(4326)
                        .apply(lambda p: f"{p.y},{p.x}" if p else None)
                    )
            
            intersects_with_points.to_excel(writer, sheet_name="Intersect points")
        
        print(f"Created Excel file: {output_file}")
        return 0
        
    except Exception as e:
        print(f"Error creating Excel file: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())

