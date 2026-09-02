#!/usr/bin/env python3
"""Slice a grid spritesheet into named, transparent, trimmed frames.

Made for the chibi donkey sheet (5x3 on a white background), but generic:
any even grid + a frames.json naming map works.

    python3 tools/slice_spritesheet.py path/to/sheet.png \
        --map assets/donkey/frames.json --out assets/donkey/frames

Outputs one PNG per named cell plus atlas.json (frame boxes relative to the
original sheet, post-trim sizes, and the animation table copied from the map).

Background removal flood-fills near-white pixels from each cell's border, so
white INSIDE the drawing (eyes, cream muzzle) survives. Requires Pillow.
"""
import argparse, json, sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install pillow")


def flood_alpha(im, tol=18):
    """Make the white background transparent via border flood fill."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_bg(p):
        r, g, b, a = p
        return a == 0 or (r > 255 - tol * 3 and g > 255 - tol * 3 and b > 255 - tol * 3)

    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + \
            [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet", help="spritesheet image (e.g. the original donkey PNG)")
    ap.add_argument("--map", default="assets/donkey/frames.json", help="frames.json naming map")
    ap.add_argument("--out", default="assets/donkey/frames", help="output directory")
    ap.add_argument("--pad", type=int, default=2, help="transparent padding kept around each trim")
    ap.add_argument("--keep-bg", action="store_true", help="skip white->alpha removal")
    args = ap.parse_args()

    m = json.loads(Path(args.map).read_text())
    cols, rows, names = m["cols"], m["rows"], m["frames"]
    sheet = Image.open(args.sheet).convert("RGBA")
    cw, ch = sheet.width // cols, sheet.height // rows
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    atlas = {"source": Path(args.sheet).name, "cell": [cw, ch], "frames": {},
             "animations": m.get("animations", {})}
    for r in range(rows):
        for c in range(cols):
            name = names[r][c]
            if not name:
                continue
            cell = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            if not args.keep_bg:
                cell = flood_alpha(cell)
            box = cell.getbbox() or (0, 0, cw, ch)
            box = (max(0, box[0] - args.pad), max(0, box[1] - args.pad),
                   min(cw, box[2] + args.pad), min(ch, box[3] + args.pad))
            cell = cell.crop(box)
            cell.save(out / f"{name}.png")
            atlas["frames"][name] = {
                "cell": [c, r],
                "box_in_sheet": [c * cw + box[0], r * ch + box[1], box[2] - box[0], box[3] - box[1]],
                "size": list(cell.size),
            }
            print(f"  {name}.png  {cell.size[0]}x{cell.size[1]}")
    (out / "atlas.json").write_text(json.dumps(atlas, indent=2))
    print(f"wrote {len(atlas['frames'])} frames + atlas.json -> {out}")


if __name__ == "__main__":
    main()
