"""Write the app icon as SVG and render the store icon to PNG.

Usage: python3 tools/art/build_store_art.py [--check]
Writes the launcher icon layers under godot/game/assets and play-store/assets/icon-512.png.
The icon uses only original shapes: a chunky white card with four alike dots in front of
a face-down card. No emoji artwork is used. --check exits 1 when an SVG on disk differs
or the PNG is missing or has the wrong size.
"""
import pathlib
import struct
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "godot/game/assets"
STORE = ROOT / "play-store/assets"
RENDER = pathlib.Path(__file__).with_name("render_svg.gd")

BG = '<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#58C4FF"/><stop offset="0.46" stop-color="#6E8CFF"/><stop offset="1" stop-color="#A56BFF"/></linearGradient>'
BACK = '<linearGradient id="bk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8A63FF"/><stop offset="1" stop-color="#6C46E8"/></linearGradient>'
DOT = '<linearGradient id="dot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD23F"/><stop offset="1" stop-color="#FF8A00"/></linearGradient>'
DEFS = BG + BACK + DOT
DOTS = ((-72, -92), (72, -92), (-72, 60), (72, 60))
# Geometry of the two-card art in its own units: the middle of its bounding box, and the centre and
# radius of the smallest circle around it. Icons are laid out from these so nothing gets cropped.
BOX_CENTRE = (36, 1)
CIRCLE_CENTRE, CIRCLE_RADIUS = (46, 16), 298
# Adaptive icons: launchers only guarantee the centre circle of radius 132 on the 432 canvas.
ADAPTIVE_SCALE = 0.41
ADAPTIVE_AT = (216 - CIRCLE_CENTRE[0] * ADAPTIVE_SCALE, 216 - CIRCLE_CENTRE[1] * ADAPTIVE_SCALE)
assert CIRCLE_RADIUS * ADAPTIVE_SCALE <= 124
# The themed (one-colour) icon shows the front card alone, so it is centred on that card (at -40, 10).
MONO_SCALE = 0.46
MONO_AT = (216 + 40 * MONO_SCALE, 216 - 10 * MONO_SCALE)


def card_group(cx, cy, scale):
    """Front card 300x400 over a tilted face-down card, centred near (cx, cy) before scaling."""
    dots = "".join(
        f'<circle cx="{x}" cy="{y + 8}" r="52" fill="#C55A00"/><circle cx="{x}" cy="{y}" r="52" fill="url(#dot)"/>'
        f'<path d="M{x - 34} {y - 14}a36 36 0 0 1 68 0 36 22 0 0 0-68 0z" fill="#FFFFFF" fill-opacity="0.5"/>'
        for x, y in DOTS)
    polka = "".join(
        f'<circle cx="{-110 + c * 44 + (22 if r % 2 else 0)}" cy="{-160 + r * 40}" r="8" fill="#FFFFFF" fill-opacity="0.9"/>'
        for r in range(9) for c in range(6))
    back = (f'<g transform="translate(96 -34) rotate(14)">'
            f'<rect x="-150" y="-176" width="300" height="400" rx="56" fill="#4A2DB8"/>'
            f'<rect x="-150" y="-200" width="300" height="400" rx="56" fill="#FFFFFF"/>'
            f'<rect x="-134" y="-184" width="268" height="368" rx="42" fill="url(#bk)"/>{polka}</g>')
    front = (f'<g transform="translate(-40 10) rotate(-8)">'
             f'<rect x="-150" y="-164" width="300" height="400" rx="56" fill="#2A2078" fill-opacity="0.28"/>'
             f'<rect x="-150" y="-176" width="300" height="400" rx="56" fill="#C4CCF4"/>'
             f'<rect x="-150" y="-200" width="300" height="400" rx="56" fill="#FFFFFF"/>{dots}</g>')
    return f'<g transform="translate({cx} {cy}) scale({scale})">{back}{front}</g>'


def monochrome(cx, cy, scale):
    """One-colour silhouette for themed icons: the front card outline and its four dots."""
    dots = "".join(f'<circle cx="{x}" cy="{y}" r="46"/>' for x, y in DOTS)
    return (f'<g transform="translate({cx} {cy}) scale({scale}) translate(-40 10) rotate(-8)">'
            f'<rect x="-136" y="-186" width="272" height="372" rx="44" fill="none" stroke="#000000" stroke-width="28"/>{dots}</g>')


def bubbles(w, h):
    spots = ((0.12, 0.18, 0.18, 0.22), (0.92, 0.3, 0.26, 0.16), (0.2, 0.86, 0.3, 0.13), (0.86, 0.94, 0.16, 0.18))
    return "".join(f'<circle cx="{w * x}" cy="{h * y}" r="{min(w, h) * r}" fill="#FFFFFF" fill-opacity="{a}"/>' for x, y, r, a in spots)


def svg(w, h, body, defs=DEFS):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>\n'


def square(size, radius=0):
    """Full icon on a gradient square. radius rounds the corners for launchers without adaptive icons."""
    clip = f'<clipPath id="r"><rect width="{size}" height="{size}" rx="{radius}"/></clipPath>' if radius else ""
    group = ' clip-path="url(#r)"' if radius else ""
    scale = round(size / 512 * 0.84, 4)
    at = (round(size / 2 - BOX_CENTRE[0] * scale, 2), round(size / 2 - BOX_CENTRE[1] * scale, 2))
    return svg(size, size, f'<g{group}><rect width="{size}" height="{size}" fill="url(#bg)"/>{bubbles(size, size)}'
               f'{card_group(*at, scale)}</g>', DEFS + clip)


def files():
    return {
        # Legacy launcher icon and the project icon.
        ASSETS / "icon.svg": square(192, 42),
        # Adaptive icon layers.
        ASSETS / "icon_background.svg": svg(432, 432, f'<rect width="432" height="432" fill="url(#bg)"/>{bubbles(432, 432)}'),
        ASSETS / "icon_foreground.svg": svg(432, 432, card_group(*ADAPTIVE_AT, ADAPTIVE_SCALE)),
        ASSETS / "icon_monochrome.svg": svg(432, 432, monochrome(*MONO_AT, MONO_SCALE), ""),
        # Store icon source: full-bleed square, Google Play applies its own mask.
        STORE / "icon-512.svg": square(512),
    }


def png_size(path):
    with open(path, "rb") as handle:
        head = handle.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def main():
    check = "--check" in sys.argv
    bad = []
    for path, text in files().items():
        if check:
            if not path.exists() or path.read_text() != text:
                bad.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    png = STORE / "icon-512.png"
    if check:
        if not png.is_file() or png_size(png) != (512, 512):
            bad.append(str(png.relative_to(ROOT)))
    else:
        subprocess.run(["godot", "--headless", "--path", str(ROOT / "godot"), "--script", str(RENDER), "--",
                        str(STORE / "icon-512.svg"), str(png)], check=True, stdout=subprocess.DEVNULL)
        if png_size(png) != (512, 512):
            bad.append(str(png.relative_to(ROOT)))
    if bad:
        print("out of date:", *bad, sep="\n  ")
        return 1
    print("ok", len(files()), "icon files and icon-512.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
