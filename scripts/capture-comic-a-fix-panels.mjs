/**
 * Comic A — fix panels 1, 7, 8 from LOCAL app only.
 * Requires: flutter with --dart-define=COPARENTES_HIDE_DEBUG_BANNER=true
 *           backend on 127.0.0.1:3000
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', 'docs', 'comic', 'panels');
const APP = process.env.COPARENTES_APP_URL ?? 'http://127.0.0.1:5055';
const VP = { width: 390, height: 844, deviceScaleFactor: 2 };
const EMAIL = `anna.comic.${Date.now()}@example.com`;
const PASSWORD = 'HasloTest99';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function assertLocal(url) {
  const u = new URL(url);
  if (u.hostname !== '127.0.0.1' && u.hostname !== 'localhost') {
    throw new Error(`Non-local refused: ${url}`);
  }
  if (/getcoparentes|railway|netlify/i.test(url)) {
    throw new Error(`Production refused: ${url}`);
  }
}

async function a11y(page) {
  for (let i = 0; i < 4; i++) {
    await page.evaluate(() =>
      document.querySelector('flt-semantics-placeholder')?.click(),
    );
    await sleep(300);
  }
}

async function scrubLocalUrlFooter(pngPath) {
  const meta = await sharp(pngPath).metadata();
  const w = meta.width;
  const h = meta.height;
  const strip = Math.round(h * 0.04);
  const ov = Buffer.from(
    `<svg width="${w}" height="${h}"><rect x="0" y="${h - strip}" width="${w}" height="${strip}" fill="#F7F8FA"/></svg>`,
  );
  await sharp(pngPath).composite([{ input: ov }]).png().toFile(pngPath + '.t');
  fs.renameSync(pngPath + '.t', pngPath);
}

async function shot(page, name, { scrub = true } = {}) {
  const p = path.join(OUT, name);
  await page.screenshot({ path: p, fullPage: false });
  if (scrub) await scrubLocalUrlFooter(p);
  console.log('Saved', name);
  return p;
}

async function fill(page, label, value) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const box = await page.evaluate((l) => {
      const el = [...document.querySelectorAll('input,textarea')].find(
        (n) => (n.getAttribute('aria-label') || '') === l,
      );
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + Math.min(20, r.height / 2), top: r.y };
    }, label);
    if (!box) {
      await page.mouse.move(195, 700);
      await page.mouse.wheel({ deltaY: 280 });
      await sleep(300);
      continue;
    }
    if (box.top > 780 || box.top < 60) {
      await page.mouse.move(195, 700);
      await page.mouse.wheel({ deltaY: box.top > 780 ? 320 : -280 });
      await sleep(300);
      continue;
    }
    await page.evaluate((l) => {
      const el = [...document.querySelectorAll('input,textarea')].find(
        (n) => (n.getAttribute('aria-label') || '') === l,
      );
      el?.focus();
    }, label);
    await page.mouse.click(box.x, box.y, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 10 });
    await sleep(150);
    return;
  }
  throw new Error('no ' + label);
}

async function clickTab(page, index) {
  const tabs = await page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .filter((el) => el.getAttribute('role') === 'button')
      .map((el) => {
        const r = el.getBoundingClientRect();
        return { x: r.x, y: r.y, w: r.width, h: r.height };
      })
      .filter(
        (b) =>
          b.y > 200 &&
          b.y < 750 &&
          b.h >= 36 &&
          b.h <= 56 &&
          b.w > 70 &&
          b.w < 130,
      )
      .sort((a, b) => a.x - b.x),
  );
  const trio = tabs.filter((b) => b.y > 500 && b.y < 680).sort((a, b) => a.x - b.x);
  const list = trio.length >= 3 ? trio : tabs.length >= 3 ? tabs.slice(-3) : [];
  if (list[index]) {
    const t = list[index];
    await page.mouse.click(t.x + t.w / 2, t.y + t.h / 2);
  } else {
    // Fixed fallback from known 390×844 layout
    const xs = [98, 195, 292];
    await page.mouse.click(xs[index], 620);
  }
  await sleep(1000);
  await a11y(page);
}

async function primary(page) {
  const btn = await page.evaluate(() => {
    const buttons = [...document.querySelectorAll('flt-semantics')]
      .filter((el) => el.getAttribute('role') === 'button')
      .map((el) => {
        const r = el.getBoundingClientRect();
        return {
          x: r.x + r.width / 2,
          y: r.y + r.height / 2,
          w: r.width,
          h: r.height,
          y0: r.y,
        };
      })
      .filter((b) => b.w >= 240 && b.h >= 44 && b.h <= 72 && b.y0 > 350 && b.y0 < 820)
      .sort((a, b) => b.y0 - a.y0);
    return buttons[0];
  });
  if (!btn) throw new Error('no primary');
  await page.mouse.click(btn.x, btn.y);
  await sleep(1200);
}

/** Close tour dialog via the 44×44 X control (top-right of blue card). */
async function closeTourX(page) {
  const xBtn = await page.evaluate(() => {
    const buttons = [...document.querySelectorAll('flt-semantics')]
      .filter((el) => el.getAttribute('role') === 'button')
      .map((el) => {
        const r = el.getBoundingClientRect();
        return {
          x: r.x + r.width / 2,
          y: r.y + r.height / 2,
          w: r.width,
          h: r.height,
          x0: r.x,
          y0: r.y,
        };
      })
      // Close chip: ~44×44, upper half, right side
      .filter(
        (b) =>
          b.w >= 36 &&
          b.w <= 56 &&
          b.h >= 36 &&
          b.h <= 56 &&
          b.y0 > 150 &&
          b.y0 < 360 &&
          b.x0 > 250,
      )
      .sort((a, b) => a.y0 - b.y0);
    return buttons[0] || null;
  });
  if (xBtn) {
    console.log('X at', xBtn);
    await page.mouse.click(xBtn.x, xBtn.y);
  } else {
    console.log('X fallback click');
    await page.mouse.click(328, 268);
  }
  await sleep(1600);
  await a11y(page);
}

async function waitForInputs(page, needle, tries = 25) {
  for (let i = 0; i < tries; i++) {
    const labels = await page.evaluate(() =>
      [...document.querySelectorAll('input,textarea')].map(
        (n) => n.getAttribute('aria-label') || '',
      ),
    );
    if (labels.some((l) => l.includes(needle))) return labels;
    await sleep(400);
  }
  throw new Error('inputs missing: ' + needle);
}

async function main() {
  assertLocal(APP);
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    executablePath:
      process.env.PUPPETEER_EXECUTABLE_PATH ??
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  const page = await browser.newPage();
  await page.setViewport(VP);
  await page.setRequestInterception(true);
  page.on('request', (req) => {
    if (/getcoparentes|railway\.app|netlify\.app/i.test(req.url())) {
      console.error('BLOCKED', req.url());
      req.abort();
      return;
    }
    req.continue();
  });

  try {
    // ---------- Panel 1: top of page + Rejestracja ----------
    await page.goto(APP, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await sleep(12000);
    await a11y(page);
    // Bring auth tabs into view, then click Rejestracja, then scroll to top for panel 1
    await page.evaluate(() => window.scrollTo(0, 480));
    await sleep(500);
    await a11y(page);
    await clickTab(page, 1);
    await waitForInputs(page, 'Imię');
    await page.evaluate(() => window.scrollTo(0, 0));
    await sleep(600);
    await shot(page, '01-rejestracja.png');

    // Scroll back to form for registration
    await page.evaluate(() => window.scrollTo(0, 480));
    await sleep(400);
    await a11y(page);
    // ---------- Register → tour for panels 7 ----------
    await fill(page, 'Imię', 'Anna');
    await fill(page, 'Nazwisko', 'Kowalska');
    await page.mouse.click(120, 806);
    await fill(page, 'Nazwa przestrzeni', 'Rodzina Kowalska');
    await fill(page, 'E-mail', EMAIL);
    await fill(page, 'Hasło', PASSWORD);
    await page.mouse.move(195, 700);
    await page.mouse.wheel({ deltaY: 520 });
    await sleep(400);
    await primary(page);
    await sleep(1500);
    await a11y(page);

    const boxes = await page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .filter((el) => {
          const role = el.getAttribute('role');
          return (
            (role === 'checkbox' || role === 'switch') &&
            el.getAttribute('aria-checked') !== 'true'
          );
        })
        .map((el) => {
          const r = el.getBoundingClientRect();
          return { x: r.x + r.width - 20, y: r.y + r.height / 2 };
        }),
    );
    for (const b of boxes) {
      await page.mouse.click(b.x, b.y);
      await sleep(220);
    }
    await primary(page);
    await sleep(4500);
    await a11y(page);

    // Dismiss step 1 with X → step 2
    await closeTourX(page);
    await shot(page, '07a-krok2.png', { scrub: false });

    // Verify we advanced (dump buttons if still step 1)
    await closeTourX(page);
    await shot(page, '07b-krok3.png', { scrub: false });

    // Compose FULL frames stacked — no cover-crop
    const aPath = path.join(OUT, '07a-krok2.png');
    const bPath = path.join(OUT, '07b-krok3.png');
    const aMeta = await sharp(aPath).metadata();
    const bMeta = await sharp(bPath).metadata();
    const w = aMeta.width;
    const aBuf = await sharp(aPath).png().toBuffer();
    const bBuf = await sharp(bPath).resize({ width: w }).png().toBuffer();
    const bMeta2 = await sharp(bBuf).metadata();
    await sharp({
      create: {
        width: w,
        height: (aMeta.height ?? 0) + (bMeta2.height ?? 0),
        channels: 3,
        background: '#F7F8FA',
      },
    })
      .composite([
        { input: aBuf, top: 0, left: 0 },
        { input: bBuf, top: aMeta.height, left: 0 },
      ])
      .png()
      .toFile(path.join(OUT, '07-kroki-2-3.png'));
    console.log('Saved 07-kroki-2-3.png (full stack, no crop)');

    // ---------- Panel 8: login with Zaloguj visible ----------
    const client = await page.createCDPSession();
    await client.send('Network.clearBrowserCookies');
    await client.send('Storage.clearDataForOrigin', {
      origin: new URL(APP).origin,
      storageTypes: 'all',
    });
    await page.goto(APP, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await sleep(12000);
    await a11y(page);
    await page.evaluate(() => window.scrollTo(0, 0));
    await sleep(300);
    // Scroll so auth card + Zaloguj fit
    await page.mouse.move(195, 500);
    await page.mouse.wheel({ deltaY: 420 });
    await sleep(500);
    await a11y(page);
    await clickTab(page, 0);
    await waitForInputs(page, 'E-mail');
    await fill(page, 'E-mail', 'anna@example.com');
    // Ensure Zaloguj in frame: wheel a bit more if needed
    await page.mouse.move(195, 700);
    await page.mouse.wheel({ deltaY: 180 });
    await sleep(400);
    await shot(page, '08-logowanie.png');

    console.log('Done. Email for tour (local):', EMAIL);
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
