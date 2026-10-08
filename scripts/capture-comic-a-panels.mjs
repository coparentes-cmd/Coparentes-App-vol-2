/**
 * Comic A — reliable local panel capture (127.0.0.1 only).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.join(__dirname, '..', 'docs', 'comic', 'panels');
const APP_URL = process.env.COPARENTES_APP_URL ?? 'http://127.0.0.1:8080';
const VIEWPORT = { width: 390, height: 844, deviceScaleFactor: 2 };
const FAKE_RECOVERY_CODE = 'XK9M-PL7Q-2N4R-AB3C';
const EMAIL = 'anna@example.com';
const PASSWORD = 'HasloTest99';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function assertLocal(url) {
  const u = new URL(url);
  if (u.hostname !== '127.0.0.1' && u.hostname !== 'localhost') {
    throw new Error(`Non-local URL refused: ${url}`);
  }
  if (/getcoparentes|railway|netlify/i.test(url)) {
    throw new Error(`Production URL refused: ${url}`);
  }
}

async function enableA11y(page) {
  for (let i = 0; i < 4; i++) {
    await page.evaluate(() =>
      document.querySelector('flt-semantics-placeholder')?.click(),
    );
    await sleep(350);
  }
}

async function inputLabels(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('input, textarea')].map(
      (el) => el.getAttribute('aria-label') || el.type,
    ),
  );
}

async function waitForInputs(page, expectedSubstring, tries = 20) {
  for (let i = 0; i < tries; i++) {
    const labels = await inputLabels(page);
    if (labels.some((l) => String(l).includes(expectedSubstring))) {
      return labels;
    }
    await sleep(400);
  }
  throw new Error(
    `Inputs not found containing ${expectedSubstring}. Got: ${(await inputLabels(page)).join(',')}`,
  );
}

async function fillByAria(page, ariaLabel, value) {
  const ok = await page.evaluate(
    (label, val) => {
      const el = [...document.querySelectorAll('input, textarea')].find(
        (n) => (n.getAttribute('aria-label') || '') === label,
      );
      if (!el) return false;
      el.focus();
      el.value = '';
      el.dispatchEvent(new Event('input', { bubbles: true }));
      return true;
    },
    ariaLabel,
    value,
  );
  if (!ok) throw new Error(`Missing input ${ariaLabel}`);
  // Flutter listens to key events more reliably than setting .value
  const el = await page.evaluateHandle((label) => {
    return [...document.querySelectorAll('input, textarea')].find(
      (n) => (n.getAttribute('aria-label') || '') === label,
    );
  }, ariaLabel);
  const handle = el.asElement();
  await handle.click({ clickCount: 3 });
  await page.keyboard.press('Backspace');
  await handle.type(value, { delay: 18 });
  await sleep(250);
}

async function clickTabIndex(page, index) {
  // 0=Logowanie 1=Rejestracja 2=Dołączanie
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
  if (tabs.length < 3) {
    // fallback fixed coords
    const xs = [98, 195, 292];
    await page.mouse.click(xs[index], 620);
  } else {
    const t = tabs[index];
    await page.mouse.click(t.x + t.w / 2, t.y + t.h / 2);
  }
  await sleep(1000);
  await enableA11y(page);
}

/** Scroll Flutter content with wheel over auth card. */
async function wheel(page, deltas) {
  await page.mouse.move(195, 700);
  for (const d of deltas) {
    await page.mouse.wheel({ deltaY: d });
    await sleep(280);
  }
}

async function clickWidePrimary(page) {
  // Prefer a wide bottom button (Zarejestruj / Utwórz / Zaloguj / Dołącz)
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
      .filter((b) => b.w >= 240 && b.h >= 44 && b.h <= 72 && b.y0 > 400 && b.y0 < 820)
      .sort((a, b) => b.y0 - a.y0);
    return buttons[0] || null;
  });
  if (!btn) throw new Error('Primary wide button not found');
  await page.mouse.click(btn.x, btn.y);
  await sleep(1200);
}

async function scrubLocalUrls(pngPath) {
  const meta = await sharp(pngPath).metadata();
  const w = meta.width ?? 780;
  const h = meta.height ?? 1688;
  const stripH = Math.round(h * 0.05);
  const overlay = Buffer.from(
    `<svg width="${w}" height="${h}"><rect x="0" y="${h - stripH}" width="${w}" height="${stripH}" fill="#F7F8FA"/></svg>`,
  );
  await sharp(pngPath)
    .composite([{ input: overlay, top: 0, left: 0 }])
    .png()
    .toFile(pngPath + '.tmp');
  fs.renameSync(pngPath + '.tmp', pngPath);
}

async function shot(page, name) {
  const filePath = path.join(OUT_DIR, name);
  await page.screenshot({ path: filePath, fullPage: false });
  await scrubLocalUrls(filePath);
  console.log('Saved', name);
}

async function redactRecoveryCode(pngPath) {
  const meta = await sharp(pngPath).metadata();
  const w = meta.width ?? 780;
  const h = meta.height ?? 1688;
  const boxY = Math.round(h * 0.4);
  const boxH = Math.round(h * 0.1);
  const boxX = Math.round(w * 0.08);
  const boxW = Math.round(w * 0.84);
  const svg = Buffer.from(
    `<svg width="${w}" height="${h}">
      <rect x="${boxX}" y="${boxY}" width="${boxW}" height="${boxH}" rx="14" fill="#E8EAED"/>
      <text x="${w / 2}" y="${boxY + boxH / 2 + 10}" text-anchor="middle"
        font-family="Menlo, Monaco, monospace" font-size="26" font-weight="700"
        fill="#1A1A1A" letter-spacing="1.2">${FAKE_RECOVERY_CODE}</text>
    </svg>`,
  );
  await sharp(pngPath)
    .composite([{ input: svg, top: 0, left: 0 }])
    .png()
    .toFile(pngPath + '.tmp');
  fs.renameSync(pngPath + '.tmp', pngPath);
  console.log('Redacted recovery →', FAKE_RECOVERY_CODE);
}

async function tapCheckboxes(page) {
  // Consent rows: tap right side switch/checkbox areas
  const boxes = await page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((el) => {
        const r = el.getBoundingClientRect();
        const role = el.getAttribute('role');
        return {
          role,
          checked: el.getAttribute('aria-checked'),
          x: r.x + r.width - 24,
          y: r.y + r.height / 2,
          w: r.width,
          h: r.height,
        };
      })
      .filter(
        (b) =>
          (b.role === 'checkbox' || b.role === 'switch') &&
          b.checked !== 'true' &&
          b.w > 40,
      ),
  );
  console.log('checkbox nodes', boxes.length);
  for (const b of boxes) {
    await page.mouse.click(b.x, b.y);
    await sleep(350);
  }
  if (boxes.length === 0) {
    // Fallback: tap switch column on consent list
    for (const y of [250, 330, 410, 490, 570]) {
      await page.mouse.click(340, y);
      await sleep(300);
    }
  }
}

async function main() {
  assertLocal(APP_URL);
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
  await page.setRequestInterception(true);
  page.on('request', (req) => {
    const u = req.url();
    if (/getcoparentes\.app|railway\.app|netlify\.app/i.test(u)) {
      console.error('BLOCKED', u);
      req.abort();
      return;
    }
    req.continue();
  });

  try {
    await page.goto(APP_URL, { waitUntil: 'networkidle2', timeout: 120_000 });
    await sleep(4500);
    await enableA11y(page);
    await page.evaluate(() => window.scrollTo(0, 480));
    await sleep(500);
    await enableA11y(page);

    // Panel 1 — Rejestracja tab
    await clickTabIndex(page, 1);
    await waitForInputs(page, 'Imię');
    await wheel(page, [180, 180]);
    await shot(page, '01-rejestracja.png');

    // Fill identity fields
    await fillByAria(page, 'Imię', 'Anna');
    await fillByAria(page, 'Nazwisko', 'Kowalska');
    // Mama chip (left of pair near bottom)
    await page.mouse.click(120, 806);
    await sleep(400);
    await fillByAria(page, 'Nazwa przestrzeni', 'Rodzina Kowalska');
    await fillByAria(page, 'E-mail', EMAIL);
    // Scroll so workspace + email visible
    await wheel(page, [220, 220, 220]);
    await sleep(400);
    await shot(page, '02-formularz.png');

    await fillByAria(page, 'Hasło', PASSWORD);
    await wheel(page, [260, 260]);
    await sleep(400);
    await shot(page, '03-haslo.png');

    // Zarejestruj → consent
    await clickWidePrimary(page);
    await sleep(1500);
    await enableA11y(page);

    // Detect consent screen: no Imię field, or Utwórz button
    let labels = await inputLabels(page);
    console.log('after register click inputs:', labels);
    if (labels.includes('Imię')) {
      // still on form — scroll more and retry
      await wheel(page, [400, 400]);
      await clickWidePrimary(page);
      await sleep(2000);
      labels = await inputLabels(page);
      console.log('retry inputs:', labels);
    }

    await tapCheckboxes(page);
    await sleep(500);
    await shot(page, '04-zgody.png');

    // Utwórz
    await clickWidePrimary(page);
    await sleep(5000);
    await enableA11y(page);
    await shot(page, '05-krok1.png');

    // Tour CTA — tap center of dialog / Wygeneruj
    await page.mouse.click(195, 430);
    await sleep(2000);
    await enableA11y(page);

    // Password unlock if present
    labels = await inputLabels(page);
    if (labels.some((l) => /hasło|password/i.test(l)) || labels.includes('password')) {
      try {
        await fillByAria(page, 'Aktualne hasło', PASSWORD);
      } catch {
        const pw = await page.$('input[type="password"]');
        if (pw) {
          await pw.click({ clickCount: 3 });
          await page.keyboard.type(PASSWORD, { delay: 15 });
        }
      }
      await sleep(400);
      // confirm
      const conf = await page.evaluate(() => {
        const buttons = [...document.querySelectorAll('flt-semantics')]
          .filter((el) => el.getAttribute('role') === 'button')
          .map((el) => {
            const r = el.getBoundingClientRect();
            return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, y0: r.y };
          })
          .filter((b) => b.w > 60 && b.y0 > 350)
          .sort((a, b) => b.x - a.x);
        return buttons[0];
      });
      if (conf) await page.mouse.click(conf.x, conf.y);
      await sleep(2800);
    }

    await shot(page, '06-kod-odzyskiwania.png');
    await redactRecoveryCode(path.join(OUT_DIR, '06-kod-odzyskiwania.png'));

    // Close sheet
    await page.keyboard.press('Escape');
    await sleep(800);
    const closeBtn = await page.evaluate(() => {
      const buttons = [...document.querySelectorAll('flt-semantics')]
        .filter((el) => el.getAttribute('role') === 'button')
        .map((el) => {
          const r = el.getBoundingClientRect();
          return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, h: r.height };
        })
        .filter((b) => b.w >= 200 && b.h >= 40);
      return buttons.sort((a, b) => b.y - a.y)[0];
    });
    if (closeBtn) {
      await page.mouse.click(closeBtn.x, closeBtn.y);
      await sleep(1500);
    }

    await enableA11y(page);
    await shot(page, '07a-krok2.png');
    // X close top-right of dialog
    await page.mouse.click(330, 270);
    await sleep(1400);
    await enableA11y(page);
    await shot(page, '07b-krok3.png');

    const a = path.join(OUT_DIR, '07a-krok2.png');
    const b = path.join(OUT_DIR, '07b-krok3.png');
    const meta = await sharp(a).metadata();
    const halfH = Math.round((meta.height ?? 1688) / 2);
    const resizedA = await sharp(a)
      .resize({ width: meta.width, height: halfH, fit: 'cover' })
      .png()
      .toBuffer();
    const resizedB = await sharp(b)
      .resize({ width: meta.width, height: halfH, fit: 'cover' })
      .png()
      .toBuffer();
    await sharp({
      create: {
        width: meta.width,
        height: halfH * 2,
        channels: 3,
        background: '#F7F8FA',
      },
    })
      .composite([
        { input: resizedA, top: 0, left: 0 },
        { input: resizedB, top: halfH, left: 0 },
      ])
      .png()
      .toFile(path.join(OUT_DIR, '07-kroki-2-3.png'));
    console.log('Saved 07-kroki-2-3.png');

    // Fresh auth for login panel
    await page.goto(APP_URL, { waitUntil: 'networkidle2', timeout: 120_000 });
    await sleep(4000);
    await enableA11y(page);
    await page.evaluate(() => window.scrollTo(0, 480));
    await sleep(400);
    await enableA11y(page);
    await clickTabIndex(page, 0);
    await waitForInputs(page, 'E-mail');
    await fillByAria(page, 'E-mail', EMAIL);
    await shot(page, '08-logowanie.png');

    console.log('OK', OUT_DIR);
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
