# ゲーム制作ワークスペース

DeepSeek を AI 相棒にして Godot 4 でゲームを作るための環境です。

## 構成一覧

| レイヤー | 採用ツール | 場所 / バージョン |
|---|---|---|
| エンジン | **Godot 4.7.2**（MIT・無料） | `godot` コマンド |
| AI エージェント（リポジトリ操作） | **DeepSeek Harness** | このセッション |
| AI エージェント（エディタ内） | **Cline v4.1.25** + DeepSeek API | VS Code 拡張 |
| マップ作成 | **LDtk 1.5.x** | `ldtk` コマンド |
| 画像生成 | **ComfyUI 0.42.0**（RTX 3060 12GB・CUDA 検証済） | `C:\AI\ComfyUI` |
| キャラクター | VRoidStudio（VRM） | 導入済み |
| バージョン管理 | git 2.56 + GitHub | このフォルダ |

## ディレクトリ構成

```
ゲーム制作/
├── godot/              ← Godot プロジェクト本体
│   ├── project.godot
│   ├── scenes/main.tscn
│   ├── scripts/main.gd
│   └── assets/         ← スプライト・音声・モデル
├── tools/              ← 起動用スクリプト
├── docs/
│   └── setup.md        ← 詳細な構築手順とトラブルシュート
└── .gitignore
```

## すぐ使うコマンド

```bash
# エディタ起動
godot --path godot

# ゲーム実行
godot --path godot --  # またはエディタの F5

# ヘッドレス検証（AI に確認させるとき用・超重要）
godot --headless --quit --path godot

# マップエディタ
ldtk

# 画像生成 UI（http://127.0.0.1:8188）
tools/start-comfyui.cmd
```

## DeepSeek の使い分け

- **DeepSeek Harness（ここ）**: 複数ファイルにまたがる実装、リファクタ、`--headless` での動作検証まで一括で任せる
- **Cline（VS Code 内）**: 開いているファイル周辺の小さな修正、エラー修正、コードの説明
- **deepseek-chat**: 実装・修正（速くて安い）
- **deepseek-reasoner**: 設計、バグの原因究明、ゲームバランスの検討

### コツ
1. 1 回の依頼は「1 シーン + 1 スクリプト」程度に区切る
2. 必ず `godot --headless --quit --path godot` で検証させる（エラーを自分で読ませる）
3. `.tscn` はテキストなので AI に直接編集させてよい。ただし**エディタで開いたまま**にしない
4. 画像は生成できないので、素材は ComfyUI / LDtk / VRoidStudio で用意して `godot/assets/` に置く

## 次の一歩

1. Cline に DeepSeek API キーを設定（`docs/setup.md` 参照）
2. ComfyUI にモデルを 1 つダウンロード
3. `godot/` を開いて最初のシーンを作る
