cwlVersion: v1.2
class: CommandLineTool

label: Make per-site Excel summary for one NZD site

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: make_xlsx_site.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import os
          import sys

          import geopandas as gpd
          import pandas as pd
          import numpy as np
          from shapely import line_interpolate_point

          def main(argv=None):
              p = argparse.ArgumentParser(
                  description="Create per-site Excel summary (NZD sites)"
              )
              p.add_argument("--site-id", required=True)
              p.add_argument("--site-dir", required=True)
              p.add_argument("--transects-geojson", required=True)
              args = p.parse_args(argv)

              site_id = args.site_id
              site_dir = os.path.abspath(args.site_dir)

              # Load transects, filter to NZD as in original script
              transects = (
                  gpd.read_file(args.transects_geojson)
                  .drop_duplicates(subset="id")
              )
              if "site_id" not in transects.columns:
                  print("transects file has no 'site_id' column", file=sys.stderr)
                  return 1

              transects = transects[transects.site_id.str.startswith("nzd")].copy()
              if transects.empty:
                  print("No NZD transects found; nothing to do.", file=sys.stderr)
                  return 0

              transects.set_index("id", inplace=True)

              # Reproject for distance-based interpolation
              transects_2193 = transects.to_crs(2193)

              # Paths inside this site's directory
              tc_path  = os.path.join(site_dir, "transect_time_series_tidally_corrected.csv")
              raw_path = os.path.join(site_dir, "transect_time_series.csv")
              tides_path = os.path.join(site_dir, "tides.csv")

              if os.path.exists(tc_path):
                  ts_path = tc_path
              elif os.path.exists(raw_path):
                  ts_path = raw_path
              else:
                  print(f"[{site_id}] No transect_time_series CSV found", file=sys.stderr)
                  return 0

              if not os.path.exists(tides_path):
                  print(f"[{site_id}] No tides.csv found", file=sys.stderr)
                  return 0

              # Load time-series and tides
              intersects = pd.read_csv(ts_path)
              if "dates" not in intersects.columns:
                  print(f"[{site_id}] intersects CSV has no 'dates' column", file=sys.stderr)
                  return 1
              intersects.set_index("dates", inplace=True)

              tides = pd.read_csv(tides_path)

              # Transects for this site
              transects_at_site = transects[transects.site_id == site_id]
              if transects_at_site.empty:
                  print(f"[{site_id}] No transects in transects_extended.geojson", file=sys.stderr)

              # Output Excel path inside the site directory
              out_xlsx_site = os.path.join(site_dir, f"{site_id}.xlsx")

              with pd.ExcelWriter(out_xlsx_site) as writer:
                  # Sheet 1: original intersects
                  intersects.to_excel(writer, sheet_name="Intersects")

                  # Sheet 2: tides
                  tides.to_excel(writer, sheet_name="Tides", index=False)

                  # Sheet 3: transects rows for this site
                  transects_at_site.to_excel(writer, sheet_name="Transects")

                  # Sheet 4: intersection points
                  transect_ids = list(transects_at_site.index)
                  for transect_id in transect_ids:
                      if transect_id not in intersects.columns:
                          continue
                      distances = intersects[transect_id]

                      points = []
                      for d in distances:
                          if pd.isna(d):
                              points.append(None)
                          else:
                              try:
                                  pt = line_interpolate_point(
                                      transects_2193.geometry[transect_id], d
                                  )
                              except Exception:
                                  pt = None
                              points.append(pt)

                      gs = gpd.GeoSeries(points, crs=transects_2193.crs)
                      gs_ll = gs.to_crs(4326)
                      intersects[transect_id] = [
                          f"{p.y},{p.x}" if p is not None else None for p in gs_ll
                      ]

                  intersects.to_excel(writer, sheet_name="Intersect points")

              # Also drop a copy in the CWL working directory so glob can find it
              cwd_xlsx = os.path.join(os.getcwd(), f"{site_id}.xlsx")
              if os.path.abspath(cwd_xlsx) != os.path.abspath(out_xlsx_site):
                  import shutil
                  shutil.copy2(out_xlsx_site, cwd_xlsx)

              print(f"[{site_id}] Wrote Excel summary to {out_xlsx_site}")
              return 0


          if __name__ == "__main__":
              raise SystemExit(main())

baseCommand: [python3, make_xlsx_site.py]

inputs:
  site_id:
    type: string
    inputBinding:
      prefix: --site-id

  site_dir:
    type: Directory
    inputBinding:
      prefix: --site-dir

  transects_extended_geojson:
    type: File
    inputBinding:
      prefix: --transects-geojson

outputs:
  site_xlsx:
    type: File
    outputBinding:
      glob: $(inputs.site_id + ".xlsx")
