# PDF Text Extraction Server

A Node.js Express server that extracts text from PDF files using PDFium WebAssembly.

## Features

- Upload PDF files and extract text content
- Page-by-page text extraction
- Full document text extraction
- RESTful API
- CORS enabled
- Built on PDFium (Chrome's PDF rendering engine)

## Prerequisites

- Node.js 18+ (for ES modules support)
- Built PDFium WASM files (located in `../build/emscripten/wasm/release/node/`)

## Installation

1. Navigate to the server directory:
```bash
cd pdf-text-server
```

2. Install dependencies:
```bash
npm install
```

## Usage

### Start the server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The server will start on `http://localhost:3000` by default.

### API Endpoints

#### 1. Health Check
```bash
GET /health
```

Response:
```json
{
  "status": "healthy",
  "pdfiumLoaded": true
}
```

#### 2. Extract Text from PDF
```bash
POST /extract-text
```

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: PDF file with field name `pdf`

**Example using cURL:**
```bash
curl -X POST http://localhost:3000/extract-text \
  -F "pdf=@/path/to/your/document.pdf"
```

**Example using JavaScript (fetch):**
```javascript
const formData = new FormData();
formData.append('pdf', pdfFile);

const response = await fetch('http://localhost:3000/extract-text', {
  method: 'POST',
  body: formData
});

const result = await response.json();
console.log(result);
```

**Response:**
```json
{
  "success": true,
  "filename": "document.pdf",
  "size": 245678,
  "pageCount": 5,
  "pages": [
    {
      "pageNumber": 1,
      "text": "Page 1 text content...",
      "characterCount": 1234
    },
    {
      "pageNumber": 2,
      "text": "Page 2 text content...",
      "characterCount": 987
    }
  ],
  "fullText": "Complete text from all pages..."
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Error message"
}
```

## Testing with Sample PDF

1. Use the sample PDF from the project:
```bash
curl -X POST http://localhost:3000/extract-text \
  -F "pdf=@../sample-wasm/assets/web-assembly.pdf"
```

2. Or create a test HTML file:

```html
<!DOCTYPE html>
<html>
<head>
  <title>PDF Text Extractor</title>
</head>
<body>
  <h1>PDF Text Extractor</h1>
  <input type="file" id="pdfFile" accept="application/pdf">
  <button onclick="extractText()">Extract Text</button>
  <pre id="result"></pre>

  <script>
    async function extractText() {
      const fileInput = document.getElementById('pdfFile');
      const file = fileInput.files[0];

      if (!file) {
        alert('Please select a PDF file');
        return;
      }

      const formData = new FormData();
      formData.append('pdf', file);

      try {
        const response = await fetch('http://localhost:3000/extract-text', {
          method: 'POST',
          body: formData
        });

        const result = await response.json();
        document.getElementById('result').textContent = JSON.stringify(result, null, 2);
      } catch (error) {
        alert('Error: ' + error.message);
      }
    }
  </script>
</body>
</html>
```

## Configuration

### Port
Change the port by setting the `PORT` environment variable:
```bash
PORT=8080 npm start
```

### File Size Limit
The default maximum file size is 50MB. To change it, edit `server.js`:
```javascript
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024, // Change to 100MB
  },
  // ...
});
```

## Error Handling

The server handles various error cases:

- **400 Bad Request**: No file provided or invalid file type
- **503 Service Unavailable**: PDFium module not initialized
- **500 Internal Server Error**: PDF processing errors

Common PDF errors:
- File not found or could not be opened
- File not in PDF format or corrupted
- Password protected PDFs
- Unsupported security schemes

## Architecture

The server uses:
- **Express.js**: Web framework
- **Multer**: File upload handling
- **PDFium WASM**: PDF processing engine
- **CORS**: Cross-origin resource sharing

### Text Extraction Process

1. PDF file is uploaded via multipart/form-data
2. File is stored in memory buffer
3. Buffer is allocated in WASM memory
4. PDFium loads the document
5. Each page is processed:
   - Load page
   - Create text page object
   - Extract characters as UTF-16
   - Convert to UTF-8 string
6. Results are returned as JSON

## Troubleshooting

### Module not found error
Make sure the PDFium WASM files exist:
```bash
ls -la ../build/emscripten/wasm/release/node/
```

You should see:
- `pdfium.js`
- `pdfium.wasm`
- `pdfium.esm.js` (optional)

### Server won't start
Check that Node.js version is 18 or higher:
```bash
node --version
```

### Text extraction returns empty
- Ensure the PDF contains actual text (not scanned images)
- Check if the PDF is password protected
- Verify the PDF is not corrupted

## Performance

- Small PDFs (< 1MB): ~100-500ms
- Medium PDFs (1-10MB): ~500ms-2s
- Large PDFs (10-50MB): ~2-10s

Performance depends on:
- PDF file size
- Number of pages
- Amount of text content
- Server hardware

## License

MIT

## Credits

Built with PDFium - Google's open-source PDF rendering engine.
