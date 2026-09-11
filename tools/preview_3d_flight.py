#!/usr/bin/env python3
"""
Sky Ace • Dual-Faction 3D Flight, 194X Weapons & Damage Engine
Interactive vertical arcade engine supporting BOTH sides of the Pacific Theater:
- Allied Powers: Lockheed P-38 Lightning (USAAF / USS Enterprise)
- Imperial Navy: Mitsubishi A6M Zero (IJN / IJN Akagi)
- Switch sides with [Tab] anytime in flight!
- Authentic 3D cel-shaded models in Style 3 (Tactical Matte Military Camo)
- Custom flight dynamics, weapons, damage smoke, carriers, and opposing enemy air fleets for both sides
"""

import sys
import math
import random
from pathlib import Path
from PIL import Image
import numpy as np

from PySide6.QtWidgets import QApplication, QWidget
from PySide6.QtGui import QPainter, QPixmap, QImage, QColor, QFont, QPolygon
from PySide6.QtCore import QTimer, Qt, QRect, QPoint

from p38_3d_engine import build_p38_mesh
from render_3d_p38 import render_3d_frame
from zero_3d_engine import build_zero_mesh
from render_3d_zero import render_3d_zero_frame

def pil_to_qpixmap(pil_img):
    """Converts a PIL RGBA image to a PySide6 QPixmap."""
    arr = np.array(pil_img.convert("RGBA"))
    h, w, ch = arr.shape
    bytes_per_line = ch * w
    qimg = QImage(arr.data, w, h, bytes_per_line, QImage.Format_RGBA8888)
    return QPixmap.fromImage(qimg)

class Flight3DPreviewWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Sky Ace • Dual-Faction 3D Flight & Combat Engine")
        self.resize(580, 720)
        self.setFocusPolicy(Qt.StrongFocus)

        # 3D Models for both sides
        print("[Sky Ace] Initializing 3D airframes for Allied and Imperial factions...")
        self.mesh_p38 = build_p38_mesh()
        self.mesh_zero = build_zero_mesh()

        # Factions: "p38" (Allied USAAF) vs "zero" (Imperial IJN)
        self.planes = ["p38", "zero"]
        self.current_plane = "p38"
        self.plane_titles = {
            "p38": "ALLIED FORCES: LOCKHEED P-38 LIGHTNING",
            "zero": "EMPIRE OF JAPAN: MITSUBISHI A6M ZERO"
        }

        self.current_style = "tactical"
        self.styles = ["tactical", "arcade", "artisan"]
        self.style_titles = {
            "tactical": "STYLE: Tactical Matte Military Camo (Default)",
            "arcade": "STYLE: Capcom CPS-1 Vibrant 16-Bit Arcade",
            "artisan": "STYLE: Artisan Modern Cel-Shaded"
        }

        # Loop stages
        self.is_looping = False
        self.loop_tick = 0
        self.loop_stages = [
            (0.0, 35.0, 0.0),    # Pitch Up
            (0.0, 75.0, 0.0),    # Vertical Climb
            (0.0, 130.0, 0.0),   # Over Top
            (0.0, 180.0, 0.0),   # Inverted Apex
            (0.0, 230.0, 0.0),   # Inverted Dive
            (0.0, 285.0, 0.0),   # Dive Zoom
            (0.0, 330.0, 0.0),   # Pulling Out
            (0.0, 355.0, 0.0),   # Recovery
        ]

        # Cache rendered sprite frames for both aircraft
        self.cache = {"p38": {}, "zero": {}}
        print("[Sky Ace] Pre-rendering animation frames for P-38 and A6M Zero...")
        self.build_cache_for_plane("p38", self.current_style)
        self.build_cache_for_plane("zero", self.current_style)

        # Flight State
        self.x = 290
        self.y = 540
        self.ocean_y = 0
        self.prop_tick = 0
        self.bank_angle = 0.0
        self.target_bank = 0.0
        # Mode: "flying", "takeoff", "landing"
        self.mode = "flying"
        self.takeoff_tick = 0
        self.landing_tick = 0
        self.carrier_y = -9999

        # Weapons & 194X Arsenal
        self.weapons = ["twin", "quad", "shotgun", "threeway", "escorts", "missiles"]
        self.weapon_names = {
            "p38": {
                "twin": "TWIN .50 CAL NOSE GUNS",
                "quad": "QUAD 20MM HISPANO CANNONS",
                "shotgun": "1943 SHOTGUN (BULLET CANCELER)",
                "threeway": "3-WAY FLANK SPREAD CANNONS",
                "escorts": "TWIN P-38 WINGMEN (6-GUN WALL)",
                "missiles": "HOMING AIR-TO-AIR ROCKETS"
            },
            "zero": {
                "twin": "TWIN 7.7MM TYPE 97 COWL GUNS",
                "quad": "QUAD 20MM TYPE 99 WING CANNONS",
                "shotgun": "TYPE 99 SPREAD (BULLET CANCELER)",
                "threeway": "3-WAY TYPE 99 ANGLE CANNONS",
                "escorts": "KI-43 OSCAR ESCORTS (6-GUN WALL)",
                "missiles": "TYPE 99 AIR-TO-AIR ROCKETS"
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
        
        # Progressive Damage & Health System
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
        self.banner_text = "ALLIED FACTION: P-38 LIGHTNING READY"
        self.banner_timer = 120

        self.keys = set()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_flight)
        self.timer.start(16)

    def build_cache_for_plane(self, plane, style):
        """Pre-renders key flight poses for the specified aircraft."""
        if style not in self.cache[plane]:
            self.cache[plane][style] = {}
        
        mesh = self.mesh_p38 if plane == "p38" else self.mesh_zero
        render_fn = render_3d_frame if plane == "p38" else render_3d_zero_frame

        # Level cruise (4 propeller phases)
        for p_idx, p_ang in enumerate([0.0, 40.0, 80.0, 120.0]):
            img = render_fn(mesh, roll_deg=0.0, pitch_deg=0.0, prop_angle=p_ang, style=style)
            self.cache[plane][style][f"level_{p_idx}"] = pil_to_qpixmap(img)

        # Banking angles: -28 to +28 with 3 spinning propeller phases
        for roll in [-28, -14, 14, 28]:
            tag = "left" if roll < 0 else "right"
            hard = "hard_" if abs(roll) > 20 else ""
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                name = f"bank_{hard}{tag}_{p_idx}"
                img = render_fn(mesh, roll_deg=float(roll), pitch_deg=0.0, 
                                yaw_deg=float(roll)*0.2, prop_angle=p_ang, style=style)
                self.cache[plane][style][name] = pil_to_qpixmap(img)

        # Loop stages
        for st_idx, (r, p, y) in enumerate(self.loop_stages):
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=r, pitch_deg=p, yaw_deg=y, 
                                prop_angle=p_ang, style=style)
                self.cache[plane][style][f"loop_{st_idx}_{p_idx}"] = pil_to_qpixmap(img)

        # Takeoff climb pitch angles
        for pitch, p_name in [(22.0, "climb_steep"), (12.0, "climb_mild")]:
            for p_idx, p_ang in enumerate([0.0, 40.0, 80.0]):
                img = render_fn(mesh, roll_deg=0.0, pitch_deg=pitch, 
                                yaw_deg=0.0, prop_angle=p_ang, style=style)
                self.cache[plane][style][f"{p_name}_{p_idx}"] = pil_to_qpixmap(img)

    def toggle_plane(self):
        """Switches player between Allied (P-38) and Empire (A6M Zero)."""
        if self.current_plane == "p38":
            self.current_plane = "zero"
            self.banner_text = "★ EMPIRE OF JAPAN: MITSUBISHI A6M ZERO SELECTED! ★"
        else:
            self.current_plane = "p38"
            self.banner_text = "★ ALLIED FORCES: LOCKHEED P-38 LIGHTNING SELECTED! ★"
        self.banner_timer = 110
        self.enemies.clear()
        self.enemy_bullets.clear()
        self.update()

    def trigger_fire(self):
        """Fires the active weapon system from underneath the nose and wings."""
        if self.mode != "flying" or self.is_looping or self.death_ticks > 0:
            return
        weapon = self.weapons[self.weapon_idx]
        nose_y = self.y - 52
        is_zero = (self.current_plane == "zero")
        
        if weapon == "twin":
            if is_zero:
                # Twin 7.7mm Cowl Guns (tighter spacing from upper cowl)
                self.bullets.append({"x": self.x - 4, "y": nose_y, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                self.bullets.append({"x": self.x + 4, "y": nose_y, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                self.muzzle_flashes.append({"x": self.x - 4, "y": nose_y, "life": 3})
                self.muzzle_flashes.append({"x": self.x + 4, "y": nose_y, "life": 3})
            else:
                # Twin .50cal Machine Guns
                self.bullets.append({"x": self.x - 7, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
                self.bullets.append({"x": self.x + 7, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
                self.muzzle_flashes.append({"x": self.x - 7, "y": nose_y, "life": 3})
                self.muzzle_flashes.append({"x": self.x + 7, "y": nose_y, "life": 3})

        elif weapon == "quad":
            if is_zero:
                # Twin 7.7mm cowl guns + Twin 20mm Type 99 wing cannons
                self.bullets.append({"x": self.x - 4, "y": nose_y, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                self.bullets.append({"x": self.x + 4, "y": nose_y, "vx": 0, "vy": -24, "type": "twin", "dmg": 1})
                self.bullets.append({"x": self.x - 26, "y": self.y - 20, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                self.bullets.append({"x": self.x + 26, "y": self.y - 20, "vx": 0, "vy": -25, "type": "quad", "dmg": 2})
                self.muzzle_flashes.append({"x": self.x - 26, "y": self.y - 20, "life": 4})
                self.muzzle_flashes.append({"x": self.x + 26, "y": self.y - 20, "life": 4})
            else:
                for bx in [-20, -7, 7, 20]:
                    self.bullets.append({"x": self.x + bx, "y": nose_y, "vx": 0, "vy": -24, "type": "quad", "dmg": 2})
                    self.muzzle_flashes.append({"x": self.x + bx, "y": nose_y, "life": 4})

        elif weapon == "shotgun":
            angles = [(-9.0, -20.0), (-4.5, -21.5), (0.0, -23.0), (4.5, -21.5), (9.0, -20.0)]
            for vx, vy in angles:
                self.bullets.append({
                    "x": self.x, "y": nose_y, "vx": vx, "vy": vy, 
                    "type": "shotgun", "dmg": 2, "cancels_bullets": True
                })
            self.muzzle_flashes.append({"x": self.x, "y": nose_y, "life": 5})

        elif weapon == "threeway":
            self.bullets.append({"x": self.x, "y": nose_y, "vx": 0, "vy": -24, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x - 12, "y": nose_y, "vx": -11, "vy": -21, "type": "threeway", "dmg": 2})
            self.bullets.append({"x": self.x + 12, "y": nose_y, "vx": 11, "vy": -21, "type": "threeway", "dmg": 2})
            self.muzzle_flashes.append({"x": self.x, "y": nose_y, "life": 4})
            self.muzzle_flashes.append({"x": self.x - 12, "y": nose_y, "life": 4})
            self.muzzle_flashes.append({"x": self.x + 12, "y": nose_y, "life": 4})

        elif weapon == "escorts":
            # 6-gun synchronized barrage
            self.bullets.append({"x": self.x - 6, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": self.x + 6, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": self.x - 6, "y": nose_y, "life": 3})
            self.muzzle_flashes.append({"x": self.x + 6, "y": nose_y, "life": 3})
            
            # Left Wingman
            lx, ly = self.x - 56, self.y + 14
            self.bullets.append({"x": lx - 5, "y": ly - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": lx + 5, "y": ly - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": lx - 5, "y": ly - 20, "life": 3})
            self.muzzle_flashes.append({"x": lx + 5, "y": ly - 20, "life": 3})

            # Right Wingman
            rx, ry = self.x + 56, self.y + 14
            self.bullets.append({"x": rx - 5, "y": ry - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": rx + 5, "y": ry - 20, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": rx - 5, "y": ry - 20, "life": 3})
            self.muzzle_flashes.append({"x": rx + 5, "y": ry - 20, "life": 3})

        elif weapon == "missiles":
            # Nose guns + 2 Homing Rockets from underwing hardpoints
            self.bullets.append({"x": self.x - 6, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.bullets.append({"x": self.x + 6, "y": nose_y, "vx": 0, "vy": -22, "type": "twin", "dmg": 1})
            self.muzzle_flashes.append({"x": self.x - 6, "y": nose_y, "life": 3})
            self.muzzle_flashes.append({"x": self.x + 6, "y": nose_y, "life": 3})

            # Launch seekers
            wing_span = 26 if is_zero else 28
            self.missiles.append({"x": self.x - wing_span, "y": self.y + 6, "vx": -3.0, "vy": -6.0, "speed": 8.0})
            self.missiles.append({"x": self.x + wing_span, "y": self.y + 6, "vx": 3.0, "vy": -6.0, "speed": 8.0})

        self.update()

    def trigger_mega_crash(self):
        """1943 Screen-clearing Mega Crash bomb."""
        if self.mode != "flying" or self.is_looping or self.death_ticks > 0:
            return
        self.mega_crash_ticks = 28
        self.screen_shake = 12
        self.banner_text = "⚡ 1943 MEGA CRASH ACTIVATED! ⚡"
        self.banner_timer = 90

        # Vaporize all enemy bullets
        for eb in self.enemy_bullets:
            for _ in range(3):
                self.spark_particles.append({
                    "x": eb["x"] + random.randint(-4, 4), 
                    "y": eb["y"] + random.randint(-4, 4), 
                    "vx": random.uniform(-3, 3), 
                    "vy": random.uniform(-3, 3), 
                    "life": 12, "color": QColor(100, 220, 255)
                })
        self.enemy_bullets.clear()

        # Damage all enemies on screen
        for e in self.enemies:
            e["hp"] -= 25
            self.explosions.append({"x": e["x"], "y": e["y"], "radius": 32, "max_radius": 38, "life": 16})
            if e.get("is_heavy", False):
                self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.0})

        self.update()

    def take_player_damage(self, amount=1, hit_x=None, hit_y=None):
        """Registers damage impact, flashes sprite, and initiates progressive damage."""
        if self.invulnerable_ticks > 0 or self.death_ticks > 0 or self.is_looping or self.mode != "flying":
            return
        
        self.hp = max(0, self.hp - amount)
        self.hit_flash_ticks = 6
        self.invulnerable_ticks = 75
        self.screen_shake = 9
        
        hx = hit_x if hit_x is not None else self.x
        hy = hit_y if hit_y is not None else self.y
        
        for _ in range(12):
            self.spark_particles.append({
                "x": hx + random.randint(-4, 4),
                "y": hy + random.randint(-4, 4),
                "vx": random.uniform(-6, 6),
                "vy": random.uniform(-6, 6),
                "life": 14,
                "color": random.choice([QColor(255, 230, 80), QColor(255, 140, 20), QColor(255, 255, 255)])
            })
        self.explosions.append({"x": hx, "y": hy, "radius": 14, "max_radius": 24, "life": 10})
        
        if self.hp == 3:
            self.banner_text = "⚠ IMPACT! LIGHT DAMAGE: ENGINE VAPOR PUFFING ⚠"
        elif self.hp == 2:
            self.banner_text = "⚠ WARNING! MODERATE DAMAGE: BLACK OIL SMOKE BILLOWING ⚠"
        elif self.hp == 1:
            self.banner_text = "🔥 CRITICAL FAILURE! ENGINE ON FIRE! EVASIVE ACTION! 🔥"
        elif self.hp == 0:
            self.banner_text = "💥 AIRCRAFT CRITICALLY STRUCK! ENTERING DEATH SPIRAL! 💥"
            self.death_ticks = 1
        self.banner_timer = 90
        self.update()

    def mousePressEvent(self, event):
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
        self.update()

    def keyPressEvent(self, event):
        key = event.key()
        if key == Qt.Key_Escape:
            self.close()
        elif key == Qt.Key_Tab or key == Qt.Key_0:
            # Switch between P-38 and A6M Zero!
            self.toggle_plane()
        elif key == Qt.Key_1:
            self.current_style = "tactical"
        elif key == Qt.Key_2:
            self.current_style = "arcade"
            self.build_cache_for_plane(self.current_plane, "arcade")
        elif key == Qt.Key_3:
            self.current_style = "artisan"
            self.build_cache_for_plane(self.current_plane, "artisan")
        elif key == Qt.Key_T:
            self.mode = "takeoff"
            self.takeoff_tick = 0
            self.is_looping = False
        elif key == Qt.Key_L:
            if self.mode == "flying" and not self.is_looping and self.death_ticks == 0:
                self.mode = "landing"
                self.landing_tick = 0
        elif key == Qt.Key_P:
            self.cycle_weapon()
        elif key in (Qt.Key_Space, Qt.Key_Return):
            if not self.is_looping and self.mode == "flying" and self.death_ticks == 0:
                self.is_looping = True
                self.loop_tick = 0
        elif key == Qt.Key_B:
            self.trigger_mega_crash()
        elif key == Qt.Key_H:
            self.take_player_damage(1)
        elif key == Qt.Key_R:
            self.hp = self.max_hp
            self.death_ticks = 0
            self.banner_text = "★ AIRCRAFT FULLY REPAIRED (100% ARMOR) ★"
            self.banner_timer = 90
            self.update()
        elif key in (Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V, Qt.Key_F, Qt.Key_J, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Shift):
            self.keys.add(key)
            self.is_fire_held = True
            self.trigger_fire()
        else:
            self.keys.add(key)

    def keyReleaseEvent(self, event):
        key = event.key()
        self.keys.discard(key)
        if key in (Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V, Qt.Key_F, Qt.Key_J, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Shift):
            if not any(k in self.keys for k in [Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V, Qt.Key_F, Qt.Key_J, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Shift]):
                self.is_fire_held = False

    def update_flight(self):
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

        moving_left = any(k in self.keys for k in [Qt.Key_Left, Qt.Key_A])
        moving_right = any(k in self.keys for k in [Qt.Key_Right, Qt.Key_D])
        moving_up = any(k in self.keys for k in [Qt.Key_Up, Qt.Key_W])
        moving_down = any(k in self.keys for k in [Qt.Key_Down, Qt.Key_S])

        is_zero = (self.current_plane == "zero")

        # ---------------------------------------------------------------------
        # 1. TAKEOFF SEQUENCE (Pitch-up steep climb off bow)
        # ---------------------------------------------------------------------
        if self.mode == "takeoff":
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
                self.mode = "flying"
                self.y = 480
                self.carrier_y = -9999

        # ---------------------------------------------------------------------
        # 2. LANDING SEQUENCE & FULL REPAIRS
        # ---------------------------------------------------------------------
        elif self.mode == "landing":
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
            else:
                self.x = self.width() // 2
                self.y = halt_y
                if self.hp < self.max_hp:
                    self.hp = self.max_hp
                    self.banner_text = "★ CARRIER DECK SERVICING: AIRCRAFT 100% REPAIRED! ★"
                    self.banner_timer = 90

        # ---------------------------------------------------------------------
        # 3. NORMAL CRUISE & FLIGHT DYNAMICS
        # ---------------------------------------------------------------------
        elif self.mode == "flying":
            if self.death_ticks > 0:
                # Fatal death dive
                self.death_ticks += 1
                self.y += 3.6
                self.x += math.sin(self.death_ticks * 0.22) * 3.8
                
                for _ in range(3):
                    self.smoke_particles.append({
                        "x": self.x + random.randint(-18, 18),
                        "y": self.y + random.randint(-10, 20),
                        "vx": random.uniform(-1.5, 1.5),
                        "vy": random.uniform(1.0, 4.0),
                        "rad": 8, "max_rad": 24,
                        "life": 18, "type": "fire"
                    })
                    self.smoke_particles.append({
                        "x": self.x + random.randint(-16, 16),
                        "y": self.y + random.randint(10, 25),
                        "vx": random.uniform(-1.2, 1.2),
                        "vy": random.uniform(2.0, 5.0),
                        "rad": 12, "max_rad": 36,
                        "life": 30, "type": "black_smoke"
                    })

                if self.death_ticks >= 80:
                    for _ in range(5):
                        self.explosions.append({
                            "x": self.x + random.randint(-25, 25),
                            "y": self.y + random.randint(-20, 20),
                            "radius": 24, "max_radius": 56, "life": 24
                        })
                    self.screen_shake = 14
                    self.hp = self.max_hp
                    self.death_ticks = 0
                    self.x = self.width() // 2
                    self.y = 540
                    self.invulnerable_ticks = 90
                    self.banner_text = f"★ FRESH {self.current_plane.upper()} REPLACED & AIRBORNE! ★"
                    self.banner_timer = 110

            elif not self.is_looping:
                # Zero has snappier bank rate and higher lateral agility
                bank_speed = 0.45 if is_zero else 0.35
                fly_speed = 7 if is_zero else 6

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

        # ---------------------------------------------------------------------
        # 4. DAMAGE SMOKE & FIRE EMISSION
        # ---------------------------------------------------------------------
        if self.mode == "flying" and self.death_ticks == 0:
            if is_zero:
                # Single Sakae radial engine: smoke & fire pour from center fuselage/cowl
                if self.hp == 3:
                    if random.random() < 0.45:
                        self.smoke_particles.append({
                            "x": self.x + random.randint(-3, 3), "y": self.y + 24,
                            "vx": random.uniform(-0.5, 0.5), "vy": random.uniform(2.5, 4.5),
                            "rad": 6, "max_rad": 16, "life": 22, "type": "vapor"
                        })
                elif self.hp == 2:
                    self.smoke_particles.append({
                        "x": self.x + random.randint(-4, 4), "y": self.y + 22,
                        "vx": random.uniform(-0.8, 0.8), "vy": random.uniform(3.0, 5.5),
                        "rad": 8, "max_rad": 26, "life": 28, "type": "black_smoke"
                    })
                    if random.random() < 0.25:
                        self.spark_particles.append({
                            "x": self.x, "y": self.y + 24,
                            "vx": random.uniform(-2, 2), "vy": random.uniform(2, 6),
                            "life": 10, "color": QColor(255, 140, 20)
                        })
                elif self.hp == 1:
                    for _ in range(2):
                        self.smoke_particles.append({
                            "x": self.x + random.randint(-4, 4), "y": self.y + 16,
                            "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.5, 6.0),
                            "rad": 7, "max_rad": 20, "life": 16, "type": "fire"
                        })
                    self.smoke_particles.append({
                        "x": self.x + random.randint(-5, 5), "y": self.y + 24,
                        "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.5, 6.5),
                        "rad": 10, "max_rad": 30, "life": 32, "type": "black_smoke"
                    })
            else:
                # P-38: Twin Allison engines
                if self.hp == 3:
                    if random.random() < 0.45:
                        self.smoke_particles.append({
                            "x": self.x - 28 + random.randint(-3, 3), "y": self.y + 24,
                            "vx": random.uniform(-0.5, 0.5), "vy": random.uniform(2.5, 4.5),
                            "rad": 6, "max_rad": 16, "life": 22, "type": "vapor"
                        })
                elif self.hp == 2:
                    self.smoke_particles.append({
                        "x": self.x - 28 + random.randint(-4, 4), "y": self.y + 22,
                        "vx": random.uniform(-0.8, 0.8), "vy": random.uniform(3.0, 5.5),
                        "rad": 8, "max_rad": 26, "life": 28, "type": "black_smoke"
                    })
                    if random.random() < 0.25:
                        self.spark_particles.append({
                            "x": self.x - 28, "y": self.y + 24,
                            "vx": random.uniform(-2, 2), "vy": random.uniform(2, 6),
                            "life": 10, "color": QColor(255, 140, 20)
                        })
                elif self.hp == 1:
                    for _ in range(2):
                        self.smoke_particles.append({
                            "x": self.x - 28 + random.randint(-4, 4), "y": self.y + 16,
                            "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.5, 6.0),
                            "rad": 7, "max_rad": 20, "life": 16, "type": "fire"
                        })
                    self.smoke_particles.append({
                        "x": self.x - 28 + random.randint(-5, 5), "y": self.y + 24,
                        "vx": random.uniform(-1.0, 1.0), "vy": random.uniform(3.5, 6.5),
                        "rad": 10, "max_rad": 30, "life": 32, "type": "black_smoke"
                    })
                    self.smoke_particles.append({
                        "x": self.x + 28 + random.randint(-5, 5), "y": self.y + 24,
                        "vx": random.uniform(-0.8, 0.8), "vy": random.uniform(3.0, 5.5),
                        "rad": 8, "max_rad": 24, "life": 26, "type": "black_smoke"
                    })

        # ---------------------------------------------------------------------
        # 5. WEAPONS AUTO-FIRE
        # ---------------------------------------------------------------------
        if self.is_fire_held and self.mode == "flying" and not self.is_looping and self.death_ticks == 0:
            if self.fire_cooldown <= 0:
                self.trigger_fire()
                self.fire_cooldown = 5

        if self.fire_cooldown > 0:
            self.fire_cooldown -= 1

        # ---------------------------------------------------------------------
        # 6. OPPOSING ENEMY FORMATION SPAWNS (Contextual to current plane)
        # ---------------------------------------------------------------------
        self.spawn_tick += 1
        if self.spawn_tick >= 80 and self.mode == "flying":
            self.spawn_tick = 0
            pattern = random.choice(["v_formation", "sweep", "heavy_bomber"])
            
            # If player is Zero, enemies are Allied F6F Hellcats (Navy Blue) & B-17s!
            # If player is P-38, enemies are Japanese Zeros (Green) & Red Bombers!
            enemy_faction = "allied" if is_zero else "imperial"

            if pattern == "v_formation":
                center_x = random.randint(140, self.width() - 140)
                self.enemies.append({"x": center_x, "y": -40, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "is_heavy": False})
                self.enemies.append({"x": center_x - 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "is_heavy": False})
                self.enemies.append({"x": center_x + 45, "y": -75, "vx": 0, "vy": 3.8, "hp": 3, "faction": enemy_faction, "is_heavy": False})
            elif pattern == "sweep":
                start_x = random.choice([60, self.width() - 60])
                vx = 2.4 if start_x < self.width() // 2 else -2.4
                self.enemies.append({"x": start_x, "y": -30, "vx": vx, "vy": 4.2, "hp": 4, "faction": enemy_faction, "is_heavy": False})
            elif pattern == "heavy_bomber":
                start_x = random.randint(100, self.width() - 100)
                self.enemies.append({"x": start_x, "y": -50, "vx": random.uniform(-0.8, 0.8), "vy": 2.2, "hp": 10, "faction": enemy_faction, "is_heavy": True})

        # Update enemies
        alive_enemies = []
        for e in self.enemies:
            e["x"] += e["vx"]
            e["y"] += e["vy"]
            
            if random.random() < 0.016 and e["y"] < self.height() - 160:
                self.enemy_bullets.append({"x": e["x"], "y": e["y"] + 15, "vx": 0, "vy": 4.5})

            if self.mode == "flying" and not self.is_looping and self.invulnerable_ticks <= 0 and self.death_ticks == 0:
                if math.hypot(e["x"] - self.x, e["y"] - self.y) < 38:
                    e["hp"] = 0
                    self.take_player_damage(1, hit_x=e["x"], hit_y=e["y"])

            if e["y"] < self.height() + 60:
                alive_enemies.append(e)
        self.enemies = alive_enemies

        # ---------------------------------------------------------------------
        # 7. HOMING MISSILE PHYSICS & TRACKING
        # ---------------------------------------------------------------------
        alive_missiles = []
        for m in self.missiles:
            target = None
            min_dist = 999999
            for e in self.enemies:
                if e["y"] < m["y"] + 20:
                    d = math.hypot(e["x"] - m["x"], e["y"] - m["y"])
                    if d < min_dist:
                        min_dist = d
                        target = e

            if target:
                tx, ty = target["x"], target["y"]
                desired_vx = (tx - m["x"]) / max(1.0, min_dist) * m["speed"]
                desired_vy = (ty - m["y"]) / max(1.0, min_dist) * m["speed"]
                m["vx"] += (desired_vx - m["vx"]) * 0.22
                m["vy"] += (desired_vy - m["vy"]) * 0.22

            m["speed"] = min(18.0, m["speed"] + 0.6)
            m["x"] += m["vx"]
            m["y"] += m["vy"]

            self.spark_particles.append({
                "x": m["x"] + random.randint(-2, 2), 
                "y": m["y"] + 10, 
                "vx": random.uniform(-0.5, 0.5), 
                "vy": random.uniform(1.0, 2.5), 
                "life": 10, "color": QColor(210, 220, 230, 180)
            })

            hit = False
            for e in self.enemies:
                if math.hypot(e["x"] - m["x"], e["y"] - m["y"]) < 24:
                    e["hp"] -= 6
                    self.explosions.append({"x": m["x"], "y": m["y"], "radius": 18, "max_radius": 24, "life": 12})
                    hit = True
                    break

            if not hit and m["y"] > -50 and 0 <= m["x"] <= self.width():
                alive_missiles.append(m)
        self.missiles = alive_missiles

        # ---------------------------------------------------------------------
        # 8. BULLETS & 1943 BULLET-CANCELING
        # ---------------------------------------------------------------------
        alive_bullets = []
        for b in self.bullets:
            b["x"] += b["vx"]
            b["y"] += b["vy"]

            if b.get("cancels_bullets", False):
                hit_eb = []
                for eb in self.enemy_bullets:
                    dist = math.hypot(eb["x"] - b["x"], eb["y"] - b["y"])
                    if dist < 18:
                        for _ in range(4):
                            self.spark_particles.append({
                                "x": eb["x"], "y": eb["y"], 
                                "vx": random.uniform(-3, 3), 
                                "vy": random.uniform(-3, 3), 
                                "life": 8, "color": QColor(80, 240, 255)
                            })
                    else:
                        hit_eb.append(eb)
                self.enemy_bullets = hit_eb

            hit = False
            for e in self.enemies:
                radius = b.get("radius", 14)
                if math.hypot(e["x"] - b["x"], e["y"] - b["y"]) < (radius + 18):
                    e["hp"] -= b.get("dmg", 1)
                    for _ in range(3):
                        self.spark_particles.append({
                            "x": b["x"], "y": b["y"], 
                            "vx": random.uniform(-4, 4), 
                            "vy": random.uniform(-4, 4), 
                            "life": 6, "color": QColor(255, 230, 80)
                        })
                    hit = True
                    break

            if not hit and b["y"] > -60 and -40 <= b["x"] <= self.width() + 40:
                alive_bullets.append(b)
        self.bullets = alive_bullets

        # ---------------------------------------------------------------------
        # 9. ENEMY BULLETS & PLAYER HIT DETECTION
        # ---------------------------------------------------------------------
        alive_enemy_bullets = []
        for eb in self.enemy_bullets:
            eb["x"] += eb.get("vx", 0)
            eb["y"] += eb["vy"]

            hit_player = False
            if self.mode == "flying" and not self.is_looping and self.invulnerable_ticks <= 0 and self.death_ticks == 0:
                # Wingman sacrifice
                if self.weapons[self.weapon_idx] == "escorts":
                    if math.hypot(eb["x"] - (self.x - 56), eb["y"] - (self.y + 14)) < 24:
                        hit_player = True
                        self.weapons[self.weapon_idx] = "twin"
                        self.explosions.append({"x": self.x - 56, "y": self.y + 14, "radius": 24, "max_radius": 34, "life": 16})
                        self.banner_text = "★ WINGMAN SACRIFICED! ABSORBED ENEMY HIT! ★"
                        self.banner_timer = 90
                        self.screen_shake = 6
                        self.invulnerable_ticks = 40
                    elif math.hypot(eb["x"] - (self.x + 56), eb["y"] - (self.y + 14)) < 24:
                        hit_player = True
                        self.weapons[self.weapon_idx] = "twin"
                        self.explosions.append({"x": self.x + 56, "y": self.y + 14, "radius": 24, "max_radius": 34, "life": 16})
                        self.banner_text = "★ WINGMAN SACRIFICED! ABSORBED ENEMY HIT! ★"
                        self.banner_timer = 90
                        self.screen_shake = 6
                        self.invulnerable_ticks = 40

                if not hit_player and math.hypot(eb["x"] - self.x, eb["y"] - self.y) < 32:
                    hit_player = True
                    self.take_player_damage(1, hit_x=eb["x"], hit_y=eb["y"])

            if not hit_player and eb["y"] < self.height() + 20:
                alive_enemy_bullets.append(eb)
        self.enemy_bullets = alive_enemy_bullets

        # ---------------------------------------------------------------------
        # 10. ENEMY DEATH & POW ITEM DROPS
        # ---------------------------------------------------------------------
        surviving_enemies = []
        for e in self.enemies:
            if e["hp"] <= 0:
                exp_rad = 34 if e.get("is_heavy", False) else 22
                self.explosions.append({"x": e["x"], "y": e["y"], "radius": 14, "max_radius": exp_rad, "life": 16})
                if e.get("is_heavy", False):
                    self.pickups.append({"x": e["x"], "y": e["y"], "vy": 2.0})
                    self.banner_text = "HEAVY TARGET DESTROYED! POW BADGE DROPPED!"
                    self.banner_timer = 90
            else:
                surviving_enemies.append(e)
        self.enemies = surviving_enemies

        # ---------------------------------------------------------------------
        # 11. POW PICKUPS & COLLISION
        # ---------------------------------------------------------------------
        alive_pickups = []
        for p in self.pickups:
            p["y"] += p["vy"]
            if math.hypot(p["x"] - self.x, p["y"] - self.y) < 40 and self.mode == "flying":
                self.cycle_weapon()
                if self.hp < self.max_hp:
                    self.hp = min(self.max_hp, self.hp + 1)
                w_name = self.weapon_names[self.current_plane][self.weapons[self.weapon_idx]]
                self.banner_text = f"★ POW ACQUIRED! UPGRADED TO {w_name} ★"
                self.banner_timer = 100
                for _ in range(12):
                    self.spark_particles.append({
                        "x": self.x, "y": self.y, 
                        "vx": random.uniform(-5, 5), 
                        "vy": random.uniform(-5, 5), 
                        "life": 15, "color": QColor(255, 180, 20)
                    })
            elif p["y"] < self.height() + 30:
                alive_pickups.append(p)
        self.pickups = alive_pickups

        # Update flashes, particles, smoke, explosions
        for f in self.muzzle_flashes:
            f["life"] -= 1
        self.muzzle_flashes = [f for f in self.muzzle_flashes if f["life"] > 0]

        for sp in self.spark_particles:
            sp["x"] += sp["vx"]
            sp["y"] += sp["vy"]
            sp["life"] -= 1
        self.spark_particles = [sp for sp in self.spark_particles if sp["life"] > 0]

        for sm in self.smoke_particles:
            sm["x"] += sm["vx"]
            sm["y"] += sm["vy"]
            sm["rad"] += (sm["max_rad"] - sm["rad"]) * 0.14
            sm["life"] -= 1
        self.smoke_particles = [sm for sm in self.smoke_particles if sm["life"] > 0]

        for exp in self.explosions:
            exp["radius"] += (exp["max_radius"] - exp["radius"]) * 0.25
            exp["life"] -= 1
        self.explosions = [exp for exp in self.explosions if exp["life"] > 0]

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)

        # Screen shake offset
        if self.screen_shake > 0:
            dx = random.randint(-self.screen_shake, self.screen_shake)
            dy = random.randint(-self.screen_shake, self.screen_shake)
            painter.translate(dx, dy)

        # 1. Deep Pacific Ocean
        painter.fillRect(self.rect(), QColor(20, 60, 115))

        # Wave ripples
        painter.setPen(QColor(36, 92, 155))
        for wy in range(-48, self.height() + 48, 30):
            y_pos = wy + self.ocean_y
            for wx in range(0, self.width(), 36):
                painter.drawArc(wx - 10, y_pos, 20, 10, 0, 180 * 16)

        # Tropical Island
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor(42, 160, 170))
        painter.drawEllipse(self.width() - 140, 160, 170, 170)
        painter.setBrush(QColor(230, 210, 150))
        painter.drawEllipse(self.width() - 120, 180, 130, 130)
        painter.setBrush(QColor(36, 120, 48))
        painter.drawEllipse(self.width() - 105, 195, 100, 100)

        is_zero = (self.current_plane == "zero")

        # 1.5. Aircraft Carrier (Contextual: USS Enterprise for Allied vs IJN Akagi for Empire)
        if self.carrier_y > -600 and self.carrier_y < self.height() + 600:
            c_w, c_h = 230, 520
            cx = self.width() // 2
            cy = self.carrier_y

            # Ocean wake foam
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(180, 220, 255, 90))
            painter.drawEllipse(cx - c_w//2 - 20, cy + c_h - 40, c_w + 40, 90)

            # Carrier Hull
            painter.setBrush(QColor(48, 56, 66) if is_zero else QColor(52, 62, 72))
            hull_pts = [
                (cx - c_w//2 + 25, cy),
                (cx + c_w//2 - 25, cy),
                (cx + c_w//2, cy + 60),
                (cx + c_w//2, cy + c_h),
                (cx - c_w//2, cy + c_h),
                (cx - c_w//2, cy + 60),
            ]
            poly = QPolygon([QPoint(int(pt[0]), int(pt[1])) for pt in hull_pts])
            painter.drawPolygon(poly)

            # Wooden Flight Deck
            painter.setBrush(QColor(155, 125, 90) if is_zero else QColor(168, 138, 102))
            deck_pts = [
                (cx - c_w//2 + 32, cy + 10),
                (cx + c_w//2 - 32, cy + 10),
                (cx + c_w//2 - 8, cy + 65),
                (cx + c_w//2 - 8, cy + c_h - 10),
                (cx - c_w//2 + 8, cy + c_h - 10),
                (cx - c_w//2 + 8, cy + 65),
            ]
            deck_poly = QPolygon([QPoint(int(pt[0]), int(pt[1])) for pt in deck_pts])
            painter.drawPolygon(deck_poly)

            painter.setPen(QColor(135, 108, 76, 160))
            for py in range(int(cy + 25), int(cy + c_h - 15), 16):
                painter.drawLine(cx - c_w//2 + 15, py, cx + c_w//2 - 15, py)

            # Runway markings
            if is_zero:
                # IJN Akagi: Bold red & white stern recognition stripes
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(210, 35, 35))
                painter.drawRect(QRect(cx - 70, int(cy + c_h - 60), 140, 16))
                painter.setBrush(QColor(245, 245, 245))
                painter.drawRect(QRect(cx - 70, int(cy + c_h - 40), 140, 14))
                # White identification character "ア" (Akagi) near aft
                painter.setPen(QColor(245, 245, 245, 220))
                font_kanji = QFont("Menlo", 16, QFont.Bold)
                painter.setFont(font_kanji)
                painter.drawText(QRect(cx - 20, int(cy + c_h - 105), 40, 30), Qt.AlignCenter, "ア")
                # Island on PORT side (Akagi uniquely had port-side island!)
                ix = cx - c_w//2 + 12
                iy = cy + 160
                painter.setBrush(QColor(42, 50, 58))
                painter.drawRect(QRect(ix, iy, 26, 75))
            else:
                # US Navy Enterprise: Yellow/White Centerline Runway
                painter.setPen(QColor(245, 220, 50))
                for py in range(int(cy + 30), int(cy + c_h - 20), 28):
                    painter.drawLine(cx, py, cx, py + 16)
                # Island on STARBOARD side
                ix = cx + c_w//2 - 38
                iy = cy + 160
                painter.setBrush(QColor(42, 50, 58))
                painter.drawRect(QRect(ix, iy, 26, 75))

            # Arresting Cables
            painter.setPen(QColor(35, 35, 38))
            for py in range(int(cy + c_h - 110), int(cy + c_h - 40), 18):
                painter.drawLine(cx - 75, py, cx + 75, py)

        # 2. Target Drones & Enemies (Contextual)
        for e in self.enemies:
            ex, ey = int(e["x"]), int(e["y"])
            faction = e.get("faction", "imperial")
            is_heavy = e.get("is_heavy", False)

            painter.setOpacity(0.25)
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(10, 20, 35))
            painter.drawEllipse(ex - 16, ey + 28, 32, 22)
            painter.setOpacity(1.0)

            if faction == "allied":
                # US Navy Grumman F6F Hellcat / B-17 Flying Fortress
                if is_heavy:
                    # B-17 Flying Fortress
                    painter.setBrush(QColor(95, 105, 90))
                    painter.setPen(QColor(40, 48, 40))
                    painter.drawRoundedRect(QRect(ex - 12, ey - 26, 24, 52), 6, 6)
                    painter.drawRoundedRect(QRect(ex - 46, ey - 8, 92, 14), 4, 4)
                    painter.setBrush(QColor(45, 48, 52))
                    painter.drawRect(QRect(ex - 28, ey - 12, 8, 20))
                    painter.drawRect(QRect(ex + 20, ey - 12, 8, 20))
                else:
                    # F6F Hellcat (Pacific Navy Blue)
                    painter.setBrush(QColor(32, 58, 95))
                    painter.setPen(QColor(14, 28, 48))
                    painter.drawRoundedRect(QRect(ex - 7, ey - 16, 14, 32), 4, 4)
                    painter.drawRoundedRect(QRect(ex - 28, ey - 4, 56, 8), 3, 3)
                    # Allied White Star Roundel
                    painter.setBrush(QColor(235, 240, 245))
                    painter.setPen(Qt.NoPen)
                    painter.drawEllipse(ex - 22, ey - 3, 6, 6)
                    painter.drawEllipse(ex + 16, ey - 3, 6, 6)
            else:
                # Japanese A6M Zero / Heavy Bomber
                if is_heavy:
                    painter.setBrush(QColor(220, 45, 35))
                    painter.setPen(QColor(90, 10, 10))
                    painter.drawRoundedRect(QRect(ex - 10, ey - 22, 20, 44), 6, 6)
                    painter.drawRoundedRect(QRect(ex - 38, ey - 6, 76, 12), 4, 4)
                    painter.setBrush(QColor(50, 50, 55))
                    painter.drawRect(QRect(ex - 22, ey - 10, 8, 18))
                    painter.drawRect(QRect(ex + 14, ey - 10, 8, 18))
                else:
                    painter.setBrush(QColor(48, 120, 75))
                    painter.setPen(QColor(20, 55, 30))
                    painter.drawRoundedRect(QRect(ex - 6, ey - 16, 12, 32), 4, 4)
                    painter.drawRoundedRect(QRect(ex - 26, ey - 4, 52, 8), 3, 3)
                    painter.setBrush(QColor(215, 35, 35))
                    painter.setPen(Qt.NoPen)
                    painter.drawEllipse(ex - 20, ey - 3, 6, 6)
                    painter.drawEllipse(ex + 14, ey - 3, 6, 6)

        # 3. Enemy Bullets
        for eb in self.enemy_bullets:
            bx, by = int(eb["x"]), int(eb["y"])
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(255, 80, 30, 200))
            painter.drawEllipse(QRect(bx - 6, by - 6, 12, 12))
            painter.setBrush(QColor(255, 230, 120))
            painter.drawEllipse(QRect(bx - 3, by - 3, 6, 6))

        # 4. POW Pickups
        for p in self.pickups:
            px, py = int(p["x"]), int(p["y"])
            painter.setPen(QColor(255, 235, 80))
            painter.setBrush(QColor(225, 110, 20))
            painter.drawRoundedRect(QRect(px - 14, py - 12, 28, 24), 5, 5)
            painter.setPen(QColor(255, 255, 255))
            font_pow = QFont("Menlo", 9, QFont.Bold)
            painter.setFont(font_pow)
            painter.drawText(QRect(px - 14, py - 12, 28, 24), Qt.AlignCenter, "POW")

        # 5. Active Player Sprite from Cache
        plane_cache = self.cache[self.current_plane][self.current_style]
        p_idx = (self.prop_tick // 3) % 3

        if self.mode == "takeoff":
            if self.takeoff_tick < 95:
                p_level = (self.prop_tick // 3) % 4
                pix = plane_cache.get(f"level_{p_level}")
                status_text = "CARRIER CATAPULT: ACCELERATING DOWN DECK"
            elif self.takeoff_tick < 125:
                pix = plane_cache.get(f"climb_steep_{p_idx}")
                status_text = "AIRBORNE! NOSE PITCHES UP INTO CLIMB"
            elif self.takeoff_tick < 155:
                pix = plane_cache.get(f"climb_mild_{p_idx}")
                status_text = "LEVELING OUT AT CRUISE ALTITUDE"
            else:
                p_level = (self.prop_tick // 3) % 4
                pix = plane_cache.get(f"level_{p_level}")
                status_text = "CRUISE FORMATION"
        elif self.mode == "landing":
            if self.landing_tick < 95:
                pix = plane_cache.get(f"climb_mild_{p_idx}")
                status_text = "GLIDESLOPE DESCENT APPROACH"
            else:
                p_level = (self.prop_tick // 3) % 4
                pix = plane_cache.get(f"level_{p_level}")
                status_text = "TOUCHDOWN: ARRESTING GEAR ENGAGED"
        elif self.is_looping:
            stage_idx = min(len(self.loop_stages) - 1, self.loop_tick // 5)
            pix = plane_cache.get(f"loop_{stage_idx}_{p_idx}")
            status_text = f"360° LOOP-THE-LOOP (STAGE {stage_idx + 1}/8)"
        else:
            if abs(self.bank_angle) > 20:
                tag = "left" if self.bank_angle < 0 else "right"
                pix = plane_cache.get(f"bank_hard_{tag}_{p_idx}")
                status_text = f"HARD BANK {tag.upper()} (-28°)"
            elif abs(self.bank_angle) > 6:
                tag = "left" if self.bank_angle < 0 else "right"
                pix = plane_cache.get(f"bank_{tag}_{p_idx}")
                status_text = f"BANK {tag.upper()} (-14°)"
            else:
                p_level = (self.prop_tick // 3) % 4
                pix = plane_cache.get(f"level_{p_level}")
                status_text = "LEVEL FLIGHT (0°)"

        # Altitudes & Scales
        if self.mode == "takeoff":
            if self.takeoff_tick < 95:
                cur_scale = 0.82
                shadow_dist = 6
                shadow_scale = 0.82
                shadow_alpha = 0.55
                plane_y = self.y
            elif self.takeoff_tick < 165:
                prog = (self.takeoff_tick - 95) / 70.0
                cur_scale = 0.82 + (1.0 - 0.82) * prog
                shadow_dist = int(6 + 28 * prog)
                shadow_scale = 0.82 - (0.82 - 0.70) * prog
                shadow_alpha = 0.55 - (0.55 - 0.32) * prog
                plane_y = self.y
            else:
                cur_scale = 1.0
                shadow_dist = 34
                shadow_scale = 0.70
                shadow_alpha = 0.32
                plane_y = self.y
        elif self.mode == "landing":
            if self.landing_tick < 40:
                cur_scale = 1.0
                shadow_dist = 34
                shadow_scale = 0.70
                shadow_alpha = 0.32
                plane_y = self.y
            elif self.landing_tick < 95:
                prog = (self.landing_tick - 40) / 55.0
                cur_scale = 1.0 - (1.0 - 0.82) * prog
                shadow_dist = int(34 - (34 - 6) * prog)
                shadow_scale = 0.70 + (0.82 - 0.70) * prog
                shadow_alpha = 0.32 + (0.55 - 0.32) * prog
                plane_y = self.y
            else:
                cur_scale = 0.82
                shadow_dist = 6
                shadow_scale = 0.82
                shadow_alpha = 0.55
                plane_y = self.y
        elif self.is_looping:
            cur_stage = min(len(self.loop_stages) - 1, self.loop_tick // 5)
            stage_prog = (self.loop_tick % 5) / 5.0
            scale_curve = [1.0, 1.18, 1.38, 1.50, 1.40, 1.22, 1.08, 1.0]
            s0 = scale_curve[cur_stage]
            s1 = scale_curve[min(len(scale_curve) - 1, cur_stage + 1)]
            cur_scale = s0 + (s1 - s0) * stage_prog

            y_surge = [0, -12, -28, -44, -32, -14, -4, 0]
            y0 = y_surge[cur_stage]
            y1 = y_surge[min(len(y_surge) - 1, cur_stage + 1)]
            plane_y = self.y + int(y0 + (y1 - y0) * stage_prog)

            shadow_dist = int(34 + (cur_scale - 1.0) * 80)
            shadow_scale = max(0.45, 1.0 - (cur_scale - 1.0) * 0.75)
            shadow_alpha = max(0.12, 0.32 - (cur_scale - 1.0) * 0.25)
        else:
            cur_scale = 1.0
            plane_y = self.y
            shadow_dist = 34
            shadow_scale = 0.70
            shadow_alpha = 0.32

        base_size = 170
        display_w = int(base_size * cur_scale)
        display_h = int(base_size * cur_scale)

        # 6. Shadow
        shadow_w = int(base_size * shadow_scale)
        shadow_h = int(base_size * shadow_scale)
        painter.setOpacity(shadow_alpha)
        shadow_rect = QRect(
            int(self.x - shadow_w // 2 + 14), 
            int(self.y - shadow_h // 2 + shadow_dist), 
            shadow_w, 
            shadow_h
        )
        painter.drawPixmap(shadow_rect, pix)
        painter.setOpacity(1.0)

        # 7. UNDER-AIRCRAFT WEAPON FIRE (Guns & Missiles mounted underneath plane/wings)
        for b in self.bullets:
            bx, by, b_type = b["x"], b["y"], b.get("type", "twin")
            painter.setPen(Qt.NoPen)
            
            if b_type == "shotgun":
                painter.setBrush(QColor(80, 230, 255, 190))
                painter.drawEllipse(QRect(int(bx - 6), int(by - 6), 12, 12))
                painter.setBrush(QColor(255, 255, 255))
                painter.drawEllipse(QRect(int(bx - 3), int(by - 3), 6, 6))

            elif b_type == "quad":
                painter.setBrush(QColor(255, 120, 20, 180))
                painter.drawRoundedRect(QRect(int(bx - 3), int(by - 16), 6, 20), 3, 3)
                painter.setBrush(QColor(255, 240, 120))
                painter.drawRoundedRect(QRect(int(bx - 1.5), int(by - 14), 3, 16), 1.5, 1.5)

            elif b_type == "threeway":
                painter.setBrush(QColor(255, 140, 40, 210))
                painter.drawRoundedRect(QRect(int(bx - 2.5), int(by - 14), 5, 18), 2.5, 2.5)
                painter.setBrush(QColor(255, 255, 220))
                painter.drawRoundedRect(QRect(int(bx - 1.2), int(by - 12), 2.4, 14), 1.2, 1.2)

            else:
                painter.setBrush(QColor(255, 180, 30, 200))
                painter.drawRoundedRect(QRect(int(bx - 2), int(by - 12), 4, 16), 2, 2)
                painter.setBrush(QColor(255, 255, 240))
                painter.drawRoundedRect(QRect(int(bx - 1), int(by - 10), 2, 12), 1, 1)

        # Underwing Homing Missiles
        for m in self.missiles:
            mx, my = int(m["x"]), int(m["y"])
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(255, 120, 20))
            painter.drawEllipse(mx - 3, my + 6, 6, 8)
            painter.setBrush(QColor(230, 235, 240))
            painter.drawRoundedRect(QRect(mx - 3, my - 8, 6, 16), 2, 2)
            painter.setBrush(QColor(220, 35, 35))
            painter.drawPolygon(QPolygon([QPoint(mx - 3, my - 8), QPoint(mx + 3, my - 8), QPoint(mx, my - 13)]))

        # Under-nose & Under-wing Muzzle Flashes
        for f in self.muzzle_flashes:
            fx, fy = int(f["x"]), int(f["y"])
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(255, 220, 40, 240))
            painter.drawEllipse(QRect(fx - 5, fy - 5, 10, 10))
            painter.setBrush(QColor(255, 255, 255, 255))
            painter.drawEllipse(QRect(fx - 2, fy - 2, 4, 4))

        # 8. Escort Mini-Fighters
        if self.weapons[self.weapon_idx] == "escorts" and self.mode == "flying" and not self.is_looping:
            escort_size = 96
            painter.setOpacity(0.28)
            painter.drawPixmap(QRect(int(self.x - 56 - escort_size//2 + 10), int(plane_y + 14 - escort_size//2 + 18), escort_size, escort_size), pix)
            painter.drawPixmap(QRect(int(self.x + 56 - escort_size//2 + 10), int(plane_y + 14 - escort_size//2 + 18), escort_size, escort_size), pix)
            painter.setOpacity(1.0)
            painter.drawPixmap(QRect(int(self.x - 56 - escort_size//2), int(plane_y + 14 - escort_size//2), escort_size, escort_size), pix)
            painter.drawPixmap(QRect(int(self.x + 56 - escort_size//2), int(plane_y + 14 - escort_size//2), escort_size, escort_size), pix)

        # 9. Engine Damage Trails (Smoke Puffs & Firebillows)
        for sm in self.smoke_particles:
            sx, sy, r, s_type = int(sm["x"]), int(sm["y"]), int(sm["rad"]), sm["type"]
            painter.setPen(Qt.NoPen)
            if s_type == "vapor":
                painter.setBrush(QColor(220, 230, 245, 120))
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
            elif s_type == "black_smoke":
                painter.setBrush(QColor(30, 32, 38, 160))
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
                painter.setBrush(QColor(50, 52, 60, 110))
                painter.drawEllipse(QRect(sx - r//2, sy - r//2, r, r))
            elif s_type == "fire":
                painter.setBrush(QColor(255, 100, 20, 180))
                painter.drawEllipse(QRect(sx - r, sy - r, r * 2, r * 2))
                painter.setBrush(QColor(255, 230, 70, 230))
                painter.drawEllipse(QRect(sx - r//2, sy - r//2, r, r))

        # 10. Main Aircraft (Rendered ON TOP of under-nose guns and pylons)
        jitter_x = random.choice([-1, 0, 1]) if self.hp == 1 else 0
        jitter_y = random.choice([-1, 0, 1]) if self.hp == 1 else 0

        if self.invulnerable_ticks > 0 and self.hit_flash_ticks == 0:
            if (self.invulnerable_ticks // 3) % 2 == 0:
                painter.setOpacity(0.35)

        painter.save()
        if self.death_ticks > 0:
            painter.translate(self.x, plane_y)
            painter.rotate(self.death_ticks * 16.0)
            death_scale = max(0.40, 1.0 - self.death_ticks * 0.007)
            painter.scale(death_scale, death_scale)
            dest_rect = QRect(-display_w // 2, -display_h // 2, display_w, display_h)
        else:
            dest_rect = QRect(
                int(self.x + jitter_x - display_w // 2), 
                int(plane_y + jitter_y - display_h // 2), 
                display_w, 
                display_h
            )

        painter.drawPixmap(dest_rect, pix)

        if self.hit_flash_ticks > 0:
            painter.setCompositionMode(QPainter.CompositionMode_SourceAtop)
            flash_color = QColor(255, 255, 255, 240) if self.hit_flash_ticks % 2 == 0 else QColor(255, 50, 50, 220)
            painter.fillRect(dest_rect, flash_color)
            painter.setCompositionMode(QPainter.CompositionMode_SourceOver)

        painter.restore()
        painter.setOpacity(1.0)

        # 11. Sparks & Explosions
        for sp in self.spark_particles:
            painter.setPen(Qt.NoPen)
            painter.setBrush(sp.get("color", QColor(255, 255, 255)))
            painter.drawEllipse(int(sp["x"] - 2), int(sp["y"] - 2), 4, 4)

        for exp in self.explosions:
            ex, ey, r = int(exp["x"]), int(exp["y"]), int(exp["radius"])
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(255, 120, 30, 160))
            painter.drawEllipse(QRect(ex - r, ey - r, r * 2, r * 2))
            painter.setBrush(QColor(255, 240, 100, 220))
            painter.drawEllipse(QRect(ex - r//2, ey - r//2, r, r))

        # 12. 1943 Mega Crash Screen FX
        if self.mega_crash_ticks > 0:
            prog = (28 - self.mega_crash_ticks) / 28.0
            for ring_i in [0, 1, 2]:
                r = int((prog * 520) - ring_i * 60)
                if r > 10:
                    alpha = max(0, int(220 * (1.0 - prog)))
                    painter.setPen(QColor(140, 220, 255, alpha))
                    painter.setBrush(Qt.NoBrush)
                    painter.drawEllipse(QRect(self.width()//2 - r, self.height()//2 - r, r * 2, r * 2))
            flash_alpha = max(0, int(150 * (1.0 - prog * 1.5)))
            if flash_alpha > 0:
                painter.fillRect(self.rect(), QColor(220, 245, 255, flash_alpha))

        # 13. HUD Overlay & 1943 Energy Meter
        painter.fillRect(QRect(12, 12, self.width() - 24, 110), QColor(10, 18, 30, 225))
        painter.setPen(QColor(50, 120, 180))
        painter.drawRect(QRect(12, 12, self.width() - 24, 110))

        font_bold = QFont("Menlo", 12, QFont.Bold)
        font_sm = QFont("Menlo", 10)

        painter.setFont(font_bold)
        # Faction Title & Plane
        p_col = QColor(245, 210, 40) if is_zero else QColor(100, 200, 255)
        painter.setPen(p_col)
        painter.drawText(24, 30, f"{self.plane_titles[self.current_plane]}  [TAB to Switch]")

        painter.setFont(font_sm)
        # 1943 Armor/Health Meter
        pips = "■ " * self.hp + "□ " * (self.max_hp - self.hp)
        if self.hp == 4:
            armor_col = QColor(100, 240, 120)
            cond_str = "100% (PRISTINE)"
        elif self.hp == 3:
            armor_col = QColor(230, 220, 50)
            cond_str = "75% (LIGHT VAPOR)"
        elif self.hp == 2:
            armor_col = QColor(255, 140, 30)
            cond_str = "50% (ENGINE SMOKE)"
        elif self.hp == 1:
            blink = (self.prop_tick // 4) % 2 == 0
            armor_col = QColor(255, 50, 50) if blink else QColor(255, 180, 50)
            cond_str = "25% (CRITICAL ENGINE FIRE!)"
        else:
            armor_col = QColor(255, 40, 40)
            cond_str = "0% (DESTROYED)"

        painter.setPen(armor_col)
        painter.drawText(24, 48, f"ARMOR GAUGE: [ {pips.strip()} ] {cond_str}")

        painter.setPen(QColor(180, 220, 255))
        painter.drawText(24, 66, f"FLIGHT STATE: {status_text}")

        # Active Weapon Display
        weapon_key = self.weapons[self.weapon_idx]
        weapon_name = self.weapon_names[self.current_plane][weapon_key]
        painter.setPen(QColor(255, 180, 40))
        painter.drawText(24, 84, f"ARMAMENT: [ {weapon_name} ]  (PRESS 'P' TO CYCLE)")

        painter.setPen(QColor(140, 170, 200))
        painter.drawText(24, 102, "FIRE: [Z/Click]  •  BOMB: [B]  •  LOOP: [Space]  •  TEST HIT: [H]  •  REPAIR: [R]/[L]")

        # Top Notification Banner
        if self.banner_timer > 0:
            painter.fillRect(QRect(30, 130, self.width() - 60, 26), QColor(25, 35, 50, 230))
            painter.setPen(QColor(255, 225, 70))
            painter.setFont(font_sm)
            painter.drawText(QRect(30, 130, self.width() - 60, 26), Qt.AlignCenter, self.banner_text)

        # Footer controls
        painter.fillRect(QRect(12, self.height() - 40, self.width() - 24, 28), QColor(10, 18, 30, 220))
        painter.setPen(QColor(50, 120, 180))
        painter.drawRect(QRect(12, self.height() - 40, self.width() - 24, 28))
        painter.setFont(font_sm)
        painter.setPen(QColor(200, 225, 250))
        painter.drawText(24, self.height() - 22, "[TAB] Switch Plane  •  [Arrows/WASD] Fly  •  [Z/Click] Fire  •  [P] Weapon  •  [B] Bomb  •  [Space] Loop")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = Flight3DPreviewWindow()
    window.show()
    sys.exit(app.exec())
