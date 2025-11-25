#!/bin/bash

# CoastSat-CWL Workflow Runner
# Simplifies running the CoastSat-CWL workflow in Docker

set -e  # Exit on error

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DATA_DIR="${SCRIPT_DIR}/CoastSat-CWL/data"
DEFAULT_WORKFLOW="update_coastsat.cwl"
DEFAULT_DOCKER_IMAGE="gusellerm/coastsat-cwl:latest"
DEFAULT_INPUT_FILE="input_small.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run the CoastSat-CWL workflow in a Docker container.

OPTIONS:
    -d, --data-dir DIR       Data directory to mount (default: ${DEFAULT_DATA_DIR})
    -c, --config-dir DIR     Directory containing input YAML file (required)
    -o, --output-dir DIR     Output directory (default: <config-dir>/out)
    -i, --input-file FILE    Input YAML file name (default: ${DEFAULT_INPUT_FILE})
    -w, --workflow FILE      Workflow CWL file (default: ${DEFAULT_WORKFLOW})
    -m, --docker-image IMG   Docker image name (default: ${DEFAULT_DOCKER_IMAGE})
    -p, --no-provenance      Disable provenance tracking (enables --parallel flag)
    -k, --keep-container     Keep container running after workflow (for inspection)
    -h, --help               Show this help message

EXAMPLES:
    # Basic usage with defaults (provenance enabled)
    $0 -c CoastSat-CWL/tests/workflow/update_coastsat

    # Disable provenance (enables --parallel flag)
    $0 -c CoastSat-CWL/tests/workflow/update_coastsat -p

    # Keep container for inspection after workflow completes
    $0 -c CoastSat-CWL/tests/workflow/update_coastsat -k

    # Specify all parameters
    $0 -d /path/to/data -c /path/to/config -o /path/to/output -i input.yml

    # Use different workflow
    $0 -c CoastSat-CWL/tests/workflow/prepare_workflow_sites -w prepare_workflow_sites.cwl

EOF
}

# Parse command line arguments
DATA_DIR=""
CONFIG_DIR=""
OUTPUT_DIR=""
INPUT_FILE="${DEFAULT_INPUT_FILE}"
WORKFLOW="${DEFAULT_WORKFLOW}"
DOCKER_IMAGE="${DEFAULT_DOCKER_IMAGE}"
ENABLE_PROVENANCE=true
KEEP_CONTAINER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -c|--config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -i|--input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        -w|--workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        -m|--docker-image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        -p|--no-provenance)
            ENABLE_PROVENANCE=false
            shift
            ;;
        -k|--keep-container)
            KEEP_CONTAINER=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$CONFIG_DIR" ]]; then
    echo -e "${RED}Error: --config-dir is required${NC}" >&2
    usage
    exit 1
fi

# Convert relative paths to absolute paths
CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd)"
if [[ -n "$DATA_DIR" ]]; then
    DATA_DIR="$(cd "$DATA_DIR" && pwd)"
else
    DATA_DIR="${DEFAULT_DATA_DIR}"
    if [[ ! -d "$DATA_DIR" ]]; then
        echo -e "${YELLOW}Warning: Default data directory does not exist: ${DATA_DIR}${NC}" >&2
    fi
fi

# Set default output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${CONFIG_DIR}/out"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Validate input file exists
INPUT_FILE_PATH="${CONFIG_DIR}/${INPUT_FILE}"
if [[ ! -f "$INPUT_FILE_PATH" ]]; then
    echo -e "${RED}Error: Input file not found: ${INPUT_FILE_PATH}${NC}" >&2
    exit 1
fi

# Determine workflow path inside container
# If workflow is just a filename, assume it's in /workflow/workflow/
if [[ "$WORKFLOW" == *.cwl ]] && [[ "$WORKFLOW" != /* ]]; then
    WORKFLOW_PATH="/workflow/workflow/${WORKFLOW}"
else
    WORKFLOW_PATH="$WORKFLOW"
fi

# Print configuration
echo -e "${GREEN}CoastSat-CWL Workflow Runner${NC}"
echo "================================"
echo "Data directory:    ${DATA_DIR}"
echo "Config directory:  ${CONFIG_DIR}"
echo "Output directory:  ${OUTPUT_DIR}"
echo "Input file:        ${INPUT_FILE}"
echo "Workflow:          ${WORKFLOW}"
echo "Docker image:      ${DOCKER_IMAGE}"
echo ""

# Build cwltool command
CWLTOOL_CMD="cwltool --enable-ext --no-container --basedir /data --outdir /out"

if [[ "$ENABLE_PROVENANCE" == "true" ]]; then
    CWLTOOL_CMD="${CWLTOOL_CMD} --provenance /out/prov_\$(date -u +%Y%m%dT%H%M%SZ)"
else
    CWLTOOL_CMD="${CWLTOOL_CMD} --parallel"
fi

CWLTOOL_CMD="${CWLTOOL_CMD} ${WORKFLOW_PATH} /cfg/${INPUT_FILE}"

# Run Docker command
echo -e "${GREEN}Running workflow...${NC}"
if [[ "$ENABLE_PROVENANCE" == "false" ]]; then
    echo -e "${YELLOW}Provenance disabled - using --parallel flag${NC}"
fi

# Build docker run command
DOCKER_RUN_ARGS=()
if [[ "$KEEP_CONTAINER" == "false" ]]; then
    DOCKER_RUN_ARGS+=("--rm")
else
    CONTAINER_NAME="coastsat-cwl-inspect-$(date +%s)"
    DOCKER_RUN_ARGS+=("--name" "${CONTAINER_NAME}")
    echo -e "${YELLOW}Container will be kept for inspection: ${CONTAINER_NAME}${NC}"
fi

docker run "${DOCKER_RUN_ARGS[@]}" \
  -v "${DATA_DIR}:/data" \
  -v "${CONFIG_DIR}:/cfg" \
  -v "${OUTPUT_DIR}:/out" \
  -w /workflow \
  "${DOCKER_IMAGE}" \
  bash -lc "${CWLTOOL_CMD}"

echo ""
echo -e "${GREEN}Workflow completed!${NC}"
echo "Results are in: ${OUTPUT_DIR}"

if [[ "$KEEP_CONTAINER" == "true" ]]; then
    CONTAINER_ID=$(docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | head -1)
    echo ""
    echo -e "${YELLOW}Container kept for inspection:${NC}"
    echo "  Container ID: ${CONTAINER_ID}"
    echo "  Container name: ${CONTAINER_NAME}"
    echo ""
    echo "To inspect the container:"
    echo "  docker exec -it ${CONTAINER_NAME} bash"
    echo ""
    echo "To commit container to image:"
    echo "  docker commit ${CONTAINER_NAME} coastsat-cwl-snapshot:latest"
    echo ""
    echo "To remove container when done:"
    echo "  docker rm -f ${CONTAINER_NAME}"
fi

