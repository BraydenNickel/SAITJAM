"""Synthesizes the arena fight theme: an original chiptune battle loop with slimy 'glorp' sounds.

Usage: python tools/audio/fight_theme.py [out.wav]
Pure standard library (no numpy). 32 bars at ~140 BPM in D minor, ~55 s, loops seamlessly.
Edit the CHORDS / HOOK / sections below and rerun to change the tune.
"""
import math
import random
import struct
import sys
import wave

SR = 32000
STEP = 3429                      # samples per 16th note (~140 BPM)
BAR = STEP * 16
BARS = 32
TOTAL = BAR * BARS               # 54.86 s, an exact number of steps so the loop is seamless
random.seed(7)
mix = [0.0] * TOTAL


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def add(start, samples):
    """Mix rendered samples in at start; tails past the end wrap to the loop start."""
    for i, v in enumerate(samples):
        mix[(start + i) % TOTAL] += v


def env(i, n, attack=0.004, release=0.03, sustain=0.75, decay=0.08):
    t = i / SR
    a = min(1.0, t / attack) if attack else 1.0
    d = sustain + (1 - sustain) * math.exp(-t / decay)
    r = min(1.0, (n - i) / (release * SR))
    return a * d * r


# ---------------- instruments ----------------
def lead(midi, steps, vol=0.16, duty=0.25):
    """Gooey pulse lead: scoops up into each note, vibrato wobbles in late."""
    n = steps * STEP - 60
    f0, ph, out = midi_hz(midi), 0.0, []
    for i in range(n):
        t = i / SR
        scoop = -0.35 * math.exp(-t / 0.025)                        # slide up into the note
        vib = 0.22 * min(1.0, max(0.0, (t - 0.12) / 0.15)) * math.sin(2 * math.pi * 5.8 * t)
        ph = (ph + f0 * 2 ** ((scoop + vib) / 12) / SR) % 1.0
        out.append(vol * (1.0 if ph < duty else -1.0) * env(i, n))
    return out


def bass(midi, steps, vol=0.22):
    """4-bit stepped triangle, like an old console bass channel."""
    n = steps * STEP - 40
    f, out = midi_hz(midi), []
    for i in range(n):
        ph = (i * f / SR) % 1.0
        tri = 4 * ph - 1 if ph < 0.5 else 3 - 4 * ph
        out.append(vol * round(tri * 7) / 7 * env(i, n, attack=0.002, sustain=0.9, release=0.01))
    return out


def bubble(midi, vol=0.07):
    """Bubbling arp note: a sine that bends upward and pops."""
    n = int(STEP * 0.9)
    f0, ph, out = midi_hz(midi), 0.0, []
    for i in range(n):
        t = i / SR
        ph += f0 * (1 + 0.6 * t / (n / SR)) / SR
        out.append(vol * math.sin(2 * math.pi * ph) * math.exp(-t / 0.035))
    return out


def glorp(dur, f_start, f_end, vol, wobble=0.0, wob_hz=20.0, drop=0.05):
    """Squelchy pitch-drop: kick drums and slime accents."""
    n = int(dur * SR)
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        f = f_end + (f_start - f_end) * math.exp(-t / drop)
        f *= 1 + wobble * math.sin(2 * math.pi * wob_hz * t)
        ph += f / SR
        s = math.sin(2 * math.pi * ph) + 0.35 * math.sin(4 * math.pi * ph)
        out.append(vol * math.tanh(1.6 * s) * min(1.0, t / 0.002) * math.exp(-t / (dur * 0.35)))
    return out


def snare(vol=0.20):
    n = int(0.16 * SR)
    return [vol * (random.uniform(-1, 1) * 0.8 * math.exp(-i / SR / 0.05)
                   + 0.6 * math.sin(2 * math.pi * 190 * i / SR) * math.exp(-i / SR / 0.03)) for i in range(n)]


def hat(vol=0.06, length=0.03):
    n, prev, out = int(length * SR), 0.0, []
    for i in range(n):
        x = random.uniform(-1, 1)
        out.append(vol * (x - prev) * math.exp(-i / SR / (length / 3)))
        prev = x
    return out


KICK = glorp(0.22, 170, 45, 0.55, drop=0.03)
GLORP = glorp(0.40, 420, 70, 0.30, wobble=0.25, wob_hz=18, drop=0.09)
BIG_GLORP = glorp(0.70, 520, 55, 0.38, wobble=0.30, wob_hz=11, drop=0.16)
SNARE, HAT, OPEN_HAT = snare(), hat(), hat(0.05, 0.12)

# ---------------- the tune ----------------
D, E, F, G, A, Bb, C, Cs = 62, 64, 65, 67, 69, 70, 72, 73
CHORDS = {"Dm": (50, [D, F, A]), "Bb": (46, [Bb - 12, D, F]), "C": (48, [C - 12, E, G]),
          "A": (45, [A - 12, Cs - 12, E]), "Gm": (43, [G - 12, Bb - 12, D])}
MAIN = ["Dm", "Bb", "C", "A"]
TENSE = ["Gm", "A", "Bb", "A", "Gm", "Bb", "C", "A"]

# Hook: (step, length, midi) per bar, an original melody
HOOK = [
    [(0, 2, 74), (2, 2, 74), (4, 2, 69), (6, 3, 77), (9, 1, 76), (10, 2, 74), (12, 2, 72), (14, 2, 74)],
    [(0, 3, 77), (3, 1, 74), (4, 4, 70), (8, 2, 72), (10, 2, 74), (12, 4, 77)],
    [(0, 2, 79), (2, 2, 77), (4, 2, 76), (6, 2, 72), (8, 4, 76), (12, 2, 72), (14, 2, 76)],
    [(0, 4, 73), (4, 4, 76), (8, 6, 81)],
]
HOOK_ANSWER = [(0, 2, 81), (2, 2, 79), (4, 2, 77), (6, 2, 76), (8, 4, 73), (12, 4, 69)]
INTRO_CALL = [(0, 2, 74), (4, 2, 69), (8, 2, 74), (10, 2, 77), (12, 3, 76)]
STAB_STEPS = [0, 3, 6, 10, 12]

for bar in range(BARS):
    section = bar // 8                         # 0 intro, 1 hook, 2 tense, 3 hook reprise
    name = TENSE[bar % 8] if section == 2 else MAIN[bar % 4]
    root, tones = CHORDS[name]
    b0 = bar * BAR

    # bass: octave bounce in 8ths, walking fill on the last bar of each phrase
    for s in range(0, 16, 8 if (section == 0 and bar < 2) else 2):
        note = root + (12 if (s // 2) % 2 else 0)
        if bar % 4 == 3 and s >= 12:
            note = root + (7 if s == 12 else 10)
        add(b0 + s * STEP, bass(note, 2))

    # bubbling arp (quiet in the intro's first half)
    if not (section == 0 and bar < 2):
        arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[1] + 24]
        for s in range(16):
            add(b0 + s * STEP, bubble(arp[s % 4], 0.05 if section == 0 else 0.07))

    # drums
    kicks = [0, 3, 8, 11] if section == 2 else [0, 6, 8]
    for s in kicks:
        if not (section == 0 and bar < 2 and s != 0):
            add(b0 + s * STEP, KICK)
    if not (section == 0 and bar < 4):
        for s in (4, 12):
            add(b0 + s * STEP, SNARE)
    for s in range(2, 16, 4 if section == 0 else 2):
        add(b0 + s * STEP, OPEN_HAT if (section == 3 and s == 14) else HAT)
    if section == 2 and bar % 8 == 7:          # snare roll into the reprise
        for s in range(8, 16):
            add(b0 + s * STEP, [v * (0.4 + s / 20) for v in SNARE])

    # glorps: a squelch every other bar, a big one at each section change
    if bar % 2 == 1:
        add(b0 + 14 * STEP, GLORP)
    if bar % 8 == 0:
        add(b0, BIG_GLORP)

    # lead
    if section == 0 and bar >= 4:
        shift = {"Dm": 0, "Bb": -4, "C": -2, "A": -5}[name]
        for s, length, m in INTRO_CALL:
            add(b0 + s * STEP, lead(m + shift, length, vol=0.12))
    elif section in (1, 3):
        phrase = HOOK[bar % 4] if not (bar % 8 == 7) else HOOK_ANSWER
        for s, length, m in phrase:
            add(b0 + s * STEP, lead(m, length))
            if section == 3:                   # reprise: lower harmony on a thinner pulse
                add(b0 + s * STEP, lead(m - 12, length, vol=0.08, duty=0.125))
    elif section == 2:
        for k, s in enumerate(STAB_STEPS):
            add(b0 + s * STEP, lead(tones[k % 3] + 12, 2 if s < 12 else 4, vol=0.14, duty=0.5))

# ---------------- master ----------------
peak = max(abs(v) for v in mix)
gain = 0.89 / math.tanh(peak * 1.1)
frames = b"".join(struct.pack("<h", int(32767 * max(-1.0, min(1.0, gain * math.tanh(v * 1.1))))) for v in mix)
out = sys.argv[1] if len(sys.argv) > 1 else "fight_theme.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(frames)
print(f"wrote {out}: {TOTAL / SR:.2f}s, {TOTAL} samples, raw peak {peak:.2f}")
