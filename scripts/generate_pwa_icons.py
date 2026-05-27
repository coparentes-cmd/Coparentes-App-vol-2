#!/usr/bin/env python3
"""Generate PWA icons (brand #00C896) for web/ and assets/icon/."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

BRAND = (0, 200, 150, 255)
TRANSPARENT = (0, 0, 0, 0)
ROOT = Path(__file__).resolve().parents[1]


def _chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png(path: Path, size: int, maskable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    margin = int(size * 0.1) if maskable else int(size * 0.06)
    radius = (size // 2) - margin
    cx = cy = size // 2
    rows = []

    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            if maskable:
                row.extend(BRAND)
                continue
            dx = x - cx
            dy = y - cy
            if (dx * dx + dy * dy) ** 0.5 <= radius:
                row.extend(BRAND)
            else:
                row.extend(TRANSPARENT)
        rows.append(bytes(row))

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    idat = zlib.compress(b"".join(rows), 9)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", idat)
        + _chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def main() -> None:
    targets = [
        (ROOT / "web/icons/Icon-192-v2.png", 192, False),
        (ROOT / "web/icons/Icon-512.png", 512, False),
        (ROOT / "web/icons/Icon-maskable-192.png", 192, True),
        (ROOT / "web/icons/Icon-maskable-512.png", 512, True),
        (ROOT / "web/favicon.png", 32, False),
        (ROOT / "assets/icon/app_icon.png", 512, False),
    ]
    for path, size, maskable in targets:
        write_png(path, size, maskable)
        print(f"Wrote {path}")


if __name__ == "__main__":
    main()
