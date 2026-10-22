#!/usr/bin/env python3
"""ComfyUI HTTP API client (standard library only).

Examples
--------
    python tools/comfy.py status
    python tools/comfy.py models
    python tools/comfy.py gen --prompt "1girl, witch" --out godot/assets/characters/witch

The exact workflow submitted for each image is saved next to it as
<image>.json so a result can always be reproduced from git history.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

SERVER = os.environ.get("COMFY_URL", "http://127.0.0.1:8188").rstrip("/")

DEFAULT_CKPT = "animagine-xl-4.0.safetensors"
DEFAULT_NEGATIVE = (
    "lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, "
    "fewer digits, cropped, worst quality, low quality, low score, bad score, "
    "average score, signature, watermark, username, blurry, jpeg artifacts"
)


# --------------------------------------------------------------------------- http

def _request(path: str, payload=None, timeout: float = 60.0) -> bytes:
    url = SERVER + path
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            return res.read()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise SystemExit(f"[comfy] HTTP {exc.code} on {path}\n{body[:2000]}") from None
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"[comfy] cannot reach {SERVER} ({exc.reason}).\n"
            "        Start it with tools/start-comfyui.cmd first."
        ) from None


def api_json(path: str, payload=None, timeout: float = 60.0):
    return json.loads(_request(path, payload, timeout).decode("utf-8"))


# ----------------------------------------------------------------------- workflow

def build_workflow(
    checkpoint: str,
    positive: str,
    negative: str,
    width: int,
    height: int,
    steps: int,
    cfg: float,
    sampler: str,
    scheduler: str,
    seed: int,
    filename_prefix: str,
) -> dict:
    """Minimal SDXL text-to-image graph in ComfyUI's API format."""
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": checkpoint},
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": positive, "clip": ["1", 1]},
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": negative, "clip": ["1", 1]},
        },
        "4": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": sampler,
                "scheduler": scheduler,
                "denoise": 1.0,
            },
        },
        "6": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["5", 0], "vae": ["1", 2]},
        },
        "7": {
            "class_type": "SaveImage",
            "inputs": {"images": ["6", 0], "filename_prefix": filename_prefix},
        },
    }


def build_img2img_workflow(
    checkpoint: str,
    image_name: str,
    positive: str,
    negative: str,
    steps: int,
    cfg: float,
    sampler: str,
    scheduler: str,
    seed: int,
    denoise: float,
    filename_prefix: str,
) -> dict:
    """入力画像の構図を保ったまま描き直す（表情・ポーズ変更用）。"""
    return {
        "0": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": checkpoint},
        },
        "1": {
            "class_type": "LoadImage",
            "inputs": {"image": image_name},
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": positive, "clip": ["0", 1]},
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": negative, "clip": ["0", 1]},
        },
        "4": {
            "class_type": "VAEEncode",
            "inputs": {"pixels": ["1", 0], "vae": ["0", 2]},
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["0", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": sampler,
                "scheduler": scheduler,
                "denoise": denoise,
            },
        },
        "6": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["5", 0], "vae": ["0", 2]},
        },
        "7": {
            "class_type": "SaveImage",
            "inputs": {"images": ["6", 0], "filename_prefix": filename_prefix},
        },
    }


# --------------------------------------------------------------------- submission

def upload_image(path: str) -> str:
    """input/ に画像を送り、LoadImage で使える名前を返す。"""
    boundary = uuid.uuid4().hex
    with open(path, "rb") as fh:
        blob = fh.read()
    filename = os.path.basename(path)
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'.encode(),
            b"Content-Type: application/octet-stream\r\n\r\n",
            blob,
            f"\r\n--{boundary}--\r\n".encode(),
        ]
    )
    req = urllib.request.Request(
        SERVER + "/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            payload = json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"[comfy] upload failed: HTTP {exc.code}") from None
    subfolder = payload.get("subfolder") or ""
    return f"{subfolder}/{payload['name']}" if subfolder else payload["name"]


def submit(workflow: dict) -> str:
    res = api_json("/prompt", {"prompt": workflow, "client_id": uuid.uuid4().hex})
    if "error" in res:
        raise SystemExit("[comfy] rejected:\n" + json.dumps(res, ensure_ascii=False, indent=2))
    return res["prompt_id"]


def wait_for(prompt_id: str, timeout: float, quiet: bool = False) -> dict:
    started = time.time()
    last = -1
    while time.time() - started < timeout:
        history = api_json(f"/history/{prompt_id}")
        entry = history.get(prompt_id)
        if entry:
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise SystemExit(
                    "[comfy] execution error:\n"
                    + json.dumps(status.get("messages", []), ensure_ascii=False, indent=2)[:3000]
                )
            if entry.get("outputs"):
                return entry
        elapsed = int(time.time() - started)
        if not quiet and elapsed // 5 != last:
            last = elapsed // 5
            print(f"[comfy] generating... {elapsed}s", flush=True)
        time.sleep(1.0)
    raise SystemExit(f"[comfy] timed out after {timeout:.0f}s (prompt {prompt_id})")


def download_image(image: dict, dest_dir: str, stem: str) -> str:
    query = urllib.parse.urlencode(
        {"filename": image["filename"], "subfolder": image.get("subfolder", ""), "type": image.get("type", "output")}
    )
    blob = _request("/view?" + query, timeout=120)
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, stem + os.path.splitext(image["filename"])[1])
    with open(path, "wb") as fh:
        fh.write(blob)
    return path


# ------------------------------------------------------------------------ commands

def cmd_status(_args) -> None:
    stats = api_json("/system_stats")
    sysinfo = stats["system"]
    print(f"ComfyUI {sysinfo['comfyui_version']} ({sysinfo['python_version'].split()[0]}, torch {sysinfo['pytorch_version']})")
    for dev in stats.get("devices", []):
        print(f"  {dev['name']}: VRAM {dev['vram_free'] / 2**30:.1f} / {dev['vram_total'] / 2**30:.1f} GiB free")
    queue = api_json("/queue")
    print(f"  queue: {len(queue.get('queue_running', []))} running, {len(queue.get('queue_pending', []))} pending")


def cmd_models(_args) -> None:
    info = api_json("/object_info/CheckpointLoaderSimple")
    names = info["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][0]
    if not names:
        print("no checkpoints found in models/checkpoints")
    for name in names:
        path = os.path.join(os.environ.get("COMFY_ROOT", r"C:\AI\ComfyUI"), "models", "checkpoints", name)
        size = f"{os.path.getsize(path) / 2**30:.2f} GiB" if os.path.exists(path) else "?"
        print(f"  {name}  {size}")


def run_and_save(workflow: dict, out_dir: str, name: str, seed: int, timeout: float, quiet: bool) -> list[str]:
    os.makedirs(out_dir, exist_ok=True)
    prompt_id = submit(workflow)
    print(f"[comfy] queued {prompt_id} (seed {seed})", flush=True)
    entry = wait_for(prompt_id, timeout, quiet)

    saved = []
    images = entry["outputs"]["7"]["images"]
    for idx, image in enumerate(images):
        stem = f"{name}_s{seed}" if len(images) == 1 else f"{name}_s{seed}_{idx}"
        path = download_image(image, out_dir, stem)
        with open(os.path.splitext(path)[0] + ".json", "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"prompt_id": prompt_id, "seed": seed, "workflow": workflow}, fh, ensure_ascii=False, indent=2)
        print(f"[comfy] saved {path}")
        saved.append(path)
    return saved


def cmd_gen(args) -> None:
    workflow = build_workflow(
        checkpoint=args.ckpt,
        positive=args.prompt,
        negative=args.negative,
        width=args.width,
        height=args.height,
        steps=args.steps,
        cfg=args.cfg,
        sampler=args.sampler,
        scheduler=args.scheduler,
        seed=args.seed,
        filename_prefix=args.prefix,
    )
    run_and_save(workflow, args.out, args.name, args.seed, args.timeout, args.quiet)


def cmd_img2img(args) -> None:
    image_name = upload_image(args.input)
    workflow = build_img2img_workflow(
        checkpoint=args.ckpt,
        image_name=image_name,
        positive=args.prompt,
        negative=args.negative,
        steps=args.steps,
        cfg=args.cfg,
        sampler=args.sampler,
        scheduler=args.scheduler,
        seed=args.seed,
        denoise=args.denoise,
        filename_prefix=args.prefix,
    )
    print(f"[comfy] input {image_name} denoise={args.denoise}", flush=True)
    run_and_save(workflow, args.out, args.name, args.seed, args.timeout, args.quiet)


def add_common_options(p) -> None:
    p.add_argument("--prompt", required=True)
    p.add_argument("--negative", default=DEFAULT_NEGATIVE)
    p.add_argument("--ckpt", default=DEFAULT_CKPT)
    p.add_argument("--steps", type=int, default=28)
    p.add_argument("--cfg", type=float, default=6.0)
    p.add_argument("--sampler", default="dpmpp_2m")
    p.add_argument("--scheduler", default="karras")
    p.add_argument("--seed", type=int, default=0, help="0 = random")
    p.add_argument("--name", default="witch")
    p.add_argument("--prefix", default="dsh/witch", help="ComfyUI-side filename prefix")
    p.add_argument("--out", default="godot/assets/characters/witch")
    p.add_argument("--timeout", type=float, default=900)
    p.add_argument("--quiet", action="store_true")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status", help="server and GPU status").set_defaults(func=cmd_status)
    sub.add_parser("models", help="list installed checkpoints").set_defaults(func=cmd_models)

    gen = sub.add_parser("gen", help="text-to-image")
    add_common_options(gen)
    gen.add_argument("--width", type=int, default=832)
    gen.add_argument("--height", type=int, default=1216)
    gen.set_defaults(func=cmd_gen)

    img = sub.add_parser("img2img", help="keep the composition, change expression/pose")
    add_common_options(img)
    img.add_argument("--input", required=True, help="元画像のパス")
    img.add_argument("--denoise", type=float, default=0.55, help="0.4=ほぼ維持 / 0.7=大きく変更")
    img.set_defaults(func=cmd_img2img)

    args = parser.parse_args(argv)
    if getattr(args, "seed", None) == 0:
        args.seed = int.from_bytes(os.urandom(4), "big")
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
