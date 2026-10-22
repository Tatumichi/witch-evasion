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

**検証済みの実測値**

| 項目 | 値 |
|---|---|
| ComfyUI | 0.42.0 |
| torch | 2.14.1+cu126 |
| Python | 3.12.10 |
| CUDA | `cuda:0 NVIDIA GeForce RTX 3060` / VRAM 12.88GB（空き 11.80GB） |
| 起動 | 約 70 秒で `/system_stats` 応答（コールドスタート） |

### モデル（12GB VRAM 向け）

`C:\AI\ComfyUI\models\checkpoints\` に置く。**1つから始めるのが吉**。

| モデル | サイズ | 用途 |
|---|---|---|
| `sd_xl_base_1.0.safetensors` | 6.9GB | 汎用・背景・キャラの下絵 |
| `sdxl-turbo` | 6.9GB | 1〜4 step で高速試作 |
| `dreamshaper_8` (SD1.5) | 2GB | 軽量・ドット絵 LoRA が豊富 |
| `flux1-schnell` fp8 | ~11GB | 最高品質だが 12GB だとギリギリ |

pixel art は SDXL + `pixel-art-xl` LoRA、または SD1.5 + ドット絵 LoRA が扱いやすい。

### 導入済みモデル（2026-10-22 追加）

| モデル | サイズ | 状態 |
|---|---|---|
| `animagine-xl-4.0.safetensors` | 6.46 GiB | ✅ 導入済み（アニメ調 SDXL・品質タグ `masterpiece, high score, great score, absurdres` 推奨） |

### API 連携（`tools/comfy.py`）

ComfyUI を起動したまま、標準ライブラリだけで動くクライアントから生成できる。

```bash
# 状態・VRAM 確認
C:\AI\ComfyUI\.venv\Scripts\python.exe tools\comfy.py status

# 導入済みモデル一覧
C:\AI\ComfyUI\.venv\Scripts\python.exe tools\comfy.py models

# 生成（--seed 0 または省略でランダム）
C:\AI\ComfyUI\.venv\Scripts\python.exe tools\comfy.py gen ^
  --prompt "masterpiece, 1girl, witch, full body, simple background" ^
  --width 832 --height 1216 --steps 28 --cfg 6 ^
  --out godot/assets/characters/witch
```

| 実測 | 値 |
|---|---|
| 832x1216 / 28 steps / dpmpp_2m karras | 約 22 秒（モデルロード込み） |
| 出力 | PNG + 同名 `.json`（投入したワークフローと seed を丸ごと保存） |

seed を固定すれば同じ絵を再現できるため、差分は git で追える。

### スプライト化（`tools/prepare_sprite.py`）

生成した白背景レンダーを、ゲームでそのまま使える透過 PNG に変換する。

```bash
C:\AI\ComfyUI\.venv\Scripts\python.exe tools/prepare_sprite.py ^
  art/witch/witch_fly2_s1212.png ^
  -o godot/assets/characters/witch/witch_sprite.png ^
  --fit 190x150 --canvas 240x190 --origin 135,125 --center=-16,-32
```

| 処理 | 内容 |
|---|---|
| 背景透過 | 四辺からフラッドフィル（`--thresh` 40）→ 内部の白は残す |
| 白フチ除去 | 2px 収縮 + ぼかし |
| サイズ | `--fit` がゲーム内の最大表示サイズ（190x150） |
| 原点 | `--origin` がゲーム座標 (0,0) にあたる画素。`player.gd` 側は `position = -SPRITE_ORIGIN` |
| 注意 | `--center` は負値なので `--center=-16,-32` と `=` で渡す |

ゲーム側はテクスチャを等倍で置くだけなので、実行時の拡縮は発生しない。
生成前のレンダーと投入ワークフローは `art/witch/` に残している。

#### 表情差分（img2img）

構図とデザインを保ったまま表情だけ変えたいときは `img2img` を使う（`--denoise` 0.4=ほぼ維持 / 0.7=大きく変更）。

```bash
C:\AI\ComfyUI\.venv\Scripts\python.exe tools/comfy.py img2img ^
  --input art/witch/witch_fly2_s1212.png ^
  --denoise 0.7 --seed 1212 --name witch_hit_img2img_d07 --out art/witch ^
  --prompt "chibi, 1girl, witch, surprised face, wide open mouth, sweatdrops, arms flailing, ..."
```

同じ `--fit / --canvas / --origin` で `prepare_sprite.py` に通せば、通常スプライトと原点・縮尺が揃う。
被弾差分はこれで作り、`player.gd` が `die()` で `witch_hit.png` に切り替える。

### UI 素材（`tools/make_ui_art.py`）

タイトル用のロゴと立ち絵カードを Pillow で生成する（ComfyUI 不要）。

```bash
C:\AI\ComfyUI\.venv\Scripts\python.exe tools/make_ui_art.py
# -> godot/assets/ui/logo.png         "WITCH" / "EVASION" の 2 段組み（Segoe UI Black）
# -> godot/assets/ui/title_witch.png  角丸カード・発光枠・夜空背景
```

| 処理 | 内容 |
|---|---|
| ロゴ | 2 倍解像度で描いて縮小（アンチエイリアス）。白→ピンク→紫のグラデーション、暗い縁取り、紫とピンクの二重グロー |
| カード | 承認済み立ち絵の白背景を抜き、深紫グラデ＋星＋床の照り返しの上に配置。足元に残る影は「床の影」として活用 |
| 差し替え | 文字・色・サイズはスクリプト冒頭の定数で調整 |

タイトル画面は `hud.gd` が `TextureRect` として読み込み、カードをゆっくり浮かせ、
開始プロンプトを明滅させる。画像が無い場合はテキスト表示にフォールバックする。

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

## 8. 構築完了時の検証結果

| 検証項目 | コマンド | 結果 |
|---|---|---|
| Godot の版 | `godot --version` | `4.7.2.stable.official.ed1daf0bf` ✅ |
| Godot の起動 | `godot --headless --quit --path godot` | `[OK] Godot boot: scene loaded` ✅ |
| LDtk | ファイルバージョン | `1.5.3` ✅ |
| Cline | VS Code 拡張一覧 | `v4.1.25` インストール済み ✅ |
| Python 3.12 | `py -3.12 --version` | `3.12.10` ✅ |
| torch + CUDA | `torch.cuda.is_available()` | `True` / RTX 3060 12.9GB ✅ |
| ComfyUI 起動 | `/system_stats` | `0.42.0` / `cuda:0` 認識 ✅ |
| ComfyUI 生成 | `tools/comfy.py gen` | 832x1216 / 28 steps / 約22秒 ✅ |
| git | `git log` | 初回コミット済み ✅ |

**未実施（意図的）**: Godot のエクスポートテンプレートは初回エクスポート時に取得。
ComfyUI のモデルは `animagine-xl-4.0`（6.46 GiB）を導入済み。

---

## 9. アンインストール

```bash
winget uninstall GodotEngine.GodotEngine
winget uninstall deepnight.LDtk
winget uninstall Python.Python.3.12
code --uninstall-extension saoudrizwan.claude-dev
# ComfyUI は C:\AI\ComfyUI を削除
# PATH: ユーザー環境変数から %USERPROFILE%\.local\bin を除去
```
