#!/bin/bash

# QPDF Setup Script for PDFium-lib
# This script clones and sets up QPDF from the akash-ironsoft fork

set -e

echo "================================================"
echo "QPDF Setup Script for PDFium WASM with QPDF"
echo "================================================"
echo ""

QPDF_DIR="build/emscripten/pdfium/third_party/qpdf"
QPDF_REPO="https://github.com/akash-ironsoft/qpdf.git"
QPDF_BRANCH="main"

# Check if QPDF directory already exists
if [ -d "$QPDF_DIR" ]; then
    echo "QPDF directory already exists at: $QPDF_DIR"
    echo "Checking remote configuration..."

    cd "$QPDF_DIR"
    CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

    if [ "$CURRENT_ORIGIN" != "$QPDF_REPO" ]; then
        echo "Updating origin remote to: $QPDF_REPO"
        git remote set-url origin "$QPDF_REPO"

        # Add upstream if it doesn't exist
        if ! git remote | grep -q "^upstream$"; then
            echo "Adding upstream remote..."
            git remote add upstream https://github.com/qpdf/qpdf.git
        fi
    else
        echo "Origin remote is already configured correctly."
    fi

    echo "Pulling latest changes..."
    git pull origin "$QPDF_BRANCH"

    cd - > /dev/null
else
    echo "Cloning QPDF from: $QPDF_REPO"

    # Create parent directory if needed
    mkdir -p "$(dirname "$QPDF_DIR")"

    # Clone QPDF
    git clone --branch "$QPDF_BRANCH" "$QPDF_REPO" "$QPDF_DIR"

    # Add upstream remote
    cd "$QPDF_DIR"
    git remote add upstream https://github.com/qpdf/qpdf.git
    cd - > /dev/null
fi

echo ""
echo "================================================"
echo "QPDF setup complete!"
echo "================================================"
echo ""
echo "Repository: $QPDF_REPO"
echo "Location: $QPDF_DIR"
echo ""
echo "Next steps:"
echo "1. Run: python3 make.py build-pdfium-wasm"
echo "2. Run: python3 make.py patch-wasm"
echo "3. Run: python3 make.py build-wasm"
echo "4. Run: source build/emsdk/emsdk_env.sh && python3 make.py generate-wasm"
echo ""
