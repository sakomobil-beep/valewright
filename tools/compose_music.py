#!/usr/bin/env python3
"""Hintergrundmusik für Valewright – im Code komponiert (keine fremden Aufnahmen, keine Lizenzfragen).

Instrumente: gezupfte Laute/Harfe (Karplus-Strong), Holzflöte (Sinus + Obertöne, Vibrato, Atem),
Bordun (tiefer Haltetton wie bei Drehleier/Dudelsack), Rahmentrommel. Ergebnis: OGG-Dateien in music/.
Aufruf: python3 tools/compose_music.py
"""
import numpy as np, subprocess, os, wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "music")
os.makedirs(OUT, exist_ok=True)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12)

def pluck(freq, dur, amp=0.4, bright=0.5, rng=None):
    n = int(SR * dur)
    p = max(2, int(SR / freq))
    buf = (rng.random(p) * 2 - 1) * amp
    out = np.zeros(n)
    decay = 0.996 - (1 - bright) * 0.004
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = decay * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    env = np.ones(n); r = min(n, int(SR * 0.05)); env[-r:] = np.linspace(1, 0, r)
    return out * env

def flute(freq, dur, amp=0.22, rng=None):
    n = int(SR * dur); t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.35, 0, 1)
    ph = 2 * np.pi * freq * np.cumsum(vib) / SR
    s = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    s += (rng.random(n) * 2 - 1) * 0.04          # Atem
    a = min(0.08, dur * 0.3); rel = min(0.15, dur * 0.4)
    env = np.clip(t / a, 0, 1) * np.clip((dur - t) / rel, 0, 1)
    return s * env * amp

def drone(freq, dur, amp=0.10):
    n = int(SR * dur); t = np.arange(n) / SR
    s = np.sin(2*np.pi*freq*t) + 0.5*np.sin(2*np.pi*freq*1.5*t) + 0.3*np.sin(2*np.pi*freq*2*t)
    s *= 1 + 0.1 * np.sin(2 * np.pi * 0.2 * t)
    env = np.clip(t / 1.5, 0, 1) * np.clip((dur - t) / 1.5, 0, 1)
    return s * env * amp

def drum(dur=0.35, amp=0.5, low=True, rng=None):
    n = int(SR * dur); t = np.arange(n) / SR
    f = (90 if low else 180) * np.exp(-t * 8) + (45 if low else 120)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (9 if low else 18))
    s += (rng.random(n) * 2 - 1) * np.exp(-t * 40) * 0.25
    return s * amp

def mix(buf, snd, at):
    i = int(at * SR)
    if i >= len(buf): return
    e = min(len(buf), i + len(snd))
    buf[i:e] += snd[:e - i]

def reverb(x):
    y = x.copy()
    for d, g in [(0.031, 0.35), (0.047, 0.3), (0.071, 0.25), (0.113, 0.2), (0.167, 0.15)]:
        k = int(d * SR); y[k:] += x[:-k] * g
    return y

def save(name, buf):
    buf = reverb(buf)
    buf /= max(1e-6, np.max(np.abs(buf))) / 0.85
    # weiches Ein-/Ausblenden, damit die Schleife nicht knackt
    f = int(SR * 0.6); buf[:f] *= np.linspace(0, 1, f); buf[-f:] *= np.linspace(1, 0, f)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((buf * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)

# D-Dorisch (mittelalterlich), Akkorde als Stufen
DORIAN = [0, 2, 3, 5, 7, 9, 10]
def deg(root, d):  # Tonleiterstufe → MIDI
    o, i = divmod(d, 7)
    return root + DORIAN[i] + 12 * o

def compose(name, seed, bpm, bars, prog, root, mood, drums, flute_on=True, drone_on=True):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat + 1.0
    buf = np.zeros(int(SR * total))
    motif = [int(x) for x in rng.choice([0, 1, 2, 3, 4, 2, 1, 4, 5, 3], 8)]
    for b in range(bars):
        chord = prog[b % len(prog)]
        t0 = b * 4 * beat
        if drone_on and b % 4 == 0:
            mix(buf, drone(midi(root - 24 + DORIAN[chord % 7]), 4 * 4 * beat, 0.07 if mood == "calm" else 0.09), t0)
        # Laute: gebrochener Akkord (Arpeggio) in Achteln
        pattern = [0, 2, 4, 2, 7, 4, 2, 4] if mood != "battle" else [0, 4, 7, 4, 0, 4, 7, 9]
        for k, step in enumerate(pattern):
            n = deg(root - 12, chord + step)
            mix(buf, pluck(midi(n), beat * 1.6, 0.35 if k % 2 == 0 else 0.25, 0.6 if mood == "battle" else 0.45, rng), t0 + k * beat / 2)
        # Flöte: Motiv, leicht variiert, mit Pausen
        if flute_on and (b % 8) >= 2:
            phrase = motif if (b // 2) % 2 == 0 else [m + int(rng.integers(-1, 2)) for m in motif]
            durs = [1, 0.5, 0.5, 1, 1] if mood != "battle" else [0.5] * 8
            t = t0
            for j, d in enumerate(durs):
                if t >= t0 + 4 * beat: break
                if rng.random() < 0.12 and mood == "calm":
                    t += d * beat; continue
                n = deg(root + 12, chord + phrase[j % len(phrase)])
                mix(buf, flute(midi(n), d * beat * 0.95, 0.2 if mood != "battle" else 0.17, rng), t)
                t += d * beat
        # Trommel
        if drums:
            for k in range(4):
                if mood == "battle":
                    mix(buf, drum(0.3, 0.55, True, rng), t0 + k * beat)
                    mix(buf, drum(0.2, 0.3, False, rng), t0 + k * beat + beat / 2)
                elif k in (0, 2):
                    mix(buf, drum(0.35, 0.35 if k == 0 else 0.25, True, rng), t0 + k * beat)
    save(name, buf)
    print(name, round(total, 1), "s")

if __name__ == "__main__":
    R = 62  # D
    compose("aufbau_1", 11, 84, 32, [0, 3, 6, 0, 4, 3, 0, 6], R, "calm", True)          # ruhig: Felder & Werkstätten
    compose("aufbau_2", 23, 104, 32, [0, 4, 3, 4, 0, 6, 3, 4], R + 5, "happy", True)     # fröhlicher Markttag (G)
    compose("aufbau_3", 37, 72, 24, [0, 5, 3, 0, 6, 5, 4, 0], R - 2, "calm", False)      # Abendstimmung (C)
    compose("kampf", 51, 132, 24, [0, 0, 6, 6, 5, 5, 6, 4], R, "battle", True)          # Angriff
    compose("menu", 7, 76, 16, [0, 3, 4, 0, 6, 3, 4, 0], R, "calm", True, True)          # feierliches Menü
