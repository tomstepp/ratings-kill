#!/usr/bin/env python3
"""Generate retro sound effects and chiptune loops for Ratings Kill.

A tiny jsfxr-style synth in pure standard library Python. Run from the
project root with `python3 tools/gen_audio.py`. Output: assets/audio/*.wav
(22050 Hz, 16-bit mono). Music loops are looped at runtime by sfx.gd.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
rng = random.Random(7)


def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == "square":
        return 1.0 if p < duty else -1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    return rng.uniform(-1, 1)


def tone(dur, f0, f1=None, kind="square", duty=0.5, vol=0.5, attack=0.005, vib=0.0, vib_rate=8.0, curve=1.0):
    f1 = f0 if f1 is None else f1
    n = int(dur * RATE)
    out = []
    phase = 0.0
    held = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        if vib:
            f *= 1.0 + vib * math.sin(2 * math.pi * vib_rate * i / RATE)
        phase += f / RATE
        if kind == "noise":
            # Sample-and-hold noise so pitch still matters.
            if int(phase) != int(phase - f / RATE):
                held = rng.uniform(-1, 1)
            s = held
        else:
            s = osc(kind, phase, duty)
        env = min(1.0, (i / RATE) / attack) if attack > 0 else 1.0
        env *= (1.0 - t) ** 1.5
        out.append(s * env * vol)
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32000))
        w.writeframes(bytes(frames))


def note(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def gen_sfx():
    write("jump", tone(0.14, 260, 620, duty=0.25, vol=0.35, curve=0.6))
    write("shoot", mix(tone(0.11, 1100, 260, duty=0.5, vol=0.3), tone(0.06, 3000, 1000, kind="noise", vol=0.15)))
    write("hit", tone(0.09, 2400, 400, kind="noise", vol=0.4))
    write("explode", mix(tone(0.45, 900, 60, kind="noise", vol=0.55), tone(0.3, 120, 40, kind="sine", vol=0.5)))
    write("stomp", mix(tone(0.12, 420, 90, duty=0.5, vol=0.4), tone(0.05, 900, 200, kind="noise", vol=0.2)))
    write("pickup", seq(tone(0.06, note(84), duty=0.25, vol=0.3), tone(0.1, note(91), duty=0.25, vol=0.3)))
    write("powerup", seq(*[tone(0.08, note(n), duty=0.25, vol=0.3) for n in (72, 76, 79, 84, 88)]))
    write("key", seq(*[tone(0.06, note(n), duty=0.125, vol=0.3) for n in (88, 91, 96)]))
    write("hurt", tone(0.28, 520, 140, duty=0.5, vol=0.4, vib=0.08, vib_rate=30))
    write("door", mix(tone(0.35, 140, 70, duty=0.5, vol=0.3), tone(0.35, 600, 200, kind="noise", vol=0.15)))
    write("bonk", tone(0.12, 220, 160, kind="tri", vol=0.6))
    write("blip", tone(0.035, 760, 700, duty=0.5, vol=0.18, attack=0.002))
    write("crate", mix(tone(0.15, 1600, 300, kind="noise", vol=0.45), tone(0.1, 200, 90, kind="tri", vol=0.3)))
    write("stun", mix(tone(0.35, 4000, 4000, kind="noise", vol=0.2), tone(0.35, 1200, 3200, kind="sine", vol=0.25)))
    write("switch", seq(tone(0.03, 1500, kind="square", vol=0.25), silence(0.03), tone(0.05, 900, kind="square", vol=0.25)))
    write("achieve", seq(tone(0.1, note(83), duty=0.25, vol=0.3), tone(0.25, note(88), duty=0.25, vol=0.3, vib=0.01)))
    write("drop", seq(*[tone(0.07, note(n), duty=0.25, vol=0.3) for n in (67, 71, 74, 79, 83)],
                      mix(tone(0.4, note(86), duty=0.25, vol=0.25, vib=0.01), tone(0.4, note(79), duty=0.5, vol=0.15))))
    write("boredom", seq(*[tone(0.25, note(n), note(n) * 0.97, duty=0.5, vol=0.3, vib=0.03, vib_rate=6) for n in (62, 61, 60)],
                         tone(0.6, note(59), note(57), duty=0.5, vol=0.3, vib=0.04, vib_rate=6)))
    write("death", seq(*[tone(0.12, note(n), duty=0.5, vol=0.3) for n in (76, 72, 69, 65, 64, 60)], tone(0.4, note(48), note(40), duty=0.5, vol=0.3)))
    write("buy", seq(tone(0.05, note(96), duty=0.25, vol=0.25), tone(0.05, note(100), duty=0.25, vol=0.25),
                     tone(0.2, 3000, 2000, kind="noise", vol=0.15)))
    write("deny", tone(0.18, 140, 120, duty=0.5, vol=0.3))
    write("cheer", mix(tone(0.9, 2500, 1800, kind="noise", vol=0.18), tone(0.9, 1200, 900, kind="noise", vol=0.12)))


def render_song(bpm, bars, chords, lead, bass_style="pulse", drums=True, lead_duty=0.25, swing=0.0):
    """chords: list of root midi notes, one per bar. lead: list of (step, midi, len_steps)."""
    step = 60.0 / bpm / 4
    total = int(bars * 16 * step * RATE)
    out = [0.0] * total

    def add(start_s, samples):
        i0 = int(start_s * RATE)
        for i, v in enumerate(samples):
            if i0 + i < total:
                out[i0 + i] += v

    for bar, root in enumerate(chords[:bars]):
        for s in range(16):
            t = (bar * 16 + s) * step + (swing * step if s % 2 else 0)
            if bass_style == "pulse":
                n = root if s % 4 != 2 else root + 12
                if s % 2 == 0:
                    add(t, tone(step * 1.6, note(n), kind="tri", vol=0.45, attack=0.002))
            else:
                if s in (0, 6, 10):
                    add(t, tone(step * 3, note(root), kind="tri", vol=0.45))
            if drums:
                if s in (0, 8) or (s == 11 and bar % 2):
                    add(t, tone(0.12, 160, 40, kind="sine", vol=0.55, attack=0.001))
                if s in (4, 12):
                    add(t, tone(0.1, 3000, 1500, kind="noise", vol=0.22, attack=0.001))
                if s % 2 == 0:
                    add(t, tone(0.03, 8000, kind="noise", vol=0.07, attack=0.001))
    for st, n, ln in lead:
        if n is None:
            continue
        add(st * step, tone(step * ln * 0.95, note(n), duty=lead_duty, vol=0.2, attack=0.004, vib=0.006, vib_rate=6))
    return out


def gen_music():
    # Level theme: driving A minor loop (Am F G E), two 4-bar phrases.
    chords = [45, 41, 43, 40, 45, 41, 43, 40]
    m = []
    phrase_a = [(0, 69, 2), (2, 72, 2), (4, 76, 3), (7, 74, 1), (8, 72, 2), (10, 71, 2), (12, 69, 4),
                (16, 65, 2), (18, 69, 2), (20, 72, 3), (23, 71, 1), (24, 69, 2), (26, 67, 2), (28, 65, 4),
                (32, 67, 2), (34, 71, 2), (36, 74, 3), (39, 72, 1), (40, 71, 2), (42, 74, 2), (44, 79, 4),
                (48, 76, 3), (51, 75, 1), (52, 76, 2), (54, 80, 2), (56, 83, 6), (62, 80, 2)]
    m += phrase_a
    phrase_b = [(64 + s, n + (12 if i % 5 == 4 else 0), l) for i, (s, n, l) in enumerate(phrase_a[:20])]
    phrase_b += [(112, 76, 2), (114, 74, 2), (116, 72, 2), (118, 71, 2), (120, 69, 8)]
    m += phrase_b
    write("music_level", render_song(140, 8, chords, m))

    # Break room: lazy lounge loop (Cmaj7 Am7 Dm7 G7 feel), swung, no kick spam.
    chords = [48, 45, 50, 43]
    lead = [(0, 76, 3), (4, 79, 2), (6, 76, 2), (8, 74, 6), (16, 72, 3), (20, 76, 2), (22, 72, 2), (24, 69, 6),
            (32, 74, 3), (36, 77, 2), (38, 74, 2), (40, 72, 6), (48, 71, 3), (52, 74, 2), (54, 77, 2), (56, 79, 6)]
    write("music_break", render_song(96, 4, chords, lead, bass_style="walk", drums=False, lead_duty=0.5, swing=0.3))

    # Title sting: big fanfare loop.
    chords = [45, 45, 41, 43]
    lead = [(0, 69, 1), (1, 69, 1), (2, 69, 1), (3, 72, 5), (8, 76, 4), (12, 74, 4),
            (16, 72, 1), (17, 72, 1), (18, 72, 1), (19, 76, 5), (24, 81, 8),
            (32, 77, 4), (36, 76, 4), (40, 74, 4), (44, 72, 4), (48, 74, 4), (52, 76, 4), (56, 79, 8)]
    write("music_title", render_song(120, 4, chords, lead))


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    print("audio generated")
