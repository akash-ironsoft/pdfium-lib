// Copyright 2024 PDFium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef EXTRAS_WASM_UTILS_QPDF_WASM_H_
#define EXTRAS_WASM_UTILS_QPDF_WASM_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Convert a PDF document to QPDF JSON format
//
// Parameters:
//   pdf_bytes - Pointer to PDF file data in memory
//   length    - Size of PDF data in bytes
//   version   - QPDF JSON format version (1 or 2, recommended: 2)
//
// Returns:
//   Pointer to JSON string (must be freed with QPDF_FreeString)
//   NULL on error
//
// Memory Management:
//   The returned string is allocated with malloc() and must be freed
//   by calling QPDF_FreeString() when no longer needed.
//
// QPDF JSON Format:
//   Version 1: Original QPDF JSON format
//   Version 2: Improved format with better stream handling (recommended)
//
// Example Usage:
//   char* json = QPDF_PDFToJSON(pdf_data, pdf_size, 2);
//   if (json) {
//       // Use json string...
//       QPDF_FreeString(json);
//   }
char* QPDF_PDFToJSON(const unsigned char* pdf_bytes,
                     size_t length,
                     int version);

// Free memory allocated by QPDF_PDFToJSON
//
// Parameters:
//   str - Pointer returned by QPDF_PDFToJSON
//
// Note:
//   It is safe to pass NULL to this function
void QPDF_FreeString(char* str);

#ifdef __cplusplus
}
#endif

#endif  // EXTRAS_WASM_UTILS_QPDF_WASM_H_
