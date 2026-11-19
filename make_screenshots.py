#!/usr/bin/env python3
"""Brainrot Bandits — screenshot renderer (fresh, PIL only).

Draws the game's arena from the same layout constants as the Luau
world: 220x220 grass arena, central asphalt lane x -95..95 at z 0
(width 14), six bases on radius 80, rebirth shrine, lucky stands,
richest board, TOKO stall, welcome board, arch, trees, mountains,
clouds, lamps and bunting. Characters are simple built-up figures
(body / head / eyes / type feature) with two-line nameplates:
name in rarity colour, then "$X/s - RARITY".

Four 1280x720 JPEGs, each <= 256 KiB, HUD kept clear of the
top-left corner (Roblox menu buttons live there).
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1280, 720
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
LIMIT = 262144  # 256 KiB

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size, bold=True):
    try:
        return ImageFont.truetype(BOLD if bold else REG, size)
    except Exception:
        return ImageFont.load_default()


# --- layout constants (same world as the Luau map) -------------------
ARENA = 110.0          # half-size of the 220x220 arena
LANE_X = 95.0          # lane runs x -95..95 at z 0
LANE_W = 14.0          # lane width in studs
BASE_R = 80.0
BASE_ANGLES = [30, 90, 150, 210, 270, 330]
SHRINE = (0, 34)
LUCKY_Z = (-36, -38)
RICHEST = (0, 56)
SHOP = (-19, 40)
WELCOME = (13, 44)

RARITY_COLOR = {
    "Common": (210, 220, 210),
    "Rare": (80, 170, 255),
    "Epic": (190, 110, 255),
    "Legendary": (255, 190, 40),
    "Mythic": (255, 90, 170),
}

# name, rarity, income $/s, body colour, accent colour
CHARS = [
    ("Cappuccino Golem", "Common", 8, (139, 90, 43), (245, 235, 210)),
    ("Banana Shark", "Common", 12, (255, 214, 0), (120, 120, 130)),
    ("Pickle Wizard", "Common", 15, (60, 180, 80), (150, 60, 200)),
    ("Toilet Titan", "Rare", 35, (235, 242, 250), (50, 130, 255)),
    ("Waffle Dragon", "Rare", 50, (255, 140, 0), (255, 210, 120)),
    ("Skibidi Samurai", "Epic", 90, (165, 25, 35), (40, 40, 45)),
    ("Glorbo Fruttodrillo", "Epic", 120, (40, 160, 70), (255, 140, 40)),
    ("Bombardiro Crocodilo", "Legendary", 250, (150, 155, 165), (70, 75, 85)),
    ("Tung Tung Sahur", "Legendary", 300, (120, 72, 32), (220, 180, 120)),
    ("Ballerina Cappuccina", "Mythic", 600, (255, 150, 200), (255, 255, 255)),
]

BASE_OWNERS = ["Dhanzz", "Tiara", "Cruz", "Baw", "Glorbo", "Sahur"]


def project(x, z):
    """World (x, z) studs -> screen (sx, sy). z=-110 far (north), +110 near."""
    t = (z + ARENA) / (2 * ARENA)          # 0 far .. 1 near
    sy = 225 + t * 465
    scale = 0.55 + 0.80 * t
    sx = 640 + x * scale * 3.35
    return sx, sy, scale


def rrect(d, box, rad, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=rad, fill=fill, outline=outline, width=width)


def text_c(d, cx, y, s, f, fill, stroke=0, stroke_fill=(0, 0, 0)):
    w = d.textlength(s, font=f)
    if stroke:
        d.text((cx - w / 2, y), s, font=f, fill=fill,
               stroke_width=stroke, stroke_fill=stroke_fill)
    else:
        d.text((cx - w / 2, y), s, font=f, fill=fill)


# --- sky / ground ------------------------------------------------------
def draw_sky(d, img, pink=False):
    top = (255, 170, 210) if pink else (90, 170, 255)
    mid = (255, 210, 225) if pink else (170, 215, 255)
    for y in range(0, 240):
        k = y / 240.0
        c = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)
    # sun
    d.ellipse([1120, 28, 1195, 103], fill=(255, 240, 150), outline=(255, 210, 80), width=4)
    d.ellipse([1138, 46, 1177, 85], fill=(255, 250, 200))
    # rainbow arcs (event lighting, stronger on the cover)
    if pink:
        cx, cy, r0 = 640, 260, 260
        for i, col in enumerate([(255, 0, 80), (255, 140, 0), (255, 235, 0),
                                 (0, 200, 90), (0, 140, 255), (170, 60, 255)]):
            r = r0 - i * 13
            d.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=col, width=13)
    # clouds
    for (cx, cy, s) in [(180, 70, 1.0), (420, 110, 0.7), (880, 60, 0.9),
                        (1050, 130, 0.6), (640, 55, 0.8)]:
        for (ox, oy, r) in [(-38, 6, 22), (0, -6, 28), (38, 6, 22), (0, 12, 24)]:
            d.ellipse([cx + ox * s - r * s, cy + oy * s - r * s,
                       cx + ox * s + r * s, cy + oy * s + r * s],
                      fill=(255, 255, 255, 235))
    # mountains on the horizon
    for (mx, mh, mw, col) in [(60, 95, 260, (110, 130, 180)),
                              (300, 130, 320, (90, 115, 165)),
                              (620, 105, 300, (120, 140, 190)),
                              (900, 140, 340, (95, 118, 168)),
                              (1150, 100, 280, (115, 135, 185))]:
        d.polygon([(mx - mw / 2, 235), (mx, 235 - mh), (mx + mw / 2, 235)], fill=col)
        d.polygon([(mx - 26, 235 - mh + 34), (mx, 235 - mh), (mx + 26, 235 - mh + 34)],
                  fill=(245, 248, 255))
    # arena grass (perspective trapezoid)
    pts = [project(-ARENA, -ARENA)[:2], project(ARENA, -ARENA)[:2],
           project(ARENA, ARENA)[:2], project(-ARENA, ARENA)[:2]]
    d.polygon(pts, fill=(96, 200, 80))
    # mow stripes
    for i in range(6):
        z0 = -ARENA + i * (2 * ARENA / 6)
        z1 = z0 + (2 * ARENA / 12)
        p = [project(-ARENA, z0)[:2], project(ARENA, z0)[:2],
             project(ARENA, z1)[:2], project(-ARENA, z1)[:2]]
        d.polygon(p, fill=(110, 210, 92))
    d.polygon(pts, outline=(70, 160, 60), width=4)


def draw_tree(d, x, z, s=1.0):
    sx, sy, sc = project(x, z)
    h = 78 * sc * s
    d.rectangle([sx - 5 * sc, sy - h * 0.35, sx + 5 * sc, sy], fill=(120, 72, 32))
    d.ellipse([sx - 30 * sc * s, sy - h - 18 * sc, sx + 30 * sc * s, sy - h * 0.35 + 22 * sc],
              fill=(30, 140, 60))
    d.ellipse([sx - 20 * sc * s, sy - h - 34 * sc, sx + 20 * sc * s, sy - h + 6 * sc],
              fill=(45, 175, 75))


def draw_lamp(d, x, z):
    sx, sy, sc = project(x, z)
    d.rectangle([sx - 3, sy - 62 * sc, sx + 3, sy], fill=(60, 60, 70))
    d.ellipse([sx - 12 * sc, sy - 78 * sc, sx + 12 * sc, sy - 54 * sc],
              fill=(255, 240, 150), outline=(220, 180, 60), width=2)
    d.ellipse([sx - 26 * sc, sy - 70 * sc, sx + 26 * sc, sy - 62 * sc],
              fill=(255, 240, 150, 70))


def draw_bunting(d):
    # strings of coloured flags across the top of the arena
    for y0, sag in [(205, 34), (222, 30)]:
        cols = [(255, 60, 90), (255, 190, 0), (60, 200, 90),
                (60, 140, 255), (190, 90, 255)]
        pts = [(40 + i * 30, y0 + sag * math.sin(math.pi * i / 40)) for i in range(41)]
        d.line(pts, fill=(40, 40, 50), width=2)
        for i in range(0, 41, 2):
            px, py = pts[i]
            c = cols[(i // 2) % len(cols)]
            d.polygon([(px - 9, py), (px + 9, py), (px, py + 20)], fill=c)


# --- lane / arch / props -------------------------------------------------
def draw_lane(d):
    hw = LANE_W / 2
    corners = [project(-LANE_X, -hw)[:2], project(LANE_X, -hw)[:2],
               project(LANE_X, hw)[:2], project(-LANE_X, hw)[:2]]
    d.polygon(corners, fill=(52, 52, 60))
    # glowing edges
    d.line([project(-LANE_X, -hw)[:2], project(LANE_X, -hw)[:2]], fill=(0, 230, 255), width=5)
    d.line([project(-LANE_X, hw)[:2], project(LANE_X, hw)[:2]], fill=(0, 230, 255), width=5)
    d.line([project(-LANE_X, -hw)[:2], project(LANE_X, -hw)[:2]], fill=(180, 250, 255), width=2)
    d.line([project(-LANE_X, hw)[:2], project(LANE_X, hw)[:2]], fill=(180, 250, 255), width=2)
    # yellow chevrons marching along the centre
    for x in range(-88, 90, 16):
        cx, cy, sc = project(x, 0)
        s = 13 * sc
        d.polygon([(cx - s, cy - s * 0.7), (cx, cy), (cx - s, cy + s * 0.7),
                   (cx - s * 0.4, cy), (cx, cy - s * 0.25), (cx, cy + s * 0.25)],
                  fill=(255, 210, 0))
        # simpler chevron overlay
        d.polygon([(cx - s, cy - s * 0.7), (cx + s * 0.5, cy), (cx - s, cy + s * 0.7),
                   (cx - s * 0.55, cy)], fill=(255, 210, 0))


def draw_arch(d):
    # big spawn arch over the lane at x = -95 (west end), drawn in screen space
    cx, base = 250, 560
    d.arc([cx - 190, base - 330, cx + 190, base + 40], 180, 360,
          fill=(255, 90, 160), width=26)
    d.arc([cx - 190, base - 330, cx + 190, base + 40], 180, 360,
          fill=(255, 200, 40), width=8)
    for bx in (cx - 190, cx + 190):
        d.rectangle([bx - 16, base - 30, bx + 16, base + 30], fill=(200, 60, 120))
        d.rectangle([bx - 22, base + 18, bx + 22, base + 34], fill=(120, 40, 90))
    # glowing portal inside the arch
    d.ellipse([cx - 110, base - 210, cx + 110, base + 10], fill=(120, 80, 255))
    d.ellipse([cx - 88, base - 185, cx + 88, base - 5], fill=(190, 140, 255))
    d.ellipse([cx - 60, base - 150, cx + 60, base - 20], fill=(240, 220, 255))
    text_c(d, cx, base - 348, "BRAINROT BANDITS", font(34), (255, 255, 255), 3)
    text_c(d, cx, base - 348, "BRAINROT BANDITS", font(34), (255, 210, 40), 0)


def draw_portal(d, x, z, label="SPAWN"):
    sx, sy, sc = project(x, z)
    d.ellipse([sx - 46 * sc, sy - 96 * sc, sx + 46 * sc, sy], fill=(120, 80, 255),
              outline=(255, 210, 40), width=4)
    d.ellipse([sx - 32 * sc, sy - 78 * sc, sx + 32 * sc, sy - 8 * sc], fill=(190, 140, 255))
    text_c(d, sx, sy - 118 * sc, label, font(max(12, int(15 * sc))), (255, 255, 255), 2)


def draw_base(d, x, z, owner, filled, highlight=False):
    sx, sy, sc = project(x, z)
    r = 78 * sc
    col = (255, 215, 90) if highlight else (235, 225, 200)
    d.ellipse([sx - r, sy - r * 0.42, sx + r, sy + r * 0.42], fill=(240, 230, 205),
              outline=col, width=5)
    d.ellipse([sx - r * 0.82, sy - r * 0.34, sx + r * 0.82, sy + r * 0.34],
              fill=(250, 245, 225))
    # delivery zone (front strip)
    d.ellipse([sx - r * 0.55, sy + r * 0.18, sx + r * 0.55, sy + r * 0.40],
              fill=(60, 200, 120), outline=(255, 255, 255), width=2)
    text_c(d, sx, sy + r * 0.24, "DELIVER", font(max(10, int(12 * sc))), (255, 255, 255), 2)
    # six pads in two rows of three
    idx = 0
    for row in (0, 1):
        for c in (-1, 0, 1):
            px = sx + c * r * 0.5
            py = sy - r * 0.16 + row * r * 0.24
            pr = 15 * sc
            d.ellipse([px - pr, py - pr * 0.5, px + pr, py + pr * 0.5],
                      fill=(200, 210, 230), outline=(120, 130, 150), width=2)
            if idx < len(filled):
                ch = filled[idx]
                draw_character(d, px, py + pr * 0.4, 0.30 * sc + 0.10, ch, mini=True)
            idx += 1
    # owner sign on a post
    d.rectangle([sx - 3, sy - r * 0.42 - 52 * sc, sx + 3, sy - r * 0.42], fill=(90, 60, 30))
    bw = 118 * sc + 30
    rrect(d, [sx - bw / 2, sy - r * 0.42 - 56 * sc, sx + bw / 2, sy - r * 0.42 - 20 * sc],
          8, fill=(60, 45, 90), outline=(255, 210, 40), width=3)
    text_c(d, sx, sy - r * 0.42 - 54 * sc, owner.upper() + "'S BASE",
           font(max(11, int(14 * sc))), (255, 215, 90), 2)
    # avatar marker above the base
    ax, ay = sx, sy - r * 0.42 - 92 * sc
    d.ellipse([ax - 14 * sc, ay - 26 * sc, ax + 14 * sc, ay + 2 * sc], fill=(255, 220, 150),
              outline=(180, 120, 40), width=2)
    d.ellipse([ax - 9 * sc, ay - 20 * sc, ax - 2 * sc, ay - 13 * sc], fill=(30, 30, 30))
    d.ellipse([ax + 2 * sc, ay - 20 * sc, ax + 9 * sc, ay - 13 * sc], fill=(30, 30, 30))
    d.polygon([(ax - 12, ay + 2), (ax + 12, ay + 2), (ax, ay + 16)], fill=(255, 80, 80))


def draw_shrine(d):
    sx, sy, sc = project(*SHRINE)
    d.ellipse([sx - 52 * sc, sy - 12 * sc, sx + 52 * sc, sy + 12 * sc],
              fill=(220, 200, 255), outline=(150, 90, 255), width=4)
    d.rectangle([sx - 26 * sc, sy - 88 * sc, sx + 26 * sc, sy - 8 * sc],
                fill=(170, 120, 255), outline=(120, 70, 220), width=3)
    d.polygon([(sx - 34 * sc, sy - 88 * sc), (sx, sy - 122 * sc), (sx + 34 * sc, sy - 88 * sc)],
              fill=(255, 210, 40), outline=(220, 160, 0), width=2)
    text_c(d, sx, sy - 78 * sc, "REBIRTH", font(max(11, int(14 * sc))), (255, 255, 255), 2)
    text_c(d, sx, sy - 56 * sc, "x2", font(max(12, int(16 * sc))), (255, 230, 60), 2)


def draw_lucky(d):
    for i, x in enumerate((-32, 0, 32)):
        sx, sy, sc = project(x, LUCKY_Z[0] if i != 1 else LUCKY_Z[1])
        s = 34 * sc
        d.rectangle([sx - s, sy - s * 1.5, sx + s, sy], fill=(255, 190, 40),
                    outline=(200, 130, 0), width=3)
        d.rectangle([sx - s, sy - s * 1.5, sx + s, sy - s * 0.9], fill=(255, 220, 90))
        text_c(d, sx, sy - s * 1.35, "?", font(int(26 * sc)), (160, 80, 0), 2)
        text_c(d, sx, sy + 4, "LUCKY", font(max(10, int(12 * sc))), (90, 50, 0), 1)


def draw_board(d, x, z, lines, wscale=1.0):
    sx, sy, sc = project(x, z)
    w = 150 * sc * wscale
    h = 62 * sc
    d.rectangle([sx - 4, sy - h - 40 * sc, sx + 4, sy], fill=(90, 60, 30))
    rrect(d, [sx - w / 2, sy - h - 44 * sc, sx + w / 2, sy - 44 * sc], 8,
          fill=(70, 50, 100), outline=(255, 210, 40), width=3)
    for i, (txt, col, size) in enumerate(lines):
        text_c(d, sx, sy - h - 42 * sc + i * (size + 6), txt, font(size), col, 2)


def draw_shop(d):
    sx, sy, sc = project(*SHOP)
    d.rectangle([sx - 58 * sc, sy - 66 * sc, sx + 58 * sc, sy], fill=(255, 120, 90),
                outline=(180, 60, 40), width=3)
    d.polygon([(sx - 66 * sc, sy - 66 * sc), (sx + 66 * sc, sy - 66 * sc),
               (sx + 48 * sc, sy - 92 * sc), (sx - 48 * sc, sy - 92 * sc)],
              fill=(255, 80, 80), outline=(255, 255, 255), width=2)
    text_c(d, sx, sy - 58 * sc, "TOKO", font(max(13, int(18 * sc))), (255, 255, 255), 2)
    text_c(d, sx, sy - 30 * sc, "SHOP", font(max(10, int(13 * sc))), (255, 240, 150), 1)
    text_c(d, sx, sy - 10 * sc, "Slap - Lock - Speed", font(max(9, int(11 * sc))),
           (255, 255, 255), 1)


# --- characters ----------------------------------------------------------
def draw_character(d, cx, feet_y, s, ch, mutation=None, mini=False):
    name, rarity, income, body, accent = ch
    if mutation == "Gold":
        body = (255, 200, 40)
        accent = (255, 240, 150)
    elif mutation == "Diamond":
        body = (140, 220, 255)
        accent = (255, 255, 255)
    h = 92 * s
    w = 58 * s
    x0, x1 = cx - w / 2, cx + w / 2
    y_top = feet_y - h
    # shadow
    d.ellipse([cx - w * 0.62, feet_y - 4, cx + w * 0.62, feet_y + 6], fill=(0, 0, 0, 60))
    key = name
    if "Shark" in key:
        d.ellipse([x0, y_top + h * 0.25, x1, feet_y], fill=body)          # banana body
        d.polygon([(cx - 8 * s, y_top + h * 0.15), (cx + 8 * s, y_top + h * 0.15),
                   (cx, y_top - 12 * s)], fill=accent)                    # fin
        d.ellipse([x0 + 4 * s, y_top + h * 0.30, x1 - 4 * s, y_top + h * 0.62], fill=(255, 255, 255))
    elif "Crocodilo" in key or "Bombardiro" in key:
        d.ellipse([x0 - 6 * s, y_top + h * 0.30, x1 + 6 * s, feet_y - 6 * s], fill=body)
        d.polygon([(x0 - 22 * s, y_top + h * 0.45), (x0, y_top + h * 0.30),
                   (x0, y_top + h * 0.62)], fill=accent)                  # wing
        d.polygon([(x1 + 22 * s, y_top + h * 0.45), (x1, y_top + h * 0.30),
                   (x1, y_top + h * 0.62)], fill=accent)
        d.ellipse([x0 + 8 * s, y_top + h * 0.18, x1 - 8 * s, y_top + h * 0.42], fill=body)
    elif "Tung Tung" in key:
        d.rectangle([x0 + 6 * s, y_top + h * 0.15, x1 - 6 * s, feet_y], fill=body)
        d.ellipse([x0 + 6 * s, y_top + h * 0.05, x1 - 6 * s, y_top + h * 0.30], fill=(200, 160, 100))
        d.rectangle([cx - 26 * s, y_top - 6 * s, cx + 26 * s, y_top + h * 0.14], fill=(240, 220, 180),
                    outline=(160, 120, 70), width=2)                     # drum
    elif "Ballerina" in key:
        d.ellipse([cx - w * 0.75, feet_y - 26 * s, cx + w * 0.75, feet_y - 4 * s],
                  fill=(255, 170, 215))                                   # tutu
        d.ellipse([x0 + 6 * s, y_top + h * 0.30, x1 - 6 * s, feet_y - 18 * s], fill=body)
        d.ellipse([cx - 14 * s, y_top, cx + 14 * s, y_top + 30 * s], fill=accent)  # cup head
    elif "Toilet" in key:
        d.rectangle([x0 + 4 * s, y_top + h * 0.35, x1 - 4 * s, feet_y], fill=body,
                    outline=accent, width=3)
        d.rectangle([x0, y_top + h * 0.05, x1, y_top + h * 0.38], fill=accent)
        d.ellipse([x0 + 2 * s, y_top + h * 0.32, x1 - 2 * s, y_top + h * 0.52], fill=(210, 230, 245))
    elif "Wizard" in key:
        d.polygon([(cx - w * 0.55, y_top + h * 0.95), (cx + w * 0.55, y_top + h * 0.95),
                   (cx, y_top + h * 0.25)], fill=body)                    # robe
        d.polygon([(cx - 26 * s, y_top + h * 0.28), (cx + 26 * s, y_top + h * 0.28),
                   (cx, y_top - 22 * s)], fill=accent)                    # hat
    elif "Dragon" in key:
        d.ellipse([x0, y_top + h * 0.25, x1, feet_y], fill=body)
        d.polygon([(x0 - 18 * s, y_top + h * 0.30), (x0, y_top + h * 0.15),
                   (x0 + 4 * s, y_top + h * 0.55)], fill=(255, 220, 130))  # wing
        d.polygon([(x1 + 18 * s, y_top + h * 0.30), (x1, y_top + h * 0.15),
                   (x1 - 4 * s, y_top + h * 0.55)], fill=(255, 220, 130))
        for k in range(3):
            d.rectangle([x0 + 8 * s + k * 14 * s, y_top + h * 0.45,
                         x0 + 16 * s + k * 14 * s, y_top + h * 0.75], fill=(255, 220, 130))
    elif "Samurai" in key:
        d.rectangle([x0 + 4 * s, y_top + h * 0.28, x1 - 4 * s, feet_y], fill=body)
        d.rectangle([x0, y_top + h * 0.05, x1, y_top + h * 0.34], fill=accent)  # helmet
        d.line([x1 + 2 * s, y_top + h * 0.10, x1 + 26 * s, y_top + h * 0.90],
               fill=(230, 230, 240), width=4)                             # katana
    elif "Golem" in key:
        d.rectangle([x0 + 4 * s, y_top + h * 0.22, x1 - 4 * s, feet_y], fill=body)
        d.ellipse([x0 + 2 * s, y_top + h * 0.10, x1 - 2 * s, y_top + h * 0.38], fill=accent)
        d.ellipse([cx - 12 * s, y_top + h * 0.02, cx + 12 * s, y_top + h * 0.22], fill=(255, 250, 230))
    else:  # Glorbo Fruttodrillo — green croc, orange belly, watermelon back
        d.ellipse([x0, y_top + h * 0.30, x1, feet_y - 4 * s], fill=body)
        d.ellipse([x0 + 8 * s, y_top + h * 0.55, x1 - 8 * s, feet_y - 6 * s], fill=accent)
        d.ellipse([x0 + 6 * s, y_top + h * 0.12, x1 - 6 * s, y_top + h * 0.42], fill=body)
        d.rectangle([x0 + 10 * s, y_top + h * 0.18, x0 + 14 * s, y_top + h * 0.36], fill=(30, 110, 50))
        d.rectangle([x1 - 14 * s, y_top + h * 0.18, x1 - 10 * s, y_top + h * 0.36], fill=(30, 110, 50))
    # eyes (shared)
    ey = y_top + h * 0.30
    for ex in (cx - 11 * s, cx + 4 * s):
        d.ellipse([ex, ey, ex + 9 * s, ey + 12 * s], fill=(255, 255, 255))
        d.ellipse([ex + 2 * s, ey + 4 * s, ex + 7 * s, ey + 10 * s], fill=(20, 20, 20))
    # mutation sparkle
    if mutation:
        mc = (255, 215, 0) if mutation == "Gold" else (160, 230, 255)
        for (sx_, sy_) in [(x0 - 6, y_top + 8), (x1 + 4, y_top + h * 0.5), (cx + 16 * s, y_top - 6)]:
            d.polygon([(sx_, sy_ - 7), (sx_ + 3, sy_), (sx_, sy_ + 7), (sx_ - 3, sy_)], fill=mc)
        text_c(d, cx, y_top - 26, mutation.upper() + " x5" if mutation == "Gold" else "DIAMOND x12",
               font(13), mc, 2)
    if not mini:
        draw_nameplate(d, cx, y_top, ch, mutation)


def draw_nameplate(d, cx, y_top, ch, mutation=None):
    name, rarity, income, _b, _a = ch
    rc = RARITY_COLOR[rarity]
    if mutation == "Gold":
        rc = (255, 210, 40)
    elif mutation == "Diamond":
        rc = (150, 225, 255)
    f1, f2 = font(17), font(14)
    line2 = "$%s/s - %s%s" % (format(income, ","), rarity,
                             " - " + mutation.upper() if mutation else "")
    w = max(d.textlength(name, font=f1), d.textlength(line2, font=f2)) + 22
    top = y_top - 52
    rrect(d, [cx - w / 2, top, cx + w / 2, top + 48], 9, fill=(15, 15, 25, 220),
          outline=rc, width=2)
    text_c(d, cx, top + 3, name, f1, rc, 1)
    text_c(d, cx, top + 25, line2, f2, (255, 255, 255), 1)


# --- HUD -------------------------------------------------------------------
def draw_hud(d, cash, per_sec, rebirths, carrying=None):
    # top-right panel only — top-left stays clear for Roblox menu buttons
    x0, y0, x1 = 930, 12, 1268
    rrect(d, [x0, y0, x1, y0 + 96], 12, fill=(15, 15, 25, 215),
          outline=(255, 210, 40), width=2)
    text_c(d, (x0 + x1) / 2, y0 + 8, "$%s" % format(cash, ","), font(30),
           (120, 255, 130), 2)
    text_c(d, (x0 + x1) / 2, y0 + 44, "$%s/s  -  Rebirths: %d (x%d)" % (
        format(per_sec, ","), rebirths, rebirths + 1), font(16), (255, 255, 255), 1)
    text_c(d, (x0 + x1) / 2, y0 + 68, "BRAINROT BANDITS", font(13), (255, 210, 40), 1)
    if carrying:
        rrect(d, [x0, y0 + 106, x1, y0 + 140], 10, fill=(90, 40, 160, 225),
              outline=(255, 255, 255), width=2)
        text_c(d, (x0 + x1) / 2, y0 + 114, "Carrying: " + carrying, font(15),
               (255, 255, 255), 1)


def draw_banner(d, text, sub=""):
    rrect(d, [290, 18, 990, 92], 14, fill=(140, 20, 60, 230),
          outline=(255, 210, 40), width=3)
    text_c(d, 640, 26, text, font(30), (255, 255, 255), 3)
    if sub:
        text_c(d, 640, 60, sub, font(16), (255, 230, 120), 1)


def base_scene(pink=False):
    img = Image.new("RGB", (W, H), (90, 170, 255))
    d = ImageDraw.Draw(img, "RGBA")
    draw_sky(d, img, pink=pink)
    draw_lane(d)
    # trees + lamps around the rim
    for (tx, tz) in [(-100, -80), (-70, -95), (70, -95), (100, -80), (-105, 60),
                     (105, 60), (-100, -30), (100, -30), (-60, 95), (60, 95)]:
        draw_tree(d, tx, tz)
    for (lx, lz) in [(-88, -12), (88, -12), (-88, 12), (88, 12)]:
        draw_lamp(d, lx, lz)
    draw_bunting(d)
    return img, d


def sort_bases():
    pts = []
    for i, ang in enumerate(BASE_ANGLES):
        x = BASE_R * math.cos(math.radians(ang))
        z = BASE_R * math.sin(math.radians(ang))
        pts.append((project(x, z)[1], x, z, BASE_OWNERS[i]))
    return sorted(pts)


def save_jpeg(img, path):
    q = 92
    while True:
        img.save(path, "JPEG", quality=q, optimize=True)
        if os.path.getsize(path) <= LIMIT or q <= 30:
            break
        q -= 6
    return os.path.getsize(path)


def shot_cover():
    img, d = base_scene(pink=True)
    draw_arch(d)
    for _, x, z, owner in sort_bases():
        draw_base(d, x, z, owner, [], highlight=(owner == "Dhanzz"))
    draw_shrine(d)
    draw_lucky(d)
    draw_shop(d)
    draw_board(d, *RICHEST, [("RICHEST", (255, 210, 40), 18),
                             ("1. Dhanzz - $12,450", (255, 255, 255), 13)])
    draw_board(d, *WELCOME, [("WELCOME!", (255, 210, 40), 18),
                             ("Steal - Carry - Deliver", (255, 255, 255), 12)], wscale=1.15)
    # hero characters on the lane
    spots = [(-55, 0, CHARS[9], None), (-30, 2, CHARS[7], "Gold"),
             (-5, -2, CHARS[8], None), (22, 2, CHARS[5], "Diamond"),
             (48, 0, CHARS[6], None), (72, -1, CHARS[4], None)]
    for (x, z, ch, mut) in spots:
        sx, sy, sc = project(x, z)
        draw_character(d, sx, sy + 6, 0.95, ch, mutation=mut)
    draw_portal(d, -95, 0)
    draw_hud(d, 12450, 1180, 2, carrying="Tung Tung Sahur")
    return img


def shot_lane():
    img, d = base_scene(pink=False)
    draw_arch(d)
    for _, x, z, owner in sort_bases():
        draw_base(d, x, z, owner, [], highlight=False)
    draw_shrine(d)
    draw_lucky(d)
    draw_shop(d)
    draw_board(d, *RICHEST, [("RICHEST", (255, 210, 40), 18),
                             ("1. Dhanzz - $12,450", (255, 255, 255), 13)])
    # walking parade along the lane, west -> east
    parade = [(CHARS[0], None), (CHARS[1], None), (CHARS[2], "Gold"),
              (CHARS[3], None), (CHARS[4], None), (CHARS[5], "Diamond"),
              (CHARS[6], None), (CHARS[9], None)]
    for i, (ch, mut) in enumerate(parade):
        x = -82 + i * 21
        z = -3 if i % 2 == 0 else 3
        sx, sy, sc = project(x, z)
        draw_character(d, sx, sy + 6, 0.78, ch, mutation=mut)
    draw_portal(d, -95, 0)
    draw_hud(d, 3280, 342, 0, carrying=None)
    return img


def shot_base():
    img, d = base_scene(pink=False)
    # other bases small in the distance
    for _, x, z, owner in sort_bases():
        if owner != "Dhanzz":
            draw_base(d, x, z, owner, [], highlight=False)
    draw_lane(d)
    draw_shrine(d)
    draw_shop(d)
    # hero base: Dhanzz, front-centre, six pads filled
    hx, hz = BASE_R * math.cos(math.radians(270)), BASE_R * math.sin(math.radians(270))
    # 270 deg -> (0, -80) north; use the south base instead for a big close view
    hx, hz = 0.0, 80.0
    sx, sy, sc = project(hx, hz)
    # big close-up base drawn in screen space over the projected spot
    cx, cy = 640, 520
    r = 300
    d.ellipse([cx - r, cy - r * 0.38, cx + r, cy + r * 0.38], fill=(240, 230, 205),
              outline=(255, 215, 90), width=6)
    d.ellipse([cx - r * 0.85, cy - r * 0.30, cx + r * 0.85, cy + r * 0.30], fill=(250, 245, 225))
    d.ellipse([cx - r * 0.55, cy + r * 0.16, cx + r * 0.55, cy + r * 0.34],
              fill=(60, 200, 120), outline=(255, 255, 255), width=3)
    text_c(d, cx, cy + r * 0.22, "DELIVER ZONE", font(18), (255, 255, 255), 2)
    filled = [CHARS[9], CHARS[7], CHARS[8], CHARS[5], CHARS[6], CHARS[4]]
    for i, ch in enumerate(filled):
        px = cx - 190 + (i % 3) * 190
        py = cy - 70 + (i // 3) * 110
        d.ellipse([px - 62, py - 26, px + 62, py + 26], fill=(200, 210, 230),
                  outline=(120, 130, 150), width=3)
        draw_character(d, px, py + 22, 0.62, ch, mini=False)
    # owner sign + avatar marker, large
    d.rectangle([cx - 4, cy - r * 0.38 - 108, cx + 4, cy - r * 0.38], fill=(90, 60, 30))
    rrect(d, [cx - 150, cy - r * 0.38 - 112, cx + 150, cy - r * 0.38 - 62], 10,
          fill=(60, 45, 90), outline=(255, 210, 40), width=4)
    text_c(d, cx, cy - r * 0.38 - 104, "DHANZZ'S BASE", font(24), (255, 215, 90), 2)
    ax, ay = cx, cy - r * 0.38 - 150
    d.ellipse([ax - 26, ay - 48, ax + 26, ay + 4], fill=(255, 220, 150),
              outline=(180, 120, 40), width=3)
    d.ellipse([ax - 16, ay - 36, ax - 4, ay - 24], fill=(30, 30, 30))
    d.ellipse([ax + 4, ay - 36, ax + 16, ay - 24], fill=(30, 30, 30))
    d.polygon([(ax - 22, ay + 4), (ax + 22, ay + 4), (ax, ay + 30)], fill=(255, 80, 80))
    text_c(d, cx, 150, "YOUR BASE — 6 BRAINROTS EARNING", font(22), (255, 255, 255), 3)
    draw_hud(d, 12450, 1180, 2, carrying=None)
    return img


def shot_events():
    img, d = base_scene(pink=True)
    draw_banner(d, "BOSS RAID — BRAINROT KING!", "Defeat him before he smashes the bases!")
    draw_arch(d)
    for _, x, z, owner in sort_bases():
        draw_base(d, x, z, owner, [], highlight=False)
    draw_lucky(d)
    draw_shrine(d)
    draw_shop(d)
    # lucky blocks front row
    for (lx, lz) in [(-45, -28), (-15, -30), (15, -28), (45, -30)]:
        sx, sy, sc = project(lx, lz)
        s = 30 * sc
        d.rectangle([sx - s, sy - s * 1.6, sx + s, sy], fill=(255, 190, 40),
                    outline=(200, 130, 0), width=3)
        text_c(d, sx, sy - s * 1.45, "?", font(int(24 * sc)), (160, 80, 0), 2)
    # giant boss centre-lane
    bx, by = 640, 470
    d.ellipse([bx - 150, by - 10, bx + 150, by + 14], fill=(0, 0, 0, 70))
    d.ellipse([bx - 120, by - 260, bx + 120, by - 10], fill=(90, 30, 120))
    d.ellipse([bx - 90, by - 300, bx + 90, by - 180], fill=(120, 50, 160))
    d.polygon([(bx - 80, by - 290), (bx - 40, by - 340), (bx - 10, by - 285)], fill=(255, 210, 40))
    d.polygon([(bx + 80, by - 290), (bx + 40, by - 340), (bx + 10, by - 285)], fill=(255, 210, 40))
    for ex in (bx - 55, bx + 25):
        d.ellipse([ex, by - 260, ex + 30, by - 228], fill=(255, 255, 255))
        d.ellipse([ex + 7, by - 252, ex + 23, by - 236], fill=(255, 0, 0))
    d.rectangle([bx - 45, by - 210, bx + 45, by - 185], fill=(40, 10, 60))
    for k in range(5):
        d.polygon([(bx - 40 + k * 18, by - 210), (bx - 31 + k * 18, by - 185),
                   (bx - 22 + k * 18, by - 210)], fill=(255, 255, 255))
    # boss health bar
    rrect(d, [bx - 170, by - 380, bx + 170, by - 352], 10, fill=(20, 20, 30),
          outline=(255, 255, 255), width=2)
    rrect(d, [bx - 166, by - 376, bx + 60, by - 356], 8, fill=(255, 40, 60))
    text_c(d, bx, by - 378, "BRAINROT KING  HP  68%", font(16), (255, 255, 255), 2)
    # small defenders on the lane
    for (x, z, ch) in [(-70, 4, CHARS[5]), (-45, -3, CHARS[3]), (70, 3, CHARS[1])]:
        sx, sy, sc = project(x, z)
        draw_character(d, sx, sy + 6, 0.62, ch)
    draw_hud(d, 9800, 940, 1, carrying="Ballerina Cappuccina")
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    shots = [("1-cover.jpg", shot_cover), ("2-lane.jpg", shot_lane),
             ("3-base.jpg", shot_base), ("4-events.jpg", shot_events)]
    for name, fn in shots:
        img = fn()
        path = os.path.join(OUT, name)
        size = save_jpeg(img, path)
        print("%s %dx%d %d bytes" % (name, img.width, img.height, size))


if __name__ == "__main__":
    main()
