"""Synthesizes the main menu theme (a creepy, glorpy music-box waltz) plus two UI blips.

Usage: python tools/audio/menu_theme.py <out dir>
Writes menu_theme.wav (~54.5 s, loops seamlessly), ui_hover.wav and ui_click.wav.
Pure standard library. 40 bars of 3/4 at 132 BPM in A minor. Original tune.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 32000
STEP = 7273                 # samples per eighth note (132 BPM)
BAR = STEP * 6              # 3/4
BARS = 40
TOTAL = BAR * BARS
random.seed(21)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def music_box(midi, steps, vol=0.16):
    """Plucked bell: sine + octave partial, fast decay, a gooey wobble that grows."""
    n = steps * STEP
    f, ph, out = midi_hz(midi), 0.0, []
    for i in range(n):
        t = i / SR
        wob = 0.18 * min(1.0, t / 0.4) * math.sin(2 * math.pi * 4.5 * t)
        ph += f * 2 ** (wob / 12) / SR
        s = math.sin(2 * math.pi * ph) + 0.35 * math.sin(4 * math.pi * ph) * math.exp(-t / 0.08)
        out.append(vol * s * min(1.0, t / 0.003) * math.exp(-t / 0.55) * min(1.0, (n - i) / 400))
    return out


def tri_bass(midi, steps, vol=0.24):
    n = steps * STEP - 200
    f, out = midi_hz(midi), []
    for i in range(n):
        ph = (i * f / SR) % 1.0
        tri = 4 * ph - 1 if ph < 0.5 else 3 - 4 * ph
        attack = min(1.0, i / (0.004 * SR))
        out.append(vol * round(tri * 7) / 7 * attack * math.exp(-i / SR / 0.6) * min(1.0, (n - i) / 300))
    return out


def bubble(midi, vol=0.06, length=0.09):
    n = int(length * SR)
    f0, ph, out = midi_hz(midi), 0.0, []
    for i in range(n):
        t = i / SR
        ph += f0 * (1 + 0.8 * t / length) / SR
        out.append(vol * math.sin(2 * math.pi * ph) * math.exp(-t / (length * 0.4)))
    return out


def glorp(dur, f_start, f_end, vol, wobble=0.25, wob_hz=14.0, drop=0.1):
    n = int(dur * SR)
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        f = (f_end + (f_start - f_end) * math.exp(-t / drop)) * (1 + wobble * math.sin(2 * math.pi * wob_hz * t))
        ph += f / SR
        s = math.sin(2 * math.pi * ph) + 0.3 * math.sin(4 * math.pi * ph)
        out.append(vol * math.tanh(1.4 * s) * min(1.0, t / 0.004) * math.exp(-t / (dur * 0.4)))
    return out


def drone(midi, samples, vol=0.05):
    f, out = midi_hz(midi), []
    for i in range(samples):
        t = i / SR
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 0.25 * t)
        s = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.004 * t)
        out.append(vol * trem * s * min(1.0, t / 0.3) * min(1.0, (samples - i) / 3000))
    return out


mix = [0.0] * TOTAL


def add(start, samples):
    for i, v in enumerate(samples):
        mix[(start + i) % TOTAL] += v


# A minor waltz. Chord: (bass root, chord tones for the "pah-pah")
CH = {"Am": (45, [69, 72, 76]), "F": (41, [65, 69, 72]), "E": (40, [68, 71, 76]), "Dm": (38, [65, 69, 74]),
      "G": (43, [67, 71, 74]), "Em": (40, [67, 71, 76])}
VERSE = ["Am", "Am", "F", "E", "Dm", "Am", "E", "Am"]
BRIDGE = ["F", "G", "Em", "Am", "F", "G", "E", "E"]
MELODY = [
    [(0, 2, 76), (2, 2, 72), (4, 2, 69)], [(0, 3, 71), (3, 1, 72), (4, 2, 76)],
    [(0, 2, 77), (2, 2, 76), (4, 2, 72)], [(0, 4, 71), (4, 2, 68)],
    [(0, 2, 74), (2, 2, 77), (4, 2, 81)], [(0, 3, 76), (3, 1, 74), (4, 2, 72)],
    [(0, 2, 71), (2, 2, 74), (4, 2, 80)], [(0, 6, 81)],
]
BRIDGE_MEL = [
    [(0, 2, 81), (2, 2, 80), (4, 2, 81)], [(0, 2, 83), (2, 2, 81), (4, 2, 79)],
    [(0, 4, 79), (4, 2, 76)], [(0, 6, 76)],
    [(0, 2, 77), (2, 2, 81), (4, 2, 84)], [(0, 2, 83), (2, 2, 79), (4, 2, 74)],
    [(0, 3, 80), (3, 3, 83)], [(0, 6, 76)],
]

for bar in range(BARS):
    section = bar // 8          # 0 intro, 1-2 verse, 3 bridge, 4 verse + harmony
    chord = BRIDGE[bar % 8] if section == 3 else VERSE[bar % 8]
    root, tones = CH[chord]
    b0 = bar * BAR
    add(b0, tri_bass(root, 2))                                   # oom
    for beat in (2, 4):                                          # pah-pah: gooey chord bubbles
        for k, m in enumerate(tones):
            add(b0 + beat * STEP + k * 220, bubble(m, 0.035, 0.12))
    if bar % 4 == 0:
        add(b0, drone(root + 12, BAR * 4, 0.04))
        add(b0 + STEP, glorp(0.6, 260, 55, 0.22, wobble=0.3, wob_hz=9, drop=0.18))
    if bar % 2 == 1:                                             # a stray bloop somewhere in the bar
        add(b0 + random.randint(0, 5) * STEP + random.randint(0, STEP // 2),
            bubble(random.choice(tones) + 12, 0.05, 0.07))
    if section == 0 and bar >= 4:                                # intro: a hint of the tune
        s, length, m = MELODY[bar % 8][0]
        add(b0 + s * STEP, music_box(m, length + 2, 0.1))
    elif section in (1, 2, 4):
        for s, length, m in MELODY[bar % 8]:
            add(b0 + s * STEP, music_box(m, length))
            if section == 4:
                add(b0 + s * STEP, music_box(m - 12, length, 0.07))
            if section == 2:
                add(b0 + s * STEP + STEP // 2, music_box(m + 12, length, 0.04))   # ghostly echo
    elif section == 3:
        for s, length, m in BRIDGE_MEL[bar % 8]:
            add(b0 + s * STEP, music_box(m, length, 0.14))
        add(b0 + 3 * STEP, glorp(0.25, 380, 120, 0.12, wobble=0.2, wob_hz=20, drop=0.05))


def write(path, data, peak_target=0.85):
    peak = max(abs(v) for v in data) or 1.0
    gain = peak_target / math.tanh(peak * 1.1)
    frames = b"".join(struct.pack("<h", int(32767 * max(-1.0, min(1.0, gain * math.tanh(v * 1.1))))) for v in data)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


out = sys.argv[1] if len(sys.argv) > 1 else "."
write(os.path.join(out, "menu_theme.wav"), mix)
write(os.path.join(out, "ui_hover.wav"), bubble(76, 0.5, 0.09) + [0.0] * 400, 0.5)
write(os.path.join(out, "ui_click.wav"), glorp(0.22, 340, 80, 0.6, wobble=0.25, wob_hz=22, drop=0.05), 0.6)
print(f"menu_theme.wav {TOTAL / SR:.2f}s, ui_hover.wav, ui_click.wav")
