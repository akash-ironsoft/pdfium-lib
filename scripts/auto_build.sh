#!/bin/bash

################################################################################
# PDFium Library - Automated Build Script
#
# This script automates the build workflow for the pdfium-lib project.
# It performs dependency checks, builds the project using the Python-based
# make system, and logs all output for troubleshooting.
#
# Usage: ./auto_build.sh [platform]
# Where [platform] can be: wasm, ios, macos, android (defaults to wasm)
#
# Requirements:
#   - Python 3 with pip and venv
#   - Git
#   - CMake (optional, for native builds)
#   - Ninja (optional, for faster builds)
#
# Exit codes:
#   0 - Success
#   1 - Missing required dependencies
#   2 - Build failed
################################################################################

set -e  # Exit on any error

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="/home/akash/Dev/ironsoft/pdfium-lib"
BUILD_LOG="${PROJECT_ROOT}/build.log"
PLATFORM="${1:-wasm}"  # Default to wasm if no platform specified

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${BUILD_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${BUILD_LOG}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${BUILD_LOG}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${BUILD_LOG}"
}

check_command() {
    local cmd=$1
    local required=$2

    if command -v "${cmd}" &> /dev/null; then
        local version=$(${cmd} --version 2>&1 | head -n 1)
        log_success "${cmd} is installed: ${version}"
        return 0
    else
        if [ "${required}" = "true" ]; then
            log_error "${cmd} is NOT installed (REQUIRED)"
            return 1
        else
            log_warning "${cmd} is NOT installed (optional)"
            return 0
        fi
    fi
}

################################################################################
# Main Script
################################################################################

# Clear previous log and start fresh
echo "==================================" > "${BUILD_LOG}"
echo "PDFium Build Log" >> "${BUILD_LOG}"
echo "Started: $(date)" >> "${BUILD_LOG}"
echo "Platform: ${PLATFORM}" >> "${BUILD_LOG}"
echo "==================================" >> "${BUILD_LOG}"
echo "" >> "${BUILD_LOG}"

log_info "Starting automated build for PDFium library..."
log_info "Platform: ${PLATFORM}"
log_info "Build log: ${BUILD_LOG}"
echo ""

# Navigate to project root
log_info "Navigating to project directory: ${PROJECT_ROOT}"
cd "${PROJECT_ROOT}" || {
    log_error "Failed to navigate to ${PROJECT_ROOT}"
    exit 1
}

# Check for required dependencies
log_info "Checking required dependencies..."
echo ""

DEPS_OK=true

# Python 3 (REQUIRED)
if ! check_command "python3" "true"; then
    DEPS_OK=false
fi

# pip (REQUIRED for installing Python packages)
if ! python3 -m pip --version &> /dev/null; then
    log_error "pip is NOT installed (REQUIRED)"
    DEPS_OK=false
else
    log_success "pip is installed"
fi

# Git (REQUIRED)
if ! check_command "git" "true"; then
    DEPS_OK=false
fi

# Optional dependencies
check_command "cmake" "false"
check_command "ninja" "false"
check_command "node" "false"

echo ""

# Exit if required dependencies are missing
if [ "${DEPS_OK}" = false ]; then
    log_error "Missing required dependencies. Please install them and try again."
    log_info "Install commands:"
    echo "  - Python 3: sudo apt-get install python3 python3-pip python3-venv (Ubuntu/Debian)"
    echo "  - Git: sudo apt-get install git (Ubuntu/Debian)"
    echo "  - CMake: sudo apt-get install cmake (Ubuntu/Debian)"
    echo "  - Ninja: sudo apt-get install ninja-build (Ubuntu/Debian)"
    exit 1
fi

# Check and activate virtual environment
log_info "Checking Python virtual environment..."
if [ ! -d "venv" ]; then
    log_warning "Virtual environment not found. Creating..."
    python3 -m venv venv >> "${BUILD_LOG}" 2>&1 || {
        log_error "Failed to create virtual environment"
        exit 1
    }
    log_success "Virtual environment created"
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source venv/bin/activate || {
    log_error "Failed to activate virtual environment"
    exit 1
}
log_success "Virtual environment activated"

# Check if Python requirements are installed
log_info "Checking Python requirements..."
if [ -f "requirements.txt" ]; then
    log_info "Installing/updating Python dependencies from requirements.txt..."
    python3 -m pip install -r requirements.txt >> "${BUILD_LOG}" 2>&1 || {
        log_error "Failed to install Python requirements"
        exit 1
    }
    log_success "Python dependencies are up to date"
else
    log_warning "requirements.txt not found"
    log_info "Installing essential packages..."
    python3 -m pip install setuptools docopt pygemstones >> "${BUILD_LOG}" 2>&1 || {
        log_error "Failed to install essential packages"
        exit 1
    }
fi

echo ""

# Check if depot-tools exists, build if needed
log_info "Checking for Google Depot Tools..."
if [ ! -d "build/depot-tools" ]; then
    log_warning "Depot Tools not found. Building..."
    python3 make.py build-depot-tools >> "${BUILD_LOG}" 2>&1 || {
        log_error "Failed to build depot-tools"
        exit 2
    }
    log_success "Depot Tools built successfully"
else
    log_success "Depot Tools already exists"
fi

# Add depot-tools to PATH for this session
export PATH="${PATH}:${PROJECT_ROOT}/build/depot-tools"
log_info "Added depot-tools to PATH"

echo ""

# For WASM builds, check and build Emscripten SDK
if [ "${PLATFORM}" = "wasm" ]; then
    log_info "Checking for Emscripten SDK..."
    if [ ! -d "build/emsdk" ]; then
        log_warning "Emscripten SDK not found. Building..."
        python3 make.py build-emsdk >> "${BUILD_LOG}" 2>&1 || {
            log_error "Failed to build Emscripten SDK"
            exit 2
        }
        log_success "Emscripten SDK built successfully"
    else
        log_success "Emscripten SDK already exists"
    fi

    # Source Emscripten environment
    log_info "Activating Emscripten environment..."
    source build/emsdk/emsdk_env.sh >> "${BUILD_LOG}" 2>&1 || {
        log_warning "Failed to source emsdk_env.sh (may not affect build)"
    }
    log_success "Emscripten environment activated"
    echo ""
fi

# Validate platform
case "${PLATFORM}" in
    wasm|WASM)
        PLATFORM="wasm"
        BUILD_TASKS=("build-pdfium-wasm" "patch-wasm" "build-wasm" "generate-wasm" "install-wasm")
        ;;
    ios|iOS)
        PLATFORM="ios"
        BUILD_TASKS=("build-pdfium-ios" "patch-ios" "build-ios" "install-ios")
        ;;
    macos|macOS)
        PLATFORM="macos"
        BUILD_TASKS=("build-pdfium-macos" "patch-macos" "build-macos" "install-macos")
        ;;
    android|Android)
        PLATFORM="android"
        BUILD_TASKS=("build-pdfium-android" "patch-android" "build-android" "install-android")
        ;;
    *)
        log_error "Unknown platform: ${PLATFORM}"
        log_info "Valid platforms: wasm, ios, macos, android"
        exit 1
        ;;
esac

# Execute build tasks for the selected platform
log_info "Starting ${PLATFORM} build process..."
log_info "Build tasks: ${BUILD_TASKS[*]}"
echo ""

BUILD_SUCCESS=true
for task in "${BUILD_TASKS[@]}"; do
    log_info "Running task: ${task}"

    if python3 make.py "${task}" >> "${BUILD_LOG}" 2>&1; then
        log_success "Task '${task}' completed successfully"
    else
        log_error "Task '${task}' failed"
        BUILD_SUCCESS=false
        break
    fi
    echo ""
done

echo ""
echo "==================================" | tee -a "${BUILD_LOG}"

if [ "${BUILD_SUCCESS}" = true ]; then
    log_success "Build completed successfully for platform: ${PLATFORM}"
    log_info "Check ${BUILD_LOG} for detailed build output"
    echo "==================================" | tee -a "${BUILD_LOG}"
    echo "" | tee -a "${BUILD_LOG}"

    # Optional: Generate documentation for WASM if doxygen is available
    if [ "${PLATFORM}" = "wasm" ]; then
        if command -v doxygen &> /dev/null; then
            log_info "Doxygen found. Generating documentation..."
            if python3 make.py generate-wasm >> "${BUILD_LOG}" 2>&1; then
                log_success "Documentation generated successfully"
            else
                log_warning "Documentation generation failed (non-critical)"
            fi
        else
            log_warning "Doxygen not installed. Skipping documentation generation."
            log_info "Install doxygen with: sudo apt-get install doxygen (optional)"
        fi
        echo ""
    fi

    log_info "Next steps:"
    if [ "${PLATFORM}" = "wasm" ]; then
        echo "  - Run the WASM sample: /home/akash/Dev/ironsoft/scripts/run_pdfium_sample.sh"
        echo "  - Test the build: python3 make.py test-wasm"
        echo "  - Copy assets: cp -r sample-wasm/assets sample-wasm/build/"
    else
        echo "  - Test the build: python3 make.py test-${PLATFORM}"
        echo "  - Archive artifacts: python3 make.py archive-${PLATFORM}"
    fi
    exit 0
else
    log_error "Build failed for platform: ${PLATFORM}"
    log_info "Check ${BUILD_LOG} for error details"
    echo "==================================" | tee -a "${BUILD_LOG}"
    exit 2
fi
