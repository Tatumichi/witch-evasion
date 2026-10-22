"""BGM 生成スクリプトの共通部品（STAGE 2 以降）。

STAGE 1 の 2 曲は stage1_bgm.py / boss1_bgm.py にそれぞれ書いてある。ピアノの合成（render）と
ゲーム用ループの書き出し（export_loop）は stage1_bgm.py のものをそのまま使う。
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mido
import stage1_bgm as s1

NOTE_PC = {'C': 0, 'Db': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6, 'G': 7, 'Ab': 8, 'A': 9,
           'Bb': 10, 'B': 11, 'Cb': 11, 'Fb': 4}
R = None   # 休符


def n(name):
    """'Eb5' -> MIDI ノート番号（C4 = 60）。Cb5 は B4 と同じ高さ（71）。"""
    if name[1:2] == 'b':
        p, o = name[:2], int(name[2:])
    else:
        p, o = name[:1], int(name[1:])
    if p == 'Cb':
        o -= 1
    return 12 * (o + 1) + NOTE_PC[p]


def mel(spec):
    """'Bb4:1 Eb5:2/3 R:1' -> [(71, 1.0), (75, 0.667), (None, 1.0)]。長さは拍。"""
    out = []
    for tok in spec.split():
        name, d = tok.split(':')
        if '/' in d:
            a, b = d.split('/')
            d = int(a) / int(b)
        out.append((None if name == 'R' else n(name), float(d)))
    return out


def set_tempo(bpm):
    """stage1_bgm の合成・書き出しが使うテンポを切り替える。"""
    s1.BPM = bpm
    s1.BEAT = 60 / bpm


def write_midi(path, title, key, meter, bpm, L, Rh, marks):
    """右手・左手の 2 トラック。loop_start / loop_end マーカー付き。左手は拍の頭でペダルを踏み直す。"""
    mid = mido.MidiFile(ticks_per_beat=480)
    meta = mido.MidiTrack(); mid.tracks.append(meta)
    meta += [mido.MetaMessage('track_name', name=title, time=0),
             mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(bpm), time=0),
             mido.MetaMessage('key_signature', key=key, time=0),
             mido.MetaMessage('time_signature', numerator=meter[0], denominator=meter[1], time=0)]
    last = 0
    for k in ('loop_start', 'loop_end'):
        tk = int(round(marks[k] * 480))
        meta.append(mido.MetaMessage('marker', text=k, time=tk - last)); last = tk
    for name, notes, ch in (('Right Hand', Rh, 0), ('Left Hand', L, 1)):
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name, time=0))
        tr.append(mido.Message('program_change', program=0, channel=ch, time=0))
        ev = []
        for p, s, d, v in notes:
            ev.append((int(round(s * 480)), 1, p, max(1, min(127, int(v)))))
            ev.append((int(round((s + d) * 480)) - 10, 0, p, 0))
        if ch == 1:
            # ペダル: 和音が変わる位置（ベース音の位置）で踏み直す
            for s in sorted({int(round(x[1] * 480)) for x in notes if x[0] < 52}):
                ev.append((s + 30, 2, 64, 100)); ev.append((s, -1, 64, 0))
        ev.sort(key=lambda e: (e[0], e[1]))
        cur = 0
        for tk, kind, p, v in ev:
            dt = max(0, tk - cur); cur += dt
            if kind == 1:
                tr.append(mido.Message('note_on', note=p, velocity=v, channel=ch, time=dt))
            elif kind == 0:
                tr.append(mido.Message('note_off', note=p, velocity=0, channel=ch, time=dt))
            else:
                tr.append(mido.Message('control_change', control=64, value=v, channel=ch, time=dt))
    mid.save(path)
