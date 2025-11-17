#include <iostream>
#include <vector>
#include <string>

#include "fpdfview.h"
#include "fpdf_text.h"

int main(int argc, char **argv)
{
    // sample: https://github.com/lukas-w/pdfium/blob/master/docs/getting-started.md

    std::cout << "========================================" << std::endl;
    std::cout << "PDFium WASM - Text Extraction Demo" << std::endl;
    std::cout << "chromium/7258 (commit: bbdc38bc)" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;
    std::cout << "Initializing PDFium library..." << std::endl;

    FPDF_LIBRARY_CONFIG config;
    config.version = 3;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    config.m_pPlatform = nullptr;

    FPDF_InitLibraryWithConfig(&config);

    std::cout << "Loading PDF document..." << std::endl;

    FPDF_STRING testDoc = "assets/web-assembly.pdf";
    FPDF_DOCUMENT doc = FPDF_LoadDocument(testDoc, nullptr);

    std::cout << "Validating document..." << std::endl;

    if (!doc)
    {
        unsigned long err = FPDF_GetLastError();
        std::cout << "ERROR: Failed to load PDF: ";

        switch (err)
        {
        case FPDF_ERR_SUCCESS:
            std::cout << "Success" << std::endl;
            break;
        case FPDF_ERR_UNKNOWN:
            std::cout << "Unknown error" << std::endl;
            break;
        case FPDF_ERR_FILE:
            std::cout << "File not found or could not be opened" << std::endl;
            break;
        case FPDF_ERR_FORMAT:
            std::cout << "File not in PDF format or corrupted" << std::endl;
            break;
        case FPDF_ERR_PASSWORD:
            std::cout << "Password required or incorrect password" << std::endl;
            break;
        case FPDF_ERR_SECURITY:
            std::cout << "Unsupported security scheme" << std::endl;
            break;
        case FPDF_ERR_PAGE:
            std::cout << "Page not found or content error" << std::endl;
            break;
        default:
            std::cout << "Unknown error " << err << std::endl;
        }

        std::cout << std::endl;

        FPDF_DestroyLibrary();

        return EXIT_FAILURE;
    }

    int pageCount = FPDF_GetPageCount(doc);
    std::cout << std::endl;
    std::cout << "SUCCESS! Document loaded." << std::endl;
    std::cout << "Total pages: " << pageCount << std::endl;
    std::cout << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "Extracting text from all pages..." << std::endl;
    std::cout << "========================================" << std::endl;

    // Extract text from each page
    for (int i = 0; i < pageCount; i++)
    {
        std::cout << std::endl;
        std::cout << "--- PAGE " << (i + 1) << " of " << pageCount << " ---" << std::endl;

        // Load the page
        FPDF_PAGE page = FPDF_LoadPage(doc, i);
        if (!page)
        {
            std::cout << "ERROR: Failed to load page " << (i + 1) << std::endl;
            continue;
        }

        // Get page dimensions
        double width = FPDF_GetPageWidth(page);
        double height = FPDF_GetPageHeight(page);
        std::cout << "Page size: " << width << " x " << height << " points" << std::endl;

        // Load text page
        FPDF_TEXTPAGE textPage = FPDFText_LoadPage(page);
        if (!textPage)
        {
            std::cout << "ERROR: Failed to load text from page " << (i + 1) << std::endl;
            FPDF_ClosePage(page);
            continue;
        }

        // Count characters
        int charCount = FPDFText_CountChars(textPage);
        std::cout << "Total characters: " << charCount << std::endl;
        std::cout << std::endl;
        std::cout << "Text content:" << std::endl;
        std::cout << "----------------------------------------" << std::endl;

        // Extract text (using UTF-16)
        if (charCount > 0)
        {
            // Allocate buffer for UTF-16 text
            std::vector<unsigned short> buffer(charCount + 1);

            // Get text
            int extractedChars = FPDFText_GetText(textPage, 0, charCount, buffer.data());

            if (extractedChars > 0)
            {
                // Convert UTF-16 to UTF-8 for display
                std::string text;
                for (int j = 0; j < extractedChars - 1; j++)
                {
                    unsigned short ch = buffer[j];
                    if (ch < 0x80)
                    {
                        text += static_cast<char>(ch);
                    }
                    else if (ch < 0x800)
                    {
                        text += static_cast<char>((ch >> 6) | 0xC0);
                        text += static_cast<char>((ch & 0x3F) | 0x80);
                    }
                    else
                    {
                        text += static_cast<char>((ch >> 12) | 0xE0);
                        text += static_cast<char>(((ch >> 6) & 0x3F) | 0x80);
                        text += static_cast<char>((ch & 0x3F) | 0x80);
                    }
                }

                std::cout << text << std::endl;
            }
            else
            {
                std::cout << "(No text extracted)" << std::endl;
            }
        }
        else
        {
            std::cout << "(Empty page or no text found)" << std::endl;
        }

        std::cout << "----------------------------------------" << std::endl;

        // Cleanup
        FPDFText_ClosePage(textPage);
        FPDF_ClosePage(page);
    }

    std::cout << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "Text extraction completed!" << std::endl;
    std::cout << "========================================" << std::endl;

    FPDF_CloseDocument(doc);

    FPDF_DestroyLibrary();

    return EXIT_SUCCESS;
}