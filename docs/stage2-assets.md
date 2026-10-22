# ステージ2の素材（制作指示）

STAGE 2「丘と森の上空」で使う画像・BGM・効果音の一覧と、作るときの仕様。
ゲームは**素材が無くても最後まで遊べる**状態で実装済みで、足りない素材はコード描画や STAGE 1 の音で代用している。
このドキュメントの素材を作って決まった場所に置けば、**コードを書き換えずに**自動で差し替わる。

- ゲーム側の仕様: `docs/stage_design.md` の「STAGE 2」
- 実装: `godot/scripts/stage/stage2.gd` ほか（各スクリプトの冒頭に画像の場所と大きさを書いてある）
- STAGE 1 の素材の棚卸し: `docs/stage1-assets.md`

---

## 0. 全体像

| 種別 | 必要 | 用意済み | 今の代用 |
| --- | --- | --- | --- |
| 画像 | 11 点 | 0 点 | コード描画（図形）。猫・雲は STAGE 1 の画像を流用済み |
| BGM | 2 曲 | 0 曲 | STAGE 1 の「村の空」「迷子の風見鶏」 |
| 効果音 | 専用にしたい音 11 音 | 0 音 | STAGE 1 の 42 音から振り替え（うち 3 音は無音） |

### 差し替えの手順（どの素材も同じ）

1. 下の表のファイル名で、決まったフォルダに置く
2. 再インポートする: `godot --headless --editor --quit --path godot`（忘れると古い絵・音のまま）
3. BGM のときだけ: `godot/scripts/stage/bgm.gd` の `TRACKS` で、その曲の `loop_offset` を実際のループ位置（秒）に直す
4. 確認する
   ```bash
   godot --headless --quit --path godot                                              # エラーゼロ
   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_stage2.gd  # 通し検証
   godot --path godot -- --stage=2 --god        # 実際に見る（被弾しない）。--boss を足すとボス戦から
   ```
5. 見た目は**必ず実画面で確認する**（大きさ・向き・原点のずれは数字ではわからない）。画面の書き出し:
   `godot --path godot --write-movie <絶対パス>/frame.png --fixed-fps 30 --quit-after 300 -- --stage=2 --god`

**判定のしくみ**: 画像は `ResourceLoader.exists` で有無を見て、あれば `draw_texture_rect` で描く。効果音は `sfx.gd` の `FALLBACK`、BGM はステージの `bgm_track()` が、専用ファイルがあればそちらを選ぶ。

---

## 1. 画像

### 共通のルール（`AGENTS.md`・`docs/decisions.md` より）

- 生成: NoobAI-XL 1.1、画風は**リッチA**（Toon LoRA なし、`cel shading, gradient shading`）。IP 画風 LoRA は使わない（D-002・D-003）
- **背景は透過 PNG**。生成後は `tools/cut_out.py` / `tools/trim_sprite.py` で切り抜き・正規化
- **影を焼き込まない**（D-005）。接地影はエンジン側で描く
- 小さく表示されるものは、細部より**シルエットと配色**で読ませる（メルルの制作制約と同じ考え方）
- 解像度は**ゲーム内の大きさの 4〜8 倍**で作る（縮小して使う）
- 下の「プロンプトの叩き台」は**未検証**。`docs/ai-quality/02-prompt-design.md` の手順で調整すること

### 1-1. 道中の小物（`godot/assets/props/`）

| ファイル | ゲーム内の大きさ | 原点（画像のどこがゲーム座標の 0,0 か） | 向き・形 | 担当スクリプト |
| --- | --- | --- | --- | --- |
| `fluff.png` | 幅 **30px** | 綿毛の玉の中心 = 画像の中心 | 正方形。茎と種は下へ | `fluff.gd` |
| `balloon.png` | 幅 **48px** | 風船の玉の中心 = 画像の中心 | 縦長（約 1:1.17）。**ひもは描かない** | `balloon.gd` |
| `goose.png` | 幅 **62px** | 胴の中心 = 画像の中心 | **右向き**の横長（約 1.6:1）。左へ飛ぶときは反転 | `goose.gd` |
| `windmill_blades.png` | 一辺 **380px** | ハブ（軸）= 画像の中心 | **正方形**。4 枚の羽根の先が画像の端に届く | `windmill.gd` |
| `windmill_house.png` | 幅 **110px** | 羽根の軸 = 画像の (横 50%, 縦 12%) | 縦長（約 2:5）。下は画面外まで続いてよい | `windmill.gd` |
| `flour_bag.png` | 幅 **40px** | 袋の中心 = 画像の中心 | ほぼ正方形 | `flour_bag.gd`（ボスが投げる） |

各素材の注意:

- **綿毛**: 嵐では画面に 40 粒並ぶ。白一色だと空に溶けるので、綿毛の縁を薄い灰色で締める。当たり判定は半径 7px と小さく、見た目より小さい（「すき間をぬえる」感覚のため）
- **風船**: **白〜薄い灰色で 1 枚だけ描く**。ゲーム側で 4 色に着色する（`#FF7380` 赤 / `#FFCC4C` 黄 / `#73B2FF` 青 / `#9EE085` 緑。乗算なので、元の白い部分がこの色になる）。ハイライトは白のままで良い。結び目は描いてよい（ひもはコードが結び目の下 28px から描いて揺らす）
- **渡り鳥**: 1 枚絵。羽ばたきは画像を上下に揺らして表すので、**翼を広げた中間のポーズ**が良い。V 字に 11 羽並ぶので、輪郭のはっきりした濃い色に
- **風車の羽根（道中・ボス共通の注意）**: **当たり判定は羽根に沿った帯**（軸から 30px〜先端、羽根の中心線から ±13px）。帆布をこれより大きく描くと「見た目は当たっているのに抜けた／触れていないのに当たった」になる。羽根の幅はゲーム内でおよそ 30px に収める。回転するので、強い向きのある陰影は避ける
- **風車小屋（道中）**: 画面の左右の端に、半分はみ出して置かれる。羽根の軸の位置（12%）が屋根の頂点近くに来るように描く。小屋自体に当たり判定は無い（当たるのは羽根だけ）

**流用している画像**（作らなくてよい）: `cat_tabby.png`（風船にぶら下がる猫・ボスの軸の猫）、`cat_white.png`、`cloud.png`（背景の雲）、`shard.png`・`hat.png`・`cat_icon.png`（HUD）

### 1-2. ボス「はぐれ大風車」（`godot/assets/characters/boss/`）

| ファイル | ゲーム内の大きさ | 原点 | 形 | 担当 |
| --- | --- | --- | --- | --- |
| `windmill_blades.png` | 一辺 **430px** | ハブ = 画像の中心 | 正方形。4 枚の羽根の先が画像の端に届く | `boss_windmill.gd` |
| `windmill_house.png` | 幅 **150px** | 羽根の軸 = 画像の (横 50%, 縦 16%) | 縦長（約 3:4）。入口に小麦粉の袋 | `boss_windmill.gd` |

- 道中の風車と**同じ意匠の大きい版**にする（「村の丘の風車が浮かんできた」と読めるように）。道中用の絵を拡大して流用してもよい
- 当たり判定: 羽根は軸から 30px〜215px、中心線から ±15px。小屋は軸の下 17〜167px、横 ±48px の四角。**この範囲からはみ出す飾り（旗・張り出した梁など）は描かない**
- **表情は描かない**。状態はコードが記号で出す（満足＝ハート / 突風＝湯気 / 退場＝渦巻き）。STAGE 1 の大風見鶏と同じ方針（`docs/backlog.md` の 1）
- 退場時は羽根を半透明にして「帆をたたむ」を表す。帆布と木枠が区別できる絵だと伝わりやすい
- 軸の上の猫はコードが `cat_tabby.png` を重ねる。軸のまわりに猫が乗る余白（直径 40px 程度）を空けておく

### 1-3. 背景（`godot/assets/background/`）

STAGE 1 と同じく「動く部分だけ画像化」（D-006）。**空のグラデーションと太陽はコード描画のまま**にする。

| ファイル | 推奨サイズ | ゲームでの使われ方 | 注意 |
| --- | --- | --- | --- |
| `hills_band.png` | **1200×400**（横:縦 = 3:1） | 画面幅 540px に縮小して、画面下端から上へ流れる。奥（少し暗く・70px 上・ゆっくり）と手前の **2 枚重ね** | 稜線より上は透過。**小さな風車を 2〜3 基描き込む**（画像があるときはコードの風車を描かない）。下端は `#61A357` 付近の緑で終える（コードがこの色で下を延長する） |
| `forest_band.png` | **1200×300** | 幅 540px。丘より奥でゆっくり流れる | 上端が木々の頭、その上は透過。遠景なので**空色を混ぜて淡く**描く。下端は `#598B78` 付近（コードがこの色で下を延長する） |
| `big_tree.png` | **300×900**（約 1:3） | 高さ **850px**、画面の左寄り（x=150）。道中の 7 割ほどでてっぺんがメルルの高さを越える | 根元が画像の下端、梢の上端が画像の上端。遠景なので淡く。3 匹目の猫「大木のてっぺんから」の目印になる |

- 空の色（参考）: 上 `#5C9EF2` → 下 `#CCEBFC`。終盤はわた雲（`cloud.png`）が増える
- 横に並べてつなぐことはしない（1 枚を画面幅に合わせて敷く）。左右の端は自然に切れていればよい

### 1-4. 画像にしないもの

| 対象 | スクリプト | 理由 |
| --- | --- | --- |
| 横風の演出（草のなびき・「≫」・風の筋・葉） | `wind_fx.gd` | 強さが毎フレーム変わる。予告として読めることが最優先 |
| 小麦粉の白い粉 | `flour_cloud.gd` | 画面を覆う大きさの半透明。画像だと縁が目立つ |
| 空・太陽 | `stage2_background.gd` | グラデーションの補間（D-006） |
| 白猫のバリア・同乗の猫 | `stage_player.gd` | STAGE 1 と共通 |

### 1-5. プロンプトの叩き台（未検証）

`--preset noobai --lora "cute-anime.safetensors:0.85"` に続けて。共通の末尾: `simple background, white background, no humans, cel shading, gradient shading`

| 素材 | タグの例 |
| --- | --- |
| 綿毛 | `dandelion seed, dandelion fluff, single, floating, white, soft` |
| 風船 | `balloon, single balloon, white balloon, round, glossy, knot, no string` |
| 渡り鳥 | `goose, flying, wings spread, from side, facing right, single bird` |
| 風車の羽根 | `windmill sails, four blades, wooden frame, canvas sails, front view, symmetrical, centered`（ControlNet Canny で十字のシルエットを固定すると安定） |
| 風車小屋 | `windmill, tower mill, small, white wall, red roof, wooden door, front view, no sails` |
| 小麦粉の袋 | `flour sack, burlap sack, tied top, single object` |
| 丘の帯 | `rolling hills, green meadow, small windmills, wide, panoramic, flat colors, landscape` |
| 森の帯 | `forest, treeline, dense trees, distant, hazy, panoramic, landscape` |
| 大木 | `giant tree, tall, single tree, lush canopy, distant, hazy` |

羽根と小屋は**別々に**生成する（一緒に描かせると羽根の角度が固定されて回せない）。

---

## 2. BGM（`godot/assets/audio/bgm/`）

方針は `docs/music.md` と D-007 に従う: **ピアノ独奏**、明るいが騒がしくなく、どこかせつない。

| ファイル | `bgm.gd` の名前 | 場面 | 今の代用 |
| --- | --- | --- | --- |
| `stage2_oka_to_mori.ogg` | `stage2_road` | タイトル（STAGE 2 を選んだとき）〜道中 | 村の空 |
| `boss2_hagure_fusha.ogg` | `stage2_boss` | ボス「はぐれ大風車」 | 迷子の風見鶏 |

**曲の狙い（案。決めるのは人間）**

- **丘と森の上空**: 青空と横風。STAGE 1 より少し速く（設定書のスクロール 1.1 倍に合わせて、テンポも 1 割ほど上げる程度）。風が吹く場面で左右に揺れるような伴奏。メルルのテーマ（村の空の冒頭 B♭–G–F）を引用する。道中は 120 秒なので、ループ本体は 90〜120 秒
- **はぐれ大風車**: 大きくゆっくり回る 4 枚羽根。4 拍で一周する重い低音の繰り返しの上に、突風のような速い走句。迷子の風見鶏（ハ短調・3/4）と対になる曲にする。ボス戦は 30〜60 秒なので、ループ本体は 40〜60 秒
- 調は効果音と濁らないよう**変ホ長調／ハ短調の系統**に寄せる（効果音の音程はこの 7 音に限っている）

**書き出しの決まり**（`docs/music.md` と同じ）: 「イントロ＋ループ本体」で終わる OGG。ループ末尾の余韻はループ頭に折り返す。MIDI 原本を `art/music/` に残す。作曲データは `tools/music/stage1_bgm.py`・`boss1_bgm.py` をまねて `stage2_bgm.py`・`boss2_bgm.py` を作る。

置いたら `bgm.gd` の `TRACKS` で `loop_offset` を直す（今は 0.0 の仮の値）。STAGE 2 は**ファイルがあれば自動で専用曲に切り替わる**（`stage2.gd` の `bgm_track`）。

---

## 3. 効果音（`godot/assets/audio/se/`）

STAGE 2 の音は**今は STAGE 1 の 42 音で鳴っている**。専用にしたい音には専用の名前を付けてあり、`<名前>.wav` を置けば自動でそちらが鳴る（`sfx.gd` の `FALLBACK`）。全体の決まり（形式・音量・音程）は `docs/sound_effects.md`。

### 3-1. 専用の名前を付けてある音（作れば差し替わる）

| ファイル名 | 場面 | 今の代用 | 欲しい音 | 優先 |
| --- | --- | --- | --- | --- |
| `balloon_pop` | 風船が割れる（体当たり・キャンディ） | `candy_fire` を低く | ぱんっ。軽く、驚きのある破裂 | A |
| `balloon_rise` | 風船が画面下から現れる（予告） | **無音** | きゅっ…（ゴムがこすれる短い音）。下からの危険の予告 | A |
| `fluff_storm_loop` | 綿毛の嵐が画面にあるあいだ。**ループ** | `storm_loop`（洗濯物のばさばさ入り） | ふわふわ舞う軽い風。4 秒前後でつながるループ | B |
| `geese_scatter` | 渡り鳥がキャンディで逃げる | `pigeon_scatter` を低く（鳩の声が入る） | ばさっ＋がー（雁の声） | B |
| `windmill_loop` | 画面端の風車がいるあいだ。**ループ** | `vane_spin`（小さな風見鶏のきぃきぃ） | ぎぃ…ごとん、と木の大きな軋み。1〜2 秒のループ | B |
| `boss2_start` | ボス戦開始（STAGE 1 の「コケーッ」にあたる） | **無音** | ごごん…と大きな歯車がかみ合う音 | B |
| `boss2_blades_loop` | ボス戦のあいだ羽根が回る。**ループ** | `vane_spin` | `windmill_loop` より低く重い軋み | B |
| `geese_incoming` | 渡り鳥の隊列が来る（予告） | `pigeon_incoming` を低く | ばさばさ（大きな鳥の群れ） | C |
| `fluff_pop` | 綿毛がキャンディで吹き飛ぶ | `laundry_pop` を高く | ふわっ | C |
| `flour_throw` | ボスが小麦粉の袋を投げる | `arrow_volley` を低く | ひゅっ（重い袋が飛ぶ） | C |
| `tree_rustle` | 森の大木を越える | **無音** | ざわざわ（葉擦れ）。STAGE 1 の教会の鐘にあたる目印 | C |

- **ループ**の 3 音は、置いたあと `.wav.import` の `edit/loop_mode=2` にする（`storm_loop.wav.import` と同じ）
- 優先: **A** 遊びの手応えや危険の予告に直結 / **B** あると気持ちいい / **C** 余裕があれば（`docs/sound_effects.md` と同じ基準）
- 作り方: `tools/sfx/make_se.py` に音の作り方を足して `python tools/sfx/make_se.py balloon_pop` のように書き出す。44.1kHz / 16bit / モノラル、音量は `LOUD` で揃える、音程は変ホ長調／ハ短調の音

### 3-2. そのまま流用で合っている音（作らなくてよい）

| 場面 | 鳴らしている音 |
| --- | --- |
| 横風の予告／横風 | `gust_warning` → `gust`（風上から聞こえるように定位） |
| ボスの突風の予告／突風 | 同上 |
| ボス登場 | `boss_appear`（ぎぎぎ…の軋みが風車に合う） |
| 小麦粉の袋が破れる | `smoke_in`（ぼふっ） |
| ボスが満足して帆をたたむ | `boss_satisfied` → `boss_leave` |
| 猫・キャンディ・勇気のかけら・被弾・UI など | STAGE 1 と共通（`docs/sound_effects.md`） |

---

## 4. 素材を入れたら確かめること

- [ ] `godot --headless --quit --path godot` でエラー・警告がゼロ
- [ ] `verify_stage2.gd` が通る（素材を入れても挙動は変わらないので、通らなければ置き場所かファイル名の間違い）
- [ ] 実画面で: 原点（羽根の軸・風船の中心）がずれていない、羽根の見た目と当たり判定が合っている、向き（渡り鳥は右向き）が正しい
- [ ] `docs/progress.md` と、このドキュメントの「0. 全体像」の数を更新する
