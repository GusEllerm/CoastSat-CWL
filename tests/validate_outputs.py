#!/usr/bin/env python3
"""
Validation tool for CoastSat minimal workflow outputs.
This script checks that all expected output files exist and validates their contents.
"""

import os
import sys
from pathlib import Path
import pandas as pd
import json

# Representative sites
REPRESENTATIVE_NZ_SITES = ['nzd0001', 'nzd0002', 'nzd0003']
REPRESENTATIVE_SAR_SITES = ['sar0001']
REPRESENTATIVE_SITES = REPRESENTATIVE_NZ_SITES + REPRESENTATIVE_SAR_SITES

# Get project root directory
project_root = Path(__file__).parent.parent
os.chdir(project_root)

def validate_site_outputs(site_id):
    """
    Validate outputs for a single site.
    
    Args:
        site_id: Site ID to validate
        
    Returns:
        dict: Validation results
    """
    results = {
        'site_id': site_id,
        'valid': True,
        'errors': [],
        'warnings': [],
        'files_checked': []
    }
    
    site_dir = Path('data') / site_id
    
    # Check if site directory exists
    if not site_dir.exists():
        results['valid'] = False
        results['errors'].append(f"Site directory does not exist: {site_dir}")
        return results
    
    # Expected output files
    expected_files = [
        'transect_time_series.csv',
        'transect_time_series_tidally_corrected.csv',
        'tides.csv',
        f'{site_id}.xlsx'
    ]
    
    # Check each expected file
    for filename in expected_files:
        filepath = site_dir / filename
        results['files_checked'].append(str(filepath))
        
        if not filepath.exists():
            results['valid'] = False
            results['errors'].append(f"Missing file: {filepath}")
            continue
        
        # Validate CSV files
        if filename.endswith('.csv'):
            try:
                df = pd.read_csv(filepath)
                if df.empty:
                    results['warnings'].append(f"File is empty: {filepath}")
                else:
                    # Check for required columns
                    if filename == 'transect_time_series.csv' or filename == 'transect_time_series_tidally_corrected.csv':
                        if 'dates' not in df.columns:
                            results['errors'].append(f"Missing 'dates' column in {filepath}")
                            results['valid'] = False
                    elif filename == 'tides.csv':
                        if 'date' not in df.columns and 'dates' not in df.columns:
                            results['warnings'].append(f"Expected 'date' or 'dates' column in {filepath}")
            except Exception as e:
                results['valid'] = False
                results['errors'].append(f"Error reading {filepath}: {e}")
        
        # Validate Excel file
        elif filename.endswith('.xlsx'):
            try:
                # Just check if file can be read
                pd.read_excel(filepath, sheet_name=None)
            except Exception as e:
                results['warnings'].append(f"Could not read Excel file {filepath}: {e}")
    
    return results

def validate_workflow_outputs():
    """
    Validate all workflow outputs.
    
    Returns:
        dict: Validation results for all sites
    """
    all_results = {
        'sites': {},
        'overall_valid': True,
        'total_errors': 0,
        'total_warnings': 0
    }
    
    print("=" * 60)
    print("CoastSat Minimal Workflow - Output Validation")
    print("=" * 60)
    print()
    
    # Validate each site
    for site_id in REPRESENTATIVE_SITES:
        print(f"Validating site: {site_id}")
        results = validate_site_outputs(site_id)
        all_results['sites'][site_id] = results
        
        if not results['valid']:
            all_results['overall_valid'] = False
            all_results['total_errors'] += len(results['errors'])
        
        all_results['total_warnings'] += len(results['warnings'])
        
        # Print results
        if results['valid']:
            print(f"  ✓ Site {site_id} is valid")
        else:
            print(f"  ✗ Site {site_id} has errors:")
            for error in results['errors']:
                print(f"    - {error}")
        
        if results['warnings']:
            print(f"  ⚠ Site {site_id} has warnings:")
            for warning in results['warnings']:
                print(f"    - {warning}")
        
        print(f"  Files checked: {len(results['files_checked'])}")
        print()
    
    # Print summary
    print("=" * 60)
    print("Validation Summary")
    print("=" * 60)
    print(f"Overall valid: {'✓ Yes' if all_results['overall_valid'] else '✗ No'}")
    print(f"Total errors: {all_results['total_errors']}")
    print(f"Total warnings: {all_results['total_warnings']}")
    print()
    
    return all_results

def main():
    """Main function."""
    results = validate_workflow_outputs()
    
    # Exit with error code if validation failed
    if not results['overall_valid']:
        sys.exit(1)
    else:
        print("All outputs validated successfully!")
        sys.exit(0)

if __name__ == '__main__':
    main()

