# PDFium + QPDF WASM Build Instructions

This repository includes integration of QPDF library with PDFium for WebAssembly, enabling PDF-to-JSON conversion functionality.

## Prerequisites

- Python 3.x
- Git
- Node.js and npm (for testing the server)
- Linux or macOS (recommended)
- At least 10GB of free disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/akash-ironsoft/pdfium-lib.git
cd pdfium-lib
```

### 2. Setup QPDF

Run the QPDF setup script to clone QPDF from the akash-ironsoft fork:

```bash
chmod +x setup-qpdf.sh
./setup-qpdf.sh
```

This script will:
- Clone QPDF from https://github.com/akash-ironsoft/qpdf.git
- Set up the correct remote configuration
- Place it in `build/emscripten/pdfium/third_party/qpdf`

### 3. Build PDFium with QPDF

```bash
# Build PDFium (includes QPDF compilation)
python3 make.py build-pdfium-wasm

# Apply patches
python3 make.py patch-wasm

# Build static libraries
python3 make.py build-wasm

# Generate WASM bindings (requires Emscripten environment)
source build/emsdk/emsdk_env.sh
python3 make.py generate-wasm
```

### 4. Test the Server

```bash
cd pdf-text-server
npm install
node server.js
```

Open `test.html` in your browser or navigate to `file:///<path>/pdfium-lib/pdf-text-server/test.html`

## What Gets Built

The build process creates:

1. **PDFium Static Library**: `build/emscripten/pdfium/out/emscripten-wasm-release/obj/libpdfium.a`
2. **QPDF Static Library**: `build/emscripten/pdfium/out/emscripten-wasm-release/obj/third_party/qpdf/libqpdf.a`
3. **Combined WASM Module**: `build/emscripten/wasm/release/node/pdfium.wasm` (~4.5MB)
4. **JavaScript Wrapper**: `build/emscripten/wasm/release/node/pdfium.js`

## Key Files Modified for QPDF Integration

- **modules/wasm.py**: Adds QPDF library linking, libjpeg dependencies, and required compiler flags
- **extras/wasm/utils/custom.cpp**: Implements QPDF wrapper functions (`QPDF_PDFToJSON`, `QPDF_FreeString`)
- **pdf-text-server/server.js**: Implements `/pdf-to-json` endpoint
- **pdf-text-server/test.html**: Web UI for testing PDF-to-JSON conversion

## API Endpoints

### Health Check
```bash
GET http://localhost:3000/health
```

### Extract Text (PDFium)
```bash
POST http://localhost:3000/extract-text
Content-Type: multipart/form-data
Body: pdf=<PDF file>
```

### Convert to JSON (QPDF)
```bash
POST http://localhost:3000/pdf-to-json?version=2
Content-Type: multipart/form-data
Body: pdf=<PDF file>
```

Query parameters:
- `version`: QPDF JSON version (1 or 2, default: 2)

## Architecture

```
pdfium-lib/
├── setup-qpdf.sh              # QPDF setup script
├── modules/wasm.py             # Build configuration with QPDF
├── extras/wasm/utils/
│   └── custom.cpp              # QPDF C++ wrappers
├── pdf-text-server/
│   ├── server.js               # Express server with PDF-to-JSON API
│   ├── test.html               # Test web interface
│   ├── pdfium.wasm            # Generated WASM module
│   └── pdfium.js              # Generated JS wrapper
└── build/emscripten/pdfium/
    └── third_party/qpdf/      # QPDF source (from akash-ironsoft fork)
```

## QPDF Repository

The QPDF integration uses a fork:
- **Fork**: https://github.com/akash-ironsoft/qpdf.git
- **Upstream**: https://github.com/qpdf/qpdf.git (official QPDF)

The fork allows for custom modifications while maintaining the ability to pull upstream updates.

## Troubleshooting

### Missing QPDF Directory
If the QPDF directory doesn't exist, run:
```bash
./setup-qpdf.sh
```

### Emscripten Environment Not Found
Make sure to source the Emscripten environment:
```bash
source build/emsdk/emsdk_env.sh
```

### Undefined Symbols During Linking
Ensure you've built PDFium completely before generating WASM:
```bash
python3 make.py build-pdfium-wasm
python3 make.py build-wasm
```

### Server Fails to Load WASM
Check that the WASM files are in `pdf-text-server/`:
```bash
ls -lh pdf-text-server/pdfium.*
```

If missing, copy from build directory:
```bash
cp build/emscripten/wasm/release/node/pdfium.* pdf-text-server/
```

## Technical Details

### Compiler Flags Added
- `-frtti`: Required by QPDF for runtime type information
- `-fexceptions`: Required by QPDF for exception handling
- `-sDISABLE_EXCEPTION_CATCHING=0`: Enable exception catching
- `-Wl,--allow-multiple-definition`: Handle duplicate JPEG symbols

### Exported Functions
- `QPDF_PDFToJSON(pdfBytes, size, version)`: Converts PDF to QPDF JSON format
- `QPDF_FreeString(ptr)`: Frees memory allocated for JSON strings

### Exported Runtime Methods
- `UTF8ToString`: Convert C strings to JavaScript strings
- `stringToUTF8`: Convert JavaScript strings to C strings
- Standard Emscripten runtime methods

## Building from Another Machine

When cloning this repository on a new machine:

1. Clone the repository
2. Run `./setup-qpdf.sh` to set up QPDF
3. Follow the build steps above
4. The build system will compile everything from source

Note: The `build/` directory is ignored by git (5+ GB), so each machine needs to rebuild.

## Contributing

When making changes:
1. Modify source files (not build artifacts)
2. Test the build process
3. Update documentation if needed
4. Commit only source files, not build artifacts

## References

- PDFium: https://pdfium.googlesource.com/pdfium/
- QPDF: https://github.com/qpdf/qpdf
- Emscripten: https://emscripten.org/
