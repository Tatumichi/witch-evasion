#!/usr/bin/env python3
"""ComfyUI の白背景レンダーを、ゲームでそのまま使えるスプライト PNG に変換する。

やること:
  1. 四辺からフラッドフィルして白背景を透過（内部の白は残す）
  2. 1px 収縮 + ぼかしで白フチを落とす
  3. アルファのバウンディングボックスで切り詰め
  4. 指定サイズへ縮小して、指定キャンバスの指定原点に焼き込む

ゲーム側は Sprite2D の offset/position だけで済み、実行時の拡縮が発生しない。

例:
    python tools/prepare_sprite.py godot/assets/characters/witch/witch_fly2_s1212.png \
        -o godot/assets/characters/witch/witch_sprite.png
"""

from __future__ import annotations

import argparse

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

FILL = (255, 0, 255)


def remove_white_background(img: Image.Image, thresh: int) -> np.ndarray:
    rgb = img.convert("RGB")
    width, height = rgb.size
    draw = ImageDraw.Draw(rgb)
    seeds = {(x, y) for x in range(0, width, 24) for y in (0, height - 1)}
    seeds |= {(x, y) for y in range(0, height, 24) for x in (0, width - 1)}
    for seed in seeds:
        if rgb.getpixel(seed) != FILL:
            ImageDraw.floodfill(rgb, seed, FILL, thresh=thresh)
    filled = np.asarray(rgb)
    background = np.all(filled == np.array(FILL, dtype=np.uint8), axis=-1)
    return ~background


def build_alpha(foreground: np.ndarray, erode: int, feather: float) -> Image.Image:
    alpha = Image.fromarray((foreground * 255).astype(np.uint8), "L")
    if erode > 0:
        alpha = alpha.filter(ImageFilter.MinFilter(erode * 2 + 1))
    if feather > 0:
        alpha = alpha.filter(ImageFilter.GaussianBlur(feather))
    return alpha


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("input")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--thresh", type=int, default=40, help="背景とみなす色差")
    parser.add_argument("--erode", type=int, default=2, help="白フチ除去の収縮 px")
    parser.add_argument("--feather", type=float, default=1.2)
    parser.add_argument("--fit", default="150x120", help="キャラクターの最大表示サイズ")
    parser.add_argument("--canvas", default="180x130", help="出力キャンバス")
    parser.add_argument("--origin", default="105,95", help="ゲーム座標(0,0)に対応するキャンバス上の画素")
    parser.add_argument("--center", default="-16,-32", help="スプライト中心を置くゲーム座標")
    args = parser.parse_args(argv)

    fit_w, fit_h = (int(v) for v in args.fit.split("x"))
    canvas_w, canvas_h = (int(v) for v in args.canvas.split("x"))
    origin_x, origin_y = (int(v) for v in args.origin.split(","))
    center_x, center_y = (int(v) for v in args.center.split(","))

    source = Image.open(args.input).convert("RGBA")
    foreground = remove_white_background(source, args.thresh)
    alpha = build_alpha(foreground, args.erode, args.feather)

    rgba = source.copy()
    rgba.putalpha(alpha)

    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        raise SystemExit("[sprite] 前景が見つかりません。--thresh を調整してください。")
    sprite = rgba.crop(bbox)

    scale = min(fit_w / sprite.width, fit_h / sprite.height)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    sprite = sprite.resize(size, Image.LANCZOS)

    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    paste_x = round(origin_x + center_x - size[0] / 2)
    paste_y = round(origin_y + center_y - size[1] / 2)
    canvas.alpha_composite(sprite, (paste_x, paste_y))
    canvas.save(args.output)

    print(f"[sprite] {args.input}")
    print(f"        crop={bbox} -> {sprite.width}x{sprite.height} (scale {scale:.3f})")
    print(f"        canvas={canvas_w}x{canvas_h} origin=({origin_x},{origin_y}) paste=({paste_x},{paste_y})")
    print(f"        saved {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
