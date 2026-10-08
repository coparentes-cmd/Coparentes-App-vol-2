/**
 * Builds Comic A vertical strip (PNG 800px + PDF) from panels + copy.pl.json.
 *
 * Usage: node scripts/build_comic.mjs
 * Output: docs/comic/out/comic-a-pl.png, comic-a-pl.pdf (do not commit binaries unless asked)
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { PDFDocument } from 'pdf-lib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const COMIC = path.join(ROOT, 'docs', 'comic');
const PANELS = path.join(COMIC, 'panels');
const OUT = path.join(COMIC, 'out');
const COPY_PATH = path.join(COMIC, 'copy.pl.json');

const WIDTH = 800;
const PANEL_IMG_W = 720;
const PAD_X = 40;
const GAP = 28;

function escapeXml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function wrapText(text, maxChars) {
  const words = String(text).split(/\s+/);
  const lines = [];
  let cur = '';
  for (const w of words) {
    const next = cur ? `${cur} ${w}` : w;
    if (next.length > maxChars && cur) {
      lines.push(cur);
      cur = w;
    } else {
      cur = next;
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

async function buildPanelBlock(panel, index) {
  const imgPath = path.join(PANELS, panel.image);
  if (!fs.existsSync(imgPath)) {
    throw new Error(`Missing panel image: ${panel.image}`);
  }

  const resized = await sharp(imgPath)
    .resize({ width: PANEL_IMG_W, withoutEnlargement: true })
    .png()
    .toBuffer();
  const meta = await sharp(resized).metadata();
  const imgH = meta.height ?? 900;

  const bubbleLines = wrapText(panel.bubble, 42);
  const captionLines = wrapText(panel.caption, 48);
  const bubbleH = 28 + bubbleLines.length * 22;
  const captionH = 18 + captionLines.length * 18;
  const numberH = 36;
  const arrowH = 24;
  const totalH = numberH + 8 + bubbleH + 12 + imgH + 10 + captionH + arrowH + GAP;

  const bubbleText = bubbleLines
    .map(
      (line, i) =>
        `<text x="${WIDTH / 2}" y="${numberH + 26 + i * 22}" text-anchor="middle" font-family="Georgia, 'Times New Roman', serif" font-size="18" fill="#1A1A1A">${escapeXml(line)}</text>`,
    )
    .join('');
  const captionText = captionLines
    .map(
      (line, i) =>
        `<text x="${WIDTH / 2}" y="${numberH + 8 + bubbleH + 12 + imgH + 22 + i * 18}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" font-size="14" fill="#444">${escapeXml(line)}</text>`,
    )
    .join('');

  const imgTop = numberH + 8 + bubbleH + 12;
  const svg = Buffer.from(`<svg width="${WIDTH}" height="${totalH}" xmlns="http://www.w3.org/2000/svg">
    <rect width="100%" height="100%" fill="#FAFAF8"/>
    <circle cx="48" cy="${numberH / 2 + 4}" r="16" fill="#1B4F9C"/>
    <text x="48" y="${numberH / 2 + 10}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" font-size="16" font-weight="700" fill="#fff">${panel.id}</text>
    <rect x="${PAD_X}" y="${numberH + 4}" width="${WIDTH - PAD_X * 2}" height="${bubbleH}" rx="18" fill="#FFF8E7" stroke="#E8D9A8"/>
    ${bubbleText}
    <!-- arrow from bubble to image -->
    <polygon points="${WIDTH / 2 - 10},${numberH + 4 + bubbleH} ${WIDTH / 2 + 10},${numberH + 4 + bubbleH} ${WIDTH / 2},${numberH + 4 + bubbleH + 10}" fill="#E8D9A8"/>
    ${captionText}
    ${
      index < 7
        ? `<text x="${WIDTH / 2}" y="${totalH - 8}" text-anchor="middle" font-size="20" fill="#1B4F9C">↓</text>`
        : ''
    }
  </svg>`);

  const base = await sharp({
    create: {
      width: WIDTH,
      height: totalH,
      channels: 3,
      background: '#FAFAF8',
    },
  })
    .composite([
      { input: svg, top: 0, left: 0 },
      { input: resized, top: imgTop, left: Math.round((WIDTH - PANEL_IMG_W) / 2) },
    ])
    .png()
    .toBuffer();

  return { buffer: base, height: totalH, alt: panel.alt };
}

async function main() {
  const copy = JSON.parse(fs.readFileSync(COPY_PATH, 'utf8'));
  fs.mkdirSync(OUT, { recursive: true });

  const blocks = [];
  for (let i = 0; i < copy.panels.length; i++) {
    blocks.push(await buildPanelBlock(copy.panels[i], i));
  }

  const titleH = 72;
  const totalH = titleH + blocks.reduce((s, b) => s + b.height, 0) + 40;
  const titleSvg = Buffer.from(`<svg width="${WIDTH}" height="${titleH}">
    <rect width="100%" height="100%" fill="#FAFAF8"/>
    <text x="${WIDTH / 2}" y="44" text-anchor="middle" font-family="Georgia, serif" font-size="22" font-weight="700" fill="#1A1A1A">${escapeXml(copy.title)}</text>
  </svg>`);

  let y = titleH;
  const composites = [{ input: titleSvg, top: 0, left: 0 }];
  for (const b of blocks) {
    composites.push({ input: b.buffer, top: y, left: 0 });
    y += b.height;
  }

  const pngPath = path.join(OUT, 'comic-a-pl.png');
  await sharp({
    create: {
      width: WIDTH,
      height: totalH,
      channels: 3,
      background: '#FAFAF8',
    },
  })
    .composite(composites)
    .png()
    .toFile(pngPath);

  const pngBytes = fs.readFileSync(pngPath);
  const pdf = await PDFDocument.create();
  const embedded = await pdf.embedPng(pngBytes);
  const pageW = 595; // A4-ish width points
  const scale = pageW / WIDTH;
  const pageH = totalH * scale;
  const page = pdf.addPage([pageW, pageH]);
  page.drawImage(embedded, { x: 0, y: 0, width: pageW, height: pageH });
  const pdfPath = path.join(OUT, 'comic-a-pl.pdf');
  fs.writeFileSync(pdfPath, await pdf.save());

  const altPath = path.join(OUT, 'comic-a-pl.alt.json');
  fs.writeFileSync(
    altPath,
    JSON.stringify(
      {
        title: copy.title,
        panels: copy.panels.map((p) => ({ id: p.id, alt: p.alt })),
      },
      null,
      2,
    ),
  );

  console.log('Wrote', pngPath);
  console.log('Wrote', pdfPath);
  console.log('Wrote', altPath);
  console.log('size png', fs.statSync(pngPath).size, 'pdf', fs.statSync(pdfPath).size);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
