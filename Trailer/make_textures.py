#!/usr/bin/env python3
"""Paint Shelf UI at real panel proportions (520x620 @2x) on liquid glass."""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parent / "textures"
OUT = ROOT
OUT.mkdir(exist_ok=True)

PHOTOS = {
    "coastal": ROOT / "1.jpg",
    "note": ROOT / "2.jpg",
    "lake": ROOT / "3.jpg",
    "headphones": ROOT / "4.jpg",
    "gallery": ROOT / "5.jpg",
    "fig": ROOT / "6.jpg",
    "boarding": ROOT / "7.jpg",
}

# Real panel 520x620. Export @2x.
W, H = 1040, 1240
SCALE = 2
PAD = 36 * SCALE
CARD_W = 138 * SCALE
CARD_H = 148 * SCALE
CARD_R = 16 * SCALE
GAP = 12 * SCALE


def font(size, weight="regular"):
    paths = {
        "regular": ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"],
        "semibold": ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"],
        "mono": ["/System/Library/Fonts/SFNSMono.ttf", "/System/Library/Fonts/Menlo.ttc"],
    }
    for p in paths.get(weight, paths["regular"]):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def cover(im, size):
    tw, th = size
    im = im.convert("RGB")
    scale = max(tw / im.width, th / im.height)
    im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.Resampling.LANCZOS)
    left = (im.width - tw) // 2
    top = (im.height - th) // 2
    return im.crop((left, top, left + tw, top + th))


def photo(key, size):
    im = Image.open(PHOTOS[key])
    im = ImageEnhance.Contrast(im).enhance(1.05)
    return cover(im, size)


def rr(d, box, r, **kw):
    d.rounded_rectangle(box, radius=r, **kw)


def glass_panel():
    """Frosted liquid glass — cool, translucent, not a white slab."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(wash)
    for y in range(H):
        t = y / max(1, H - 1)
        r = int(42 + 18 * (1 - t) + 8 * t)
        g = int(46 + 20 * (1 - t) + 10 * t)
        b = int(54 + 22 * (1 - t) + 14 * t)
        a = 178
        d.line([(0, y), (W, y)], fill=(r, g, b, a))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), 22 * SCALE, fill=255)
    img.paste(wash, mask=mask)
    noise = Image.effect_noise((W, H), 12).convert("L")
    grain = Image.merge(
        "RGBA",
        (noise, noise, noise, ImageOps.invert(noise).point(lambda p: int(p * 0.08))),
    )
    img = Image.alpha_composite(img, grain)
    img.putalpha(ImageChops.darker(img.split()[-1], mask))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rounded_rectangle((1, 1, W - 2, H - 2), 22 * SCALE - 1, outline=(255, 255, 255, 48), width=2)
    od.rounded_rectangle((2, 2, W - 3, int(H * 0.22)), 20 * SCALE, outline=(255, 255, 255, 22), width=4)
    rail_h = 5 * SCALE
    od.rounded_rectangle((PAD, H - PAD - rail_h, W - PAD, H - PAD), 3, fill=(10, 132, 255, 210))
    img = Image.alpha_composite(img, ov)
    img.putalpha(ImageChops.darker(img.split()[-1], mask))
    return img


def icon_circle(d, xy, kind, r=13 * SCALE):
    x, y = xy
    d.ellipse((x, y, x + 2 * r, y + 2 * r), fill=(255, 255, 255, 22))
    cx, cy = x + r, y + r
    c = (235, 237, 240, 230)
    s = r * 0.45
    if kind == "clip":
        d.arc((cx - s, cy - s * 1.1, cx + s * 0.3, cy + s * 0.6), 200, 500, fill=c, width=2)
        d.line((cx + 1, cy - s * 0.7, cx + 1, cy + s * 0.8), fill=c, width=2)
    elif kind == "left":
        d.rounded_rectangle((cx - s, cy - s * 0.8, cx + s, cy + s * 0.8), 2, outline=c, width=2)
        d.line((cx - 3, cy - s * 0.8, cx - 3, cy + s * 0.8), fill=c, width=2)
    elif kind == "right":
        d.rounded_rectangle((cx - s, cy - s * 0.8, cx + s, cy + s * 0.8), 2, outline=c, width=2)
        d.line((cx + 3, cy - s * 0.8, cx + 3, cy + s * 0.8), fill=c, width=2)
    elif kind == "grid":
        for i in range(2):
            for j in range(2):
                d.rounded_rectangle(
                    (
                        cx - s + i * (s + 2),
                        cy - s + j * (s + 2),
                        cx - s + i * (s + 2) + s - 2,
                        cy - s + j * (s + 2) + s - 2,
                    ),
                    1,
                    outline=c,
                    width=2,
                )


def search_bar(img, y):
    d = ImageDraw.Draw(img)
    box = (PAD, y, W - PAD, y + 36 * SCALE)
    rr(d, box, 18 * SCALE, fill=(255, 255, 255, 18), outline=(255, 255, 255, 28), width=1)
    cy = y + 18 * SCALE
    d.ellipse((PAD + 16, cy - 8, PAD + 32, cy + 8), outline=(200, 204, 210, 200), width=2)
    d.line((PAD + 29, cy + 6, PAD + 36, cy + 13), fill=(200, 204, 210, 200), width=2)
    d.text((PAD + 48, cy - 11), "Search this shelf", font=font(15 * SCALE), fill=(190, 194, 200, 200))
    d.text((W - PAD - 52, cy - 9), "⌘F", font=font(12 * SCALE, "mono"), fill=(160, 164, 172, 180))


def tabs(img, y, active, counts):
    d = ImageDraw.Draw(img)
    names = ["Inbox", "Work", "Personal"]
    x = PAD
    for name in names:
        on = name == active
        col = (245, 246, 248, 240) if on else (180, 184, 190, 200)
        f = font(15 * SCALE, "semibold" if on else "regular")
        d.text((x, y), name, font=f, fill=col)
        tw = int(d.textlength(name, font=f))
        d.text((x + tw + 8, y + 4), str(counts.get(name, 0)), font=font(11 * SCALE, "mono"), fill=(150, 154, 160, 190))
        if on:
            d.rounded_rectangle((x, y + 28, x + tw, y + 31), 2, fill=(245, 246, 248, 240))
        x += 118 * SCALE
    px = x - 20
    d.ellipse((px, y - 2, px + 28, y + 26), fill=(255, 255, 255, 18))
    d.line((px + 8, y + 12, px + 20, y + 12), fill=(210, 214, 220, 210), width=2)
    d.line((px + 14, y + 6, px + 14, y + 18), fill=(210, 214, 220, 210), width=2)


def card_image(title, key):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    th = 92 * SCALE
    p = photo(key, (CARD_W - 20, th)).convert("RGBA")
    mask = Image.new("L", p.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, p.size[0] - 1, p.size[1] - 1), 10 * SCALE, fill=255)
    im.paste(p, (10, 10), mask)
    d.text((10, th + 18), title, font=font(12 * SCALE), fill=(210, 214, 220, 230))
    return im


def card_link(title, host):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (10, 10, 10 + 28, 10 + 28), 6, fill=(10, 132, 255, 230))
    d.arc((16, 16, 32, 32), 40, 320, fill=(255, 255, 255, 240), width=2)
    d.text((10, 48), title, font=font(13 * SCALE, "semibold"), fill=(236, 238, 242, 240))
    d.text((10, 92), host, font=font(11 * SCALE), fill=(170, 176, 184, 210))
    return im


def card_pdf(title, pages):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (10, 10, CARD_W - 10, 18 + 70), 8, fill=(255, 255, 255, 18))
    rr(d, (10, 10, CARD_W - 10, 32), 6, fill=(200, 40, 44, 230))
    d.text((18, 12), "PDF", font=font(10 * SCALE, "semibold"), fill=(255, 255, 255, 255))
    for i, wfrac in enumerate((0.86, 0.72, 0.80)):
        y = 42 + i * 12
        d.rounded_rectangle((20, y, 20 + int((CARD_W - 50) * wfrac), y + 5), 2, fill=(200, 204, 210, 80))
    d.text((10, 100), title, font=font(12 * SCALE), fill=(220, 224, 228, 230))
    d.text((10, 124), f"{pages} pages", font=font(11 * SCALE), fill=(160, 164, 172, 200))
    return im


def card_code(title, lines):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (8, 8, CARD_W - 8, 100), 8, fill=(12, 14, 18, 200))
    cols = [(255, 120, 140), (120, 220, 180), (140, 190, 255), (220, 220, 230)]
    for i, line in enumerate(lines[:5]):
        d.text((14, 14 + i * 16), line, font=font(9 * SCALE, "mono"), fill=cols[i % len(cols)])
    d.text((10, 110), title, font=font(12 * SCALE), fill=(220, 224, 228, 230))
    return im


def card_color(hex_s, rgb):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (10, 10, CARD_W - 10, 102), 10, fill=rgb + (255,))
    d.text((16, 74), hex_s, font=font(12 * SCALE, "mono"), fill=(255, 255, 255, 240))
    d.text((10, 114), hex_s, font=font(12 * SCALE), fill=(210, 214, 220, 230))
    return im


def card_text(title, body):
    im = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.text((10, 10), title, font=font(12 * SCALE, "semibold"), fill=(230, 232, 236, 240))
    words, cur, lines = body.split(), "", []
    f = font(11 * SCALE)
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) > CARD_W - 22:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    for i, line in enumerate(lines[:5]):
        d.text((10, 36 + i * 18), line, font=f, fill=(190, 194, 200, 220))
    return im


def compose(active, counts, cards, footer, subtitle="Hold this for me."):
    img = glass_panel()
    d = ImageDraw.Draw(img)
    y = PAD
    d.text((PAD, y), active, font=font(22 * SCALE, "semibold"), fill=(245, 246, 248, 245))
    d.text((PAD, y + 34 * SCALE), subtitle, font=font(12 * SCALE), fill=(170, 174, 180, 210))
    bx = W - PAD - (26 * SCALE) * 4 - 18
    for i, k in enumerate(("clip", "left", "right", "grid")):
        icon_circle(d, (bx + i * (26 * SCALE + 6), y + 4), k)
    search_bar(img, y + 70 * SCALE)
    tabs(img, y + 118 * SCALE, active, counts)

    grid_y = y + 160 * SCALE
    cols = 3
    for i, card in enumerate(cards[:6]):
        col, row = i % cols, i // cols
        x = PAD + col * (CARD_W + GAP)
        yy = grid_y + row * (CARD_H + GAP)
        img.alpha_composite(card, (x, yy))

    d.text((PAD, H - PAD - 28 * SCALE), footer, font=font(12 * SCALE), fill=(180, 184, 190, 210))
    kx = W - PAD - 120 * SCALE
    ky = H - PAD - 32 * SCALE
    rr(d, (kx, ky, kx + 72 * SCALE, ky + 22 * SCALE), 6, fill=(255, 255, 255, 22), outline=(255, 255, 255, 30))
    d.text((kx + 8, ky + 2), "⌥ Space", font=font(11 * SCALE, "semibold"), fill=(230, 232, 236, 230))
    d.text((kx + 80 * SCALE, ky + 4), "hide", font=font(11 * SCALE), fill=(160, 164, 170, 200))
    return img


def add_hover(base):
    img = base.copy()
    d = ImageDraw.Draw(img)
    x, y = PAD, PAD + 160 * SCALE
    d.rounded_rectangle((x - 2, y - 2, x + CARD_W + 2, y + CARD_H + 2), CARD_R, outline=(10, 132, 255, 220), width=3)
    chip = Image.new("RGBA", (240 * SCALE, 44 * SCALE), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chip)
    rr(cd, (0, 0, 240 * SCALE - 1, 44 * SCALE - 1), 12, fill=(20, 22, 26, 220))
    cd.text((12, 6), "Coastal Highway", font=font(12 * SCALE, "semibold"), fill=(250, 250, 252, 255))
    cd.text((12, 24), "Image · Open  Copy  Preview", font=font(10 * SCALE), fill=(180, 184, 190, 230))
    img.alpha_composite(chip, (x, y + CARD_H - 8))
    return img


def mac_desktop():
    dw, dh = 1800, 1166
    im = Image.new("RGB", (dw, dh), (28, 36, 48))
    d = ImageDraw.Draw(im)
    for y in range(dh):
        t = y / dh
        d.line([(0, y), (dw, y)], fill=(int(48 + 30 * t), int(62 + 20 * t), int(78 + 10 * (1 - t))))
    blob = Image.new("RGB", (dw, dh), (28, 36, 48))
    ImageDraw.Draw(blob).ellipse((dw * 0.4, -200, dw * 1.2, dh * 0.6), fill=(120, 150, 180))
    im = Image.blend(im, blob, 0.25)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, dw, 28), fill=(40, 42, 46))
    d.text((14, 6), "  Finder    File    Edit    View    Go    Window    Help", font=font(13), fill=(230, 232, 236))
    d.text((dw - 220, 6), "Mon 16 Aug    7:14", font=font(13), fill=(230, 232, 236))
    d.rounded_rectangle((dw / 2 - 260, dh - 70, dw / 2 + 260, dh - 18), 16, fill=(30, 32, 36))
    colors = [(80, 160, 255), (90, 200, 120), (255, 180, 60), (255, 90, 80), (180, 140, 255), (240, 240, 245)]
    for i, c in enumerate(colors):
        x = dw / 2 - 220 + i * 72
        d.rounded_rectangle((x, dh - 62, x + 44, dh - 22), 10, fill=c)
    im.save(OUT / "mac_desktop.jpg", quality=92)


def main():
    mac_desktop()
    inbox = [
        card_image("Coastal Highway", "coastal"),
        card_link("Human Interface", "developer.apple.com"),
        card_pdf("Q3 Launch Brief.pdf", 12),
        card_code("ShelfItem.swift", ["struct ShelfItem {", "  var id: UUID", "  var title: String", "  var hash: SHA256", "}"]),
        card_image("Alpine Lake", "lake"),
        card_color("#0A84FF", (10, 132, 255)),
    ]
    work = [
        card_pdf("SOW — North Studio.pdf", 8),
        card_link("Linear · SHLF-142", "linear.app"),
        card_code("DuplicateDetector", ["@MainActor", "func match(_ h: String)", "  -> ShelfItem? {", "  items.first {", "    $0.hash == h"]),
        card_image("Studio Cans", "headphones"),
        card_pdf("Invoice 1842.pdf", 2),
        card_color("#1D1D1F", (29, 29, 31)),
    ]
    personal = [
        card_image("Sunday Figs", "fig"),
        card_image("Pencil notes", "note"),
        card_image("Quiet chair", "gallery"),
        card_text("Packing list", "Passport, cable, 35mm, black sweater, the book."),
        card_color("#FF9F0A", (255, 159, 10)),
        card_link("Reservations", "tables.example"),
    ]
    ui_inbox = compose("Inbox", {"Inbox": 6, "Work": 3, "Personal": 4}, inbox, "6 items")
    ui_work = compose("Work", {"Inbox": 6, "Work": 6, "Personal": 4}, work, "6 items · Work", "Client drops and briefs.")
    ui_personal = compose("Personal", {"Inbox": 6, "Work": 6, "Personal": 6}, personal, "6 items · Personal", "Keep for later.")
    ui_hover = add_hover(ui_inbox)
    for n, im in [("ui_inbox", ui_inbox), ("ui_work", ui_work), ("ui_personal", ui_personal), ("ui_hover", ui_hover)]:
        im.save(OUT / f"{n}.png")
        print("wrote", n, im.size)


if __name__ == "__main__":
    main()
