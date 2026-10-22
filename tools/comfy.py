#!/usr/bin/env python3
"""ComfyUI HTTP API client (standard library only).

Examples
--------
    python tools/comfy.py status
    python tools/comfy.py models
    python tools/comfy.py models
    python tools/comfy.py gen --prompt "1girl, witch" --out godot/assets/characters/witch
    python tools/comfy.py gen --preset noobai --prompt "1girl, witch, standing"

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

COMFY_ROOT = os.environ.get("COMFY_ROOT", r"C:\AI\ComfyUI")

# モデルごとに「品質タグの語彙」「ネガ」「推奨パラメータ」が違う。混ぜると出力が崩れるため、
# 一式をプリセットとして持ち、--preset で切り替える（--preset auto は導入済みの中から選ぶ）。
PRESETS = {
    "noobai": {
        "label": "NoobAI-XL 1.1 (tags+NSFW, non-commercial)",
        "ckpt": "NoobAI-XL-v1.1.safetensors",
        "prefix": "masterpiece, best quality, newest, absurdres, highres, safe",
        "negative": (
            "nsfw, worst quality, old, early, low quality, lowres, signature, "
            "username, logo, bad hands, mutated hands, mammal, anthro, furry, "
            "ambiguous form, feral, semi-anthro"
        ),
        "steps": 28,
        "cfg": 5.5,
        "sampler": "euler_ancestral",
        "scheduler": "normal",
        "width": 832,
        "height": 1216,
    },
    "illustrious": {
        "label": "Illustrious-XL v2.0 (commercial ok)",
        "ckpt": "Illustrious-XL-v2.0.safetensors",
        "prefix": "masterpiece, best quality, very aesthetic, absurdres",
        "negative": (
            "worst quality, bad quality, low quality, lowres, bad anatomy, bad hands, "
            "text, error, missing finger, extra digits, fewer digits, cropped, "
            "signature, watermark, username, blurry, jpeg artifacts"
        ),
        "steps": 28,
        "cfg": 5.5,
        "sampler": "euler_ancestral",
        "scheduler": "normal",
        "width": 832,
        "height": 1216,
    },
    "animagine": {
        "label": "Animagine XL 4.0 (commercial ok, mostly SFW)",
        "ckpt": "animagine-xl-4.0.safetensors",
        "prefix": "masterpiece, high score, great score, absurdres",
        "negative": (
            "lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, "
            "fewer digits, cropped, worst quality, low quality, low score, bad score, "
            "average score, signature, watermark, username, blurry, jpeg artifacts"
        ),
        "steps": 28,
        "cfg": 5.0,
        "sampler": "euler_ancestral",
        "scheduler": "normal",
        "width": 832,
        "height": 1216,
    },
}
PRESET_ORDER = ("noobai", "illustrious", "animagine")
DOWNLOADS = {
    "noobai": "https://huggingface.co/Laxhar/noobai-XL-1.1/resolve/main/NoobAI-XL-v1.1.safetensors",
    "illustrious": "https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0/resolve/main/Illustrious-XL-v2.0.safetensors",
    "animagine": "https://huggingface.co/cagliostrolab/animagine-xl-4.0/resolve/main/animagine-xl-4.0.safetensors",
}


def available_checkpoints() -> list[str]:
    folder = os.path.join(COMFY_ROOT, "models", "checkpoints")
    try:
        names = os.listdir(folder)
    except OSError:
        return []
    return [n for n in names if n.lower().endswith((".safetensors", ".ckpt", ".pt"))]


def available_loras() -> list[str]:
    folder = os.path.join(COMFY_ROOT, "models", "loras")
    try:
        names = os.listdir(folder)
    except OSError:
        return []
    return sorted(n for n in names if n.lower().endswith(".safetensors"))


def available_controlnets() -> list[str]:
    folder = os.path.join(COMFY_ROOT, "models", "controlnet")
    try:
        names = os.listdir(folder)
    except OSError:
        return []
    return sorted(n for n in names if n.lower().endswith((".safetensors", ".ckpt", ".pth")))


def resolve_controlnet(name: str) -> str:
    if not os.path.isfile(os.path.join(COMFY_ROOT, "models", "controlnet", name)):
        have = ", ".join(available_controlnets()) or "none"
        raise SystemExit(
            f"[comfy] controlnet not found: {name}\n"
            f"        put it in {os.path.join(COMFY_ROOT, 'models', 'controlnet')}\n"
            f"        available: {have}"
        )
    return name


def parse_loras(items: list[str]) -> list[tuple[str, float]]:
    """`NAME[:WEIGHT]` の並びを (name, weight) に変換し、実ファイルの存在を確認する。"""
    folder = os.path.join(COMFY_ROOT, "models", "loras")
    parsed: list[tuple[str, float]] = []
    for item in items:
        name, sep, raw_weight = item.rpartition(":")
        if not sep:
            name, raw_weight = item, "1.0"
        try:
            weight = float(raw_weight)
        except ValueError:
            name, weight = item, 1.0
        if not os.path.isfile(os.path.join(folder, name)):
            have = ", ".join(available_loras()) or "none"
            raise SystemExit(
                f"[comfy] LoRA not found: {name}\n"
                f"        put it in {folder}\n"
                f"        available: {have}"
            )
        parsed.append((name, weight))
    return parsed


def resolve_preset(name: str) -> dict:
    """プリセット名→実際に使う設定。auto は導入済みモデルのうち優先順で最初のもの。"""
    have = set(available_checkpoints())
    if name != "auto":
        if name not in PRESETS:
            raise SystemExit(
                f"[comfy] unknown preset {name!r}; choose auto or one of: {', '.join(PRESETS)}"
            )
        preset = dict(PRESETS[name])
        if preset["ckpt"] not in have:
            raise SystemExit(
                f"[comfy] preset {name!r} needs {preset['ckpt']}\n"
                f"        save it to {os.path.join(COMFY_ROOT, 'models', 'checkpoints')}\n"
                f"        download: {DOWNLOADS[name]}"
            )
        return preset
    for key in PRESET_ORDER:
        if PRESETS[key]["ckpt"] in have:
            return dict(PRESETS[key])
    raise SystemExit(
        "[comfy] no checkpoint found in models/checkpoints\n"
        f"        download: {DOWNLOADS[PRESET_ORDER[0]]}"
    )


def apply_preset(args) -> dict:
    """未指定のオプションをプリセットで埋め、品質タグをプロンプト先頭に足す。"""
    preset = resolve_preset(args.preset)
    if not args.quiet:
        print(f"[comfy] preset {args.preset} -> {preset['label']}", flush=True)
    for key in ("steps", "cfg", "sampler", "scheduler"):
        if getattr(args, key, None) is None:
            setattr(args, key, preset[key])
    if not args.ckpt:
        args.ckpt = preset["ckpt"]
    if not args.no_quality_tags and preset["prefix"]:
        args.prompt = f"{preset['prefix']}, {args.prompt}"
    if args.negative is None:
        args.negative = preset["negative"]
    for key in ("width", "height"):
        if hasattr(args, key) and getattr(args, key) is None:
            setattr(args, key, preset[key])
    return preset


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

def _lora_chain(workflow: dict, loras: list[tuple[str, float]], ckpt_id: str = "1") -> tuple[list, list]:
    """Checkpoint の後ろに LoraLoader を直列につなぎ、(model, clip) の参照を返す。"""
    model_ref: list = [ckpt_id, 0]
    clip_ref: list = [ckpt_id, 1]
    for idx, (name, strength) in enumerate(loras, start=1):
        node_id = f"L{idx}"
        workflow[node_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": model_ref,
                "clip": clip_ref,
                "lora_name": name,
                "strength_model": strength,
                "strength_clip": strength,
            },
        }
        model_ref = [node_id, 0]
        clip_ref = [node_id, 1]
    return model_ref, clip_ref


def _apply_controlnet(workflow: dict, image_name: str, controlnet: str, strength: float,
                      start: float, end: float, preprocess: str,
                      canny_low: int, canny_high: int) -> None:
    """LoadImage -> (Canny) -> ControlNetApplyAdvanced を組んで KSampler に繋ぐ。"""
    workflow["C1"] = {"class_type": "LoadImage", "inputs": {"image": image_name}}
    image_ref: list = ["C1", 0]
    if preprocess == "canny":
        workflow["C2"] = {
            "class_type": "Canny",
            "inputs": {"image": image_ref, "low_threshold": canny_low, "high_threshold": canny_high},
        }
        image_ref = ["C2", 0]
    workflow["C3"] = {
        "class_type": "ControlNetLoader",
        "inputs": {"control_net_name": controlnet},
    }
    workflow["C4"] = {
        "class_type": "ControlNetApplyAdvanced",
        "inputs": {
            "positive": ["2", 0],
            "negative": ["3", 0],
            "control_net": ["C3", 0],
            "image": image_ref,
            "strength": strength,
            "start_percent": start,
            "end_percent": end,
        },
    }
    workflow["5"]["inputs"]["positive"] = ["C4", 0]
    workflow["5"]["inputs"]["negative"] = ["C4", 1]


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
    loras: list[tuple[str, float]] | None = None,
) -> dict:
    """Minimal SDXL text-to-image graph in ComfyUI's API format."""
    workflow = {
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
    if loras:
        model_ref, clip_ref = _lora_chain(workflow, loras)
        workflow["2"]["inputs"]["clip"] = clip_ref
        workflow["3"]["inputs"]["clip"] = clip_ref
        workflow["5"]["inputs"]["model"] = model_ref
    return workflow


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
    loras: list[tuple[str, float]] | None = None,
) -> dict:
    """入力画像の構図を保ったまま描き直す（表情・ポーズ変更用）。"""
    workflow = {
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
    if loras:
        model_ref, clip_ref = _lora_chain(workflow, loras, ckpt_id="0")
        workflow["2"]["inputs"]["clip"] = clip_ref
        workflow["3"]["inputs"]["clip"] = clip_ref
        workflow["5"]["inputs"]["model"] = model_ref
    return workflow


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


def cmd_controlnets(_args) -> None:
    names = available_controlnets()
    folder = os.path.join(COMFY_ROOT, "models", "controlnet")
    if not names:
        print(f"no controlnets in {folder}")
        return
    for name in names:
        size = os.path.getsize(os.path.join(folder, name)) / 2**30
        print(f"  {name}  {size:.2f} GiB")
    print('\nusage: python tools/comfy.py gen --control-image pose.png --controlnet "NAME" --prompt "..."')


def cmd_loras(_args) -> None:
    names = available_loras()
    folder = os.path.join(COMFY_ROOT, "models", "loras")
    if not names:
        print(f"no loras in {folder}")
        return
    for name in names:
        size = os.path.getsize(os.path.join(folder, name)) / 2**30
        print(f"  {name}  {size:.2f} GiB")
    print('\nusage: python tools/comfy.py gen --lora "NAME:0.8" --prompt "..."')


def cmd_models(_args) -> None:
    names = sorted(available_checkpoints())
    folder = os.path.join(COMFY_ROOT, "models", "checkpoints")
    if not names:
        print(f"no checkpoints in {folder}")
    for name in names:
        size = os.path.getsize(os.path.join(folder, name)) / 2**30
        print(f"  {name}  {size:.2f} GiB")
    print("\npresets:")
    for key in PRESET_ORDER:
        preset = PRESETS[key]
        ready = preset["ckpt"] in names
        print(f"  {key:11s} {'ready  ' if ready else 'missing'}  {preset['label']}")
        if not ready:
            print(f"             {DOWNLOADS[key]}")


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


def _maybe_controlnet(workflow: dict, args) -> None:
    if not args.control_image:
        return
    controlnet = resolve_controlnet(args.controlnet or "openpose-sdxl.safetensors")
    image_name = upload_image(args.control_image)
    _apply_controlnet(workflow, image_name, controlnet, args.control_strength,
                      args.control_start, args.control_end, args.control_preprocess,
                      args.canny_low, args.canny_high)
    if not args.quiet:
        print(f"[comfy] controlnet {controlnet} <- {os.path.basename(args.control_image)} "
              f"(strength {args.control_strength:g})", flush=True)


def cmd_gen(args) -> None:
    apply_preset(args)
    loras = parse_loras(args.lora)
    if loras and not args.quiet:
        print("[comfy] loras: " + ", ".join(f"{n}@{w:g}" for n, w in loras), flush=True)
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
        loras=loras,
    )
    _maybe_controlnet(workflow, args)
    run_and_save(workflow, args.out, args.name, args.seed, args.timeout, args.quiet)


def cmd_img2img(args) -> None:
    apply_preset(args)
    loras = parse_loras(args.lora)
    if loras and not args.quiet:
        print("[comfy] loras: " + ", ".join(f"{n}@{w:g}" for n, w in loras), flush=True)
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
        loras=loras,
    )
    _maybe_controlnet(workflow, args)
    print(f"[comfy] input {image_name} denoise={args.denoise}", flush=True)
    run_and_save(workflow, args.out, args.name, args.seed, args.timeout, args.quiet)


def add_common_options(p) -> None:
    p.add_argument("--prompt", required=True)
    p.add_argument(
        "--preset",
        default="auto",
        choices=("auto",) + tuple(PRESETS),
        help="モデル別の文法・ネガ・パラメータ一式（auto=導入済みから選択）",
    )
    p.add_argument("--no-quality-tags", action="store_true", help="プリセットの品質タグを付けない")
    p.add_argument("--control-image", help="ControlNet に渡す画像（ポーズ画像や線画）")
    p.add_argument("--controlnet", default=None, help="models/controlnet のファイル名")
    p.add_argument("--control-strength", type=float, default=0.8)
    p.add_argument("--control-start", type=float, default=0.0)
    p.add_argument("--control-end", type=float, default=1.0)
    p.add_argument("--control-preprocess", choices=("none", "canny"), default="none",
                   help="canny=グレースケール画像から線画を作る")
    p.add_argument("--canny-low", type=int, default=100)
    p.add_argument("--canny-high", type=int, default=200)
    p.add_argument(
        "--lora",
        action="append",
        default=[],
        metavar="NAME[:WEIGHT]",
        help="LoRA を適用（複数指定可）。例: add-detail-xl.safetensors:0.8",
    )
    p.add_argument("--negative", default=None, help="省略時はプリセットのネガ")
    p.add_argument("--ckpt", default=None, help="プリセットを無視してモデルを直接指定")
    p.add_argument("--steps", type=int, default=None)
    p.add_argument("--cfg", type=float, default=None)
    p.add_argument("--sampler", default=None)
    p.add_argument("--scheduler", default=None)
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
    sub.add_parser("loras", help="list installed LoRAs").set_defaults(func=cmd_loras)
    sub.add_parser("controlnets", help="list installed ControlNets").set_defaults(func=cmd_controlnets)

    gen = sub.add_parser("gen", help="text-to-image")
    add_common_options(gen)
    gen.add_argument("--width", type=int, default=None)
    gen.add_argument("--height", type=int, default=None)
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
