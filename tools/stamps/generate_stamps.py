#!/usr/bin/env python3
"""Generate original, generic Seichi Quest stamp PNGs from a CSV manifest.

CSV columns: event_slug,content_id,title,content_key,type
Output: assets/generated_stamps/<event_slug>/<content_id>.png
Requires Pillow. No copyrighted characters, logos, or official artwork are used.
"""
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
PALETTES = {
    "jomo_karuta_stamp": ("#F6E8C8", "#9D3D32", "#D9A441"),
    "kofun_stamp": ("#E9E2D4", "#405B52", "#B57B48"),
    "roadside_station_stamp": ("#E4EEF0", "#285D70", "#D88A4B"),
    "stamp": ("#F0E7D8", "#4D5C83", "#D9A441"),
}
FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    "C:/Windows/Fonts/meiryo.ttc",
    "C:/Windows/Fonts/YuGothR.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
]


def safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", value).strip("-") or "item"


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).is_file():
            try:
                return ImageFont.truetype(path, size=size)
            except OSError:
                pass
    raise RuntimeError("Japanese-capable font not found. Install Noto Sans CJK JP or configure FONT_CANDIDATES.")


def fit_font(draw: ImageDraw.ImageDraw, text: str, max_width: int, start: int) -> ImageFont.FreeTypeFont:
    for size in range(start, 19, -2):
        f = font(size)
        if draw.textbbox((0, 0), text, font=f)[2] <= max_width:
            return f
    return font(20)


def render(row: dict[str, str], output: Path) -> None:
    bg, ink, accent = PALETTES.get(row.get("type", ""), PALETTES["stamp"])
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    # Original geometric seal, not modeled on any existing franchise or official stamp.
    d.ellipse((28, 28, 484, 484), fill=bg, outline=ink, width=15)
    d.ellipse((49, 49, 463, 463), outline=accent, width=5)
    d.arc((78, 78, 434, 434), start=205, end=335, fill=ink, width=7)
    kind = row.get("type", "")
    if kind == "kofun_stamp":
        d.polygon([(170, 235), (205, 200), (307, 200), (342, 235), (342, 250), (170, 250)], fill=accent, outline=ink)
        d.rectangle((195, 250, 317, 269), fill=accent, outline=ink, width=3)
        d.line((160, 285, 352, 285), fill=ink, width=5)
    elif kind == "roadside_station_stamp":
        d.polygon([(165, 190), (256, 135), (347, 190)], fill=accent, outline=ink)
        d.rectangle((180, 190, 332, 265), outline=ink, width=7)
        d.rectangle((236, 218, 276, 265), outline=ink, width=5)
        d.line((200, 205, 200, 246), fill=ink, width=4)
        d.line((312, 205, 312, 246), fill=ink, width=4)
    else:
        # A simple original journey marker with a path and destination dot.
        d.line((180, 250, 220, 210, 258, 242, 302, 190), fill=accent, width=13, joint="curve")
        d.ellipse((285, 165, 325, 205), fill=accent, outline=ink, width=5)
        d.ellipse((164, 235, 196, 267), fill=ink)
    title = (row.get("title") or row.get("content_key") or "スポット").strip()
    if len(title) > 16:
        title = title[:15] + "…"
    f = fit_font(d, title, 340, 42 if len(title) <= 8 else 34)
    box = d.textbbox((0, 0), title, font=f, stroke_width=0)
    x = (SIZE - (box[2] - box[0])) / 2
    y = 326
    d.rounded_rectangle((74, 314, 438, 390), radius=18, fill=bg, outline=ink, width=3)
    d.text((x, y), title, font=f, fill=ink)
    d.text((SIZE / 2, 416), "SEICHI QUEST", font=font(19), fill=ink, anchor="mm")
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output-root", type=Path, default=Path("assets/generated_stamps"))
    parser.add_argument("--limit", type=int, default=0, help="Optional smoke-test limit")
    args = parser.parse_args()
    with args.manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {"event_slug", "content_id", "title", "type"}
    if not rows or not required.issubset(rows[0]):
        raise SystemExit("Manifest must include columns: event_slug, content_id, title, type")
    if args.limit:
        rows = rows[:args.limit]
    for row in rows:
        event_slug = safe_name(row["event_slug"])
        content_id = safe_name(row["content_id"])
        render(row, args.output_root / event_slug / f"{content_id}.png")
    print(f"Generated {len(rows)} PNG stamp(s) under {args.output_root}")


if __name__ == "__main__":
    main()
