#!/usr/bin/env python3
"""Paint Shelf UI frames and unique item faces for the trailer."""
from __future__ import annotations

import os
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parent / "textures"
SRC = ROOT
OUT = ROOT
OUT.mkdir(exist_ok=True)

# Photos copied in from generation
PHOTOS = {
    "coastal": SRC / "1.jpg",
    "note": SRC / "2.jpg",
    "lake": SRC / "3.jpg",
    "headphones": SRC / "4.jpg",
    "gallery": SRC / "5.jpg",
    "fig": SRC / "6.jpg",
    "boarding": SRC / "7.jpg",
}


def font(size, weight="regular"):
    candidates = {
        "regular": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/SFCompact.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ],
        "medium": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ],
        "semibold": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        ],
        "mono": [
            "/System/Library/Fonts/SFNSMono.ttf",
            "/System/Library/Fonts/Menlo.ttc",
            "/System/Library/Fonts/Monaco.ttf",
        ],
    }
    for p in candidates.get(weight, candidates["regular"]):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def rr(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def load_photo(key, size):
    im = Image.open(PHOTOS[key]).convert("RGB")
    im = ImageEnhance.Contrast(im).enhance(1.06)
    im = ImageEnhance.Color(im).enhance(1.04)
    return cover(im, size)


def cover(im, size):
    tw, th = size
    scale = max(tw / im.width, th / im.height)
    im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.Resampling.LANCZOS)
    left = (im.width - tw) // 2
    top = (im.height - th) // 2
    return im.crop((left, top, left + tw, top + th))


def glass_bg(size, radius=72):
    w, h = size
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    # soft vertical wash like light through glass
    wash = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(wash)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(232 - 18 * t)
        g = int(236 - 14 * t)
        b = int(242 - 8 * t)
        a = 230
        d.line([(0, y), (w, y)], fill=(r, g, b, a))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    base.paste(wash, mask=mask)
    # inner highlight
    hi = Image.new("RGBA", size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.rounded_rectangle((3, 3, w - 4, h - 4), radius=radius - 2, outline=(255, 255, 255, 70), width=2)
    hd.rounded_rectangle((2, 2, w - 3, int(h * 0.38)), radius=radius - 2, outline=(255, 255, 255, 28), width=6)
    base = Image.alpha_composite(base, hi)
    return base, mask


def icon_btn(draw, xy, kind, size=34):
    x, y = xy
    rr(draw, (x, y, x + size, y + size), 10, fill=(255, 255, 255, 70))
    cx, cy = x + size / 2, y + size / 2
    c = (40, 44, 52, 210)
    if kind == "clip":
        draw.arc((cx - 7, cy - 9, cx + 3, cy + 5), 200, 500, fill=c, width=2)
        draw.line((cx + 1, cy - 6, cx + 1, cy + 7), fill=c, width=2)
    elif kind == "left":
        draw.rounded_rectangle((cx - 8, cy - 7, cx + 8, cy + 7), 2, outline=c, width=2)
        draw.line((cx - 3, cy - 7, cx - 3, cy + 7), fill=c, width=2)
    elif kind == "right":
        draw.rounded_rectangle((cx - 8, cy - 7, cx + 8, cy + 7), 2, outline=c, width=2)
        draw.line((cx + 3, cy - 7, cx + 3, cy + 7), fill=c, width=2)
    elif kind == "grid":
        for i in range(2):
            for j in range(2):
                draw.rounded_rectangle(
                    (cx - 7 + i * 8, cy - 7 + j * 8, cx - 7 + i * 8 + 6, cy - 7 + j * 8 + 6),
                    1, outline=c, width=2,
                )


def search_pill(img, box, placeholder="Search this shelf"):
    d = ImageDraw.Draw(img)
    rr(d, box, 22, fill=(255, 255, 255, 120), outline=(255, 255, 255, 90), width=1)
    x0, y0, x1, y1 = box
    cy = (y0 + y1) / 2
    # magnifier
    d.ellipse((x0 + 16, cy - 8, x0 + 32, cy + 8), outline=(70, 74, 82, 200), width=2)
    d.line((x0 + 29, cy + 6, x0 + 36, cy + 13), fill=(70, 74, 82, 200), width=2)
    d.text((x0 + 46, cy - 11), placeholder, font=font(22), fill=(90, 94, 102, 200))
    d.text((x1 - 58, cy - 9), "⌘F", font=font(16, "mono"), fill=(130, 134, 142, 180))


def tabs(img, box, active="Inbox", counts=None):
    counts = counts or {"Inbox": 6, "Work": 3, "Personal": 4}
    d = ImageDraw.Draw(img)
    x, y, x1, y1 = box
    names = ["Inbox", "Work", "Personal"]
    tw = 150
    for i, name in enumerate(names):
        tx = x + i * tw
        on = name == active
        color = (20, 22, 26, 230) if on else (90, 94, 102, 200)
        d.text((tx, y), name, font=font(24, "semibold" if on else "regular"), fill=color)
        d.text((tx + 78, y + 4), str(counts.get(name, 0)), font=font(16, "mono"), fill=(130, 134, 142, 180))
        if on:
            d.rounded_rectangle((tx, y + 34, tx + 58, y + 37), 2, fill=(20, 22, 26, 230))
    # plus
    px = x + 3 * tw - 20
    rr(d, (px, y - 2, px + 28, y + 26), 8, fill=(255, 255, 255, 70))
    d.line((px + 8, y + 12, px + 20, y + 12), fill=(70, 74, 82, 200), width=2)
    d.line((px + 14, y + 6, px + 14, y + 18), fill=(70, 74, 82, 200), width=2)


def card_photo(title, photo_key, w=248, h=268):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(255, 255, 255, 150))
    thumb = load_photo(photo_key, (w - 28, 168)).convert("RGBA")
    mask = Image.new("L", thumb.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, thumb.size[0] - 1, thumb.size[1] - 1), 18, fill=255)
    im.paste(thumb, (14, 14), mask)
    d.text((16, 196), title, font=font(20, "medium"), fill=(28, 30, 34, 230))
    return im


def card_link(title, host, w=248, h=268, accent=(10, 132, 255)):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(255, 255, 255, 150))
    rr(d, (16, 16, 52, 52), 10, fill=accent + (230,))
    d.arc((24, 24, 44, 44), 40, 320, fill=(255, 255, 255, 240), width=3)
    d.text((16, 72), title, font=font(20, "semibold"), fill=(22, 24, 28, 235))
    d.text((16, 132), host, font=font(16), fill=(90, 94, 102, 200))
    return im


def card_pdf(title, pages, w=248, h=268):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(255, 255, 255, 155))
    rr(d, (16, 16, w - 16, 150), 16, fill=(248, 248, 250, 255))
    rr(d, (16, 16, w - 16, 40), 8, fill=(200, 40, 44, 240))
    d.text((28, 20), "PDF", font=font(16, "semibold"), fill=(255, 255, 255, 255))
    for i, line in enumerate((0.92, 0.78, 0.84, 0.60)):
        y = 58 + i * 18
        d.rounded_rectangle((32, y, 32 + int((w - 80) * line), y + 7), 3, fill=(210, 212, 218, 255))
    d.text((16, 168), title, font=font(20, "medium"), fill=(22, 24, 28, 235))
    d.text((16, 200), f"{pages} pages", font=font(15), fill=(110, 114, 122, 200))
    return im


def card_code(title, lines, w=248, h=268):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(28, 30, 36, 230))
    rr(d, (12, 12, w - 12, 168), 14, fill=(18, 20, 26, 255))
    colors = [(255, 107, 129), (120, 220, 180), (130, 190, 255), (230, 230, 235), (180, 160, 255)]
    for i, line in enumerate(lines[:7]):
        d.text((22, 22 + i * 20), line, font=font(13, "mono"), fill=colors[i % len(colors)])
    d.text((16, 184), title, font=font(18, "medium"), fill=(236, 238, 242, 240))
    d.text((16, 212), "Swift", font=font(14, "mono"), fill=(140, 150, 165, 200))
    return im


def card_color(hex_s, name, rgb, w=248, h=268):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(255, 255, 255, 150))
    rr(d, (14, 14, w - 14, 176), 18, fill=rgb + (255,))
    d.text((20, 140), hex_s, font=font(18, "mono"), fill=(255, 255, 255, 240))
    d.text((16, 196), name, font=font(20, "medium"), fill=(22, 24, 28, 235))
    return im


def card_text(title, body, w=248, h=268):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rr(d, (0, 0, w - 1, h - 1), 28, fill=(255, 255, 255, 150))
    d.text((16, 18), title, font=font(18, "semibold"), fill=(22, 24, 28, 235))
    # wrap
    words = body.split()
    lines, cur = [], ""
    f = font(16)
    for word in words:
        trial = (cur + " " + word).strip()
        if d.textlength(trial, font=f) > w - 36:
            lines.append(cur)
            cur = word
        else:
            cur = trial
    if cur:
        lines.append(cur)
    for i, line in enumerate(lines[:7]):
        d.text((16, 54 + i * 22), line, font=f, fill=(50, 54, 60, 220))
    return im


def footer(img, box, label="6 items"):
    d = ImageDraw.Draw(img)
    x, y, x1, y1 = box
    d.text((x, y), label, font=font(18), fill=(80, 84, 92, 200))
    # keycap
    rr(d, (x1 - 168, y - 4, x1 - 78, y + 24), 6, fill=(255, 255, 255, 90), outline=(255, 255, 255, 80))
    d.text((x1 - 158, y - 1), "⌥ Space", font=font(14, "medium"), fill=(40, 44, 52, 220))
    d.text((x1 - 70, y + 2), "hide", font=font(16), fill=(120, 124, 132, 190))


def compose_panel(active, counts, cards, footer_label, subtitle="Hold this for me."):
    W, H = 1100, 1480
    img, mask = glass_bg((W, H), radius=78)
    d = ImageDraw.Draw(img)
    # header
    d.text((56, 52), active, font=font(42, "semibold"), fill=(18, 20, 24, 240))
    d.text((56, 108), subtitle, font=font(22), fill=(110, 114, 122, 200))
    icon_btn(d, (W - 56 - 34 * 4 - 18, 58), "clip")
    icon_btn(d, (W - 56 - 34 * 3 - 12, 58), "left")
    icon_btn(d, (W - 56 - 34 * 2 - 6, 58), "right")
    icon_btn(d, (W - 56 - 34, 58), "grid")
    search_pill(img, (56, 164, W - 56, 216))
    tabs(img, (56, 244, W - 56, 290), active=active, counts=counts)

    # cards 2x3
    ox, oy = 56, 330
    gap = 24
    cw, ch = 248, 268
    # scale cards to panel
    cw, ch = 470, 300
    positions = [
        (ox, oy), (ox + cw + gap, oy),
        (ox, oy + ch + gap), (ox + cw + gap, oy + ch + gap),
        (ox, oy + 2 * (ch + gap)), (ox + cw + gap, oy + 2 * (ch + gap)),
    ]
    for (px, py), card in zip(positions, cards):
        c = card.resize((cw, ch), Image.Resampling.LANCZOS)
        img.alpha_composite(c, (px, py))

    footer(img, (56, H - 86, W - 56, H - 50), footer_label)
    return ImageChops_min_alpha(img, mask)


def ImageChops_min_alpha(img, mask):
    r, g, b, a = img.split()
    a = ImageChops_darker(a, mask)
    img.putalpha(a)
    return img


def ImageChops_darker(a, b):
    from PIL import ImageChops
    return ImageChops.darker(a, b)


def add_hover(panel, which=0):
    img = panel.copy()
    d = ImageDraw.Draw(img)
    # selected ring on first card
    ox, oy = 56, 330
    cw, ch, gap = 470, 300, 24
    xs = [ox, ox + cw + gap]
    ys = [oy, oy + ch + gap, oy + 2 * (ch + gap)]
    col = which % 2
    row = which // 2
    x, y = xs[col], ys[row]
    d.rounded_rectangle((x - 4, y - 4, x + cw + 4, y + ch + 4), 34, outline=(10, 132, 255, 220), width=4)
    # description chip
    chip = Image.new("RGBA", (360, 72), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chip)
    rr(cd, (0, 0, 359, 71), 18, fill=(20, 22, 26, 210))
    cd.text((16, 10), "Coastal Highway", font=font(20, "semibold"), fill=(250, 250, 252, 255))
    cd.text((16, 38), "Image · Dropped just now · Open / Copy", font=font(14), fill=(190, 194, 200, 230))
    img.alpha_composite(chip, (x + 40, y + ch - 20))
    return img


def paint_standalone_items():
    # Large faces for 3D props
    faces = {
        "face_coastal": load_photo("coastal", (1024, 1024)),
        "face_lake": load_photo("lake", (1024, 1024)),
        "face_headphones": load_photo("headphones", (1024, 1024)),
        "face_fig": load_photo("fig", (1024, 1024)),
        "face_gallery": load_photo("gallery", (1024, 1024)),
        "face_note": load_photo("note", (1024, 1280)),
        "face_boarding": load_photo("boarding", (1400, 900)),
    }
    for name, im in faces.items():
        im.save(OUT / f"{name}.jpg", quality=92)

    # PDF page
    pdf = Image.new("RGB", (1000, 1300), (250, 249, 246))
    d = ImageDraw.Draw(pdf)
    d.rectangle((0, 0, 1000, 70), fill=(190, 32, 38))
    d.text((40, 20), "BRIEF  ·  Q3 LAUNCH", font=font(28, "semibold"), fill=(255, 255, 255))
    d.text((40, 110), "Shelf for Mac", font=font(44, "semibold"), fill=(22, 22, 24))
    d.text((40, 170), "The space between clipboard and Finder.", font=font(24), fill=(70, 72, 78))
    for i, line in enumerate([
        "Drop files, links, images, colours and snippets onto a floating shelf.",
        "Summon with Option-Space. Drag them back into any app later.",
        "Duplicates collapse. Links fetch a title on this Mac.",
        "OCR search lives on-device. Nothing is uploaded.",
        "",
        "1. Capture    2. Hold    3. Place",
    ]):
        d.text((40, 260 + i * 42), line, font=font(22), fill=(40, 42, 48))
    d.rectangle((40, 560, 960, 1180), outline=(220, 220, 224), width=2)
    d.text((60, 580), "Timeline", font=font(22, "semibold"), fill=(22, 22, 24))
    pdf.save(OUT / "face_pdf.jpg", quality=92)

    # Code poster
    code = Image.new("RGB", (1100, 800), (16, 18, 22))
    d = ImageDraw.Draw(code)
    lines = [
        ("struct ShelfItem: Identifiable {", (200, 210, 255)),
        ("    var id: UUID", (230, 230, 235)),
        ("    var title: String", (230, 230, 235)),
        ("    var type: ItemType", (180, 160, 255)),
        ("    var bookmark: Data?", (120, 220, 180)),
        ("}", (200, 210, 255)),
        ("", (230, 230, 235)),
        ("func capture(_ item: NSItemProvider) async {", (255, 180, 120)),
        ("    let hashed = await ContentHasher.sha256(item)", (120, 220, 180)),
        ("    if let existing = DuplicateDetector.match(hashed) {", (255, 107, 129)),
        ("        bringForward(existing)", (230, 230, 235)),
        ("        return", (230, 230, 235)),
        ("    }", (255, 107, 129)),
        ("    store.insert(item)", (200, 210, 255)),
        ("}", (255, 180, 120)),
    ]
    for i, (text, col) in enumerate(lines):
        d.text((48, 36 + i * 48), text, font=font(28, "mono"), fill=col)
    code.save(OUT / "face_code.jpg", quality=92)

    # Color chip
    chip = Image.new("RGB", (800, 800), (10, 132, 255))
    d = ImageDraw.Draw(chip)
    d.text((48, 680), "#0A84FF", font=font(48, "mono"), fill=(255, 255, 255))
    chip.save(OUT / "face_color_blue.jpg", quality=92)
    chip2 = Image.new("RGB", (800, 800), (255, 159, 10))
    d = ImageDraw.Draw(chip2)
    d.text((48, 680), "#FF9F0A", font=font(48, "mono"), fill=(255, 255, 255))
    chip2.save(OUT / "face_color_orange.jpg", quality=92)
    chip3 = Image.new("RGB", (800, 800), (191, 90, 242))
    d = ImageDraw.Draw(chip3)
    d.text((48, 680), "#BF5AF2", font=font(48, "mono"), fill=(255, 255, 255))
    chip3.save(OUT / "face_color_purple.jpg", quality=92)

    # Link card large
    link = Image.new("RGB", (1000, 640), (246, 247, 250))
    d = ImageDraw.Draw(link)
    d.rounded_rectangle((48, 48, 140, 140), 22, fill=(10, 132, 255))
    d.arc((68, 68, 120, 120), 40, 320, fill=(255, 255, 255), width=6)
    d.text((168, 60), "Human Interface", font=font(44, "semibold"), fill=(20, 22, 26))
    d.text((168, 120), "Guidelines", font=font(44, "semibold"), fill=(20, 22, 26))
    d.text((48, 220), "developer.apple.com", font=font(28), fill=(90, 94, 102))
    d.text((48, 320), "Layout, materials, and motion for\nsoftware that feels at home on Mac.", font=font(28), fill=(50, 54, 60))
    link.save(OUT / "face_link.jpg", quality=92)


def main():
    paint_standalone_items()

    inbox_cards = [
        card_photo("Coastal Highway", "coastal"),
        card_link("Human Interface", "developer.apple.com"),
        card_pdf("Q3 Launch Brief.pdf", 12),
        card_code("ShelfItem.swift", [
            "struct ShelfItem {",
            "  var id: UUID",
            "  var title: String",
            "  var hash: SHA256",
            "}",
            "func capture() async {",
            "  bringForward()",
        ]),
        card_photo("Alpine Lake", "lake"),
        card_color("#0A84FF", "System Blue", (10, 132, 255)),
    ]
    work_cards = [
        card_pdf("SOW — North Studio.pdf", 8),
        card_link("Linear · SHLF-142", "linear.app"),
        card_code("DuplicateDetector.swift", [
            "@MainActor",
            "func match(_ hash: String)",
            "  -> ShelfItem? {",
            "  items.first {",
            "    $0.contentHash == hash",
            "  }",
            "}",
        ]),
        card_photo("Studio Cans", "headphones"),
        card_pdf("Invoice 1842.pdf", 2),
        card_color("#1D1D1F", "Graphite", (29, 29, 31)),
    ]
    personal_cards = [
        card_photo("Sunday Figs", "fig"),
        card_photo("Pencil notes", "note"),
        card_photo("Quiet chair", "gallery"),
        card_text("Packing list", "Passport, cable, 35mm, black sweater, the book from the nightstand."),
        card_color("#FF9F0A", "Sunset", (255, 159, 10)),
        card_link("Reservations", "tables.example"),
    ]

    ui_inbox = compose_panel("Inbox", {"Inbox": 6, "Work": 3, "Personal": 4}, inbox_cards, "6 items")
    ui_work = compose_panel("Work", {"Inbox": 6, "Work": 6, "Personal": 4}, work_cards, "6 items · Work", "Client drops and briefs.")
    ui_personal = compose_panel("Personal", {"Inbox": 6, "Work": 6, "Personal": 6}, personal_cards, "6 items · Personal", "Keep for later.")
    ui_hover = add_hover(ui_inbox, 0)

    for name, im in [
        ("ui_inbox", ui_inbox),
        ("ui_work", ui_work),
        ("ui_personal", ui_personal),
        ("ui_hover", ui_hover),
    ]:
        im.save(OUT / f"{name}.png")
        print("wrote", name, im.size)

    print("done", OUT)


if __name__ == "__main__":
    main()
