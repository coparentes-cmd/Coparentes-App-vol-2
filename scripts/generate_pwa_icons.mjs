#!/usr/bin/env node
/**
 * Generates PWA + favicon assets from assets/branding/coparentes-app-icon-source.png
 */
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const source = join(root, 'assets/branding/coparentes-app-icon-source.png');
const themeBackground = '#F8F8FB';

async function renderIcon(size, { maskable = false } = {}) {
  const inset = maskable ? Math.round(size * 0.12) : Math.round(size * 0.08);
  const inner = size - inset * 2;

  const logo = await sharp(source)
    .resize(inner, inner, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer();

  const background = maskable
    ? { r: 248, g: 248, b: 251, alpha: 1 }
    : { r: 0, g: 0, b: 0, alpha: 0 };

  return sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background,
    },
  })
    .composite([{ input: logo, gravity: 'centre' }])
    .png()
    .toBuffer();
}

async function writeIcon(path, size, options) {
  mkdirSync(dirname(path), { recursive: true });
  const png = await renderIcon(size, options);
  await sharp(png).toFile(path);
  console.log(`Wrote ${path}`);
}

const targets = [
  [join(root, 'web/icons/Icon-192-v2.png'), 192, {}],
  [join(root, 'web/icons/Icon-192.png'), 192, {}],
  [join(root, 'web/icons/Icon-512.png'), 512, {}],
  [join(root, 'web/icons/Icon-maskable-192.png'), 192, { maskable: true }],
  [join(root, 'web/icons/Icon-maskable-512.png'), 512, { maskable: true }],
  [join(root, 'web/favicon.png'), 32, {}],
  [join(root, 'web/icons/favicon-16.png'), 16, {}],
  [join(root, 'web/icons/favicon-32.png'), 32, {}],
  [join(root, 'web/icons/apple-touch-icon.png'), 180, {}],
  [join(root, 'assets/icon/app_icon.png'), 512, {}],
];

for (const [path, size, options] of targets) {
  await writeIcon(path, size, options);
}

console.log(`Done — source: ${source}, maskable bg: ${themeBackground}`);
