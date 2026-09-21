#!/usr/bin/env python3
"""card-draft — one-time design-time generator for the 78 Augury card drafts.

Turns per-arcana *celestial specs* into first-pass **line-art SVGs** in `drafts/`.

This is a throwaway production tool — it is NOT shipped in the app. Its job is to
make the M3 "refine" pass fast: emit a coherent, consistent set of drafts that a human
then reviews and hand-tweaks into the committed 78 SVGs. Once approved, the drafts are
the source of truth: each is split into a shared background + a transparent line-art
layer (`drafts/layers/`, regenerable) and `sync_assets.py` copies those into the app's
asset catalog, where `actool` rasterizes them for the ~8 MB bundle.

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
    """A straight line. `**s` accepts either a style dict from `S()` or the
    shorthand keys w=/color=/op=; the shorthand is mapped to the real SVG
    attributes, because bare `w=`/`color=`/`op=` are not valid SVG and would
    render the line invisible (stroke defaults to none)."""
    a = {"x1": f"{x1:.1f}", "y1": f"{y1:.1f}", "x2": f"{x2:.1f}", "y2": f"{y2:.1f}"}
    if "w" in s or "color" in s or "op" in s:
        a.update(S(s.pop("w", MOTIF_W), s.pop("color", LINE), s.pop("op", 1.0)))
    a.update(s)
    return el("line", **a)


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


def spiral(cx, cy, r, turns=2.6, w=MID_W, color=LINE, op=1.0, flip=False):
    pts = []
    for i in range(91):
        t = i / 90
        a = t * turns * 2 * math.pi
        rr = r * t
        sx = -rr * math.cos(a) if flip else rr * math.cos(a)
        pts.append(f"{cx + sx:.1f} {cy + rr * math.sin(a):.1f}")
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


def wand(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0, lean=0.0):
    """A star-tipped wand — the wands must read as wands. A slender staff,
    a 4-point star at the tip, two small leaf-sparks along the shaft, a knob
    at the base. Celestial vocabulary, but unmistakably a wand — not a burst."""
    L = r * 1.15
    tx = cx + L * math.sin(lean)
    ty = cy - L * math.cos(lean)
    bx = cx - L * math.sin(lean)
    by = cy + L * math.cos(lean)
    out = [line(bx, by, tx, ty, **S(w, color, op))]
    out += star(tx, ty, r * 0.28, points=4, inner=0.4, w=THIN_W, color=color, op=op)
    dx, dy = tx - bx, ty - by
    dl = math.hypot(dx, dy) or 1.0
    px, py = -dy / dl, dx / dl
    for t, sgn in ((0.32, 1.0), (0.58, -1.0)):
        mx, my = bx + dx * t, by + dy * t
        ln = r * 0.3
        out.append(line(mx, my, mx + px * ln * sgn, my + py * ln * sgn,
                         **S(THIN_W, color, op * 0.85)))
    out.append(circle(bx, by, max(2.0, r * 0.07), **S(THIN_W, color, op)))
    return out


def wheat(cx, cy, r, w=MID_W, color=LINE, op=1.0, lean=0.0):
    """A stalk of wheat — the Empress is the mother of the harvest. A stalk
    with three paired kernels and a three-awn tuft at the tip: the garden's
    grain, unmistakably wheat. (Distinct from `wand` — the wand has a single
    star tip and no kernels — and from `starpath`'s dotted road.)"""
    L = r * 1.3
    a = -math.pi / 2 + lean                        # stalk direction, base → tip
    tx, ty = cx + (L / 2) * math.cos(a), cy + (L / 2) * math.sin(a)
    bx, by = cx - (L / 2) * math.cos(a), cy - (L / 2) * math.sin(a)
    out = [line(bx, by, tx, ty, **S(w, color, op))]
    px, py = -math.sin(a), math.cos(a)            # perpendicular to the stalk
    for t, k in ((0.18, 1.0), (0.38, 0.85), (0.58, 0.68)):   # kernels, tip → base
        mx, my = tx + (bx - tx) * t, ty + (by - ty) * t
        for sgn in (-1, 1):
            kx, ky = mx + px * sgn * r * 0.17, my + py * sgn * r * 0.17
            out.append(el("ellipse", cx=f"{kx:.1f}", cy=f"{ky:.1f}",
                          rx=f"{r * 0.125:.1f}", ry=f"{r * 0.30 * k:.1f}",
                          transform=f"rotate({math.degrees(a) - 90 + sgn * 30:.1f} {kx:.1f} {ky:.1f})",
                          **S(MID_W, color, op)))
    for da in (-0.38, 0.0, 0.38):                 # awns fanning from the tip
        out.append(line(tx, ty, tx + r * 0.42 * math.cos(a + da), ty + r * 0.42 * math.sin(a + da),
                        **S(THIN_W, color, op * 0.8)))
    return out


def blade(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """A celestial blade — the swords must read as swords. A slim pointed
    blade with a fuller, a crossguard, a grip, and a star pommel: the suit's
    steel drawn as starlight."""
    gy = cy + r * 0.45
    out = [path(f"M {cx:.1f} {cy - r:.1f} L {cx + r * 0.18:.1f} {gy:.1f} "
                f"L {cx - r * 0.18:.1f} {gy:.1f} Z", **S(w, color, op))]
    out.append(line(cx, cy - r * 0.72, cx, gy, **S(THIN_W, color, op * 0.6)))
    out.append(line(cx - r * 0.55, gy, cx + r * 0.55, gy, **S(MID_W, color, op)))
    out.append(line(cx, gy, cx, cy + r * 0.78, **S(w, color, op)))
    out += star(cx, cy + r * 0.9, r * 0.22, points=4, inner=0.4, w=THIN_W, color=color, op=op)
    return out


def pentacle(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """A pentacle — the pentacles must read as pentacles. A five-point star in
    a circle: the suit's coin, its face stamped with the star (the classic
    pentagram ratio, inner = 0.382)."""
    return [circle(cx, cy, r * 0.9, **S(w, color, op)),
            star(cx, cy, r * 0.55, points=5, inner=0.382, w=MID_W, color=color, op=op)]


def tree(cx, basey, r, w=MID_W, color=LINE, op=1.0):
    """A fruit tree — the Lovers' tree of knowledge. A round canopy with a
    few fruit dots, a trunk, and two root flicks: a tree at a glance, the
    garden side of the choice."""
    ty = basey - 0.9 * r            # the trunk top
    kcy = ty - 0.7 * r              # the canopy centre
    out = [circle(cx, kcy, r, **S(w, color, op)),
           line(cx, basey, cx, ty + 0.3 * r, **S(w, color, op))]
    for sgn in (-1, 1):            # root flicks
        out.append(line(cx, basey, cx + sgn * r * 0.5, basey + r * 0.12, **S(THIN_W, color, op * 0.8)))
    for fx, fy in ((-0.35, -0.25), (0.30, -0.40), (-0.05, 0.30), (0.35, 0.15)):   # the fruit
        out.append(dot(cx + fx * r, kcy + fy * r, 3.0, color, op * 0.8))
    return out


def flame(cx, basey, r, w=MID_W, color=LINE, op=1.0):
    """A flame — the Lovers' burning bush: fire on a twig. A wavy teardrop
    with a curled tip and an inner flame: fire at a glance (the droplet is
    water; this one tips and burns), the trial side of the choice."""
    d = (f"M {cx - r * 0.45:.1f} {basey:.1f} "
         f"C {cx - r * 0.70:.1f} {basey - r * 0.45:.1f} {cx - r * 0.30:.1f} {basey - r * 0.55:.1f} {cx - r * 0.18:.1f} {basey - r * 0.68:.1f} "
         f"C {cx - r * 0.02:.1f} {basey - r * 0.88:.1f} {cx + r * 0.18:.1f} {basey - r * 0.98:.1f} {cx + r * 0.10:.1f} {basey - r * 0.80:.1f} "
         f"C {cx + r * 0.05:.1f} {basey - r * 0.68:.1f} {cx + r * 0.12:.1f} {basey - r * 0.60:.1f} {cx + r * 0.22:.1f} {basey - r * 0.52:.1f} "
         f"C {cx + r * 0.38:.1f} {basey - r * 0.38:.1f} {cx + r * 0.55:.1f} {basey - r * 0.22:.1f} {cx + r * 0.45:.1f} {basey:.1f} "
         f"C {cx + r * 0.20:.1f} {basey + r * 0.16:.1f} {cx - r * 0.20:.1f} {basey + r * 0.16:.1f} {cx - r * 0.45:.1f} {basey:.1f} Z")
    out = [path(d, **S(w, color, op))]
    out += droplet(cx - r * 0.02, basey - r * 0.38, r * 0.26, w=MID_W, color=color, op=op * 0.85)
    for sgn in (-1, 1):            # the bush's twigs
        out.append(line(cx, basey, cx + sgn * r * 0.7, basey - r * 0.08, **S(THIN_W, color, op * 0.8)))
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


def starpath(cx, cy, width, height, seed, color=LINE, op=1.0, n=5):
    """A star road: small stars linked by faint lines, climbing across the card.
    The celestial version of a path — where `pathline` wanders, a star road
    *leads* (a journey marked by destinations, constellation-style)."""
    rng = random.Random(seed)
    pts = []
    for i in range(n):
        x = cx - width / 2 + width * i / (n - 1) + rng.uniform(-width * 0.1, width * 0.1)
        y = cy + height / 2 - height * i / (n - 1) + rng.uniform(-height * 0.1, height * 0.1)
        pts.append((x, y))
    out = []
    for i in range(n - 1):
        out.append(line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1],
                         **S(THIN_W, color, op * 0.45)))
    for x, y in pts:
        out.append(dot(x, y, 3.2, color, op))
    return out


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


def mountain(cx, basey, halfw, amp, w=THIN_W, color=LINE, op=1.0):
    """A ridge of peaks — the mountains behind the Emperor's throne. A quiet
    jagged horizon (two shoulders, a central peak) whose ends rest on the
    baseline, faint enough to sit behind the structure it frames."""
    prof = ((0.0, 0.0), (0.16, 1.0), (0.34, 0.5), (0.5, 0.78),
            (0.66, 0.5), (0.84, 1.0), (1.0, 0.0))
    pts = [f"{cx + (f - 0.5) * 2 * halfw:.1f} {basey - amp * hgt:.1f}" for f, hgt in prof]
    return [path("M " + " L ".join(pts), **S(w, color, op))]


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


def ram(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    """A ram's head — the Emperor sits under Aries. A small head with two
    curled horns (spirals) flanking it: the horned crown, a ram at a glance,
    distinct from the Priestess's pointed crown and the Empress's star circlet."""
    out = [circle(cx, cy, r * 0.38, **S(MID_W, color, op))]
    out += spiral(cx - r * 0.5, cy - r * 0.12, r * 0.5, turns=1.9, w=THIN_W, color=color, op=op * 0.9)
    out += spiral(cx + r * 0.5, cy - r * 0.12, r * 0.5, turns=1.9, w=THIN_W, color=color, op=op * 0.9, flip=True)
    return out


def tiara(cx, basey, r, w=MOTIF_W, color=LINE, op=1.0):
    """The triple tiara — the Hierophant's sign of office: the Pope's hat.
    One tall rounded dome with a brim, two ridges marking the three tiers,
    and a cross at the peak. Rounded and tiered — never pointed like the
    Priestess's `crown`, never stars like the Empress's circlet: a hat."""
    ry = r * 0.85
    topy = basey - ry
    out = [path(f"M {cx - r:.1f} {basey:.1f} A {r:.1f} {ry:.1f} 0 0 1 {cx + r:.1f} {basey:.1f}",
                **S(w, color, op)),
           line(cx - r, basey, cx + r, basey, **S(w, color, op))]            # the brim
    for fy in (0.45, 0.80):                                                  # the tier ridges
        hw = r * math.sqrt(1 - fy * fy)
        out.append(line(cx - hw, basey - ry * fy, cx + hw, basey - ry * fy,
                        **S(THIN_W, color, op * 0.85)))
    out.append(line(cx, topy - r * 0.30, cx, topy - r * 0.02, **S(w, color, op)))
    out.append(line(cx - r * 0.16, topy - r * 0.16, cx + r * 0.16, topy - r * 0.16,
                    **S(w, color, op)))
    return out


def keys(cx, cy, r, w=MID_W, color=LINE, op=1.0, lean=math.radians(26)):
    """Crossed keys — the Hierophant's: the keys to the kingdom of heaven,
    the power to bind and loose. Two keys crossing in an X, each a ringed
    bow, a shaft, and a two-toothed bit: keys at a glance, and no other
    card in the deck carries them."""
    out = []
    for sgn in (-1, 1):
        a = sgn * lean
        ca, sa = math.cos(a), math.sin(a)

        def R(x, y):
            return (cx + x * ca - y * sa, cy + x * sa + y * ca)

        bx, by = R(0, -r * 0.5)                 # the bow (ring)
        out.append(circle(bx, by, r * 0.26, **S(w, color, op)))
        sx0, sy0 = R(0, -r * 0.24)              # the shaft
        sx1, sy1 = R(0, r * 0.5)
        out.append(line(sx0, sy0, sx1, sy1, **S(w, color, op)))
        for ty in (r * 0.28, r * 0.44):         # the two teeth
            tx0, ty0 = R(0, ty)
            tx1, ty1 = R(r * 0.2, ty + r * 0.12)
            out.append(line(tx0, ty0, tx1, ty1, **S(THIN_W, color, op * 0.9)))
    return out


def pillars(cx, cy, h, w=MOTIF_W, color=LINE, op=1.0, gap=0.9):
    """Two complete columns under a lintel — a finished temple, the High
    Priestess's. Each column: a stepped capital, a fluted two-edge shaft, and
    a stepped plinth (a bare shaft reads as a stray line; round knobs read as
    random circles). The lintel rests on the two capitals, so the pair reads
    as a structure that supports something — not two floating sticks."""
    out = []
    colw = h * 0.09          # shaft half-width
    cap = h * 0.16           # abacus / plinth half-width
    step = h * 0.115         # capital / base step half-width
    s = h * 0.075            # height of the stepped zone
    top, bot = cy - h / 2, cy + h / 2
    for sx in (-gap, gap):
        x = cx + sx * h * 0.6
        out.append(line(x - cap, top, x + cap, top, w=w, color=color, op=op))            # abacus
        out.append(line(x - step, top + s, x + step, top + s, **S(MID_W, color, op)))    # capital step
        for ex in (-colw, colw):                                                          # fluted shaft
            out.append(line(x + ex, top + s, x + ex, bot - s, w=w, color=color, op=op))
        for fx in (-0.5, 0.5):
            out.append(line(x + fx * colw, top + s * 1.7, x + fx * colw, bot - s * 1.7,
                            **S(THIN_W, color, op * 0.5)))
        out.append(line(x - step, bot - s, x + step, bot - s, **S(MID_W, color, op)))    # base step
        out.append(line(x - cap, bot, x + cap, bot, w=w, color=color, op=op))            # plinth
    xl, xr = cx - gap * h * 0.6, cx + gap * h * 0.6
    out.append(line(xl - cap, top - s * 0.8, xr + cap, top - s * 0.8, w=w, color=color, op=op))   # lintel
    out.append(line(xl + cap, top, xr - cap, top, **S(MID_W, color, op)))                      # lintel underside
    return out


def droplet(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    d = (f"M {cx:.1f} {cy - r:.1f} C {cx + r:.1f} {cy + r * 0.1:.1f} {cx + r * 0.7:.1f} {cy + r:.1f} "
         f"{cx:.1f} {cy + r:.1f} C {cx - r * 0.7:.1f} {cy + r:.1f} {cx - r:.1f} {cy + r * 0.1:.1f} "
         f"{cx:.1f} {cy - r:.1f} Z")
    return [path(d, **S(w, color, op))]


def chalice(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """A chalice — the cups must read as cups. A rimmed bowl, a stem, and a
    foot: the one unambiguous cup silhouette. (A bare crescent, however
    cradling, still reads as a moon — and The Moon is a major.)"""
    rim = cy - r * 0.35
    out = [path(f"M {cx - r * 0.8:.1f} {rim:.1f} A {r * 0.8:.1f} {r * 0.75:.1f} 0 0 0 "
                f"{cx + r * 0.8:.1f} {rim:.1f} Z", **S(w, color, op))]
    out.append(line(cx, cy + r * 0.4, cx, cy + r * 0.85, **S(MID_W, color, op)))
    out.append(line(cx - r * 0.45, cy + r * 0.85, cx + r * 0.45, cy + r * 0.85, **S(MID_W, color, op)))
    return out


def venus(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0):
    """The Venus sign — the Empress is the mother goddess, and hers is the
    one card that may wear it. A circle over a cross: 'her', at a glance;
    no other card in the deck carries this glyph (the Priestess is her in
    body, the Moon is the moon)."""
    cr = r * 0.5
    cyc = cy - r * 0.35
    out = [circle(cx, cyc, cr, **S(w, color, op))]
    out.append(line(cx, cyc + cr, cx, cy + r * 0.8, **S(w, color, op)))
    out.append(line(cx - r * 0.55, cy + r * 0.48, cx + r * 0.55, cy + r * 0.48, **S(w, color, op)))
    return out


def wings(cx, cy, r, w=MID_W, color=LINE, op=1.0):
    """Spread wings — the angel of the Lovers, the one figure in the deck
    not of the ground. Two wings of one long feather-curve each, swept up
    and out from the shoulders, with a quill line down each: winged at a
    glance."""
    out = []
    for sgn in (-1, 1):
        s0 = (cx + sgn * r * 0.28, cy - r * 0.30)     # upper shoulder
        s1 = (cx + sgn * r * 0.34, cy + r * 0.18)     # lower shoulder
        tip = (cx + sgn * r * 1.15, cy - r * 0.85)    # the wing tip
        out.append(path(f"M {s0[0]:.1f} {s0[1]:.1f} "
                        f"C {cx + sgn * r * 0.60:.1f} {cy - r * 0.62:.1f} {cx + sgn * r * 0.85:.1f} {cy - r * 0.95:.1f} {tip[0]:.1f} {tip[1]:.1f} "
                        f"C {cx + sgn * r * 0.72:.1f} {cy - r * 0.55:.1f} {cx + sgn * r * 0.55:.1f} {cy - r * 0.05:.1f} {s1[0]:.1f} {s1[1]:.1f}",
                        **S(w, color, op)))
        out.append(line(cx + sgn * r * 0.32, cy - r * 0.26, cx + sgn * r * 0.95, cy - r * 0.68,
                        **S(THIN_W, color, op * 0.7)))
    return out


def littleFigure(cx, cy, r, w=MOTIF_W, color=LINE, op=1.0, brooch_points=4, brooch_inner=0.35, brooch=None):
    """A robed figure: a head over a CLOSED robe silhouette (a classical bust,
    like a coin's portrait) with a star brooch on the chest. The closed
    outline is what makes it read as a person — an open curve reads as a bowl.
    `brooch_points` varies the star per figure so the people don't all wear
    the same twinkle (the deck's default 4-point glint is everywhere).
    `brooch`, if given, is a function `(x, y, s, color, op) -> elements`
    that replaces the star pin — the Empress wears Venus, not a star."""
    out = [circle(cx, cy - r * 0.28, r * 0.27, **S(MID_W, color, op))]
    out.append(path(
        f"M {cx - r * 0.65:.1f} {cy + r * 0.75:.1f} "
        f"C {cx - r * 0.65:.1f} {cy + r * 0.28:.1f} {cx - r * 0.42:.1f} {cy + r * 0.14:.1f} {cx - r * 0.18:.1f} {cy + r * 0.12:.1f} "
        f"C {cx - r * 0.06:.1f} {cy + r * 0.16:.1f} {cx + r * 0.06:.1f} {cy + r * 0.16:.1f} {cx + r * 0.18:.1f} {cy + r * 0.12:.1f} "
        f"C {cx + r * 0.42:.1f} {cy + r * 0.14:.1f} {cx + r * 0.65:.1f} {cy + r * 0.28:.1f} {cx + r * 0.65:.1f} {cy + r * 0.75:.1f} Z",
        **S(MID_W, color, op)))
    if brooch is None:
        out += star(cx, cy + r * 0.45, r * 0.2, points=brooch_points, inner=brooch_inner,
                    w=THIN_W, color=color, op=op)
    else:
        out += brooch(cx, cy + r * 0.45, r * 0.2, color=color, op=op)
    return out


def wheel(cx, cy, r, spokes=8, w=MID_W, color=LINE, op=1.0, rot=0.0):
    """A spoked wheel: a rim, a hub, and spokes — the chariot's turning points
    drawn as starlight. A rim with spokes reads as a *wheel* (and therefore a
    vehicle) at a glance; a bare circle would read as a moon."""
    out = [circle(cx, cy, r, **S(w, color, op)),
           circle(cx, cy, max(2.0, r * 0.14), **S(THIN_W, color, op))]
    for i in range(spokes):
        a = rot + i * 2 * math.pi / spokes
        out.append(line(cx, cy, cx + r * 0.86 * math.cos(a), cy + r * 0.86 * math.sin(a),
                         **S(THIN_W, color, op * 0.85)))
    return out


def sphinx(cx, cy, r, s=1, w=MID_W, color=LINE, op=1.0):
    """A sphinx — the Chariot's two opposing beasts. A low body, a raised head
    on a neck, four legs, and a curling tail, drawn in profile. `s` is the
    facing direction (+1 right, -1 left): the two of them are mirrored so one
    faces left and one faces right — the chariot holds two forces that pull
    apart, which is the card's whole meaning. (A horse would borrow from The
    Sun; the sphinx is the deck's one mythic beast.)"""
    out = [el("ellipse", cx=f"{cx:.1f}", cy=f"{cy:.1f}",
              rx=f"{r * 0.95:.1f}", ry=f"{r * 0.40:.1f}", **S(w, color, op))]
    hx, hy = cx + s * r * 0.78, cy - r * 0.74                     # the head, raised
    out.append(line(cx + s * r * 0.40, cy - r * 0.10, cx + s * r * 0.66, hy + r * 0.30,
                    **S(MID_W, color, op)))                       # the neck
    out.append(circle(hx, hy, r * 0.36, **S(w, color, op)))
    out.append(line(hx - s * r * 0.10, hy - r * 0.28, hx - s * r * 0.26, hy - r * 0.52,
                    **S(THIN_W, color, op * 0.85)))              # the ear
    out.append(line(hx + s * r * 0.30, hy + r * 0.10, hx + s * r * 0.55, hy + r * 0.18,
                    **S(THIN_W, color, op * 0.9)))               # the snout
    for fx in (-0.58, -0.24, 0.26, 0.60):                        # four legs
        out.append(line(cx + s * r * fx, cy + r * 0.28, cx + s * r * fx, cy + r * 0.85,
                        **S(MID_W, color, op)))
    out.append(path(f"M {cx - s * r * 0.95:.1f} {cy - r * 0.05:.1f} "
                    f"C {cx - s * r * 1.32:.1f} {cy - r * 0.12:.1f} "
                    f"{cx - s * r * 1.40:.1f} {cy - r * 0.58:.1f} {cx - s * r * 1.16:.1f} {cy - r * 0.82:.1f}",
                    **S(THIN_W, color, op * 0.8)))               # the tail, a curl
    return out


def lion(cx, cy, r, s=1, w=MOTIF_W, color=LINE, op=1.0):
    """A tamed lion — the beast of Strength. Seated on the ground, head
    raised above the shoulders, eyes closed: not defeated, *tamed* — at
    peace in its own right. A sun for a mane: a spiky star around the face,
    its spikes the hair (in celestial line art a lion is a face in a burning
    ring), draping onto the shoulders. A wide low body (the haunches, seated
    on the ground), four short legs, and a tail curling up to a star tuft.
    `s` is the facing direction (+1 right, -1 left). (The Chariot's sphinx
    stands proud with a bare head; the lion is the deck's only real beast —
    and the only one that sits.)"""
    out = [el("ellipse", cx=f"{cx:.1f}", cy=f"{cy:.1f}",
              rx=f"{r * 1.08:.1f}", ry=f"{r * 0.50:.1f}", **S(w, color, op))]
    hx, hy = cx + s * r * 0.68, cy - r * 0.88                     # the head, raised
    out.append(line(cx + s * r * 0.45, cy - r * 0.45, cx + s * r * 0.78, cy - r * 0.68,
                    **S(MID_W, color, op)))                       # the neck, hidden under the mane
    out += star(hx, hy, r * 0.60, points=14, inner=0.68, w=MID_W, color=color, op=op * 0.9)   # the mane, a sun
    out.append(circle(hx, hy, r * 0.30, **S(w, color, op)))
    ey = hy + r * 0.06                                            # the face, at peace:
    for sgn in (-1, 1):                                          # two closed eyes
        out.append(path(f"M {hx + sgn * r * 0.11 - r * 0.075:.1f} {ey:.1f} "
                        f"A {r * 0.075:.1f} {r * 0.075:.1f} 0 0 1 {hx + sgn * r * 0.11 + r * 0.075:.1f} {ey:.1f}",
                        **S(THIN_W, color, op * 0.9)))
    out.append(line(hx - r * 0.09, hy + r * 0.16, hx + r * 0.09, hy + r * 0.16,
                    **S(THIN_W, color, op * 0.9)))               # and a short calm mouth
    for fx in (0.55, 0.80, -0.30, -0.58):                        # four short legs, haunches on the ground
        out.append(line(cx + s * r * fx, cy + r * 0.30, cx + s * r * fx, cy + r * 0.50,
                        **S(MID_W, color, op)))
    out.append(path(f"M {cx - s * r * 0.95:.1f} {cy - r * 0.20:.1f} "
                    f"C {cx - s * r * 1.18:.1f} {cy - r * 0.32:.1f} "
                    f"{cx - s * r * 1.20:.1f} {cy - r * 0.58:.1f} {cx - s * r * 1.10:.1f} {cy - r * 0.72:.1f}",
                    **S(THIN_W, color, op * 0.85)))             # the tail, a curl
    out += star(cx - s * r * 1.12, cy - r * 0.82, 6, points=4, inner=0.4, w=THIN_W, color=color, op=op * 0.9)   # the tuft
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


def build_card_art(name, spec, seed):
    """The card's line-art layer on a TRANSPARENT canvas: starfield + figure +
    frame + name, no background. Same rng sequence as build_card, so these are
    exactly the non-background pixels of the draft. The app composites this over
    the shared `card-bg` at render time (one gradient stored once instead of 79
    times); `actool` rasterizes the sparse layer to a small bitmap for the car,
    so the deck ships at ~8 MB instead of ~130+ MB."""
    rng = random.Random(seed)
    return svg_doc(starfield(rng) + spec + frame() + [nameplate(name)])


def build_back(seed, include_bg=True):
    """The card back — a quiet crescent-and-star seal, not a second illustration.

    The earlier zodiac ring, large eight-point star, and crescent crossed over
    one another and made the back read as visual noise at card size. This
    keeps one generous crescent and one separate guiding star, with a sparse,
    deliberately placed field around them. `include_bg=False` writes the
    transparent line-art layer for the app.
    """
    layers = bg() if include_bg else []
    # A fixed, open field: enough depth to feel celestial, never enough to
    # compete with the single crescent-and-star seal.
    for x, y, r, op in ((94, 184, 2.2, 0.32), (150, 302, 1.6, 0.24),
                        (430, 210, 2.0, 0.30), (456, 374, 1.4, 0.20),
                        (104, 576, 1.7, 0.22), (438, 606, 2.1, 0.28),
                        (162, 714, 1.4, 0.18), (390, 760, 1.8, 0.24),
                        (100, 826, 2.0, 0.26), (452, 850, 1.5, 0.20)):
        layers.append(dot(x, y, r, op=op))
    for x, y, r, op in ((118, 420, 7, 0.30), (420, 485, 6, 0.24),
                        (216, 220, 5, 0.22), (342, 690, 6, 0.26),
                        (270, 790, 5, 0.20), (82, 690, 5, 0.18)):
        layers += spark(x, y, r, points=4, w=THIN_W, color=LINE, op=op)
    # The two marks deliberately do not touch: one solid crescent on the
    # left and the guiding star beside it. A closed crescent silhouette reads
    # cleanly at small size; two overlapping outline arcs did not.
    layers.append(path(
        "M 214 325 "
        "C 104 360 104 475 214 510 "
        "C 164 460 164 375 214 325 Z",
        fill=LINE, stroke="none", **{"fill-opacity": "0.92"}))
    layers += star(338, FY - 20, 52, points=4, inner=0.28,
                   w=MOTIF_W, color=LINE, op=0.95)
    layers += frame()
    layers += [nameplate("Augury")]
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
    "wands":     {"prim": lambda x, y, r: wand(x, y, r),
                  "accent": lambda x, y, r: comet(x, y, r, angle=math.pi * 0.8, tail=2.4)},
    "cups":      {"prim": lambda x, y, r: chalice(x, y, r),
                  "accent": lambda x, y, r: droplet(x, y, r * 0.8)},
    "swords":    {"prim": lambda x, y, r: blade(x, y, r),
                  "accent": lambda x, y, r: spiral(x, y, r * 0.8, turns=2.0)},
    "pentacles": {"prim": lambda x, y, r: pentacle(x, y, r),
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
        return littleFigure(cx - 60, cy + 80, 80) \
            + starpath(cx + 92, cy + 5, 130, 260, seed) \
            + star(cx + 190, cy - 175, 22, points=5, inner=0.42, op=0.95)
    if name == "The Magician":
        return littleFigure(cx, cy + 65, 90) \
            + lemniscate(cx, cy - 55, 85, op=0.95) \
            + [wand(cx - 135, cy + 190, 30, op=0.85),
               chalice(cx - 45, cy + 215, 32, op=0.85),
               blade(cx + 45, cy + 215, 28, op=0.85),
               pentacle(cx + 135, cy + 190, 30, op=0.85)]
    if name == "The High Priestess":
        return pillars(cx, cy, 340, gap=0.62) \
            + littleFigure(cx, cy + 40, 85, brooch_points=6, brooch_inner=0.55) \
            + crown(cx, cy - 30, 26, op=0.95)
    if name == "The Empress":
        # The mother of the garden, a crowned woman: a twelve-star circlet
        # over her head (her crown — the crescent would read as the Moon's
        # halo), the Venus sign at her chest (hers, not the Sun's), wheat
        # flanking the robe, two roses at the hem, and the garden's river
        # below. She wears no star pin (the people do: Priestess 6, the rest
        # 4) — Venus is the glyph only she may carry. The figure is the hero;
        # the garden is the whisper.
        r = 95
        hy = cy + 45 - r * 0.28                    # her head
        out = littleFigure(cx, cy + 45, r,
                           brooch=lambda x, y, s, color, op: venus(x, y, s * 1.2, w=MOTIF_W, color=color, op=op))
        for i in range(12):                       # the crown: twelve stars on an arc
            a = math.radians(-160 + i * 140 / 11)
            out += star(cx + 62 * math.cos(a), hy + 62 * math.sin(a), 6.5, points=4, inner=0.35, w=THIN_W, op=0.9)
        return out + wheat(cx - 122, cy + 117, 85, lean=math.radians(9)) \
            + wheat(cx + 122, cy + 117, 85, lean=math.radians(-9)) \
            + rosette(cx - 85, cy + 180, 22, petals=5, op=0.6) \
            + rosette(cx + 85, cy + 180, 22, petals=5, op=0.6) \
            + tide(cx, cy + 240, 125, 13, waves=3, op=0.55)
    if name == "The Emperor":
        # The mountain father, the seat of order. A figure INSIDE a square
        # throne (the square is this card's identity — the Tower keeps its
        # pointed keep for it), a ram of Aries for a crown, a scepter at his
        # right, a two-tier pedestal below, and the ridge of peaks behind the
        # seat. Where the Priestess stands *between* the gate, he sits
        # *within* the walls.
        r = 95
        sq = 165
        h2 = sq * math.cos(math.pi / 4)         # the square's half-side
        ty = cy + 87                           # the throne's centre
        out = mountain(cx, ty - h2, 165, 115, op=0.45) \
            + star(cx, ty - h2 - 115 * 0.78 - 25, 15, points=4, inner=0.4, op=0.9) \
            + crystal(cx, ty, sq, sides=4, rot=math.pi / 4)
        out += [line(cx - h2 - 20, ty + h2 + 12, cx + h2 + 20, ty + h2 + 12, **S(MID_W, LINE, 0.7)),
                line(cx - h2 - 40, ty + h2 + 26, cx + h2 + 40, ty + h2 + 26, **S(MID_W, LINE, 0.5))]
        fy = ty + 15
        return out + littleFigure(cx, fy, r, brooch_points=5, brooch_inner=0.382) \
            + ram(cx, fy - r * 0.55 - 18, 34) \
            + wand(cx + 82, fy, 55, op=0.95)
    if name == "The Hierophant":
        # The one who binds and looses — the pope, the teacher of the
        # doctrine. A figure before the pillars (his temple family is the
        # Priestess's; she stands *between* the gate, he stands *before* it,
        # facing out to teach), a triple tiara for his office, and the
        # crossed keys at his chest. His hat is rounded and tiered, never
        # pointed like hers; his chest bears keys, hers a star.
        r = 90
        out = pillars(cx, cy + 10, 340, gap=0.72, op=0.85) \
            + littleFigure(cx, cy + 55, r,
                           brooch=lambda x, y, s, color, op: keys(x, y + s * 0.6, s * 1.2, color=color, op=op))
        return out + tiara(cx, cy + 55 - r * 0.28 - r * 0.27 - 2, 44)
    if name == "The Lovers":
        # Two people, one angel, and the choice between them. The couple
        # below (she veiled, he plain), the winged angel hovering over
        # them with the star of blessing, the fruit tree to the left and
        # the burning bush to the right, all on the ground of the scene.
        # The deck's only card with more than one person — union is a
        # *composition*, not a glyph. (The old sun is gone; it is The
        # Sun's.)
        out = [line(cx - 215, cy + 118, cx + 215, cy + 118, **S(MID_W, LINE, 0.5))]
        out += tree(cx - 162, cy + 118, 40, op=0.85) \
            + flame(cx + 166, cy + 118, 62, op=0.85)
        out += littleFigure(cx - 62, cy + 58, 80, brooch=lambda x, y, s, color, op: []) \
            + littleFigure(cx + 62, cy + 58, 80, brooch=lambda x, y, s, color, op: [])
        hx, hy = cx - 62, cy + 58 - 80 * 0.28         # her head, the veil
        out.append(path(f"M {hx - 26:.1f} {hy + 14:.1f} A 26 38 0 0 1 {hx + 26:.1f} {hy + 14:.1f}",
                        **S(THIN_W, LINE, 0.9)))
        ay = cy - 70                                  # the angel
        return out + wings(cx, ay, 55) \
            + littleFigure(cx, ay, 55, brooch=lambda x, y, s, color, op: []) \
            + star(cx, ay - 55 * 0.28 - 55 * 0.27 - 20, 12, points=4, inner=0.4, w=THIN_W, op=0.9)
    if name == "The Chariot":
        # The will at the helm. A charioteer seated in a raised cart on two
        # spoked wheels, two sphinxes hitched ahead facing *outward* — one
        # left, one right, the forces that pull apart and the will that holds
        # them — and a canopy of stars roofed over the whole procession.
        # The deck's one vehicle: the beast-pair and the wheels make it read
        # as a chariot at a glance; the star canopy is what makes it *ours*.
        gy = cy + 185                          # the road
        rb = 60
        bcy = gy - rb * 0.85                   # the beasts, feet on the road
        out = [line(cx - 225, gy, cx + 225, gy, **S(THIN_W, LINE, 0.5))]
        out += littleFigure(cx, gy - 158.5, 78, brooch_points=5, brooch_inner=0.382)
        out += wheel(cx - 70, gy - 40, 40) + wheel(cx + 70, gy - 40, 40)
        out.append(path(f"M {cx - 80:.1f} {gy - 100:.1f} L {cx + 80:.1f} {gy - 100:.1f} "
                        f"L {cx + 58:.1f} {gy - 45:.1f} L {cx - 58:.1f} {gy - 45:.1f} Z",
                        **S(MOTIF_W, LINE, 0.95)))   # the cart body; the robe hem meets its rim
        out += sphinx(cx - 148, bcy, rb, s=-1) + sphinx(cx + 148, bcy, rb, s=1)
        for i in range(9):                     # the star canopy, a dome overhead
            a = math.radians(-54 + 108 * i / 8)
            out += star(cx + 148 * math.sin(a), cy + 103 - 148 * math.cos(a),
                        8, points=4, inner=0.4, w=THIN_W, op=0.8)
        return out
    if name == "Strength":
        # The lion alone — strength without a tamer. Seated on the ground,
        # head raised, eyes closed: not defeated, at peace. A sun for a mane,
        # a tail curling up to a star tuft. The deck's only beast carries
        # the card on its own: power, worn gently.
        lw = 160
        gy = cy + 165                           # the ground
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += lion(cx, gy - lw * 0.50, lw, s=-1)   # seated: haunches on the ground
        return out
    if name == "The Hermit":
        # The solitary one, on the summit. One figure, one peak, one light.
        # He stands on a lone peak — solitude is *elevation* (the Emperor's
        # ridge sits behind his walls; the Hermit's summit is his own) — and
        # holds a lantern: a crystal of starlight, the light within, the one
        # attribute no other card carries (the Emperor's crystal is a square
        # throne; his is a hexagon of light). Above, the night keeps watch:
        # the crescent and a single star. Kept spare on purpose: the deck's
        # most private card gives the silence room to sit.
        gy = cy + 170                                   # the mountain's foot, the ground
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        amp = 150
        # a lone summit: one high peak over two lower shoulders — the deck's
        # other ridge (the Emperor's `mountain`) has the *opposite* profile,
        # so the two mountains never blur into one another
        prof = ((0.0, 0.0), (0.22, 0.5), (0.50, 1.0), (0.78, 0.5), (1.0, 0.0))
        pts = [f"{cx + (f - 0.5) * 380:.1f} {gy - amp * hgt:.1f}" for f, hgt in prof]
        out.append(path("M " + " L ".join(pts), **S(THIN_W, LINE, 0.5)))
        r = 88
        fy = gy - amp - r * 0.75                       # the robe hem, on the summit
        out += littleFigure(cx, fy, r, brooch=lambda x, y, s, color, op: [])
        lx, ly = cx - 70, fy + 2                      # the lantern, in his hand, at his left
        out += [line(lx, ly - 27, cx - 45, fy + 50, **S(MID_W, LINE, 0.9))]  # the staff, from the crystal to the robe
        out += crystal(lx, ly, 27)                    # the lantern: a hexagon of light
        out += star(lx, ly, 12, points=4, inner=0.35, w=THIN_W, op=0.95)     # the light within
        out += star(cx + 128, cy - 158, 28, points=5, inner=0.45, op=0.95)   # a single star, the way without
        out += crescent(cx - 112, cy - 152, 36, open=0.6, angle=math.pi / 2, op=0.9)
        return out
    if name == "Wheel of Fortune":
        # The turning wheel — fortune as a *cycle*, the whole card in motion.
        # A big spoked wheel (the Chariot's little wheels, grown to full size —
        # vehicle and wheel are one family), twelve stations on the rim (the
        # zodiac: every turn passes all twelve), a star at the hub (the axis
        # fortune turns on), and two five-point stars riding the rim — one
        # climbing, one falling — each with an arc of motion so the wheel
        # reads as *turning*, not parked.
        wc = cy - 15
        out = [line(cx - 215, cy + 190, cx + 215, cy + 190, **S(MID_W, LINE, 0.5))]
        out += wheel(cx, wc, 165, spokes=8)
        for i in range(12):                        # the zodiac stations on the rim
            a = i * math.pi / 6
            out.append(dot(cx + 165 * math.cos(a), wc + 165 * math.sin(a), 3.2, op=0.75))
        out += star(cx, wc, 34, points=4, inner=0.4, op=0.95)   # the hub: the axis
        a_up, a_dn = math.radians(225), math.radians(45)   # the two travellers
        out += star(cx + 165 * math.cos(a_up), wc + 165 * math.sin(a_up), 26,
                    points=5, inner=0.45, rot=a_up, op=0.95)        # ascending
        out += star(cx + 165 * math.cos(a_dn), wc + 165 * math.sin(a_dn), 26,
                    points=5, inner=0.45, rot=a_dn + math.pi, op=0.95)   # descending
        def arc(x, y, r, a0, a1):
            p0 = (x + r * math.cos(a0), y + r * math.sin(a0))
            p1 = (x + r * math.cos(a1), y + r * math.sin(a1))
            return [path(f"M {p0[0]:.1f} {p0[1]:.1f} A {r:.1f} {r:.1f} 0 0 1 {p1[0]:.1f} {p1[1]:.1f}",
                         **S(THIN_W, LINE, 0.5)),
                    spark(x + r * math.cos(a1), y + r * math.sin(a1), 10, points=4, w=THIN_W, op=0.6)]
        out += arc(cx, wc, 196, math.radians(255), math.radians(285))   # the climb
        out += arc(cx, wc, 196, math.radians(15), math.radians(45))     # the fall
        return out
    if name == "Justice":
        # The weighing. Two parties stand apart below; the scale rises between
        # them; the star of the verdict hangs above. A card of *balance as
        # composition*: neither figure leads, the scale is the agent, and the
        # pans hang level (justice, not favour). The deck's only card whose
        # subject is an instrument rather than a being.
        gy = cy + 180
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += littleFigure(cx - 115, cy + 130, 62)
        out += littleFigure(cx + 115, cy + 130, 62, brooch_points=5, brooch_inner=0.382)
        out += scale(cx, cy - 15, 125)
        return out + star(cx, cy - 185, 40, points=4, inner=0.4, op=0.95)   # the verdict
    if name == "The Hanged Man":
        # The voluntary surrender — the deck's only *inverted* person. He
        # hangs from a tree limb by a rope, upside down, and keeps his peace:
        # a halo of light around the head (enlightenment is what the inversion
        # buys; the closed robe makes the up-side-down unmistakable). The limb
        # sags where the rope takes its weight; a quiet star above. No ground:
        # he is not of it (the one who chose this is suspended from it).
        by = cy - 160                          # the branch
        out = [path(f"M {cx - 165:.1f} {by:.1f} Q {cx:.1f} {by + 22:.1f} {cx + 165:.1f} {by:.1f}",
                    **S(MID_W, LINE, 0.9))]   # the limb, sagging under the rope
        for bx, sgn in ((cx - 95, -1.0), (cx + 95, 1.0)):
            out.append(line(bx, by + 11, bx + sgn * 30, by - 16, **S(THIN_W, LINE, 0.8)))
            out += spark(bx + sgn * 30, by - 16, 11, points=3, w=THIN_W, op=0.7)   # the leaves
        out += [line(cx, by + 11, cx, cy - 58, **S(MID_W, LINE, 0.9))]              # the rope
        out.append(circle(cx, cy - 54, 6, **S(THIN_W, LINE, 0.9)))                  # the knot
        fy = cy + 10
        fig = littleFigure(cx, fy, 85)
        out.append(el("g", "".join(fig), transform=f"rotate(180 {cx:.1f} {fy:.1f})"))
        hy = fy + 0.28 * 85                    # the head, now below
        out += [circle(cx, hy, 38, **S(THIN_W, LINE, 0.85))]                        # the halo
        return out + star(cx, cy - 198, 14, points=4, inner=0.4, w=THIN_W, op=0.8)
    if name == "Death":
        # The passage, not the end — a star in transit. A dying star (a five-
        # point star wrapped in its own halo) falls along the diagonal with a
        # comet's wake trailing behind it, toward a dawn on the horizon: a
        # dome of light and a young crescent. One rose on the ground — what
        # was, remembered. Everything tilts with the fall; the card is a
        # single motion from night to morning. (No rider, no beast — the
        # deck's beasts belong to the Chariot and Strength; here death is a
        # *celestial* event: a light going out and a light coming up.)
        sx, sy = cx - 15, cy + 15
        out = comet(sx, sy, 60, angle=math.pi * 1.25, tail=3.4)   # halo + wake, from the north-west
        out += star(sx, sy, 60, points=5, inner=0.45)             # the star within the halo
        tx, ty = math.cos(math.pi * 1.25), math.sin(math.pi * 1.25)
        for t, op in ((0.45, 0.5), (0.7, 0.35), (0.95, 0.22)):    # the wake, fading
            out.append(dot(sx + tx * 205 * t, sy + ty * 205 * t, 3.2 - t, op=op))
        gy = cy + 190
        out += [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.55))]
        out.append(path(f"M {cx + 30:.1f} {gy:.1f} A 75 75 0 0 1 {cx + 180:.1f} {gy:.1f}",
                        **S(MID_W, LINE, 0.7)))                   # the dawn, a dome on the horizon
        out += crescent(cx + 105, gy - 120, 30, open=0.62, angle=math.pi * 1.15, op=0.85)   # the young moon
        out += rosette(cx - 140, gy - 24, 20, petals=5, op=0.55)  # the rose: what was
        return out
    if name == "Temperance":
        # The angel of the mixing — one water, two vessels. A figure between
        # two chalices, pouring from one into the other (the cups of the RWS
        # reading, drawn as the deck's one cup silhouette); an arc of water
        # passes in front of the robe, a star hangs over the head (the RWS
        # star of the spirit), and a quiet sea lies below — the water both
        # cups share is one water. The pouring arc is the card's motion;
        # nothing here is at rest.
        gy = cy + 150
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += tide(cx, gy + 40, 150, 10, waves=2, op=0.4)            # the shared sea
        out += littleFigure(cx, cy + 10, 95)
        out += star(cx, cy - 85, 34, points=4, inner=0.4, op=0.95)    # the star of the spirit
        out += chalice(cx - 125, cy + 35, 58) + chalice(cx + 125, cy + 35, 58)
        # the pour: an arc from the left rim to the right, in front of the robe
        p0 = (cx - 125, cy + 35 - 58 * 0.35)
        p1 = (cx + 125, cy + 35 - 58 * 0.35)
        c = (cx, cy - 43)
        out.append(path(f"M {p0[0]:.1f} {p0[1]:.1f} Q {c[0]:.1f} {c[1]:.1f} {p1[0]:.1f} {p1[1]:.1f}",
                        **S(MID_W, LINE, 0.9)))
        for t in (0.25, 0.5, 0.75):                                    # the water, falling along the arc
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]
            out += droplet(x, y + 9, 8, op=0.8)
        return out
    if name == "The Devil":
        # The bondage — a fallen light above, two bound beings below. The
        # deck's one *inverted* star (every other card wears its star upright):
        # a five-point star turned down inside its ring, with two curved horns
        # from the top — Baphomet at a glance, drawn in starlight. The two
        # figures below are chained to it by arcs of dots (chains of light —
        # the bond is desire, and desire is also starlight). The deck's
        # darker card: no ground of hope, no rising, just the ring, the horns,
        # and the leash.
        out = []
        # the fallen star, ringed and horned
        out += star(cx, cy - 60, 85, points=5, inner=0.45, rot=math.pi)
        out.append(circle(cx, cy - 60, 95, **S(MID_W, LINE, 0.7)))
        for sgn in (-1, 1):                      # the horns, from the top of the ring
            out.append(path(f"M {cx + sgn * 28:.1f} {cy - 148:.1f} "
                            f"Q {cx + sgn * 60:.1f} {cy - 205:.1f} {cx + sgn * 105:.1f} {cy - 212:.1f}",
                            **S(MID_W, LINE, 0.9)))
        for sgn in (-1, 1):                     # the two bound
            out += littleFigure(cx + sgn * 110, cy + 120, 70)
        for sgn in (-1, 1):                     # the chains: arcs of dots, neck to ring
            for t in (0, 0.2, 0.4, 0.6, 0.8, 1.0):
                x = (1 - t) ** 2 * (cx + sgn * 110) + 2 * (1 - t) * t * (cx + sgn * 175) + t * t * (cx + sgn * 30)
                y = (1 - t) ** 2 * (cy + 100) + 2 * (1 - t) * t * (cy - 5) + t * t * (cy + 10)
                out.append(dot(x, y, 2.6, op=0.75 - t * 0.2))
        gy = cy + 178
        return out + [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
    if name == "The Tower":
        # The struck keep — the deck's one card of destruction. The keep's
        # own pointed roof (its silhouette, kept from the pass-1 fix), a bolt
        # of starlight striking the apex, a burst of light where they meet,
        # and two stars thrown off the tower and falling — the exiled, the
        # RWS's two falling figures drawn as the deck's one "person made of
        # light". The crown comes off, the lights go down, and the card is
        # done: disruption is a single instant, not a scene.
        gy = cy + 190
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += tower(cx, cy + 55, 130)
        out += bolt(cx, cy - 150, 75)                       # the bolt, on the apex
        out += burst(cx, cy - 85, 55, points=10, op=0.9)   # the light where they meet
        for sx, sy, sr, srot in ((cx + 105, cy + 15, 26, 0.6), (cx - 95, cy + 105, 20, -0.5)):   # the exiled, falling
            out += star(sx, sy, sr, points=5, inner=0.45, rot=srot, op=0.9)
            out.append(line(sx, sy - sr * 0.4, sx - 8, sy - sr * 1.9, **S(THIN_W, LINE, 0.45)))
        return out + spark(cx - 140, gy - 15, 14, op=0.6) + spark(cx + 150, gy - 20, 12, op=0.5)
    if name == "The Star":
        # The hope — a light above, a figure pouring below. The deck's biggest
        # star (eight points, the RWS' great star) over seven lesser ones in
        # the arc of the sky; below, a figure pours — one stream into the pool
        # (the water), one onto the land (the seed): the RWS' two offerings,
        # drawn as drops along a falling arc. The card is the deck's quietest
        # optimism: nothing struggles here, everything flows.
        gy = cy + 175
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += star(cx, cy - 115, 105, points=8, inner=0.42)
        for i in range(7):                          # the seven stars, an arc beneath
            a = math.radians(210 + i * 30)
            out += star(cx + 150 * math.cos(a), cy - 115 + 150 * math.sin(a), 9, points=4, inner=0.35, w=THIN_W, op=0.6)
        out += littleFigure(cx - 30, cy + 80, 80)
        out += tide(cx + 105, cy + 165, 105, 12, waves=2, op=0.7)        # the pool
        out += [line(cx - 30 + 40, cy + 95, cx + 70, cy + 150, **S(THIN_W, LINE, 0.8))]   # into the pool
        for t, x, y in ((0.35, 30, 118), (0.75, 58, 141)):
            out += droplet(cx - 30 + x, cy + y, 7, op=0.8)
        out += [line(cx - 30 - 45, cy + 95, cx - 105, cy + 165, **S(THIN_W, LINE, 0.8))]  # onto the land
        for x, y, r in ((-75, 130, 7), (-95, 152, 6), (-108, 168, 5)):
            out += droplet(cx - 30 + x, cy + y, r, op=0.8)
        return out
    if name == "The Moon":
        # The dream-road — the moon over the way between the towers. The
        # deck's one face-on moon (the Empress's circlet and the cups' bowls
        # are crescents; hers is the full face), with the road climbing to it
        # between two round towers (the RWS' gate pair — round, like the moon;
        # the Priestess' fluted gate and the Tower's pointed keep stay theirs),
        # and the pool at the bottom of the way keeping its small life: the
        # swirl and the drop (the crayfish and the water of the RWS pool).
        out = [circle(cx, cy - 105, 95)] + face(cx, cy - 105, 95)
        def rt(x, basey, r):                 # a round tower: walls, a dome, a foot
            top = basey - 2 * r * 0.9
            return [line(x - r * 0.7, top, x - r * 0.7, basey, **S(MOTIF_W, LINE, 0.9)),
                    line(x + r * 0.7, top, x + r * 0.7, basey, **S(MOTIF_W, LINE, 0.9)),
                    path(f"M {x - r * 0.7:.1f} {top:.1f} A {r * 0.7:.1f} {r * 0.45:.1f} 0 0 1 {x + r * 0.7:.1f} {top:.1f}",
                         **S(MOTIF_W, LINE, 0.9)),
                    line(x - r, basey, x + r, basey, **S(MID_W, LINE, 0.9))]
        out += rt(cx - 155, cy + 180, 55) + rt(cx + 155, cy + 180, 55)
        out += [line(cx - 85, cy + 215, cx - 40, cy - 30, **S(MID_W, LINE, 0.8)),
                line(cx + 85, cy + 215, cx + 40, cy - 30, **S(MID_W, LINE, 0.8))]   # the road, climbing to the moon
        out += tide(cx, cy + 195, 90, 9, waves=2, op=0.6)        # the pool
        out += spiral(cx - 25, cy + 195, 16, turns=2.0, op=0.7)  # the crayfish, a swirl
        out += droplet(cx + 30, cy + 200, 12, op=0.7)            # the water
        return out
    if name == "The Sun":
        # The joy — the deck's only *warm* card. The big face-on sun (the moon
        # wears the other face; the two face-cards answer each other), a child
        # below it waving a banner of a star (victory, not effort — the RWS'
        # naked child with the banner, drawn as the deck's robed figure), and
        # a row of sunflowers along the ground (the RWS' flower border —
        # the Empress's roses are five-petalled and few; the sun's are eight
        # and many). Nothing here is in tension: it simply shines.
        gy = cy + 155
        out = [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        out += sun(cx, cy - 85, 95, rays=12) + face(cx, cy - 85, 95, op=0.95)
        out += littleFigure(cx - 15, cy + 85, 78)
        out += [line(cx + 55, cy + 60, cx + 55, cy - 60, **S(MOTIF_W, LINE, 0.9))]
        out += star(cx + 55, cy - 75, 16, points=4, inner=0.4, op=0.95)   # the banner of victory
        for fx, fr in ((-165, 20), (-90, 24), (25, 20), (95, 24), (165, 20)):  # the sunflowers
            fy = gy - 24
            out += rosette(cx + fx, fy, fr, petals=8, op=0.8)
            out.append(line(cx + fx, fy + fr * 0.55, cx + fx, gy, **S(THIN_W, LINE, 0.7)))
        return out
    if name == "Judgement":
        # The call — the angel sounds the horn, the dead rise. A figure with
        # a star overhead (her herald) and a flared horn of light: the trumpet
        # drawn as a flare of starlight with three waves of sound (the call
        # is what leaves the card, it travels). Below, three figures rise from
        # open coffins — the RWS' many dead as the deck's three, the least
        # number that makes a *rising*. No wings (the Lovers' angel holds the
        # deck's only wings): this one stands and sounds, and the sound does
        # the lifting.
        out = littleFigure(cx, cy - 65, 85)
        out += star(cx, cy - 150, 26, points=4, inner=0.4, op=0.95)   # the herald above
        hy = cy - 65 - 85 * 0.28                   # the horn, from the mouth
        out += [line(cx + 25, hy, cx + 125, cy - 100, **S(MOTIF_W, LINE, 0.9)),
                line(cx + 25, hy, cx + 125, cy - 50, **S(MOTIF_W, LINE, 0.9)),
                path(f"M {cx + 125:.1f} {cy - 100:.1f} A 26 26 0 0 1 {cx + 125:.1f} {cy - 50:.1f}",
                     **S(MID_W, LINE, 0.9))]
        for rr, op in ((30, 0.6), (52, 0.4), (74, 0.25)):              # the waves of the call
            out.append(path(f"M {cx + 132 + rr * 0.5:.1f} {cy - 75 - rr * 0.85:.1f} "
                            f"A {rr:.1f} {rr:.1f} 0 0 1 {cx + 132 + rr * 0.5:.1f} {cy - 75 + rr * 0.85:.1f}",
                            **S(THIN_W, LINE, op)))
        gy = cy + 150
        out += [line(cx - 215, gy, cx + 215, gy, **S(MID_W, LINE, 0.5))]
        for fx, fr in ((-115, 42), (0, 46), (115, 42)):                # the rising dead
            out += littleFigure(cx + fx, cy + 85, fr)
            out.append(el("rect", x=f"{cx + fx - 30:.1f}", y=f"{cy + 119:.1f}",
                          width="60", height="22", **S(MID_W, LINE, 0.9)))   # the coffin
            out.append(line(cx + fx - 30, cy + 119, cx + fx - 48, cy + 103, **S(THIN_W, LINE, 0.7)))  # the lid, thrown back
        return out
    if name == "The World":
        # The completion — the dancer in the wreath, the four living creatures
        # at the corners. A double laurel ring (the deck's one ellipse pair),
        # a figure at its heart on a whirling path (the dance — the RWS' dancing
        # figure, the deck's last person), and the four corner beings as the
        # four star counts: 4 the man, 5 the eagle, 6 the ox, 8 the lion —
        # every creature in the deck's own vocabulary (a star is this deck's
        # way of saying *alive*). The journey's end: all the sky, contained.
        out = [orbit(cx, cy, 165, 200),
               orbit(cx, cy, 148, 183, w=THIN_W, color=LINE, op=0.5)]   # the laurel
        out += littleFigure(cx, cy + 5, 75)
        a0, a1 = math.radians(120), math.radians(60)
        p0 = (cx + 100 * math.cos(a0), cy + 5 + 100 * math.sin(a0))
        p1 = (cx + 100 * math.cos(a1), cy + 5 + 100 * math.sin(a1))
        out.append(path(f"M {p0[0]:.1f} {p0[1]:.1f} A 100 100 0 1 1 {p1[0]:.1f} {p1[1]:.1f}",
                        **S(THIN_W, LINE, 0.5)))                       # the whirling path
        corners = [((cx - 120, cy - 150), 4), ((cx + 120, cy - 150), 5),
                   ((cx - 120, cy + 150), 6), ((cx + 120, cy + 150), 8)]
        for (x, y), n in corners:                       # the four living creatures
            out += star(x, y, 30, points=n, inner=0.42, op=0.9)
        return out
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

    # The card back (not a deck card, so it is not in _order.txt).
    back_seed = seed_base * 1000 + len(DECK)
    with open(os.path.join(out_dir, "card-back.svg"), "w") as f:
        f.write(build_back(back_seed))

    # Layer split for the app: the shared background + one transparent line-art
    # layer per card (+ the back's art layer). Regenerable build input
    # (gitignored) — `sync_assets.py` copies these into the asset catalog.
    layer_dir = os.path.join(out_dir, "layers")
    os.makedirs(layer_dir, exist_ok=True)
    with open(os.path.join(layer_dir, "card-bg.svg"), "w") as f:
        f.write(svg_doc(bg()))
    for idx, card in enumerate(DECK):
        seed = seed_base * 1000 + idx
        spec = figure_for_major(card["name"], seed) if card["major"] \
            else figure_for_minor(card["suit"], card["rank"], seed)
        base = (card["file"][:-4] + ".svg")
        with open(os.path.join(layer_dir, base), "w") as f:
            f.write(build_card_art(card["name"], spec, seed))
    with open(os.path.join(layer_dir, "card-back.svg"), "w") as f:
        f.write(build_back(back_seed, include_bg=False))  # transparent art layer

    # Validate: every draft must be well-formed XML with the expected shape.
    import xml.etree.ElementTree as ET
    ok = bad = 0
    cards = [dict(c) for c in DECK] + [{"file": "card-back.svg"}]
    for card in cards:
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
    print(f"{len(cards)} files  |  valid {ok}  |  bad {bad}  →  {out_dir}/")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
