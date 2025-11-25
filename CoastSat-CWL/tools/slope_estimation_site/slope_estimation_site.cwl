cwlVersion: v1.2
class: CommandLineTool

label: Estimate beach slope for a single NZ site

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: slope_estimation_site.py
        entry: |
          #!/usr/bin/env python3
          import argparse, json, os, sys

          # Ensure PROJ environment variables are set before importing geospatial libraries
          # This prevents GDAL/PROJ initialization errors
          conda_prefix = os.environ.get('CONDA_PREFIX', '/opt/conda/envs/coastsat-cwl')
          proj_data = os.path.join(conda_prefix, 'share', 'proj')
          if os.path.exists(proj_data):
              os.environ.setdefault('PROJ_DATA', proj_data)
              os.environ.setdefault('PROJ_LIB', proj_data)

          import pandas as pd
          import geopandas as gpd
          import numpy as np
          import pytz
          from datetime import datetime
          import SDS_slope  # provided as SDS_slope.py in this workdir

          def main(argv=None):
              p = argparse.ArgumentParser()
              p.add_argument("--site-id", required=True)
              p.add_argument("--site-dir", required=True)
              p.add_argument("--transects-geojson", required=True)
              args = p.parse_args(argv)

              site_id = args.site_id
              site_dir = os.path.abspath(args.site_dir)

              # Load transects and subset to this site
              transects = gpd.read_file(args.transects_geojson)
              new_transects = transects[transects.site_id == site_id].copy()
              if new_transects.empty:
                  # Nothing to do, write empty JSON
                  out = {"site_id": site_id, "slopes": {}}
                  with open(f"slopes_{site_id}.json", "w") as f:
                      json.dump(out, f)
                  return 0

              # Load time series + tides for this site
              ts_path = os.path.join(site_dir, "transect_time_series.csv")
              tides_path = os.path.join(site_dir, "tides.csv")
              df = pd.read_csv(ts_path)
              df.index = pd.to_datetime(df["dates"])
              df = df.drop(columns=["dates", "satname"])
              tides = pd.read_csv(tides_path)
              tides["dates"] = pd.to_datetime(tides["dates"])
              tides = tides.set_index("dates")
              # align/round as in notebook
              df.index = df.index.round("10min")
              assert all(df.index == tides.index)

              # Slope settings (as per notebook)
              seconds_in_day = 24 * 3600
              settings_slope = {
                  "slope_min": 0.01,
                  "slope_max": 0.2,
                  "delta_slope": 0.005,
                  "date_range": [1999, 2020],
                  "n_days": 8,
                  "n0": 50,
                  "freqs_cutoff": 1.0 / (seconds_in_day * 30),
                  "delta_f": 100 * 1e-10,
                  "prc_conf": 0.05,
              }
              settings_slope["date_range"] = [
                  pytz.utc.localize(datetime(settings_slope["date_range"][0], 5, 1)),
                  pytz.utc.localize(datetime(settings_slope["date_range"][1], 1, 1)),
              ]

              # This mirrors what the notebook did before calling integrate_power_spectrum.
              freqs_max = SDS_slope.find_tide_peak(
                  df.index,                 # datetime index of shoreline series
                  tides["tide"].to_numpy(), # NIWA tide levels
                  settings_slope,
              )
              settings_slope["freqs_max"] = freqs_max

              beach_slopes = SDS_slope.range_slopes(
                  settings_slope["slope_min"],
                  settings_slope["slope_max"],
                  settings_slope["delta_slope"],
              )

              slope_est = {}
              cis = {}
              t = np.array([_.timestamp() for _ in df.index]).astype("float64")

              for key in df.columns:
                  # Match notebook logic: skip NaNs
                  idx_nan = np.isnan(df[key])
                  if np.all(idx_nan):
                      continue
                  dates = [df.index[_] for _ in np.where(~idx_nan)[0]]
                  tide = tides["tide"].to_numpy()[~idx_nan]
                  composite = df[key][~idx_nan]

                  tsall = SDS_slope.tide_correct(composite, tide, beach_slopes)
                  s, ci = SDS_slope.integrate_power_spectrum(
                      dates, tsall, settings_slope
                  )
                  slope_est[key] = float(s)
                  cis[key] = [float(ci[0]), float(ci[1])]

              result = {
                  "site_id": site_id,
                  "slopes": {
                      k: {"beach_slope": slope_est[k], "cil": cis[k][0], "ciu": cis[k][1]}
                      for k in slope_est.keys()
                  },
              }

              with open(f"slopes_{site_id}.json", "w") as f:
                  json.dump(result, f, indent=2)

              return 0

          if __name__ == "__main__":
              raise SystemExit(main())

      # Here we materialise SDS_slope.py from the file input contents
      - entryname: SDS_slope.py
        entry: $(inputs.sds_slope.contents)

baseCommand: [python3, slope_estimation_site.py]

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

  sds_slope:
    type: File
    loadContents: true
    default:
      class: File
      location: SDS_slope.py

outputs:
  site_slopes:
    type: File
    outputBinding:
      glob: $( "slopes_" + inputs.site_id + ".json" )
