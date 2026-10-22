"""見習い魔女メルル ステージ1「村の空」 ピアノ曲 — MIDI生成とゲーム用ループOGGの書き出し

使い方（リポジトリのルートで）:  python tools/music/stage1_bgm.py
  - art/music/stage1_mura_no_sora_loop.mid   … 編集・差し替え用の原本（loop_start / loop_end マーカー付き）
  - godot/assets/audio/bgm/stage1_mura_no_sora.ogg … ゲーム用。イントロ＋ループ本体で終わり、余韻はループ頭に折り返し済み
必要: pip install mido numpy scipy、ffmpeg（libvorbis）
"""
import numpy as np, mido, random, subprocess, scipy.signal as ss
from scipy.io import wavfile

random.seed(7); np.random.seed(7)
BPM = 80
BEAT = 60 / BPM
PC = {'C':0,'Db':1,'D':2,'Eb':3,'E':4,'F':5,'Gb':6,'G':7,'Ab':8,'A':9,'Bb':10,'B':11,'Cb':11}
Q = {'':[0,4,7],'m':[0,3,7],'maj7':[0,4,7,11],'m7':[0,3,7,10],'7':[0,4,7,10],
     'sus4':[0,5,7],'7sus4':[0,5,7,10],'add9':[0,4,7,14],'m6':[0,3,7,9]}

def chord(name):
    """'Eb/G' -> (pitch classes, bass pc)"""
    body, _, bass = name.partition('/')
    root = body[:2] if len(body) > 1 and body[1] == 'b' else body[:1]
    pcs = [(PC[root] + i) % 12 for i in Q[body[len(root):]]]
    return pcs, PC[bass] if bass else PC[root]

# ---- 楽曲データ（1小節 = 4拍。和音は (拍数, 名前)） ----
Eb4,F4,G4,Ab4,Bb4,Cb5,C5,D5,Eb5,E5,F5,G5,Ab5,Bb5 = 63,65,67,68,70,71,72,74,75,76,77,79,80,82
R = None
intro_ch = [[(4,'Ebadd9')],[(4,'Bb/D')],[(4,'Cm7')],[(2,'Abmaj7'),(2,'Bbsus4')]]
intro_mel = [[(Bb5,2),(G5,2)],[(F5,3),(R,1)],[(G5,2),(Eb5,2)],[(D5,2),(C5,1),(R,1)]]

A_ch = [[(4,'Eb')],[(4,'Bb/D')],[(4,'Cm')],[(4,'Gm/Bb')],[(4,'Ab')],[(4,'Eb/G')],[(4,'Fm7')],[(2,'Bbsus4'),(2,'Bb')]]
A_mel = [[(G4,1.5),(Bb4,.5),(Eb5,1),(D5,1)],[(D5,1.5),(C5,.5),(Bb4,2)],
         [(C5,1.5),(Eb5,.5),(G5,1),(F5,1)],[(F5,1.5),(Eb5,.5),(D5,2)],
         [(Eb5,1.5),(C5,.5),(Ab4,1),(C5,1)],[(Bb4,1.5),(G4,.5),(Eb4,1),(G4,1)],
         [(Ab4,1),(C5,1),(Eb5,1),(D5,.5),(C5,.5)],[(Eb5,2),(D5,2)]]
A2_ch = A_ch[:4] + [[(4,'Ab')],[(4,'Eb/G')],[(2,'Fm7'),(2,'Bb7')],[(4,'Eb')]]
A2_mel = A_mel[:4] + [[(Eb5,1.5),(F5,.5),(G5,1),(Ab5,1)],[(G5,1.5),(F5,.5),(Eb5,1),(Bb4,1)],
                      [(C5,1.5),(Bb4,.5),(Ab4,1),(D5,1)],[(Eb5,3),(R,1)]]
B_ch = [[(4,'Abmaj7')],[(4,'Bb')],[(4,'Gm7')],[(4,'Cm7')],[(4,'Fm7')],[(4,'Bb/Ab')],[(4,'Gm7')],[(4,'C7')],
        [(4,'Abmaj7')],[(4,'Bb')],[(4,'Eb/G')],[(4,'Cm')],[(4,'Abm6')],[(4,'Eb/G')],[(4,'Fm7')],[(2,'Bb7sus4'),(2,'Bb7')]]
B_mel = [[(C5,1),(Eb5,1),(G5,2)],[(F5,1.5),(D5,.5),(Bb4,2)],[(Bb4,1),(D5,1),(F5,1.5),(G5,.5)],[(Eb5,2),(D5,1),(C5,1)],
         [(C5,1),(Eb5,1),(Ab5,1.5),(G5,.5)],[(F5,2),(D5,1),(Bb4,1)],[(Bb4,1.5),(C5,.5),(D5,1),(F5,1)],[(E5,2),(D5,1),(C5,1)],
         [(C5,1),(Eb5,1),(G5,1.5),(F5,.5)],[(F5,2),(D5,1),(Eb5,1)],[(G5,1.5),(F5,.5),(Eb5,1),(Bb4,1)],[(C5,2),(Eb5,1),(G5,1)],
         [(F5,1.5),(Eb5,.5),(Cb5,2)],[(Bb4,1),(Eb5,1),(G5,2)],[(F5,1.5),(Eb5,.5),(C5,1),(Ab4,1)],[(Eb5,1),(D5,1),(C5,1),(Ab4,1)]]
end_ch, end_mel = [[(4,'Eb')],[(4,'Eb')]], [[(G4,1),(Bb4,1),(Eb5,2)],[(R,4)]]

def bass_note(pc):
    n = 36 + pc
    return n + 12 if n < 39 else n  # E♭2〜D3付近

def arpeggio(name, start, beats, vel, bar_idx):
    pcs, b = chord(name)
    bn = bass_note(b)
    tones = sorted({bn + 12*k + ((p - bn) % 12) for p in pcs for k in range(3)
                    if bn + 7 <= bn + 12*k + ((p - bn) % 12) <= bn + 21})
    tones = tones[:4] if len(tones) >= 4 else tones + [bn + 12]
    pat = [0,1,2,1,3,1,2,1]
    out = [(bn, start, beats + .5, vel + 6)]
    for i in range(1, int(beats * 2)):
        idx = pat[i % 8] if i % 8 else 1
        out.append((tones[min(idx, len(tones)-1)], start + i*.5, beats - i*.5 + .5, vel - (4 if i % 2 else 0)))
    return out

def section(chs, mels, t0, lv, rv, pads=False):
    L, Rh = [], []
    t = t0
    for bi, (cbar, mbar) in enumerate(zip(chs, mels)):
        ct = t
        for beats, name in cbar:
            L += arpeggio(name, ct, beats, lv, bi)
            if pads:
                pcs, _ = chord(name)
                for p in pcs:
                    n = 60 + ((p - 60) % 12)
                    if n < 66: Rh.append((n, ct, beats, lv - 8))
            ct += beats
        mt = t
        for i, (p, d) in enumerate(mbar):
            if p is not None:
                accent = 6 if mt % 4 == 0 else 0
                Rh.append((p, mt, d, rv + accent + random.randint(-4, 3)))
            mt += d
        t += 4
    return L, Rh, t

def build(full_preview):
    L, Rh, t = [], [], 0
    parts = [(intro_ch, intro_mel, 44, 64, False)]
    loop = [(A_ch, A_mel, 48, 74, False), (A2_ch, A2_mel, 48, 76, False),
            (B_ch[:8], B_mel[:8], 50, 78, False), (B_ch[8:], B_mel[8:], 52, 80, True)]
    parts += loop
    if full_preview:
        parts += loop[:2]
    marks = {}
    for i, p in enumerate(parts):
        if i == 1: marks['loop_start'] = t
        l, r, t = section(*p[:2], t, p[2], p[3], p[4]); L += l; Rh += r
        if i == 4: marks['loop_end'] = t
    if full_preview:
        l, r, t = section(end_ch, end_mel, t, 42, 62); L += l; Rh += r
        # 最後の主和音
        for n in (51, 55, 58, 63, 67): Rh.append((n, t - 4, 6, 50))
    return L, Rh, t, marks

def write_midi(path, L, Rh, marks):
    mid = mido.MidiFile(ticks_per_beat=480)
    meta = mido.MidiTrack(); mid.tracks.append(meta)
    meta += [mido.MetaMessage('track_name', name='Stage1 Mura no Sora', time=0),
             mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM), time=0),
             mido.MetaMessage('key_signature', key='Eb', time=0),
             mido.MetaMessage('time_signature', numerator=4, denominator=4, time=0)]
    last = 0
    for k in ('loop_start', 'loop_end'):
        tk = int(marks[k] * 480)
        meta.append(mido.MetaMessage('marker', text=k, time=tk - last)); last = tk
    for name, notes, ch in (('Right Hand', Rh, 0), ('Left Hand', L, 1)):
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name, time=0))
        tr.append(mido.Message('program_change', program=0, channel=ch, time=0))
        ev = []
        for p, s, d, v in notes:
            ev.append((int(s*480), 1, p, v)); ev.append((int((s+d)*480) - 10, 0, p, 0))
        # ペダル: 和音の変わり目ごとに踏み直し（左手のみに付与）
        if ch == 1:
            for s in sorted({int(n[1]*480) for n in notes if n[0] < 52}):
                ev.append((s + 30, 2, 64, 100)); ev.append((s, -1, 64, 0))
        ev.sort(key=lambda e: (e[0], e[1]))
        cur = 0
        for tk, kind, p, v in ev:
            dt = max(0, tk - cur); cur += dt
            if kind == 1: tr.append(mido.Message('note_on', note=p, velocity=v, channel=ch, time=dt))
            elif kind == 0: tr.append(mido.Message('note_off', note=p, velocity=0, channel=ch, time=dt))
            else: tr.append(mido.Message('control_change', control=64, value=v, channel=ch, time=dt))
    mid.save(path)

# ---- 簡易ピアノ合成（試聴用） ----
SR = 44100
def piano_note(midi, dur, vel, seed=0):
    f = 440 * 2 ** ((midi - 69) / 12)
    v = vel / 127
    T = dur + 1.6
    t = np.arange(int(T * SR)) / SR
    Bc = 0.00012 * (f / 261) ** 1.2
    sig = np.zeros_like(t)
    for n in range(1, 16):
        fn = n * f * np.sqrt(1 + Bc * n * n)
        if fn > 16000: break
        amp = (1 / n ** (1.35 - 0.35 * v)) * (0.6 if n % 7 == 0 else 1)
        d1 = 1.2 + 0.9 * n * (f / 440) ** .6            # 速い減衰
        d2 = 0.25 + 0.12 * n * (f / 440) ** .7           # 余韻
        env = 0.55 * np.exp(-d1 * t) + 0.45 * np.exp(-d2 * t)
        det = 1 + (0.00025 if n % 2 else -0.0002)        # 弦のうなり
        sig += amp * env * 0.5 * (np.sin(2*np.pi*fn*t) + np.sin(2*np.pi*fn*det*t + .3))
    att = np.minimum(1, t / 0.004)
    rel = np.where(t < dur, 1, np.exp(-(t - dur) / 0.35))
    ham = np.random.default_rng(seed).standard_normal(len(t)) * np.exp(-t / 0.008) * 0.03 * v
    return (sig * att * rel + ham) * (v ** 1.6)

def render(path, L, Rh, total_beats, length_beats=None):
    """path=None なら正規化前の配列を返す。"""
    T = (length_beats or total_beats) * BEAT + 4
    out = np.zeros((int(T * SR), 2))
    for p, s, d, v in L + Rh:
        seed = (p * 1000003 + int(s * 960)) & 0xffffffff
        s2 = s * BEAT + (np.random.default_rng(seed).random() - .5) * 0.012
        x = piano_note(p, d * BEAT, v, seed)
        i = int(max(0, s2) * SR); x = x[:len(out) - i]
        pan = np.clip((p - 64) / 48, -.5, .5)
        out[i:i+len(x), 0] += x * (1 - pan) * .7
        out[i:i+len(x), 1] += x * (1 + pan) * .7
    # 部屋鳴りのリバーブ
    n = int(2.4 * SR); tt = np.arange(n) / SR
    irng = np.random.default_rng(2024)
    for c in range(2):
        ir = irng.standard_normal(n) * np.exp(-tt / 0.55)
        ir = ss.lfilter(*ss.butter(2, 5000 / (SR/2)), ir); ir[0] = 0
        wet = ss.fftconvolve(out[:, c], ir)[:len(out)]
        out[:, c] = out[:, c] + wet / np.abs(ir).sum() * 9
    out = ss.lfilter(*ss.butter(1, 9000 / (SR/2)), out, axis=0)
    if path is None:
        return out
    out /= np.abs(out).max() * 1.12
    wavfile.write(path, SR, (out * 32767).astype(np.int16))

def export_loop(ogg_path, L, Rh, loop_start_beat, loop_end_beat):
    """ゲーム用ループ音源（イントロ＋ループ本体、loop_end で終わる）。
    ・ループ本体の余韻（loop_end 以降）はループ頭に折り返す
    ・イントロの余韻は loop_start の直前でフェードアウトさせ、ループ区間には含めない
    これで loop_end → loop_start の継ぎ目が波形として連続する。
    Godot 側では AudioStreamOggVorbis.loop_offset = loop_start 秒 でループさせる。"""
    import os, tempfile
    is_body = lambda n: n[1] >= loop_start_beat - 0.01
    body = render(None, [n for n in L if is_body(n)], [n for n in Rh if is_body(n)], loop_end_beat)
    intro = render(None, [n for n in L if not is_body(n)], [n for n in Rh if not is_body(n)], loop_end_beat)
    ls, le = int(round(loop_start_beat * BEAT * SR)), int(round(loop_end_beat * BEAT * SR))
    fade = int(0.15 * SR)
    out = np.zeros((le, 2))
    out[:ls] = intro[:ls]
    out[ls - fade:ls] *= np.linspace(1, 0, fade)[:, None]
    out += body[:le]
    tail = body[le:]
    n = min(len(tail), le - ls)
    out[ls:ls + n] += tail[:n]
    # 揺らぎで loop_start より少し前に鳴り始めた音の頭を、ファイル末尾にも置く（2周目以降の継ぎ目用）
    pre = int(0.05 * SR)
    out[le - pre:le] += body[ls - pre:ls]
    out /= np.abs(out).max() * 1.12
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, 'x.wav')
        wavfile.write(wav, SR, (out * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', ogg_path], check=True)
    return loop_start_beat * BEAT, loop_end_beat * BEAT

if __name__ == '__main__':
    L, Rh, tb, marks = build(False)
    write_midi('art/music/stage1_mura_no_sora_loop.mid', L, Rh, marks)
    print('stage1 loop sec', export_loop('godot/assets/audio/bgm/stage1_mura_no_sora.ogg', L, Rh, marks['loop_start'], marks['loop_end']))
