# 効果音（SE）

効果音の一覧と、鳴らす場面。音源は第 1 稿（合成）で、`godot/assets/audio/se/` にある。全 55 音（STAGE 1 と共通 42 音、STAGE 2 専用 11 音、ステージ選択 2 音）をゲームに組み込み済み。

- 鳴らすところの関数は、全ステージ共通の進行（被弾・猫・キャンディ・結果など）が `stage_base.gd`、STAGE 1 固有（鳩・煙突・教会の鐘）が `stage1.gd`
- 再生: `godot/scripts/stage/sfx.gd`（各ステージのシーンの `SFX` ノード）。鳴らす側は `Sfx.fire(self, "hit", {"x": 位置, "pitch_jitter": 0.05})`、ループは `Sfx.loop_on(self, "vane_spin")` / `Sfx.loop_off(...)`（参照カウント）
- 検証: `godot --headless --path godot --fixed-fps 60 --script res://tests/verify_sfx.gd`（ステージを通して、各イベントで鳴ったかを `SFX.counts` で確かめる）
- ヘッドレス実行では実際の音は出さない（Godot は再生中のまま終了すると警告を出すため）。鳴らす判断と記録はそのまま動く

- 生成: `python tools/sfx/make_se.py`（リポジトリのルートで。名前を渡すとその音だけ作り直す）。必要: `pip install numpy scipy`
  - **作り直すときは名前を渡す**。全部を一度に作り直すと、STAGE 1 の `boss_appear`・`church_bell` は今のファイルと少し違う（ノイズの並びが変わる）音になる。2 音だけ個別に作り直した経緯があるため。STAGE 2 以降の音は音ごとに乱数を固定してあるので、どちらの作り方でも同じになる
- 形式: 44.1kHz / 16bit / モノラル WAV。左右の定位はゲーム側（AudioStreamPlayer2D やパン）で付ける
- 音色: BGM がピアノ独奏なので、ベル・チェレスタ・やわらかい打楽器系に寄せる。音程のある音は変ホ長調／ハ短調の音（E♭ G B♭ C D F A♭）から選び、BGM と濁らないようにする
- 音量: 最も大きい 100ms 区間の RMS で揃えてある（`make_se.py` の `LOUD`）。予告・危険は大きめ、連発するもの・UI は小さめ。ピークは −1dBFS 以下
- 優先度: **A** 遊びの手応えや危険の予告に直結する／**B** あると気持ちいい／**C** 余裕があれば

## メルル

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `hit` | 被弾・帽子が飛ぶ | `stage_base.gd` `_on_damaged` | ぽこっ＋帽子がひらっ | A |
| `hat_warning` | 帽子が残り 1 | 被弾後に `hats == 1` | 被弾音に重ねる短い警告 | B |
| `faint` | 目を回す（気絶） | `_faint` | くるくる下がる音＋ひよこ | A |
| `restart` | やり直し | `_restart_after_faint` | ふわっと立ち直る | C |
| `smoke_in` | 煙に入る | `smoke_changed(true)` | ぼふっ | B |
| `smoke_out` | 煙から出る | `smoke_changed(false)` | ふぁさっ | C |

## アイテム・猫

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `courage` | 勇気のかけら | `_on_courage` | きらっ。連続で取ったら `pitch_scale = 2 ** (n / 12.0)` で半音ずつ上げる（n は 0〜5 程度で頭打ち、少し間が空いたら 0 に戻す） | A |
| `hat_restore` | 帽子がもどった | かけら規定数で `hats += 1` | 明るい和音のチャイム | A |
| `bonus` | かけらボーナス +500 | 帽子が満タンのとき | チャリン | B |
| `cat_fall` | 猫が落ちてくる | `_spawn_cat`、ボスの `drop_cat` | にゃっ＋ひゅ〜 | A |
| `cat_catch` | 猫を受け止める | `_on_cat_caught` | ぽふっ＋にゃ〜ん | A |
| `cat_miss` | 猫を取り逃がす | `_on_cat_missed` | ひゅ〜…（控えめ） | B |
| `candy_fire` | キャンディ発射 | `_fire_candy`（自動連射） | ぽんっ。`pitch_scale` を 0.95〜1.05 で揺らす | A |
| `candy_hit` | キャンディが当たる | `candy.broke` | ぽふ＋きらきら | B |
| `candy_eat` | ボスがキャンディを食べる | `candy.fed` → `feed()` | もぐっ＋ぴろっ | A |
| `barrier_on` | 白猫のバリア | 白猫を受け止めたとき | しゃらん | B |
| `cat_effect_warn` | 効果が切れそう | 残り 2 秒から 0.5 秒ごと | かちっ | B |
| `cat_effect_end` | 猫の効果が切れる | `_end_cat_effect` | ふしゅ〜 | B |

## 道中

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `pigeon_incoming` | 鳩の列が来る | `_spawn_pigeon_row` | ばさばさっ（出現の予告） | A |
| `pigeon_scatter` | 鳩が逃げる | `pigeon.break_apart` | ばさっ＋くるっぽー | B |
| `vane_spin` | 風見鶏（小）の回転 | `weathervane.gd` が画面にいるあいだ | きぃきぃ。**ループ**（1 秒）。画面内の数に関係なく 1 本だけ鳴らす | B |
| `laundry_pop` | 洗濯物がはじける | `laundry.break_apart` | ぱさっ | C |
| `chimney_puff` | 煙突の煙 | `_spawn_smoke` | しゅぽっ | C |
| `church_bell` | 教会の塔を越える | `tower_passed` | からーん。3 匹目の猫「教会の鐘から」とつながる | B |

## ボス：大風見鶏

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `boss_appear` | 登場 | `_enter_boss_intro` | ぎぎぎ…と軋む | A |
| `boss_crow` | 戦闘開始 | `begin_fight` | コケーッ！ | B |
| `arrow_volley` | 矢印の一斉発射 | `boss_weathervane.gd` `_fire_volley` | ひゅんひゅんっ | A |
| `gust_warning` | 突風の予告 | GUST 開始〜1 秒（回転が速くなる） | 軋みの間隔が詰まり、音程が上がる。**よける合図** | A |
| `gust` | 突風 | GUST 1〜4 秒（押し流される） | ごおおっ（3.2 秒）。風向き `_gust_dir` にパン | A |
| `storm_loop` | 洗濯物の嵐 | STORM のあいだ | 風＋ばさばさ。**ループ**（4 秒） | B |
| `boss_satisfied` | 満足ゲージ満タン | `satisfied` | ぽわーん | A |
| `boss_koke` | 「……コケッ。」 | クリアのセリフ | 小さなコケッ | B |
| `boss_leave` | 去っていく | `Mode.LEAVE` | 回転がゆっくり止まる | C |
| `god_voice` | 神々のつぶやき | `hud.god_say`（クリア後） | ハープ | C |

## UI・進行

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `ui_start` | タイトルで決定 | `_unhandled_input` → `start_stage` | ピアノのアルペジオ | A |
| `stage_card` | ステージ名の表示 | `stage_hud.gd` `show_stage_card` | しゃらーん | B |
| `talk_meruru` | セリフ（メルル） | `hud.say` | ぽっ | B |
| `talk_god` | セリフ（神々） | `hud.god_say` | 天上のベル | B |
| `pop_score` | スコアのポップ | `_pop_text` | ぴっ | C |
| `gauge_show` | ボスゲージ表示 | `show_boss_gauge(true)` | かちっ | C |
| `result_line` | リザルトの 1 行 | `show_result` | ぽん（1 行ごと） | B |
| `new_best` | NEW BEST | 最高スコア更新 | ファンファーレ | B |
| `ui_select` | タイトルで ←→（ステージを選ぶ） | `stage_base.gd` `_unhandled_input` | 小さなチェレスタ | B |
| `ui_locked` | まだ遊べないステージで決定 | 同上 | こもった低い 2 音（D → C）。責める感じにしない | B |

## STAGE 2「丘と森の上空」

STAGE 2 のスクリプトは**専用の名前**で鳴らす。11 音とも専用の `<名前>.wav` があるので、そちらが鳴る。ファイルを消すと `sfx.gd` の `FALLBACK` が右端の列の既存音に振り替える（作り直すときの一時しのぎ）。

| 名前（専用音） | 場面 | 鳴らすところ | 音 | 優先度 | ファイルが無いときの代わり |
| --- | --- | --- | --- | --- | --- |
| `balloon_pop` | 風船が割れる | `balloon.gd` `_pop` | ぱんっ。頭だけ鋭く、30ms で 20dB 下がる | A | `candy_fire`（音程 0.62・+3dB） |
| `balloon_rise` | 風船が画面下から来る（予告） | `stage2.gd` `_spawn_balloon` | きゅっ（ゴムがこすれる。B♭5 から上がって少し戻る） | A | 無音 |
| `fluff_storm_loop` | 綿毛の嵐が画面にあるあいだ。**ループ**（4 秒） | `fluff.gd`（嵐の綿毛、参照カウント） | 高めの柔らかい風＋ときどき小さな「ふわっ」 | B | `storm_loop` |
| `fluff_pop` | 綿毛が吹き飛ぶ | `fluff.gd` `break_apart` | ふわっ（上へ抜ける空気） | C | `laundry_pop`（音程 1.35） |
| `geese_incoming` | 渡り鳥の隊列が来る（予告） | `stage2.gd` `_spawn_geese_v` | 大きな羽ばたき 4 羽ぶん＋遠くの「がー」 | C | `pigeon_incoming`（音程 0.85） |
| `geese_scatter` | 渡り鳥が逃げる | `goose.gd` `break_apart` | ばさっ＋がー、がー | B | `pigeon_scatter`（音程 0.82） |
| `windmill_loop` | 画面端の風車がいるあいだ。**ループ**（2 秒） | `windmill.gd`（参照カウント） | ぎぃ…ごとん（木の軋みと、一回りごとの打撃） | B | `vane_spin` |
| `tree_rustle` | 森の大木を越える | `stage2.gd` `_on_tree_passed` | ざわざわ（葉擦れ）＋遠くの小鳥 | C | 無音 |
| `boss2_start` | ボス戦開始 | `boss_windmill.gd` `begin_fight` | ごごん…（木の歯車がかみ合う） | B | 無音 |
| `boss2_blades_loop` | ボス戦のあいだ羽根が回る。**ループ**（2 秒） | `boss_windmill.gd` | 低く重い軋み＋羽根が風を切る「ぶぉん」 | B | `vane_spin` |
| `flour_throw` | 小麦粉の袋を投げる | `boss_windmill.gd` `_throw_bag` | ひゅっ（重い袋）＋布のはためき | C | `arrow_volley`（音程 0.8・−3dB） |

`FALLBACK` で付けていた音程・音量の調整は、代わりの音にだけかかる。専用音はそのまま鳴る。

既存音をそのまま使っている場面:

| 音 | 場面 | 鳴らすところ |
| --- | --- | --- |
| `gust_warning` → `gust` | 横風の予告 → 横風（風上に定位） | `stage2.gd` `start_wind` / `stage_process` |
| `gust_warning` → `gust` | ボスの突風 | `boss_windmill.gd` |
| `boss_appear` | ボス登場 | `stage_base.gd`（`se_boss_appear`） |
| `smoke_in` | 小麦粉の袋が破れる | `flour_bag.gd` |
| `boss_leave` | 帆をたたんで帰る | `boss_windmill.gd`（満足の 0.5 秒後） |

検証: `verify_stage2.gd` が、専用の名前で鳴ったこと、振り替え先（代わりの音）が鳴っていないことを `SFX.counts` で確かめる。ステージ選択の 2 音は `verify_flow.gd`。

## 再生のしくみ（sfx.gd）

- **連発の間引き**: 同じ音の同時発音数を `MAX_VOICES` で制限（既定 2、キャンディ 2・鳩が逃げる 1 など）。上限に達したら一番古いものを鳴らし直す
- **優先**: 全体 14 本が埋まったら、`PRIORITY` 以外の一番古い音を止める。`gust_warning`・`pigeon_incoming`・`hit`・`cat_fall` などの予告と手応えは削らない
- **音程の揺らし**: キャンディ・煙突・洗濯物・鳩などは `pitch_jitter` で毎回少し変える。勇気のかけらは 0.6 秒以内に続けて拾うと半音ずつ上がる（最大 7 段）
- **定位**: `x`（0〜540）で左右に置く。突風は風上から聞こえる
- **ループ音**: `vane_spin`（小さな風見鶏が画面にいるあいだ、何羽いても 1 本）、`storm_loop`（STORM のあいだ）、STAGE 2 の `fluff_storm_loop`・`windmill_loop`・`boss2_blades_loop`。`.wav.import` で `edit/loop_mode=2`。止めるときは 0.3 秒でフェード
- **振り替え（FALLBACK）**: 専用音がまだ無い名前を既存音に振り替える。`[代わりの音, opts]` の opts は呼び出し側に重ねる（音程は掛け算、音量は足し算）。代わりが `""` なら鳴らさずに記録だけする。`SFX.counts` には頼まれた名前と実際に鳴らした名前の両方が残る。ループは頼まれた名前ごとに数える
- **音量**: SE 全体は `volume_db = -3`。BGM は −6dB
- **セリフのボイス**は別枠。「ひゃっ！」「けほっ」などに声を付けるかは別に決める
