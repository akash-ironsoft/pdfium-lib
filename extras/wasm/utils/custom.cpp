#include "fpdfview.h"
#include <emscripten.h>
#include <string>
#include <sstream>
#include <cstring>

// QPDF integration - public API
#include "public/ipdf_qpdf.h"

#ifdef __cplusplus
extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE void PDFium_Init();

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

// Note: QPDF integration functions (IPDF_QPDF_PDFToJSON, IPDF_QPDF_FreeString)
// are implemented in fpdfsdk/fpdf_qpdf.cpp following PDFium's API conventions.

// Function names exported to WebAssembly
// These functions will be available to JavaScript via Module.ccall()/Module.cwrap()
const char* FunctionNames[] = {
    // PDFium initialization
    "PDFium_Init",

    // QPDF integration - PDF to JSON conversion
    "IPDF_QPDF_PDFToJSON",
    "IPDF_QPDF_FreeString",
};
