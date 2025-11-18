// Copyright 2024 PDFium-QPDF Integration. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PUBLIC_IPDF_QPDF_H_
#define PUBLIC_IPDF_QPDF_H_

#include "fpdfview.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Function: IPDF_QPDF_PDFToJSON
 *          Convert a PDF document to QPDF JSON format.
 *
 * Parameters:
 *          pdf_data    -   Pointer to the PDF file data in memory.
 *          pdf_size    -   Size of the PDF file data in bytes.
 *          version     -   QPDF JSON version (1 or 2).
 *                          Version 1: Basic JSON structure
 *                          Version 2: Extended JSON with more details
 *
 * Return value:
 *          A pointer to a null-terminated C string containing the JSON data.
 *          Returns NULL if the conversion fails.
 *
 * Comments:
 *          The returned string is allocated with malloc() and must be freed
 *          by calling IPDF_QPDF_FreeString() when done.
 *
 *          The JSON format follows QPDF's JSON specification:
 *          - Version 1: Basic structure with objects and streams
 *          - Version 2: Enhanced with encryption info, object streams, etc.
 *
 *          Example usage:
 *              char* json = IPDF_QPDF_PDFToJSON(pdf_data, size, 2);
 *              if (json) {
 *                  // Use the JSON data...
 *                  printf("%s\n", json);
 *
 *                  // Free when done
 *                  IPDF_QPDF_FreeString(json);
 *              }
 *
 * Error handling:
 *          Returns NULL on error. Possible causes:
 *          - Invalid PDF data
 *          - Insufficient memory
 *          - QPDF processing error
 *          - Invalid version parameter
 */
FPDF_EXPORT char* FPDF_CALLCONV IPDF_QPDF_PDFToJSON(const void* pdf_data,
                                                      size_t pdf_size,
                                                      int version);

/**
 * Function: IPDF_QPDF_FreeString
 *          Free a string allocated by IPDF_QPDF_PDFToJSON.
 *
 * Parameters:
 *          str         -   Pointer to the string to free.
 *
 * Return value:
 *          None.
 *
 * Comments:
 *          This function must be called to free strings returned by
 *          IPDF_QPDF_PDFToJSON() to prevent memory leaks.
 *
 *          Do not call this function with:
 *          - NULL pointers (safe to call, but no-op)
 *          - Pointers not returned by IPDF_QPDF_PDFToJSON()
 *          - Already freed pointers (undefined behavior)
 *
 *          Example usage:
 *              char* json = IPDF_QPDF_PDFToJSON(pdf_data, size, 2);
 *              if (json) {
 *                  // Use json...
 *                  IPDF_QPDF_FreeString(json);
 *              }
 */
FPDF_EXPORT void FPDF_CALLCONV IPDF_QPDF_FreeString(char* str);

#ifdef __cplusplus
}
#endif

#endif  // PUBLIC_IPDF_QPDF_H_
