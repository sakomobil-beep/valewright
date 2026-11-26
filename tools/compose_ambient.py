#!/usr/bin/env python3
"""Umgebungs- und Arbeitsgeräusche für Valewright – komplett im Code erzeugt (keine fremden Aufnahmen).

Vögel (Amsel, Meise, Buchfink, Kuckuck, Specht), Blätterrauschen bei Windböen, Bach,
Arbeitsgeräusche (Amboss, Säge, Holzhammer, Spitzhacke, Feuer, Brodeln, Webstuhl, Knarren,
Messer, Drehscheibe, Münzen) und Tiere (Schaf, Kuh, Schwein, Bienen).
Ergebnis: OGG-Dateien in sounds/. Aufruf: python3 tools/compose_ambient.py
"""
import numpy as np, subprocess, os, wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1307)

def t_(d): return np.arange(int(SR * d)) / SR

def env(n, a=0.005, r=0.05):
    e = np.ones(n); ai = max(1, int(SR * a)); ri = max(1, int(SR * r))
    e[:ai] = np.linspace(0, 1, ai); e[-ri:] *= np.linspace(1, 0, ri); return e

def lp(x, k):   # einfacher Tiefpass (gleitender Mittelwert, k-fach)
    for _ in range(k):
        x = np.convolve(x, np.ones(4) / 4, mode="same")
    return x

def hp(x): return np.append(x[0], np.diff(x))

def place(buf, s, at):
    i = int(at * SR); j = min(len(buf), i + len(s)); buf[i:j] += s[: j - i]

def chirp(f0, f1, d, amp=0.3, curve=1.0):
    t = t_(d); f = f0 + (f1 - f0) * (t / d) ** curve
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.15 * np.sin(2 * ph)) * env(len(t), 0.008, d * 0.4) * amp

def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    tmp = f"/tmp/{name}.wav"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(OUT, name + ".ogg")], check=True)

# ---------- Vögel ----------
def amsel():   # flötende, abwechslungsreiche Strophe
    b = np.zeros(int(SR * 2.4)); at = 0.05
    for f0, f1, d in [(1900, 2300, .16), (2300, 1700, .14), (1500, 2600, .12), (2600, 2200, .2), (2000, 1400, .18), (3200, 4200, .06), (4200, 3000, .06)]:
        place(b, chirp(f0, f1, d, .35), at); at += d + 0.04
    return b

def meise():   # "zi-zi-bä" ×3
    b = np.zeros(int(SR * 1.6)); at = 0.03
    for _ in range(3):
        place(b, chirp(5200, 5000, .09, .3), at); place(b, chirp(3400, 3300, .13, .3), at + .14); at += .42
    return b

def fink():    # schmetternder Triller mit Schlussschnörkel
    b = np.zeros(int(SR * 2.2)); at = 0.02
    for i in range(14):
        f = 4200 - i * 90; place(b, chirp(f + 600, f, .05, .25), at); at += .075
    place(b, chirp(2600, 4800, .18, .3), at + .05); place(b, chirp(4800, 2200, .2, .3), at + .25)
    return b

def kuckuck():
    b = np.zeros(int(SR * 1.5))
    for at, f in [(0.05, 660), (0.42, 528)]:
        t = t_(.32); s = np.sin(2 * np.pi * f * t) + .2 * np.sin(4 * np.pi * f * t)
        place(b, s * env(len(t), .03, .15) * .4, at)
    return lp(b, 1)

def specht():
    b = np.zeros(int(SR * 1.1))
    for i in range(16):
        t = t_(.03); s = (rng.random(len(t)) * 2 - 1) * np.exp(-t * 160) + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 120)
        place(b, s * .5 * (1 - i / 22), 0.03 + i * 0.045)
    return b

# ---------- Natur ----------
def rauschen(d, k, amp=1.0):
    x = rng.random(int(SR * d)) * 2 - 1
    return lp(x, k) * amp

def blaetter():   # Windböe durch Laub: Rauschen, an- und abschwellend, flatternd
    d = 5.0; t = t_(d); x = hp(rauschen(d, 2)) * 3
    swell = np.sin(np.pi * t / d) ** 1.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 7.3 * t + rng.random() * 6) ** 2)
    return x * swell

def bach():       # plätschernder Bach als Schleife
    d = 8.0; t = t_(d); x = hp(rauschen(d, 3)) * 2 * (0.75 + 0.25 * np.sin(2 * np.pi * 0.4 * t))
    for _ in range(70):   # kleine Blubber
        f = rng.uniform(600, 1400); dd = rng.uniform(.03, .07)
        place(x, chirp(f, f * 1.6, dd, .25), rng.uniform(0, d - .1))
    n = int(SR * .3); x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x

# ---------- Arbeit ----------
def amboss():     # zwei Hammerschläge auf Eisen, hell nachklingend
    b = np.zeros(int(SR * 1.3))
    for at, a in [(0.02, 1.0), (0.55, .8)]:
        t = t_(.7)
        s = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * dk) * g for f, dk, g in [(1180, 9, .6), (2650, 14, .4), (3900, 22, .25), (5300, 30, .15)])
        s += (rng.random(len(t)) * 2 - 1) * np.exp(-t * 90) * .8
        place(b, s * a, at)
    return b

def saege():      # Handsäge: zwei Züge vor und zurück
    b = np.zeros(int(SR * 1.4)); x = hp(hp(rauschen(1.4, 1)))
    t = t_(1.4); stroke = np.abs(np.sin(np.pi * t / 0.35)) ** .7
    tone = 1 + .4 * np.sin(2 * np.pi * 140 * t)
    return x * stroke * tone

def holzhammer():
    b = np.zeros(int(SR * 1.0))
    for at in [0.02, 0.36, 0.7]:
        t = t_(.15); s = (np.sin(2 * np.pi * 180 * t) * .8 + (rng.random(len(t)) * 2 - 1) * .5) * np.exp(-t * 45)
        place(b, s, at)
    return b

def spitzhacke():
    b = np.zeros(int(SR * 1.2))
    for at in [0.02, 0.62]:
        t = t_(.3); s = (rng.random(len(t)) * 2 - 1) * np.exp(-t * 35) + np.sin(2 * np.pi * 2100 * t) * np.exp(-t * 40) * .5
        place(b, s, at)
        for k in range(6):   # Steinchen rieseln
            tt = t_(.02); place(b, (rng.random(len(tt)) * 2 - 1) * .2, at + .08 + k * .03 + rng.uniform(0, .02))
    return b

def feuer():      # Knistern + tiefes Grollen
    d = 3.0; x = rauschen(d, 6) * .6
    for _ in range(90):
        tt = t_(rng.uniform(.003, .012)); place(x, (rng.random(len(tt)) * 2 - 1) * rng.uniform(.3, 1.0), rng.uniform(0, d - .02))
    n = int(SR * .2); x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x

def brodeln():    # Sud im Kessel
    d = 3.0; x = rauschen(d, 8) * .3
    for _ in range(55):
        f = rng.uniform(180, 420); dd = rng.uniform(.04, .09)
        place(x, chirp(f, f * 2.2, dd, .5, 2), rng.uniform(0, d - .1))
    n = int(SR * .2); x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x

def webstuhl():   # Klack-klack des Webstuhls
    b = np.zeros(int(SR * 1.6))
    for at, f in [(0.02, 420), (0.4, 360), (0.8, 420), (1.2, 360)]:
        t = t_(.09); s = (np.sin(2 * np.pi * f * t) + (rng.random(len(t)) * 2 - 1) * .6) * np.exp(-t * 60)
        place(b, s, at)
    return b

def knarren():    # Holz knarrt (Brunnenkurbel, Presse, Mühle)
    d = 1.2; t = t_(d); f = 95 + 25 * np.sin(np.pi * t / d)
    imp = (np.sin(2 * np.pi * np.cumsum(f) / SR) > .97).astype(float)
    s = lp(imp * (rng.random(len(t)) * .5 + .5), 1) * 4 * np.sin(np.pi * t / d)
    return s

def messer():     # Hackmesser auf Holzbrett
    b = np.zeros(int(SR * 1.1))
    for at in [0.02, 0.3, 0.58, 0.86]:
        t = t_(.08); s = ((rng.random(len(t)) * 2 - 1) * .7 + np.sin(2 * np.pi * 300 * t)) * np.exp(-t * 70)
        place(b, s, at)
    return b

def drehscheibe():   # Töpferscheibe: leises Summen und Schaben
    d = 2.5; t = t_(d); s = np.sin(2 * np.pi * 70 * t) * .3 + hp(rauschen(d, 4)) * .6 * (1 + .3 * np.sin(2 * np.pi * 1.5 * t))
    n = int(SR * .3); s[:n] *= np.linspace(0, 1, n); s[-n:] *= np.linspace(1, 0, n)
    return s

def muenzen():
    b = np.zeros(int(SR * 0.9))
    for k in range(5):
        t = t_(.25); f = rng.uniform(3000, 4800)
        s = (np.sin(2 * np.pi * f * t) + .5 * np.sin(2 * np.pi * f * 1.48 * t)) * np.exp(-t * 18)
        place(b, s * .5, .03 + k * .1 + rng.uniform(0, .04))
    return b

# ---------- Tiere ----------
def voice(f0, d, vib, form, amp=.5, bleat=0.0):
    t = t_(d); f = f0 * (1 + .04 * np.sin(np.pi * t / d)) * (1 + bleat * np.sin(2 * np.pi * 9 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(np.sin(k * ph) * g for k, g in enumerate(form, 1))
    return s * env(len(t), .05, d * .35) * amp

def schaf(): return voice(330, .8, 0, [1, .7, .5, .3, .2], bleat=.08)
def kuh():   return lp(voice(110, 1.4, 0, [1, .8, .6, .4, .25, .15]), 1)
def schwein():
    b = np.zeros(int(SR * .9))
    for at in [0.02, 0.3, 0.55]:
        t = t_(.18); s = (np.sin(2 * np.pi * 120 * t) * (rng.random(len(t)) * .8 + .2)) * env(len(t), .01, .08)
        place(b, lp(s, 2), at)
    return b
def bienen():
    d = 3.0; t = t_(d); s = np.zeros(len(t))
    for k in range(6):
        f = rng.uniform(190, 260) * (1 + .03 * np.sin(2 * np.pi * rng.uniform(.5, 2) * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        s += (np.sin(ph) + .5 * np.sin(2 * ph) + .3 * np.sin(3 * ph)) * (.6 + .4 * np.sin(2 * np.pi * rng.uniform(.2, .7) * t + k))
    n = int(SR * .3); s[:n] *= np.linspace(0, 1, n); s[-n:] *= np.linspace(1, 0, n)
    return s

ALL = {"amsel": amsel, "meise": meise, "fink": fink, "kuckuck": kuckuck, "specht": specht,
       "blaetter": blaetter, "bach": bach, "amboss": amboss, "saege": saege, "holzhammer": holzhammer,
       "spitzhacke": spitzhacke, "feuer": feuer, "brodeln": brodeln, "webstuhl": webstuhl,
       "knarren": knarren, "messer": messer, "drehscheibe": drehscheibe, "muenzen": muenzen,
       "schaf": schaf, "kuh": kuh, "schwein": schwein, "bienen": bienen}

if __name__ == "__main__":
    for k, f in ALL.items():
        save(k, f()); print("ok", k)
