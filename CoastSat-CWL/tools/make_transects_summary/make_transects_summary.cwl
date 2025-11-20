cwlVersion: v1.2
class: CommandLineTool

label: Make global transects.xlsx summary (NZD sites)

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: make_transects_summary.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import geopandas as gpd
          import pandas as pd

          def main(argv=None):
              p = argparse.ArgumentParser()
              p.add_argument("--transects-geojson", required=True)
              args = p.parse_args(argv)

              transects = gpd.read_file(args.transects_geojson).drop_duplicates(subset="id")
              transects.set_index("id", inplace=True)
              transects = transects[transects.site_id.str.startswith("nzd")].copy()

              transects["land_x"] = transects.geometry.apply(lambda x: x.coords[0][0])
              transects["land_y"] = transects.geometry.apply(lambda x: x.coords[0][1])
              transects["sea_x"]  = transects.geometry.apply(lambda x: x.coords[-1][0])
              transects["sea_y"]  = transects.geometry.apply(lambda x: x.coords[-1][1])
              transects["center_x"] = (transects["land_x"] + transects["sea_x"]) / 2
              transects["center_y"] = (transects["land_y"] + transects["sea_y"]) / 2

              transects.to_excel("transects.xlsx")
              print("Wrote transects.xlsx for NZD sites")
              return 0

          if __name__ == "__main__":
              raise SystemExit(main())

baseCommand: [python3, make_transects_summary.py]

inputs:
  transects_extended_geojson:
    type: File
    inputBinding:
      prefix: --transects-geojson

outputs:
  transects_xlsx:
    type: File
    outputBinding:
      glob: transects.xlsx
