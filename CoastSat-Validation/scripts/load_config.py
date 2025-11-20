#!/usr/bin/env python3
"""
Load and validate configuration for CoastSat validation framework
"""

import json
import os
from pathlib import Path

def load_config(config_path=None):
    """Load configuration from JSON file"""
    if config_path is None:
        # Default to config.json in validation directory
        script_dir = Path(__file__).parent.parent
        config_path = script_dir / "config.json"
    
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # Validate required fields
    required_fields = ['validation_sites']
    for field in required_fields:
        if field not in config:
            raise ValueError(f"Missing required configuration field: {field}")
    
    return config

def get_validation_sites(config=None):
    """Get list of validation sites from config"""
    if config is None:
        config = load_config()
    return config.get('validation_sites', [])

def get_baseline_commit(config=None):
    """Get baseline commit from config"""
    if config is None:
        config = load_config()
    return config.get('baseline_commit', 'HEAD~1')

def get_max_date_strategy(config=None):
    """Get max date strategy from config"""
    if config is None:
        config = load_config()
    return config.get('max_date', {}).get('strategy', 'auto')

def get_notebook_timeout(config=None):
    """Get notebook timeout from config"""
    if config is None:
        config = load_config()
    return config.get('workflow', {}).get('notebook_timeout_seconds', 1800)

if __name__ == "__main__":
    # Test loading config
    try:
        config = load_config()
        print("Configuration loaded successfully:")
        print(f"  Validation sites: {config.get('validation_sites')}")
        print(f"  Baseline commit: {config.get('baseline_commit')}")
        print(f"  Max date strategy: {get_max_date_strategy(config)}")
    except Exception as e:
        print(f"Error loading config: {e}")

