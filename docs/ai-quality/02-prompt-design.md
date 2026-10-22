# 破綻しないプロンプト設計 — ComfyUI / NoobAI-XL 1.1

**調査レポート #02** / 前提: [01 AIイラストはなぜ「AIっぽい」のか](01-why-ai-looks-ai.md)

---

## 0. この文書の位置づけ

01 で整理した破綻の4層（L1 構造 / L2 物理・光学 / L3 質感 / L4 構図）を、**実際のモデル選定・プロンプト・パラメータ**に落とす。

結論を先に書くと、プロンプトで直せるのは主に **L1の一部とL2の一部** まで。L3（高周波）とL4（構図の意図）はプロンプトでは動かない。だからこの文書は「呪文の集め方」ではなく、**破綻しにくい構図に寄せる設計**として読んでほしい。

---

## 1. モデル選定

### 1.1 結論

| 役割 | モデル | 理由 |
|---|---|---|
| **主軸** | **NoobAI-XL 1.1** | タグ語彙が最も広く、公式が推奨設定とネガまで公開している。NSFW込みで破綻が少ない |
| **商用可が必要なら** | **Illustrious-XL v2.0** | CreativeML OpenRAIL-M で商用利用可。同じ Illustrious 系なのでタグ文法が互換 |
| **既存（残す）** | **Animagine XL 4.0** | 導入済み。商用可。SFW寄りで、ゲームの見た目を統一したいときに使う |

3つとも SDXL 系（6.9〜7.1GB）なので、**RTX 3060 12GB で 832×1216 は余裕**。追加の量子化も軽量化も要らない。

### 1.2 比較

| | NoobAI-XL 1.1 | Illustrious-XL v2.0 | Animagine XL 4.0 |
|---|---|---|---|
| ベース | SDXL → Illustrious | SDXL | SDXL 1.0 |
| 学習データ | Danbooru（2024-10頃）＋ e621 | Danbooru 系 | 8.4M画像（〜2025-01） |
| サイズ | 7.11 GB | 6.94 GB | 6.94 GB |
| ライセンス | **FAI-PL 1.0-SD（商用禁止）** | CreativeML OpenRAIL-M（商用可） | CreativeML OpenRAIL++-M（商用可） |
| NSFW | ◎（e621 も学習） | ○（ベースに含む） | △（SFW寄り） |
| 推奨解像度 | 832×1216 ほか | 1024級（832×1216推奨） | 1024級（832×1216推奨） |
| 推奨 CFG / Steps | 5〜6 / 25〜30 | 5〜6 / 28（コミュニティ慣例） | 4〜7（5推奨）/ 28 |
| 推奨サンプラー | Euler a | Euler a | Euler a |
| プロンプト文法 | booruタグ中心＋prefix必須 | booruタグ | タグ＋**順序指定が厳格** |

### 1.3 ライセンスの注意（ここは飛ばさない）

**NoobAI-XL 1.1 は商用利用を禁止している。** ライセンス本文に「モデル・派生モデル・生成物のいずれについても、いかなる形の商用化も禁止する」と明記されている。加えて、派生モデルやLoRAを公開する場合はオープンソース化とワークフロー共有が義務。

- 個人利用・無償配布のゲーム → 問題になりにくい
- 販売・投げ銭・広告収益・受託制作 → **使わない**
- その場合は Illustrious v2.0 か Animagine 4.0 に切り替える

ゲームを後で売る可能性があるなら、最初から **Illustrious v2.0** を主軸にした方が安全だ。判断はプロジェクト側で決めてほしい。

### 1.4 VRAM の見積もり

| 解像度 | 推定ピーク | 12GB 判定 | 備考 |
|---|---|---|---|
| 832×1216 | 8〜10 GB | ○ | 標準。1枚 20〜25秒（3060実測ベース） |
| 1024×1024 | 7〜9 GB | ○ | アイコン・バストアップ向け |
| 1216×832 | 8〜10 GB | ○ | 横長の背景・シーン向け |
| 1536×1536 | 14 GB〜 | × | tiled VAE / offload が必要。今回は使わない |

※ 概算。Windows の ComfyUI はモデルをシステムRAMに逃がすので、VRAM が足りなくても極端に遅くなるだけで落ちないことが多い。

---

## 2. セットアップ

### 2.1 ダウンロード

PowerShell か cmd で:

```powershell
curl.exe -L -o "C:\AI\ComfyUI\models\checkpoints\NoobAI-XL-v1.1.safetensors" `
  "https://huggingface.co/Laxhar/noobai-XL-1.1/resolve/main/NoobAI-XL-v1.1.safetensors"
```

商用可のほうを使う場合:

```powershell
curl.exe -L -o "C:\AI\ComfyUI\models\checkpoints\Illustrious-XL-v2.0.safetensors" `
  "https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0/resolve/main/Illustrious-XL-v2.0.safetensors"
```

### 2.2 確認

```bash
python tools/comfy.py models
```

```
  NoobAI-XL-v1.1.safetensors  6.62 GiB
  animagine-xl-4.0.safetensors  6.46 GiB

presets:
  noobai      ready    NoobAI-XL 1.1 (tags+NSFW, non-commercial)
  illustrious missing  Illustrious-XL v2.0 (commercial ok)
  animagine   ready    Animagine XL 4.0 (commercial ok, mostly SFW)
```

`ready` になっていれば使える。VAE はモデル内蔵なので追加不要。

### 2.3 プリセットの仕組み

`tools/comfy.py` はモデルごとの「品質タグ・ネガ・CFG・steps・サンプラー・解像度」を**プリセットとして一括管理**する。モデルを変えたらプロンプト文法も変わるので、これを手で管理しないための仕組み。

```bash
# 導入済みのうち優先順（noobai → illustrious → animagine）で自動選択
python tools/comfy.py gen --prompt "1girl, solo, witch, standing"

# 明示指定
python tools/comfy.py gen --preset noobai --prompt "1girl, solo, witch, standing"

# 品質タグを自分で書く場合（プリセットの自動付与を止める）
python tools/comfy.py gen --preset noobai --no-quality-tags --prompt "masterpiece, best quality, 1girl, ..."
```

`--preset` を付けると、プロンプト先頭に品質タグが自動で入り、ネガとパラメータもそのモデル用になる。**本文には品質タグを書かない**のが約束。

---

## 3. プロンプト設計の6原則

### 原則1: プロンプトは「制約」ではなく「確率の偏り」

これが最重要。プロンプトは「指を5本にしろ」という命令ではない。学習分布のどこに寄せるかという**重み付け**にすぎない。

だから:
- 破綻の**除去**には弱い（`bad hands` を書いても手は直らない）
- 破綻の**回避**には強い（手が写らない構図にすれば破綻しない）

**「描かせない」が最強の修正テクニック**である。

### 原則2: 原因を書く（光・素材・接地・機能）

01 の結論「AIは結果だけを学び原因を学ばない」への直接の対処。破綻しやすい要素には、**その物理的な原因をセットで書く**。

| 結果だけ書く（弱い） | 原因も書く（強い） |
|---|---|
| `1girl, holding sword` | `1girl, holding sword, sword blade reflecting the sunset, metal guard with specular highlight` |
| `1girl, witch` | `1girl, witch, backlit by moonlight, rim light on hat brim` |
| `1girl, sitting` | `1girl, sitting on wooden floor, contact shadow under her, ambient occlusion at the skirt` |

ただし**タグを増やしすぎると attention が分散する**。1つの破綻に対して2〜3語まで。

### 原則3: 一度に描かせない

01 で見た「局所最適の寄せ集め」は、要素を増やすほど悪化する。だから:

- 人数は必ず1人（`solo`, `1girl`）から始める
- 小物は1つまで。`holding A, holding B` は溶接の温床
- 背景は `simple background` で逃がすか、**別生成して合成**
- 手は「何も持たない・隠す・単純な形を持つ」に寄せる

### 原則4: 大域制約はプロンプトでなく構造で与える

消失点・骨格・光源方向は、言葉では制御できない。ここは割り切って別の道具を使う。

| 制約 | プロンプトでやる | 実際に効く手段 |
|---|---|---|
| ポーズ・骨格 | `standing`, `from side` 程度 | **ControlNet OpenPose** |
| 構図・配置 | ほぼ無理 | **ControlNet Depth / Canny**、ラフのimg2img |
| 光源方向 | `backlighting` などで限定 | 3Dレイアウト、後処理の乗算レイヤ |
| 消失点 | `wide shot` 程度 | Depth ControlNet |

プロンプトで「構図を指定した気になる」のが一番の時間泥棒だ。

### 原則5: 高周波と不完全さを足す

01 の L3（VAE圧縮で質感が落ちる）への対処。**「きれい」を消して「質感」を足す**。

- 足す: `film grain`, `painterly`, `brushstrokes`, `detailed skin`, `textured`
- 消す（ネガ）: `smooth`, `airbrushed`, `plastic`, `waxy`, `glossy`
- 構図側: 髪を `messy hair`, `stray hair` にして非対称を作る

※ `film grain` などは booru タグとして実在する。`ambient occlusion` や `contact shadow` は**自然言語**で、Illustrious系は部分的に解釈するが保証はない。効かなければ後処理で足す。

### 原則6: モデルの文法に従う

品質タグの語彙はモデルごとに違う。混ぜると出力が崩れる。

| モデル | 品質タグ | 置き場所 |
|---|---|---|
| NoobAI | `masterpiece, best quality, newest, absurdres, highres` | **先頭**（prefixとして） |
| Illustrious | `masterpiece, best quality, very aesthetic, absurdres` | 先頭 |
| Animagine 4.0 | `masterpiece, high score, great score, absurdres` | カードは**末尾**を推奨 |
| Pony系 | `score_9, score_8_up, ...` | 先頭 |

`--preset` はこれを自動でやる。手で書くときは混ぜないこと。

---

## 4. テンプレート

### 4.1 基本構造

```
[品質タグ（プリセットが付与）]
, [人数] , [キャラ/作品名] , [レーティング]
, [ポーズ・動作]
, [構図・カメラ]
, [服装・小物（1つまで）]
, [光源・時間帯]
, [背景]
, [質感・スタイル]
```

前半（人数・キャラ・レーティング）は固定し、**後半だけ差し替える**と、シリーズ内で見た目が揃う。

レーティングはプリセットの prefix に `safe` が入っているので、通常は本文に書かない。`sensitive` 以上にするときは [4.5](#45-nsfw-のレーティング制御) の手順で prefix ごと差し替える。

### 4.2 キャラ単体（ゲームスプライト向け）

```text
1girl, solo, witch, original,
chibi, super deformed, standing, arms at sides, full body, front view,
long sleeves, sleeves past wrists,
black dress, purple hair, witch hat,
white background, soft lighting, cel shading
```

ポイント:
- `chibi, super deformed` は破綻を減らす**構図的な回避策**でもある（指の本数が問題になりにくい）
- `arms at sides` で手のポーズを単純化。ただし**これだけでは手は隠れない**（手が出て崩れる）。袖で隠すなら `long sleeves, sleeves past wrists` を併用する
- `white background` は透過処理の前工程として有効
- 色を残すなら `cel shading` まで。`flat color` に `clean lineart` と `thick outlines` を重ねると**線画に潰れる**

**実測メモ**（NoobAI-XL 1.1 / 832×1216 / 28 steps / CFG 5.5 / seed 777）:

| プロンプト | 結果 | ファイル |
|---|---|---|
| `flat color, clean lineart, thick outlines` 付き | 白黒の線画になった（色が飛んだ） | `art/witch/template_check_s777.png` |
| それらを外して `cel shading` に変更 | 彩色された。ただし人物が小さくなり、台座とスポットライトを勝手に補った | `art/witch/template_check2_s777.png` |

後者の「台座」は `full body` ＋ 縦長キャンバス ＋ `white background` が「展示台に載ったフィギュア」の構図を呼んだため。**ゲーム用はトリミング前提で生成する**か、`cowboy shot` に寄せると安定する。

### 4.3 立ち絵

```text
1girl, solo, witch, original,
standing, hand on chest, looking at viewer,
cowboy shot, three-quarter view,
black robe, purple ribbon, oversized hat,
window light from the left, soft shadow on the right,
gradient background,
detailed skin, fabric texture, painterly
```

ポイント:
- 光源を**1方向に限定**（`window light from the left`）。影の向きが決まる
- `three-quarter view` で奥行きを出すと、正面より破綻が減る（耳・鼻・顎の関係が曖昧になりにくい）
- `fabric texture` で高周波を補う

### 4.4 背景

```text
no humans, scenery, night sky, starry sky, full moon,
clouds, distant village, silhouette,
wide shot, vanishing point, depth of field,
moonlight, rim light, atmospheric perspective,
film grain
```

ポイント:
- キャラと同時に生成しない。**背景は背景だけで作る**（01 の「密度の不整合」対策）
- `wide shot` + `vanishing point` でパースの基準を作る
- `atmospheric perspective` で遠景の破綻を「霞」で隠す

### 4.5 NSFW のレーティング制御

NoobAI / Illustrious は Danbooru のレーティングタグで露出度を制御する。

| タグ | 意味 | 用途 |
|---|---|---|
| `safe` | 全年齢 | 通常のゲーム素材 |
| `sensitive` |  suggestive（水着・下着・扇情的） | ゲームの見せ場 |
| `nsfw` | 成人向け | — |
| `explicit` | 露骨 | — |

**手順（重要）**:

1. プリセットの prefix に入っている `safe` を、目的のレーティングに置き換える
2. **ネガから `nsfw` を外す**（NoobAI の公式ネガには `nsfw` が入っている。外さないと打ち消される）
3.  clothed 状態を保つなら `clothed`, `dress`, `pantyhose` など着衣タグを明示する

```powershell
# sensitive まで。ネガから nsfw を外し、prefix を差し替える
python tools/comfy.py gen --preset noobai --no-quality-tags `
  --prompt "masterpiece, best quality, newest, absurdres, highres, sensitive, 1girl, solo, witch, ..." `
  --negative "worst quality, old, early, low quality, lowres, signature, username, logo, bad hands, mutated hands"
```

`--no-quality-tags` を使うのは、prefix の `safe` を自分で置き換えるため。**`safe` を残したまま `sensitive` を足すと競合する。**

> 注: 本プロジェクトの成果物を配布する場合、レーティングとライセンス（1.3）の両方を確認すること。

### 4.6 悪い例 → 直した例

**例1: 抽象的すぎる**

```text
# 悪い
beautiful witch, amazing, cool, masterpiece, best quality, 8k, ultra detailed

# 良い
1girl, solo, witch, safe, standing, hand on hat, full body,
backlit by moonlight, rim light, night sky, simple background, film grain
```

抽象的語（`beautiful`, `amazing`, `cool`）は分布を動かさない。`8k, ultra detailed` の羅列は彩度とコントラストを上げるだけで、破綻も増える。

**例2: 持ち物が多い**

```text
# 悪い（溶接・指の破綻が起きる）
1girl, holding staff, holding book, holding lantern, holding potion

# 良い（1つに絞り、握りを単純化）
1girl, holding staff, staff in right hand, arms at sides, ...
```

**例3: 光源が書かれていない**

```text
# 悪い（影の方向がばらける）
1girl, standing in forest, detailed background

# 良い（光源を1つに限定）
1girl, standing in forest, dappled sunlight from above, light rays,
backlit, detailed background, film grain
```

---

## 5. 破綻別 処方箋

「ポジで書く」が効きやすい順。**それでも無理**の列が、プロンプトの限界を示す。

| 破綻 | ポジで書く（回避） | ネガ（補助） | それでも無理 → 代替 |
|---|---|---|---|
| 指の融合・本数 | `arms at sides`, `hands behind back`, 手を画面外に | `bad hands, extra fingers, fused fingers, missing fingers` | 手のアップを避ける / ControlNet lineart / inpaint |
| 腕の余剰 | `solo`, `1girl`, 上半身のみ | `extra arms, multiple arms` | 人数と向きを固定 |
| 瞳のハイライト不整合 | 光源を1つに限定する構図（`backlighting`, `rim light`） | — | 目を局部修正。ここはプロンプトで直らない |
| 影の方向不一致 | `window light from the left`, `sunlight from above` | `inconsistent lighting, multiple light sources` | 影は後処理で統一 |
| AO 欠落 | `ambient occlusion, contact shadow`（自然言語） | `flat lighting, flat shading` | 乗算レイヤで後入れ |
| 素材の混在 | `matte fabric`, `metal armor`, `leather belt` と素材を明示 | `plastic, glossy skin` | 素材ごとに塗り分け |
| つるつる・均質 | `film grain, painterly, brushstrokes, detailed skin` | `smooth, airbrushed, plastic, waxy` | 後処理でグレイン・テクスチャ |
| 背景が空っぽ | `detailed background, scenery` / 背景を**別生成** | — | 合成。これが最も確実 |
| 文字・ロゴの崩壊 | 文字を描かせない | `text, logo, watermark, signature, artist name` | 文字はUI側で載せる |
| パース破綻 | `wide shot`, `from side`, 消失点が1つの構図 | `fisheye` を避ける | Depth ControlNet |
| 小物の溶接 | 小物は1つ、`holding X` は片手・単純形状 | `merged objects` | 小物を別レイヤーで合成 |
| 定番構図の反復 | artist タグで画風を寄せる | — | ラフを描いて img2img / ControlNet |
| 顔だけ高精細 | `full body` で解像度を分散 | — | アップで別生成して合成 |

---

## 6. パラメータ

| プリセット | CFG | Steps | Sampler | Scheduler | 解像度 | ネガの要点 |
|---|---|---|---|---|---|---|
| noobai | 5.5 | 28 | euler_ancestral | normal | 832×1216 | 公式ネガ（`nsfw` 込み） |
| illustrious | 5.5 | 28 | euler_ancestral | normal | 832×1216 | 汎用ネガ |
| animagine | 5.0 | 28 | euler_ancestral | normal | 832×1216 | スコア系タグ込み |

- **CFG を上げすぎない**。7.5 以上は彩度・コントラスト過多で「AIっぽいギラつき」が出る。アニメ系は 5〜6 が適正
- **Steps は 28 前後**。増やしても破綻は直らない（L3 の質感がわずかに変わるだけ）
- **Euler a（euler_ancestral）** が3モデル共通の推奨。`dpmpp_2m + karras` でも動くが、公式推奨から外れる

---

## 7. アンチパターン

1. **品質タグの盛りすぎ** — `masterpiece, best quality, ultra detailed, 8k, hyperdetailed, ...` は attention を食い、彩度過多になる。モデル規定の3〜5語で十分
2. **モデル間のプロンプト混在** — Pony の `score_9` を NoobAI に書いても効かない。逆も同じ
3. **ネガの万能視** — ネガは「すでに起きた破綻」を消せない。構図で避けるのが先
4. **`holding` の多用** — 小物が増えるほど溶接と指の破綻が増える
5. **人数の曖昧さ** — `1girl, 2girls` のような矛盾。`solo` を基本にする
6. **抽象語** — `beautiful`, `amazing`, `cool`, `perfect` は分布を動かさない
7. **英語の長文** — Illustrious系はNLPも解釈するが、**タグのほうが確実**。長文は最後の手段
8. **`simple background` を全部に入れる** — 背景が必要な絵で使うと密度不足になる。用途で切り替える
9. **CFG 7.5 以上** — 破綻が増える。まず 5.5 に下げる
10. **1枚で全部やろうとする** — キャラ＋背景＋小物＋文字を同時に。分離生成が最短

---

## 8. 検証ループ

### 8.1 生成

```powershell
python tools/comfy.py gen --preset noobai `
  --prompt "1girl, solo, witch, standing, full body, window light from the left, simple background, film grain" `
  --name witch_test --out art/witch
```

ワークフローは `art/witch/witch_test_s<seed>.json` に保存されるので、seed とプロンプトが常に再現できる。

実測: 832×1216 / 28 steps / CFG 5.5 で **1枚 約20秒**（RTX 3060 12GB、NoobAI-XL 1.1）。

### 8.2 チェックリスト（10項目）

生成した画像を、この順で見る。**上から順に、見つけたら即ボツ**。

1. 指の本数・関節（手が写っているか）
2. 腕・脚の接続（胴から生えていないか）
3. 瞳のハイライト（左右で光源が一致しているか）
4. 影の方向（顔・体・床で同じか）
5. 接地部（足元・椅子・小物の下に暗がりがあるか）
6. 小物の機能（箒なら箒に見えるか、持てる形か）
7. 素材（金属と布と肌が区別できるか）
8. 輪郭線（途切れ・二重線がないか）
9. 背景（キャラとの密度差が不自然でないか）
10. 文字（存在するなら読めるか。読めないなら消す）

### 8.3 直し方の優先順位

```
破綻を見つけた
  ├─ 構図で回避できる → プロンプトを変えて再生成（最速・最安）
  ├─ 部分的に壊れている → inpaint で局所修正
  └─ 全体の整合が崩れている → 別生成して合成、または ControlNet で構造を与える
```

**「ネガを足して再生成」は最初にやらない。** ネガは確率を少し下げるだけで、構図が同じなら同じ破綻が出る。

---

## 9. 付録: タグ辞書

### 光

`backlighting` / `rim light` / `sunlight` / `light rays` / `god rays` / `window light` / `moonlight` / `dappled sunlight` / `dramatic lighting` / `soft lighting` / `chiaroscuro`

**コツ**: 「光源を1つに限定する」タグを選ぶ。`backlighting` は光源が後ろに1つと暗黙に決まるので、影の方向が安定する。

### 素材・質感

`metal` / `armor` / `leather` / `silk` / `lace` / `frills` / `sheer clothes` / `wet clothes` / `film grain` / `painterly` / `brushstrokes` / `detailed skin` / `textured`

### 構図・カメラ

`full body` / `upper body` / `cowboy shot` / `close-up` / `wide shot` / `from side` / `from above` / `from below` / `front view` / `dutch angle` / `depth of field` / `blurry background` / `vanishing point` / `foreshortening`（破綻しやすいので注意）

### 破綻回避（ポーズ）

`arms at sides` / `hands behind back` / `hand on hip` / `hand on chest` / `hand on hat` / `standing` / `sitting` / `solo`

### レーティング

`safe` / `sensitive` / `nsfw` / `explicit`

---

## 10. 参考

- [NoobAI-XL 1.1 モデルカード](https://huggingface.co/Laxhar/noobai-XL-1.1) — 推奨設定・品質タグのパーセンタイル定義・ネガ・ライセンス
- [Illustrious-XL v2.0 モデルカード](https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0) — ライセンス（OpenRAIL-M）
- [Illustrious-XL v1.0 モデルカード](https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.0) — 1536px native・NLP+タグ併用の記載
- [Animagine XL 4.0](https://huggingface.co/cagliostrolab/animagine-xl-4.0) — プロンプト順序・スコアタグ
- [FAI-PL 1.0-SD（NoobAI のライセンス本文）](https://freedevproject.org/faipl-1.0-sd/)
- 破綻の分類と原因は [01 AIイラストはなぜ「AIっぽい」のか](01-why-ai-looks-ai.md) を参照

---

*本ドキュメントのタグは Danbooru 由来のものを中心に、生成モデルで一般に通じる語を含めて記載している。自然言語での指示（`ambient occlusion` など）は効果が保証されないため、その旨を明記した。パラメータは各モデルカードの推奨値とコミュニティの慣例に基づく。*
