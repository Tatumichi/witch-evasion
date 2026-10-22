"""見習い魔女メルル ステージ1ボス「迷子の風見鶏」 ピアノ曲（3/4ワルツ）

使い方（リポジトリのルートで）:  python tools/music/boss1_bgm.py
  - art/music/boss1_maigo_no_kazamidori_loop.mid
  - godot/assets/audio/bgm/boss1_maigo_no_kazamidori.ogg
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import random, mido, numpy as np
import stage1_bgm as s1

BPM = 172
s1.BPM = BPM; s1.BEAT = 60 / BPM
random.seed(11)
chord = s1.chord

C4,D4,Eb4,F4,G4,Ab4,Bb4,B4,Cb5,C5,D5,Eb5,F5,Fs5,G5,Ab5,Bb5,C6 = 60,62,63,65,67,68,70,71,71,72,74,75,77,78,79,80,82,84
R = None
BAR = 3

# 回転モチーフ: 4音 x 8分音符を3拍子に重ねる → 2小節半で一周し、強拍が毎回ずれる（向きが定まらない）
SPIN = {'Cm':[G5,Ab5,G5,Fs5],'Cm/B':[G5,Ab5,G5,Fs5],'Cm/Bb':[G5,Ab5,G5,F5],'Ab':[Ab5,Bb5,Ab5,G5],
        'Am7b5':[Eb5,F5,Eb5,D5],'G':[G5,Ab5,G5,Fs5],'Fm':[Ab5,Bb5,Ab5,G5]}
s1.Q['m7b5'] = [0,3,6,10]

def waltz_lh(name, t, vel, bars=1):
    pcs, b = chord(name)
    bn = s1.bass_note(b)
    if bn > 47: bn -= 12
    upper = sorted(55 + ((p - 55) % 12) for p in pcs)[:3]   # G3〜F#4付近の和音
    out = []
    for k in range(bars):
        s = t + k * BAR
        out.append((bn, s, 2.6, vel + 8))
        if k % 2 == 0: out.append((bn + 12, s, 1.2, vel - 6))
        for beat in (1, 2):
            for n in upper: out.append((n, s + beat, .45, vel - 10 + (2 if beat == 1 else -2)))
    return out

def spin_line(name, t, bars, vel, phase, octave=False):
    out, cyc = [], SPIN[name]
    for i in range(bars * 6):
        n = cyc[(phase + i) % 4]
        acc = 10 if (phase + i) % 4 == 0 else 0           # 4音の頭にアクセント → 拍とずれる
        out.append((n, t + i * .5, .5, vel + acc + random.randint(-3, 3)))
        if octave: out.append((n - 12, t + i * .5, .5, vel - 12 + acc))
    return out, phase + bars * 6

def melody(bars, t, vel):
    out = []
    for i, bar in enumerate(bars):
        mt = t + i * BAR
        for p, d in bar:
            if p is not None:
                out.append((p, mt, d, vel + (6 if (mt - t) % 3 == 0 else 0) + random.randint(-4, 3)))
            mt += d
    return out

# ---- A: 迷子の風見鶏（ハ短調、ベースが半音ずつ下がる＝くるくる沈む） ----
A_ch = ['Cm','Cm/B','Cm/Bb','Ab','Fm','Dm7b5','G','G7','Cm','Cm/B','Cm/Bb','Ab','Fm','G7','Cm','Cm']
A_mel = [[(C5,1),(Eb5,1),(G5,1)],[(G5,1.5),(Ab5,.5),(G5,.5),(Fs5,.5)],[(G5,2),(Eb5,1)],[(C5,1.5),(D5,.5),(Eb5,1)],
         [(F5,1),(Ab5,1),(C6,1)],[(C6,1.5),(Bb5,.5),(Ab5,.5),(F5,.5)],[(B4,1),(D5,1),(G5,1)],[(F5,1.5),(Eb5,.5),(D5,1)],
         [(C5,1),(Eb5,1),(G5,1)],[(G5,1.5),(Ab5,.5),(G5,.5),(Fs5,.5)],[(G5,2),(Bb5,1)],[(Ab5,1.5),(G5,.5),(Eb5,1)],
         [(Ab5,1.5),(G5,.5),(F5,1)],[(D5,1),(F5,1),(B4,1)],[(C5,3)],[(R,3)]]
# ---- B: 少女の影を見つけた（変ホ長調。ステージ1冒頭のメロディを3拍子で引用） ----
B_ch = ['Eb','Bb/D','Cm','Ab','Fm','Bb7','Eb','G7','Eb','Bb/D','Cm','Abm','Fm','Dm7b5','G','G']
B_mel = [[(Bb5,1.5),(G5,1.5)],[(F5,3)],[(G5,1.5),(Eb5,1.5)],[(D5,1.5),(C5,1.5)],
         [(C5,1),(F5,1),(Ab5,1)],[(G5,1.5),(F5,.5),(D5,1)],[(Eb5,2),(Bb4,1)],[(F5,1.5),(Eb5,.5),(D5,1)],
         [(Bb5,1.5),(G5,1.5)],[(F5,3)],[(G5,1.5),(Eb5,1.5)],[(Eb5,1.5),(Cb5,1.5)],
         [(C5,1),(F5,1),(Ab5,1)],[(Ab5,1),(F5,1),(D5,1)],[(B4,1),(D5,1),(G5,1)],[(R,3)]]
# ---- C: 追いかけっこ（回転モチーフをオクターブで、ボス戦の山場） ----
C_ch = ['Cm','Cm/B','Cm/Bb','Am7b5','Ab','G','Ab','G']

def build(preview):
    L, Rh, t, marks = [], [], 0, {}
    # イントロ: 回転モチーフだけ → ワルツが加わる
    r, ph = spin_line('Cm', t, 2, 60, 0); Rh += r; t += 2 * BAR
    r, ph = spin_line('Cm', t, 2, 68, ph); Rh += r; L += waltz_lh('Cm', t, 54, 2); t += 2 * BAR
    loops = 2 if preview else 1
    for lp in range(loops):
        if lp == 0: marks['loop_start'] = t
        a0 = t
        for i, c in enumerate(A_ch): L += waltz_lh(c, t + i * BAR, 56)
        Rh += melody(A_mel, t, 80)
        # 最後の小節は回転モチーフで埋める
        r, ph = spin_line('Cm', t + 15 * BAR, 1, 66, 0); Rh += r
        # 後半8小節は中音域に回転モチーフを薄く重ねる
        for i, c in enumerate(A_ch[8:14]):
            cyc = SPIN.get(c.replace('7','') if c != 'Dm7b5' else 'Fm', SPIN['Cm'])
            for k in range(6):
                Rh.append((cyc[(ph + k) % 4] - 12, t + (8 + i) * BAR + k * .5, .5, 46))
            ph += 6
        t += 16 * BAR
        for i, c in enumerate(B_ch): L += waltz_lh(c, t + i * BAR, 48)
        Rh += melody(B_mel, t, 68)
        r, ph = spin_line('G', t + 15 * BAR, 1, 64, 0); Rh += r
        t += 16 * BAR
        ph = 0
        for i, c in enumerate(C_ch):
            L += waltz_lh(c, t + i * BAR, 62 + i)
            r, ph = spin_line(c, t + i * BAR, 1, 80 + i * 2, ph, octave=True); Rh += r
        t += 8 * BAR
        if lp == 0: marks['loop_end'] = t
    if preview:
        # 終止: くるっと一回転して主和音
        r, _ = spin_line('Cm', t, 1, 76, 0); Rh += r; L += waltz_lh('G', t, 60); t += BAR
        for n in (36, 48): L.append((n, t, 6, 80))
        for n in (60, 63, 67, 72): Rh.append((n, t, 6, 78))
        t += 2 * BAR
    return L, Rh, t, marks

def write_midi(path, L, Rh, marks):
    mid = mido.MidiFile(ticks_per_beat=480)
    meta = mido.MidiTrack(); mid.tracks.append(meta)
    meta += [mido.MetaMessage('track_name', name='Stage1 Boss Maigo no Kazamidori', time=0),
             mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM), time=0),
             mido.MetaMessage('key_signature', key='Cm', time=0),
             mido.MetaMessage('time_signature', numerator=3, denominator=4, time=0)]
    last = 0
    for k in ('loop_start', 'loop_end'):
        tk = int(marks[k] * 480); meta.append(mido.MetaMessage('marker', text=k, time=tk - last)); last = tk
    for name, notes, ch in (('Right Hand', Rh, 0), ('Left Hand', L, 1)):
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name, time=0))
        tr.append(mido.Message('program_change', program=0, channel=ch, time=0))
        ev = []
        for p, s, d, v in notes:
            ev.append((int(s*480), 1, p, min(127, v))); ev.append((int((s+d)*480) - 10, 0, p, 0))
        ev.sort(key=lambda e: (e[0], e[1]))
        cur = 0
        for tk, kind, p, v in ev:
            dt = max(0, tk - cur); cur += dt
            tr.append(mido.Message('note_on' if kind else 'note_off', note=p, velocity=v, channel=ch, time=dt))
    mid.save(path)

if __name__ == '__main__':
    L, Rh, tb, m = build(False)
    write_midi('art/music/boss1_maigo_no_kazamidori_loop.mid', L, Rh, m)
    print('boss1 loop sec', s1.export_loop('godot/assets/audio/bgm/boss1_maigo_no_kazamidori.ogg', L, Rh, m['loop_start'], m['loop_end']))
