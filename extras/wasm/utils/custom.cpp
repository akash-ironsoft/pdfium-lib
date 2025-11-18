#include "fpdfview.h"
#include <emscripten.h>
#include <string>
#include <sstream>
#include <cstring>

// QPDF includes
#include "qpdf/QPDF.hh"
#include "qpdf/QPDFWriter.hh"
#include "qpdf/Pl_String.hh"
#include "qpdf/QUtil.hh"

#ifdef __cplusplus
extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE void PDFium_Init();
    EMSCRIPTEN_KEEPALIVE char* QPDF_PDFToJSON(const unsigned char* pdf_bytes, size_t length, int version);
    EMSCRIPTEN_KEEPALIVE void QPDF_FreeString(char* str);

#ifdef __cplusplus
}
#endif

void PDFium_Init()
{
    // https://source.chromium.org/chromium/chromium/src/+/master:third_party/pdfium/samples/pdfium_test.cc;l=1172

    FPDF_LIBRARY_CONFIG config;
    config.version = 3;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    config.m_pPlatform = nullptr;

    FPDF_InitLibraryWithConfig(&config);
}

// Convert PDF bytes directly to JSON using QPDF
// Parameters:
//   pdf_bytes - pointer to PDF file bytes
//   length - size of PDF data
//   version - JSON format version (1 or 2, recommended: 2)
// Returns:
//   JSON string (caller must call QPDF_FreeString to free memory)
//   NULL on error
char* QPDF_PDFToJSON(const unsigned char* pdf_bytes, size_t length, int version)
{
    if (!pdf_bytes || length == 0) {
        return nullptr;
    }

    try {
        // Create QPDF instance
        QPDF qpdf;

        // Load PDF from memory buffer
        // IMPORTANT: The buffer must remain valid for the lifetime of QPDF object
        qpdf.processMemoryFile("wasm-pdf-buffer",
                              reinterpret_cast<const char*>(pdf_bytes),
                              length);

        // Setup output pipeline to capture JSON as string
        std::string json_output;
        Pl_String json_pipeline("json-output", nullptr, json_output);

        // Generate JSON
        // Parameters:
        //   version - JSON format version (2 is recommended)
        //   pipeline - output destination
        //   decode_level - qpdf_dl_generalized (decode streams for better text extraction)
        //   json_stream_data - qpdf_sj_inline (include stream data as base64)
        //   file_prefix - empty (don't write external files)
        //   wanted_objects - empty set (include all objects)
        qpdf.writeJSON(
            version,                           // JSON version
            &json_pipeline,                    // Output pipeline
            qpdf_stream_decode_level_e::qpdf_dl_generalized,  // Decode streams
            qpdf_json_stream_data_e::qpdf_sj_inline,          // Inline stream data
            "",                                // No file prefix
            std::set<std::string>()           // All objects
        );

        // Finish the pipeline to flush output
        json_pipeline.finish();

        // Allocate C string and copy result
        // Caller must free this with QPDF_FreeString()
        char* result = static_cast<char*>(malloc(json_output.length() + 1));
        if (result) {
            std::memcpy(result, json_output.c_str(), json_output.length());
            result[json_output.length()] = '\0';
        }

        return result;

    } catch (const std::exception& e) {
        // QPDF throws exceptions on errors
        // Return NULL to indicate error
        return nullptr;
    } catch (...) {
        // Catch any other exceptions
        return nullptr;
    }
}

// Free string allocated by QPDF_PDFToJSON
void QPDF_FreeString(char* str)
{
    if (str) {
        free(str);
    }
}
