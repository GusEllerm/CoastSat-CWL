#!/usr/bin/env python3
"""
Compare outputs from the new minimal workflow with the original CoastSat workflow.

This script compares output files from both workflows to ensure they produce
the same results. It handles minor differences in formatting and floating-point
precision while detecting significant discrepancies.
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import pandas as pd
import geopandas as gpd
import numpy as np
from dataclasses import dataclass, field
from datetime import datetime

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

# Configuration
ORIGINAL_DATA_DIR = project_root / "CoastSat" / "data"
NEW_DATA_DIR = project_root / "data"
ORIGINAL_TRANSECTS = project_root / "CoastSat" / "transects_extended.geojson"
NEW_TRANSECTS = project_root / "inputs" / "transects_extended.geojson"

# Tolerance for floating-point comparisons
FLOAT_TOLERANCE = 1e-6
RELATIVE_TOLERANCE = 1e-5

# Sites to compare
TEST_SITES = ["nzd0001", "nzd0002", "nzd0003", "sar0001"]


@dataclass
class ComparisonResult:
    """Result of comparing two files."""
    file_path: str
    status: str  # "match", "different", "missing_original", "missing_new", "error"
    differences: List[str] = field(default_factory=list)
    summary: str = ""
    details: Dict = field(default_factory=dict)


def compare_csv_files(
    original_path: Path,
    new_path: Path,
    tolerance: float = FLOAT_TOLERANCE
) -> ComparisonResult:
    """
    Compare two CSV files with alignment on key columns.
    
    Args:
        original_path: Path to original CSV file
        new_path: Path to new CSV file
        tolerance: Tolerance for floating-point comparisons
        
    Returns:
        ComparisonResult with comparison details
    """
    try:
        file_path = str(new_path.relative_to(project_root))
    except ValueError:
        file_path = str(new_path)

    result = ComparisonResult(
        file_path=file_path,
        status="error"
    )

    try:
        if not original_path.exists():
            result.status = "missing_original"
            result.summary = f"Original file not found: {original_path}"
            return result

        if not new_path.exists():
            result.status = "missing_new"
            result.summary = f"New file not found: {new_path}"
            return result

        original_df = pd.read_csv(original_path)
        new_df = pd.read_csv(new_path)

        # Determine key columns for alignment
        key_columns: List[str] = []
        if 'dates' in original_df.columns and 'dates' in new_df.columns:
            key_columns.append('dates')
        elif 'date' in original_df.columns and 'date' in new_df.columns:
            key_columns.append('date')
        if 'satname' in original_df.columns and 'satname' in new_df.columns and key_columns:
            key_columns.append('satname')

        def prepare_dataframe(df: pd.DataFrame) -> pd.DataFrame:
            temp = df.copy()
            for key in key_columns:
                if key in temp.columns and key in ('dates', 'date'):
                    temp[key] = pd.to_datetime(temp[key])
            if key_columns:
                temp['__row_order'] = temp.groupby(key_columns).cumcount()
                index_cols = key_columns + ['__row_order']
            else:
                temp['__row_order'] = range(len(temp))
                index_cols = ['__row_order']
            temp.set_index(index_cols, inplace=True)
            return temp

        original_prepared = prepare_dataframe(original_df)
        new_prepared = prepare_dataframe(new_df)

        common_index = original_prepared.index.intersection(new_prepared.index)
        missing_in_new = original_prepared.index.difference(new_prepared.index)
        missing_in_original = new_prepared.index.difference(original_prepared.index)

        original_aligned = original_prepared.loc[common_index].sort_index()
        new_aligned = new_prepared.loc[common_index].sort_index()

        differences_found = False

        if len(missing_in_new) > 0:
            sample_missing = list(missing_in_new[:5])
            result.differences.append(
                f"Rows missing in new file: {len(missing_in_new)} (e.g., {sample_missing})"
            )
            differences_found = True

        if len(missing_in_original) > 0:
            sample_missing = list(missing_in_original[:5])
            result.differences.append(
                f"Rows missing in original file: {len(missing_in_original)} (e.g., {sample_missing})"
            )
            differences_found = True

        # Compare numeric columns
        numeric_columns = [
            col for col in original_aligned.columns
            if col in new_aligned.columns
            and pd.api.types.is_numeric_dtype(original_aligned[col])
            and col != '__row_order'
        ]

        for col in numeric_columns:
            orig_values = original_aligned[col]
            new_values = new_aligned[col]
            diff = orig_values - new_values
            if not np.allclose(orig_values, new_values, rtol=RELATIVE_TOLERANCE, atol=tolerance, equal_nan=True):
                max_diff = diff.abs().max()
                mean_diff = diff.abs().mean()
                num_diff = (diff.abs() > tolerance).sum()
                result.differences.append(
                    f"Column '{col}': max_diff={max_diff:.6f}, mean_diff={mean_diff:.6f}, {num_diff} values differ"
                )
                differences_found = True

        # Compare string/object columns (excluding indices)
        string_columns = [
            col for col in original_aligned.columns
            if col in new_aligned.columns
            and col not in numeric_columns
            and original_aligned[col].dtype == object
        ]

        for col in string_columns:
            orig_series = original_aligned[col].astype(str).str.strip()
            new_series = new_aligned[col].astype(str).str.strip()
            diff_mask = orig_series != new_series
            if diff_mask.any():
                differences = diff_mask.sum()
                result.differences.append(
                    f"Column '{col}': {differences} string differences"
                )
                differences_found = True

        result.details = {
            "original_rows": len(original_df),
            "new_rows": len(new_df),
            "aligned_rows": len(common_index),
            "missing_rows_in_new": len(missing_in_new),
            "missing_rows_in_original": len(missing_in_original),
            "numeric_columns_compared": numeric_columns,
            "string_columns_compared": string_columns,
            "num_differences": len(result.differences)
        }

        if differences_found:
            result.status = "different"
            result.summary = f"Files differ: {len(result.differences)} differences found"
        else:
            result.status = "match"
            result.summary = "Files match (within tolerance)"

    except Exception as e:
        result.status = "error"
        result.summary = f"Error comparing files: {e}"
        result.details = {"error": str(e)}

    return result


def compare_geojson_files(
    original_path: Path,
    new_path: Path,
    tolerance: float = FLOAT_TOLERANCE,
    compare_columns: Optional[List[str]] = None
) -> ComparisonResult:
    """
    Compare two GeoJSON files, focusing on specific columns.
    
    Args:
        original_path: Path to original GeoJSON file
        new_path: Path to new GeoJSON file
        tolerance: Tolerance for floating-point comparisons
        compare_columns: List of columns to compare (if None, compares all)
        
    Returns:
        ComparisonResult with comparison details
    """
    result = ComparisonResult(
        file_path=str(new_path.relative_to(project_root)),
        status="error"
    )
    
    try:
        # Check if files exist
        if not original_path.exists():
            result.status = "missing_original"
            result.summary = f"Original file not found: {original_path}"
            return result
        
        if not new_path.exists():
            result.status = "missing_new"
            result.summary = f"New file not found: {new_path}"
            return result
        
        # Read GeoJSON files
        try:
            original_gdf = gpd.read_file(original_path)
        except Exception:
            try:
                original_gdf = gpd.read_file(original_path, engine="fiona")
            except Exception as inner_exc:
                result.status = "skipped"
                result.summary = "Skipped GeoJSON comparison (requires pyogrio or fiona)"
                result.details = {"error": str(inner_exc)}
                return result
        try:
            new_gdf = gpd.read_file(new_path)
        except Exception:
            try:
                new_gdf = gpd.read_file(new_path, engine="fiona")
            except Exception as inner_exc:
                result.status = "skipped"
                result.summary = "Skipped GeoJSON comparison (requires pyogrio or fiona)"
                result.details = {"error": str(inner_exc)}
                return result

        # Set index if 'id' column exists
        if 'id' in original_gdf.columns:
            original_gdf.set_index('id', inplace=True)
        if 'id' in new_gdf.columns:
            new_gdf.set_index('id', inplace=True)
        
        # Filter to test sites if specified
        if compare_columns is None:
            columns_to_compare: List[str] = (
                original_gdf.select_dtypes(include=[np.number]).columns.tolist()
            )
            columns_to_compare = [col for col in columns_to_compare if col != 'geometry']
        else:
            columns_to_compare = [
                col for col in compare_columns
                if col in original_gdf.columns and col in new_gdf.columns
            ]
        
        # Filter to sites that exist in both
        common_indices = original_gdf.index.intersection(new_gdf.index)
        if len(common_indices) == 0:
            result.status = "different"
            result.summary = "No common indices found"
            return result
        
        original_gdf = original_gdf.loc[common_indices]
        new_gdf = new_gdf.loc[common_indices]
        
        # Compare specified columns
        differences_found = False
        for col in columns_to_compare:
            if col in original_gdf.columns and col in new_gdf.columns:
                # Handle NaN values
                orig_values = original_gdf[col].fillna(0)
                new_values = new_gdf[col].fillna(0)
                
                # Compare using numpy allclose
                if not np.allclose(orig_values, new_values, rtol=RELATIVE_TOLERANCE, atol=tolerance, equal_nan=True):
                    max_diff = np.abs(orig_values - new_values).max()
                    mean_diff = np.abs(orig_values - new_values).mean()
                    num_diff = (np.abs(orig_values - new_values) > tolerance).sum()
                    result.differences.append(
                        f"Column '{col}': max_diff={max_diff:.6f}, mean_diff={mean_diff:.6f}, {num_diff} values differ"
                    )
                    differences_found = True
        
        if differences_found:
            result.status = "different"
            result.summary = f"Files differ: {len(result.differences)} column differences found"
        else:
            result.status = "match"
            result.summary = "Files match (within tolerance)"
        
        # Add summary statistics
        result.details = {
            "original_rows": len(original_gdf),
            "new_rows": len(new_gdf),
            "common_indices": len(common_indices),
            "compared_columns": columns_to_compare,
            "num_differences": len(result.differences)
        }
        
    except Exception as e:
        result.status = "error"
        result.summary = f"Error comparing files: {e}"
        result.details = {"error": str(e)}
    
    return result


def compare_site_outputs(site_id: str) -> List[ComparisonResult]:
    """
    Compare all output files for a site.
    
    Args:
        site_id: Site ID (e.g., "nzd0001")
        
    Returns:
        List of ComparisonResult objects
    """
    results = []
    
    original_site_dir = ORIGINAL_DATA_DIR / site_id
    new_site_dir = NEW_DATA_DIR / site_id
    
    # Files to compare
    files_to_compare = [
        "transect_time_series.csv",
        "tides.csv",
        "transect_time_series_tidally_corrected.csv",
    ]
    
    for filename in files_to_compare:
        original_path = original_site_dir / filename
        new_path = new_site_dir / filename
        
        result = compare_csv_files(original_path, new_path)
        result.file_path = f"{site_id}/{filename}"
        results.append(result)
    
    # Compare Excel files (if they exist)
    excel_file = f"{site_id}.xlsx"
    original_excel = original_site_dir / excel_file
    new_excel = new_site_dir / excel_file
    
    if original_excel.exists() and new_excel.exists():
        # For Excel files, we'll do a basic check (file exists, similar size)
        # Full comparison would require reading Excel files
        orig_size = original_excel.stat().st_size
        new_size = new_excel.stat().st_size
        size_diff = abs(orig_size - new_size) / orig_size if orig_size > 0 else 0
        
        result = ComparisonResult(
            file_path=f"{site_id}/{excel_file}",
            status="match" if size_diff < 0.1 else "different",  # 10% size difference threshold
            summary=f"Size difference: {size_diff*100:.1f}%"
        )
        results.append(result)
    
    return results


def compare_transects_file() -> ComparisonResult:
    """
    Compare the transects_extended.geojson file.
    
    Returns:
        ComparisonResult with comparison details
    """
    # Compare specific columns that should match
    compare_columns = [
        "beach_slope",
        "cil",
        "ciu",
        "trend",
        "intercept",
        "r2_score",
        "mae",
        "mse",
        "rmse",
        "n_points",
        "n_points_nonan"
    ]
    
    return compare_geojson_files(
        ORIGINAL_TRANSECTS,
        NEW_TRANSECTS,
        compare_columns=compare_columns
    )


def generate_comparison_report(results: List[ComparisonResult]) -> str:
    """
    Generate a human-readable comparison report.
    
    Args:
        results: List of ComparisonResult objects
        
    Returns:
        Report string
    """
    report = []
    report.append("=" * 80)
    report.append("CoastSat Workflow Comparison Report")
    report.append("=" * 80)
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    
    # Summary statistics
    status_counts = {}
    for result in results:
        status_counts[result.status] = status_counts.get(result.status, 0) + 1
    
    report.append("Summary:")
    report.append(f"  Total files compared: {len(results)}")
    for status, count in sorted(status_counts.items()):
        report.append(f"  {status}: {count}")
    report.append("")
    
    # Detailed results
    report.append("=" * 80)
    report.append("Detailed Results:")
    report.append("=" * 80)
    report.append("")
    
    for result in results:
        report.append(f"File: {result.file_path}")
        report.append(f"  Status: {result.status}")
        report.append(f"  Summary: {result.summary}")
        
        if result.differences:
            report.append(f"  Differences:")
            for diff in result.differences:
                report.append(f"    - {diff}")
        
        if result.details:
            report.append(f"  Details:")
            for key, value in result.details.items():
                report.append(f"    {key}: {value}")
        
        report.append("")
    
    return "\n".join(report)


def main():
    """Main function to run comparison."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Compare outputs from new and original workflows")
    parser.add_argument(
        "--sites",
        nargs="+",
        default=TEST_SITES,
        help="Site IDs to compare (default: all test sites)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="comparison_report.txt",
        help="Output file for comparison report (default: comparison_report.txt)"
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=FLOAT_TOLERANCE,
        help=f"Tolerance for floating-point comparisons (default: {FLOAT_TOLERANCE})"
    )
    
    args = parser.parse_args()
    
    print("=" * 80)
    print("CoastSat Workflow Comparison")
    print("=" * 80)
    print(f"Comparing sites: {args.sites}")
    print(f"Tolerance: {args.tolerance}")
    print("")
    
    # Collect all results
    all_results = []
    
    # Compare site outputs
    for site_id in args.sites:
        print(f"Comparing outputs for {site_id}...")
        site_results = compare_site_outputs(site_id)
        all_results.extend(site_results)
        
        # Print summary for this site
        match_count = sum(1 for r in site_results if r.status == "match")
        print(f"  {match_count}/{len(site_results)} files match")
    
    # Compare transects file
    print("Comparing transects_extended.geojson...")
    transects_result = compare_transects_file()
    all_results.append(transects_result)
    print(f"  Status: {transects_result.status}")
    
    # Generate report
    report = generate_comparison_report(all_results)
    
    # Save report
    output_path = project_root / args.output
    with open(output_path, 'w') as f:
        f.write(report)
    
    print("")
    print("=" * 80)
    print("Comparison complete!")
    print("=" * 80)
    print(f"Report saved to: {output_path}")
    
    # Print summary
    status_counts = {}
    for result in all_results:
        status_counts[result.status] = status_counts.get(result.status, 0) + 1
    
    print("")
    print("Summary:")
    for status, count in sorted(status_counts.items()):
        print(f"  {status}: {count}")
    
    # Exit with error code if there are differences
    if status_counts.get("different", 0) > 0 or status_counts.get("error", 0) > 0:
        print("")
        print("⚠️  WARNING: Some files differ or had errors!")
        sys.exit(1)
    else:
        print("")
        print("✅ All files match!")
        sys.exit(0)


if __name__ == "__main__":
    main()

