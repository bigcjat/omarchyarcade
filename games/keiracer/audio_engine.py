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
        sr = str(int(self.sample_rate))
        candidates = []
        # aplay: Rock-solid ALSA standard across all Linux distros; PipeWire-ALSA bridge handles it natively
        if shutil.which("aplay"):
            candidates.append(["aplay", "-q", "-r", sr, "-f", "S16_LE", "-c", "1", "-t", "raw", "-"])
        # pw-cat: PipeWire native (MUST specify --raw when reading headerless PCM from stdin)
        if shutil.which("pw-cat"):
            candidates.append(["pw-cat", "-p", "--raw", f"--rate={sr}", "--format=s16", "--channels=1", "-"])
        # pw-play: PipeWire playback alias (also requires --raw for stdin)
        if shutil.which("pw-play"):
            candidates.append(["pw-play", "--raw", f"--rate={sr}", "--format=s16", "--channels=1", "-"])
        # pacat: PulseAudio / PipeWire Pulse emulation for raw streaming
        if shutil.which("pacat"):
            candidates.append(["pacat", "--playback", "--raw", f"--rate={sr}", "--format=s16le", "--channels=1"])

        if not candidates:
            print("[AudioEngine] Note: No Linux audio sink (aplay/pw-cat/pw-play/pacat) found.")
            return

        def stream_worker():
            chunk_samples = 1024 # ~46ms low-latency buffer chunks
            c_short_array = (ctypes.c_int16 * chunk_samples)()
            silence = b"\x00" * (chunk_samples * 2)

            for cmd in candidates:
                print(f"[AudioEngine] Trying Linux audio sink: {' '.join(cmd)}")
                try:
                    proc = subprocess.Popen(
                        cmd,
                        stdin=subprocess.PIPE,
                        stderr=subprocess.PIPE
                    )
                    self._linux_proc = proc

                    # Use Linux kernel pipe buffer capacity (4096 bytes = ~92ms)
                    # When set, proc.stdin.write() blocks naturally in the kernel at hardware audio rate.
                    # This eliminates the need for Python time.sleep() oversleeping, preventing all XRUN pops/stutter!
                    has_kernel_pipe_limit = False
                    try:
                        import fcntl
                        f_setpipe_sz = getattr(fcntl, "F_SETPIPE_SZ", 1031)
                        fcntl.fcntl(proc.stdin.fileno(), f_setpipe_sz, 4096)
                        has_kernel_pipe_limit = True
                    except Exception:
                        has_kernel_pipe_limit = False

                    # Pre-buffer 2 chunks (~92ms) so the audio card always has a safety cushion
                    proc.stdin.write(silence)
                    proc.stdin.write(silence)
                    proc.stdin.flush()
                    time.sleep(0.03)

                    if proc.poll() is not None:
                        err = proc.stderr.read().decode("utf-8", errors="ignore").strip()
                        print(f"[AudioEngine] {cmd[0]} exited immediately (code {proc.poll()}): {err}")
                        continue

                    print(f"[AudioEngine] Successfully streaming audio via {cmd[0]} (kernel pipe flow control: {has_kernel_pipe_limit})")

                    stream_start = time.monotonic()
                    samples_written = chunk_samples * 2

                    while self.running and proc.poll() is None:
                        if self.is_muted:
                            proc.stdin.write(silence)
                            proc.stdin.flush()
                        else:
                            self._generate_samples(c_short_array, chunk_samples)
                            proc.stdin.write(bytes(c_short_array))
                            proc.stdin.flush()

                        samples_written += chunk_samples

                        # If kernel pipe size limit couldn't be set, use a cushioned drift regulator
                        # (Only sleeps if lead > 120ms, and preserves 80ms cushion, NEVER starving the buffer!)
                        if not has_kernel_pipe_limit:
                            audio_time = samples_written / self.sample_rate
                            lead = audio_time - (time.monotonic() - stream_start)
                            if lead > 0.12:
                                time.sleep(lead - 0.08)

                    if not self.running:
                        try:
                            proc.stdin.close()
                            proc.terminate()
                        except Exception:
                            pass
                        return
                    else:
                        print(f"[AudioEngine] {cmd[0]} closed (code {proc.poll()}), attempting next fallback...")
                except Exception as e:
                    print(f"[AudioEngine] Failed to initialize {cmd[0]}: {e}")
                    continue

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
        
        # Engine architecture parameters for Slow Car League
        if car in ("keitruck", "smart"):
            cylinders = 3.0
            firing_factor = 1.5 # 3-cyl: 1.5 firing pulses per crank rev
        else:
            cylinders = 4.0
            firing_factor = 2.0 # 4-cyl: 2.0 firing pulses per crank rev

        target_throttle = 1.0 if self.is_accelerating else 0.0
        
        for i in range(num_samples):
            # Smooth RPM transitions
            self.current_rpm += (self.target_rpm - self.current_rpm) * 0.004
            # Smooth throttle response
            self.throttle_filter += (target_throttle - self.throttle_filter) * 0.006
            
            # Clutch shift cut: soft volume dip
            target_shift_gain = 0.20 if self.is_shift_cut else 1.0
            self.shift_cut_gain += (target_shift_gain - self.shift_cut_gain) * 0.08
            
            # Internal Combustion Engine: Continuous harmonic series (zero step discontinuities)
            pulse_freq = (self.current_rpm / 60.0) * firing_factor
            self.phase_crank += two_pi * pulse_freq * dt
            if self.phase_crank >= two_pi:
                self.phase_crank -= two_pi
                
            # Secondary harmonic sub-phases
            self.phase_gear += two_pi * (pulse_freq * 0.5) * dt
            if self.phase_gear >= two_pi:
                self.phase_gear -= two_pi

            # Continuous harmonics (guaranteed C0-continuous, zero pops)
            h1 = math.sin(self.phase_crank)
            h2 = math.sin(self.phase_crank * 2.0) * 0.44
            h3 = math.sin(self.phase_crank * 3.0) * 0.22
            h4 = math.sin(self.phase_crank * 4.0) * 0.09
            
            # Acoustic personalities for Slow Car Racing League
            if car == "keitruck":
                # 660cc 3-cylinder buzzsaw: 1/3 order sub-harmonic + transmission gear whine
                sub = math.sin(self.phase_crank / 3.0) * 0.24
                raw = h1 + h2 + h3 + h4 + sub
                if self.speed > 8:
                    whine_freq = self.speed * 9.5 + 90.0
                    self.phase_turbo += two_pi * whine_freq * dt
                    if self.phase_turbo >= two_pi: self.phase_turbo -= two_pi
                    raw += math.sin(self.phase_turbo) * (0.06 + 0.06 * self.throttle_filter)
            elif car == "smart":
                # Smart 3-cyl turbo commuter: smooth cadence + turbo spool whistle
                raw = h1 * 0.9 + h2 * 0.5 + h3 * 0.16
                if self.throttle_filter > 0.1 and self.speed > 12:
                    turbo_freq = 950.0 + (self.current_rpm / 6500.0) * 1600.0
                    self.phase_turbo += two_pi * turbo_freq * dt
                    if self.phase_turbo >= two_pi: self.phase_turbo -= two_pi
                    raw += math.sin(self.phase_turbo) * (0.08 * self.throttle_filter)
            elif car == "panda":
                # Fiat Panda 999cc FIRE: lively Italian 4-cylinder mechanical valve chatter
                chatter = math.sin(self.phase_crank * 4.0) * 0.16
                raw = h1 + h2 + h3 + chatter
            elif car == "sidekick":
                # Suzuki Sidekick 1.6L 16V: throaty 90s Japanese 4x4 mid rumble
                rumble = math.sin(self.phase_gear) * 0.26
                raw = h1 + h2 + rumble
            elif car == "wrangler":
                # Jeep Wrangler YJ 2.5L: heavy displacement 4-cylinder bass chug
                bass = math.sin(self.phase_gear) * 0.36
                raw = h1 * 0.88 + h2 * 0.32 + bass
            elif car == "vwbus":
                # VW Type 2 Bus: air-cooled flat-4 boxer rhythm + exhaust tailpipe chirp
                boxer = math.sin(self.phase_gear) * 0.28 + math.sin(self.phase_crank * 1.5) * 0.14
                raw = h1 + h2 + boxer
            else:
                raw = h1 + h2 + h3

            # Soft asymmetric exhaust saturation (analog manifold compression)
            sat = raw / (1.0 + 0.35 * abs(raw))
            
            # Throttle-dependent warm acoustic filter:
            # Off-throttle = muffled bassy tone (~380 Hz)
            # On-throttle = open exhaust roar (~1400 Hz)
            filter_cutoff = 0.14 + 0.38 * self.throttle_filter
            self.lpf_state += filter_cutoff * (sat - self.lpf_state)
            
            # Smooth off-throttle exhaust gurgle (continuous low-frequency wave, NOT white noise pops)
            if self.throttle_filter < 0.25:
                gurgle = math.sin(self.phase_gear * 0.5) * 0.12 * (1.0 - self.throttle_filter * 4.0)
                acoustic = self.lpf_state + gurgle
            else:
                acoustic = self.lpf_state

            # Master gain staging
            gain = 0.38 + 0.34 * self.throttle_filter + 0.28 * (self.current_rpm / 7200.0)
            sample_val = acoustic * gain * self.shift_cut_gain * 24000.0
            
            # 16-bit integer clamp
            c_short_array[i] = max(-32767, min(32767, int(sample_val)))


if __name__ == "__main__":
    print("[AudioEngine] Starting standalone audio synthesizer test...")
    engine = ProceduralEngineAudio()
    engine.start()
    try:
        print("[AudioEngine] 1. Idling at 950 RPM (1.5s)...")
        engine.update_state("keitruck", 950, False, 0, False, False)
        time.sleep(1.5)

        print("[AudioEngine] 2. Full throttle rev to 6800 RPM (2.0s)...")
        engine.update_state("keitruck", 6800, True, 65, False, False)
        time.sleep(2.0)

        print("[AudioEngine] 3. Shift cut pop (0.3s)...")
        engine.update_state("keitruck", 5200, False, 65, True, False)
        time.sleep(0.3)

        print("[AudioEngine] 4. Off-throttle overrun burble (1.5s)...")
        engine.update_state("keitruck", 3200, False, 50, False, False)
        time.sleep(1.5)
    finally:
        print("[AudioEngine] Stopping engine audio.")
        engine.stop()
    print("[AudioEngine] Standalone test completed.")
