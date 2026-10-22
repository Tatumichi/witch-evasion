"""見習い魔女メルル ステージ2ボス「はぐれ大風車」 ピアノ曲（ハ短調・4/4）

使い方（リポジトリのルートで）:  python tools/music/boss2_bgm.py
  - art/music/boss2_hagure_fusha_loop.mid
  - godot/assets/audio/bgm/boss2_hagure_fusha.ogg

曲の狙い（docs/music.md）:
  - 4 枚羽根が大きくゆっくり回る: 左手は 4 拍で一周する重い低音（根音–5 度–オクターブ–5 度）。
    1 拍目は羽根が真下を通るように、さらに 1 オクターブ下を足して重くする
  - A（ゆっくり回る）: 二分音符の大きな旋律をオクターブで
  - B（突風）: 低音が 8 分に詰まり、右手は 16 分の走句が駆け上がって駆け下りる
  - C（小麦粉が舞う／帰りたい丘）: 変ホ長調に明るみ、メルルのテーマ（B♭–G–F）と A♭m を引用
  - 迷子の風見鶏（ハ短調・3/4・ワルツ）と同じ調で、拍子と重さを対にする
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm
from common import mel, n
import stage1_bgm as s1

BPM = 120
cm.set_tempo(BPM)
s1.Q['m7b5'] = [0, 3, 6, 10]
s1.Q['dim7'] = [0, 3, 6, 9]
random.seed(33)

A_CH = ['Cm', 'Cm', 'Ab', 'Ab', 'Fm', 'Fm', 'G', 'G7']
A_MEL = ['G4:2 C5:2', 'Eb5:3 D5:1', 'C5:2 Ab4:2', 'C5:1 Eb5:1 Ab5:2',
         'G5:2 F5:1 Eb5:1', 'Ab5:3 G5:1', 'F5:2 D5:2', 'B4:2 D5:1 F5:1']
B_CH = ['Cm', 'Ab', 'Eb', 'Bb', 'Cm', 'Ab', 'Fm', 'G7']
C_CH = ['Eb', 'Bb/D', 'Cm', 'Ab', 'Fm', 'Abm', 'Dm7b5', 'G7']
C_MEL = ['Bb5:2 G5:2', 'F5:3 R:1', 'G5:2 Eb5:2', 'Eb5:2 C5:2',
         'Ab5:2 F5:1 C5:1', 'Cb5:2 Eb5:2', 'F5:2 D5:2', 'G5:2 F5:1 D5:1']


def low_root(name):
    pcs, b = s1.chord(name)
    r = 36 + b            # C2〜B2
    return r if r <= 43 else r - 12, pcs


def turn(name, t, vel, eighths=False, heavy=True):
    """4 拍で一周する低音（根音–5 度–オクターブ–5 度）。
    eighths: 突風。各拍の裏に 1 オクターブ上を足して 8 分に詰める。heavy: 1 拍目にさらに 1 オクターブ下"""
    r, pcs = low_root(name)
    cycle = [r, r + 7, r + 12, r + 7]
    out = []
    for i, p in enumerate(cycle):
        s = t + i
        acc = 14 if i == 0 else (6 if i == 2 else 0)
        out.append((p, s, 0.5 if eighths else 0.95, vel + acc))
        if eighths:
            out.append((p + 12, s + 0.5, 0.45, vel - 6))
        if heavy and i == 0 and r - 12 >= 24:
            out.append((r - 12, s, 1.8, vel + 4))
    # 2・4 拍目に中音域の和音を軽く（羽根の風切り）
    mid = sorted(48 + ((p - 48) % 12) for p in pcs)
    for beat in (1, 3):
        for p in mid:
            out.append((p, t + beat, 0.45, vel - 16))
    return out


def gust_run(name, t, vel, up_first=True):
    """16 分で 1 小節: 和音の音を 8 つ駆け上がって 8 つ駆け下りる（up_first=False なら逆）。
    走句の中でだんだん強く、頭でいちばん強く。"""
    pcs, _ = s1.chord(name)
    tones = sorted({55 + ((p - 55) % 12) + 12 * k for p in pcs for k in range(3)})
    tones = [x for x in tones if x <= 88][:8]
    while len(tones) < 8:
        tones.append(tones[-3] + 12)
    up, down = tones, tones[::-1]
    seq = up + down if up_first else down + up
    out = []
    for i, p in enumerate(seq):
        v = vel + 8 if i == 0 else vel - 10 + int(18 * (i % 8) / 7)
        out.append((p, t + i * 0.25, 0.3, v + random.randint(-3, 3)))
    return out


def melody(specs, t, vel, octave=True):
    out = []
    for i, spec in enumerate(specs):
        mt = t + i * 4
        for p, d in mel(spec):
            if p is not None:
                v = vel + (6 if (mt - t) % 4 == 0 else 0) + random.randint(-3, 3)
                out.append((p, mt, d, v))
                if octave:
                    out.append((p - 12, mt, d, v - 12))
            mt += d
    return out


def build(preview):
    L, Rh, t, marks = [], [], 0.0, {}
    # イントロ: 羽根が回り始める（低音だけ、だんだん強く）
    for i, c in enumerate(['Cm', 'Cm']):
        L += turn(c, t, 48 + i * 10)
        t += 4
    loops = 2 if preview else 1
    for lp in range(loops):
        if lp == 0:
            marks['loop_start'] = t
        # A: ゆっくり回る
        for i, c in enumerate(A_CH):
            L += turn(c, t + i * 4, 58)
        Rh += melody(A_MEL, t, 82)
        t += 32
        # B: 突風。低音が 8 分に詰まり、右手は 16 分の走句
        for i, c in enumerate(B_CH):
            L += turn(c, t + i * 4, 60 + i, eighths=True)
            Rh += gust_run(c, t + i * 4, 70 + i * 2, up_first=(i % 2 == 0))
        t += 32
        # C: 小麦粉が舞う／帰りたい丘。軽い低音、テーマの引用
        for i, c in enumerate(C_CH):
            L += turn(c, t + i * 4, 46, heavy=False)
        Rh += melody(C_MEL, t, 74, octave=False)
        t += 32
        if lp == 0:
            marks['loop_end'] = t
    if preview:
        # 終止: 羽根が止まる
        L += turn('Cm', t, 50, heavy=True)
        t += 4
        for p in (n('C2'), n('C3'), n('G3'), n('Eb4'), n('C5')):
            L.append((p, t, 6, 56))
        t += 6
    return L, Rh, t, marks


if __name__ == '__main__':
    L, Rh, tb, m = build(False)
    cm.write_midi('art/music/boss2_hagure_fusha_loop.mid', 'Stage2 Boss Hagure Fusha', 'Cm', (4, 4), BPM, L, Rh, m)
    print('boss2 loop sec', s1.export_loop('godot/assets/audio/bgm/boss2_hagure_fusha.ogg', L, Rh, m['loop_start'], m['loop_end']))
    if '--preview' in sys.argv:
        L, Rh, tb, m = build(True)
        s1.render('boss2_preview.wav', L, Rh, tb)
        print('preview sec', tb * s1.BEAT)
