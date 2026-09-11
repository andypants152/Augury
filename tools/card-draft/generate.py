#!/usr/bin/env python3
"""card-draft — one-time design-time generator for the 78 Augury card drafts.

Turns per-arcana *celestial specs* into first-pass **line-art SVGs** in `drafts/`.

This is a throwaway production tool — it is NOT shipped in the app. Its job is to
make the M3 "refine" pass fast: emit a coherent, consistent set of drafts that a human
then reviews and hand-tweaks into the committed 78 SVGs.

Deterministic: the same run produces byte-identical SVGs (seeded per card), so drafts
are reproducible.

Usage:
    python3 tools/card-draft/generate.py [--out drafts] [--seed 1]
"""
import math
import os
import random
import sys

# ─────────────────────────── canvas + style (the one consistent look) ───────────────────────────
W, H = 540, 960                 # 9:16 card (fills a phone screen nicely)
BG_INNER = "#141b3f"            # deep-space indigo, lit centre
BG_OUTER = "#090e24"            # ...falling to near-black at the edges
LINE = "#dfe7ff"                # starlight — the single motif colour
GOLD = "#e6c79c"                # the frame, a warm counterpoint

MOTIF_W = 3.4                   # primary motif stroke
MID_W = 2.4                     # secondary
THIN_W = 1.5                    # hairlines / frame detail


def S(w=MOTIF_W, color=LINE, op=1.0, fill="none"):
    d = {"fill": fill, "stroke": color, "stroke-width": str(w),
         "stroke-linecap": "round", "stroke-linejoin": "round"}
    if op < 1.0:
        d["stroke-opacity"] = f"{op:.2f}"
    return d


def el(tag, inner="", **attrs):
    a = " ".join(f'{k}="{v}"' for k, v in attrs.items())
    return f"<{tag} {a}>{inner}</{tag}>" if inner else f"<{tag} {a}/>"


def circle(x, y, r, **s):
    return el("circle", cx=f"{x:.1f}", cy=f"{y:.1f}", r=f"{r:.1f}", **s)


def line(x1, y1, x2, y2, **s):
    return el("line", x1=f"{x1:.1f}", y1=f"{y1:.1f}", x2=f"{x2:.1f}", y2=f"{y2:.1f}", **s)


def path(d, **s):
    return el("path", d=d, **s)


# ─────────────────────────── motif library (celestial line art) ───────────────────────────
def spark(cx, cy, r, points=4, w=THIN_W, color=LINE, op=1.0, rot=0.0):
    """A glint: short radiating lines from the centre."""
    out = []
    for i in range(points):
        a = rot + i * 2 * math.pi / points
        out.append(line(cx, cy, cx + r * math.cos(a), cy + r * math.sin(a), w=w, color=color, op=op))
    return out


def star(cx, cy, r, points=5, inner=0.45, w=MOTIF_W, color=LINE, op=1.0, rot=-math.pi / 2):
    """A star polygon outline."""
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = rot + i * math.pi / points
        pts.append(f"{cx + rr * math.cos(a):.1f} {cy + rr * math.sin(a):.1f}")
    return [path("M " + " L ".join(pts) + " Z", **S(w, color, op))]


def moon(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    return [circle(cx, cy, r, **S(w, color, op))]


def crescent(cx, cy, r, open=0.55, angle=math.pi, w=MOTIF_W, color=LINE, op=1.0):
    """A crescent: outer arc + inner (offset) arc."""
    dx = -r * open
    a0, a1 = angle - math.pi * 0.62, angle + math.pi * 0.62
    p0 = (cx + r * math.cos(a0), cy + r * math.sin(a0))
    p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1))
    i0 = (cx + dx + r * math.cos(a0), cy + r * math.sin(a0))
    i1 = (cx + dx + r * math.cos(a1), cy + r * math.sin(a1))
    d = (f"M {p0[0]:.1f} {p0[1]:.1f} A {r:.1f} {r:.1f} 0 1 1 {p1[0]:.1f} {p1[1]:.1f} "
         f"L {i1[0]:.1f} {i1[1]:.1f} A {r:.1f} {r:.1f} 0 1 0 {i0[0]:.1f} {i0[1]:.1f} Z")
    return [path(d, **S(w, color, op))]


def sun(cx, cy, r, rays=12, w=MID_W, color=LINE, op=1.0, raylen=0.85):
    out = [circle(cx, cy, r, **S(MOTIF_W, color, op))]
    for i in range(rays):
        a = i * 2 * math.pi / rays
        r0 = r * 1.18
        r1 = r * (1.18 + raylen)
        out.append(line(cx + r0 * math.cos(a), cy + r0 * math.sin(a),
                        cx + r1 * math.cos(a), cy + r1 * math.sin(a), w=MID_W, color=color, op=op))
    return out


def planet(cx, cy, r, ringed=False, w=MOTIF_W, color=LINE, op=1.0, ring_rot=20):
    out = [circle(cx, cy, r, **S(w, color, op))]
    if ringed:
        out.append(el("ellipse", cx=f"{cx:.1f}", cy=f"{cy:.1f}", rx=f"{r * 1.7:.1f}",
                      ry=f"{r * 0.55:.1f}", transform=f"rotate({ring_rot} {cx:.1f} {cy:.1f})",
                      **S(MID_W, color, op * 0.85)))
    return out


def comet(cx, cy, r, angle=math.pi * 0.75, tail=3.2, w=MID_W, color=LINE, op=1.0):
    out = [circle(cx, cy, r, **S(MOTIF_W, color, op))]
    for k in range(3):
        a = angle + (k - 1) * 0.16
        out.append(line(cx, cy, cx + tail * r * math.cos(a), cy + tail * r * math.sin(a),
                        w=THIN_W, color=color, op=op * (1 - k * 0.25)))
    return out


def constellation(cx, cy, r, seed, n=6, w=THIN_W, color=LINE, op=1.0):
    rng = random.Random(seed)
    pts = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.25, 1.0) * r
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    out = [path(d, **S(THIN_W, color, op * 0.7))]
    for x, y in pts:
        out.append(circle(x, y, 2.6, **S(THIN_W, color, op)))
    return out


def orbit(cx, cy, rx, ry, rot=0, w=MID_W, color=LINE, op=1.0):
    return [el("ellipse", cx=f"{cx:.1f}", cy=f"{cy:.1f}", rx=f"{rx:.1f}", ry=f"{ry:.1f}",
               transform=f"rotate({rot} {cx:.1f} {cy:.1f})", **S(w, color, op))]


def spiral(cx, cy, r, turns=2.6, w=MID_W, color=LINE, op=1.0):
    pts = []
    for i in range(91):
        t = i / 90
        a = t * turns * 2 * math.pi
        rr = r * t
        pts.append(f"{cx + rr * math.cos(a):.1f} {cy + rr * math.sin(a):.1f}")
    return [path("M " + " L ".join(pts), **S(w, color, op))]


def tide(cx, cy, halfw, amp, waves=3, gap=0.9, w=MID_W, color=LINE, op=1.0):
    out = []
    for k in range(waves):
        yy = cy + (k - waves // 2) * amp * gap * 2
        pts = []
        for i in range(25):
            t = i / 24
            x = cx - halfw + 2 * halfw * t
            y = yy + amp * math.sin(t * 2 * math.pi * 1.5)
            pts.append(f"{x:.1f} {y:.1f}")
        out.append(path("M " + " L ".join(pts), **S(w, color, op)))
    return out


def burst(cx, cy, r, points=9, w=MID_W, color=LINE, op=1.0):
    out = []
    for i in range(points):
        a = i * 2 * math.pi / points + 0.3
        ln = r * (1.0 if i % 2 == 0 else 0.55)
        out.append(line(cx + r * 0.2 * math.cos(a), cy + r * 0.2 * math.sin(a),
                        cx + ln * math.cos(a), cy + ln * math.sin(a), w=w, color=color, op=op))
    return out


def crystal(cx, cy, r, sides=6, w=MOTIF_W, color=LINE, op=1.0, rot=-math.pi / 2):
    pts = []
    for i in range(sides):
        a = rot + i * 2 * math.pi / sides
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return [path("M " + " L ".join(pts) + " Z", **S(w, color, op))]


def rosette(cx, cy, r, petals=8, w=MID_W, color=LINE, op=1.0):
    out = [circle(cx, cy, r * 0.28, **S(THIN_W, color, op))]
    for i in range(petals):
        a = i * 2 * math.pi / petals
        px, py = cx + r * 0.5 * math.cos(a), cy + r * 0.5 * math.sin(a)
        out.append(el("ellipse", cx=f"{px:.1f}", cy=f"{py:.1f}", rx=f"{r * 0.34:.1f}",
                      ry=f"{r * 0.18:.1f}", transform=f"rotate({math.degrees(a)} {px:.1f} {py:.1f})",
                      **S(MID_W, color, op)))
    return out


def lemniscate(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    pts = []
    for i in range(90):
        t = i / 89 * 2 * math.pi
        d = 1 + math.sin(t) ** 2
        pts.append(f"{cx + r * 1.4 * math.cos(t) / d:.1f} {cy + r * 0.7 * math.sin(t) * math.cos(t) / d:.1f}")
    return [path("M " + " L ".join(pts) + " Z", **S(w, color, op))]


def pathline(cx, cy, width, height, seed, wdt=MID_W, color=LINE, op=1.0):
    rng = random.Random(seed)
    pts = [(cx - width / 2, cy + height / 2)]
    for i in range(1, 5):
        pts.append((cx - width / 2 + width * i / 4 + rng.uniform(-width * 0.15, width * 0.15),
                    cy + height / 2 - height * i / 4 + rng.uniform(-height * 0.12, height * 0.12)))
    d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    return [path(d, **S(wdt, color, op))]


def bolt(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    pts = [(cx + r * 0.1, cy - r), (cx - r * 0.4, cy + r * 0.1), (cx + r * 0.05, cy + r * 0.1),
           (cx - r * 0.15, cy + r), (cx + r * 0.5, cy - r * 0.15), (cx + r * 0.02, cy - r * 0.15)]
    return [path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z", **S(w, color, op))]


def tower(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """A tall keep with a pointed roof — the Tower needs its own silhouette,
    distinct from the Emperor's square."""
    hw = r * 0.55
    pts = [(cx - hw, cy + r), (cx - hw, cy - r * 0.35), (cx, cy - r),
           (cx + hw, cy - r * 0.35), (cx + hw, cy + r), (cx - hw, cy + r)]
    return [path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z", **S(w, color, op))]


def scale(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    out = [line(cx, cy - r, cx, cy + r * 0.8, w=MOTIF_W, color=color, op=op)]
    out.append(line(cx - r * 0.8, cy - r * 0.5, cx + r * 0.8, cy - r * 0.5, w=MOTIF_W, color=color, op=op))
    for sx in (-0.8, 0.8):
        px = cx + sx * r
        out.append(path(f"M {px - r * 0.35:.1f} {cy - r * 0.5:.1f} A {r * 0.35:.1f} {r * 0.35:.1f} "
                        f"0 1 0 {px + r * 0.35:.1f} {cy - r * 0.5:.1f}", **S(MID_W, color, op)))
    return out


def crown(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    pts = [(cx - r, cy + r * 0.5), (cx - r, cy - r * 0.3), (cx - r * 0.4, cy + r * 0.1),
           (cx, cy - r * 0.6), (cx + r * 0.4, cy + r * 0.1), (cx + r, cy - r * 0.3), (cx + r, cy + r * 0.5)]
    return [path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z", **S(w, color, op))]


def pillars(cx, cy, h, w=MOTIF_W, color=LINE, op=1.0, gap=0.9):
    out = []
    for sx in (-gap, gap):
        x = cx + sx * h * 0.6
        out.append(line(x, cy - h / 2, x, cy + h / 2, w=w, color=color, op=op))
        out.append(circle(x, cy - h / 2, h * 0.09, **S(THIN_W, color, op)))
        out.append(circle(x, cy + h / 2, h * 0.09, **S(THIN_W, color, op)))
    return out


def droplet(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    d = (f"M {cx:.1f} {cy - r:.1f} C {cx + r:.1f} {cy + r * 0.1:.1f} {cx + r * 0.7:.1f} {cy + r:.1f} "
         f"{cx:.1f} {cy + r:.1f} C {cx - r * 0.7:.1f} {cy + r:.1f} {cx - r:.1f} {cy + r * 0.1:.1f} "
         f"{cx:.1f} {cy - r:.1f} Z")
    return [path(d, **S(w, color, op))]


def littleFigure(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """A simple figure: head + shoulders + a star held at the chest."""
    out = [circle(cx, cy - r * 0.55, r * 0.22, **S(MID_W, color, op))]
    out.append(path(f"M {cx - r * 0.5:.1f} {cy + r * 0.7:.1f} C {cx - r * 0.5:.1f} {cy - r * 0.1:.1f} "
                    f"{cx + r * 0.5:.1f} {cy - r * 0.1:.1f} {cx + r * 0.5:.1f} {cy + r * 0.7:.1f}",
                    **S(MID_W, color, op)))
    out += star(cx, cy + r * 0.15, r * 0.24, points=4, inner=0.35, w=THIN_W, color=color, op=op)
    return out


# ─────────────────────────── card scaffolding (bg, starfield, frame, name) ───────────────────────────
def bg():
    grad = (f'<radialGradient id="bg" cx="50%" cy="36%" r="85%">'
            f'<stop offset="0%" stop-color="{BG_INNER}"/>'
            f'<stop offset="100%" stop-color="{BG_OUTER}"/></radialGradient>')
    return [f"<defs>{grad}</defs>",
            el("rect", x="0", y="0", width=str(W), height=str(H), rx="38", fill="url(#bg)")]


def dot(x, y, r, color=LINE, op=1.0):
    extra = {} if op >= 1 else {"fill-opacity": f"{op:.2f}"}
    return el("circle", cx=f"{x:.1f}", cy=f"{y:.1f}", r=f"{r:.1f}", fill=color, stroke="none", **extra)


def face(cx, cy, r, op=0.9):
    out = [dot(cx - r * 0.32, cy - r * 0.1, r * 0.09, op=op),
           dot(cx + r * 0.32, cy - r * 0.1, r * 0.09, op=op)]
    out.append(path(f"M {cx - r * 0.3:.1f} {cy + r * 0.18:.1f} A {r * 0.34:.1f} {r * 0.34:.1f} "
                    f"0 0 0 {cx + r * 0.3:.1f} {cy + r * 0.18:.1f}", **S(THIN_W, LINE, op)))
    return out


def starfield(rng, n=64):
    out = []
    for _ in range(n):
        x = rng.uniform(30, W - 30)
        y = rng.uniform(30, H - 30)
        op = rng.uniform(0.10, 0.40)
        if rng.random() < 0.66:
            out.append(dot(x, y, rng.uniform(1.0, 2.6), op=op))
        else:
            out += spark(x, y, rng.uniform(3, 9), points=4, w=1.2, color=LINE, op=op)
    return out


def frame():
    out = [el("rect", x="16", y="16", width=str(W - 32), height=str(H - 32), rx="26",
              **S(MID_W, GOLD, 0.9)),
           el("rect", x="30", y="30", width=str(W - 60), height=str(H - 60), rx="18",
              **S(THIN_W, LINE, 0.26))]
    for cx, cy in ((52, 52), (W - 52, 52), (52, H - 52), (W - 52, H - 52)):
        out += star(cx, cy, 11, points=4, inner=0.3, w=1.6, color=GOLD, op=0.8)
    return out


def nameplate(name):
    return el("text", name.upper(), x=f"{W / 2:.0f}", y=f"{H - 66:.0f}",
               **{"text-anchor": "middle", "fill": GOLD,
                  "font-family": "'Avenir Next', system-ui, sans-serif",
                  "font-size": "24", "letter-spacing": "5", "font-weight": "500"})


def _flatten(layers):
    out = []
    for it in layers:
        if isinstance(it, (list, tuple)):
            out += _flatten(it)
        else:
            out.append(it)
    return out


def svg_doc(layers):
    body = "\n".join(_flatten(layers))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">\n'
            f'{body}\n</svg>\n')


def build_card(name, spec, seed):
    rng = random.Random(seed)
    layers = bg()
    layers += starfield(rng)
    layers += spec
    layers += frame()
    layers += [nameplate(name)]
    return svg_doc(layers)


# ─────────────────────────── composition ───────────────────────────
FX, FY = W / 2, H * 0.42        # figure centre (a little above middle; name sits at the bottom)


def layout(n, cx, cy, rx, ry):
    """n points arranged sensibly inside an ellipse of radii (rx, ry) about (cx, cy)."""
    if n == 1:
        return [(cx, cy)]
    if n == 2:
        return [(cx - rx * 0.42, cy), (cx + rx * 0.42, cy)]
    if n == 3:
        return [(cx, cy - ry * 0.55), (cx - rx * 0.55, cy + ry * 0.4), (cx + rx * 0.55, cy + ry * 0.4)]
    if n == 4:
        return [(cx - rx * 0.5, cy - ry * 0.5), (cx + rx * 0.5, cy - ry * 0.5),
                (cx - rx * 0.5, cy + ry * 0.5), (cx + rx * 0.5, cy + ry * 0.5)]
    if n == 5:
        return [(cx - rx * 0.5, cy - ry * 0.5), (cx + rx * 0.5, cy - ry * 0.5),
                (cx - rx * 0.5, cy + ry * 0.5), (cx + rx * 0.5, cy + ry * 0.5), (cx, cy)]
    return [(cx + rx * math.cos(a), cy + ry * math.sin(a))
            for a in (i * 2 * math.pi / n - math.pi / 2 for i in range(n))]


# Each suit gets a distinct celestial *vocabulary*; the rank sets the *composition*.
SUIT_MOTIFS = {
    "wands":     {"prim": lambda x, y, r: burst(x, y, r * 1.15),
                  "accent": lambda x, y, r: comet(x, y, r, angle=math.pi * 0.8, tail=2.4)},
    "cups":      {"prim": lambda x, y, r: crescent(x, y, r, open=0.55, angle=math.pi / 2),
                  "accent": lambda x, y, r: droplet(x, y, r * 0.8)},
    "swords":    {"prim": lambda x, y, r: star(x, y, r, points=4, inner=0.35),
                  "accent": lambda x, y, r: spiral(x, y, r * 0.8, turns=2.0)},
    "pentacles": {"prim": lambda x, y, r: planet(x, y, r * 0.8, ringed=True),
                  "accent": lambda x, y, r: orbit(x, y, r * 1.25, r * 0.5, rot=18)},
}

RANK_N = {"Ace": 1, "Two": 2, "Three": 3, "Four": 4, "Five": 5, "Six": 6,
          "Seven": 7, "Eight": 8, "Nine": 9, "Ten": 10}


def figure_for_minor(suit, rank, seed):
    m = SUIT_MOTIFS[suit]
    cx, cy = FX, FY
    if rank in RANK_N:
        n = RANK_N[rank]
        size = 150.0 / math.sqrt(n)          # more motifs → smaller, so it still fits
        return [el for (x, y) in layout(n, cx, cy, 185, 210) for el in m["prim"](x, y, max(26, size))]
    if rank == "Page":
        return m["prim"](cx, cy + 30, 90) + m["accent"](cx + 95, cy - 80, 34) \
            + pathline(cx, cy + 130, 180, 150, seed, op=0.7) + spark(cx - 100, cy - 90, 16, op=0.8)
    if rank == "Knight":
        return m["prim"](cx - 20, cy + 10, 95) + m["accent"](cx + 70, cy - 60, 40) \
            + pathline(cx + 30, cy + 120, 240, 180, seed, op=0.7)
    if rank == "Queen":
        return crescent(cx, cy + 10, 150, open=0.5, angle=math.pi / 2) + m["prim"](cx, cy, 78) \
            + spark(cx, cy - 120, 18, op=0.9) + spark(cx - 95, cy + 70, 14, op=0.7) \
            + spark(cx + 95, cy + 70, 14, op=0.7)
    if rank == "King":
        return orbit(cx, cy, 150, 150) + m["prim"](cx, cy, 88) \
            + crown(cx, cy - 150, 26) + spark(cx, cy - 178, 16, op=0.9)
    return m["prim"](cx, cy, 90)


def figure_for_major(name, seed):
    cx, cy = FX, FY
    if name == "The Fool":
        return littleFigure(cx - 55, cy + 55, 70) + pathline(cx + 10, cy - 30, 240, 250, seed, op=0.8) \
            + spark(cx + 110, cy - 130, 15, op=0.85)
    if name == "The Magician":
        return lemniscate(cx, cy + 20, 120) + [dot(cx, cy + 20, 5)] \
            + [spark(cx, cy - 120, 20, op=0.9), spark(cx, cy + 160, 20, op=0.9),
               spark(cx - 150, cy + 20, 20, op=0.9), spark(cx + 150, cy + 20, 20, op=0.9)]
    if name == "The High Priestess":
        return pillars(cx, cy, 300) + crescent(cx, cy - 40, 70, open=0.5, angle=0) \
            + star(cx, cy - 130, 20, points=4, inner=0.35, op=0.9)
    if name == "The Empress":
        return sun(cx, cy - 30, 60, rays=10) + rosette(cx, cy + 90, 110, petals=8, op=0.85)
    if name == "The Emperor":
        return crystal(cx, cy, 165, sides=4, rot=math.pi / 4) + star(cx, cy, 60, points=4, inner=0.4, op=0.95) \
            + spark(cx, cy - 215, 18, op=0.8) + spark(cx, cy + 215, 13, op=0.6)
    if name == "The Hierophant":
        xs = [(cx, cy - 130), (cx - 120, cy), (cx + 120, cy), (cx - 75, cy + 130), (cx + 75, cy + 130)]
        return [star(x, y, 24, points=4, inner=0.4, op=0.95) for (x, y) in xs] + lemniscate(cx, cy, 60, op=0.8)
    if name == "The Lovers":
        return star(cx - 70, cy + 20, 55, points=4, inner=0.4) + star(cx + 70, cy + 20, 55, points=4, inner=0.4) \
            + sun(cx, cy - 130, 45, rays=8) \
            + [line(cx - 70, cy + 20, cx, cy - 130, **S(THIN_W, LINE, 0.5)),
               line(cx + 70, cy + 20, cx, cy - 130, **S(THIN_W, LINE, 0.5))]
    if name == "The Chariot":
        return star(cx, cy, 60, points=4, inner=0.4) + comet(cx - 110, cy, 30, angle=0, tail=3) \
            + comet(cx + 110, cy, 30, angle=math.pi, tail=3) + pathline(cx, cy + 160, 120, 120, seed, op=0.7)
    if name == "Strength":
        return spiral(cx, cy, 150, turns=2.6) + star(cx, cy, 55, points=4, inner=0.4, op=0.95)
    if name == "The Hermit":
        return [line(cx, cy - 130, cx, cy + 60, **S(MOTIF_W, LINE, 0.9))] \
            + spark(cx, cy - 140, 34, points=4, op=1.0) + star(cx, cy + 60, 40, points=5, inner=0.45, op=0.8) \
            + spark(cx - 110, cy + 130, 14, op=0.5) + spark(cx + 120, cy + 120, 12, op=0.5)
    if name == "Wheel of Fortune":
        out = [circle(cx, cy, 150)]
        for i in range(8):
            a = i * math.pi / 4
            out.append(line(cx, cy, cx + 150 * math.cos(a), cy + 150 * math.sin(a), **S(MID_W, LINE, 0.8)))
        return out + star(cx, cy, 50, points=4, inner=0.4, op=0.95)
    if name == "Justice":
        return scale(cx, cy + 20, 120) + star(cx, cy - 140, 40, points=4, inner=0.4, op=0.95)
    if name == "The Hanged Man":
        return [line(cx, cy - 170, cx, cy - 60, **S(MID_W, LINE, 0.8))] \
            + star(cx, cy + 10, 80, points=5, inner=0.45, rot=math.pi) \
            + [circle(cx, cy - 10, 130, **S(THIN_W, LINE, 0.4))]
    if name == "Death":
        return comet(cx - 40, cy - 30, 40, angle=math.pi * 0.7, tail=3.2) \
            + star(cx + 90, cy + 60, 40, points=4, inner=0.35, op=0.95) \
            + crescent(cx - 90, cy + 90, 60, open=0.6)
    if name == "Temperance":
        return droplet(cx - 90, cy - 40, 60) + droplet(cx + 90, cy + 40, 60) \
            + tide(cx, cy, 130, 16, waves=3, op=0.85) + star(cx, cy - 150, 30, points=4, inner=0.4, op=0.9)
    if name == "The Devil":
        return star(cx - 80, cy, 55, points=4, inner=0.3) + star(cx + 80, cy, 55, points=4, inner=0.3) \
            + [path(f"M {cx - 80:.0f} {cy + 50:.0f} A 90 90 0 0 1 {cx + 80:.0f} {cy + 50:.0f}",
                    **S(MID_W, LINE, 0.8))] + crescent(cx, cy - 120, 70, open=0.7, angle=math.pi)
    if name == "The Tower":
        return tower(cx, cy + 30, 120) + bolt(cx, cy - 95, 90) \
            + star(cx + 110, cy + 130, 30, points=5, inner=0.45, rot=math.pi * 0.3, op=0.9)
    if name == "The Star":
        return star(cx, cy - 40, 120, points=8, inner=0.42) + tide(cx, cy + 150, 150, 16, waves=3, op=0.8) \
            + spark(cx - 130, cy - 110, 18, op=0.9) + spark(cx + 130, cy - 110, 18, op=0.9)
    if name == "The Moon":
        return [circle(cx, cy - 90, 100)] + face(cx, cy - 90, 100) \
            + pathline(cx, cy + 90, 220, 160, seed, op=0.8) \
            + spiral(cx - 120, cy + 130, 40, turns=2.2, op=0.8) + droplet(cx + 120, cy + 140, 34, op=0.8)
    if name == "The Sun":
        return sun(cx, cy - 30, 90, rays=12) + face(cx, cy - 30, 90) + rosette(cx, cy + 150, 90, petals=8, op=0.8)
    if name == "Judgement":
        return [line(cx - 160, cy + 60, cx + 160, cy + 60, **S(MID_W, LINE, 0.7))] \
            + star(cx, cy - 60, 80, points=4, inner=0.4, op=0.95) \
            + spark(cx - 90, cy + 110, 20, op=0.8) + spark(cx, cy + 110, 24, op=0.85) + spark(cx + 90, cy + 110, 20, op=0.8)
    if name == "The World":
        corners = [(cx - 120, cy - 150), (cx + 120, cy - 150), (cx - 120, cy + 150), (cx + 120, cy + 150)]
        return orbit(cx, cy, 165, 200) + [star(x, y, 30, points=4, inner=0.4, op=0.9) for (x, y) in corners] \
            + star(cx, cy, 60, points=8, inner=0.42, op=0.95)
    return star(cx, cy, 100, points=4, inner=0.4)


# ─────────────────────────── deck + main ───────────────────────────
MAJORS = ["The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
          "The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit",
          "Wheel of Fortune", "Justice", "The Hanged Man", "Death", "Temperance", "The Devil",
          "The Tower", "The Star", "The Moon", "The Sun", "Judgement", "The World"]
SUITS = ["wands", "cups", "swords", "pentacles"]
RANKS = ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
         "Page", "Knight", "Queen", "King"]


def slug(s):
    return s.lower().replace(" ", "-").replace("\u2019", "").replace("'", "")


DECK = []
for _name in MAJORS:
    DECK.append({"name": _name, "file": slug(_name) + ".svg", "major": True, "suit": None, "rank": None})
for _si, _suit in enumerate(SUITS):
    for _ri, _rank in enumerate(RANKS):
        _disp = f"{_rank} of {_suit.capitalize()}"
        DECK.append({"name": _disp, "file": f"{_suit}-{_rank.lower()}.svg", "major": False,
                     "suit": _suit, "rank": _rank})


def main():
    out_dir, seed_base = "drafts", 1
    args = sys.argv[1:]
    if "--out" in args:
        out_dir = args[args.index("--out") + 1]
    if "--seed" in args:
        seed_base = int(args[args.index("--seed") + 1])
    os.makedirs(out_dir, exist_ok=True)

    # Write the deck order so the montage tool can lay the sheet out majored-then-by-suit.
    with open(os.path.join(out_dir, "_order.txt"), "w") as f:
        f.write("\n".join(card["file"] for card in DECK) + "\n")

    for idx, card in enumerate(DECK):
        seed = seed_base * 1000 + idx
        spec = figure_for_major(card["name"], seed) if card["major"] \
            else figure_for_minor(card["suit"], card["rank"], seed)
        with open(os.path.join(out_dir, card["file"]), "w") as f:
            f.write(build_card(card["name"], spec, seed))

    # Validate: every draft must be well-formed XML with the expected shape.
    import xml.etree.ElementTree as ET
    ok = bad = 0
    for card in DECK:
        fn = os.path.join(out_dir, card["file"])
        try:
            root = ET.parse(fn).getroot()
        except Exception as e:
            bad += 1
            print(f"  INVALID  {card['file']}: {e}")
            continue
        shapes = {c.tag.split("}")[-1] for c in root}
        drawing = sum(1 for c in root if c.tag.split("}")[-1] in ("path", "line", "circle", "ellipse"))
        if not {"rect", "path"} <= shapes or drawing < 20:
            bad += 1
            print(f"  THIN     {card['file']}: {drawing} drawing elements, shapes={sorted(shapes)}")
            continue
        ok += 1
    print(f"{ok + bad} cards  |  valid {ok}  |  bad {bad}  →  {out_dir}/")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
