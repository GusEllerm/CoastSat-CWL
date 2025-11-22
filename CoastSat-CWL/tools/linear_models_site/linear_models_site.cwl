cwlVersion: v1.2
class: CommandLineTool

label: Fit linear shoreline trend for a single site

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: linear_models_site.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import shutil
          import json
          import os

          import numpy as np
          import pandas as pd
          from sklearn.linear_model import LinearRegression
          from sklearn.metrics import (
              mean_squared_error,
              r2_score,
              mean_absolute_error,
              root_mean_squared_error,
          )
          # As in the notebook: use SDS_transects.despike helper
          from coastsat import SDS_transects


          def despike(chainage: pd.Series, threshold: float = 40) -> pd.Series:
              """
              Match linear_models.ipynb: use SDS_transects.identify_outliers to
              drop spikes, returning a Series with filtered values and dates.
              """
              chainage = chainage.dropna()
              if chainage.empty:
                  return chainage
              chainage_vals, dates = SDS_transects.identify_outliers(
                  chainage.tolist(), chainage.index.tolist(), threshold
              )
              return pd.Series(chainage_vals, index=dates)


          def main(argv=None) -> int:
              p = argparse.ArgumentParser()
              p.add_argument("--site-id", required=True)
              p.add_argument("--site-dir", required=True)
              args = p.parse_args(argv)

              site_id = args.site_id
              site_dir = os.path.abspath(args.site_dir)

              # Prefer tidally-corrected, fall back to raw.
              # In the original notebook, `my_files` points at
              # transect_time_series_tidally_corrected.csv, but
              # here we support both patterns.
              tc_path = os.path.join(site_dir, "transect_time_series_tidally_corrected.csv")
              raw_path = os.path.join(site_dir, "transect_time_series.csv")

              if os.path.exists(tc_path):
                  f = tc_path
              elif os.path.exists(raw_path):
                  f = raw_path
              else:
                  # Nothing to do for this site
                  with open(f"linear_{site_id}.json", "w") as fp:
                      json.dump({"site_id": site_id, "trends": {}}, fp, indent=2)
                  return 0

              df = pd.read_csv(f)
              # Robust datetime parse, as in the notebook
              try:
                  df["dates"] = pd.to_datetime(df["dates"])
              except Exception:
                  # If that fails, just log the filename like the notebook did
                  print(f"Could not parse dates for {f}")

              # --- SAR / BER smoothing branch (from notebook) ---
              if site_id.startswith("sar") or site_id.startswith("ber"):
                  smoothed_filename = f.replace(".csv", "_smoothed.csv")
                  try:
                      # If a smoothed file already exists, re-use it
                      df_smooth = pd.read_csv(smoothed_filename)
                      df_smooth["dates"] = pd.to_datetime(df_smooth["dates"])
                      df = df_smooth
                  except FileNotFoundError:
                      # Recreate the despiked + 180d-rolling-smoothed series
                      df["dates"] = pd.to_datetime(df["dates"])
                      df.set_index("dates", inplace=True)

                      # Preserve satname if present; despike numeric columns
                      satname = df.get("satname", None)
                      df_no_sat = df.drop(columns=["satname"], errors="ignore")
                      df_des = df_no_sat.apply(despike, axis=0)
                      if satname is not None:
                          df_des["satname"] = satname

                      # Save despiked version
                      df_des.reset_index(names="dates").to_csv(
                          f.replace(".csv", "_despiked.csv"), index=False
                      )

                      # 180-day rolling mean on all transect columns (exclude satname)
                      for col in df_des.drop(columns=["satname"], errors="ignore").columns:
                          df_des[col] = df_des[col].rolling("180d", min_periods=1).mean()

                      df_des.reset_index(names="dates", inplace=True)
                      df_des.to_csv(smoothed_filename, index=False)
                      df = df_des
              # --- end SAR / BER special handling ---

              # Time axis in fractional years since the earliest date in this file,
              # as in the notebook:
              #   df.index = (df.dates - df.dates.min()).dt.days / 365.25
              df.index = (df["dates"] - df["dates"].min()).dt.days / 365.25

              # Drop non-transect columns exactly like the notebook
              df.drop(
                  columns=["dates", "satname", "Unnamed: 0"],
                  inplace=True,
                  errors="ignore",
              )

              trends = []
              for transect_id in df.columns:
                  sub_df = df[transect_id].dropna()
                  if not len(sub_df):
                      continue

                  x = sub_df.index.to_numpy().reshape(-1, 1)
                  y = sub_df.to_numpy()

                  linear_model = LinearRegression().fit(x, y)
                  pred = linear_model.predict(x)

                  trends.append(
                      {
                          "transect_id": transect_id,
                          "trend": float(linear_model.coef_[0]),
                          "intercept": float(linear_model.intercept_),
                          "n_points": int(len(df[transect_id])),
                          "n_points_nonan": int(len(sub_df)),
                          "r2_score": float(r2_score(y, pred)),
                          "mae": float(mean_absolute_error(y, pred)),
                          "mse": float(mean_squared_error(y, pred)),
                          "rmse": float(root_mean_squared_error(y, pred)),
                      }
                  )

              result = {
                  "site_id": site_id,
                  "trends": {t["transect_id"]: t for t in trends},
              }

              with open(f"linear_{site_id}.json", "w") as fp:
                  json.dump(result, fp, indent=2)

              out_site_dir = os.path.join(os.getcwd(), site_id)
              os.makedirs(out_site_dir, exist_ok=True)

              # Always copy the base time-series file we actually used (f)
              if os.path.exists(f):
                  shutil.copy2(
                      f,
                      os.path.join(out_site_dir, os.path.basename(f)),
                  )

              # For SAR/BER, we may also have despiked/smoothed variants
              for suffix in ("_despiked.csv", "_smoothed.csv"):
                  candidate = f.replace(".csv", suffix)
                  if os.path.exists(candidate):
                      shutil.copy2(
                          candidate,
                          os.path.join(out_site_dir, os.path.basename(candidate)),
                      )

              return 0


          if __name__ == "__main__":
              raise SystemExit(main())

baseCommand: [python3, linear_models_site.py]

inputs:
  site_id:
    type: string
    inputBinding:
      prefix: --site-id

  site_dir:
    type: Directory
    inputBinding:
      prefix: --site-dir

outputs:
  site_models:
    type: File
    outputBinding:
      glob: $( "linear_" + inputs.site_id + ".json" )

  site_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.site_id)
