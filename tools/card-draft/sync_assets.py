#!/usr/bin/env python3
"""sync_assets — copy approved layer SVGs into the app's asset catalog.

The deck is made-once-done. Each card ships as two layers (see generate.py):
  card-bg  — ONE shared background (radial indigo glow, rounded corners)
  <card>   — the transparent line-art layer (starfield + figure + frame + name)
The app composites the art over the background. Sources are the canonical SVGs
(git stays text-sized); `actool` rasterizes them into the compiled catalog — the
sparse art layers keep the whole deck at ~8 MB instead of ~130 MB (a single
full-card raster per card).

    python3 tools/card-draft/sync_assets.py <svgDir> <assetsDir>

For every `*.svg` in <svgDir> it (re)writes <assetsDir>/<name>.imageset/ with a
copy of the SVG and a Contents.json pointing at it, then validates each (well-
formed XML, 540x960 viewBox, expected shape). Exits non-zero if any file fails,
so a bad draft can never sneak into the bundle.
"""
import json
import os
import shutil
import sys
import xml.etree.ElementTree as ET

W, H = 540, 960


def write_contents(set_dir: str, filename: str) -> None:
    data = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(set_dir, "Contents.json"), "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: sync_assets.py <svgDir> <assetsDir>\n")
        return 2
    src_dir, assets_dir = sys.argv[1], sys.argv[2]
    if not os.path.isdir(src_dir):
        sys.stderr.write(f"no such directory: {src_dir}\n")
        return 1
    os.makedirs(assets_dir, exist_ok=True)

    svgs = sorted(f for f in os.listdir(src_dir) if f.endswith(".svg"))
    if not svgs:
        sys.stderr.write(f"no .svg files in {src_dir}\n")
        return 1

    ok = bad = 0
    total = 0
    for fname in svgs:
        name = fname[:-4]
        src = os.path.join(src_dir, fname)
        set_dir = os.path.join(assets_dir, name + ".imageset")
        # (Re)build the imageset from scratch so stale rasterizations are dropped.
        shutil.rmtree(set_dir, ignore_errors=True)
        os.makedirs(set_dir, exist_ok=True)
        shutil.copyfile(src, os.path.join(set_dir, fname))
        write_contents(set_dir, fname)

        # Validate the copy.
        try:
            root = ET.parse(os.path.join(set_dir, fname)).getroot()
        except ET.ParseError as e:
            sys.stderr.write(f"INVALID XML  {name}: {e}\n")
            bad += 1
            continue
        vb = (root.get("viewbox") or root.get("viewBox") or "").split()
        all_tags = [el.tag.split("}")[-1] for el in root.iter()]
        shapes = [c.tag.split("}")[-1] for c in root]
        has_rect = "rect" in shapes
        has_gradient = any("gradient" in t.lower() for t in all_tags)
        drawing = sum(1 for t in shapes if t in ("path", "line", "circle", "ellipse"))
        if vb != ["0", "0", str(W), str(H)]:
            sys.stderr.write(f"BAD VIEWBOX  {name}: {root.get('viewBox')}\n")
            bad += 1
            continue
        if name == "card-bg":
            # The shared background is a single rounded rect with a gradient —
            # it legitimately has no stroke drawing, so check for the rect + a
            # gradient instead of a drawing count.
            if not (has_rect and has_gradient):
                sys.stderr.write(f"BG MALFORMED {name}: rect={has_rect} gradient={has_gradient}\n")
                bad += 1
                continue
        elif drawing < 20:
            sys.stderr.write(f"THIN         {name}: {drawing} drawing elements\n")
            bad += 1
            continue
        total += os.path.getsize(src)
        ok += 1

    human = f"{total / 1e6:.2f} MB"
    print(f"{len(svgs)} images  |  ok {ok}  |  bad {bad}  |  {human} of SVG  →  {assets_dir}/")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
