"""Draw the Google Play feature graphic (1024x500) for each store language.

Usage: python3 tools/art/build_feature_graphic.py [--check]
Writes play-store/assets/feature-graphic-<locale>.png. The art is the product's own: the icon
gradient, the game fonts and four fruit cards from the card set, fanned like the title screen.
Each PNG carries the SHA-256 of everything it was drawn from (this script, the card icons and
the fonts), so --check exits 1 when a PNG is missing, has the wrong size or is out of date.
Drawing needs Pillow; --check does not.
"""
import hashlib
import pathlib
import sys

from build_store_art import STAMP_KEY, png_info

ROOT = pathlib.Path(__file__).resolve().parents[2]
STORE = ROOT / "play-store/assets"
ICONS = ROOT / "godot/game/assets/icons"
FONTS = ROOT / "godot/addons/seorilabs_game/fonts"
FREDOKA, JUA = FONTS / "Fredoka.ttf", FONTS / "Jua.ttf"

W, H, SCALE = 1024, 500, 2
WHITE, INK, LIP, DEPTH = "#FFFFFF", "#3A3470", "#C4CCF4", "#2A2078"
PURPLE_TOP, PURPLE_BOT, PURPLE_LIP = "#8A63FF", "#6C46E8", "#4A2DB8"
CORAL_TOP, CORAL_BOT, CORAL_LIP = "#FF8F6B", "#FF6A5C", "#D4463E"
BG_STOPS = ((0.0, "#58C4FF"), (0.46, "#6E8CFF"), (1.0, "#A56BFF"))
SHADE = (42, 32, 120, 102)
CARD_W, CARD_H = 128, 160

CARDS = ("banana", "lemon", "grapes", "strawberry")
TEXT = {
    "en-US": {"logo": "Four Alike", "sub": "Hidden Category Cards", "tag": "Fruit",
              "names": ("Banana", "Lemon", "Grapes", "Strawberry")},
    "ko-KR": {"logo": "끼리끼리", "sub": "연상 카드 퍼즐", "tag": "과일",
              "names": ("바나나", "레몬", "포도", "딸기")},
}


def output(locale):
    return STORE / f"feature-graphic-{locale}.png"


def inputs_digest():
    digest = hashlib.sha256()
    for path in [pathlib.Path(__file__), FREDOKA, JUA] + [ICONS / f"{name}.png" for name in CARDS]:
        digest.update(path.name.encode() + b"\0" + path.read_bytes())
    return digest.hexdigest()


def draw(locale, digest):
    from PIL import Image, ImageDraw, ImageFont
    from PIL.PngImagePlugin import PngInfo

    s = SCALE
    text = TEXT[locale]

    def rgb(value):
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))

    def font(path, size, weight=None):
        face = ImageFont.truetype(str(path), size * s)
        if weight is not None:
            face.set_variation_by_axes([weight])
        return face

    def title_font(size, weight):
        return font(JUA, size) if locale == "ko-KR" else font(FREDOKA, size, weight)

    def gradient(width, height, stops):
        img = Image.new("RGB", (1, height))
        for y in range(height):
            t = y / max(1, height - 1)
            for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0)
                    img.putpixel((0, y), tuple(round(a + (b - a) * k) for a, b in zip(rgb(c0), rgb(c1))))
                    break
        return img.resize((width, height))

    canvas = gradient(W * s, H * s, BG_STOPS).convert("RGBA")
    bubbles = Image.new("RGBA", canvas.size)
    bd = ImageDraw.Draw(bubbles)
    for x, y, r, a in ((0.06, 0.12, 0.30, 0.20), (0.50, 1.02, 0.34, 0.12), (0.97, 0.10, 0.26, 0.16), (0.80, 0.98, 0.18, 0.14)):
        cx, cy, rr = W * x * s, H * y * s, H * r * s
        bd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 255, 255, round(255 * a)))
    canvas = Image.alpha_composite(canvas, bubbles)

    def shadowed_text(layer, xy, value, face, fill, shade_dy, anchor, embolden=0):
        d = ImageDraw.Draw(layer)
        x, y = xy
        d.text((x, y + shade_dy * s), value, font=face, fill=SHADE, anchor=anchor, stroke_width=embolden, stroke_fill=SHADE)
        d.text((x, y), value, font=face, fill=fill, anchor=anchor, stroke_width=embolden, stroke_fill=fill)

    def card_face(icon, name):
        cw, ch, r = CARD_W * s, CARD_H * s, 22 * s
        pad = 30 * s
        layer = Image.new("RGBA", (cw + 2 * pad, ch + 2 * pad))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle((pad, pad + 14 * s, pad + cw, pad + ch + 14 * s), r, fill=rgb(DEPTH) + (70,))
        d.rounded_rectangle((pad, pad + 8 * s, pad + cw, pad + ch + 8 * s), r, fill=LIP)
        d.rounded_rectangle((pad, pad, pad + cw, pad + ch), r, fill=WHITE)
        art = Image.open(ICONS / f"{icon}.png").convert("RGBA").resize((92 * s, 92 * s), Image.LANCZOS)
        layer.alpha_composite(art, (pad + (cw - art.width) // 2, pad + 18 * s))
        size = 24 if locale == "ko-KR" else 21
        while True:
            face = font(JUA, size) if locale == "ko-KR" else font(FREDOKA, size, 600)
            if d.textlength(name, font=face) <= cw - 18 * s or size <= 12:
                break
            size -= 1
        d.text((pad + cw // 2, pad + 135 * s), name, font=face, fill=INK, anchor="mm")
        return layer

    def card_back():
        cw, ch, r = CARD_W * s, CARD_H * s, 22 * s
        pad = 30 * s
        layer = Image.new("RGBA", (cw + 2 * pad, ch + 2 * pad))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle((pad, pad + 8 * s, pad + cw, pad + ch + 8 * s), r, fill=PURPLE_LIP)
        d.rounded_rectangle((pad, pad, pad + cw, pad + ch), r, fill=WHITE)
        inner = gradient(cw - 12 * s, ch - 12 * s, ((0, PURPLE_TOP), (1, PURPLE_BOT))).convert("RGBA")
        mask = Image.new("L", inner.size)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), r - 6 * s, fill=255)
        layer.paste(inner, (pad + 6 * s, pad + 6 * s), mask)
        for row in range(9):
            for col in range(6):
                if (row + col) % 2 == 0:
                    cx, cy = pad + 20 * s + col * 19 * s, pad + 20 * s + row * 17 * s
                    d.ellipse((cx - 3 * s, cy - 3 * s, cx + 3 * s, cy + 3 * s), fill=(255, 255, 255, 220))
        return layer

    def place(layer, centre, angle):
        turned = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
        canvas.alpha_composite(turned, (round(centre[0] * s - turned.width / 2), round(centre[1] * s - turned.height / 2)))

    # Face-down cards peeking out behind the fan.
    place(card_back(), (604, 262), 16)
    place(card_back(), (912, 256), -14)
    # The fan of four fruit cards.
    for i, (icon, name) in enumerate(zip(CARDS, text["names"])):
        x = 594 + i * 112
        y = 300 + abs(i - 1.5) * 12
        place(card_face(icon, name), (x, y), (1.5 - i) * 6)

    # The category tag above the fan, as the game shows it after a correct group.
    tag_face = font(JUA, 30) if locale == "ko-KR" else font(FREDOKA, 28, 700)
    tag_layer = Image.new("RGBA", canvas.size)
    td = ImageDraw.Draw(tag_layer)
    left, top, right, bottom = td.textbbox((0, 0), text["tag"], font=tag_face, anchor="lt")
    tw, th = right - left, bottom - top
    cx, cy = 762 * s, 128 * s
    bw, bh = tw + 48 * s, max(th + 24 * s, 50 * s)
    box = (cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2)
    td.rounded_rectangle((box[0], box[1] + 6 * s, box[2], box[3] + 6 * s), bh / 2, fill=CORAL_LIP)
    td.rounded_rectangle(box, bh / 2, fill=CORAL_BOT)
    td.rounded_rectangle((box[0] + 4 * s, box[1] + 3 * s, box[2] - 4 * s, (box[1] + box[3]) / 2), bh / 3, fill=rgb(CORAL_TOP) + (200,))
    td.text((cx, cy), text["tag"], font=tag_face, fill=WHITE, anchor="mm")
    canvas = Image.alpha_composite(canvas, tag_layer)

    # Logo and subtitle on the left.
    words = Image.new("RGBA", canvas.size)
    if locale == "ko-KR":
        shadowed_text(words, (262 * s, 214 * s), text["logo"], title_font(112, None), WHITE, 6, "mm", embolden=3 * s)
        shadowed_text(words, (262 * s, 318 * s), text["sub"], font(JUA, 40), WHITE, 3, "mm", embolden=s)
    else:
        shadowed_text(words, (262 * s, 214 * s), text["logo"], title_font(98, 700), WHITE, 6, "mm")
        shadowed_text(words, (262 * s, 312 * s), text["sub"], font(FREDOKA, 36, 600), WHITE, 3, "mm")
    canvas = Image.alpha_composite(canvas, words)

    final = canvas.convert("RGB").resize((W, H), Image.LANCZOS)
    info = PngInfo()
    info.add_text(STAMP_KEY.decode("ascii"), digest)
    STORE.mkdir(parents=True, exist_ok=True)
    final.save(output(locale), pnginfo=info, optimize=True)


def main():
    check = "--check" in sys.argv
    digest = inputs_digest()
    if not check:
        for locale in TEXT:
            draw(locale, digest)
    bad = [str(output(locale).relative_to(ROOT)) for locale in TEXT if png_info(output(locale)) != (W, H, digest)]
    if bad:
        print("out of date (missing, wrong size, or drawn from other inputs):", *bad, sep="\n  ")
        return 1
    print("ok", len(TEXT), "feature graphics")
    return 0


if __name__ == "__main__":
    sys.exit(main())
