cwlVersion: v1.2
class: CommandLineTool

$namespaces:
  cwltool: "http://commonwl.org/cwltool#"

label: Process single NZD site with CoastSat

doc: |
  Runs the batch_process_NZ logic for a single site.
  This tool is intended to be scattered over a list of NZD site IDs.
  It:
    - reads polygons, shorelines and transects GeoJSON files
    - reads any existing transect_time_series.csv for that site
    - downloads and processes new imagery with CoastSat
    - writes ./<site-id>/transect_time_series.csv as output

hints:
  "cwltool:Secrets":
    secrets: [gee_key_json]

requirements:
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: process_nzd_site.py
        entry: |
          #!/usr/bin/env python3
          #!/usr/bin/env python3
          import os
          import sys
          import argparse
          import warnings
          import tempfile
          import time
          from datetime import timedelta

          import numpy as np
          import pandas as pd
          import geopandas as gpd
          import ee
          from shapely.ops import split
          from shapely import line_merge

          from coastsat import SDS_download, SDS_shoreline, SDS_tools, SDS_transects

          warnings.filterwarnings("ignore")

          CRS = 2193  # NZTM2000

          def init_gee(gee_key_json: str, service_account: str) -> str:
              """Initialise Earth Engine using a service-account JSON string.

              Returns the path to the temporary key file so the caller can
              clean it up later if desired.
              """
              fd, key_path = tempfile.mkstemp(prefix="gee-key-", suffix=".json")
              os.close(fd)
              with open(key_path, "w") as f:
                  f.write(gee_key_json)
              credentials = ee.ServiceAccountCredentials(service_account, key_path)
              ee.Initialize(credentials)
              return key_path


          def process_site(
              sitename: str,
              poly: gpd.GeoDataFrame,
              shorelines: gpd.GeoDataFrame,
              transects_gdf: gpd.GeoDataFrame,
              existing_df: pd.DataFrame,
              min_date
          ):
              """Run the CoastSat shoreline workflow for a single site.

              Returns a concatenated DataFrame (existing + new results),
              or None if no new results are available.
              """
              print(f"Now processing {sitename}")

              inputs = {
                  "polygon": list(poly.geometry[sitename].exterior.coords),
                  "dates": [min_date, "2030-12-30"],  # all available imagery
                  "sat_list": ["L5", "L7", "L8", "L9"],
                  "sitename": sitename,
                  # put outputs under ./<sitename> relative to CWL step workdir
                  "filepath": os.path.abspath("."),
                  "landsat_collection": "C02",
              }

              metadata = SDS_download.retrieve_images(inputs)

              # settings for shoreline extraction (same as your NZ script)
              settings = {
                  "cloud_thresh": 0.1,
                  "dist_clouds": 300,
                  "output_epsg": CRS,
                  "check_detection": False,
                  "adjust_detection": False,
                  "save_figure": True,
                  "min_beach_area": 1000,
                  "min_length_sl": 500,
                  "cloud_mask_issue": False,
                  "sand_color": "default",
                  "pan_off": False,
                  "s2cloudless_prob": 40,
                  "inputs": inputs,
              }

              # Optional quicklooks:
              # SDS_preprocess.save_jpg(metadata, settings, use_matplotlib=True)

              # Transects for this site
              transects_at_site = transects_gdf[transects_gdf.site_id == sitename]
              transects = {
                  transect_id: np.array(transects_at_site.geometry[transect_id].coords)
                  for transect_id in transects_at_site.index
              }

              # Reference shoreline (NZD version flips it)
              ref_sl = np.array(
                  line_merge(split(shorelines.geometry[sitename], transects_at_site.unary_union)).coords
              )
              settings["max_dist_ref"] = 300
              settings["reference_shoreline"] = np.flip(ref_sl)

              output = SDS_shoreline.extract_shorelines(metadata, settings)
              print(f"Have {len(output['shorelines'])} new shorelines for {sitename}")
              if not output["shorelines"]:
                  return None

              # Flip each shoreline as in NZ script
              output["shorelines"] = [np.flip(s) for s in output["shorelines"]]

              # QC filters
              output = SDS_tools.remove_duplicates(output)
              output = SDS_tools.remove_inaccurate_georef(output, 10)

              settings_transects = {
                  "along_dist": 25,
                  "min_points": 3,
                  "max_std": 15,
                  "max_range": 30,
                  "min_chainage": -100,
                  "multiple_inter": "auto",
                  "auto_prc": 0.1,
              }

              cross_distance = SDS_transects.compute_intersection_QC(
                  output, transects, settings_transects
              )

              out_dict = {}
              out_dict["dates"] = output["dates"]
              out_dict["satname"] = output["satname"]
              for key in transects.keys():
                  out_dict[key] = cross_distance[key]

              new_results = pd.DataFrame(out_dict)
              if new_results.empty:
                  return None

              if existing_df is None or existing_df.empty:
                  df = new_results
              else:
                  df = pd.concat([existing_df, new_results], ignore_index=True)

              df.sort_values("dates", inplace=True)
              return df


          def main(argv=None) -> int:
              parser = argparse.ArgumentParser(
                  description="Process a single NZD site with CoastSat (CWL-friendly)"
              )
              parser.add_argument("--site-id", required=True, help="Site ID, e.g. nzd0001")
              parser.add_argument("--polygons-geojson", required=True, help="Polygons GeoJSON path")
              parser.add_argument("--shoreline-geojson", required=True, help="Shorelines GeoJSON path")
              parser.add_argument("--transects-geojson", required=True, help="Transects GeoJSON path")
              parser.add_argument(
                  "--existing-ts-root",
                  required=True,
                  help="Directory containing existing per-site transect_time_series.csv (subdir per site)",
              )
              parser.add_argument(
                  "--gee-key-json",
                  required=True,
                  help="GEE service-account JSON (string, marked as secret in CWL)",
              )
              parser.add_argument(
                  "--service-account-email",
                  required=False,
                  # falls back to your original hard-coded service account if env var not set
                  default=os.environ.get(
                      "GEE_SERVICE_ACCOUNT",
                      "service-account@iron-dynamics-294100.iam.gserviceaccount.com",
                  ),
              )

              args = parser.parse_args(argv)

              start = time.time()
              key_path = init_gee(args.gee_key_json, args.service_account_email)
              print(f"{time.time() - start:.1f}s: Logged into EE as {args.service_account_email}")

              # Load data for this site only
              poly = gpd.read_file(args.polygons_geojson)
              poly = poly[poly.id == args.site_id]
              if poly.empty:
                  print(f"No polygon found for site {args.site_id}", file=sys.stderr)
                  return 1
              poly.set_index("id", inplace=True)

              shorelines = gpd.read_file(args.shoreline_geojson)
              shorelines = shorelines[shorelines.id == args.site_id].to_crs(CRS)
              if shorelines.empty:
                  print(f"No shoreline found for site {args.site_id}", file=sys.stderr)
                  return 1
              shorelines.set_index("id", inplace=True)

              transects_gdf = (
                  gpd.read_file(args.transects_geojson)
                  .to_crs(CRS)
                  .drop_duplicates(subset="id")
              )
              transects_gdf.set_index("id", inplace=True)

              # Existing time-series, if any
              existing_root = args.existing_ts_root
              existing_csv = os.path.join(existing_root, args.site_id, "transect_time_series.csv")
              try:
                  existing_df = pd.read_csv(existing_csv)
                  existing_df.dates = pd.to_datetime(existing_df.dates)
                  min_date = str(existing_df.dates.max().date() + timedelta(days=1))
              except FileNotFoundError:
                  existing_df = pd.DataFrame()
                  min_date = "1984-01-01"

              df = process_site(args.site_id, poly, shorelines, transects_gdf, existing_df, min_date)

              if df is None:
                  # Case 1: we have existing data but nothing new – reuse the existing time series
                  if existing_df is not None and not existing_df.empty:
                      print(
                          f"No new shorelines for {args.site_id}; "
                          f"reusing existing transect_time_series.csv from input."
                      )
                      df_to_write = existing_df
                  else:
                      # Case 2: no existing data and no new data – write an empty placeholder
                      # so CWL can still glob a file and downstream tools can handle "no data".
                      print(
                          f"No shorelines and no existing time series for {args.site_id}; "
                          f"writing an empty placeholder transect_time_series.csv"
                      )
                      df_to_write = pd.DataFrame(columns=["dates", "satname"])
              else:
                  # Normal case: we have a merged (existing + new) DataFrame
                  print(f"[batch_process_sar] New data found for site {args.site_id}, writing to file.")
                  df_to_write = df

              # Write output: ./<site-id>/transect_time_series.csv in the CWL workdir
              site_dir = os.path.join(os.getcwd(), args.site_id)
              os.makedirs(site_dir, exist_ok=True)
              out_csv = os.path.join(site_dir, "transect_time_series.csv")
              df_to_write.to_csv(out_csv, index=False, float_format="%.2f")
              print(f"{args.site_id} is done. Time-series saved as: {out_csv}")
              return 0

          if __name__ == "__main__":
              raise SystemExit(main())


baseCommand: [python3, process_nzd_site.py]

inputs:
  site_id:
    type: string
    doc: Site ID, e.g. nzd0001
    inputBinding:
      prefix: --site-id

  polygons_geojson:
    type: File
    inputBinding:
      prefix: --polygons-geojson

  shoreline_geojson:
    type: File
    inputBinding:
      prefix: --shoreline-geojson

  transects_extended_geojson:
    type: File
    inputBinding:
      prefix: --transects-geojson

  transect_time_series_per_site:
    type: Directory
    doc: Directory containing existing per-site transect_time_series.csv
    inputBinding:
      prefix: --existing-ts-root

  gee_key_json:
    type: string
    inputBinding:
      prefix: --gee-key-json

  service_account_email:
    type: string?
    doc: >
      Optional GEE service account email. If not set, defaults to the hard-coded
      service account in the script or the GEE_SERVICE_ACCOUNT env var.
    inputBinding:
      prefix: --service-account-email

stdout: process_site.log

outputs:
  site_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.site_id)

  transect_time_series:
    type: File
    outputBinding:
      glob: $(inputs.site_id + "/transect_time_series.csv")
