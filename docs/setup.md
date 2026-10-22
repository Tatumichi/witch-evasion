# 環境構築メモ（2026-10-22 構築）

## マシン構成

| 項目 | 内容 |
|---|---|
| GPU | NVIDIA GeForce RTX 3060 12GB（ドライバ 617.14） |
| OS | Windows（スタンドアロン winget 1.29 使用） |
| 既存 | VS Code 1.142.0 / Node 24.22.1 / pnpm 12.14.0 / Python 3.14.3 / .NET 10 / Docker 29.4 / git 2.56.0 / Unity 6 & 2022 LTS / VRoidStudio |

---

## 1. Godot 4.7.2

```bash
winget install --id GodotEngine.GodotEngine --silent
```

インストール先（winget はポータブル配置）:
```
%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\
  ├─ Godot_v4.7.2-stable_win64.exe          ← GUI（エディタ）
  └─ Godot_v4.7.2-stable_win64_console.exe  ← コンソール版（ログが出る）
```

**重要**: winget は GUI 版に `godot` エイリアスを張るため、`--headless` のログが取れません。
そこで `%USERPROFILE%\.local\bin\godot.cmd` から**コンソール版**を呼ぶようにし、このフォルダを
ユーザー PATH の**先頭**に置いています（管理者権限不要）。

```bash
# 確認
godot --version
# → 4.7.2.stable.official.ed1daf0bf
```

### 検証コマンド
```bash
godot --headless --quit --path godot
# → [OK] Godot boot: scene loaded, version=4.7.2-stable (official)
```

> **エクスポート（.exe 書き出し）時**: 初回はエディタの
> `エディタ → エクスポートテンプレートの管理` からテンプレートをダウンロードしてください。

---

## 2. LDtk 1.5.3（マップエディタ）

```bash
winget install --id deepnight.LDtk --silent
# 実体: %LOCALAPPDATA%\Programs\ldtk\LDtk.exe
# ラッパ: %USERPROFILE%\.local\bin\ldtk.cmd
```

LDtk の利点は**レベルが JSON**であること。`.ldtk` プロジェクトを DeepSeek に読ませて、
タイル配置や敵配置をテキストで生成・修正できます。

---

## 3. Python 3.12（ComfyUI 用）

ComfyUI / PyTorch は Python 3.14 に未対応のため 3.12 を追加。

```bash
winget install --id Python.Python.3.12 --silent
py -3.12 --version   # → Python 3.12.x
```

`py -3.14` が既定のままなので、ComfyUI は専用 venv で 3.12 を使います。

---

## 4. Cline（VS Code 拡張）

```bash
code --install-extension saoudrizwan.claude-dev
# → v4.1.25
```

### DeepSeek API キーの設定（要手動：3分）

1. https://platform.deepseek.com/api_keys で API キーを発行（クレジット残高も確認）
2. VS Code 左のアクティビティバー → **Cline** アイコン
3. 歯車（Settings）→ **API Configuration**
4. **API Provider: `DeepSeek`** を選択
5. **API Key** に発行したキーを貼り付け
6. モデル:
   - `deepseek-chat` … 実装・修正用（高速・安価）
   - `deepseek-reasoner` … 設計・原因究明用
7. 「Use custom base URL」は**不要**（DeepSeek プロバイダを使う場合）

> キーは Cline が VS Code の SecretStorage に保存します。リポジトリには入りません。

### Cline の実運用ルール（ハルシネーション対策）
- 依頼は「1 シーン + 1 スクリプト」単位に区切る
- 必ず最後に `godot --headless --quit --path godot` を実行させ、エラーを読ませる
- 自動承認（Auto-approve）は **コマンド実行以外** に留めるのが安全

---

## 5. ComfyUI（画像生成）

```
C:\AI\ComfyUI\           ← OneDrive 外に配置（モデルが数 GB になるため）
├─ .venv\                ← Python 3.12
├─ models\checkpoints\   ← モデルはここ
└─ main.py
```

構築内容:
```bash
git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git C:/AI/ComfyUI
py -3.12 -m venv C:/AI/ComfyUI/.venv
.venv\Scripts\pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
.venv\Scripts\pip install -r requirements.txt
```

起動: ワークスペースの `tools\start-comfyui.cmd` → http://127.0.0.1:8188

### モデル（12GB VRAM 向け）

`C:\AI\ComfyUI\models\checkpoints\` に置く。**1つから始めるのが吉**。

| モデル | サイズ | 用途 |
|---|---|---|
| `sd_xl_base_1.0.safetensors` | 6.9GB | 汎用・背景・キャラの下絵 |
| `sdxl-turbo` | 6.9GB | 1〜4 step で高速試作 |
| `dreamshaper_8` (SD1.5) | 2GB | 軽量・ドット絵 LoRA が豊富 |
| `flux1-schnell` fp8 | ~11GB | 最高品質だが 12GB だとギリギリ |

pixel art は SDXL + `pixel-art-xl` LoRA、または SD1.5 + ドット絵 LoRA が扱いやすい。

> **注意**: 生成した絵をそのままゲームに使う場合、モデルのライセンス（商用可否）を必ず確認。

---

## 6. PATH / シェル設定

`%USERPROFILE%\.local\bin` をユーザー PATH の**先頭**に追加済み。

| コマンド | 実体 |
|---|---|
| `godot` | `Godot_v4.7.2-stable_win64_console.exe` |
| `ldtk` | `LDtk.exe` |
| `py -3.12` | Python 3.12 |

**既に開いているターミナル / VS Code は再起動が必要**です。

---

## 7. トラブルシュート

| 症状 | 対処 |
|---|---|
| `godot` が見つからない | ターミナルを新規に開く。`%USERPROFILE%\.local\bin` が PATH にあるか確認 |
| `--headless` で何も表示されない | GUI 版が呼ばれている。`where godot` で `.local\bin\godot.cmd` が先か確認 |
| Godot がシーンを開かない | `godot/` を**フォルダごと**開く（`project.godot` 単体ではなく） |
| ComfyUI が CUDA を認識しない | `C:\AI\ComfyUI\.venv\Scripts\python -c "import torch;print(torch.cuda.is_available())"` |
| ComfyUI が OOM | `main.py --lowvram` を付ける。解像度を 1024→768 に下げる |
| OneDrive の同期が重い | `.godot/` と `C:\AI\` は同期対象外に設定（下記） |

### OneDrive 対策（推奨）
`ゲーム制作` フォルダは OneDrive 配下にあります。Godot の `.godot/` キャッシュは
数千ファイルになるため、**OneDrive の「同期しないフォルダ」に `godot\.godot` を追加**するか、
プロジェクトを `C:\dev\` に移すことを推奨します（現状は後述の運用で回避可能）。

---

## 8. アンインストール

```bash
winget uninstall GodotEngine.GodotEngine
winget uninstall deepnight.LDtk
winget uninstall Python.Python.3.12
code --uninstall-extension saoudrizwan.claude-dev
# ComfyUI は C:\AI\ComfyUI を削除
# PATH: ユーザー環境変数から %USERPROFILE%\.local\bin を除去
```
