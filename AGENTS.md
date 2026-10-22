# AGENTS.md — エージェント共通指示

> 人間向けの進め方は `docs/GAME_DEV_WORKFLOW.md`。ここは**毎回読む短い指示**だけを置く。

## プロジェクト概要

- **WITCH EVASION** — 見習い魔女メルルが空を上昇し、障害物をよける 2D 縦スクロールアクション
- **Godot 4.7.2**（GDScript のみ・アドオンなし）/ 表示 540×960
- 主人公: メルル・ポプリエ（12歳・高所恐怖症）。設定は `docs/witch_merulu_setting.md`
- ステージ1「村の空」実装済み。`godot/scenes/stage1.tscn` がメインシーン

## ディレクトリ

| パス | 内容 |
|---|---|
| `godot/` | Godot プロジェクト本体（`godot/project.godot`） |
| `godot/assets/` | 画像・フォント。生成物はここへ |
| `godot/scripts/` | ゲームロジック。`stage/` にステージ1の実装 |
| `godot/tests/` | ヘッドレス検証スクリプト |
| `tools/` | 画像生成・変換の Python（ComfyUI 連携） |
| `docs/` | 設計・設定・進捗・決定 |
| `art/` | 生成の作業場（実験ログは git 管理外） |

## コマンド

```bash
# 構文・起動チェック（必須）
/c/Users/dubia/.local/bin/godot.cmd --headless --quit --path godot

# アセット再インポート（PNG を差し替えたら必須）
/c/Users/dubia/.local/bin/godot.cmd --headless --editor --quit --path godot

# 検証スクリプト
cmd --headless --path godot --script res://tests/verify_sprite.gd
```

- Godot は PATH に無い。`/c/Users/dubia/.local/bin/godot.cmd` を使う
- 画面確認は `--write-movie <絶対パス>`。**日本語パスだと失敗する**ので `%LOCALAPPDATA%\Temp` に出す

## 画像生成

```bash
C:\AI\ComfyUI\.venv\Scripts\python.exe tools/comfy.py gen --preset noobai --lora "cute-anime.safetensors:0.85" --prompt "..."
```

- モデル: NoobAI-XL 1.1（プリセット `noobai`）。詳細は `docs/ai-quality/02-prompt-design.md`
- 画風: **リッチA**（Toon LoRA なし・`cel shading, detailed hair, gradient shading`）
- IP画風 LoRA は使わない（`docs/ai-quality/07-style-generic.md`）
- 生成後は `tools/trim_sprite.py` で正規化、`tools/prepare_sprite.py` で原点焼き込み

## 規約

1. GDScript のみ。外部アドオン・C# は使わない
2. 1タスク = 1目的 = 1コミット。コミットメッセージは英語の命令形
3. 変更したら `--headless --quit` でエラーゼロを確認してから報告する
4. 画像を差し替えたら `--headless --editor --quit` で再インポートする（忘れると古い絵が出る）
5. 決定は `docs/decisions.md`、進捗は `docs/progress.md`、タスクは `docs/backlog.md` に書く
6. 触ってよい範囲を依頼で指定されたら、その外は変更しない

## よくある落とし穴（Godot 4）

- **`.uid` ファイル**はコミットする（Godot 4.4+ が生成）
- `_ready` は兄弟の構築順に依存する。他ノードを掴むなら `_process` で遅延解決する
- シーン側で子を全消しするコードがある場合、静的ノードはその親の外に置く
- `z_index` は親からの相対。背景 (-10) < 影 (-1) < キャラ (0) < HUD (CanvasLayer)
- テストは `SceneTree` を継承した `--script` で書ける（例: `godot/tests/verify_shadow.gd`）

## 参照

- 進め方: `docs/GAME_DEV_WORKFLOW.md`
- アセット棚卸し: `docs/stage1-assets.md`
- AI 生成の知見: `docs/ai-quality/`（01〜07）
