cwlVersion: v1.2
class: CommandLineTool

$namespaces:
  cwltool: "http://commonwl.org/cwltool#"

label: Apply tidal correction for a single NZ site

doc: |
  Given a site_id, transects_extended.geojson, and a per-site directory
  containing transect_time_series.csv and tides.csv, apply tidal correction
  using the per-transect beach slopes and write
  transect_time_series_tidally_corrected.csv.

  Intended to be scattered over NZD site IDs, after:
    1. batch_process_nz.cwl (produces transect_time_series.csv)
    2. fetch_tides_nz_site.cwl (produces tides.csv)
    3. slope_estimation.cwl (fills beach_slope, cil, ciu in transects_extended.geojson)

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - entryname: apply_tidal_correction_nz_site.py
        entry: |
          #!/usr/bin/env python3
          import os
          import sys
          import argparse
          import shutil
          import warnings

          import numpy as np
          import pandas as pd
          import geopandas as gpd
          from coastsat import SDS_transects

          warnings.filterwarnings("ignore")


          def despike(series: pd.Series, threshold: float = 40.0) -> pd.Series:
              """
              Apply CoastSat-style despiking to a 1D time series using
              SDS_transects.identify_outliers.

              Returns a new Series with the same index; non-outlier values
              are kept, outliers are removed.
              """
              chainage = series.dropna()
              if chainage.empty:
                  return series

              cleaned, dates = SDS_transects.identify_outliers(
                  chainage.tolist(), chainage.index.to_list(), threshold
              )

              out = pd.Series(index=series.index, dtype="float64")
              out.loc[dates] = cleaned
              return out


          def main(argv=None) -> int:
              parser = argparse.ArgumentParser(
                  description="Apply tidal correction for a single NZ site."
              )
              parser.add_argument(
                  "--site-id",
                  required=True,
                  help="Site ID (e.g. nzd0001)",
              )
              parser.add_argument(
                  "--transects-geojson",
                  required=True,
                  help="Path to transects_extended.geojson (with beach_slope per transect).",
              )
              parser.add_argument(
                  "--site-dir",
                  required=True,
                  help=(
                      "Per-site directory containing transect_time_series.csv "
                      "and tides.csv for this site."
                  ),
              )

              args = parser.parse_args(argv)

              site_id = args.site_id
              site_dir_in = os.path.abspath(args.site_dir)

              ts_path = os.path.join(site_dir_in, "transect_time_series.csv")
              tides_path = os.path.join(site_dir_in, "tides.csv")

              if not os.path.isfile(ts_path):
                  print(f"[{site_id}] Missing transect_time_series.csv, skipping", file=sys.stderr)
                  return 0

              if not os.path.isfile(tides_path):
                  print(f"[{site_id}] Missing tides.csv, skipping", file=sys.stderr)
                  return 0

              # Load transects with slopes
              transects = gpd.read_file(args.transects_geojson)
              if "site_id" not in transects.columns:
                  print(
                      "transects_extended.geojson must contain a 'site_id' column.",
                      file=sys.stderr,
                  )
                  return 1

              transects_at_site = transects[transects["site_id"] == site_id]
              if transects_at_site.empty:
                  print(
                      f"[{site_id}] No transects found in transects_extended.geojson, skipping.",
                      file=sys.stderr,
                  )
                  return 0

              if "beach_slope" not in transects_at_site.columns:
                  print(
                      f"[{site_id}] beach_slope column missing in transects_extended.geojson.",
                      file=sys.stderr,
                  )
                  return 1

              # Index transects by 'id' so we can match columns to transect IDs
              transects_at_site = transects_at_site.set_index("id")

              print(f"[{site_id}] Found {len(transects_at_site)} transects at this site.", file=sys.stderr)

              # Load raw intersections
              raw = pd.read_csv(ts_path)
              if "dates" not in raw.columns:
                  print(f"[{site_id}] 'dates' column missing in transect_time_series.csv", file=sys.stderr)
                  return 1

              raw["dates"] = pd.to_datetime(raw["dates"])
              raw.set_index("dates", inplace=True)
              raw.index = raw.index.round("10min")

              # Load tides and align to raw index
              tides = pd.read_csv(tides_path)
              if "dates" not in tides.columns or "tide" not in tides.columns:
                  print(
                      f"[{site_id}] tides.csv must have 'dates' and 'tide' columns.",
                      file=sys.stderr,
                  )
                  return 1

              tides["dates"] = pd.to_datetime(tides["dates"])
              tides.set_index("dates", inplace=True)
              tides = tides.sort_index()
              tides = tides[~tides.index.duplicated(keep="first")]

              # Reindex tides to raw index and interpolate if necessary
              tides_aligned = tides.reindex(raw.index)
              if tides_aligned["tide"].isna().any():
                  tides_aligned["tide"] = tides_aligned["tide"].interpolate().bfill().ffill()

              # Identify transect columns (everything except satname)
              transect_cols = [c for c in raw.columns if c != "satname"]

              # Build slopes Series aligned to transect columns
              slopes = transects_at_site["beach_slope"].astype("float64")
              slopes = slopes.sort_index() # Sort to make interpolation deterministic along some alongshore order              
              slopes = slopes.interpolate().bfill().ffill() # Interpolate and fill missing slopes (just to stay 1:1 with the notebook)
              slopes = slopes.reindex(transect_cols) # Reindex to match the columns


              # Build tidal correction DataFrame
              corrections = pd.DataFrame(index=raw.index, columns=transect_cols, dtype="float64")

              tide_vals = tides_aligned["tide"].to_numpy(dtype="float64")

              for col in transect_cols:
                  slope = slopes.get(col)
                  if slope is None or np.isnan(slope) or slope == 0:
                      # No slope → no correction for this transect
                      continue
                  # Horizontal correction along transect = tide / slope
                  corrections[col] = tide_vals / slope

              # Fill any remaining NaNs in corrections with 0 (no correction)
              corrections = corrections.fillna(0.0)

              # Apply corrections
              corrected = raw.copy()
              corrected[transect_cols] = corrected[transect_cols] + corrections[transect_cols]

              # Despike per transect (excluding satname)
              corrected_no_sat = corrected.drop(columns="satname", errors="ignore")
              corrected_no_sat = corrected_no_sat.apply(despike, axis=0)
              corrected_no_sat.index.name = "dates"

              # Re-add satname if present
              if "satname" in raw.columns:
                  corrected_no_sat["satname"] = raw["satname"]

              # Prepare output directory: ./<site_id> relative to CWL outdir
              out_site_dir = os.path.join(os.getcwd(), site_id)
              os.makedirs(out_site_dir, exist_ok=True)

              # Copy original files for convenience/continuity
              shutil.copy2(ts_path, os.path.join(out_site_dir, "transect_time_series.csv"))
              shutil.copy2(tides_path, os.path.join(out_site_dir, "tides.csv"))

              out_csv = os.path.join(out_site_dir, "transect_time_series_tidally_corrected.csv")
              corrected_no_sat.to_csv(out_csv, float_format='%.2f')

              print(f"[{site_id}] Wrote tidally corrected time series to {out_csv}", file=sys.stderr)
              return 0


          if __name__ == "__main__":
              raise SystemExit(main())


baseCommand: [python3, apply_tidal_correction_nz_site.py]

inputs:
  site_id:
    type: string
    doc: Site ID, e.g. nzd0001
    inputBinding:
      prefix: --site-id

  transects_extended_geojson:
    type: File
    doc: Updated transects_extended.geojson with beach_slope values
    inputBinding:
      prefix: --transects-geojson

  site_dir_in:
    type: Directory
    doc: Per-site directory containing transect_time_series.csv and tides.csv
    inputBinding:
      prefix: --site-dir
      valueFrom: $(self.path)

stdout: apply_tidal_correction.log

outputs:
  site_dir:
    type: Directory
    doc: >
      Per-site directory containing transect_time_series.csv, tides.csv,
      and transect_time_series_tidally_corrected.csv.
    outputBinding:
      glob: $(inputs.site_id)

  transect_time_series_tidally_corrected:
    type: File
    doc: Tidally corrected time series for this site.
    outputBinding:
      glob: $(inputs.site_id + "/transect_time_series_tidally_corrected.csv")
