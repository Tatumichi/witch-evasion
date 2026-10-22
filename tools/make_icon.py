#!/usr/bin/env python3
"""ゲーム用アイコン（PNG / ICO）をドット絵調で生成する。

    python tools/make_icon.py

入力: art/witch/witch_icon_s414.png（魔女のバストアップ）
出力: godot/icon.png  (256x256 / Godot の config/icon)
      godot/icon.ico  (16〜256 のマルチサイズ / Windows の exe アイコン)

手順:
  1. 白背景を抜いてバッジ（角丸・紫グラデ）に配置
  2. 64px へ縮小して 32 色に減色（ディザ無し）
  3. NEAREST で 256px へ拡大してドット絵の粒を固定
  4. 角丸マスクを適用し、各サイズを ICO に詰める
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

from prepare_sprite import build_alpha, remove_white_background

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "art", "witch", "witch_icon_s414.png")
OUT_PNG = os.path.join(ROOT, "godot", "icon.png")
OUT_ICO = os.path.join(ROOT, "godot", "icon.ico")

MASTER = 64
FINAL = 256
PALETTE = 32


def badge(size: int) -> Image.Image:
    """紫グラデーション＋内側の光の土台。"""
    bg = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(bg)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=(int(58 - 22 * t), int(28 - 14 * t), int(92 - 26 * t)))

    halo = Image.new("RGB", (size, size), (0, 0, 0))
    ImageDraw.Draw(halo).ellipse(
        [size * 0.5 - size * 0.42, size * 0.24 - size * 0.42, size * 0.5 + size * 0.42, size * 0.24 + size * 0.42],
        fill=(96, 54, 150),
    )
    bg = Image.blend(bg, halo, 0.55)
    return bg


def compose(size: int = FINAL) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    alpha = build_alpha(remove_white_background(source, 40), 1, 1.0)
    source.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    witch = source.crop(bbox)

    target = int(size * 0.92)
    scale = target / witch.height
    witch = witch.resize((max(1, round(witch.width * scale)), target), Image.LANCZOS)

    canvas = badge(size).convert("RGBA")
    canvas.alpha_composite(witch, ((size - witch.width) // 2, size - witch.height))

    # 内側のリム
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        [2, 2, size - 3, size - 3], radius=size // 8, outline=(231, 198, 255, 90), width=max(2, size // 64)
    )
    canvas.alpha_composite(rim.filter(ImageFilter.GaussianBlur(size / 256)))
    return canvas


def pixelate(image: Image.Image) -> Image.Image:
    small = image.convert("RGB").resize((MASTER, MASTER), Image.LANCZOS)
    small = small.quantize(colors=PALETTE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    small = small.convert("RGB").resize((FINAL, FINAL), Image.NEAREST)
    return small


def rounded_alpha(image: Image.Image, radius_ratio: float = 0.16) -> Image.Image:
    mask_small = Image.new("L", (MASTER, MASTER), 0)
    ImageDraw.Draw(mask_small).rounded_rectangle(
        [0, 0, MASTER - 1, MASTER - 1], radius=round(MASTER * radius_ratio), fill=255
    )
    mask = mask_small.resize((FINAL, FINAL), Image.NEAREST)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> int:
    icon = rounded_alpha(pixelate(compose()))
    icon.save(OUT_PNG)
    icon.save(
        OUT_ICO,
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"[icon] {OUT_PNG} {icon.size}")
    print(f"[icon] {OUT_ICO} sizes 16-256")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
