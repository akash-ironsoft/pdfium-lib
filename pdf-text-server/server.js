import express from 'express';
import multer from 'multer';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import PDFiumModule from '../build/emscripten/wasm/release/node/pdfium.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB max file size
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are allowed'), false);
    }
  },
});

// Global PDFium module
let Module = null;
let FPDF = {};

// Initialize PDFium
async function initializePDFium() {
  console.log('Initializing PDFium WASM module...');

  try {
    Module = await PDFiumModule();

    // Wrap PDFium functions
    FPDF.Init = Module.cwrap('PDFium_Init');
    FPDF.LoadMemDocument = Module.cwrap('FPDF_LoadMemDocument', 'number', ['number', 'number', 'string']);
    FPDF.GetPageCount = Module.cwrap('FPDF_GetPageCount', 'number', ['number']);
    FPDF.LoadPage = Module.cwrap('FPDF_LoadPage', 'number', ['number', 'number']);
    FPDF.ClosePage = Module.cwrap('FPDF_ClosePage', '', ['number']);
    FPDF.CloseDocument = Module.cwrap('FPDF_CloseDocument', '', ['number']);
    FPDF.GetLastError = Module.cwrap('FPDF_GetLastError', 'number');

    // Text extraction functions
    FPDF.Text_LoadPage = Module.cwrap('FPDFText_LoadPage', 'number', ['number']);
    FPDF.Text_ClosePage = Module.cwrap('FPDFText_ClosePage', '', ['number']);
    FPDF.Text_CountChars = Module.cwrap('FPDFText_CountChars', 'number', ['number']);
    FPDF.Text_GetText = Module.cwrap('FPDFText_GetText', 'number', ['number', 'number', 'number', 'number']);

    // QPDF functions for PDF-to-JSON
    FPDF.QPDF_PDFToJSON = Module.cwrap('QPDF_PDFToJSON', 'number', ['number', 'number', 'number']);
    FPDF.QPDF_FreeString = Module.cwrap('QPDF_FreeString', '', ['number']);

    // Initialize the library
    FPDF.Init();

    console.log('PDFium initialized successfully');
    return true;
  } catch (error) {
    console.error('Failed to initialize PDFium:', error);
    return false;
  }
}

// Get error message from PDFium error code
function getErrorMessage(errorCode) {
  const errors = {
    0: 'Success',
    1: 'Unknown error',
    2: 'File not found or could not be opened',
    3: 'File not in PDF format or corrupted',
    4: 'Password required or incorrect password',
    5: 'Unsupported security scheme',
    6: 'Page not found or content error',
  };
  return errors[errorCode] || `Unknown error code: ${errorCode}`;
}

// Convert UTF-16 buffer to UTF-8 string
function utf16ToUtf8(buffer) {
  let text = '';
  for (let i = 0; i < buffer.length - 1; i += 2) {
    const charCode = buffer[i] | (buffer[i + 1] << 8);
    if (charCode === 0) break;

    if (charCode < 0x80) {
      text += String.fromCharCode(charCode);
    } else if (charCode < 0x800) {
      text += String.fromCharCode(0xC0 | (charCode >> 6));
      text += String.fromCharCode(0x80 | (charCode & 0x3F));
    } else if (charCode < 0xD800 || charCode >= 0xE000) {
      text += String.fromCharCode(0xE0 | (charCode >> 12));
      text += String.fromCharCode(0x80 | ((charCode >> 6) & 0x3F));
      text += String.fromCharCode(0x80 | (charCode & 0x3F));
    } else {
      // Surrogate pair - handle 4-byte UTF-8
      const nextCharCode = buffer[i + 2] | (buffer[i + 3] << 8);
      i += 2;
      const codePoint = 0x10000 + (((charCode & 0x3FF) << 10) | (nextCharCode & 0x3FF));
      text += String.fromCharCode(0xF0 | (codePoint >> 18));
      text += String.fromCharCode(0x80 | ((codePoint >> 12) & 0x3F));
      text += String.fromCharCode(0x80 | ((codePoint >> 6) & 0x3F));
      text += String.fromCharCode(0x80 | (codePoint & 0x3F));
    }
  }
  return text;
}

// Extract text from PDF
function extractTextFromPDF(pdfBuffer) {
  try {
    // Allocate memory for PDF data
    const wasmBuffer = Module._malloc(pdfBuffer.length);
    Module.HEAPU8.set(pdfBuffer, wasmBuffer);

    // Load document
    const doc = FPDF.LoadMemDocument(wasmBuffer, pdfBuffer.length, '');

    if (!doc) {
      const errorCode = FPDF.GetLastError();
      Module._free(wasmBuffer);
      throw new Error(`Failed to load PDF: ${getErrorMessage(errorCode)}`);
    }

    // Get page count
    const pageCount = FPDF.GetPageCount(doc);
    console.log(`PDF has ${pageCount} pages`);

    const pages = [];

    // Extract text from each page
    for (let i = 0; i < pageCount; i++) {
      const page = FPDF.LoadPage(doc, i);

      if (!page) {
        console.warn(`Failed to load page ${i + 1}`);
        pages.push({
          pageNumber: i + 1,
          text: '',
          error: 'Failed to load page',
        });
        continue;
      }

      const textPage = FPDF.Text_LoadPage(page);

      if (!textPage) {
        console.warn(`Failed to load text from page ${i + 1}`);
        FPDF.ClosePage(page);
        pages.push({
          pageNumber: i + 1,
          text: '',
          error: 'Failed to load text',
        });
        continue;
      }

      const charCount = FPDF.Text_CountChars(textPage);
      let text = '';

      if (charCount > 0) {
        // Allocate buffer for UTF-16 text (2 bytes per character + null terminator)
        const bufferSize = (charCount + 1) * 2;
        const textBuffer = Module._malloc(bufferSize);

        // Get text
        const extractedChars = FPDF.Text_GetText(textPage, 0, charCount, textBuffer);

        if (extractedChars > 0) {
          // Read UTF-16 data from WASM memory
          const utf16Buffer = new Uint8Array(Module.HEAPU8.buffer, textBuffer, extractedChars * 2);

          // Convert to JavaScript string
          const uint16Array = new Uint16Array(utf16Buffer.buffer, utf16Buffer.byteOffset, extractedChars);
          text = String.fromCharCode.apply(null, Array.from(uint16Array).filter(c => c !== 0));
        }

        Module._free(textBuffer);
      }

      pages.push({
        pageNumber: i + 1,
        text: text.trim(),
        characterCount: charCount,
      });

      FPDF.Text_ClosePage(textPage);
      FPDF.ClosePage(page);
    }

    // Cleanup
    FPDF.CloseDocument(doc);
    Module._free(wasmBuffer);

    return {
      success: true,
      pageCount,
      pages,
      fullText: pages.map(p => p.text).join('\n\n'),
    };
  } catch (error) {
    console.error('Error extracting text:', error);
    throw error;
  }
}

// Convert PDF to JSON using QPDF
function convertPDFToJSON(pdfBuffer, version = 2) {
  try {
    // Allocate WASM memory for PDF bytes
    const wasmBuffer = Module._malloc(pdfBuffer.length);
    Module.HEAPU8.set(pdfBuffer, wasmBuffer);

    // Call QPDF function
    const jsonPtr = FPDF.QPDF_PDFToJSON(wasmBuffer, pdfBuffer.length, version);

    // Free the input buffer
    Module._free(wasmBuffer);

    if (!jsonPtr) {
      throw new Error('QPDF failed to convert PDF to JSON');
    }

    // Read JSON string from WASM memory
    const jsonString = Module.UTF8ToString(jsonPtr);

    // Free the JSON string
    FPDF.QPDF_FreeString(jsonPtr);

    // Parse and return JSON
    return JSON.parse(jsonString);
  } catch (error) {
    console.error('Error converting PDF to JSON:', error);
    throw error;
  }
}

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'PDF Text Extraction Server',
    version: '1.0.0',
    endpoints: {
      health: 'GET /health',
      extractText: 'POST /extract-text',
      pdfToJson: 'POST /pdf-to-json',
    },
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    pdfiumLoaded: Module !== null,
  });
});

app.post('/extract-text', upload.single('pdf'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No PDF file provided',
      });
    }

    if (!Module) {
      return res.status(503).json({
        success: false,
        error: 'PDFium module not initialized',
      });
    }

    console.log(`Processing PDF: ${req.file.originalname} (${req.file.size} bytes)`);

    const result = extractTextFromPDF(req.file.buffer);

    res.json({
      success: true,
      filename: req.file.originalname,
      size: req.file.size,
      ...result,
    });
  } catch (error) {
    console.error('Error processing PDF:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post('/pdf-to-json', upload.single('pdf'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No PDF file provided',
      });
    }

    if (!Module) {
      return res.status(503).json({
        success: false,
        error: 'PDFium module not initialized',
      });
    }

    console.log(`Converting PDF to JSON: ${req.file.originalname} (${req.file.size} bytes)`);

    // Get version from query parameter (default: 2)
    const version = parseInt(req.query.version) || 2;

    if (version !== 1 && version !== 2) {
      return res.status(400).json({
        success: false,
        error: 'Invalid version. Must be 1 or 2',
      });
    }

    const result = convertPDFToJSON(req.file.buffer, version);

    res.json({
      success: true,
      filename: req.file.originalname,
      size: req.file.size,
      version: version,
      qpdf: result,
    });
  } catch (error) {
    console.error('Error converting PDF to JSON:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size too large. Maximum size is 50MB.',
      });
    }
  }

  res.status(500).json({
    success: false,
    error: error.message || 'Internal server error',
  });
});

// Start server
async function startServer() {
  const initialized = await initializePDFium();

  if (!initialized) {
    console.error('Failed to initialize PDFium. Exiting...');
    process.exit(1);
  }

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log('Ready to process PDF files!');
  });
}

startServer();
