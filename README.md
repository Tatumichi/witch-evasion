# ゲーム制作ワークスペース

DeepSeek を AI 相棒にして Godot 4 でゲームを作るための環境です。

## 収録ゲーム: WITCH EVASION

見習い魔女メルルが、止まらないほうきで空を昇っていく 2D 縦スクロールアクション。
**STAGE 1「村の空」** と **STAGE 2「丘と森の上空」** を遊べます。タイトルで ←→ を押すとステージを選べます。
STAGE 2 は STAGE 1 をクリアすると解放され、STAGE 1 の結果画面から続けて始まります。
STAGE 2 の素材（画像・BGM・専用の効果音）はまだ無く、図形・STAGE 1 の曲・既存の効果音で動いています（作る素材は [`docs/stage2-assets.md`](docs/stage2-assets.md)）。

| 要素 | 内容 |
|---|---|
| 操作 | `←` `→` `↑` `↓` / `W` `A` `S` `D` で移動、`SPACE` / `ENTER` / クリックで開始。タイトルでは ←→ でステージ選択 |
| 構成 | 各ステージ 道中 120 秒 → ボス → クリア結果 → 次のステージ |
| ライフ | 帽子 3 つ。被弾後 1.5 秒は無敵。0 で目を回し、道中なら最初から・ボス戦ならボス戦の頭から |
| STAGE 1 | 洗濯物（シーツ / 靴下）、鳩の列（1 羽分のすき間）、落ちてくる風見鶏、煙突の煙（当たらないが遅くなる）。ボス「ぐるぐる大風見鶏」 |
| STAGE 2 | スクロール 1.1 倍。横風（予告のあと 3 秒、メルルも障害物も流される）、綿毛の嵐、下から昇る風船（当たっても帽子は減らず、はじかれる）、渡り鳥の V 字、画面端の風車の羽根。ボス「はぐれ大風車」（回る羽根・強い横風・小麦粉の目隠し） |
| 落っこち猫 | 「にゃー！」の予告後に落ちてくる。受け止めると 15 秒間、茶トラ＝キャンディ連射 / 白猫＝バリア |
| 勇気のかけら | 50 個で帽子 1 つ回復（満タンなら +500） |
| ボス | 満足ゲージが満タンになるまでよけ切ればクリア。キャンディを当てると早く満足する |
| 保存 | ステージごとのベストスコアと解放状況を `user://witch_stage.cfg` に保存 |

以前のエンドレス版（夜空で岩・枝・鳥をよけ続ける）も `scenes/main.tscn` として残してあります。

### 世界観・ステージ設定（企画）

今後の拡張は「見習い魔女メルル」の設定に沿って進めます。実装・アセット制作・バランス調整の前に、次の設定書を参照してください。

| ドキュメント | 内容 |
|---|---|
| [`docs/witch_merulu_setting.md`](docs/witch_merulu_setting.md) | コンセプト、主人公メルル、暴走の原因と神域、導入シーン台本 |
| [`docs/stage_design.md`](docs/stage_design.md) | 全5ステージの設定書。共通仕様、障害物、落っこち猫、ボス、セリフ、エンディング |
| [`docs/music.md`](docs/music.md) | BGM。曲の狙い、ループ位置、書き出し方、再生の切り替え |
| [`docs/sound_effects.md`](docs/sound_effects.md) | 効果音 42 音の一覧、鳴らす場面、優先度、組み込みの注意。STAGE 2 の振り替え |
| [`docs/stage1-assets.md`](docs/stage1-assets.md) | STAGE 1 の素材（画像・UI）の棚卸し |
| [`docs/stage2-assets.md`](docs/stage2-assets.md) | **STAGE 2 で作る素材の仕様**（画像 11 点・BGM 2 曲・専用 SE 11 音）。置けば差し替わる |

設定書で決めている主な仕様（STAGE 1・2 は実装済み、STAGE 3〜5 は未実装）:

| 項目 | 設定 |
|---|---|
| ステージ | 1 村の空 → 2 丘と森の上空 → 3 雲の層 → 4 星の海 → 5 神域の門（各 約2〜3分） |
| ライフ | 帽子 3 つ。全部失うとステージ頭からやり直し |
| 収集物 | 勇気のかけら（50 個で帽子 1 つ回復） |
| 落っこち猫 | 受け止めると 15 秒間効果。茶トラ＝キャンディ連射 / 白猫＝バリア。全 21 匹 |
| ボス | 毎ステージ 1 体。満足ゲージが満タンになるまでよけ切ればクリア、キャンディで短縮 |
| スクロール速度 | ステージ 1 の 1.0 倍からステージ 5 の 1.4 倍まで段階的に上昇 |

### ファイル

```
godot/
├── project.godot          540x960・入力マップ・物理レイヤー
├── icon.png               256px アイコン（ドット絵調）
├── icon.ico               exe 用アイコン（16〜256）
├── scenes/
│   ├── stage1.tscn        STAGE 1「村の空」（メインシーン。タイトルもここ）
│   ├── stage2.tscn        STAGE 2「丘と森の上空」
│   └── main.tscn          以前のエンドレス版
├── assets/
│   ├── characters/witch/
│   │   ├── witch_sprite.png   通常（240x190・原点焼き込み済み）
│   │   └── witch_hit.png      被弾差分（同じ原点・同じ縮尺）
│   ├── ui/
│   │   ├── logo.png           タイトルロゴ（780x400）
│   │   └── title_witch.png    立ち絵カード（420x500）
│   └── fonts/
│       ├── MPLUSRounded1c-Bold.ttf  セリフ・HUD 用の日本語フォント
│       └── OFL.txt                  フォントのライセンス（SIL OFL 1.1）
├── tests/
│   ├── verify_stage1.gd   STAGE 1 を最初から最後まで通す検証
│   ├── verify_stage2.gd   STAGE 2 を最初から最後まで通す検証（横風・風船・効果音・BGM も）
│   ├── verify_flow.gd     ステージの解放と、STAGE 1 クリア → STAGE 2 の流れ
│   ├── verify_sprite.gd   スプライト装着と被弾差分の検証
│   ├── verify_ui.gd       タイトル画面とスコア表示の検証
│   └── hit_demo.tscn      被弾フレームを撮るためのデモ
└── scripts/
    ├── game.gd            状態遷移・難易度・生成・スコア・セーブ
    ├── player.gd          魔女の移動・当たり判定・スプライト/軌跡
    ├── obstacle.gd        岩 / 枝 / 鳥の生成と描画
    ├── pickup.gd          光の星
    ├── ring.gd            被弾・回収のリング演出
    ├── background.gd      夜空・月・星・星雲（タイトル中は月を隠す）
    ├── ground_shadow.gd   接地影／光暈（生成画像には焼き込まない）
    ├── hud.gd             スコア表示 / タイトル / ゲームオーバー
    ├── game_state.gd      autoload。ステージの解放・ベストスコア・ステージ間の移動
    └── stage/             ── ここからステージ制 ──
        ├── stage_base.gd          全ステージ共通の進行（帽子・猫・キャンディ・やり直し・ボス戦の流れ・結果・効果音）
        ├── stage_player.gd        player.gd を拡張（無敵時間・猫の同乗・バリア・煙で減速・はじかれ）
        ├── stage_hud.gd           帽子・かけら・猫・スコア・高度レール・セリフ・タイトルのステージ選択・結果画面
        ├── bgm.gd / sfx.gd        BGM の切り替え / 効果音の再生（専用音が無い名前は既存音に振り替え）
        ├── stage1.gd              STAGE 1 の出現表・セリフ・ボス指定（stage_base を継承）
        ├── stage1_background.gd   朝焼けの空、流れていく村、遠くの教会の塔
        ├── laundry.gd             洗濯物（シーツ / 靴下）
        ├── pigeon.gd              鳩（列で出る）
        ├── weathervane.gd         落ちてくる小さな風見鶏
        ├── smoke.gd               煙突の煙
        ├── courage.gd             勇気のかけら
        ├── falling_cat.gd         落っこち猫
        ├── candy.gd               茶トラのキャンディ
        ├── boss_weathervane.gd    ボス「ぐるぐる大風見鶏」と満足ゲージ
        ├── wind_arrow.gd          ボスの矢印型の風向き板
        ├── fx.gd                  飛んでいく帽子・「ごめんね」などの小演出
        ├── stage2.gd              STAGE 2 の出現表・横風・セリフ・ボス指定・BGM の指定
        ├── stage2_background.gd   青空、流れていく丘と風車、遠くの森と大木、わた雲
        ├── wind_fx.gd             横風の見た目（風上の草・「≫」の予告・風の筋と葉）
        ├── fluff.gd               たんぽぽの綿毛（嵐でまとめて出る）
        ├── balloon.gd             風船（下から昇る。猫つきもある）
        ├── goose.gd               渡り鳥（V 字の隊列）
        ├── windmill.gd            画面端の風車（回る羽根）
        ├── boss_windmill.gd       ボス「はぐれ大風車」と満足ゲージ
        ├── flour_bag.gd           ボスが投げる小麦粉の袋
        └── flour_cloud.gd         小麦粉の白い粉（視界をふさぐだけ）
```

道中の出現タイミングは各 `stageN.gd` の `build_timeline()`（決まった出来事）と `SECTIONS`（区間ごとのランダム出現）で調整する。
新しいステージは `stage_base.gd` を継承し、冒頭の「ステージごとに上書きする」関数を書いて、`game_state.gd` の `STAGES` に登録する。

生成前のレンダーとプロンプト記録は `art/witch/` に置いてある。

### 検証コマンド

```bash
# 構文と起動の確認（エラーが出なければ OK）
godot --headless --quit --path godot

# スプライトが Player に装着されているか（失敗時は exit 1）
godot --headless --path godot --script res://tests/verify_sprite.gd

# タイトル画面のロゴ / 立ち絵とスコア表示の切替（失敗時は exit 1）
godot --headless --path godot --script res://tests/verify_ui.gd

# STAGE 1 を通しで検証（被弾・猫・キャンディ・やり直し・道中 120 秒・ボス・クリア。失敗時は exit 1）
# --fixed-fps 60 を付けると実時間を待たずに数秒で終わる
godot --headless --path godot --fixed-fps 60 --script res://tests/verify_stage1.gd

# 当たり判定が見た目の中心にあり、アイテム・猫を拾えるか（失敗時は exit 1）
godot --headless --path godot --fixed-fps 60 --script res://tests/verify_hitbox.gd

# STAGE 2 を通しで検証 / ステージの解放と STAGE 1 → 2 の流れ（どちらも保存データは触らない）
godot --headless --path godot --fixed-fps 60 --script res://tests/verify_stage2.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/verify_flow.gd

# 確認用の起動（組み合わせ可）：タイトルを飛ばして開始 / ボス戦から / 被弾しない / ステージ指定
godot --path godot -- --start
godot --path godot -- --boss
godot --path godot -- --start --god
godot --path godot -- --stage=2 --god
godot --path godot -- --stage=2 --boss

# 以前のエンドレス版を遊ぶ
godot --path godot res://scenes/main.tscn
```

clone 直後など `.godot/` が無い状態では、ヘッドレス検証の前に一度 `godot --headless --import --path godot` で取り込みを済ませる（しないと画像やフォントが読み込めず検証が失敗する）。

タイトル画面の確認（PNG 連番で書き出し）:
```bash
godot --path godot --write-movie out/frame.png --fixed-fps 30 --quit-after 45
```

### 配布用ビルド（exe）

アイコンはドット絵調の魔女。`godot/icon.png`（256px・ウィンドウ / エディタ用）と
`godot/icon.ico`（16〜256 のマルチサイズ・exe 用）を、`tools/make_icon.py` で生成している。

初回だけエクスポートテンプレートの導入が必要:
1. Godot 4.7.2 のエクスポートテンプレート（`.tpz`）を取得
2. `%APPDATA%\Godot\export_templates\4.7.2.stable\` に中身を展開

```bash
# ビルド（build/ は git 管理外）
godot --headless --export-release "Windows Desktop" build/WitchEvasion.exe
```

被弾フレームの確認（1 回被弾させて停止）:
```bash
godot --path godot res://tests/hit_demo.tscn --write-movie out/frame.png --fixed-fps 30 --quit-after 90
```

動画として書き出すとレイアウト確認が早い:
```bash
godot --path godot --write-movie frames/frame.png --fixed-fps 30 --quit-after 45 -- --start
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
├── godot/              ← Godot プロジェクト本体（WITCH EVASION）
│   ├── project.godot
│   ├── scenes/main.tscn
│   ├── scripts/        ← ゲームロジックと描画
│   └── assets/         ← 将来のスプライト・音声・モデル置き場
├── tools/              ← 起動用スクリプト
├── docs/
│   ├── setup.md                ← 詳細な構築手順とトラブルシュート
│   ├── witch_merulu_setting.md ← 世界観・主人公・導入シーン台本
│   ├── stage_design.md         ← 全5ステージの設定書
│   └── ai-quality/             ← イラスト品質向上プロジェクト（調査と改善の記録）
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

# API 経由で画像生成（ComfyUI 起動中に実行・1 枚 約22秒）
C:\AI\ComfyUI\.venv\Scripts\python.exe tools\comfy.py gen ^
  --prompt "1girl, witch, full body, simple background" ^
  --out godot/assets/characters/witch
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
4. 画像生成は `tools/comfy.py` 経由で依頼できる（`--preset` でモデル別の品質タグ・ネガ・パラメータを一括切替。既定は導入済みモデルを自動選択）。成果物は `godot/assets/` に置く。設計方針は `docs/ai-quality/02-prompt-design.md`

## 次の一歩

1. Cline に DeepSeek API キーを設定（`docs/setup.md` 参照）
2. タイトル画面用の立ち絵（`art/witch/witch_chibi_s111.png`）を HUD に組み込む
3. 実機で BGM と SE の音量バランスを聴いて調整する（BGM・SE は実装済み。`docs/music.md`・`docs/sound_effects.md`）
4. LDtk でステージを作り、`godot/assets/` のスプライトに差し替える
5. STAGE 2 の素材を作る（`docs/stage2-assets.md`）。STAGE 2 を遊んで難しさを決める
6. `docs/stage_design.md` に沿って STAGE 3「雲の層」を実装する
