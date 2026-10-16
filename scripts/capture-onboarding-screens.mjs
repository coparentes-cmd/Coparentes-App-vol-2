/**
 * Capture current Coparentes screens for PPTX (auth + demo settings).
 */
import puppeteer from 'puppeteer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', 'tmp_pptx_screens');
fs.mkdirSync(OUT, { recursive: true });

const W = 390;
const H = 844;

async function shot(page, name) {
  const file = path.join(OUT, `${name}.png`);
  await page.screenshot({ path: file, type: 'png' });
  console.log('saved', name);
}

async function pause(ms = 900) {
  await new Promise((r) => setTimeout(r, ms));
}

async function click(page, x, y) {
  await page.mouse.click(x, y);
  await pause(700);
}

async function main() {
  const browser = await puppeteer.launch({
    headless: true,
    executablePath:
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args: ['--no-sandbox', `--window-size=${W},${H}`],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 2 });
  await page.goto('https://getcoparentes.app/', {
    waitUntil: 'networkidle0',
    timeout: 90000,
  });
  await pause(2800);

  // 1. Login (adult)
  await shot(page, '01-logowanie');

  // 2. Registration tab (center tab ~ y 560–600 worked before)
  await click(page, W * 0.5, 580);
  await shot(page, '02-rejestracja');

  // Scroll registration form down via drag on canvas
  await page.mouse.move(W * 0.5, 720);
  await page.mouse.down();
  await page.mouse.move(W * 0.5, 320, { steps: 20 });
  await page.mouse.up();
  await pause(800);
  await shot(page, '03-rejestracja-formularz');

  await page.mouse.move(W * 0.5, 720);
  await page.mouse.down();
  await page.mouse.move(W * 0.5, 280, { steps: 20 });
  await page.mouse.up();
  await pause(800);
  await shot(page, '04-rejestracja-dol');

  // 3. Join tab — adult (second parent)
  await click(page, W * 0.82, 420);
  // If still scrolled, scroll up first
  await page.mouse.move(W * 0.5, 300);
  await page.mouse.down();
  await page.mouse.move(W * 0.5, 700, { steps: 15 });
  await page.mouse.up();
  await pause(800);
  await click(page, W * 0.82, 580);
  await click(page, W * 0.28, 650); // Dorosły
  await shot(page, '05-rodzic-dolacz');

  // 4. Join — child
  await click(page, W * 0.72, 650);
  await shot(page, '06-dziecko-dolacz');

  // 5. Demo mode — click tryb demo row (~ y 480)
  await page.goto('https://getcoparentes.app/', {
    waitUntil: 'networkidle0',
    timeout: 90000,
  });
  await pause(2800);
  await click(page, W * 0.5, 480);
  await pause(2000);
  await shot(page, '07-demo-attempt');

  // Try a few more demo click positions
  for (const y of [450, 500, 520, 540]) {
    await click(page, W * 0.45, y);
  }
  await pause(2500);
  await shot(page, '08-po-demo');

  await browser.close();
  console.log('done →', OUT);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
