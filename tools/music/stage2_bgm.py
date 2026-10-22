"""見習い魔女メルル ステージ2「丘と森の上空」 ピアノ曲 — MIDI 生成とゲーム用ループ OGG の書き出し

使い方（リポジトリのルートで）:  python tools/music/stage2_bgm.py
  - art/music/stage2_oka_to_mori_loop.mid          … 編集・差し替え用の原本（loop_start / loop_end マーカー付き）
  - godot/assets/audio/bgm/stage2_oka_to_mori.ogg  … ゲーム用（イントロ＋ループ本体。余韻はループ頭に折り返し済み）
必要: pip install mido numpy scipy、ffmpeg（libvorbis）

曲の狙い（docs/music.md）:
  - 変ホ長調・4/4・88（STAGE 1 の 80 から 1 割速く。スクロール 1.1 倍に合わせる）
  - 左手は 3 連符で上がって下がる「揺れる」伴奏（12/8 の感じ）。STAGE 1 のまっすぐな 8 分と変える
  - B は横風: ハ短調に陰り、揺れの幅と強弱の波を大きくする
  - C は大木とわた雲: メルルのテーマ（村の空の冒頭 B♭–G–F）を引用し、最後に A♭m6（STAGE 1 と同じ借用和音）
"""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm
from common import mel, n
import stage1_bgm as s1

BPM = 88
cm.set_tempo(BPM)
random.seed(22)
T = 1 / 3   # 3 連符の 8 分

# ---------------------------------------------------------------- 楽曲データ（1 小節 = 4 拍）
# 和音は 1 小節に 1 つ、または [(拍数, 名前), ...]
INTRO = (['Ebadd9', 'Abmaj7/Eb', 'Ebadd9', [(2, 'Bbsus4'), (2, 'Bb')]],
         ['R:2 Bb5:2/3 G5:1/3 F5:1', 'G5:2 Eb5:2', 'R:2 Bb5:2/3 G5:1/3 F5:1', 'Eb5:2 D5:2'])

A = (['Eb', 'Gm7', 'Abmaj7', 'Bb', 'Cm7', 'Abmaj7', 'Fm7', [(2, 'Bb7sus4'), (2, 'Bb7')]],
     ['Bb4:1 Eb5:2/3 F5:1/3 G5:2', 'F5:2/3 G5:1/3 F5:1 D5:2', 'C5:1 Eb5:1 G5:1 Ab5:1', 'G5:2/3 F5:1/3 D5:1 Bb4:2',
      'Eb5:2/3 F5:1/3 G5:1 Bb5:2', 'Ab5:2/3 G5:1/3 Eb5:1 C5:2', 'C5:1 Eb5:1 Ab5:2/3 G5:1/3 F5:1', 'Eb5:2 D5:2'])

A2 = (['Eb', 'Gm7', 'Abmaj7', 'Bb/Ab', 'Gm7', 'Cm7', [(2, 'Fm7'), (2, 'Bb7')], 'Eb'],
      ['Bb4:1 Eb5:2/3 F5:1/3 G5:2', 'F5:2/3 G5:1/3 F5:1 D5:2', 'C5:1 Eb5:1 G5:1 Ab5:1', 'G5:2/3 F5:1/3 D5:1 F5:2',
       'G5:1 Bb5:1 D6:2', 'C6:2/3 Bb5:1/3 G5:1 Eb5:2', 'F5:1 Ab5:1 G5:2/3 F5:1/3 D5:1', 'Eb5:3 R:1'])

# 横風（ハ短調）。ため息のように短く切る
B = (['Cm', 'Ab', 'Eb/G', 'Bb', 'Cm', 'Ab', 'Fm7', 'G7'],
     ['G5:2 Eb5:2/3 D5:1/3 C5:1', 'C5:2/3 D5:1/3 Eb5:1 Ab5:2', 'G5:2 F5:2/3 Eb5:1/3 Bb4:1', 'D5:3 R:1',
      'G5:2 Eb5:2/3 D5:1/3 C5:1', 'C6:2 Bb5:2/3 Ab5:1/3 G5:1', 'Ab5:2/3 G5:1/3 F5:1 C5:1 Eb5:1', 'D5:2 B4:2'])

# 大木とわた雲。メルルのテーマ（B♭–G–F）をオクターブで
C = (['Abmaj7', 'Bb', 'Gm7', 'Cm7', 'Abmaj7', 'Bb', 'Eb/G', 'Abm6'],
     ['Bb5:2 G5:2', 'F5:3 Eb5:2/3 F5:1/3', 'G5:2 Eb5:2', 'D5:2 C5:1 Bb4:1',
      'C5:2/3 Eb5:1/3 Ab5:1 C6:2', 'Bb5:2/3 Ab5:1/3 G5:1 F5:2', 'G5:2/3 Ab5:1/3 Bb5:1 Eb6:2', 'Eb6:1 Cb6:1 Ab5:2'])

# つなぎ。最後の小節で 3 連符を駆け上がって A の頭（B♭4）へ戻る
D = (['Eb/Bb', 'Bb7sus4', 'Bb7', 'Bb7'],
     ['G5:2 F5:2/3 Eb5:1/3 D5:1', 'Eb5:4', 'D5:2 F5:2',
      'R:1 Bb4:1/3 C5:1/3 D5:1/3 Eb5:1/3 F5:1/3 G5:1/3 Ab5:1/3 G5:1/3 F5:1/3'])

END = (['Eb', 'Eb'], ['G5:1 Bb5:1 Eb6:2', 'R:4'])


# ---------------------------------------------------------------- 伴奏

def chord_tones(name):
    """左手の音: ベース、5 度、10 度（上の和音）…の 5 音を低い順に。"""
    pcs, b = s1.chord(name)
    bn = s1.bass_note(b)
    up = sorted({bn + 12 * k + ((p - bn) % 12) for p in pcs for k in range(1, 3)
                 if bn + 7 <= bn + 12 * k + ((p - bn) % 12) <= bn + 24})
    return bn, up[:4] if len(up) >= 4 else (up + [bn + 24])[:4]


def sway(name, start, beats, vel, wide=False, swell=None):
    """3 連符で上がって下がる伴奏。1 拍目にベース、そのあと 0-1-2-3-2-1 の波。
    wide: 横風の B。波が 1 音高くまで届く。swell(t): 強弱の波（0〜1）"""
    bn, up = chord_tones(name)
    wave = [0, 1, 2, 3, 2, 1] if not wide else [0, 1, 2, 3, 3, 2]
    out = [(bn, start, beats + 0.4, vel + 8)]
    if wide:
        out.append((bn - 12 if bn - 12 >= 28 else bn, start, beats + 0.4, vel))
    steps = int(round(beats / T))
    for i in range(1, steps):
        t = start + i * T
        idx = wave[i % 6]
        p = up[min(idx, len(up) - 1)] + (12 if wide and i % 6 == 4 else 0)
        g = swell(t) if swell else 0.5
        v = vel - 10 + int(10 * g) - (3 if i % 3 else 0)
        # 次の和音まで鳴らしっぱなし（ペダル）
        out.append((p, t, (start + beats) - t + 0.3, v))
    return out


def section(spec, t0, lv, rv, wide=False, octave=False, swell=None):
    chords, melodies = spec
    L, Rh, t = [], [], t0
    for bar, (cbar, mbar) in enumerate(zip(chords, melodies)):
        cbar = [(4, cbar)] if isinstance(cbar, str) else cbar
        ct = t
        for beats, name in cbar:
            L += sway(name, ct, beats, lv, wide, swell)
            ct += beats
        mt = t
        for p, d in mel(mbar):
            if p is not None:
                v = rv + (6 if abs(mt - round(mt)) < 1e-6 and int(round(mt)) % 4 == 0 else 0) + random.randint(-4, 3)
                if swell:
                    v += int(8 * swell(mt)) - 4
                Rh.append((p, mt, d, v))
                if octave and p >= n('C5'):
                    Rh.append((p - 12, mt, d, v - 14))
            mt += d
        t += 4
    return L, Rh, t


def build(preview):
    L, Rh, t, marks = [], [], 0.0, {}

    def add(res):
        nonlocal L, Rh, t
        l, r, t = res
        L += l; Rh += r

    add(section(INTRO, t, 42, 62))
    loops = 2 if preview else 1
    for lp in range(loops):
        if lp == 0:
            marks['loop_start'] = t
        add(section(A, t, 48, 74))
        add(section(A2, t, 48, 76))
        # 横風: 2 小節で一度、押し寄せて引く強弱の波
        t0 = t
        add(section(B, t, 50, 76, wide=True, swell=lambda x, t0=t0: 0.5 - 0.5 * math.cos(math.pi * ((x - t0) % 8) / 4)))
        add(section(C, t, 54, 82, octave=True))
        add(section(D, t, 46, 70))
        if lp == 0:
            marks['loop_end'] = t
    if preview:
        add(section(END, t, 40, 60))
        for p in (n('Eb3'), n('Bb3'), n('G4'), n('Eb5')):
            Rh.append((p, t - 4, 6, 48))
    return L, Rh, t, marks


if __name__ == '__main__':
    L, Rh, tb, m = build(False)
    cm.write_midi('art/music/stage2_oka_to_mori_loop.mid', 'Stage2 Oka to Mori no Joku', 'Eb', (4, 4), BPM, L, Rh, m)
    print('stage2 loop sec', s1.export_loop('godot/assets/audio/bgm/stage2_oka_to_mori.ogg', L, Rh, m['loop_start'], m['loop_end']))
    if '--preview' in sys.argv:
        L, Rh, tb, m = build(True)
        s1.render('stage2_preview.wav', L, Rh, tb)
        print('preview sec', tb * s1.BEAT)
