cwlVersion: v1.2
class: CommandLineTool

label: Merge per-site slope estimates into transects_extended.geojson

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: merge_slopes.py
        entry: |
          #!/usr/bin/env python3
          import argparse, json, os, sys
          import geopandas as gpd

          def main(argv=None):
              p = argparse.ArgumentParser()
              p.add_argument("--transects-geojson", required=True)
              p.add_argument("--site-slopes", nargs="+", required=True)
              args = p.parse_args(argv)

              transects = gpd.read_file(args.transects_geojson)

              # ensure columns exist
              for col in ["beach_slope", "cil", "ciu"]:
                  if col not in transects.columns:
                      transects[col] = None

              for path in args.site_slopes:
                  with open(path) as f:
                      data = json.load(f)
                  slopes = data.get("slopes", {})
                  for tid, vals in slopes.items():
                      if tid not in transects.index:
                          continue
                      transects.at[tid, "beach_slope"] = vals["beach_slope"]
                      transects.at[tid, "cil"] = vals["cil"]
                      transects.at[tid, "ciu"] = vals["ciu"]

              out_path = "transects_extended.geojson"
              transects.to_file(out_path)
              print(f"Wrote merged transects to {out_path}")
              return 0

          if __name__ == "__main__":
              raise SystemExit(main())

baseCommand: [python3, merge_slopes.py]

inputs:
  transects_extended_geojson:
    type: File
    inputBinding:
      prefix: --transects-geojson

  site_slopes:
    type: File[]
    inputBinding:
      prefix: --site-slopes

outputs:
  transects_extended_geojson_out:
    type: File
    outputBinding:
      glob: transects_extended.geojson
