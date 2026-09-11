#!/usr/bin/env python3
"""
Sky Ace • High-Fidelity 1943 Chiptune Loop Synthesizer
Synthesizes the exact 6 arcade BGM tracks from music.html into lightweight,
seamlessly loopable OGG Vorbis audio files for Omarchy Linux and desktop arcade.
"""

import math
import subprocess
from pathlib import Path
import numpy as np

SAMPLE_RATE = 44100

def note_to_freq(note_str):
    if not note_str:
        return 0.0
    # format: e.g. "D4", "F#4", "Bb3", "Eb5", "C#5", "Ab4"
    name = note_str[:-1]
    octave = int(note_str[-1])
    semitones = {
        "C": 0, "C#": 1, "Db": 1,
        "D": 2, "D#": 3, "Eb": 3,
        "E": 4,
        "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8,
        "A": 9, "A#": 10, "Bb": 10,
        "B": 11
    }
    semi = semitones[name]
    # A4 is 440 Hz, MIDI 69
    midi = (octave + 1) * 12 + semi
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))

def time_str_to_seconds(time_str, bpm):
    # format: "bar:beat:sixteenth", e.g. "0:1:2" or "3:2:0"
    parts = time_str.split(":")
    bar = int(parts[0])
    beat = int(parts[1])
    sixteenth = float(parts[2])
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4.0
    six_dur = beat_dur / 4.0
    return bar * bar_dur + beat * beat_dur + sixteenth * six_dur

def dur_str_to_seconds(dur_str, bpm):
    beat_dur = 60.0 / bpm
    durs = {
        "1n": beat_dur * 4.0,
        "2n.": beat_dur * 3.0,
        "2n": beat_dur * 2.0,
        "4n.": beat_dur * 1.5,
        "4n": beat_dur * 1.0,
        "8n.": beat_dur * 0.75,
        "8n": beat_dur * 0.5,
        "16n": beat_dur * 0.25,
        "32n": beat_dur * 0.125,
        "64n": beat_dur * 0.0625,
    }
    return durs.get(dur_str, beat_dur * 0.5)

# Waveform generators
def gen_sawtooth(freq, duration, sr=SAMPLE_RATE):
    n = int(duration * sr)
    if n <= 0 or freq <= 0:
        return np.zeros(max(0, n), dtype=np.float32)
    t = np.arange(n) / sr
    phase = (t * freq) % 1.0
    # anti-aliased / rich sawtooth
    wave = 2.0 * phase - 1.0
    return wave.astype(np.float32)

def gen_triangle(freq, duration, sr=SAMPLE_RATE):
    n = int(duration * sr)
    if n <= 0 or freq <= 0:
        return np.zeros(max(0, n), dtype=np.float32)
    t = np.arange(n) / sr
    phase = (t * freq) % 1.0
    wave = 2.0 * np.abs(2.0 * phase - 1.0) - 1.0
    return wave.astype(np.float32)

def gen_square(freq, duration, duty=0.5, sr=SAMPLE_RATE):
    n = int(duration * sr)
    if n <= 0 or freq <= 0:
        return np.zeros(max(0, n), dtype=np.float32)
    t = np.arange(n) / sr
    phase = (t * freq) % 1.0
    wave = np.where(phase < duty, 1.0, -1.0)
    return wave.astype(np.float32)

def apply_envelope(wave, attack_s, decay_s, sustain_level, release_s, gate_s, sr=SAMPLE_RATE):
    total_len = len(wave)
    env = np.zeros(total_len, dtype=np.float32)
    gate_samples = min(total_len, int(gate_s * sr))
    att_samples = max(1, int(attack_s * sr))
    dec_samples = max(1, int(decay_s * sr))
    rel_samples = max(1, int(release_s * sr))

    for i in range(gate_samples):
        if i < att_samples:
            env[i] = i / att_samples
        elif i < att_samples + dec_samples:
            progress = (i - att_samples) / dec_samples
            env[i] = 1.0 - (1.0 - sustain_level) * progress
        else:
            env[i] = sustain_level

    # release
    start_val = env[gate_samples - 1] if gate_samples > 0 else 0.0
    for i in range(gate_samples, total_len):
        progress = (i - gate_samples) / rel_samples
        if progress >= 1.0:
            env[i] = 0.0
        else:
            env[i] = start_val * (1.0 - progress)

    return wave * env

# =============================================================================
# DATA DEFINITIONS FROM music.html
# =============================================================================

HANGAR_CHORDS = [
    ["D3", "F3", "A3", "C4"],
    ["D3", "G3", "B3", "E4"],
    ["F2", "A3", "C4", "E4"],
    ["G2", "B3", "D4", "F4", "A4"],
    ["D3", "F3", "A3", "C4", "E4"],
    ["Bb2", "F3", "A3", "D4"],
    ["E2", "G3", "Bb3", "D4"],
    ["A2", "D3", "E3", "G3", "C#4"]
]

PATROL_CHORDS = [
    ["D3", "F3", "A3", "D4"],
    ["C3", "F3", "A3", "D4"],
    ["Bb2", "F3", "A3", "D4"],
    ["C3", "E3", "G3", "D4"],
    ["D3", "F3", "A3", "F4"],
    ["A2", "F3", "C4", "E4"],
    ["G2", "D3", "Bb3", "F4"],
    ["A2", "E3", "A3", "E4"]
]

BOSS_CHORDS = [
    ["D3", "F3", "A3", "D4"],
    ["D3", "Eb3", "G3", "Bb3"],
    ["D3", "F3", "Ab3", "B3"],
    ["A2", "E3", "G3", "Bb3"],
    ["D3", "E3", "F3", "A3"],
    ["G2", "D3", "E3", "Bb3"],
    ["Bb2", "F3", "Ab3", "E4"],
    ["A2", "F3", "G3", "C#4"]
]

VICTORY_CHORDS = [
    ["D3", "F#3", "A3", "D4"],
    ["D3", "G3", "B3", "D4"],
    ["C#3", "E3", "A3", "E4"],
    ["B2", "D3", "F#3", "A3"],
    ["G2", "B3", "D4", "F#4"],
    ["F#2", "A3", "D4", "F#4"],
    ["E2", "G3", "B3", "E4"],
    ["A2", "E3", "A3", "C#4"]
]

WARROOM_CHORDS = [
    ["D3", "F3", "A3", "C4", "E4"],
    ["Bb2", "F3", "A3", "D4"],
    ["G2", "Bb3", "D4", "F4", "A4"],
    ["A2", "D3", "E3", "G3"],
    ["F2", "A3", "C4", "E4"],
    ["E2", "G3", "Bb3", "D4"],
    ["C3", "E3", "G3", "Bb3", "D4"],
    ["D3", "F3", "A3", "D4"]
]

DEFEAT_CHORDS = [
    ["D3", "F3", "A3", "D4"],
    ["D3", "G3", "Bb3", "D4"],
    ["C3", "F3", "A3", "D4"],
    ["Bb2", "F3", "A3", "D4"],
    ["G2", "D3", "E3", "Bb3"],
    ["A2", "F3", "A3", "D4"],
    ["A2", "E3", "G3", "C#4"],
    ["D3", "F3", "A3", "D4"]
]

HANGAR_NOTES = [
    ("0:0:0", "D4", "8n"), ("0:0:2", "A4", "8n"), ("0:1:0", "C5", "8n"), ("0:1:2", "D5", "8n"),
    ("0:2:0", "A4", "4n"), ("0:3:0", "F4", "8n"), ("0:3:2", "G4", "8n"),
    ("1:0:0", "B4", "4n"), ("1:1:0", "G4", "8n"), ("1:1:2", "E4", "8n"), ("1:2:0", "G4", "4n"), ("1:3:0", "A4", "4n"),
    ("2:0:0", "C5", "8n"), ("2:0:2", "D5", "8n"), ("2:1:0", "E5", "4n"), ("2:2:0", "C5", "8n"), ("2:2:2", "A4", "8n"), ("2:3:0", "F4", "4n"),
    ("3:0:0", "G4", "8n"), ("3:0:2", "B4", "8n"), ("3:1:0", "D5", "4n"), ("3:2:0", "E5", "4n"), ("3:3:0", "D5", "4n"),
    ("4:0:0", "F5", "8n."), ("4:0:3", "E5", "16n"), ("4:1:0", "D5", "4n"), ("4:2:0", "C5", "8n"), ("4:2:2", "A4", "8n"), ("4:3:0", "D5", "4n"),
    ("5:0:0", "F5", "4n"), ("5:1:0", "D5", "4n"), ("5:2:0", "Bb4", "8n"), ("5:2:2", "C5", "8n"), ("5:3:0", "D5", "4n"),
    ("6:0:0", "G5", "8n"), ("6:0:2", "E5", "8n"), ("6:1:0", "Bb4", "4n"), ("6:2:0", "G4", "8n"), ("6:2:2", "A4", "8n"), ("6:3:0", "Bb4", "4n"),
    ("7:0:0", "A4", "8n"), ("7:0:2", "D5", "8n"), ("7:1:0", "E5", "8n"), ("7:1:2", "F5", "8n"), ("7:2:0", "E5", "8n"), ("7:2:2", "C#5", "8n"), ("7:3:0", "A4", "4n")
]

PATROL_NOTES = [
    ("0:0:0", "D4", "8n"), ("0:1:0", "F4", "8n"), ("0:2:0", "A4", "4n"), ("0:3:0", "D5", "8n."), ("0:3:3", "C5", "16n"),
    ("1:0:0", "A4", "4n"), ("1:1:2", "G4", "8n"), ("1:2:0", "A4", "4n"), ("1:3:2", "C5", "8n"),
    ("2:0:0", "D5", "4n."), ("2:1:2", "C5", "8n"), ("2:2:0", "Bb4", "4n"), ("2:3:0", "A4", "8n"), ("2:3:2", "G4", "8n"),
    ("3:0:0", "A4", "2n"), ("3:2:0", "E4", "4n"), ("3:3:0", "G4", "4n"),
    ("4:0:0", "D5", "8n"), ("4:0:2", "F5", "8n"), ("4:1:0", "A5", "4n"), ("4:2:0", "F5", "8n."), ("4:2:3", "G5", "16n"), ("4:3:0", "E5", "4n"),
    ("5:0:0", "F5", "4n"), ("5:1:0", "D5", "4n"), ("5:2:0", "C5", "8n"), ("5:2:2", "D5", "8n"), ("5:3:0", "E5", "4n"),
    ("6:0:0", "F5", "8n"), ("6:1:0", "D5", "8n"), ("6:1:2", "Bb4", "8n"), ("6:2:0", "G4", "4n"), ("6:3:0", "A4", "4n"),
    ("7:0:0", "D5", "8n"), ("7:0:2", "C#5", "8n"), ("7:1:0", "D5", "8n"), ("7:1:2", "E5", "8n"), ("7:2:0", "F5", "8n"), ("7:2:2", "E5", "8n"), ("7:3:0", "C#5", "8n"), ("7:3:2", "A4", "8n")
]

BOSS_NOTES = [
    ("0:0:0", "D4", "16n"), ("0:0:2", "D4", "16n"), ("0:1:0", "F4", "16n"), ("0:1:2", "G#4", "16n"), ("0:2:0", "A4", "8n"), ("0:3:0", "F4", "16n"), ("0:3:2", "D4", "16n"),
    ("1:0:0", "Eb4", "8n"), ("1:1:0", "D4", "8n"), ("1:2:0", "Eb4", "16n"), ("1:2:2", "G4", "16n"), ("1:3:0", "Bb4", "8n"),
    ("2:0:0", "Ab4", "16n"), ("2:0:2", "F4", "16n"), ("2:1:0", "D4", "8n"), ("2:2:0", "B4", "8n."), ("2:3:1", "Ab4", "16n"),
    ("3:0:0", "A4", "8n"), ("3:1:0", "Bb4", "8n"), ("3:2:0", "A4", "16n"), ("3:2:2", "G4", "16n"), ("3:3:0", "F4", "16n"), ("3:3:2", "E4", "16n"),
    ("4:0:0", "D5", "16n"), ("4:0:2", "D5", "16n"), ("4:1:0", "F5", "8n"), ("4:2:0", "Eb5", "8n"), ("4:3:0", "D5", "8n"),
    ("5:0:0", "G5", "16n"), ("5:0:2", "F5", "16n"), ("5:1:0", "E5", "16n"), ("5:1:2", "D5", "16n"), ("5:2:0", "C#5", "8n"), ("5:3:0", "D5", "8n"),
    ("6:0:0", "Bb5", "8n"), ("6:1:0", "Ab5", "8n"), ("6:2:0", "E5", "4n"), ("6:3:2", "F5", "8n"),
    ("7:0:0", "G5", "16n"), ("7:0:2", "F5", "16n"), ("7:1:0", "E5", "16n"), ("7:1:2", "Eb5", "16n"), ("7:2:0", "D5", "8n"), ("7:3:0", "C#5", "8n")
]

VICTORY_NOTES = [
    ("0:0:0", "D4", "8n"), ("0:0:2", "F#4", "8n"), ("0:1:0", "A4", "8n"), ("0:1:2", "D5", "4n"), ("0:2:2", "E5", "8n"), ("0:3:0", "F#5", "4n"),
    ("1:0:0", "G5", "4n."), ("1:1:2", "F#5", "8n"), ("1:2:0", "E5", "4n"), ("1:3:0", "D5", "4n"),
    ("2:0:0", "E5", "4n."), ("2:1:2", "D5", "8n"), ("2:2:0", "C#5", "4n"), ("2:3:0", "A4", "4n"),
    ("3:0:0", "B4", "2n"), ("3:2:0", "C#5", "4n"), ("3:3:0", "D5", "4n"),
    ("4:0:0", "B4", "8n"), ("4:0:2", "D5", "8n"), ("4:1:0", "G5", "4n."), ("4:2:2", "F#5", "8n"), ("4:3:0", "E5", "4n"),
    ("5:0:0", "F#5", "4n."), ("5:1:2", "E5", "8n"), ("5:2:0", "D5", "4n"), ("5:3:0", "A4", "4n"),
    ("6:0:0", "G4", "8n"), ("6:0:2", "B4", "8n"), ("6:1:0", "D5", "8n"), ("6:1:2", "G5", "8n"), ("6:2:0", "F#5", "4n"), ("6:3:0", "E5", "4n"),
    ("7:0:0", "A5", "4n"), ("7:1:0", "G5", "8n"), ("7:1:2", "F#5", "8n"), ("7:2:0", "E5", "4n"), ("7:3:0", "D5", "4n")
]

WARROOM_NOTES = [
    ("0:0:0", "A4", "4n"), ("0:1:2", "F4", "8n"), ("0:2:0", "D4", "4n."), ("0:3:2", "E4", "8n"),
    ("1:0:0", "F4", "4n"), ("1:1:0", "G4", "4n"), ("1:2:0", "A4", "2n"),
    ("2:0:0", "Bb4", "4n."), ("2:1:2", "A4", "8n"), ("2:2:0", "G4", "4n"), ("2:3:0", "F4", "4n"),
    ("3:0:0", "E4", "2n."), ("3:3:0", "A4", "4n"),
    ("4:0:0", "C5", "4n."), ("4:1:2", "Bb4", "8n"), ("4:2:0", "A4", "4n"), ("4:3:0", "F4", "4n"),
    ("5:0:0", "G4", "4n."), ("5:1:2", "F4", "8n"), ("5:2:0", "E4", "2n"),
    ("6:0:0", "D4", "8n"), ("6:0:2", "F4", "8n"), ("6:1:0", "A4", "8n"), ("6:1:2", "C5", "8n"), ("6:2:0", "E5", "4n"), ("6:3:0", "D5", "4n"),
    ("7:0:0", "A4", "2n"), ("7:2:0", "D4", "2n")
]

DEFEAT_NOTES = [
    ("0:0:0", "D4", "4n"), ("0:1:2", "F4", "8n"), ("0:2:0", "A4", "4n."), ("0:3:2", "F4", "8n"),
    ("1:0:0", "G4", "4n."), ("1:1:2", "F4", "8n"), ("1:2:0", "E4", "4n"), ("1:3:0", "D4", "4n"),
    ("2:0:0", "F4", "4n."), ("2:1:2", "E4", "8n"), ("2:2:0", "D4", "4n"), ("2:3:0", "C4", "4n"),
    ("3:0:0", "Bb3", "2n"), ("3:2:0", "D4", "4n"), ("3:3:0", "F4", "4n"),
    ("4:0:0", "E4", "4n."), ("4:1:2", "F4", "8n"), ("4:2:0", "G4", "4n"), ("4:3:0", "Bb4", "4n"),
    ("5:0:0", "A4", "4n."), ("5:1:2", "G4", "8n"), ("5:2:0", "F4", "4n"), ("5:3:0", "D4", "4n"),
    ("6:0:0", "E4", "4n."), ("6:1:2", "F4", "8n"), ("6:2:0", "E4", "4n"), ("6:3:0", "C#4", "4n"),
    ("7:0:0", "D4", "1n")
]

# Roots
HANGAR_ROOTS = (["D2", "D2", "F2", "G1", "D2", "Bb1", "E1", "A1"], ["D3", "G2", "C3", "D3", "A2", "F2", "G2", "E2"])
PATROL_ROOTS = (["D2", "C2", "Bb1", "C2", "D2", "F2", "G1", "A1"], ["D3", "C3", "Bb2", "C3", "D3", "F3", "G2", "A2"])
BOSS_ROOTS = (["D1", "Eb1", "D1", "A1", "D1", "G1", "Bb1", "A1"], ["D2", "Eb2", "D2", "A2", "D2", "G2", "Bb2", "A2"])
VICTORY_ROOTS = (["D2", "G1", "A1", "B1", "G1", "F#1", "E1", "A1"], ["D3", "G2", "A2", "B2", "G2", "F#2", "E2", "A2"])
WARROOM_ROOTS = (["D2", "Bb1", "G1", "A1", "F1", "E1", "C2", "D2"], ["D3", "Bb2", "G2", "A2", "F2", "E2", "C3", "D3"])
DEFEAT_ROOTS = (["D2", "D2", "C2", "Bb1", "G1", "A1", "A1", "D1"], ["D3", "G2", "C3", "Bb2", "E2", "F2", "A2", "D2"])

# =============================================================================
# SYNTHESIS ENGINE
# =============================================================================

def render_track(bpm, chords, notes, roots_tuple, mode_name):
    roots, oct_roots = roots_tuple
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4.0
    total_dur = bar_dur * 8.0
    total_samples = int(total_dur * SAMPLE_RATE)

    mix_lead = np.zeros(total_samples, dtype=np.float32)
    mix_bass = np.zeros(total_samples, dtype=np.float32)
    mix_chord = np.zeros(total_samples, dtype=np.float32)
    mix_drums = np.zeros(total_samples, dtype=np.float32)

    six_dur = beat_dur / 4.0

    # 1. Lead Melody
    for t_str, n_str, d_str in notes:
        t_start = time_str_to_seconds(t_str, bpm)
        dur = dur_str_to_seconds(d_str, bpm)
        freq = note_to_freq(n_str)
        wave = gen_sawtooth(freq, dur + 0.15)
        env_wave = apply_envelope(wave, attack_s=0.015, decay_s=0.15, sustain_level=0.35, release_s=0.15, gate_s=dur)
        idx_start = int(t_start * SAMPLE_RATE)
        idx_end = min(total_samples, idx_start + len(env_wave))
        slice_len = idx_end - idx_start
        if slice_len > 0:
            mix_lead[idx_start:idx_end] += env_wave[:slice_len] * 0.45

    # 2. Bass & Chords & Drums per 16th step
    for bar in range(8):
        chord_notes = chords[bar]
        for step in range(16):
            step_time = bar * bar_dur + step * six_dur
            idx_start = int(step_time * SAMPLE_RATE)

            # Bass
            bass_freq = 0.0
            trigger_bass = False
            bass_dur = six_dur
            if mode_name == "hangar":
                if step in [0, 3, 6, 8, 10, 14]:
                    bass_freq = note_to_freq(roots[bar])
                    trigger_bass = True
                elif step == 12:
                    bass_freq = note_to_freq(oct_roots[bar])
                    trigger_bass = True
            elif mode_name == "warroom":
                if step % 4 in [0, 2]:
                    bass_freq = note_to_freq(roots[bar])
                    bass_dur = six_dur * 2
                    trigger_bass = True
                elif step % 8 == 7:
                    bass_freq = note_to_freq(oct_roots[bar])
                    trigger_bass = True
            elif mode_name == "defeat":
                if step in [0, 8]:
                    bass_freq = note_to_freq(roots[bar])
                    bass_dur = six_dur * 4
                    trigger_bass = True
                elif step == 12 and bar % 2 == 1:
                    bass_freq = note_to_freq(oct_roots[bar])
                    bass_dur = six_dur * 2
                    trigger_bass = True
            else: # patrol, boss, victory
                if step % 2 == 0:
                    bass_freq = note_to_freq(roots[bar])
                    trigger_bass = True
                elif mode_name in ["boss", "victory"] or step % 4 == 3:
                    bass_freq = note_to_freq(oct_roots[bar])
                    trigger_bass = True

            if trigger_bass and bass_freq > 0:
                b_wave = gen_sawtooth(bass_freq, bass_dur + 0.08)
                b_env = apply_envelope(b_wave, 0.005, 0.12, 0.25, 0.08, gate_s=bass_dur)
                idx_end = min(total_samples, idx_start + len(b_env))
                slen = idx_end - idx_start
                if slen > 0:
                    mix_bass[idx_start:idx_end] += b_env[:slen] * 0.42

            # Chords
            trigger_chord = False
            c_dur = six_dur
            if mode_name == "hangar" and step in [2, 6, 8, 12]:
                trigger_chord = True
            elif mode_name == "boss" and step in [0, 3, 6, 10, 14]:
                trigger_chord = True
            elif mode_name == "victory" and step in [0, 3, 8, 11, 14]:
                trigger_chord = True
            elif mode_name == "warroom" and step in [0, 6, 12]:
                trigger_chord = True
                c_dur = six_dur * 2
            elif mode_name == "defeat" and step in [0, 8]:
                trigger_chord = True
                c_dur = six_dur * 8
            elif mode_name == "patrol" and step in [2, 8, 12]:
                trigger_chord = True

            if trigger_chord:
                for c_note in chord_notes:
                    c_freq = note_to_freq(c_note)
                    c_wave = gen_triangle(c_freq, c_dur + 0.12)
                    c_env = apply_envelope(c_wave, 0.02, 0.22, 0.25, 0.1, gate_s=c_dur)
                    idx_end = min(total_samples, idx_start + len(c_env))
                    slen = idx_end - idx_start
                    if slen > 0:
                        mix_chord[idx_start:idx_end] += c_env[:slen] * (0.28 / len(chord_notes))

            # Drums
            # Kick
            trigger_kick = False
            if mode_name == "hangar" and step in [0, 6, 8, 14]: trigger_kick = True
            elif mode_name == "boss" and step in [0, 2, 6, 8, 10, 14]: trigger_kick = True
            elif mode_name == "victory" and step in [0, 4, 8, 12]: trigger_kick = True
            elif mode_name == "warroom" and step in [0, 8, 10]: trigger_kick = True
            elif mode_name == "defeat" and step in [0, 8]: trigger_kick = True
            elif mode_name == "patrol" and step in [0, 6, 8, 14]: trigger_kick = True

            if trigger_kick:
                k_len = int(0.22 * SAMPLE_RATE)
                t_k = np.arange(k_len) / SAMPLE_RATE
                k_pitch = 140.0 * np.exp(-t_k * 28.0) + 42.0
                k_wave = np.sin(2.0 * math.pi * k_pitch * t_k) * np.exp(-t_k * 18.0)
                idx_end = min(total_samples, idx_start + k_len)
                slen = idx_end - idx_start
                if slen > 0:
                    mix_drums[idx_start:idx_end] += k_wave[:slen] * 0.55

            # Snare
            trigger_snare = False
            if mode_name == "hangar" and step in [4, 12]: trigger_snare = True
            elif mode_name == "boss" and step in [4, 7, 12, 15]: trigger_snare = True
            elif mode_name == "victory" and step in [4, 12, 15]: trigger_snare = True
            elif mode_name == "warroom" and step in [4, 12]: trigger_snare = True
            elif mode_name == "defeat" and step in [4, 12]: trigger_snare = True
            elif mode_name == "patrol" and (step in [4, 12] or ((bar in [3, 7]) and step >= 13)): trigger_snare = True

            if trigger_snare:
                sn_len = int(0.16 * SAMPLE_RATE)
                t_sn = np.arange(sn_len) / SAMPLE_RATE
                sn_noise = np.random.uniform(-1.0, 1.0, sn_len).astype(np.float32) * np.exp(-t_sn * 24.0)
                sn_body = np.sin(2.0 * math.pi * 180.0 * t_sn) * np.exp(-t_sn * 35.0)
                sn_wave = sn_noise * 0.7 + sn_body * 0.3
                idx_end = min(total_samples, idx_start + sn_len)
                slen = idx_end - idx_start
                if slen > 0:
                    mix_drums[idx_start:idx_end] += sn_wave[:slen] * 0.38

            # Hi-hat
            hi_len = int(0.045 * SAMPLE_RATE)
            t_hi = np.arange(hi_len) / SAMPLE_RATE
            hi_wave = np.random.uniform(-1.0, 1.0, hi_len).astype(np.float32) * np.exp(-t_hi * 80.0)
            idx_end = min(total_samples, idx_start + hi_len)
            slen = idx_end - idx_start
            if slen > 0:
                mix_drums[idx_start:idx_end] += hi_wave[:slen] * 0.16

    # Final Master Mix & Soft Limiter
    master = mix_lead + mix_bass + mix_chord + mix_drums
    # Soft saturation curve: tanh
    master = np.tanh(master * 1.35) * 0.92

    # Return stereo array (interleaved or shape (2, N))
    stereo = np.zeros((total_samples, 2), dtype=np.float32)
    stereo[:, 0] = master
    stereo[:, 1] = master
    return stereo

def save_as_audio(stereo_data, output_base_path):
    output_base_path = Path(output_base_path)
    output_base_path.parent.mkdir(parents=True, exist_ok=True)
    wav_path = output_base_path.with_suffix(".wav")
    ogg_path = output_base_path.with_suffix(".ogg")

    # 1. Write pristine 16-bit PCM WAV (universal hardware playback)
    int16_data = np.clip(stereo_data * 32767.0, -32768.0, 32767.0).astype(np.int16)
    import wave
    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(int16_data.tobytes())

    # 2. Convert to high efficiency OGG (Opus) for Linux
    cmd = [
        "ffmpeg", "-y", "-i", str(wav_path),
        "-c:a", "libopus", "-b:a", "96k",
        str(ogg_path)
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    size_wav_kb = wav_path.stat().st_size / 1024.0
    size_ogg_kb = ogg_path.stat().st_size / 1024.0
    print(f"✓ Rendered: {wav_path.name} ({size_wav_kb:.1f} KB) & {ogg_path.name} ({size_ogg_kb:.1f} KB)")

def main():
    tracks = [
        ("bgm_hangar.ogg", 126, HANGAR_CHORDS, HANGAR_NOTES, HANGAR_ROOTS, "hangar"),
        ("bgm_patrol.ogg", 144, PATROL_CHORDS, PATROL_NOTES, PATROL_ROOTS, "patrol"),
        ("bgm_boss.ogg", 154, BOSS_CHORDS, BOSS_NOTES, BOSS_ROOTS, "boss"),
        ("bgm_victory.ogg", 138, VICTORY_CHORDS, VICTORY_NOTES, VICTORY_ROOTS, "victory"),
        ("bgm_warroom.ogg", 116, WARROOM_CHORDS, WARROOM_NOTES, WARROOM_ROOTS, "warroom"),
        ("bgm_defeat.ogg", 92, DEFEAT_CHORDS, DEFEAT_NOTES, DEFEAT_ROOTS, "defeat")
    ]

    out_dir = Path("/Users/christhompson/arcade/games/skyace/sounds")
    print(f"Synthesizing 6 Sky Ace chiptune loops into {out_dir}...")
    total_size = 0
    for filename, bpm, chords, notes, roots, mode in tracks:
        audio = render_track(bpm, chords, notes, roots, mode)
        target = out_dir / filename
        save_as_audio(audio, target)
        total_size += (out_dir / filename).with_suffix(".ogg").stat().st_size

    print(f"\nAll 6 tracks rendered in WAV and OGG! Total OGG soundtrack size: {total_size / 1024.0:.1f} KB ({(total_size / (1024.0 * 1024.0)):.2f} MB)")

if __name__ == "__main__":
    main()
