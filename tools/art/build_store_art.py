"""Write the app icon as SVG and render the store icon to PNG.

Usage: python3 tools/art/build_store_art.py [--check]
Writes the launcher icon layers under godot/game/assets and play-store/assets/icon-512.png.
The icon uses only original shapes: a chunky white card with four alike dots in front of
a face-down card. No emoji artwork is used. The PNG carries the SHA-256 of the SVG it was
rendered from, so --check exits 1 when an SVG on disk differs or the PNG is missing, has the
wrong size or was rendered from an older SVG.
"""
import hashlib
import pathlib
import shutil
import struct
import subprocess
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "godot/game/assets"
IOS_ICONS = ASSETS / "ios"
STORE = ROOT / "play-store/assets"
APP_STORE = ROOT / "app-store/assets"
RENDER = pathlib.Path(__file__).with_name("render_svg.gd")
IOS_ICON_SIZES = (1024, 180, 167, 152, 120, 87, 80, 60, 58, 40)

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
        # Store icon source: full-bleed square, Google Play and App Store apply their own masks.
        STORE / "icon-512.svg": square(512),
        APP_STORE / "icon-1024.svg": square(1024),
    }


PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
STAMP_KEY = b"Source-SHA256"


def png_chunks(data):
    """Yield (type, body) for each chunk of a PNG file's bytes."""
    at = len(PNG_MAGIC)
    while at + 8 <= len(data):
        size, kind = struct.unpack(">I4s", data[at:at + 8])
        yield kind, data[at + 8:at + 8 + size]
        at += 12 + size


def png_info(path):
    """(width, height, stamp) of a PNG, or None when the file is not a readable PNG."""
    if not path.is_file():
        return None
    data = path.read_bytes()
    if not data.startswith(PNG_MAGIC):
        return None
    size, stamp = None, ""
    for kind, body in png_chunks(data):
        if kind == b"IHDR":
            size = struct.unpack(">II", body[:8])
        elif kind == b"tEXt" and body.startswith(STAMP_KEY + b"\x00"):
            stamp = body[len(STAMP_KEY) + 1:].decode("ascii", "replace")
    return None if size is None else (size[0], size[1], stamp)


def stamp_png(path, digest):
    """Record which SVG the PNG came from as a text chunk right after the header chunk."""
    data = path.read_bytes()
    body = STAMP_KEY + b"\x00" + digest.encode("ascii")
    chunk = struct.pack(">I", len(body)) + b"tEXt" + body + struct.pack(">I", zlib.crc32(b"tEXt" + body))
    header_end = len(PNG_MAGIC) + 12 + struct.unpack(">I", data[len(PNG_MAGIC):len(PNG_MAGIC) + 4])[0]
    path.write_bytes(data[:header_end] + chunk + data[header_end:])


def render_store_icon(source, png, digest, expected_size=512, opaque_rgb=False):
    """Rasterise a store icon with the engine. Returns an error message, or "" on success."""
    if shutil.which("godot") is None:
        return f"godot is not on PATH, so {png.relative_to(ROOT)} was not rendered"
    png.parent.mkdir(parents=True, exist_ok=True)
    png.unlink(missing_ok=True)
    done = subprocess.run(["godot", "--headless", "--path", str(ROOT / "godot"), "--script", str(RENDER), "--",
                           str(source), str(png)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if done.returncode == 0 and opaque_rgb and png.is_file():
        from PIL import Image
        with Image.open(png) as img:
            img.convert("RGB").save(png, format="PNG")
    info = png_info(png)
    if done.returncode != 0 or info is None or info[:2] != (expected_size, expected_size):
        return f"rendering {png.relative_to(ROOT)} failed (exit {done.returncode}): {done.stderr.strip()[-400:]}"
    stamp_png(png, digest)
    return ""


def write_ios_icon_slots(master_png, digest):
    """Derive opaque RGB iOS AppIcon slot PNGs from the 1024x1024 master PNG."""
    from PIL import Image
    IOS_ICONS.mkdir(parents=True, exist_ok=True)
    with Image.open(master_png) as master:
        rgb = master.convert("RGB")
        for px in IOS_ICON_SIZES:
            out = IOS_ICONS / f"icon_{px}.png"
            resized = rgb if px == 1024 else rgb.resize((px, px), Image.Resampling.LANCZOS)
            resized.save(out, format="PNG")
            stamp_png(out, digest)


def main():
    check = "--check" in sys.argv
    bad = []
    generated = files()
    for path, text in generated.items():
        if check:
            if not path.exists() or path.read_text() != text:
                bad.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    source, png = STORE / "icon-512.svg", STORE / "icon-512.png"
    digest = hashlib.sha256(generated[source].encode()).hexdigest()
    ios_source, ios_png = APP_STORE / "icon-1024.svg", APP_STORE / "icon-1024.png"
    ios_digest = hashlib.sha256(generated[ios_source].encode()).hexdigest()
    if not check:
        for error in (
            render_store_icon(source, png, digest, 512, False),
            render_store_icon(ios_source, ios_png, ios_digest, 1024, True),
        ):
            if error:
                print(error, file=sys.stderr)
                return 1
        write_ios_icon_slots(ios_png, ios_digest)
    if png_info(png) != (512, 512, digest):
        bad.append(f"{png.relative_to(ROOT)} (missing, wrong size, or rendered from another SVG)")
    if png_info(ios_png) != (1024, 1024, ios_digest):
        bad.append(f"{ios_png.relative_to(ROOT)} (missing, wrong size, or rendered from another SVG)")
    for px in IOS_ICON_SIZES:
        slot = IOS_ICONS / f"icon_{px}.png"
        if png_info(slot) != (px, px, ios_digest):
            bad.append(f"{slot.relative_to(ROOT)} (missing, wrong size, or rendered from another SVG)")
    if bad:
        print("out of date:", *bad, sep="\n  ")
        return 1
    print("ok", len(generated), "icon files, icon-512.png, icon-1024.png and iOS AppIcons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
