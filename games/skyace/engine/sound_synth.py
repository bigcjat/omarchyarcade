#!/usr/bin/env python3
"""
Sky Ace • 16-Bit Retro Arcade Sound Synthesizer
Generates punchy, authentic arcade sound effects in uncompressed WAV format.
"""

import math
import struct
import random
from pathlib import Path

SAMPLE_RATE = 22050

def write_wav(filename, samples):
    path = Path(filename)
    path.parent.mkdir(parents=True, exist_ok=True)
    num_samples = len(samples)
    byte_rate = SAMPLE_RATE * 2
    block_align = 2
    subchunk2_size = num_samples * 2
    chunk_size = 36 + subchunk2_size

    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF', chunk_size, b'WAVE',
        b'fmt ', 16, 1, 1, SAMPLE_RATE, byte_rate, block_align, 16,
        b'data', subchunk2_size
    )
    raw_data = bytearray(header)
    for s in samples:
        val = int(max(-1.0, min(1.0, s)) * 32767)
        raw_data.extend(struct.pack('<h', val))

    with open(path, 'wb') as f:
        f.write(raw_data)

def gen_twin_gun():
    """Crisp, punchy .50 cal machine gun shot."""
    dur = 0.09
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-32.0 * t)
        freq = 320.0 * (1.0 - 0.7 * (t / dur))
        tone = math.sin(2.0 * math.pi * freq * t)
        noise = random.uniform(-0.5, 0.5) * math.exp(-45.0 * t)
        samples.append(env * (0.65 * tone + 0.35 * noise))
    return samples

def gen_cannon():
    """Heavy 20mm autocannon thud."""
    dur = 0.16
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-22.0 * t)
        freq = 180.0 * (1.0 - 0.8 * (t / dur))
        tone = math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(2.0 * math.pi * freq * 0.5 * t)
        noise = random.uniform(-0.6, 0.6) * math.exp(-30.0 * t)
        samples.append(env * (0.6 * tone + 0.4 * noise))
    return samples

def gen_shotgun():
    """1943 Retro Shotgun explosive spread blast."""
    dur = 0.28
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-14.0 * t)
        noise = random.uniform(-1.0, 1.0)
        low_tone = math.sin(2.0 * math.pi * 110.0 * (1.0 - 0.5 * (t / dur)) * t)
        samples.append(env * (0.4 * low_tone + 0.6 * noise))
    return samples

def gen_missile():
    """Homing rocket booster whoosh."""
    dur = 0.32
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * min(1.0, t / dur))
        freq = 240.0 + 380.0 * (t / dur)
        tone = math.sin(2.0 * math.pi * freq * t)
        noise = random.uniform(-0.4, 0.4)
        samples.append(env * (0.5 * tone + 0.5 * noise) * 0.75)
    return samples

def gen_explosion_small():
    """Crisp fighter destruction."""
    dur = 0.35
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-9.0 * t)
        noise = random.uniform(-1.0, 1.0)
        thud = math.sin(2.0 * math.pi * (140.0 * (1.0 - t/dur)) * t)
        samples.append(env * (0.65 * noise + 0.35 * thud))
    return samples

def gen_explosion_large():
    """Heavy bomber / boss destruction with deep bass rumble."""
    dur = 0.75
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-4.5 * t)
        noise = random.uniform(-1.0, 1.0)
        sub = math.sin(2.0 * math.pi * (75.0 * math.exp(-2.0 * t)) * t)
        samples.append(env * (0.55 * noise + 0.45 * sub))
    return samples

def gen_pow_pickup():
    """Vibrant Capcom arcade ascending 2-tone chime."""
    dur = 0.22
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        freq = 587.33 if t < 0.10 else 880.0  # D5 -> A5
        env = math.exp(-12.0 * (t % 0.11))
        tone = math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(2.0 * math.pi * freq * 2.0 * t)
        samples.append(env * tone * 0.7)
    return samples

def gen_loop_whoosh():
    """360° Loop aerodynamic G-force slipstream rush."""
    dur = 0.65
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / dur)) ** 1.5
        noise = random.uniform(-0.8, 0.8)
        sweep = math.sin(2.0 * math.pi * (180.0 + 220.0 * math.sin(math.pi * t / dur)) * t)
        samples.append(env * (0.6 * noise + 0.4 * sweep) * 0.8)
    return samples

def gen_mega_crash():
    """1943 Screen-clearing thunderous detonation."""
    dur = 0.85
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-3.5 * t)
        zap = math.sin(2.0 * math.pi * (800.0 * math.exp(-12.0 * t)) * t)
        rumble = math.sin(2.0 * math.pi * 55.0 * t)
        noise = random.uniform(-1.0, 1.0)
        samples.append(env * (0.4 * zap + 0.3 * rumble + 0.3 * noise))
    return samples

def gen_damage_hit():
    """Metal impact shrapnel clang."""
    dur = 0.18
    num_samples = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-24.0 * t)
        clang = math.sin(2.0 * math.pi * 920.0 * t) + 0.4 * math.sin(2.0 * math.pi * 1440.0 * t)
        noise = random.uniform(-0.5, 0.5) * math.exp(-35.0 * t)
        samples.append(env * (0.7 * clang + 0.3 * noise))
    return samples

def gen_victory_fanfare():
    """8-bit/16-bit arcade triumphant victory arpeggio chord."""
    notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
    note_dur = 0.14
    tail_dur = 0.60
    total_dur = len(notes) * note_dur + tail_dur
    num_samples = int(SAMPLE_RATE * total_dur)
    samples = [0.0] * num_samples

    for idx, f in enumerate(notes):
        start_t = idx * note_dur
        start_sample = int(start_t * SAMPLE_RATE)
        dur = note_dur if idx < len(notes) - 1 else (note_dur + tail_dur)
        n_s = int(dur * SAMPLE_RATE)
        for i in range(n_s):
            if start_sample + i < num_samples:
                t = i / SAMPLE_RATE
                env = math.exp(-2.8 * t) if idx == len(notes) - 1 else min(1.0, i / (SAMPLE_RATE * 0.02)) * math.exp(-4.0 * t)
                # Brass-like harmonic overtone
                sig = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(4 * math.pi * f * t) + 0.25 * math.sin(6 * math.pi * f * t)
                samples[start_sample + i] += 0.45 * env * sig

    return samples

def build_all_sounds(target_dir):
    td = Path(target_dir)
    td.mkdir(parents=True, exist_ok=True)
    
    generators = {
        "shoot_twin.wav": gen_twin_gun,
        "shoot_cannon.wav": gen_cannon,
        "shoot_shotgun.wav": gen_shotgun,
        "missile_launch.wav": gen_missile,
        "explosion_small.wav": gen_explosion_small,
        "explosion_large.wav": gen_explosion_large,
        "pow_pickup.wav": gen_pow_pickup,
        "loop_whoosh.wav": gen_loop_whoosh,
        "mega_crash.wav": gen_mega_crash,
        "damage_hit.wav": gen_damage_hit,
        "victory_fanfare.wav": gen_victory_fanfare,
    }

    print(f"[Sky Ace Audio] Generating {len(generators)} authentic 16-bit sound effects...")
    for filename, fn in generators.items():
        out_file = td / filename
        samples = fn()
        write_wav(out_file, samples)
        print(f"  ✓ {filename} ({len(samples)} samples)")

if __name__ == "__main__":
    build_all_sounds("games/skyace/sounds")
