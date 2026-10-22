# ゲーム制作ワークスペース

DeepSeek を AI 相棒にして Godot 4 でゲームを作るための環境です。

## 収録ゲーム: WITCH FLIGHT

魔女の少女が夜空を飛び、降ってくる障害物をよける 2D 縦スクロールアクション。
画像素材は使わず、すべてコードで描画しているため追加アセットなしで動きます。

| 要素 | 内容 |
|---|---|
| 操作 | `←` `→` `↑` `↓` / `W` `A` `S` `D` で移動、`SPACE` / クリックで開始・リトライ |
| スコア | 飛行距離で加算、光の星を取ると +25 |
| 難易度 | 70 秒かけてスクロール速度と障害物の出現間隔が変化 |
| 障害物 | 浮遊岩 / 枯れ枝 / 鳥の群れ（時間経過で種類が増える） |
| 保存 | ベストスコアを `user://witch_flight.cfg` に保存 |
| 描画 | 夜空グラデーション、月、星、星雲、パララックス / 魔女はパーツ描画 |

### ファイル

```
godot/
├── project.godot          540x960・入力マップ・物理レイヤー
├── scenes/main.tscn       Background / World / Player / HUD
└── scripts/
    ├── game.gd            状態遷移・難易度・生成・スコア・セーブ
    ├── player.gd          魔女の移動・当たり判定・描画・軌跡
    ├── obstacle.gd        岩 / 枝 / 鳥の生成と描画
    ├── pickup.gd          光の星
    ├── ring.gd            被弾・回収のリング演出
    ├── background.gd      夜空・月・星・星雲
    └── hud.gd             スコア表示 / タイトル / ゲームオーバー
```

### 検証コマンド

```bash
# 構文と起動の確認（エラーが出なければ OK）
godot --headless --quit --path godot

# タイトルを飛ばして即ゲーム開始（撮影・確認用）
godot --path godot -- --start
```

## 構成一覧

| レイヤー | 採用ツール | 場所 / バージョン |
|---|---|---|
| エンジン | **Godot 4.7.2**（MIT・無料） | `godot` コマンド |
| AI エージェント（リポジトリ操作） | **DeepSeek Harness** | このセッション |
| AI エージェント（エディタ内） | **Cline v4.1.25** + DeepSeek API | VS Code 拡張 |
| マップ作成 | **LDtk 1.5.3** | `ldtk` コマンド |
| 画像生成 | **ComfyUI 0.42.0**（RTX 3060 12GB・CUDA 検証済） | `C:\AI\ComfyUI` |
| キャラクター | VRoidStudio（VRM） | 導入済み |
| バージョン管理 | git 2.56 + GitHub | このフォルダ |

## ディレクトリ構成

```
ゲーム制作/
├── godot/              ← Godot プロジェクト本体（WITCH FLIGHT）
│   ├── project.godot
│   ├── scenes/main.tscn
│   ├── scripts/        ← ゲームロジックと描画
│   └── assets/         ← 将来のスプライト・音声・モデル置き場
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
godot --path godot

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
3. WITCH FLIGHT に効果音・BGM を追加（未実装）
4. LDtk でステージを作り、`godot/assets/` のスプライトに差し替える
