#!/usr/bin/env python3
"""
Sky Ace • Interactive P-38 Flight Preview Tool
Allows immediate live flight testing of the high-res artisan P-38 Lightning sprite in a native PySide6 window.
Controls:
- Left / Right Arrow (or A / D, H / L): Bank fighter
- Space / Enter: Trigger full 360° Loop-the-Loop maneuver
- Esc: Quit
"""

import sys
import json
from pathlib import Path
from PySide6.QtWidgets import QApplication, QWidget
from PySide6.QtGui import QPainter, QPixmap, QColor, QFont
from PySide6.QtCore import QTimer, Qt, QRect

SPRITES_DIR = Path(__file__).resolve().parent.parent / "games" / "skyace" / "sprites"

class P38PreviewWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Sky Ace • High-Res P-38 Lightning Flight Test")
        self.resize(540, 680)
        self.setFocusPolicy(Qt.StrongFocus)

        sheet_img = SPRITES_DIR / "sheet_player_p38.png"
        meta_file = SPRITES_DIR / "sheet_player_p38.json"

        self.pixmap = QPixmap(str(sheet_img))
        self.meta = json.loads(meta_file.read_text(encoding="utf-8"))

        self.x = 270
        self.y = 500
        self.bank_state = "fly_0"
        self.prop_tick = 0
        self.ocean_y = 0

        self.is_looping = False
        self.loop_tick = 0
        self.loop_sequence = [
            "pitch_up",
            "knife_edge",
            "dive_apex",
            "dive_inverted",
            "dive_pullout",
            "level_recover"
        ]

        self.keys = set()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_flight)
        self.timer.start(16)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close()
        elif event.key() in (Qt.Key_Space, Qt.Key_Return, Qt.Key_B):
            if not self.is_looping:
                self.is_looping = True
                self.loop_tick = 0
        else:
            self.keys.add(event.key())

    def keyReleaseEvent(self, event):
        self.keys.discard(event.key())

    def update_flight(self):
        self.prop_tick += 1
        self.ocean_y = (self.ocean_y + 4) % 48

        moving_left = any(k in self.keys for k in [Qt.Key_Left, Qt.Key_A, Qt.Key_H])
        moving_right = any(k in self.keys for k in [Qt.Key_Right, Qt.Key_D, Qt.Key_L])
        moving_up = any(k in self.keys for k in [Qt.Key_Up, Qt.Key_W, Qt.Key_K])
        moving_down = any(k in self.keys for k in [Qt.Key_Down, Qt.Key_S, Qt.Key_J])

        if not self.is_looping:
            if moving_left:
                self.x = max(80, self.x - 6)
                self.bank_state = "bank_left_2"
            elif moving_right:
                self.x = min(self.width() - 80, self.x + 6)
                self.bank_state = "bank_right_2"
            else:
                # Frames 1, 2, 3 are pure idle with spinning props (fly_0, fly_1, fly_2)
                idle_idx = (self.prop_tick // 4) % 3
                self.bank_state = f"fly_{idle_idx}"

            if moving_up:
                self.y = max(120, self.y - 5)
            if moving_down:
                self.y = min(self.height() - 100, self.y + 5)
        else:
            stage_idx = (self.loop_tick // 6)
            if stage_idx < len(self.loop_sequence):
                self.bank_state = self.loop_sequence[stage_idx]
                self.loop_tick += 1
                if stage_idx in [0, 1]:
                    self.y -= 3
                elif stage_idx in [4, 5]:
                    self.y += 3
            else:
                self.is_looping = False
                self.loop_tick = 0
                self.bank_state = "fly_0"

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)

        # Pacific ocean
        painter.fillRect(self.rect(), QColor(22, 64, 118))

        painter.setPen(QColor(38, 98, 160))
        for wy in range(-48, self.height() + 48, 30):
            y_pos = wy + self.ocean_y
            for wx in range(0, self.width(), 36):
                painter.drawArc(wx - 10, y_pos, 20, 10, 0, 180 * 16)

        # Tropical island
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor(42, 160, 170))
        painter.drawEllipse(self.width() - 140, 160, 160, 160)
        painter.setBrush(QColor(230, 210, 150))
        painter.drawEllipse(self.width() - 120, 180, 120, 120)
        painter.setBrush(QColor(36, 120, 48))
        painter.drawEllipse(self.width() - 105, 195, 90, 90)

        # Sprite coordinates
        f_meta = self.meta["frames"].get(self.bank_state, self.meta["frames"]["fly_0"])
        f = f_meta["frame"]
        src_rect = QRect(f["x"], f["y"], f["w"], f["h"])

        display_size = 160

        # Ground shadow
        if self.bank_state not in ["knife_edge", "pitch_up"]:
            painter.setOpacity(0.3)
            shadow_dest = QRect(int(self.x - display_size//2 + 14), int(self.y - display_size//2 + 40), display_size, display_size)
            painter.drawPixmap(shadow_dest, self.pixmap, src_rect)
            painter.setOpacity(1.0)

        # Fighter
        dest_rect = QRect(int(self.x - display_size//2), int(self.y - display_size//2), display_size, display_size)
        painter.drawPixmap(dest_rect, self.pixmap, src_rect)

        # Header HUD
        painter.fillRect(0, 0, self.width(), 40, QColor(12, 18, 26, 220))
        painter.setPen(QColor(0, 240, 255))
        painter.setFont(QFont("Monospace", 11, QFont.Bold))
        status = "360° LOOP-THE-LOOP" if self.is_looping else "FLIGHT READY"
        painter.drawText(20, 25, f"P-38 SUPER ACE  |  {status}  |  FRAME: {self.bank_state}")

        painter.setPen(QColor(160, 185, 210))
        painter.setFont(QFont("Monospace", 9))
        painter.drawText(20, self.height() - 16, "Arrows / WASD / HJKL to Bank & Steer  •  Space / Enter to Loop  •  Esc to Exit")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    win = P38PreviewWindow()
    win.show()
    sys.exit(app.exec())
