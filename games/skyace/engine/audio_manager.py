#!/usr/bin/env python3
"""
Sky Ace • Zero-Latency Native Audio Manager
Low-latency hardware audio playback via CoreAudio/AudioToolbox (macOS) and PipeWire/PulseAudio (Linux).
"""

import os
import sys
import shutil
import ctypes
import atexit
import subprocess
from pathlib import Path

class SoundManager:
    def __init__(self, sounds_dir):
        self.sounds_dir = Path(sounds_dir)
        self.sounds = {}
        self.is_mac = (sys.platform == "darwin")

        if self.is_mac:
            try:
                cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
                tb = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox")

                self.CFURLCreateWithFileSystemPath = cf.CFURLCreateWithFileSystemPath
                self.CFURLCreateWithFileSystemPath.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long, ctypes.c_bool]
                self.CFURLCreateWithFileSystemPath.restype = ctypes.c_void_p

                self.CFStringCreateWithCString = cf.CFStringCreateWithCString
                self.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
                self.CFStringCreateWithCString.restype = ctypes.c_void_p

                self.CFRelease = cf.CFRelease
                self.CFRelease.argtypes = [ctypes.c_void_p]

                self.AudioServicesCreateSystemSoundID = tb.AudioServicesCreateSystemSoundID
                self.AudioServicesCreateSystemSoundID.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
                self.AudioServicesCreateSystemSoundID.restype = ctypes.c_int32

                self.AudioServicesPlaySystemSound = tb.AudioServicesPlaySystemSound
                self.AudioServicesPlaySystemSound.argtypes = [ctypes.c_uint32]
                self.AudioServicesPlaySystemSound.restype = None

                for wav in self.sounds_dir.glob("*.wav"):
                    s_name = wav.stem
                    cf_path = self.CFStringCreateWithCString(None, str(wav.resolve()).encode("utf-8"), 0x08000100)
                    cf_url = self.CFURLCreateWithFileSystemPath(None, cf_path, 0, False)
                    sound_id = ctypes.c_uint32()
                    if self.AudioServicesCreateSystemSoundID(cf_url, ctypes.byref(sound_id)) == 0:
                        self.sounds[s_name] = sound_id.value
                    self.CFRelease(cf_path)
                    self.CFRelease(cf_url)
            except Exception as ex:
                print(f"[Audio] AudioToolbox initialization fallback: {ex}")
                self.is_mac = False

        if not self.is_mac:
            self.player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")

        # Volume controls (0.0 to 1.0)
        self.music_volume = 0.40
        self.battle_volume = 0.75

        # Hardware-accelerated low-latency sound effects
        self.effects = {}
        try:
            from PySide6.QtMultimedia import QSoundEffect
            from PySide6.QtCore import QUrl
            for wav in self.sounds_dir.glob("*.wav"):
                eff = QSoundEffect()
                eff.setSource(QUrl.fromLocalFile(str(wav.resolve())))
                eff.setVolume(self.battle_volume)
                self.effects[wav.stem] = eff
        except Exception:
            self.effects = {}

        # Comprehensive audio alias mapping so game triggers always resolve correctly
        self.aliases = {
            # Bullet impacts & armor damage
            "hit_sound": "damage_hit",
            "damage_hit": "damage_hit",
            "player_damage": "damage_hit",
            "enemy_hit": "damage_hit",
            "damage": "damage_hit",
            "hit": "damage_hit",
            
            # Explosions & destructions
            "enemy_explode": "explosion_small",
            "exp_small": "explosion_small",
            "explosion_small": "explosion_small",
            "exp_mid": "explosion_small",
            "exp_large": "explosion_large",
            "explosion_large": "explosion_large",
            "player_death": "explosion_large",
            "bomb_explode": "explosion_large",
            "boss_defeat": "explosion_large",
            
            # Weaponry
            "enemy_shoot": "shoot_cannon",
            "shoot_cannon": "shoot_cannon",
            "shoot_shotgun": "shoot_shotgun",
            "shoot_twin": "shoot_twin",
            "missile_launch": "missile_launch",
            "mega_crash": "mega_crash",
            
            # Airframe down / Death spiral
            "plane_falling": "plane_falling",
            "plane_down": "plane_falling",
            "death_spiral": "plane_falling",

            # Carrier Touchdown / Tire squeal
            "tire_squeal": "carrier_touchdown",
            "carrier_touchdown": "carrier_touchdown",
            "touchdown": "carrier_touchdown",
            "carrier_land": "carrier_touchdown",
            
            # Fanfare & Powerups
            "pow_pickup": "pow_pickup",
            "victory_fanfare": "victory_fanfare",
            "loop_whoosh": "loop_whoosh",
        }

        # In-process native Qt BGM player (no external daemon or subprocess leaks)
        self.current_bgm = None
        self.bgm_player = None
        self.bgm_audio = None
        try:
            from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
            self.bgm_player = QMediaPlayer()
            self.bgm_audio = QAudioOutput()
            self.bgm_player.setAudioOutput(self.bgm_audio)
            self.bgm_audio.setVolume(self.music_volume)
        except Exception:
            self.bgm_player = None
            self.bgm_audio = None

        atexit.register(self.shutdown)

    def set_music_volume(self, vol):
        """Dynamically adjusts BGM volume."""
        self.music_volume = max(0.0, min(1.0, float(vol)))
        if self.bgm_audio:
            try:
                self.bgm_audio.setVolume(self.music_volume)
            except Exception:
                pass
        if self.bgm_player:
            try:
                from PySide6.QtMultimedia import QMediaPlayer
                if self.music_volume <= 0.005:
                    self.bgm_player.pause()
                elif self.current_bgm and self.bgm_player.playbackState() != QMediaPlayer.PlaybackState.PlayingState:
                    self.bgm_player.play()
            except Exception:
                pass

    def set_battle_volume(self, vol):
        """Dynamically adjusts sound effects volume."""
        self.battle_volume = max(0.0, min(1.0, float(vol)))
        for eff in self.effects.values():
            try:
                eff.setVolume(self.battle_volume)
            except Exception:
                pass

    def play(self, name):
        """Plays sound effect by name with current battle volume."""
        if os.environ.get("QT_QPA_PLATFORM") == "offscreen":
            return
        if self.battle_volume <= 0.001:
            return

        resolved = self.aliases.get(name, name)

        if resolved in self.effects:
            eff = self.effects[resolved]
            eff.setVolume(self.battle_volume)
            eff.play()
            return
        if self.is_mac and resolved in self.sounds:
            self.AudioServicesPlaySystemSound(self.sounds[resolved])
        elif not self.is_mac and hasattr(self, 'player_cmd') and self.player_cmd:
            wav_file = self.sounds_dir / f"{resolved}.wav"
            if wav_file.exists():
                subprocess.Popen([self.player_cmd, str(wav_file)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def play_bgm(self, track_name, loop=True):
        """Plays background music loop seamlessly inside the Qt application process."""
        import os
        if os.environ.get("QT_QPA_PLATFORM") == "offscreen":
            return

        if self.current_bgm == track_name and self.bgm_player:
            try:
                from PySide6.QtMultimedia import QMediaPlayer
                if self.bgm_player.playbackState() == QMediaPlayer.PlaybackState.PlayingState:
                    return
            except Exception:
                pass

        track_path = None
        extensions = [".ogg", ".wav"]
        for ext in extensions:
            candidate = self.sounds_dir / f"{track_name}{ext}"
            if candidate.exists():
                track_path = candidate
                break

        if not track_path:
            return

        self.current_bgm = track_name

        if self.bgm_player and self.bgm_audio:
            try:
                from PySide6.QtCore import QUrl
                from PySide6.QtMultimedia import QMediaPlayer
                self.bgm_player.stop()
                self.bgm_audio.setVolume(self.music_volume)
                self.bgm_player.setSource(QUrl.fromLocalFile(str(track_path.resolve())))
                self.bgm_player.setLoops(QMediaPlayer.Infinite if loop else 1)
                if self.music_volume > 0.005:
                    self.bgm_player.play()
            except Exception as ex:
                print(f"[Audio] play_bgm error: {ex}")

    def stop_bgm(self):
        """Stops currently playing background music."""
        self.current_bgm = None
        if self.bgm_player:
            try:
                from PySide6.QtCore import QUrl
                self.bgm_player.stop()
                self.bgm_player.setSource(QUrl())
            except Exception:
                pass

    def shutdown(self):
        """Cleanly releases audio players and backend resources before process exit."""
        self.stop_bgm()
        if self.bgm_player:
            try:
                self.bgm_player.setAudioOutput(None)
                self.bgm_player.deleteLater()
            except Exception:
                pass
            self.bgm_player = None
        if self.bgm_audio:
            try:
                self.bgm_audio.deleteLater()
            except Exception:
                pass
            self.bgm_audio = None
        self.effects.clear()

