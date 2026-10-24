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
    write("roar", mix(tone(0.9, 140, 70, kind="saw", vol=0.45, vib=0.08, vib_rate=11),
                      tone(0.9, 900, 300, kind="noise", vol=0.2)))
    write("cheer", mix(tone(0.9, 2500, 1800, kind="noise", vol=0.18), tone(0.9, 1200, 900, kind="noise", vol=0.12)))


MINOR = [0, 2, 3, 5, 7, 8, 10]
MAJOR = [0, 2, 4, 5, 7, 9, 11]

# Two-bar rhythms for melodies: (step, length) pairs in 16th notes.
RHYTHMS = [
    [(0, 2), (2, 2), (4, 3), (7, 1), (8, 2), (10, 2), (12, 4), (16, 3), (19, 1), (20, 2), (22, 2), (24, 6), (30, 2)],
    [(0, 1), (1, 1), (2, 2), (4, 4), (8, 2), (10, 1), (11, 1), (12, 4), (16, 2), (18, 2), (20, 4), (24, 8)],
    [(0, 3), (3, 3), (6, 2), (8, 4), (12, 2), (14, 2), (16, 3), (19, 3), (22, 2), (24, 4), (28, 4)],
    [(0, 2), (4, 2), (6, 2), (8, 2), (10, 4), (16, 2), (18, 2), (20, 2), (22, 2), (24, 4), (28, 2), (30, 2)],
]


def degree_note(key, scale, degree, octave=0):
    """Scale degree (can be negative or > 6) -> midi note."""
    o, d = divmod(degree, len(scale))
    return key + scale[d] + 12 * (o + octave)


def make_motif(seed, rhythm):
    """A two-bar melodic shape: scale-degree offsets from the chord root, one per note."""
    r = random.Random(seed)
    degs, cur = [], r.choice([0, 2, 4])
    for i, _ in enumerate(rhythm):
        degs.append(cur)
        step = r.choice([-2, -1, -1, 1, 1, 2, 2, 3, -3, 0])
        cur = max(-2, min(9, cur + step))
    degs[-1] = r.choice([0, 2, 4, 7])  # land on a chord tone
    return degs


def compose(name, bpm, key, scale, sections, lead_duty=0.25, seed=1):
    """sections: list of dicts with bars, chords (scale degrees, one per bar), and
    lead ('a', 'b', 'a_high', None), drums ('full', 'half', 'none'), arp, bass ('pulse', 'walk', None)."""
    step = 60.0 / bpm / 4
    total_bars = sum(sec["bars"] for sec in sections)
    total = int(total_bars * 16 * step * RATE) + RATE
    out = [0.0] * total

    def add(t, samples):
        i0 = int(t * RATE)
        for i, v in enumerate(samples):
            if i0 + i < total:
                out[i0 + i] += v

    motifs = {}
    for tag, offset in (("a", 0), ("b", 1)):
        rh = RHYTHMS[(seed + offset * 3) % len(RHYTHMS)]
        motifs[tag] = (rh, make_motif(seed * 31 + offset, rh))

    bar0 = 0
    for sec in sections:
        chords = sec["chords"]
        for b in range(sec["bars"]):
            bar = bar0 + b
            root_deg = chords[b % len(chords)]
            last_bar = b == sec["bars"] - 1
            # Bass
            for s16 in range(16):
                t = (bar * 16 + s16) * step
                if sec.get("bass") == "pulse" and s16 % 2 == 0:
                    n = degree_note(key, scale, root_deg, -2) + (12 if s16 % 8 == 6 else 0)
                    add(t, tone(step * 1.7, note(n), kind="tri", vol=0.42, attack=0.002))
                elif sec.get("bass") == "walk" and s16 % 4 == 0:
                    n = degree_note(key, scale, root_deg + [0, 2, 4, 2][s16 // 4], -2)
                    add(t, tone(step * 3.5, note(n), kind="tri", vol=0.42))
            # Arpeggio: chord tones in 16ths, quiet
            if sec.get("arp"):
                for s16 in range(16):
                    t = (bar * 16 + s16) * step
                    n = degree_note(key, scale, root_deg + [0, 2, 4, 7][s16 % 4], 0)
                    add(t, tone(step * 0.9, note(n), duty=0.125, vol=0.07, attack=0.001))
            # Drums
            style = sec.get("drums", "full")
            for s16 in range(16):
                t = (bar * 16 + s16) * step
                fill = last_bar and s16 >= 12 and style != "none"
                if style == "full":
                    if s16 in (0, 8) or (s16 == 10 and bar % 2):
                        add(t, tone(0.12, 160, 40, kind="sine", vol=0.55, attack=0.001))
                    if s16 in (4, 12) or fill:
                        add(t, tone(0.1, 3000, 1500, kind="noise", vol=0.2 + (0.05 if fill else 0), attack=0.001))
                    if s16 % 2 == 0:
                        add(t, tone(0.03, 8000, kind="noise", vol=0.07, attack=0.001))
                elif style == "half":
                    if s16 == 0:
                        add(t, tone(0.12, 160, 40, kind="sine", vol=0.5, attack=0.001))
                    if s16 == 8 or fill:
                        add(t, tone(0.1, 3000, 1500, kind="noise", vol=0.18, attack=0.001))
                    if s16 % 4 == 2:
                        add(t, tone(0.03, 8000, kind="noise", vol=0.06, attack=0.001))
            # Lead melody: motif repeated over each pair of bars, following the chords
            lead = sec.get("lead")
            if lead and b % 2 == 0:
                tag = lead[0]
                octave = 1 if lead.endswith("high") else 0
                rh, degs = motifs[tag]
                # Every other phrase answers with a varied ending.
                vary = (b // 2) % 2 == 1
                for i, (st, ln) in enumerate(rh):
                    d = degs[i]
                    if vary and i >= len(rh) - 3:
                        d = degs[i] - 2
                    chord_here = chords[(b + st // 16) % len(chords)]
                    n = degree_note(key, scale, chord_here + d, octave)
                    add((bar * 16 + st) * step, tone(step * ln * 0.92, note(n), duty=lead_duty, vol=0.19, attack=0.004, vib=0.006, vib_rate=6))
                    if octave:
                        # Harmony a third below on the high variation.
                        n2 = degree_note(key, scale, chord_here + d - 2, octave)
                        add((bar * 16 + st) * step, tone(step * ln * 0.92, note(n2), duty=0.5, vol=0.08, attack=0.004))
        bar0 += sec["bars"]
    # Trim the spare second we allocated.
    write(name, out[: int(total_bars * 16 * step * RATE)])


def gen_music():
    # Level 1, Platform Zero: driving A minor, ~60s before it repeats.
    i, iv, v, VI, VII = 0, 3, 4, 5, 6
    compose("music_level", 140, 57, MINOR, [
        {"bars": 4, "chords": [i, i, VI, VII], "drums": "half", "bass": "pulse", "arp": True},
        {"bars": 8, "chords": [i, VI, VII, v], "drums": "full", "bass": "pulse", "lead": "a"},
        {"bars": 8, "chords": [iv, i, VI, VII], "drums": "full", "bass": "pulse", "lead": "b", "arp": True},
        {"bars": 4, "chords": [i, i, VI, VII], "drums": "half", "bass": "walk", "arp": True},
        {"bars": 8, "chords": [i, VI, VII, v], "drums": "full", "bass": "pulse", "lead": "a_high"},
        {"bars": 4, "chords": [VI, VII, i, i], "drums": "full", "bass": "pulse", "lead": "b"},
    ], seed=3)

    # Level 2, Rush Hour Ruins: faster D minor with a different hook.
    compose("music_level2", 152, 50, MINOR, [
        {"bars": 4, "chords": [i, VII, VI, VII], "drums": "full", "bass": "pulse"},
        {"bars": 8, "chords": [i, VII, VI, VII], "drums": "full", "bass": "pulse", "lead": "a", "arp": True},
        {"bars": 8, "chords": [iv, v, i, i], "drums": "full", "bass": "walk", "lead": "b"},
        {"bars": 4, "chords": [VI, VI, VII, VII], "drums": "half", "bass": "pulse", "arp": True},
        {"bars": 8, "chords": [i, VII, VI, VII], "drums": "full", "bass": "pulse", "lead": "a_high", "arp": True},
        {"bars": 4, "chords": [iv, v, i, i], "drums": "full", "bass": "pulse", "lead": "b"},
    ], lead_duty=0.5, seed=8)

    # Break room: lazy major-key lounge, no drums, ~40s.
    I, ii, IV, V, vi = 0, 1, 3, 4, 5
    compose("music_break", 96, 60, MAJOR, [
        {"bars": 8, "chords": [I, vi, ii, V], "drums": "none", "bass": "walk", "lead": "a"},
        {"bars": 8, "chords": [IV, I, ii, V], "drums": "none", "bass": "walk", "lead": "b", "arp": True},
    ], lead_duty=0.5, seed=5)

    # Boss: Mister Cheddar's theme. Fast, relentless, a bit silly.
    compose("music_boss", 168, 52, MINOR, [
        {"bars": 4, "chords": [i, i, VI, v], "drums": "full", "bass": "pulse", "arp": True},
        {"bars": 8, "chords": [i, VI, iv, v], "drums": "full", "bass": "pulse", "lead": "a", "arp": True},
        {"bars": 8, "chords": [VI, VII, i, i], "drums": "full", "bass": "walk", "lead": "b"},
        {"bars": 8, "chords": [i, VI, iv, v], "drums": "full", "bass": "pulse", "lead": "a_high", "arp": True},
    ], lead_duty=0.25, seed=21)

    # Title: big fanfare loop.
    compose("music_title", 120, 57, MINOR, [
        {"bars": 4, "chords": [i, i, VI, VII], "drums": "full", "bass": "pulse", "lead": "a"},
        {"bars": 4, "chords": [i, i, VI, VII], "drums": "full", "bass": "pulse", "lead": "a_high", "arp": True},
    ], seed=11)


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    print("audio generated")
