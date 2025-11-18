// Copyright 2024 PDFium-QPDF Integration. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "public/ipdf_qpdf.h"

#include <cstdlib>
#include <cstring>
#include <memory>
#include <sstream>

// QPDF library headers
#include "qpdf/QPDF.hh"
#include "qpdf/QPDFWriter.hh"
#include "qpdf/Pl_String.hh"
#include "qpdf/Pl_Buffer.hh"
#include "qpdf/Buffer.hh"
#include "qpdf/BufferInputSource.hh"
#include "qpdf/Constants.h"

/**
 * IPDF_QPDF_PDFToJSON
 *
 * Converts a PDF document to QPDF JSON format.
 *
 * Implementation notes:
 * - Uses QPDF library for PDF parsing and JSON generation
 * - Stack-allocated QPDF object ensures automatic cleanup on exception
 * - Pipeline-based output using Pl_String for efficient string building
 * - Comprehensive error handling with try-catch
 * - C-style memory management (malloc) for cross-language compatibility
 */
FPDF_EXPORT char* FPDF_CALLCONV IPDF_QPDF_PDFToJSON(const void* pdf_data,
                                                      size_t pdf_size,
                                                      int version) {
  // Validate input parameters
  if (!pdf_data || pdf_size == 0) {
    return nullptr;
  }

  // Validate version parameter (QPDF supports versions 1 and 2)
  if (version != 1 && version != 2) {
    return nullptr;
  }

  try {
    // Create QPDF object (stack-allocated for automatic cleanup)
    QPDF qpdf;

    // Create buffer input source from PDF data
    // BufferInputSource takes ownership of the Buffer when own_memory=true
    Buffer* buffer = new Buffer(pdf_size);
    std::memcpy(buffer->getBuffer(), pdf_data, pdf_size);

    auto input_source = std::make_shared<BufferInputSource>(
        "memory-buffer", buffer, true);  // true = own_memory, QPDF will delete buffer

    // Process the PDF from memory
    qpdf.processInputSource(input_source);

    // Create string pipeline for JSON output
    std::string json_output;
    Pl_String pl_string("json", nullptr, json_output);

    // Write JSON to the pipeline
    // version parameter controls JSON format (1 or 2)
    // Use qpdf_dl_none for no decoding, qpdf_sj_none for no stream data, empty set for all objects
    qpdf.writeJSON(
        version,
        &pl_string,
        qpdf_dl_none,           // decode_level: preserve all stream filters
        qpdf_sj_none,           // json_stream_data: no stream data inline
        "",                     // file_prefix: empty
        std::set<std::string>() // wanted_objects: empty = all objects
    );

    // Finish the pipeline to ensure all data is flushed
    pl_string.finish();

    // Allocate C-style string for return
    // Must be freed by caller using IPDF_QPDF_FreeString
    size_t json_size = json_output.size();
    char* result = static_cast<char*>(std::malloc(json_size + 1));

    if (!result) {
      // Memory allocation failed
      return nullptr;
    }

    // Copy JSON data to allocated buffer
    std::memcpy(result, json_output.c_str(), json_size);
    result[json_size] = '\0';  // Null-terminate

    return result;

  } catch (const std::exception& e) {
    // QPDF or std::exception - return NULL to indicate error
    // In production, could log error message: e.what()
    return nullptr;
  } catch (...) {
    // Unknown exception - return NULL
    return nullptr;
  }
}

/**
 * IPDF_QPDF_FreeString
 *
 * Frees a string allocated by IPDF_QPDF_PDFToJSON.
 *
 * Implementation notes:
 * - Simple wrapper around std::free()
 * - Safe to call with NULL pointer (no-op)
 * - Must only be called on strings returned by IPDF_QPDF_PDFToJSON
 */
FPDF_EXPORT void FPDF_CALLCONV IPDF_QPDF_FreeString(char* str) {
  if (str) {
    std::free(str);
  }
}
