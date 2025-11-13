#!/usr/bin/env python3

import os
import argparse
from pathlib import Path

import geopandas as gpd
import pandas as pd
from tqdm.auto import tqdm
from shapely import line_interpolate_point

PROJECT_ROOT = Path(__file__).parent.parent
os.chdir(PROJECT_ROOT)


def load_transects() -> gpd.GeoDataFrame:
    """Load transects for NZ sites and compute helper columns."""
    transects = gpd.read_file("inputs/transects_extended.geojson").drop_duplicates(subset="id")
    transects.set_index("id", inplace=True)
    transects = gpd.GeoDataFrame(
        transects.loc[transects.site_id.str.startswith("nzd")].copy(),
        crs=transects.crs,
    )
    if len(transects) == 0:
        return transects

    transects["land_x"] = transects.geometry.apply(lambda x: x.coords[0][0])
    transects["land_y"] = transects.geometry.apply(lambda x: x.coords[0][1])
    transects["sea_x"] = transects.geometry.apply(lambda x: x.coords[-1][0])
    transects["sea_y"] = transects.geometry.apply(lambda x: x.coords[-1][1])
    transects["center_x"] = (transects["land_x"] + transects["sea_x"]) / 2
    transects["center_y"] = (transects["land_y"] + transects["sea_y"]) / 2

    # Export handy reference file (original behaviour)
    transects.to_excel("transects.xlsx")
    return transects


def process_site(site_id: str, transects: gpd.GeoDataFrame, transects_2193: gpd.GeoDataFrame) -> bool:
    """Create Excel output for a single site."""
    transects_at_site = gpd.GeoDataFrame(
        transects.loc[transects.site_id == site_id].copy(),
        crs=transects.crs,
    )
    if transects_at_site.empty:
        print(f"Warning: No transects found for {site_id}")
        return False

    transects_2193_at_site = gpd.GeoDataFrame(
        transects_2193.loc[transects_2193.site_id == site_id].copy(),
        crs=transects_2193.crs,
    )

    try:
        data_dir = Path("data") / site_id
        data_dir.mkdir(parents=True, exist_ok=True)

        with pd.ExcelWriter(data_dir / f"{site_id}.xlsx") as writer:
            intersects = pd.read_csv(data_dir / "transect_time_series_tidally_corrected.csv")
            intersects.set_index("dates", inplace=True)
            intersects.to_excel(writer, sheet_name="Intersects")

            tides = pd.read_csv(data_dir / "tides.csv")
            tides.to_excel(writer, sheet_name="Tides", index=False)

            transects_at_site.to_excel(writer, sheet_name="Transects")

            transect_ids = list(transects_at_site.index)
            for transect_id in transect_ids:
                intersects[transect_id] = (
                    gpd.GeoSeries(
                        line_interpolate_point(
                            transects_2193_at_site.geometry[transect_id],
                            intersects[transect_id]
                        ),
                        crs=2193,
                    )
                    .to_crs(4326)
                    .apply(lambda p: f"{p.y},{p.x}" if p else None)
                )

            intersects.to_excel(writer, sheet_name="Intersect points")

        print(f"Created Excel file for {site_id}")
        return True
    except FileNotFoundError as exc:
        print(f"Warning: Could not create Excel file for {site_id}: {exc}")
        return False


def parse_site_list(arg_sites) -> list:
    if arg_sites:
        return [s.strip() for s in arg_sites if s.strip()]
    env_sites = os.getenv("TEST_SITES", "")
    if env_sites:
        return [s.strip() for s in env_sites.split(",") if s.strip()]
    return []


def main():
    parser = argparse.ArgumentParser(description="Create Excel files from CoastSat outputs.")
    parser.add_argument(
        "--sites",
        nargs="+",
        help="Site IDs to process (e.g., nzd0001). If omitted, process all NZ sites present in inputs."
    )
    args = parser.parse_args()

    requested_sites = parse_site_list(args.sites)

    transects = load_transects()
    if transects.empty:
        print("No NZ transects found in inputs.")
        return

    if requested_sites:
        missing = [s for s in requested_sites if s not in transects.site_id.unique()]
        if missing:
            print(f"⚠️  Warning: {missing} not found in transects. They will be skipped.")
        transects = gpd.GeoDataFrame(
            transects.loc[transects.site_id.isin(requested_sites)].copy(),
            crs=transects.crs,
        )

    if transects.empty:
        print("No matching sites to process.")
        return

    transects_2193 = transects.to_crs(2193)
    site_ids = transects.site_id.unique()

    success = 0
    for site_id in tqdm(site_ids, desc="Processing sites"):
        try:
            if process_site(site_id, transects, transects_2193):
                success += 1
        except Exception as exc:
            print(f"Error processing {site_id}: {exc}")
            continue

    print()
    print(f"Completed Excel generation for {success}/{len(site_ids)} site(s).")


if __name__ == "__main__":
    main()

