#!/usr/bin/env python3
"""
Patch notebooks to remove problematic IPython magic before execution
This allows us to use jupyter nbconvert like the original workflow
"""

import json
import sys
import os

def patch_notebook(notebook_path):
    """Patch a notebook to remove autotime magic"""
    with open(notebook_path, 'r') as f:
        nb = json.load(f)
    
    patched = False
    for i, cell in enumerate(nb['cells']):
        if cell['cell_type'] == 'code':
            source = cell['source']
            new_source = source
            
            # Remove autotime magic
            if '%reload_ext autotime' in source:
                new_source = new_source.replace(
                    "%reload_ext autotime",
                    "# %reload_ext autotime  # Disabled for non-interactive execution"
                )
                patched = True
            
            if 'get_ipython().run_line_magic' in source and 'autotime' in source:
                new_source = new_source.replace(
                    "get_ipython().run_line_magic('reload_ext', 'autotime')",
                    "# get_ipython().run_line_magic('reload_ext', 'autotime')  # Disabled for non-interactive execution"
                )
                patched = True
            
            if new_source != source:
                cell['source'] = new_source
                print(f"  Patched cell {i} in {os.path.basename(notebook_path)}")
    
    if patched:
        with open(notebook_path, 'w') as f:
            json.dump(nb, f)
        return True
    return False

if __name__ == "__main__":
    notebooks = [
        "tidal_correction.ipynb",
        "slope_estimation.ipynb",
        "linear_models.ipynb"
    ]
    
    patched_any = False
    for nb in notebooks:
        if os.path.exists(nb):
            if patch_notebook(nb):
                patched_any = True
        else:
            print(f"Warning: {nb} not found")
    
    if patched_any:
        print("Notebooks patched successfully")
    else:
        print("No patches needed")

