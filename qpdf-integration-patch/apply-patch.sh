#!/bin/bash

# QPDF Integration Patch Application Script
# This script copies all necessary files to integrate QPDF into PDFium

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if we're in the PDFium root directory
if [ ! -f "BUILD.gn" ] || [ ! -d "public" ] || [ ! -d "fpdfsdk" ]; then
    echo -e "${RED}Error: This script must be run from the PDFium root directory${NC}"
    echo "Usage: cd /path/to/pdfium && $0"
    exit 1
fi

echo -e "${YELLOW}QPDF Integration Patch Application${NC}"
echo "=================================="
echo ""

# Backup existing files
echo -e "${YELLOW}Creating backups of existing files...${NC}"
mkdir -p .backup-qpdf-integration

if [ -f "BUILD.gn" ]; then
    cp BUILD.gn .backup-qpdf-integration/BUILD.gn.bak
    echo "  ✓ Backed up BUILD.gn"
fi

if [ -f "core/fxcrt/BUILD.gn" ]; then
    cp core/fxcrt/BUILD.gn .backup-qpdf-integration/fxcrt-BUILD.gn.bak
    echo "  ✓ Backed up core/fxcrt/BUILD.gn"
fi

if [ -f "core/fxge/BUILD.gn" ]; then
    cp core/fxge/BUILD.gn .backup-qpdf-integration/fxge-BUILD.gn.bak
    echo "  ✓ Backed up core/fxge/BUILD.gn"
fi

echo ""

# Copy new files
echo -e "${YELLOW}Installing new files...${NC}"

cp "$SCRIPT_DIR/public/ipdf_qpdf.h" public/
echo "  ✓ Installed public/ipdf_qpdf.h"

cp "$SCRIPT_DIR/fpdfsdk/fpdf_qpdf.cpp" fpdfsdk/
echo "  ✓ Installed fpdfsdk/fpdf_qpdf.cpp"

echo ""

# Replace modified files
echo -e "${YELLOW}Updating build configuration files...${NC}"

cp "$SCRIPT_DIR/BUILD.gn" .
echo "  ✓ Updated BUILD.gn"

cp "$SCRIPT_DIR/core/fxcrt/BUILD.gn" core/fxcrt/
echo "  ✓ Updated core/fxcrt/BUILD.gn"

cp "$SCRIPT_DIR/core/fxge/BUILD.gn" core/fxge/
echo "  ✓ Updated core/fxge/BUILD.gn"

echo ""
echo -e "${GREEN}✓ QPDF integration patch applied successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Ensure QPDF is installed in third_party/qpdf/"
echo "2. Build PDFium: python3 make.py build-wasm"
echo "3. Generate WASM: python3 make.py generate-wasm"
echo ""
echo "Backups saved in: .backup-qpdf-integration/"
echo ""

# Check for QPDF
if [ ! -d "third_party/qpdf" ]; then
    echo -e "${YELLOW}Warning: third_party/qpdf directory not found${NC}"
    echo "Make sure to install QPDF before building"
fi
