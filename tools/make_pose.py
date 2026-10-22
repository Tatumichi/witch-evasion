#!/usr/bin/env python3
"""OpenPose（COCO-18）形式のポーズ画像を作る。

ControlNet（openpose）に渡す「棒人間」を、座標指定から決定論的に描く。
生成画像から pose を抽出する代わりに、こちらでポーズを定義するので、
スプライトごとに同じポーズを再利用できる。

Usage
-----
    python tools/make_pose.py --preset flying --size 832x1216 --out art/pose/flying.png
    python tools/make_pose.py --spec my_pose.json --size 832x1216 --out art/pose/custom.png

座標は 0〜1 の正規化（x は右、y は下）。JSON は
    {"nose": [0.30, 0.30], "neck": [0.33, 0.37], ...}
の形式で、COCO-18 のキー名を使う。
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

# COCO-18 のキーポイント順（OpenPose の BODY_25 から neck を 1 として扱う）
KEYS = [
    "nose", "neck",
    "r_shoulder", "r_elbow", "r_wrist",
    "l_shoulder", "l_elbow", "l_wrist",
    "r_hip", "r_knee", "r_ankle",
    "l_hip", "l_knee", "l_ankle",
    "r_eye", "l_eye", "r_ear", "l_ear",
]

# 0-indexed の骨格（OpenPose の limbSeq と同じ組み合わせ）
LIMBS = [
    (1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7),
    (1, 8), (8, 9), (9, 10), (5, 11), (11, 12), (12, 13),
    (1, 0), (0, 14), (14, 16), (0, 15), (15, 17),
]

# OpenPose 既定の色（RGB）。手足ごとに色を変えることで関節の対応が伝わる。
COLORS = [
    (255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0),
    (85, 255, 0), (0, 255, 0), (0, 255, 85), (0, 255, 170), (0, 255, 255),
    (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255),
    (255, 0, 255), (255, 0, 170), (255, 0, 85),
]

PRESETS: dict[str, dict[str, list[float]]] = {
    # 直立・腕を下ろした基本形
    "standing": {
        "nose": [0.50, 0.16], "neck": [0.50, 0.24],
        "r_shoulder": [0.44, 0.26], "r_elbow": [0.40, 0.38], "r_wrist": [0.38, 0.50],
        "l_shoulder": [0.56, 0.26], "l_elbow": [0.60, 0.38], "l_wrist": [0.62, 0.50],
        "r_hip": [0.45, 0.52], "r_knee": [0.44, 0.70], "r_ankle": [0.43, 0.88],
        "l_hip": [0.55, 0.52], "l_knee": [0.56, 0.70], "l_ankle": [0.57, 0.88],
        "r_eye": [0.48, 0.14], "l_eye": [0.52, 0.14],
        "r_ear": [0.46, 0.15], "l_ear": [0.54, 0.15],
    },
    # 箒に乗って前傾・脚を後ろへ流す（横から見た構図）
    "flying": {
        "nose": [0.28, 0.38], "neck": [0.34, 0.44],
        "r_shoulder": [0.35, 0.45], "r_elbow": [0.30, 0.51], "r_wrist": [0.26, 0.57],
        "l_shoulder": [0.37, 0.46], "l_elbow": [0.32, 0.52], "l_wrist": [0.28, 0.58],
        "r_hip": [0.47, 0.52], "r_knee": [0.56, 0.55], "r_ankle": [0.64, 0.60],
        "l_hip": [0.47, 0.54], "l_knee": [0.56, 0.58], "l_ankle": [0.64, 0.64],
        "r_eye": [0.27, 0.37], "l_eye": [0.29, 0.37],
        "r_ear": [0.26, 0.38], "l_ear": [0.30, 0.38],
    },
    # 片手を上げる（手の位置を固定したいとき）
    "reaching": {
        "nose": [0.50, 0.16], "neck": [0.50, 0.24],
        "r_shoulder": [0.44, 0.26], "r_elbow": [0.40, 0.18], "r_wrist": [0.38, 0.09],
        "l_shoulder": [0.56, 0.26], "l_elbow": [0.60, 0.38], "l_wrist": [0.62, 0.50],
        "r_hip": [0.45, 0.52], "r_knee": [0.44, 0.70], "r_ankle": [0.43, 0.88],
        "l_hip": [0.55, 0.52], "l_knee": [0.56, 0.70], "l_ankle": [0.57, 0.88],
        "r_eye": [0.48, 0.14], "l_eye": [0.52, 0.14],
        "r_ear": [0.46, 0.15], "l_ear": [0.54, 0.15],
    },
}


def draw_pose(points: dict[str, list[float]], width: int, height: int,
              bg: tuple[int, int, int] = (0, 0, 0)) -> Image.Image:
    im = Image.new("RGB", (width, height), bg)
    d = ImageDraw.Draw(im)
    px = {k: (v[0] * width, v[1] * height) for k, v in points.items() if k in KEYS}
    thickness = max(5, int(min(width, height) / 110))
    radius = max(3, int(thickness * 0.55))

    for idx, (a, b) in enumerate(LIMBS):
        ka, kb = KEYS[a], KEYS[b]
        if ka in px and kb in px:
            d.line([px[ka], px[kb]], fill=COLORS[idx % len(COLORS)], width=thickness)

    dot = (255, 255, 255) if sum(bg) < 384 else (20, 20, 20)
    for key in KEYS:
        if key in px:
            x, y = px[key]
            d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=dot)
    return im


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--out", required=True)
    p.add_argument("--size", default="832x1216", help="WxH。生成解像度に合わせる")
    p.add_argument("--preset", choices=sorted(PRESETS), default="flying")
    p.add_argument("--spec", help="キーポイントを書いた JSON（--preset より優先）")
    p.add_argument("--bg", choices=("black", "white", "gray"), default="black",
                   help="背景色。黒は生成側の背景に色が漏れることがある")
    args = p.parse_args(argv)

    w, h = (int(v) for v in args.size.lower().split("x"))
    if args.spec:
        with open(args.spec, encoding="utf-8") as fh:
            points = json.load(fh)
        missing = [k for k in KEYS if k not in points]
        if missing:
            print(f"[pose] warning: missing keypoints {missing}", file=sys.stderr)
    else:
        points = PRESETS[args.preset]

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    bg = {"black": (0, 0, 0), "white": (255, 255, 255), "gray": (127, 127, 127)}[args.bg]
    im = draw_pose(points, w, h, bg)
    im.save(args.out)
    with open(os.path.splitext(args.out)[0] + ".json", "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"preset": args.preset, "size": [w, h], "bg": args.bg, "points": points}, fh,
                  ensure_ascii=False, indent=2)
    print(f"[pose] {args.out} ({w}x{h}, {args.preset})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
