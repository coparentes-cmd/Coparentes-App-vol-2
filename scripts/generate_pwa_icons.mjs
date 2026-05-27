#!/usr/bin/env node
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const BRAND = [0, 200, 150, 255];
const TRANSPARENT = [0, 0, 0, 0];

function crc32(buffer) {
  let crc = 0xffffffff;
  for (let i = 0; i < buffer.length; i += 1) {
    crc ^= buffer[i];
    for (let j = 0; j < 8; j += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuf = Buffer.from(type);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

function writePng(path, size, maskable = false) {
  mkdirSync(dirname(path), { recursive: true });
  const margin = Math.floor(size * (maskable ? 0.1 : 0.06));
  const radius = size / 2 - margin;
  const cx = size / 2;
  const cy = size / 2;
  const rows = [];

  for (let y = 0; y < size; y += 1) {
    const row = [0];
    for (let x = 0; x < size; x += 1) {
      let rgba = TRANSPARENT;
      if (maskable) {
        rgba = BRAND;
      } else {
        const dx = x - cx;
        const dy = y - cy;
        if (dx * dx + dy * dy <= radius * radius) rgba = BRAND;
      }
      row.push(...rgba);
    }
    rows.push(Buffer.from(row));
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;

  const idat = deflateSync(Buffer.concat(rows));
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0))
  ]);
  writeFileSync(path, png);
  console.log(`Wrote ${path}`);
}

const targets = [
  [join(root, 'web/icons/Icon-192-v2.png'), 192, false],
  [join(root, 'web/icons/Icon-512.png'), 512, false],
  [join(root, 'web/icons/Icon-maskable-192.png'), 192, true],
  [join(root, 'web/icons/Icon-maskable-512.png'), 512, true],
  [join(root, 'web/favicon.png'), 32, false],
  [join(root, 'assets/icon/app_icon.png'), 512, false]
];

for (const [path, size, maskable] of targets) {
  writePng(path, size, maskable);
}
