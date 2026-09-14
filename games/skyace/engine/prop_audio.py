#!/usr/bin/env python3
"""
Sky Ace • Procedural WW2 Warbird Engine Audio Synthesizer
Continuous real-time acoustic physics synthesis for 10 historical aircraft engines.
Supports native macOS AudioQueue and Linux streaming (pw-cat / pw-play / pacat / aplay).

Acoustic Features:
- Distinct radial (9-cyl & 14-cyl) vs single V12 vs twin V12 architectures
- Dual-propeller acoustic phase beating (Merlin / Allison twin harmonics)
- Differential engine throttling/silencing during banking maneuvers on twin-engine planes (P-38, Mosquito)
- Dynamic RPM transitions across Takeoff acceleration, In-Flight throttle modulation, and Landing touchdown sputter
- Low-profile master mixing so engine ambience sits comfortably below BGM and gunfire
"""

import sys
import os
import math
import ctypes
import shutil
import subprocess
import threading
import time
import random

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    np = None
    HAS_NUMPY = False

# AudioToolbox ctypes bindings for macOS low-latency streaming
try:
    if sys.platform == "darwin" and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        _toolbox = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox")
    else:
        _toolbox = None
except Exception:
    _toolbox = None

# High-resolution 4096-entry precomputed sine lookup table for zero-overhead harmonic synthesis
_LUT_SIZE = 4096
_LUT_SCALE = _LUT_SIZE / 6.283185307179586
_SIN_LUT = [math.sin(i * (6.283185307179586 / _LUT_SIZE)) for i in range(_LUT_SIZE)]

def _fast_sin(phase):
    return _SIN_LUT[int(phase * _LUT_SCALE) & (_LUT_SIZE - 1)]


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


class ProceduralPropAudio:
    """
    Real-time procedural prop aircraft engine synthesizer.
    Simulates cylinder exhaust expansion harmonics, supercharger blowers,
    twin-engine intermeshing phase beating, differential bank throttling, and carrier landing sputters.
    """
    def __init__(self, sample_rate=22050):
        self.sample_rate = float(sample_rate)
        self.dt = 1.0 / self.sample_rate
        
        # Flight & engine state
        self.plane_id = "p38"
        self.flight_state = "playing" # takeoff, playing, landing, hangar
        self.target_rpm = 2200.0
        self.current_rpm = 2200.0
        self.throttle_input = 0.0     # -1.0 (back) to +1.0 (forward)
        self.bank_angle = 0.0         # -30 to +30 degrees
        self.is_looping = False
        self.loop_tick = 0
        self.is_touchdown = False
        self.is_muted = False
        
        # Synthesis phases
        self.phase_engine_left = 0.0
        self.phase_engine_right = 0.0
        self.phase_supercharger = 0.0
        self.phase_subharmonic = 0.0
        self.phase_prop_wash = 0.0
        
        # Smoothing filters & envelopes
        self.throttle_filter = 0.0
        self.lpf_state = 0.0
        self.left_engine_gain = 1.0
        self.right_engine_gain = 1.0
        self.sputter_timer = 0.0
        self.sputter_factor = 1.0
        
        # Master volume headroom (Full acoustic range up to loud roaring warbird)
        self.master_volume = 1.0
        self.engine_volume_scale = 0.70
        
        self.running = False
        self.aq_ptr = ctypes.c_void_p()
        self._buffers = []
        self._callback_ref = None
        self._linux_proc = None
        self._stream_thread = None
        
        if _toolbox and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
            self._init_audio_queue()

    def set_volume(self, vol):
        """Sets the volume gain scale (0.0 to 1.0) for the engine synthesizer."""
        self.engine_volume_scale = max(0.0, min(1.0, float(vol)))

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
            return
            
        buf_size = 1024 * 2
        self._buffers = []
        for _ in range(3):
            buf = ctypes.POINTER(AudioQueueBuffer)()
            _toolbox.AudioQueueAllocateBuffer(self.aq_ptr, buf_size, ctypes.byref(buf))
            self._buffers.append(buf)
            self._fill_buffer(buf)

    def start(self):
        if self.running or os.environ.get("QT_QPA_PLATFORM") == "offscreen" or os.environ.get("SKYACE_NO_PROP_AUDIO") == "1":
            return
        self.running = True
        if _toolbox and self.aq_ptr:
            _toolbox.AudioQueueStart(self.aq_ptr, None)
        else:
            self._start_linux_fallback()

    def _start_linux_fallback(self):
        sr = str(int(self.sample_rate))
        candidates = []
        # Prioritize aplay (ALSA standard across Arch Linux/Omarchy with zero overhead bridge)
        if shutil.which("aplay"):
            candidates.append(["aplay", "-q", "-r", sr, "-f", "S16_LE", "-c", "1", "-t", "raw", "-"])
        if shutil.which("pw-cat"):
            candidates.append(["pw-cat", "-p", "--raw", f"--rate={sr}", "--format=s16le", "--channels=1", "-"])
        if shutil.which("pw-play"):
            candidates.append(["pw-play", "--raw", f"--rate={sr}", "--format=s16le", "--channels=1", "-"])
        if shutil.which("pacat"):
            candidates.append(["pacat", "--playback", "--raw", f"--rate={sr}", "--format=s16le", "--channels=1"])

        if not candidates:
            return

        def stream_worker():
            chunk_samples = 1024
            chunk_duration = chunk_samples / self.sample_rate
            c_short_array = (ctypes.c_int16 * chunk_samples)()
            silence = b"\x00" * (chunk_samples * 2)

            for cmd in candidates:
                try:
                    proc = subprocess.Popen(
                        cmd,
                        stdin=subprocess.PIPE,
                        stderr=subprocess.DEVNULL
                    )
                    self._linux_proc = proc

                    # Set Linux kernel pipe buffer capacity (65536 bytes = ~1.48s cushion against PipeWire XRUNs)
                    try:
                        import fcntl
                        f_setpipe_sz = getattr(fcntl, "F_SETPIPE_SZ", 1031)
                        fcntl.fcntl(proc.stdin.fileno(), f_setpipe_sz, 65536)
                    except Exception:
                        pass

                    # Pre-buffer 4 chunks (~185ms) so audio card has a safety cushion
                    for _ in range(4):
                        proc.stdin.write(silence)
                    proc.stdin.flush()
                    time.sleep(0.03)

                    if proc.poll() is not None:
                        continue

                    stream_start = time.monotonic()
                    samples_written = chunk_samples * 4

                    while self.running and proc.poll() is None:
                        if self.is_muted:
                            time.sleep(0.04)
                            continue

                        self._generate_samples(c_short_array, chunk_samples)
                        proc.stdin.write(bytes(c_short_array))
                        proc.stdin.flush()
                        samples_written += chunk_samples

                        # Drift regulator: compare audio synthesized time with wall clock time
                        # Yields GIL to Qt GUI thread while keeping audio pipeline smoothly supplied
                        audio_time = samples_written / self.sample_rate
                        elapsed = time.monotonic() - stream_start
                        lead = audio_time - elapsed
                        if lead > 0.08:
                            time.sleep(lead - 0.04)
                        elif lead > 0.02:
                            time.sleep(0.005)
                        else:
                            time.sleep(0.001)

                    if not self.running:
                        try:
                            proc.stdin.close()
                            proc.terminate()
                        except Exception:
                            pass
                        return
                except Exception:
                    continue

        self._stream_thread = threading.Thread(target=stream_worker, daemon=True)
        self._stream_thread.start()

    def stop(self):
        self.running = False
        if _toolbox and self.aq_ptr:
            try:
                _toolbox.AudioQueueStop(self.aq_ptr, True)
            except Exception:
                pass
        if self._linux_proc:
            try:
                self._linux_proc.terminate()
            except Exception:
                pass

    def update_flight_telemetry(self, plane_id, flight_state, throttle_input=0.0, bank_angle=0.0,
                               is_looping=False, loop_tick=0, takeoff_tick=0, landing_tick=0, is_muted=False):
        """
        Invoked from SkyAceGame at 60 FPS to continuously synchronize aerodynamic and acoustic states.
        """
        self.plane_id = str(plane_id).lower()
        self.flight_state = str(flight_state).lower()
        self.throttle_input = max(-1.0, min(1.0, float(throttle_input)))
        self.bank_angle = float(bank_angle)
        self.is_looping = bool(is_looping)
        self.loop_tick = int(loop_tick)
        self.is_muted = bool(is_muted)

        # 1. State-specific target RPM calculations
        if self.flight_state == "takeoff":
            # Deck idle -> full catapult takeoff power ramp (700 RPM up to 3200 RPM)
            if takeoff_tick < 90:
                prog = takeoff_tick / 90.0
                self.target_rpm = 750.0 + (prog ** 1.8) * 2450.0
            else:
                self.target_rpm = 3200.0
            self.is_touchdown = False

        elif self.flight_state == "landing":
            # Glideslope descent down to deck touchdown (1400 RPM down to 700 RPM with touchdown sputter)
            if landing_tick < 95:
                prog = landing_tick / 95.0
                self.target_rpm = 1600.0 - prog * 750.0
                self.is_touchdown = False
            else:
                # Carrier arrestor wire catch: throttle cut & cylinder sputter
                self.target_rpm = 680.0
                self.is_touchdown = True

        elif self.flight_state == "playing":
            self.is_touchdown = False
            if self.is_looping:
                # Surges on vertical climb, dips at top inverted apex (stage 3-4), surges on dive recovery
                stage = min(7, self.loop_tick // 5)
                rpm_curve = [2700, 3100, 2600, 1650, 1500, 2300, 2900, 2400]
                self.target_rpm = float(rpm_curve[stage])
            else:
                # Normal combat maneuvering:
                # Forward (Up key) = high RPM roar (~2900 RPM)
                # Reverse (Down key) = engine overrun drop (~1650 RPM)
                # Neutral cruise = ~2250 RPM
                if self.throttle_input > 0.1:
                    self.target_rpm = 2250.0 + self.throttle_input * 650.0
                elif self.throttle_input < -0.1:
                    self.target_rpm = 2250.0 + self.throttle_input * 600.0
                else:
                    self.target_rpm = 2250.0
        else:
            # Menu / Hangar: quiet background idle
            self.target_rpm = 700.0
            self.is_touchdown = False

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
        if HAS_NUMPY:
            self._generate_samples_numpy(c_short_array, num_samples)
        else:
            self._generate_samples_scalar(c_short_array, num_samples)

    def _generate_samples_numpy(self, c_short_array, num_samples):
        dt = self.dt
        two_pi = 6.283185307179586
        plane = self.plane_id
        is_twin = plane in ("p38", "mosquito")
        is_radial = plane in ("zero", "pzl11")

        if is_twin:
            firing_factor = 6.0
        elif plane == "pzl11":
            firing_factor = 4.5
        elif plane == "zero":
            firing_factor = 7.0
        else:
            firing_factor = 6.0

        target_throttle = max(0.0, (self.target_rpm - 1400.0) / 1600.0)

        if is_twin:
            if self.bank_angle < -6.0:
                dip = min(0.70, (abs(self.bank_angle) - 6.0) / 22.0)
                target_left_gain = 1.0 - dip
                target_right_gain = 1.0
            elif self.bank_angle > 6.0:
                dip = min(0.70, (self.bank_angle - 6.0) / 22.0)
                target_left_gain = 1.0
                target_right_gain = 1.0 - dip
            else:
                target_left_gain = 1.0
                target_right_gain = 1.0
        else:
            target_left_gain = 1.0
            target_right_gain = 1.0

        # Vectorized parameter transitions over the buffer duration
        decay_rpm = 1.0 - (1.0 - 0.0035) ** num_samples
        end_rpm = self.current_rpm + (self.target_rpm - self.current_rpm) * decay_rpm
        rpm_arr = np.linspace(self.current_rpm, end_rpm, num_samples, dtype=np.float32)
        self.current_rpm = float(end_rpm)

        decay_thr = 1.0 - (1.0 - 0.004) ** num_samples
        end_thr = self.throttle_filter + (target_throttle - self.throttle_filter) * decay_thr
        thr_arr = np.linspace(self.throttle_filter, end_thr, num_samples, dtype=np.float32)
        self.throttle_filter = float(end_thr)

        decay_gain = 1.0 - (1.0 - 0.006) ** num_samples
        end_left_gain = self.left_engine_gain + (target_left_gain - self.left_engine_gain) * decay_gain
        left_gain_arr = np.linspace(self.left_engine_gain, end_left_gain, num_samples, dtype=np.float32)
        self.left_engine_gain = float(end_left_gain)

        end_right_gain = self.right_engine_gain + (target_right_gain - self.right_engine_gain) * decay_gain
        right_gain_arr = np.linspace(self.right_engine_gain, end_right_gain, num_samples, dtype=np.float32)
        self.right_engine_gain = float(end_right_gain)

        # Pulse frequency & phase accumulators
        pulse_freq = (rpm_arr / 60.0) * firing_factor
        phase_inc_left = two_pi * pulse_freq * dt
        phases_left = (self.phase_engine_left + np.cumsum(phase_inc_left)) % two_pi
        self.phase_engine_left = float(phases_left[-1])

        detune = 1.006 if is_twin else 1.0
        phase_inc_right = two_pi * (pulse_freq * detune) * dt
        phases_right = (self.phase_engine_right + np.cumsum(phase_inc_right)) % two_pi
        self.phase_engine_right = float(phases_right[-1])

        phase_inc_sub = two_pi * (pulse_freq * 0.5) * dt
        phases_sub = (self.phase_subharmonic + np.cumsum(phase_inc_sub)) % two_pi
        self.phase_subharmonic = float(phases_sub[-1])

        blower_freq = 900.0 + (rpm_arr / 3200.0) * 1400.0
        phase_inc_super = two_pi * blower_freq * dt
        phases_super = (self.phase_supercharger + np.cumsum(phase_inc_super)) % two_pi
        self.phase_supercharger = float(phases_super[-1])

        prop_rev_freq = rpm_arr / 60.0
        phase_inc_prop = two_pi * (prop_rev_freq * 3.0) * dt
        phases_prop = (self.phase_prop_wash + np.cumsum(phase_inc_prop)) % two_pi
        self.phase_prop_wash = float(phases_prop[-1])

        # Acoustic modeling by engine layout
        if is_twin:
            eng1 = (np.sin(phases_left) + 0.40 * np.sin(phases_left * 2.0) + 0.18 * np.sin(phases_left * 3.0)) * left_gain_arr
            eng2 = (np.sin(phases_right) + 0.40 * np.sin(phases_right * 2.0) + 0.18 * np.sin(phases_right * 3.0)) * right_gain_arr
            blower = np.sin(phases_super) * (0.04 + 0.05 * thr_arr)
            bass_thrum = np.sin(phases_sub) * 0.28
            raw = (eng1 + eng2) * 0.65 + blower + bass_thrum
        elif is_radial:
            h1 = np.sin(phases_left)
            h2 = np.sin(phases_left * 2.0) * 0.32
            h3 = np.sin(phases_left * 3.0) * 0.25
            h4 = np.sin(phases_left * 4.0) * 0.12
            lope = np.sin(phases_left * 0.5) * 0.28
            bass_pulse = np.sin(phases_sub) * 0.36
            raw = h1 + h2 + h3 + h4 + lope + bass_pulse
        else:
            h1 = np.sin(phases_left)
            h2 = np.sin(phases_left * 2.0) * 0.44
            h3 = np.sin(phases_left * 3.0) * 0.20
            h4 = np.sin(phases_left * 4.0) * 0.08
            supercharger_gain = 0.08 if plane in ("spitfire", "bf109") else 0.04
            blower = np.sin(phases_super) * (supercharger_gain * thr_arr)
            chatter = np.sin(phases_left * 5.0) * 0.10 if plane == "bf109" else 0.0
            raw = h1 + h2 + h3 + h4 + blower + chatter

        prop_wash = np.sin(phases_prop) * (0.05 + 0.06 * (abs(self.bank_angle) / 30.0))
        raw += prop_wash

        if self.is_touchdown:
            sputter_times = self.sputter_timer + np.arange(1, num_samples + 1, dtype=np.float32) * dt
            self.sputter_timer = float(sputter_times[-1])
            sputter_wave = np.sin(sputter_times * 18.0) * np.sin(sputter_times * 4.5)
            cut_mask = sputter_wave > 0.7
            raw[cut_mask] *= 0.35
            burble_mask = sputter_wave < -0.65
            raw[burble_mask] += np.sin(phases_sub[burble_mask] * 2.0) * 0.25

        sat = raw / (1.0 + 0.30 * np.abs(raw))
        cutoff = float(0.12 + 0.35 * self.throttle_filter)

        acoustic = np.empty(num_samples, dtype=np.float32)
        lpf = self.lpf_state
        for i, val in enumerate(sat):
            lpf += cutoff * (val - lpf)
            acoustic[i] = lpf
        self.lpf_state = float(lpf)

        base_gain = (self.master_volume * self.engine_volume_scale) * (0.70 + 0.30 * (self.current_rpm / 3200.0))
        sample_val = acoustic * base_gain * 32000.0
        out_int16 = np.clip(sample_val, -32767, 32767).astype(np.int16)
        ctypes.memmove(ctypes.addressof(c_short_array), out_int16.ctypes.data, num_samples * 2)

    def _generate_samples_scalar(self, c_short_array, num_samples):
        dt = self.dt
        two_pi = 6.283185307179586
        plane = self.plane_id
        is_twin = plane in ("p38", "mosquito")
        is_radial = plane in ("zero", "pzl11")

        # Cylinder pulse factors (4-stroke engine: firing pulses per crank rev = cyl / 2)
        if is_twin:
            # Dual V12 engines: each engine has 6 pulses/rev
            firing_factor = 6.0
        elif plane == "pzl11":
            # 9-cylinder Bristol Mercury radial: 4.5 pulses/rev (distinctive gallop)
            firing_factor = 4.5
        elif plane == "zero":
            # 14-cylinder Nakajima Sakae radial: 7.0 pulses/rev
            firing_factor = 7.0
        else:
            # Standard single V12 (Merlin, DB605, Klimov, Hispano-Suiza): 6.0 pulses/rev
            firing_factor = 6.0

        # Target throttle mapping (0.0 = idle/overrun, 1.0 = full forward power)
        target_throttle = max(0.0, (self.target_rpm - 1400.0) / 1600.0)

        # Twin-Engine Differential Banking Throttling
        # Banking hard left quietens left engine; banking hard right quietens right engine!
        if is_twin:
            if self.bank_angle < -6.0:
                # Banking left: quieten port engine
                dip = min(0.70, (abs(self.bank_angle) - 6.0) / 22.0)
                target_left_gain = 1.0 - dip
                target_right_gain = 1.0
            elif self.bank_angle > 6.0:
                # Banking right: quieten starboard engine
                dip = min(0.70, (self.bank_angle - 6.0) / 22.0)
                target_left_gain = 1.0
                target_right_gain = 1.0 - dip
            else:
                target_left_gain = 1.0
                target_right_gain = 1.0
        else:
            target_left_gain = 1.0
            target_right_gain = 1.0

        for i in range(num_samples):
            # Smooth RPM and throttle response curves
            self.current_rpm += (self.target_rpm - self.current_rpm) * 0.0035
            self.throttle_filter += (target_throttle - self.throttle_filter) * 0.004
            
            # Smooth differential engine gains
            self.left_engine_gain += (target_left_gain - self.left_engine_gain) * 0.006
            self.right_engine_gain += (target_right_gain - self.right_engine_gain) * 0.006

            # Fundamental cylinder pulse frequency
            pulse_freq = (self.current_rpm / 60.0) * firing_factor

            # Engine 1 Phase (Port / Main)
            self.phase_engine_left += two_pi * pulse_freq * dt
            if self.phase_engine_left >= two_pi:
                self.phase_engine_left -= two_pi

            # Engine 2 Phase (Starboard - Twin engines have slight 0.6% acoustic detune creating warbird beat phasing)
            detune = 1.006 if is_twin else 1.0
            self.phase_engine_right += two_pi * (pulse_freq * detune) * dt
            if self.phase_engine_right >= two_pi:
                self.phase_engine_right -= two_pi

            # Sub-harmonic rumble & supercharger whistle phases
            self.phase_subharmonic += two_pi * (pulse_freq * 0.5) * dt
            if self.phase_subharmonic >= two_pi:
                self.phase_subharmonic -= two_pi

            blower_freq = 900.0 + (self.current_rpm / 3200.0) * 1400.0
            self.phase_supercharger += two_pi * blower_freq * dt
            if self.phase_supercharger >= two_pi:
                self.phase_supercharger -= two_pi

            # Aerodynamic prop blade wash
            prop_rev_freq = self.current_rpm / 60.0
            self.phase_prop_wash += two_pi * (prop_rev_freq * 3.0) * dt # 3-blade prop
            if self.phase_prop_wash >= two_pi:
                self.phase_prop_wash -= two_pi

            # -------------------------------------------------------------
            # Acoustic Modeling by Engine Layout
            # -------------------------------------------------------------
            if is_twin:
                # TWIN V12 (P-38 Lightning & Mosquito):
                # Sum of two independent engine waveforms with differential gain & intermeshing phase beating
                eng1 = (_fast_sin(self.phase_engine_left) + 
                        0.40 * _fast_sin(self.phase_engine_left * 2.0) + 
                        0.18 * _fast_sin(self.phase_engine_left * 3.0)) * self.left_engine_gain

                eng2 = (_fast_sin(self.phase_engine_right) + 
                        0.40 * _fast_sin(self.phase_engine_right * 2.0) + 
                        0.18 * _fast_sin(self.phase_engine_right * 3.0)) * self.right_engine_gain

                # Allison/Merlin supercharger boost whine
                blower = _fast_sin(self.phase_supercharger) * (0.04 + 0.05 * self.throttle_filter)
                bass_thrum = _fast_sin(self.phase_subharmonic) * 0.28
                raw = (eng1 + eng2) * 0.65 + blower + bass_thrum

            elif is_radial:
                # RADIAL ENGINES (A6M Zero & PZL P.11c):
                # Heavy low-frequency odd harmonics, galloping exhaust lope, deep husky thrum
                h1 = _fast_sin(self.phase_engine_left)
                h2 = _fast_sin(self.phase_engine_left * 2.0) * 0.32
                h3 = _fast_sin(self.phase_engine_left * 3.0) * 0.25
                h4 = _fast_sin(self.phase_engine_left * 4.0) * 0.12
                # Galloping radial cylinder lope
                lope = _fast_sin(self.phase_engine_left / 2.0) * 0.28
                bass_pulse = _fast_sin(self.phase_subharmonic) * 0.36
                raw = h1 + h2 + h3 + h4 + lope + bass_pulse

            else:
                # SINGLE V12 ENGINES (Spitfire Merlin, Bf 109 DB 605, Yak-3, Folgore, D.520, Avia):
                # Crisp metallic high-strung V12 bark + centrifugal supercharger whistle
                h1 = _fast_sin(self.phase_engine_left)
                h2 = _fast_sin(self.phase_engine_left * 2.0) * 0.44
                h3 = _fast_sin(self.phase_engine_left * 3.0) * 0.20
                h4 = _fast_sin(self.phase_engine_left * 4.0) * 0.08
                
                # Supercharger wail (loudest on Spitfire Merlin and Bf 109)
                supercharger_gain = 0.08 if plane in ("spitfire", "bf109") else 0.04
                blower = _fast_sin(self.phase_supercharger) * (supercharger_gain * self.throttle_filter)
                
                # Inverted V12 mechanical chatter on DB 605
                chatter = _fast_sin(self.phase_engine_left * 5.0) * 0.10 if plane == "bf109" else 0.0
                raw = h1 + h2 + h3 + h4 + blower + chatter

            # Aerodynamic Prop Wash Slipstream (adds realism at high RPM and banking)
            prop_wash = _fast_sin(self.phase_prop_wash) * (0.05 + 0.06 * (abs(self.bank_angle) / 30.0))
            raw += prop_wash

            # Landing Touchdown Sputter Effect (Mechanical engine drop & cylinder backpressure pops)
            if self.is_touchdown:
                self.sputter_timer += dt
                # Periodic cylinder misfires / sputter pops at low idle
                sputter_wave = _fast_sin(self.sputter_timer * 18.0) * _fast_sin(self.sputter_timer * 4.5)
                if sputter_wave > 0.7:
                    raw *= 0.35 # cylinder cut
                elif sputter_wave < -0.65:
                    raw += _fast_sin(self.phase_subharmonic * 2.0) * 0.25 # exhaust burble

            # Analog manifold soft-saturation (warm vacuum-tube style compression)
            sat = raw / (1.0 + 0.30 * abs(raw))

            # Dynamic Low-Pass Filter:
            # Idle/Off-throttle: Muffled warm low rumble (~340 Hz)
            # Full War Emergency Power: Wide open exhaust roar (~1600 Hz)
            cutoff = 0.12 + 0.35 * self.throttle_filter
            self.lpf_state += cutoff * (sat - self.lpf_state)
            acoustic = self.lpf_state

            # Master mix gain staging:
            # Full warbird acoustic range up to loud roaring engine
            base_gain = (self.master_volume * self.engine_volume_scale) * (0.70 + 0.30 * (self.current_rpm / 3200.0))
            sample_val = acoustic * base_gain * 32000.0
            
            # 16-bit PCM integer clamp
            c_short_array[i] = max(-32767, min(32767, int(sample_val)))


if __name__ == "__main__":
    print("[PropAudio] Testing Procedural WW2 Engine Synthesizer...")
    synth = ProceduralPropAudio()
    synth.start()
    try:
        print("1. P-38 Lightning Twin V12 Takeoff (Idle -> 3200 RPM)...")
        for t in range(0, 100, 10):
            synth.update_flight_telemetry("p38", "takeoff", takeoff_tick=t)
            time.sleep(0.15)

        print("2. P-38 Cruising Level (2250 RPM with dual-prop phase beat)...")
        synth.update_flight_telemetry("p38", "playing", throttle_input=0.0, bank_angle=0.0)
        time.sleep(1.5)

        print("3. P-38 Hard Left Bank (Port engine throttles down / quietens)...")
        synth.update_flight_telemetry("p38", "playing", throttle_input=0.0, bank_angle=-26.0)
        time.sleep(1.5)

        print("4. Spitfire Mk IX Merlin Roar (Full Forward Power)...")
        synth.update_flight_telemetry("spitfire", "playing", throttle_input=1.0, bank_angle=0.0)
        time.sleep(1.5)

        print("5. A6M Zero 14-Cylinder Radial Chug...")
        synth.update_flight_telemetry("zero", "playing", throttle_input=0.0, bank_angle=0.0)
        time.sleep(1.5)

        print("6. Carrier Landing & Touchdown Sputter...")
        synth.update_flight_telemetry("zero", "landing", landing_tick=110)
        time.sleep(1.5)
    finally:
        synth.stop()
    print("[PropAudio] Audio test finished cleanly.")
