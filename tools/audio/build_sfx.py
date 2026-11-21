"""Synthesize the Four Alike gameplay sound effects (16-bit mono WAV, 44.1 kHz).

Usage: python3 tools/audio/build_sfx.py [--check]
Writes godot/game/assets/audio/sfx. Pure standard library so the result is reproducible on any machine; --check compares
with the files on disk and exits 1 on any difference.
"""
import math
import pathlib
import random
import struct
import sys
import wave

OUT = pathlib.Path(__file__).resolve().parents[2] / "godot/game/assets/audio/sfx"
RATE = 44100
NOTE = {"C5": 523.25, "D5": 587.33, "Eb5": 622.25, "E5": 659.25, "G5": 783.99, "A5": 880.0, "B5": 987.77,
        "C6": 1046.5, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98, "C7": 2093.0, "A4": 440.0, "G4": 392.0,
        "E4": 329.63, "C4": 261.63, "F4": 349.23, "D4": 293.66}


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mallet(freq, seconds, gain=0.5, decay=9.0, bright=0.35):
    """Marimba-like tone: fundamental plus quickly fading overtones."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, t / 0.004)
        s = math.sin(2 * math.pi * freq * t)
        s += bright * math.exp(-22 * t) * math.sin(2 * math.pi * freq * 4.0 * t)
        s += 0.18 * math.exp(-14 * t) * math.sin(2 * math.pi * freq * 2.0 * t)
        out.append(gain * env * s)
    return out


def bell(freq, seconds, gain=0.4, decay=5.0):
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, t / 0.002)
        s = math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-8 * t)
        s += 0.25 * math.sin(2 * math.pi * freq * 5.4 * t) * math.exp(-16 * t)
        out.append(gain * env * s)
    return out


def sweep(f0, f1, seconds, gain=0.45, decay=18.0):
    out, phase = [], 0.0
    n = int(RATE * seconds)
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / RATE
        env = math.exp(-decay * t) * min(1.0, t / 0.003)
        out.append(gain * env * math.sin(phase))
    return out


def noise(seconds, gain=0.3, decay=30.0, smooth=0.25, seed=1):
    rng = random.Random(seed)
    out, last = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        last += smooth * (rng.uniform(-1, 1) - last)
        env = math.exp(-decay * t) * min(1.0, t / 0.005)
        out.append(gain * env * last * 2.2)
    return out


def mix(*layers):
    n = max(len(layer) for layer in layers)
    return [sum(layer[i] if i < len(layer) else 0.0 for layer in layers) for i in range(n)]


def at(offset, samples):
    return silence(offset) + samples


def arp(notes, step, seconds, gain=0.42, voice=mallet):
    return mix(*[at(i * step, voice(NOTE[n], seconds, gain)) for i, n in enumerate(notes)])


def fade_tail(samples, seconds=0.012):
    n = min(len(samples), int(RATE * seconds))
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


SOUNDS = {
    "card_select": lambda: sweep(620, 900, 0.07, 0.42, 26),
    "card_deselect": lambda: sweep(560, 400, 0.07, 0.36, 26),
    "card_slide": lambda: mix(noise(0.14, 0.34, 22, 0.18, 3), sweep(300, 220, 0.12, 0.12, 20)),
    "card_flip": lambda: mix(noise(0.05, 0.4, 60, 0.6, 5), at(0.025, sweep(420, 760, 0.07, 0.28, 30))),
    "group_complete": lambda: arp(["C5", "E5", "G5", "C6"], 0.07, 0.45),
    "miss": lambda: mix(sweep(230, 150, 0.16, 0.5, 16), at(0.09, sweep(200, 130, 0.16, 0.4, 16))),
    "one_away": lambda: arp(["E5", "Eb5"], 0.11, 0.3, 0.4),
    "stuck": lambda: arp(["A4", "F4", "D4"], 0.12, 0.4, 0.38),
    "booster": lambda: arp(["G5", "B5", "D6", "G6"], 0.045, 0.3, 0.3, bell),
    "slot_unlock": lambda: mix(noise(0.03, 0.4, 80, 0.7, 7), at(0.04, arp(["E5", "A5", "E6"], 0.06, 0.4, 0.34, bell))),
    "coin": lambda: mix(bell(NOTE["E6"], 0.18, 0.3, 14), at(0.04, bell(NOTE["C7"], 0.2, 0.26, 12))),
    "star_1": lambda: bell(NOTE["G5"], 0.5, 0.42, 7),
    "star_2": lambda: bell(NOTE["B5"], 0.5, 0.42, 7),
    "star_3": lambda: mix(bell(NOTE["D6"], 0.7, 0.42, 5), at(0.03, bell(NOTE["G6"], 0.6, 0.2, 6))),
    "win": lambda: mix(arp(["C5", "E5", "G5", "C6", "E6"], 0.09, 0.7, 0.34), at(0.45, mix(bell(NOTE["C6"], 0.9, 0.22, 4), bell(NOTE["G6"], 0.9, 0.16, 4)))),
    "fail": lambda: arp(["G4", "E4", "C4"], 0.16, 0.6, 0.4),
    "hint": lambda: arp(["A5", "E6"], 0.08, 0.35, 0.3, bell),
    "undo": lambda: sweep(700, 360, 0.16, 0.34, 14),
}


def render(name):
    samples = fade_tail(SOUNDS[name]())
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.89 / peak)
    return b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)


def wav_bytes(frames):
    import io
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    return buf.getvalue()


def main():
    check = "--check" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name in sorted(SOUNDS):
        data = wav_bytes(render(name))
        path = OUT / f"{name}.wav"
        if check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
        else:
            path.write_bytes(data)
            print(f"{name:16s} {len(data) / 2 / RATE:5.2f}s")
    for stray in sorted(q for q in OUT.glob("*.wav") if q.stem not in SOUNDS):
        if check:
            stale.append(f"{stray.name} (not generated)")
        else:
            stray.unlink()
    if stale:
        print("out of date:", stale)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
