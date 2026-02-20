# Cursor DevTools Inspector

A tool to capture DevTools-like information (Network requests/responses, DOM structure, Console logs) using Playwright, designed for AI analysis within Cursor.

## Setup

1. Install dependencies:
   ```bash
   cd projects/cursor-devtools-inspector
   npm install
   npx playwright install chromium
   ```

## Usage

Run from Cursor terminal or command palette:

```bash
./projects/cursor-devtools-inspector/bin/cursor-inspector <url>
```

## Output

The tool outputs a JSON object to stdout containing:

- `metadata`: URL, Title, Timestamp
- `console`: Array of console logs
- `network`: Array of network requests (including response bodies for text/json)
- `accessibilityTree`: Accessibility tree snapshot (if available)
- `html`: Full HTML content

## AI Analysis

Pipe the output to a file or let Cursor read the stdout directly to analyze:

- API response structures
- DOM elements and hierarchy
- Console errors
