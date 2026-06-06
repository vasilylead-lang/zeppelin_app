#!/usr/bin/env python3
"""Render the TTR Zeppelin Command logo and generate all iOS app icon sizes."""

import os
import math
from PIL import Image, ImageDraw

# ─── TTR palette ─────────────────────────────────────────────────────────────
CREAM      = (244, 232, 201)
PARCHMENT  = (232, 213, 168)
INK        = (61, 40, 23)
INK_LIGHT  = (107, 68, 35)
RED        = (200, 54, 45)
NAVY       = (31, 58, 95)
BRASS      = (184, 134, 11)
WOOD       = (92, 58, 33)
TAN        = (184, 153, 104)   # envelope bottom for gradient


def render_logo(target_size: int, background=PARCHMENT) -> Image.Image:
    """Render the logo at the requested square size, with the given solid
    background color. Uses 3x SSAA for clean anti-aliased edges."""
    SSAA = 3
    W = target_size * SSAA
    H = W

    # Start with the background (so the icon is opaque — iOS requires no alpha)
    img = Image.new('RGB', (W, H), background)
    draw = ImageDraw.Draw(img)

    cx, cy = W / 2, H / 2
    s = W / 80  # base scale: original widget is 80px

    # ── Outer red disc with thick ink border ──
    r_outer = W / 2 - 1 * s
    ellipse(draw, cx, cy, r_outer, fill=RED, outline=INK, width=2 * s)

    # ── Cream inner disc + ink hairline ──
    r_inner = r_outer - 8 * s
    ellipse(draw, cx, cy, r_inner, fill=CREAM, outline=INK, width=0.8 * s)

    # ── Brass accent ring ──
    r_brass = r_inner - 2.5 * s
    ellipse(draw, cx, cy, r_brass, fill=None, outline=BRASS, width=0.8 * s)

    # ── 6 cream stars on the red ring ──
    star_r = W * 0.035
    star_orbit = r_outer - W * 0.04
    for i in range(6):
        a = -math.pi / 2 + i * math.pi / 3
        px = cx + math.cos(a) * star_orbit
        py = cy + math.sin(a) * star_orbit
        draw_star(draw, px, py, star_r, fill=CREAM, outline=INK,
                  outline_w=max(1, int(0.4 * s)))

    # ── Zeppelin ──
    zcx = cx + 1 * s
    zcy = cy + W * 0.05
    zW_ = W * 0.50
    zH_ = W * 0.20

    # Tail fin (drawn first, behind the envelope)
    fin_base_x = zcx - zW_ / 2 + 2 * s
    fin = [
        (fin_base_x,                       zcy - zH_ * 0.15),
        (fin_base_x - W * 0.06,            zcy - zH_ * 0.65),
        (fin_base_x - W * 0.06,            zcy + zH_ * 0.65),
    ]
    draw.polygon(fin, fill=WOOD, outline=INK)

    # Envelope: rounded rect with cream→tan vertical gradient
    e_x0 = zcx - zW_ / 2
    e_y0 = zcy - zH_ / 2
    e_x1 = zcx + zW_ / 2
    e_y1 = zcy + zH_ / 2
    radius = int(zH_ / 2)
    grad = vertical_gradient(int(zW_), int(zH_), CREAM, TAN)
    mask = Image.new('L', (int(zW_), int(zH_)), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([(0, 0), (int(zW_) - 1, int(zH_) - 1)],
                         radius=radius, fill=255)
    img.paste(grad, (int(e_x0), int(e_y0)), mask)
    draw.rounded_rectangle([(e_x0, e_y0), (e_x1, e_y1)],
                           radius=radius, outline=INK,
                           width=max(1, int(0.9 * s)))

    # Red stripe + brass under-stripe
    stripe_w = zW_ - 6 * s
    sh = zH_ * 0.18
    draw.rectangle([(zcx - stripe_w / 2, zcy - sh / 2),
                    (zcx + stripe_w / 2, zcy + sh / 2)], fill=RED)
    under_h = zH_ * 0.06
    under_y = zcy + zH_ * 0.20
    draw.rectangle([(zcx - stripe_w / 2, under_y - under_h / 2),
                    (zcx + stripe_w / 2, under_y + under_h / 2)], fill=BRASS)

    # Gondola
    gcx = zcx
    gcy = zcy + zH_ * 0.65
    gw = zW_ * 0.42
    gh = zH_ * 0.36
    draw.rounded_rectangle([(gcx - gw / 2, gcy - gh / 2),
                            (gcx + gw / 2, gcy + gh / 2)],
                           radius=int(2 * s), fill=WOOD, outline=INK,
                           width=max(1, int(0.7 * s)))

    # ── Tiny aircraft glyph (above-right of zeppelin) ──
    pcx = cx + W * 0.22
    pcy = cy - W * 0.22
    pw = W * 0.16
    plane_w = max(1, int(1.4 * s))
    tail_w = max(1, int(1.0 * s))
    # Fuselage
    draw.line([(pcx - pw * 0.45, pcy), (pcx + pw * 0.5, pcy)],
              fill=INK, width=plane_w)
    # Wing
    draw.line([(pcx - pw * 0.10, pcy - pw * 0.28),
               (pcx - pw * 0.10, pcy + pw * 0.28)],
              fill=INK, width=plane_w)
    # Tail
    draw.line([(pcx - pw * 0.40, pcy - pw * 0.18),
               (pcx - pw * 0.40, pcy + pw * 0.05)],
              fill=INK, width=tail_w)
    # Brass propeller hub
    hub_r = 1.2 * s
    draw.ellipse([(pcx + pw * 0.5 - hub_r, pcy - hub_r),
                  (pcx + pw * 0.5 + hub_r, pcy + hub_r)], fill=BRASS)

    # Downsample with Lanczos for clean anti-aliasing
    return img.resize((target_size, target_size), Image.LANCZOS)


# ─── helpers ────────────────────────────────────────────────────────────────

def ellipse(draw, cx, cy, r, fill=None, outline=None, width=1):
    bbox = [(cx - r, cy - r), (cx + r, cy + r)]
    if fill is not None:
        draw.ellipse(bbox, fill=fill,
                     outline=outline, width=max(1, int(width)))
    else:
        draw.ellipse(bbox, outline=outline, width=max(1, int(width)))


def vertical_gradient(w, h, top, bottom) -> Image.Image:
    """Row-by-row vertical gradient (RGB)."""
    img = Image.new('RGB', (w, h), top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (w - 1, y)], fill=(r, g, b))
    return img


def draw_star(draw, cx, cy, r, fill, outline, outline_w=1):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(pts, fill=fill, outline=outline, width=outline_w)


# ─── main ──────────────────────────────────────────────────────────────────

IOS_ICONS = {
    'Icon-App-20x20@1x.png':       20,
    'Icon-App-20x20@2x.png':       40,
    'Icon-App-20x20@3x.png':       60,
    'Icon-App-29x29@1x.png':       29,
    'Icon-App-29x29@2x.png':       58,
    'Icon-App-29x29@3x.png':       87,
    'Icon-App-40x40@1x.png':       40,
    'Icon-App-40x40@2x.png':       80,
    'Icon-App-40x40@3x.png':      120,
    'Icon-App-60x60@2x.png':      120,
    'Icon-App-60x60@3x.png':      180,
    'Icon-App-76x76@1x.png':       76,
    'Icon-App-76x76@2x.png':      152,
    'Icon-App-83.5x83.5@2x.png':  167,
    'Icon-App-1024x1024@1x.png': 1024,
}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    project = os.path.dirname(here)
    icons_dir = os.path.join(
        project,
        'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
    )
    assets_dir = os.path.join(project, 'assets')
    os.makedirs(assets_dir, exist_ok=True)

    # 1024 master — save a copy to assets/ for reference too
    master = render_logo(1024)
    master.save(os.path.join(assets_dir, 'logo.png'), 'PNG')
    print(f'wrote assets/logo.png (1024x1024)')

    for fname, sz in IOS_ICONS.items():
        img = master.resize((sz, sz), Image.LANCZOS) if sz != 1024 else master
        img.save(os.path.join(icons_dir, fname), 'PNG')
        print(f'wrote {fname} ({sz}x{sz})')


if __name__ == '__main__':
    main()
