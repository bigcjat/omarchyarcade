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

# AudioToolbox ctypes bindings for macOS low-latency streaming
try:
    if sys.platform == "darwin" and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
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
        if self.running or os.environ.get("QT_QPA_PLATFORM") == "offscreen":
            return
        self.running = True
        if _toolbox and self.aq_ptr:
            _toolbox.AudioQueueStart(self.aq_ptr, None)
        else:
            self._start_linux_fallback()

    def _start_linux_fallback(self):
        sr = str(int(self.sample_rate))
        candidates = []
        if shutil.which("aplay"):
            candidates.append(["aplay", "-q", "-r", sr, "-f", "S16_LE", "-c", "1", "-t", "raw", "-"])
        elif shutil.which("pw-cat"):
            candidates.append(["pw-cat", "-p", "--raw", f"--rate={sr}", "--format=s16", "--channels=1", "-"])
        elif shutil.which("pacat"):
            candidates.append(["pacat", "--playback", "--raw", f"--rate={sr}", "--format=s16le", "--channels=1"])

        if not candidates:
            return

        def stream_worker():
            chunk_samples = 1024
            c_short_array = (ctypes.c_int16 * chunk_samples)()
            silence = b"\x00" * (chunk_samples * 2)

            for cmd in candidates:
                try:
                    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    self._linux_proc = proc
                    while self.running and proc.poll() is None:
                        if self.is_muted:
                            proc.stdin.write(silence)
                        else:
                            self._generate_samples(c_short_array, chunk_samples)
                            proc.stdin.write(bytes(c_short_array))
                        proc.stdin.flush()
                    if not self.running:
                        try: proc.terminate()
                        except Exception: pass
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
                eng1 = (math.sin(self.phase_engine_left) + 
                        0.40 * math.sin(self.phase_engine_left * 2.0) + 
                        0.18 * math.sin(self.phase_engine_left * 3.0)) * self.left_engine_gain

                eng2 = (math.sin(self.phase_engine_right) + 
                        0.40 * math.sin(self.phase_engine_right * 2.0) + 
                        0.18 * math.sin(self.phase_engine_right * 3.0)) * self.right_engine_gain

                # Allison/Merlin supercharger boost whine
                blower = math.sin(self.phase_supercharger) * (0.04 + 0.05 * self.throttle_filter)
                bass_thrum = math.sin(self.phase_subharmonic) * 0.28
                raw = (eng1 + eng2) * 0.65 + blower + bass_thrum

            elif is_radial:
                # RADIAL ENGINES (A6M Zero & PZL P.11c):
                # Heavy low-frequency odd harmonics, galloping exhaust lope, deep husky thrum
                h1 = math.sin(self.phase_engine_left)
                h2 = math.sin(self.phase_engine_left * 2.0) * 0.32
                h3 = math.sin(self.phase_engine_left * 3.0) * 0.25
                h4 = math.sin(self.phase_engine_left * 4.0) * 0.12
                # Galloping radial cylinder lope
                lope = math.sin(self.phase_engine_left / 2.0) * 0.28
                bass_pulse = math.sin(self.phase_subharmonic) * 0.36
                raw = h1 + h2 + h3 + h4 + lope + bass_pulse

            else:
                # SINGLE V12 ENGINES (Spitfire Merlin, Bf 109 DB 605, Yak-3, Folgore, D.520, Avia):
                # Crisp metallic high-strung V12 bark + centrifugal supercharger whistle
                h1 = math.sin(self.phase_engine_left)
                h2 = math.sin(self.phase_engine_left * 2.0) * 0.44
                h3 = math.sin(self.phase_engine_left * 3.0) * 0.20
                h4 = math.sin(self.phase_engine_left * 4.0) * 0.08
                
                # Supercharger wail (loudest on Spitfire Merlin and Bf 109)
                supercharger_gain = 0.08 if plane in ("spitfire", "bf109") else 0.04
                blower = math.sin(self.phase_supercharger) * (supercharger_gain * self.throttle_filter)
                
                # Inverted V12 mechanical chatter on DB 605
                chatter = math.sin(self.phase_engine_left * 5.0) * 0.10 if plane == "bf109" else 0.0
                raw = h1 + h2 + h3 + h4 + blower + chatter

            # Aerodynamic Prop Wash Slipstream (adds realism at high RPM and banking)
            prop_wash = math.sin(self.phase_prop_wash) * (0.05 + 0.06 * (abs(self.bank_angle) / 30.0))
            raw += prop_wash

            # Landing Touchdown Sputter Effect (Mechanical engine drop & cylinder backpressure pops)
            if self.is_touchdown:
                self.sputter_timer += dt
                # Periodic cylinder misfires / sputter pops at low idle
                sputter_wave = math.sin(self.sputter_timer * 18.0) * math.sin(self.sputter_timer * 4.5)
                if sputter_wave > 0.7:
                    raw *= 0.35 # cylinder cut
                elif sputter_wave < -0.65:
                    raw += math.sin(self.phase_subharmonic * 2.0) * 0.25 # exhaust burble

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
