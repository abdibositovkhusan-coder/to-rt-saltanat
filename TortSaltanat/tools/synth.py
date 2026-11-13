# 10-bosqich: o'yin ovozlari va musiqasini noldan sintez qiladi (tashqi fayllarsiz, 100% original).
# Natija: <loyiha>/assets/audio/sfx/*.wav va assets/audio/music/*.wav (16-bit mono).
import numpy as np, wave, os, sys
from scipy.signal import lfilter

ROOT = sys.argv[1]
SR = 22050
rng = np.random.default_rng(7)
OUT_SFX = os.path.join(ROOT, "assets/audio/sfx")
OUT_MUS = os.path.join(ROOT, "assets/audio/music")
os.makedirs(OUT_SFX, exist_ok=True)
os.makedirs(OUT_MUS, exist_ok=True)


def save(path, x, sr=SR, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def t_(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, a=0.005, d=0.2, sr=SR):
    t = np.arange(n) / sr
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / max(d, 1e-4))
    return e


def lowpass(x, cutoff, sr=SR):
    # oddiy bir qutbli filtr
    a = np.exp(-2 * np.pi * cutoff / sr)
    return lfilter([1 - a], [1, -a], np.asarray(x, dtype=np.float64))


def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def sweep(f0, f1, dur, shape="sin"):
    t = t_(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "sq":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def tone(freq, dur, shape="sin", a=0.005, d=0.3):
    t = t_(dur)
    ph = 2 * np.pi * freq * t
    if shape == "saw":
        w = 2 * ((freq * t) % 1.0) - 1
    elif shape == "tri":
        w = 2 * np.abs(2 * ((freq * t) % 1.0) - 1) - 1
    elif shape == "sq":
        w = np.sign(np.sin(ph))
    else:
        w = np.sin(ph)
    return w * env(len(t), a, d)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total):
    out = np.zeros(int(total * SR))
    s = int(offset * SR)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def pluck(freq, dur, bright=0.5, decay=0.996):
    """Karplus-Strong — dutor/tanbur tori."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p)
    buf = lowpass(buf, 1500 + 6000 * bright)
    blocks = []
    total = 0
    while total < n:
        blocks.append(buf.copy())
        total += p
        buf = decay * 0.5 * (buf + np.roll(buf, -1))
    out = np.concatenate(blocks)[:n]
    return out * env(n, 0.002, dur * 0.6)


# ======================= SFX =======================
S = {}
S["click"] = mix(tone(1200, 0.06, "sin", 0.001, 0.02), 0.4 * tone(2400, 0.04, "sin", 0.001, 0.01))
S["select"] = mix(tone(660, 0.12, "tri", 0.002, 0.05), at(tone(990, 0.1, "tri", 0.002, 0.05), 0.05, 0.15))
S["order"] = mix(tone(520, 0.1, "tri", 0.002, 0.04), at(tone(390, 0.1, "tri", 0.002, 0.05), 0.06, 0.16))
n = noise(0.25)
S["sword"] = mix(highpass(n, 2500) * env(len(n), 0.001, 0.05), tone(1800, 0.25, "sin", 0.001, 0.08) * 0.5, tone(2730, 0.25, "sin", 0.001, 0.06) * 0.3)
n = noise(0.3)
S["hit"] = mix(lowpass(n, 900) * env(len(n), 0.001, 0.06), sweep(180, 60, 0.15) * env(int(0.15 * SR), 0.001, 0.05))
n = noise(0.35)
S["arrow"] = mix(highpass(n, 3000) * np.sin(np.linspace(0, np.pi, len(n))) * 0.6, at(tone(900, 0.06, "sin", 0.001, 0.02), 0.28, 0.35))
S["magic"] = mix(sweep(400, 1600, 0.5, "sin") * env(int(0.5 * SR), 0.05, 0.3), sweep(600, 2400, 0.5, "sin") * env(int(0.5 * SR), 0.05, 0.25) * 0.5,
                 highpass(noise(0.5), 4000) * env(int(0.5 * SR), 0.02, 0.2) * 0.2)
n = noise(1.0)
S["explosion"] = mix(lowpass(n, 500) * env(len(n), 0.002, 0.35), sweep(120, 35, 0.6) * env(int(0.6 * SR), 0.002, 0.25))
n = noise(0.6)
S["death"] = mix(sweep(300, 90, 0.5, "saw") * env(int(0.5 * SR), 0.01, 0.2) * 0.4, lowpass(n, 700) * env(len(n), 0.001, 0.15))
S["build"] = mix(*[at(lowpass(noise(0.12), 1500) * env(int(0.12 * SR), 0.001, 0.03) + tone(220, 0.12, "sin", 0.001, 0.04), i * 0.18, 0.75) for i in range(4)])
S["done"] = mix(tone(523, 0.3, "tri", 0.005, 0.2), at(tone(659, 0.3, "tri", 0.005, 0.2), 0.12, 0.6), at(tone(784, 0.45, "tri", 0.005, 0.3), 0.24, 0.8))
S["levelup"] = mix(*[at(tone(f, 0.35, "tri", 0.004, 0.25), i * 0.09, 1.0) for i, f in enumerate([523, 659, 784, 1046, 1318])],
                   at(highpass(noise(0.6), 5000) * env(int(0.6 * SR), 0.05, 0.3) * 0.3, 0.2, 1.0))
S["coin"] = mix(tone(1567, 0.25, "sin", 0.001, 0.08), at(tone(2093, 0.3, "sin", 0.001, 0.12), 0.07, 0.4))
S["error"] = mix(tone(220, 0.12, "sq", 0.002, 0.06) * 0.4, at(tone(180, 0.15, "sq", 0.002, 0.08) * 0.4, 0.11, 0.3))
# karnay — dushman hujumi signali
t = t_(1.4)
k = (2 * ((233 * t + 3 * np.sin(2 * np.pi * 5 * t) / 233) % 1.0) - 1)
S["horn"] = lowpass(k, 1400) * np.minimum(1, t / 0.15) * np.minimum(1, (1.4 - t) / 0.3)
S["victory"] = mix(*[at(tone(f, 0.5, "tri", 0.01, 0.4) + 0.5 * tone(f * 2, 0.5, "sin", 0.01, 0.3), o, 2.2)
                     for f, o in [(392, 0), (523, 0.25), (659, 0.5), (784, 0.75), (1046, 1.1)]])
S["defeat"] = mix(*[at(tone(f, 0.7, "tri", 0.02, 0.5), o, 2.4) for f, o in [(392, 0), (349, 0.45), (311, 0.9), (262, 1.4)]])
S["heal"] = mix(sweep(500, 900, 0.6, "sin") * env(int(0.6 * SR), 0.1, 0.3) * 0.6, at(tone(1320, 0.4, "sin", 0.05, 0.2) * 0.3, 0.2, 0.7))

for name, x in S.items():
    save(os.path.join(OUT_SFX, name + ".wav"), x)


# ======================= MUSIQA =======================
def note_freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def doira(pattern, step, total, low=1.0, high=1.0):
    """Doira: 'D' — dum (past), 't' — tak (yuqori), '.' — tanaffus."""
    out = np.zeros(int(total * SR))
    for i, ch in enumerate(pattern * int(np.ceil(total / (len(pattern) * step)))):
        o = i * step
        if o >= total:
            break
        if ch == "D":
            d = mix(sweep(110, 55, 0.25) * env(int(0.25 * SR), 0.001, 0.09) * low,
                    lowpass(noise(0.05), 600) * env(int(0.05 * SR), 0.001, 0.02) * 0.3 * low)
            out += at(d, o, total)
        elif ch == "t":
            h = mix(highpass(noise(0.08), 2500) * env(int(0.08 * SR), 0.001, 0.025) * 0.45 * high,
                    tone(900, 0.06, "sin", 0.001, 0.02) * 0.15 * high)
            out += at(h, o, total)
    return out


def flute(freq, dur):
    t = t_(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.3)
    ph = 2 * np.pi * freq * np.cumsum(vib) / SR
    w = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = highpass(noise(dur), 3000)[:len(t)] * 0.05
    e = np.minimum(1, t / 0.06) * np.minimum(1, np.maximum(0, (dur - t)) / 0.08)
    return (w + breath) * e


def brass(freq, dur):
    t = t_(dur)
    w = 2 * ((freq * t) % 1.0) - 1
    e = np.minimum(1, t / 0.05) * np.minimum(1, np.maximum(0, (dur - t)) / 0.1)
    return lowpass(w, 1700) * e


def pad(freqs, dur, shape="sin"):
    t = t_(dur)
    out = np.zeros(len(t))
    for f in freqs:
        out += np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.003 * t)
    e = np.minimum(1, t / 1.0) * np.minimum(1, np.maximum(0, (dur - t)) / 1.0)
    return out * e / max(1, len(freqs))


def melody(scale, root, bars, beats_per_bar, beat, seed, motif_len=8):
    r = np.random.default_rng(seed)
    motif = []
    pos = 2
    for i in range(motif_len):
        pos = int(np.clip(pos + r.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(scale) * 2 - 1))
        length = r.choice([1, 1, 1, 2])
        motif.append((pos, length))
    notes = []
    o = 0.0
    total_beats = bars * beats_per_bar
    k = 0
    while o < total_beats:
        p, l = motif[k % len(motif)]
        if (k // len(motif)) % 2 == 1 and k % len(motif) >= len(motif) - 3:
            p = max(0, p - 2)  # ikkinchi takrorda biroz pastga — javob iborasi
        midi = root + 12 * (p // len(scale)) + scale[p % len(scale)]
        notes.append((o * beat, min(l, total_beats - o) * beat, midi))
        o += l
        k += 1
    return notes


def song(name, scale, root, bpm, bars, lead, bass_root, drum, pad_notes, seed, drum_amp=(1.0, 1.0)):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = np.zeros(int(total * SR))
    # Doira
    out += doira(drum, beat / 2, total, *drum_amp) * 0.55
    # Bass (dutor)
    for b in range(bars):
        f = note_freq(bass_root + (0 if b % 4 < 2 else scale[3] if b % 4 == 2 else scale[4]))
        for q in [0, 1.5, 3]:
            out += at(pluck(f, beat * 1.5, 0.3) * 0.5, (b * 4 + q) * beat, total)
    # Pad
    out += pad([note_freq(n) for n in pad_notes], total) * 0.18
    # Kuy
    for (o, d, midi) in melody(scale, root, bars, 4, beat, seed):
        f = note_freq(midi)
        if lead == "flute":
            x = flute(f, d * 0.95)
        elif lead == "brass":
            x = brass(f, d * 0.95)
        else:
            x = pluck(f, d * 1.2, 0.8, 0.998)
        out += at(x * 0.42, o, total)
    # Yumshoq boshlanish/tugash halqa uchun
    fade = int(0.03 * SR)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    save(os.path.join(OUT_MUS, name + ".wav"), out, peak=0.7)
    print(name, round(total, 1), "s")


# Maqomlarga yaqin tovushqatorlar
HIJAZ = [0, 1, 4, 5, 7, 8, 10]
PENTA = [0, 2, 4, 7, 9]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
PHRYG = [0, 1, 3, 5, 7, 8, 10]
MAJOR = [0, 2, 4, 5, 7, 9, 11]

song("menu", DORIAN, 62, 84, 8, "pluck", 38, "D.t.D.tt", [50, 57, 62], 11, (0.8, 0.6))
song("odamlar", MAJOR, 67, 104, 8, "brass", 43, "D.tD.tt.", [55, 59, 62], 21)
song("trollar", PHRYG, 52, 92, 8, "brass", 28, "D.D.t.D.", [40, 47, 52], 31, (1.4, 0.7))
song("elflar", PENTA, 74, 88, 8, "flute", 50, "D..t.t..", [62, 66, 69], 41, (0.6, 0.8))
song("yalmogiz", HIJAZ, 60, 80, 8, "pluck", 36, "D..tD.t.", [48, 51, 55], 51, (1.0, 0.7))
print("sfx:", len(S))
