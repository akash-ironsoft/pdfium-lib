# Build Scripts

This folder contains automation scripts for building PDFium with QPDF integration.

## Available Scripts

### generate-wasm.sh

Automates the complete WASM build process for PDFium with QPDF integration.

#### Features

- ✓ Automated build-wasm and generate-wasm steps
- ✓ Progress indicators and colored output
- ✓ Detailed logging to files
- ✓ Verification of QPDF integration
- ✓ Function export validation
- ✓ Automatic file copying to lib directory
- ✓ Error handling and reporting

#### Usage

```bash
# Full build (build + generate)
./scripts/generate-wasm.sh

# Clean build from scratch
./scripts/generate-wasm.sh --clean

# Only build (skip generation)
./scripts/generate-wasm.sh --build-only

# Only generate (skip build)
./scripts/generate-wasm.sh --generate-only

# Verbose output (show all logs in terminal)
./scripts/generate-wasm.sh --verbose
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--clean` | `-c` | Remove out directory before building |
| `--build-only` | `-b` | Only run build-wasm (skip generate-wasm) |
| `--generate-only` | `-g` | Only run generate-wasm (skip build-wasm) |
| `--verbose` | `-v` | Show all output in terminal |
| `--help` | `-h` | Show help message |

#### What It Does

1. **Validation**
   - Checks if PDFium directory exists
   - Verifies QPDF integration files are present
   - Confirms QPDF library is installed

2. **Building** (unless --generate-only)
   - Adds depot_tools to PATH
   - Runs `python3 make.py build-wasm`
   - Logs output to `logs/build-wasm-TIMESTAMP.log`
   - Verifies libqpdf.a was created

3. **Generation** (unless --build-only)
   - Sources Emscripten environment
   - Runs `python3 make.py generate-wasm`
   - Logs output to `logs/generate-wasm-TIMESTAMP.log`
   - Verifies WASM and JS files created

4. **Verification**
   - Checks pdfium.wasm and pdfium.js exist
   - Verifies QPDF functions are exported
   - Reports file sizes

5. **Output**
   - Copies files to `lib/` directory
   - Displays summary with file sizes
   - Shows log file locations

#### Output Files

After successful build:
- `lib/pdfium.wasm` - WebAssembly binary (~4MB)
- `lib/pdfium.js` - JavaScript wrapper (~200KB)
- `logs/build-wasm-TIMESTAMP.log` - Build log
- `logs/generate-wasm-TIMESTAMP.log` - Generation log

#### Example Output

```
╔════════════════════════════════════════════════╗
║  PDFium WASM Build with QPDF Integration      ║
╚════════════════════════════════════════════════╝

ℹ Working directory: /home/akash/Dev/ironsoft/pdfium-lib/build/emscripten/pdfium
✓ QPDF integration files detected
✓ QPDF library found

==> Building PDFium WASM (Step 1/2)

ℹ This may take several minutes...
ℹ Log file: logs/build-wasm-20251118_181500.log
✓ Build completed successfully
✓ QPDF library built: 9.2K

==> Generating WASM files (Step 2/2)

ℹ Activating Emscripten environment...
✓ Emscripten environment activated
✓ WASM generation completed successfully

==> Verifying output files

✓ pdfium.wasm: 4.0M
✓ pdfium.js: 201K

==> Copying files to lib directory

✓ Files copied to: /home/akash/Dev/ironsoft/pdfium-lib/lib

==> Verifying QPDF function exports

✓ IPDF_QPDF_PDFToJSON exported
✓ IPDF_QPDF_FreeString exported

╔════════════════════════════════════════════════╗
║            Build Summary                       ║
╚════════════════════════════════════════════════╝

✓ WASM file: lib/pdfium.wasm (4.0M)
✓ JS file: lib/pdfium.js (201K)

ℹ Logs saved to:
  - Build: logs/build-wasm-20251118_181500.log
  - Generate: logs/generate-wasm-20251118_181500.log

ℹ Next steps:
  1. Test the WASM build: cd pdf-text-server && node server.js
  2. View logs if needed: tail -f logs/*.log

✓ WASM generation completed successfully!
```

#### Troubleshooting

**Error: PDFium directory not found**
- Ensure PDFium is cloned to `build/emscripten/pdfium/`

**Error: QPDF integration files not found**
- Apply the QPDF patch: `qpdf-integration-patch/apply-patch.sh`

**Error: QPDF library not found**
- Install QPDF to `third_party/qpdf/`
- Run the setup script if available

**Build failed**
- Check the build log: `tail -100 logs/build-wasm-*.log`
- Verify all dependencies are installed
- Try clean build: `./scripts/generate-wasm.sh --clean`

**Functions not exported**
- Check `modules/wasm.py` includes QPDF functions
- Verify function names have underscore prefix

#### Requirements

- Python 3
- Emscripten SDK (in build/emsdk/)
- depot_tools (in build/depot-tools/)
- QPDF library (in third_party/qpdf/)
- PDFium source with QPDF integration patch applied

#### Environment Variables

The script uses these paths (modify in script if needed):
- `PROJECT_ROOT=/home/akash/Dev/ironsoft/pdfium-lib`
- `PDFIUM_DIR=$PROJECT_ROOT/build/emscripten/pdfium`
- `OUTPUT_DIR=$PROJECT_ROOT/lib`
- `LOG_DIR=$PROJECT_ROOT/logs`

## Adding More Scripts

To add new build automation scripts:

1. Create script in this folder
2. Make it executable: `chmod +x script-name.sh`
3. Document it in this README
4. Follow the naming convention: `action-target.sh`

## Examples

### Typical Workflow

```bash
# First time: Clean build
./scripts/generate-wasm.sh --clean

# Development: Quick rebuild
./scripts/generate-wasm.sh --generate-only

# After code changes: Full rebuild
./scripts/generate-wasm.sh

# Debug build issues
./scripts/generate-wasm.sh --verbose
```

### Automated Testing

```bash
# Build and test
./scripts/generate-wasm.sh && cd pdf-text-server && node server.js
```

### CI/CD Integration

```bash
# In CI pipeline
./scripts/generate-wasm.sh --clean --verbose
if [ $? -eq 0 ]; then
    echo "Build successful"
    # Run tests here
fi
```

## License

These scripts are part of the pdfium-lib project and follow the same license.
