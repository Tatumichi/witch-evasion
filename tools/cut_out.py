#!/usr/bin/env python3
"""単体の小物画像から背景を抜いて、透過 PNG に切り抜く。

`prepare_sprite.py` はゲーム用に原点を焼き込むが、こちらは
「素材をそのまま透過させる」だけの用途。背景色は四隅から自動で拾う。

Usage
-----
    python tools/cut_out.py art/props/cn_hat_s8701.png godot/assets/props/hat.png
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prepare_sprite import build_alpha, remove_white_background  # noqa: E402


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("input")
    p.add_argument("output")
    p.add_argument("--thresh", type=int, default=48)
    p.add_argument("--erode", type=int, default=1)
    p.add_argument("--feather", type=float, default=0.8)
    p.add_argument("--pad", type=int, default=4, help="切り抜き後に足す余白 px")
    args = p.parse_args(argv)

    img = Image.open(args.input).convert("RGBA")
    alpha = build_alpha(remove_white_background(img, args.thresh), args.erode, args.feather)
    img.putalpha(alpha)

    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        raise SystemExit(f"[cut] no foreground in {args.input}")
    x0, y0, x1, y1 = bbox
    w, h = args.pad, args.pad
    img = img.crop((max(0, x0 - w), max(0, y0 - h),
                    min(img.width, x1 + w), min(img.height, y1 + h)))

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    img.save(args.output)
    print(f"[cut] {os.path.basename(args.input)} -> {args.output} ({img.width}x{img.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
