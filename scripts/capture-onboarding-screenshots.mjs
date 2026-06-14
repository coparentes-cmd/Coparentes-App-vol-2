/**
 * Captures onboarding guide screenshots from the live Coparentes web app.
 * Flutter Web canvas UI — uses viewport coordinates after mobile layout settles.
 *
 * Usage: node scripts/capture-onboarding-screenshots.mjs
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

async function waitForFlutter(page) {
  await page.goto(APP_URL, { waitUntil: 'networkidle2', timeout: 120_000 });
  await sleep(3500);
}

async function tap(page, x, y) {
  await page.mouse.click(x, y);
  await sleep(1100);
}

async function shot(page, filename) {
  const filePath = path.join(OUT_DIR, filename);
  await page.screenshot({ path: filePath, fullPage: false });
  console.log(`Saved ${filename}`);
}

async function tapSemanticsLabel(page, label) {
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
  if (ok) {
    await sleep(1100);
  }
  return ok;
}

async function enableAccessibility(page) {
  await page.evaluate(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder[role="button"]');
    placeholder?.click();
  });
  await sleep(800);
}

async function scrollTo(page, y) {
  await page.evaluate((top) => window.scrollTo(0, top), y);
  await sleep(500);
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
    await waitForFlutter(page);
    await enableAccessibility(page);

    // Auth tabs (mobile layout, second card)
    await scrollTo(page, 420);

    await tap(page, 132, 668);
    await shot(page, '01-nowa-rodzina.png');

    await tap(page, 248, 668);
    await shot(page, '05-rodzic-dolacz.png');

    await tap(page, 338, 668);
    await shot(page, '08-dziecko-logowanie.png');

    // Demo → Parent A dashboard
    await waitForFlutter(page);
    await scrollTo(page, 620);
    await enableAccessibility(page);
    if (!(await tapSemanticsLabel(page, 'Rodzic A'))) {
      await tap(page, 95, 760);
    }
    await sleep(2200);

    // Settings gear (top-right of parent home)
    if (!(await tapSemanticsLabel(page, 'Ustawienia'))) {
      await tap(page, 358, 48);
    }
    await sleep(1200);
    await shot(page, '03-ustawienia-kody.png');

    // Email invite sheet
    if (await tapSemanticsLabel(page, 'Zaproś drugiego rodzica mailem')) {
      await sleep(700);
      await shot(page, '04-zaproszenie-email.png');
      await page.keyboard.press('Escape');
      await sleep(600);
    } else {
      await tap(page, 195, 520);
      await sleep(700);
      await shot(page, '04-zaproszenie-email.png');
      await page.keyboard.press('Escape');
      await sleep(600);
    }

    // Child invite code row (scroll settings if needed)
    await scrollTo(page, 0);
    await sleep(300);
    if (!(await tapSemanticsLabel(page, 'Kod zaproszenia dziecka'))) {
      await tap(page, 195, 360);
    }
    await sleep(400);
    await shot(page, '07-kod-dziecka.png');

    // Add child sheet
    if (await tapSemanticsLabel(page, 'Dodaj dziecko')) {
      await sleep(900);
      await shot(page, '02-dodaj-dziecko-sheet.png');
      await page.keyboard.press('Escape');
      await sleep(700);
      await tapSemanticsLabel(page, 'Dodaj dziecko');
      await sleep(900);
      await shot(page, '06-dodaj-kolejne-dziecko.png');
      await page.keyboard.press('Escape');
    } else {
      await tap(page, 195, 620);
      await sleep(900);
      await shot(page, '02-dodaj-dziecko-sheet.png');
      await page.keyboard.press('Escape');
      await sleep(700);
      await tap(page, 195, 620);
      await sleep(900);
      await shot(page, '06-dodaj-kolejne-dziecko.png');
      await page.keyboard.press('Escape');
    }

    // Child dashboard (demo)
    await waitForFlutter(page);
    await scrollTo(page, 620);
    await enableAccessibility(page);
    if (!(await tapSemanticsLabel(page, 'Dziecko'))) {
      await tap(page, 215, 760);
    }
    await sleep(2500);
    await shot(page, '09-panel-dziecka.png');
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
