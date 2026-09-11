#!/usr/bin/env python3
"""
tools/update_skyace_6nation.py
Generates the complete, production-grade 6-nation Sky Ace main.py
"""

code = '''#!/usr/bin/env python3
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

import sys
import math
import random
import json
from pathlib import Path
from PIL import Image
import numpy as np

from PySide6.QtWidgets import QApplication, QWidget
from PySide6.QtGui import QPainter, QPixmap, QImage, QColor, QFont, QPolygon
from PySide6.QtCore import QTimer, Qt, QRect, QPoint, QSettings

# Add engine directory to python path
current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir / "engine"))

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

from audio_manager import SoundManager

def pil_to_qpixmap(pil_img):
    """Converts a PIL RGBA image to a PySide6 QPixmap."""
    arr = np.array(pil_img.convert("RGBA"))
    h, w, ch = arr.shape
    bytes_per_line = ch * w
    qimg = QImage(arr.data, w, h, bytes_per_line, QImage.Format_RGBA8888)
    return QPixmap.fromImage(qimg)

class SkyAceGame(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Sky Ace • 194X Global Air War")
        self.resize(580, 750)
        self.setFocusPolicy(Qt.StrongFocus)

        self.settings = QSettings("Arcade", "SkyAce")
        self.sound = SoundManager(current_dir / "sounds")

        # Game States: "hangar", "takeoff", "playing", "landing", "victory"
        self.state = "hangar"
        self.hangar_step = 1  # 1: Select Player Plane, 2: Select Enemy Theater
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

        # 3D Airframe Models
        print("[Sky Ace] Initializing 6-Nation 3D airframes...")
        self.mesh_p38 = build_p38_mesh()
        self.mesh_zero = build_zero_mesh()
        self.mesh_spitfire = build_spitfire_mesh()
        self.mesh_bf109 = build_bf109_mesh()
        self.mesh_yak3 = build_yak3_mesh()
        self.mesh_mosquito = build_mosquito_mesh()

        self.factions = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito"]
        self.current_plane = "p38"
        self.enemy_theater = "imperial"

        # National Metas
        self.nation_info = {
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
            }
        }

        # Theater Metas
        self.theaters = {
            "imperial": {
                "name": "PACIFIC OCEAN", "flag": "🇯🇵", "enemy_title": "IMPERIAL JAPANESE NAVY",
                "boss_name": "AYAKO", "boss_title": "IJN SUPER FORTRESS 'AYAKO'",
                "banner": "⚠ WARNING: IJN SUPER HEAVY FORTRESS 'AYAKO' DETECTED! ⚠",
                "water_color": (16, 44, 78), "water_line": (28, 64, 110),
                "turrets": [{"x": -124, "y": 10}, {"x": -76, "y": -5}, {"x": 76, "y": -5}, {"x": 124, "y": 10}, {"x": 0, "y": 25}]
            },
            "allied": {
                "name": "SOUTH PACIFIC", "flag": "🇺🇸", "enemy_title": "ALLIED COMBINED FLEET",
                "boss_name": "GOLIATH", "boss_title": "USAAF SUPER FORTRESS 'B-29 GOLIATH'",
                "banner": "⚠ WARNING: USAAF SUPER FLYING FORTRESS 'B-29 GOLIATH' DETECTED! ⚠",
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
            }
        }

        # Loop maneuver stages
        self.is_looping = False
        self.loop_tick = 0
        self.loop_stages = [
            (0.0, 35.0, 0.0), (0.0, 75.0, 0.0), (0.0, 130.0, 0.0), (0.0, 180.0, 0.0),
            (0.0, 230.0, 0.0), (0.0, 285.0, 0.0), (0.0, 330.0, 0.0), (0.0, 355.0, 0.0),
        ]

        # Player 3D Sprite cache
        print("[Sky Ace] Building 3D player sprite cache for all 6 airframes in Tactical Style 3...")
        self.cache = {p: {} for p in self.factions}
        for plane_key in self.factions:
            self.build_cache_for_plane(plane_key)

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
                "boss": self.load_atlas("sheet_boss_goliath"),
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
            }
        }

        # Environmental scenery textures
        sprites_dir = current_dir / "sprites"
        self.cloud_pixmaps = [
            QPixmap(str(sprites_dir / f"cloud_cumulus_{i}.png"))
            for i in range(1, 7)
            if (sprites_dir / f"cloud_cumulus_{i}.png").exists()
        ]
        self.island_pixmaps = [
            QPixmap(str(sprites_dir / f"island_atoll_{i}.png"))
            for i in range(1, 6)
            if (sprites_dir / f"island_atoll_{i}.png").exists()
        ]

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

        # Boss
        self.boss = None
        self.boss_spawned = False
        self.mission_ticks = 0

        # Health & Damage
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
            for frame_id, meta in data.get("frames", {}).items():
                fr = meta["frame"]
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
        """Initializes drifting cloud and island positions."""
        self.clouds = [
            self.spawn_cloud(y=y_pos)
            for y_pos in [50, 190, 340, 490, 640]
        ]
        self.islands = [
            {"x": 420, "y": 140, "speed": 0.85, "type": 0, "flip_h": False, "scale": 1.0},
            {"x": 140, "y": 580, "speed": 0.85, "type": 1, "flip_h": True, "scale": 1.05},
        ]

    def build_cache_for_plane(self, plane):
        if plane == "p38":
            mesh, render_fn = self.mesh_p38, render_3d_frame
        elif plane == "zero":
            mesh, render_fn = self.mesh_zero, render_3d_zero_frame
        elif plane == "spitfire":
            mesh, render_fn = self.mesh_spitfire, render_3d_spitfire_frame
        elif plane == "bf109":
            mesh, render_fn = self.mesh_bf109, render_3d_bf109_frame
        elif plane == "yak3":
            mesh, render_fn = self.mesh_yak3, render_3d_yak3_frame
        elif plane == "mosquito":
            mesh, render_fn = self.mesh_mosquito, render_3d_mosquito_frame
        else:
            mesh, render_fn = self.mesh_p38, render_3d_frame

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

    def start_mission(self, plane_key, theater_key=None):
        """Starts a new mission on the carrier flight deck or frontline airfield."""
        self.current_plane = plane_key
        if theater_key:
            self.enemy_theater = theater_key
        else:
            self.enemy_theater = self.nation_info[plane_key]["default_rival"]

        self.state = "takeoff"
        self.takeoff_tick = 0
        self.carrier_y = 140
        self.x = self.width() // 2
        self.y = 520
        self.hp = self.max_hp
        self.weapon_idx = 0
        self.score = 0
        self.bombs_remaining = 3
        self.loops_remaining = 3
        self.mission_ticks = 0
        self.boss_spawned = False
        self.boss = None
        self.enemies.clear()
        self.enemy_bullets.clear()
        self.bullets.clear()
        self.missiles.clear()
        self.pickups.clear()
        self.stats = {"scouts_killed": 0, "interceptors_killed": 0, "bombers_killed": 0, "boss_killed": False}

        base_name = self.nation_info[self.current_plane]["base"]
        th_name = self.theaters[self.enemy_theater]["name"]
        self.banner_text = f"MISSION START: SCRAMBLING FROM {base_name} INTO {th_name}!"
        self.banner_timer = 140

    def trigger_fire(self):
        if self.state != "playing" or self.is_looping or self.death_ticks > 0:
            return
        weapon = self.weapons[self.weapon_idx]
        nose_y = self.y - 52
        p_key = self.current_plane

        # Calculate primary gun offsets by aircraft geometry
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
            self.sound.play("loop_whoosh")
            self.banner_text = "★ EMERGENCY 360° LOOP ENGAGED! FULL INVULNERABILITY! ★"
            self.banner_timer = 60

    def trigger_mega_crash(self):
        if self.state == "playing" and self.death_ticks == 0 and self.bombs_remaining > 0:
            self.bombs_remaining -= 1
            self.mega_crash_ticks = 28
            self.screen_shake = 18
            self.sound.play("bomb_explode")
            self.enemy_bullets.clear()
            for e in self.enemies:
                e["hp"] -= 10
                e["hit_flash"] = 12
                self.explosions.append({
                    "x": e["x"] + random.randint(-15, 15),
                    "y": e["y"] + random.randint(-15, 15),
                    "radius": 24, "max_radius": 48, "life": 16
                })
            if self.boss and self.boss["active"]:
                self.boss["hp"] = max(0, self.boss["hp"] - 45)
                for _ in range(6):
                    self.explosions.append({
                        "x": self.boss["x"] + random.randint(-120, 120),
                        "y": self.boss["y"] + random.randint(-40, 40),
                        "radius": 28, "max_radius": 56, "life": 20
                    })
            self.banner_text = "★ 1943 MEGA CRASH DETONATED! AIRSPACE CLEARED! ★"
            self.banner_timer = 90

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
            self.banner_text = f"☠ {self.nation_info[self.current_plane]['name']} CRITICAL FAILURE! SPIRALING DOWN! ☠"
            self.banner_timer = 100

    def mousePressEvent(self, event):
        pos = event.position()
        mx, my = pos.x(), pos.y()

        if self.state == "hangar":
            if self.hangar_step == 1:
                # 6 plane cards in 2 columns of 3
                col_w = (self.width() - 48) // 2
                row_h = 160
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito"]
                for i, k in enumerate(card_keys):
                    col = i % 2
                    row = i // 2
                    rx = 20 + col * (col_w + 8)
                    ry = 120 + row * (row_h + 12)
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
                # 5 theater options
                th_keys = ["imperial", "luftwaffe", "vvs", "raf", "allied"]
                card_h = 76
                for idx, tk in enumerate(th_keys):
                    ry = 135 + idx * (card_h + 10)
                    rect = QRect(24, ry, self.width() - 48, card_h)
                    if rect.contains(int(mx), int(my)):
                        self.start_mission(self.current_plane, tk)
                        return

        elif self.state == "victory":
            self.state = "hangar"
            self.hangar_step = 1
            self.update()
        elif self.state == "playing":
            if event.button() == Qt.LeftButton:
                self.is_fire_held = True
                self.trigger_fire()
            elif event.button() == Qt.RightButton:
                self.cycle_weapon()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.is_fire_held = False

    def cycle_weapon(self):
        self.weapon_idx = (self.weapon_idx + 1) % len(self.weapons)
        w_key = self.weapons[self.weapon_idx]
        w_name = self.weapon_names[self.current_plane][w_key]
        self.banner_text = f"ARMAMENT: {w_name}"
        self.banner_timer = 80
        self.sound.play("pow_pickup")
        self.update()

    def keyPressEvent(self, event):
        key = event.key()
        if key == Qt.Key_Escape:
            if self.state == "hangar" and self.hangar_step == 2:
                self.hangar_step = 1
                self.update()
            elif self.state in ("playing", "victory"):
                self.state = "hangar"
                self.hangar_step = 1
                self.update()
            else:
                self.close()
        elif self.state == "hangar":
            if self.hangar_step == 1:
                key_map = {
                    Qt.Key_1: "p38", Qt.Key_2: "zero", Qt.Key_3: "spitfire",
                    Qt.Key_4: "bf109", Qt.Key_5: "yak3", Qt.Key_6: "mosquito"
                }
                if key in key_map:
                    self.current_plane = key_map[key]
                    self.hangar_step = 2
                    self.sound.play("pow_pickup")
                    self.banner_text = f"SELECTED {self.nation_info[self.current_plane]['name']} • CHOOSE ENEMY THEATER"
                    self.banner_timer = 120
                    self.update()
            elif self.hangar_step == 2:
                th_map = {
                    Qt.Key_1: "imperial", Qt.Key_2: "luftwaffe", Qt.Key_3: "vvs",
                    Qt.Key_4: "raf", Qt.Key_5: "allied"
                }
                if key in th_map:
                    self.start_mission(self.current_plane, th_map[key])
                elif key in (Qt.Key_Space, Qt.Key_Return):
                    # Launch default rival theater
                    self.start_mission(self.current_plane, self.nation_info[self.current_plane]["default_rival"])
                elif key == Qt.Key_Backspace:
                    self.hangar_step = 1
                    self.update()

        elif self.state == "victory":
            if key in (Qt.Key_Space, Qt.Key_Return, Qt.Key_1, Qt.Key_2, Qt.Key_3):
                self.state = "hangar"
                self.hangar_step = 1
                self.update()
        elif self.state == "playing":
            if key == Qt.Key_Tab or key == Qt.Key_0:
                # Cycle player aircraft in flight
                curr_idx = self.factions.index(self.current_plane)
                self.current_plane = self.factions[(curr_idx + 1) % len(self.factions)]
                self.banner_text = f"★ HOT-SWAPPED AIRCRAFT: {self.nation_info[self.current_plane]['name']} ★"
                self.banner_timer = 90
            elif key == Qt.Key_P:
                self.cycle_weapon()
            elif key in (Qt.Key_Space, Qt.Key_Return):
                self.trigger_loop()
            elif key == Qt.Key_B:
                self.trigger_mega_crash()
            elif key == Qt.Key_L:
                if not self.is_looping and self.death_ticks == 0:
                    self.state = "landing"
                    self.landing_tick = 0
            elif key in (Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V, Qt.Key_F, Qt.Key_Control, Qt.Key_Meta):
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
        if key in (Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V, Qt.Key_F, Qt.Key_Control, Qt.Key_Meta):
            self.is_fire_held = False

    def game_loop(self):
        self.prop_tick += 1
        self.ocean_y = (self.ocean_y + 4) % 48

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
        for isl in self.islands:
            isl["y"] += isl["speed"]
            if isl["y"] > self.height() + 250:
                isl["y"] = -random.randint(280, 500)
                isl["x"] = random.randint(100, self.width() - 100)
                isl["type"] = random.randint(0, len(self.island_pixmaps) - 1) if self.island_pixmaps else 0
                isl["flip_h"] = random.choice([True, False])
                isl["scale"] = random.uniform(0.85, 1.20)

        # ---------------------------------------------------------------------
        # STATE: TAKEOFF SEQUENCE
        # ---------------------------------------------------------------------
        if self.state == "takeoff":
            self.takeoff_tick += 1
            self.bank_angle = 0.0
            self.x = self.width() // 2

            if self.takeoff_tick < 35:
                self.carrier_y = 140
                self.y = 520
            elif self.takeoff_tick < 95:
                progress = (self.takeoff_tick - 35) / 60.0
                self.y = 520 - int(80 * (progress ** 1.4))
                self.carrier_y = 140 + int(220 * (progress ** 1.6))
            elif self.takeoff_tick < 165:
                self.y += (480 - self.y) * 0.08
                self.carrier_y += 10
            else:
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
                # Transition to Victory Debriefing
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
                    for _ in range(5):
                        self.explosions.append({
                            "x": self.x + random.randint(-25, 25), "y": self.y + random.randint(-20, 20),
                            "radius": 24, "max_radius": 56, "life": 24
                        })
                    self.screen_shake = 14
                    self.hp = self.max_hp
                    self.death_ticks = 0
                    self.x = self.width() // 2
                    self.y = 540
                    self.invulnerable_ticks = 90
                    self.banner_text = f"★ FRESH {p_info['name']} REPLACED & AIRBORNE! ★"
                    self.banner_timer = 110

            elif not self.is_looping:
                bank_speed = p_info["bank"]
                fly_speed = p_info["speed"]

                if moving_left:
                    self.x = max(80, self.x - fly_speed)
                    self.target_bank = -28.0
                elif moving_right:
                    self.x = min(self.width() - 80, self.x + fly_speed)
                    self.target_bank = 28.0
                else:
                    self.target_bank = 0.0

                self.bank_angle += (self.target_bank - self.bank_angle) * bank_speed
                if moving_up:
                    self.y = max(140, self.y - 5)
                if moving_down:
                    self.y = min(self.height() - 120, self.y + 5)
            else:
                self.bank_angle = 0.0
                self.loop_tick += 1
                if self.loop_tick >= len(self.loop_stages) * 5:
                    self.is_looping = False
                    self.loop_tick = 0

            # Progressive Damage Smoke
            if self.death_ticks == 0:
                engine_ox = 0 if self.current_plane in ("zero", "spitfire", "bf109", "yak3") else -26
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

            # Check Boss Spawn after 1400 ticks (~23 seconds of combat)
            if self.mission_ticks >= 1400 and not self.boss_spawned:
                self.boss_spawned = True
                boss_name = theater_data["boss_name"]
                boss_title = theater_data["boss_title"]
                self.banner_text = theater_data["banner"]
                turrets = theater_data["turrets"]

                self.banner_timer = 150
                self.boss = {
                    "name": boss_name,
                    "title": boss_title,
                    "faction": enemy_faction,
                    "x": self.width() // 2, "y": -140, "target_y": 205,
                    "hp": 240, "max_hp": 240, "active": True,
                    "fire_tick": 0, "turrets": turrets,
                    "damage_stage": 0,
                }

            if not self.boss_spawned:
                self.spawn_tick += 1
                if self.spawn_tick >= 75:
                    self.spawn_tick = 0
                    pattern = random.choice(["v_formation", "sweep", "pincer", "heavy"])
                    if pattern == "v_formation":
                        center_x = random.randint(140, self.width() - 140)
                        self.enemies.append({"x": center_x, "y": -40, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "type": "scout", "hit_flash": 0})
                        self.enemies.append({"x": center_x - 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "type": "scout", "hit_flash": 0})
                        self.enemies.append({"x": center_x + 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "type": "scout", "hit_flash": 0})
                    elif pattern == "sweep":
                        start_x = random.choice([60, self.width() - 60])
                        vx = 2.6 if start_x < self.width() // 2 else -2.6
                        self.enemies.append({"x": start_x, "y": -30, "vx": vx, "vy": 4.5, "hp": 4, "faction": enemy_faction, "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": start_x, "y": -65, "vx": vx, "vy": 4.5, "hp": 4, "faction": enemy_faction, "type": "interceptor", "hit_flash": 0})
                    elif pattern == "pincer":
                        self.enemies.append({"x": 40, "y": -30, "vx": 2.4, "vy": 4.0, "hp": 4, "faction": enemy_faction, "type": "interceptor", "hit_flash": 0})
                        self.enemies.append({"x": self.width() - 40, "y": -30, "vx": -2.4, "vy": 4.0, "hp": 4, "faction": enemy_faction, "type": "interceptor", "hit_flash": 0})
                    elif pattern == "heavy":
                        start_x = random.randint(120, self.width() - 120)
                        self.enemies.append({"x": start_x, "y": -60, "vx": random.uniform(-0.6, 0.6), "vy": 2.0, "hp": 12, "faction": enemy_faction, "type": "bomber", "hit_flash": 0})

            # Boss Update & Multi-Stage Damage
            if self.boss and self.boss["active"]:
                b = self.boss
                if b["y"] < b["target_y"]:
                    b["y"] += 1.8
                else:
                    b["x"] += math.sin(self.mission_ticks * 0.02) * 1.5

                # Damage stages: 0 = pristine (>160 hp), 1 = wing damaged (80-160 hp), 2 = critical wreck (<80 hp)
                if b["hp"] <= 80:
                    b["damage_stage"] = 2
                    if random.random() < 0.6:
                        self.smoke_particles.append({
                            "x": b["x"] + random.randint(-120, 120),
                            "y": b["y"] + random.randint(-20, 30),
                            "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.0, 6.0),
                            "rad": 10, "max_rad": 32, "life": 24, "type": "fire"
                        })
                elif b["hp"] <= 160:
                    b["damage_stage"] = 1
                    if random.random() < 0.4:
                        self.smoke_particles.append({
                            "x": b["x"] + random.randint(-100, 100),
                            "y": b["y"] + random.randint(-10, 20),
                            "vx": random.uniform(-0.5, 0.5), "vy": random.uniform(2.5, 5.0),
                            "rad": 8, "max_rad": 24, "life": 22, "type": "black_smoke"
                        })
                else:
                    b["damage_stage"] = 0

                b["fire_tick"] += 1
                if b["fire_tick"] >= 45:
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
                if random.random() < 0.016 and e["y"] > 20 and e["y"] < self.y - 60:
                    dx = self.x - e["x"]
                    dy = self.y - e["y"]
                    dist = math.hypot(dx, dy)
                    if dist > 0:
                        spd = 4.2
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
                    
                    # Random pickup drop
                    drop_roll = random.random()
                    if drop_roll < 0.18:
                        p_choice = random.choice(["pow", "wing", "bomb", "loop", "medal"])
                        self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.2, "type": p_choice})
            self.enemies = alive_enemies

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

                # Hit Boss
                if not hit and self.boss and self.boss["active"]:
                    boss_w = 175
                    boss_h = 75
                    if abs(b["x"] - self.boss["x"]) < boss_w and abs(b["y"] - self.boss["y"]) < boss_h:
                        self.boss["hp"] -= b["dmg"]
                        hit = True
                        self.sound.play("hit_sound")
                        for _ in range(4):
                            self.spark_particles.append({
                                "x": b["x"], "y": b["y"],
                                "vx": random.uniform(-3, 3), "vy": random.uniform(-1, 3),
                                "life": 10, "color": QColor(255, 180, 50)
                            })
                        if self.boss["hp"] <= 0:
                            # Boss Destroyed!
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
                            self.banner_text = f"★ {self.boss['title']} DESTROYED! RETURN TO BASE FOR RECOVERY! ★"
                            self.banner_timer = 180
                            # Scramble carrier landing
                            self.state = "landing"
                            self.landing_tick = 0

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
                    d = math.hypot(e["x"] - m["x"], e["y"] - m["y"])
                    if d < target_dist and e["y"] < m["y"]:
                        target_dist = d
                        target = e
                if not target and self.boss and self.boss["active"]:
                    target = self.boss
                    target_dist = math.hypot(self.boss["x"] - m["x"], self.boss["y"] - m["y"])

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
                    if math.hypot(e["x"] - m["x"], e["y"] - m["y"]) < 36:
                        e["hp"] -= 4
                        e["hit_flash"] = 4
                        m_hit = True
                        break
                if not m_hit and self.boss and self.boss["active"]:
                    if abs(m["x"] - self.boss["x"]) < 160 and abs(m["y"] - self.boss["y"]) < 60:
                        self.boss["hp"] -= 4
                        m_hit = True

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
                    if p_type == "pow":
                        self.cycle_weapon()
                        self.hp = min(self.max_hp, self.hp + 1)
                        self.score += 500
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
                elif p["y"] < self.height() + 30:
                    alive_pickups.append(p)
            self.pickups = alive_pickups

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

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)

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
            painter.setPen(QColor(180, 210, 240))
            painter.setFont(font_body)
            painter.drawText(QRect(0, 62, self.width(), 22), Qt.AlignCenter, f"ARCADE HIGH SCORE: {self.high_score:06d}")

            if self.hangar_step == 1:
                # Step 1: Choose Aircraft & Country
                painter.setPen(QColor(100, 210, 255))
                painter.setFont(font_head)
                painter.drawText(QRect(0, 88, self.width(), 22), Qt.AlignCenter, "STEP 1: SELECT YOUR NATION & FIGHTER [1-6]")

                col_w = (self.width() - 48) // 2
                row_h = 160
                card_keys = ["p38", "zero", "spitfire", "bf109", "yak3", "mosquito"]

                for i, k in enumerate(card_keys):
                    info = self.nation_info[k]
                    col = i % 2
                    row = i // 2
                    rx = 20 + col * (col_w + 8)
                    ry = 120 + row * (row_h + 12)
                    rect = QRect(rx, ry, col_w, row_h)

                    # Card background
                    is_selected = (self.current_plane == k)
                    bg_col = QColor(36, 54, 78, 240) if is_selected else QColor(20, 32, 48, 230)
                    border_col = QColor(255, 215, 50) if is_selected else QColor(60, 110, 160)
                    
                    painter.fillRect(rect, bg_col)
                    painter.setPen(border_col)
                    painter.drawRect(rect)

                    # Plane 3D thumbnail (compact, centered vertically)
                    pix = self.cache[k]["level_0"]
                    painter.drawPixmap(QRect(rect.left() + 8, rect.top() + 38, 76, 76), pix)

                    # Text details with exact fit
                    painter.setFont(QFont("Menlo", 10, QFont.Bold))
                    painter.setPen(QColor(255, 230, 80))
                    painter.drawText(rect.left() + 88, rect.top() + 26, f"[{i+1}] {info['flag']} {info['name']}")

                    painter.setFont(QFont("Menlo", 8, QFont.Bold))
                    painter.setPen(QColor(160, 210, 255))
                    painter.drawText(rect.left() + 88, rect.top() + 46, info['country'])
                    
                    painter.setFont(QFont("Menlo", 8))
                    painter.setPen(QColor(230, 230, 230))
                    painter.drawText(rect.left() + 88, rect.top() + 66, f"ROLE: {info['role']}")
                    painter.drawText(rect.left() + 88, rect.top() + 86, f"BASE: {info['base']}")
                    painter.drawText(rect.left() + 88, rect.top() + 106, f"RANK: {info['pilot']}")

                    # Button strip
                    btn_rect = QRect(rect.left() + 88, rect.top() + 120, rect.width() - 96, 24)
                    painter.fillRect(btn_rect, QColor(40, 95, 165))
                    painter.setPen(QColor(255, 255, 255))
                    painter.setFont(QFont("Menlo", 8, QFont.Bold))
                    painter.drawText(btn_rect, Qt.AlignCenter, f"SELECT [{i+1}]")

                # Footer
                painter.setPen(QColor(160, 180, 200))
                painter.setFont(font_sm)
                painter.drawText(QRect(0, self.height() - 36, self.width(), 26), Qt.AlignCenter, "[1-6] Select Fighter  •  [Click] Card  •  [Esc] Exit")

            elif self.hangar_step == 2:
                # Step 2: Choose Enemy Theater
                p_info = self.nation_info[self.current_plane]
                painter.setPen(QColor(255, 215, 60))
                painter.setFont(font_head)
                painter.drawText(QRect(0, 88, self.width(), 22), Qt.AlignCenter, f"STEP 2: CHOOSE THEATER FOR {p_info['flag']} {p_info['name']}")

                th_keys = ["imperial", "luftwaffe", "vvs", "raf", "allied"]
                card_h = 82

                for idx, tk in enumerate(th_keys):
                    t_data = self.theaters[tk]
                    ry = 125 + idx * (card_h + 12)
                    rect = QRect(24, ry, self.width() - 48, card_h)

                    is_default = (p_info["default_rival"] == tk)
                    bg_col = QColor(38, 52, 70, 240) if is_default else QColor(22, 34, 48, 225)
                    border_col = QColor(255, 210, 50) if is_default else QColor(60, 100, 150)

                    painter.fillRect(rect, bg_col)
                    painter.setPen(border_col)
                    painter.drawRect(rect)

                    # Boss icon preview
                    boss_pix = self.enemy_sprites[tk]["boss"].get("pristine")
                    if boss_pix:
                        painter.drawPixmap(QRect(rect.left() + 12, rect.top() + 10, 95, 63), boss_pix)

                    # Information
                    painter.setFont(font_head)
                    painter.setPen(QColor(255, 230, 80))
                    rec_tag = " ★ [HISTORICAL RIVAL]" if is_default else ""
                    painter.drawText(rect.left() + 120, rect.top() + 26, f"[{idx+1}] {t_data['flag']} {t_data['name']}{rec_tag}")

                    painter.setFont(font_sm)
                    painter.setPen(QColor(210, 230, 255))
                    painter.drawText(rect.left() + 120, rect.top() + 46, f"OPFOR: {t_data['enemy_title']}")
                    painter.setPen(QColor(255, 180, 50))
                    painter.drawText(rect.left() + 120, rect.top() + 66, f"FLAGSHIP BOSS: {t_data['boss_title']}")

                # Footer
                painter.setPen(QColor(160, 180, 200))
                painter.setFont(font_sm)
                painter.drawText(QRect(0, self.height() - 40, self.width(), 30), Qt.AlignCenter, "[1-5] Choose Theater  •  [Enter] Recommended Rival  •  [Esc/Back] Change Plane")

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
            painter.drawText(QRect(0, 42, self.width(), 36), Qt.AlignCenter, "★ MISSION ACCOMPLISHED ★")
            
            p_info = self.nation_info[self.current_plane]
            t_info = self.theaters[self.enemy_theater]

            painter.setFont(font_title)
            painter.setPen(QColor(100, 210, 255))
            painter.drawText(QRect(0, 80, self.width(), 26), Qt.AlignCenter, f"{t_info['name']} CAMPAIGN COMPLETED")

            # Debriefing Panel
            panel = QRect(36, 120, self.width() - 72, 490)
            painter.fillRect(panel, QColor(20, 30, 45, 235))
            painter.setPen(QColor(245, 205, 50))
            painter.drawRect(panel)

            pix = self.cache[self.current_plane]["level_0"]
            painter.drawPixmap(QRect(panel.left() + 20, panel.top() + 20, 120, 120), pix)

            painter.setFont(font_title)
            painter.setPen(QColor(255, 255, 255))
            painter.drawText(panel.left() + 155, panel.top() + 45, f"PILOT: {p_info['pilot']}")
            painter.setPen(QColor(180, 215, 250))
            painter.setFont(font_row)
            painter.drawText(panel.left() + 155, panel.top() + 72, f"AIRCRAFT: {p_info['flag']} {p_info['name']}")
            painter.drawText(panel.left() + 155, panel.top() + 94, f"BASE    : {p_info['base']}")
            painter.drawText(panel.left() + 155, panel.top() + 116, f"THEATER : {t_info['name']}")

            painter.setPen(QColor(50, 80, 120))
            painter.drawLine(panel.left() + 15, panel.top() + 155, panel.right() - 15, panel.top() + 155)

            # Stat rows
            painter.setFont(font_row)
            stats_y = panel.top() + 185
            rows = [
                ("SCOUTS INTERCEPTED", f"{self.stats['scouts_killed']:02d}", f"{self.stats['scouts_killed'] * 100} PTS"),
                ("FIGHTER ACES DOWNED", f"{self.stats['interceptors_killed']:02d}", f"{self.stats['interceptors_killed'] * 250} PTS"),
                ("HEAVY BOMBERS SMASHED", f"{self.stats['bombers_killed']:02d}", f"{self.stats['bombers_killed'] * 800} PTS"),
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
                stats_y += 34

            # Action buttons
            painter.fillRect(QRect(panel.left() + 30, panel.bottom() - 65, panel.width() - 60, 42), QColor(40, 100, 170))
            painter.setPen(QColor(255, 255, 255))
            painter.setFont(font_title)
            painter.drawText(QRect(panel.left() + 30, panel.bottom() - 65, panel.width() - 60, 42), Qt.AlignCenter, "PRESS [SPACE] OR CLICK FOR HANGAR")

            painter.setPen(QColor(160, 180, 200))
            painter.setFont(font_row)
            painter.drawText(QRect(0, self.height() - 36, self.width(), 26), Qt.AlignCenter, "[Space/Click] Return to Hangar  •  [Esc] Exit")
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

        # 1. Background Ocean/Terrain Tinted by Active Theater
        t_data = self.theaters[self.enemy_theater]
        w_r, w_g, w_b = t_data["water_color"]
        wl_r, wl_g, wl_b = t_data["water_line"]
        painter.fillRect(self.rect(), QColor(w_r, w_g, w_b))

        # Drifting ocean waves
        painter.setPen(QColor(wl_r, wl_g, wl_b, 140))
        for y in range(-48, self.height() + 48, 24):
            wave_y = y + self.ocean_y
            painter.drawLine(0, wave_y, self.width(), wave_y)

        # 1b. Cloud Drop-Shadows on Ocean (Authentic High-Altitude Depth)
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

        # 2. Environmental Islands / Taiga Patches
        for isl in self.islands:
            if not self.island_pixmaps:
                continue
            pix = self.island_pixmaps[isl["type"] % len(self.island_pixmaps)]
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
        if self.carrier_y > -600 and self.carrier_y < self.height() + 200:
            cx = self.width() // 2
            cy = int(self.carrier_y)
            c_w, c_h = 240, 560

            # Deck Shadow
            painter.setOpacity(0.35)
            painter.fillRect(QRect(cx - c_w//2 + 18, cy + 22, c_w, c_h), QColor(10, 18, 30))
            painter.setOpacity(1.0)

            # Carrier Deck
            is_land_base = (self.current_plane == "yak3")
            deck_col = QColor(64, 58, 50) if is_land_base else QColor(72, 60, 52)
            painter.fillRect(QRect(cx - c_w//2, cy, c_w, c_h), deck_col)
            painter.setPen(QColor(95, 80, 70))
            for py in range(cy, cy + c_h, 8): painter.drawLine(cx - c_w//2, py, cx + c_w//2, py)

            # Outer hull border
            painter.setPen(QColor(38, 44, 50))
            painter.drawRect(QRect(cx - c_w//2, cy, c_w, c_h))

            # Arrestor Wires (Wires 1 through 4)
            if not is_land_base:
                painter.setPen(QColor(220, 220, 230))
                for w_idx, wy in enumerate([cy + 340, cy + 365, cy + 390, cy + 415]):
                    painter.drawLine(cx - 85, wy, cx + 85, wy)

            # Flight Deck Markings
            if self.current_plane == "zero":
                # IJN Akagi deck stripes & kanji
                painter.setBrush(QColor(210, 35, 35))
                painter.drawRect(QRect(cx - 70, int(cy + c_h - 60), 140, 16))
                painter.setBrush(QColor(245, 245, 245))
                painter.drawRect(QRect(cx - 70, int(cy + c_h - 40), 140, 14))
                font_kanji = QFont("Menlo", 16, QFont.Bold)
                painter.setFont(font_kanji)
                painter.drawText(QRect(cx - 20, int(cy + c_h - 105), 40, 30), Qt.AlignCenter, "ア")
                ix = cx - c_w//2 + 12
            elif is_land_base:
                # Krasny Luch Soviet runway white threshold lines
                painter.setBrush(QColor(245, 245, 245))
                for tx in range(cx - 80, cx + 90, 20):
                    painter.drawRect(QRect(tx, int(cy + c_h - 50), 12, 35))
                ix = cx + c_w//2 - 38
            else:
                # Allied / British / German deck centerline
                painter.setPen(QColor(245, 220, 50))
                for py in range(int(cy + 30), int(cy + c_h - 20), 28): painter.drawLine(cx, py, cx, py + 16)
                ix = cx + c_w//2 - 38

            # Island superstructure
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(42, 50, 58))
            painter.drawRect(QRect(ix, cy + 160, 26, 75))

        # 4. Boss: Super Heavy Fortress
        if self.boss and self.boss["active"]:
            b = self.boss
            bx, by = int(b["x"]), int(b["y"])
            b_faction = b["faction"]
            stage = b["damage_stage"]
            stage_names = ["pristine", "wing_damaged", "critical_wreck"]
            frame_key = stage_names[min(stage, 2)]

            boss_pix = self.enemy_sprites[b_faction]["boss"].get(frame_key)

            # Boss Shadow
            painter.setOpacity(0.28)
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(10, 18, 30))
            painter.drawEllipse(bx - 160, by + 45, 320, 90)
            painter.setOpacity(1.0)

            if boss_pix:
                painter.drawPixmap(QRect(bx - 192, by - 128, 384, 256), boss_pix)

            # Dedicated Arcade Boss Health Gauge (Top Position Below HUD)
            bar_w = 340
            fill_w = int(bar_w * (b["hp"] / b["max_hp"]))
            painter.fillRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28), QColor(12, 18, 28, 235))
            painter.fillRect(QRect(self.width()//2 - bar_w//2, 142, fill_w, 8), QColor(240, 45, 45))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QColor(245, 185, 45))
            painter.drawRect(QRect(self.width()//2 - bar_w//2 - 6, 126, bar_w + 12, 28))
            painter.setPen(QColor(255, 230, 80))
            painter.setFont(QFont("Menlo", 9, QFont.Bold))
            painter.drawText(QRect(self.width()//2 - bar_w//2, 127, bar_w, 15), Qt.AlignCenter, f"★ {b['title']} [{b['hp']}/{b['max_hp']}] ★")

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

        # 7. Pickups (Official High-Res Shimmering Badges)
        for p in self.pickups:
            px, py = int(p["x"]), int(p["y"])
            p_type = p.get("type", "pow")
            shimmer = (self.prop_tick // 8) % 2

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
            cur_scale = 0.82 if self.takeoff_tick < 95 else (0.82 + 0.18 * min(1.0, (self.takeoff_tick - 95)/70.0))
            shadow_dist = int(6 + 28 * min(1.0, (self.takeoff_tick - 95)/70.0)) if self.takeoff_tick >= 95 else 6
            plane_y = self.y
        elif self.state == "landing":
            cur_scale = 1.0 if self.landing_tick < 40 else (1.0 - 0.18 * min(1.0, (self.landing_tick - 40)/55.0))
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

        # 11. Smoke Trails
        for sm in self.smoke_particles:
            sx, sy, r, s_type = int(sm["x"]), int(sm["y"]), int(sm["rad"]), sm["type"]
            painter.setPen(Qt.NoPen)
            if s_type == "vapor":
                painter.setBrush(QColor(220, 230, 245, 120)); painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
            elif s_type == "black_smoke":
                painter.setBrush(QColor(30, 32, 38, 160)); painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
            elif s_type == "fire":
                painter.setBrush(QColor(255, 100, 20, 180)); painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))

        # 12. Main Player Aircraft Sprite
        jitter = random.choice([-1, 0, 1]) if self.hp == 1 else 0
        if self.invulnerable_ticks > 0 and self.hit_flash_ticks == 0:
            if (self.invulnerable_ticks // 3) % 2 == 0: painter.setOpacity(0.35)

        painter.save()
        if self.death_ticks > 0:
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

        # 13. Drifting Meteorological Clouds (Above Aircraft Layer)
        for c in self.clouds:
            if not self.cloud_pixmaps:
                continue
            pix = self.cloud_pixmaps[c["type"] % len(self.cloud_pixmaps)]
            painter.save()
            painter.setOpacity(c.get("opacity", 0.75))
            painter.translate(c["x"], c["y"])
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

        # 14. Sparks & Explosions
        for sp in self.spark_particles:
            painter.setPen(Qt.NoPen); painter.setBrush(sp.get("color", QColor(255, 255, 255))); painter.drawEllipse(int(sp["x"] - 2), int(sp["y"] - 2), 4, 4)
        for exp in self.explosions:
            ex, ey, r = int(exp["x"]), int(exp["y"]), int(exp["radius"])
            painter.setPen(Qt.NoPen); painter.setBrush(QColor(255, 120, 30, 160)); painter.drawEllipse(QRect(ex - r, ey - r, r * 2, r * 2))

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

        # 16. Tactical HUD
        painter.fillRect(QRect(12, 12, self.width() - 24, 110), QColor(10, 18, 30, 225))
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QColor(50, 120, 180))
        painter.drawRect(QRect(12, 12, self.width() - 24, 110))

        font_bold = QFont("Menlo", 11, QFont.Bold)
        font_sm = QFont("Menlo", 10)

        p_info = self.nation_info[self.current_plane]
        t_info = self.theaters[self.enemy_theater]

        painter.setFont(font_bold)
        painter.setPen(QColor(245, 210, 40))
        painter.drawText(24, 30, f"{p_info['flag']} {p_info['country']}: {p_info['name']}")
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(self.width() - 210, 30, f"SCORE: {self.score:06d}")

        painter.setFont(font_sm)
        # Armor gauge
        pips = "■ " * self.hp + "□ " * (self.max_hp - self.hp)
        if self.hp >= 4: col = QColor(100, 240, 120)
        elif self.hp == 3: col = QColor(230, 220, 50)
        elif self.hp == 2: col = QColor(255, 140, 30)
        else: col = QColor(255, 50, 50) if (self.prop_tick // 4) % 2 == 0 else QColor(255, 180, 50)

        painter.setPen(col)
        painter.drawText(24, 48, f"ARMOR: [ {pips.strip()} ]   BOMBS: {'★ ' * self.bombs_remaining}  LOOPS: {'🔄 ' * self.loops_remaining}")

        painter.setPen(QColor(180, 220, 255))
        painter.drawText(24, 66, f"THEATER: {t_info['name']} ({t_info['enemy_title']})")

        w_name = self.weapon_names[self.current_plane][self.weapons[self.weapon_idx]]
        painter.setPen(QColor(255, 180, 40))
        painter.drawText(24, 84, f"WEAPON: [ {w_name} ]  (PRESS 'P' TO CYCLE)")

        painter.setPen(QColor(140, 170, 200))
        painter.drawText(24, 102, "[Z/Click] Fire  •  [B] Bomb  •  [Space] Loop  •  [L] Land  •  [Tab] Switch Plane")

        if self.banner_timer > 0:
            banner_y = 162 if (self.boss and self.boss["active"]) else 130
            painter.fillRect(QRect(20, banner_y, self.width() - 40, 26), QColor(25, 35, 50, 230))
            painter.setBrush(Qt.NoBrush)
            painter.setPen(QColor(255, 225, 70))
            painter.setFont(QFont("Menlo", 8, QFont.Bold))
            painter.drawText(QRect(20, banner_y, self.width() - 40, 26), Qt.AlignCenter, self.banner_text)

        # Footer
        painter.fillRect(QRect(12, self.height() - 36, self.width() - 24, 26), QColor(10, 18, 30, 220))
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QColor(50, 120, 180))
        painter.drawRect(QRect(12, self.height() - 36, self.width() - 24, 26))
        painter.setPen(QColor(200, 225, 250))
        painter.drawText(24, self.height() - 19, "CONTROLS: [Arrows/WASD] Fly  •  [Z] Fire  •  [B] Bomb  •  [Space] Loop  •  [Esc] Hangar")

        painter.restore()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = SkyAceGame()
    window.show()
    sys.exit(app.exec())
'''

with open("games/skyace/main.py", "w", encoding="utf-8") as f:
    f.write(code)

print("Successfully updated games/skyace/main.py with 6 nations and free theaters!")
