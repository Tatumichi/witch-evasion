# コマンド集

## Godot

```bash
GD=/c/Users/dubia/.local/bin/godot.cmd

# 起動・構文チェック（必須）
$GD --headless --quit --path godot

# アセット再インポート（PNG 差し替え後）
$GD --headless --editor --quit --path godot

# 検証スクリプト
$GD --headless --path godot --script res://tests/verify_sprite.gd
$GD --headless --path godot --script res://tests/verify_ui.gd
$GD --headless --path godot --script res://tests/verify_stage1.gd
$GD --headless --path godot --fixed-fps 60 --script res://tests/verify_hitbox.gd
$GD --headless --path godot --script res://tests/verify_shadow.gd
$GD --headless --path godot --fixed-fps 60 --script res://tests/verify_bgm.gd
$GD --headless --path godot --fixed-fps 60 --script res://tests/verify_sfx.gd

# ボス確認（演出を飛ばして進入。--symbol は記号描画の強制）
$GD --path godot --write-movie "$LOCALAPPDATA/Temp/boss/frame.png" --fixed-fps 30 --quit-after 80 -- --boss --symbol=happy

# 画面キャプチャ（日本語パス不可 → Temp に出す）
$GD --path godot --write-movie "$LOCALAPPDATA/Temp/out/frame.png" --fixed-fps 30 --quit-after 90 -- --start
```

## 画像生成

```bash
PY=/c/AI/ComfyUI/.venv/Scripts/python.exe
$PY tools/comfy.py models        # モデルとプリセット
$PY tools/comfy.py loras         # LoRA 一覧
$PY tools/comfy.py controlnets   # ControlNet 一覧

$PY tools/comfy.py gen --preset noobai --seed 5041 `
  --lora "cute-anime.safetensors:0.85" `
  --prompt "1girl, solo, witch, ..." --name sample --out art/meluru
```

## 画像変換

```bash
# 透過・512px 正規化
$PY tools/trim_sprite.py --in art/meluru --out art/meluru/trim --size 512 --sheet

# ゲーム用スプライト（原点焼き込み）
$PY tools/prepare_sprite.py <src.png> -o godot/assets/characters/witch/witch_sprite.png `
  --fit 190x150 --canvas 240x190 --origin 135,125 --center=-16,-32

# 村の帯を組み立てる
$PY tools/build_village_band.py --house a.png --house b.png --out godot/assets/background/village_band.png

# タイトル用カード
UI_CARD_SOURCE="art/meluru/rich/rich_cute_s5041.png" $PY tools/make_ui_art.py
```

## 音

```bash
# BGM（MIDI 原本と、ゲーム用ループ OGG）。pip install mido numpy scipy、ffmpeg が必要
python tools/music/stage1_bgm.py
python tools/music/boss1_bgm.py

# SE（全部、または名前を指定して作り直す）。pip install numpy scipy
python tools/sfx/make_se.py
python tools/sfx/make_se.py hit gust_warning
```

音源を差し替えたら `--headless --editor --quit` で再インポートする。
