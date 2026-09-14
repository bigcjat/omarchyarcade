# Sky Ace Performance Optimization Plan (Linux / Omarchy Laptop)

## 1. Executive Summary & Problem Context
When running **Sky Ace** (`games/skyace`) on an Arch Linux laptop (Omarchy OS), the game suffers from severe frame drops, input latency, stuttering, and audio crackling ("running like shit").

### System Constraints & Rules
- **CRITICAL CONSTRAINT:** **NEVER touch `games/omarchybolo/`** (strictly off-limits).
- **Target OS:** Arch Linux (Omarchy OS) on laptop hardware (running battery/powersave frequency governors, integrated Intel/AMD GPU, Wayland compositor, and PipeWire audio).
- **Development Host:** macOS (which masks several Linux-specific bugs due to native CoreAudio/Metal backing).

---

## 2. Detailed Root Cause Analysis

### Bottleneck 1: Procedural Propeller Audio Engine (`games/skyace/engine/prop_audio.py`)
1. **Divergence Between macOS and Linux:**
   - On macOS, `AudioQueueNewOutput` in native C handles audio callbacks seamlessly.
   - On Linux, `_start_linux_fallback()` spawns a pure-Python background thread `stream_worker` writing raw PCM bytes to `aplay` or `pw-cat` via `subprocess.Popen(..., stdin=subprocess.PIPE)`.
2. **Tiny 4KB Pipe & PipeWire XRUNs (`fcntl.F_SETPIPE_SZ`):**
   - Lines 207–215 set `fcntl.fcntl(proc.stdin.fileno(), F_SETPIPE_SZ, 4096)`.
   - 4,096 bytes of 22,050 Hz 16-bit mono PCM equals **only ~92 milliseconds** of audio buffer.
   - Because `has_kernel_pipe_limit = True`, the code **completely disables the sleep drift regulator** (`if not has_kernel_pipe_limit:` is skipped).
   - PipeWire (`pipewire-alsa`) uses its own quantum buffer scheduling. Any 50ms stutter or garbage collection in the game thread empties the 92ms pipe instantly, causing constant **ALSA / PipeWire buffer underruns (XRUNs)**, audio crackling, and desynchronization.
3. **Severe CPython GIL Contention:**
   - In pure Python, `_generate_samples` calculates 22,050 samples per second. Every sample runs multiple `_fast_sin()` calls, phase accumulators, differential banking gains, and supercharger frequencies.
   - This generates over **180,000 Python function calls per second** in a background thread.
   - Because of the CPython Global Interpreter Lock (GIL), this tight audio synthesis thread constantly interrupts and starves the Qt GUI thread running at 60 FPS (16.6ms budget).

### Bottleneck 2: Pure Software `QPainter` Compositing (`games/skyace/main.py`)
1. **No Hardware Acceleration (`QWidget` vs `QOpenGLWidget`):**
   - `SkyAceGame` inherits from `QWidget`, not `QOpenGLWidget`.
   - On Linux (X11 / Wayland), `QWidget` uses Qt's pure CPU software raster engine (`QPaintEngine::Raster`).
2. **Excessive Per-Frame Compositing Operations in `paintEvent`:**
   - **Ocean Swell Line Allocations:** Lines 6831, 6862, and 6991 construct Python lists of `QLine` objects every single frame:
     ```python
     wave_lines = [QLine(0, y + self.ocean_y, self.width(), y + self.ocean_y) for y in range(-48, self.height() + 48, 24)]
     painter.drawLines(wave_lines)
     ```
     This triggers continuous Python memory allocation and GC passes.
   - **Transformed Cloud Puffs:** In Round 1 and Round 2, `self.clouds` draws up to 8 clouds, each doing `painter.save()`, `painter.setOpacity(0.18)` (shadow), `painter.translate()`, `painter.rotate()`, `painter.scale()`, and `painter.drawPixmap()`, followed by a second pass at `0.85` opacity. Because `SmoothPixmapTransform` is enabled, the CPU performs software bilinear scaling and rotation on large alpha surfaces every 16ms.
   - **Multi-Layer Scrolling Backgrounds:** Tiling `cloud_bed_pixmap` (3 screen-width blits) and terrain pixmaps.
   - **Particles:** Up to 50 active volumetric smoke/fire particles running software alpha blits.
   - On a laptop running on battery with clock speeds throttled to 1.2–2.0 GHz, software rasterization of 580×750 pixels across 5+ alpha layers takes >25ms per frame, dropping FPS to 20–30.

### Bottleneck 3: Sound Effect Subprocess Forking (`games/skyace/engine/audio_manager.py`)
1. **`QSoundEffect` Fragility on Linux:**
   - If QtMultimedia lacks GStreamer or PipeWire plugins on Linux, `self.effects` fails or is empty.
2. **Process Storm via `subprocess.Popen`:**
   - In `play(name)`, if `resolved not in self.effects`, it falls back to:
     ```python
     p = subprocess.Popen([self.player_cmd, str(wav_file)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
     ```
   - During combat, the player fires cannons every 5 ticks (12 shots/second), plus enemy shots, hits, and explosions.
   - Forking `aplay` or `pw-play` repeatedly from a 300MB Python process clones page tables and causes massive kernel context-switch spikes.

### Bottleneck 4: Rigid `Qt.PreciseTimer(16)`
- Running a 16ms timer with `Qt.PreciseTimer` on Linux means any frame that takes >16ms causes timer events to queue up, resulting in severe input latency, stuttering plane controls, and rubber-banding.

---

## 3. Step-by-Step Implementation Plan

### Step 1: Optimize Procedural Prop Audio (`games/skyace/engine/prop_audio.py`)
1. **Increase Pipe Buffer Cushion on Linux:**
   - Replace the 4KB pipe limit with a 64KB kernel buffer (or 32KB), giving ~1.5 seconds of cushion so PipeWire never suffers XRUN underruns during frame spikes.
2. **Vectorize Sample Generation with NumPy:**
   - `numpy` is already installed in the environment (`.venv`).
   - Replace the pure-Python `for i in range(num_samples):` loop with vectorized NumPy arrays:
     - Generate phase ramps using `np.linspace` or phase arrays.
     - Compute harmonics using `np.sin()` in vectorized C rather than pure-Python `_fast_sin()`.
     - This reduces CPU time from ~1.5–4.0ms per chunk down to <0.1ms per chunk, eliminating 95% of GIL contention.
3. **Add Clean Drift Regulation with Thread Yield/Sleep:**
   - Implement an explicit time-based regulator that computes lead time (`audio_time - elapsed_wall_clock`) and sleeps cleanly for 10–20ms chunks, releasing the GIL completely to the Qt GUI thread.
4. **Graceful Fallback / Toggle:**
   - Respect `SKYACE_NO_PROP_AUDIO=1` or low-power audio mode.

### Step 2: Optimize Rendering in `games/skyace/main.py`
1. **Pre-render Ocean Swells into a Cached Surface:**
   - Instead of allocating 30 `QLine` objects in a list comprehension every frame, pre-render a tileable 48px ocean wave pixmap once.
   - In `paintEvent`, simply blit the cached wave tile at `self.ocean_y`, saving CPU and garbage collection overhead.
2. **Optimize Cloud Puff Transformations:**
   - Pre-scale or pre-rotate cloud pixmaps, or skip the secondary shadow pass if running on battery/low-power mode.
   - Reduce redundant `painter.save()` / `painter.restore()` calls in cloud and particle loops.
3. **Cap Active Particles & Smoke Blits:**
   - Limit `self.smoke_particles` to a strict maximum (e.g. 24 active particles) and recycle particle dictionaries instead of continuous list allocations.
4. **Adaptive Frame Timing:**
   - Use `Qt.CoarseTimer` or dynamic frame budgeting so minor hitches don't cause timer event congestion.
5. **Hardware Acceleration Check:**
   - Provide an optional `QOpenGLWidget` viewport option with automatic fallback to `QWidget` when headless or when OpenGL context creation fails.

### Step 3: Harden Sound Effects (`games/skyace/engine/audio_manager.py`)
1. **Eliminate Subprocess Forking during Combat:**
   - Ensure missing alias mappings (like `"powerup"` -> `"pow_pickup"`) are resolved so they don't fall through to subprocess execution.
   - If `QSoundEffect` is unavailable, use a persistent background audio worker thread with a pre-opened audio sink rather than spawning `subprocess.Popen` per sound.

---

## 4. Verification & Testing Commands

### Verify on Local/Dev Environment:
```bash
# 1. Run Sky Ace benchmark frame test (grab/render time)
./.venv/bin/python -c "
import os, sys, time
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
sys.path.insert(0, 'games/skyace')
from PySide6.QtWidgets import QApplication
from main import SkyAceGame

app = QApplication.instance() or QApplication([])
game = SkyAceGame()
game.start_mission('p38', 'imperial', 1)
game.state = 'playing'

t0 = time.perf_counter()
for _ in range(120):
    game.game_loop()
    pix = game.grab()
t1 = time.perf_counter()
print(f'Avg frame time: {((t1-t0)/120)*1000:.2f} ms ({120/(t1-t0):.1f} FPS)')
"

# 2. Benchmark Prop Audio Generator
./.venv/bin/python -c "
import sys, time, ctypes
sys.path.insert(0, 'games/skyace')
from engine.prop_audio import ProceduralPropAudio
audio = ProceduralPropAudio()
buf = (ctypes.c_int16 * 1024)()
t0 = time.perf_counter()
for _ in range(100):
    audio._generate_samples(buf, 1024)
t1 = time.perf_counter()
print(f'Chunk gen time: {((t1-t0)/100)*1000:.2f} ms')
"

# 3. Test Game Launch
./.venv/bin/python games/skyace/main.py --play
```

### Verification on Omarchy Laptop:
```bash
# Test with prop audio enabled
./.venv/bin/python games/skyace/main.py

# Compare with engine audio disabled to verify zero-audio baseline
SKYACE_NO_PROP_AUDIO=1 ./.venv/bin/python games/skyace/main.py
```

---

## 5. Key Files to Modify
1. `games/skyace/engine/prop_audio.py`
2. `games/skyace/engine/audio_manager.py`
3. `games/skyace/main.py`
*(Remember: Never touch `games/omarchybolo/`)*
