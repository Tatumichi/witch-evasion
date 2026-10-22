#!/usr/bin/env python3
"""タイトル画面用のロゴと立ち絵カードを生成する。

    python tools/make_ui_art.py

出力:
    godot/assets/ui/logo.png         "WITCH" / "EVASION" の 2 段組みロゴ
    godot/assets/ui/title_witch.png  立ち絵カード（角丸・発光枠・夜空の背景付き）

立ち絵は art/witch/witch_chibi_s111.png（承認済みデザイン）の白背景を抜いて使う。
残る足元の影はカード内の「床の影」として活かす。
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from prepare_sprite import build_alpha, remove_white_background

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "art", "witch", "witch_chibi_s111.png")
OUT_DIR = os.path.join(ROOT, "godot", "assets", "ui")

FONT_BLACK = r"C:\Windows\Fonts\seguibl.ttf"

INK = (26, 11, 42, 255)
GLOW = (192, 96, 255)
TOP = (246, 236, 255)
MID = (228, 169, 255)
BOTTOM = (176, 108, 232)


# --------------------------------------------------------------------------- logo

def draw_tracked(draw: ImageDraw.ImageDraw, xy, text, font, spacing, fill) -> int:
    """文字間隔を空けて描く。合計幅を返す。"""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + spacing
    return x - spacing - xy[0]


def tracked_width(text: str, font, spacing: float) -> float:
    return sum(font.getlength(ch) for ch in text) + spacing * (len(text) - 1)


def star(draw: ImageDraw.ImageDraw, center, radius: float, fill) -> None:
    """4 方向に尖った星。"""
    cx, cy = center
    points = []
    for i in range(8):
        angle = math.pi * i / 4.0
        r = radius if i % 2 == 0 else radius * 0.26
        points.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    draw.polygon(points, fill=fill)


def odd(n: int) -> int:
    return n if n % 2 == 1 else n + 1


def make_logo(path: str, scale: int = 2) -> None:
    width, height = 780, 400
    canvas = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))

    big = ImageFont.truetype(FONT_BLACK, 150 * scale)
    small = ImageFont.truetype(FONT_BLACK, 84 * scale)
    space_small = 20 * scale

    mask = Image.new("L", canvas.size, 0)
    md = ImageDraw.Draw(mask)

    w_big = tracked_width("WITCH", big, 6 * scale)
    draw_tracked(md, ((width * scale - w_big) / 2, 8 * scale), "WITCH", big, 6 * scale, 255)

    w_small = tracked_width("EVASION", small, space_small)
    draw_tracked(md, ((width * scale - w_small) / 2, 238 * scale), "EVASION", small, space_small, 255)

    # グラデーション（上=白 / 中=ピンク / 下=紫）
    gradient = Image.new("RGBA", canvas.size)
    gd = ImageDraw.Draw(gradient)
    for y in range(canvas.size[1]):
        t = y / canvas.size[1]
        if t < 0.45:
            k = t / 0.45
            color = tuple(int(TOP[i] + (MID[i] - TOP[i]) * k) for i in range(3))
        else:
            k = (t - 0.45) / 0.55
            color = tuple(int(MID[i] + (BOTTOM[i] - MID[i]) * k) for i in range(3))
        gd.line([(0, y), (canvas.size[0], y)], fill=color + (255,))

    # 外側グロー（広い紫 + 近いピンク）
    for spread, blur, color, alpha in (
        (13, 24, (150, 72, 240), 0.40),
        (7, 8, (255, 118, 226), 0.45),
    ):
        halo_mask = mask.filter(ImageFilter.MaxFilter(odd(spread * scale))).filter(
            ImageFilter.GaussianBlur(blur * scale)
        )
        halo = Image.new("RGBA", canvas.size, color + (0,))
        halo.putalpha(halo_mask.point(lambda v: int(v * alpha)))
        canvas.alpha_composite(halo)

    # 縁取り
    outline_mask = mask.filter(ImageFilter.MaxFilter(odd(9 * scale))).filter(ImageFilter.GaussianBlur(1.5 * scale))
    outline = Image.new("RGBA", canvas.size, INK[:3] + (0,))
    outline.putalpha(outline_mask)
    canvas.alpha_composite(outline)

    # 本体
    canvas.paste(gradient, (0, 0), mask)

    # 仕切り線と星
    d = ImageDraw.Draw(canvas)
    line_y = 207 * scale
    half = 232 * scale
    gap = 30 * scale
    cx = width * scale / 2
    for x0, x1 in ((cx - half, cx - gap), (cx + gap, cx + half)):
        d.line([(x0, line_y), (x1, line_y)], fill=(214, 190, 255, 200), width=3 * scale)
    star(d, (cx, line_y), 15 * scale, (255, 240, 255, 245))
    star(d, (cx - 292 * scale, 52 * scale), 9 * scale, (255, 236, 255, 200))
    star(d, (cx + 296 * scale, 330 * scale), 7 * scale, (255, 216, 250, 180))

    logo = canvas.resize((width, height), Image.LANCZOS)
    logo.save(path)
    print(f"[ui] logo  -> {path} ({logo.size[0]}x{logo.size[1]})")


# ---------------------------------------------------------------------- portrait

def rounded_mask(size, radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def make_card(path: str, width: int = 420, height: int = 500) -> None:
    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    bg = Image.new("RGBA", (width, height))
    bd = ImageDraw.Draw(bg)
    for y in range(height):
        t = y / height
        color = (int(38 + 26 * t), int(22 + 20 * t), int(74 + 32 * t))
        bd.line([(0, y), (width, y)], fill=color + (255,))

    # 奥の光
    halo = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse(
        [width * 0.5 - 165, height * 0.28 - 165, width * 0.5 + 165, height * 0.28 + 165],
        fill=(142, 91, 217, 95),
    )
    bg.alpha_composite(halo.filter(ImageFilter.GaussianBlur(45)))

    # 星
    rng = random.Random(7)
    stars = ImageDraw.Draw(bg)
    for _ in range(38):
        x = rng.uniform(12, width - 12)
        y = rng.uniform(12, height * 0.72)
        r = rng.uniform(0.7, 2.1)
        stars.ellipse([x, y, x + r, y + r], fill=(235, 220, 255, rng.randint(45, 140)))

    # 床の照り返し
    floor = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(floor).ellipse(
        [width * 0.5 - 150, height - 130, width * 0.5 + 150, height - 20],
        fill=(104, 68, 168, 110),
    )
    bg.alpha_composite(floor.filter(ImageFilter.GaussianBlur(26)))

    # キャラクター
    source = Image.open(SOURCE).convert("RGBA")
    alpha = build_alpha(remove_white_background(source, 40), 1, 1.0)
    source.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    witch = source.crop(bbox)

    target_h = height - 58
    scale = target_h / witch.height
    witch = witch.resize((max(1, round(witch.width * scale)), target_h), Image.LANCZOS)
    bg.alpha_composite(witch, ((width - witch.width) // 2, height - witch.height - 26))

    card.paste(bg, (0, 0), rounded_mask((width, height), 34))

    # 発光する枠
    frame_mask = rounded_mask((width, height), 34)
    ring = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.rounded_rectangle([1, 1, width - 2, height - 2], radius=33, outline=(236, 198, 255, 235), width=3)
    card.alpha_composite(ring)
    glow = ring.filter(ImageFilter.GaussianBlur(9))
    glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.75)))
    card.alpha_composite(glow)
    del frame_mask

    card.save(path)
    print(f"[ui] card  -> {path} ({width}x{height})")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    make_logo(os.path.join(OUT_DIR, "logo.png"))
    make_card(os.path.join(OUT_DIR, "title_witch.png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
