"""Synthesizes the retro sound effects of MUTANT LAB into assets/sfx/ (16-bit mono 22050 Hz WAV).

    python tools/gen_sfx.py          (run from the project root; stdlib only, deterministic)

Each sound is a list of layers mixed together. A layer is an oscillator (square, triangle, saw,
sine or noise) with a pitch sweep and an attack/decay envelope. Everything is peak-normalised to
about -6 dB and gets a short fade at both ends so nothing clicks.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
PEAK = 0.5            # about -6 dBFS
FADE = 0.004          # seconds of fade in/out
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def osc(kind, phase, rng_state):
    """One sample of an oscillator at `phase` (in cycles)."""
    f = phase % 1.0
    if kind == "square":
        return 1.0 if f < 0.5 else -1.0
    if kind == "pulse":            # 25 % duty: thinner, more nasal
        return 1.0 if f < 0.25 else -1.0
    if kind == "triangle":
        return 4.0 * abs(f - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * f - 1.0
    if kind == "sine":
        return math.sin(2.0 * math.pi * f)
    raise ValueError(kind)


def tone(kind, f0, f1, dur, vol=1.0, start=0.0, attack=0.002, decay=None, curve=1.0,
         vibrato=0.0, vib_rate=0.0, seed=1):
    """A layer: (start, samples). Pitch goes f0 -> f1 (exponential, shaped by `curve`).

    For kind "noise", f0 -> f1 is the sample-and-hold rate, which sets how bright the noise is.
    `decay` None holds the level then fades at the very end; a number is an exponential decay time.
    """
    n = max(1, int(dur * RATE))
    rng = random.Random(seed)
    out = [0.0] * n
    phase = 0.0
    held = rng.uniform(-1.0, 1.0)
    for i in range(n):
        t = i / RATE
        k = (i / n) ** curve
        freq = f0 * (f1 / f0) ** k
        if vibrato:
            freq *= 1.0 + vibrato * math.sin(2.0 * math.pi * vib_rate * t)
        prev = phase
        phase += freq / RATE
        if kind == "noise":
            if int(phase) != int(prev):
                held = rng.uniform(-1.0, 1.0)
            s = held
        else:
            s = osc(kind, phase, rng)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if decay is None:
            env *= min(1.0, (dur - t) / 0.01)
        else:
            env *= math.exp(-t / decay)
        out[i] = s * env * vol
    return (start, out)


def arp(kind, freqs, step, note_dur, vol=1.0, start=0.0, decay=0.08, seed=1):
    """A run of short notes, one every `step` seconds."""
    return [tone(kind, f, f, note_dur, vol, start + i * step, decay=decay, seed=seed + i) for i, f in enumerate(freqs)]


def mix(layers, length=None):
    end = max(start + len(s) / RATE for start, s in layers)
    n = int((length or end) * RATE)
    out = [0.0] * n
    for start, s in layers:
        o = int(start * RATE)
        for i, v in enumerate(s):
            if o + i < n:
                out[o + i] += v
    # one-pole low-pass to take the harshest aliasing off, then normalise and fade the ends
    y = 0.0
    for i in range(n):
        y += 0.65 * (out[i] - y)
        out[i] = y
    peak = max(1e-9, max(abs(v) for v in out))
    f = int(FADE * RATE)
    for i in range(n):
        g = PEAK / peak
        if i < f:
            g *= i / f
        if n - 1 - i < f:
            g *= (n - 1 - i) / f
        out[i] *= g
    return out


def note(semitones, base=440.0):
    return base * 2.0 ** (semitones / 12.0)


def build():
    """name -> list of layers."""
    s = {}
    # --- per-hit sounds: all under 0.25 s ---
    s["attack"] = [tone("noise", 9000, 1500, 0.11, 0.8, decay=0.04, seed=11),
                   tone("triangle", 520, 180, 0.10, 0.6, decay=0.05)]
    s["hit"] = [tone("noise", 5000, 600, 0.12, 1.0, decay=0.035, seed=12),
                tone("square", 220, 70, 0.12, 0.7, decay=0.05)]
    s["crit"] = [tone("noise", 11000, 900, 0.20, 0.9, decay=0.05, seed=13),
                 tone("square", 880, 110, 0.20, 0.8, decay=0.07, curve=0.6),
                 tone("pulse", 1760, 1320, 0.09, 0.5, start=0.02, decay=0.04)]
    s["dodge"] = [tone("noise", 2500, 9000, 0.14, 0.7, attack=0.05, decay=0.08, seed=14),
                  tone("sine", 600, 1500, 0.14, 0.4, attack=0.03, decay=0.08)]
    s["heal"] = [tone("triangle", note(3), note(3), 0.09, 0.9, decay=0.06),
                 tone("triangle", note(10), note(10), 0.14, 0.9, start=0.08, decay=0.07),
                 tone("sine", note(22), note(22), 0.12, 0.3, start=0.08, decay=0.06)]
    s["ability"] = [tone("pulse", 330, 990, 0.16, 0.8, decay=0.09, curve=0.7),
                    tone("triangle", 660, 1980, 0.16, 0.5, decay=0.09, curve=0.7),
                    tone("noise", 6000, 12000, 0.06, 0.25, decay=0.03, seed=15)]
    s["click"] = [tone("square", 1200, 900, 0.035, 1.0, decay=0.012),
                  tone("noise", 8000, 8000, 0.012, 0.4, decay=0.005, seed=16)]
    s["coin"] = [tone("square", note(14), note(14), 0.06, 0.9, decay=0.05),
                 tone("square", note(19), note(19), 0.16, 0.9, start=0.06, decay=0.07)]
    # --- battle events ---
    s["death"] = [tone("square", 330, 45, 0.42, 0.8, decay=0.2, curve=0.7),
                  tone("noise", 3000, 300, 0.42, 0.7, decay=0.16, seed=17),
                  tone("triangle", 165, 30, 0.42, 0.6, decay=0.22)]
    s["frenzy"] = [tone("saw", 110, 330, 0.55, 0.7, attack=0.05, decay=None, curve=1.6, vibrato=0.03, vib_rate=18),
                   tone("square", 55, 165, 0.55, 0.6, attack=0.05, decay=None, curve=1.6),
                   tone("noise", 800, 7000, 0.55, 0.35, attack=0.3, decay=None, seed=18),
                   tone("square", 660, 660, 0.12, 0.7, start=0.55, decay=0.06)]
    # --- results ---
    s["win_small"] = arp("square", [note(3), note(7), note(10)], 0.07, 0.12, 0.9)
    s["win_medium"] = (arp("square", [note(3), note(7), note(10), note(15)], 0.075, 0.14, 0.9)
                       + arp("triangle", [note(-9), note(-5), note(-2), note(3)], 0.075, 0.14, 0.6)
                       + [tone("square", note(15), note(15), 0.22, 0.7, start=0.30, decay=0.12)])
    big = [note(3), note(7), note(10), note(15), note(10), note(15), note(19), note(22)]
    s["win_big"] = (arp("square", big, 0.08, 0.15, 0.9)
                    + arp("triangle", [f / 2 for f in big], 0.08, 0.15, 0.6)
                    + [tone("square", note(15), note(15), 0.5, 0.8, start=0.64, decay=0.25, vibrato=0.012, vib_rate=7),
                       tone("square", note(22), note(22), 0.5, 0.6, start=0.64, decay=0.25, vibrato=0.012, vib_rate=7),
                       tone("noise", 12000, 12000, 0.3, 0.2, start=0.64, decay=0.12, seed=19)])
    s["lose"] = (arp("square", [note(-2), note(-5), note(-9)], 0.16, 0.2, 0.8, decay=0.14)
                 + [tone("square", note(-14), note(-17), 0.45, 0.8, start=0.48, decay=0.22),
                    tone("triangle", note(-26), note(-29), 0.45, 0.7, start=0.48, decay=0.25)])
    # --- shop and lab ---
    s["purchase"] = [tone("noise", 7000, 7000, 0.03, 0.5, decay=0.012, seed=20),
                     tone("square", note(10), note(10), 0.05, 0.8, start=0.02, decay=0.04),
                     tone("square", note(15), note(15), 0.05, 0.8, start=0.08, decay=0.04),
                     tone("square", note(22), note(22), 0.18, 0.8, start=0.14, decay=0.08)]
    s["mutate_success"] = [tone("noise", 500, 5000, 0.22, 0.4, attack=0.1, decay=None, seed=21),
                           tone("pulse", 180, 720, 0.22, 0.7, decay=None, curve=1.4, vibrato=0.05, vib_rate=24),
                           tone("square", note(7), note(7), 0.08, 0.9, start=0.22, decay=0.06),
                           tone("square", note(14), note(14), 0.24, 0.9, start=0.30, decay=0.11),
                           tone("triangle", note(26), note(26), 0.24, 0.4, start=0.30, decay=0.1)]
    # descending wet noise: a falling, wobbling bubble under a darkening hiss, then a low plop
    s["mush"] = [tone("noise", 4000, 250, 0.45, 0.9, decay=0.2, seed=22),
                 tone("sine", 420, 70, 0.45, 0.8, decay=0.22, vibrato=0.25, vib_rate=14),
                 tone("triangle", 200, 50, 0.3, 0.6, start=0.1, decay=0.12, vibrato=0.3, vib_rate=9),
                 tone("sine", 90, 45, 0.12, 0.8, start=0.4, decay=0.06)]
    # 0.8 s rising arpeggio with shimmer
    ultra = [note(-9), note(-2), note(3), note(7), note(10), note(15), note(19), note(22), note(27)]
    s["ultra_reveal"] = (arp("square", ultra, 0.065, 0.16, 0.8, decay=0.09)
                         + arp("triangle", [f * 2 for f in ultra], 0.065, 0.16, 0.4, start=0.0325, decay=0.07, seed=40)
                         + [tone("noise", 9000, 14000, 0.8, 0.14, attack=0.4, decay=None, seed=23),
                            tone("sine", note(27), note(27), 0.3, 0.5, start=0.5, decay=None, vibrato=0.02, vib_rate=11),
                            tone("pulse", note(15), note(15), 0.3, 0.4, start=0.5, decay=None, vibrato=0.02, vib_rate=11)])
    return s


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, layers in sorted(build().items()):
        data = mix(layers)
        path = os.path.join(OUT_DIR, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data))
        peak = max(abs(v) for v in data)
        print("%-16s %.2f s  peak %.1f dB  %d bytes" % (name, len(data) / RATE, 20 * math.log10(peak), os.path.getsize(path)))


if __name__ == "__main__":
    main()
