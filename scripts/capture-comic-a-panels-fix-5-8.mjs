/**
 * Fix comic panels 5–8: tour steps via X (no Resend), synthetic recovery sheet,
 * login tab after cleared storage. LOCAL ONLY.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', 'docs', 'comic', 'panels');
const APP = 'http://127.0.0.1:8080';
const VP = { width: 390, height: 844, deviceScaleFactor: 2 };
const EMAIL = `anna.comic.${Date.now()}@example.com`;
const PASSWORD = 'HasloTest99';
const FAKE_CODE = 'XK9M-PL7Q-2N4R-AB3C';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function a11y(page) {
  for (let i = 0; i < 3; i++) {
    await page.evaluate(() =>
      document.querySelector('flt-semantics-placeholder')?.click(),
    );
    await sleep(300);
  }
}

async function fill(page, label, value) {
  const box = await page.evaluate((l) => {
    const el = [...document.querySelectorAll('input,textarea')].find(
      (n) => (n.getAttribute('aria-label') || '') === l,
    );
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, label);
  if (!box) throw new Error('no ' + label);
  // Off-screen Flutter fields: scroll into view via wheel then click coords
  if (box.y > 820 || box.y < 0) {
    await page.mouse.move(195, 700);
    await page.mouse.wheel({ deltaY: box.y > 820 ? 350 : -200 });
    await sleep(350);
  }
  const box2 = await page.evaluate((l) => {
    const el = [...document.querySelectorAll('input,textarea')].find(
      (n) => (n.getAttribute('aria-label') || '') === l,
    );
    if (!el) return null;
    el.focus();
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + Math.min(r.height / 2, 24) };
  }, label);
  await page.mouse.click(box2.x, box2.y, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, { delay: 12 });
  await sleep(200);
}

async function tab(page, i) {
  const tabs = await page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .filter((el) => el.getAttribute('role') === 'button')
      .map((el) => {
        const r = el.getBoundingClientRect();
        return { x: r.x, y: r.y, w: r.width, h: r.height };
      })
      .filter((b) => b.y > 560 && b.y < 650 && b.h >= 36 && b.h <= 56 && b.w > 70 && b.w < 130)
      .sort((a, b) => a.x - b.x),
  );
  const t = tabs[i] || { x: [49, 146, 244][i], y: 598, w: 97, h: 44 };
  await page.mouse.click(t.x + t.w / 2, t.y + t.h / 2);
  await sleep(900);
  await a11y(page);
}

async function primary(page) {
  const btn = await page.evaluate(() => {
    const buttons = [...document.querySelectorAll('flt-semantics')]
      .filter((el) => el.getAttribute('role') === 'button')
      .map((el) => {
        const r = el.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, h: r.height, y0: r.y };
      })
      .filter((b) => b.w >= 240 && b.h >= 44 && b.h <= 72 && b.y0 > 400 && b.y0 < 820)
      .sort((a, b) => b.y0 - a.y0);
    return buttons[0];
  });
  if (!btn) throw new Error('no primary');
  await page.mouse.click(btn.x, btn.y);
  await sleep(1200);
}

async function scrub(p) {
  const m = await sharp(p).metadata();
  const w = m.width;
  const h = m.height;
  const strip = Math.round(h * 0.05);
  const ov = Buffer.from(
    `<svg width="${w}" height="${h}"><rect x="0" y="${h - strip}" width="${w}" height="${strip}" fill="#F7F8FA"/></svg>`,
  );
  await sharp(p).composite([{ input: ov }]).png().toFile(p + '.t');
  fs.renameSync(p + '.t', p);
}

async function shot(page, name) {
  const p = path.join(OUT, name);
  await page.screenshot({ path: p });
  await scrub(p);
  console.log('Saved', name);
}

async function renderFakeRecoverySheet(browser) {
  const page = await browser.newPage();
  await page.setViewport(VP);
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8">
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F0F2F5;width:390px;height:844px;overflow:hidden}
    .dash{height:844px;background:linear-gradient(#1B3A6B 0 96px,#F0F2F5 96px);position:relative}
    .header{color:#fff;padding:28px 16px 0;font-size:18px;font-weight:700}
    .sub{opacity:.8;font-size:13px;font-weight:500;margin-top:2px}
    .sheet{position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:24px 24px 0 0;padding:20px 24px 28px;box-shadow:0 -8px 30px rgba(0,0,0,.18)}
    h1{font-size:18px;font-weight:700;margin-bottom:10px}
    p{font-size:14px;line-height:1.4;color:#5F6368;margin-bottom:20px}
    .code{background:#E8EAED;border:1px solid #DADCE0;border-radius:12px;padding:18px 16px;text-align:center;font-family:Menlo,Monaco,monospace;font-size:18px;font-weight:700;letter-spacing:1.1px;margin-bottom:12px}
    .out{width:100%;padding:12px;border-radius:24px;border:1px solid #DADCE0;background:#fff;font-size:15px;margin-bottom:12px}
    .ok{width:100%;padding:14px;border-radius:24px;border:0;background:#2A9D8F;color:#fff;font-size:15px;font-weight:600}
  </style></head><body>
  <div class="dash">
    <div class="header">Dzień dobry, Anna<div class="sub">Rodzina Kowalska</div></div>
    <div class="sheet">
      <h1>Kod odzyskiwania czatu</h1>
      <p>Ten kod pozwoli odzyskać historię czatu, jeśli zapomnisz hasła. Wysłaliśmy go też na Twój e-mail. Zapisz go w bezpiecznym miejscu.</p>
      <div class="code">${FAKE_CODE}</div>
      <button class="out">Kopiuj</button>
      <button class="ok">Zamknij</button>
    </div>
  </div>
  </body></html>`;
  await page.setContent(html, { waitUntil: 'load' });
  await sleep(300);
  const p = path.join(OUT, '06-kod-odzyskiwania.png');
  await page.screenshot({ path: p });
  console.log('Saved synthetic 06-kod-odzyskiwania.png with', FAKE_CODE);
  await page.close();
}

async function closeTourX(page) {
  // white X circle top-right of blue dialog ~ (330, 270) at 1x; with dpr still CSS coords
  await page.mouse.click(328, 268);
  await sleep(1400);
  await a11y(page);
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({
    headless: 'new',
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args: ['--no-sandbox'],
  });
  const page = await browser.newPage();
  await page.setViewport(VP);
  await page.setRequestInterception(true);
  page.on('request', (req) => {
    if (/getcoparentes|railway\.app|netlify\.app/i.test(req.url())) {
      req.abort();
      return;
    }
    req.continue();
  });

  try {
    await page.goto(APP, { waitUntil: 'networkidle2', timeout: 120000 });
    await sleep(5500);
    await a11y(page);
    await page.evaluate(() => window.scrollTo(0, 500));
    await sleep(600);
    await a11y(page);
    await tab(page, 1);
    let found = false;
    for (let i = 0; i < 20; i++) {
      const labels = await page.evaluate(() =>
        [...document.querySelectorAll('input,textarea')].map(
          (n) => n.getAttribute('aria-label') || '',
        ),
      );
      if (labels.includes('Imię')) {
        found = true;
        break;
      }
      await page.mouse.click(195, 620);
      await sleep(700);
      await a11y(page);
    }
    if (!found) throw new Error('register form never appeared');
    await fill(page, 'Imię', 'Anna');
    await fill(page, 'Nazwisko', 'Kowalska');
    await page.mouse.click(120, 806);
    await fill(page, 'Nazwa przestrzeni', 'Rodzina Kowalska');
    await fill(page, 'E-mail', EMAIL);
    await fill(page, 'Hasło', PASSWORD);
    await page.mouse.move(195, 700);
    await page.mouse.wheel({ deltaY: 500 });
    await sleep(400);
    await primary(page);
    await sleep(1200);
    await a11y(page);
    // consents
    const boxes = await page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .filter((el) => {
          const role = el.getAttribute('role');
          return (role === 'checkbox' || role === 'switch') && el.getAttribute('aria-checked') !== 'true';
        })
        .map((el) => {
          const r = el.getBoundingClientRect();
          return { x: r.x + r.width - 20, y: r.y + r.height / 2 };
        }),
    );
    for (const b of boxes) {
      await page.mouse.click(b.x, b.y);
      await sleep(250);
    }
    await primary(page);
    await sleep(4500);
    await a11y(page);

    await shot(page, '05-krok1.png');

    // Advance tour with X only (skip recovery — Resend not configured locally)
    await closeTourX(page);
    await shot(page, '07a-krok2.png');
    await closeTourX(page);
    await shot(page, '07b-krok3.png');

    const a = path.join(OUT, '07a-krok2.png');
    const b = path.join(OUT, '07b-krok3.png');
    const meta = await sharp(a).metadata();
    const half = Math.round(meta.height / 2);
    const ra = await sharp(a).resize({ width: meta.width, height: half, fit: 'cover' }).png().toBuffer();
    const rb = await sharp(b).resize({ width: meta.width, height: half, fit: 'cover' }).png().toBuffer();
    await sharp({
      create: { width: meta.width, height: half * 2, channels: 3, background: '#F7F8FA' },
    })
      .composite([
        { input: ra, top: 0, left: 0 },
        { input: rb, top: half, left: 0 },
      ])
      .png()
      .toFile(path.join(OUT, '07-kroki-2-3.png'));
    console.log('Saved 07-kroki-2-3.png');

    await renderFakeRecoverySheet(browser);

    // Panel 8: clear site data → login tab
    const ctx = page.browserContext();
    await page.goto('about:blank');
    const client = await page.createCDPSession();
    await client.send('Network.clearBrowserCookies');
    await client.send('Storage.clearDataForOrigin', {
      origin: 'http://127.0.0.1:8080',
      storageTypes: 'all',
    });
    await page.goto(APP, { waitUntil: 'networkidle2', timeout: 120000 });
    await sleep(4000);
    await a11y(page);
    await page.evaluate(() => window.scrollTo(0, 480));
    await sleep(400);
    await a11y(page);
    await tab(page, 0);
    await fill(page, 'E-mail', 'anna@example.com');
    await shot(page, '08-logowanie.png');

    console.log('email used for tour register (local only):', EMAIL);
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
