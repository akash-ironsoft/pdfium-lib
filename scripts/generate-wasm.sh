#!/bin/bash

# PDFium WASM Generation Script
# Automates the complete WASM build process for PDFium with QPDF integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="/home/akash/Dev/ironsoft/pdfium-lib"
PDFIUM_DIR="$PROJECT_ROOT/build/emscripten/pdfium"
OUTPUT_DIR="$PROJECT_ROOT/lib"
LOG_DIR="$PROJECT_ROOT/logs"

# Options
CLEAN_BUILD=false
SKIP_BUILD=false
SKIP_GENERATE=false
VERBOSE=false

# Function to print colored messages
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "\n${YELLOW}==>${NC} ${BLUE}$1${NC}\n"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automates PDFium WASM build with QPDF integration

Options:
    -c, --clean         Clean build (remove out directory)
    -b, --build-only    Only run build-wasm (skip generate-wasm)
    -g, --generate-only Only run generate-wasm (skip build-wasm)
    -v, --verbose       Verbose output
    -h, --help          Show this help message

Examples:
    $0                  # Full build and generate
    $0 -c               # Clean build from scratch
    $0 -b               # Only build, don't generate
    $0 -g               # Only generate WASM files

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -b|--build-only)
            SKIP_GENERATE=true
            shift
            ;;
        -g|--generate-only)
            SKIP_BUILD=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Create log directory
mkdir -p "$LOG_DIR"

# Get timestamp for logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUILD_LOG="$LOG_DIR/build-wasm-$TIMESTAMP.log"
GENERATE_LOG="$LOG_DIR/generate-wasm-$TIMESTAMP.log"

# Print header
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  PDFium WASM Build with QPDF Integration    ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if PDFium directory exists
if [ ! -d "$PDFIUM_DIR" ]; then
    log_error "PDFium directory not found: $PDFIUM_DIR"
    log_info "Please ensure PDFium is cloned and QPDF patch is applied"
    exit 1
fi

# Change to PDFium directory
cd "$PDFIUM_DIR"
log_info "Working directory: $PDFIUM_DIR"

# Check for QPDF integration
if [ ! -f "public/ipdf_qpdf.h" ]; then
    log_warning "QPDF integration files not found!"
    log_info "Apply patch: $PROJECT_ROOT/qpdf-integration-patch/apply-patch.sh"
    exit 1
fi

log_success "QPDF integration files detected"

# Check for QPDF library
if [ ! -d "third_party/qpdf" ]; then
    log_error "QPDF library not found in third_party/qpdf/"
    log_info "Please install QPDF before building"
    exit 1
fi

log_success "QPDF library found"

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    log_step "Cleaning build directory"
    if [ -d "out" ]; then
        rm -rf out
        log_success "Build directory cleaned"
    else
        log_info "No build directory to clean"
    fi
fi

# Build WASM
if [ "$SKIP_BUILD" = false ]; then
    log_step "Building PDFium WASM (Step 1/2)"
    log_info "This may take several minutes..."
    log_info "Log file: $BUILD_LOG"

    # Change to project root to run make.py
    cd "$PROJECT_ROOT"

    # Export depot_tools to PATH
    export PATH=$PATH:$PWD/build/depot-tools
    log_info "depot_tools added to PATH"

    if [ "$VERBOSE" = true ]; then
        python3 make.py build-wasm 2>&1 | tee "$BUILD_LOG"
    else
        python3 make.py build-wasm > "$BUILD_LOG" 2>&1 &
        BUILD_PID=$!

        # Show progress spinner
        spin='-\|/'
        i=0
        while kill -0 $BUILD_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r${BLUE}Building...${NC} ${spin:$i:1}"
            sleep .1
        done
        printf "\r"

        wait $BUILD_PID
        BUILD_STATUS=$?

        if [ $BUILD_STATUS -ne 0 ]; then
            log_error "Build failed! Check log: $BUILD_LOG"
            tail -50 "$BUILD_LOG"
            exit 1
        fi
    fi

    log_success "Build completed successfully"

    # Check if libqpdf.a was created
    if [ -f "out/wasm/obj/third_party/qpdf/libqpdf.a" ]; then
        QPDF_SIZE=$(du -h "out/wasm/obj/third_party/qpdf/libqpdf.a" | cut -f1)
        log_success "QPDF library built: $QPDF_SIZE"
    fi
else
    log_info "Skipping build step (--generate-only)"
fi

# Generate WASM files
if [ "$SKIP_GENERATE" = false ]; then
    log_step "Generating WASM files (Step 2/2)"
    log_info "Activating Emscripten environment..."

    # Change to project root
    cd "$PROJECT_ROOT"

    # Source Emscripten environment
    if [ -f "build/emsdk/emsdk_env.sh" ]; then
        source build/emsdk/emsdk_env.sh
        log_success "Emscripten environment activated"
    else
        log_error "Emscripten SDK not found"
        exit 1
    fi

    log_info "Generating WASM and JS files..."
    log_info "Log file: $GENERATE_LOG"

    if [ "$VERBOSE" = true ]; then
        python3 make.py generate-wasm 2>&1 | tee "$GENERATE_LOG"
    else
        python3 make.py generate-wasm > "$GENERATE_LOG" 2>&1 &
        GEN_PID=$!

        # Show progress spinner
        spin='-\|/'
        i=0
        while kill -0 $GEN_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r${BLUE}Generating...${NC} ${spin:$i:1}"
            sleep .1
        done
        printf "\r"

        wait $GEN_PID
        GEN_STATUS=$?

        if [ $GEN_STATUS -ne 0 ]; then
            log_error "Generation failed! Check log: $GENERATE_LOG"
            tail -50 "$GENERATE_LOG"
            exit 1
        fi
    fi

    log_success "WASM generation completed successfully"
else
    log_info "Skipping generate step (--build-only)"
fi

# Check output files
log_step "Verifying output files"

# Change to PDFium directory for output file checks
cd "$PDFIUM_DIR"

WASM_FILE="out/wasm/pdfium.wasm"
JS_FILE="out/wasm/pdfium.js"

if [ -f "$WASM_FILE" ] && [ -f "$JS_FILE" ]; then
    WASM_SIZE=$(du -h "$WASM_FILE" | cut -f1)
    JS_SIZE=$(du -h "$JS_FILE" | cut -f1)

    log_success "pdfium.wasm: $WASM_SIZE"
    log_success "pdfium.js: $JS_SIZE"

    # Copy to lib directory
    log_step "Copying files to lib directory"
    mkdir -p "$OUTPUT_DIR"

    cp "$WASM_FILE" "$OUTPUT_DIR/"
    cp "$JS_FILE" "$OUTPUT_DIR/"

    log_success "Files copied to: $OUTPUT_DIR"
else
    log_error "Output files not found!"
    log_error "Expected: $WASM_FILE and $JS_FILE"
    exit 1
fi

# Verify QPDF functions are exported
log_step "Verifying QPDF function exports"

if grep -q "IPDF_QPDF_PDFToJSON" "$JS_FILE"; then
    log_success "IPDF_QPDF_PDFToJSON exported"
else
    log_warning "IPDF_QPDF_PDFToJSON not found in exports!"
fi

if grep -q "IPDF_QPDF_FreeString" "$JS_FILE"; then
    log_success "IPDF_QPDF_FreeString exported"
else
    log_warning "IPDF_QPDF_FreeString not found in exports!"
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}            Build Summary                      ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
log_success "WASM file: $OUTPUT_DIR/pdfium.wasm ($WASM_SIZE)"
log_success "JS file: $OUTPUT_DIR/pdfium.js ($JS_SIZE)"
echo ""
log_info "Logs saved to:"
if [ "$SKIP_BUILD" = false ]; then
    echo "  - Build: $BUILD_LOG"
fi
if [ "$SKIP_GENERATE" = false ]; then
    echo "  - Generate: $GENERATE_LOG"
fi
echo ""

# Suggest next steps
log_info "Next steps:"
echo "  1. Test the WASM build: cd $PROJECT_ROOT/pdf-text-server && node server.js"
echo "  2. View logs if needed: tail -f $LOG_DIR/*.log"
echo ""

log_success "WASM generation completed successfully!"
