const { chromium } = require('playwright');
const fs = require('fs');

async function run() {
  const url = process.argv[2];
  if (!url) {
    console.error('Usage: node src/inspect.js <url>');
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  const page = await context.newPage();

  const networkLogs = [];
  const consoleLogs = [];

  // Capture Console Logs
  page.on('console', msg => {
    consoleLogs.push({
      type: msg.type(),
      text: msg.text(),
      location: msg.location()
    });
  });

  // Capture Network Activity
  page.on('response', async response => {
    try {
      const request = response.request();
      const resourceType = request.resourceType();
      
      // Filter out static assets to focus on API/Document
      if (['image', 'font', 'stylesheet', 'media'].includes(resourceType)) {
        return;
      }

      const status = response.status();
      const headers = response.headers();
      let body = null;

      // Try to get response body
      try {
        const buffer = await response.body();
        if (buffer.length < 1024 * 1024) { // 1MB limit
          const text = buffer.toString('utf8');
          // Try to parse JSON
          try {
            body = JSON.parse(text);
          } catch (e) {
            body = text.substring(0, 5000); // Truncate long text
            if (text.length > 5000) body += '... (truncated)';
          }
        } else {
            body = '[Body too large]';
        }
      } catch (e) {
        body = `[Error reading body: ${e.message}]`;
      }

      networkLogs.push({
        url: response.url(),
        method: request.method(),
        status,
        type: resourceType,
        headers, // Consider filtering headers if too verbose
        body
      });
    } catch (e) {
      console.error('Error processing response:', e);
    }
  });

  try {
    console.error(`Navigating to ${url}...`);
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    
    // Wait a bit for any delayed hydration
    await page.waitForTimeout(1000);

    const title = await page.title();
    
    // Get Accessibility Snapshot if available
    let snapshot = null;
    if (page.accessibility) {
        try {
            snapshot = await page.accessibility.snapshot();
        } catch (e) {
            // Ignore accessibility errors
        }
    }

    // Get HTML
    const content = await page.content();

    const result = {
      metadata: {
        url,
        title,
        timestamp: new Date().toISOString()
      },
      console: consoleLogs,
      network: networkLogs,
      accessibilityTree: snapshot,
      html: content
    };

    console.log(JSON.stringify(result, null, 2));

  } catch (error) {
    console.error('Error during inspection:', error);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

run();
