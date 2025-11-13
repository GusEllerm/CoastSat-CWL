# Simple CWL Test Tool

This directory contains a simple CWL test tool for verifying Docker image and CWL environment setup.

## Test Tool

- **`test_simple.cwl`** - Simple CWL tool that imports CoastSat modules to verify the Docker environment is working correctly

## Purpose

This test tool is used to:
- Verify Docker image `coastsat-cwl:latest` is working
- Test that CoastSat modules can be imported in the container
- Validate basic CWL execution in Docker

## Running the Test

From the project root:

```bash
cd CoastSat-CWL
cwltool --outdir test/simple/outputs test/simple/test_simple.cwl
```

Or from the test directory:

```bash
cd test/simple
cwltool --outdir outputs test_simple.cwl
```

## Expected Output

The tool should print:
```
CoastSat modules imported successfully
Test passed!
```

## Directory Structure

```
simple/
├── README.md              # This file
├── test_simple.cwl        # Simple CWL test tool
├── inputs/                # Test inputs (if needed)
├── expected/              # Expected outputs (if needed)
└── outputs/               # Generated outputs (gitignored)
```

## Integration

This test is automatically run by `test_harness.sh` as part of the comprehensive test suite.

