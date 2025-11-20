cwlVersion: v1.2
class: CommandLineTool

label: Merge per-site linear trends into transects_extended.geojson

doc: |
  Reads an existing transects_extended.geojson (already augmented with slopes)
  and a collection of per-site linear trend JSON files (one per site),
  then joins the trend metrics onto the transects table by transect_id/id.

  Each site_models file is expected to have structure:
    {
      "site_id": "nzd0001" | "sar0001" | ...,
      "trends": {
        "<transect_id>": {
          "trend": ...,
          "intercept": ...,
          "n_points": ...,
          "n_points_nonan": ...,
          "r2_score": ...,
          "mae": ...,
          "mse": ...,
          "rmse": ...
        },
        ...
      }
    }

  The tool:
    - loads transects_extended.geojson into a GeoDataFrame with index 'id'
    - flattens all site_models into a single DataFrame indexed by transect_id
    - drops any trend columns that already exist on transects
    - performs transects = transects.join(trends_filtered)
    - writes transects_extended.geojson in the current working directory.

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: merge_linear_models.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import json
          import sys

          import geopandas as gpd
          import pandas as pd


          def main(argv=None) -> int:
              p = argparse.ArgumentParser(
                  description="Merge per-site linear models into transects_extended.geojson"
              )
              p.add_argument(
                  "--transects-geojson",
                  required=True,
                  help="Input transects_extended.geojson (with slopes etc.)",
              )
              p.add_argument(
                  "--site-models",
                  nargs="+",
                  required=True,
                  help="Per-site linear model JSON files",
              )
              args = p.parse_args(argv)

              # --- Load transects and choose ID column ---
              transects = gpd.read_file(args.transects_geojson)

              if "id" in transects.columns:
                  id_col = "id"
              elif "transect_id" in transects.columns:
                  id_col = "transect_id"
              else:
                  print(
                      "Error: transects_extended.geojson has neither 'id' nor 'transect_id' column",
                      file=sys.stderr,
                  )
                  print("Available columns:", list(transects.columns), file=sys.stderr)
                  return 1

              transects[id_col] = transects[id_col].astype(str)
              transects = transects.set_index(id_col)

              print(f"[merge_linear_models] Using '{id_col}' as transect ID column")
              print(f"[merge_linear_models] Transects rows: {len(transects)}")

              # --- Flatten all site_models into a DataFrame ---
              rows = []
              for path in args.site_models:
                  with open(path, "r") as f:
                      data = json.load(f)
                  site_id = data.get("site_id")
                  trends = data.get("trends", {})
                  for transect_id, metrics in trends.items():
                      row = {
                          "transect_id": str(transect_id),
                          "site_id_model": site_id,
                      }
                      row.update(metrics)
                      rows.append(row)

              if not rows:
                  out_path = "transects_extended.geojson"
                  transects.reset_index().to_file(out_path, driver="GeoJSON")
                  print("[merge_linear_models] No trends to merge; wrote original transects to", out_path)
                  return 0

              trends_df = pd.DataFrame(rows)
              trends_df = trends_df.drop_duplicates(subset="transect_id", keep="last")
              trends_df = trends_df.set_index("transect_id")
              trends_df.index = trends_df.index.astype(str)

              print(f"[merge_linear_models] Loaded {len(args.site_models)} model files")
              print(f"[merge_linear_models] Unique transect_ids in trends: {len(trends_df)}")

              # --- Join with suffix _new, then selectively overwrite ---
              trends_new = trends_df.add_suffix("_new")
              transects_out = transects.join(trends_new, how="left")

              metric_cols = list(trends_df.columns)  # includes site_id_model and all metrics
              updated_counts = {}

              for col in metric_cols:
                  new_col = col + "_new"
                  if new_col not in transects_out.columns:
                      continue

                  if col in transects_out.columns:
                      # Overwrite existing values where we have new non-null ones
                      before_nonnull = transects_out[col].notna().sum()
                      transects_out[col] = transects_out[new_col].where(
                          transects_out[new_col].notna(),
                          transects_out[col],
                      )
                      after_nonnull = transects_out[col].notna().sum()
                      updated_counts[col] = (before_nonnull, after_nonnull)
                  else:
                      # Column didn't exist before: just copy
                      transects_out[col] = transects_out[new_col]
                      updated_counts[col] = (0, transects_out[col].notna().sum())

              # Drop all *_new helper columns
              new_cols = [c for c in transects_out.columns if c.endswith("_new")]
              transects_out = transects_out.drop(columns=new_cols)

              for col, (before, after) in updated_counts.items():
                  print(f"[merge_linear_models] '{col}': non-null before={before}, after={after}")

              if "trend" in transects_out.columns:
                  n_nonnull = transects_out["trend"].notna().sum()
                  print(f"[merge_linear_models] Rows with non-null 'trend' after merge: {n_nonnull}")

              out_path = "transects_extended.geojson"
              transects_out.reset_index().to_file(out_path, driver="GeoJSON")
              print("[merge_linear_models] Wrote merged transects to", out_path)
              return 0


          if __name__ == "__main__":
              raise SystemExit(main())


baseCommand: [python3, merge_linear_models.py]

inputs:
  transects_extended_geojson:
    type: File
    inputBinding:
      prefix: --transects-geojson

  site_models:
    type: File[]
    inputBinding:
      prefix: --site-models
      separate: true

outputs:
  transects_extended_geojson_out:
    type: File
    outputBinding:
      glob: transects_extended.geojson
