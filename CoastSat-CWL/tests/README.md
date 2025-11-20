# Test Input Files

This directory contains test input files organized by tool and workflow.

## Directory Structure

```
tests/
├── workflow/
│   ├── prepare_workflow_sites/
│   │   ├── input_small.yml      # Test with small_polygons.geojson (24 sites)
│   │   └── input_full.yml       # Test with full polygons.geojson (5707 sites)
│   └── example_parent_workflow/
│       └── input_small.yml      # Test parallel processing with small dataset
└── tools/
    └── group_by_prefix/
        ├── input_full.yml       # Test tool with full dataset
        └── input_with_script.yml # Test tool with explicit script path
```

## Usage

### Running Workflow Tests

From the project root:

```bash
# Test prepare_workflow_sites with small dataset
cwltool --no-container --basedir . \
  CoastSat-CWL/workflow/prepare_workflow_sites.cwl \
  CoastSat-CWL/tests/workflow/prepare_workflow_sites/input_small.yml

# Test example_parent_workflow with small dataset
cwltool --no-container --basedir . \
  CoastSat-CWL/workflow/example_parent_workflow.cwl \
  CoastSat-CWL/tests/workflow/example_parent_workflow/input_small.yml
```

### Running Tool Tests

```bash
# Test group_by_prefix tool
cwltool --no-container --basedir . \
  CoastSat-CWL/tools/group_by_prefix/group_by_prefix.cwl \
  CoastSat-CWL/tests/tools/group_by_prefix/input_full.yml
```

## Path Conventions

All paths in test input files are relative to the test file's location:
- `../../../data/input/` - Points to `CoastSat-CWL/data/input/`

This allows tests to be run from any directory as long as `--basedir` is set correctly.

## Script Handling

Script files (e.g., Python scripts) are **not** specified in test input files. Instead:
- Scripts are defined with defaults in their respective tool definitions
- Tools automatically use scripts from the same directory as the CWL file
- In Docker containers, scripts are available locally and don't need to be passed as inputs
- This keeps test files simple and makes tools more portable

