"""Make the Google Play phone screenshots (1080x1920) for each store language.

Usage: python3 tools/store/build_screenshots.py [--check] [--no-capture]
1. Runs Godot in rendering mode (not headless) with godot/tests/game/store_capture.gd. That script opens the
   real start scene, moves through it with screen taps and saves six raw screens per language under
   build/store-capture/<locale>/ (a 390x693 screen drawn at 3x). The clock, the random seed and the frame
   time (--fixed-fps) are fixed, so the same commit gives the same screens.
2. Draws each raw screen under its caption on the icon gradient with Pillow and writes
   play-store/screenshots/phone/<locale>/<name>.png.
--no-capture redraws from the raw screens already in build/store-capture/.
--check needs neither Godot nor Pillow: it exits 1 unless every listed screenshot exists as a 1080x1920 PNG
of at most 8 MB, no other file is in the screenshot folders and play-store/google-play.config.json lists the
same files in the same order. Rendering needs a display, so CI only checks.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
from build_feature_graphic import BG_STOPS, FREDOKA, JUA, SHADE  # noqa: E402
from build_store_art import png_info  # noqa: E402

OUT = ROOT / "play-store/screenshots/phone"
CONFIG = ROOT / "play-store/google-play.config.json"
RAW = ROOT / "build/store-capture"
CAPTURE_SCRIPT = "res://tests/game/store_capture.gd"
# Store locale -> game language.
LOCALES = {"en-US": "en", "ko-KR": "ko"}
# Screenshot order: the name of the raw screen and of the output file, and the caption per store locale.
# A caption wraps by itself; "\n" fixes the break where the even break would split a phrase.
SHOTS = (
    ("01-group", {"en-US": "Find four that belong together", "ko-KR": "어울리는 네 장을 찾아 묶어요"}),
    ("02-category", {"en-US": "The category shows when you get it", "ko-KR": "맞히면 숨은 범주가 드러나요"}),
    ("03-hold", {"en-US": "Move a card aside to reach the next", "ko-KR": "임시 칸에 옮겨 뒤 카드를 꺼내요"}),
    ("04-daily", {"en-US": "A new puzzle every day", "ko-KR": "매일 새로운 일일 도전"}),
    ("05-album", {"en-US": "Collect 158 categories", "ko-KR": "범주 158개를 도감에 모아요"}),
    ("06-decor", {"en-US": "Unlock card backs\nand themes", "ko-KR": "카드 뒷면과 배경을 꾸며요"}),
)

W, H = 1080, 1920
MAX_BYTES = 8 * 1024 * 1024
# The game screen: 390x693 logical, captured at 3x and drawn 844x1500 under the caption band.
RAW_SIZE = (1170, 2079)
SCREEN_W = 844
SCREEN_H = round(SCREEN_W * RAW_SIZE[1] / RAW_SIZE[0])
SCREEN_X = (W - SCREEN_W) // 2
SCREEN_Y = H - SCREEN_H - 66
RADIUS, RIM = 46, 9
# The caption band above the screen: two lines at most, centred.
CAPTION_WIDTH = 860
CAPTION_SIZE = {"en-US": 74, "ko-KR": 84}
CAPTION_MIN = 52
LINE_GAP = 1.18
# White caption with an indigo outline and drop, like the game's own button titles.
OUTLINE, OUTLINE_COLOR = 4, (74, 45, 184, 200)
GODOT_TRIES = 3
FOCUS_LOST = "The window lost focus"


def output(locale, name):
    return OUT / locale / f"{name}.png"


# =====================================================================
# Capture
# =====================================================================

def capture(locale):
    """Render the six raw screens of one language with Godot. Returns an error message, or "" on success."""
    godot = os.environ.get("GODOT", "godot")
    if shutil.which(godot) is None:
        return f"{godot} is not on PATH"
    out = RAW / locale
    command = [godot, "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", str(ROOT / "godot"),
               "--script", CAPTURE_SCRIPT, "--", "--out", str(out), "--language", LOCALES[locale]]
    log = ""
    for attempt in range(1, GODOT_TRIES + 1):
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        done = subprocess.run(command, capture_output=True, text=True, timeout=600)
        log = done.stdout + done.stderr
        (RAW / f"{locale}.log").write_text(log)
        failed = done.returncode != 0 or re.search(r"^(?:SCRIPT ERROR|ERROR:)", log, re.M)
        if not failed and journey_passed(out):
            return ""
        # Another window taking focus cancels a tap in flight. That run says so in its log; run it again.
        if FOCUS_LOST not in log or attempt == GODOT_TRIES:
            break
        print(f"{locale}: the Godot window lost focus (try {attempt}), capturing again", file=sys.stderr)
    return f"capturing {locale} failed, see {(RAW / f'{locale}.log').relative_to(ROOT)}:\n{log[-3000:]}"


def journey_passed(out):
    try:
        journey = json.loads((out / "journey.json").read_text())
    except (OSError, ValueError):
        return False
    scenarios = journey.get("scenarios", [])
    return bool(scenarios) and all(s.get("status") == "passed" for s in scenarios) \
        and all((out / f"{name}.png").is_file() for name, _ in SHOTS)


# =====================================================================
# Drawing
# =====================================================================

def draw(locale, name, caption):
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    def rgb(value):
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))

    def gradient(height):
        column = Image.new("RGB", (1, height))
        for y in range(height):
            t = y / max(1, height - 1)
            for (t0, c0), (t1, c1) in zip(BG_STOPS, BG_STOPS[1:]):
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0)
                    column.putpixel((0, y), tuple(round(a + (b - a) * k) for a, b in zip(rgb(c0), rgb(c1))))
                    break
        return column.resize((W, height))

    def rounded_mask(size, radius, scale=4):
        """Anti-aliased rounded rectangle mask, drawn large and scaled down."""
        big = Image.new("L", (size[0] * scale, size[1] * scale))
        ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * scale, fill=255)
        return big.resize(size, Image.LANCZOS)

    def caption_font(size):
        if locale == "ko-KR":
            return ImageFont.truetype(str(JUA), size)
        face = ImageFont.truetype(str(FREDOKA), size)
        face.set_variation_by_axes([700])
        return face

    canvas = gradient(H).convert("RGBA")
    bubbles = Image.new("RGBA", canvas.size)
    bd = ImageDraw.Draw(bubbles)
    for x, y, r, a in ((0.04, 0.05, 0.30, 0.18), (1.0, 0.16, 0.22, 0.14), (0.0, 0.70, 0.26, 0.12), (0.96, 0.95, 0.30, 0.14)):
        cx, cy, rr = W * x, H * y, W * r
        bd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 255, 255, round(255 * a)))
    canvas = Image.alpha_composite(canvas, bubbles)

    # Soft shadow and a white rim around the game screen so it stands apart from the same gradient inside it.
    outer = (SCREEN_W + 2 * RIM, SCREEN_H + 2 * RIM)
    shadow = Image.new("RGBA", canvas.size)
    shadow.paste(Image.new("RGBA", outer, SHADE[:3] + (110,)), (SCREEN_X - RIM, SCREEN_Y - RIM + 18), rounded_mask(outer, RADIUS + RIM))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(22)))
    canvas.paste(Image.new("RGBA", outer, (255, 255, 255, 255)), (SCREEN_X - RIM, SCREEN_Y - RIM), rounded_mask(outer, RADIUS + RIM))
    raw = Image.open(RAW / locale / f"{name}.png").convert("RGB")
    if raw.size != RAW_SIZE:
        raise ValueError(f"{name} ({locale}) was captured at {raw.size}, expected {RAW_SIZE}")
    screen = raw.resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    canvas.paste(screen, (SCREEN_X, SCREEN_Y), rounded_mask((SCREEN_W, SCREEN_H), RADIUS))

    # Caption: the largest size that fits in two lines, broken where the two lines are most even.
    measure = ImageDraw.Draw(canvas)
    size = CAPTION_SIZE[locale]
    while True:
        face = caption_font(size)
        lines = wrap(caption, lambda text: measure.textlength(text, font=face) + 2 * OUTLINE)
        if lines or size <= CAPTION_MIN:
            break
        size -= 2
    if not lines:
        raise ValueError(f"caption does not fit: {caption}")
    words = Image.new("RGBA", canvas.size)
    wd = ImageDraw.Draw(words)
    line_height = round(size * LINE_GAP)
    band_centre = (SCREEN_Y - RIM) / 2
    top = band_centre - line_height * (len(lines) - 1) / 2
    for index, line in enumerate(lines):
        y = top + index * line_height
        wd.text((W / 2, y + 7), line, font=face, fill=SHADE[:3] + (150,), anchor="mm", stroke_width=OUTLINE, stroke_fill=SHADE[:3] + (150,))
        wd.text((W / 2, y), line, font=face, fill="#FFFFFF", anchor="mm", stroke_width=OUTLINE, stroke_fill=OUTLINE_COLOR)
    canvas = Image.alpha_composite(canvas, words)

    path = output(locale, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)


def wrap(text, width):
    """One line if it fits, else the two-line break with the most even widths. [] when nothing fits."""
    if "\n" in text:
        lines = text.split("\n")
        return lines if len(lines) <= 2 and all(width(line) <= CAPTION_WIDTH for line in lines) else []
    if width(text) <= CAPTION_WIDTH:
        return [text]
    words = text.split(" ")
    best = []
    for cut in range(1, len(words)):
        lines = [" ".join(words[:cut]), " ".join(words[cut:])]
        widths = [width(line) for line in lines]
        if max(widths) <= CAPTION_WIDTH and (not best or max(widths) < max(width(line) for line in best)):
            best = lines
    return best


# =====================================================================
# Check
# =====================================================================

def problems():
    bad = []
    expected = {output(locale, name) for locale in LOCALES for name, _ in SHOTS}
    for path in sorted(expected):
        info = png_info(path)
        if info is None:
            bad.append(f"{path.relative_to(ROOT)} is missing or not a PNG")
        elif info[:2] != (W, H):
            bad.append(f"{path.relative_to(ROOT)} is {info[0]}x{info[1]}, expected {W}x{H}")
        elif path.stat().st_size > MAX_BYTES:
            bad.append(f"{path.relative_to(ROOT)} is over 8 MB")
    if OUT.is_dir():
        for path in sorted(OUT.rglob("*")):
            if path.is_file() and path not in expected:
                bad.append(f"{path.relative_to(ROOT)} is not a listed screenshot")
    config = json.loads(CONFIG.read_text())
    listed = {"en-US": config.get("assets", {}).get("phoneScreenshots"),
              "ko-KR": config.get("localizedAssets", {}).get("ko-KR", {}).get("phoneScreenshots")}
    for locale, paths in listed.items():
        wanted = [output(locale, name).relative_to(ROOT).as_posix() for name, _ in SHOTS]
        if paths != wanted:
            bad.append(f"{CONFIG.relative_to(ROOT)} does not list the {locale} phone screenshots in order")
    return bad


def main():
    args = sys.argv[1:]
    if "--check" not in args:
        for locale in LOCALES:
            if "--no-capture" not in args:
                error = capture(locale)
                if error:
                    print(error, file=sys.stderr)
                    return 1
            for name, captions in SHOTS:
                draw(locale, name, captions[locale])
    bad = problems()
    if bad:
        print("phone screenshots are not ready:", *bad, sep="\n  ")
        return 1
    print("ok", len(LOCALES) * len(SHOTS), "phone screenshots")
    return 0


if __name__ == "__main__":
    sys.exit(main())
