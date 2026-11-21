"""Write the Candy Pop skin and play-screen textures as SVG.

Usage: python3 tools/art/build_candy_pop.py [--check]
Writes godot/game/skins/candy_pop and godot/game/features/play/assets. Every file is derived from the constants below, so the art can be regenerated and
compared byte for byte (--check exits 1 when a file on disk differs).
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIN_DIR = ROOT / "godot/game/skins/candy_pop"
PLAY_DIR = ROOT / "godot/game/features/play/assets"

# ---- palette (from the approved direction B mockup) ----
WHITE = "#FFFFFF"
INK = "#3A3470"
LIP = "#C4CCF4"
DEPTH = "#2A2078"
YELLOW = "#FFC61A"
YELLOW_DEEP = "#E19A00"
ORANGE_TOP, ORANGE_MID, ORANGE_BOT, ORANGE_LIP = "#FFD23F", "#FFA41B", "#FF8A00", "#C55A00"
PURPLE_TOP, PURPLE_BOT, PURPLE_LIP = "#8A63FF", "#6C46E8", "#4A2DB8"
CORAL_TOP, CORAL_BOT, CORAL_LIP = "#FF8F6B", "#FF6A5C", "#D4463E"
GREEN, GREEN_LIP = "#48D46A", "#1F9A45"
SKY_TOP, SKY_BOT, SKY_LIP = "#7FE3FF", "#35B6F5", "#1881C4"
VIOLET_TOP, VIOLET_BOT, VIOLET_LIP = "#C9A4FF", "#9A6BFF", "#6238CC"
NAVY = "#221C6E"
GOLD = "#FFD54A"
GOLD_LIP = "#D99A00"
RED = "#FF4B5C"


def svg(w, h, body, defs=""):
    d = f"<defs>{defs}</defs>" if defs else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{d}{body}</svg>\n'


def grad(gid, stops, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rect(x, y, w, h, r, fill, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" {extra}/>'


def skin_files():
    f = {}
    # primary button: white outline 3, body 0..54, lip 7
    def primary(top, mid, bot, lip, press=0):
        defs = grad("g", [(0, top), (0.55, mid), (1, bot)])
        y = press
        body = (rect(0, y, 104, 64 - press + 6, 24, WHITE)
                + rect(3, 10, 98, 57, 21, lip)
                + rect(3, 3 + y, 98, 57, 21, "url(#g)")
                + rect(11, 8 + y, 82, 13, 6.5, WHITE, 'fill-opacity="0.45"'))
        return svg(104, 70, body, defs)
    f["ui_button_primary_normal.svg"] = primary(ORANGE_TOP, ORANGE_MID, ORANGE_BOT, ORANGE_LIP)
    f["ui_button_primary_pressed.svg"] = primary(ORANGE_MID, ORANGE_BOT, "#F07C00", ORANGE_LIP, press=4)
    f["ui_button_primary_disabled.svg"] = primary("#D9DCEF", "#C5C9E3", "#B4B9D8", "#8F95BC")

    def secondary(press=0, face=WHITE, lip=LIP):
        y = press
        body = (rect(2, 8, 92, 50, 18, lip)
                + rect(2, 2 + y, 92, 50, 18, face, f'stroke="{lip}" stroke-width="1.5"'))
        return svg(96, 60, body)
    f["ui_button_secondary_normal.svg"] = secondary()
    f["ui_button_secondary_pressed.svg"] = secondary(press=4)
    f["ui_button_secondary_disabled.svg"] = secondary(face="#E3E5F2", lip="#B4B9D8")

    f["ui_panel.svg"] = svg(72, 72, rect(1, 7, 70, 64, 20, LIP) + rect(1, 1, 70, 64, 20, WHITE, f'stroke="{LIP}" stroke-width="1.5"'))
    f["ui_popup_frame.svg"] = svg(
        112, 116,
        rect(0, 0, 112, 116, 34, WHITE)
        + rect(4, 12, 104, 100, 30, PURPLE_LIP)
        + rect(4, 4, 104, 100, 30, WHITE)
        + rect(4, 4, 104, 100, 30, "none", f'stroke="{LIP}" stroke-width="2"'),
    )
    f["ui_chip.svg"] = svg(
        72, 40,
        rect(1, 1, 70, 38, 19, NAVY, 'fill-opacity="0.62"')
        + rect(2, 2, 68, 36, 18, "none", f'stroke="{WHITE}" stroke-opacity="0.38" stroke-width="2"'),
    )
    f["icon_coin.svg"] = svg(
        48, 48,
        '<circle cx="24" cy="26" r="21" fill="#D98A00"/><circle cx="24" cy="23" r="21" fill="#FFC83D"/>'
        '<circle cx="24" cy="23" r="15" fill="#FFE27A" stroke="#F0A800" stroke-width="3"/>'
        '<path d="M24 13l3 6.6 7.2.8-5.4 4.9 1.5 7.1L24 28.8l-6.3 3.6 1.5-7.1-5.4-4.9 7.2-.8z" fill="#F0A800"/>',
    )
    f["skin.json"] = json.dumps({
        "id": "candy-pop",
        "contract": "1.1.0",
        "background": "#6E8CFF",
        "panel": "#FFFFFF",
        "text": INK,
        "primary": ORANGE_MID,
        "focus": "#FFE27A",
        "textures": {
            "button_primary": {"normal": "ui_button_primary_normal.svg", "pressed": "ui_button_primary_pressed.svg", "disabled": "ui_button_primary_disabled.svg", "margins": [26, 24, 26, 30], "content": [22, 10, 22, 18], "minimum": [72, 56]},
            "button_secondary": {"normal": "ui_button_secondary_normal.svg", "pressed": "ui_button_secondary_pressed.svg", "disabled": "ui_button_secondary_disabled.svg", "margins": [22, 20, 22, 26], "content": [16, 8, 16, 14], "minimum": [56, 48]},
            "panel": {"normal": "ui_panel.svg", "margins": [24, 24, 24, 30], "content": [16, 12, 16, 18], "minimum": [56, 56]},
            "popup_frame": {"normal": "ui_popup_frame.svg", "margins": [38, 38, 38, 46], "content": [22, 20, 22, 30], "minimum": [96, 96]},
            "chip": {"normal": "ui_chip.svg", "margins": [22, 14, 22, 14], "content": [10, 4, 10, 4], "minimum": [56, 36]},
        },
        "icons": {"coin": "icon_coin.svg"},
        "fonts": {
            "display_en": "res://addons/seorilabs_game/fonts/Fredoka.ttf",
            "display_ko": "res://addons/seorilabs_game/fonts/Jua.ttf",
            "body": "res://addons/seorilabs_game/fonts/NotoSansKR.ttf",
            "number": "res://addons/seorilabs_game/fonts/NotoSansMono.ttf",
        },
        "sizes": {"body": 16, "label": 14, "title": 24, "display": 34, "action": 22, "number": 18},
        "motion": {"press_punch_ms": 100, "pop_in_ms": 220, "pop_out_ms": 140, "reward_anticipation_ms": 400, "reward_impact_ms": 200, "reward_settle_ms": 500, "count_up_ms": 600, "toast_ms": 2000},
    }, ensure_ascii=False, indent=2) + "\n"
    return f


def play_files():
    f = {}
    shadow = f'fill="{DEPTH}" fill-opacity="0.28"'
    # card face: body 64x64, lip 6, depth shadow 3 (9-slice margins 20/20/20/29)
    f["card_face.svg"] = svg(64, 73, rect(0, 9, 64, 64, 16, DEPTH, 'fill-opacity="0.28"') + rect(0, 6, 64, 64, 16, LIP) + rect(0, 0, 64, 64, 16, WHITE))
    f["card_selected.svg"] = svg(
        72, 82,
        rect(0, 10, 72, 72, 20, YELLOW_DEEP) + rect(0, 0, 72, 72, 20, YELLOW) + rect(4, 4, 64, 64, 16, WHITE))
    f["card_hint.svg"] = svg(
        72, 82,
        rect(0, 10, 72, 72, 20, SKY_LIP) + rect(0, 0, 72, 72, 20, SKY_BOT) + rect(4, 4, 64, 64, 16, WHITE))
    dots = "".join(
        f'<circle cx="{x}" cy="{y}" r="2.6" fill="{WHITE}" fill-opacity="0.9"/>'
        for row in range(11) for col in range(8)
        for x, y in [(10 + col * 16 + (8 if row % 2 else 0), 10 + row * 12)] if 6 < x < 122 and 6 < y < 132)
    f["card_back.svg"] = svg(
        128, 147,
        rect(0, 9, 128, 138, 24, DEPTH, 'fill-opacity="0.28"') + rect(0, 6, 128, 138, 24, PURPLE_LIP)
        + rect(0, 0, 128, 138, 24, WHITE) + rect(6, 6, 116, 126, 18, "url(#g)")
        + f'<g clip-path="url(#c)">{dots}</g>',
        grad("g", [(0, PURPLE_TOP), (1, PURPLE_BOT)]) + '<clipPath id="c"><rect x="6" y="6" width="116" height="126" rx="18"/></clipPath>')
    f["cell_empty.svg"] = svg(64, 64, rect(0, 0, 64, 64, 16, "#281E82", 'fill-opacity="0.22"') + '<path d="M16 0h32a16 16 0 0 1 16 16v4a16 16 0 0 0-16-16H16A16 16 0 0 0 0 20v-4A16 16 0 0 1 16 0z" fill="#1E146E" fill-opacity="0.25"/>')
    f["cell_target.svg"] = svg(64, 64, rect(0, 0, 64, 64, 16, GREEN, 'fill-opacity="0.28"') + rect(1.5, 1.5, 61, 61, 14.5, "none", f'stroke="{WHITE}" stroke-width="3" stroke-dasharray="7 6"'))
    f["cell_locked.svg"] = svg(64, 64, rect(0, 0, 64, 64, 16, GOLD, 'fill-opacity="0.30"') + rect(1.5, 1.5, 61, 61, 14.5, "none", f'stroke="{GOLD}" stroke-width="3"'))
    f["tray.svg"] = svg(64, 64, rect(0, 0, 64, 64, 22, WHITE, 'fill-opacity="0.20"') + rect(1, 1, 62, 62, 21, "none", f'stroke="{WHITE}" stroke-opacity="0.40" stroke-width="2"'))
    f["medal_empty.svg"] = svg(64, 64, f'<circle cx="32" cy="32" r="29" fill="{WHITE}" fill-opacity="0.20"/><circle cx="32" cy="32" r="28" fill="none" stroke="{WHITE}" stroke-opacity="0.45" stroke-width="2.5"/>')
    f["medal_done.svg"] = svg(72, 78, f'<circle cx="36" cy="41" r="35" fill="{CORAL_LIP}"/><circle cx="36" cy="36" r="35" fill="{CORAL_BOT}"/><circle cx="36" cy="36" r="30" fill="{WHITE}"/>')
    f["name_tag.svg"] = svg(48, 26, rect(0, 2, 48, 24, 12, CORAL_LIP) + rect(0, 0, 48, 24, 12, CORAL_BOT))
    f["stage_ribbon.svg"] = svg(64, 40, rect(0, 4, 64, 36, 18, GOLD_LIP) + rect(0, 0, 64, 36, 18, GOLD) + rect(8, 3, 48, 8, 4, WHITE, 'fill-opacity="0.5"'))
    f["hud_button.svg"] = svg(48, 52, rect(0, 4, 48, 48, 14, "#4E54C8") + rect(0, 0, 48, 48, 14, WHITE))

    def round_button(top, bot, lip):
        return svg(64, 70,
                   f'<circle cx="32" cy="37" r="32" fill="{WHITE}"/><circle cx="32" cy="32" r="32" fill="{WHITE}"/>'
                   f'<circle cx="32" cy="37" r="29" fill="{lip}"/><circle cx="32" cy="32" r="29" fill="url(#g)"/>'
                   f'<path d="M10 26a22 22 0 0 1 44 0 22 14 0 0 0-44 0z" fill="{WHITE}" fill-opacity="0.45"/>',
                   grad("g", [(0, top), (1, bot)]))
    f["booster_hint.svg"] = round_button(SKY_TOP, SKY_BOT, SKY_LIP)
    f["booster_undo.svg"] = round_button(VIOLET_TOP, VIOLET_BOT, VIOLET_LIP)
    f["booster_disabled.svg"] = round_button("#D9DCEF", "#B4B9D8", "#8F95BC")
    stroke = f'fill="none" stroke="{WHITE}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'
    f["icon_hint.svg"] = svg(28, 28, f'<path d="M14 4a7.5 7.5 0 0 0-4.6 13.4c.9.8 1.4 1.6 1.4 2.6h6.4c0-1 .5-1.8 1.4-2.6A7.5 7.5 0 0 0 14 4z" {stroke}/><path d="M11.2 23.5h5.6" {stroke}/>')
    f["icon_undo.svg"] = svg(28, 28, f'<path d="M8 11h9.5a5.5 5.5 0 0 1 0 11H11" {stroke}/><path d="M12 6.5L7.5 11l4.5 4.5" {stroke}/>')
    f["icon_pause.svg"] = svg(18, 18, '<rect x="3.5" y="2.5" width="4" height="13" rx="1.4" fill="#5B5FE0"/><rect x="10.5" y="2.5" width="4" height="13" rx="1.4" fill="#5B5FE0"/>')
    f["icon_play_ad.svg"] = svg(10, 10, f'<path d="M2 1l7 4-7 4z" fill="{WHITE}"/>')
    f["icon_lock.svg"] = svg(26, 26, f'<path d="M8 12V9a5 5 0 0 1 10 0v3" fill="none" stroke="#C8CCE8" stroke-width="3"/><rect x="5" y="11" width="16" height="13" rx="3.5" fill="{GOLD}"/><circle cx="13" cy="16.5" r="2" fill="#7A5200"/><rect x="12" y="17" width="2" height="4" rx="1" fill="#7A5200"/>')
    f["badge.svg"] = svg(24, 24, f'<circle cx="12" cy="12" r="12" fill="{WHITE}"/><circle cx="12" cy="12" r="9.5" fill="{RED}"/>')
    f["tick.svg"] = svg(28, 30, f'<circle cx="14" cy="16" r="13" fill="{DEPTH}" fill-opacity="0.30"/><circle cx="14" cy="14" r="14" fill="{WHITE}"/><circle cx="14" cy="14" r="11" fill="{GREEN}"/><path d="M8.6 14.4l3.7 3.7 7.3-8.2" fill="none" stroke="{WHITE}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    f["ad_tag.svg"] = svg(40, 22, rect(0, 2, 40, 20, 10, GREEN_LIP) + rect(0, 0, 40, 20, 10, GREEN))
    f["plus_button.svg"] = svg(24, 26, f'<circle cx="12" cy="14" r="12" fill="{GREEN_LIP}"/><circle cx="12" cy="12" r="12" fill="{GREEN}"/><path d="M12 6.5v11M6.5 12h11" stroke="{WHITE}" stroke-width="3" stroke-linecap="round"/>')
    f["bubble.svg"] = svg(128, 128, f'<circle cx="64" cy="64" r="64" fill="{WHITE}"/>')
    f["heart_empty.svg"] = svg(32, 32, '<path d="M16 28S3 20.5 3 11.5A6.8 6.8 0 0 1 16 8a6.8 6.8 0 0 1 13 3.5C29 20.5 16 28 16 28z" fill="#B9C3F5" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="1.5"/>')
    f["heart_full.svg"] = svg(32, 32, '<path d="M16 28S3 20.5 3 11.5A6.8 6.8 0 0 1 16 8a6.8 6.8 0 0 1 13 3.5C29 20.5 16 28 16 28z" fill="#F92F60"/><path d="M8 9.5c2-1.6 4.6-1.2 6 .8" fill="none" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2" stroke-linecap="round"/>')
    f["star_full.svg"] = svg(48, 48, '<path d="M24 4l6.2 12.6 13.9 2-10 9.8 2.4 13.8L24 35.7l-12.5 6.5 2.4-13.8-10-9.8 13.9-2z" fill="#FFC61A" stroke="#E19A00" stroke-width="2.5" stroke-linejoin="round"/>')
    f["star_empty.svg"] = svg(48, 48, '<path d="M24 4l6.2 12.6 13.9 2-10 9.8 2.4 13.8L24 35.7l-12.5 6.5 2.4-13.8-10-9.8 13.9-2z" fill="#281E82" fill-opacity="0.25" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="2.5" stroke-linejoin="round"/>')
    return f


def main():
    check = "--check" in sys.argv
    bad = []
    for d, files in ((SKIN_DIR, skin_files()), (PLAY_DIR, play_files())):
        d.mkdir(parents=True, exist_ok=True)
        for name, text in sorted(files.items()):
            p = d / name
            if check:
                if not p.exists() or p.read_text() != text:
                    bad.append(str(p.relative_to(ROOT)))
            else:
                p.write_text(text)
        # A file the generator no longer writes must not linger next to the generated ones.
        for stray in sorted(q for q in d.iterdir() if q.suffix in (".svg", ".json") and q.name not in files):
            if check:
                bad.append(f"{stray.relative_to(ROOT)} (not generated)")
            else:
                stray.unlink()
    if check and bad:
        print("out of date:", *bad, sep="\n  ")
        return 1
    print("ok", len(skin_files()), "skin files,", len(play_files()), "play files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
