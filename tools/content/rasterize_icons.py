"""Rasterize the Fluent Emoji Flat SVGs used by the game to square transparent PNGs.

    python3 tools/content/rasterize_icons.py content/source/items.tsv <fluentui-emoji checkout>/assets godot/game/assets/icons 192

Needs Playwright with Chromium. The emoji checkout is not part of this repository;
the artwork comes from microsoft/fluentui-emoji (MIT), commit 1ffb34c.
"""
import argparse
import asyncio
import base64
import csv
import pathlib
import sys

from playwright.async_api import async_playwright


def flat_svg(assets: pathlib.Path, name: str):
    for sub in ("Flat", "Default/Flat"):
        d = assets / name / sub
        hits = sorted(d.glob("*.svg")) if d.is_dir() else []
        if hits:
            return hits[0]
    return None


async def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("items_tsv", type=pathlib.Path)
    parser.add_argument("assets", type=pathlib.Path, help="assets folder of a fluentui-emoji checkout")
    parser.add_argument("out", type=pathlib.Path)
    parser.add_argument("size", type=int, nargs="?", default=192)
    args = parser.parse_args()
    assets, out, size = args.assets, args.out, args.size
    out.mkdir(parents=True, exist_ok=True)
    with open(args.items_tsv, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    missing = []
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={"width": size, "height": size}, device_scale_factor=1)
        await page.set_content(
            f"<html><body style='margin:0;background:transparent'>"
            f"<img id='i' style='display:block;width:{size}px;height:{size}px'></body></html>")
        for r in rows:
            src = flat_svg(assets, r["asset"])
            if src is None:
                missing.append(r["asset"])
                continue
            data = base64.b64encode(src.read_bytes()).decode()
            await page.evaluate(
                "async (d) => { const i = document.getElementById('i'); i.src = 'data:image/svg+xml;base64,' + d; await i.decode(); }",
                data)
            await page.screenshot(path=str(out / f"{r['id']}.png"), omit_background=True)
        await browser.close()
    print("rendered", len(rows) - len(missing), "missing", missing)
    return 1 if missing else 0


sys.exit(asyncio.run(main()))
