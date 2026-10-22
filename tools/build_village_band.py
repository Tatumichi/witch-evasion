#!/usr/bin/env python3
"""生成した家の切り抜きを並べて、横長の村の帯を作る。

ゲーム側はこの帯を画面幅に合わせて縮小し、下から流して使う。
家を個別に生成して組み上げることで、
「屋根の帯」を1枚絵で生成するより構図が安定する。

Usage
-----
    python tools/build_village_band.py \
        --house art/bg/house_b_s8202.png \
        --house art/bg/house_a_s8201.png \
        --house art/bg/house_c_s8203.png \
        --out godot/assets/background/village_band.png \
        --width 1024 --height 300
"""

from __future__ import annotations

import argparse
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prepare_sprite import build_alpha, remove_white_background  # noqa: E402


def cut_out(path: str, thresh: int = 40, erode: int = 1, feather: float = 0.8) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    alpha = build_alpha(remove_white_background(img, thresh), erode, feather)
    img.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        raise SystemExit(f"[band] no foreground in {path}")
    return img.crop(bbox)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--house", action="append", required=True, help="家の画像（複数指定可）")
    p.add_argument("--out", required=True)
    p.add_argument("--width", type=int, default=1024)
    p.add_argument("--height", type=int, default=300)
    p.add_argument("--baseline", type=int, default=0, help="帯の下端から浮かせる px")
    p.add_argument("--overlap", type=float, default=0.14, help="家同士の重なり（幅に対する割合）")
    p.add_argument("--seed", type=int, default=7)
    args = p.parse_args(argv)

    houses = [cut_out(h) for h in args.house]
    rng = random.Random(args.seed)

    band = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    baseline = args.height - args.baseline

    x = -rng.randint(0, 40)
    i = 0
    while x < args.width + 40:
        house = houses[i % len(houses)].copy()
        if rng.random() < 0.5:
            house = house.transpose(Image.FLIP_LEFT_RIGHT)

        target_h = int(rng.uniform(args.height * 0.62, args.height * 0.92))
        scale = target_h / house.height
        house = house.resize((max(1, round(house.width * scale)), target_h), Image.LANCZOS)

        y = baseline - house.height + rng.randint(-6, 4)
        band.alpha_composite(house, (x, max(0, y)))

        x += int(house.width * (1.0 - args.overlap))
        i += 1

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    band.save(args.out)
    print(f"[band] {len(houses)} house(s) -> {args.out} ({band.width}x{band.height}), {i} placed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
