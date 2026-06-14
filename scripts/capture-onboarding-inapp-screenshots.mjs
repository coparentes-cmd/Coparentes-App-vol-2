/**
 * Captures in-app onboarding screenshots (settings, sheets, child panel).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.join(__dirname, '..', 'docs', 'assets', 'onboarding');
const APP_URL = process.env.COPARENTES_APP_URL ?? 'https://getcoparentes.app';
const VIEWPORT = { width: 390, height: 844, deviceScaleFactor: 2 };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function enableA11y(page) {
  await page.evaluate(() =>
    document.querySelector('flt-semantics-placeholder[role="button"]')?.click(),
  );
  await sleep(600);
}

async function wheelDown(page, times = 5) {
  for (let i = 0; i < times; i++) {
    await page.mouse.wheel({ deltaY: 320 });
    await sleep(220);
  }
}

async function tap(page, x, y) {
  await page.mouse.click(x, y);
  await sleep(1200);
}

async function tapLabel(page, label) {
  const ok = await page.evaluate((target) => {
    for (const el of document.querySelectorAll('flt-semantics')) {
      const aria = (el.getAttribute('aria-label') ?? '').trim();
      if (aria.includes(target)) {
        el.click();
        return true;
      }
    }
    return false;
  }, label);
  if (ok) await sleep(1100);
  return ok;
}

async function shot(page, filename) {
  await page.screenshot({ path: path.join(OUT_DIR, filename) });
  console.log(`Saved ${filename}`);
}

async function openDemoParentA(page) {
  await page.goto(APP_URL, { waitUntil: 'networkidle2', timeout: 120_000 });
  await sleep(3000);
  await enableA11y(page);
  await wheelDown(page, 6);
  if (!(await tapLabel(page, 'Rodzic A'))) {
    await tap(page, 92, 518);
  }
  await sleep(2500);
  await enableA11y(page);
}

async function openSettings(page) {
  if (!(await tapLabel(page, 'Ustawienia'))) {
    await tap(page, 352, 74);
  }
  await sleep(1500);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    executablePath:
      process.env.PUPPETEER_EXECUTABLE_PATH ??
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);

  try {
    await openDemoParentA(page);
    await openSettings(page);
    await shot(page, '03-ustawienia-kody.png');

    if (await tapLabel(page, 'Zaproś drugiego rodzica mailem')) {
      await sleep(800);
      await shot(page, '04-zaproszenie-email.png');
      await page.keyboard.press('Escape');
      await sleep(700);
      await openSettings(page);
    }

    await wheelDown(page, 2);
    await sleep(400);
    await shot(page, '07-kod-dziecka.png');

    if (await tapLabel(page, 'Dodaj dziecko')) {
      await sleep(900);
      await shot(page, '02-dodaj-dziecko-sheet.png');
      await page.keyboard.press('Escape');
      await sleep(700);
      await openSettings(page);
      await tapLabel(page, 'Dodaj dziecko');
      await sleep(900);
      await shot(page, '06-dodaj-kolejne-dziecko.png');
      await page.keyboard.press('Escape');
    }

    await page.goto(APP_URL, { waitUntil: 'networkidle2', timeout: 120_000 });
    await sleep(3000);
    await enableA11y(page);
    await wheelDown(page, 6);
    if (!(await tapLabel(page, 'Dziecko'))) {
      await tap(page, 92, 602);
    }
    await sleep(2800);
    await shot(page, '09-panel-dziecka.png');
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
