#!/bin/bash

################################################################################
# PDFium WASM Sample Runner
#
# This script runs the PDFium WebAssembly sample application built by the
# auto_build.sh script. It handles various runtime scenarios and provides
# helpful error messages.
#
# Usage: ./run_pdfium_sample.sh [mode]
# Where [mode] can be: node, server (defaults to node)
#
# Requirements:
#   - Node.js (for node mode)
#   - Python 3 (for server mode)
#   - Built WASM artifacts in sample-wasm/build/
#
# Exit codes:
#   0 - Success
#   1 - Missing dependencies or build directory
#   2 - Runtime error
################################################################################

set -e  # Exit on any error (except where explicitly handled)

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
PROJECT_ROOT="/home/akash/Dev/ironsoft/pdfium-lib"
SAMPLE_BUILD_DIR="${PROJECT_ROOT}/sample-wasm/build"
SAMPLE_ASSETS_DIR="${PROJECT_ROOT}/sample-wasm/assets"
WASM_FILE="${SAMPLE_BUILD_DIR}/index.wasm"
JS_FILE="${SAMPLE_BUILD_DIR}/index.js"
HTML_FILE="${SAMPLE_BUILD_DIR}/index.html"

# Mode (node or server)
MODE="${1:-node}"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Main Script
################################################################################

print_header "PDFium WASM Sample Runner"

# Navigate to project root
log_info "Navigating to project directory..."
cd "${PROJECT_ROOT}" || {
    log_error "Failed to navigate to ${PROJECT_ROOT}"
    exit 1
}

# Check mode
case "${MODE}" in
    node|NODE)
        MODE="node"
        ;;
    server|SERVER|web|WEB)
        MODE="server"
        ;;
    *)
        log_error "Unknown mode: ${MODE}"
        log_info "Valid modes: node, server"
        exit 1
        ;;
esac

log_info "Running in ${MODE} mode"
echo ""

# Check if Node.js is available (required for node mode)
if [ "${MODE}" = "node" ]; then
    log_info "Checking for Node.js..."
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed!"
        echo ""
        echo "Node.js is required to run the WASM sample."
        echo "Install it with:"
        echo "  - Ubuntu/Debian: sudo apt-get install nodejs"
        echo "  - macOS: brew install node"
        echo "  - Or download from: https://nodejs.org/"
        exit 1
    else
        NODE_VERSION=$(node --version)
        log_success "Node.js is installed: ${NODE_VERSION}"
    fi
fi

# Check if Python is available (required for server mode)
if [ "${MODE}" = "server" ]; then
    log_info "Checking for Python 3..."
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed!"
        exit 1
    else
        PYTHON_VERSION=$(python3 --version)
        log_success "Python 3 is installed: ${PYTHON_VERSION}"
    fi
fi

echo ""

# Check if build directory exists
log_info "Checking build directory..."
if [ ! -d "${SAMPLE_BUILD_DIR}" ]; then
    log_error "Build directory not found: ${SAMPLE_BUILD_DIR}"
    echo ""
    echo "The WASM sample has not been built yet."
    echo "Please run the build script first:"
    echo "  /home/akash/Dev/ironsoft/scripts/auto_build.sh wasm"
    exit 1
else
    log_success "Build directory found: ${SAMPLE_BUILD_DIR}"
fi

# Check if required WASM artifacts exist
log_info "Checking for WASM artifacts..."

ARTIFACTS_OK=true

if [ ! -f "${WASM_FILE}" ]; then
    log_error "WASM file not found: ${WASM_FILE}"
    ARTIFACTS_OK=false
else
    WASM_SIZE=$(du -h "${WASM_FILE}" | cut -f1)
    log_success "WASM file found (${WASM_SIZE}): index.wasm"
fi

if [ ! -f "${JS_FILE}" ]; then
    log_error "JavaScript file not found: ${JS_FILE}"
    ARTIFACTS_OK=false
else
    JS_SIZE=$(du -h "${JS_FILE}" | cut -f1)
    log_success "JavaScript file found (${JS_SIZE}): index.js"
fi

if [ ! -f "${HTML_FILE}" ]; then
    log_warning "HTML file not found: ${HTML_FILE}"
    echo "           (This is optional for Node.js execution)"
else
    log_success "HTML file found: index.html"
fi

echo ""

if [ "${ARTIFACTS_OK}" = false ]; then
    log_error "Missing required build artifacts!"
    echo ""
    echo "Please rebuild the WASM sample:"
    echo "  /home/akash/Dev/ironsoft/scripts/auto_build.sh wasm"
    exit 1
fi

# Check if assets directory needs to be copied
log_info "Checking for assets in build directory..."
if [ ! -d "${SAMPLE_BUILD_DIR}/assets" ]; then
    if [ -d "${SAMPLE_ASSETS_DIR}" ]; then
        log_warning "Assets not found in build directory. Copying..."
        cp -r "${SAMPLE_ASSETS_DIR}" "${SAMPLE_BUILD_DIR}/" || {
            log_error "Failed to copy assets"
            exit 1
        }
        log_success "Assets copied to build directory"
    else
        log_error "Assets directory not found: ${SAMPLE_ASSETS_DIR}"
        exit 1
    fi
else
    log_success "Assets directory found in build directory"
fi

echo ""

# Navigate to the build directory to ensure relative paths work
log_info "Navigating to build directory..."
cd "${SAMPLE_BUILD_DIR}" || {
    log_error "Failed to navigate to ${SAMPLE_BUILD_DIR}"
    exit 1
}

################################################################################
# Execute based on mode
################################################################################

if [ "${MODE}" = "node" ]; then
    # Run the WASM sample with Node.js
    print_header "Running PDFium WASM Sample (Node.js)"

    log_info "Executing: node index.js"
    echo ""

    # Run node and capture exit code
    set +e  # Temporarily disable exit on error to handle it gracefully
    node index.js
    EXIT_CODE=$?
    set -e

    echo ""

    # Report results
    if [ ${EXIT_CODE} -eq 0 ]; then
        print_header "Execution Completed Successfully"
        log_success "PDFium WASM sample ran without errors"
        log_info "Exit code: ${EXIT_CODE}"
        echo ""
        log_info "To view the HTML version, run:"
        echo "  /home/akash/Dev/ironsoft/scripts/run_pdfium_sample.sh server"
        exit 0
    else
        log_error "Execution failed with exit code: ${EXIT_CODE}"
        echo ""
        echo "Troubleshooting tips:"
        echo "  1. Check if the PDF file exists in the assets directory"
        echo "  2. Verify the WASM module was built correctly"
        echo "  3. Rebuild with: /home/akash/Dev/ironsoft/scripts/auto_build.sh wasm"
        echo "  4. Check build.log for detailed build information"
        exit 2
    fi

elif [ "${MODE}" = "server" ]; then
    # Start HTTP server
    print_header "Starting HTTP Server"

    PORT=8080
    log_info "Starting Python HTTP server on port ${PORT}..."
    log_info "Server directory: ${SAMPLE_BUILD_DIR}"
    echo ""
    log_success "Server is running!"
    echo ""
    echo "Access the demo at:"
    echo -e "  ${GREEN}http://localhost:${PORT}${NC}"
    echo -e "  ${GREEN}http://localhost:${PORT}/index.html${NC}"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""

    # Start the server
    python3 -m http.server ${PORT}
fi
