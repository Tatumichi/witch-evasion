#!/usr/bin/env python3
"""背景を抜いて被写体を検出し、同じ余白・同じキャンバスに正規化する。

ゲームスプライトは「被写体の大きさと位置が揃っている」ことが前提なので、
生成画像のフレーミングのばらつき（画面いっぱい〜画面の1/5）をここで吸収する。

Usage
-----
    python tools/trim_sprite.py --in art/bench/benchB_s2005.png --out art/bench/trim
    python tools/trim_sprite.py --in art/bench --out art/bench/trim --size 512 --sheet

しくみ
------
1. 画像の縁から、隣接画素との色差が小さい範囲だけを伝って背景を広げる
   （勾配のある背景でも、キャラの輪郭という急な色差で止まる）
2. 前景の最大連結成分を被写体とし、穴を埋める（浮遊線・ゴミは落ちる）
3. バウンディングボックス＋余白で切り抜き
4. 指定サイズの正方形キャンバスに、比率を保って配置

注意
----
背景が「縁から伝って届く単一の面」でない場合（画面を横切る帯、強いビネット、
境界の硬い二色背景など）は検出に失敗し、警告が出る。その場合は生成側で背景を
単純にする（`white background` を守らせる）か、`--debug-mask` でマスクを見て
`--local-tol` を調整する。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import deque
from glob import glob

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


# ------------------------------------------------------------------ background

def background_mask(arr: np.ndarray, seed_tol: float, local_tol: float) -> np.ndarray:
    """縁から、隣接画素との色差が local_tol 未満の範囲だけを伝って背景を広げる。"""
    h, w, _ = arr.shape
    flat = arr.reshape(-1, 3).astype(np.int16)
    corners = np.array([arr[0, 0], arr[0, -1], arr[-1, 0], arr[-1, -1]], dtype=np.int16)
    to_bg = np.abs(flat - np.median(corners, axis=0)).sum(axis=1)

    visited = np.zeros(h * w, dtype=bool)
    seeds = (
        list(range(w)) + list(range((h - 1) * w, h * w))
        + [y * w for y in range(h)] + [y * w + w - 1 for y in range(h)]
    )
    queue: deque[int] = deque()
    for i in seeds:
        if not visited[i] and to_bg[i] < seed_tol:
            visited[i] = True
            queue.append(i)

    while queue:
        i = queue.popleft()
        y, x = divmod(i, w)
        c0, c1, c2 = int(flat[i][0]), int(flat[i][1]), int(flat[i][2])
        neighbours = []
        if y > 0:
            neighbours.append(i - w)
        if y < h - 1:
            neighbours.append(i + w)
        if x > 0:
            neighbours.append(i - 1)
        if x < w - 1:
            neighbours.append(i + 1)
        for j in neighbours:
            if visited[j]:
                continue
            p0, p1, p2 = int(flat[j][0]), int(flat[j][1]), int(flat[j][2])
            if abs(p0 - c0) + abs(p1 - c1) + abs(p2 - c2) < local_tol:
                visited[j] = True
                queue.append(j)

    return visited.reshape(h, w)


def foreground_mask(im: Image.Image, seed_tol: float, local_tol: float) -> np.ndarray:
    """被写体（背景以外の最大連結成分）を True にしたマスクを返す。"""
    arr = np.asarray(im.convert("RGB"))
    fg = ~background_mask(arr, seed_tol, local_tol)

    labels, count = ndimage.label(fg)
    if count == 0:
        raise SystemExit("[trim] foreground is empty (local-tol too small?)")
    sizes = ndimage.sum_labels(fg, labels, np.arange(1, count + 1))
    return ndimage.binary_fill_holes(labels == (int(np.argmax(sizes)) + 1))


def feather(mask: np.ndarray, blur: float) -> np.ndarray:
    """輪郭を1px縮めてから軽くぼかす（背景色のフチを落とし、ジャギーを消す）。"""
    eroded = ndimage.binary_erosion(mask, iterations=1)
    alpha = (eroded.astype(np.uint8) * 255)
    alpha = np.asarray(Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(blur)))
    return alpha


def cut_out(im: Image.Image, mask: np.ndarray, blur: float) -> Image.Image:
    rgb = np.asarray(im.convert("RGB"))
    return Image.fromarray(np.dstack([rgb, feather(mask, blur)]), "RGBA")


# ---------------------------------------------------------------------- canvas

def fit_to_canvas(sprite: Image.Image, size: int, margin: float, align: str) -> tuple[Image.Image, dict]:
    sw, sh = sprite.size
    inner = max(1, int(round(size * (1.0 - 2.0 * margin))))
    scale = min(inner / sw, inner / sh)
    nw, nh = max(1, round(sw * scale)), max(1, round(sh * scale))
    resized = sprite.resize((nw, nh), Image.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pad = int(round(size * margin))
    x = (size - nw) // 2
    y = size - pad - nh if align == "bottom" else (size - nh) // 2
    canvas.paste(resized, (x, max(0, y)), resized)
    return canvas, {"scale": round(scale, 4), "placed": [x, max(0, y), nw, nh]}


# ----------------------------------------------------------------------- batch

def process(path: str, out_dir: str, size: int, margin: float, seed_tol: float,
            local_tol: float, blur: float, align: str, debug: bool) -> dict:
    im = Image.open(path)
    mask = foreground_mask(im, seed_tol, local_tol)
    ys, xs = np.nonzero(mask)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    bw, bh = x1 - x0, y1 - y0
    coverage = (bw * bh) / (im.width * im.height)

    cut = cut_out(im, mask, blur).crop((x0, y0, x1, y1))
    canvas, info = fit_to_canvas(cut, size, margin, align)

    stem = os.path.splitext(os.path.basename(path))[0]
    os.makedirs(out_dir, exist_ok=True)
    out_png = os.path.join(out_dir, stem + "_trim.png")
    canvas.save(out_png)
    if debug:
        Image.fromarray((mask * 255).astype(np.uint8), "L").save(
            os.path.join(out_dir, stem + "_mask.png"))

    meta = {
        "source": os.path.relpath(path).replace(os.sep, "/"),
        "source_size": list(im.size),
        "bbox": [x0, y0, bw, bh],
        "coverage": round(coverage, 4),
        "canvas": [size, size],
        "margin": margin,
        "seed_tol": seed_tol,
        "local_tol": local_tol,
        **info,
    }
    with open(os.path.splitext(out_png)[0] + ".json", "w", encoding="utf-8", newline="\n") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    return {"path": out_png, "meta": meta, "warn": coverage > 0.85}


def contact_sheet(results: list[dict], out_path: str, cell: int = 260) -> None:
    """元画像と正規化後を横に並べた確認用シート。"""
    pad = 8
    sheet = Image.new("RGBA", (2 * (cell + pad) + pad, len(results) * (cell + pad) + pad), (245, 245, 245, 255))
    for i, r in enumerate(results):
        y = pad + i * (cell + pad)
        for col, src in enumerate((r["meta"]["source"], r["path"])):
            im = Image.open(src).convert("RGBA")
            im.thumbnail((cell, cell), Image.LANCZOS)
            sheet.alpha_composite(im, (pad + col * (cell + pad) + (cell - im.width) // 2,
                                       y + (cell - im.height) // 2))
    sheet.convert("RGB").save(out_path)
    print(f"[trim] sheet -> {out_path}")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--in", dest="src", required=True, help="画像ファイル or ディレクトリ")
    p.add_argument("--out", default="art/trim", help="出力ディレクトリ")
    p.add_argument("--size", type=int, default=512, help="出力キャンバスの一辺(px)")
    p.add_argument("--margin", type=float, default=0.06, help="キャンバスに対する余白の割合")
    p.add_argument("--seed-tol", type=float, default=60.0, help="縁の画素を背景の起点とする色差")
    p.add_argument("--local-tol", type=float, default=14.0, help="背景を広げる際の隣接色差(小さいほど慎重)")
    p.add_argument("--blur", type=float, default=0.8, help="輪郭のぼかし(px)")
    p.add_argument("--align", choices=("center", "bottom"), default="center")
    p.add_argument("--debug-mask", action="store_true", help="検出マスクも書き出す")
    p.add_argument("--sheet", action="store_true", help="元画像との比較シートを作る")
    args = p.parse_args(argv)

    if os.path.isdir(args.src):
        paths = sorted(f for f in glob(os.path.join(args.src, "*.png"))
                       if not os.path.basename(f).startswith("_"))
    else:
        paths = [args.src]
    if not paths:
        raise SystemExit(f"[trim] no png in {args.src}")

    results, warned = [], 0
    for path in paths:
        r = process(path, args.out, args.size, args.margin, args.seed_tol,
                    args.local_tol, args.blur, args.align, args.debug_mask)
        m = r["meta"]
        status = "WARN" if r["warn"] else "OK  "
        if r["warn"]:
            warned += 1
        print(f"  [{status}] {os.path.basename(path):26s} bbox {m['bbox'][2]:4d}x{m['bbox'][3]:<4d} "
              f"coverage {m['coverage']*100:4.1f}%  scale {m['scale']:.2f}")
        results.append(r)

    if args.sheet:
        contact_sheet(results, os.path.join(args.out, "_sheet.png"))
    print(f"[trim] {len(results)} image(s) -> {args.out}")
    if warned:
        print(f"[trim] warning: {warned} image(s) で背景を分離できませんでした。"
              " 生成側で背景を単純にするか --local-tol を調整してください。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
