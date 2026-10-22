"""見習い魔女メルル STAGE 1 の効果音（SE）を合成して書き出す。

使い方（リポジトリのルートで）:  python tools/sfx/make_se.py [名前 ...]
  - godot/assets/audio/se/<名前>.wav（44.1kHz / 16bit / モノラル）
  - 名前を渡すとその音だけ作り直す
必要: pip install numpy scipy

方針: BGM がピアノ独奏なので、ベル・チェレスタ・やわらかい打楽器系に寄せる。
音程のある音は変ホ長調／ハ短調の音（E♭ G B♭ C D F A♭）から選び、BGM と濁らないようにする。
一覧と鳴らす場面は docs/sound_effects.md。
"""
import os, sys
import numpy as np
import scipy.signal as ss
from scipy.io import wavfile

SR = 44100
OUT = 'godot/assets/audio/se'
RNG = np.random.default_rng(1234)

# ---------------------------------------------------------------- 基本部品

def T(d):
    return np.arange(int(d * SR)) / SR

def hz(name):
    """'Eb5' -> 周波数"""
    pcs = {'C':0,'Db':1,'D':2,'Eb':3,'E':4,'F':5,'Gb':6,'G':7,'Ab':8,'A':9,'Bb':10,'B':11}
    n, o = (name[:2], name[2:]) if len(name) > 2 and name[1] == 'b' else (name[:1], name[1:])
    return 440.0 * 2 ** ((pcs[n] + 12 * (int(o) + 1) - 69) / 12)

def pad(x, d):
    n = int(d * SR)
    return np.pad(x, (0, max(0, n - len(x))))[:n] if n else x

def mix(*parts, d=None):
    """parts: (信号, 開始秒, 音量)"""
    end = max(int(s * SR) + len(x) for x, s, g in parts)
    if d: end = max(end, int(d * SR))
    out = np.zeros(end)
    for x, s, g in parts:
        i = int(s * SR); out[i:i + len(x)] += x * g
    return out

def noise(d):
    return RNG.standard_normal(int(d * SR))

def adsr(n, a=0.005, decay=None, release=0.02):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4))
    if decay: e *= np.exp(-t / decay)
    r = int(release * SR)
    if r and r < n: e[-r:] *= np.linspace(1, 0, r)
    return e

def glide(f0, f1, d, curve='exp'):
    t = T(d)
    if curve == 'exp':
        f = f0 * (f1 / f0) ** (t / d)
    else:
        f = f0 + (f1 - f0) * (t / d)
    return f

def osc(freq, wave='sine'):
    """freq: 配列（瞬時周波数）"""
    ph = 2 * np.pi * np.cumsum(freq) / SR
    if wave == 'sine': return np.sin(ph)
    if wave == 'tri': return 2 / np.pi * np.arcsin(np.sin(ph))
    if wave == 'saw':
        # 帯域制限ぎみのノコギリ（倍音 12 本）
        return sum(np.sin(k * ph) / k for k in range(1, 13)) * 0.6
    raise ValueError(wave)

def svf(x, fc, q=0.7, mode='bp'):
    """状態変数フィルタ。fc は定数か配列（時間変化）"""
    fc = np.broadcast_to(np.asarray(fc, float), x.shape)
    f = 2 * np.sin(np.pi * np.minimum(fc, SR / 6) / SR)
    damp = 1 / q
    lp = bp = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        hp = x[i] - lp - damp * bp
        bp += f[i] * hp
        lp += f[i] * bp
        out[i] = bp if mode == 'bp' else lp if mode == 'lp' else hp
    return out

def lowpass(x, fc, order=2):
    return ss.sosfilt(ss.butter(order, fc / (SR / 2), output='sos'), x)

def highpass(x, fc, order=2):
    return ss.sosfilt(ss.butter(order, fc / (SR / 2), 'high', output='sos'), x)

def bandpass(x, lo, hi, order=2):
    return ss.sosfilt(ss.butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)

def reverb(x, size=0.6, wet=0.25):
    n = int(size * 2.5 * SR); t = np.arange(n) / SR
    ir = np.random.default_rng(7).standard_normal(n) * np.exp(-t / (size * 0.4))
    ir = lowpass(ir, 6000); ir[0] = 0
    w = ss.fftconvolve(x, ir)
    w /= np.abs(ir).sum() / 6
    y = np.pad(x, (0, len(w) - len(x)))
    return y + w * wet

# ---------------------------------------------------------------- 楽器

def bell(f, d=1.2, bright=1.0, decay=0.6):
    """チェレスタ／グロッケン系（FM）。"""
    t = T(d)
    idx = bright * 2.2 * np.exp(-t / 0.08)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * idx
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / decay)
    x += 0.25 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / (decay * 0.25))
    return x * adsr(len(t), a=0.002, release=0.05)

def marimba(f, d=0.5):
    t = T(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.18) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.03)
    return x * adsr(len(t), a=0.002, release=0.03)

def pluck(f, d=1.5, bright=0.5):
    """ハープ（Karplus-Strong）。"""
    n = int(d * SR); p = int(SR / f)
    buf = np.random.default_rng(int(f)).uniform(-1, 1, p)
    buf = lowpass(buf, 2000 + 6000 * bright, 1)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.996 * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out * adsr(n, a=0.001, release=0.1)

def church_bell(f, d=4.0):
    t = T(d)
    parts = [(0.5, 1.0, 2.2), (1.0, 0.8, 1.6), (1.19, 0.5, 1.2), (1.5, 0.35, 0.9), (2.0, 0.45, 0.8),
             (2.51, 0.2, 0.5), (3.0, 0.18, 0.4), (4.07, 0.08, 0.25), (5.2, 0.05, 0.18), (6.7, 0.03, 0.12)]
    x = sum(a * np.sin(2 * np.pi * f * r * t * (1 + 0.0007 * k)) * np.exp(-t / dec)
            for k, (r, a, dec) in enumerate(parts))
    strike = lowpass(noise(0.03), 3000) * np.exp(-T(0.03) / 0.006) * 0.4
    return mix((x * adsr(len(t), 0.002, release=0.3), 0, 1), (strike, 0, 1))

def piano(f, d=1.0, vel=0.7):
    t = T(d + 0.6)
    x = np.zeros_like(t)
    for n in range(1, 10):
        fn = n * f * np.sqrt(1 + 0.0002 * n * n)
        if fn > 15000: break
        amp = 1 / n ** (1.4 - 0.4 * vel)
        env = 0.6 * np.exp(-(1.3 + 0.8 * n * (f / 440) ** .6) * t) + 0.4 * np.exp(-(0.3 + 0.15 * n) * t)
        x += amp * env * np.sin(2 * np.pi * fn * t)
    rel = np.where(t < d, 1, np.exp(-(t - d) / 0.25))
    return x * rel * adsr(len(t), 0.003, release=0.02) * vel

def creak(d, rate, res=(700, 1500, 2600), jitter=0.25, seed=0):
    """金属の軋み。スティックスリップ（不規則なパルス列）を金属の共鳴に通す。
    rate: 1 秒あたりのパルス数（定数か配列）"""
    rng = np.random.default_rng(seed)
    n = int(d * SR)
    rate = np.broadcast_to(np.asarray(rate, float), (n,))
    x = np.zeros(n); pos = 0.0
    while True:
        i = int(pos)
        if i >= n: break
        x[i] = rng.uniform(0.6, 1.0)
        pos += SR / rate[i] * (1 + rng.uniform(-jitter, jitter))
    y = sum(svf(x, f, q=18) * g for f, g in zip(res, (1.0, 0.7, 0.45)))
    # パルスの角が全帯域に広がって耳に痛いので、共鳴より上を落とす
    return lowpass(y, max(res) * 1.3, 2)

def meow(f0=650, d=0.55, happy=False, short=False):
    """猫の鳴き声（フォルマント合成）。m → i → a → u と母音が動く。"""
    t = T(d); u = t / d
    if short:
        contour = f0 * (1 + 0.35 * np.sin(np.pi * np.minimum(u * 1.4, 1)))
    elif happy:
        contour = f0 * (0.9 + 0.35 * np.sin(np.pi * u) - 0.15 * u)
    else:
        contour = f0 * (1 + 0.3 * np.sin(np.pi * u ** 0.7))
    vib = 1 + 0.015 * np.sin(2 * np.pi * 6 * t)
    src = osc(contour * vib, 'saw') + 0.03 * noise(d)
    F1 = np.interp(u, [0, .15, .45, 1], [300, 450, 950, 500])
    F2 = np.interp(u, [0, .15, .45, 1], [1800, 2400, 1500, 900])
    F3 = np.full_like(u, 3000.0)
    y = svf(src, F1, 6) + 0.8 * svf(src, F2, 8) + 0.3 * svf(src, F3, 8)
    env = np.interp(u, [0, .08, .2, .75, 1], [0, .35, 1, .8, 0])
    return y * env

def rooster(scale=1.0, short=False):
    """コケコッコー（ノコギリ波＋フォルマント）。"""
    sylls = [(0.11, 520, 600), (0.11, 600, 700), (0.13, 640, 760), (0.55, 760, 560)]
    if short: sylls = [(0.09, 520, 600), (0.16, 620, 520)]
    out = []
    for i, (d, a, b) in enumerate(sylls):
        t = T(d); u = t / d
        f = (a + (b - a) * u) * scale * (1 + 0.02 * np.sin(2 * np.pi * 7 * t))
        src = osc(f, 'saw') + 0.08 * noise(d)
        F1 = np.interp(u, [0, .3, 1], [450, 750, 650 if i < len(sylls) - 1 else 500])
        y = svf(src, F1, 5) + 0.7 * svf(src, 1200 + 400 * u, 6) + 0.25 * svf(src, 2600, 6)
        env = np.interp(u, [0, .15, .8, 1], [0, 1, .8, 0])
        out.append(y * env); out.append(np.zeros(int(0.025 * SR)))
    return np.concatenate(out)

def wind(d, lo=250, hi=900, speed=0.7, seed=0):
    rng = np.random.default_rng(seed)
    t = T(d)
    fc = lo + (hi - lo) * (0.5 + 0.5 * np.sin(2 * np.pi * speed * t + rng.uniform(0, 6))) \
         * (0.7 + 0.3 * np.sin(2 * np.pi * speed * 2.3 * t))
    n = rng.standard_normal(len(t))
    return svf(n, fc, q=1.4) + 0.4 * lowpass(n, 180)

def whoosh(d=0.25, f0=3000, f1=900, q=2.0):
    t = T(d); u = t / d
    fc = f0 * (f1 / f0) ** u
    env = np.sin(np.pi * u) ** 1.5
    return svf(noise(d), fc, q) * env

def flap(seed=0):
    """羽ばたき 1 回。"""
    rng = np.random.default_rng(seed)
    d = 0.06
    x = bandpass(rng.standard_normal(int(d * SR)), 500, 2500) * np.exp(-T(d) / 0.015)
    return x

def puff(d=0.25, fc=900, decay=0.06):
    return lowpass(noise(d), fc) * np.exp(-T(d) / decay) * adsr(int(d * SR), 0.004)

def pop(f0=900, f1=180, d=0.09):
    f = glide(f0, f1, d)
    return osc(f) * np.exp(-T(d) / 0.03) * adsr(len(f), 0.001, release=0.01)

def sparkle(n=5, start=0.0, notes=('Eb7', 'G7', 'Bb7', 'C8', 'Eb8'), spacing=0.04, seed=0):
    rng = np.random.default_rng(seed)
    parts = []
    for i in range(n):
        parts.append((bell(hz(notes[rng.integers(len(notes))]) / 2, 0.35, 0.6, 0.12), start + i * spacing * rng.uniform(.7, 1.3), rng.uniform(.4, .8)))
    return mix(*parts)

def chirp(f0, f1, d):
    return osc(glide(f0, f1, d)) * np.sin(np.pi * T(d) / d) ** 2

def seamless(x, xfade=0.3):
    """末尾を先頭にクロスフェードしてループ可能にする（長さは xfade 分短くなる）。"""
    n = int(xfade * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    y = x[:-n].copy()
    y[:n] = head * w + tail * (1 - w)
    return y

# ---------------------------------------------------------------- 各SE

SE = {}

def se(name, peak_db, loop=False):
    def deco(fn):
        SE[name] = (fn, peak_db, loop)
        return fn
    return deco

# ---- メルル
@se('hit', -2)
def _():
    p = pop(700, 160, 0.12)
    thud = lowpass(noise(0.08), 400) * np.exp(-T(0.08) / 0.02)
    flutter = whoosh(0.35, 1800, 4000, 1.5) * 0.5
    return mix((p, 0, 1), (thud, 0, .6), (flutter, 0.06, 1), (bell(hz('D6'), 0.4, .5, .12), 0.02, .25))

@se('hat_warning', -5)
def _():
    return reverb(mix((bell(hz('D6'), 0.5, .7, .2), 0, 1), (bell(hz('Ab5'), 0.6, .7, .25), 0.14, 1)), 0.4, 0.2)

@se('faint', -3)
def _():
    d = 1.0
    f = glide(1000, 180, d) * (1 + 0.06 * np.sin(2 * np.pi * 7 * T(d)))
    down = osc(f, 'tri') * np.linspace(1, 0.2, len(f)) * adsr(len(f), 0.01, release=0.1)
    tweets = [(chirp(3200, 4200, 0.07), 1.0 + i * 0.18, .35) for i in range(4)]
    return mix((down, 0, .9), *tweets, (puff(0.3, 600, 0.1), 0.95, .4))

@se('restart', -6)
def _():
    up = whoosh(0.5, 400, 2500, 1.2)
    return reverb(mix((up, 0, .6), (bell(hz('Eb6'), .8, .6, .3), 0.35, .6), (bell(hz('Bb6'), .8, .6, .3), 0.45, .5)), 0.5, 0.25)

@se('smoke_in', -6)
def _():
    return mix((puff(0.35, 700, 0.09), 0, 1), (lowpass(noise(0.3), 300) * np.exp(-T(0.3) / 0.1), 0.02, .7))

@se('smoke_out', -9)
def _():
    return whoosh(0.3, 900, 2600, 1.0)

# ---- アイテム・猫
@se('courage', -5)
def _():
    # 連続で取ったときは pitch_scale を半音ずつ上げて使う（2 ** (n / 12)）
    return reverb(mix((bell(hz('Bb6'), .5, .9, .14), 0, 1), (bell(hz('Eb7'), .5, .9, .12), 0.05, .7)), 0.3, 0.15)

@se('hat_restore', -3)
def _():
    notes = ['Eb5', 'G5', 'Bb5', 'Eb6', 'G6']
    parts = [(bell(hz(n), 1.2, .8, .45), i * 0.06, 1 - i * 0.08) for i, n in enumerate(notes)]
    return reverb(mix(*parts, (sparkle(6, 0.3, seed=2), 0, .35)), 0.6, 0.3)

@se('bonus', -5)
def _():
    return reverb(mix((bell(hz('Bb6'), .2, 1.2, .06), 0, 1), (bell(hz('Eb7'), .7, 1.2, .25), 0.07, 1)), 0.3, 0.15)

@se('cat_fall', -3)
def _():
    m = meow(820, 0.4, short=True)
    whistle = osc(glide(1500, 700, 0.7) * (1 + 0.02 * np.sin(2 * np.pi * 9 * T(0.7)))) * np.sin(np.pi * T(0.7) / 0.7) * 0.25
    return mix((m, 0, 1), (whistle, 0.3, 1))

@se('cat_catch', -3)
def _():
    m = meow(560, 0.65, happy=True)
    return mix((puff(0.2, 1200, 0.04), 0, .8), (pop(500, 250, 0.08), 0, .5), (m, 0.1, .9), (bell(hz('G6'), .5, .6, .2), 0.05, .25))

@se('cat_miss', -9)
def _():
    d = 0.9
    w = osc(glide(1200, 300, d)) * np.linspace(1, 0, int(d * SR)) ** 1.5
    return reverb(w * 0.8, 0.4, 0.2)

@se('candy_fire', -9)
def _():
    return mix((pop(1200, 400, 0.06), 0, 1), (puff(0.05, 3000, 0.01), 0, .4))

@se('candy_hit', -7)
def _():
    return mix((puff(0.18, 1500, 0.04), 0, 1), (sparkle(3, 0.02, seed=5, spacing=0.05), 0, .7))

@se('candy_eat', -5)
def _():
    crunch = lambda s: bandpass(np.random.default_rng(s).standard_normal(int(0.05 * SR)), 300, 2500) * np.exp(-T(0.05) / 0.012)
    piro = mix((marimba(hz('Bb6'), .12), 0, 1), (marimba(hz('Eb7'), .25), 0.06, 1))
    return mix((crunch(1), 0, 1), (crunch(2), 0.09, .9), (piro, 0.16, .7))

@se('barrier_on', -5)
def _():
    notes = ['Bb5', 'D6', 'F6', 'Bb6', 'D7']
    parts = [(bell(hz(n) * 1.003 ** k, 1.0, .5, .5), i * 0.035, .7) for i, n in enumerate(notes) for k in (0, 1)]
    return reverb(mix(*parts), 0.7, 0.35)

@se('cat_effect_warn', -10)
def _():
    return marimba(hz('C7'), 0.12)

@se('cat_effect_end', -7)
def _():
    d = 0.45
    hiss = svf(noise(d), glide(4000, 600, d), 1.2) * np.exp(-T(d) / 0.15)
    return mix((hiss, 0, .7), (marimba(hz('Eb6'), .2), 0.05, .5), (marimba(hz('Bb5'), .3), 0.15, .5))

# ---- 道中
@se('pigeon_incoming', -6)
def _():
    parts = []
    for b in range(3):           # 3 羽ぶん、少しずつずらす
        for k in range(7):
            parts.append((flap(b * 10 + k), b * 0.05 + k * 0.085 + RNG.uniform(0, 0.01), 0.6 + 0.4 * np.sin(np.pi * k / 6)))
    return mix(*parts)

@se('pigeon_scatter', -5)
def _():
    flaps = [(flap(100 + k), k * 0.045 + RNG.uniform(0, 0.02), 1 - k / 14) for k in range(12)]
    t = T(0.35)
    coo = np.sin(2 * np.pi * (330 + 40 * np.sin(np.pi * t / 0.35)) * t) * np.sin(np.pi * t / 0.35) ** 2 * (1 + 0.5 * np.sin(2 * np.pi * 18 * t))
    return mix(*flaps, (lowpass(coo, 1200), 0.15, .6))

@se('vane_spin', -10, loop=True)
def _():
    # 1 回転 0.5 秒、2 周で 1 秒。周期的に作ってそのままループ
    out = np.zeros(SR)
    for k in range(4):
        sq = creak(0.18, np.interp(T(0.18), [0, .18], [180, 320]), (900, 1900, 3100), 0.15, seed=k % 2)
        sq *= np.sin(np.pi * T(0.18) / 0.18)
        i = int(k * 0.25 * SR); n = min(len(sq), SR - i); out[i:i + n] += sq[:n] * (1 if k % 2 == 0 else .6)
    return out

@se('laundry_pop', -10)
def _():
    return mix((whoosh(0.08, 2500, 1200, 1.2), 0, 1), (whoosh(0.1, 2200, 900, 1.2), 0.07, .8))

@se('chimney_puff', -10)
def _():
    return mix((whoosh(0.25, 300, 1200, 1.5), 0, 1), (pop(300, 120, 0.08), 0.18, .5))

@se('church_bell', -3)
def _():
    return reverb(church_bell(hz('Eb4'), 4.0), 1.2, 0.35)

# ---- ボス
@se('boss_appear', -2)
def _():
    d = 1.8
    rate = np.interp(T(d), [0, .8, 1.8], [60, 25, 45])
    g = creak(d, rate, (320, 760, 1450), 0.35, seed=3) * adsr(int(d * SR), 0.05, release=0.4)
    thud = lowpass(noise(0.4), 150) * np.exp(-T(0.4) / 0.1)
    return reverb(mix((g, 0, 1), (thud, 1.3, 1.2)), 0.8, 0.3)

@se('boss_crow', -2)
def _():
    return reverb(rooster(1.0), 0.6, 0.25)

@se('boss_koke', -8)
def _():
    return reverb(rooster(0.9, short=True), 0.5, 0.2)

@se('arrow_volley', -5)
def _():
    parts = []
    for k in range(3):
        parts.append((whoosh(0.18, 4500, 1500, 2.5), k * 0.07, 1))
        parts.append((osc(glide(1800, 900, 0.15)) * np.sin(np.pi * T(0.15) / 0.15) ** 2 * 0.15, k * 0.07, 1))
    return mix(*parts)

@se('gust_warning', -4)
def _():
    # 1 秒の予告。風見鶏の回転が速くなる（軋みの間隔が詰まる）＋音程が上がる
    d = 1.0
    sq = creak(d, glide(6, 40, d), (900, 1900, 3100), 0.1, seed=9)
    whine = osc(glide(350, 1400, d), 'tri') * np.linspace(0.1, 1, int(d * SR)) ** 2 * 0.3
    return mix((sq, 0, .8), (whine, 0, 1))

@se('gust', -3)
def _():
    d = 3.2
    w = wind(d, 400, 1300, 1.3, seed=4) * adsr(int(d * SR), 0.15, release=0.6)
    return w

@se('storm_loop', -6, loop=True)
def _():
    w = wind(4.3, 350, 1000, 0.9, seed=6)
    for k in range(10):
        i = int((0.2 + k * 0.4 + RNG.uniform(0, .1)) * SR)
        f = whoosh(0.12, 2500, 1000, 1.5) * 0.5
        w[i:i + len(f)] += f
    return seamless(w, 0.3)

@se('boss_satisfied', -3)
def _():
    notes = ['Eb4', 'Bb4', 'G5', 'D6', 'F6', 'Bb6']
    parts = [(bell(hz(n), 2.2, .5, .9), i * 0.07, .8) for i, n in enumerate(notes)]
    padv = sum(np.sin(2 * np.pi * hz(n) * T(2.2)) for n in ('Eb4', 'G4', 'Bb4')) * np.sin(np.pi * T(2.2) / 2.2) * 0.15
    return reverb(mix(*parts, (padv, 0, 1)), 1.0, 0.35)

@se('boss_leave', -8)
def _():
    d = 2.0
    g = creak(d, glide(30, 4, d), (900, 1900, 3100), 0.1, seed=12) * np.linspace(1, 0, int(d * SR))
    return g

@se('god_voice', -8)
def _():
    return reverb(mix((pluck(hz('Bb4'), 1.6), 0, 1), (pluck(hz('Eb5'), 1.6), 0.08, .8), (pluck(hz('G5'), 1.6), 0.16, .7)), 1.0, 0.4)

# ---- UI・進行
@se('ui_start', -3)
def _():
    notes = ['Eb4', 'Bb4', 'Eb5', 'G5', 'Bb5']
    return reverb(mix(*[(piano(hz(n), 0.8, .7), i * 0.07, 1) for i, n in enumerate(notes)]), 0.6, 0.3)

@se('stage_card', -5)
def _():
    notes = ['Eb6', 'F6', 'G6', 'Bb6', 'C7', 'Eb7', 'F7', 'G7']
    return reverb(mix(*[(bell(hz(n), 0.8, .6, .3), i * 0.035, .7) for i, n in enumerate(notes)]), 0.8, 0.35)

@se('talk_meruru', -12)
def _():
    d = 0.07
    return osc(glide(hz('G5'), hz('Bb5'), d)) * np.exp(-T(d) / 0.025) * adsr(int(d * SR), 0.002, release=0.01)

@se('talk_god', -10)
def _():
    return reverb(bell(hz('Eb5'), 0.5, .4, .2), 0.6, 0.35)

@se('pop_score', -14)
def _():
    return marimba(hz('Eb7'), 0.08)

@se('gauge_show', -12)
def _():
    return mix((marimba(hz('C6'), 0.1), 0, 1), (puff(0.03, 4000, 0.005), 0, .5))

@se('result_line', -8)
def _():
    return reverb(piano(hz('Bb5'), 0.25, .6), 0.4, 0.2)

@se('new_best', -3)
def _():
    seq = [('Bb4', 0, .3), ('Eb5', .12, .3), ('G5', .24, .3), ('Bb5', .36, 1.2)]
    parts = [(piano(hz(n), d, .8), s, 1) for n, s, d in seq]
    parts += [(piano(hz(n), 1.2, .6), .36, .6) for n in ('Eb4', 'G4', 'Eb5')]
    return reverb(mix(*parts, (sparkle(6, .4, seed=3), 0, .4)), 0.8, 0.3)

# ---------------------------------------------------------------- 書き出し

# ---------------------------------------------------------------- STAGE 2「丘と森の上空」
# ここから下の音は、それぞれ自分の乱数（seed 固定）を使う。STAGE 1 の 42 音の結果を変えないため。

def rng(seed):
    return np.random.default_rng(seed)

def nz(d, seed):
    return rng(seed).standard_normal(int(d * SR))

def honk(f0=330, d=0.22, seed=0):
    """雁の「がー」。鼻にかかった声（ノコギリ波＋鼻音のフォルマント）、音程は少し下がる。"""
    t = T(d); u = t / d
    f = f0 * (1.08 - 0.16 * u) * (1 + 0.012 * np.sin(2 * np.pi * 23 * t))
    src = osc(f, 'saw') + 0.12 * nz(d, seed)
    y = svf(src, 750, 5) + 0.9 * svf(src, 1500, 7) + 0.35 * svf(src, 2900, 6) - 0.4 * svf(src, 1000, 9)
    env = np.interp(u, [0, .08, .6, 1], [0, 1, .8, 0])
    return y * env

def big_flap(seed=0, d=0.11):
    """大きな鳥の羽ばたき 1 回（鳩より低く長い）。"""
    x = bandpass(nz(d, seed), 250, 1500) * np.exp(-T(d) / 0.035)
    return x * adsr(len(x), 0.006)

def wood_knock(f=180, d=0.35, seed=0):
    """木の「ごとん」。低い打撃＋木の共鳴。"""
    hit = lowpass(nz(0.02, seed), 1200) * np.exp(-T(0.02) / 0.004)
    t = T(d)
    body = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / dec)
               for r, a, dec in ((1.0, 1.0, 0.09), (2.3, 0.5, 0.05), (3.9, 0.25, 0.03)))
    return mix((hit, 0, 0.6), (body, 0.002, 1.0))

def periodic(length, events):
    """length 秒のループ用バッファに events [(信号, 開始秒, 音量)] を置く。はみ出した分は頭に回す（継ぎ目なし）。"""
    n = int(length * SR)
    out = np.zeros(n)
    for x, s, g in events:
        i = int(s * SR) % n
        k = 0
        while k < len(x):
            m = min(len(x) - k, n - i)
            out[i:i + m] += x[k:k + m] * g
            k += m; i = 0
    return out

@se('balloon_pop', -3)
def _():
    # ぱんっ: 鋭い破裂（高域のノイズが一瞬）＋ゴムが縮む音（音程が急に下がる）＋小さな空気の抜け
    burst = highpass(nz(0.07, 201), 700) * np.exp(-T(0.07) / 0.014)
    snap = osc(glide(1400, 380, 0.06)) * np.exp(-T(0.06) / 0.02)
    thump = lowpass(nz(0.08, 202), 260) * np.exp(-T(0.08) / 0.025)
    air = whoosh(0.12, 3500, 1500, 1.0) * 0.12
    x = mix((burst, 0, 1.0), (snap, 0.001, 0.6), (thump, 0, 0.9))
    # 鋭すぎる山を丸めて短くても聞こえる大きさにし、丸めで伸びた後ろはもう一度すぐ減衰させる
    x = np.tanh(3.0 * x / np.abs(x).max()) * np.exp(-T(len(x) / SR) / 0.03)
    return reverb(mix((x, 0, 1), (air, 0.01, 1)), 0.3, 0.12)

@se('balloon_rise', -6)
def _():
    # きゅっ…: ゴムがこすれる短い音。音程が上がって少し戻る、こすれのざらつき（細かい振幅の揺れ）
    d = 0.26; t = T(d); u = t / d
    f = hz('Bb5') * (1 + 0.5 * np.sin(np.pi * np.minimum(u * 1.3, 1)) ** 1.5)
    grit = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 55 * t)) * (rng(203).random(len(t)) > 0.3)
    x = osc(f, 'tri') * grit
    x = bandpass(x, 700, 4500)
    env = np.interp(u, [0, .1, .55, 1], [0, 1, .7, 0])
    return x * env

@se('fluff_storm_loop', -8, loop=True)
def _():
    # ふわふわ舞う軽い風: 高めの帯域の柔らかい風＋ときどき小さな「ふわっ」。洗濯物のばさばさは入れない
    L = 4.3
    w = wind(L, 900, 2600, 0.6, seed=210) * 0.7 + lowpass(nz(L, 211), 400) * 0.15
    r = rng(212)
    for k in range(9):
        s = 0.2 + k * 0.45 + r.uniform(0, 0.15)
        p = whoosh(0.22, r.uniform(2500, 4000), r.uniform(1200, 1800), 1.2) * 0.35
        i = int(s * SR); w[i:i + len(p)] += p[:len(w) - i]
    return seamless(w, 0.3)

@se('geese_scatter', -4)
def _():
    flaps = [(big_flap(220 + k), k * 0.07 + rng(221 + k).uniform(0, 0.02), 1 - k / 12) for k in range(9)]
    return mix(*flaps, (honk(340, 0.2, 222), 0.12, 0.7), (honk(300, 0.24, 223), 0.34, 0.55))

@se('windmill_loop', -8, loop=True)
def _():
    # ぎぃ…ごとん: 木の大きな軋み（ゆっくりのスティックスリップ、木の低い共鳴）と、羽根が一回りするごとの「ごとん」
    L = 2.0
    sq = creak(1.1, np.interp(T(1.1), [0, 1.1], [35, 70]), (260, 520, 950), 0.3, seed=230)
    sq *= np.sin(np.pi * T(1.1) / 1.1) ** 1.2
    return periodic(L, [(sq, 0.15, 1.0), (wood_knock(150, 0.4, 231), 1.45, 0.9)])

@se('boss2_start', -2)
def _():
    # ごごん…: 大きな木の歯車がかみ合う。重い打撃が 2 つ、歯が噛む細かい音、低い唸り
    clicks = [(wood_knock(420 + 30 * k, 0.08, 240 + k) * 0.25, 0.05 + k * 0.045, 1) for k in range(6)]
    g1 = wood_knock(90, 0.9, 246)
    g2 = wood_knock(70, 1.2, 247)
    rumble = lowpass(nz(1.8, 248), 120) * np.interp(T(1.8), [0, .4, 1.8], [0, 1, 0])
    return reverb(mix(*clicks, (g1, 0.32, 1.0), (g2, 0.62, 1.1), (rumble, 0.3, 0.6)), 1.0, 0.3)

@se('boss2_blades_loop', -8, loop=True)
def _():
    # windmill_loop より低く重い軋み＋大きな羽根が風を切る「ぶぉん」（2 秒で 2 回）
    L = 2.0
    sq = creak(1.6, np.interp(T(1.6), [0, 1.6], [22, 40]), (150, 330, 640), 0.3, seed=250)
    sq *= np.sin(np.pi * T(1.6) / 1.6)
    swish = lambda seed: svf(nz(0.6, seed), glide(250, 700, 0.6), 2.0) * np.sin(np.pi * T(0.6) / 0.6) ** 2
    return periodic(L, [(sq, 0.1, 0.8), (swish(251), 0.0, 0.9), (swish(252), 1.0, 0.9),
                        (wood_knock(100, 0.5, 253), 1.7, 0.6)])

@se('geese_incoming', -6)
def _():
    parts = []
    for b in range(4):          # 4 羽ぶん、ゆっくり大きく
        for k in range(6):
            parts.append((big_flap(260 + b * 10 + k), b * 0.07 + k * 0.14 + rng(270 + b * 10 + k).uniform(0, 0.015),
                          0.5 + 0.5 * np.sin(np.pi * k / 5)))
    parts.append((honk(360, 0.18, 280) * 0.5, 0.5, 1))
    return mix(*parts)

@se('fluff_pop', -10)
def _():
    # ふわっ: 柔らかく上へ抜ける空気＋ごく小さなきらめき
    d = 0.28
    air = svf(nz(d, 290), glide(1200, 4000, d), 1.0) * np.sin(np.pi * T(d) / d) ** 1.5
    return mix((air, 0, 1), (bell(hz('Eb7'), 0.25, 0.4, 0.06), 0.06, 0.12))

@se('flour_throw', -6)
def _():
    # ひゅっ: 重い袋が飛ぶ（低めの風切り）＋袋の布がはためく
    d = 0.4
    swish = svf(nz(d, 300), glide(1200, 320, d), 1.6) * np.sin(np.pi * T(d) / d) ** 1.2
    cloth = bandpass(nz(d, 301), 400, 2000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * T(d)))) \
        * np.sin(np.pi * T(d) / d) * 0.25
    return mix((swish, 0, 1), (cloth, 0.03, 1))

@se('tree_rustle', -4)
def _():
    # ざわざわ: 葉擦れ（細かいノイズの粒が寄せて返す）＋遠くの小鳥。STAGE 1 の教会の鐘にあたる目印
    d = 1.8; r = rng(310)
    out = np.zeros(int(d * SR))
    swell = np.interp(T(d), [0, .5, 1.1, 1.8], [0.15, 1, .7, 0])
    for k in range(260):
        s = r.uniform(0, d - 0.05)
        g = bandpass(r.standard_normal(int(0.03 * SR)), 2000, 7000) * np.exp(-T(0.03) / 0.008)
        i = int(s * SR); out[i:i + len(g)] += g * r.uniform(.3, 1) * swell[i]
    out += bandpass(nz(d, 311), 600, 2500) * swell * 0.25
    birds = [(chirp(hz(nm), hz(nm) * 1.12, 0.06) * 0.25, s, 1) for nm, s in (('Bb6', 0.7), ('Eb7', 0.82), ('Bb6', 1.25))]
    return mix((out, 0, 1), *birds)

# ---- UI（ステージ選択）
@se('ui_select', -12)
def _():
    # ステージ選択で ←→: 小さなチェレスタ（スコアのポップと分ける）
    return reverb(mix((bell(hz('G6'), 0.25, 0.5, 0.07), 0, 1), (marimba(hz('G5'), 0.1), 0, 0.4)), 0.3, 0.12)

@se('ui_locked', -10)
def _():
    # まだ遊べないステージで決定: こもった低い 2 音（D → C）。責める感じにしない
    a = lowpass(marimba(hz('D5'), 0.14), 1800)
    b = lowpass(marimba(hz('C5'), 0.2), 1500)
    return mix((a, 0, 1), (b, 0.11, 0.9))

# 聞こえの大きさの目標（最も大きい 100ms 区間の RMS, dBFS）。
# 予告・危険は大きめ、連発するもの・UI は小さめ。ピークは -1dBFS を超えないようにする。
LOUD = {
    'hit': -12, 'hat_warning': -14, 'faint': -12, 'restart': -16, 'smoke_in': -16, 'smoke_out': -21,
    'courage': -14, 'hat_restore': -13, 'bonus': -14, 'cat_fall': -12, 'cat_catch': -12, 'cat_miss': -17,
    'candy_fire': -20, 'candy_hit': -17, 'candy_eat': -14, 'barrier_on': -15, 'cat_effect_warn': -18,
    'cat_effect_end': -18, 'pigeon_incoming': -15, 'pigeon_scatter': -15, 'vane_spin': -22,
    'laundry_pop': -22, 'chimney_puff': -22, 'church_bell': -13, 'boss_appear': -12, 'boss_crow': -11,
    'boss_koke': -17, 'arrow_volley': -14, 'gust_warning': -13, 'gust': -14, 'storm_loop': -18,
    'boss_satisfied': -13, 'boss_leave': -22, 'god_voice': -18, 'ui_start': -14, 'stage_card': -16,
    'talk_meruru': -24, 'talk_god': -19, 'pop_score': -24, 'gauge_show': -21, 'result_line': -17, 'new_best': -13,
    # STAGE 2
    'balloon_pop': -12, 'balloon_rise': -16, 'fluff_storm_loop': -20, 'geese_scatter': -15, 'windmill_loop': -22,
    'boss2_start': -11, 'boss2_blades_loop': -20, 'geese_incoming': -15, 'fluff_pop': -21, 'flour_throw': -16,
    'tree_rustle': -15,
    # UI
    'ui_select': -22, 'ui_locked': -19,
}

def loudness_db(x):
    w = int(0.1 * SR)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
    return 20 * np.log10(max(np.sqrt((x[i:i + w] ** 2).mean()) for i in range(0, len(x) - w, w // 2)) + 1e-12)

def render(name):
    fn, _peak_db, loop = SE[name]
    x = np.asarray(fn(), float)
    if not loop:
        # 末尾の無音を詰め、最後は 10ms でフェード
        thr = np.abs(x).max() * 10 ** (-60 / 20)
        idx = np.nonzero(np.abs(x) > thr)[0]
        x = x[:idx[-1] + int(0.01 * SR)] if len(idx) else x
        f = min(len(x), int(0.01 * SR)); x[-f:] *= np.linspace(1, 0, f)
        x = highpass(x, 40, 1)
    x = x * 10 ** ((LOUD[name] - loudness_db(x)) / 20)
    peak = np.abs(x).max()
    if peak > 10 ** (-1 / 20):
        x *= 10 ** (-1 / 20) / peak
    os.makedirs(OUT, exist_ok=True)
    wavfile.write(os.path.join(OUT, name + '.wav'), SR, (x * 32767).astype(np.int16))
    return len(x) / SR

if __name__ == '__main__':
    names = sys.argv[1:] or list(SE)
    for n in names:
        print(f'{n:18s} {render(n):5.2f}s' + ('  (loop)' if SE[n][2] else ''))
