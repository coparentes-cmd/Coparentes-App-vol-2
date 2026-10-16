#!/usr/bin/env python3
"""
Build Keynote-style PPTX: one app screen per slide.
Style matches Coparentes-instrukcja-pierwsze-logowanie.key
(phone left / step + instruction right; title slide blue).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import nsmap
from pptx.util import Emu, Inches, Pt

ROOT = Path(__file__).resolve().parents[1]
SCREENS = ROOT / "tmp_pptx_screens"
ONBOARD = ROOT / "docs" / "assets" / "onboarding"
COMIC = ROOT / "docs" / "comic" / "panels"
KEY_DATA = Path("/tmp/cp_key_extract/Data")
OUT = Path.home() / "Desktop" / "Coparentes-instrukcja-pierwsze-logowanie.pptx"
WORK = ROOT / "tmp_pptx_screens" / "framed"

# 16:9 like Keynote export
SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)

BLUE = RGBColor(0x2F, 0x6F, 0xB8)
BLUE_DARK = RGBColor(0x1E, 0x4F, 0x8C)
GREEN = RGBColor(0x3D, 0xDC, 0x84)
TEAL = RGBColor(0x00, 0xB8, 0x96)
DARK = RGBColor(0x1A, 0x2A, 0x44)
GRAY = RGBColor(0x4A, 0x55, 0x68)
LIGHT_BG = RGBColor(0xF2, 0xF4, 0xF7)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
PHONE = RGBColor(0x22, 0x22, 0x22)


def set_bg(slide, rgb: RGBColor) -> None:
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = rgb


def add_round_rect(slide, left, top, width, height, fill: RGBColor, line=None):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    if line is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = line
        shape.line.width = Pt(2)
    # tighter corners
    try:
        shape.adjustments[0] = 0.08
    except Exception:
        pass
    return shape


def frame_phone_screenshot(src: Path, dest: Path, max_h: int = 1480) -> Path:
    """Put screenshot into a simple phone bezel PNG."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(src).convert("RGBA")
    # Crop to content if needed — keep full mobile capture
    scale = max_h / img.height
    w = int(img.width * scale)
    h = int(img.height * scale)
    img = img.resize((w, h), Image.Resampling.LANCZOS)

    pad = 18
    radius = 48
    frame_w = w + pad * 2
    frame_h = h + pad * 2 + 10
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle(
        (0, 0, frame_w - 1, frame_h - 1),
        radius=radius,
        fill=(34, 34, 34, 255),
    )
    # screen
    screen = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    screen.paste(img, (0, 0), img)
    # rounded mask for screen
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, w - 1, h - 1), radius=36, fill=255)
    frame.paste(screen, (pad, pad + 4), mask)
    # notch
    nw, nh = int(w * 0.38), 18
    nx = (frame_w - nw) // 2
    draw.rounded_rectangle((nx, 10, nx + nw, 10 + nh), radius=9, fill=(20, 20, 20, 255))
    frame.save(dest)
    return dest


def resolve_src(name: str) -> Path:
    candidates = [
        SCREENS / name,
        ONBOARD / name,
        COMIC / name,
        KEY_DATA / name,
    ]
    for p in candidates:
        if p.exists():
            return p
    raise FileNotFoundError(name)


def add_title_slide(prs: Presentation, phone_png: Path) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(slide, BLUE)

    # decorative circles
    for left, top, size in [
        (Inches(-1.2), Inches(-1.5), Inches(4.5)),
        (Inches(10.5), Inches(4.5), Inches(5)),
        (Inches(9.8), Inches(-1.8), Inches(3.5)),
    ]:
        c = slide.shapes.add_shape(MSO_SHAPE.OVAL, left, top, size, size)
        c.fill.solid()
        c.fill.fore_color.rgb = BLUE_DARK
        c.line.fill.background()

    badge = add_round_rect(
        slide, Inches(0.9), Inches(1.6), Inches(4.2), Inches(0.55), GREEN
    )
    tf = badge.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = "INSTRUKCJA KROK PO KROKU"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = DARK
    p.alignment = PP_ALIGN.CENTER
    tf.paragraphs[0].space_before = Pt(6)

    title = slide.shapes.add_textbox(Inches(0.9), Inches(2.5), Inches(6.2), Inches(2.2))
    ttf = title.text_frame
    ttf.word_wrap = True
    tp = ttf.paragraphs[0]
    tp.text = "Pierwsze logowanie\ni założenie wspólnej przestrzeni"
    tp.font.size = Pt(36)
    tp.font.bold = True
    tp.font.color.rgb = WHITE

    sub = slide.shapes.add_textbox(Inches(0.9), Inches(5.0), Inches(6.2), Inches(1.2))
    sp = sub.text_frame
    sp.word_wrap = True
    spp = sp.paragraphs[0]
    spp.text = (
        "Od pierwszego ekranu do zaproszenia\n"
        "drugiego rodzica i dziecka w Coparentes."
    )
    spp.font.size = Pt(18)
    spp.font.color.rgb = WHITE

    slide.shapes.add_picture(
        str(phone_png), Inches(8.0), Inches(0.55), height=Inches(6.4)
    )


def add_screen_slide(
    prs: Presentation,
    *,
    index: int,
    total: int,
    instruction: str,
    phone_png: Path,
) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(slide, LIGHT_BG)

    # phone
    slide.shapes.add_picture(
        str(phone_png), Inches(0.7), Inches(0.35), height=Inches(6.8)
    )

    # step circle
    circle = slide.shapes.add_shape(
        MSO_SHAPE.OVAL, Inches(7.2), Inches(1.6), Inches(0.85), Inches(0.85)
    )
    circle.fill.solid()
    circle.fill.fore_color.rgb = BLUE_DARK
    circle.line.fill.background()
    ctf = circle.text_frame
    ctf.paragraphs[0].alignment = PP_ALIGN.CENTER
    ctf.word_wrap = False
    cp = ctf.paragraphs[0]
    cp.text = str(index)
    cp.font.size = Pt(28)
    cp.font.bold = True
    cp.font.color.rgb = WHITE
    # vertical center hack
    ctf.auto_size = None

    label = slide.shapes.add_textbox(Inches(8.2), Inches(1.75), Inches(4.5), Inches(0.6))
    lp = label.text_frame.paragraphs[0]
    lp.text = f"Ekran {index} z {total}"
    lp.font.size = Pt(20)
    lp.font.bold = True
    lp.font.color.rgb = DARK

    box = add_round_rect(
        slide,
        Inches(7.2),
        Inches(2.8),
        Inches(5.5),
        Inches(2.4),
        WHITE,
        line=TEAL,
    )
    btf = box.text_frame
    btf.word_wrap = True
    bp = btf.paragraphs[0]
    bp.text = instruction
    bp.font.size = Pt(22)
    bp.font.bold = True
    bp.font.color.rgb = DARK
    bp.alignment = PP_ALIGN.LEFT


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)

    slides = [
        # (source relative name, instruction) — one real screen per slide
        (
            "01-logowanie.png",
            "Otwórz aplikację — pierwszy ekran to Logowanie.",
        ),
        (
            "02-rejestracja.png",
            "Wybierz zakładkę Rejestracja.",
        ),
        (
            "03-rejestracja-formularz.png",
            "Uzupełnij imię, rolę, nazwę przestrzeni i e-mail.",
        ),
        (
            "04-zgody.png",
            "Zaznacz zgody i kliknij Utwórz — konto powstaje dopiero wtedy.",
        ),
        (
            "02-dodaj-dziecko-sheet.png",
            "Dodaj profil dziecka (imię i data urodzenia) albo pomiń na razie.",
        ),
        (
            "03-ustawienia-kody.png",
            "W Ustawieniach skopiuj kod dla drugiego rodzica i kod dla dziecka.",
        ),
        (
            "05-rodzic-dolacz.png",
            "Drugi rodzic: Dołączanie → Dorosły → kod przestrzeni, dane i hasło.",
        ),
        (
            "06-dziecko-dolacz.png",
            "Dziecko: Dołączanie → Dziecko → kod dziecka, data urodzenia i hasło.",
        ),
    ]

    framed: list[tuple[Path, str]] = []
    for src_name, text in slides:
        src = resolve_src(src_name)
        dest = WORK / f"framed-{src_name}"
        framed.append((frame_phone_screenshot(src, dest), text))

    # Title phone = login screen
    title_phone = framed[0][0]

    prs = Presentation()
    prs.slide_width = SLIDE_W
    prs.slide_height = SLIDE_H

    add_title_slide(prs, title_phone)

    total = len(framed)
    for i, (phone, instruction) in enumerate(framed, start=1):
        add_screen_slide(
            prs,
            index=i,
            total=total,
            instruction=instruction,
            phone_png=phone,
        )

    # closing summary
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(slide, BLUE)
    box = slide.shapes.add_textbox(Inches(1.2), Inches(2.0), Inches(10.8), Inches(3.5))
    tf = box.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = "Podsumowanie"
    p.font.size = Pt(36)
    p.font.bold = True
    p.font.color.rgb = WHITE
    for line in [
        "Rodzic A — Rejestracja → ustawia rodzinę i kody w Ustawieniach.",
        "Rodzic B — Dołączanie → Dorosły + kod zaproszenia.",
        "Dziecko — Dołączanie → Dziecko + kod dziecka + data urodzenia.",
        "Aplikacja: getcoparentes.app",
    ]:
        bp = tf.add_paragraph()
        bp.text = line
        bp.font.size = Pt(20)
        bp.font.color.rgb = WHITE
        bp.space_before = Pt(10)

    prs.save(str(OUT))
    print(f"Saved {OUT}")


if __name__ == "__main__":
    main()
