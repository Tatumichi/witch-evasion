# 効果音（SE）

STAGE 1 の効果音の一覧と、鳴らす場面。音源は第 1 稿（合成）で、`godot/assets/audio/se/` にある。ゲームへの組み込み（各イベントで鳴らす処理）はまだ。

- 生成: `python tools/sfx/make_se.py`（リポジトリのルートで。名前を渡すとその音だけ作り直す）。必要: `pip install numpy scipy`
- 形式: 44.1kHz / 16bit / モノラル WAV。左右の定位はゲーム側（AudioStreamPlayer2D やパン）で付ける
- 音色: BGM がピアノ独奏なので、ベル・チェレスタ・やわらかい打楽器系に寄せる。音程のある音は変ホ長調／ハ短調の音（E♭ G B♭ C D F A♭）から選び、BGM と濁らないようにする
- 音量: 最も大きい 100ms 区間の RMS で揃えてある（`make_se.py` の `LOUD`）。予告・危険は大きめ、連発するもの・UI は小さめ。ピークは −1dBFS 以下
- 優先度: **A** 遊びの手応えや危険の予告に直結する／**B** あると気持ちいい／**C** 余裕があれば

## メルル

| ファイル | 場面 | 鳴らすところ | 音 | 優先度 |
| --- | --- | --- | --- | --- |
| `hit` | 被弾・帽子が飛ぶ | `stage1.gd` `_on_damaged` | ぽこっ＋帽子がひらっ | A |
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

## 組み込むときの注意

- **連発するものは間引く**: キャンディ・鳩・矢印・洗濯物はボス戦で重なる。同じ SE の同時発音は 2〜3 本までにし、`pitch_scale` を少し揺らす
- **予告音を優先**: `gust_warning` と `pigeon_incoming` はほかの SE より後回しにしない（同時発音の上限で削られないようにする）
- **ループ音**: `vane_spin` と `storm_loop` は `.wav.import` で `edit/loop_mode=2`（前方ループ）にしてある。止めるときは短いフェードを付ける
- **セリフのボイス**は別枠。「ひゃっ！」「けほっ」などに声を付けるかは別に決める
