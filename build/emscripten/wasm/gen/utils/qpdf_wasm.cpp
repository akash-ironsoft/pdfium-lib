// Copyright 2024 PDFium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "extras/wasm/utils/qpdf_wasm.h"

#include <cstring>
#include <exception>
#include <set>
#include <string>

#include "qpdf/Constants.h"
#include "qpdf/Pipeline.hh"
#include "qpdf/Pl_String.hh"
#include "qpdf/QPDF.hh"

// Convert a PDF document to QPDF JSON format
//
// This function wraps QPDF's writeJSON functionality to provide a simple
// C-style interface suitable for WebAssembly exports.
//
// Technical Details:
// - Uses QPDF::processMemoryFile() to load PDF from memory buffer
// - Uses Pl_String pipeline to capture JSON output as string
// - Decodes streams with qpdf_dl_generalized for better text extraction
// - Includes stream data inline as base64 (qpdf_sj_inline)
// - Returns all PDF objects (empty wanted_objects set)
//
// Error Handling:
// - Returns nullptr if input is invalid (null pointer or zero length)
// - Returns nullptr if QPDF throws exception during processing
// - Caller should check return value before using
//
// Memory Management:
// - Allocates result with malloc() to avoid C++/C runtime mixing issues
// - Caller MUST free result with QPDF_FreeString() or memory leak occurs
// - QPDF object is stack-allocated and automatically cleaned up
//
// WASM Considerations:
// - Function uses "extern C" linkage for direct JavaScript calling
// - No C++ name mangling - function name is exactly "QPDF_PDFToJSON"
// - Memory allocated in WASM heap, accessible via Emscripten memory API
//
extern "C" char* QPDF_PDFToJSON(const unsigned char* pdf_bytes,
                                 size_t length,
                                 int version) {
  // Validate input parameters
  if (!pdf_bytes || length == 0) {
    return nullptr;
  }

  // Validate version (QPDF supports versions 1 and 2)
  if (version < 1 || version > 2) {
    return nullptr;
  }

  try {
    // Create QPDF instance
    // QPDF is the main class for PDF manipulation
    QPDF qpdf;

    // Load PDF from memory buffer
    // Parameters:
    //   - "wasm-pdf-buffer": Logical name for error messages
    //   - pdf_bytes: Pointer to PDF data
    //   - length: Size of PDF data
    //
    // Note: The buffer must remain valid for the lifetime of the QPDF object.
    // Since we're reading immediately and not keeping QPDF around, this is safe.
    qpdf.processMemoryFile("wasm-pdf-buffer",
                           reinterpret_cast<const char*>(pdf_bytes),
                           length);

    // Setup output pipeline to capture JSON as string
    // Pipeline is QPDF's abstraction for streaming output
    std::string json_output;
    Pl_String json_pipeline("json-output", nullptr, json_output);

    // Convert PDF to JSON
    // Parameters:
    //   - version: JSON format version (1 or 2)
    //     Version 2 is recommended - better stream handling, cleaner format
    //
    //   - &json_pipeline: Output destination
    //     Pl_String captures output into std::string
    //
    //   - qpdf_dl_generalized: Decode streams for better text extraction
    //     Decodes filters like FlateDecode, ASCIIHexDecode, etc.
    //
    //   - qpdf_sj_inline: Include stream data inline as base64
    //     Alternative is qpdf_sj_file which writes external files
    //
    //   - "": File prefix (empty = no external files)
    //     Used when qpdf_sj_file is specified
    //
    //   - empty set: Include all objects
    //     Could filter to specific objects if needed
    qpdf.writeJSON(
        version,                                           // JSON version
        &json_pipeline,                                    // Output pipeline
        qpdf_stream_decode_level_e::qpdf_dl_generalized,  // Decode streams
        qpdf_json_stream_data_e::qpdf_sj_inline,          // Inline stream data
        "",                                                 // No file prefix
        std::set<std::string>()                            // All objects
    );

    // Finish the pipeline to flush any buffered output
    json_pipeline.finish();

    // Allocate C string for result
    // Using malloc() instead of new[] to ensure compatibility with free()
    // +1 for null terminator
    char* result = static_cast<char*>(malloc(json_output.length() + 1));
    if (!result) {
      // malloc failed (out of memory)
      return nullptr;
    }

    // Copy JSON string to allocated buffer
    std::memcpy(result, json_output.c_str(), json_output.length());
    result[json_output.length()] = '\0';  // Null terminate

    return result;

  } catch (const std::exception& e) {
    // QPDF throws std::exception (or derived) on errors:
    // - Invalid PDF structure
    // - Encrypted PDF without password
    // - Corrupted data
    // - I/O errors
    //
    // We catch and return nullptr to indicate error
    // JavaScript layer should handle nullptr return
    return nullptr;

  } catch (...) {
    // Catch any other exceptions (shouldn't happen, but be safe)
    return nullptr;
  }
}

// Free memory allocated by QPDF_PDFToJSON
//
// This function provides a C-style interface for freeing memory allocated
// by QPDF_PDFToJSON. It's necessary because:
// 1. JavaScript cannot directly call free() in WASM memory
// 2. Ensures proper cleanup of C++ allocated memory
// 3. Prevents memory leaks in long-running applications
//
// Safety:
// - Passing nullptr is safe and does nothing (like standard free())
// - Memory MUST have been allocated by QPDF_PDFToJSON
// - Calling twice on same pointer is undefined behavior (like free())
//
extern "C" void QPDF_FreeString(char* str) {
  if (str) {
    free(str);
  }
}
