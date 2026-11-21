"""Write the Candy Pop skin, play-screen and outgame-screen textures as SVG.

Usage: python3 tools/art/build_candy_pop.py [--check]
Writes godot/game/skins/candy_pop, godot/game/features/play/assets, godot/game/features/outgame/assets and the SVG
source pack godot/game/features/shared/svg_sources.json. Every file is derived from the constants below, so the art can
be regenerated and compared byte for byte (--check exits 1 when a file on disk differs).

The pack holds the text of every SVG keyed by its res:// path. The game builds its textures from that text
(DPITexture) so they stay sharp on 2.5x-3x phone screens; an exported build has no raw .svg files, only the pack.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIN_DIR = ROOT / "godot/game/skins/candy_pop"
PLAY_DIR = ROOT / "godot/game/features/play/assets"
OUTGAME_DIR = ROOT / "godot/game/features/outgame/assets"
PACK = ROOT / "godot/game/features/shared/svg_sources.json"
RES_ROOT = ROOT / "godot"

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
RED_LIP = "#C92F40"
HEART = "#F8312F"


def svg(w, h, body, defs=""):
    d = f"<defs>{defs}</defs>" if defs else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{d}{body}</svg>\n'


def grad(gid, stops, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rect(x, y, w, h, r, fill, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" {extra}/>'


def circle(cx, cy, r, fill, extra=""):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" {extra}/>'


def skin_files():
    f = {}

    # Primary button: body 98x58 (radius 22) with a 3px white outline, a 3px light band inside the top edge and a
    # 7px lip below. The lip sits over the outline, so the outline shows on the top and the sides only.
    def primary(top, mid, bot, lip, band, press=0):
        defs = (grad("g", [(0, top), (0.55, mid), (1, bot)])
                + f'<clipPath id="c"><rect x="3" y="{3 + press}" width="98" height="58" rx="22"/></clipPath>')
        y = press
        body = (rect(0, y, 104, 64, 25, WHITE)
                + rect(3, 10, 98, 58, 22, lip)
                + rect(3, 3 + y, 98, 58, 22, band)
                + f'<g clip-path="url(#c)">{rect(3, 6 + y, 98, 58, 22, "url(#g)")}</g>')
        return svg(104, 68, body, defs)
    f["ui_button_primary_normal.svg"] = primary(ORANGE_TOP, ORANGE_MID, ORANGE_BOT, ORANGE_LIP, "#FFEDB2")
    f["ui_button_primary_pressed.svg"] = primary(ORANGE_MID, ORANGE_BOT, "#F07C00", ORANGE_LIP, "#FFD08A", press=4)
    f["ui_button_primary_disabled.svg"] = primary("#D9DCEF", "#C5C9E3", "#B4B9D8", "#8F95BC", "#ECEEF8")

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
            "button_primary": {"normal": "ui_button_primary_normal.svg", "pressed": "ui_button_primary_pressed.svg", "disabled": "ui_button_primary_disabled.svg", "margins": [26, 26, 26, 32], "content": [20, 9, 20, 13], "minimum": [72, 56]},
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


def framed_card(ring, lip):
    """Card plate with a 4px coloured ring and a 6px lip: the white body is the 64x64 square at (4, 4)."""
    return svg(72, 78, rect(0, 6, 72, 72, 20, lip) + rect(0, 0, 72, 72, 20, ring) + rect(4, 4, 64, 64, 16, WHITE))


def back_dots(w, h):
    """Polka dots of the card back, laid out from the card's top-left corner: one dot every 8px where column + row is even."""
    return "".join(
        circle(col * 8, row * 8, 2.4, WHITE, 'fill-opacity="0.9"')
        for row in range(h // 8 + 1) for col in range(w // 8 + 1) if (col + row) % 2 == 0)


def back_stripes(w, h):
    """Diagonal stripes, 3px wide every 12px, running from lower left to upper right."""
    lines = "".join(f'<path d="M{x} {h}L{x + h} 0" stroke="{WHITE}" stroke-opacity="0.5" stroke-width="3"/>'
                    for x in range(-h, w + 12, 12))
    return svg(w, h, lines)


def back_stars(w, h):
    """Four-point stars on a 16px grid; every other row is shifted by half a cell."""
    stars = []
    for row in range(h // 16 + 1):
        for col in range(w // 16 + 1):
            cx, cy = col * 16 + (8 if row % 2 else 0), row * 16 + 4
            stars.append(f'<path d="M{cx} {cy - 4.2}Q{cx + 0.8} {cy - 0.8} {cx + 4.2} {cy}Q{cx + 0.8} {cy + 0.8} {cx} {cy + 4.2}'
                         f'Q{cx - 0.8} {cy + 0.8} {cx - 4.2} {cy}Q{cx - 0.8} {cy - 0.8} {cx} {cy - 4.2}z" fill="{WHITE}" fill-opacity="0.85"/>')
    return svg(w, h, "".join(stars))


def back_sparkles(w, h):
    """Small gold dots every 12px with a larger dot in every third cell of every third row."""
    dots = []
    for row in range(h // 12 + 1):
        for col in range(w // 12 + 1):
            big = row % 3 == 1 and col % 3 == 1
            dots.append(circle(col * 12 + (6 if row % 2 else 0), row * 12 + 2, 2.6 if big else 1.4, GOLD, f'fill-opacity="{0.95 if big else 0.7}"'))
    return svg(w, h, "".join(dots))


# Card back themes sold in the shop (05 economy doc): plate gradient, lip and the pattern drawn over the plate.
CARD_BACKS = {
    "card_back_mint": ("#4FE0C0", "#1FB0A3", "#13857A", back_stripes),
    "card_back_sunset": ("#FFB15C", "#FF6A7A", "#D9445A", back_stars),
    "card_back_night": ("#454AB8", "#25236A", "#15124A", back_sparkles),
}


def card_back(top, bot, lip):
    """Card back plate: white edge 4, gradient panel, lip 6 and depth shadow 3 (9-slice margins 20/20/20/29)."""
    return svg(
        64, 73,
        rect(0, 9, 64, 64, 16, DEPTH, 'fill-opacity="0.28"') + rect(0, 6, 64, 64, 16, lip)
        + rect(0, 0, 64, 64, 16, WHITE) + rect(4, 4, 56, 56, 12, "url(#g)"),
        grad("g", [(0, top), (1, bot)]))


def soft_shadow():
    """A blurred shadow built from stacked translucent rounded squares (the engine's SVG reader has no blur filter).
    The 64x64 core sits 14px inside the 92x92 canvas; nine-slice margins of 34 keep every rounded corner fixed."""
    layers = "".join(rect(i * 2, i * 2, 92 - i * 4, 92 - i * 4, 30 - i * 2, DEPTH, 'fill-opacity="0.03"') for i in range(14))
    return svg(92, 92, layers)


def dashed_cell():
    """Drop target: green fill, solid white corner brackets and two 8px dashes per edge. The 28px edge strip between the
    22px corners holds exactly two dash periods (8 on, 6 off), so the strip can be tiled along any edge length."""
    stroke = f'fill="none" stroke="{WHITE}" stroke-width="3" stroke-linecap="butt"'
    corners = ('M1.5 22V16A14.5 14.5 0 0 1 16 1.5H22', 'M50 1.5H56A14.5 14.5 0 0 1 70.5 16V22',
               'M70.5 50V56A14.5 14.5 0 0 1 56 70.5H50', 'M22 70.5H16A14.5 14.5 0 0 1 1.5 56V50')
    dashes = []
    for start in (25, 39):
        dashes += [f'M{start} 1.5H{start + 8}', f'M{start} 70.5H{start + 8}', f'M1.5 {start}V{start + 8}', f'M70.5 {start}V{start + 8}']
    return svg(72, 72, rect(0, 0, 72, 72, 16, GREEN, 'fill-opacity="0.28"') + f'<path d="{" ".join(corners + tuple(dashes))}" {stroke}/>')


HINT_GLYPH = ('M14 4a7.5 7.5 0 0 0-4.6 13.4c.9.8 1.4 1.6 1.4 2.6h6.4c0-1 .5-1.8 1.4-2.6A7.5 7.5 0 0 0 14 4z', 'M11.2 23.5h5.6')
UNDO_GLYPH = ('M8 11h9.5a5.5 5.5 0 0 1 0 11H11', 'M12 6.5L7.5 11l4.5 4.5')
LOCK_BODY = (f'<path d="M8 12V9a5 5 0 0 1 10 0v3" fill="none" stroke="#C8CCE8" stroke-width="3"/><rect x="5" y="11" width="16" height="13" rx="3.5" fill="{GOLD}"/>'
             '<circle cx="13" cy="16.5" r="2" fill="#433B6B"/><rect x="12" y="17" width="2" height="4" rx="1" fill="#433B6B"/>')


def line_glyph(paths):
    """White line icon, 3px round strokes, drawn in a 28x28 box."""
    stroke = f'fill="none" stroke="{WHITE}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'
    return "".join(f'<path d="{d}" {stroke}/>' for d in paths)


def round_button(top, bot, lip, glyph=()):
    """Booster button: a 52px disc with a 3px white outline, a 3px light band inside the top edge and a 5px lip.
    With a glyph the icon is drawn in the middle (the reward picture of that booster)."""
    defs = grad("g", [(0, top), (1, bot)]) + '<clipPath id="c"><circle cx="29" cy="29" r="26"/></clipPath>'
    body = (circle(29, 29, 29, WHITE) + circle(29, 34, 26, lip) + circle(29, 29, 26, "#FFFFFF")
            + circle(29, 29, 26, top, 'fill-opacity="0.45"')
            + f'<g clip-path="url(#c)">{circle(29, 32, 26, "url(#g)")}</g>')
    if glyph:
        body += f'<g transform="translate(15 15)">{line_glyph(glyph)}</g>'
    return svg(58, 60, body, defs)


def heart(fill, opacity, shade="", shine=""):
    """Heart for the mistake counter. A full heart has a darker left flank, a highlight on the upper right and a 2px
    drop shadow; a lost heart is one flat translucent shape."""
    path = "M16 27S3 19.5 3 10.5A6.8 6.8 0 0 1 16 7a6.8 6.8 0 0 1 13 3.5C29 19.5 16 27 16 27z"
    body = ""
    if shade:
        body += f'<path d="{path}" transform="translate(0 2)" fill="#281E78" fill-opacity="0.35"/>'
    body += f'<path d="{path}" fill="{fill}" fill-opacity="{opacity}"/>'
    if shade:
        body += (f'<path d="M16 27S3 19.5 3 10.5A6.8 6.8 0 0 1 8 4.2 8.6 8.6 0 0 0 5.6 10.5c0 7.4 7.6 13.6 10.4 16.5z" fill="{shade}"/>'
                 f'<ellipse cx="22.6" cy="9.6" rx="3.2" ry="2.1" transform="rotate(38 22.6 9.6)" fill="{shine}"/>')
    return svg(32, 32, body)


def pointing_hand():
    """Tutorial pointer: a gloved hand with the index finger up. The shapes are drawn once as a thick dark outline
    and once more in white on top, so they read as one silhouette. The fingertip is at (25, 3)."""
    shapes = ('<rect x="19" y="3" width="12" height="30" rx="6"/>'
              '<rect x="30" y="20" width="10" height="20" rx="5"/>'
              '<rect x="38" y="24" width="9" height="18" rx="4.5"/>'
              '<rect x="6" y="24" width="12" height="20" rx="6" transform="rotate(-28 12 34)"/>'
              '<rect x="14" y="24" width="33" height="28" rx="12"/>')
    outline = f'<g fill="{INK}" stroke="{INK}" stroke-width="5" stroke-linejoin="round">{shapes}</g>'
    fill = f'<g fill="{WHITE}">{shapes}</g>'
    creases = f'<path d="M30.5 27v8M38.5 29v7" fill="none" stroke="{LIP}" stroke-width="2" stroke-linecap="round"/>'
    return svg(52, 58, outline + fill + creases)


def play_files():
    f = {}
    # card face: body 64x64, lip 6, depth shadow 3 (9-slice margins 20/20/20/29)
    f["card_face.svg"] = svg(64, 73, rect(0, 9, 64, 64, 16, DEPTH, 'fill-opacity="0.28"') + rect(0, 6, 64, 64, 16, LIP) + rect(0, 0, 64, 64, 16, WHITE))
    # selected and hinted cards: ring 4, lip 6 (9-slice margins 24/24/24/30, drawn 4px outside the card on every side)
    f["card_selected.svg"] = framed_card(YELLOW, YELLOW_DEEP)
    f["card_hint.svg"] = framed_card(SKY_BOT, SKY_LIP)
    # card back: white edge 4, purple panel, lip 6, depth shadow 3 (9-slice margins 20/20/20/29); dots are a separate layer
    f["card_back.svg"] = card_back(PURPLE_TOP, PURPLE_BOT, PURPLE_LIP)
    f["card_back_dots.svg"] = svg(96, 136, back_dots(96, 136))
    # mask for the back pattern on tilted cards: the inner panel of the card back (radius 12, 9-slice margins 12)
    f["card_mask.svg"] = svg(56, 56, rect(0, 0, 56, 56, 12, WHITE))
    for name, (top, bot, lip, pattern) in CARD_BACKS.items():
        f[name + ".svg"] = card_back(top, bot, lip)
        f[name + "_pattern.svg"] = pattern(96, 136)
    f["soft_shadow.svg"] = soft_shadow()
    f["cell_empty.svg"] = svg(64, 64, rect(0, 0, 64, 64, 16, "#281E82", 'fill-opacity="0.22"') + '<path d="M16 0h32a16 16 0 0 1 16 16v4a16 16 0 0 0-16-16H16A16 16 0 0 0 0 20v-4A16 16 0 0 1 16 0z" fill="#1E146E" fill-opacity="0.25"/>')
    f["cell_target.svg"] = dashed_cell()
    f["cell_locked.svg"] = svg(64, 64, rect(0, 0, 64, 64, 16, GOLD, 'fill-opacity="0.30"') + rect(1.5, 1.5, 61, 61, 14.5, "none", f'stroke="{GOLD}" stroke-width="3"'))
    f["tray.svg"] = svg(64, 64, rect(0, 0, 64, 64, 22, WHITE, 'fill-opacity="0.20"') + rect(1, 1, 62, 62, 21, "none", f'stroke="{WHITE}" stroke-opacity="0.40" stroke-width="2"'))
    f["medal_empty.svg"] = svg(58, 58, circle(29, 29, 29, WHITE, 'fill-opacity="0.20"') + circle(29, 29, 27.75, "none", f'stroke="{WHITE}" stroke-opacity="0.45" stroke-width="2.5"'))
    # finished medal: white disc 58 with a 4px coral ring and a 5px lip, drawn 4px outside the disc
    f["medal_done.svg"] = svg(66, 71, circle(33, 38, 33, CORAL_LIP) + circle(33, 33, 33, CORAL_BOT) + circle(33, 33, 29, WHITE))
    f["name_tag.svg"] = svg(40, 20, rect(0, 2, 40, 18, 9, CORAL_LIP) + rect(0, 0, 40, 18, 9, CORAL_BOT))
    f["stage_ribbon.svg"] = svg(
        64, 35,
        rect(0, 4, 64, 31, 15.5, GOLD_LIP) + rect(0, 0, 64, 31, 15.5, "#FFEEB6")
        + f'<g clip-path="url(#c)">{rect(0, 2, 64, 31, 15.5, GOLD)}</g>',
        '<clipPath id="c"><rect x="0" y="0" width="64" height="31" rx="15.5"/></clipPath>')
    f["hud_button.svg"] = svg(48, 52, rect(0, 4, 48, 48, 14, "#4E54C8") + rect(0, 0, 48, 48, 14, WHITE))
    f["booster_hint.svg"] = round_button(SKY_TOP, SKY_BOT, SKY_LIP)
    f["booster_undo.svg"] = round_button(VIOLET_TOP, VIOLET_BOT, VIOLET_LIP)
    f["booster_disabled.svg"] = round_button("#D9DCEF", "#B4B9D8", "#8F95BC")
    f["icon_hint.svg"] = svg(28, 28, line_glyph(HINT_GLYPH))
    f["icon_undo.svg"] = svg(28, 28, line_glyph(UNDO_GLYPH))
    # reward pictures: the booster disc with its glyph, and the locked slot with its padlock
    f["gift_hint.svg"] = round_button(SKY_TOP, SKY_BOT, SKY_LIP, HINT_GLYPH)
    f["gift_undo.svg"] = round_button(VIOLET_TOP, VIOLET_BOT, VIOLET_LIP, UNDO_GLYPH)
    f["gift_slot.svg"] = svg(58, 60, rect(7, 4, 44, 52, 14, WHITE, 'fill-opacity="0.35"') + rect(7, 4, 44, 52, 14, GOLD, 'fill-opacity="0.45"')
                             + rect(8.5, 5.5, 41, 49, 12.5, "none", f'stroke="{GOLD}" stroke-width="3"') + f'<g transform="translate(16 17)">{LOCK_BODY}</g>')
    f["icon_pause.svg"] = svg(18, 18, '<rect x="3.5" y="2.5" width="4" height="13" rx="1.4" fill="#5B5FE0"/><rect x="10.5" y="2.5" width="4" height="13" rx="1.4" fill="#5B5FE0"/>')
    f["icon_play_ad.svg"] = svg(10, 10, f'<path d="M2 1l7 4-7 4z" fill="{WHITE}"/>')
    f["icon_lock.svg"] = svg(26, 26, LOCK_BODY)
    # rewarded-ad mark on buttons: green pill with a play triangle
    f["icon_ad.svg"] = svg(26, 20, rect(0, 2, 26, 18, 9, GREEN_LIP) + rect(0, 0, 26, 18, 9, GREEN) + f'<path d="M10 4.5l8 4.5-8 4.5z" fill="{WHITE}"/>')
    f["badge.svg"] = svg(24, 24, f'<circle cx="12" cy="12" r="12" fill="{WHITE}"/><circle cx="12" cy="12" r="9.5" fill="{RED}"/>')
    f["tick.svg"] = svg(28, 30, f'<circle cx="14" cy="16" r="13" fill="{DEPTH}" fill-opacity="0.30"/><circle cx="14" cy="14" r="14" fill="{WHITE}"/><circle cx="14" cy="14" r="11" fill="{GREEN}"/><path d="M9.7 14.5l2.9 2.9 5.8-6.5" fill="none" stroke="{WHITE}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>')
    f["ad_tag.svg"] = svg(40, 21, rect(0, 2, 40, 19, 9.5, GREEN_LIP) + rect(0, 0, 40, 19, 9.5, GREEN))
    f["count_pill.svg"] = svg(32, 22, rect(0, 0, 32, 22, 11, "#8C3C00", 'fill-opacity="0.40"'))
    f["toast_info.svg"] = svg(48, 40, rect(0, 4, 48, 36, 18, "#150F52", 'fill-opacity="0.55"') + rect(0, 0, 48, 36, 18, NAVY, 'fill-opacity="0.92"')
                              + rect(1, 1, 46, 34, 17, "none", f'stroke="{WHITE}" stroke-opacity="0.38" stroke-width="2"'))
    f["toast_yellow.svg"] = svg(48, 40, rect(0, 4, 48, 36, 18, YELLOW_DEEP) + rect(0, 0, 48, 36, 18, YELLOW) + rect(1.5, 1.5, 45, 33, 16.5, "none", f'stroke="{WHITE}" stroke-opacity="0.55" stroke-width="2"'))
    f["toast_red.svg"] = svg(48, 40, rect(0, 4, 48, 36, 18, RED_LIP) + rect(0, 0, 48, 36, 18, RED) + rect(1.5, 1.5, 45, 33, 16.5, "none", f'stroke="{WHITE}" stroke-opacity="0.45" stroke-width="2"'))
    f["plus_button.svg"] = svg(24, 26, f'<circle cx="12" cy="14" r="12" fill="{GREEN_LIP}"/><circle cx="12" cy="12" r="12" fill="{GREEN}"/><path d="M12 7.2v9.6M7.2 12h9.6" stroke="{WHITE}" stroke-width="2.6" stroke-linecap="round"/>')
    f["bubble.svg"] = svg(128, 128, f'<circle cx="64" cy="64" r="64" fill="{WHITE}"/>')
    f["finger.svg"] = pointing_hand()
    f["heart_empty.svg"] = heart("#7F8C96", 0.62)
    f["heart_full.svg"] = heart(HEART, 1, "#CA0B4A", "#F37366")
    f["star_full.svg"] = svg(48, 48, '<path d="M24 4l6.2 12.6 13.9 2-10 9.8 2.4 13.8L24 35.7l-12.5 6.5 2.4-13.8-10-9.8 13.9-2z" fill="#FFC61A" stroke="#E19A00" stroke-width="2.5" stroke-linejoin="round"/>')
    f["star_empty.svg"] = svg(48, 48, '<path d="M24 4l6.2 12.6 13.9 2-10 9.8 2.4 13.8L24 35.7l-12.5 6.5 2.4-13.8-10-9.8 13.9-2z" fill="#281E82" fill-opacity="0.25" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="2.5" stroke-linejoin="round"/>')
    return f


HUD_GLYPH = "#5B5FE0"
GREEN_TOP = "#8CF29B"
ALBUM_GLYPH = ('M4.5 8c3.2-1.6 6.3-1.6 9.5 0v14c-3.2-1.6-6.3-1.6-9.5 0z', 'M14 8c3.2-1.6 6.3-1.6 9.5 0v14c-3.2-1.6-6.3-1.6-9.5 0z')
SHOP_GLYPH = ('M6.5 11h15l-1.2 11.6a2 2 0 0 1-2 1.8H9.7a2 2 0 0 1-2-1.8z', 'M10.5 11V9a3.5 3.5 0 0 1 7 0v2')
CALENDAR_GLYPH = ('M7.5 7h13a3 3 0 0 1 3 3v11a3 3 0 0 1-3 3h-13a3 3 0 0 1-3-3V10a3 3 0 0 1 3-3z', 'M4.5 12.5h19',
                  'M10 4.5v4', 'M18 4.5v4', 'M10.5 18l2.5 2.5 4.5-5')
FLAME = 'M12 2.5c.9 3.6 6.5 5.6 6.5 11.6a6.5 6.5 0 0 1-13 0c0-3.1 1.7-5.2 3-7 .4 2 1.3 3.2 2.8 3.4-.9-2.8-.8-5.4.7-8z'


def gear(cx, cy, outer, inner, hole, teeth=8):
    """Cog wheel as one even-odd path: square teeth on a ring with a round hole."""
    points = []
    step = 360.0 / teeth
    for i in range(teeth):
        a = i * step
        for angle, radius in ((a - step / 2 + 4, inner), (a - 13, inner), (a - 10, outer), (a + 10, outer), (a + 13, inner)):
            r = math.radians(angle)
            points.append(f"{cx + radius * math.cos(r):.2f} {cy + radius * math.sin(r):.2f}")
    ring = "M" + "L".join(points) + "z"
    hole_path = f"M{cx - hole} {cy}a{hole} {hole} 0 1 0 {hole * 2} 0a{hole} {hole} 0 1 0 {-hole * 2} 0z"
    return f'<path d="{ring}{hole_path}" fill="{HUD_GLYPH}" fill-rule="evenodd"/>'


def pill(w, h, top, bot, lip, ring=0, lip_size=4, band=""):
    """A rounded bar with an optional white ring around the body and a lip below it (the lip sits over the ring)."""
    r = h / 2
    body = ""
    if ring:
        body += rect(0, 0, w + ring * 2, h + ring * 2, r + ring, WHITE)
    body += rect(ring, ring + lip_size, w, h, r, lip) + rect(ring, ring, w, h, r, "url(#g)")
    if band:
        body += f'<g clip-path="url(#c)">{rect(ring, ring - h + 3, w, h, r, band)}</g>'
    defs = grad("g", [(0, top), (1, bot)]) + f'<clipPath id="c"><rect x="{ring}" y="{ring}" width="{w}" height="{h}" rx="{r}"/></clipPath>'
    return svg(w + ring * 2, h + ring * 2 + lip_size, body, defs)


def switch(on, faded=False):
    """Settings toggle: a 52x30 track with a 3px lip and a white knob on the side it is switched to."""
    track, lip = (GREEN, GREEN_LIP) if on else ("#C9CDE6", "#A3A8CC")
    knob_x = 37 if on else 15
    opacity = 'opacity="0.45"' if faded else ""
    body = (rect(0, 3, 52, 30, 15, lip) + rect(0, 0, 52, 30, 15, track)
            + circle(knob_x, 17, 11, DEPTH, 'fill-opacity="0.25"') + circle(knob_x, 15, 11, WHITE))
    return svg(52, 33, f'<g {opacity}>{body}</g>' if faded else body)


def ink_glyph(body):
    """A 24x24 settings-row icon: 2.2px round ink strokes (shapes may add their own fill)."""
    stroke = f'fill="none" stroke="{INK}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"'
    return svg(24, 24, f'<g {stroke}>{body}</g>')


# Settings-row icons, keyed by the settings button or toggle name they sit on.
SETTINGS_GLYPHS = {
    "music": '<path d="M9 17.5V6l10-2v11.5"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="15.5" r="2.5"/>',
    "sfx": '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4z"/><path d="M15.5 9a4 4 0 0 1 0 6"/><path d="M18 6.5a7.5 7.5 0 0 1 0 11"/>',
    "vibration": '<rect x="8" y="4" width="8" height="16" rx="2"/><path d="M4.5 9v6M19.5 9v6"/>',
    "analytics": '<path d="M5 19.5v-7M10 19.5V5.5M15 19.5v-4M20 19.5V9"/>',
    "language": '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
    "account": '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-4 3.2-6.5 7-6.5s7 2.5 7 6.5"/>',
    "support": '<path d="M5 13.5V12a7 7 0 0 1 14 0v1.5"/><rect x="3.5" y="12.5" width="4.5" height="6" rx="2"/><rect x="16" y="12.5" width="4.5" height="6" rx="2"/>',
    "accessibility": '<circle cx="12" cy="5" r="2"/><path d="M5 9l7 1.5L19 9"/><path d="M12 10.5V15M9 21l3-6 3 6"/>',
    "replay": '<path d="M5 12a7 7 0 1 0 2.1-5"/><path d="M6.5 3.5V7.5h4"/>',
    "privacy_policy": '<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"/><path d="M9 12l2 2 4-4.5"/>',
    "privacy_choice": '<path d="M4.5 8h15M4.5 16h15"/><circle cx="9" cy="8" r="2.4" fill="#FFFFFF"/><circle cx="15" cy="16" r="2.4" fill="#FFFFFF"/>',
    "licenses": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M9.5 12h5.5M9.5 15.5h5.5"/>',
    "chevron": '<path d="M10 6l6 6-6 6"/>',
}


def outgame_files():
    f = {}
    for name, body in SETTINGS_GLYPHS.items():
        f["set_" + name + ".svg"] = ink_glyph(body)
    # title: coral category ribbon (white 3 ring, 4 lip) and the loading bar
    f["ribbon.svg"] = pill(58, 31, CORAL_TOP, CORAL_BOT, CORAL_LIP, ring=3)
    f["bar_track.svg"] = svg(48, 18, rect(0, 0, 48, 18, 9, NAVY, 'fill-opacity="0.5"') + rect(1, 1, 46, 16, 8, "none", f'stroke="{WHITE}" stroke-opacity="0.5" stroke-width="2"'))
    shine = rect(0, -10, 24, 12, 6, WHITE, 'fill-opacity="0.5"')
    f["bar_fill.svg"] = svg(24, 12, rect(0, 0, 24, 12, 6, "url(#g)") + f'<g clip-path="url(#c)">{shine}</g>',
                            grad("g", [(0, GREEN_TOP), (1, GREEN)]) + '<clipPath id="c"><rect x="0" y="0" width="24" height="12" rx="6"/></clipPath>')
    # home: square HUD glyphs (drawn on hud_button), round menu buttons, daily card bits
    f["icon_settings.svg"] = svg(24, 24, gear(12, 12, 10.5, 7.5, 3.4))
    f["icon_inbox.svg"] = svg(24, 24, rect(2, 5, 20, 15, 3.5, HUD_GLYPH) + f'<path d="M4.8 8.2l7.2 5.4 7.2-5.4" fill="none" stroke="{WHITE}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
    f["icon_back.svg"] = svg(24, 24, f'<path d="M15 5l-7 7 7 7" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    f["icon_close.svg"] = svg(24, 24, f'<path d="M7 7l10 10M17 7L7 17" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>')
    f["icon_copy.svg"] = svg(24, 24, rect(8, 3, 13, 15, 3, "none", f'stroke="{WHITE}" stroke-width="2.4"') + rect(3, 7, 13, 15, 3, WHITE))
    f["icon_flame.svg"] = svg(24, 24, f'<path d="{FLAME}" fill="url(#g)"/><path d="M12 13.5c1.6 1.8 3 2.6 3 4.4a3 3 0 0 1-6 0c0-1.6 1.6-2.6 3-4.4z" fill="#FFE27A"/>',
                              grad("g", [(0, "#FFB13D"), (1, "#FF5A3C")]))
    f["round_album.svg"] = round_button(CORAL_TOP, CORAL_BOT, CORAL_LIP, ALBUM_GLYPH)
    f["round_shop.svg"] = round_button(GREEN_TOP, GREEN, GREEN_LIP, SHOP_GLYPH)
    f["round_attendance.svg"] = round_button(SKY_TOP, SKY_BOT, SKY_LIP, CALENDAR_GLYPH)
    f["round_daily.svg"] = round_button(GOLD, "#FFB000", GOLD_LIP, CALENDAR_GLYPH)
    # calendar and attendance cells on the white sheet
    f["day_cell.svg"] = svg(40, 44, rect(0, 4, 40, 40, 11, LIP) + rect(0, 0, 40, 40, 11, WHITE, f'stroke="{LIP}" stroke-width="1.5"'))
    f["day_today.svg"] = svg(40, 44, rect(0, 4, 40, 40, 11, YELLOW_DEEP) + rect(0, 0, 40, 40, 11, YELLOW) + rect(3, 3, 34, 34, 8, WHITE))
    f["day_selected.svg"] = svg(40, 44, rect(0, 4, 40, 40, 11, PURPLE_LIP) + rect(0, 0, 40, 40, 11, VIOLET_BOT) + rect(3, 3, 34, 34, 8, WHITE))
    f["day_dim.svg"] = svg(40, 40, rect(0, 0, 40, 40, 11, "#EEF0FB"))
    f["ring.svg"] = svg(24, 24, circle(12, 12, 9.5, "none", f'stroke="{LIP}" stroke-width="3"'))
    # card outline for cards not seen yet in the album detail
    f["card_outline.svg"] = svg(64, 64, rect(1.5, 1.5, 61, 61, 14.5, "#F4F5FC", f'stroke="{LIP}" stroke-width="3" stroke-dasharray="7 5"'))
    # shop tabs and the rounded mask for theme previews
    f["tab_track.svg"] = svg(48, 48, rect(0, 0, 48, 48, 24, "#E6E9FA"))
    f["tab_on.svg"] = pill(42, 38, PURPLE_TOP, PURPLE_BOT, PURPLE_LIP, lip_size=4)
    f["mask_round.svg"] = svg(48, 48, rect(0, 0, 48, 48, 14, WHITE))
    # settings toggles
    f["switch_on.svg"] = switch(True)
    f["switch_off.svg"] = switch(False)
    f["switch_on_disabled.svg"] = switch(True, faded=True)
    f["switch_off_disabled.svg"] = switch(False, faded=True)
    return f


def source_pack(folders):
    """The text of every generated SVG keyed by its res:// path, in one JSON file the exported game can read."""
    sources = {}
    for directory, files in folders:
        for name, text in sorted(files.items()):
            if name.endswith(".svg"):
                sources["res://" + (directory / name).relative_to(RES_ROOT).as_posix()] = text
    return json.dumps({"version": 1, "sources": sources}, ensure_ascii=False, indent=1) + "\n"


def main():
    check = "--check" in sys.argv
    bad = []
    folders = ((SKIN_DIR, skin_files()), (PLAY_DIR, play_files()), (OUTGAME_DIR, outgame_files()))
    for d, files in folders:
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
    pack = source_pack(folders)
    if check:
        if not PACK.exists() or PACK.read_text() != pack:
            bad.append(str(PACK.relative_to(ROOT)))
    else:
        PACK.parent.mkdir(parents=True, exist_ok=True)
        PACK.write_text(pack)
    if check and bad:
        print("out of date:", *bad, sep="\n  ")
        return 1
    print("ok", len(skin_files()), "skin files,", len(play_files()), "play files,", len(outgame_files()), "outgame files, 1 source pack")
    return 0


if __name__ == "__main__":
    sys.exit(main())
