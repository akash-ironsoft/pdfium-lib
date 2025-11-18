# QPDF Integration Changes

This document describes all changes made to PDFium for QPDF integration.

## Summary

This integration adds PDF-to-JSON conversion functionality to PDFium using the QPDF library. The integration follows PDFium's API conventions and is designed for WebAssembly (WASM) builds.

## Files Added

### 1. public/ipdf_qpdf.h
**Purpose:** Public API header for QPDF integration

**Key Elements:**
- `IPDF_QPDF_PDFToJSON()` - Converts PDF to QPDF JSON format
- `IPDF_QPDF_FreeString()` - Frees strings allocated by the conversion function
- Uses `FPDF_EXPORT` and `FPDF_CALLCONV` macros for proper linkage
- Includes comprehensive documentation with examples

**API Design:**
- Follows PDFium naming convention (IPDF prefix for Integrated PDF functions)
- C-compatible interface for WASM export
- Memory management uses malloc/free for cross-language compatibility
- Supports QPDF JSON version 1 and 2

### 2. fpdfsdk/fpdf_qpdf.cpp
**Purpose:** Implementation of QPDF integration functions

**Implementation Details:**
- Uses QPDF library for PDF parsing and JSON generation
- Input validation for pdf_data, pdf_size, and version parameters
- Creates BufferInputSource from in-memory PDF data
- Uses Pl_String pipeline for efficient JSON string building
- Comprehensive error handling with try-catch blocks
- Returns nullptr on any error condition

**Key Functions:**
```cpp
char* IPDF_QPDF_PDFToJSON(const void* pdf_data, size_t pdf_size, int version)
void IPDF_QPDF_FreeString(char* str)
```

**Memory Management:**
- Buffer ownership transferred to QPDF (own_memory=true)
- JSON output allocated with std::malloc for C compatibility
- Caller must free returned string with IPDF_QPDF_FreeString()

**QPDF Configuration:**
- decode_level: qpdf_dl_none (preserve stream filters)
- json_stream_data: qpdf_sj_none (no inline stream data)
- wanted_objects: empty set (include all objects)

## Files Modified

### 1. BUILD.gn (Main build file)
**Location:** Root directory

**Changes:**
```gn
deps = [
  # ... existing deps ...
  "third_party/qpdf:libqpdf",  # ADDED
]
```

**Purpose:** Links QPDF library into the main PDFium component

**Line Number:** ~239 (in deps array of "pdfium" component)

---

### 2. core/fxcrt/BUILD.gn
**Location:** core/fxcrt/BUILD.gn

**Changes:**
```gn
# Before:
if (is_posix) {
  sources += [
    "cfx_fileaccess_posix.cpp",
    "cfx_fileaccess_posix.h",
  ]
}

# After:
if (is_posix || is_wasm) {
  sources += [
    "cfx_fileaccess_posix.cpp",
    "cfx_fileaccess_posix.h",
  ]
}
```

**Purpose:** Enables POSIX file access for WASM builds

**Reasoning:** WASM environment uses POSIX-like file operations through Emscripten

**Line Number:** ~162 (in source_set("fxcrt"))

---

### 3. core/fxge/BUILD.gn
**Location:** core/fxge/BUILD.gn

**Changes:**
```gn
# Before:
if (is_linux || is_chromeos) {
  sources += [ "linux/fx_linux_impl.cpp" ]
}

# After:
if (is_linux || is_chromeos || is_wasm) {
  sources += [ "linux/fx_linux_impl.cpp" ]
}
```

**Purpose:** Enables Linux graphics implementation for WASM builds

**Reasoning:** WASM uses Linux-compatible graphics implementation

**Line Number:** ~166 (in source_set("fxge"))

## Build System Integration

### GN Build Configuration
The integration requires:
1. QPDF library built as a static library (libqpdf)
2. QPDF BUILD.gn file in third_party/qpdf/
3. QPDF headers accessible via include paths

### Compiler Flags Required
QPDF requires:
- `-frtti` (Run-Time Type Information)
- `-fexceptions` (C++ exception handling)

These are configured in third_party/qpdf/BUILD.gn

## WASM Export Configuration

The functions must be exported in the WASM build. This is configured in `modules/wasm.py`:

```python
function_list.extend([
    "_malloc",
    "_free",
    "_IPDF_QPDF_PDFToJSON",      # Added
    "_IPDF_QPDF_FreeString"       # Added
])
```

**Note:** Underscore prefix is required for C function exports in Emscripten.

## API Compatibility

### QPDF Version Requirements
- Tested with QPDF 11.x
- Uses modern QPDF API (not deprecated functions)
- writeJSON() method signature:
  ```cpp
  void writeJSON(
      int version,
      Pipeline* p,
      qpdf_stream_decode_level_e decode_level,
      qpdf_json_stream_data_e json_stream_data,
      std::string const& file_prefix,
      std::set<std::string> const& wanted_objects
  )
  ```

### Error Handling
- Returns nullptr on any error
- No exceptions thrown to caller
- All QPDF exceptions caught internally
- Safe to call from any language binding

## Testing

### Test Scenarios Covered
1. Valid PDF conversion (2MB PDF file)
2. Invalid PDF data handling
3. Null pointer checks
4. Invalid version parameter (not 1 or 2)
5. Memory allocation failures
6. QPDF parsing errors

### Example Test Results
```
✓ Converting infinistore.pdf (2010533 bytes)
✓ JSON output generated successfully
✓ Memory freed without leaks
```

## Dependencies

### Direct Dependencies
- QPDF library (third_party/qpdf/)
- PDFium core (fpdfview.h)

### QPDF Dependencies
- Standard C++ library
- zlib (compression)
- libjpeg (JPEG handling)

## Performance Considerations

### Memory Usage
- In-memory PDF processing (no temp files)
- Single allocation for JSON output
- Immediate cleanup after conversion

### Processing Speed
- Depends on PDF complexity
- JSON version 2 slower than version 1 (more details)
- No optimization for streaming (full document in memory)

## Security Considerations

### Input Validation
- PDF data pointer checked for nullptr
- PDF size validated (>0)
- Version parameter validated (1 or 2)

### Memory Safety
- All allocations checked for nullptr
- RAII used for automatic cleanup
- Exception handling prevents crashes

### Attack Surface
- PDF parsing handled by QPDF (battle-tested library)
- No custom PDF parser code
- Buffer overflow protection via Buffer class

## Future Enhancements

### Potential Improvements
1. Streaming JSON output for large PDFs
2. Progress callbacks for long operations
3. Configurable decode level options
4. Stream data inclusion options
5. Object filtering by object numbers
6. Error message reporting

### API Extensions
```cpp
// Potential future API
char* IPDF_QPDF_PDFToJSONEx(
    const void* pdf_data,
    size_t pdf_size,
    const IPDF_QPDF_Options* options,
    IPDF_QPDF_ErrorInfo* error_info
);
```

## Rollback Instructions

If you need to remove the QPDF integration:

1. Remove the new files:
   ```bash
   rm public/ipdf_qpdf.h
   rm fpdfsdk/fpdf_qpdf.cpp
   ```

2. Restore original BUILD.gn files from backups:
   ```bash
   cp .backup-qpdf-integration/BUILD.gn.bak BUILD.gn
   cp .backup-qpdf-integration/fxcrt-BUILD.gn.bak core/fxcrt/BUILD.gn
   cp .backup-qpdf-integration/fxge-BUILD.gn.bak core/fxge/BUILD.gn
   ```

3. Remove QPDF exports from modules/wasm.py

4. Rebuild PDFium

## Changelog

### Version 1.0 (PDF-2105)
- Initial QPDF integration
- Add IPDF_QPDF_PDFToJSON and IPDF_QPDF_FreeString APIs
- WASM build support
- Memory-safe implementation
- Comprehensive error handling

## References

- PDFium Source: https://pdfium.googlesource.com/pdfium.git
- QPDF Library: https://github.com/qpdf/qpdf
- QPDF JSON Format: https://qpdf.readthedocs.io/en/stable/json.html
- Emscripten: https://emscripten.org/

## License

This integration code is licensed under the same BSD-style license as PDFium.
QPDF is licensed under Apache 2.0 License.
