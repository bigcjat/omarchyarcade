#!/usr/bin/env python3
"""
Synthesizes authentic Canadian VLT Keno sound effects.
Zero dependencies: standard library math, wave, struct.
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
SOUNDS_DIR = Path(__file__).resolve().parent.parent / "games" / "keno" / "sounds"
SOUNDS_DIR.mkdir(parents=True, exist_ok=True)

def write_wav(filename, samples):
    filepath = SOUNDS_DIR / filename
    with wave.open(str(filepath), "wb") as wf:
        wf.setnchannels(1)     # Mono
        wf.setsampwidth(2)     # 16-bit
        wf.setframerate(SAMPLE_RATE)
        packed = bytearray()
        for s in samples:
            # Clamp to 16-bit range
            clamped = max(-32767, min(32767, int(s * 32767)))
            packed.extend(struct.pack("<h", clamped))
        wf.writeframes(packed)
    print(f"Generated {filepath.name} ({len(samples)} samples)")

def env_decay(length, decay_rate=5.0):
    for i in range(length):
        t = i / length
        yield math.exp(-decay_rate * t)

# 1. keno_select.wav: crisp electronic arcade select chirp
def make_select():
    duration = 0.08
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 880 + 880 * (i / n)
        env = (1.0 - i / n) * 0.7
        val = math.sin(2 * math.pi * freq * t) * env
        samples.append(val)
    write_wav("keno_select.wav", samples)

# 2. keno_deselect.wav: subtle soft low tap
def make_deselect():
    duration = 0.06
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 550 - 250 * (i / n)
        env = (1.0 - i / n) * 0.5
        val = math.sin(2 * math.pi * freq * t) * env
        samples.append(val)
    write_wav("keno_deselect.wav", samples)

# 3. keno_ball_drop.wav: iconic VLT rapid ping / ball stamp
def make_ball_drop():
    duration = 0.12
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-22.0 * t)
        # Hollow metallic percussive ping
        f1 = 780
        f2 = 1560
        f3 = 2340
        val = (0.55 * math.sin(2 * math.pi * f1 * t) +
               0.30 * math.sin(2 * math.pi * f2 * t) +
               0.15 * math.sin(2 * math.pi * f3 * t)) * env
        samples.append(val)
    write_wav("keno_ball_drop.wav", samples)

# 4. keno_hit.wav: THE ICONIC VLT KENO HIT! Bright resonant two-tone bell
def make_hit():
    duration = 0.45
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-7.0 * t)
        # Major chord bell: C6 (1046Hz), E6 (1318Hz), G6 (1568Hz)
        val = (0.45 * math.sin(2 * math.pi * 1046.5 * t) +
               0.35 * math.sin(2 * math.pi * 1318.5 * t) +
               0.20 * math.sin(2 * math.pi * 1568.0 * t)) * env
        # Slight shimmer tremolo
        trem = 1.0 + 0.15 * math.sin(2 * math.pi * 35 * t)
        samples.append(val * trem * 0.9)
    write_wav("keno_hit.wav", samples)

# 5. keno_power_hit.wav: Electric surge / lightning crash / deep power hit
def make_power_hit():
    duration = 0.70
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-4.5 * t)
        # Deep bass strike (110Hz) + electric buzz (440Hz + 880Hz + saw)
        bass = math.sin(2 * math.pi * 110 * t) * math.exp(-6.0 * t) * 0.6
        chime = (math.sin(2 * math.pi * 1318.5 * t) + math.sin(2 * math.pi * 1760 * t)) * env * 0.4
        # Electric noise grit
        noise = (math.sin(2 * math.pi * (t * 8000 % 1) * 300)) * math.exp(-18.0 * t) * 0.3
        samples.append((bass + chime + noise) * 0.95)
    write_wav("keno_power_hit.wav", samples)

# 6. keno_super_hit.wav: Rising high-energy ignition laser chord
def make_super_hit():
    duration = 0.65
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-5.0 * t)
        f = 440 + 880 * math.sqrt(i / n)
        val = (0.5 * math.sin(2 * math.pi * f * t) +
               0.3 * math.sin(2 * math.pi * (f * 1.5) * t) +
               0.2 * math.sin(2 * math.pi * (f * 2.0) * t)) * env
        samples.append(val * 0.85)
    write_wav("keno_super_hit.wav", samples)

# 7. keno_bonus.wav: Cleopatra Free Games fanfare
def make_bonus():
    duration = 1.1
    n = int(SAMPLE_RATE * duration)
    samples = []
    # 3-step arpeggio: A4 (440), C#5 (554), E5 (659), A5 (880)
    notes = [440, 554.37, 659.25, 880]
    step = int(SAMPLE_RATE * 0.18)
    for i in range(n):
        t = i / SAMPLE_RATE
        note_idx = min(len(notes) - 1, i // step)
        freq = notes[note_idx]
        local_t = (i % step) / SAMPLE_RATE if note_idx < len(notes) - 1 else (i - 3 * step) / SAMPLE_RATE
        env = math.exp(-3.0 * (i / n))
        val = (0.6 * math.sin(2 * math.pi * freq * t) +
               0.3 * math.sin(2 * math.pi * freq * 2 * t) +
               0.1 * math.sin(2 * math.pi * freq * 3 * t)) * env
        samples.append(val * 0.85)
    write_wav("keno_bonus.wav", samples)

# 8. keno_win.wav: Triumphant casino win jingle
def make_win():
    duration = 0.9
    n = int(SAMPLE_RATE * duration)
    samples = []
    # C major fanfare: C5, E5, G5, C6
    notes = [523.25, 659.25, 783.99, 1046.5]
    step = int(SAMPLE_RATE * 0.15)
    for i in range(n):
        t = i / SAMPLE_RATE
        note_idx = min(len(notes) - 1, i // step)
        freq = notes[note_idx]
        env = math.exp(-3.5 * (i / n))
        val = (0.55 * math.sin(2 * math.pi * freq * t) +
               0.35 * math.sin(2 * math.pi * freq * 1.5 * t) +
               0.10 * math.sin(2 * math.pi * freq * 2.0 * t)) * env
        samples.append(val * 0.85)
    write_wav("keno_win.wav", samples)

# 9. keno_credit.wav: Fast casino credit count-up ticker
def make_credit():
    duration = 0.04
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-40.0 * t)
        val = math.sin(2 * math.pi * 1800 * t) * env
        samples.append(val * 0.6)
    write_wav("keno_credit.wav", samples)

def main():
    print("Synthesizing Canadian VLT Keno sounds...")
    make_select()
    make_deselect()
    make_ball_drop()
    make_hit()
    make_power_hit()
    make_super_hit()
    make_bonus()
    make_win()
    make_credit()
    print("Sound synthesis complete!")

if __name__ == "__main__":
    main()
