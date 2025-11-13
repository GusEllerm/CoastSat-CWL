# CoastSat to CWL Refactoring Plan

This document outlines the conversion plan from the `CoastSat-minimal/` Python script implementation to a Common Workflow Language (CWL) workflow implementation with Docker-based reproducibility.

## Overview

The goal is to translate the 7-step CoastSat processing pipeline into a CWL workflow that:
- Maintains functional equivalence with the minimal implementation
- Enables automated provenance tracking via CWLProv
- Provides reproducible execution through Docker containerization
- Supports parallel processing where applicable
- Preserves data lineage and metadata

## Current Workflow Structure

The minimal CoastSat workflow consists of the following steps:

1. **Batch Process NZ Sites** (`batch_process_NZ.py`)
   - Download Landsat imagery from Google Earth Engine
   - Extract shorelines
   - Compute transect intersections
   - Output: `data/{site}/transect_time_series.csv`

2. **Batch Process SAR Sites** (`batch_process_sar.py`)
   - Same as step 1 for SAR sites (when required)

3. **Fetch Tides** (`tidal_correction.py --mode fetch`)
   - Call NIWA Tide API for each site
   - Output: `data/{site}/tides.csv`

4. **Slope Estimation** (`slope_estimation.py`)
   - Estimate beach slopes per transect using spectral analysis
   - Update: `inputs/transects_extended.geojson`

5. **Apply Tidal Correction** (`tidal_correction.py --mode apply`)
   - Apply tidal corrections to transect time series
   - Output: `data/{site}/transect_time_series_tidally_corrected.csv`

6. **Linear Models** (`linear_models.py`)
   - Compute linear shoreline change metrics (trend, MAE, RMSE)
   - Update: `inputs/transects_extended.geojson`

7. **Generate Reports** (`make_xlsx.py`)
   - Collate outputs into Excel files
   - Output: `data/{site}/{site}.xlsx`

## Docker Environment Strategy

### Base Docker Image

Create a single base Docker image that contains:
- Python 3.11+ with all dependencies from `requirements.txt`
- CoastSat package (`coastsat_package`)
- GDAL with Python bindings
- All required system libraries

**File Structure:**
```
CoastSat-CWL/
├── docker/
│   ├── Dockerfile              # Base image with all dependencies
│   ├── .dockerignore
│   └── requirements.txt        # Copy from CoastSat-minimal
```

### Containerization Principles

1. **Single Base Image**: All CWL tools use the same base image to ensure consistency
2. **Dependency Isolation**: All Python dependencies bundled in container
3. **Credential Management**: Use CWL input parameters or secrets management for API keys
4. **Data Mounting**: Input/output data mounted as volumes, preserving provenance

### Docker Image Development Plan

**Phase 1: Base Image Creation** ✅ COMPLETE
- [x] Create `docker/Dockerfile` based on Python 3.11-slim
- [x] Install system dependencies (GDAL, proj, geos, spatialindex, etc.)
  - Includes Qt libraries for PyQt5 (optimized build)
- [x] Copy and install Python requirements
  - Separate GDAL Python bindings installation to match system version
  - Optimized PyQt5 installation (split dependencies, memory-efficient)
- [x] Test image with basic CoastSat import
  - Verified: `from coastsat import SDS_download, SDS_tools` ✓
  - All geospatial libraries functional (GDAL, GeoPandas)
- [x] Tag and publish base image (or document local build process)
  - Image tagged: `coastsat-cwl:latest`
  - Local build process documented in `docker/README.md`
  - Build script: `docker/build.sh`
  - Test script: `docker/test.sh`

**Phase 2: Image Optimization** (Future)
- [ ] Multi-stage build for size optimization
- [ ] Layer caching optimization
- [ ] Health checks and metadata labels
- [ ] Documentation for image usage (✅ Basic docs complete)

## CWL Tool Definitions

### Tool Structure

Each Python script becomes a CWL CommandLineTool with:
- Input parameters (files, environment variables)
- Output declarations
- Base command pointing to Python script
- Docker requirement referencing base image

**Naming Convention:**
- Tools: `tools/batch-process-nz.cwl`, `tools/tidal-correction.cwl`, etc.
- Workflows: `workflows/coastsat-workflow.cwl`

### Tool Mapping

| Script | CWL Tool | Key Inputs | Key Outputs |
|--------|----------|------------|-------------|
| `batch_process_NZ.py` | `batch-process-nz.cwl` | `polygons.geojson`, `shorelines.geojson`, `transects_extended.geojson`, site IDs | `transect_time_series.csv` per site |
| `batch_process_sar.py` | `batch-process-sar.cwl` | Same as above | `transect_time_series.csv` per site |
| `tidal_correction.py --mode fetch` | `tidal-correction-fetch.cwl` | Site coordinates, date range | `tides.csv` per site |
| `slope_estimation.py` | `slope-estimation.cwl` | `transect_time_series.csv`, `tides.csv`, `transects_extended.geojson` | Updated `transects_extended.geojson` |
| `tidal_correction.py --mode apply` | `tidal-correction-apply.cwl` | `transect_time_series.csv`, `tides.csv`, `transects_extended.geojson` | `transect_time_series_tidally_corrected.csv` |
| `linear_models.py` | `linear-models.cwl` | `transect_time_series_tidally_corrected.csv`, `transects_extended.geojson` | Updated `transects_extended.geojson` |
| `make_xlsx.py` | `make-xlsx.cwl` | All CSV files per site, `transects_extended.geojson` | `{site}.xlsx` per site |

## Step-by-Step Conversion Plan

### Phase 1: Infrastructure Setup ✅ COMPLETE

**Goal**: Establish Docker and CWL development environment

1. **Docker Environment** ✅
   - [x] Create `docker/Dockerfile` with base image
     - Python 3.11-slim base
     - GDAL, proj, geos, spatialindex system dependencies
     - Python dependencies from requirements.txt
     - GDAL Python bindings matching system version
     - Optimized PyQt5/Jupyter handling (memory optimizations)
   - [x] Create `docker/.dockerignore`
     - Excludes credentials, test files, build artifacts
   - [x] Build and test base image
     - Image built successfully: `coastsat-cwl:latest`
     - CoastSat imports verified in Docker container
     - All dependencies tested and working
   - [x] Document image build process
     - `docker/README.md` with build instructions
     - `docker/MEMORY_ISSUES.md` troubleshooting guide
     - Build and test scripts (`build.sh`, `test.sh`)

2. **CWL Project Structure** ✅
   - [x] Create `tools/` directory for CWL tool definitions
   - [x] Create `workflows/` directory for workflow definitions
   - [x] Create `schemas/` directory for custom schemas (if needed)
   - [x] Create `test/` directory for test data and validation
     - Organized structure: `inputs/`, `expected/`, `outputs/cwl/`, `outputs/temp/`
     - Gitignore configuration for test outputs
     - Cleanup scripts for output management

3. **Development Tools** ✅
   - [x] Install CWL runner (cwltool)
     - Version: 3.1.20251031082601
     - Verified with simple CWL test (`test/test_simple.cwl`)
   - [x] Install CWLProv for provenance tracking
     - Version: 0.1.1
     - Ready for provenance generation once workflows are created
   - [x] Set up validation scripts
     - `test/validate_cwl.py` - Validates CWL files
     - `test/compare_outputs.py` - Compares CWL vs minimal outputs
     - `test/run_cwl_workflow.py` - Executes CWL workflows
     - `test/test_harness.sh` - Comprehensive test suite
     - `test/cleanup.sh` - Test output cleanup
   - [x] Create test harness for comparing outputs
     - Test harness validates environment, tools, and structure
     - Organized output directories prevent test directory pollution
     - Automated cleanup of temporary files

### Phase 2: Individual Tool Conversion

**Goal**: Convert each Python script to a CWL CommandLineTool

**2.1 Batch Processing Tools** (Parallel implementation)

- [ ] **Tool: `batch-process-nz.cwl`**
  - Inputs: GeoJSON files, site IDs list, date range, credentials
  - Outputs: `transect_time_series.csv` files (one per site)
  - Special considerations:
    - Site-level parallelization (each site can run independently)
    - Google Earth Engine authentication (service account credentials)
    - Large output data handling

- [ ] **Tool: `batch-process-sar.cwl`**
  - Similar structure to NZ tool
  - Same considerations

**2.2 Tidal Correction Tools**

- [ ] **Tool: `tidal-correction-fetch.cwl`**
  - Inputs: Site coordinates, date range, NIWA API key
  - Outputs: `tides.csv` per site
  - Special considerations:
    - API rate limiting handling
    - Error handling for API failures
    - Per-site parallelization possible

- [ ] **Tool: `tidal-correction-apply.cwl`**
  - Inputs: `transect_time_series.csv`, `tides.csv`, `transects_extended.geojson`
  - Outputs: `transect_time_series_tidally_corrected.csv`
  - Special considerations:
    - Requires slopes from previous step
    - Per-site processing

**2.3 Analysis Tools**

- [ ] **Tool: `slope-estimation.cwl`**
  - Inputs: `transect_time_series.csv`, `tides.csv`, `transects_extended.geojson`
  - Outputs: Updated `transects_extended.geojson`
  - Special considerations:
    - In-place file update (may need to copy then update)
    - Per-site processing with aggregation

- [ ] **Tool: `linear-models.cwl`**
  - Inputs: `transect_time_series_tidally_corrected.csv`, `transects_extended.geojson`
  - Outputs: Updated `transects_extended.geojson`
  - Special considerations:
    - Cumulative updates to transects file
    - Per-site processing

**2.4 Reporting Tool**

- [ ] **Tool: `make-xlsx.cwl`**
  - Inputs: All CSV files per site, `transects_extended.geojson`
  - Outputs: `{site}.xlsx` per site
  - Special considerations:
    - Per-site processing
    - Aggregation of multiple inputs

### Phase 3: Workflow Definition

**Goal**: Create main workflow that orchestrates all tools

- [ ] **Workflow: `coastsat-workflow.cwl`**
  - Steps in sequence:
    1. `batch_process_nz` (with scatter for sites)
    2. `batch_process_sar` (optional, with scatter for sites)
    3. `tidal_correction_fetch` (with scatter for sites)
    4. `slope_estimation` (with scatter for sites)
    5. `tidal_correction_apply` (with scatter for sites)
    6. `linear_models` (with scatter for sites)
    7. `make_xlsx` (with scatter for sites)
  
  - **Scatter Strategy**: 
    - Sites can be processed in parallel where independent
    - Use `scatter: [sites]` for parallelization
    - Sequential steps where dependencies exist (e.g., slope estimation before tidal correction apply)

- [ ] **Workflow Inputs:**
  - GeoJSON input files
  - Site IDs list
  - Date range parameters
  - Credentials (via secrets or environment variables)

- [ ] **Workflow Outputs:**
  - All generated CSV files
  - Updated `transects_extended.geojson`
  - Excel reports per site

### Phase 4: Testing and Validation

**Goal**: Ensure functional equivalence with minimal implementation

1. **Unit Testing**
   - [ ] Test each CWL tool independently with sample data
   - [ ] Validate input/output schemas
   - [ ] Compare outputs with Python script outputs

2. **Integration Testing**
   - [ ] Run full workflow with test data
   - [ ] Compare outputs with `CoastSat-minimal/` outputs
   - [ ] Validate against original CoastSat data (`CoastSat/data/nzd0001/`)

3. **Provenance Testing**
   - [ ] Generate provenance records with CWLProv
   - [ ] Validate PROV structure
   - [ ] Verify all inputs/outputs are captured
   - [ ] Test provenance record completeness

4. **Performance Testing**
   - [ ] Benchmark execution time vs. minimal implementation
   - [ ] Test parallelization effectiveness
   - [ ] Measure resource usage (CPU, memory, disk)

### Phase 5: Documentation and Deployment

**Goal**: Document usage and deployment process

- [ ] **Usage Documentation**
  - [ ] CWL workflow invocation guide
  - [ ] Input parameter documentation
  - [ ] Example workflow runs
  - [ ] Troubleshooting guide

- [ ] **Provenance Documentation**
  - [ ] How to generate provenance records
  - [ ] Provenance record structure
  - [ ] How provenance feeds into Component E2.2

- [ ] **Deployment Guide**
  - [ ] Docker image building and publishing
  - [ ] CWL runner configuration
  - [ ] Environment setup
  - [ ] Credential management best practices

## Key Design Decisions

### 1. Single vs. Multiple Docker Images

**Decision**: Single base image for all tools
**Rationale**: 
- Ensures consistent environment across all steps
- Easier maintenance and updates
- Reduces complexity in provenance tracking

### 2. Site-Level Parallelization

**Decision**: Parallelize at site level where possible
**Rationale**:
- Sites are independent processing units
- Significant performance gains for multiple sites
- Natural fit for CWL scatter feature

### 3. File Update Handling

**Decision**: Create new files rather than in-place updates where possible
**Rationale**:
- Better provenance tracking (each step produces distinct outputs)
- Easier to trace data lineage
- Aligns with immutable data principles

**Exception**: `transects_extended.geojson` may need special handling (aggregate updates)

### 4. Credential Management

**Decision**: Use CWL environment variables with secrets management
**Rationale**:
- Avoids hardcoding credentials in CWL files
- Supports multiple deployment scenarios
- Enables secure credential injection

**Implementation**:
- Use `EnvVarRequirement` or `secrets` in workflow
- Document credential requirements
- Provide example `.env` structure

### 5. Large Data Handling

**Decision**: Use CWL file staging with appropriate caching
**Rationale**:
- Satellite imagery and outputs can be large
- Need efficient data transfer between steps
- CWL runners handle staging automatically

## File Structure

```
CoastSat-CWL/
├── docker/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── requirements.txt
│   └── README.md
├── tools/
│   ├── batch-process-nz.cwl
│   ├── batch-process-sar.cwl
│   ├── tidal-correction-fetch.cwl
│   ├── tidal-correction-apply.cwl
│   ├── slope-estimation.cwl
│   ├── linear-models.cwl
│   └── make-xlsx.cwl
├── workflows/
│   ├── coastsat-workflow.cwl
│   ├── coastsat-workflow-test.cwl  # Test version with limited data
│   └── README.md
├── schemas/
│   └── (custom schemas if needed)
├── test/
│   ├── inputs/          # Test input data
│   ├── expected/        # Expected outputs for validation
│   ├── outputs/         # Test outputs (gitignored)
│   │   ├── cwl/        # CWL workflow outputs
│   │   └── temp/       # Temporary test outputs
│   ├── validate_cwl.py # CWL validation script
│   ├── compare_outputs.py # Output comparison script
│   ├── run_cwl_workflow.py # Workflow execution script
│   ├── test_harness.sh # Comprehensive test suite
│   ├── cleanup.sh      # Test output cleanup
│   ├── test_simple.cwl # Simple CWL test tool
│   └── README.md       # Test documentation
├── examples/
│   ├── workflow-input.yml
│   └── README.md
└── REFACTOR_PLAN.md (this file)
```

## Dependencies and Requirements

### Software Dependencies
- Docker (for containerization)
- CWL runner (cwltool or equivalent)
- CWLProv (for provenance tracking)
- Python 3.11+ (in container)
- All Python dependencies from `CoastSat-minimal/requirements.txt`

### External Services
- Google Earth Engine (for satellite imagery)
- NIWA Tide API (for tide data)

### Input Data Requirements
- GeoJSON input files (`polygons.geojson`, `shorelines.geojson`, `transects_extended.geojson`)
- Site IDs list
- Date range parameters
- Credentials (GEE service account, NIWA API key)

## Validation Strategy

### Functional Validation
1. Run CWL workflow with test data from `CoastSat-minimal/`
2. Compare outputs file-by-file with minimal implementation
3. Validate CSV structure, GeoJSON updates, Excel format
4. Test with original CoastSat data (`CoastSat/data/nzd0001/`)

### Provenance Validation
1. Generate provenance records with CWLProv
2. Verify all workflow steps are captured
3. Verify all inputs/outputs are linked
4. Validate PROV structure against W3C specification
5. Ensure Component E2.2 requirements are met

### Performance Validation
1. Benchmark execution time
2. Measure resource usage
3. Compare with minimal implementation
4. Document any performance differences

## Timeline and Milestones

### Milestone 1: Infrastructure (Week 1-2) ✅ COMPLETE
- ✅ Docker base image built and tested
  - Image: `coastsat-cwl:latest`
  - All dependencies verified
  - Memory optimizations documented
- ✅ CWL project structure established
  - All directories created
  - Test infrastructure organized
  - Gitignore configured
- ✅ Development environment ready
  - cwltool installed and tested
  - cwlprov installed
  - Validation scripts created
  - Test harness functional

### Milestone 2: Core Tools (Week 3-5)
- Batch processing tools converted and tested
- Tidal correction tools converted and tested

### Milestone 3: Analysis Tools (Week 6-7)
- Slope estimation tool converted
- Linear models tool converted
- Reporting tool converted

### Milestone 4: Integration (Week 8-9)
- Full workflow assembled
- Integration testing complete
- Functional validation passed

### Milestone 5: Provenance and Documentation (Week 10)
- Provenance tracking verified
- Documentation complete
- Ready for deployment

## Risks and Mitigation

### Risk 1: Google Earth Engine Authentication in Docker
**Mitigation**: 
- Test credential mounting strategies
- Document service account setup
- Provide example credential configuration

### Risk 2: Large Data Transfer Overhead
**Mitigation**:
- Optimize data staging
- Use appropriate caching strategies
- Consider data streaming where possible

### Risk 3: Functional Differences
**Mitigation**:
- Comprehensive validation suite
- Side-by-side output comparison
- Incremental validation at each step

### Risk 4: Performance Degradation
**Mitigation**:
- Benchmark early and often
- Optimize Docker image size
- Tune CWL runner configuration

## Success Criteria

1. ⏳ All tools successfully converted to CWL (Phase 2 - Pending)
2. ⏳ Full workflow executes end-to-end (Phase 3 - Pending)
3. ⏳ Outputs match minimal implementation (within tolerance) (Phase 4 - Pending)
4. ⏳ Provenance records generated successfully (Phase 4 - Pending)
5. ⏳ Component E2.2 requirements met (Phase 4 - Pending)
6. ⏳ Documentation complete and clear (Phase 5 - Pending)
7. ✅ Docker environment reproducible **COMPLETE**

## Next Steps

1. ✅ Review and approve this plan
2. ✅ Set up development environment
3. ✅ Begin Phase 1: Infrastructure Setup **COMPLETE**
4. ✅ Create initial Docker base image **COMPLETE**
5. **Next**: Begin Phase 2: Individual Tool Conversion
   - Start with simplest tool first (e.g., `make-xlsx.cwl`)
   - Convert one tool at a time
   - Test and validate each tool before moving to next

## References

- [Common Workflow Language Specification](https://www.commonwl.org/)
- [CWLProv Documentation](https://github.com/common-workflow-language/cwlprov)
- [CWL Best Practices](https://www.commonwl.org/user_guide/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- Original CoastSat: https://github.com/UoA-eResearch/CoastSat

