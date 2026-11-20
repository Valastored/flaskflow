#!/usr/bin/env python3
"""Synthesises the game's sound effects (no external assets, no licence issue).

Usage: python3 tools/generate_sfx.py   -> writes assets/sfx/*.wav
Tweak the functions below and re-run to change a sound.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = random.Random(7)


def write(name, samples, gain=0.8):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = gain / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    print("wrote", os.path.relpath(path))


def env(t, attack, decay):
    """Fast attack, exponential decay."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def bell(freq, dur, decay=0.25, harmonics=((1, 1.0), (2.01, 0.35), (3.02, 0.12))):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(s * env(t, 0.004, decay))
    return out


def mix(*tracks):
    """tracks: (samples, start_time_seconds)"""
    n = max(int(off * RATE) + len(t) for t, off in tracks)
    out = [0.0] * n
    for track, offset in tracks:
        o = int(offset * RATE)
        for i, s in enumerate(track):
            out[o + i] += s
    return out


def select():
    return bell(1046, 0.09, decay=0.03, harmonics=((1, 1.0), (2, 0.2)))


def click():
    return bell(1568, 0.05, decay=0.012, harmonics=((1, 1.0),))


def pour():
    """Gurgling liquid: bubbles = short sine chirps at random pitches + soft noise."""
    dur = 0.42
    n = int(RATE * dur)
    out = [0.0] * n
    # Filtered noise bed.
    lp = 0.0
    for i in range(n):
        t = i / RATE
        lp += 0.08 * (rng.uniform(-1, 1) - lp)
        fade = min(1.0, t / 0.03) * min(1.0, (dur - t) / 0.12)
        out[i] += lp * 0.35 * fade
    # Bubbles.
    t0 = 0.0
    while t0 < dur - 0.06:
        f = rng.uniform(380, 900)
        bd = rng.uniform(0.025, 0.05)
        start = int(t0 * RATE)
        for j in range(int(bd * RATE)):
            t = j / RATE
            freq = f * (1 + 2.5 * t / bd)  # rising chirp = "bloop"
            if start + j < n:
                out[start + j] += 0.5 * math.sin(2 * math.pi * freq * t) * math.sin(math.pi * t / bd)
        t0 += rng.uniform(0.025, 0.055)
    return out


def pop():
    """Cork: pitch drop + click."""
    dur = 0.16
    out = []
    phase = 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        freq = 900 * math.exp(-t * 18) + 180
        phase += 2 * math.pi * freq / RATE
        s = math.sin(phase) * env(t, 0.002, 0.04)
        if t < 0.004:
            s += rng.uniform(-1, 1) * 0.6
        out.append(s)
    return mix((out, 0), (bell(1318, 0.3, decay=0.1), 0.05))


def invalid():
    dur = 0.18
    out = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        f = 150 if t < 0.08 else 120
        s = (1 if math.sin(2 * math.pi * f * t) > 0 else -1) * 0.5 + math.sin(2 * math.pi * f * t)
        out.append(s * env(t, 0.005, 0.06) * 0.6)
    return out


def win():
    notes = [523.25, 659.25, 783.99, 1046.5]
    tracks = [(bell(f, 0.6, decay=0.22), k * 0.11) for k, f in enumerate(notes)]
    tracks.append((bell(1318.5, 0.9, decay=0.4), 0.48))
    tracks.append((bell(783.99, 0.9, decay=0.4), 0.48))
    return mix(*tracks)


def star():
    return mix((bell(1760, 0.35, decay=0.12), 0), (bell(2637, 0.3, decay=0.1), 0.03))


def reward():
    notes = [659.25, 880, 1174.66, 1567.98]
    return mix(*[(bell(f, 0.4, decay=0.15), k * 0.06) for k, f in enumerate(notes)])


def lose():
    notes = [392, 349.23, 293.66]
    return mix(*[(bell(f, 0.5, decay=0.2, harmonics=((1, 1), (2, 0.2))), k * 0.15)
                 for k, f in enumerate(notes)])


def main():
    os.makedirs(OUT, exist_ok=True)
    write("select", select(), 0.5)
    write("click", click(), 0.4)
    write("pour", pour(), 0.7)
    write("pop", pop(), 0.8)
    write("invalid", invalid(), 0.5)
    write("win", win(), 0.8)
    write("star", star(), 0.6)
    write("reward", reward(), 0.7)
    write("lose", lose(), 0.6)


if __name__ == "__main__":
    main()
