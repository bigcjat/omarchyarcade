#!/usr/bin/env python3
"""
Sky Ace • 194X Arcade Homage
Featuring 6 Playable Nations and Free Global Matchup Theaters:
- 🇺🇸 USA: Lockheed P-38 Lightning (USS Enterprise)
- 🇯🇵 Japan: Mitsubishi A6M Zero (IJN Akagi)
- 🇬🇧 Britain: Supermarine Spitfire Mk.IX (HMS Ark Royal)
- 🇩🇪 Germany: Messerschmitt Bf 109G (KMS Graf Zeppelin)
- 🇷🇺 Soviet Union: Yakovlev Yak-3 (Krasny Luch Frontline Base)
- 🇨🇦 Canada: de Havilland Mosquito (HMCS Warrior)

Free Opposing Theaters & Super Fortress Bosses:
- 🇯🇵 Pacific (IJN Fleet & Ayako Super Heavy Fortress)
- 🇺🇸 Allied Pacific (USAAF & B-29 Goliath Super Fortress)
- 🇩🇪 Western Front / Channel (Luftwaffe Jets & BV 238 6-Engine Leviathan)
- 🇬🇧 Battle of Britain (RAF Squadrons & Avro Lancaster Boss)
- 🇷🇺 Eastern Front (VVS Red Star Formations & Pe-8 Heavy Fortress)
"""

import os
import sys
import math
import random
import json
import tomllib
from pathlib import Path
# Soft optional import for 3D engine developer mode
try:
    from PIL import Image
    import numpy as np
    HAS_3D_DEPS = True
except ImportError:
    HAS_3D_DEPS = False

from PySide6.QtWidgets import QApplication, QWidget
from PySide6.QtGui import QPainter, QPixmap, QImage, QColor, QFont, QPolygon, QRadialGradient, QLinearGradient, QPen, QBrush, QIcon
from PySide6.QtCore import QTimer, Qt, QRect, QPoint, QSettings

# Add engine directory to python path
current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir / "engine"))

from audio_manager import SoundManager
from prop_audio import ProceduralPropAudio

def find_omarchy_colors_file():
    env_path = os.environ.get("OMARCHY_THEME_FILE")
    if env_path and Path(env_path).is_file():
        return Path(env_path)

    home = Path.home()
    candidates = [
        home / ".local" / "state" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "current" / "theme" / "colors.toml",
        home / ".local" / "state" / "omarchy" / "theme" / "colors.toml",
        home / ".config" / "omarchy" / "colors.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def get_omarchy_theme():
    theme_path = find_omarchy_colors_file()
    if not theme_path:
        return None
    try:
        with open(theme_path, "rb") as f:
            data = tomllib.load(f)
        c = data.get("colors") if isinstance(data.get("colors"), dict) else data
        return {
            "background": c.get("background") or c.get("bg"),
            "foreground": c.get("foreground") or c.get("fg"),
            "accent": c.get("accent") or c.get("primary") or c.get("color4"),
            "muted": c.get("muted") or c.get("color8"),
        }
    except Exception:
        return None

def pil_to_qpixmap(pil_img):
    """Converts a PIL RGBA image to a PySide6 QPixmap if 3D developer dependencies are installed."""
    if not HAS_3D_DEPS or pil_img is None:
        return QPixmap()
    arr = np.array(pil_img.convert("RGBA"))
    h, w, ch = arr.shape
    bytes_per_line = ch * w
    qimg = QImage(arr.data, w, h, bytes_per_line, QImage.Format_RGBA8888)
    return QPixmap.fromImage(qimg)

def get_3d_engine_map():
    """Lazily loads 3D meshes and rasterizers when re-baking airframe frames."""
    if not HAS_3D_DEPS:
        return {}
    from p38_3d_engine import build_p38_mesh
    from render_3d_p38 import render_3d_frame
    from zero_3d_engine import build_zero_mesh
    from render_3d_zero import render_3d_zero_frame
    from spitfire_3d_engine import build_spitfire_mesh
    from render_3d_spitfire import render_3d_spitfire_frame
    from bf109_3d_engine import build_bf109_mesh
    from render_3d_bf109 import render_3d_bf109_frame
    from yak3_3d_engine import build_yak3_mesh
    from render_3d_yak3 import render_3d_yak3_frame
    from mosquito_3d_engine import build_mosquito_mesh
    from render_3d_mosquito import render_3d_mosquito_frame
    from folgore_3d_engine import build_folgore_mesh
    from render_3d_folgore import render_3d_folgore_frame
    from d520_3d_engine import build_d520_mesh
    from render_3d_d520 import render_3d_d520_frame
    from pzl11_3d_engine import build_pzl11_mesh
    from render_3d_pzl11 import render_3d_pzl11_frame
    from avia_3d_engine import build_avia_mesh
    from render_3d_avia import render_3d_avia_frame

    return {
        "p38": (build_p38_mesh(), render_3d_frame),
        "zero": (build_zero_mesh(), render_3d_zero_frame),
        "spitfire": (build_spitfire_mesh(), render_3d_spitfire_frame),
        "bf109": (build_bf109_mesh(), render_3d_bf109_frame),
        "yak3": (build_yak3_mesh(), render_3d_yak3_frame),
        "mosquito": (build_mosquito_mesh(), render_3d_mosquito_frame),
        "folgore": (build_folgore_mesh(), render_3d_folgore_frame),
        "d520": (build_d520_mesh(), render_3d_d520_frame),
        "pzl11": (build_pzl11_mesh(), render_3d_pzl11_frame),
        "avia": (build_avia_mesh(), render_3d_avia_frame),
    }

class SkyAceGame(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Sky Ace • 194X Global Air War")
        icon_path = current_dir / "assets" / "disk_icon.png"
        if icon_path.exists():
            self.setWindowIcon(QIcon(str(icon_path)))
        self.resize(580, 750)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setMouseTracking(True)

        self.settings = QSettings("Arcade", "SkyAce")
        self.sound = SoundManager(current_dir / "sounds")
        self.prop_audio = ProceduralPropAudio()
        self.prop_audio.start()

        # Audio Volume Channels (Music 50%, Battle Combat SFX 50%, Warbird Prop Engine 30%)
        self.music_volume = float(self.settings.value("music_volume", 0.50))
        self.battle_volume = float(self.settings.value("battle_volume", 0.50))
        self.engine_volume = float(self.settings.value("engine_volume", 0.30))
        self.sound.set_music_volume(self.music_volume)
        self.sound.set_battle_volume(self.battle_volume)
        self.prop_audio.set_volume(self.engine_volume)

        # Audio Console Overlay & Pause State
        self.audio_menu_open = False
        self.is_paused = False
        self.terrain_speed = 1.8
        self.audio_selected_channel = 0  # 0: Music, 1: Battle, 2: Engine
        self.audio_slider_dragging = None  # 0, 1, 2 or None
        self.mouse_cursor_pos = None
        self.matchup_badge_hovered = False
        self.omarchy_theme = get_omarchy_theme()

        # Game States: "hangar", "transition", "takeoff", "playing", "landing", "round_clear", "victory"
        self.state = "hangar"
        self.sound.play_bgm("bgm_hangar")
        self.hangar_step = 1  # 1: Select Player Plane, 2: Select Enemy Theater
        self.current_round = 1  # Round 1, Round 2, or Round 3
        self.rounds_per_country = 3
        self.transition_origin = "p38"
        self.transition_target = "imperial"
        self.transition_round = 1
        self.transition_t = 0.0
        self.world_map_pix = QPixmap(str(current_dir / "sprites" / "ww2_world_map.jpg"))

        self.geo_coords = {
            "p38": (0.23, 0.38, "USA", "🇺🇸"),
            "allied": (0.23, 0.38, "USA", "🇺🇸"),
            "zero": (0.82, 0.40, "Japan", "🇯🇵"),
            "imperial": (0.82, 0.40, "Japan", "🇯🇵"),
            "spitfire": (0.47, 0.30, "Britain", "🇬🇧"),
            "raf": (0.47, 0.30, "Britain", "🇬🇧"),
            "bf109": (0.50, 0.32, "Germany", "🇩🇪"),
            "luftwaffe": (0.50, 0.32, "Germany", "🇩🇪"),
            "yak3": (0.66, 0.27, "Soviet Union", "🇷🇺"),
            "vvs": (0.66, 0.27, "Soviet Union", "🇷🇺"),
            "mosquito": (0.24, 0.25, "Canada", "🇨🇦"),
            "canada": (0.24, 0.25, "Canada", "🇨🇦"),
            "folgore": (0.51, 0.38, "Italy", "🇮🇹"),
            "mediterranean": (0.51, 0.38, "Italy", "🇮🇹"),
            "d520": (0.48, 0.35, "France", "🇫🇷"),
            "france": (0.48, 0.35, "France", "🇫🇷"),
            "pzl11": (0.53, 0.31, "Poland", "🇵🇱"),
            "poland": (0.53, 0.31, "Poland", "🇵🇱"),
            "avia": (0.51, 0.33, "Czechoslovakia", "🇨🇿"),
            "czech": (0.51, 0.33, "Czechoslovakia", "🇨🇿"),
        }
        self.score = 0
        self.high_score = int(self.settings.value("highScore", 10000))
        self.bombs_remaining = 3
        self.loops_remaining = 3

        # Mission combat stats
        self.stats = {
            "scouts_killed": 0,
            "interceptors_killed": 0,
            "bombers_killed": 0,
            "boss_killed": False
        }

        # 3D Airframe Models (Lazy loaded for developer re-bakes)
        self.mesh_engines = None

        self.factions = [
            "p38", "zero", "spitfire", "bf109", "yak3", "mosquito",
            "folgore", "d520", "pzl11", "avia"
        ]
        self.secret_factions = ["ho229", "b29", "shinden", "xb35"]
        self.current_plane = "p38"
        self.enemy_theater = "imperial"
        self.is_mini_header = False
        self.show_help_modal = False
        self.paused_by_menu = False

        # National Metas (10 Playable Nations + 4 Secret Coalition Prototypes)
        self.nation_info = {
            "xb35": {
                "flag": "🇺🇸", "country": "UNITED STATES", "name": "XB-35 FLYING WING",
                "role": "Strategic Failsafe Nuclear Bomber", "base": "Muroc Army Air Field",
                "pilot": "COALITION FAILSAFE ACE", "speed": 8.0, "bank": 0.25, "default_rival": "allied"
            },
            "p38": {
                "flag": "🇺🇸", "country": "UNITED STATES", "name": "P-38 LIGHTNING",
                "role": "USAAF Twin-Boom Heavy", "base": "USS Enterprise (CV-6)",
                "pilot": "USAAF CAPTAIN", "speed": 6.0, "bank": 0.35, "default_rival": "imperial"
            },
            "zero": {
                "flag": "🇯🇵", "country": "EMPIRE OF JAPAN", "name": "A6M ZERO",
                "role": "IJN Dogfight Legend", "base": "IJN Akagi (Flagship)",
                "pilot": "IJN LIEUTENANT", "speed": 7.0, "bank": 0.45, "default_rival": "allied"
            },
            "spitfire": {
                "flag": "🇬🇧", "country": "GREAT BRITAIN", "name": "SPITFIRE Mk.IX",
                "role": "RAF Merlin Interceptor", "base": "HMS Ark Royal (R09)",
                "pilot": "RAF SQDN LEADER", "speed": 6.8, "bank": 0.42, "default_rival": "luftwaffe"
            },
            "bf109": {
                "flag": "🇩🇪", "country": "GERMANY", "name": "Bf 109G GUSTAV",
                "role": "Luftwaffe Hub-Gun Ace", "base": "KMS Graf Zeppelin",
                "pilot": "HAUPTMANN", "speed": 6.6, "bank": 0.40, "default_rival": "raf"
            },
            "yak3": {
                "flag": "🇷🇺", "country": "SOVIET UNION", "name": "YAKOVLEV YAK-3",
                "role": "VVS Guards Dogfighter", "base": "Krasny Luch Airbase",
                "pilot": "GUARDS CAPTAIN", "speed": 7.2, "bank": 0.48, "default_rival": "luftwaffe"
            },
            "mosquito": {
                "flag": "🇨🇦", "country": "CANADA (RCAF)", "name": "DH.98 MOSQUITO",
                "role": "RCAF Twin-Merlin Wood", "base": "HMCS Warrior (R31)",
                "pilot": "WING COMMANDER", "speed": 6.4, "bank": 0.36, "default_rival": "luftwaffe"
            },
            "folgore": {
                "flag": "🇮🇹", "country": "ITALY", "name": "MACCHI C.202",
                "role": "Regia Aeronautica Interceptor", "base": "Carrier Aquila",
                "pilot": "TENENTE", "speed": 6.8, "bank": 0.42, "default_rival": "mediterranean"
            },
            "d520": {
                "flag": "🇫🇷", "country": "FRANCE", "name": "DEWOITINE D.520",
                "role": "Armée de l'Air Canonier", "base": "Carrier Béarn",
                "pilot": "CAPITAINE", "speed": 6.6, "bank": 0.40, "default_rival": "france"
            },
            "pzl11": {
                "flag": "🇵🇱", "country": "POLAND", "name": "PZL P.11c",
                "role": "Gull-Wing Warsaw Defender", "base": "Warsaw Okęcie Airbase",
                "pilot": "PORUCZNIK", "speed": 6.2, "bank": 0.46, "default_rival": "poland"
            },
            "avia": {
                "flag": "🇨🇿", "country": "CZECHOSLOVAKIA", "name": "AVIA B.534",
                "role": "Aerodynamic Biplane Ace", "base": "Prague-Kbely Airbase",
                "pilot": "NADPORUČÍK", "speed": 6.4, "bank": 0.50, "default_rival": "czech"
            },
            "ho229": {
                "flag": "🇩🇪", "country": "GERMAN BLACK-PROJECT", "name": "HORTEN Ho 229",
                "role": "Twin-Jet Stealth Flying Wing", "base": "Sahara Forward Strip Alpha",
                "pilot": "COALITION ACE", "speed": 8.0, "bank": 0.50, "default_rival": "africa"
            },
            "b29": {
                "flag": "🇺🇸", "country": "USAAF BLACK-PROJECT", "name": "B-29 SUPERFORTRESS",
                "role": "Airborne Strategic Dreadnought", "base": "Sahara Forward Strip Bravo",
                "pilot": "COALITION CMDR", "speed": 5.8, "bank": 0.30, "default_rival": "africa"
            },
            "shinden": {
                "flag": "🇯🇵", "country": "IJN BLACK-PROJECT", "name": "J7W1 SHINDEN",
                "role": "Canard Rear-Pusher Interceptor", "base": "Sahara Forward Strip Charlie",
                "pilot": "COALITION STRIKER", "speed": 7.6, "bank": 0.52, "default_rival": "africa"
            }
        }

        # Theater Metas (10 Global Theaters)
        self.theaters = {
            "imperial": {
                "name": "PACIFIC OCEAN", "flag": "🇯🇵", "enemy_title": "IMPERIAL JAPANESE NAVY",
                "boss_name": "AYAKO", "boss_title": "IJN SUPER FORTRESS 'AYAKO'",
                "banner": "⚠ WARNING: IJN SUPER HEAVY FORTRESS 'AYAKO' DETECTED! ⚠",
                "water_color": (16, 44, 78), "water_line": (28, 64, 110),
                "turrets": [{"x": -124, "y": 10}, {"x": -76, "y": -5}, {"x": 76, "y": -5}, {"x": 124, "y": 10}, {"x": 0, "y": 25}]
            },
            "allied": {
                "name": "SOUTH PACIFIC", "flag": "🇺🇸", "enemy_title": "USAAF AIR FORCE COMMAND",
                "boss_name": "B24", "boss_title": "USAAF HEAVY FORTRESS 'B-24 LIBERATOR'",
                "banner": "⚠ WARNING: USAAF HEAVY FORTRESS 'B-24 LIBERATOR' DETECTED! ⚠",
                "water_color": (18, 48, 86), "water_line": (32, 70, 118),
                "turrets": [{"x": -120, "y": 8}, {"x": -72, "y": -6}, {"x": 72, "y": -6}, {"x": 120, "y": 8}, {"x": 0, "y": -20}]
            },
            "luftwaffe": {
                "name": "ENGLISH CHANNEL", "flag": "🇩🇪", "enemy_title": "LUFTWAFFE WESTERN FRONT",
                "boss_name": "BV238", "boss_title": "LUFTWAFFE 6-ENGINE LEVIATHAN 'BV 238'",
                "banner": "⚠ WARNING: LUFTWAFFE GIANT 6-ENGINE FLYING BOAT 'BV 238' DETECTED! ⚠",
                "water_color": (24, 46, 52), "water_line": (38, 70, 78),
                "turrets": [{"x": -140, "y": 15}, {"x": -80, "y": 0}, {"x": 80, "y": 0}, {"x": 140, "y": 15}, {"x": 0, "y": -30}]
            },
            "raf": {
                "name": "BATTLE OF BRITAIN", "flag": "🇬🇧", "enemy_title": "ROYAL AIR FORCE BOMBER COMMAND",
                "boss_name": "LANCASTER", "boss_title": "RAF SUPER BOMBER 'AVRO LANCASTER'",
                "banner": "⚠ WARNING: RAF HEAVY BOMBER 'AVRO LANCASTER' DETECTED! ⚠",
                "water_color": (22, 42, 58), "water_line": (36, 66, 88),
                "turrets": [{"x": -115, "y": 12}, {"x": -65, "y": -4}, {"x": 65, "y": -4}, {"x": 115, "y": 12}, {"x": 0, "y": 28}]
            },
            "vvs": {
                "name": "EASTERN FRONT", "flag": "🇷🇺", "enemy_title": "SOVIET RED AIR FORCE",
                "boss_name": "PE8", "boss_title": "VVS 4-ENGINE HEAVY FORTRESS 'Pe-8'",
                "banner": "⚠ WARNING: VVS RED STAR HEAVY FORTRESS 'Pe-8' DETECTED! ⚠",
                "water_color": (26, 40, 50), "water_line": (40, 62, 75),
                "turrets": [{"x": -120, "y": 10}, {"x": -70, "y": -5}, {"x": 70, "y": -5}, {"x": 120, "y": 10}, {"x": 0, "y": -25}]
            },
            "canada": {
                "name": "NORTH ATLANTIC", "flag": "🇨🇦", "enemy_title": "ROYAL CANADIAN AIR FORCE",
                "boss_name": "CANADAGOOSE", "boss_title": "RCAF SUPER BOMBER 'THE CANADA GOOSE'",
                "banner": "⚠ WARNING: RCAF HEAVY BOMBER 'THE CANADA GOOSE' DETECTED! ⚠",
                "water_color": (14, 38, 54), "water_line": (26, 58, 80),
                "turrets": [{"x": -115, "y": 10}, {"x": -65, "y": -4}, {"x": 65, "y": -4}, {"x": 115, "y": 10}, {"x": 0, "y": 28}]
            },
            "mediterranean": {
                "name": "MEDITERRANEAN SEA", "flag": "🇮🇹", "enemy_title": "REGIA AERONAUTICA COMMAND",
                "boss_name": "P108", "boss_title": "REGIA AERONAUTICA 4-ENG 'PIAGGIO P.108'",
                "banner": "⚠ WARNING: REGIA AERONAUTICA HEAVY FORTRESS 'PIAGGIO P.108' DETECTED! ⚠",
                "water_color": (16, 52, 90), "water_line": (28, 75, 130),
                "turrets": [{"x": -118, "y": 12}, {"x": -68, "y": -5}, {"x": 68, "y": -5}, {"x": 118, "y": 12}, {"x": 0, "y": 25}]
            },
            "france": {
                "name": "BATTLE OF FRANCE", "flag": "🇫🇷", "enemy_title": "ARMÉE DE L'AIR STRATEGIC WING",
                "boss_name": "F222", "boss_title": "FRENCH 4-ENG HEAVY 'FARMAN F.222'",
                "banner": "⚠ WARNING: FRENCH HEAVY BOMBER 'FARMAN F.222' DETECTED! ⚠",
                "water_color": (20, 46, 60), "water_line": (34, 68, 86),
                "turrets": [{"x": -125, "y": 14}, {"x": -65, "y": -5}, {"x": 65, "y": -5}, {"x": 125, "y": 14}, {"x": 0, "y": 28}]
            },
            "poland": {
                "name": "INVASION OF POLAND", "flag": "🇵🇱", "enemy_title": "POLISH AIR FORCE DEFENSE WING",
                "boss_name": "PZL37", "boss_title": "POLISH TWIN-ENGINE HEAVY 'PZL.37 ŁOŚ'",
                "banner": "⚠ WARNING: POLISH HEAVY BOMBER 'PZL.37 ŁOŚ' DETECTED! ⚠",
                "water_color": (22, 40, 52), "water_line": (36, 62, 78),
                "turrets": [{"x": -105, "y": 10}, {"x": -55, "y": -4}, {"x": 55, "y": -4}, {"x": 105, "y": 10}, {"x": 0, "y": 22}]
            },
            "czech": {
                "name": "CENTRAL EUROPE", "flag": "🇨🇿", "enemy_title": "CZECHOSLOVAK BORDER DEFENSE",
                "boss_name": "A300", "boss_title": "CZECH FAST BOMBER 'AERO A.300'",
                "banner": "⚠ WARNING: CZECHOSLOVAK BOMBER 'AERO A.300' DETECTED! ⚠",
                "water_color": (24, 42, 48), "water_line": (38, 64, 72),
                "turrets": [{"x": -100, "y": 10}, {"x": -50, "y": -4}, {"x": 50, "y": -4}, {"x": 100, "y": 10}, {"x": 0, "y": 22}]
            },
            "africa": {
                "name": "SAHARA CANYONLANDS", "flag": "⚔️", "enemy_title": "ROGUE SYNDICATE ARMADA",
                "boss_name": "BV238", "boss_title": "ROGUE SYNDICATE DREADNOUGHT",
                "banner": "⚠ WARNING: ROGUE ARMADA CANYON CITADEL & DREADNOUGHT DETECTED! ⚠",
                "water_color": (16, 48, 82), "water_line": (30, 75, 125),
                "turrets": [{"x": -130, "y": 10}, {"x": -70, "y": -5}, {"x": 70, "y": -5}, {"x": 130, "y": 10}, {"x": 0, "y": 20}]
            }
        }

        # Loop maneuver stages
        self.is_looping = False
        self.loop_tick = 0
        self.loop_stages = [
            (0.0, 35.0, 0.0), (0.0, 75.0, 0.0), (0.0, 130.0, 0.0), (0.0, 180.0, 0.0),
            (0.0, 230.0, 0.0), (0.0, 285.0, 0.0), (0.0, 330.0, 0.0), (0.0, 355.0, 0.0),
        ]

        # Player 3D Sprite cache (Standard + Secret Airframes)
        print("[Sky Ace] Building 3D player sprite cache for standard and secret airframes...")
        self.cache = {p: {} for p in self.factions + self.secret_factions}
        for plane_key in self.factions + self.secret_factions:
            self.build_cache_for_plane(plane_key)

        # Showcase demonstration for hangar inspection (Pre-rendered for all fighters)
        print("[Sky Ace] Pre-rendering 3D roll showcases for all fighters...")
        self.showcase_tick = 0
        self.showcase_frames = {}
        for p in self.factions:
            self.build_showcase_for_plane(p)

        # High-Res 2D Sprite Atlases
        print("[Sky Ace] Loading dedicated high-resolution sprite sheets...")
        self.fx_sprites = self.load_atlas("sheet_fx")
        self.pickup_sprites = self.load_atlas("sheet_pickups")
        self.escort_sprites = self.load_atlas("sheet_escort")

        # Enemy fleets for all theaters
        self.enemy_sprites = {
            "imperial": {
                "scout": self.load_atlas("sheet_enemy_zero"),
                "interceptor": self.load_atlas("sheet_enemy_red"),
                "bomber": self.load_atlas("sheet_enemy_bomber"),
                "boss": self.load_atlas("sheet_boss_ayako"),
            },
            "allied": {
                "scout": self.load_atlas("sheet_enemy_hellcat"),
                "interceptor": self.load_atlas("sheet_enemy_warhawk"),
                "bomber": self.load_atlas("sheet_enemy_b17"),
                "boss": self.load_atlas("sheet_boss_b24"),
            },
            "luftwaffe": {
                "scout": self.load_atlas("sheet_enemy_fw190"),
                "interceptor": self.load_atlas("sheet_enemy_me262"),
                "bomber": self.load_atlas("sheet_enemy_he111"),
                "boss": self.load_atlas("sheet_boss_bv238"),
            },
            "raf": {
                "scout": self.load_atlas("sheet_enemy_hurricane"),
                "interceptor": self.load_atlas("sheet_enemy_typhoon"),
                "bomber": self.load_atlas("sheet_enemy_stirling"),
                "boss": self.load_atlas("sheet_boss_lancaster"),
            },
            "vvs": {
                "scout": self.load_atlas("sheet_enemy_la7"),
                "interceptor": self.load_atlas("sheet_enemy_il2"),
                "bomber": self.load_atlas("sheet_enemy_pe2"),
                "boss": self.load_atlas("sheet_boss_pe8"),
            },
            "canada": {
                "scout": self.load_atlas("sheet_enemy_hurricane"),
                "interceptor": self.load_atlas("sheet_enemy_typhoon"),
                "bomber": self.load_atlas("sheet_enemy_stirling"),
                "boss": self.load_atlas("sheet_boss_canadagoose"),
            },
            "mediterranean": {
                "scout": self.load_atlas("sheet_enemy_zero"),
                "interceptor": self.load_atlas("sheet_enemy_fw190"),
                "bomber": self.load_atlas("sheet_enemy_he111"),
                "boss": self.load_atlas("sheet_boss_p108"),
            },
            "france": {
                "scout": self.load_atlas("sheet_enemy_hurricane"),
                "interceptor": self.load_atlas("sheet_enemy_typhoon"),
                "bomber": self.load_atlas("sheet_enemy_stirling"),
                "boss": self.load_atlas("sheet_boss_f222"),
            },
            "poland": {
                "scout": self.load_atlas("sheet_enemy_la7"),
                "interceptor": self.load_atlas("sheet_enemy_il2"),
                "bomber": self.load_atlas("sheet_enemy_pe2"),
                "boss": self.load_atlas("sheet_boss_pzl37"),
            },
            "czech": {
                "scout": self.load_atlas("sheet_enemy_la7"),
                "interceptor": self.load_atlas("sheet_enemy_pe2"),
                "bomber": self.load_atlas("sheet_enemy_stirling"),
                "boss": self.load_atlas("sheet_boss_a300"),
            },
            "africa": {
                "scout": self.load_atlas("sheet_enemy_fw190"),
                "interceptor": self.load_atlas("sheet_enemy_me262"),
                "bomber": self.load_atlas("sheet_enemy_bomber"),
                "boss": self.load_atlas("sheet_boss_bv238"),
            }
        }

        # Environmental scenery textures
        sprites_dir = current_dir / "sprites"
        self.cloud_pixmaps = [
            QPixmap(str(sprites_dir / f"cloud_cumulus_{i}.png"))
            for i in range(1, 7)
            if (sprites_dir / f"cloud_cumulus_{i}.png").exists()
        ]
        self.pacific_island_pixmaps = [
            QPixmap(str(sprites_dir / f"island_atoll_{i}.png"))
            for i in range(1, 6)
            if (sprites_dir / f"island_atoll_{i}.png").exists()
        ]
        self.arctic_island_pixmaps = [
            QPixmap(str(sprites_dir / f"island_arctic_{i}.png"))
            for i in range(1, 6)
            if (sprites_dir / f"island_arctic_{i}.png").exists()
        ]
        self.uk_island_pixmaps = [
            QPixmap(str(sprites_dir / f"island_uk_{i}.png"))
            for i in range(1, 6)
            if (sprites_dir / f"island_uk_{i}.png").exists()
        ]
        self.japan_island_pixmaps = [
            QPixmap(str(sprites_dir / f"island_japan_{i}.png"))
            for i in range(1, 6)
            if (sprites_dir / f"island_japan_{i}.png").exists()
        ]
        self.island_pixmaps = self.pacific_island_pixmaps
        carrier_deck_pix = QPixmap(str(sprites_dir / "carrier_p38.png"))
        self.carrier_pixmaps = {
            k: carrier_deck_pix for k in self.factions + self.secret_factions
        }

        # 3D Cel-Shaded Hostile Naval Warships & Rotating Turrets
        self.warship_sprites = {
            "gunboat": {
                "pristine": QPixmap(str(sprites_dir / "ship_gunboat_pristine.png")),
                "damaged": QPixmap(str(sprites_dir / "ship_gunboat_damaged.png")),
                "wreck": QPixmap(str(sprites_dir / "ship_gunboat_wreck.png")),
            },
            "destroyer": {
                "pristine": QPixmap(str(sprites_dir / "ship_destroyer_pristine.png")),
                "damaged": QPixmap(str(sprites_dir / "ship_destroyer_damaged.png")),
                "wreck": QPixmap(str(sprites_dir / "ship_destroyer_wreck.png")),
            },
            "cruiser": {
                "pristine": QPixmap(str(sprites_dir / "ship_cruiser_pristine.png")),
                "damaged": QPixmap(str(sprites_dir / "ship_cruiser_damaged.png")),
                "wreck": QPixmap(str(sprites_dir / "ship_cruiser_wreck.png")),
            }
        }
        self.turret_destroyer_sheet = QPixmap(str(sprites_dir / "turret_destroyer_sheet.png"))
        self.turret_heavy_sheet = QPixmap(str(sprites_dir / "turret_heavy_sheet.png"))
        self.warships = []
        self.warship_spawn_tick = 0

        # Round 1 & Round 3 Atmospheric Terrain Textures
        self.cloud_bed_pixmap = QPixmap(str(sprites_dir / "cloud_bed_floor.png"))
        self.mainland_terrain_pixmap = QPixmap(str(sprites_dir / "mainland_terrain_floor.png"))
        self.theater_terrains = {
            "imperial": QPixmap(str(sprites_dir / "terrain_imperial.png")),
            "allied": QPixmap(str(sprites_dir / "terrain_allied.png")),
            "luftwaffe": QPixmap(str(sprites_dir / "terrain_luftwaffe.png")),
            "raf": QPixmap(str(sprites_dir / "terrain_raf.png")),
            "vvs": QPixmap(str(sprites_dir / "terrain_vvs.png")),
            "canada": QPixmap(str(sprites_dir / "terrain_canada.png")),
            "mediterranean": QPixmap(str(sprites_dir / "terrain_mediterranean.png")),
            "france": QPixmap(str(sprites_dir / "terrain_france.png")),
            "poland": QPixmap(str(sprites_dir / "terrain_poland.png")),
            "czech": QPixmap(str(sprites_dir / "terrain_czech.png")),
            "africa": QPixmap(str(sprites_dir / "terrain_africa.png")),
        }

        # Shadow Commander portrait for Top Secret Briefing
        self.shadow_officer_pixmap = QPixmap(str(sprites_dir / "shadow_officer.png"))

        # 8 Unsung WWII Warbird Sprites for Tactical Air Support
        self.unsung_sprites = {}
        for uk in ["hurricane", "p39", "ki43", "hs129", "i16", "cr42", "ms406", "beaufighter"]:
            u_path = sprites_dir / f"sheet_unsung_{uk}.png"
            if u_path.exists():
                u_sheet = QPixmap(str(u_path))
                self.unsung_sprites[uk] = {
                    "level": u_sheet.copy(0, 0, 256, 256),
                    "left": u_sheet.copy(256, 0, 256, 256),
                    "right": u_sheet.copy(512, 0, 256, 256)
                }

        # 3D Cel-Shaded Ground Targets (Authentic WW2 Tanks, Fortifications, Base Depots)
        self.tank_sprites = {
            k: {
                "pristine": QPixmap(str(sprites_dir / f"{k}_pristine.png")),
                "damaged": QPixmap(str(sprites_dir / f"{k}_damaged.png")),
                "wreck": QPixmap(str(sprites_dir / f"{k}_wreck.png")),
            }
            for k in ["tank_sherman", "tank_tiger", "tank_chiha", "tank_t34", "tank_churchill"]
        }
        self.hangar_sprites = {
            "pristine": QPixmap(str(sprites_dir / "hangar_depot_pristine.png")),
            "damaged": QPixmap(str(sprites_dir / "hangar_depot_damaged.png")),
            "wreck": QPixmap(str(sprites_dir / "hangar_depot_wreck.png")),
        }
        self.ground_sprites = {}
        for k in ["pillbox_bunker", "flak_emplacement", "military_building", "military_tent"]:
            self.ground_sprites[k] = {
                "pristine": QPixmap(str(sprites_dir / f"{k}_pristine.png")),
                "damaged": QPixmap(str(sprites_dir / f"{k}_damaged.png")),
                "wreck": QPixmap(str(sprites_dir / f"{k}_wreck.png")),
            }
        self.cutscene_sprites = {
            "wreckage": QPixmap(str(sprites_dir / "cutscene_fighter_wreckage.png")),
            "photo_wreckage": QPixmap(str(sprites_dir / "cutscene_photo_wreckage.png")),
            "bomb": QPixmap(str(sprites_dir / "cutscene_nuke_bomb.png")),
            "crater": QPixmap(str(sprites_dir / "cutscene_scorched_crater.png")),
            "fireball": QPixmap(str(sprites_dir / "cutscene_fireball_blast.png")),
            "sat_hangar": QPixmap(str(sprites_dir / "cartel_hangar_base_clean.png")),
            "sat_scorched": QPixmap(str(sprites_dir / "cartel_hangar_nuked_clean.png")),
        }
        b_full_path = sprites_dir / "cutscene_bomb_full_sheet.png"
        if b_full_path.exists():
            b_sheet = QPixmap(str(b_full_path))
            fw = b_sheet.width() // 18
            fh = b_sheet.height()
            self.cutscene_sprites["bomb_anim_18"] = [b_sheet.copy(i * fw, 0, fw, fh) for i in range(18)]
        else:
            self.cutscene_sprites["bomb_anim_18"] = []
        self.cartel_hangar = None
        self.ground_targets = []
        self.ground_target_spawn_tick = 0
        self.world_scroll_y = 0.0

        self.NATION_TANK_MAP = {
            "allied": "tank_sherman",
            "imperial": "tank_chiha",
            "luftwaffe": "tank_tiger",
            "raf": "tank_churchill",
            "vvs": "tank_t34",
            "canada": "tank_churchill",
            "mediterranean": "tank_tiger",
            "france": "tank_sherman",
            "poland": "tank_t34",
            "czech": "tank_tiger",
        }

        # Scenery instances
        self.clouds = []
        self.islands = []
        self.init_scenery()

        # Flight State
        self.x = 290
        self.y = 560
        self.ocean_y = 0
        self.prop_tick = 0
        self.bank_angle = 0.0
        self.target_bank = 0.0
        self.takeoff_tick = 0
        self.landing_tick = 0
        self.carrier_y = -9999

        # Weapons
        self.weapons = ["twin", "quad", "shotgun", "threeway", "escorts", "missiles"]
        self.weapon_names = {
            "p38": {
                "twin": "TWIN .50 CAL NOSE GUNS",
                "quad": "QUAD 20MM NOSE CANNONS",
                "shotgun": "1943 FLAK SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY ANGLE CANNONS",
                "escorts": "TWIN P-38 ESCORTS (6-GUN WALL)",
                "missiles": "HOMING AIR ROCKETS"
            },
            "zero": {
                "twin": "TWIN 7.7MM COWL GUNS",
                "quad": "QUAD 20MM WING CANNONS",
                "shotgun": "TYPE 99 SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY ANGLE CANNONS",
                "escorts": "KI-43 OSCAR ESCORTS (6-GUN WALL)",
                "missiles": "TYPE 99 AIR ROCKETS"
            },
            "spitfire": {
                "twin": "TWIN .303 WING BROWNINGS",
                "quad": "QUAD 20MM HISPANO CANNONS",
                "shotgun": "MERLIN CONE BURST (BULLET CANCELER)",
                "threeway": "3-WAY DEFLECTION CONE",
                "escorts": "HURRICANE ESCORTS (6-GUN WALL)",
                "missiles": "RP-3 AIR-TO-GROUND ROCKETS"
            },
            "bf109": {
                "twin": "TWIN 13MM MG 131 COWL GUNS",
                "quad": "QUAD 20MM MG 151 GUN PODS",
                "shotgun": "MINENGESCHOSS SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY TRACER FAN",
                "escorts": "Fw 190 BUTCHER BIRDS (6-GUN WALL)",
                "missiles": "WERFER-GRANATE 21 HEAVY ROCKETS"
            },
            "yak3": {
                "twin": "NOSE 20MM ShVAK CANNON",
                "quad": "BERESIN UB & ShVAK DUAL CLUSTERS",
                "shotgun": "RED STAR FLAK BURST (BULLET CANCELER)",
                "threeway": "3-WAY GUARDS FAN",
                "escorts": "La-7 GUARDS ESCORTS (6-GUN WALL)",
                "missiles": "RS-82 GUARDS ROCKETS"
            },
            "mosquito": {
                "twin": "TWIN HISPANO 20MM BELLY CANNONS",
                "quad": "OCTUPLE 20MM & .303 FUSILLADE",
                "shotgun": "WOODEN WONDER SHOTGUN (BULLET CANCELER)",
                "threeway": "3-WAY HIGH-SPEED SWEEP",
                "escorts": "TWIN MOSQUITO ESCORTS (HEAVY BATTERY)",
                "missiles": "60LB HEAVY SAP ROCKETS"
            },
            "folgore": {
                "twin": "TWIN 12.7MM BREDA-SAFAT COWL GUNS",
                "quad": "QUAD 12.7MM & 20MM WING GONDOLAS",
                "shotgun": "FOLGORE CANISTER SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY MEDITERRANEAN FAN",
                "escorts": "MACCHI C.205 VELTRO ESCORTS",
                "missiles": "AEROSILURANTE GUIDED ROCKETS"
            },
            "d520": {
                "twin": "HUB 20MM HISPANO 404 CANNON",
                "quad": "QUAD 7.5MM MAC 1934 WING GUNS + 20MM",
                "shotgun": "TRICOLOR CANISTER CONE (BULLET CANCELER)",
                "threeway": "3-WAY ANGLE DEFLECTION",
                "escorts": "M.S.406 FIGHTER ESCORTS",
                "missiles": "BRANDT 68MM AERIAL ROCKETS"
            },
            "pzl11": {
                "twin": "TWIN 7.92MM PWU wz.36 COWL GUNS",
                "quad": "QUAD 7.92MM GULL-WING BATTERY",
                "shotgun": "WARSAW SHRAPNEL CANISTER (BULLET CANCELER)",
                "threeway": "3-WAY GULL-WING DEFLECTION CONE",
                "escorts": "PZL P.24 FIGHTER ESCORTS",
                "missiles": "POLISH HEAVY ROCKET PODS"
            },
            "avia": {
                "twin": "TWIN 7.92MM vz.30 COWL MACHINE GUNS",
                "quad": "QUAD SYNCHRONIZED NOSE BATTERY",
                "shotgun": "BIPLANE FLAK BURST (BULLET CANCELER)",
                "threeway": "3-WAY DUAL-WING FAN",
                "escorts": "AVIA B.135 MONOPLANE ESCORTS",
                "missiles": "AERO CZECH ROCKET PACKS"
            },
            "ho229": {
                "twin": "TWIN 30MM MK 108 JET CANNONS",
                "quad": "QUAD MK 108 HIGH-VELOCITY BATTERY",
                "shotgun": "JUMO JET-BLAST SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY SWEPT DELTA TRACER FAN",
                "escorts": "COALITION ESCORTS (B-29 & SHINDEN)",
                "missiles": "R4M ORKAN FOLDING-FIN JET ROCKETS"
            },
            "b29": {
                "twin": "TWIN .50 CAL REMOTE CHIN TURRET",
                "quad": "OCTUPLE DORSAL/VENTRAL COMPUTER TURRETS",
                "shotgun": "HEAVY FLAK WALL (BULLET CANCELER)",
                "threeway": "3-WAY 360° BARBETTE VOLLEY",
                "escorts": "COALITION ESCORTS (HO 229 & SHINDEN)",
                "missiles": "HEAVY CARPET BOMB CLUSTERS"
            },
            "shinden": {
                "twin": "TWIN 30MM TYPE 5 NOSE CANNONS",
                "quad": "QUAD 30MM HIGH-ALTITUDE BATTERY",
                "shotgun": "CANARD PULSE BURST (BULLET CANCELER)",
                "threeway": "3-WAY CANARD DEFLECTION ARC",
                "escorts": "COALITION ESCORTS (HO 229 & B-29)",
                "missiles": "TYPE 3 HIGH-SPEED ROCKET SALVO"
            }
        }
        self.weapon_idx = 0
        self.bullets = []
        self.missiles = []
        self.enemy_bullets = []
        self.enemies = []
        self.pickups = []
        self.explosions = []
        self.spark_particles = []
        self.muzzle_flashes = []

        # Tactical Air Support (10 Seconds of Glory)
        self.air_support_ready = False
        self.air_support_hero = "hurricane"
        self.air_support_active = False
        self.air_support_timer = 0
        self.air_support_obj = None
        self.air_support_dropped_this_round = False

        # Secret Coalition Mission ("Operation Blackout")
        self.is_secret_mission = False
        self.secret_wingmen = []
        self.failsafe_shockwaves = []
        self.failsafe_flash_ticks = 0
        self.briefing_scroll = 0
        self.pre_secret_plane = "p38"
        self.pre_secret_theater = "imperial"
        self.pre_secret_round = 1

        # Boss & Mission Progression
        self.boss = None
        self.boss_spawned = False
        self.mission_ticks = 0
        self.boss_target_ticks = 3600
        self.health_drops_spawned = [False, False, False]
        self.floating_texts = []

        # Health & Damage
        self.lives = 3
        self.max_lives = 3
        self.max_hp = 4
        self.hp = 4
        self.invulnerable_ticks = 0
        self.hit_flash_ticks = 0
        self.smoke_particles = []
        self.death_ticks = 0

        self.fire_cooldown = 0
        self.spawn_tick = 0
        self.is_fire_held = False
        self.mega_crash_ticks = 0
        self.screen_shake = 0

        self.banner_text = "WELCOME TO SKY ACE • SELECT YOUR COUNTRY & AIRCRAFT"
        self.banner_timer = 160

        self.flash_cache = {}
        self.keys = set()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.game_loop)
        self.timer.start(16)

    def get_flash_pixmap(self, pix, color=QColor(255, 255, 255, 240)):
        """Returns an exact-silhouette white/red flash sprite without bounding box artifacts."""
        cache_key = (id(pix), color.rgb())
        if cache_key in self.flash_cache:
            return self.flash_cache[cache_key]
        mask = pix.mask()
        flash_pix = QPixmap(pix.size())
        flash_pix.fill(color)
        flash_pix.setMask(mask)
        self.flash_cache[cache_key] = flash_pix
        return flash_pix

    def load_atlas(self, sheet_name):
        """Loads a spritesheet PNG and its accompanying JSON atlas into a dict of QPixmaps."""
        sheet_png = current_dir / "sprites" / f"{sheet_name}.png"
        sheet_json = current_dir / "sprites" / f"{sheet_name}.json"
        if not sheet_png.exists() or not sheet_json.exists():
            print(f"[Sky Ace] Warning: Missing atlas {sheet_name}")
            return {}
        try:
            with open(sheet_json, "r", encoding="utf-8") as f:
                data = json.load(f)
            pix = QPixmap(str(sheet_png))
            frames = {}
            raw_frames = data.get("frames", data)
            for frame_id, meta in raw_frames.items():
                if frame_id == "meta": continue
                fr = meta.get("frame", meta)
                if isinstance(fr, dict) and "x" in fr and "y" in fr and "w" in fr and "h" in fr:
                    frames[frame_id] = pix.copy(fr["x"], fr["y"], fr["w"], fr["h"])
            return frames
        except Exception as e:
            print(f"[Sky Ace] Error loading atlas {sheet_name}: {e}")
            return {}

    def spawn_cloud(self, y=None):
        """Creates an organic, randomized cloud with unique type, scale, speed, mirroring, and soft transparency."""
        if y is None:
            y = -random.randint(100, 300)
        w_bound = self.width() if hasattr(self, "width") and self.width() > 50 else 580
        return {
            "x": random.randint(20, w_bound - 20),
            "y": y,
            "speed": random.uniform(0.75, 1.65),
            "type": random.randint(0, len(self.cloud_pixmaps) - 1) if self.cloud_pixmaps else 0,
            "scale": random.uniform(0.75, 1.30),
            "flip_h": random.choice([True, False]),
            "rotation": random.uniform(-10.0, 10.0),
            "opacity": random.uniform(0.68, 0.85),
        }

    def init_scenery(self):
        """Initializes drifting cloud and island positions. Islands only spawn at combat altitude."""
        self.clouds = [
            self.spawn_cloud(y=y_pos)
            for y_pos in [50, 190, 340, 490, 640]
        ]
        self.islands = []
        self.island_spawn_timer = 0

    def build_cache_for_plane(self, plane):
        if plane in ("ho229", "b29", "shinden", "xb35"):
            sheet_path = current_dir / "sprites" / f"sheet_secret_{plane}.png"
            if sheet_path.exists():
                sheet = QPixmap(str(sheet_path))
                c_size = 256
                for col in range(4):
                    self.cache[plane][f"level_{col}"] = sheet.copy(col * c_size, 0, c_size, c_size)
                b_left_mild = sheet.copy(0 * c_size, 1 * c_size, c_size, c_size)
                b_left_hard = sheet.copy(1 * c_size, 1 * c_size, c_size, c_size)
                b_right_mild = sheet.copy(2 * c_size, 1 * c_size, c_size, c_size)
                b_right_hard = sheet.copy(3 * c_size, 1 * c_size, c_size, c_size)
                for p_idx in range(3):
                    self.cache[plane][f"bank_left_{p_idx}"] = b_left_mild
                    self.cache[plane][f"bank_hard_left_{p_idx}"] = b_left_hard
                    self.cache[plane][f"bank_right_{p_idx}"] = b_right_mild
                    self.cache[plane][f"bank_hard_right_{p_idx}"] = b_right_hard
                c_mild = sheet.copy(0 * c_size, 2 * c_size, c_size, c_size)
                c_steep = sheet.copy(1 * c_size, 2 * c_size, c_size, c_size)
                dive = sheet.copy(2 * c_size, 2 * c_size, c_size, c_size)
                loop_peak = sheet.copy(3 * c_size, 2 * c_size, c_size, c_size)
                for p_idx in range(3):
                    self.cache[plane][f"climb_mild_{p_idx}"] = c_mild
                    self.cache[plane][f"climb_steep_{p_idx}"] = c_steep
                for st_idx in range(len(self.loop_stages)):
                    for p_idx in range(3):
                        frame = loop_peak if st_idx in (3, 4) else (c_steep if st_idx in (1, 2) else (dive if st_idx in (5, 6) else self.cache[plane]["level_0"]))
                        self.cache[plane][f"loop_{st_idx}_{p_idx}"] = frame
                return

        # 1. Fast path: Load pre-rendered 3D frames from disk (Zero external dependencies)
        p_dir = current_dir / "sprites" / "rendered_3d" / plane
        if p_dir.exists():
            for png_path in p_dir.glob("*.png"):
                stem = png_path.stem
                if not stem.startswith("showcase_"):
                    self.cache[plane][stem] = QPixmap(str(png_path))
            if "level_0" in self.cache[plane]:
                return

        # 2. Developer fallback: If frames are missing and developer has 3D deps installed
        if not HAS_3D_DEPS:
            print(f"[Sky Ace] Notice: Pre-rendered frames for {plane} not found and 3D dependencies are disabled.")
            return

        if self.mesh_engines is None:
            self.mesh_engines = get_3d_engine_map()

        if plane not in self.mesh_engines:
            return

        mesh, render_fn = self.mesh_engines[plane]
        style = "tactical"

        for p_idx, p_ang in enumerate([0.0, 40.0, 80.0, 120.0]):
            img = render_fn(mesh, roll_deg=0.0, pitch_deg=0.0, prop_angle=p_ang, style=style)
            self.cache[plane][f"level_{p_idx}"] = pil_to_qpixmap(img)

        for roll in [-28, -14, 14, 28]:
            tag = "left" if roll < 0 else "right"
            hard = "hard_" if abs(roll) > 20 else ""
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                name = f"bank_{hard}{tag}_{p_idx}"
                img = render_fn(mesh, roll_deg=float(roll), pitch_deg=0.0, 
                                yaw_deg=float(roll)*0.2, prop_angle=p_ang, style=style)
                self.cache[plane][name] = pil_to_qpixmap(img)

        for st_idx, (r, p, y) in enumerate(self.loop_stages):
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=r, pitch_deg=p, yaw_deg=y, prop_angle=p_ang, style=style)
                self.cache[plane][f"loop_{st_idx}_{p_idx}"] = pil_to_qpixmap(img)

        for pitch, p_name in [(22.0, "climb_steep"), (12.0, "climb_mild")]:
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=0.0, pitch_deg=pitch, yaw_deg=0.0, prop_angle=p_ang, style=style)
                self.cache[plane][f"{p_name}_{p_idx}"] = pil_to_qpixmap(img)

    def build_showcase_for_plane(self, plane):
        """Pre-renders or loads plane in standard top-down view rolling 360 from top to under view and back."""
        if not hasattr(self, "showcase_frames"):
            self.showcase_frames = {}
        if plane in self.showcase_frames:
            return self.showcase_frames[plane]

        # 1. Fast path: Load from pre-rendered showcase PNGs (Zero external dependencies)
        p_dir = current_dir / "sprites" / "rendered_3d" / plane
        if p_dir.exists():
            frames = []
            for i in range(24):
                p_pix = self.cache.get(plane, {}).get(f"level_{(i // 3) % 4}")
                if p_pix:
                    frames.append(p_pix)
            roll_frames = []
            for i in range(24):
                s_path = p_dir / f"showcase_{i}.png"
                if s_path.exists():
                    roll_frames.append(QPixmap(str(s_path)))
            if len(roll_frames) == 24:
                frames.extend(roll_frames)
                self.showcase_frames[plane] = frames
                return frames

        # 2. Developer fallback
        if not HAS_3D_DEPS:
            return None

        if self.mesh_engines is None:
            self.mesh_engines = get_3d_engine_map()

        if plane not in self.mesh_engines:
            return None

        mesh, render_fn = self.mesh_engines[plane]
        style = "tactical"
        frames = []

        # 1. Level flight pause in standard top-down view
        for i in range(24):
            p_pix = self.cache.get(plane, {}).get(f"level_{(i // 3) % 4}")
            if p_pix:
                frames.append(p_pix)

        # 2. Smooth 360 roll
        for i in range(24):
            roll = (i / 24.0) * 360.0
            p_ang = (i * 35.0) % 360.0
            img = render_fn(mesh, roll_deg=roll, pitch_deg=0.0, yaw_deg=0.0, prop_angle=p_ang, style=style, size=256, scale=1.75)
            frames.append(pil_to_qpixmap(img))

        self.showcase_frames[plane] = frames
        return frames

    def start_transition(self, origin_key, target_theater_key, round_num=1):
        """Starts the Street Fighter World Map transition screen."""
        self.state = "transition"
        self.sound.play_bgm("bgm_warroom")
        self.transition_origin = origin_key
        self.transition_target = target_theater_key
        self.transition_round = round_num
        self.transition_t = 0.0
        self.sound.play("loop_whoosh")
        self.update()

    def start_mission(self, plane_key, theater_key=None, round_num=1):
        """Starts a new mission on the carrier flight deck or frontline airfield."""
        self.current_plane = plane_key
        if theater_key:
            self.enemy_theater = theater_key
        else:
            self.enemy_theater = self.nation_info[plane_key]["default_rival"]

        self.current_round = round_num
        self.state = "takeoff"
        self.sound.play_bgm("bgm_patrol")
        self.takeoff_tick = 0
        self.carrier_y = 140
        self.x = self.width() // 2
        self.y = 520
        if round_num == 1:
            self.lives = 3
        else:
            self.lives = max(1, getattr(self, "lives", 3))
        self.hp = self.max_hp
        self.death_ticks = 0
        self.landing_tick = 0
        self.is_looping = False
        self.loop_tick = 0
        self.invulnerable_ticks = 60
        self.hit_flash_ticks = 0
        self.bank_angle = 0.0
        self.keys.clear()
        self.is_fire_held = False
        self.weapon_idx = 0
        self.bombs_remaining = 3
        self.loops_remaining = 3
        self.mission_ticks = 0
        self.boss_target_ticks = 3600 if self.current_round == 1 else (3800 if self.current_round == 2 else 4000)
        self.boss_spawned = False
        self.boss = None
        self.health_drops_spawned = [False, False, False]
        self.floating_texts.clear()
        self.enemies.clear()
        self.enemy_bullets.clear()
        self.bullets.clear()
        self.missiles.clear()
        self.pickups.clear()
        self.warships.clear()
        self.warship_spawn_tick = 0
        self.ground_targets.clear()
        self.ground_target_spawn_tick = 0
        self.world_scroll_y = 0.0
        self.islands.clear()
        self.island_spawn_timer = 0
        self.smoke_particles.clear()
        self.explosions.clear()
        self.spark_particles.clear()
        self.failsafe_shockwaves.clear()
        self.failsafe_flash_ticks = 0
        self.air_support_ready = False
        self.air_support_active = False
        self.air_support_obj = None
        self.air_support_dropped_this_round = False
        if plane_key not in self.secret_factions:
            self.is_secret_mission = False
            self.secret_wingmen.clear()
            self.pre_secret_plane = plane_key
            self.pre_secret_theater = self.enemy_theater
            self.pre_secret_round = round_num
        self.stats = {
            "scouts_killed": 0,
            "interceptors_killed": 0,
            "bombers_killed": 0,
            "warships_sunk": 0,
            "ground_targets_destroyed": 0,
            "boss_killed": False,
            "shots_fired": 0,
            "bombs_dropped": 0,
            "loops_executed": 0,
            "flight_ticks": 0,
        }

        base_name = self.nation_info[self.current_plane]["base"]
        th_name = self.theaters[self.enemy_theater]["name"]
        round_titles = {
            1: "ROUND 1/3: STRATOSPHERE • HIGH SKY AIR COMBAT",
            2: "ROUND 2/3: COASTAL OCEAN • NAVAL FLEET INTERDICTION",
            3: "ROUND 3/3: ENEMY MAINLAND • AIR & GROUND TOTAL WAR"
        }
        st_title = round_titles.get(round_num, f"ROUND {round_num}/3")
        self.banner_text = f"★ {st_title} • SCRAMBLING FROM {base_name} INTO {th_name}! ★"
        self.banner_timer = 150

    def spawn_warship(self, ship_type, x, y, vy=1.2, hp=50):
        turrets = []
        if ship_type == "destroyer":
            turrets = [
                {"ox": 0, "oy": -95, "type": "destroyer", "cooldown": random.randint(25, 55), "frame_idx": 0},
                {"ox": 0, "oy": 105, "type": "destroyer", "cooldown": random.randint(45, 75), "frame_idx": 8},
            ]
        elif ship_type == "cruiser":
            turrets = [
                {"ox": 0, "oy": -145, "type": "heavy", "cooldown": random.randint(20, 50), "frame_idx": 0},
                {"ox": 0, "oy": -95, "type": "heavy", "cooldown": random.randint(40, 70), "frame_idx": 0},
                {"ox": 0, "oy": 130, "type": "heavy", "cooldown": random.randint(60, 90), "frame_idx": 8},
            ]
        elif ship_type == "gunboat":
            turrets = [
                {"ox": 0, "oy": -20, "type": "destroyer", "cooldown": random.randint(20, 40), "frame_idx": 0},
            ]

        self.warships.append({
            "type": ship_type,
            "x": float(x), "y": float(y),
            "vx": random.uniform(-0.15, 0.15), "vy": float(vy),
            "hp": hp, "max_hp": hp,
            "hit_flash": 0,
            "wake_tick": random.randint(0, 100),
            "sinking": False,
            "sink_tick": 0,
            "turrets": turrets,
        })

    def spawn_ground_target(self, target_type, x, y):
        """Spawns an authentic WW2 ground combat target in Round 3."""
        tank_model = self.NATION_TANK_MAP.get(self.enemy_theater, "tank_tiger")
        if target_type == "tank":
            self.ground_targets.append({
                "type": "tank",
                "model": tank_model,
                "x": float(x),
                "y": float(y),
                "vx": 0.0,
                "vy": self.terrain_speed + 0.35,
                "hp": 35,
                "max_hp": 35,
                "turret_angle": 180.0,
                "fire_timer": random.randint(35, 75),
                "hit_flash": 0,
                "wreck": False,
                "score": 600,
                "width": 58,
                "height": 105,
            })
        elif target_type == "pillbox":
            self.ground_targets.append({
                "type": "pillbox",
                "model": "pillbox_bunker",
                "x": float(x),
                "y": float(y),
                "vx": 0.0,
                "vy": self.terrain_speed,
                "hp": 45,
                "max_hp": 45,
                "fire_timer": random.randint(30, 65),
                "hit_flash": 0,
                "wreck": False,
                "score": 750,
                "width": 84,
                "height": 84,
            })
        elif target_type == "flak":
            self.ground_targets.append({
                "type": "flak",
                "model": "flak_emplacement",
                "x": float(x),
                "y": float(y),
                "vx": 0.0,
                "vy": self.terrain_speed,
                "hp": 55,
                "max_hp": 55,
                "fire_timer": random.randint(40, 80),
                "hit_flash": 0,
                "wreck": False,
                "score": 1000,
                "width": 96,
                "height": 96,
            })
        elif target_type == "building":
            self.ground_targets.append({
                "type": "building",
                "model": "military_building",
                "x": float(x),
                "y": float(y),
                "vx": 0.0,
                "vy": self.terrain_speed,
                "hp": 90,
                "max_hp": 90,
                "fire_timer": 9999,
                "hit_flash": 0,
                "wreck": False,
                "score": 2500,
                "width": 160,
                "height": 160,
            })
        elif target_type == "tent":
            self.ground_targets.append({
                "type": "tent",
                "model": "military_tent",
                "x": float(x),
                "y": float(y),
                "vx": 0.0,
                "vy": self.terrain_speed,
                "hp": 70,
                "max_hp": 70,
                "fire_timer": 9999,
                "hit_flash": 0,
                "wreck": False,
                "score": 2000,
                "width": 170,
                "height": 170,
            })

    def trigger_fire(self):
        if self.state != "playing" or self.is_looping or self.death_ticks > 0:
            return
        self.stats["shots_fired"] = self.stats.get("shots_fired", 0) + 1
        weapon = self.weapons[self.weapon_idx]
        nose_y = self.y - 52
        p_key = self.current_plane

        # Calculate primary gun offsets by aircraft geometry
        if self.is_secret_mission:
            # THE GENERAL EQUIPPED US WITH EVERY WEAPON!
            # Every weapon active simultaneously, and they never go away!
            self.sound.play("shoot_cannon")
            self.sound.play("shoot_shotgun")
            if (self.stats["shots_fired"] % 2) == 0:
                self.sound.play("missile_launch")

            if p_key == "ho229":
                p_quad = [-38, -14, 14, 38]
                wing_span = 44
            elif p_key == "b29":
                p_quad = [-64, -28, 28, 64]
                wing_span = 58
            elif p_key == "shinden":
                p_quad = [-20, -7, 7, 20]
                wing_span = 32
            else:
                p_quad = [-26, -8, 8, 26]
                wing_span = 30

            # 1. Forward Quad Heavy Cannons
            for ox in p_quad:
                self.bullets.append({"x": self.x + ox, "y": nose_y, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                self.muzzle_flashes.append({"x": self.x + ox, "y": nose_y, "life": 4})

            # 2. 3-Way Angled Flak Cannons
            self.bullets.append({"x": self.x, "y": nose_y, "vx": 0, "vy": -24, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x - 16, "y": nose_y, "vx": -11, "vy": -21, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x + 16, "y": nose_y, "vx": 11, "vy": -21, "type": "threeway", "dmg": 2})

            # 3. 5-Way Bullet-Canceling Spread (Shotgun Shield)
            angles = [(-10.0, -19.0), (-5.0, -21.0), (0.0, -23.0), (5.0, -21.0), (10.0, -19.0)]
            for vx, vy in angles:
                self.bullets.append({"x": self.x, "y": nose_y, "vx": vx, "vy": vy, "type": "shotgun", "dmg": 2, "cancels_bullets": True})

            # 4. Dual Tracking Homing Missiles / Rockets
            self.missiles.append({"x": self.x - wing_span, "y": self.y + 6, "vx": -3.5, "vy": -6.0, "speed": 9.0})
            self.missiles.append({"x": self.x + wing_span, "y": self.y + 6, "vx": 3.5, "vy": -6.0, "speed": 9.0})

            self.update()
            return

        if p_key == "p38":
            gun_offsets = [-7, 7]
            quad_offsets = [-20, -7, 7, 20]
        elif p_key == "zero":
            gun_offsets = [-4, 4]
            quad_offsets = [-26, -4, 4, 26]
        elif p_key == "spitfire":
            gun_offsets = [-18, 18]
            quad_offsets = [-28, -18, 18, 28]
        elif p_key == "bf109":
            gun_offsets = [0, -5, 5]
            quad_offsets = [-24, -5, 5, 24]
        elif p_key == "yak3":
            gun_offsets = [0, -4, 4]
            quad_offsets = [-16, -4, 4, 16]
        elif p_key == "mosquito":
            gun_offsets = [-6, 6]
            quad_offsets = [-22, -6, 6, 22]
        else:
            gun_offsets = [-6, 6]
            quad_offsets = [-20, -6, 6, 20]

        if weapon == "twin":
            self.sound.play("shoot_twin")
            for ox in gun_offsets:
                self.bullets.append({"x": self.x + ox, "y": nose_y, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                self.muzzle_flashes.append({"x": self.x + ox, "y": nose_y, "life": 3})

        elif weapon == "quad":
            self.sound.play("shoot_cannon")
            for ox in quad_offsets:
                is_outer = abs(ox) > 12
                vy = -25 if is_outer else -23
                self.bullets.append({"x": self.x + ox, "y": nose_y + (4 if is_outer else 0), "vx": 0, "vy": vy, "type": "quad", "dmg": 2})
                self.muzzle_flashes.append({"x": self.x + ox, "y": nose_y + (4 if is_outer else 0), "life": 4})

        elif weapon == "shotgun":
            self.sound.play("shoot_shotgun")
            angles = [(-9.0, -20.0), (-4.5, -21.5), (0.0, -23.0), (4.5, -21.5), (9.0, -20.0)]
            for vx, vy in angles:
                self.bullets.append({"x": self.x, "y": nose_y, "vx": vx, "vy": vy, "type": "shotgun", "dmg": 2, "cancels_bullets": True})
            self.muzzle_flashes.append({"x": self.x, "y": nose_y, "life": 5})

        elif weapon == "threeway":
            self.sound.play("shoot_cannon")
            self.bullets.append({"x": self.x, "y": nose_y, "vx": 0, "vy": -24, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x - 12, "y": nose_y, "vx": -11, "vy": -21, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x + 12, "y": nose_y, "vx": 11, "vy": -21, "type": "threeway", "dmg": 2})
            self.muzzle_flashes.append({"x": self.x, "y": nose_y, "life": 4})
            self.muzzle_flashes.append({"x": self.x - 12, "y": nose_y, "life": 4})
            self.muzzle_flashes.append({"x": self.x + 12, "y": nose_y, "life": 4})

        elif weapon == "escorts":
            self.sound.play("shoot_twin")
            for ox in gun_offsets:
                self.bullets.append({"x": self.x + ox, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
                self.muzzle_flashes.append({"x": self.x + ox, "y": nose_y, "life": 3})
            
            lx, ly = self.x - 56, self.y + 14
            self.bullets.append({"x": lx - 5, "y": ly - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": lx + 5, "y": ly - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": lx - 5, "y": ly - 20, "life": 3})
            self.muzzle_flashes.append({"x": lx + 5, "y": ly - 20, "life": 3})

            rx, ry = self.x + 56, self.y + 14
            self.bullets.append({"x": rx - 5, "y": ry - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": rx + 5, "y": ry - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": rx - 5, "y": ry - 20, "life": 3})
            self.muzzle_flashes.append({"x": rx + 5, "y": ry - 20, "life": 3})

        elif weapon == "missiles":
            self.sound.play("shoot_twin")
            self.sound.play("missile_launch")
            for ox in gun_offsets:
                self.bullets.append({"x": self.x + ox, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
                self.muzzle_flashes.append({"x": self.x + ox, "y": nose_y, "life": 3})

            wing_span = 30 if p_key in ("p38", "mosquito") else 26
            self.missiles.append({"x": self.x - wing_span, "y": self.y + 6, "vx": -3.0, "vy": -6.0, "speed": 8.0})
            self.missiles.append({"x": self.x + wing_span, "y": self.y + 6, "vx": 3.0, "vy": -6.0, "speed": 8.0})

        self.update()

    def trigger_loop(self):
        if not self.is_looping and self.state == "playing" and self.death_ticks == 0 and self.loops_remaining > 0:
            self.is_looping = True
            self.loop_tick = 0
            self.loops_remaining -= 1
            self.stats["loops_executed"] = self.stats.get("loops_executed", 0) + 1
            self.sound.play("loop_whoosh")
            self.banner_text = "★ EMERGENCY 360° LOOP ENGAGED! FULL INVULNERABILITY! ★"
            self.banner_timer = 60

    def trigger_mega_crash(self):
        if self.state == "playing" and self.death_ticks == 0 and self.bombs_remaining > 0:
            self.bombs_remaining -= 1
            self.stats["bombs_dropped"] = self.stats.get("bombs_dropped", 0) + 1
            self.mega_crash_ticks = 28
            self.screen_shake = 18
            self.sound.play("bomb_explode")
            self.enemy_bullets.clear()
            for e in self.enemies:
                if e.get("y", 0) < 40 or e.get("y", 0) > self.height() - 10:
                    continue
                e["hp"] -= 10
                e["hit_flash"] = 12
                self.explosions.append({
                    "x": e["x"] + random.randint(-15, 15),
                    "y": e["y"] + random.randint(-15, 15),
                    "radius": 24, "max_radius": 48, "life": 16
                })
            for w in self.warships:
                if not w.get("sinking") and 0 < w["y"] < self.height():
                    w["hp"] -= 35
                    w["hit_flash"] = 12
                    for _ in range(4):
                        self.explosions.append({
                            "x": w["x"] + random.randint(-30, 30),
                            "y": w["y"] + random.randint(-40, 40),
                            "radius": 24, "max_radius": 56, "life": 20
                        })
                    if w["hp"] <= 0 and not w.get("sinking"):
                        w["sinking"] = True
                        w["sink_tick"] = 0
                        self.stats["warships_sunk"] = self.stats.get("warships_sunk", 0) + 1
                        pts = 400 if w["type"] == "gunboat" else (1200 if w["type"] == "destroyer" else 3000)
                        self.score += pts
            for g in self.ground_targets:
                if not g.get("wreck") and 0 < g["y"] < self.height():
                    g["hp"] -= 35
                    g["hit_flash"] = 12
                    for _ in range(3):
                        self.explosions.append({
                            "x": g["x"] + random.randint(-20, 20),
                            "y": g["y"] + random.randint(-20, 20),
                            "radius": 22, "max_radius": 50, "life": 18
                        })
                    if g["hp"] <= 0 and not g.get("wreck"):
                        g["wreck"] = True
                        self.stats["ground_targets_destroyed"] = self.stats.get("ground_targets_destroyed", 0) + 1
                        self.score += g["score"]
                        if g["type"] in ("building", "tent"):
                            p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                            self.pickups.append({"x": g["x"], "y": g["y"], "vy": 2.0, "type": p_choice})
            # Bomb damage to boss (Only when fully revealed on station!)
            if self.boss and self.boss["active"] and self.boss.get("vulnerable", False):
                self.boss["hp"] = max(0, self.boss["hp"] - 45)
                for _ in range(6):
                    self.explosions.append({
                        "x": self.boss["x"] + random.randint(-120, 120),
                        "y": self.boss["y"] + random.randint(-40, 40),
                        "radius": 28, "max_radius": 56, "life": 20
                    })
                if self.boss["hp"] <= 0:
                    self.defeat_boss()

            # Bomb damage to Cartel Underground Hangar Complex
            if self.cartel_hangar and self.cartel_hangar.get("active") and not self.cartel_hangar.get("exploding"):
                self.cartel_hangar["hp"] = max(0, self.cartel_hangar["hp"] - 120)
                self.cartel_hangar["hit_flash"] = 12
                for _ in range(8):
                    self.explosions.append({
                        "x": self.cartel_hangar["x"] + random.randint(-160, 160),
                        "y": self.cartel_hangar["y"] + random.randint(-140, 140),
                        "radius": 32, "max_radius": 70, "life": 24
                    })
                if self.cartel_hangar["hp"] <= 0:
                    self.defeat_hangar()

            self.banner_text = "★ 1943 MEGA CRASH DETONATED! AIRSPACE CLEARED! ★"
            self.banner_timer = 90

    def start_secret_mission(self, chosen_plane):
        """Launches Operation Blackout: 2-Minute High-Intensity Coalition Strike in Africa."""
        self.is_secret_mission = True
        self.start_mission(chosen_plane, theater_key="africa", round_num=3)
        self.is_secret_mission = True
        self.sound.play_bgm("bgm_boss")
        
        # ONE LIFE ONLY - PER USER COMMAND
        self.lives = 1
        
        # Prototype Armor & Hit Points
        if chosen_plane == "b29":
            self.max_hp = 6
            self.hp = 6
        else:
            self.max_hp = 5
            self.hp = 5

        # FULL ORDNANCE ARMED FROM THE START
        self.bombs_remaining = 5
        self.loops_remaining = 5
        self.air_support_ready = True
        self.air_support_hero = random.choice(["hurricane", "p39", "ki43", "hs129", "i16", "cr42", "ms406", "beaufighter"])
        
        # MISSION DURATION: AT LEAST 2 MINUTES (120 seconds = 7,200 ticks at 60 FPS)
        self.boss_target_ticks = 7200

        # HEALTH AIR-DROPS: EXACTLY 1 REPAIR KIT EVERY 20 SECONDS (1200 TICKS)
        # (Zero random health drops from regular enemy kills!)
        self.secret_next_health_tick = 1200

        # FINAL OBJECTIVE AT 2 MINUTES: UNDERGROUND HANGAR DEPOT COMPLEX
        self.cartel_hangar = None

        # 4 BOSS FLEETS EVENLY SPACED ACROSS THE 2 MINUTES:
        # ~24s: AYAKO | ~48s: B24 | ~72s: BV238 | ~96s: PE8
        self.secret_boss_schedule = [
            (1440, "AYAKO"),
            (2880, "B24"),
            (4320, "BV238"),
            (5760, "PE8")
        ]
        self.secret_boss_index = 0
        self.secret_bosses_defeated = 0
        self.boss = None
        self.boss_spawned = False

        # SQUADRONS OF EVERY PLANE IN THE GAME (10 National Planes + 8 Unsung Warbirds)
        # Scheduled every ~370 ticks (~6.2s) across the 2-minute sortie
        self.secret_squadron_plan = [
            (240,  "zero",        "IJN A6M ZERO ESCORT SQUADRON"),
            (620,  "spitfire",    "RAF SUPERMARINE SPITFIRE PATROL"),
            (1000, "bf109",       "LUFTWAFFE BF-109 HUNTING SWARM"),
            (1380, "ki43",        "IJA NAKAJIMA KI-43 HAYABUSA WEDGE"),
            (1780, "p38",         "USAAF P-38 LIGHTNING INTERCEPTORS"),
            (2160, "folgore",     "REGIA AERONAUTICA FOLGORE SQUADRON"),
            (2540, "yak3",        "VVS YAK-3 RED STAR GUARDS"),
            (2920, "p39",         "USAAF P-39 AIRACOBRA FLIGHT"),
            (3300, "mosquito",    "RCAF MOSQUITO STRIKE DIVISION"),
            (3680, "d520",        "FRENCH DEWOITINE D.520 FIGHTERS"),
            (4060, "hs129",       "LUFTWAFFE HS-129 TANK BUSTER FLIGHT"),
            (4440, "cr42",        "ITALIAN FIAT CR.42 FALCO FIGHTERS"),
            (4820, "pzl11",       "POLISH PZL P.11 WHITE EAGLES"),
            (5200, "avia",        "CZECHOSLOVAK AVIA B-534 WING"),
            (5580, "hurricane",   "ROYAL AIR FORCE HAWKER HURRICANES"),
            (5960, "i16",         "SOVIET POLIKARPOV I-16 ISHAK SQUAD"),
            (6340, "ms406",       "FRENCH MORANE-SAULNIER M.S.406 PATROL"),
            (6720, "beaufighter", "COMMONWEALTH BEAUFIGHTER HEAVY CORPS"),
        ]
        self.secret_squadron_index = 0

        # Spawn the other two secret prototypes as autonomous AI wingmen
        all_secret = ["ho229", "b29", "shinden"]
        wing_keys = [p for p in all_secret if p != chosen_plane]
        self.secret_wingmen = [
            {
                "plane": wing_keys[0],
                "x": float(self.width() // 2 - 110),
                "y": float(self.height() + 350),  # Off-screen rear during carrier takeoff
                "target_ox": -110.0,
                "target_oy": 45.0,
                "hp": 16 if wing_keys[0] == "b29" else 12,
                "max_hp": 16 if wing_keys[0] == "b29" else 12,
                "fire_cooldown": random.randint(10, 25),
                "bank_angle": 0.0,
                "hit_flash": 0,
                "name": self.nation_info[wing_keys[0]]["name"]
            },
            {
                "plane": wing_keys[1],
                "x": float(self.width() // 2 + 110),
                "y": float(self.height() + 450),  # Off-screen rear during carrier takeoff
                "target_ox": 110.0,
                "target_oy": 45.0,
                "hp": 16 if wing_keys[1] == "b29" else 12,
                "max_hp": 16 if wing_keys[1] == "b29" else 12,
                "fire_cooldown": random.randint(15, 30),
                "bank_angle": 0.0,
                "hit_flash": 0,
                "name": self.nation_info[wing_keys[1]]["name"]
            }
        ]
        self.failsafe_shockwaves.clear()
        self.failsafe_flash_ticks = 0
        self.banner_text = "★ OPERATION BLACKOUT: 2-MIN SORTIE! DESTROY SQUADRONS, BOSSES & HANGAR! ★"
        self.banner_timer = 220

    def spawn_secret_squadron(self, plane_key, title):
        """Spawns an organized 5-aircraft combat wedge of the specified fighter."""
        center_x = random.randint(150, self.width() - 150)
        formation_offsets = [(0, -40), (-45, -75), (45, -75), (-90, -110), (90, -110)]
        for ox, oy in formation_offsets:
            self.enemies.append({
                "x": center_x + ox,
                "y": oy,
                "vx": 0.0,
                "vy": 3.8,
                "hp": 5,
                "faction": plane_key,
                "type": "scout",
                "hit_flash": 0
            })
        self.banner_text = f"⚠ SQUADRON INBOUND: {title}! ⚠"
        self.banner_timer = 100

    def spawn_secret_cartel_boss(self, boss_key):
        """Spawns captured enemy boss leviathans during the Sahara secret mission."""
        boss_configs = {
            "AYAKO": {
                "name": "AYAKO", "title": "STOLEN IJN SUPER FORTRESS 'AYAKO'",
                "faction": "imperial", "hp": 260,
                "turrets": [
                    {"x": -110, "y": -20}, {"x": -50, "y": 30},
                    {"x": 50, "y": 30}, {"x": 110, "y": -20}
                ]
            },
            "BV238": {
                "name": "BV238", "title": "STOLEN 6-ENGINE LEVIATHAN 'BV 238'",
                "faction": "luftwaffe", "hp": 320,
                "turrets": [
                    {"x": -130, "y": -10}, {"x": -60, "y": 25},
                    {"x": 0, "y": 40}, {"x": 60, "y": 25}, {"x": 130, "y": -10}
                ]
            },
            "B24": {
                "name": "B24", "title": "STOLEN USAAF DREADNOUGHT 'B-24 LIBERATOR'",
                "faction": "allied", "hp": 360,
                "turrets": [
                    {"x": -90, "y": -15}, {"x": -35, "y": 35},
                    {"x": 35, "y": 35}, {"x": 90, "y": -15}
                ]
            },
            "PE8": {
                "name": "PE8", "title": "STOLEN VVS 4-ENGINE FORTRESS 'Pe-8'",
                "faction": "vvs", "hp": 380,
                "turrets": [
                    {"x": -100, "y": -20}, {"x": -40, "y": 30},
                    {"x": 40, "y": 30}, {"x": 100, "y": -20}
                ]
            }
        }
        cfg = boss_configs.get(boss_key, boss_configs["AYAKO"])
        self.sound.play_bgm("bgm_boss")
        self.banner_text = f"⚠ ENEMY LEVIATHAN DESCENDING: {cfg['title']}! ⚠"
        self.banner_timer = 160
        self.boss = {
            "name": cfg["name"],
            "title": cfg["title"],
            "faction": cfg["faction"],
            "x": self.width() // 2, "y": -160, "target_y": 200,
            "hp": cfg["hp"], "max_hp": cfg["hp"], "active": True,
            "vulnerable": False,
            "fire_tick": 0, "turrets": cfg["turrets"],
            "damage_stage": 0
        }
        self.boss_spawned = True

    def defeat_hangar(self):
        """Initiates the cataclysmic chain explosion sequence of the underground cartel depot."""
        if not self.cartel_hangar or self.cartel_hangar.get("exploding"):
            return
        self.cartel_hangar["exploding"] = True
        self.cartel_hangar["explosion_ticks"] = 0
        self.sound.play("boss_defeat")
        self.screen_shake = 45
        self.score += 50000
        self.banner_text = "★ UNDERGROUND WEAPONS HANGAR OBLITERATED! AIRSPACE SECURED! ★"
        self.banner_timer = 220
        self.enemies.clear()
        self.enemy_bullets.clear()
        for _ in range(25):
            self.explosions.append({
                "x": self.cartel_hangar["x"] + random.randint(-170, 170),
                "y": self.cartel_hangar["y"] + random.randint(-150, 150),
                "radius": 28, "max_radius": 75, "life": random.randint(24, 40)
            })

    def trigger_failsafe_detonation(self, x, y, name):
        """Atomic-yield self-destruct scuttle to deny prototype capture by rogue cartel."""
        self.sound.play("failsafe_alarm")
        self.failsafe_shockwaves.append({
            "x": float(x), "y": float(y),
            "radius": 18.0, "max_radius": 560.0,
            "speed": 18.0, "life": 38,
            "name": name
        })
        self.screen_shake = 32
        self.failsafe_flash_ticks = 24
        self.enemy_bullets.clear()
        
        for e in self.enemies:
            if e.get("y", 0) < 40 or e.get("y", 0) > self.height() - 10:
                continue
            dist = math.hypot(e["x"] - x, e["y"] - y)
            if dist < 440:
                e["hp"] -= 50
                e["hit_flash"] = 15
                self.explosions.append({
                    "x": e["x"], "y": e["y"],
                    "radius": 28, "max_radius": 60, "life": 22
                })
        for g in self.ground_targets:
            dist = math.hypot(g["x"] - x, g["y"] - y)
            if dist < 440 and not g.get("wreck"):
                g["hp"] -= 50
                g["hit_flash"] = 15
                if g["hp"] <= 0:
                    g["wreck"] = True
                    self.score += g["score"]
                    self.stats["ground_targets_destroyed"] = self.stats.get("ground_targets_destroyed", 0) + 1

        if self.cartel_hangar and self.cartel_hangar.get("active") and not self.cartel_hangar.get("exploding"):
            h_dist = math.hypot(self.cartel_hangar["x"] - x, self.cartel_hangar["y"] - y)
            if h_dist < 440:
                self.cartel_hangar["hp"] -= 80
                self.cartel_hangar["hit_flash"] = 15
                if self.cartel_hangar["hp"] <= 0:
                    self.defeat_hangar()
        
        self.floating_texts.append({
            "text": f"☢ FAILSAFE ATOMIC SCUTTLE: {name} DESTROYED",
            "x": int(x), "y": int(y - 30), "life": 65,
            "color": QColor(255, 220, 80)
        })

    def start_nuke_cutscene(self):
        """Initializes the dramatic failsafe nuclear cutscene when player's prototype is destroyed."""
        self.state = "nuke_cutscene"
        self.bullets.clear()
        self.missiles.clear()
        self.enemy_bullets.clear()
        self.smoke_particles.clear()

        # Position wreckage ahead along the strategic flight corridor
        wreck_x = float(self.width() // 2 - 18)

        if not self.cartel_hangar:
            self.cartel_hangar = {
                "active": True,
                "x": self.width() // 2,
                "y": 240.0,
                "hp": 999,
                "max_hp": 999,
                "hit_flash": 0,
                "exploding": False,
                "explosion_tick": 0
            }

        self.nuke_cutscene = {
            "tick": 0,
            "phase": "plane_entry",
            "cam_y": 0.0,
            "cam_speed": 4.2,
            "wreck_x": wreck_x,
            "wreck_world_y": 672.0,    # Fixed ground position of crash site
            "airfield_world_y": 1848.0, # Fixed ground position of airfield
            "wreck_y": -120.0,
            "airfield_y": -999.0,
            "terrain_scroll": 0.0,
            "transit_prog": 0.0,
            "xb35_x": float(self.width() // 2),
            "xb35_y": float(self.height() + 160),
            "xb35_target_y": 375.0,
            "xb35_locked": False,
            "xb35_bank": 0,
            "xb35_prop_frame": 0,
            "bomb_dropped": False,
            "bomb_x": float(self.width() // 2),
            "bomb_y": 375.0,
            "parachute_open": False,
            "whiteout_alpha": 0.0,
            "camera_shake_amp": 0.0,
            "tinnitus_played": False,
            "blast_played": False,
            "mono_sound_played": False,
            "shockwave_radius": 0.0,
            "flyby_sound_played": False,
            "subtitles": "COALITION AIRFRAME DOWN • INITIATING BLACKOUT FAILSAFE",
            "subtitle_color": QColor(255, 80, 80),
        }

    def update_nuke_cutscene(self):
        c = self.nuke_cutscene
        c["tick"] += 1
        t = c["tick"]

        if t % 3 == 0:
            c["xb35_prop_frame"] = (c["xb35_prop_frame"] + 1) % 4

        # Ground camera movement along unified world coordinates:
        # Cruising speed of 4.2 px/tick until camera arrives over the target base at t=440
        if t < 440:
            c["cam_speed"] = 4.2
        elif t < 470:
            # Smoothly decelerate camera to 0 as it locks onto the airfield
            c["cam_speed"] = max(0.0, 4.2 * (1.0 - (t - 440) / 30.0))
        else:
            c["cam_speed"] = 0.0

        c["cam_y"] += c["cam_speed"]
        c["terrain_scroll"] = c["cam_y"]

        # Wreckage is 100% anchored to world coordinates:
        c["wreck_y"] = 375.0 + (c["cam_y"] - c["wreck_world_y"])

        # Airfield base is 100% anchored to world coordinates:
        base_target_y = 135.0
        c["airfield_y"] = base_target_y + (c["cam_y"] - c["airfield_world_y"])

        # Update smoke and ember particles
        for s in self.smoke_particles:
            s["x"] += s.get("vx", 0.0) + 0.25 * math.sin(t * 0.08 + s.get("life", 0))
            if s.get("type") == "black_smoke":
                s["y"] += s.get("vy", 1.8) + c["cam_speed"]
            else:
                s["y"] += s.get("vy", -1.5)
            s["life"] -= 1
        self.smoke_particles = [s for s in self.smoke_particles if s["life"] > 0]

        # ---------------------------------------------------------------------
        # BEAT 1: CAMERA KEEPS MOVING AFTER WE GO DOWN, NEW PLANE COMES INTO VIEW (t: 0 - 90)
        # ---------------------------------------------------------------------
        if t < 90:
            c["phase"] = "plane_entry"
            c["subtitles"] = "COALITION AIRFRAME DOWN • STRATEGIC FAILSAFE 'SPECTRE 01' INBOUND"
            c["subtitle_color"] = QColor(255, 100, 100)

            # XB-35 enters from south and flies up to center screen (y = 375)
            if t >= 18:
                if not c["flyby_sound_played"]:
                    c["flyby_sound_played"] = True
                    self.sound.play("flying_wing_flyby")
                prog_entry = min(1.0, (t - 18) / 72.0)
                smooth_entry = math.sin(prog_entry * math.pi / 2.0)
                c["xb35_y"] = (self.height() + 160.0) - ((self.height() + 160.0) - 375.0) * smooth_entry
            else:
                c["xb35_y"] = float(self.height() + 160.0)

        # ---------------------------------------------------------------------
        # BEAT 2: CAMERA LOCKS ONTO XB-35 AT CENTER, FLIES BY OUR WRECKAGE (t: 90 - 230)
        # ---------------------------------------------------------------------
        elif t < 230:
            c["phase"] = "flyby_wreckage"
            c["xb35_locked"] = True
            c["xb35_y"] = 375.0  # Camera locked on XB-35 at exact center!

            if c["wreck_y"] < 330:
                c["subtitles"] = "APPROACHING DOWNED AIRFRAME WRECKAGE • RUNNING INTERCEPT"
                c["subtitle_color"] = QColor(255, 215, 60)
            elif c["wreck_y"] < 440:
                c["subtitles"] = "OVERFLYING CRASH SITE • ALL COALITION AIRFRAMES SCUTTLED"
                c["subtitle_color"] = QColor(255, 160, 60)
            else:
                c["subtitles"] = "WRECKAGE CLEARED • SETTING DIRECT COURSE TO CARTEL BASE"
                c["subtitle_color"] = QColor(140, 210, 255)

        # ---------------------------------------------------------------------
        # BEAT 3: CONTINUES FLYING, COMES TO HANGARS (EXTENDED FLIGHT TIME) (t: 230 - 440)
        # ---------------------------------------------------------------------
        elif t < 440:
            c["phase"] = "transit_to_hangars"
            c["xb35_y"] = 375.0  # Camera locked at center screen cruising

            if t < 340:
                c["subtitles"] = "CRUISING NORTH ACROSS SAHARA SECTOR 7 • FAILSAFE ARMED"
                c["subtitle_color"] = QColor(140, 220, 255)
            else:
                c["subtitles"] = "CLOSING ON CARTEL RUNWAYS & HANGARS • INITIATING DROP SEQUENCE"
                c["subtitle_color"] = QColor(255, 220, 80)

        # ---------------------------------------------------------------------
        # BEAT 4: DROPS BOMB AND KEEPS STRAIGHT PATH FLYING AWAY (t: 440 - 580)
        # Camera stays locked on airfield watching falling bomb!
        # ---------------------------------------------------------------------
        elif t < 580:
            c["phase"] = "bomb_drop"

            if not c["bomb_dropped"]:
                c["bomb_dropped"] = True
                c["bomb_x"] = float(self.width() // 2)
                c["bomb_y"] = 375.0  # Released right over hangars
                c["parachute_open"] = True

            # Bomb drifts down towards ground zero (exact crater center: y = 310)
            p_bomb = (t - 440) / 140.0
            c["bomb_y"] = 375.0 + (310.0 - 375.0) * p_bomb

            # XB-35 keeps its straight flight path flying away north! (Zero banking / veering!)
            c["xb35_y"] = 375.0 - (t - 440) * 4.2

            c["subtitles"] = "FAILSAFE ATOMIC PAYLOAD RELEASED • DESCENDING TO GROUND ZERO"
            c["subtitle_color"] = QColor(255, 80, 80)

        # ---------------------------------------------------------------------
        # BEAT 5: FLASH, CAMERA SHAKING, ACOUSTIC BLAST (t: 580 - 650)
        # ---------------------------------------------------------------------
        elif t < 650:
            c["phase"] = "detonation"
            c["transit_prog"] = 1.0

            if not c["tinnitus_played"]:
                c["tinnitus_played"] = True
                self.sound.stop_bgm()
                self.sound.play("nuke_tinnitus")
                c["whiteout_alpha"] = 255.0
                c["camera_shake_amp"] = 28.0

            if t == 594 and not c["blast_played"]:
                c["blast_played"] = True
                self.sound.play("nuke_blast")
                c["camera_shake_amp"] = 32.0
                self.smoke_particles.clear()

            c["shockwave_radius"] += 18.0
            if t > 605:
                c["whiteout_alpha"] = max(0.0, c["whiteout_alpha"] - 2.8)

            c["subtitles"] = "[ DETONATION CONFIRMED — COMPLETE ELECTROMAGNETIC & ACOUSTIC SHOCK ]"
            c["subtitle_color"] = QColor(255, 255, 255)

        # ---------------------------------------------------------------------
        # BEAT 6: DUST SETTLING AND CAMERA STOPPING SHAKE, SHOWING CRATER (t: 650 - 920)
        # ---------------------------------------------------------------------
        elif t < 920:
            c["phase"] = "scorched_earth"
            c["transit_prog"] = 1.0

            # Dust and whiteout dissolve smoothly
            c["whiteout_alpha"] = max(0.0, c["whiteout_alpha"] - 1.5)

            # Camera shake smoothly dampens to 0 as dust settles!
            c["camera_shake_amp"] = max(0.0, c["camera_shake_amp"] * 0.955 - 0.08)

            if not c["mono_sound_played"]:
                c["mono_sound_played"] = True
                self.sound.play_bgm("bgm_defeat")
                self.sound.set_music_volume(0.22)

            # Gentle floating fallout embers
            if t % 3 == 0 and len(self.smoke_particles) < 28:
                self.smoke_particles.append({
                    "x": random.uniform(30, self.width() - 30),
                    "y": random.uniform(self.height() - 30, self.height() + 10),
                    "vx": random.uniform(-0.35, 0.35),
                    "vy": random.uniform(-1.0, -2.2),
                    "rad": random.uniform(2.5, 4.5),
                    "max_rad": random.uniform(5.0, 7.5),
                    "life": 140,
                    "max_life": 140,
                    "type": "ember"
                })

            c["subtitles"] = "CARTEL COMPLEX OBLITERATED. 50-MEGATON CRATER VAPORIZED SURROUNDING BASIN."
            c["subtitle_color"] = QColor(255, 200, 80)

        # ---------------------------------------------------------------------
        # BEAT 7: TRANSITION TO CLASSIFIED DEBRIEF (t >= 920)
        # ---------------------------------------------------------------------
        else:
            self.sound.set_music_volume(0.40)
            self.state = "secret_defeat"

    def draw_nuke_cutscene(self, painter):
        """Draws the cinematic failsafe nuke cutscene with continuous flight to hangars and static crater reveal."""
        c = self.nuke_cutscene
        t = c["tick"]
        H = self.height()
        W = self.width()
        prog = c.get("transit_prog", 0.0)

        # ---------------------------------------------------------------------
        # CAMERA SHAKE: Applied directly to the scene world!
        # Stops smoothly as dust settles!
        # ---------------------------------------------------------------------
        painter.save()
        shake_amp = c.get("camera_shake_amp", 0.0)
        if shake_amp > 0.05:
            ox = random.uniform(-shake_amp, shake_amp)
            oy = random.uniform(-shake_amp, shake_amp)
            painter.translate(ox, oy)

        # Airfield layout:
        # Aspect ratio of the new clean airfield assets: 1024x559 (w:h = 1.83)
        base_w = 700
        base_h = int(base_w * 559 / 1024)
        base_x = (W - base_w) // 2
        base_target_y = 135
        # Airfield Y position anchored directly to the African desert terrain coordinates:
        airfield_y = int(c.get("airfield_y", base_target_y))

        # 1. Background Layer
        t_pix = self.theater_terrains.get("africa")
        if t < 580:
            sat_hangar = self.cutscene_sprites.get("sat_hangar")

            # 1a. Base desert ground scrolling smoothly
            if t_pix and not t_pix.isNull():
                t_h = t_pix.height()
                scroll_offset = int(c.get("terrain_scroll", t * 4.2)) % t_h
                painter.drawPixmap(0, scroll_offset - t_h, W, t_h, t_pix)
                painter.drawPixmap(0, scroll_offset, W, t_h, t_pix)
                painter.drawPixmap(0, scroll_offset + t_h, W, t_h, t_pix)
                painter.fillRect(self.rect(), QColor(140, 95, 45, 25))
            else:
                painter.fillRect(self.rect(), QColor(215, 165, 95))

            # 1b. Intact Airfield base enters from top and scrolls into view as we approach hangars!
            if airfield_y > -base_h and sat_hangar and not sat_hangar.isNull():
                painter.drawPixmap(base_x, airfield_y, base_w, base_h, sat_hangar)
        else:
            # POST-DETONATION SCORCHED EARTH CRATER REVEAL
            # 1a. African desert terrain background
            if t_pix and not t_pix.isNull():
                painter.drawPixmap(0, 0, W, H, t_pix)
                painter.fillRect(self.rect(), QColor(140, 95, 45, 35))
            else:
                painter.fillRect(self.rect(), QColor(215, 165, 95))

            # 1b. Nuked Airfield with crater
            sat_scorch = self.cutscene_sprites.get("sat_scorched")
            if sat_scorch and not sat_scorch.isNull():
                painter.drawPixmap(base_x, base_target_y, base_w, base_h, sat_scorch)

            # 1c. HEAVY BILLOWING SMOKE PLUMES AND GLOWING EMBERS FROM CRATER & HANGARS
            nuked_vents = [
                # Crater center & rim
                {'x': 512, 'y': 255, 'r_start': 18, 'r_end': 95, 'count': 24, 'alpha': 225, 'type': 'crater_heavy'},
                {'x': 440, 'y': 245, 'r_start': 14, 'r_end': 70, 'count': 18, 'alpha': 210, 'type': 'dark_fuel'},
                {'x': 575, 'y': 265, 'r_start': 14, 'r_end': 68, 'count': 18, 'alpha': 200, 'type': 'dark_fuel'},
                # NW Hangar Rows
                {'x': 250, 'y': 155, 'r_start': 14, 'r_end': 75, 'count': 20, 'alpha': 230, 'type': 'black_fuel'},
                {'x': 325, 'y': 155, 'r_start': 14, 'r_end': 70, 'count': 18, 'alpha': 220, 'type': 'black_fuel'},
                # SW Hangar Rows
                {'x': 235, 'y': 275, 'r_start': 14, 'r_end': 75, 'count': 20, 'alpha': 230, 'type': 'black_fuel'},
                {'x': 305, 'y': 285, 'r_start': 14, 'r_end': 70, 'count': 18, 'alpha': 220, 'type': 'black_fuel'},
                # East depots & barracks
                {'x': 735, 'y': 300, 'r_start': 15, 'r_end': 75, 'count': 20, 'alpha': 230, 'type': 'black_fuel'},
                {'x': 630, 'y': 105, 'r_start': 13, 'r_end': 60, 'count': 16, 'alpha': 200, 'type': 'grey_smoke'},
                {'x': 515, 'y': 455, 'r_start': 13, 'r_end': 60, 'count': 16, 'alpha': 200, 'type': 'grey_smoke'},
            ]

            # Fire core glow
            for v_idx, vent in enumerate(nuked_vents):
                vx = base_x + int(base_w * (vent['x'] / 1024.0))
                vy = base_target_y + int(base_h * (vent['y'] / 559.0))
                is_core = (vent['type'] == 'crater_heavy')
                glow_r = (55.0 if is_core else 24.0) + math.sin(t * 0.35 + v_idx) * (6.0 if is_core else 3.5)
                g = QRadialGradient(vx, vy, glow_r)
                if is_core:
                    g.setColorAt(0.0, QColor(255, 170, 40, 180))
                    g.setColorAt(0.45, QColor(255, 70, 10, 110))
                    g.setColorAt(1.0, QColor(160, 20, 0, 0))
                else:
                    g.setColorAt(0.0, QColor(255, 140, 25, 140))
                    g.setColorAt(0.5, QColor(220, 50, 5, 70))
                    g.setColorAt(1.0, QColor(120, 10, 0, 0))
                painter.setBrush(g)
                painter.setPen(Qt.NoPen)
                painter.drawEllipse(QPoint(int(vx), int(vy)), int(glow_r), int(glow_r))

            # Heavy billowing volumetric smoke plumes
            for v_idx, vent in enumerate(nuked_vents):
                vx = base_x + int(base_w * (vent['x'] / 1024.0))
                vy = base_target_y + int(base_h * (vent['y'] / 559.0))
                count = vent['count']
                r_start = vent['r_start']
                r_end = vent['r_end']
                max_alpha = vent['alpha']
                ptype = vent['type']

                for i in range(count):
                    phase = (t * 0.52 + i * (60.0 / count) + v_idx * 14.7) % 60.0
                    prog_s = phase / 60.0
                    radius = r_start + (prog_s ** 0.8) * (r_end - r_start)
                    wind_dist = prog_s * 95.0
                    turb_x = math.sin(prog_s * 5.8 + i * 1.7) * (15.0 * prog_s)
                    turb_y = math.cos(prog_s * 4.9 + v_idx * 1.3) * (11.0 * prog_s)
                    sx = vx + wind_dist * 0.90 + turb_x
                    sy = vy - wind_dist * 0.35 + turb_y

                    if prog_s < 0.15:
                        cur_alpha = int(max_alpha * (prog_s / 0.15))
                    else:
                        cur_alpha = int(max_alpha * (1.0 - (prog_s - 0.15) / 0.85) ** 1.3)

                    if cur_alpha > 5:
                        smk = QRadialGradient(sx, sy, radius)
                        if ptype == 'black_fuel':
                            shade = int(12 + prog_s * 26)
                            smk.setColorAt(0.0, QColor(shade, shade, shade + 2, cur_alpha))
                            smk.setColorAt(0.55, QColor(shade + 10, shade + 8, shade + 10, int(cur_alpha * 0.75)))
                            smk.setColorAt(0.85, QColor(shade + 20, shade + 18, shade + 18, int(cur_alpha * 0.30)))
                            smk.setColorAt(1.0, QColor(shade + 28, shade + 26, shade + 26, 0))
                        elif ptype == 'crater_heavy':
                            shade = int(22 + prog_s * 40)
                            smk.setColorAt(0.0, QColor(shade + 4, shade + 2, shade - 2, cur_alpha))
                            smk.setColorAt(0.50, QColor(shade + 14, shade + 11, shade + 6, int(cur_alpha * 0.75)))
                            smk.setColorAt(0.85, QColor(shade + 26, shade + 22, shade + 16, int(cur_alpha * 0.30)))
                            smk.setColorAt(1.0, QColor(shade + 34, shade + 30, shade + 24, 0))
                        else:
                            shade = int(28 + prog_s * 42)
                            smk.setColorAt(0.0, QColor(shade + 2, shade, shade - 2, cur_alpha))
                            smk.setColorAt(0.55, QColor(shade + 12, shade + 10, shade + 8, int(cur_alpha * 0.70)))
                            smk.setColorAt(1.0, QColor(shade + 24, shade + 22, shade + 20, 0))

                        painter.setBrush(smk)
                        painter.setPen(Qt.NoPen)
                        painter.drawEllipse(QPoint(int(sx), int(sy)), int(radius), int(radius))

            # Flying embers & sparks across nuked base
            painter.save()
            painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Screen)
            for e_i in range(65):
                e_phase = (t * 1.7 + e_i * 4.3) % 45.0
                e_prog = e_phase / 45.0
                vent = nuked_vents[e_i % len(nuked_vents)]
                vx = base_x + int(base_w * (vent['x'] / 1024.0))
                vy = base_target_y + int(base_h * (vent['y'] / 559.0))
                ang = (e_i * 59.7) * (math.pi / 180.0)
                spd = 22.0 + (e_i % 11) * 5.0
                dist = spd * (e_prog ** 0.8)
                ex = vx + math.cos(ang) * dist + e_prog * 45.0
                ey = vy + math.sin(ang) * dist - e_prog * 18.0
                e_rad = 3.2 if e_prog < 0.25 else (2.0 if e_prog < 0.60 else 1.2)
                e_alpha = int(255 * (1.0 - e_prog))
                emb = QRadialGradient(ex, ey, e_rad * 2.0)
                if e_prog < 0.28:
                    emb.setColorAt(0.0, QColor(255, 255, 220, e_alpha))
                    emb.setColorAt(0.5, QColor(255, 160, 30, int(e_alpha * 0.85)))
                elif e_prog < 0.62:
                    emb.setColorAt(0.0, QColor(255, 130, 20, e_alpha))
                    emb.setColorAt(0.6, QColor(220, 50, 10, int(e_alpha * 0.60)))
                else:
                    emb.setColorAt(0.0, QColor(200, 35, 5, e_alpha))
                    emb.setColorAt(0.8, QColor(120, 10, 0, int(e_alpha * 0.35)))
                emb.setColorAt(1.0, QColor(0, 0, 0, 0))
                painter.setBrush(emb)
                painter.drawEllipse(QPoint(int(ex), int(ey)), int(e_rad * 2.0), int(e_rad * 2.0))
            painter.restore()

        # 2. Player Burning Wreckage (Uses player's actual chosen aircraft!)
        wrk_screen_y = int(c["wreck_y"])
        if -140 < wrk_screen_y < H + 180:
            wx = int(c["wreck_x"])

            # 2a. Photorealistic self-destructed wreckage & debris field
            photo_wrk = self.cutscene_sprites.get("photo_wreckage")
            if photo_wrk and not photo_wrk.isNull():
                pww, pwh = int(photo_wrk.width() * 0.44), int(photo_wrk.height() * 0.44)
                painter.drawPixmap(wx - pww // 2, wrk_screen_y - pwh // 2, pww, pwh, photo_wrk)
            else:
                # Fallback scorched sand crater
                painter.save()
                painter.setOpacity(0.65)
                painter.setBrush(QColor(22, 16, 12))
                painter.setPen(Qt.NoPen)
                painter.drawEllipse(wx - 55, wrk_screen_y - 30, 110, 60)
                painter.restore()

            # 2c. Top-Down Animated Fire, Billowing Smoke & Flying Embers
            hotspots = [
                (wx - 8, wrk_screen_y - 4),
                (wx - 45, wrk_screen_y - 10),
                (wx + 42, wrk_screen_y + 8),
            ]

            # Fire Core Glow
            for hx, hy in hotspots:
                flicker = math.sin(t * 0.30 + hx) * 4.0
                core_grad = QRadialGradient(hx, hy, 22.0 + flicker)
                core_grad.setColorAt(0.0, QColor(255, 200, 80, 160))
                core_grad.setColorAt(0.45, QColor(255, 90, 10, 90))
                core_grad.setColorAt(1.0, QColor(180, 20, 0, 0))
                painter.setBrush(core_grad)
                painter.setPen(Qt.NoPen)
                painter.drawEllipse(QPoint(int(hx), int(hy)), int(22 + flicker), int(22 + flicker))

            # Volumetric Smoke Puffs (Top-down view: expands radially as it rises, drifts with wind)
            for h_idx, (hx, hy) in enumerate(hotspots):
                for i in range(12):
                    phase = (t * 0.55 + i * 4.4 + h_idx * 15.7) % 55.0
                    prog = phase / 55.0
                    radius = 10.0 + prog * 40.0
                    turb_x = math.sin(prog * 5.5 + i) * (10.0 * prog)
                    turb_y = math.cos(prog * 4.5 + h_idx) * (7.0 * prog)
                    sx = hx + prog * 24.0 + turb_x
                    sy = hy + prog * 32.0 + turb_y
                    alpha = int(135 * (1.0 - prog) * (1.0 - prog))
                    if alpha > 2:
                        smk_grad = QRadialGradient(sx, sy, radius)
                        shade = int(26 + prog * 36)
                        smk_grad.setColorAt(0.0, QColor(shade, shade - 3, shade - 5, alpha))
                        smk_grad.setColorAt(0.50, QColor(shade + 10, shade + 8, shade + 6, int(alpha * 0.55)))
                        smk_grad.setColorAt(1.0, QColor(shade + 18, shade + 16, shade + 14, 0))
                        painter.setBrush(smk_grad)
                        painter.setPen(Qt.NoPen)
                        painter.drawEllipse(QPoint(int(sx), int(sy)), int(radius), int(radius))

            # Glowing Flying Embers & Sparks
            painter.save()
            painter.setCompositionMode(QPainter.CompositionMode_Screen)
            for e_i in range(30):
                e_phase = (t * 1.6 + e_i * 6.3) % 45.0
                e_prog = e_phase / 45.0
                src_x, src_y = hotspots[e_i % len(hotspots)]
                ang = (e_i * 71.0) * (math.pi / 180.0)
                spd = 20.0 + (e_i % 7) * 5.0
                dist = spd * (e_prog ** 0.8)
                ex = src_x + math.cos(ang) * dist + e_prog * 20.0
                ey = src_y + math.sin(ang) * dist + e_prog * 28.0
                e_rad = 3.2 if e_prog < 0.3 else (2.0 if e_prog < 0.7 else 1.2)
                e_alpha = int(255 * (1.0 - e_prog))
                emb_grad = QRadialGradient(ex, ey, e_rad * 2.0)
                if e_prog < 0.35:
                    emb_grad.setColorAt(0.0, QColor(255, 255, 220, e_alpha))
                    emb_grad.setColorAt(0.5, QColor(255, 160, 30, int(e_alpha * 0.8)))
                elif e_prog < 0.70:
                    emb_grad.setColorAt(0.0, QColor(255, 140, 20, e_alpha))
                    emb_grad.setColorAt(0.6, QColor(220, 60, 10, int(e_alpha * 0.6)))
                else:
                    emb_grad.setColorAt(0.0, QColor(220, 40, 10, e_alpha))
                    emb_grad.setColorAt(0.8, QColor(140, 20, 0, int(e_alpha * 0.4)))
                emb_grad.setColorAt(1.0, QColor(0, 0, 0, 0))
                painter.setBrush(emb_grad)
                painter.setPen(Qt.NoPen)
                painter.drawEllipse(QPoint(int(ex), int(ey)), int(e_rad * 2.0), int(e_rad * 2.0))
            painter.restore()

        # 3. Falling Parachute Mk.3 Atomic Bomb
        # Camera stays locked on the airfield and watches the bomb drop!
        if c["bomb_dropped"] and t < 580:
            bx, by = int(c["bomb_x"]), int(c["bomb_y"])
            anim_frames = self.cutscene_sprites.get("bomb_anim_18", [])
            if anim_frames:
                prog = max(0.0, min(1.0, (t - 440) / 140.0))
                f_idx = min(len(anim_frames) - 1, int(prog * len(anim_frames)))
                bomb_pix = anim_frames[f_idx]
            else:
                bomb_pix = self.cutscene_sprites.get("bomb")

            if bomb_pix and not bomb_pix.isNull():
                bw, bh = 135, 205
                painter.save()
                painter.translate(bx, by)
                # Soft ground shadow
                painter.save()
                painter.setOpacity(0.25)
                painter.drawPixmap(-bw // 2 + 18, -bh // 2 + 55, int(bw * 0.80), int(bh * 0.80), bomb_pix)
                painter.restore()
                painter.drawPixmap(-bw // 2, -bh // 2, bw, bh, bomb_pix)
                painter.restore()

        # 4. Northrop XB-35 Flying Wing
        # Keeps its straight flight path flying away north into the distance!
        xb_screen_y = int(c["xb35_y"])
        xb_x = int(c["xb35_x"])
        if -260 < xb_screen_y < H + 260 and t < 600:
            p_col = c["xb35_prop_frame"]
            pix = self.cache.get("xb35", {}).get(f"level_{p_col}")
            if not pix or pix.isNull():
                pix = self.cache.get("xb35", {}).get("level_0")

            if pix and not pix.isNull():
                xb_w, xb_h = 240, 240
                # Realistic soft silhouetted drop shadow
                painter.save()
                painter.setOpacity(0.32)
                shadow_pix = QPixmap(pix.size())
                shadow_pix.fill(Qt.transparent)
                sp = QPainter(shadow_pix)
                sp.drawPixmap(0, 0, pix)
                sp.setCompositionMode(QPainter.CompositionMode_SourceIn)
                sp.fillRect(shadow_pix.rect(), QColor(14, 18, 22, 255))
                sp.end()
                painter.drawPixmap(xb_x - xb_w // 2 + 18, xb_screen_y - xb_h // 2 + 65, xb_w, xb_h, shadow_pix)
                painter.restore()

                dest_rect = QRect(xb_x - xb_w // 2, xb_screen_y - xb_h // 2, xb_w, xb_h)
                painter.drawPixmap(dest_rect, pix)

        # 5. Thermonuclear Detonation Fireball & Shockwave
        if t >= 580 and t < 740:
            fb_pix = self.cutscene_sprites.get("fireball")
            if fb_pix and not fb_pix.isNull():
                progress = min(1.0, (t - 580) / 45.0)
                fb_size = int(80 + 480 * math.sqrt(progress))
                fb_alpha = 1.0 if t < 630 else max(0.0, 1.0 - (t - 630) / 100.0)
                painter.save()
                painter.setOpacity(fb_alpha)
                painter.drawPixmap(W // 2 - fb_size // 2, 280 - fb_size // 2, fb_size, fb_size, fb_pix)
                painter.restore()

        if c["shockwave_radius"] > 0 and c["shockwave_radius"] < 900:
            sr = int(c["shockwave_radius"])
            painter.save()
            sw_alpha = int(max(0, 255 - sr * 0.30))
            painter.setPen(QPen(QColor(255, 245, 210, sw_alpha), max(2, int(20 - sr * 0.02))))
            painter.setBrush(Qt.NoBrush)
            painter.drawEllipse(W // 2 - sr, 280 - sr, sr * 2, sr * 2)
            painter.restore()

        # 6. Particles: Wreckage smoke or fallout embers
        for s in self.smoke_particles:
            alpha = int(240 * (s["life"] / s.get("max_life", 100)))
            rad = int(s.get("rad", 3))
            painter.save()
            if s.get("type") == "black_smoke":
                py = int(s["y"])
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(25, 25, 30, alpha))
                painter.drawEllipse(int(s["x"] - rad), py - rad, rad * 2, rad * 2)
            else:
                grad = QRadialGradient(s["x"], s["y"], rad * 2)
                grad.setColorAt(0.0, QColor(255, 220, 100, alpha))
                grad.setColorAt(0.4, QColor(255, 120, 30, int(alpha * 0.75)))
                grad.setColorAt(1.0, QColor(200, 40, 10, 0))
                painter.setBrush(grad)
                painter.setPen(Qt.NoPen)
                painter.drawEllipse(int(s["x"] - rad * 2), int(s["y"] - rad * 2), rad * 4, rad * 4)
            painter.restore()

        # 7. Blinding Pure Whiteout Flash
        if c["whiteout_alpha"] > 0:
            painter.fillRect(self.rect(), QColor(255, 255, 255, int(c["whiteout_alpha"])))

        # Restore camera shake transform before drawing fixed HUD letterbox bars
        painter.restore()

        # 8. Cinematic Widescreen Letterbox Bars with Military HUD Styling
        bar_h = 64
        painter.fillRect(QRect(0, 0, self.width(), bar_h), QColor(8, 12, 18, 250))
        painter.fillRect(QRect(0, self.height() - bar_h, self.width(), bar_h), QColor(8, 12, 18, 250))

        painter.setPen(QPen(QColor(255, 190, 40, 180), 1.5))
        painter.drawLine(0, bar_h, self.width(), bar_h)
        painter.drawLine(0, self.height() - bar_h, self.width(), self.height() - bar_h)

        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(QRect(10, 14, self.width() - 20, 20), Qt.AlignCenter, "★ TOP SECRET // OPERATION BLACKOUT: STRATEGIC FAILSAFE ★")
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.setPen(QColor(140, 200, 245))
        painter.drawText(QRect(10, 36, self.width() - 20, 16), Qt.AlignCenter, "AIR COMBAT COMMAND • NORTHROP XB-35 FAILSAFE ATOMIC INTERVENTION")

        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(c["subtitle_color"])
        painter.drawText(QRect(20, self.height() - bar_h + 12, self.width() - 40, 22), Qt.AlignCenter, c["subtitles"])

        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.setPen(QColor(160, 180, 200, 190))
        painter.drawText(QRect(self.width() - 160, self.height() - bar_h + 38, 145, 16), Qt.AlignRight, "[SPACE TO SKIP]")


    def summon_air_support(self):
        """Scrambles autonomous Unsung Hero Ace for 10 seconds of high-intensity close air support."""
        if not self.air_support_ready or self.air_support_active:
            return
        self.air_support_ready = False
        self.air_support_active = True
        self.air_support_timer = 600  # 600 frames at 60fps = 10.0 seconds!
        self.sound.play("radio_chime")
        hero = self.air_support_hero
        hero_names = {
            "hurricane": "HAWKER HURRICANE", "p39": "P-39 AIRACOBRA",
            "ki43": "KI-43 OSCAR", "hs129": "Hs 129 PANZERKNACKER",
            "i16": "POLIKARPOV I-16", "cr42": "FIAT CR.42 FALCO",
            "ms406": "M.S.406 FIGHTER", "beaufighter": "BRISTOL BEAUFIGHTER"
        }
        h_name = hero_names.get(hero, hero.upper())
        self.air_support_obj = {
            "hero": hero,
            "x": float(self.x + random.choice([-80, 80])),
            "y": float(self.height() + 70),
            "target_y": float(self.y - 120),
            "vx": 0.0,
            "vy": -8.5,
            "fire_cooldown": 5,
            "special_cooldown": 30,
            "bank_angle": 0.0,
            "name": h_name
        }
        self.banner_text = f"★ 📻 TACTICAL AIR SUPPORT ON STATION: {h_name} ENGAGING (10s)! ★"
        self.banner_timer = 140
        self.floating_texts.append({
            "text": f"★ AIR SUPPORT: {h_name} INBOUND ★",
            "x": int(self.x), "y": int(self.y - 45), "life": 50,
            "color": QColor(255, 235, 100)
        })

    def advance_to_next_campaign_theater(self):
        """Advances to the next country in the global World Tour campaign after secret mission or victory."""
        cycle = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
        base_th = getattr(self, "pre_secret_theater", self.enemy_theater)
        base_plane = getattr(self, "pre_secret_plane", self.current_plane)
        if base_th in cycle:
            idx = cycle.index(base_th)
            next_th = cycle[(idx + 1) % len(cycle)]
        else:
            next_th = "imperial"
        self.is_secret_mission = False
        self.start_transition(base_plane, next_th, round_num=1)

    def draw_secret_briefing(self, painter):
        """Renders the atmospheric Top Secret Briefing screen with the anonymous Shadow General."""
        painter.fillRect(self.rect(), QColor(10, 14, 20))
        
        # Subtle classified grid
        painter.setPen(QColor(22, 34, 48))
        for y in range(0, self.height(), 32): painter.drawLine(0, y, self.width(), y)
        for x in range(0, self.width(), 32): painter.drawLine(x, 0, x, self.height())
        
        # Header Banner
        painter.fillRect(QRect(0, 0, self.width(), 64), QColor(18, 22, 32, 240))
        painter.setPen(QColor(255, 55, 55))
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.drawText(QRect(0, 12, self.width(), 18), Qt.AlignCenter, "TOP SECRET // LEVEL 5 EYES ONLY // SPECIAL COMPARTMENTED ACCESS")
        painter.setPen(QColor(255, 215, 60))
        painter.setFont(QFont("Menlo", 16, QFont.Bold))
        painter.drawText(QRect(0, 32, self.width(), 26), Qt.AlignCenter, "★ OPERATION BLACKOUT: SAHARA COALITION STRIKE ★")
        
        # Left Panel: Shadow General Silhouette Portrait
        port_rect = QRect(22, 76, 186, 230)
        painter.fillRect(port_rect, QColor(14, 18, 26))
        if not self.shadow_officer_pixmap.isNull():
            painter.drawPixmap(port_rect, self.shadow_officer_pixmap)
        painter.setPen(QPen(QColor(215, 175, 45), 2))
        painter.drawRect(port_rect)
        
        # Badge below portrait
        painter.fillRect(QRect(22, 310, 186, 68), QColor(18, 24, 34, 240))
        painter.setPen(QColor(60, 100, 140))
        painter.drawRect(QRect(22, 310, 186, 68))
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(255, 220, 60))
        painter.drawText(QRect(22, 314, 186, 16), Qt.AlignCenter, "BRIEFING GENERAL")
        painter.setPen(QColor(255, 80, 80))
        painter.drawText(QRect(22, 330, 186, 16), Qt.AlignCenter, "[IDENTITY REDACTED]")
        painter.setPen(QColor(160, 200, 240))
        painter.drawText(QRect(22, 346, 186, 16), Qt.AlignCenter, "CLEARANCE: OMEGA")
        painter.drawText(QRect(22, 360, 186, 16), Qt.AlignCenter, "COMBINED HIGH COMMAND")

        # Right Panel: Operation Metadata Dossier
        meta_rect = QRect(218, 76, self.width() - 240, 302)
        painter.fillRect(meta_rect, QColor(16, 22, 32, 240))
        painter.setPen(QPen(QColor(65, 110, 160), 1.5))
        painter.drawRect(meta_rect)
        
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(100, 220, 255))
        painter.drawText(230, 96, "CLASSIFIED DOSSIER FILE: #OB-1945-AF")
        painter.setPen(QColor(200, 215, 230))
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.drawText(230, 118, "COALITION: 🇩🇪 GERMANY • 🇺🇸 USA • 🇯🇵 JAPAN")
        painter.drawText(230, 136, "THEATER: ENNEDI PLATEAU, SAHARA DESERT")
        painter.drawText(230, 154, "TARGET: SYNDICATE STAGING REDOUBT")
        painter.drawText(230, 172, "OPFOR: MULTI-NATIONAL CAPTURED ARMADA")
        
        painter.setPen(QColor(255, 190, 40))
        painter.drawText(230, 196, "ASSIGNED BLACK-PROJECT PROTOTYPES:")
        painter.setPen(QColor(220, 230, 240))
        painter.setFont(QFont("Menlo", 7))
        painter.drawText(238, 214, "• HORTEN Ho 229 (JET FLYING WING)")
        painter.drawText(238, 230, "• B-29 SUPERFORTRESS (FLYING BATTLESHIP)")
        painter.drawText(238, 246, "• J7W1 SHINDEN (CANARD REAR-PUSHER)")
        
        painter.setPen(QColor(255, 80, 80))
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.drawText(230, 272, "FAILSAFE PROTOCOL: ATOMIC SCUTTLE")
        painter.setPen(QColor(200, 200, 200))
        painter.setFont(QFont("Menlo", 7))
        painter.drawText(230, 290, "Crash outside coordinates triggers immediate")
        painter.drawText(230, 304, "atomic-yield blast to deny enemy capture.")
        painter.drawText(230, 318, "Wingmen fly under combat AI alongside you.")

        # Bottom Panel: Teletype Officer Briefing Transcript
        narr_rect = QRect(22, 386, self.width() - 44, 276)
        painter.fillRect(narr_rect, QColor(14, 20, 30, 245))
        painter.setPen(QPen(QColor(215, 175, 45), 1.5))
        painter.drawRect(narr_rect)
        
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(36, 406, "▶ TRANSCRIPTION OF SECURE LIAISON DIRECTIVE:")
        
        briefing_lines = [
            ("\"At ease, pilot. What you hear in this room does not leave this room.\"", QColor(240, 245, 250)),
            ("\"Reconnaissance confirms an armed coup seized our secret Sahara testing depot.\"", QColor(220, 230, 245)),
            ("\"An underground cartel has stockpiled hundreds of captured warbirds from every\"", QColor(220, 230, 245)),
            ("\"fighting country—Allies, Axis, and Comintern alike. An unprecedented threat.\"", QColor(255, 180, 60)),
            ("\"Even in world war, Washington, Berlin, and Tokyo agree: this rogue army cannot stand.\"", QColor(220, 230, 245)),
            ("\"We are giving you three top-secret prototypes equipped with state-of-the-art weapons.\"", QColor(100, 220, 255)),
            ("\"Choose the bird you wish to fly. The other two will fly on your wings under combat AI.\"", QColor(245, 225, 70)),
            ("\"Be warned: There are more hostiles than any pilot has ever faced, from sand to sky.\"", QColor(255, 140, 140)),
            ("\"And if any prototype falls, barometric failsafe atomic charges detonate on impact.\"", QColor(255, 70, 70)),
            ("\"Nothing must be captured. Scramble immediately and annihilate the cartel fortress.\"", QColor(255, 215, 50)),
        ]
        
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        line_y = 428
        for text, col in briefing_lines:
            painter.setPen(col)
            painter.drawText(36, line_y, text)
            line_y += 22

        # Proceed Button
        btn_rect = QRect(22, 672, self.width() - 44, 42)
        painter.fillRect(btn_rect, QColor(42, 60, 28, 240))
        painter.setPen(QPen(QColor(100, 240, 120), 2))
        painter.drawRect(btn_rect)
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(140, 255, 160))
        painter.drawText(btn_rect, Qt.AlignCenter, "★ PROCEED TO PROTOTYPE SELECTION • [SPACE / CLICK] ★")
        
        painter.setFont(QFont("Menlo", 8))
        painter.setPen(QColor(160, 180, 200))
        painter.drawText(QRect(0, self.height() - 22, self.width(), 18), Qt.AlignCenter, "[Esc] Return to Campaign Debrief")

    def draw_secret_select(self, painter):
        """Renders the 3 Secret Prototype selection cards with specs and wingman assignment."""
        painter.fillRect(self.rect(), QColor(12, 16, 24))
        
        # Grid
        painter.setPen(QColor(22, 34, 48))
        for y in range(0, self.height(), 32): painter.drawLine(0, y, self.width(), y)
        for x in range(0, self.width(), 32): painter.drawLine(x, 0, x, self.height())
        
        # Header Banner
        painter.fillRect(QRect(0, 0, self.width(), 64), QColor(18, 24, 36, 240))
        painter.setPen(QColor(255, 215, 50))
        painter.setFont(QFont("Menlo", 15, QFont.Bold))
        painter.drawText(QRect(0, 12, self.width(), 24), Qt.AlignCenter, "★ SELECT YOUR BLACK-PROJECT FIGHTER ★")
        painter.setPen(QColor(140, 210, 255))
        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.drawText(QRect(0, 36, self.width(), 18), Qt.AlignCenter, "THE OTHER TWO CRAFT WILL FLY ON YOUR WINGS AS FORMATION WINGMEN")

        cards_data = [
            {
                "key": "ho229", "key_tag": "1",
                "flag": "🇩🇪", "origin": "GERMAN JET BLACK-PROJECT",
                "name": "HORTEN Ho 229 V3 FLYING WING",
                "role": "Twin-Jumo Stealth Jet Striker",
                "stats": "SPEED: 8.0 • ARMOR: 4 • MANEUVER: EXTREME",
                "weapons": "TWIN 30MM MK 108 JET CANNONS + R4M ORKAN JET ROCKETS",
                "special": "JET-BLAST SPREAD (BULLET CANCELER) • LOW RADAR CROSS-SECTION",
                "y": 74
            },
            {
                "key": "b29", "key_tag": "2",
                "flag": "🇺🇸", "origin": "USAAF STRATEGIC BLACK-PROJECT",
                "name": "BOEING B-29 SUPERFORTRESS",
                "role": "Airborne Strategic Dreadnought",
                "stats": "SPEED: 5.8 • ARMOR: 6 • MANEUVER: HEAVY",
                "weapons": "OCTUPLE 360° COMPUTER TURRETS + CARPET BOMB CLUSTERS",
                "special": "SUPER-HEAVY ARMOR PLATING • MASSIVE FLAK SUPPRESSION WALL",
                "y": 258
            },
            {
                "key": "shinden", "key_tag": "3",
                "flag": "🇯🇵", "origin": "IJN CANARD BLACK-PROJECT",
                "name": "KYUSHU J7W1 SHINDEN",
                "role": "Canard High-Altitude Rear-Pusher",
                "stats": "SPEED: 7.6 • ARMOR: 4 • MANEUVER: HYPER-AGILE",
                "weapons": "QUAD 30MM TYPE 5 NOSE CANNONS + TYPE 3 ROCKET SALVO",
                "special": "CANARD HIGH-G PITCH DYNAMICS • TYPE 5 CANARD PULSE BURST",
                "y": 442
            },
        ]

        for card in cards_data:
            c_rect = QRect(22, card["y"], self.width() - 44, 172)
            k = card["key"]
            painter.fillRect(c_rect, QColor(18, 26, 40, 240))
            painter.setPen(QPen(QColor(255, 215, 60), 1.8))
            painter.drawRect(c_rect)
            
            pix = self.cache[k].get("level_0")
            if pix and not pix.isNull():
                thumb_rect = QRect(c_rect.left() + 10, c_rect.top() + 32, 110, 110)
                painter.drawPixmap(thumb_rect, pix)
            
            tx = c_rect.left() + 130
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.setPen(QColor(255, 235, 80))
            painter.drawText(tx, c_rect.top() + 24, f"[{card['key_tag']}] {card['flag']} {card['name']}")
            
            painter.setFont(QFont("Menlo", 7, QFont.Bold))
            painter.setPen(QColor(100, 200, 255))
            painter.drawText(tx, c_rect.top() + 42, f"ORIGIN: {card['origin']} • {card['role']}")
            
            painter.setFont(QFont("Menlo", 7))
            painter.setPen(QColor(160, 240, 140))
            painter.drawText(tx, c_rect.top() + 62, card["stats"])
            
            painter.setPen(QColor(220, 220, 230))
            painter.drawText(tx, c_rect.top() + 82, f"PRIMARY: {card['weapons']}")
            painter.setPen(QColor(255, 170, 45))
            painter.drawText(tx, c_rect.top() + 102, f"TRAIT: {card['special']}")
            
            other_p = [self.nation_info[p]["name"] for p in ["ho229", "b29", "shinden"] if p != k]
            painter.setFont(QFont("Menlo", 7, QFont.Bold))
            painter.setPen(QColor(200, 180, 255))
            painter.drawText(tx, c_rect.top() + 124, f"WINGMEN: {other_p[0]} & {other_p[1]}")

            btn_mini = QRect(tx, c_rect.top() + 138, 220, 24)
            painter.fillRect(btn_mini, QColor(35, 55, 80, 220))
            painter.setPen(QPen(QColor(100, 210, 255), 1.2))
            painter.drawRect(btn_mini)
            painter.setFont(QFont("Menlo", 8, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(btn_mini, Qt.AlignCenter, f"SELECT [{card['key_tag']}] & LAUNCH")

        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(QRect(0, 634, self.width(), 20), Qt.AlignCenter, "PRESS [1, 2, 3] OR CLICK CARD TO SCRAMBLE COALITION")
        painter.setFont(QFont("Menlo", 8))
        painter.setPen(QColor(160, 180, 200))
        painter.drawText(QRect(0, 654, self.width(), 18), Qt.AlignCenter, "[Esc / Backspace] Return to Briefing")

    def draw_secret_debrief(self, painter, is_victory=True):
        """Renders the dramatic narrative scene with the Shadow General after the secret mission."""
        painter.fillRect(self.rect(), QColor(10, 14, 20))
        
        # Grid
        painter.setPen(QColor(20, 30, 44))
        for y in range(0, self.height(), 32): painter.drawLine(0, y, self.width(), y)
        for x in range(0, self.width(), 32): painter.drawLine(x, 0, x, self.height())
        
        # Header Banner
        painter.fillRect(QRect(0, 0, self.width(), 64), QColor(18, 24, 34, 245))
        if is_victory:
            painter.setPen(QColor(100, 255, 140))
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.drawText(QRect(0, 12, self.width(), 18), Qt.AlignCenter, "TOP SECRET // OPERATION BLACKOUT: MISSION ACCOMPLISHED")
            painter.setPen(QColor(255, 215, 50))
            painter.setFont(QFont("Menlo", 16, QFont.Bold))
            painter.drawText(QRect(0, 32, self.width(), 26), Qt.AlignCenter, "★ CLASSIFIED COALITION DEBRIEFING ★")
        else:
            painter.setPen(QColor(255, 70, 70))
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.drawText(QRect(0, 12, self.width(), 18), Qt.AlignCenter, "TOP SECRET // OPERATION BLACKOUT: SQUADRON COMPROMISED")
            painter.setPen(QColor(255, 120, 50))
            painter.setFont(QFont("Menlo", 16, QFont.Bold))
            painter.drawText(QRect(0, 32, self.width(), 26), Qt.AlignCenter, "⚠ FAILSAFE STRATEGIC SCUTTLE DEPLOYED ⚠")

        # Portrait Box
        port_rect = QRect(22, 76, 186, 230)
        painter.fillRect(port_rect, QColor(14, 18, 26))
        if not self.shadow_officer_pixmap.isNull():
            painter.drawPixmap(port_rect, self.shadow_officer_pixmap)
        border_col = QColor(215, 175, 45) if is_victory else QColor(255, 70, 70)
        painter.setPen(QPen(border_col, 2))
        painter.drawRect(port_rect)
        
        # Badge
        painter.fillRect(QRect(22, 310, 186, 68), QColor(18, 24, 34, 240))
        painter.setPen(QColor(60, 100, 140))
        painter.drawRect(QRect(22, 310, 186, 68))
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(255, 220, 60))
        painter.drawText(QRect(22, 314, 186, 16), Qt.AlignCenter, "BRIEFING GENERAL")
        painter.setPen(QColor(255, 80, 80))
        painter.drawText(QRect(22, 330, 186, 16), Qt.AlignCenter, "[IDENTITY REDACTED]")
        painter.setPen(QColor(160, 200, 240))
        painter.drawText(QRect(22, 346, 186, 16), Qt.AlignCenter, "CLEARANCE: OMEGA")
        painter.drawText(QRect(22, 360, 186, 16), Qt.AlignCenter, "COMBINED HIGH COMMAND")

        # Right Summary Panel
        meta_rect = QRect(218, 76, self.width() - 240, 302)
        painter.fillRect(meta_rect, QColor(16, 22, 32, 240))
        painter.setPen(QPen(QColor(65, 110, 160), 1.5))
        painter.drawRect(meta_rect)
        
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(100, 220, 255))
        painter.drawText(230, 96, "OPERATION FILE: #OB-1945-AF")
        painter.setPen(QColor(200, 215, 230))
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.drawText(230, 118, "LOCATION: ENNEDI CANYONS, SAHARA")
        painter.drawText(230, 136, "AIRCRAFT: ALL-PROTOTYPE COALITION")
        
        if is_victory:
            painter.setPen(QColor(100, 255, 140))
            painter.drawText(230, 160, "OUTCOME: CARTEL ARSENAL ANNIHILATED")
            painter.setPen(QColor(220, 230, 240))
            painter.setFont(QFont("Menlo", 7))
            painter.drawText(230, 184, "All captured foreign aircraft destroyed.")
            painter.drawText(230, 200, "Depot and testing infrastructure leveled.")
            painter.drawText(230, 216, "Black-project airframes recovered cleanly.")
            painter.setPen(QColor(255, 215, 60))
            painter.setFont(QFont("Menlo", 7, QFont.Bold))
            painter.drawText(230, 244, "RECOGNITION: NONE (DENIED BY TREATY)")
            painter.setPen(QColor(180, 200, 220))
            painter.setFont(QFont("Menlo", 7))
            painter.drawText(230, 264, "No ribbons. No medals. No mention in")
            painter.drawText(230, 278, "any country's official military archives.")
        else:
            painter.setPen(QColor(255, 80, 80))
            painter.drawText(230, 160, "OUTCOME: STRATEGIC FAILSAFE DETONATED")
            painter.setPen(QColor(220, 230, 240))
            painter.setFont(QFont("Menlo", 7))
            painter.drawText(230, 184, "High-altitude failsafe bomber deployed.")
            painter.drawText(230, 200, "50-megaton atomic charge detonated.")
            painter.drawText(230, 216, "The facility and surrounding basin are gone.")
            painter.setPen(QColor(255, 80, 80))
            painter.setFont(QFont("Menlo", 7, QFont.Bold))
            painter.drawText(230, 244, "CLEARANCE DIRECTIVE: SILENCE OR EXECUTION")
            painter.setPen(QColor(220, 180, 180))
            painter.setFont(QFont("Menlo", 7))
            painter.drawText(230, 264, "Any discussion of this operation will")
            painter.drawText(230, 278, "result in immediate permanent erasure.")

        # Bottom Transcript Panel
        narr_rect = QRect(22, 386, self.width() - 44, 272)
        painter.fillRect(narr_rect, QColor(14, 20, 30, 245))
        painter.setPen(QPen(border_col, 1.5))
        painter.drawRect(narr_rect)
        
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(36, 406, "▶ TRANSCRIPTION OF GENERAL'S CLOSING REMARKS:")
        
        if is_victory:
            dialogue = [
                ("\"Thank you for your service, pilot.\"", QColor(255, 255, 255)),
                ("\"What you have accomplished in that desert today is the most critical mission\"", QColor(100, 255, 160)),
                ("\"the world will never hear about.\"", QColor(100, 255, 160)),
                ("\"There will be no medals pinned to your chest. No commendations. No promotions.\"", QColor(220, 230, 245)),
                ("\"Washington, Berlin, and Tokyo will swear under oath this coalition never happened.\"", QColor(220, 230, 245)),
                ("\"The history books will never record your names, and humanity will remain ignorant\"", QColor(220, 230, 245)),
                ("\"of the catastrophic war you just prevented.\"", QColor(255, 215, 60)),
                ("\"Take pride knowing the skies are safe because of what you did in that canyon.\"", QColor(255, 215, 60)),
                ("\"Now return to your standard frontline station. Your regular war is still waiting.\"", QColor(140, 210, 255)),
            ]
        else:
            dialogue = [
                ("\"You disappointed us, pilot. We trusted you to resolve this cleanly.\"", QColor(255, 100, 100)),
                ("\"However... tailing your squadron at 50,000 feet was a strategic failsafe bomber.\"", QColor(240, 240, 245)),
                ("\"The moment your airframes went down, they dropped a 50-megaton nuclear yield device.\"", QColor(255, 180, 80)),
                ("\"The facility, the stolen planes, the cartel, every person, civilian and combatant—\"", QColor(255, 180, 80)),
                ("\"everything has ceased to exist. A scorched crater of glass is all that remains.\"", QColor(255, 80, 80)),
                ("\"We did not want it to come to that. But we could not risk failure.\"", QColor(220, 230, 245)),
                ("\"Now hear this clearly: If a single syllable of this mission ever crosses your lips...\"", QColor(255, 60, 60)),
                ("\"You, your service records, and everyone you know will also cease to exist.\"", QColor(255, 60, 60)),
                ("\"Get back into your standard cockpit. You have a scheduled campaign sortie to fly.\"", QColor(140, 210, 255)),
            ]

        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        line_y = 430
        for text, col in dialogue:
            painter.setPen(col)
            painter.drawText(36, line_y, text)
            line_y += 22

        # Return Button
        btn_rect = QRect(22, 668, self.width() - 44, 44)
        btn_bg = QColor(30, 65, 110, 240) if is_victory else QColor(55, 25, 25, 240)
        btn_border = QColor(100, 210, 255) if is_victory else QColor(255, 100, 80)
        painter.fillRect(btn_rect, btn_bg)
        painter.setPen(QPen(btn_border, 2))
        painter.drawRect(btn_rect)
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        btn_msg = "★ RESUME WORLD TOUR CAMPAIGN • [SPACE / CLICK] ★" if is_victory else "★ RETURN TO CAMPAIGN SORTIE • [SPACE / CLICK] ★"
        painter.drawText(btn_rect, Qt.AlignCenter, btn_msg)

    def defeat_boss(self):
        if not self.boss or not self.boss.get("active"):
            return
        self.boss["active"] = False
        self.stats["boss_killed"] = True
        self.score += 20000
        self.sound.play("boss_defeat")
        for _ in range(25):
            self.explosions.append({
                "x": self.boss["x"] + random.randint(-140, 140),
                "y": self.boss["y"] + random.randint(-40, 40),
                "radius": 24, "max_radius": 68, "life": random.randint(20, 36)
            })
        self.screen_shake = 26

        if self.is_secret_mission:
            self.secret_bosses_defeated += 1
            b_title = self.boss.get("title", "CARTEL DREADNOUGHT") if self.boss else "CARTEL DREADNOUGHT"
            self.boss = None
            self.boss_spawned = False
            self.banner_text = f"★ {b_title} DOWN! ADVANCING TOWARDS WEAPONS DEPOT! ★"
            self.banner_timer = 150
            return

        self.sound.play_bgm("bgm_victory")
        self.banner_text = f"★ {self.boss['title']} DESTROYED! RETURN TO CARRIER FOR RECOVERY! ★"
        self.banner_timer = 180
        # Scramble carrier landing
        self.state = "landing"
        self.landing_tick = 0

    def take_player_damage(self, amount=1, hit_x=None, hit_y=None):
        if self.invulnerable_ticks > 0 or self.is_looping or self.death_ticks > 0 or self.state != "playing":
            return

        self.hp -= amount
        self.hit_flash_ticks = 10
        self.invulnerable_ticks = 60
        self.screen_shake = 10

        hx = hit_x if hit_x is not None else self.x
        hy = hit_y if hit_y is not None else self.y

        for _ in range(12):
            self.spark_particles.append({
                "x": hx + random.randint(-8, 8),
                "y": hy + random.randint(-8, 8),
                "vx": random.uniform(-4, 4),
                "vy": random.uniform(-3, 5),
                "life": random.randint(10, 20),
                "color": random.choice([QColor(255, 240, 160), QColor(255, 140, 40), QColor(255, 60, 20)])
            })

        if self.hp > 0:
            self.sound.play("player_damage")
            self.banner_text = f"⚠ AIRFRAME IMPACT! ARMOR AT {self.hp}/{self.max_hp} ⚠"
            self.banner_timer = 60
        else:
            self.sound.play("player_death")
            self.death_ticks = 1
            if self.lives > 1:
                self.banner_text = f"☠ AIRFRAME DOWN! RESERVE SORTIE EN ROUTE ({self.lives - 1} LEFT)! ☠"
            else:
                self.sound.play_bgm("bgm_defeat")
                self.banner_text = f"☠ {self.nation_info[self.current_plane]['name']} FINAL AIRFRAME DESTROYED! ☠"
            self.banner_timer = 90

    def get_audio_button_rect(self):
        if self.state == "playing":
            return self.get_header_rects()["sound"]
        return QRect(self.width() - 84, 18, 70, 26)

    def draw_audio_button(self, painter, rect, is_hud=False):
        painter.save()
        painter.setBrush(QColor(20, 32, 48))
        painter.setPen(QPen(QColor(255, 215, 60) if self.audio_menu_open else QColor(50, 80, 120), 1))
        painter.drawRoundedRect(rect, 5, 5)
        painter.setFont(QFont("Arial", 9, QFont.Bold))
        painter.setPen(QColor(255, 215, 60) if self.audio_menu_open else QColor(220, 235, 250))
        painter.drawText(rect, Qt.AlignCenter, "🔊 Snd [M]")
        painter.restore()

    def set_help_modal(self, open_help):
        if open_help:
            if not self.is_paused and self.state == "playing":
                self.is_paused = True
                self.paused_by_menu = True
            self.show_help_modal = True
            self.sound.play("pow_pickup")
        else:
            self.show_help_modal = False
            if getattr(self, "paused_by_menu", False) and not self.audio_menu_open:
                self.is_paused = False
                self.paused_by_menu = False
        self.update()

    def set_audio_menu(self, open_audio):
        if open_audio:
            if not self.is_paused and self.state == "playing":
                self.is_paused = True
                self.paused_by_menu = True
            self.audio_menu_open = True
            self.sound.play("pow_pickup")
        else:
            self.audio_menu_open = False
            if getattr(self, "paused_by_menu", False) and not getattr(self, "show_help_modal", False):
                self.is_paused = False
                self.paused_by_menu = False
        self.update()

    def toggle_help_modal(self):
        self.set_help_modal(not getattr(self, "show_help_modal", False))

    def toggle_audio_menu(self):
        self.set_audio_menu(not self.audio_menu_open)

    def toggle_pause(self):
        if getattr(self, "show_help_modal", False):
            self.set_help_modal(False)
            return
        if self.audio_menu_open:
            self.set_audio_menu(False)
            return
        self.is_paused = not self.is_paused
        self.paused_by_menu = False
        self.sound.play("pow_pickup")
        self.update()

    def toggle_header_mode(self):
        self.is_mini_header = not getattr(self, "is_mini_header", False)
        self.sound.play("pow_pickup")
        self.update()

    def get_audio_dialog_rect(self):
        dlg_w = 444
        dlg_h = 430
        h_h = (46 if getattr(self, "is_mini_header", False) else 108) if self.state == "playing" else 10
        dlg_x = (self.width() - dlg_w) // 2
        dlg_y = h_h + (self.height() - h_h - dlg_h) // 2
        return QRect(dlg_x, dlg_y, dlg_w, dlg_h)

    def get_hangar_help_rect(self):
        return QRect(16, 20, 116, 28)

    def draw_template_help_button(self, painter, rect):
        painter.save()
        is_active = getattr(self, "show_help_modal", False)
        # Template subheader pill styling: radius 8, border 1
        painter.setBrush(QColor(26, 40, 60) if is_active else QColor(16, 26, 40))
        painter.setPen(QPen(QColor(255, 215, 60) if is_active else QColor(48, 78, 114), 1))
        painter.drawRoundedRect(rect, 8, 8)

        # Template gold '?' on left
        painter.setFont(QFont("Arial", 11, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(QRect(rect.left() + 8, rect.top(), 16, rect.height()), Qt.AlignCenter, "?")

        # Template 'How to Play' label
        painter.setFont(QFont("Arial", 9, QFont.Bold))
        painter.setPen(QColor(255, 215, 60) if is_active else QColor(240, 248, 255))
        painter.drawText(QRect(rect.left() + 26, rect.top(), rect.width() - 28, rect.height()), Qt.AlignLeft | Qt.AlignVCenter, "How to Play")
        painter.restore()

    def get_header_rects(self):
        m_w, m_h = 440, 430
        m_x = (self.width() - m_w) // 2
        m_y = (self.height() - m_h) // 2
        modal_close_rect = QRect(m_x + (m_w - 120) // 2, m_y + m_h - 70, 120, 32)
        if getattr(self, "is_mini_header", False):
            my = 13
            return {
                "is_mini": True,
                "pause": QRect(self.width() - 170, my, 26, 28),
                "help": QRect(self.width() - 138, my, 26, 28),
                "sound": QRect(self.width() - 106, my, 26, 28),
                "restart": QRect(self.width() - 74, my, 26, 28),
                "view_mode": QRect(self.width() - 42, my, 26, 28),
                "modal_close": modal_close_rect
            }
        else:
            r2_y = 68
            return {
                "is_mini": False,
                "help": QRect(16, r2_y, 116, 28),
                "pause": QRect(self.width() - 256, r2_y, 72, 28),
                "sound": QRect(self.width() - 176, r2_y, 62, 28),
                "restart": QRect(self.width() - 106, r2_y, 64, 28),
                "view_mode": QRect(self.width() - 36, r2_y, 24, 28),
                "modal_close": modal_close_rect
            }

    def draw_template_header(self, painter):
        painter.save()
        rects = self.get_header_rects()

        if getattr(self, "is_mini_header", False):
            # -----------------------------------------------------------------
            # Mini Floating Header (Shift+F Tiled View / Micro-HUD)
            # -----------------------------------------------------------------
            mini_rect = QRect(12, 8, self.width() - 24, 38)
            painter.fillRect(mini_rect, QColor(10, 18, 30, 235))
            painter.setPen(QPen(QColor(45, 80, 125), 1))
            painter.drawRoundedRect(mini_rect, 7, 7)

            painter.setFont(QFont("Arial", 11, QFont.Bold))
            painter.setPen(QColor(255, 215, 60))
            painter.drawText(22, 32, "SKY ACE 194X")

            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(136, 32, f"• {self.score:,}")

            painter.setFont(QFont("Menlo", 8))
            painter.setPen(QColor(160, 195, 230))
            painter.drawText(215, 32, f"HI:{self.high_score:,}")

            # Mini buttons on right
            for b_key, b_icon in [("pause", "▶" if self.is_paused else "⏸"),
                                   ("help", "?"),
                                   ("sound", "🔊"),
                                   ("restart", "🔄"),
                                   ("view_mode", "⛶")]:
                b_rect = rects[b_key]
                is_active = (b_key == "pause" and self.is_paused) or \
                            (b_key == "help" and getattr(self, "show_help_modal", False)) or \
                            (b_key == "sound" and self.audio_menu_open)
                painter.fillRect(b_rect, QColor(20, 34, 52))
                painter.setPen(QPen(QColor(255, 215, 60) if is_active else QColor(50, 90, 140), 1))
                painter.drawRoundedRect(b_rect, 4, 4)
                painter.setFont(QFont("Menlo", 10, QFont.Bold))
                painter.setPen(QColor(255, 215, 60) if is_active else QColor(240, 248, 255))
                painter.drawText(b_rect, Qt.AlignCenter, b_icon)

        else:
            # -----------------------------------------------------------------
            # Standard 2048 Arcade Header (Row 1 Title/Stats + Row 2 Action Bar)
            # -----------------------------------------------------------------
            h_h = 108
            header_rect = QRect(0, 0, self.width(), h_h)
            painter.fillRect(header_rect, QColor(8, 14, 22, 245))
            painter.setPen(QPen(QColor(36, 56, 82), 1))
            painter.drawLine(0, h_h, self.width(), h_h)

            # Row 1: Title & Subtitle (Left)
            t_info = self.theaters.get(self.enemy_theater, self.theaters["imperial"])

            painter.setFont(QFont("Arial", 18, QFont.Bold))
            painter.setPen(QColor(255, 215, 60))
            painter.drawText(18, 36, "SKY ACE 194X")

            painter.setFont(QFont("Arial", 10))
            painter.setPen(QColor(140, 175, 210))
            sub_text = f"WWII Tactical Carrier Arcade • {t_info['name']}"
            painter.drawText(18, 52, sub_text)

            # Row 1: Stat Cards (Right)
            sc_w, sc_h = 76, 44
            # SCORE Card
            sc_rect = QRect(self.width() - 176, 16, sc_w, sc_h)
            painter.setBrush(QColor(16, 26, 40))
            painter.setPen(QPen(QColor(48, 78, 114), 1))
            painter.drawRoundedRect(sc_rect, 6, 6)
            painter.setFont(QFont("Arial", 8, QFont.Bold))
            painter.setPen(QColor(140, 175, 210))
            painter.drawText(QRect(sc_rect.left(), sc_rect.top() + 4, sc_w, 14), Qt.AlignCenter, "SCORE")
            painter.setFont(QFont("Menlo", 11, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(QRect(sc_rect.left(), sc_rect.top() + 18, sc_w, 22), Qt.AlignCenter, f"{self.score:06d}")

            # BEST Card
            best_rect = QRect(self.width() - 92, 16, sc_w, sc_h)
            painter.setBrush(QColor(16, 26, 40))
            painter.setPen(QPen(QColor(48, 78, 114), 1))
            painter.drawRoundedRect(best_rect, 6, 6)
            painter.setFont(QFont("Arial", 8, QFont.Bold))
            painter.setPen(QColor(140, 175, 210))
            painter.drawText(QRect(best_rect.left(), best_rect.top() + 4, sc_w, 14), Qt.AlignCenter, "BEST")
            painter.setFont(QFont("Menlo", 11, QFont.Bold))
            painter.setPen(QColor(255, 215, 60))
            painter.drawText(QRect(best_rect.left(), best_rect.top() + 18, sc_w, 22), Qt.AlignCenter, f"{self.high_score:06d}")

            # Row 2: Subheader Action Bar
            r2_y = 68
            # [? How to Play] (Standard Template Button)
            h_btn = rects["help"]
            self.draw_template_help_button(painter, h_btn)

            # [⏸ Pause (P)]
            p_btn = rects["pause"]
            painter.setBrush(QColor(20, 32, 48))
            painter.setPen(QPen(QColor(255, 215, 60) if self.is_paused else QColor(50, 80, 120), 1))
            painter.drawRoundedRect(p_btn, 5, 5)
            painter.setFont(QFont("Arial", 9, QFont.Bold))
            painter.setPen(QColor(255, 215, 60) if self.is_paused else QColor(220, 235, 250))
            p_label = "▶ Resume" if self.is_paused else "⏸ Pause"
            painter.drawText(p_btn, Qt.AlignCenter, p_label)

            # [🔊 Snd (M)]
            s_btn = rects["sound"]
            painter.setBrush(QColor(20, 32, 48))
            painter.setPen(QPen(QColor(255, 215, 60) if self.audio_menu_open else QColor(50, 80, 120), 1))
            painter.drawRoundedRect(s_btn, 5, 5)
            painter.setFont(QFont("Arial", 9, QFont.Bold))
            painter.setPen(QColor(255, 215, 60) if self.audio_menu_open else QColor(220, 235, 250))
            painter.drawText(s_btn, Qt.AlignCenter, "🔊 Snd (M)")

            # [🔄 Reset (R)]
            r_btn = rects["restart"]
            painter.setBrush(QColor(20, 32, 48))
            painter.setPen(QPen(QColor(50, 80, 120), 1))
            painter.drawRoundedRect(r_btn, 5, 5)
            painter.setFont(QFont("Arial", 9, QFont.Bold))
            painter.setPen(QColor(220, 235, 250))
            painter.drawText(r_btn, Qt.AlignCenter, "🔄 Reset")

            # [⛶ Full / Tiled (Shift+F)]
            f_btn = rects["view_mode"]
            painter.setBrush(QColor(20, 32, 48))
            painter.setPen(QPen(QColor(50, 80, 120), 1))
            painter.drawRoundedRect(f_btn, 5, 5)
            painter.setFont(QFont("Arial", 9, QFont.Bold))
            painter.setPen(QColor(220, 235, 250))
            painter.drawText(f_btn, Qt.AlignCenter, "⛶")

        painter.restore()

    def draw_option1_hud(self, painter):
        painter.save()
        hud_y = 52 if getattr(self, "is_mini_header", False) else 114
        hud_h = 34
        hud_w = self.width() - 28
        hud_rect = QRect(14, hud_y, hud_w, hud_h)

        # 1. Dark glassmorphic bar
        painter.fillRect(hud_rect, QColor(10, 18, 28, 220))
        painter.setPen(QPen(QColor(45, 110, 175), 1))
        painter.drawRoundedRect(hud_rect, 6, 6)

        # 2. Left Section: ARMOR + Lives + Bombs
        painter.setFont(QFont("Arial", 7, QFont.Bold))
        painter.setPen(QColor(160, 200, 240))
        painter.drawText(20, hud_y + 22, "ARMOR")

        # 4-segment neon health bar
        for seg in range(4):
            if seg < self.hp:
                if self.hp >= 4:
                    col = QColor(70, 240, 120)
                elif self.hp == 3:
                    col = QColor(230, 220, 50)
                elif self.hp == 2:
                    col = QColor(255, 140, 30)
                else:
                    col = QColor(255, 50, 50) if (self.prop_tick // 4) % 2 == 0 else QColor(255, 180, 50)
            else:
                col = QColor(30, 48, 65)
            painter.fillRect(QRect(58 + seg * 10, hud_y + 11, 7, 12), col)

        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.setPen(QColor(255, 215, 60))
        painter.drawText(104, hud_y + 22, f"✈{self.lives} 💣{self.bombs_remaining}")

        # 3. Center Section: Boss/Sortie Radar Pill
        pill_w = 116
        pill_x = (self.width() - pill_w) // 2
        painter.setBrush(QColor(18, 30, 46))
        painter.setPen(QPen(QColor(50, 90, 140), 1))
        painter.drawRoundedRect(QRect(pill_x, hud_y + 6, pill_w, 22), 4, 4)

        if self.boss and self.boss.get("active"):
            clock_text = "⚠ BOSS ACTIVE"
            pulse_c = QColor(255, 70, 70) if (self.prop_tick // 4) % 2 == 0 else QColor(255, 215, 60)
            painter.setPen(pulse_c)
        else:
            rem_secs = max(0, (self.boss_target_ticks - self.mission_ticks) // 60)
            clock_text = f"⚔️ BOSS IN {rem_secs}s"
            painter.setPen(QColor(255, 230, 90))
        painter.setFont(QFont("Menlo", 7, QFont.Bold))
        painter.drawText(QRect(pill_x, hud_y + 6, pill_w, 22), Qt.AlignCenter, clock_text)

        # 4. Right Section: Active Weapon & Tactical Air Support
        if self.is_secret_mission:
            w_disp = "[★ ALL ARMED ★]"
        else:
            w_name = self.weapon_names[self.current_plane][self.weapons[self.weapon_idx]]
            w_disp = f"[Q/E] {w_name[:9]}"

        painter.setFont(QFont("Arial", 8, QFont.Bold))
        painter.setPen(QColor(255, 180, 40))
        painter.drawText(self.width() - 176, hud_y + 22, w_disp)

        if self.air_support_active and self.air_support_obj:
            rem_s = max(0, self.air_support_timer // 60)
            painter.setPen(QColor(100, 255, 150))
            painter.drawText(self.width() - 78, hud_y + 22, f"📻 {rem_s}s")
        elif self.air_support_ready:
            pulse_col = QColor(100, 255, 140) if (self.prop_tick // 6) % 2 == 0 else QColor(255, 225, 70)
            painter.setPen(pulse_col)
            painter.drawText(self.width() - 86, hud_y + 22, "📻 [C] RDY")
        else:
            painter.setPen(QColor(140, 165, 190))
            painter.drawText(self.width() - 86, hud_y + 22, "📻 CHRG")

        painter.restore()

    def get_matchup_badge_rect(self):
        badge_w = 120
        badge_h = 24
        badge_x = (self.width() - badge_w) // 2
        badge_y = self.height() - badge_h - 8
        return QRect(badge_x, badge_y, badge_w, badge_h)

    def draw_battle_matchup_badge(self, painter):
        """Draws the sleek [flag] vs [flag] battle matchup indicator pill centered at the bottom of the screen."""
        badge_rect = self.get_matchup_badge_rect()

        p_info = self.nation_info.get(self.current_plane, {})
        p_flag = p_info.get("flag", "🇺🇸")
        p_name = p_info.get("country", "ALLIED")

        if getattr(self, "is_secret_mission", False):
            t_flag = "⚔️"
            t_name = "ROGUE SYNDICATE"
        else:
            t_info = self.theaters.get(self.enemy_theater, {})
            t_flag = t_info.get("flag", "⚔️")
            t_name = t_info.get("name", "THEATER")

        hovered = getattr(self, "matchup_badge_hovered", False)
        if not hovered and hasattr(self, "mouse_cursor_pos") and self.mouse_cursor_pos is not None:
            hovered = badge_rect.contains(self.mouse_cursor_pos[0], self.mouse_cursor_pos[1])

        painter.save()
        painter.setRenderHint(QPainter.Antialiasing)

        # Tactical hover tooltip
        if hovered:
            tip_text = f"{p_name}  vs  {t_name}"
            tip_w = max(180, len(tip_text) * 7 + 36)
            tip_h = 20
            tip_x = (self.width() - tip_w) // 2
            tip_y = badge_rect.top() - tip_h - 6
            tip_rect = QRect(tip_x, tip_y, tip_w, tip_h)
            painter.fillRect(tip_rect, QColor(6, 12, 20, 235))
            painter.setPen(QPen(QColor(80, 160, 230, 200), 1))
            painter.drawRoundedRect(tip_rect, 4, 4)
            painter.setFont(QFont("Menlo", 7, QFont.Bold))
            painter.setPen(QColor(200, 230, 255))
            painter.drawText(tip_rect, Qt.AlignCenter, tip_text)

        # Glassmorphic pill badge
        bg_col = QColor(10, 20, 32, 235) if hovered else QColor(8, 16, 26, 215)
        border_col = QColor(100, 210, 255, 230) if hovered else QColor(45, 110, 175, 190)

        painter.fillRect(badge_rect, bg_col)
        painter.setPen(QPen(border_col, 1.2 if hovered else 1.0))
        painter.drawRoundedRect(badge_rect, 5, 5)

        # Left flag
        painter.setFont(QFont("Arial", 11))
        painter.drawText(QRect(badge_rect.left() + 6, badge_rect.top(), 32, badge_rect.height()), Qt.AlignCenter, p_flag)

        # Center "VS"
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(255, 220, 70))
        painter.drawText(QRect(badge_rect.left() + 40, badge_rect.top(), 40, badge_rect.height()), Qt.AlignCenter, "VS")

        # Right flag
        painter.setFont(QFont("Arial", 11))
        painter.drawText(QRect(badge_rect.left() + 82, badge_rect.top(), 32, badge_rect.height()), Qt.AlignCenter, t_flag)

        painter.restore()

    def draw_help_modal(self, painter):
        painter.save()
        # Fullscreen backdrop dimming overlay matching template/main.qml (color: "#b3000000")
        painter.fillRect(self.rect(), QColor(0, 0, 0, 195))

        m_w, m_h = 440, 430
        m_x = (self.width() - m_w) // 2
        m_y = (self.height() - m_h) // 2
        modal_rect = QRect(m_x, m_y, m_w, m_h)

        # Template modal card: radius 12, border 1
        card_bg = QColor(16, 24, 38, 252)
        accent_col = QColor(255, 215, 60)
        theme = getattr(self, "omarchy_theme", None)
        if theme:
            if theme.get("background"):
                card_bg = QColor(theme["background"])
                card_bg.setAlpha(252)
            if theme.get("accent"):
                accent_col = QColor(theme["accent"])

        painter.setBrush(card_bg)
        painter.setPen(QPen(accent_col, 1.5))
        painter.drawRoundedRect(modal_rect, 12, 12)

        # Header Title: HOW TO PLAY (matching template/main.qml line 698)
        painter.setFont(QFont("Arial", 16, QFont.Bold))
        painter.setPen(accent_col)
        painter.drawText(QRect(m_x, m_y + 18, m_w, 24), Qt.AlignCenter, "HOW TO PLAY")

        painter.setFont(QFont("Arial", 9, QFont.Bold))
        painter.setPen(QColor(140, 175, 210))
        painter.drawText(QRect(m_x, m_y + 42, m_w, 16), Qt.AlignCenter, "SKY ACE 194X • TACTICAL WWII CARRIER ARCADE")

        # Controls List (matching template pill design)
        controls = [
            ("Arrows / WASD", "Flight Maneuvering & Mouse Aim"),
            ("Z / Left Click", "Primary Cannons (Hold to Autofire)"),
            ("Space / Enter",  "Barrel Roll Loop (Evade Flak)"),
            ("B",              "Heavy Ordnance (Clear Screen Fleet)"),
            ("C",              "Wingman Sortie (Tactical Air Support)"),
            ("Q / E",          "Cycle Weapons (Rockets, Spread)"),
            ("Shift+F",        "Full / Compact View (Micro-HUD)"),
            ("M • P • ?",      "Sound Console • Pause • Help Manual")
        ]

        p_y = m_y + 70
        for key_text, desc_text in controls:
            pill_rect = QRect(m_x + 24, p_y, 114, 22)
            painter.setBrush(QColor(24, 38, 60))
            painter.setPen(QPen(QColor(52, 82, 120), 1))
            painter.drawRoundedRect(pill_rect, 4, 4)

            painter.setFont(QFont("Menlo", 8, QFont.Bold))
            painter.setPen(QColor(255, 230, 90))
            painter.drawText(pill_rect, Qt.AlignCenter, key_text)

            painter.setFont(QFont("Arial", 9))
            painter.setPen(QColor(220, 235, 250))
            painter.drawText(QRect(m_x + 148, p_y, m_w - 170, 22), Qt.AlignLeft | Qt.AlignVCenter, desc_text)
            p_y += 28

        # "GOT IT" Button (matching template/main.qml lines 715-732)
        btn_w, btn_h = 120, 32
        btn_x = m_x + (m_w - btn_w) // 2
        btn_y = m_y + m_h - 70
        btn_rect = QRect(btn_x, btn_y, btn_w, btn_h)

        painter.setBrush(QColor(255, 215, 60))
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(btn_rect, 6, 6)

        painter.setFont(QFont("Arial", 10, QFont.Bold))
        painter.setPen(QColor(14, 20, 30))
        painter.drawText(btn_rect, Qt.AlignCenter, "GOT IT")

        # Attribution Footnote (matching template/main.qml line 735)
        painter.setFont(QFont("Arial", 9))
        painter.setPen(QColor(130, 160, 195, 190))
        painter.drawText(QRect(m_x, m_y + m_h - 26, m_w, 18), Qt.AlignCenter, "Created by Chris Thompson (@bigcjat) with Gemini")

        painter.restore()

    def get_current_engine_spec(self):
        specs = {
            "p38": "P-38 Lightning • Dual Allison V-1710 V12s",
            "zero": "A6M Zero • Nakajima Sakae 12 14-Cyl Radial",
            "spitfire": "Spitfire Mk IX • Rolls-Royce Merlin 61 V12",
            "bf109": "Bf 109 G-6 • Daimler-Benz DB 605 Inverted V12",
            "yak3": "Yak-3 • Klimov VK-105PF2 Liquid-Cooled V12",
            "mosquito": "DH Mosquito • Twin Rolls-Royce Merlin 25 V12s",
            "folgore": "MC.202 Folgore • Alfa Romeo RA.1000 RC.41 V12",
            "d520": "Dewoitine D.520 • Hispano-Suiza 12Y-45 V12",
            "pzl11": "PZL P.11c • Bristol Mercury V.S2 9-Cyl Radial",
            "avia": "Avia B-534 • Hispano-Suiza 12Ydrs 12-Cylinder",
        }
        return specs.get(self.current_plane, "WW2 Warbird Aviation Engine")

    def adjust_channel_volume(self, channel_idx, delta=0.0, absolute_val=None):
        if channel_idx == 0:
            if absolute_val is not None:
                self.music_volume = absolute_val
            else:
                self.music_volume += delta
            self.music_volume = max(0.0, min(1.0, round(self.music_volume, 2)))
            self.sound.set_music_volume(self.music_volume)
            self.settings.setValue("music_volume", self.music_volume)
        elif channel_idx == 1:
            if absolute_val is not None:
                self.battle_volume = absolute_val
            else:
                self.battle_volume += delta
            self.battle_volume = max(0.0, min(1.0, round(self.battle_volume, 2)))
            self.sound.set_battle_volume(self.battle_volume)
            self.settings.setValue("battle_volume", self.battle_volume)
        elif channel_idx == 2:
            if absolute_val is not None:
                self.engine_volume = absolute_val
            else:
                self.engine_volume += delta
            self.engine_volume = max(0.0, min(1.0, round(self.engine_volume, 2)))
            self.prop_audio.set_volume(self.engine_volume)
            self.settings.setValue("engine_volume", self.engine_volume)
        self.update()

    def apply_audio_preset(self, music, battle, engine):
        self.music_volume = music
        self.battle_volume = battle
        self.engine_volume = engine
        self.sound.set_music_volume(self.music_volume)
        self.sound.set_battle_volume(self.battle_volume)
        self.prop_audio.set_volume(self.engine_volume)
        self.settings.setValue("music_volume", self.music_volume)
        self.settings.setValue("battle_volume", self.battle_volume)
        self.settings.setValue("engine_volume", self.engine_volume)
        self.sound.play("pow_pickup")
        self.update()

    def trigger_test_sfx(self):
        self.sound.play("shoot_cannon")

    def handle_audio_menu_mouse(self, mx, my, is_press=True):
        dlg_rect = self.get_audio_dialog_rect()
        dlg_x = dlg_rect.x()
        dlg_y = dlg_rect.y()
        dlg_w = dlg_rect.width()
        dlg_h = dlg_rect.height()

        # 1. Close button
        close_btn_rect = QRect(dlg_x + dlg_w - 44, dlg_y + 16, 26, 26)
        if close_btn_rect.contains(int(mx), int(my)):
            self.set_audio_menu(False)
            return True

        # 2. Save / Resume button
        save_btn_rect = QRect(dlg_x + 36, dlg_y + 378, dlg_w - 72, 38)
        if save_btn_rect.contains(int(mx), int(my)):
            self.set_audio_menu(False)
            self.sound.play("pow_pickup")
            return True

        # 3. Test SFX button
        ch1_y = dlg_y + 152
        test_btn_rect = QRect(dlg_x + dlg_w - 168, ch1_y + 8, 86, 22)
        if test_btn_rect.contains(int(mx), int(my)):
            self.trigger_test_sfx()
            return True

        # 4. Presets
        preset_y = dlg_y + 310
        if QRect(dlg_x + 84, preset_y, 68, 26).contains(int(mx), int(my)):
            self.apply_audio_preset(0.0, 0.0, 0.0)
            return True
        if QRect(dlg_x + 158, preset_y, 84, 26).contains(int(mx), int(my)):
            self.apply_audio_preset(0.50, 0.50, 0.30)
            return True
        if QRect(dlg_x + 248, preset_y, 86, 26).contains(int(mx), int(my)):
            self.apply_audio_preset(0.20, 1.00, 0.75)
            return True
        if QRect(dlg_x + 340, preset_y, 88, 26).contains(int(mx), int(my)):
            self.apply_audio_preset(0.75, 0.20, 0.20)
            return True

        # 5. Channel strips & slider tracks
        ch_y_list = [dlg_y + 74, dlg_y + 152, dlg_y + 230]
        track_x = dlg_x + 36
        track_w = dlg_w - 72

        for ch_idx, ch_y in enumerate(ch_y_list):
            card_rect = QRect(dlg_x + 16, ch_y, dlg_w - 32, 68)
            slider_hit_rect = QRect(track_x - 12, ch_y + 32, track_w + 24, 32)

            if slider_hit_rect.contains(int(mx), int(my)):
                self.audio_selected_channel = ch_idx
                self.audio_slider_dragging = ch_idx
                val = max(0.0, min(1.0, (mx - track_x) / float(track_w)))
                self.adjust_channel_volume(ch_idx, absolute_val=val)
                return True
            elif card_rect.contains(int(mx), int(my)):
                self.audio_selected_channel = ch_idx
                self.sound.play("pow_pickup")
                self.update()
                return True
        return False

    def mouseMoveEvent(self, event):
        pos = event.position()
        mx, my = pos.x(), pos.y()
        self.mouse_cursor_pos = (int(mx), int(my))
        if self.state in ("playing", "takeoff", "landing", "boss_intro", "victory", "game_over"):
            prev_h = getattr(self, "matchup_badge_hovered", False)
            cur_h = self.get_matchup_badge_rect().contains(int(mx), int(my))
            if cur_h != prev_h:
                self.matchup_badge_hovered = cur_h
                self.update()

        if self.audio_menu_open and self.audio_slider_dragging is not None:
            dlg_rect = self.get_audio_dialog_rect()
            track_x = dlg_rect.x() + 36
            track_w = dlg_rect.width() - 72
            val = max(0.0, min(1.0, (mx - track_x) / float(track_w)))
            self.adjust_channel_volume(self.audio_slider_dragging, absolute_val=val)
            return

        if self.state == "hangar":
            col_w = (self.width() - 44) // 2
            row_h = 106
            if self.hangar_step == 1:
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]
                for i, k in enumerate(card_keys):
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 110 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)
                    if rect.contains(int(mx), int(my)):
                        if self.current_plane != k:
                            self.current_plane = k
                            self.showcase_tick = 0
                            self.update()
                        break
            elif self.hangar_step == 2:
                th_keys = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
                for i, tk in enumerate(th_keys):
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 110 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)
                    if rect.contains(int(mx), int(my)):
                        if getattr(self, "selected_theater", None) != tk:
                            self.selected_theater = tk
                            self.showcase_tick = 0
                            self.update()
                        break

        super().mouseMoveEvent(event)

    def mousePressEvent(self, event):
        pos = event.position()
        mx, my = int(pos.x()), int(pos.y())

        # If Help modal is open
        if getattr(self, "show_help_modal", False):
            h_rects = self.get_header_rects()
            if h_rects["modal_close"].contains(mx, my):
                self.set_help_modal(False)
            else:
                m_w, m_h = 440, 430
                m_x = (self.width() - m_w) // 2
                m_y = (self.height() - m_h) // 2
                modal_rect = QRect(m_x, m_y, m_w, m_h)
                if not modal_rect.contains(mx, my):
                    self.set_help_modal(False)
            return

        # If Audio Console is open
        if self.audio_menu_open:
            audio_btn = self.get_audio_button_rect()
            h_rects = self.get_header_rects()
            if audio_btn.contains(mx, my) or (self.state == "playing" and h_rects["sound"].contains(mx, my)):
                self.set_audio_menu(False)
                return
            self.handle_audio_menu_mouse(mx, my, is_press=True)
            return

        # Check Help button in Hangar
        if self.state == "hangar" and self.get_hangar_help_rect().contains(mx, my):
            self.toggle_help_modal()
            return

        # Check Template Header buttons in playing mode
        if self.state == "playing":
            h_rects = self.get_header_rects()
            if h_rects["help"].contains(mx, my):
                self.toggle_help_modal()
                return
            elif h_rects["pause"].contains(mx, my):
                self.toggle_pause()
                return
            elif h_rects["sound"].contains(mx, my):
                self.toggle_audio_menu()
                return
            elif h_rects["restart"].contains(mx, my):
                self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round)
                return
            elif h_rects["view_mode"].contains(mx, my):
                self.toggle_header_mode()
                return

        # Check Audio Console button in Hangar
        audio_btn_rect = self.get_audio_button_rect()
        if audio_btn_rect.contains(mx, my):
            self.toggle_audio_menu()
            return

        if self.state == "hangar":
            col_w = (self.width() - 44) // 2
            row_h = 106
            if self.hangar_step == 1:
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]
                for i, k in enumerate(card_keys):
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 110 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)
                    if rect.contains(int(mx), int(my)):
                        self.current_plane = k
                        self.hangar_step = 2
                        self.sound.play("pow_pickup")
                        self.banner_text = f"SELECTED {self.nation_info[k]['name']} • CHOOSE ENEMY THEATER"
                        self.banner_timer = 120
                        self.update()
                        return
            elif self.hangar_step == 2:
                th_keys = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
                for i, tk in enumerate(th_keys):
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 114 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)
                    if rect.contains(int(mx), int(my)):
                        self.start_transition(self.current_plane, tk, round_num=1)
                        return

        elif self.state == "transition":
            self.start_mission(self.current_plane, self.transition_target, round_num=1)
            return
        elif self.state == "round_clear":
            self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round + 1)
            return
        elif self.state == "game_over":
            panel_x = 24
            panel_w = self.width() - 48
            btn_retry = QRect(panel_x + 30, 96 + 635 - 100, panel_w - 60, 40)
            btn_hangar = QRect(panel_x + 30, 96 + 635 - 100 + 48, panel_w - 60, 36)
            if btn_hangar.contains(int(mx), int(my)):
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()
            else:
                self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round)
            return
        elif self.state == "victory":
            panel = QRect(28, 95, self.width() - 56, 620)
            btn_next_tour = QRect(panel.left() + 20, panel.bottom() - 92, panel.width() - 40, 38)
            btn_secret_mission = QRect(panel.left() + 20, panel.bottom() - 46, panel.width() - 40, 38)
            if btn_secret_mission.contains(int(mx), int(my)):
                self.state = "secret_briefing"
                self.sound.play("pow_pickup")
                self.sound.play_bgm("bgm_boss")
                self.update()
                return
            else:
                self.advance_to_next_campaign_theater()
                return
        elif self.state == "secret_briefing":
            self.state = "secret_select"
            self.sound.play("pow_pickup")
            self.update()
            return
        elif self.state == "secret_select":
            card1 = QRect(22, 74, self.width() - 44, 172)
            card2 = QRect(22, 258, self.width() - 44, 172)
            card3 = QRect(22, 442, self.width() - 44, 172)
            if card1.contains(int(mx), int(my)):
                self.start_secret_mission("ho229")
            elif card2.contains(int(mx), int(my)):
                self.start_secret_mission("b29")
            elif card3.contains(int(mx), int(my)):
                self.start_secret_mission("shinden")
            return
        elif self.state == "nuke_cutscene":
            self.sound.set_music_volume(0.40)
            self.state = "secret_defeat"
            self.sound.play_bgm("bgm_defeat")
            self.update()
            return
        elif self.state in ("secret_victory", "secret_defeat"):
            self.advance_to_next_campaign_theater()
            return
        elif self.state == "playing":
            if self.is_paused:
                self.toggle_pause()
                return
            if event.button() == Qt.LeftButton:
                self.is_fire_held = True
                self.trigger_fire()
            elif event.button() == Qt.RightButton:
                self.cycle_weapon()

    def mouseReleaseEvent(self, event):
        if self.audio_slider_dragging is not None:
            self.audio_slider_dragging = None
            self.update()
        if event.button() == Qt.LeftButton:
            self.is_fire_held = False

    def leaveEvent(self, event):
        self.mouse_cursor_pos = None
        if getattr(self, "matchup_badge_hovered", False):
            self.matchup_badge_hovered = False
            self.update()
        super().leaveEvent(event)

    def cycle_weapon(self):
        if self.is_secret_mission:
            self.banner_text = "★ ALL COMBAT WEAPONS ARMED SIMULTANEOUSLY BY GENERAL DIRECTIVE! ★"
            self.banner_timer = 80
            self.sound.play("pow_pickup")
            self.update()
            return
        self.weapon_idx = (self.weapon_idx + 1) % len(self.weapons)
        w_key = self.weapons[self.weapon_idx]
        w_name = self.weapon_names[self.current_plane][w_key]
        self.banner_text = f"ARMAMENT: {w_name}"
        self.banner_timer = 80
        self.sound.play("pow_pickup")
        self.update()

    def keyPressEvent(self, event):
        key = event.key()

        # [Shift+F] or [F11] toggles header view mode (mini vs standard) anywhere
        if (event.modifiers() & Qt.ShiftModifier and key == Qt.Key_F) or key == Qt.Key_F11:
            self.toggle_header_mode()
            return

        # [H] or [?] toggles Help Modal anywhere (or returns to hangar if in game_over)
        if key == Qt.Key_H or key == Qt.Key_Question or (key == Qt.Key_Slash and (event.modifiers() & Qt.ShiftModifier)):
            if self.state == "game_over":
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()
                return
            else:
                self.toggle_help_modal()
                return

        # [M] or [O] toggles the Audio Console anywhere
        if key in (Qt.Key_M, Qt.Key_O):
            self.toggle_audio_menu()
            return

        # If Help modal is open, dismiss it on Escape/Enter/Space
        if getattr(self, "show_help_modal", False):
            if key in (Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
                self.set_help_modal(False)
                return
            return

        # If Audio console is open, handle keys
        if self.audio_menu_open:
            if key in (Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter):
                self.set_audio_menu(False)
                return
            elif key in (Qt.Key_Up, Qt.Key_W):
                self.audio_selected_channel = (self.audio_selected_channel - 1) % 3
                self.sound.play("pow_pickup")
                self.update()
                return
            elif key in (Qt.Key_Down, Qt.Key_S):
                self.audio_selected_channel = (self.audio_selected_channel + 1) % 3
                self.sound.play("pow_pickup")
                self.update()
                return
            elif key in (Qt.Key_Left, Qt.Key_A):
                self.adjust_channel_volume(self.audio_selected_channel, delta=-0.05)
                return
            elif key in (Qt.Key_Right, Qt.Key_D):
                self.adjust_channel_volume(self.audio_selected_channel, delta=+0.05)
                return
            elif key == Qt.Key_1:
                self.audio_selected_channel = 0
                self.update()
                return
            elif key == Qt.Key_2:
                self.audio_selected_channel = 1
                self.update()
                return
            elif key == Qt.Key_3:
                self.audio_selected_channel = 2
                self.update()
                return
            elif key == Qt.Key_T:
                self.trigger_test_sfx()
                return
            return

        if key == Qt.Key_Escape:
            if self.is_paused:
                self.is_paused = False
                self.paused_by_menu = False
                self.sound.play("pow_pickup")
                self.update()
                return
            elif self.state == "hangar" and self.hangar_step == 2:
                self.hangar_step = 1
                self.update()
                return
            elif self.state == "playing":
                self.toggle_pause()
                return
            elif self.state in ("victory", "game_over"):
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()
                return
            else:
                self.close()
        elif self.state == "hangar":
            if self.hangar_step == 1:
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]
                cur_idx = card_keys.index(self.current_plane) if self.current_plane in card_keys else 0
                if key in (Qt.Key_Left, Qt.Key_Right):
                    cur_idx = cur_idx ^ 1
                    self.current_plane = card_keys[cur_idx]
                    self.sound.play("pow_pickup")
                    self.update()
                    return
                elif key == Qt.Key_Up:
                    if cur_idx >= 2:
                        cur_idx -= 2
                        self.current_plane = card_keys[cur_idx]
                        self.sound.play("pow_pickup")
                        self.update()
                    return
                elif key == Qt.Key_Down:
                    if cur_idx + 2 < len(card_keys):
                        cur_idx += 2
                        self.current_plane = card_keys[cur_idx]
                        self.sound.play("pow_pickup")
                        self.update()
                    return
                elif key in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
                    self.hangar_step = 2
                    self.sound.play("pow_pickup")
                    self.banner_text = f"SELECTED {self.nation_info[self.current_plane]['name']} • CHOOSE ENEMY THEATER"
                    self.banner_timer = 120
                    self.update()
                    return

                key_map = {
                    Qt.Key_1: "p38", Qt.Key_2: "zero", Qt.Key_3: "spitfire",
                    Qt.Key_4: "bf109", Qt.Key_5: "yak3", Qt.Key_6: "mosquito",
                    Qt.Key_7: "folgore", Qt.Key_8: "d520", Qt.Key_9: "pzl11",
                    Qt.Key_0: "avia"
                }
                if key in key_map:
                    self.current_plane = key_map[key]
                    self.hangar_step = 2
                    self.sound.play("pow_pickup")
                    self.banner_text = f"SELECTED {self.nation_info[self.current_plane]['name']} • CHOOSE ENEMY THEATER"
                    self.banner_timer = 120
                    self.update()
            elif self.hangar_step == 2:
                th_keys = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
                if not hasattr(self, "selected_theater") or self.selected_theater not in th_keys:
                    self.selected_theater = self.nation_info[self.current_plane]["default_rival"]
                cur_idx = th_keys.index(self.selected_theater) if self.selected_theater in th_keys else 0

                if key in (Qt.Key_Left, Qt.Key_Right):
                    cur_idx = cur_idx ^ 1
                    self.selected_theater = th_keys[cur_idx]
                    self.sound.play("pow_pickup")
                    self.update()
                    return
                elif key == Qt.Key_Up:
                    if cur_idx >= 2:
                        cur_idx -= 2
                        self.selected_theater = th_keys[cur_idx]
                        self.sound.play("pow_pickup")
                        self.update()
                    return
                elif key == Qt.Key_Down:
                    if cur_idx + 2 < len(th_keys):
                        cur_idx += 2
                        self.selected_theater = th_keys[cur_idx]
                        self.sound.play("pow_pickup")
                        self.update()
                    return
                elif key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter):
                    self.start_transition(self.current_plane, self.selected_theater, round_num=1)
                    return
                elif key in (Qt.Key_Backspace, Qt.Key_Escape):
                    self.hangar_step = 1
                    self.update()
                    return
                else:
                    th_map = {
                        Qt.Key_1: "imperial", Qt.Key_2: "allied", Qt.Key_3: "luftwaffe",
                        Qt.Key_4: "raf", Qt.Key_5: "vvs", Qt.Key_6: "canada",
                        Qt.Key_7: "mediterranean", Qt.Key_8: "france", Qt.Key_9: "poland",
                        Qt.Key_0: "czech"
                    }
                    if key in th_map:
                        self.selected_theater = th_map[key]
                        self.start_transition(self.current_plane, th_map[key], round_num=1)

        elif self.state == "transition":
            th_keys = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
            card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]

            if key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter):
                self.start_mission(self.current_plane, self.transition_target, round_num=1)
            elif key in (Qt.Key_Escape, Qt.Key_Backspace):
                self.state = "hangar"
                self.hangar_step = 2
                self.sound.play_bgm("bgm_hangar")
                self.update()
            elif key in (Qt.Key_Left, Qt.Key_Right):
                # Cycle enemy theater destination
                cur_t_idx = th_keys.index(self.transition_target) if self.transition_target in th_keys else 0
                step = 1 if key == Qt.Key_Right else -1
                self.transition_target = th_keys[(cur_t_idx + step) % len(th_keys)]
                self.transition_t = 0.0
                self.sound.play("pow_pickup")
                self.update()
            elif key in (Qt.Key_Up, Qt.Key_Down):
                # Cycle player fighter plane
                cur_p_idx = card_keys.index(self.current_plane) if self.current_plane in card_keys else 0
                step = -1 if key == Qt.Key_Up else 1
                self.current_plane = card_keys[(cur_p_idx + step) % len(card_keys)]
                self.transition_origin = self.current_plane
                self.transition_t = 0.0
                self.build_showcase_for_plane(self.current_plane)
                self.sound.play("pow_pickup")
                self.update()
            else:
                th_map = {
                    Qt.Key_1: "imperial", Qt.Key_2: "allied", Qt.Key_3: "luftwaffe",
                    Qt.Key_4: "raf", Qt.Key_5: "vvs", Qt.Key_6: "canada",
                    Qt.Key_7: "mediterranean", Qt.Key_8: "france", Qt.Key_9: "poland",
                    Qt.Key_0: "czech"
                }
                if key in th_map:
                    self.transition_target = th_map[key]
                    self.transition_t = 0.0
                    self.sound.play("pow_pickup")
                    self.update()

        elif self.state == "round_clear":
            if key in (Qt.Key_Space, Qt.Key_Return):
                self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round + 1)
            elif key in (Qt.Key_Escape, Qt.Key_Backspace):
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()

        elif self.state == "game_over":
            if key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_R):
                self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round)
            elif key in (Qt.Key_Escape, Qt.Key_H, Qt.Key_Backspace):
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()

        elif self.state == "victory":
            if key == Qt.Key_S:
                self.state = "secret_briefing"
                self.sound.play("pow_pickup")
                self.sound.play_bgm("bgm_boss")
                self.update()
                return
            elif key in (Qt.Key_Space, Qt.Key_Return):
                self.advance_to_next_campaign_theater()
                return
            elif key == Qt.Key_Escape:
                self.state = "hangar"
                self.hangar_step = 1
                self.sound.play_bgm("bgm_hangar")
                self.update()
                return

        elif self.state == "secret_briefing":
            if key in (Qt.Key_Space, Qt.Key_Return):
                self.state = "secret_select"
                self.sound.play("pow_pickup")
                self.update()
            elif key == Qt.Key_Escape:
                self.state = "victory"
                self.update()
            return

        elif self.state == "secret_select":
            if key == Qt.Key_1:
                self.start_secret_mission("ho229")
            elif key == Qt.Key_2:
                self.start_secret_mission("b29")
            elif key == Qt.Key_3:
                self.start_secret_mission("shinden")
            elif key in (Qt.Key_Escape, Qt.Key_Backspace):
                self.state = "secret_briefing"
                self.sound.play("pow_pickup")
                self.update()
            return

        elif self.state == "nuke_cutscene":
            if key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_Escape):
                self.sound.set_music_volume(0.40)
                self.state = "secret_defeat"
                self.sound.play_bgm("bgm_defeat")
                self.update()
                return
        elif self.state in ("secret_victory", "secret_defeat"):
            if key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_Escape):
                self.advance_to_next_campaign_theater()
                return

        elif self.state == "playing":
            if key == Qt.Key_C:
                if self.air_support_ready and not self.air_support_active:
                    self.summon_air_support()
                    return
            if key == Qt.Key_P:
                self.toggle_pause()
                return
            if key == Qt.Key_R:
                self.start_mission(self.current_plane, self.enemy_theater, round_num=self.current_round)
                return
            elif self.is_paused:
                if key in (Qt.Key_Escape, Qt.Key_Space, Qt.Key_Return):
                    self.is_paused = False
                    self.paused_by_menu = False
                    self.sound.play("pow_pickup")
                    self.update()
                return
            elif key in (Qt.Key_Q, Qt.Key_E):
                self.cycle_weapon()
            elif key == Qt.Key_Tab or key == Qt.Key_0:
                # Cycle player aircraft in flight
                curr_idx = self.factions.index(self.current_plane) if self.current_plane in self.factions else 0
                self.current_plane = self.factions[(curr_idx + 1) % len(self.factions)]
                self.banner_text = f"★ HOT-SWAPPED AIRCRAFT: {self.nation_info[self.current_plane]['name']} ★"
                self.banner_timer = 90
            elif key in (Qt.Key_Space, Qt.Key_Return):
                self.trigger_loop()
            elif key == Qt.Key_B:
                self.trigger_mega_crash()
            elif key == Qt.Key_L:
                if not self.is_looping and self.death_ticks == 0:
                    self.state = "landing"
                    self.landing_tick = 0
            elif key in (Qt.Key_Z, Qt.Key_X, Qt.Key_V, Qt.Key_F, Qt.Key_Control, Qt.Key_Meta):
                self.keys.add(key)
                self.is_fire_held = True
                self.trigger_fire()
            else:
                self.keys.add(key)
        else:
            self.keys.add(key)

    def keyReleaseEvent(self, event):
        key = event.key()
        if key in self.keys:
            self.keys.remove(key)
        if key in (Qt.Key_Z, Qt.Key_X, Qt.Key_V, Qt.Key_F, Qt.Key_Control, Qt.Key_Meta):
            self.is_fire_held = False

    def game_loop(self):
        if self.audio_menu_open or self.is_paused or getattr(self, "show_help_modal", False):
            if hasattr(self, "prop_audio"):
                self.prop_audio.update_flight_telemetry(
                    plane_id=self.current_plane,
                    flight_state="playing" if self.state in ("takeoff", "playing", "landing") else "hangar",
                    throttle_input=0.0,
                    bank_angle=0.0,
                    is_looping=False,
                    loop_tick=0,
                    takeoff_tick=0,
                    landing_tick=0,
                    is_muted=True
                )
            self.update()
            if self.state in ("takeoff", "playing", "landing"):
                return
        if self.state == "hangar":
            self.showcase_tick += 1
            self.update()
            return

        if self.state == "nuke_cutscene":
            for s in list(self.smoke_particles):
                s["x"] += s["vx"]
                s["y"] += s["vy"]
                s["life"] -= 1
                if s["life"] <= 0:
                    self.smoke_particles.remove(s)
            for exp in list(self.explosions):
                exp["life"] -= 1
                if exp["life"] <= 0:
                    self.explosions.remove(exp)
            self.update_nuke_cutscene()
            self.update()
            return

        self.prop_tick += 1
        self.ocean_y = (self.ocean_y + 4) % 48
        self.world_scroll_y += self.terrain_speed

        if self.banner_timer > 0:
            self.banner_timer -= 1
        if self.mega_crash_ticks > 0:
            self.mega_crash_ticks -= 1
        if self.screen_shake > 0:
            self.screen_shake -= 1
        if self.invulnerable_ticks > 0:
            self.invulnerable_ticks -= 1
        if self.hit_flash_ticks > 0:
            self.hit_flash_ticks -= 1

        p_info = self.nation_info[self.current_plane]

        # Update scenery
        for c in self.clouds:
            c["y"] += c["speed"]
            if c["y"] > self.height() + 180:
                fresh = self.spawn_cloud(y=-random.randint(120, 260))
                c.update(fresh)

        # Islands only exist at high cruising altitude in Round 2 (Coastal Ocean)
        # NEVER in Round 1 (pure cloud floor) or Round 3 (mainland terrain)
        # NEVER near carrier (preserves scale)
        carrier_on_screen = (self.carrier_y > -750 and self.carrier_y < self.height() + 250) or self.state in ("takeoff", "landing")
        if carrier_on_screen or self.current_round in (1, 3):
            self.islands.clear()
        elif self.state == "playing" and self.current_round == 2:
            alive_islands = []
            for isl in self.islands:
                isl["y"] += isl["speed"]
                if isl["y"] <= self.height() + 250:
                    alive_islands.append(isl)
            self.islands = alive_islands

            self.island_spawn_timer += 1
            if self.island_spawn_timer >= 320 and len(self.islands) < 2:
                # Spawn in open dead space away from all active warships
                lane_candidates = [80, 160, 480, 560]
                random.shuffle(lane_candidates)
                chosen_isl_x = None
                for cx in lane_candidates:
                    if not any(abs(w["x"] - cx) < 130 and w["y"] < 320 for w in self.warships):
                        chosen_isl_x = cx
                        break

                if chosen_isl_x is not None:
                    self.island_spawn_timer = 0
                    active_islands = self.pacific_island_pixmaps
                    if self.enemy_theater == "imperial":
                        active_islands = self.japan_island_pixmaps
                    elif self.enemy_theater in ("raf", "luftwaffe"):
                        active_islands = self.uk_island_pixmaps
                    elif self.enemy_theater in ("canada", "vvs"):
                        active_islands = self.arctic_island_pixmaps

                    t_count = len(active_islands) if active_islands else 1
                    self.islands.append({
                        "x": chosen_isl_x,
                        "y": -random.randint(300, 460),
                        "speed": 0.85,
                        "type": random.randint(0, t_count - 1),
                        "flip_h": random.choice([True, False]),
                        "scale": random.uniform(0.85, 1.1)
                    })

        # ---------------------------------------------------------------------
        # STATE: TRANSITION SCREEN (STREET FIGHTER WORLD TOUR)
        # ---------------------------------------------------------------------
        if self.state == "transition":
            self.takeoff_tick += 1
            self.showcase_tick += 1
            if self.transition_t < 1.0:
                self.transition_t = min(1.0, self.transition_t + 0.015)
                if self.transition_t >= 1.0:
                    self.sound.play("pow_pickup")
            self.update()
            return

        elif self.state in ("round_clear", "victory", "game_over"):
            self.takeoff_tick += 1
            self.update()
            return

        # ---------------------------------------------------------------------
        # STATE: TAKEOFF SEQUENCE
        # ---------------------------------------------------------------------
        elif self.state == "takeoff":
            self.takeoff_tick += 1
            self.bank_angle = 0.0
            self.x = self.width() // 2

            if self.takeoff_tick < 40:
                # 1. Parked on carrier deck over deep ocean
                self.carrier_y = 140
                self.y = 520
            elif self.takeoff_tick < 110:
                # 2. Acceleration run down flight deck & lift-off
                progress = (self.takeoff_tick - 40) / 70.0
                self.y = 520 - int(70 * (progress ** 1.5))
                self.carrier_y = 140 + int(750 * (progress ** 1.6))
            elif self.takeoff_tick < 160:
                # 3. Climbing to elevation over open ocean
                self.y += (480 - self.y) * 0.08
                self.carrier_y = -9999
            elif self.takeoff_tick < 390:
                # 4. Enveloped in cloud cover:
                #    160..210 (clouds roll in)
                #    210..390 (3 full seconds of solid cloud cover at 60 FPS)
                self.y += (480 - self.y) * 0.08
                self.carrier_y = -9999
            elif self.takeoff_tick < 450:
                # 5. Clouds dissipating, emerging over land
                self.y += (480 - self.y) * 0.08
                self.carrier_y = -9999
            else:
                # 6. Mission flight control over land
                self.state = "playing"
                self.y = 480
                self.carrier_y = -9999

        # ---------------------------------------------------------------------
        # STATE: LANDING SEQUENCE & WIRE CATCH
        # ---------------------------------------------------------------------
        elif self.state == "landing":
            self.landing_tick += 1
            self.bank_angle = 0.0
            target_carrier_y = 60
            self.carrier_y += (target_carrier_y - self.carrier_y) * 0.10

            stern_y = self.carrier_y + 440
            touchdown_y = self.carrier_y + 340
            halt_y = self.carrier_y + 200

            if self.landing_tick < 40:
                self.x += (self.width() // 2 - self.x) * 0.15
                self.y = max(self.y, stern_y + 120)
            elif self.landing_tick < 95:
                prog = (self.landing_tick - 40) / 55.0
                self.x = self.width() // 2
                self.y = (stern_y + 120) - ((stern_y + 120) - touchdown_y) * prog
            elif self.landing_tick < 140:
                if self.landing_tick == 95:
                    self.sound.play("carrier_touchdown")
                    self.screen_shake = 7
                prog = (self.landing_tick - 95) / 45.0
                brake_prog = 1.0 - (1.0 - prog) ** 2
                self.x = self.width() // 2
                self.y = touchdown_y - (touchdown_y - halt_y) * brake_prog
            elif self.landing_tick < 190:
                self.x = self.width() // 2
                self.y = halt_y
                if self.hp < self.max_hp:
                    self.hp = self.max_hp
            else:
                # Transition after carrier recovery
                if self.is_secret_mission:
                    self.state = "secret_victory"
                    self.sound.play("victory_fanfare")
                elif self.current_round < 3:
                    self.state = "round_clear"
                    self.lives = min(3, self.lives + 1)
                    self.sound.play("victory_fanfare")
                else:
                    self.state = "victory"
                    self.sound.play("victory_fanfare")

        # ---------------------------------------------------------------------
        # STATE: PLAYING
        # ---------------------------------------------------------------------
        elif self.state == "playing":
            self.mission_ticks += 1

            moving_left = any(k in self.keys for k in [Qt.Key_Left, Qt.Key_A])
            moving_right = any(k in self.keys for k in [Qt.Key_Right, Qt.Key_D])
            moving_up = any(k in self.keys for k in [Qt.Key_Up, Qt.Key_W])
            moving_down = any(k in self.keys for k in [Qt.Key_Down, Qt.Key_S])

            # Death Spiral
            if self.death_ticks > 0:
                if self.death_ticks == 1:
                    self.sound.play("plane_falling")
                self.death_ticks += 1
                self.y += 3.6
                self.x += math.sin(self.death_ticks * 0.22) * 3.8
                for _ in range(3):
                    self.smoke_particles.append({
                        "x": self.x + random.randint(-18, 18), "y": self.y + random.randint(-10, 20),
                        "vx": random.uniform(-1.5, 1.5), "vy": random.uniform(1.0, 4.0),
                        "rad": 8, "max_rad": 24, "life": 18, "type": "fire"
                    })
                if self.death_ticks >= 80:
                    self.sound.play("explosion_large")
                    for _ in range(5):
                        self.explosions.append({
                            "x": self.x + random.randint(-25, 25), "y": self.y + random.randint(-20, 20),
                            "radius": 24, "max_radius": 56, "life": 24
                        })
                    self.screen_shake = 14
                    self.death_ticks = 0

                    if self.is_secret_mission:
                        self.trigger_failsafe_detonation(self.x, self.y, self.nation_info[self.current_plane]["name"])
                        self.start_nuke_cutscene()
                        self.update()
                        return

                    if self.lives > 1:
                        # Deduct 1 life and scramble reserve fighter
                        self.lives -= 1
                        self.x = self.width() // 2
                        self.y = self.height() - 140
                        self.hp = self.max_hp
                        self.invulnerable_ticks = 150  # 2.5s flashing shield
                        self.hit_flash_ticks = 0
                        self.bank_angle = 0.0
                        self.enemy_bullets.clear()  # clear airspace for safe recovery
                        self.bombs_remaining = max(self.bombs_remaining, 2)
                        self.loops_remaining = max(self.loops_remaining, 2)
                        self.banner_text = f"★ SORTIE REINFORCEMENT! {self.lives} AIRFRAME{'S' if self.lives > 1 else ''} REMAINING! ★"
                        self.banner_timer = 120
                        self.sound.play("pow_pickup")
                        self.sound.play_bgm("bgm_patrol")
                    else:
                        self.lives = 0
                        self.state = "game_over"
                        self.sound.play_bgm("bgm_defeat")
                    self.update()
                self.update()
                return

            # Loop maneuver progression
            if self.is_looping:
                self.loop_tick += 1
                if self.loop_tick >= len(self.loop_stages) * 5:
                    self.is_looping = False
                    self.loop_tick = 0

            # Flight Time Tracking
            self.stats["flight_ticks"] = self.stats.get("flight_ticks", 0) + 1

            # Controls
            dx = 0.0
            dy = 0.0
            if moving_left: dx -= p_info["speed"]
            if moving_right: dx += p_info["speed"]
            if moving_up: dy -= p_info["speed"]
            if moving_down: dy += p_info["speed"]

            self.x = max(38, min(self.width() - 38, self.x + dx))
            self.y = max(60, min(self.height() - 70, self.y + dy))

            # Banking
            target_bank = 0.0
            if moving_left: target_bank = -28.0
            elif moving_right: target_bank = 28.0
            bank_speed = p_info.get("bank", 0.35)
            self.bank_angle += (target_bank - self.bank_angle) * bank_speed

            # Damage smoke trails on player airframe
            if self.hp < self.max_hp and not self.is_looping and random.random() < 0.70:
                engine_ox = -16 if random.random() < 0.5 else 16
                if self.hp == 3 and random.random() < 0.45:
                    self.smoke_particles.append({"x": self.x + engine_ox, "y": self.y + 24, "vx": random.uniform(-0.5, 0.5), "vy": random.uniform(2.5, 4.5), "rad": 6, "max_rad": 16, "life": 22, "type": "vapor"})
                elif self.hp == 2:
                    self.smoke_particles.append({"x": self.x + engine_ox, "y": self.y + 22, "vx": random.uniform(-0.8, 0.8), "vy": random.uniform(3.0, 5.5), "rad": 8, "max_rad": 26, "life": 28, "type": "black_smoke"})
                elif self.hp == 1:
                    for _ in range(2):
                        self.smoke_particles.append({"x": self.x + engine_ox, "y": self.y + 16, "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.5, 6.0), "rad": 7, "max_rad": 20, "life": 16, "type": "fire"})

            # Auto-fire
            if self.is_fire_held and not self.is_looping and self.death_ticks == 0:
                if self.fire_cooldown <= 0:
                    self.trigger_fire()
                    self.fire_cooldown = 5
            if self.fire_cooldown > 0:
                self.fire_cooldown -= 1

            # Enemy & Boss Spawning Logic for Active Theater
            enemy_faction = self.enemy_theater
            theater_data = self.theaters[enemy_faction]

            if self.is_secret_mission:
                # EXACTLY 1 HEALTH REPAIR KIT EVERY 20 SECONDS (1200 TICKS)
                if self.mission_ticks >= self.secret_next_health_tick and self.mission_ticks < 7100:
                    self.secret_next_health_tick += 1200
                    cx = random.randint(160, self.width() - 160)
                    self.pickups.append({"x": cx, "y": -30, "vy": 1.8, "type": "repair"})
                    self.sound.play("powerup")
                    self.banner_text = "★ ALLIED AIR-DROP: FIELD REPAIR KIT DEPLOYED! ★"
                    self.banner_timer = 110

                # SQUADRONS OF EVERY PLANE (10 National + 8 Unsung Fighters)
                if self.secret_squadron_index < len(self.secret_squadron_plan):
                    s_tick, s_plane, s_title = self.secret_squadron_plan[self.secret_squadron_index]
                    if self.mission_ticks >= s_tick:
                        self.secret_squadron_index += 1
                        self.spawn_secret_squadron(s_plane, s_title)

                # 4 BOSS FLEETS EVENLY DISTRIBUTED ACROSS THE 2 MINUTES
                if self.secret_boss_index < len(self.secret_boss_schedule):
                    b_tick, b_key = self.secret_boss_schedule[self.secret_boss_index]
                    if self.mission_ticks >= b_tick:
                        if not (self.boss and self.boss.get("active")):
                            self.secret_boss_index += 1
                            self.spawn_secret_cartel_boss(b_key)

                # AT 2 MINUTES (7,200 TICKS): FINAL OBJECTIVE UNDERGROUND HANGAR DEPOT COMPLEX
                if self.mission_ticks >= 7200 and not self.cartel_hangar:
                    self.cartel_hangar = {
                        "x": float(self.width() // 2),
                        "y": -220.0,
                        "target_y": 240.0,
                        "vy": 1.4,
                        "hp": 900,
                        "max_hp": 900,
                        "width": 440,
                        "height": 440,
                        "hit_flash": 0,
                        "active": True,
                        "exploding": False,
                        "explosion_ticks": 0,
                        "turrets": [
                            {"ox": -140, "oy": -80, "hp": 80, "fire_tick": random.randint(10, 35), "active": True},
                            {"ox": 140, "oy": -80, "hp": 80, "fire_tick": random.randint(20, 45), "active": True},
                            {"ox": -100, "oy": 70, "hp": 90, "fire_tick": random.randint(15, 40), "active": True},
                            {"ox": 100, "oy": 70, "hp": 90, "fire_tick": random.randint(25, 50), "active": True},
                            {"ox": 0, "oy": -110, "hp": 120, "fire_tick": random.randint(5, 30), "active": True},
                        ]
                    }
                    self.sound.play("failsafe_alarm")
                    self.banner_text = "⚠ CARTEL UNDERGROUND WEAPONS DEPOT REACHED! OBLITERATE THE HANGAR COMPLEX! ⚠"
                    self.banner_timer = 200
                    self.screen_shake = 24

                # Update Cartel Underground Hangar Complex
                if self.cartel_hangar and self.cartel_hangar.get("active"):
                    h = self.cartel_hangar
                    if h.get("hit_flash", 0) > 0:
                        h["hit_flash"] -= 1

                    if h["y"] < h["target_y"]:
                        h["y"] += h["vy"]

                    if h.get("exploding"):
                        h["explosion_ticks"] += 1
                        if h["explosion_ticks"] % 3 == 0:
                            self.explosions.append({
                                "x": h["x"] + random.randint(-180, 180),
                                "y": h["y"] + random.randint(-160, 160),
                                "radius": random.randint(24, 38),
                                "max_radius": random.randint(65, 90),
                                "life": random.randint(20, 36)
                            })
                            self.screen_shake = max(self.screen_shake, 14)
                        if h["explosion_ticks"] % 18 == 0:
                            self.sound.play("boss_defeat")
                        if h["explosion_ticks"] >= 140:
                            h["active"] = False
                            self.sound.play_bgm("bgm_victory")
                            self.banner_text = "★ MISSION ACCOMPLISHED: BLACKOUT OPERATION COMPLETE! ★"
                            self.banner_timer = 200
                            self.state = "landing"
                            self.landing_tick = 0
                    else:
                        for t in h.get("turrets", []):
                            if t.get("active", True):
                                t["fire_tick"] += 1
                                if t["fire_tick"] >= 65:
                                    t["fire_tick"] = random.randint(0, 20)
                                    tx = h["x"] + t["ox"]
                                    ty = h["y"] + t["oy"]
                                    if 0 < ty < self.height():
                                        dx = self.x - tx
                                        dy = self.y - ty
                                        dist = math.hypot(dx, dy) or 1.0
                                        spd = 3.6
                                        self.enemy_bullets.append({
                                            "x": tx, "y": ty,
                                            "vx": (dx / dist) * spd,
                                            "vy": (dy / dist) * spd,
                                            "type": "flak"
                                        })
                                        self.sound.play("turret_fire")
            else:
                # EXACTLY 3 HEALTH POWERUPS PER BATTLE:
                # Drop 1: Spaced at 1/3rd of the way through the battle
                # Drop 2: Spaced at 2/3rds of the way through the battle
                # Drop 3: The last or second-to-last enemy before the boss arrives
                tick_1_3 = self.boss_target_ticks // 3
                tick_2_3 = (self.boss_target_ticks * 2) // 3
                tick_pre_boss = self.boss_target_ticks - 140

                health_slot = None
                if self.mission_ticks >= tick_pre_boss and not self.health_drops_spawned[2]:
                    health_slot = 2
                elif self.mission_ticks >= tick_2_3 and not self.health_drops_spawned[1]:
                    health_slot = 1
                elif self.mission_ticks >= tick_1_3 and not self.health_drops_spawned[0]:
                    health_slot = 0

                if health_slot is not None and not self.boss_spawned:
                    self.health_drops_spawned[health_slot] = True
                    labels = {
                        0: "STAGE 1/3 SUPPLY ESCORT INBOUND",
                        1: "STAGE 2/3 SUPPLY ESCORT INBOUND",
                        2: "FINAL PRE-BOSS SUPPLY ESCORT INBOUND"
                    }
                    cx = random.randint(160, self.width() - 160)
                    self.enemies.append({
                        "x": cx, "y": -50, "vx": 0, "vy": 2.2, "hp": 8,
                        "faction": enemy_faction, "type": "bomber", "hit_flash": 0,
                        "guaranteed_drop": "repair"
                    })
                    self.banner_text = f"⚠ {labels[health_slot]}: DESTROY FOR REPAIR CRATE! ⚠"
                    self.banner_timer = 130

            # Boss Spawns:
            if not self.is_secret_mission and self.mission_ticks >= self.boss_target_ticks and not self.boss_spawned:
                self.boss_spawned = True
                self.sound.play_bgm("bgm_boss")
                boss_name = theater_data["boss_name"]
                hp_scale = {1: 220, 2: 280, 3: 360}
                hp_val = hp_scale.get(self.current_round, 240)
                round_titles = {
                    1: f"{theater_data['boss_title']} [ROUND I: PATROL]",
                    2: f"{theater_data['boss_title']} [ROUND II: ARMORED FLEET]",
                    3: f"{theater_data['boss_title']} [ROUND III: SUPREME FLAGSHIP]"
                }
                boss_title = round_titles.get(self.current_round, theater_data["boss_title"])
                self.banner_text = theater_data["banner"]
                turrets = theater_data["turrets"]

                self.banner_timer = 150
                # Clear all stray bullets and missiles so sky is clear for boss grand entrance
                self.bullets.clear()
                self.missiles.clear()
                self.enemy_bullets.clear()

                self.boss = {
                    "name": boss_name,
                    "title": boss_title,
                    "faction": enemy_faction,
                    "x": self.width() // 2, "y": -160, "target_y": 205,
                    "hp": hp_val, "max_hp": hp_val, "active": True,
                    "vulnerable": False,
                    "fire_tick": 0, "turrets": turrets,
                    "damage_stage": 0,
                }

            if not self.boss_spawned or self.is_secret_mission:
                # Enemy aircraft swarms across all rounds (In secret mission, swarms NEVER stop!)
                self.spawn_tick += 1
                freq = 10 if self.is_secret_mission else (70 if self.current_round == 1 else (95 if self.current_round == 2 else 85))
                if self.spawn_tick >= freq:
                    self.spawn_tick = 0
                    if self.is_secret_mission:
                        # Stolen cartel armada: Every plane in the game! (10 national fighters + 8 unsung warbirds)
                        pool = [
                            "p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia",
                            "hurricane", "p39", "ki43", "hs129", "i16", "cr42", "ms406", "beaufighter"
                        ]
                        def get_ef(): return random.choice(pool)
                    else:
                        def get_ef(): return enemy_faction

                    if self.is_secret_mission:
                        pattern = random.choice(["v_formation_5", "sweep_3", "pincer_4", "heavy_dual", "strafers"])
                    else:
                        pattern = random.choice(["v_formation", "sweep", "pincer", "heavy"])

                    if pattern == "v_formation_5":
                        center_x = random.randint(140, self.width() - 140)
                        for ox, oy in [(0, -40), (-45, -75), (45, -75), (-90, -110), (90, -110)]:
                            self.enemies.append({"x": center_x + ox, "y": oy, "vx": 0, "vy": 5.4, "hp": 4, "faction": get_ef(), "type": "scout", "hit_flash": 0})
                    elif pattern == "sweep_3":
                        start_x = random.choice([60, self.width() - 60])
                        vx = 3.6 if start_x < self.width() // 2 else -3.6
                        for oy in [-30, -65, -100]:
                            self.enemies.append({"x": start_x, "y": oy, "vx": vx, "vy": 6.2, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                    elif pattern == "pincer_4":
                        self.enemies.append({"x": 30, "y": -30, "vx": 3.4, "vy": 5.6, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": self.width() - 30, "y": -30, "vx": -3.4, "vy": 5.6, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": 70, "y": -65, "vx": 3.0, "vy": 5.6, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": self.width() - 70, "y": -65, "vx": -3.0, "vy": 5.6, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                    elif pattern == "heavy_dual":
                        bx1 = random.randint(110, 240)
                        bx2 = random.randint(320, self.width() - 110)
                        b_fac = random.choice(["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "france"])
                        self.enemies.append({"x": bx1, "y": -70, "vx": random.uniform(-0.4, 0.4), "vy": 3.2, "hp": 18, "faction": b_fac, "type": "bomber", "hit_flash": 0})
                        self.enemies.append({"x": bx2, "y": -70, "vx": random.uniform(-0.4, 0.4), "vy": 3.2, "hp": 18, "faction": b_fac, "type": "bomber", "hit_flash": 0})
                    elif pattern == "strafers":
                        sx = random.randint(80, self.width() - 80)
                        for oy in [-30, -70, -110]:
                            self.enemies.append({"x": sx + random.randint(-25, 25), "y": oy, "vx": random.uniform(-1.5, 1.5), "vy": 6.4, "hp": 4, "faction": get_ef(), "type": "scout", "hit_flash": 0})
                    elif pattern == "v_formation":
                        center_x = random.randint(140, self.width() - 140)
                        self.enemies.append({"x": center_x, "y": -40, "vx": 0, "vy": 3.8, "hp": 3, "faction": get_ef(), "type": "scout", "hit_flash": 0})
                        self.enemies.append({"x": center_x - 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": get_ef(), "type": "scout", "hit_flash": 0})
                        self.enemies.append({"x": center_x + 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": get_ef(), "type": "scout", "hit_flash": 0})
                    elif pattern == "sweep":
                        start_x = random.choice([60, self.width() - 60])
                        vx = 2.6 if start_x < self.width() // 2 else -2.6
                        self.enemies.append({"x": start_x, "y": -30, "vx": vx, "vy": 4.5, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": start_x, "y": -65, "vx": vx, "vy": 4.5, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                    elif pattern == "pincer":
                        self.enemies.append({"x": 40, "y": -30, "vx": 2.4, "vy": 4.0, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": self.width() - 40, "y": -30, "vx": -2.4, "vy": 4.0, "hp": 4, "faction": get_ef(), "type": "interceptor", "hit_flash": 0})
                    elif pattern == "heavy":
                        start_x = random.randint(120, self.width() - 120)
                        self.enemies.append({"x": start_x, "y": -60, "vx": random.uniform(-0.6, 0.6), "vy": 2.0, "hp": 12, "faction": get_ef(), "type": "bomber", "hit_flash": 0})

                # ROUND 2: Coastal Ocean Warships in separated sea lanes
                if self.current_round == 2:
                    self.warship_spawn_tick += 1
                    w_freq = 135
                    active_ships = [w for w in self.warships if not w.get("sinking")]
                    if self.warship_spawn_tick >= w_freq and len(active_ships) < 3:
                        self.warship_spawn_tick = 0
                        candidate_lanes = [130, 290, 450]
                        random.shuffle(candidate_lanes)
                        chosen_x = None
                        for lx in candidate_lanes:
                            too_close_ship = any(abs(w["x"] - lx) < 95 and w["y"] < 260 for w in active_ships)
                            too_close_land = any(abs(isl["x"] - lx) < 140 and isl["y"] < 350 for isl in self.islands)
                            if not too_close_ship and not too_close_land:
                                chosen_x = lx
                                break

                        if chosen_x is not None:
                            w_type = random.choices(["gunboat", "destroyer", "cruiser"], weights=[45, 38, 17])[0]
                            if w_type == "gunboat":
                                self.spawn_warship("gunboat", chosen_x, -100, vy=1.8, hp=22)
                            elif w_type == "destroyer":
                                self.spawn_warship("destroyer", chosen_x, -220, vy=1.3, hp=55)
                            elif w_type == "cruiser":
                                self.spawn_warship("cruiser", chosen_x, -300, vy=0.9, hp=125)

                # ROUND 3: Mainland Invasion - Authentic WW2 Tanks, Pillboxes, Flak 88s, and Base Depots
                if self.current_round == 3:
                    self.ground_target_spawn_tick += 1
                    active_g = [g for g in self.ground_targets if not g.get("wreck")]
                    if self.ground_target_spawn_tick >= 105 and len(active_g) < 4:
                        self.ground_target_spawn_tick = 0
                        g_choice = random.choices(["tank", "pillbox", "flak", "building", "tent"], weights=[42, 24, 20, 7, 7])[0]
                        lanes = [110, 220, 330, 440, 530]
                        random.shuffle(lanes)
                        chosen_x = None
                        for lx in lanes:
                            if not any(abs(g["x"] - lx) < 90 and g["y"] < 180 for g in self.ground_targets):
                                chosen_x = lx
                                break
                        if chosen_x is not None:
                            self.spawn_ground_target(g_choice, chosen_x, -120)

            # Boss Update & Multi-Stage Damage
            if self.boss and self.boss["active"]:
                b = self.boss
                if not b.get("vulnerable", False):
                    # Boss is descending onto screen - invulnerable to damage!
                    if b["y"] < b["target_y"]:
                        b["y"] += 2.0
                    else:
                        b["y"] = b["target_y"]
                        b["vulnerable"] = True
                        self.screen_shake = 18
                        self.banner_text = f"⚔ {b['title']} ON STATION! ALL BATTERIES ENGAGED! ⚔"
                        self.banner_timer = 120
                else:
                    b["x"] += math.sin(self.mission_ticks * 0.02) * 1.5

                # Multi-stage boss battle damage emitters
                if b["hp"] <= 80:
                    b["damage_stage"] = 2
                elif b["hp"] <= 160:
                    b["damage_stage"] = 1
                else:
                    b["damage_stage"] = 0

                # High-fidelity dynamic smoke, flame, and spark emitters from damaged engines
                if b["damage_stage"] >= 1:
                    # Starboard outer engine damage emitter (X = +85, Y = +15)
                    emitters = [(85, 15)]
                    if b["damage_stage"] >= 2:
                        # Critical wreck: Port inner engine (X = -45, Y = +18) + fuselage breach
                        emitters.extend([(-45, 18), (0, -10), (-95, 12)])

                    for ex_off, ey_off in emitters:
                        em_x = b["x"] + ex_off
                        em_y = b["y"] + ey_off

                        # 1. Vibrant orange/red flame jet
                        self.smoke_particles.append({
                            "x": em_x + random.uniform(-4, 4),
                            "y": em_y + random.uniform(0, 6),
                            "vx": random.uniform(-0.8, 0.8),
                            "vy": random.uniform(2.0, 4.5),
                            "rad": random.randint(7, 11),
                            "max_rad": random.randint(16, 26),
                            "life": random.randint(14, 20),
                            "max_life": 20,
                            "type": "fire"
                        })

                        # 2. Billowing heavy black charcoal smoke plume
                        self.smoke_particles.append({
                            "x": em_x + random.uniform(-5, 5),
                            "y": em_y + random.uniform(2, 8),
                            "vx": random.uniform(-1.2, 1.2),
                            "vy": random.uniform(3.5, 6.0),
                            "rad": random.randint(10, 15),
                            "max_rad": random.randint(28, 44),
                            "life": random.randint(26, 40),
                            "max_life": 40,
                            "type": "black_smoke"
                        })

                        # 3. Flying burning metal sparks & embers
                        if random.random() < 0.65:
                            self.smoke_particles.append({
                                "x": em_x + random.uniform(-3, 3),
                                "y": em_y + random.uniform(-2, 2),
                                "vx": random.uniform(-3.5, 3.5),
                                "vy": random.uniform(2.5, 8.0),
                                "rad": 2, "max_rad": 3,
                                "life": random.randint(10, 16),
                                "max_life": 16,
                                "type": "spark"
                            })
                # Boss only opens fire with turrets once fully revealed and on station!
                if b.get("vulnerable", False):
                    fire_rate = max(26, 46 - (self.current_round - 1) * 8)
                    b["fire_tick"] += 1
                    if b["fire_tick"] >= fire_rate:
                        b["fire_tick"] = 0
                        self.sound.play("enemy_shoot")
                        for t in b["turrets"]:
                            tx, ty = b["x"] + t["x"], b["y"] + t["y"]
                            dx = self.x - tx
                            dy = self.y - ty
                            dist = math.hypot(dx, dy)
                            if dist > 0:
                                spd = 4.8
                                self.enemy_bullets.append({"x": tx, "y": ty, "vx": (dx / dist) * spd, "vy": (dy / dist) * spd})

            # Update Enemies
            alive_enemies = []
            for e in self.enemies:
                e["x"] += e["vx"]
                e["y"] += e["vy"]
                if e.get("hit_flash", 0) > 0:
                    e["hit_flash"] -= 1

                # Enemy shooting
                shoot_chance = 0.055 if self.is_secret_mission else 0.016
                min_y = 40 if self.is_secret_mission else 20
                if random.random() < shoot_chance and e["y"] > min_y and e["y"] < self.y - 50:
                    dx = self.x - e["x"]
                    dy = self.y - e["y"]
                    dist = math.hypot(dx, dy)
                    if dist > 0:
                        spd = 5.6 if self.is_secret_mission else 4.2
                        if self.is_secret_mission and e.get("type") == "interceptor":
                            # 3-way fan spread aimed at player
                            base_ang = math.atan2(dy, dx)
                            for spread in [-0.24, 0.0, 0.24]:
                                a = base_ang + spread
                                self.enemy_bullets.append({
                                    "x": e["x"], "y": e["y"],
                                    "vx": math.cos(a) * spd,
                                    "vy": math.sin(a) * spd
                                })
                        elif self.is_secret_mission and e.get("type") == "scout":
                            # Twin tracer burst
                            self.enemy_bullets.append({"x": e["x"] - 6, "y": e["y"], "vx": (dx / dist) * spd, "vy": (dy / dist) * spd})
                            self.enemy_bullets.append({"x": e["x"] + 6, "y": e["y"], "vx": (dx / dist) * spd, "vy": (dy / dist) * spd})
                        else:
                            self.enemy_bullets.append({"x": e["x"], "y": e["y"], "vx": (dx / dist) * spd, "vy": (dy / dist) * spd})
                        self.sound.play("enemy_shoot")

                # Collision with player
                if math.hypot(e["x"] - self.x, e["y"] - self.y) < 42:
                    self.take_player_damage(1, hit_x=e["x"], hit_y=e["y"])
                    e["hp"] -= 8

                if e["hp"] > 0 and e["y"] < self.height() + 80 and e["x"] > -60 and e["x"] < self.width() + 60:
                    alive_enemies.append(e)
                elif e["hp"] <= 0:
                    # Enemy destroyed
                    e_type = e["type"]
                    pts = 100 if e_type == "scout" else (250 if e_type == "interceptor" else 800)
                    self.score += pts
                    if e_type == "scout": self.stats["scouts_killed"] += 1
                    elif e_type == "interceptor": self.stats["interceptors_killed"] += 1
                    elif e_type == "bomber": self.stats["bombers_killed"] += 1

                    self.sound.play("enemy_explode")
                    r_max = 48 if e_type == "bomber" else 32
                    self.explosions.append({"x": e["x"], "y": e["y"], "radius": 14, "max_radius": r_max, "life": 16})
                    
                    # Pickup drops:
                    if self.is_secret_mission:
                        # ZERO RANDOM HEALTH DROPS! User: "You have 100s of health right from the start, that's silly."
                        # Exactly 1 health repair kit is dropped cleanly every 20 seconds from allied air-drops.
                        if random.random() < 0.05:
                            self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.2, "type": random.choice(["bomb", "loop"])})
                    elif e.get("guaranteed_drop"):
                        self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.0, "type": e["guaranteed_drop"]})
                    elif not self.air_support_dropped_this_round and not self.air_support_ready and not self.air_support_active and self.mission_ticks > 300 and random.random() < 0.28:
                        self.air_support_dropped_this_round = True
                        self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.0, "type": "support"})
                    elif random.random() < 0.16:
                        p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                        self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.2, "type": p_choice})
            self.enemies = alive_enemies

            # Update Hostile 3D Warships
            alive_warships = []
            for w in self.warships:
                w["wake_tick"] += 1
                if w.get("hit_flash", 0) > 0:
                    w["hit_flash"] -= 1

                if w.get("sinking"):
                    w["sink_tick"] += 1
                    w["y"] += w["vy"] * 0.35
                    if w["sink_tick"] % 4 == 0:
                        ox = random.randint(-20, 20)
                        oy = random.randint(-40, 40)
                        self.smoke_particles.append({
                            "x": w["x"] + ox, "y": w["y"] + oy,
                            "vx": random.uniform(-0.8, 0.8), "vy": random.uniform(-0.5, 1.5),
                            "rad": 8, "max_rad": 32, "life": 24, "type": "black_smoke"
                        })
                    if w["sink_tick"] < 70:
                        alive_warships.append(w)
                    continue

                w["x"] += w["vx"]
                w["y"] += w["vy"]
                if w["x"] < 70 or w["x"] > self.width() - 70:
                    w["vx"] = -w["vx"]

                # Rotating Turrets Tracking & Naval Gunfire AI
                for t in w.get("turrets", []):
                    t_world_x = w["x"] + t["ox"]
                    t_world_y = w["y"] + t["oy"]
                    dx = self.x - t_world_x
                    dy = self.y - t_world_y
                    ang = math.degrees(math.atan2(dx, -dy)) % 360.0
                    t["frame_idx"] = int(round(ang / 22.5)) % 16

                    t["cooldown"] -= 1
                    if t["cooldown"] <= 0 and -30 < w["y"] < self.height() + 30:
                        dist = math.hypot(dx, dy)
                        if dist > 30:
                            spd = 4.0 if t["type"] == "heavy" else 4.6
                            b_vx = (dx / dist) * spd
                            b_vy = (dy / dist) * spd
                            self.enemy_bullets.append({
                                "x": t_world_x, "y": t_world_y,
                                "vx": b_vx, "vy": b_vy
                            })
                            self.sound.play("shoot_twin")
                            t["cooldown"] = random.randint(85, 130) if t["type"] == "heavy" else random.randint(60, 95)

                if w["y"] < self.height() + 350:
                    alive_warships.append(w)
            self.warships = alive_warships

            # Update Ground Targets (Round 3: Mainland Assault)
            alive_targets = []
            for g in self.ground_targets:
                if g.get("wreck"):
                    # Wrecked debris is permanently anchored to the ground
                    g["y"] += self.terrain_speed
                    g["vx"] = 0.0
                elif g["type"] in ("pillbox", "flak", "building", "tent", "radar", "hangar"):
                    # Stationary fortifications and buildings are locked to ground scroll speed
                    g["y"] += self.terrain_speed
                    g["vx"] = 0.0
                else:
                    # Active moving tanks patrol with terrain + forward advance
                    g["x"] += g.get("vx", 0.0)
                    g["y"] += g.get("vy", self.terrain_speed)

                if g["hit_flash"] > 0:
                    g["hit_flash"] -= 1

                if g.get("wreck"):
                    if random.random() < 0.25:
                        self.smoke_particles.append({
                            "x": g["x"] + random.uniform(-15, 15),
                            "y": g["y"] + random.uniform(-15, 15),
                            "vx": random.uniform(-0.4, 0.4),
                            "vy": -1.2,
                            "rad": 5, "max_rad": 14, "life": 18,
                            "type": "black_smoke"
                        })
                    if g["y"] <= self.height() + 180:
                        alive_targets.append(g)
                    continue

                # Live ground target combat AI
                if 0 < g["y"] < self.height() - 40:
                    g["fire_timer"] -= 1
                    dx = self.x - g["x"]
                    dy = self.y - g["y"]
                    dist = math.hypot(dx, dy)
                    ang = math.atan2(dy, dx)
                    g["turret_angle"] = math.degrees(ang) + 90.0

                    if g["fire_timer"] <= 0 and dist > 30:
                        if g["type"] == "tank":
                            g["fire_timer"] = random.randint(65, 100)
                            spd = 4.2
                            self.enemy_bullets.append({
                                "x": g["x"], "y": g["y"],
                                "vx": (dx / dist) * spd,
                                "vy": (dy / dist) * spd,
                                "color": QColor(255, 130, 40),
                                "radius": 5
                            })
                            self.sound.play("shoot_twin")
                            self.spark_particles.append({
                                "x": g["x"] + math.cos(ang) * 24,
                                "y": g["y"] + math.sin(ang) * 24,
                                "vx": 0, "vy": 0, "life": 6,
                                "color": QColor(255, 230, 100)
                            })
                        elif g["type"] == "pillbox":
                            g["fire_timer"] = random.randint(55, 85)
                            spd = 4.6
                            perp_x = -math.sin(ang) * 8
                            perp_y = math.cos(ang) * 8
                            for sgn in (-1, 1):
                                self.enemy_bullets.append({
                                    "x": g["x"] + perp_x * sgn,
                                    "y": g["y"] + perp_y * sgn,
                                    "vx": (dx / dist) * spd,
                                    "vy": (dy / dist) * spd,
                                    "color": QColor(255, 180, 50),
                                    "radius": 4
                                })
                            self.sound.play("shoot_twin")
                        elif g["type"] == "flak":
                            g["fire_timer"] = random.randint(60, 95)
                            spd = 4.8
                            self.enemy_bullets.append({
                                "x": g["x"], "y": g["y"],
                                "vx": (dx / dist) * spd,
                                "vy": (dy / dist) * spd,
                                "flak": True,
                                "target_y": self.y,
                                "fuse": int(dist / spd),
                                "color": QColor(255, 60, 30),
                                "radius": 6
                            })
                            self.sound.play("shoot_twin")

                if g["y"] <= self.height() + 180:
                    alive_targets.append(g)
            self.ground_targets = alive_targets

            # Update Player Bullets
            alive_bullets = []
            for b in self.bullets:
                b["x"] += b["vx"]
                b["y"] += b["vy"]
                hit = False

                # Bullet canceling
                if b.get("cancels_bullets"):
                    rem_eb = []
                    for eb in self.enemy_bullets:
                        if math.hypot(eb["x"] - b["x"], eb["y"] - b["y"]) < 26:
                            self.spark_particles.append({"x": eb["x"], "y": eb["y"], "vx": 0, "vy": 0, "life": 8, "color": QColor(100, 240, 255)})
                        else:
                            rem_eb.append(eb)
                    self.enemy_bullets = rem_eb

                # Hit enemies
                for e in self.enemies:
                    if e.get("y", 0) < 40 or e.get("y", 0) > self.height() - 10:
                        continue
                    hit_rad = 48 if e["type"] == "bomber" else 28
                    if math.hypot(e["x"] - b["x"], e["y"] - b["y"]) < hit_rad:
                        e["hp"] -= b["dmg"]
                        e["hit_flash"] = 3
                        hit = True
                        self.sound.play("hit_sound")
                        for _ in range(3):
                            self.spark_particles.append({
                                "x": b["x"], "y": b["y"],
                                "vx": random.uniform(-2, 2), "vy": random.uniform(-2, 2),
                                "life": 8, "color": QColor(255, 230, 80)
                            })
                        break

                # Hit Warships
                if not hit:
                    for w in self.warships:
                        if w.get("sinking"):
                            continue
                        w_hw = 36 if w["type"] == "gunboat" else (60 if w["type"] == "destroyer" else 88)
                        w_hh = 75 if w["type"] == "gunboat" else (175 if w["type"] == "destroyer" else 250)
                        if abs(w["x"] - b["x"]) < w_hw and abs(w["y"] - b["y"]) < w_hh:
                            w["hp"] -= b["dmg"]
                            w["hit_flash"] = 3
                            hit = True
                            self.sound.play("hit_sound")
                            for _ in range(4):
                                self.spark_particles.append({
                                    "x": b["x"], "y": b["y"],
                                    "vx": random.uniform(-3, 3), "vy": random.uniform(-2, 2),
                                    "life": 8, "color": QColor(255, 210, 80)
                                })
                            if w["hp"] <= 0 and not w.get("sinking"):
                                w["sinking"] = True
                                w["sink_tick"] = 0
                                self.stats["warships_sunk"] = self.stats.get("warships_sunk", 0) + 1
                                pts = 400 if w["type"] == "gunboat" else (1200 if w["type"] == "destroyer" else 3000)
                                self.score += pts
                                self.sound.play("enemy_explode")
                                self.screen_shake = 12
                                self.explosions.append({"x": w["x"], "y": w["y"], "radius": 20, "max_radius": 56, "life": 22})
                                if random.random() < 0.30:
                                    p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                                    self.pickups.append({"x": w["x"], "y": w["y"], "vy": 2.0, "type": p_choice})
                            break

                # Hit Ground Targets (Round 3)
                if not hit:
                    for g in self.ground_targets:
                        if g.get("wreck"):
                            continue
                        hw = g["width"] // 2
                        hh = g["height"] // 2
                        if abs(g["x"] - b["x"]) < hw and abs(g["y"] - b["y"]) < hh:
                            g["hp"] -= b["dmg"]
                            g["hit_flash"] = 3
                            hit = True
                            self.sound.play("hit_sound")
                            for _ in range(3):
                                self.spark_particles.append({
                                    "x": b["x"], "y": b["y"],
                                    "vx": random.uniform(-2, 2), "vy": random.uniform(-2, 2),
                                    "life": 8, "color": QColor(255, 210, 70)
                                })
                            if g["hp"] <= 0 and not g.get("wreck"):
                                g["wreck"] = True
                                self.stats["ground_targets_destroyed"] = self.stats.get("ground_targets_destroyed", 0) + 1
                                self.score += g["score"]
                                self.sound.play("exp_large" if g["type"] in ("building", "tent", "flak") else "enemy_explode")
                                self.screen_shake = 10
                                self.explosions.append({"x": g["x"], "y": g["y"], "radius": 22, "max_radius": 54, "life": 22})
                                if g["type"] in ("building", "tent"):
                                    p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                                    self.pickups.append({"x": g["x"], "y": g["y"], "vy": 2.0, "type": p_choice})
                                elif random.random() < 0.30:
                                    p_choice = random.choice(["pow", "medal"])
                                    self.pickups.append({"x": g["x"], "y": g["y"], "vy": 2.0, "type": p_choice})
                            break

                # Hit Boss (Takes NO damage until fully revealed on station!)
                if not hit and self.boss and self.boss["active"]:
                    boss_w = 175
                    boss_h = 75
                    if abs(b["x"] - self.boss["x"]) < boss_w and abs(b["y"] - self.boss["y"]) < boss_h:
                        hit = True
                        if self.boss.get("vulnerable", False):
                            self.boss["hp"] -= b["dmg"]
                            self.sound.play("hit_sound")
                            for _ in range(4):
                                self.spark_particles.append({
                                    "x": b["x"], "y": b["y"],
                                    "vx": random.uniform(-3, 3), "vy": random.uniform(-1, 3),
                                    "life": 10, "color": QColor(255, 180, 50)
                                })
                            if self.boss["hp"] <= 0:
                                self.defeat_boss()
                # Hit Cartel Underground Hangar Complex
                if not hit and self.cartel_hangar and self.cartel_hangar.get("active") and not self.cartel_hangar.get("exploding"):
                    h = self.cartel_hangar
                    if abs(b["x"] - h["x"]) < 200 and abs(b["y"] - h["y"]) < 180:
                        hit = True
                        h["hp"] -= b.get("dmg", 1)
                        h["hit_flash"] = 3
                        self.sound.play("hit_sound")
                        for _ in range(3):
                            self.spark_particles.append({
                                "x": b["x"], "y": b["y"],
                                "vx": random.uniform(-3, 3), "vy": random.uniform(-1, 3),
                                "life": 10, "color": QColor(255, 200, 50)
                            })
                        if h["hp"] <= 0:
                            self.defeat_hangar()

                if not hit and b["y"] > -40 and b["y"] < self.height() + 40 and b["x"] > -30 and b["x"] < self.width() + 30:
                    alive_bullets.append(b)
            self.bullets = alive_bullets

            # Update Missiles (Seeking)
            alive_missiles = []
            for m in self.missiles:
                # Seek nearest target
                target = None
                target_dist = 9999
                for e in self.enemies:
                    if e.get("y", 0) < 40 or e.get("y", 0) > self.height() - 10:
                        continue
                    d = math.hypot(e["x"] - m["x"], e["y"] - m["y"])
                    if d < target_dist and e["y"] < m["y"]:
                        target_dist = d
                        target = e
                if not target and self.boss and self.boss["active"] and self.boss.get("vulnerable", False):
                    target = self.boss
                    target_dist = math.hypot(self.boss["x"] - m["x"], self.boss["y"] - m["y"])
                if not target:
                    for w in self.warships:
                        if not w.get("sinking"):
                            d = math.hypot(w["x"] - m["x"], w["y"] - m["y"])
                            if d < target_dist and w["y"] < m["y"]:
                                target_dist = d
                                target = w
                if not target:
                    for g in self.ground_targets:
                        if not g.get("wreck"):
                            d = math.hypot(g["x"] - m["x"], g["y"] - m["y"])
                            if d < target_dist and g["y"] < m["y"]:
                                target_dist = d
                                target = g
                if not target and self.cartel_hangar and self.cartel_hangar.get("active") and not self.cartel_hangar.get("exploding"):
                    target = self.cartel_hangar
                    target_dist = math.hypot(self.cartel_hangar["x"] - m["x"], self.cartel_hangar["y"] - m["y"])

                if target:
                    dx = target["x"] - m["x"]
                    dy = target["y"] - m["y"]
                    ang = math.atan2(dy, dx)
                    m["vx"] += math.cos(ang) * 0.9
                    m["vy"] += math.sin(ang) * 0.9
                    speed = math.hypot(m["vx"], m["vy"])
                    if speed > m["speed"]:
                        m["vx"] = (m["vx"] / speed) * m["speed"]
                        m["vy"] = (m["vy"] / speed) * m["speed"]
                else:
                    m["vy"] -= 0.3

                m["x"] += m["vx"]
                m["y"] += m["vy"]

                # Missile trail
                self.smoke_particles.append({"x": m["x"], "y": m["y"] + 6, "vx": 0, "vy": 1.5, "rad": 4, "max_rad": 12, "life": 12, "type": "vapor"})

                # Hit check
                m_hit = False
                for e in self.enemies:
                    if e.get("y", 0) < 40 or e.get("y", 0) > self.height() - 10:
                        continue
                    if math.hypot(e["x"] - m["x"], e["y"] - m["y"]) < 36:
                        e["hp"] -= 4
                        e["hit_flash"] = 4
                        m_hit = True
                        break
                if not m_hit:
                    for w in self.warships:
                        if not w.get("sinking"):
                            w_hw = 40 if w["type"] == "gunboat" else (65 if w["type"] == "destroyer" else 95)
                            w_hh = 80 if w["type"] == "gunboat" else (180 if w["type"] == "destroyer" else 260)
                            if abs(w["x"] - m["x"]) < w_hw and abs(w["y"] - m["y"]) < w_hh:
                                w["hp"] -= 16
                                w["hit_flash"] = 4
                                m_hit = True
                                if w["hp"] <= 0 and not w.get("sinking"):
                                    w["sinking"] = True
                                    w["sink_tick"] = 0
                                    self.stats["warships_sunk"] = self.stats.get("warships_sunk", 0) + 1
                                    pts = 400 if w["type"] == "gunboat" else (1200 if w["type"] == "destroyer" else 3000)
                                    self.score += pts
                                    self.sound.play("enemy_explode")
                                    self.screen_shake = 12
                                    self.explosions.append({"x": w["x"], "y": w["y"], "radius": 24, "max_radius": 60, "life": 24})
                                break
                if not m_hit:
                    for g in self.ground_targets:
                        if not g.get("wreck"):
                            hw = g["width"] // 2 + 8
                            hh = g["height"] // 2 + 8
                            if abs(g["x"] - m["x"]) < hw and abs(g["y"] - m["y"]) < hh:
                                g["hp"] -= 16
                                g["hit_flash"] = 4
                                m_hit = True
                                if g["hp"] <= 0 and not g.get("wreck"):
                                    g["wreck"] = True
                                    self.stats["ground_targets_destroyed"] = self.stats.get("ground_targets_destroyed", 0) + 1
                                    self.score += g["score"]
                                    self.sound.play("exp_large" if g["type"] in ("building", "tent", "flak") else "enemy_explode")
                                    self.screen_shake = 10
                                    self.explosions.append({"x": g["x"], "y": g["y"], "radius": 24, "max_radius": 58, "life": 22})
                                    if g["type"] in ("building", "tent"):
                                        p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                                        self.pickups.append({"x": g["x"], "y": g["y"], "vy": 2.0, "type": p_choice})
                                    elif random.random() < 0.35:
                                        p_choice = random.choice(["pow", "medal"])
                                        self.pickups.append({"x": g["x"], "y": g["y"], "vy": 2.0, "type": p_choice})
                                break
                if not m_hit and self.boss and self.boss["active"]:
                    if abs(m["x"] - self.boss["x"]) < 160 and abs(m["y"] - self.boss["y"]) < 60:
                        m_hit = True
                        if self.boss.get("vulnerable", False):
                            self.boss["hp"] -= 4
                            if self.boss["hp"] <= 0:
                                self.defeat_boss()

                if not m_hit and self.cartel_hangar and self.cartel_hangar.get("active") and not self.cartel_hangar.get("exploding"):
                    h = self.cartel_hangar
                    if abs(m["x"] - h["x"]) < 200 and abs(m["y"] - h["y"]) < 180:
                        m_hit = True
                        h["hp"] -= 8
                        h["hit_flash"] = 4
                        if h["hp"] <= 0:
                            self.defeat_hangar()

                if m_hit:
                    self.sound.play("bomb_explode")
                    self.explosions.append({"x": m["x"], "y": m["y"], "radius": 16, "max_radius": 36, "life": 14})
                elif m["y"] > -40 and m["y"] < self.height() + 40 and m["x"] > -30 and m["x"] < self.width() + 30:
                    alive_missiles.append(m)
            self.missiles = alive_missiles

            # Update Enemy Bullets
            alive_eb = []
            for eb in self.enemy_bullets:
                eb["x"] += eb["vx"]
                eb["y"] += eb["vy"]

                # Flak 88 detonation
                if eb.get("flak"):
                    eb["fuse"] = eb.get("fuse", 50) - 1
                    if eb["fuse"] <= 0 or abs(eb["y"] - eb.get("target_y", 0)) < 22:
                        self.sound.play("exp_mid")
                        self.explosions.append({"x": eb["x"], "y": eb["y"], "radius": 14, "max_radius": 34, "life": 14})
                        for fa in (-0.55, 0.0, 0.55):
                            cur_ang = math.atan2(eb["vy"], eb["vx"]) + fa
                            alive_eb.append({
                                "x": eb["x"], "y": eb["y"],
                                "vx": math.cos(cur_ang) * 3.4,
                                "vy": math.sin(cur_ang) * 3.4,
                                "color": QColor(255, 90, 30),
                                "radius": 4
                            })
                        continue

                # Check player hit
                if math.hypot(eb["x"] - self.x, eb["y"] - self.y) < 22:
                    self.take_player_damage(1, hit_x=eb["x"], hit_y=eb["y"])
                elif eb["y"] < self.height() + 40 and eb["y"] > -40 and eb["x"] > -30 and eb["x"] < self.width() + 30:
                    alive_eb.append(eb)
            self.enemy_bullets = alive_eb

            # Pickups
            alive_pickups = []
            for p in self.pickups:
                p["y"] += p["vy"]
                if math.hypot(p["x"] - self.x, p["y"] - self.y) < 38:
                    p_type = p.get("type", "pow")
                    self.sound.play("pow_pickup")
                    if p_type in ("repair", "health"):
                        # Restricted to exactly 3 drops per battle, heals +1 HP
                        self.hp = min(self.max_hp, self.hp + 1)
                        self.score += 1000
                        self.banner_text = "★ FIELD REPAIR KIT: +1 ARMOR RESTORED! ★"
                        self.banner_timer = 100
                        self.floating_texts.append({
                            "text": "+1 ARMOR REPAIRED",
                            "x": self.x, "y": self.y - 25, "life": 50,
                            "color": QColor(60, 255, 120)
                        })
                    elif p_type == "pow":
                        # POW ONLY upgrades weapon, does NOT heal player!
                        self.cycle_weapon()
                        self.score += 500
                        self.floating_texts.append({
                            "text": "WEAPON UPGRADE",
                            "x": self.x, "y": self.y - 25, "life": 40,
                            "color": QColor(255, 220, 60)
                        })
                    elif p_type == "wing":
                        if "escorts" in self.weapons:
                            self.weapon_idx = self.weapons.index("escorts")
                        self.banner_text = "★ ESCORT FIGHTERS SCRAMBLED: FORMATION DEFENSE! ★"
                        self.banner_timer = 90
                        self.score += 500
                    elif p_type == "bomb":
                        self.bombs_remaining = min(5, self.bombs_remaining + 1)
                        self.banner_text = "★ 1943 MEGA CRASH BOMB REPLENISHED! ★"
                        self.banner_timer = 90
                        self.score += 500
                    elif p_type == "loop":
                        self.loops_remaining = min(5, self.loops_remaining + 1)
                        self.banner_text = "★ 360° EMERGENCY LOOP TACTIC REPLENISHED! ★"
                        self.banner_timer = 90
                        self.score += 500
                    elif p_type == "medal":
                        self.score += 2500
                        self.banner_text = "★ GOLD STAR MEDAL AWARDED: +2,500 PTS! ★"
                        self.banner_timer = 90
                    elif p_type == "support":
                        self.air_support_ready = True
                        self.air_support_hero = random.choice(["hurricane", "p39", "ki43", "hs129", "i16", "cr42", "ms406", "beaufighter"])
                        self.sound.play("radio_chime")
                        hero_names = {
                            "hurricane": "HAWKER HURRICANE", "p39": "P-39 AIRACOBRA",
                            "ki43": "KI-43 OSCAR", "hs129": "Hs 129 PANZERKNACKER",
                            "i16": "POLIKARPOV I-16", "cr42": "FIAT CR.42 FALCO",
                            "ms406": "M.S.406 FIGHTER", "beaufighter": "BRISTOL BEAUFIGHTER"
                        }
                        h_name = hero_names.get(self.air_support_hero, self.air_support_hero.upper())
                        self.banner_text = f"★ 📻 TACTICAL AIR SUPPORT READY: {h_name} [PRESS 'C']! ★"
                        self.banner_timer = 150
                        self.floating_texts.append({
                            "text": f"📻 AIR SUPPORT READY: {h_name} [PRESS 'C']",
                            "x": self.x, "y": self.y - 30, "life": 60,
                            "color": QColor(255, 235, 80)
                        })
                elif p["y"] < self.height() + 30:
                    alive_pickups.append(p)
            self.pickups = alive_pickups

            # Update floating combat texts
            alive_ft = []
            for ft in self.floating_texts:
                ft["y"] -= 0.8
                ft["life"] -= 1
                if ft["life"] > 0:
                    alive_ft.append(ft)
            self.floating_texts = alive_ft

            # Update Coalition Secret Prototypes (Wingmen)
            if self.is_secret_mission and self.state == "playing":
                alive_wingmen = []
                for w in self.secret_wingmen:
                    target_x = self.x + w["target_ox"]
                    target_y = self.y + w["target_oy"]
                    dx = target_x - w["x"]
                    dy = target_y - w["y"]
                    w["x"] += dx * 0.12
                    w["y"] += dy * 0.12
                    w["bank_angle"] = max(-26.0, min(26.0, dx * 0.8))
                    if w.get("hit_flash", 0) > 0:
                        w["hit_flash"] -= 1

                    w["fire_cooldown"] -= 1
                    if w["fire_cooldown"] <= 0:
                        w["fire_cooldown"] = random.randint(14, 26)
                        w_plane = w["plane"]
                        wx, wy = w["x"], w["y"]
                        if w_plane == "ho229":
                            self.bullets.append({"x": wx - 16, "y": wy - 22, "vx": 0, "vy": -24, "type": "quad", "dmg": 2})
                            self.bullets.append({"x": wx + 16, "y": wy - 22, "vx": 0, "vy": -24, "type": "quad", "dmg": 2})
                            self.muzzle_flashes.append({"x": wx - 16, "y": wy - 22, "life": 3})
                            self.muzzle_flashes.append({"x": wx + 16, "y": wy - 22, "life": 3})
                        elif w_plane == "b29":
                            self.bullets.append({"x": wx - 26, "y": wy - 10, "vx": -1.5, "vy": -22, "type": "twin", "dmg": 2})
                            self.bullets.append({"x": wx + 26, "y": wy - 10, "vx": 1.5, "vy": -22, "type": "twin", "dmg": 2})
                            if random.random() < 0.35:
                                self.bullets.append({"x": wx, "y": wy - 20, "vx": 0, "vy": -18, "type": "shotgun", "dmg": 2, "cancels_bullets": True})
                            self.muzzle_flashes.append({"x": wx - 26, "y": wy - 10, "life": 3})
                            self.muzzle_flashes.append({"x": wx + 26, "y": wy - 10, "life": 3})
                        elif w_plane == "shinden":
                            self.bullets.append({"x": wx - 8, "y": wy - 24, "vx": 0, "vy": -25, "type": "threeway", "dmg": 2})
                            self.bullets.append({"x": wx + 8, "y": wy - 24, "vx": 0, "vy": -25, "type": "threeway", "dmg": 2})
                            self.muzzle_flashes.append({"x": wx - 8, "y": wy - 24, "life": 3})
                            self.muzzle_flashes.append({"x": wx + 8, "y": wy - 24, "life": 3})

                    for eb in list(self.enemy_bullets):
                        if math.hypot(eb["x"] - w["x"], eb["y"] - w["y"]) < 30:
                            if eb in self.enemy_bullets:
                                self.enemy_bullets.remove(eb)
                            w["hp"] -= 1
                            w["hit_flash"] = 5
                            if w["hp"] <= 0:
                                break

                    if w["hp"] <= 0:
                        self.trigger_failsafe_detonation(w["x"], w["y"], w["name"])
                    else:
                        alive_wingmen.append(w)
                self.secret_wingmen = alive_wingmen

            # Update Tactical Air Support Ace
            if self.air_support_active and self.air_support_obj:
                obj = self.air_support_obj
                self.air_support_timer -= 1
                hero = obj["hero"]

                if self.air_support_timer > 540:
                    obj["y"] += obj["vy"]
                    obj["bank_angle"] = 0.0
                elif self.air_support_timer > 60:
                    sweep_x = self.x + math.sin(self.mission_ticks * 0.07) * 120
                    target_combat_y = max(130, self.y - 120)
                    dx = sweep_x - obj["x"]
                    dy = target_combat_y - obj["y"]
                    obj["x"] += dx * 0.10
                    obj["y"] += dy * 0.10
                    obj["bank_angle"] = max(-25.0, min(25.0, dx * 1.2))

                    self.enemy_bullets = [eb for eb in self.enemy_bullets if math.hypot(eb["x"] - obj["x"], eb["y"] - obj["y"]) > 42]

                    obj["fire_cooldown"] -= 1
                    if obj["fire_cooldown"] <= 0:
                        ax, ay = obj["x"], obj["y"]
                        if hero == "hurricane":
                            obj["fire_cooldown"] = 12
                            for ox in [-24, -18, -12, -6, 6, 12, 18, 24]:
                                self.bullets.append({"x": ax + ox, "y": ay - 14, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 14, "life": 3})
                        elif hero == "p39":
                            obj["fire_cooldown"] = 16
                            self.bullets.append({"x": ax, "y": ay - 18, "vx": 0, "vy": -26, "type": "quad", "dmg": 4})
                            self.bullets.append({"x": ax - 8, "y": ay - 14, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                            self.bullets.append({"x": ax + 8, "y": ay - 14, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 18, "life": 4})
                        elif hero == "ki43":
                            obj["fire_cooldown"] = 8
                            self.bullets.append({"x": ax - 6, "y": ay - 16, "vx": random.uniform(-0.5, 0.5), "vy": -26, "type": "twin", "dmg": 1.5})
                            self.bullets.append({"x": ax + 6, "y": ay - 16, "vx": random.uniform(-0.5, 0.5), "vy": -26, "type": "twin", "dmg": 1.5})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 16, "life": 3})
                        elif hero == "hs129":
                            obj["fire_cooldown"] = 14
                            self.bullets.append({"x": ax, "y": ay - 20, "vx": 0, "vy": -24, "type": "shotgun", "dmg": 4, "cancels_bullets": True})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 20, "life": 5})
                        elif hero == "i16":
                            obj["fire_cooldown"] = 15
                            self.bullets.append({"x": ax - 10, "y": ay - 16, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                            self.bullets.append({"x": ax + 10, "y": ay - 16, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                            if random.random() < 0.35:
                                self.missiles.append({"x": ax - 16, "y": ay, "vx": -2.5, "vy": -6.0, "speed": 8.0})
                                self.missiles.append({"x": ax + 16, "y": ay, "vx": 2.5, "vy": -6.0, "speed": 8.0})
                        elif hero == "cr42":
                            obj["fire_cooldown"] = 10
                            self.bullets.append({"x": ax - 8, "y": ay - 16, "vx": -1.0, "vy": -23, "type": "threeway", "dmg": 1.5})
                            self.bullets.append({"x": ax + 8, "y": ay - 16, "vx": 1.0, "vy": -23, "type": "threeway", "dmg": 1.5})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 16, "life": 3})
                        elif hero == "ms406":
                            obj["fire_cooldown"] = 12
                            self.bullets.append({"x": ax, "y": ay - 20, "vx": 0, "vy": -26, "type": "quad", "dmg": 2.5})
                            self.bullets.append({"x": ax - 14, "y": ay - 14, "vx": 0, "vy": -23, "type": "twin", "dmg": 1})
                            self.bullets.append({"x": ax + 14, "y": ay - 14, "vx": 0, "vy": -23, "type": "twin", "dmg": 1})
                            self.muzzle_flashes.append({"x": ax, "y": ay - 20, "life": 4})
                        elif hero == "beaufighter":
                            obj["fire_cooldown"] = 15
                            for ox in [-12, -4, 4, 12]:
                                self.bullets.append({"x": ax + ox, "y": ay - 18, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                            if random.random() < 0.4:
                                self.missiles.append({"x": ax - 28, "y": ay, "vx": -3.0, "vy": -6.5, "speed": 8.5})
                                self.missiles.append({"x": ax + 28, "y": ay, "vx": 3.0, "vy": -6.5, "speed": 8.5})
                else:
                    obj["vy"] -= 0.35
                    obj["y"] += obj["vy"]
                    obj["bank_angle"] = 30.0

                if self.air_support_timer <= 0:
                    self.air_support_active = False
                    self.air_support_obj = None
                    self.banner_text = "★ AIR SUPPORT MISSION EXECUTED • RETURNING TO BASE ★"
                    self.banner_timer = 90

            # Update Failsafe Shockwaves
            alive_sw = []
            for sw in self.failsafe_shockwaves:
                sw["radius"] += sw["speed"]
                sw["life"] -= 1
                if sw["life"] > 0 and sw["radius"] < sw["max_radius"]:
                    alive_sw.append(sw)
            self.failsafe_shockwaves = alive_sw
            if self.failsafe_flash_ticks > 0:
                self.failsafe_flash_ticks -= 1

        # Update particles & flashes
        for f in self.muzzle_flashes: f["life"] -= 1
        self.muzzle_flashes = [f for f in self.muzzle_flashes if f["life"] > 0]

        for exp in self.explosions:
            exp["life"] -= 1
            exp["radius"] += (exp["max_radius"] - exp["radius"]) * 0.18
        self.explosions = [exp for exp in self.explosions if exp["life"] > 0]

        for sp in self.spark_particles:
            sp["life"] -= 1
            sp["x"] += sp.get("vx", 0)
            sp["y"] += sp.get("vy", 0)
        self.spark_particles = [sp for sp in self.spark_particles if sp["life"] > 0]

        for sm in self.smoke_particles:
            sm["life"] -= 1
            sm["x"] += sm.get("vx", 0)
            sm["y"] += sm.get("vy", 0)
            sm["rad"] += (sm["max_rad"] - sm["rad"]) * 0.08
        self.smoke_particles = [sm for sm in self.smoke_particles if sm["life"] > 0]

        if self.score > self.high_score:
            self.high_score = self.score
            self.settings.setValue("highScore", self.high_score)

        # Update procedural prop engine acoustic telemetry
        if hasattr(self, "prop_audio"):
            th_input = 0.0
            if self.state == "playing":
                if any(k in self.keys for k in [Qt.Key_Up, Qt.Key_W]):
                    th_input = 1.0
                elif any(k in self.keys for k in [Qt.Key_Down, Qt.Key_S]):
                    th_input = -1.0

            is_muted = (self.state not in ("takeoff", "playing", "landing")) or (getattr(self, "death_ticks", 0) > 0)
            self.prop_audio.update_flight_telemetry(
                plane_id=self.current_plane,
                flight_state=self.state,
                throttle_input=th_input,
                bank_angle=getattr(self, "bank_angle", 0.0),
                is_looping=getattr(self, "is_looping", False),
                loop_tick=getattr(self, "loop_tick", 0),
                takeoff_tick=getattr(self, "takeoff_tick", 0),
                landing_tick=getattr(self, "landing_tick", 0),
                is_muted=is_muted
            )

        self.update()

    def draw_transition_screen(self, painter):
        painter.fillRect(self.rect(), QColor(10, 14, 20))

        # 1. Header Banner
        grad_top = QLinearGradient(0, 0, 0, 85)
        grad_top.setColorAt(0.0, QColor(22, 28, 38))
        grad_top.setColorAt(1.0, QColor(12, 16, 24))
        painter.fillRect(0, 0, self.width(), 85, grad_top)

        painter.setPen(QPen(QColor(212, 175, 55, 180), 2))
        painter.drawLine(0, 83, self.width(), 83)

        painter.setPen(QColor(212, 175, 55))
        font_hdr = QFont("Menlo", 15, QFont.Bold)
        painter.setFont(font_hdr)
        painter.drawText(QRect(0, 10, self.width(), 32), Qt.AlignCenter, "★ GLOBAL WAR TOUR • THEATER DEPLOYMENT ★")

        painter.setPen(QColor(180, 210, 245))
        font_sub = QFont("Menlo", 11, QFont.Bold)
        painter.setFont(font_sub)
        painter.drawText(QRect(0, 46, self.width(), 24), Qt.AlignCenter, "ROUND 1 / 3: INITIAL THEATER DEPLOYMENT")

        # 2. Strategic World Map
        map_w = self.width() - 40
        map_h = int(map_w * 768 / 1376)
        map_x = 20
        map_y = 96

        # Outer bezel
        painter.setPen(QPen(QColor(212, 175, 55, 140), 2))
        painter.setBrush(QColor(0, 0, 0))
        painter.drawRoundedRect(map_x - 2, map_y - 2, map_w + 4, map_h + 4, 6, 6)

        if not self.world_map_pix.isNull():
            scaled_map = self.world_map_pix.scaled(map_w, map_h, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
            src_rect = QRect((scaled_map.width() - map_w) // 2, (scaled_map.height() - map_h) // 2, map_w, map_h)
            painter.drawPixmap(QRect(map_x, map_y, map_w, map_h), scaled_map, src_rect)
        else:
            painter.fillRect(QRect(map_x, map_y, map_w, map_h), QColor(25, 35, 45))

        # Origin & Destination Coordinates
        orig_data = self.geo_coords.get(self.transition_origin, (0.23, 0.38, "USA", "🇺🇸"))
        targ_data = self.geo_coords.get(self.transition_target, (0.82, 0.40, "Japan", "🇯🇵"))

        sx = map_x + orig_data[0] * map_w
        sy = map_y + orig_data[1] * map_h
        ex = map_x + targ_data[0] * map_w
        ey = map_y + targ_data[1] * map_h

        # Trans-continental Arc Flight
        plane_t = self.transition_t
        painter.setPen(QPen(QColor(255, 255, 255, 210), 2, Qt.DashLine))
        steps = max(2, int(30 * plane_t))
        prev_pt = QPoint(int(sx), int(sy))
        for i in range(1, steps + 1):
            t = i / 30.0
            cx = sx + (ex - sx) * t
            cy = sy + (ey - sy) * t - math.sin(t * math.pi) * 45
            curr_pt = QPoint(int(cx), int(cy))
            painter.drawLine(prev_pt, curr_pt)
            prev_pt = curr_pt

        # Current plane position
        px = sx + (ex - sx) * plane_t
        py = sy + (ey - sy) * plane_t - math.sin(plane_t * math.pi) * 45

        # Calculate tangent heading
        dt = 0.01
        px_n = sx + (ex - sx) * (plane_t + dt)
        py_n = sy + (ey - sy) * (plane_t + dt) - math.sin((plane_t + dt) * math.pi) * 45
        dx = px_n - px
        dy = py_n - py
        heading_deg = math.degrees(math.atan2(dy, dx)) + 90.0

        # Origin Pin
        painter.setBrush(QColor(40, 180, 255))
        painter.setPen(QPen(QColor(255, 255, 255), 2))
        painter.drawEllipse(QPoint(int(sx), int(sy)), 5, 5)
        painter.setFont(QFont("Arial", 8, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(int(sx - 20), int(sy + 16), f"{orig_data[3]} {orig_data[2]}")

        # Destination Target Crosshair & Pulsing Radar
        pulse = 12 + math.sin(self.takeoff_tick * 0.18) * 5
        painter.setBrush(QColor(255, 40, 40))
        painter.setPen(QPen(QColor(255, 255, 255), 2))
        painter.drawEllipse(QPoint(int(ex), int(ey)), 6, 6)

        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(255, 50, 50, 200), 2))
        painter.drawEllipse(QPoint(int(ex), int(ey)), int(pulse), int(pulse))
        painter.drawLine(int(ex - pulse - 6), int(ey), int(ex + pulse + 6), int(ey))
        painter.drawLine(int(ex), int(ey - pulse - 6), int(ex), int(ey + pulse + 6))

        painter.setFont(QFont("Arial", 9, QFont.Bold))
        painter.setPen(QColor(255, 225, 80))
        painter.drawText(int(ex - 35), int(ey + 26), f"TARGET {targ_data[3]}")

        # 3. DRAW THE PLAYER'S ACTUAL CHOSEN FIGHTER ON THE MAP!
        p_frame = f"level_{(self.showcase_tick // 3) % 4}"
        plane_pix = self.cache.get(self.current_plane, {}).get(p_frame, self.cache.get(self.current_plane, {}).get("level_0"))
        if plane_pix and not plane_pix.isNull():
            scaled_plane = plane_pix.scaled(48, 48, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            painter.save()
            painter.translate(px + 4, py + 7)
            painter.rotate(heading_deg)
            painter.setOpacity(0.40)
            painter.setBrush(QColor(0, 0, 0, 200))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(-18, -18, 36, 36)
            painter.restore()

            painter.save()
            painter.translate(px, py)
            painter.rotate(heading_deg)
            painter.drawPixmap(-scaled_plane.width() // 2, -scaled_plane.height() // 2, scaled_plane)
            painter.restore()

        # 4. STREET FIGHTER II STYLE SPLIT VS CARDS
        card_y = map_y + map_h + 14
        card_h = 224
        card_gap = 52
        col_w = (self.width() - 36 - card_gap) // 2

        # Left Card (Player Fighter)
        p_info = self.nation_info.get(self.current_plane, self.nation_info["p38"])
        p_rect = QRect(18, card_y, col_w, card_h)
        painter.setPen(QPen(QColor(40, 140, 220), 2))
        painter.setBrush(QColor(16, 24, 36, 235))
        painter.drawRoundedRect(p_rect, 6, 6)

        painter.setPen(QColor(90, 195, 255))
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.drawText(p_rect.left() + 10, p_rect.top() + 24, f"{p_info['flag']} {p_info['pilot']}")

        painter.setPen(QColor(255, 255, 255))
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.drawText(p_rect.left() + 10, p_rect.top() + 46, p_info['name'])

        # Player Fighter 3D Rolling Animation Preview
        p_thumb = QRect(p_rect.right() - 72, p_rect.top() + 8, 64, 64)
        painter.fillRect(p_thumb, QColor(10, 20, 32, 220))
        painter.setPen(QColor(50, 130, 200))
        painter.drawRect(p_thumb)
        p_frames = self.showcase_frames.get(self.current_plane)
        if p_frames:
            f_idx = (self.showcase_tick // 2) % len(p_frames)
            painter.drawPixmap(p_thumb, p_frames[f_idx])
        else:
            pix = self.cache.get(self.current_plane, {}).get("level_0")
            if pix:
                painter.drawPixmap(p_thumb, pix)

        painter.setFont(QFont("Menlo", 8))
        painter.setPen(QColor(170, 190, 215))
        p_details = [
            f"BASE: {p_info['base'][:21]}",
            f"ROLE: {p_info['role'][:21]}",
            f"SPEED: {p_info['speed'] * 60:.0f} MPH",
            f"AGILITY: BANK {int(p_info['bank'] * 100)}°",
            f"WEAPON: {self.weapon_names[self.current_plane].get('twin', self.weapon_names[self.current_plane].get('single', 'Cannons'))[:18]}",
            f"SCORE: {self.score:06d} PTS"
        ]
        for idx, line in enumerate(p_details):
            painter.drawText(p_rect.left() + 10, p_rect.top() + 74 + idx * 22, line)

        # Right Card (Enemy Theater & Boss)
        t_info = self.theaters.get(self.transition_target, self.theaters["imperial"])
        o_rect = QRect(self.width() - 18 - col_w, card_y, col_w, card_h)
        painter.setPen(QPen(QColor(220, 55, 55), 2))
        painter.setBrush(QColor(36, 18, 22, 235))
        painter.drawRoundedRect(o_rect, 6, 6)

        painter.setPen(QColor(255, 100, 100))
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.drawText(o_rect.left() + 10, o_rect.top() + 24, f"{t_info['flag']} {t_info['name'][:17]}")

        painter.setPen(QColor(255, 215, 60))
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.drawText(o_rect.left() + 10, o_rect.top() + 46, t_info['boss_title'][:19])

        # Enemy Rival Fighter 3D Rolling Animation Preview
        e_plane = {
            "imperial": "zero", "allied": "p38", "luftwaffe": "bf109",
            "raf": "spitfire", "vvs": "yak3", "canada": "mosquito",
            "mediterranean": "folgore", "france": "d520", "poland": "pzl11",
            "czech": "avia"
        }.get(self.transition_target, "zero")

        o_thumb = QRect(o_rect.right() - 72, o_rect.top() + 8, 64, 64)
        painter.fillRect(o_thumb, QColor(28, 12, 16, 220))
        painter.setPen(QColor(200, 50, 50))
        painter.drawRect(o_thumb)
        e_frames = self.showcase_frames.get(e_plane)
        if e_frames:
            f_idx = (self.showcase_tick // 2) % len(e_frames)
            painter.drawPixmap(o_thumb, e_frames[f_idx])
        else:
            boss_pix = self.enemy_sprites.get(self.transition_target, {}).get("boss", {}).get("pristine")
            if boss_pix:
                painter.drawPixmap(QRect(o_thumb.left() + 2, o_thumb.top() + 10, 60, 44), boss_pix)

        painter.setFont(QFont("Menlo", 8))
        painter.setPen(QColor(225, 190, 195))
        t_details = [
            f"AIR FORCE: {t_info.get('enemy_title', 'AXIS FORCES')[:19]}",
            f"BOSS: {t_info.get('boss_name', 'SUPER FORTRESS')}",
            f"MISSION: 3 FULL COMBAT ROUNDS",
            f"SECTOR: {t_info.get('name', 'ZONE')[:19]}",
            f"TURRETS: {len(t_info.get('turrets', []))} BATTERIES",
            f"THREAT: HEAVY FLAK & ESCORTS"
        ]
        for idx, line in enumerate(t_details):
            painter.drawText(o_rect.left() + 10, o_rect.top() + 74 + idx * 22, line)

        # Center VS Medallion
        vs_cx = self.width() // 2
        vs_cy = card_y + card_h // 2
        painter.setBrush(QColor(12, 16, 22))
        painter.setPen(QPen(QColor(212, 175, 55), 3))
        painter.drawEllipse(QPoint(vs_cx, vs_cy), 25, 25)

        painter.setPen(QColor(255, 215, 50))
        painter.setFont(QFont("Impact", 18, QFont.Bold))
        painter.drawText(QRect(vs_cx - 25, vs_cy - 16, 50, 32), Qt.AlignCenter, "VS")

        # 5. Bottom Action Button
        btn_w = self.width() - 80
        btn_h = 44
        btn_x = 40
        btn_y = card_y + card_h + 12

        if self.transition_t >= 1.0:
            glow = int(180 + math.sin(self.takeoff_tick * 0.2) * 70)
            painter.setPen(QPen(QColor(245, 215, 50, glow), 2))
            painter.setBrush(QColor(36, 28, 16))
            painter.drawRoundedRect(btn_x, btn_y, btn_w, btn_h, 6, 6)

            painter.setPen(QColor(255, 230, 90))
            painter.setFont(QFont("Menlo", 13, QFont.Bold))
            painter.drawText(QRect(btn_x, btn_y, btn_w, btn_h), Qt.AlignCenter, "⚔️ PRESS [SPACE] TO SCRAMBLE ⚔️")
        else:
            painter.setPen(QPen(QColor(100, 140, 180, 140), 1))
            painter.setBrush(QColor(20, 26, 36))
            painter.drawRoundedRect(btn_x, btn_y, btn_w, btn_h, 6, 6)

            painter.setPen(QColor(160, 195, 230))
            painter.setFont(QFont("Menlo", 11, QFont.Bold))
            painter.drawText(QRect(btn_x, btn_y, btn_w, btn_h), Qt.AlignCenter, "✈️ EN ROUTE TO THEATER... ✈️")

        # Footer
        painter.setPen(QColor(140, 160, 185))
        painter.setFont(QFont("Menlo", 8))
        painter.drawText(QRect(0, self.height() - 22, self.width(), 20), Qt.AlignCenter, "[Arrows] Change Theater / Fighter  •  [1-9, 0] Sector  •  [Space] Scramble  •  [Esc] Hangar")

    def draw_game_over_screen(self, painter):
        """Renders authentic arcade 'Shot Down in Action' combat casualty report and gameplay stats."""
        # 1. Dark charcoal/crimson tactical atmosphere
        painter.fillRect(self.rect(), QColor(14, 10, 15))

        # 2. Subtle warning grid
        painter.setPen(QPen(QColor(38, 18, 22), 1))
        for y in range(0, self.height(), 28):
            painter.drawLine(0, y, self.width(), y)
        for x in range(0, self.width(), 28):
            painter.drawLine(x, 0, x, self.height())

        # 3. Header Banner with deep red gradient
        grad_hdr = QLinearGradient(0, 0, 0, 85)
        grad_hdr.setColorAt(0.0, QColor(48, 14, 18))
        grad_hdr.setColorAt(1.0, QColor(20, 8, 12))
        painter.fillRect(0, 0, self.width(), 85, grad_hdr)

        painter.setPen(QPen(QColor(220, 45, 45, 220), 2))
        painter.drawLine(0, 84, self.width(), 84)

        # Title: SHOT DOWN IN ACTION
        glow = int(210 + math.sin(self.takeoff_tick * 0.15) * 45)
        painter.setPen(QColor(255, 55, 55, glow))
        font_big = QFont("Menlo", 17, QFont.Bold)
        painter.setFont(font_big)
        painter.drawText(QRect(0, 14, self.width(), 32), Qt.AlignCenter, "☠ SHOT DOWN IN ACTION ☠")

        painter.setPen(QColor(255, 175, 175))
        font_sub = QFont("Menlo", 10, QFont.Bold)
        painter.setFont(font_sub)
        p_info = self.nation_info.get(self.current_plane, self.nation_info["p38"])
        t_info = self.theaters.get(self.enemy_theater, self.theaters["imperial"])
        painter.drawText(QRect(0, 48, self.width(), 24), Qt.AlignCenter, f"MISSION FAILED • {t_info['name'].upper()} CASUALTY REPORT")

        # 4. Main Casualty Dossier Panel
        panel_x = 24
        panel_y = 96
        panel_w = self.width() - 48
        panel_h = 635

        # Background
        painter.setBrush(QColor(20, 14, 18, 245))
        painter.setPen(QPen(QColor(200, 45, 45, 180), 2))
        painter.drawRoundedRect(panel_x, panel_y, panel_w, panel_h, 8, 8)

        # Inner highlight border
        painter.setPen(QPen(QColor(65, 28, 35, 140), 1))
        painter.drawRoundedRect(panel_x + 4, panel_y + 4, panel_w - 8, panel_h - 8, 6, 6)

        # Section A: Aircraft Casualty Box
        sec_a_y = panel_y + 14
        painter.setPen(QPen(QColor(85, 30, 38), 1))
        painter.setBrush(QColor(16, 10, 14, 220))
        painter.drawRoundedRect(panel_x + 12, sec_a_y, panel_w - 24, 126, 6, 6)

        # Draw Fighter Sprite (darkened with red damage wash)
        pix = self.cache.get(self.current_plane, {}).get("level_0")
        if pix and not pix.isNull():
            scaled_pix = pix.scaled(90, 90, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            px = panel_x + 22 + (90 - scaled_pix.width()) // 2
            py = sec_a_y + (126 - scaled_pix.height()) // 2
            painter.drawPixmap(px, py, scaled_pix)
            # Red fire overlay
            painter.setBrush(QColor(255, 40, 20, 55))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(px - 5, py - 5, scaled_pix.width() + 10, scaled_pix.height() + 10)

        # Casualty dossier details
        tx = panel_x + 126
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(255, 95, 95))
        painter.drawText(tx, sec_a_y + 26, f"AIRFRAME: {p_info['flag']} {p_info['name']}")

        painter.setFont(QFont("Menlo", 10))
        painter.setPen(QColor(220, 180, 180))
        painter.drawText(tx, sec_a_y + 48, f"CALLSIGN : {p_info['pilot']}")
        painter.drawText(tx, sec_a_y + 68, f"STATUS   : AIRFRAME DESTROYED • MIA")
        round_name = {1: "STRATOSPHERE", 2: "COASTAL FLEET", 3: "MAINLAND INVASION"}.get(self.current_round, "ENGAGEMENT")
        painter.drawText(tx, sec_a_y + 88, f"SECTOR   : ROUND {self.current_round}/3 ({round_name})")
        painter.drawText(tx, sec_a_y + 108, f"BASE     : {p_info['base']}")

        # Divider line
        painter.setPen(QPen(QColor(75, 30, 38), 1))
        painter.drawLine(panel_x + 15, sec_a_y + 138, panel_x + panel_w - 15, sec_a_y + 138)

        # Section B: Detailed Gameplay Statistics
        stats_y = sec_a_y + 162
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.setPen(QColor(255, 205, 75))
        painter.drawText(panel_x + 18, stats_y, "★ COMBAT PERFORMANCE LOG ★")
        stats_y += 24

        flight_sec = self.stats.get("flight_ticks", 0) // 60
        flight_min = flight_sec // 60
        flight_rem = flight_sec % 60
        time_str = f"{flight_min:02d}:{flight_rem:02d}"

        rows = [
            ("ENEMY SCOUTS SHOT DOWN", f"{self.stats.get('scouts_killed', 0):02d}", f"+{self.stats.get('scouts_killed', 0) * 100} PTS"),
            ("INTERCEPTOR ACES DOWNED", f"{self.stats.get('interceptors_killed', 0):02d}", f"+{self.stats.get('interceptors_killed', 0) * 250} PTS"),
            ("HEAVY BOMBERS DESTROYED", f"{self.stats.get('bombers_killed', 0):02d}", f"+{self.stats.get('bombers_killed', 0) * 800} PTS"),
            ("HOSTILE WARSHIPS SUNK", f"{self.stats.get('warships_sunk', 0):02d}", f"+{self.stats.get('warships_sunk', 0) * 1500} PTS"),
            ("GROUND TARGETS SMASHED", f"{self.stats.get('ground_targets_destroyed', 0):02d}", f"+{self.stats.get('ground_targets_destroyed', 0) * 800} PTS"),
            ("BOSS FORTRESS ENGAGEMENT", "DEFEATED" if self.stats.get('boss_killed') else "FAILED", "+20,000 PTS" if self.stats.get('boss_killed') else "+0 PTS"),
            ("ORDNANCE EXPENDED", f"{self.stats.get('shots_fired', 0)} RDS", f"{self.stats.get('bombs_dropped', 0)} BOMBS"),
            ("COMBAT FLIGHT DURATION", time_str, "TIME IN ACTION"),
            ("FINAL COMBAT SCORE", f"{self.score:06d} PTS", "TOTAL RECORDED"),
        ]

        font_row = QFont("Menlo", 10)
        for idx, (label, count_val, pts_val) in enumerate(rows):
            is_final = (idx == len(rows) - 1)
            # Alternating row background
            if idx % 2 == 1 and not is_final:
                painter.fillRect(panel_x + 14, stats_y - 14, panel_w - 28, 22, QColor(32, 20, 26, 120))

            if is_final:
                stats_y += 4
                painter.fillRect(panel_x + 14, stats_y - 15, panel_w - 28, 26, QColor(48, 20, 28, 220))
                painter.setPen(QPen(QColor(255, 215, 50, 200), 1))
                painter.drawRect(panel_x + 14, stats_y - 15, panel_w - 28, 26)
                painter.setFont(QFont("Menlo", 11, QFont.Bold))
                painter.setPen(QColor(255, 220, 60))
            else:
                painter.setFont(font_row)
                painter.setPen(QColor(215, 220, 230))

            painter.drawText(panel_x + 22, stats_y + 2, label)
            painter.setPen(QColor(255, 140, 140) if not is_final else QColor(255, 230, 80))
            painter.drawText(panel_x + 255, stats_y + 2, count_val)
            painter.setPen(QColor(140, 230, 160) if not is_final else QColor(100, 255, 140))
            painter.drawText(panel_x + panel_w - 165, stats_y + 2, pts_val)
            stats_y += 24

        # Section C: Action Buttons
        btn_y = panel_y + panel_h - 100
        btn_w = panel_w - 60
        btn_x = panel_x + 30

        # Button 1: Retry Mission
        btn_retry_rect = QRect(btn_x, btn_y, btn_w, 40)
        grad_btn1 = QLinearGradient(btn_x, btn_y, btn_x, btn_y + 40)
        grad_btn1.setColorAt(0.0, QColor(195, 45, 45))
        grad_btn1.setColorAt(1.0, QColor(135, 25, 25))
        painter.fillRect(btn_retry_rect, grad_btn1)
        painter.setPen(QPen(QColor(255, 220, 100), 2))
        painter.drawRect(btn_retry_rect)
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(btn_retry_rect, Qt.AlignCenter, "★ RETRY MISSION (PRESS SPACE / ENTER) ★")

        # Button 2: Return to Hangar
        btn_hangar_rect = QRect(btn_x, btn_y + 48, btn_w, 36)
        grad_btn2 = QLinearGradient(btn_x, btn_y + 48, btn_x, btn_y + 84)
        grad_btn2.setColorAt(0.0, QColor(36, 52, 74))
        grad_btn2.setColorAt(1.0, QColor(22, 32, 48))
        painter.fillRect(btn_hangar_rect, grad_btn2)
        painter.setPen(QPen(QColor(70, 100, 140), 1))
        painter.drawRect(btn_hangar_rect)
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.setPen(QColor(180, 215, 245))
        painter.drawText(btn_hangar_rect, Qt.AlignCenter, "RETURN TO HANGAR (PRESS [H] / [ESC])")

    def draw_round_clear_screen(self, painter):
        painter.fillRect(self.rect(), QColor(10, 15, 24))

        # 1. Subtle tactical background grid
        painter.setPen(QPen(QColor(24, 36, 52), 1))
        for y in range(0, self.height(), 30):
            painter.drawLine(0, y, self.width(), y)
        for x in range(0, self.width(), 30):
            painter.drawLine(x, 0, x, self.height())

        # 2. Header Banner
        grad_hdr = QLinearGradient(0, 0, 0, 85)
        grad_hdr.setColorAt(0.0, QColor(24, 32, 48))
        grad_hdr.setColorAt(1.0, QColor(14, 18, 28))
        painter.fillRect(0, 0, self.width(), 85, grad_hdr)

        painter.setPen(QPen(QColor(212, 175, 55, 200), 2))
        painter.drawLine(0, 84, self.width(), 84)

        # Header Title
        painter.setPen(QColor(255, 215, 50))
        font_big = QFont("Menlo", 16, QFont.Bold)
        painter.setFont(font_big)
        painter.drawText(QRect(0, 14, self.width(), 32), Qt.AlignCenter, f"★ ROUND {self.current_round} OF 3 CLEARED! ★")

        painter.setPen(QColor(100, 210, 255))
        font_sub = QFont("Menlo", 10, QFont.Bold)
        painter.setFont(font_sub)
        painter.drawText(QRect(0, 48, self.width(), 24), Qt.AlignCenter, "CARRIER RECOVERY COMPLETE • FLIGHT DECK RESTOCK & SERVICING")

        p_info = self.nation_info.get(self.current_plane, self.nation_info["p38"])
        t_info = self.theaters.get(self.enemy_theater, self.theaters["imperial"])

        # 3. Main Briefing Dossier / Carrier Clipboard Panel
        panel_x = 24
        panel_y = 96
        panel_w = self.width() - 48
        panel_h = 515

        # Background
        painter.setBrush(QColor(18, 26, 40, 245))
        painter.setPen(QPen(QColor(212, 175, 55, 160), 2))
        painter.drawRoundedRect(panel_x, panel_y, panel_w, panel_h, 8, 8)

        # Inner highlight border
        painter.setPen(QPen(QColor(50, 75, 110, 120), 1))
        painter.drawRoundedRect(panel_x + 4, panel_y + 4, panel_w - 8, panel_h - 8, 6, 6)

        # Section A: Aircraft Recovery Box (Top Half of Dossier)
        sec_a_y = panel_y + 14
        painter.setPen(QPen(QColor(60, 90, 130), 1))
        painter.setBrush(QColor(12, 18, 28, 200))
        painter.drawRoundedRect(panel_x + 12, sec_a_y, panel_w - 24, 146, 6, 6)

        # Draw Fighter Sprite in Recovery Bay
        pix = self.cache.get(self.current_plane, {}).get("level_0")
        if pix and not pix.isNull():
            scaled_pix = pix.scaled(105, 105, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            px = panel_x + 22 + (105 - scaled_pix.width()) // 2
            py = sec_a_y + (146 - scaled_pix.height()) // 2
            painter.drawPixmap(px, py, scaled_pix)

        # Fighter recovery text
        tx = panel_x + 138
        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(tx, sec_a_y + 24, f"{p_info['flag']} {p_info['name'][:22]}")

        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.setPen(QColor(140, 195, 255))
        painter.drawText(tx, sec_a_y + 44, f"PILOT: {p_info['pilot']}  •  {p_info['base']}")

        painter.setFont(QFont("Menlo", 9))
        painter.setPen(QColor(80, 235, 140))
        painter.drawText(tx, sec_a_y + 68, f"[✓] AIRFRAME REPAIRED: {self.max_hp}/{self.max_hp} ARMOR HULL")
        painter.setPen(QColor(80, 215, 255))
        painter.drawText(tx, sec_a_y + 88, f"[✓] ORDNANCE RESTOCKED: {self.bombs_remaining} MEGA CRASH BOMBS")
        painter.setPen(QColor(255, 215, 80))
        painter.drawText(tx, sec_a_y + 108, f"[✓] FLIGHT SYSTEMS: {self.loops_remaining}/3 EVASIVE LOOPS READY")
        painter.setPen(QColor(255, 230, 100))
        painter.drawText(tx, sec_a_y + 128, f"[✓] SQUADRON RESERVES: {self.lives}/3 AIRFRAMES READY (+1 SORTIE BONUS)")

        # Section B: Sector Combat Record
        sec_b_y = sec_a_y + 158
        painter.setPen(QPen(QColor(60, 90, 130), 1))
        painter.setBrush(QColor(12, 18, 28, 200))
        painter.drawRoundedRect(panel_x + 12, sec_b_y, panel_w - 24, 150, 6, 6)

        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.setPen(QColor(255, 215, 50))
        painter.drawText(panel_x + 24, sec_b_y + 24, f"THEATER COMBAT RECORD: {t_info['flag']} {t_info['name']}")

        round_names = {
            1: "ROUND 1: STRATOSPHERE • HIGH SKY AIR COMBAT",
            2: "ROUND 2: COASTAL OCEAN • NAVAL FLEET INTERDICTION",
            3: "ROUND 3: ENEMY MAINLAND • AIR & GROUND TOTAL WAR"
        }
        r_name = round_names.get(self.current_round, f"ROUND {self.current_round}")
        boss_hp_scaled = {1: 220, 2: 280, 3: 360}.get(self.current_round, 240)

        painter.setFont(QFont("Menlo", 9))
        painter.setPen(QColor(180, 210, 240))
        painter.drawText(panel_x + 24, sec_b_y + 48, f"SECTOR OPERATION: {r_name}")
        painter.setPen(QColor(255, 90, 90))
        painter.drawText(panel_x + 24, sec_b_y + 70, f"BOSS CONFIRMED DOWN: {t_info['boss_name']} ({boss_hp_scaled} HP)")
        painter.setPen(QColor(80, 235, 140))
        painter.drawText(panel_x + 24, sec_b_y + 92, f"RECOVERY BONUS: +20,000 PTS (CARRIER ARRESTING WIRE TOUCHDOWN)")

        painter.setFont(QFont("Menlo", 11, QFont.Bold))
        painter.setPen(QColor(255, 230, 90))
        painter.drawText(panel_x + 24, sec_b_y + 124, f"ACCUMULATED SCORE: {self.score:,} PTS")

        # Section C: Next Round Intelligence & Threat Warning
        sec_c_y = sec_b_y + 162
        painter.setPen(QPen(QColor(212, 175, 55, 180), 1))
        painter.setBrush(QColor(28, 20, 16, 220))
        painter.drawRoundedRect(panel_x + 12, sec_c_y, panel_w - 24, 118, 6, 6)

        next_round = self.current_round + 1
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.setPen(QColor(255, 180, 50))
        painter.drawText(panel_x + 24, sec_c_y + 22, f"⚠️ TACTICAL INTEL FOR ROUND {next_round} OF 3:")

        if next_round == 2:
            brief1 = "Coastal ocean approach: enemy naval battle fleet sighted ahead!"
            brief2 = "Destroyers, cruisers, and gunboats engaging with 360° rotating turrets."
            brief3 = "Maintain naval sea lane separation and dive bomb the warships from above."
        else:
            brief1 = "Mainland invasion: low-altitude assault over enemy military territory!"
            brief2 = "Expect heavy tanks, concrete pillboxes, and Flak 88 anti-aircraft batteries."
            brief3 = "Target supply depots and command hangars for massive score and weapon drops."

        painter.setFont(QFont("Menlo", 8))
        painter.setPen(QColor(230, 210, 185))
        painter.drawText(panel_x + 24, sec_c_y + 46, f"• {brief1}")
        painter.drawText(panel_x + 24, sec_c_y + 68, f"• {brief2}")
        painter.drawText(panel_x + 24, sec_c_y + 90, f"• {brief3}")

        # 4. Big Glowing Scramble Action Button
        btn_w = self.width() - 64
        btn_h = 48
        btn_x = 32
        btn_y = panel_y + panel_h + 14

        glow = int(190 + math.sin(self.takeoff_tick * 0.22) * 60)
        painter.setPen(QPen(QColor(255, 215, 50, glow), 2))
        painter.setBrush(QColor(36, 28, 14))
        painter.drawRoundedRect(btn_x, btn_y, btn_w, btn_h, 6, 6)

        painter.setPen(QColor(255, 230, 90))
        painter.setFont(QFont("Menlo", 12, QFont.Bold))
        action_text = f"⚔️ READY FOR ROUND {next_round} OF 3 • PRESS [SPACE] TO SCRAMBLE ⚔️"
        painter.drawText(QRect(btn_x, btn_y, btn_w, btn_h), Qt.AlignCenter, action_text)

        # Footer
        painter.setPen(QColor(140, 160, 185))
        painter.setFont(QFont("Menlo", 8))
        painter.drawText(QRect(0, self.height() - 20, self.width(), 18), Qt.AlignCenter, "[Space / Click] Scramble Catapult  •  [Esc] Abort to Hangar")

    def draw_audio_menu(self, painter):
        painter.save()
        h_h = (46 if getattr(self, "is_mini_header", False) else 108) if self.state == "playing" else 0
        # 1. Dark high-opacity military backdrop overlay ONLY over playfield below header
        painter.fillRect(QRect(0, h_h, self.width(), self.height() - h_h), QColor(6, 10, 16, 235))

        dlg_rect = self.get_audio_dialog_rect()
        dlg_w = dlg_rect.width()
        dlg_h = dlg_rect.height()
        dlg_x = dlg_rect.x()
        dlg_y = dlg_rect.y()

        # Deep matte black chassis
        painter.fillRect(dlg_rect, QColor(13, 20, 30))

        # Solid high-contrast brass outer frame
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(240, 200, 70), 2))
        painter.drawRect(dlg_rect)
        painter.setPen(QPen(QColor(50, 75, 105), 1))
        painter.drawRect(dlg_rect.adjusted(3, 3, -3, -3))

        # 4 Corner rivets
        for rx, ry in [(dlg_x + 9, dlg_y + 9), (dlg_x + dlg_w - 9, dlg_y + 9),
                       (dlg_x + 9, dlg_y + dlg_h - 9), (dlg_x + dlg_w - 9, dlg_y + dlg_h - 9)]:
            painter.setBrush(QColor(180, 150, 65))
            painter.setPen(QColor(60, 50, 20))
            painter.drawEllipse(QPoint(rx, ry), 3, 3)
        painter.setBrush(Qt.NoBrush)

        # Top Stamped Nameplate (Jet Black for Maximum Contrast)
        nameplate_rect = QRect(dlg_x + 16, dlg_y + 14, dlg_w - 32, 48)
        painter.fillRect(nameplate_rect, QColor(6, 10, 16))
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(210, 175, 65), 1.5))
        painter.drawRect(nameplate_rect)

        painter.setFont(QFont("Menlo", 12, QFont.Bold))
        painter.setPen(QColor(255, 230, 80))
        painter.drawText(QRect(dlg_x + 24, dlg_y + 18, dlg_w - 80, 22), Qt.AlignLeft | Qt.AlignVCenter, "★ TACTICAL AUDIO MIXER • AN/ARC-5 ★")

        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(200, 230, 255))
        painter.drawText(QRect(dlg_x + 24, dlg_y + 40, dlg_w - 75, 16), Qt.AlignLeft | Qt.AlignVCenter, "SIGNAL CORPS • THREE-CHANNEL ACOUSTIC MIXER")

        # Close [✕] button
        close_rect = QRect(dlg_x + dlg_w - 46, dlg_y + 16, 28, 28)
        painter.fillRect(close_rect, QColor(110, 20, 26))
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(255, 95, 95), 1.5))
        painter.drawRect(close_rect)
        painter.setFont(QFont("Menlo", 12, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(close_rect, Qt.AlignCenter, "✕")

        # Channels Data
        channels = [
            {
                "idx": 0,
                "tag": "[1]",
                "title": "MUSIC (ORCHESTRAL BGM)",
                "sub": "Hardware BGM Loop (CoreAudio / PipeWire)",
                "vol": self.music_volume,
            },
            {
                "idx": 1,
                "tag": "[2]",
                "title": "BATTLE SFX (COMBAT SOUNDS)",
                "sub": "Combat Explosions & Ballistic Audio",
                "vol": self.battle_volume,
            },
            {
                "idx": 2,
                "tag": "[3]",
                "title": "WARBIRD ENGINE (ACOUSTICS)",
                "sub": self.get_current_engine_spec(),
                "vol": self.engine_volume,
            }
        ]

        ch_y_list = [dlg_y + 74, dlg_y + 152, dlg_y + 230]
        track_w = dlg_w - 72
        track_x = dlg_x + 36

        for ch in channels:
            c_idx = ch["idx"]
            c_y = ch_y_list[c_idx]
            is_sel = (self.audio_selected_channel == c_idx)
            vol = ch["vol"]

            # Card box
            card_rect = QRect(dlg_x + 16, c_y, dlg_w - 32, 68)
            card_bg = QColor(19, 32, 48) if is_sel else QColor(12, 19, 28)
            border_pen = QPen(QColor(255, 220, 60), 2) if is_sel else QPen(QColor(55, 80, 110), 1)
            painter.fillRect(card_rect, card_bg)
            painter.setBrush(Qt.NoBrush)
            painter.setPen(border_pen)
            painter.drawRect(card_rect)

            # Indicator vacuum lamp
            lamp_pt = QPoint(dlg_x + 32, c_y + 19)
            lamp_col = QColor(50, 240, 90) if is_sel else QColor(30, 75, 45)
            painter.setBrush(lamp_col)
            painter.setPen(QColor(15, 35, 20))
            painter.drawEllipse(lamp_pt, 5, 5)
            painter.setBrush(Qt.NoBrush)

            # Channel Title (Bold, High Luminance White/Cream)
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.setPen(QColor(255, 255, 255) if is_sel else QColor(225, 240, 255))
            painter.drawText(QRect(dlg_x + 46, c_y + 8, dlg_w - 240, 20), Qt.AlignLeft | Qt.AlignVCenter, f"{ch['tag']} {ch['title']}")

            # Channel Sub-label (Clear Sky Blue, generous width)
            sub_w = dlg_w - 240 if c_idx == 1 else dlg_w - 100
            painter.setFont(QFont("Menlo", 8))
            painter.setPen(QColor(185, 215, 245))
            painter.drawText(QRect(dlg_x + 46, c_y + 26, sub_w, 16), Qt.AlignLeft | Qt.AlignVCenter, ch["sub"])

            # Test button for Battle SFX
            if c_idx == 1:
                t_rect = QRect(dlg_x + dlg_w - 188, c_y + 8, 96, 22)
                painter.fillRect(t_rect, QColor(32, 48, 70))
                painter.setBrush(Qt.NoBrush)
                painter.setPen(QPen(QColor(255, 175, 40), 1.5))
                painter.drawRect(t_rect)
                painter.setFont(QFont("Menlo", 8, QFont.Bold))
                painter.setPen(QColor(255, 255, 255))
                painter.drawText(t_rect, Qt.AlignCenter, "🔊 TEST [T]")

            # Percentage Badge (Pure Solid Black with Bright Golden Yellow font)
            badge_rect = QRect(dlg_x + dlg_w - 84, c_y + 8, 56, 22)
            painter.fillRect(badge_rect, QColor(0, 0, 0))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QPen(QColor(255, 220, 60) if is_sel else QColor(70, 110, 160), 1.5))
            painter.drawRect(badge_rect)
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            pct_col = QColor(255, 235, 50) if vol > 0.01 else QColor(150, 165, 180)
            painter.setPen(pct_col)
            painter.drawText(badge_rect, Qt.AlignCenter, f"{int(vol * 100)}%")

            # Slider Track (Jet Black Groove)
            track_y = c_y + 44
            track_h = 16
            track_rect = QRect(track_x, track_y, track_w, track_h)
            painter.fillRect(track_rect, QColor(4, 7, 12))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QPen(QColor(55, 80, 115), 1))
            painter.drawRect(track_rect)

            # Segmented VU Meter Fill (24 segments)
            num_segs = 24
            active_segs = int(round(vol * num_segs))
            seg_w = (track_w - 4) / float(num_segs)
            for s in range(num_segs):
                sx = track_x + 2 + int(s * seg_w)
                sw = max(1, int(seg_w - 1.5))
                s_rect = QRect(sx, track_y + 2, sw, track_h - 4)
                if s < active_segs:
                    if s < int(num_segs * 0.60):
                        sc = QColor(46, 204, 113)  # Vivid neon green
                    elif s < int(num_segs * 0.85):
                        sc = QColor(243, 156, 18)   # Vivid warm amber
                    else:
                        sc = QColor(231, 76, 60)    # Vivid scarlet
                else:
                    sc = QColor(22, 32, 44)         # Distinct unlit charcoal slot
                painter.fillRect(s_rect, sc)

            # Draggable Knob (Bright High-Contrast Chrome Slider)
            knob_x = track_x + int(vol * track_w)
            knob_rect = QRect(knob_x - 7, track_y - 3, 14, track_h + 6)
            knob_grad = QLinearGradient(knob_rect.left(), knob_rect.top(), knob_rect.right(), knob_rect.bottom())
            if is_sel:
                knob_grad.setColorAt(0.0, QColor(255, 250, 190))
                knob_grad.setColorAt(0.5, QColor(255, 220, 80))
                knob_grad.setColorAt(1.0, QColor(200, 150, 30))
            else:
                knob_grad.setColorAt(0.0, QColor(250, 252, 255))
                knob_grad.setColorAt(0.5, QColor(210, 225, 240))
                knob_grad.setColorAt(1.0, QColor(140, 160, 185))
            painter.fillRect(knob_rect, knob_grad)
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QPen(QColor(20, 30, 40), 1.5))
            painter.drawRect(knob_rect)
            # Center grip notch line
            painter.setPen(QColor(50, 65, 80))
            painter.drawLine(knob_x, track_y - 1, knob_x, track_y + track_h + 1)

        # Presets Bar
        preset_y = dlg_y + 310
        painter.setFont(QFont("Menlo", 9, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(dlg_x + 20, preset_y + 17, "PRESETS:")

        presets = [
            ("MUTE", 0.0, 0.0, 0.0, QRect(dlg_x + 84, preset_y, 68, 26)),
            ("DEFAULT", 0.50, 0.50, 0.30, QRect(dlg_x + 158, preset_y, 84, 26)),
            ("WARZONE", 0.20, 1.00, 0.75, QRect(dlg_x + 248, preset_y, 86, 26)),
            ("MUSIC", 0.75, 0.20, 0.20, QRect(dlg_x + 340, preset_y, 88, 26)),
        ]
        for name, m, b, e, prect in presets:
            painter.fillRect(prect, QColor(24, 38, 54))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QPen(QColor(80, 120, 170), 1))
            painter.drawRect(prect)
            painter.setFont(QFont("Menlo", 8, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(prect, Qt.AlignCenter, name)

        # Controls Legend (Bold, High Visibility)
        info_y = dlg_y + 346
        painter.setFont(QFont("Menlo", 8, QFont.Bold))
        painter.setPen(QColor(240, 248, 255))
        painter.drawText(QRect(dlg_x, info_y, dlg_w, 20), Qt.AlignCenter,
                         "[▲/▼ or Click] Channel  •  [◀/▶ or Drag] Volume  •  [T] Test SFX")

        # Save & Resume Mission button (Bold High-Contrast Banner)
        save_btn_rect = QRect(dlg_x + 36, dlg_y + 378, dlg_w - 72, 38)
        save_grad = QLinearGradient(save_btn_rect.left(), save_btn_rect.top(), save_btn_rect.right(), save_btn_rect.bottom())
        save_grad.setColorAt(0.0, QColor(36, 64, 98))
        save_grad.setColorAt(1.0, QColor(18, 32, 50))
        painter.fillRect(save_btn_rect, save_grad)
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(255, 220, 60), 2))
        painter.drawRect(save_btn_rect)
        painter.setFont(QFont("Menlo", 10, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(save_btn_rect, Qt.AlignCenter, "★ CLOSE & RESUME MISSION [M / ESC] ★")

        painter.restore()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)

        # ---------------------------------------------------------------------
        # SCREEN: THEATER TRANSITION (STREET FIGHTER WORLD TOUR)
        # ---------------------------------------------------------------------
        if self.state == "transition":
            self.draw_transition_screen(painter)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: TOP SECRET BRIEFING (SHADOW GENERAL // OPERATION BLACKOUT)
        # ---------------------------------------------------------------------
        if self.state == "secret_briefing":
            self.draw_secret_briefing(painter)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: PROTOTYPE SELECTION (HO 229, B-29, SHINDEN)
        # ---------------------------------------------------------------------
        if self.state == "secret_select":
            self.draw_secret_select(painter)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: TOP SECRET DEBRIEFINGS (WIN / LOSS NARRATIVE SCENES)
        # ---------------------------------------------------------------------
        if self.state == "secret_victory":
            self.draw_secret_debrief(painter, is_victory=True)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        if self.state == "secret_defeat":
            self.draw_secret_debrief(painter, is_victory=False)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        if self.state == "nuke_cutscene":
            self.draw_nuke_cutscene(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: HANGAR / 2-STEP SELECTION
        # ---------------------------------------------------------------------
        if self.state == "hangar":
            painter.fillRect(self.rect(), QColor(14, 22, 34))
            
            # Grid
            painter.setPen(QColor(30, 48, 72))
            for y in range(0, self.height(), 32): painter.drawLine(0, y, self.width(), y)
            for x in range(0, self.width(), 32): painter.drawLine(x, 0, x, self.height())

            font_title = QFont("Menlo", 22, QFont.Bold)
            font_head = QFont("Menlo", 12, QFont.Bold)
            font_body = QFont("Menlo", 10)
            font_sm = QFont("Menlo", 9)

            # Header Banner
            painter.setPen(QColor(245, 215, 50))
            painter.setFont(font_title)
            painter.drawText(QRect(0, 24, self.width(), 36), Qt.AlignCenter, "★ SKY ACE • 194X ★")
            self.draw_template_help_button(painter, self.get_hangar_help_rect())
            self.draw_audio_button(painter, self.get_audio_button_rect(), is_hud=False)
            painter.setPen(QColor(180, 210, 240))
            painter.setFont(font_body)
            painter.drawText(QRect(0, 62, self.width(), 22), Qt.AlignCenter, f"ARCADE HIGH SCORE: {self.high_score:06d}")

            if self.hangar_step == 1:
                # Step 1: Choose Aircraft & Country
                painter.setPen(QColor(100, 210, 255))
                painter.setFont(font_head)
                painter.drawText(QRect(0, 84, self.width(), 22), Qt.AlignCenter, "STEP 1: SELECT YOUR NATION & FIGHTER [1-9, 0]")

                col_w = (self.width() - 44) // 2
                row_h = 106
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito", "folgore", "d520", "pzl11", "avia"]

                for i, k in enumerate(card_keys):
                    info = self.nation_info[k]
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 110 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)

                    # Card background
                    is_selected = (self.current_plane == k)
                    bg_col = QColor(36, 54, 78, 240) if is_selected else QColor(20, 32, 48, 230)
                    border_col = QColor(255, 215, 50) if is_selected else QColor(60, 110, 160)
                    
                    painter.fillRect(rect, bg_col)
                    painter.setPen(border_col)
                    painter.drawRect(rect)

                    # Plane 3D thumbnail or roll showcase
                    s_frames = self.showcase_frames.get(k) if (is_selected and hasattr(self, "showcase_frames")) else None
                    if s_frames:
                        f_idx = (self.showcase_tick // 2) % len(s_frames)
                        painter.drawPixmap(QRect(rect.left() + 6, rect.top() + 18, 68, 68), s_frames[f_idx])
                    else:
                        pix = self.cache[k]["level_0"]
                        painter.drawPixmap(QRect(rect.left() + 6, rect.top() + 18, 68, 68), pix)

                    # Text details with exact fit
                    key_tag = (i + 1) % 10
                    painter.setFont(QFont("Menlo", 9, QFont.Bold))
                    painter.setPen(QColor(255, 230, 80))
                    painter.drawText(rect.left() + 78, rect.top() + 20, f"[{key_tag}] {info['flag']} {info['name']}")

                    painter.setFont(QFont("Menlo", 7, QFont.Bold))
                    painter.setPen(QColor(160, 210, 255))
                    painter.drawText(rect.left() + 78, rect.top() + 38, info['country'])
                    
                    painter.setFont(QFont("Menlo", 7))
                    painter.setPen(QColor(220, 220, 220))
                    painter.drawText(rect.left() + 78, rect.top() + 54, f"ROLE: {info['role']}")
                    painter.drawText(rect.left() + 78, rect.top() + 70, f"BASE: {info['base']}")
                    painter.setPen(QColor(245, 185, 50))
                    painter.drawText(rect.left() + 78, rect.top() + 86, f"RANK: {info['pilot']}")

                # Footer
                painter.setPen(QColor(160, 180, 200))
                painter.setFont(font_sm)
                painter.drawText(QRect(0, self.height() - 28, self.width(), 24), Qt.AlignCenter, "[Arrows / 1-9, 0] Select  •  [Enter / Click] Confirm  •  [Esc] Exit")

            elif self.hangar_step == 2:
                # Step 2: Choose Enemy Theater
                p_info = self.nation_info[self.current_plane]
                painter.setPen(QColor(255, 215, 60))
                painter.setFont(font_head)
                painter.drawText(QRect(0, 84, self.width(), 22), Qt.AlignCenter, f"STEP 2: CHOOSE THEATER FOR {p_info['flag']} {p_info['name']}")

                th_keys = ["imperial", "allied", "luftwaffe", "raf", "vvs", "canada", "mediterranean", "france", "poland", "czech"]
                col_w = (self.width() - 44) // 2
                row_h = 106

                for i, tk in enumerate(th_keys):
                    t_data = self.theaters[tk]
                    col = i % 2
                    row = i // 2
                    rx = 18 + col * (col_w + 8)
                    ry = 110 + row * (row_h + 8)
                    rect = QRect(rx, ry, col_w, row_h)

                    is_selected = (getattr(self, "selected_theater", p_info["default_rival"]) == tk)
                    is_default = (p_info["default_rival"] == tk)
                    bg_col = QColor(38, 54, 78, 240) if is_selected else QColor(22, 34, 48, 225)
                    border_col = QColor(255, 215, 50) if is_selected else (QColor(100, 180, 240) if is_default else QColor(60, 100, 150))

                    painter.fillRect(rect, bg_col)
                    painter.setPen(border_col)
                    painter.drawRect(rect)

                    # Opponent Fighter 3D thumbnail or roll showcase
                    th_to_fighter = {
                        "imperial": "zero", "allied": "p38", "luftwaffe": "bf109",
                        "raf": "spitfire", "vvs": "yak3", "canada": "mosquito",
                        "mediterranean": "folgore", "france": "d520", "poland": "pzl11",
                        "czech": "avia"
                    }
                    opp_plane = th_to_fighter.get(tk, "zero")
                    s_frames = self.showcase_frames.get(opp_plane) if is_selected else None
                    if s_frames:
                        f_idx = (self.showcase_tick // 2) % len(s_frames)
                        painter.drawPixmap(QRect(rect.left() + 6, rect.top() + 18, 68, 68), s_frames[f_idx])
                    else:
                        pix = self.cache.get(opp_plane, {}).get("level_0")
                        if pix:
                            painter.drawPixmap(QRect(rect.left() + 6, rect.top() + 18, 68, 68), pix)
                        else:
                            boss_pix = self.enemy_sprites[tk]["boss"].get("pristine")
                            if boss_pix:
                                painter.drawPixmap(QRect(rect.left() + 6, rect.top() + 26, 68, 48), boss_pix)

                    # Information
                    key_tag = (i + 1) % 10
                    painter.setFont(QFont("Menlo", 9, QFont.Bold))
                    painter.setPen(QColor(255, 230, 80))
                    rec_tag = " ★" if is_default else ""
                    painter.drawText(rect.left() + 78, rect.top() + 20, f"[{key_tag}] {t_data['flag']} {t_data['name']}{rec_tag}")

                    painter.setFont(QFont("Menlo", 7))
                    painter.setPen(QColor(180, 210, 245))
                    painter.drawText(rect.left() + 78, rect.top() + 38, f"OPFOR: {t_data['enemy_title']}")
                    painter.setPen(QColor(255, 175, 45))
                    painter.drawText(rect.left() + 78, rect.top() + 56, f"BOSS: {t_data['boss_name']}")
                    if is_default:
                        painter.setPen(QColor(120, 255, 120))
                        painter.drawText(rect.left() + 78, rect.top() + 74, "★ RECOMMENDED RIVAL")

                # Footer
                painter.setPen(QColor(160, 180, 200))
                painter.setFont(font_sm)
                painter.drawText(QRect(0, self.height() - 28, self.width(), 24), Qt.AlignCenter, "[Arrows / 1-9, 0] Choose Theater  •  [Enter] Confirm  •  [Esc/Back] Change Plane")

                if self.audio_menu_open:
                    self.draw_audio_menu(painter)
                if getattr(self, "show_help_modal", False):
                    self.draw_help_modal(painter)
                return

            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            if getattr(self, "show_help_modal", False):
                self.draw_help_modal(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: GAME OVER / SHOT DOWN IN ACTION
        # ---------------------------------------------------------------------
        if self.state == "game_over":
            self.draw_game_over_screen(painter)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: ROUND CLEAR & REARMAMENT (ROUNDS 1 & 2)
        # ---------------------------------------------------------------------
        if self.state == "round_clear":
            self.draw_round_clear_screen(painter)
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: VICTORY & DEBRIEFING
        # ---------------------------------------------------------------------
        if self.state == "victory":
            painter.fillRect(self.rect(), QColor(12, 18, 28))
            
            # Subtle grid
            painter.setPen(QColor(25, 40, 60))
            for y in range(0, self.height(), 32): painter.drawLine(0, y, self.width(), y)
            for x in range(0, self.width(), 32): painter.drawLine(x, 0, x, self.height())

            font_big = QFont("Menlo", 20, QFont.Bold)
            font_title = QFont("Menlo", 13, QFont.Bold)
            font_row = QFont("Menlo", 11)

            # Banner
            painter.setPen(QColor(255, 220, 50))
            painter.setFont(font_big)
            painter.drawText(QRect(0, 24, self.width(), 32), Qt.AlignCenter, "★ MISSION ACCOMPLISHED ★")
            
            p_info = self.nation_info[self.current_plane]
            t_info = self.theaters[self.enemy_theater]

            painter.setFont(font_title)
            painter.setPen(QColor(100, 210, 255))
            painter.drawText(QRect(0, 58, self.width(), 24), Qt.AlignCenter, f"{t_info['name']} CAMPAIGN COMPLETED")

            # Debriefing Panel
            panel = QRect(28, 90, self.width() - 56, 625)
            painter.fillRect(panel, QColor(20, 30, 45, 235))
            painter.setPen(QColor(245, 205, 50))
            painter.drawRect(panel)

            pix = self.cache[self.current_plane]["level_0"]
            painter.drawPixmap(QRect(panel.left() + 20, panel.top() + 16, 110, 110), pix)

            painter.setFont(font_title)
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(panel.left() + 150, panel.top() + 38, f"PILOT: {p_info['pilot']}")
            painter.setPen(QColor(180, 215, 250))
            painter.setFont(font_row)
            painter.drawText(panel.left() + 150, panel.top() + 62, f"AIRCRAFT: {p_info['flag']} {p_info['name']}")
            painter.drawText(panel.left() + 150, panel.top() + 84, f"BASE    : {p_info['base']}")
            painter.drawText(panel.left() + 150, panel.top() + 106, f"THEATER : {t_info['name']}")

            painter.setPen(QColor(50, 80, 120))
            painter.drawLine(panel.left() + 15, panel.top() + 138, panel.right() - 15, panel.top() + 138)

            # Stat rows
            painter.setFont(font_row)
            stats_y = panel.top() + 168
            rows = [
                ("SCOUTS INTERCEPTED", f"{self.stats['scouts_killed']:02d}", f"{self.stats['scouts_killed'] * 100} PTS"),
                ("FIGHTER ACES DOWNED", f"{self.stats['interceptors_killed']:02d}", f"{self.stats['interceptors_killed'] * 250} PTS"),
                ("HEAVY BOMBERS SMASHED", f"{self.stats['bombers_killed']:02d}", f"{self.stats['bombers_killed'] * 800} PTS"),
                ("HOSTILE WARSHIPS SUNK", f"{self.stats.get('warships_sunk', 0):02d}", f"+{self.stats.get('warships_sunk', 0) * 1500} PTS"),
                ("GROUND TARGETS SMASHED", f"{self.stats.get('ground_targets_destroyed', 0):02d}", f"+{self.stats.get('ground_targets_destroyed', 0) * 800} PTS"),
                (f"BOSS: {t_info['boss_name']}", "DEFEATED" if self.stats['boss_killed'] else "ESCAPED", "20,000 PTS" if self.stats['boss_killed'] else "0 PTS"),
                ("FINAL COMBAT SCORE", "", f"{self.score:06d} PTS"),
                ("CARRIER RECOVERY", "SUCCESSFUL", "+5,000 PTS BONUS")
            ]

            for label, count_val, pts_val in rows:
                is_total = (label == "FINAL COMBAT SCORE")
                painter.setPen(QColor(255, 215, 50) if is_total else QColor(210, 230, 255))
                painter.drawText(panel.left() + 24, stats_y, label)
                if count_val:
                    painter.setPen(QColor(160, 200, 240))
                    painter.drawText(panel.left() + 235, stats_y, count_val)
                painter.setPen(QColor(100, 255, 140) if is_total else QColor(245, 245, 245))
                painter.drawText(panel.right() - 140, stats_y, pts_val)
                stats_y += 30

            # Dividing line above buttons
            painter.setPen(QColor(50, 80, 120))
            painter.drawLine(panel.left() + 15, panel.bottom() - 105, panel.right() - 15, panel.bottom() - 105)

            # Action buttons
            # 1. Normal Campaign Progression (Advance to next country on World Tour map)
            btn_next_tour = QRect(panel.left() + 20, panel.bottom() - 92, panel.width() - 40, 38)
            painter.fillRect(btn_next_tour, QColor(36, 80, 140, 240))
            painter.setPen(QPen(QColor(100, 210, 255), 1.5))
            painter.drawRect(btn_next_tour)
            painter.setPen(QColor(255, 255, 255))
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.drawText(btn_next_tour, Qt.AlignCenter, "★ [SPACE / CLICK] ADVANCE TO NEXT CAMPAIGN THEATER ★")

            # 2. Classified African Sahara Bonus Mission (Operation Blackout)
            btn_secret_mission = QRect(panel.left() + 20, panel.bottom() - 46, panel.width() - 40, 38)
            painter.fillRect(btn_secret_mission, QColor(48, 16, 22, 240))
            painter.setPen(QPen(QColor(255, 195, 45), 2))
            painter.drawRect(btn_secret_mission)
            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.setPen(QColor(255, 225, 70))
            painter.drawText(btn_secret_mission, Qt.AlignCenter, "📁 [S] TOP SECRET: OPERATION BLACKOUT (AFRICA BONUS) ⚠")

            painter.setPen(QColor(160, 180, 200))
            painter.setFont(font_row)
            painter.drawText(QRect(0, self.height() - 20, self.width(), 18), Qt.AlignCenter, "[Space] Next Country  •  [S] Secret Bonus Mission  •  [Esc] Hangar")
            if self.audio_menu_open:
                self.draw_audio_menu(painter)
            return

        # ---------------------------------------------------------------------
        # SCREEN: IN-FLIGHT COMBAT / TAKEOFF / LANDING
        # ---------------------------------------------------------------------
        # Screen Shake
        painter.save()
        if self.screen_shake > 0:
            ox = random.randint(-self.screen_shake, self.screen_shake)
            oy = random.randint(-self.screen_shake, self.screen_shake)
            painter.translate(ox, oy)

        # 1. Environmental Background Progression Across Rounds
        # 1. Environmental Background Progression Across Rounds
        # During takeoff: starts on ocean, transitions to destination theater background while inside cloud cover (tick 300)
        show_ocean_base = (
            (self.state == "takeoff" and self.takeoff_tick < 300)
            or (self.state == "landing" and self.landing_tick >= 80)
            or (self.carrier_y > -750 and self.carrier_y < self.height() + 250)
            or (self.current_round == 2 and not self.is_secret_mission)
        )

        if show_ocean_base:
            # -----------------------------------------------------------------
            # CARRIER OPERATIONS / OCEAN BASE: PURE DEEP WATER & SWELLS
            # -----------------------------------------------------------------
            t_data = self.theaters[self.enemy_theater]
            w_r, w_g, w_b = t_data["water_color"]
            wl_r, wl_g, wl_b = t_data["water_line"]
            painter.fillRect(self.rect(), QColor(w_r, w_g, w_b))

            # Drifting ocean swells & whitecap ripples
            painter.setPen(QColor(wl_r, wl_g, wl_b, 130))
            for y in range(-48, self.height() + 48, 24):
                wave_y = y + self.ocean_y
                painter.drawLine(0, wave_y, self.width(), wave_y)

            # Cloud cover transition during landing:
            # Starts in thick cloud bank, then clouds part revealing ocean & carrier below
            if self.state == "landing" and self.landing_tick < 80:
                l_prog = min(1.0, self.landing_tick / 75.0)
                cloud_alpha = int(240 * (1.0 - l_prog))
                if cloud_alpha > 0 and not self.cloud_bed_pixmap.isNull():
                    painter.save()
                    painter.setOpacity(cloud_alpha / 255.0)
                    c_w = self.cloud_bed_pixmap.width()
                    c_h = self.cloud_bed_pixmap.height()
                    c_y = int(self.world_scroll_y * 0.85) % c_h
                    for tx in range(-c_w // 2, self.width() + c_w, c_w):
                        painter.drawPixmap(tx, c_y - c_h, self.cloud_bed_pixmap)
                        painter.drawPixmap(tx, c_y, self.cloud_bed_pixmap)
                    painter.restore()

        elif self.current_round == 1:
            # -----------------------------------------------------------------
            # ROUND 1: STRATOSPHERE / HIGH SKY (OCEAN BASE + MULTI-LAYER CLOUDS)
            # -----------------------------------------------------------------
            # 1. Base Layer: Deep ocean floor beneath clouds
            t_data = self.theaters[self.enemy_theater]
            w_r, w_g, w_b = t_data["water_color"]
            wl_r, wl_g, wl_b = t_data["water_line"]
            painter.fillRect(self.rect(), QColor(w_r, w_g, w_b))

            # Drifting ocean swells visible under any cloud rifts
            painter.setPen(QColor(wl_r, wl_g, wl_b, 75))
            for y in range(-48, self.height() + 48, 24):
                wave_y = y + self.ocean_y
                painter.drawLine(0, wave_y, self.width(), wave_y)

            # 2. Dense Seamless Cloud Bed Floor (Scrolling over ocean)
            if not self.cloud_bed_pixmap.isNull():
                c_w = self.cloud_bed_pixmap.width()
                c_h = self.cloud_bed_pixmap.height()
                c_y = int(self.world_scroll_y * 0.85) % c_h
                for tx in range(0, self.width() + c_w, c_w):
                    painter.drawPixmap(tx, c_y - c_h, self.cloud_bed_pixmap)
                    painter.drawPixmap(tx, c_y, self.cloud_bed_pixmap)
                    painter.drawPixmap(tx, c_y + c_h, self.cloud_bed_pixmap)

            # 3. Floating Upper Cumulus Puffs (Billowing at parallax speeds with soft drop-shadows)
            for c in self.clouds:
                if not self.cloud_pixmaps:
                    continue
                pix = self.cloud_pixmaps[c["type"] % len(self.cloud_pixmaps)]
                sc = c.get("scale", 1.0)
                w = int(pix.width() * sc)
                h = int(pix.height() * sc)

                # Soft shadow onto cloud deck
                painter.save()
                painter.setOpacity(0.18)
                painter.translate(c["x"] + 20, c["y"] + 24)
                if c.get("rotation", 0): painter.rotate(c["rotation"])
                if c.get("flip_h", False): painter.scale(-1, 1)
                painter.drawPixmap(-w // 2, -h // 2, w, h, pix)
                painter.restore()

                # Crisp sunlit cloud puff
                painter.save()
                painter.setOpacity(0.85)
                painter.translate(c["x"], c["y"])
                if c.get("rotation", 0): painter.rotate(c["rotation"])
                if c.get("flip_h", False): painter.scale(-1, 1)
                painter.drawPixmap(-w // 2, -h // 2, w, h, pix)
                painter.restore()

        elif self.current_round == 3 or self.is_secret_mission:
            # -----------------------------------------------------------------
            # ROUND 3 / OPERATION BLACKOUT: MAINLAND THEATER COUNTRYSIDE
            # -----------------------------------------------------------------
            terrain_pix = self.theater_terrains.get(self.enemy_theater, self.mainland_terrain_pixmap)
            m_h = terrain_pix.height() if not terrain_pix.isNull() else 1536
            m_y = int(self.world_scroll_y) % m_h
            if not terrain_pix.isNull():
                painter.drawPixmap(0, m_y - m_h, terrain_pix)
                painter.drawPixmap(0, m_y, terrain_pix)
            else:
                painter.fillRect(self.rect(), QColor(55, 95, 45))

            # Draw Ground Targets (Tanks, Pillbox Bunkers, Flak 88s, Hangars, Tents)
            for g in self.ground_targets:
                gx, gy = int(g["x"]), int(g["y"])
                g_model = g["model"]
                stage_name = "wreck" if g.get("wreck") else ("damaged" if g["hp"] <= g["max_hp"] * 0.5 else "pristine")

                if g["type"] == "tank":
                    pix = self.tank_sprites.get(g_model, {}).get(stage_name)
                else:
                    pix = self.structure_sprites.get(g_model, {}).get(stage_name)

                if not pix or pix.isNull():
                    continue

                pw, ph = pix.width(), pix.height()

                # Soft ground shadow for vehicles and fortifications
                if not g.get("wreck"):
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor(15, 25, 15, 75))
                    painter.drawEllipse(gx - pw // 2 + 4, gy - ph // 2 + 10, pw, ph - 6)

                painter.save()
                if g["hit_flash"] > 0:
                    painter.setOpacity(0.65)
                painter.drawPixmap(gx - pw // 2, gy - ph // 2, pix)
                painter.restore()

            # Draw Cartel Underground Hangar Complex (Ground Redoubt)
            if self.cartel_hangar and self.cartel_hangar.get("active"):
                h = self.cartel_hangar
                hx, hy = int(h["x"]), int(h["y"])
                if h.get("exploding"):
                    h_pix = self.hangar_sprites["wreck"]
                elif h["hp"] <= h["max_hp"] * 0.5:
                    h_pix = self.hangar_sprites["damaged"]
                else:
                    h_pix = self.hangar_sprites["pristine"]

                if h_pix and not h_pix.isNull():
                    hw, hh = 440, 440
                    # Deep concrete shadow
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor(10, 15, 10, 95))
                    painter.drawRect(hx - hw // 2 + 10, hy - hh // 2 + 15, hw, hh)

                    painter.save()
                    if h.get("hit_flash", 0) > 0:
                        painter.setOpacity(0.65)
                    painter.drawPixmap(hx - hw // 2, hy - hh // 2, hw, hh, h_pix)
                    painter.restore()

                    # Fortified Flak Turrets
                    for t in h.get("turrets", []):
                        if t.get("active", True):
                            tx = hx + t["ox"]
                            ty = hy + t["oy"]
                            painter.setPen(QColor(35, 35, 40))
                            painter.setBrush(QColor(75, 80, 85))
                            painter.drawEllipse(tx - 11, ty - 11, 22, 22)
                            painter.setBrush(QColor(40, 45, 50))
                            painter.drawEllipse(tx - 5, ty - 5, 10, 10)
                            painter.setPen(QPen(QColor(20, 20, 25), 3))
                            painter.drawLine(tx, ty, tx, ty + 14)

        else:
            # -----------------------------------------------------------------
            # ROUND 2: COASTAL OCEAN FLEET (OPEN WATER & SEPARATED SEA LANES)
            # -----------------------------------------------------------------
            t_data = self.theaters[self.enemy_theater]
            w_r, w_g, w_b = t_data["water_color"]
            wl_r, wl_g, wl_b = t_data["water_line"]
            painter.fillRect(self.rect(), QColor(w_r, w_g, w_b))

            # Drifting ocean waves
            painter.setPen(QColor(wl_r, wl_g, wl_b, 140))
            for y in range(-48, self.height() + 48, 24):
                wave_y = y + self.ocean_y
                painter.drawLine(0, wave_y, self.width(), wave_y)

            # Cloud drop-shadows on ocean
            for c in self.clouds:
                if not self.cloud_pixmaps:
                    continue
                pix = self.cloud_pixmaps[c["type"] % len(self.cloud_pixmaps)]
                painter.save()
                painter.setOpacity(0.18)
                painter.translate(c["x"] + 24, c["y"] + 32)
                if c.get("rotation", 0):
                    painter.rotate(c["rotation"])
                if c.get("flip_h", False):
                    painter.scale(-1, 1)
                sc = c.get("scale", 1.0)
                w = int(pix.width() * sc)
                h = int(pix.height() * sc)
                painter.drawPixmap(-w // 2, -h // 2, w, h, pix)
                painter.restore()
            painter.setOpacity(1.0)

            # Distant Coastal Islands in dead space between ship groups
            if self.enemy_theater == "imperial":
                active_islands = self.japan_island_pixmaps
            elif self.enemy_theater in ("raf", "luftwaffe"):
                active_islands = self.uk_island_pixmaps
            elif self.enemy_theater in ("canada", "vvs"):
                active_islands = self.arctic_island_pixmaps
            else:
                active_islands = self.pacific_island_pixmaps

            for isl in self.islands:
                if not active_islands:
                    continue
                pix = active_islands[isl["type"] % len(active_islands)]
                painter.save()
                painter.translate(isl["x"], isl["y"])
                if isl.get("flip_h", False):
                    painter.scale(-1, 1)
                sc = isl.get("scale", 1.0)
                w = int(pix.width() * sc)
                h = int(pix.height() * sc)
                painter.drawPixmap(-w // 2, -h // 2, w, h, pix)
                painter.restore()

        # 3. Aircraft Carrier / Runway
        if self.carrier_y > -750 and self.carrier_y < self.height() + 250:
            cx = self.width() // 2
            cy = int(self.carrier_y)
            c_w, c_h = 320, 720

            carrier_pix = self.carrier_pixmaps.get(self.current_plane)
            if carrier_pix and not carrier_pix.isNull():
                dest_rect = QRect(cx - c_w // 2, cy, c_w, c_h)
                painter.drawPixmap(dest_rect, carrier_pix)

        # 3.5 Hostile 3D Cel-Shaded Naval Warships
        for w in self.warships:
            wx, wy = int(w["x"]), int(w["y"])
            w_type = w["type"]
            stage_idx = 0 if w["hp"] > w["max_hp"] * 0.5 else (1 if w["hp"] > 0 else 2)
            stage_name = ["pristine", "damaged", "wreck"][stage_idx]
            ship_pix = self.warship_sprites[w_type][stage_name]
            if ship_pix.isNull():
                continue

            sw, sh = ship_pix.width(), ship_pix.height()

            painter.save()
            if w.get("sinking"):
                sink_prog = min(1.0, w.get("sink_tick", 0) / 70.0)
                painter.setOpacity(max(0.0, 1.0 - sink_prog))
                painter.translate(wx, wy)
                painter.rotate(sink_prog * 10.0)
                painter.translate(-wx, -wy)

            # Ocean Bow V-Wake & Propeller Wash
            wake_cycle = (w.get("wake_tick", 0) // 4) % 6
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(225, 245, 255, 65))
            bow_y = wy - sh // 2 + 15
            for i in range(3):
                spread = 16 + i * 14 + wake_cycle * 2
                dy = bow_y + 30 + i * 26
                painter.drawEllipse(wx - spread - 8, dy, 16, 7)
                painter.drawEllipse(wx + spread - 8, dy, 16, 7)
            # Propeller wash at stern
            stern_y = wy + sh // 2 - 15
            painter.setBrush(QColor(240, 250, 255, 90))
            painter.drawEllipse(wx - 14, stern_y + 4, 28, 20 + wake_cycle * 3)

            # Warship Hull
            if w.get("hit_flash", 0) > 0:
                painter.setOpacity(0.65)
            painter.drawPixmap(wx - sw // 2, wy - sh // 2, ship_pix)
            painter.setOpacity(1.0 if not w.get("sinking") else max(0.0, 1.0 - w.get("sink_tick", 0) / 70.0))

            # Independent Rotating 3D Turrets
            for t in w.get("turrets", []):
                t_type = t["type"]
                frame_idx = t.get("frame_idx", 0)
                tx = wx + t["ox"]
                ty = wy + t["oy"]
                if t_type == "heavy":
                    sheet = self.turret_heavy_sheet
                    tw, th = 80, 80
                else:
                    sheet = self.turret_destroyer_sheet
                    tw, th = 64, 64

                if not sheet.isNull():
                    src_rect = QRect(frame_idx * tw, 0, tw, th)
                    dest_rect = QRect(tx - tw // 2, ty - th // 2, tw, th)
                    painter.drawPixmap(dest_rect, sheet, src_rect)

            painter.restore()

        # 3.8 Takeoff Cloud Bed Floor (Solid cloud layer between sea/ground and plane)
        # Sequence: 160..210 (clouds roll in), 210..390 (3 full seconds of solid clouds), 390..450 (dissipate over land)
        if self.state == "takeoff" and self.takeoff_tick >= 160 and self.takeoff_tick < 450:
            if self.takeoff_tick < 210:
                cloud_alpha = int(255 * ((self.takeoff_tick - 160) / 50.0))
            elif self.takeoff_tick < 390:
                cloud_alpha = 255  # Solid impenetrable overcast for 3.0 seconds
            else:
                cloud_alpha = int(255 * (1.0 - (self.takeoff_tick - 390) / 60.0))

            if cloud_alpha > 0 and not self.cloud_bed_pixmap.isNull():
                painter.save()
                painter.setOpacity(cloud_alpha / 255.0)
                c_w = self.cloud_bed_pixmap.width()
                c_h = self.cloud_bed_pixmap.height()
                c_y = int(self.world_scroll_y * 1.3) % c_h
                for tx in range(-c_w // 2, self.width() + c_w, c_w):
                    painter.drawPixmap(tx, c_y - c_h, self.cloud_bed_pixmap)
                    painter.drawPixmap(tx, c_y, self.cloud_bed_pixmap)
                    painter.drawPixmap(tx, c_y + c_h, self.cloud_bed_pixmap)
                painter.restore()

        # 4. Boss: Super Heavy Fortress
        if self.boss and self.boss["active"]:
            b = self.boss
            bx, by = int(b["x"]), int(b["y"])
            b_faction = b["faction"]
            stage = b["damage_stage"]
            stage_names = ["pristine", "wing_damaged", "critical_wreck"]
            frame_key = stage_names[min(stage, 2)]

            boss_pix = self.enemy_sprites[b_faction]["boss"].get(frame_key)


            if boss_pix:
                painter.drawPixmap(QRect(bx - 192, by - 128, 384, 256), boss_pix)

            # Dedicated Arcade Boss Health Gauge (Top Position Below HUD)
            bar_w = 340
            painter.fillRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28), QColor(12, 18, 28, 235))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QColor(245, 185, 45))
            painter.drawRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28))

            if not b.get("vulnerable", False):
                warn_col = QColor(255, 210, 40) if (self.prop_tick // 4) % 2 == 0 else QColor(255, 60, 60)
                painter.setPen(warn_col)
                painter.setFont(QFont("Menlo", 9, QFont.Bold))
                painter.drawText(QRect(self.width()//2 - bar_w//2, 126, bar_w, 28), Qt.AlignCenter, f"⚠ {b['title']}: DESCENDING ONTO STATION ⚠")
            else:
                fill_w = int(bar_w * (b["hp"] / b["max_hp"]))
                painter.fillRect(QRect(self.width()//2 - bar_w//2, 142, fill_w, 8), QColor(240, 45, 45))
                painter.setPen(QColor(255, 230, 80))
                painter.setFont(QFont("Menlo", 9, QFont.Bold))
                painter.drawText(QRect(self.width()//2 - bar_w//2, 127, bar_w, 15), Qt.AlignCenter, f"★ {b['title']} [{b['hp']}/{b['max_hp']}] ★")

        # Dedicated Boss Health Gauge for Cartel Hangar Complex
        if self.cartel_hangar and self.cartel_hangar.get("active"):
            h = self.cartel_hangar
            bar_w = 360
            painter.fillRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28), QColor(12, 18, 28, 235))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QColor(245, 185, 45))
            painter.drawRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28))

            if h.get("exploding"):
                painter.setPen(QColor(255, 60, 60))
                painter.setFont(QFont("Menlo", 9, QFont.Bold))
                painter.drawText(QRect(self.width()//2 - bar_w//2, 126, bar_w, 28), Qt.AlignCenter, "★ FACILITY DETONATION IN PROGRESS ★")
            else:
                pct = max(0.0, min(1.0, h["hp"] / float(h["max_hp"])))
                fill_w = int(bar_w * pct)
                col = QColor(240, 45, 45) if pct < 0.35 else QColor(255, 140, 30)
                painter.fillRect(QRect(self.width()//2 - bar_w//2, 142, fill_w, 8), col)
                painter.setPen(QColor(255, 230, 80))
                painter.setFont(QFont("Menlo", 9, QFont.Bold))
                painter.drawText(QRect(self.width()//2 - bar_w//2, 127, bar_w, 15), Qt.AlignCenter, f"★ CARTEL UNDERGROUND HANGAR [{h['hp']}/{h['max_hp']}] ★")

        # 5. Enemies (Using Dedicated High-Res Sprites)
        for e in self.enemies:
            ex, ey = int(e["x"]), int(e["y"])
            faction = e["faction"]
            e_type = e["type"]
            vx = e.get("vx", 0)

            # Shadow
            painter.setOpacity(0.26)
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(10, 20, 35))
            sh_w = 60 if e_type == "bomber" else 36
            painter.drawEllipse(ex - sh_w//2, ey + 26, sh_w, 22)
            painter.setOpacity(1.0)

            # Choose animation frame
            p_idx = (self.prop_tick // 4) % 2
            if e_type == "bomber":
                frame_key = "damaged_engine" if e["hp"] <= 4 else f"fly_{p_idx}"
                cell_w, cell_h = 192, 160
            else:
                if vx < -1.0: frame_key = "bank_left"
                elif vx > 1.0: frame_key = "bank_right"
                else: frame_key = f"fly_{p_idx}"
                cell_w, cell_h = 96, 96

            spr_dict = self.enemy_sprites.get(faction, {}).get(e_type, {})
            pix = spr_dict.get(frame_key)
            if not pix and faction in self.unsung_sprites:
                u_dict = self.unsung_sprites[faction]
                if vx < -1.0: pix = u_dict.get("left")
                elif vx > 1.0: pix = u_dict.get("right")
                else: pix = u_dict.get("level")
                cell_w, cell_h = 88, 88

            if pix:
                dest = QRect(ex - cell_w//2, ey - cell_h//2, cell_w, cell_h)
                painter.drawPixmap(dest, pix)
                if e.get("hit_flash", 0) > 0:
                    flash_pix = self.get_flash_pixmap(pix, QColor(255, 255, 255, 230))
                    painter.drawPixmap(dest, flash_pix)

        # 6. Enemy Bullets
        for eb in self.enemy_bullets:
            bx, by = int(eb["x"]), int(eb["y"])
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(255, 80, 30, 200))
            painter.drawEllipse(QRect(bx - 6, by - 6, 12, 12))
            painter.setBrush(QColor(255, 230, 120))
            painter.drawEllipse(QRect(bx - 3, by - 3, 6, 6))

        # 7. Pickups (Official High-Res Shimmering Badges & Dedicated Repair Kits)
        for p in self.pickups:
            px, py = int(p["x"]), int(p["y"])
            p_type = p.get("type", "pow")
            shimmer = (self.prop_tick // 8) % 2

            if p_type in ("repair", "health"):
                # Glistening Military Field Medic / Armor Repair Crate Badge
                pulse = (self.prop_tick // 4) % 2
                painter.save()
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(40, 240, 100, 75 if pulse else 35))
                painter.drawEllipse(px - 24, py - 24, 48, 48)

                painter.setBrush(QColor(18, 45, 28, 235))
                painter.setPen(QPen(QColor(255, 215, 60), 2))
                painter.drawEllipse(px - 18, py - 18, 36, 36)

                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(245, 255, 250))
                painter.drawRect(px - 11, py - 4, 22, 8)
                painter.drawRect(px - 4, py - 11, 8, 22)

                painter.setBrush(QColor(235, 45, 45))
                painter.drawRect(px - 9, py - 2, 18, 4)
                painter.drawRect(px - 2, py - 9, 4, 18)

                painter.setFont(QFont("Menlo", 7, QFont.Bold))
                painter.setPen(QColor(255, 235, 100))
                painter.drawText(QRect(px - 20, py + 18, 40, 14), Qt.AlignCenter, "+HP")
                painter.restore()
                continue

            if p_type == "support":
                # Military Tactical Air Support Radio Crate Badge
                painter.save()
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(255, 215, 60, 65 if shimmer else 30))
                painter.drawEllipse(px - 22, py - 22, 44, 44)

                painter.setBrush(QColor(24, 36, 52, 240))
                painter.setPen(QPen(QColor(255, 215, 60), 2))
                painter.drawRoundedRect(px - 16, py - 16, 32, 32, 6, 6)

                painter.setFont(QFont("Menlo", 7, QFont.Bold))
                painter.setPen(QColor(100, 240, 255))
                painter.drawText(QRect(px - 16, py - 12, 32, 14), Qt.AlignCenter, "RAD")
                painter.setPen(QColor(255, 225, 80))
                painter.drawText(QRect(px - 16, py + 2, 32, 12), Qt.AlignCenter, "AIR")
                painter.restore()
                continue

            if p_type == "pow": frame_key = f"pow_{shimmer}"
            elif p_type == "wing": frame_key = f"wing_{shimmer}"
            elif p_type == "bomb": frame_key = f"bomb_{shimmer}"
            elif p_type == "loop": frame_key = f"loop_{shimmer}"
            elif p_type == "medal": frame_key = "medal_gold"
            else: frame_key = f"pow_{shimmer}"

            badge_pix = self.pickup_sprites.get(frame_key)
            if badge_pix:
                painter.drawPixmap(QRect(px - 22, py - 22, 44, 44), badge_pix)
            else:
                painter.setPen(QColor(255, 235, 80))
                painter.setBrush(QColor(225, 110, 20))
                painter.drawRoundedRect(QRect(px - 14, py - 12, 28, 24), 5, 5)

        # 8. Player Aircraft Sprite Calculation
        plane_cache = self.cache[self.current_plane]
        p_idx = (self.prop_tick // 3) % 3

        if self.state == "takeoff":
            if self.takeoff_tick < 95:
                pix = plane_cache[f"level_{(self.prop_tick // 3) % 4}"]
                status_text = "CATAPULT RUNWAY: ACCELERATING"
            elif self.takeoff_tick < 125:
                pix = plane_cache[f"climb_steep_{p_idx}"]
                status_text = "AIRBORNE! NOSE PITCHES UP INTO CLIMB"
            elif self.takeoff_tick < 155:
                pix = plane_cache[f"climb_mild_{p_idx}"]
                status_text = "LEVELING OUT AT CRUISE"
            else:
                pix = plane_cache[f"level_{(self.prop_tick // 3) % 4}"]
                status_text = "CRUISE FORMATION"
        elif self.state == "landing":
            if self.landing_tick < 95:
                pix = plane_cache[f"climb_mild_{p_idx}"]
                status_text = "GLIDESLOPE DESCENT"
            else:
                pix = plane_cache[f"level_{(self.prop_tick // 3) % 4}"]
                status_text = "TOUCHDOWN: RECOVERY CAUGHT"
        elif self.is_looping:
            stage_idx = min(len(self.loop_stages) - 1, self.loop_tick // 5)
            pix = plane_cache[f"loop_{stage_idx}_{p_idx}"]
            status_text = f"360° LOOP (STAGE {stage_idx + 1}/8)"
        else:
            if abs(self.bank_angle) > 20:
                tag = "left" if self.bank_angle < 0 else "right"
                pix = plane_cache[f"bank_hard_{tag}_{p_idx}"]
                status_text = f"HARD BANK {tag.upper()}"
            elif abs(self.bank_angle) > 6:
                tag = "left" if self.bank_angle < 0 else "right"
                pix = plane_cache[f"bank_{tag}_{p_idx}"]
                status_text = f"BANK {tag.upper()}"
            else:
                pix = plane_cache[f"level_{(self.prop_tick // 3) % 4}"]
                status_text = "LEVEL FLIGHT"

        # Scale & Position
        if self.state == "takeoff":
            cur_scale = 0.42 if self.takeoff_tick < 110 else (0.42 + 0.58 * min(1.0, (self.takeoff_tick - 110)/50.0))
            shadow_dist = int(6 + 28 * min(1.0, (self.takeoff_tick - 110)/50.0)) if self.takeoff_tick >= 110 else 6
            plane_y = self.y
        elif self.state == "landing":
            cur_scale = 1.0 if self.landing_tick < 40 else (1.0 - 0.58 * min(1.0, (self.landing_tick - 40)/55.0))
            shadow_dist = int(34 - 28 * min(1.0, (self.landing_tick - 40)/55.0)) if self.landing_tick >= 40 else 34
            plane_y = self.y
        elif self.is_looping:
            cur_stage = min(len(self.loop_stages) - 1, self.loop_tick // 5)
            scale_curve = [1.0, 1.18, 1.38, 1.50, 1.40, 1.22, 1.08, 1.0]
            cur_scale = scale_curve[cur_stage]
            shadow_dist = int(34 + (cur_scale - 1.0) * 80)
            plane_y = self.y - int((cur_scale - 1.0) * 60)
        else:
            cur_scale = 1.0
            plane_y = self.y
            shadow_dist = 34

        base_size = 170
        display_w, display_h = int(base_size * cur_scale), int(base_size * cur_scale)

        # Player Shadow
        painter.setOpacity(0.32)
        shadow_rect = QRect(int(self.x - display_w//2 + 14), int(self.y - display_h//2 + shadow_dist), int(display_w*0.75), int(display_h*0.75))
        painter.drawPixmap(shadow_rect, pix)
        painter.setOpacity(1.0)

        # 9. Bullets & Missiles (UNDER AIRCRAFT WINGS)
        for b in self.bullets:
            bx, by, b_type = b["x"], b["y"], b.get("type", "twin")
            painter.setPen(Qt.NoPen)
            if b_type == "shotgun":
                painter.setBrush(QColor(80, 230, 255, 190)); painter.drawEllipse(QRect(int(bx - 6), int(by - 6), 12, 12))
            elif b_type == "quad":
                painter.setBrush(QColor(255, 120, 20, 180)); painter.drawRoundedRect(QRect(int(bx - 3), int(by - 16), 6, 20), 3, 3)
            elif b_type == "threeway":
                painter.setBrush(QColor(255, 140, 40, 210)); painter.drawRoundedRect(QRect(int(bx - 2.5), int(by - 14), 5, 18), 2.5, 2.5)
            else:
                painter.setBrush(QColor(255, 180, 30, 200)); painter.drawRoundedRect(QRect(int(bx - 2), int(by - 12), 4, 16), 2, 2)

        for m in self.missiles:
            mx, my = int(m["x"]), int(m["y"])
            painter.setPen(Qt.NoPen); painter.setBrush(QColor(255, 120, 20)); painter.drawEllipse(mx - 3, my + 6, 6, 8)
            painter.setBrush(QColor(230, 235, 240)); painter.drawRoundedRect(QRect(mx - 3, my - 8, 6, 16), 2, 2)

        for f in self.muzzle_flashes:
            painter.setPen(Qt.NoPen); painter.setBrush(QColor(255, 220, 40, 240)); painter.drawEllipse(QRect(int(f["x"] - 5), int(f["y"] - 5), 10, 10))

        # 10. Escort Fighters
        if self.weapons[self.weapon_idx] == "escorts" and self.state == "playing" and not self.is_looping:
            escort_size = 96
            painter.drawPixmap(QRect(int(self.x - 56 - escort_size//2), int(plane_y + 14 - escort_size//2), escort_size, escort_size), pix)
            painter.drawPixmap(QRect(int(self.x + 56 - escort_size//2), int(plane_y + 14 - escort_size//2), escort_size, escort_size), pix)

        # 10.1 Secret Coalition AI Wingmen (Operation Blackout)
        if self.is_secret_mission and self.state == "playing":
            for w in self.secret_wingmen:
                wx, wy, w_plane = int(w["x"]), int(w["y"]), w["plane"]
                w_cache = self.cache.get(w_plane)
                if not w_cache:
                    continue
                w_bank = w.get("bank_angle", 0.0)
                p_idx = (self.prop_tick // 3) % 3
                if abs(w_bank) > 18:
                    tag = "left" if w_bank < 0 else "right"
                    w_pix = w_cache.get(f"bank_hard_{tag}_{p_idx}", w_cache.get("level_0"))
                elif abs(w_bank) > 6:
                    tag = "left" if w_bank < 0 else "right"
                    w_pix = w_cache.get(f"bank_{tag}_{p_idx}", w_cache.get("level_0"))
                else:
                    w_pix = w_cache.get(f"level_{(self.prop_tick // 3) % 4}", w_cache.get("level_0"))

                w_scale = 1.15 if w_plane == "b29" else 1.0
                w_size = int(140 * w_scale)

                # Shadow
                painter.setOpacity(0.28)
                painter.drawPixmap(QRect(wx - w_size//2 + 12, wy - w_size//2 + 28, int(w_size*0.75), int(w_size*0.75)), w_pix)
                painter.setOpacity(1.0)

                # Aircraft Sprite
                dest_w = QRect(wx - w_size//2, wy - w_size//2, w_size, w_size)
                painter.drawPixmap(dest_w, w_pix)
                if w.get("hit_flash", 0) > 0:
                    flash_w = self.get_flash_pixmap(w_pix, QColor(255, 80, 80, 220))
                    painter.drawPixmap(dest_w, flash_w)

                # Callout Tag
                painter.setFont(QFont("Menlo", 7, QFont.Bold))
                painter.setPen(QColor(255, 215, 60, 200))
                painter.drawText(QRect(wx - 60, wy + w_size//2 - 10, 120, 14), Qt.AlignCenter, f"{w['name'][:12]}")

        # 10.2 Tactical Air Support Ace (10 Seconds of Glory)
        if self.air_support_active and self.air_support_obj:
            obj = self.air_support_obj
            ax, ay, hero = int(obj["x"]), int(obj["y"]), obj["hero"]
            hero_sprites = self.unsung_sprites.get(hero, {})
            h_bank = obj.get("bank_angle", 0.0)
            if h_bank < -10 and "left" in hero_sprites:
                a_pix = hero_sprites["left"]
            elif h_bank > 10 and "right" in hero_sprites:
                a_pix = hero_sprites["right"]
            else:
                a_pix = hero_sprites.get("level")

            if a_pix and not a_pix.isNull():
                a_size = 118
                # Shadow
                painter.setOpacity(0.30)
                painter.drawPixmap(QRect(ax - a_size//2 + 14, ay - a_size//2 + 30, int(a_size*0.75), int(a_size*0.75)), a_pix)
                painter.setOpacity(1.0)

                # Aircraft Sprite
                dest_a = QRect(ax - a_size//2, ay - a_size//2, a_size, a_size)
                painter.drawPixmap(dest_a, a_pix)

                # Engine exhaust glow
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(255, 200, 80, 180))
                painter.drawEllipse(ax - 3, ay + a_size//2 - 18, 6, 8)

                # Tactical Callout Tag & Countdown
                rem_secs = max(0, self.air_support_timer // 60)
                painter.setFont(QFont("Menlo", 7, QFont.Bold))
                painter.setPen(QColor(100, 240, 140))
                painter.drawText(QRect(ax - 70, ay - a_size//2 - 14, 140, 14), Qt.AlignCenter, f"★ {obj['name']} ({rem_secs}s) ★")

        # 11. Multi-Stage Volumetric Smoke, Flame & Spark Trails
        for sm in self.smoke_particles:
            sx, sy, r, s_type = int(sm["x"]), int(sm["y"]), int(sm["rad"]), sm["type"]
            life_ratio = sm["life"] / max(1, sm.get("max_life", 25))
            painter.setPen(Qt.NoPen)

            if s_type == "vapor":
                grad = QRadialGradient(sx, sy, max(1, r))
                grad.setColorAt(0.0, QColor(220, 230, 245, int(140 * life_ratio)))
                grad.setColorAt(0.65, QColor(200, 215, 235, int(70 * life_ratio)))
                grad.setColorAt(1.0, QColor(180, 200, 225, 0))
                painter.setBrush(grad)
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))

            elif s_type == "black_smoke":
                grad = QRadialGradient(sx, sy, max(1, r))
                grad.setColorAt(0.0, QColor(24, 26, 30, int(210 * life_ratio)))
                grad.setColorAt(0.45, QColor(40, 44, 50, int(150 * life_ratio)))
                grad.setColorAt(0.80, QColor(55, 60, 68, int(60 * life_ratio)))
                grad.setColorAt(1.0, QColor(65, 70, 78, 0))
                painter.setBrush(grad)
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))

            elif s_type == "fire":
                grad = QRadialGradient(sx, sy, max(1, r))
                grad.setColorAt(0.0, QColor(255, 245, 190, int(255 * life_ratio))) # White-hot core
                grad.setColorAt(0.30, QColor(255, 145, 25, int(220 * life_ratio))) # Intense orange
                grad.setColorAt(0.70, QColor(225, 45, 15, int(140 * life_ratio)))  # Crimson flame
                grad.setColorAt(1.0, QColor(160, 20, 5, 0))                         # Feathered fade
                painter.setBrush(grad)
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))

            elif s_type == "spark":
                painter.setPen(QColor(255, 230, 110, int(255 * life_ratio)))
                vx = sm.get("vx", 0)
                vy = sm.get("vy", 0)
                painter.drawLine(sx, sy, sx - int(vx * 1.5), sy - int(vy * 1.5))

        # 12. Main Player Aircraft Sprite
        jitter = random.choice([-1, 0, 1]) if self.hp == 1 else 0
        if self.invulnerable_ticks > 0 and self.hit_flash_ticks == 0:
            if (self.invulnerable_ticks // 3) % 2 == 0: painter.setOpacity(0.35)

        painter.save()
        if self.death_ticks > 0 and self.state == "playing":
            painter.translate(self.x, plane_y)
            painter.rotate(self.death_ticks * 16.0)
            d_scale = max(0.40, 1.0 - self.death_ticks * 0.007)
            painter.scale(d_scale, d_scale)
            dest_rect = QRect(-display_w // 2, -display_h // 2, display_w, display_h)
        else:
            dest_rect = QRect(int(self.x + jitter - display_w // 2), int(plane_y + jitter - display_h // 2), display_w, display_h)

        painter.drawPixmap(dest_rect, pix)

        if self.hit_flash_ticks > 0:
            flash_col = QColor(255, 255, 255, 240) if self.hit_flash_ticks % 2 == 0 else QColor(255, 60, 60, 220)
            flash_pix = self.get_flash_pixmap(pix, flash_col)
            painter.drawPixmap(dest_rect, flash_pix)

        painter.restore()
        painter.setOpacity(1.0)


        # 14. Sparks & Explosions
        for sp in self.spark_particles:
            painter.setPen(Qt.NoPen); painter.setBrush(sp.get("color", QColor(255, 255, 255))); painter.drawEllipse(int(sp["x"] - 2), int(sp["y"] - 2), 4, 4)
        for exp in self.explosions:
            ex, ey, r = int(exp["x"]), int(exp["y"]), int(exp["radius"])
            painter.setPen(Qt.NoPen); painter.setBrush(QColor(255, 120, 30, 160)); painter.drawEllipse(QRect(ex - r, ey - r, r * 2, r * 2))

        # Floating Combat Texts (e.g. +2 ARMOR REPAIR)
        for ft in self.floating_texts:
            fx, fy = int(ft["x"]), int(ft["y"])
            alpha = max(0, min(255, int(255 * (ft["life"] / 30.0))))
            c = ft.get("color", QColor(80, 255, 120))
            painter.save()
            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.setPen(QColor(0, 0, 0, alpha))
            painter.drawText(fx - 49, fy + 1, ft["text"])
            painter.setPen(QColor(c.red(), c.green(), c.blue(), alpha))
            painter.drawText(fx - 50, fy, ft["text"])
            painter.restore()

        # 14.5 High-Altitude Cloud Cover Blanket & Foreground Puffs (Takeoff punch-through & Landing cloud dive)
        if self.state == "takeoff" and self.takeoff_tick >= 160 and self.takeoff_tick < 450:
            if self.takeoff_tick < 210:
                t_alpha = int(160 * ((self.takeoff_tick - 160) / 50.0))
            elif self.takeoff_tick < 390:
                t_alpha = 160
            else:
                t_alpha = int(160 * (1.0 - (self.takeoff_tick - 390) / 60.0))

            if t_alpha > 0:
                painter.save()
                painter.setOpacity(t_alpha / 255.0)
                # Billowing cumulus and cloud wisps sweeping directly over the aircraft canopy
                for c in self.clouds:
                    if not self.cloud_pixmaps:
                        continue
                    pix = self.cloud_pixmaps[c["type"] % len(self.cloud_pixmaps)]
                    sc = c.get("scale", 1.2) * 1.4
                    w = int(pix.width() * sc)
                    h = int(pix.height() * sc)
                    puff_y = (c["y"] * 2 + int(self.world_scroll_y * 1.6)) % (self.height() + 400) - 200
                    puff_x = c["x"]
                    painter.drawPixmap(puff_x - w // 2, puff_y - h // 2, w, h, pix)
                painter.restore()

        elif self.state == "landing" and self.landing_tick < 80:
            # Plane breaks through lower cloud deck down to sea level
            l_alpha = int(220 * (1.0 - (self.landing_tick / 80.0)))
            if l_alpha > 0 and not self.cloud_bed_pixmap.isNull():
                painter.save()
                painter.setOpacity(l_alpha / 255.0)
                c_w = self.cloud_bed_pixmap.width()
                c_h = self.cloud_bed_pixmap.height()
                c_y = int(self.world_scroll_y * 1.2) % c_h
                for tx in range(-c_w // 2, self.width() + c_w, c_w):
                    painter.drawPixmap(tx, c_y - c_h, self.cloud_bed_pixmap)
                    painter.drawPixmap(tx, c_y, self.cloud_bed_pixmap)
                painter.restore()

        # 15. Mega Crash Shockwave
        if self.mega_crash_ticks > 0:
            prog = (28 - self.mega_crash_ticks) / 28.0
            for ring_i in [0, 1, 2]:
                r = int((prog * 520) - ring_i * 60)
                if r > 10:
                    painter.setPen(QColor(140, 220, 255, max(0, int(220 * (1.0 - prog)))))
                    painter.setBrush(Qt.NoBrush)
                    painter.drawEllipse(QRect(self.width()//2 - r, self.height()//2 - r, r * 2, r * 2))
            flash_alpha = max(0, int(150 * (1.0 - prog * 1.5)))
            if flash_alpha > 0: painter.fillRect(self.rect(), QColor(220, 245, 255, flash_alpha))

        # 15.1 Failsafe Atomic Self-Destruct Shockwaves & Flash
        for sw in self.failsafe_shockwaves:
            sx, sy, r = int(sw["x"]), int(sw["y"]), int(sw["radius"])
            life_p = max(0.0, sw["life"] / 38.0)
            painter.setPen(QPen(QColor(255, 240, 150, int(230 * life_p)), 4))
            painter.setBrush(Qt.NoBrush)
            painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
            painter.setPen(QPen(QColor(255, 100, 30, int(180 * life_p)), 2))
            painter.drawEllipse(QRect(sx - int(r*0.75), sy - int(r*0.75), int(r * 1.5), int(r * 1.5)))

        if self.failsafe_flash_ticks > 0:
            f_alpha = int(220 * (self.failsafe_flash_ticks / 24.0))
            painter.fillRect(self.rect(), QColor(255, 245, 220, f_alpha))

        painter.restore()

        # 16. Option 1 Sleek In-Game HUD
        self.draw_option1_hud(painter)

        # 16.1 Battle Matchup Badge at Bottom Center ([Flag] VS [Flag])
        self.draw_battle_matchup_badge(painter)

        if self.banner_timer > 0:
            has_boss_gauge = (self.boss and self.boss["active"]) or (self.cartel_hangar and self.cartel_hangar["active"])
            hud_y = 52 if getattr(self, "is_mini_header", False) else 114
            banner_y = hud_y + 44 if not has_boss_gauge else hud_y + 72
            painter.fillRect(QRect(20, banner_y, self.width() - 40, 26), QColor(25, 35, 50, 230))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QColor(255, 225, 70))
            painter.setFont(QFont("Menlo", 8, QFont.Bold))
            painter.drawText(QRect(20, banner_y, self.width() - 40, 26), Qt.AlignCenter, self.banner_text)

        # Pause Overlay (hidden when Help modal or Audio menu is active)
        if self.is_paused and not self.audio_menu_open and not getattr(self, "show_help_modal", False):
            painter.save()
            h_h = 46 if getattr(self, "is_mini_header", False) else 108
            painter.fillRect(QRect(0, h_h, self.width(), self.height() - h_h), QColor(6, 12, 20, 205))
            
            p_w = 420
            p_h = 180
            p_x = (self.width() - p_w) // 2
            p_y = h_h + (self.height() - h_h - p_h) // 2
            p_rect = QRect(p_x, p_y, p_w, p_h)
            
            painter.fillRect(p_rect, QColor(8, 14, 22, 245))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QPen(QColor(255, 215, 60), 2.5))
            painter.drawRect(p_rect)
            
            painter.setFont(QFont("Menlo", 16, QFont.Bold))
            painter.setPen(QColor(255, 225, 70))
            painter.drawText(QRect(p_x, p_y + 24, p_w, 32), Qt.AlignCenter, "⏸ MISSION PAUSED")
            
            painter.setFont(QFont("Menlo", 10, QFont.Bold))
            painter.setPen(QColor(240, 248, 255))
            painter.drawText(QRect(p_x, p_y + 74, p_w, 24), Qt.AlignCenter, "PRESS [P] OR [ESC] TO RESUME FLIGHT")
            
            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.setPen(QColor(160, 210, 255))
            painter.drawText(QRect(p_x, p_y + 116, p_w, 22), Qt.AlignCenter, "PRESS [M] FOR AUDIO CONSOLE")
            painter.restore()

        # Draw the Arcade Template Header
        self.draw_template_header(painter)

        if self.audio_menu_open:
            self.draw_audio_menu(painter)

        if getattr(self, "show_help_modal", False):
            self.draw_help_modal(painter)

        # Preview Recording Indicator Pill
        if hasattr(self, "preview_rec_status") and not getattr(self, "preview_rec_done", False):
            painter.save()
            pill_rect = QRect(self.width() - 140, 14, 125, 24)
            is_active = getattr(self, "preview_rec_active", False)
            bg = QColor(225, 30, 45, 240) if is_active else QColor(15, 22, 35, 220)
            painter.fillRect(pill_rect, bg)
            painter.setPen(QColor(255, 60, 60) if not is_active else QColor(255, 255, 255))
            painter.drawRect(pill_rect)
            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(pill_rect, Qt.AlignCenter, self.preview_rec_status)
            painter.restore()

    def start_preview_recording_scheduler(self, delay_sec=20, duration_sec=8):
        """Schedules automated in-process WebP gameplay preview recording after delay_sec."""
        import time
        import threading
        import subprocess
        import shutil
        from pathlib import Path
        from PySide6.QtCore import QTimer, Qt

        self.preview_rec_active = False
        self.preview_rec_done = False
        self.preview_rec_frames = []
        self.preview_rec_start_time = time.time()
        self.preview_rec_delay = delay_sec
        self.preview_rec_duration = duration_sec
        self.preview_rec_tmp_dir = Path("/tmp/skyace_preview_rec")
        if self.preview_rec_tmp_dir.exists():
            shutil.rmtree(self.preview_rec_tmp_dir, ignore_errors=True)
        self.preview_rec_tmp_dir.mkdir(parents=True, exist_ok=True)
        self.preview_rec_status = f"REC IN {delay_sec}s"

        self.rec_timer = QTimer(self)

        def rec_tick():
            if getattr(self, "preview_rec_done", False):
                self.rec_timer.stop()
                return
            now = time.time()
            elapsed = now - self.preview_rec_start_time
            if elapsed < self.preview_rec_delay:
                rem_cd = max(1, int(math.ceil(self.preview_rec_delay - elapsed)))
                self.preview_rec_status = f"REC IN {rem_cd}s"
                self.update()
                return

            rec_elapsed = elapsed - self.preview_rec_delay
            if rec_elapsed < self.preview_rec_duration:
                self.preview_rec_active = True
                rem_rec = max(1, int(math.ceil(self.preview_rec_duration - rec_elapsed)))
                self.preview_rec_status = f"● REC {rem_rec}s"
                pix = self.grab()
                scaled = pix.scaled(320, 414, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                f_idx = len(self.preview_rec_frames)
                f_path = self.preview_rec_tmp_dir / f"frame_{f_idx:04d}.png"
                scaled.save(str(f_path), "PNG")
                self.preview_rec_frames.append(f_path)
                self.update()
            else:
                self.preview_rec_active = False
                self.preview_rec_done = True
                self.rec_timer.stop()
                self.preview_rec_status = "SAVED!"
                self.banner_text = "★ GAMEPLAY WEBP PREVIEW CAPTURED & SAVED! ★"
                self.banner_timer = 150
                self.update()

                def assemble():
                    out_webp = current_dir.parent.parent / "assets" / "previews" / "skyace.webp"
                    out_webp.parent.mkdir(parents=True, exist_ok=True)
                    cmd = ["img2webp", "-loop", "0", "-d", "80", "-q", "80"]
                    for fp in sorted(self.preview_rec_tmp_dir.glob("frame_*.png")):
                        cmd.append(str(fp))
                    cmd.extend(["-o", str(out_webp)])
                    try:
                        subprocess.run(cmd, check=True)
                        print(f"[Sky Ace] Gameplay preview saved to {out_webp} ({len(self.preview_rec_frames)} frames)")
                    except Exception as err:
                        print(f"[Sky Ace] Error compiling webp preview: {err}")

                threading.Thread(target=assemble, daemon=True).start()

        self.rec_timer.timeout.connect(rec_tick)
        self.rec_timer.start(80)

    def closeEvent(self, event):
        if hasattr(self, "prop_audio"):
            self.prop_audio.stop()
        self.sound.stop_bgm()
        super().closeEvent(event)

if __name__ == "__main__":
    if "--bake-3d" in sys.argv:
        from engine.bake_3d_frames import bake_all_planes
        bake_all_planes(verbose=True)
        sys.exit(0)

    app = QApplication(sys.argv)
    window = SkyAceGame()
    if "--record-preview" in sys.argv:
        window.start_preview_recording_scheduler(delay_sec=20, duration_sec=8)

    if "--secret-play" in sys.argv:
        window.start_secret_mission("ho229")
    elif "--secret" in sys.argv:
        window.state = "secret_briefing"
        window.sound.play_bgm("bgm_boss")
    window.show()
    sys.exit(app.exec())
