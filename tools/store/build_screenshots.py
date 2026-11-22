"""Make Google Play (1080x1920) and App Store 6.9" (1320x2868) screenshots per store language.

Usage: python3 tools/store/build_screenshots.py [--target play|ios|all] [--check] [--no-capture]
1. Runs Godot in rendering mode (not headless) with godot/tests/game/store_capture.gd. That script opens the
   real start scene, moves through it with screen taps and saves six raw screens per language under
   build/store-capture*/<locale>/ (logical phone screen drawn at 3x). The clock, the random seed and the frame
   time (--fixed-fps) are fixed, so the same commit gives the same screens.
2. Draws each raw screen under its caption on the icon gradient with Pillow and writes the configured store
   screenshot paths.
--no-capture redraws from the raw screens already in build/.
--check needs neither Godot nor Pillow: it exits 1 unless every listed screenshot exists at the exact size,
under the store size limit, with no stray files, matching each store config in order. Rendering needs a display,
so CI only checks.
"""
from dataclasses import dataclass
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

CAPTURE_SCRIPT = "res://tests/game/store_capture.gd"
# Screenshot order: the name of the raw screen and of the output file, and the caption per game language.
# A caption wraps by itself; "\n" fixes the break where the even break would split a phrase.
SHOTS = (
    ("01-group", {"en": "Find four that belong together", "ko": "어울리는 네 장을 찾아 묶어요"}),
    ("02-category", {"en": "The category shows when you get it", "ko": "맞히면 숨은 범주가 드러나요"}),
    ("03-hold", {"en": "Move a card aside to reach the next", "ko": "임시 칸에 옮겨 뒤 카드를 꺼내요"}),
    ("04-daily", {"en": "A new puzzle every day", "ko": "매일 새로운 일일 도전"}),
    ("05-album", {"en": "Collect 158 categories", "ko": "범주 158개를 도감에 모아요"}),
    ("06-decor", {"en": "Unlock card backs\nand themes", "ko": "카드 뒷면과 배경을 꾸며요"}),
)

MAX_BYTES = 8 * 1024 * 1024
LINE_GAP = 1.18
# White caption with an indigo outline and drop, like the game's own button titles.
OUTLINE_COLOR = (74, 45, 184, 200)
GODOT_TRIES = 3
FOCUS_LOST = "The window lost focus"


@dataclass(frozen=True)
class StoreTarget:
    """Layout, capture dimensions and manifest rules for one store screenshot set."""
    name: str
    out_dir: pathlib.Path
    raw_dir: pathlib.Path
    config_path: pathlib.Path
    locales: dict[str, str]
    logical_size: tuple[int, int]
    size: tuple[int, int]
    screen_w: int
    bottom_margin: int
    radius: int
    rim: int
    caption_width: int
    caption_size: dict[str, int]
    caption_min: int
    outline: int
    shadow_offset: int
    blur_radius: int

    @property
    def raw_size(self) -> tuple[int, int]:
        return (self.logical_size[0] * 3, self.logical_size[1] * 3)

    @property
    def screen_h(self) -> int:
        return round(self.screen_w * self.raw_size[1] / self.raw_size[0])

    @property
    def screen_x(self) -> int:
        return (self.size[0] - self.screen_w) // 2

    @property
    def screen_y(self) -> int:
        return self.size[1] - self.screen_h - self.bottom_margin


TARGETS = {
    "play": StoreTarget(
        name="phone",
        out_dir=ROOT / "play-store/screenshots/phone",
        raw_dir=ROOT / "build/store-capture",
        config_path=ROOT / "play-store/google-play.config.json",
        locales={"en-US": "en", "ko-KR": "ko"},
        logical_size=(390, 693),
        size=(1080, 1920),
        screen_w=844,
        bottom_margin=66,
        radius=46,
        rim=9,
        caption_width=860,
        caption_size={"en": 74, "ko": 84},
        caption_min=52,
        outline=4,
        shadow_offset=18,
        blur_radius=22,
    ),
    "ios": StoreTarget(
        name="app-store-69",
        out_dir=ROOT / "app-store/screenshots",
        raw_dir=ROOT / "build/store-capture-ios",
        config_path=ROOT / "app-store/app-store.config.json",
        locales={"en-US": "en", "ko": "ko"},
        logical_size=(390, 844),
        size=(1320, 2868),
        screen_w=1044,
        bottom_margin=92,
        radius=62,
        rim=11,
        caption_width=1060,
        caption_size={"en": 92, "ko": 104},
        caption_min=64,
        outline=5,
        shadow_offset=22,
        blur_radius=28,
    ),
}


def output(target: StoreTarget, locale: str, name: str) -> pathlib.Path:
    return target.out_dir / locale / f"{name}.png"


# =====================================================================
# Capture
# =====================================================================

def capture(target: StoreTarget, locale: str) -> str:
    """Render the six raw screens of one language with Godot. Returns an error message, or "" on success."""
    godot = os.environ.get("GODOT", "godot")
    if shutil.which(godot) is None:
        return f"{godot} is not on PATH"
    out = target.raw_dir / locale
    size_arg = f"{target.logical_size[0]}x{target.logical_size[1]}"
    command = [
        godot, "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", str(ROOT / "godot"),
        "--script", CAPTURE_SCRIPT, "--",
        "--out", str(out), "--language", target.locales[locale], "--size", size_arg,
    ]
    log = ""
    for attempt in range(1, GODOT_TRIES + 1):
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        done = subprocess.run(command, capture_output=True, text=True, timeout=600)
        log = done.stdout + done.stderr
        (target.raw_dir / f"{locale}.log").write_text(log)
        failed = done.returncode != 0 or re.search(r"^(?:SCRIPT ERROR|ERROR:)", log, re.M)
        if not failed and journey_passed(out):
            return ""
        # Another window taking focus cancels a tap in flight. That run says so in its log; run it again.
        if FOCUS_LOST not in log or attempt == GODOT_TRIES:
            break
        print(f"{target.name}/{locale}: the Godot window lost focus (try {attempt}), capturing again", file=sys.stderr)
    return f"capturing {target.name}/{locale} failed, see {(target.raw_dir / f'{locale}.log').relative_to(ROOT)}:\n{log[-3000:]}"


def journey_passed(out: pathlib.Path) -> bool:
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

def draw(target: StoreTarget, locale: str, name: str, captions: dict[str, str]) -> None:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    lang = target.locales[locale]
    caption = captions[lang]
    w, h = target.size

    def rgb(value: str) -> tuple[int, ...]:
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))

    def gradient(height: int):
        column = Image.new("RGB", (1, height))
        for y in range(height):
            t = y / max(1, height - 1)
            for (t0, c0), (t1, c1) in zip(BG_STOPS, BG_STOPS[1:]):
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0)
                    column.putpixel((0, y), tuple(round(a + (b - a) * k) for a, b in zip(rgb(c0), rgb(c1))))
                    break
        return column.resize((w, height))

    def rounded_mask(size: tuple[int, int], radius: int, scale: int = 4):
        """Anti-aliased rounded rectangle mask, drawn large and scaled down."""
        big = Image.new("L", (size[0] * scale, size[1] * scale))
        ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * scale, fill=255)
        return big.resize(size, Image.LANCZOS)

    def caption_font(size: int):
        if lang == "ko":
            return ImageFont.truetype(str(JUA), size)
        face = ImageFont.truetype(str(FREDOKA), size)
        face.set_variation_by_axes([700])
        return face

    canvas = gradient(h).convert("RGBA")
    bubbles = Image.new("RGBA", canvas.size)
    bd = ImageDraw.Draw(bubbles)
    for x, y, r, a in ((0.04, 0.05, 0.30, 0.18), (1.0, 0.16, 0.22, 0.14), (0.0, 0.70, 0.26, 0.12), (0.96, 0.95, 0.30, 0.14)):
        cx, cy, rr = w * x, h * y, w * r
        bd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 255, 255, round(255 * a)))
    canvas = Image.alpha_composite(canvas, bubbles)

    # Soft shadow and a white rim around the game screen so it stands apart from the same gradient inside it.
    outer = (target.screen_w + 2 * target.rim, target.screen_h + 2 * target.rim)
    shadow = Image.new("RGBA", canvas.size)
    shadow.paste(
        Image.new("RGBA", outer, SHADE[:3] + (110,)),
        (target.screen_x - target.rim, target.screen_y - target.rim + target.shadow_offset),
        rounded_mask(outer, target.radius + target.rim),
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(target.blur_radius)))
    canvas.paste(
        Image.new("RGBA", outer, (255, 255, 255, 255)),
        (target.screen_x - target.rim, target.screen_y - target.rim),
        rounded_mask(outer, target.radius + target.rim),
    )
    raw = Image.open(target.raw_dir / locale / f"{name}.png").convert("RGB")
    if raw.size != target.raw_size:
        raise ValueError(f"{target.name}/{name} ({locale}) was captured at {raw.size}, expected {target.raw_size}")
    screen = raw.resize((target.screen_w, target.screen_h), Image.LANCZOS)
    canvas.paste(screen, (target.screen_x, target.screen_y), rounded_mask((target.screen_w, target.screen_h), target.radius))

    # Caption: the largest size that fits in two lines, broken where the two lines are most even.
    measure = ImageDraw.Draw(canvas)
    size = target.caption_size[lang]
    while True:
        face = caption_font(size)
        lines = wrap(caption, lambda text: measure.textlength(text, font=face) + 2 * target.outline, target.caption_width)
        if lines or size <= target.caption_min:
            break
        size -= 2
    if not lines:
        raise ValueError(f"caption does not fit: {caption}")
    words = Image.new("RGBA", canvas.size)
    wd = ImageDraw.Draw(words)
    line_height = round(size * LINE_GAP)
    band_centre = (target.screen_y - target.rim) / 2
    top = band_centre - line_height * (len(lines) - 1) / 2
    drop_y = max(7, round(target.outline * 1.6))
    for index, line in enumerate(lines):
        y = top + index * line_height
        wd.text((w / 2, y + drop_y), line, font=face, fill=SHADE[:3] + (150,), anchor="mm",
                stroke_width=target.outline, stroke_fill=SHADE[:3] + (150,))
        wd.text((w / 2, y), line, font=face, fill="#FFFFFF", anchor="mm",
                stroke_width=target.outline, stroke_fill=OUTLINE_COLOR)
    canvas = Image.alpha_composite(canvas, words)

    path = output(target, locale, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)


def wrap(text: str, width, max_width: int) -> list[str]:
    """One line if it fits, else the two-line break with the most even widths. [] when nothing fits."""
    if "\n" in text:
        lines = text.split("\n")
        return lines if len(lines) <= 2 and all(width(line) <= max_width for line in lines) else []
    if width(text) <= max_width:
        return [text]
    words = text.split(" ")
    best = []
    for cut in range(1, len(words)):
        lines = [" ".join(words[:cut]), " ".join(words[cut:])]
        widths = [width(line) for line in lines]
        if max(widths) <= max_width and (not best or max(widths) < max(width(line) for line in best)):
            best = lines
    return best


# =====================================================================
# Check
# =====================================================================

def configured_paths(target: StoreTarget) -> dict[str, list[str] | None]:
    config = json.loads(target.config_path.read_text())
    if target.name == "phone":
        return {
            "en-US": config.get("assets", {}).get("phoneScreenshots"),
            "ko-KR": config.get("localizedAssets", {}).get("ko-KR", {}).get("phoneScreenshots"),
        }
    screenshots = config.get("screenshots", {})
    return {locale: screenshots.get(locale, {}).get("iphone69") for locale in target.locales}


def problems(target: StoreTarget) -> list[str]:
    bad = []
    expected = {output(target, locale, name) for locale in target.locales for name, _ in SHOTS}
    for path in sorted(expected):
        info = png_info(path)
        if info is None:
            bad.append(f"{path.relative_to(ROOT)} is missing or not a PNG")
        elif info[:2] != target.size:
            bad.append(f"{path.relative_to(ROOT)} is {info[0]}x{info[1]}, expected {target.size[0]}x{target.size[1]}")
        elif path.stat().st_size > MAX_BYTES:
            bad.append(f"{path.relative_to(ROOT)} is over 8 MB")
    if target.out_dir.is_dir():
        for path in sorted(target.out_dir.rglob("*")):
            if path.is_file() and path not in expected:
                bad.append(f"{path.relative_to(ROOT)} is not a listed screenshot")
    for locale, paths in configured_paths(target).items():
        wanted = [output(target, locale, name).relative_to(ROOT).as_posix() for name, _ in SHOTS]
        if paths != wanted:
            bad.append(f"{target.config_path.relative_to(ROOT)} does not list the {locale} {target.name} screenshots in order")
    return bad


def parse_targets(args: list[str]) -> list[StoreTarget]:
    if "--target" in args:
        idx = args.index("--target")
        if idx + 1 >= len(args):
            raise SystemExit("missing value for --target (play, ios, all)")
        choice = args[idx + 1]
        if choice == "all":
            return [TARGETS["play"], TARGETS["ios"]]
        if choice in TARGETS:
            return [TARGETS[choice]]
        raise SystemExit(f"unknown --target: {choice}")
    return [TARGETS["play"], TARGETS["ios"]]


def main() -> int:
    args = sys.argv[1:]
    selected = parse_targets(args)
    if "--check" not in args:
        for target in selected:
            for locale in target.locales:
                if "--no-capture" not in args:
                    error = capture(target, locale)
                    if error:
                        print(error, file=sys.stderr)
                        return 1
                for name, captions in SHOTS:
                    draw(target, locale, name, captions)
    bad = [item for target in selected for item in problems(target)]
    if bad:
        print("store screenshots are not ready:", *bad, sep="\n  ")
        return 1
    total = sum(len(t.locales) * len(SHOTS) for t in selected)
    names = ", ".join(t.name for t in selected)
    print(f"ok {total} store screenshots ({names})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
