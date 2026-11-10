// Headless-Chromium check: open the page, wait for "Hello World" in the
// xterm.js terminal, and save a screenshot.
//
// Usage: node scripts/browser-test.mjs [url] [screenshot.png]
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const url = process.argv[2] || 'http://127.0.0.1:8088/';
const shot = process.argv[3] || 'hello-world.png';

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
page.on('console', (m) => console.log(`[console.${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => console.log(`[pageerror] ${e.message}`));

const t0 = Date.now();
await page.goto(url);
console.log('crossOriginIsolated =', await page.evaluate(() => crossOriginIsolated));
let ok = false;
try {
  await page.waitForFunction(
    () => document.querySelector('.xterm-rows')?.innerText.includes('Hello World'),
    null, { timeout: 120000 });
  ok = true;
} catch { /* fall through and report */ }
const terminal = await page.evaluate(() => document.querySelector('.xterm-rows')?.innerText.trim());
console.log('terminal text:', JSON.stringify(terminal));
console.log(ok ? `PASS: "Hello World" after ${((Date.now() - t0) / 1000).toFixed(1)} s`
               : 'FAIL: "Hello World" not seen within 120 s');
await page.screenshot({ path: shot });
await browser.close();
process.exit(ok ? 0 : 1);
