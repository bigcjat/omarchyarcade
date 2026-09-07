#!/usr/bin/env python3
"""
KeiRacer • Procedural Engine Audio Synthesizer
Continuous real-time acoustic physics synthesis.
Supports native macOS AudioQueue and Linux streaming (pw-cat / pw-play / paplay / aplay).
Implements cylinder exhaust pulse math, on/off throttle filtering, and clutch shift cuts.
"""

import sys
import math
import ctypes
import shutil
import subprocess
import threading
import time

# AudioToolbox ctypes bindings for macOS low-latency streaming
try:
    if sys.platform == "darwin":
        _toolbox = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox")
    else:
        _toolbox = None
except Exception:
    _toolbox = None

class AudioStreamBasicDescription(ctypes.Structure):
    _fields_ = [
        ("mSampleRate", ctypes.c_double),
        ("mFormatID", ctypes.c_uint32),
        ("mFormatFlags", ctypes.c_uint32),
        ("mBytesPerPacket", ctypes.c_uint32),
        ("mFramesPerPacket", ctypes.c_uint32),
        ("mBytesPerFrame", ctypes.c_uint32),
        ("mChannelsPerFrame", ctypes.c_uint32),
        ("mBitsPerChannel", ctypes.c_uint32),
        ("mReserved", ctypes.c_uint32),
    ]

class AudioQueueBuffer(ctypes.Structure):
    _fields_ = [
        ("mAudioDataBytesCapacity", ctypes.c_uint32),
        ("mAudioData", ctypes.c_void_p),
        ("mAudioDataByteSize", ctypes.c_uint32),
        ("mUserData", ctypes.c_void_p),
        ("mPacketDescriptionCapacity", ctypes.c_uint32),
        ("mPacketDescriptions", ctypes.c_void_p),
        ("mPacketDescriptionCount", ctypes.c_uint32),
    ]

AudioQueueOutputCallback = ctypes.CFUNCTYPE(
    None, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(AudioQueueBuffer)
)


class ProceduralEngineAudio:
    """
    Real-time procedural acoustic synthesizer.
    Generates continuous cylinder exhaust expansion pulses, transmission gear whine,
    turbo whistle, on/off throttle low-pass filtering, and clutch shift cuts.
    Cross-platform: AudioQueue on macOS, pw-cat/pw-play/paplay/aplay on Linux.
    """
    def __init__(self, sample_rate=22050):
        self.sample_rate = float(sample_rate)
        self.dt = 1.0 / self.sample_rate
        
        # Audio state
        self.car_id = "keitruck"
        self.target_rpm = 850.0
        self.current_rpm = 850.0
        self.is_accelerating = False
        self.speed = 0.0
        self.is_shift_cut = False
        self.is_muted = False
        
        # Synthesis phases
        self.phase_crank = 0.0
        self.phase_gear = 0.0
        self.phase_turbo = 0.0
        self.phase_electric = 0.0
        
        # On-throttle dynamic envelope & filters
        self.throttle_filter = 0.0
        self.lpf_state = 0.0
        self.shift_cut_gain = 1.0
        self.burble_phase = 0.0
        self.burble_seed = 12345
        
        self.running = False
        self.aq_ptr = ctypes.c_void_p()
        self._buffers = []
        self._callback_ref = None
        self._linux_proc = None
        self._stream_thread = None
        
        if _toolbox:
            self._init_audio_queue()

    def _init_audio_queue(self):
        kAudioFormatLinearPCM = 0x6C70636D
        kAudioFormatFlagIsSignedInteger = (1 << 2)
        kAudioFormatFlagIsPacked = (1 << 3)
        
        fmt = AudioStreamBasicDescription()
        fmt.mSampleRate = self.sample_rate
        fmt.mFormatID = kAudioFormatLinearPCM
        fmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        fmt.mBytesPerPacket = 2
        fmt.mFramesPerPacket = 1
        fmt.mBytesPerFrame = 2
        fmt.mChannelsPerFrame = 1
        fmt.mBitsPerChannel = 16
        fmt.mReserved = 0
        
        self._callback_ref = AudioQueueOutputCallback(self._audio_callback)
        
        status = _toolbox.AudioQueueNewOutput(
            ctypes.byref(fmt),
            self._callback_ref,
            None,
            None,
            None,
            0,
            ctypes.byref(self.aq_ptr)
        )
        if status != 0:
            print(f"Warning: AudioQueueNewOutput failed with status {status}")
            return
            
        buf_size = 1024 * 2
        self._buffers = []
        for _ in range(3):
            buf = ctypes.POINTER(AudioQueueBuffer)()
            _toolbox.AudioQueueAllocateBuffer(self.aq_ptr, buf_size, ctypes.byref(buf))
            self._buffers.append(buf)
            self._fill_buffer(buf)

    def start(self):
        if self.running:
            return
        self.running = True
        if _toolbox and self.aq_ptr:
            status = _toolbox.AudioQueueStart(self.aq_ptr, None)
            if status != 0:
                print(f"Warning: AudioQueueStart returned {status}")
        else:
            self._start_linux_stream()

    def _start_linux_stream(self):
        cmd = None
        sr = str(int(self.sample_rate))
        if shutil.which("pw-cat"):
            cmd = ["pw-cat", "-p", f"--rate={sr}", "--format=s16", "--channels=1", "-"]
        elif shutil.which("pw-play"):
            cmd = ["pw-play", f"--rate={sr}", "--format=s16", "--channels=1", "-"]
        elif shutil.which("paplay"):
            cmd = ["paplay", "--raw", f"--rate={sr}", "--channels=1", "--format=s16le"]
        elif shutil.which("aplay"):
            cmd = ["aplay", "-q", "-r", sr, "-f", "S16_LE", "-c", "1", "-t", "raw", "-"]

        if not cmd:
            print("[AudioEngine] Note: No Linux audio sink (pw-cat/pw-play/paplay/aplay) found.")
            return

        def stream_worker():
            chunk_samples = 512 # ~23ms low-latency buffer chunks
            c_short_array = (ctypes.c_int16 * chunk_samples)()
            silence = b"\x00" * (chunk_samples * 2)
            try:
                proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
                self._linux_proc = proc
                while self.running and proc.poll() is None:
                    if self.is_muted:
                        proc.stdin.write(silence)
                        proc.stdin.flush()
                        time.sleep(chunk_samples / self.sample_rate)
                        continue

                    self._generate_samples(c_short_array, chunk_samples)
                    proc.stdin.write(bytes(c_short_array))
                    proc.stdin.flush()

                try:
                    proc.stdin.close()
                    proc.terminate()
                except Exception:
                    pass
            except Exception as e:
                print("[AudioEngine] Linux stream error:", e)

        self._stream_thread = threading.Thread(target=stream_worker, daemon=True)
        self._stream_thread.start()

    def stop(self):
        self.running = False
        if _toolbox and self.aq_ptr:
            _toolbox.AudioQueueStop(self.aq_ptr, True)
        if self._linux_proc:
            try:
                self._linux_proc.terminate()
            except Exception:
                pass

    def update_state(self, car_id, rpm, is_accelerating, speed, is_shift_cut, is_muted):
        """Update audio parameters from QML game tick (60 FPS)."""
        self.car_id = str(car_id).lower()
        self.target_rpm = float(rpm)
        self.is_accelerating = bool(is_accelerating)
        self.speed = float(speed)
        self.is_shift_cut = bool(is_shift_cut)
        self.is_muted = bool(is_muted)

    def _audio_callback(self, user_data, aq, buf_ptr):
        if not self.running:
            return
        self._fill_buffer(buf_ptr)

    def _fill_buffer(self, buf_ptr):
        buf = buf_ptr.contents
        num_samples = buf.mAudioDataBytesCapacity // 2
        c_short_array = (ctypes.c_int16 * num_samples).from_address(buf.mAudioData)
        
        if self.is_muted:
            ctypes.memset(buf.mAudioData, 0, buf.mAudioDataBytesCapacity)
            buf.mAudioDataByteSize = buf.mAudioDataBytesCapacity
            _toolbox.AudioQueueEnqueueBuffer(self.aq_ptr, buf_ptr, 0, None)
            return

        self._generate_samples(c_short_array, num_samples)
        buf.mAudioDataByteSize = num_samples * 2
        _toolbox.AudioQueueEnqueueBuffer(self.aq_ptr, buf_ptr, 0, None)

    def _generate_samples(self, c_short_array, num_samples):
        dt = self.dt
        two_pi = 6.283185307179586
        car = self.car_id
        
        # Determine engine architecture parameters for Slow Car League
        if car == "keitruck":
            cylinders = 3.0
            firing_factor = 1.5 # 660cc 3-cyl: 1.5 fires per rev
        elif car == "smart":
            cylinders = 3.0
            firing_factor = 1.5 # 898cc 3-cyl Turbo
        elif car == "panda":
            cylinders = 4.0
            firing_factor = 2.0 # 999cc FIRE 4-cyl: 2.0 fires per rev
        elif car == "sidekick":
            cylinders = 4.0
            firing_factor = 2.0 # 1.6L 16V 4-cyl
        elif car == "wrangler":
            cylinders = 4.0
            firing_factor = 2.0 # 2.5L AMC 4-cyl
        elif car == "vwbus":
            cylinders = 4.0
            firing_factor = 2.0 # 1.6L Air-Cooled Flat-4 Boxer
        else:
            cylinders = 3.0
            firing_factor = 1.5

        target_throttle = 1.0 if self.is_accelerating else 0.0
        
        for i in range(num_samples):
            # Smooth RPM transitions
            self.current_rpm += (self.target_rpm - self.current_rpm) * 0.003
            # Smooth throttle envelope
            self.throttle_filter += (target_throttle - self.throttle_filter) * 0.005
            
            # Clutch shift cut: instantaneous volume dip
            target_shift_gain = 0.12 if self.is_shift_cut else 1.0
            self.shift_cut_gain += (target_shift_gain - self.shift_cut_gain) * 0.05
            
            sample_val = 0.0
            
            # Internal Combustion Engine: Exhaust Pulse Math
            # Fundamental pulse frequency: (RPM / 60) * (cylinders / 2)
            pulse_freq = (self.current_rpm / 60.0) * firing_factor
            self.phase_crank += two_pi * pulse_freq * dt
            if self.phase_crank > two_pi: self.phase_crank -= two_pi
            
            p = self.phase_crank / two_pi # normalized 0..1
                
            # Asymmetric exhaust expansion pulse
            pulse = (
                math.sin(self.phase_crank) * 0.50 +
                math.sin(2.0 * self.phase_crank) * 0.30 +
                math.sin(3.0 * self.phase_crank) * 0.18 +
                math.sin(4.0 * self.phase_crank) * 0.10
            )
            
            # Cylinder firing pressure pop
            pop_center = 0.22
            pop = math.exp(-((p - pop_center) ** 2) * 45.0) - 0.18
            
            # Specific acoustic personalities for each slow car
            if car == "keitruck":
                # 3-cylinder buzzsaw rasp: 1/3 order sub-harmonic + transmission gear whine
                sub = math.sin(self.phase_crank / 3.0) * 0.22
                raw_engine = (pulse * 0.44 + pop * 0.40 + sub * 0.16)
                if self.speed > 5:
                    gear_freq = self.speed * 8.8 + 80.0
                    self.phase_gear += two_pi * gear_freq * dt
                    if self.phase_gear > two_pi: self.phase_gear -= two_pi
                    gear_whine = math.sin(self.phase_gear) * (0.07 + 0.07 * self.throttle_filter)
                    raw_engine += gear_whine
            elif car == "smart":
                # Smart 3-cyl turbo commuter: higher frequency harmonics + turbo spool
                sub = math.sin(self.phase_crank / 3.0) * 0.18
                raw_engine = (pulse * 0.48 + pop * 0.38 + sub * 0.14)
                if self.throttle_filter > 0.1 and self.speed > 15:
                    turbo_freq = 900.0 + (self.current_rpm / 6500.0) * 1800.0
                    self.phase_turbo += two_pi * turbo_freq * dt
                    if self.phase_turbo > two_pi: self.phase_turbo -= two_pi
                    raw_engine += math.sin(self.phase_turbo) * (0.05 * self.throttle_filter)
            elif car == "panda":
                # Fiat Panda 999cc FIRE: raspy Italian 4-cylinder with mechanical valve chatter
                chatter = math.sin(self.phase_crank * 4.0) * 0.14
                raw_engine = (pulse * 0.48 + pop * 0.38 + chatter)
            elif car == "sidekick":
                # Suzuki Sidekick 1.6L 16V SOHC: throaty 90s Japanese 4x4 rumble
                mid_rumble = math.sin(self.phase_crank * 0.5) * 0.18
                raw_engine = (pulse * 0.46 + pop * 0.38 + mid_rumble)
            elif car == "wrangler":
                # Jeep Wrangler YJ 2.5L: heavy displacement 4-cylinder bass thrum & chug
                bass = math.sin(self.phase_crank * 0.5) * 0.25
                raw_engine = (pulse * 0.42 + pop * 0.35 + bass)
            elif car == "vwbus":
                # Volkswagen Type 2 Bus 1.6L Air-Cooled Flat-4 Boxer:
                # Uneven boxer exhaust resonance, valve tap, and tailpipe chirp whistle
                boxer_cadence = math.sin(self.phase_crank * 0.5) * 0.24 + math.sin(self.phase_crank * 1.5) * 0.12
                chirp_freq = 680.0 + (self.current_rpm / 4500.0) * 450.0
                self.phase_turbo += two_pi * chirp_freq * dt
                if self.phase_turbo > two_pi: self.phase_turbo -= two_pi
                chirp = math.sin(self.phase_turbo) * 0.06
                raw_engine = (pulse * 0.42 + pop * 0.36 + boxer_cadence + chirp)
            else:
                raw_engine = (pulse * 0.50 + pop * 0.50)
            
            # On-Throttle vs Off-Throttle Acoustics:
            if self.throttle_filter < 0.35:
                # Low-pass filter (cutoff ~420 Hz)
                alpha = 0.11 + 0.18 * self.throttle_filter
                self.lpf_state += alpha * (raw_engine - self.lpf_state)
                
                # Deceleration exhaust overrun burble / crackle
                self.burble_phase += dt * 18.0
                if self.burble_phase > 1.0:
                    self.burble_phase -= 1.0
                    self.burble_seed = (self.burble_seed * 1103515245 + 12345) & 0x7FFFFFFF
                burble = ((self.burble_seed % 100) / 100.0 - 0.5) * 0.14 * (1.0 - self.throttle_filter)
                
                gain = 0.32 + 0.18 * (self.current_rpm / 7500.0)
                sample_val = (self.lpf_state + burble) * gain * self.shift_cut_gain * 19000.0
            else:
                # Full on-throttle acoustic punch
                gain = 0.55 + 0.35 * self.throttle_filter
                sample_val = raw_engine * gain * self.shift_cut_gain * 19000.0
            
            # 16-bit integer clamp
            c_short_array[i] = max(-32767, min(32767, int(sample_val)))
