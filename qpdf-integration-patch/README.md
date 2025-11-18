# QPDF Integration Patch for PDFium

This folder contains all the necessary files to integrate QPDF PDF-to-JSON functionality into PDFium.

## Files Included

### New Files (to be added)
- `public/ipdf_qpdf.h` - Public API header for QPDF integration
- `fpdfsdk/fpdf_qpdf.cpp` - Implementation of QPDF integration functions

### Modified Files (to be replaced)
- `BUILD.gn` - Main build file with QPDF dependency added
- `core/fxcrt/BUILD.gn` - Core runtime build with WASM support
- `core/fxge/BUILD.gn` - Graphics engine build with WASM support

## Installation Instructions

### Prerequisites
1. Fresh PDFium source code cloned from https://pdfium.googlesource.com/pdfium.git
2. QPDF library installed in `third_party/qpdf/`

### Steps to Apply the Patch

1. Navigate to your PDFium root directory:
   ```bash
   cd /path/to/pdfium
   ```

2. Copy the new files:
   ```bash
   cp /path/to/qpdf-integration-patch/public/ipdf_qpdf.h public/
   cp /path/to/qpdf-integration-patch/fpdfsdk/fpdf_qpdf.cpp fpdfsdk/
   ```

3. Replace the modified build files:
   ```bash
   cp /path/to/qpdf-integration-patch/BUILD.gn .
   cp /path/to/qpdf-integration-patch/core/fxcrt/BUILD.gn core/fxcrt/
   cp /path/to/qpdf-integration-patch/core/fxge/BUILD.gn core/fxge/
   ```

### Alternative: Use Script to Apply All Changes

You can use the provided script to automatically copy all files:

```bash
cd /path/to/pdfium
/path/to/qpdf-integration-patch/apply-patch.sh
```

## API Functions

### IPDF_QPDF_PDFToJSON
```c
char* IPDF_QPDF_PDFToJSON(const void* pdf_data, size_t pdf_size, int version);
```
Converts a PDF document to QPDF JSON format.

**Parameters:**
- `pdf_data` - Pointer to PDF file data in memory
- `pdf_size` - Size of PDF file data in bytes
- `version` - QPDF JSON version (1 or 2)

**Returns:** Null-terminated JSON string (must be freed with IPDF_QPDF_FreeString)

### IPDF_QPDF_FreeString
```c
void IPDF_QPDF_FreeString(char* str);
```
Frees a string allocated by IPDF_QPDF_PDFToJSON.

**Parameters:**
- `str` - String to free

## Building PDFium with QPDF Integration

### For WASM Build
```bash
# Build PDFium
python3 make.py build-wasm

# Generate WASM files
python3 make.py generate-wasm
```

Make sure your `modules/wasm.py` includes the QPDF functions in the exported functions list:
- `_IPDF_QPDF_PDFToJSON`
- `_IPDF_QPDF_FreeString`

## Usage Example (JavaScript/WASM)

```javascript
const FPDF = {
  IPDF_QPDF_PDFToJSON: Module.cwrap('IPDF_QPDF_PDFToJSON', 'number', ['number', 'number', 'number']),
  IPDF_QPDF_FreeString: Module.cwrap('IPDF_QPDF_FreeString', '', ['number'])
};

// Convert PDF to JSON
const pdfBuffer = fs.readFileSync('document.pdf');
const pdfPtr = Module._malloc(pdfBuffer.length);
Module.HEAPU8.set(pdfBuffer, pdfPtr);

const jsonPtr = FPDF.IPDF_QPDF_PDFToJSON(pdfPtr, pdfBuffer.length, 2);
if (jsonPtr) {
  const jsonStr = Module.UTF8ToString(jsonPtr);
  const jsonObj = JSON.parse(jsonStr);
  console.log(jsonObj);

  // Free memory
  FPDF.IPDF_QPDF_FreeString(jsonPtr);
}
Module._free(pdfPtr);
```

## Key Changes Summary

### BUILD.gn
- Added `"third_party/qpdf:libqpdf"` to deps

### core/fxcrt/BUILD.gn
- Changed `if (is_posix)` to `if (is_posix || is_wasm)` for POSIX file access

### core/fxge/BUILD.gn
- Changed `if (is_linux || is_chromeos)` to `if (is_linux || is_chromeos || is_wasm)` for Linux implementation

### public/ipdf_qpdf.h (NEW)
- Declares IPDF_QPDF_PDFToJSON and IPDF_QPDF_FreeString APIs
- Follows PDFium API conventions with FPDF_EXPORT and FPDF_CALLCONV

### fpdfsdk/fpdf_qpdf.cpp (NEW)
- Implements PDF-to-JSON conversion using QPDF library
- Handles memory management with malloc/free for cross-language compatibility
- Comprehensive error handling

## Troubleshooting

### Build Errors
If you encounter build errors:

1. Ensure QPDF is properly installed in `third_party/qpdf/`
2. Verify QPDF BUILD.gn exists at `third_party/qpdf/BUILD.gn`
3. Check that QPDF headers are accessible

### WASM Export Errors
If functions are not exported:

1. Check `modules/wasm.py` includes the functions in the export list
2. Ensure function names have underscore prefix: `_IPDF_QPDF_PDFToJSON`
3. Regenerate WASM: `python3 make.py generate-wasm`

## License

This integration follows PDFium's BSD-style license and QPDF's Apache 2.0 license.

## Support

For issues related to:
- PDFium: https://pdfium.googlesource.com/pdfium.git
- QPDF: https://github.com/qpdf/qpdf
- This integration: Contact the project maintainer
