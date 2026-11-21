#!/usr/bin/env python3
"""Build the card and category data the game ships from the reviewed source tables.

    python3 tools/content/build_content.py            # write godot/data/content/*.json
    python3 tools/content/build_content.py --check    # exit 1 if the JSON is out of date or the tables are invalid

Sources (tab separated, UTF-8):
    content/source/items.tsv        id, asset, en, ko
    content/source/categories.tsv   id, tier, domain, en, ko, members, also
`members` and `also` are ';' separated item ids. `also` lists cards that are not members
but could reasonably be read as belonging to the category; the level generator keeps
them out of any deck that uses the category.
"""
import argparse
import csv
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "content" / "source"
OUT = ROOT / "godot" / "data" / "content"
ICONS = ROOT / "godot" / "game" / "assets" / "icons"
EN_MAX, KO_MAX, WORD_MAX_EN = 18, 8, 13
DOMAINS = {"food", "animal", "plant", "sky", "transport", "place", "music", "object", "home", "fun", "wear", "tech", "sport", "people", "symbol", "color"}


def read(name):
    with open(SOURCE / name, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def split(cell):
    return [part for part in (cell or "").split(";") if part]


def validate(items, categories):
    problems = []
    ids = [row["id"] for row in items]
    known = set(ids)
    if len(known) != len(ids):
        problems.append("duplicate item id")
    for lang, limit in (("en", EN_MAX), ("ko", KO_MAX)):
        seen = {}
        for row in items:
            label = row[lang].strip()
            if not label:
                problems.append(f"{row['id']}: empty {lang} name")
            if len(label) > limit:
                problems.append(f"{row['id']}: {lang} name longer than {limit}: {label}")
            key = label.lower()
            if key in seen:
                problems.append(f"{row['id']}: {lang} name '{label}' duplicates {seen[key]}")
            seen[key] = row["id"]
    for row in items:
        if any(len(word) > WORD_MAX_EN for word in re.split(r"[ -]", row["en"])):
            problems.append(f"{row['id']}: an English word is longer than {WORD_MAX_EN} letters: {row['en']}")
        if not (ICONS / f"{row['id']}.png").is_file():
            problems.append(f"{row['id']}: icon PNG is missing")
    used = set()
    cat_ids = set()
    for row in categories:
        cid = row["id"]
        if cid in cat_ids:
            problems.append(f"duplicate category id {cid}")
        cat_ids.add(cid)
        if row["tier"] not in {"1", "2", "3", "4"}:
            problems.append(f"{cid}: tier must be 1-4")
        if row["domain"] not in DOMAINS:
            problems.append(f"{cid}: unknown domain {row['domain']}")
        members, also = split(row["members"]), split(row.get("also", ""))
        if len(members) < 4:
            problems.append(f"{cid}: fewer than 4 members")
        if len(set(members)) != len(members) or len(set(also)) != len(also):
            problems.append(f"{cid}: repeated item")
        if set(members) & set(also):
            problems.append(f"{cid}: item listed as both member and also: {sorted(set(members) & set(also))}")
        for item in members + also:
            if item not in known:
                problems.append(f"{cid}: unknown item {item}")
        used.update(members)
    unused = sorted(known - used)
    if unused:
        problems.append(f"items in no category: {unused[:8]}")
    return problems


def build(items, categories):
    items_doc = {"version": 1, "items": [{"id": r["id"], "icon": r["id"], "en": r["en"].strip(), "ko": r["ko"].strip()} for r in items]}
    cats_doc = {"version": 1, "categories": [
        {"id": r["id"], "tier": int(r["tier"]), "domain": r["domain"], "en": r["en"].strip(), "ko": r["ko"].strip(),
         "members": split(r["members"]), "also": split(r.get("also", ""))} for r in categories]}
    return {"items.json": items_doc, "categories.json": cats_doc}


def dump(doc):
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    items, categories = read("items.tsv"), read("categories.tsv")
    problems = validate(items, categories)
    if problems:
        print("\n".join(problems))
        return 1
    stale = []
    for name, doc in build(items, categories).items():
        text, path = dump(doc), OUT / name
        if args.check:
            if not path.is_file() or path.read_text(encoding="utf-8") != text:
                stale.append(name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
    if stale:
        print("out of date:", ", ".join(stale), "- run tools/content/build_content.py")
        return 1
    print(f"content ok: {len(items)} cards, {len(categories)} categories")
    return 0


if __name__ == "__main__":
    sys.exit(main())
