"""
Omarchy Arcade • ByteCity Top-Down 2D Viewport
High-performance QQuickPaintedItem rendering the 120x100 Micropolis tilemap.
Clean orthographic projection with pan, zoom, drag-to-build, and theme awareness.
"""

import os
import sys
import math
from PySide6.QtCore import Qt, QPointF, QRectF, Signal, Property, Slot, QObject, QTimer
from PySide6.QtGui import (
    QColor, QFont, QPainter, QPainterPath, QPen, QBrush, QCursor, QRadialGradient, QLinearGradient, QPolygonF, QImage
)

from PySide6.QtQuick import QQuickPaintedItem

# Tool footprints: size (width=height) in tiles
TOOL_FOOTPRINTS = {
    -1: 1,  # Pan / Hand
    0: 3,   # Residential ($100)
    1: 3,   # Commercial ($100)
    2: 3,   # Industrial ($100)
    3: 3,   # Fire Station ($500)
    4: 3,   # Police Station ($500)
    5: 1,   # Query ($0)
    6: 1,   # Power Wire ($5)
    7: 1,   # Bulldozer ($1)
    8: 1,   # Railroad ($20)
    9: 1,   # Road ($10)
    10: 4,  # Stadium ($5000)
    11: 1,  # Park ($10)
    12: 4,  # Seaport ($3000)
    13: 4,  # Coal Power ($3000)
    14: 4,  # Nuclear Power ($5000)
    15: 6,  # Airport ($10000)
}

# Linear tools that support continuous drag-to-build
DRAGGABLE_TOOLS = {6, 7, 8, 9, 11}

# Studio Ghibli Watercolor Nature Palette
COLOR_MEADOW_BASE   = QColor("#a4cb74")
COLOR_MEADOW_LIGHT  = QColor("#bde082")
COLOR_MEADOW_WARM   = QColor("#dfcb96")
COLOR_MEADOW_SHADOW = QColor("#8ab35b")

COLOR_SAND_BANK     = QColor("#decca0")
COLOR_SAND_DARK     = QColor("#ab956b")
COLOR_CLIFF_EDGE    = QColor("#4a3b2c")

COLOR_WATER_DEEP    = QColor("#1e568c")
COLOR_WATER_MID     = QColor("#2a79af")
COLOR_WATER_SHALLOW = QColor("#4ec0d9")
COLOR_WATER_FOAM    = QColor(255, 255, 255, 215)
COLOR_WAVE_CREST    = QColor(255, 255, 255, 175)

COLOR_PINE_DEEP     = QColor("#1b4324")
COLOR_PINE_MID      = QColor("#2d6a36")
COLOR_PINE_LIGHT    = QColor("#489643")
COLOR_PINE_TIP      = QColor("#70ba54")

COLOR_DECID_DEEP    = QColor("#1d4a25")
COLOR_DECID_MID     = QColor("#367533")
COLOR_DECID_LIGHT   = QColor("#5ca545")
COLOR_DECID_CROWN   = QColor("#8ecf5a")

COLOR_TRUNK         = QColor("#4a3320")
COLOR_SOOT_SPRITE   = QColor("#111111")

# Aliases for backwards compatibility with infrastructure
COLOR_WATER = COLOR_WATER_DEEP
COLOR_DIRT = COLOR_MEADOW_BASE
COLOR_DIRT_DARK = COLOR_MEADOW_SHADOW
COLOR_TREES = COLOR_DECID_MID
COLOR_TREES_DARK = COLOR_DECID_DEEP
COLOR_RUBBLE = QColor("#404040")
COLOR_FIRE = QColor("#e63946")

# Roads & Bridges
COLOR_ROAD = QColor("#2b2f3a")
COLOR_ROAD_CURB = QColor("#1b1e26")
COLOR_ROAD_LANE = QColor("#f4a261")
COLOR_ROAD_STOP = QColor("#ffffff")
COLOR_BRIDGE_CONCRETE = QColor("#546e7a")
COLOR_BRIDGE_BARRIER = QColor("#cfd8dc")

# Railroads & Crossings
COLOR_RAIL_BALLAST = QColor("#3e3733")
COLOR_RAIL_TIE = QColor("#5d4037")
COLOR_RAIL_STEEL = QColor("#cfd8dc")
COLOR_RAIL_STEEL_DARK = QColor("#37474f")
COLOR_RAIL_CROSS_WOOD = QColor("#795548")

# Powerlines
COLOR_WIRE_POLE = QColor("#8d6e63")
COLOR_WIRE_ARM = QColor("#5d4037")
COLOR_WIRE_INSULATOR = QColor("#e0e1dd")
COLOR_WIRE_CABLE = QColor("#1a1a1a")
COLOR_WIRE_PYLON = QColor("#78909c")

# Traffic & Vehicles
CAR_PALETTE = [
    QColor("#e63946"), QColor("#ffb703"), QColor("#219ebc"),
    QColor("#f8f9fa"), QColor("#8338ec"), QColor("#fb8500")
]

# Trolley / Streetcar
COLOR_TROLLEY_BODY = QColor("#c1121f")
COLOR_TROLLEY_CREAM = QColor("#fefae0")
COLOR_TROLLEY_WINDOW = QColor("#1d3557")
COLOR_TROLLEY_LIGHT = QColor("#ffea00")

# Zones & Buildings
COLOR_RES_BASE = QColor("#2a9d8f")
COLOR_COM_BASE = QColor("#219ebc")
COLOR_IND_BASE = QColor("#d48b28")
COLOR_FIRE_DEPT = QColor("#c1121f")
COLOR_POLICE_DEPT = QColor("#0077b6")
COLOR_COAL = QColor("#343a40")
COLOR_NUCLEAR = QColor("#e0e1dd")
COLOR_STADIUM = QColor("#38b000")
COLOR_PORT = QColor("#0096c7")
COLOR_AIRPORT = QColor("#495057")
COLOR_PARK = QColor("#52b788")


class CityViewport(QQuickPaintedItem):
    hoverChanged = Signal(int, int)
    toolApplied = Signal(int, int, int, int)
    cameraChanged = Signal()
    activeToolChanged = Signal(int)
    cityEngineChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptedMouseButtons(Qt.LeftButton | Qt.RightButton | Qt.MiddleButton)
        self.setAcceptHoverEvents(True)
        self.setAntialiasing(False)  # Crisp pixel-art tiles
        self.setFlag(QQuickPaintedItem.ItemHasContents, True)

        # Engine reference
        self._engine = None

        # Camera state (tile coordinates at screen center)
        self._cam_x = 60.0
        self._cam_y = 50.0
        self._tile_size = 24.0  # Pixels per tile (zoom)

        # Active tool (-1 = Hand/Pan, 0..15 = tools)
        self._active_tool = 9  # Default to Road

        # Mouse interaction state
        self._is_panning = False
        self._is_drawing = False
        self._last_mouse_pos = QPointF(0, 0)
        self._hover_x = -1
        self._hover_y = -1
        self._last_placed_tile = (-1, -1)

        # Theme styling tokens
        self._theme_board_bg = QColor("#11111b")
        self._theme_accent = QColor("#89b4fa")
        self._theme_fg = QColor("#cdd6f4")

        # Animation loop for traffic and trolley (25 FPS)
        self._anim_tick = 0
        self._anim_timer = QTimer(self)
        self._anim_timer.setInterval(40)
        self._anim_timer.timeout.connect(self._on_anim_timer)
        self._anim_timer.start()

        # Commuter Trolley state
        self._trolley = {
            'active': False,
            'x': -1.0,
            'y': -1.0,
            'dir': (1.0, 0.0),
            'speed': 2.4,
        }

        # Building Sprites
        self._res_sprites_3x3 = {}
        self._house_sprites = []
        self._ind_sprites_3x3 = {}
        self._com_sprites_3x3 = {}
        self._load_building_sprites()

    def _load_building_sprites(self):
        base_dir = os.path.join(os.path.dirname(__file__), "assets", "buildings")
        # Load 3x3 residential & civic sprites (5 rows x 4 cols)
        for r in range(5):
            for c in range(4):
                p = os.path.join(base_dir, f"res_r{r}_c{c}.png")
                if os.path.exists(p):
                    self._res_sprites_3x3[(r, c)] = QImage(p)
        # Load 1x1 house sprites
        for idx in range(5):
            hp = os.path.join(base_dir, f"house_{idx}.png")
            if os.path.exists(hp):
                self._house_sprites.append(QImage(hp))
        # Load 3x3 industrial sprites (2 rows x 4 cols)
        for r in range(2):
            for c in range(4):
                p = os.path.join(base_dir, f"ind_r{r}_c{c}.png")
                if os.path.exists(p):
                    self._ind_sprites_3x3[(r, c)] = QImage(p)
        # Load 3x3 commercial sprites (4 rows x 5 cols)
        for r in range(4):
            for c in range(5):
                p = os.path.join(base_dir, f"com_r{r}_c{c}.png")
                if os.path.exists(p):
                    self._com_sprites_3x3[(r, c)] = QImage(p)

        # Load municipal special building sprites
        self._spec_sprites = {}
        for k in ["fire", "police", "coal", "nuke", "port", "stadium", "airport"]:
            p = os.path.join(base_dir, f"spec_{k}.png")
            if os.path.exists(p):
                self._spec_sprites[k] = QImage(p)

        # Load civic & park building sprites
        self._civic_sprites = {}
        for k in ["mayor", "temple", "shrine", "cathedral", "pavilion"]:
            p = os.path.join(base_dir, f"civic_{k}.png")
            if os.path.exists(p):
                self._civic_sprites[k] = QImage(p)

        self._park_sprites = []
        for i in range(4):
            p = os.path.join(base_dir, f"park_{i}.png")
            if os.path.exists(p):
                self._park_sprites.append(QImage(p))



    # --- Properties ---


    def get_city_engine(self):
        return self._engine

    def set_city_engine(self, engine):
        if self._engine != engine:
            if self._engine is not None:
                try:
                    self._engine.mapChanged.disconnect(self.update)
                except (RuntimeError, TypeError):
                    pass
            self._engine = engine
            if self._engine is not None:
                self._engine.mapChanged.connect(self.update)
            self.cityEngineChanged.emit()
            self.update()

    cityEngine = Property(QObject, get_city_engine, set_city_engine, notify=cityEngineChanged)

    def get_active_tool(self):
        return self._active_tool

    def set_active_tool(self, tool_id):
        if self._active_tool != tool_id:
            self._active_tool = tool_id
            self.activeToolChanged.emit(tool_id)
            self.update()

    activeTool = Property(int, get_active_tool, set_active_tool, notify=activeToolChanged)

    def get_tile_size(self):
        return self._tile_size

    def set_tile_size(self, size):
        new_size = max(8.0, min(64.0, float(size)))
        if self._tile_size != new_size:
            self._tile_size = new_size
            self.cameraChanged.emit()
            self.update()

    tileSize = Property(float, get_tile_size, set_tile_size, notify=cameraChanged)

    def get_hover_x(self):
        return self._hover_x

    hoverX = Property(int, get_hover_x, notify=hoverChanged)

    def get_hover_y(self):
        return self._hover_y

    hoverY = Property(int, get_hover_y, notify=hoverChanged)

    def get_cam_x(self):
        return self._cam_x

    def set_cam_x(self, x):
        clamped = max(0.0, min(120.0, float(x)))
        if self._cam_x != clamped:
            self._cam_x = clamped
            self.cameraChanged.emit()
            self.update()

    camX = Property(float, get_cam_x, set_cam_x, notify=cameraChanged)

    def get_cam_y(self):
        return self._cam_y

    def set_cam_y(self, y):
        clamped = max(0.0, min(100.0, float(y)))
        if self._cam_y != clamped:
            self._cam_y = clamped
            self.cameraChanged.emit()
            self.update()

    camY = Property(float, get_cam_y, set_cam_y, notify=cameraChanged)

    # --- Public Slots for QML ---

    @Slot(float, float)
    def panBy(self, dx, dy):
        """Pans the camera by delta screen pixels."""
        self._cam_x = max(0.0, min(120.0, self._cam_x - dx / self._tile_size))
        self._cam_y = max(0.0, min(100.0, self._cam_y - dy / self._tile_size))
        self.cameraChanged.emit()
        self.update()

    @Slot()
    def zoomIn(self):
        self.set_tile_size(self._tile_size * 1.25)

    @Slot()
    def zoomOut(self):
        self.set_tile_size(self._tile_size / 1.25)

    @Slot(int, int)
    def centerOn(self, tx, ty):
        self._cam_x = max(0.0, min(120.0, float(tx)))
        self._cam_y = max(0.0, min(100.0, float(ty)))
        self.cameraChanged.emit()
        self.update()

    @Slot()
    def resetView(self):
        self._cam_x = 60.0
        self._cam_y = 50.0
        self._tile_size = 24.0
        self.cameraChanged.emit()
        self.update()

    # --- Coordinate Transformations ---

    def screen_to_tile(self, sx, sy):
        """Converts screen pixel position to tile grid (tx, ty)."""
        w, h = self.width(), self.height()
        tx = int(math.floor((sx - w / 2.0) / self._tile_size + self._cam_x))
        ty = int(math.floor((sy - h / 2.0) / self._tile_size + self._cam_y))
        return tx, ty

    def tile_to_screen(self, tx, ty):
        """Converts tile coordinates to screen pixel top-left corner."""
        w, h = self.width(), self.height()
        sx = (tx - self._cam_x) * self._tile_size + w / 2.0
        sy = (ty - self._cam_y) * self._tile_size + h / 2.0
        return sx, sy

    # --- Mouse Event Handlers ---

    def hoverMoveEvent(self, event):
        pos = event.position()
        tx, ty = self.screen_to_tile(pos.x(), pos.y())
        if 0 <= tx < 120 and 0 <= ty < 100:
            if tx != self._hover_x or ty != self._hover_y:
                self._hover_x = tx
                self._hover_y = ty
                self.hoverChanged.emit(tx, ty)
                self.update()
        else:
            if self._hover_x != -1 or self._hover_y != -1:
                self._hover_x = -1
                self._hover_y = -1
                self.update()
        super().hoverMoveEvent(event)

    def mousePressEvent(self, event):
        pos = event.position()
        self._last_mouse_pos = pos

        # Right click or Middle click: pan
        if event.button() in (Qt.RightButton, Qt.MiddleButton):
            self._is_panning = True
            self.setCursor(QCursor(Qt.ClosedHandCursor))
            event.accept()
            return

        # Left click
        if event.button() == Qt.LeftButton:
            if self._active_tool == -1:
                # Hand tool: pan
                self._is_panning = True
                self.setCursor(QCursor(Qt.ClosedHandCursor))
                event.accept()
                return

            # Building / Action Tool
            tx, ty = self.screen_to_tile(pos.x(), pos.y())
            if 0 <= tx < 120 and 0 <= ty < 100 and self._engine:
                self._is_drawing = True
                self._last_placed_tile = (tx, ty)
                res = self._engine.apply_tool(self._active_tool, tx, ty)
                self.toolApplied.emit(self._active_tool, tx, ty, res)
                self.update()
                event.accept()
                return

        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        pos = event.position()
        dx = pos.x() - self._last_mouse_pos.x()
        dy = pos.y() - self._last_mouse_pos.y()
        self._last_mouse_pos = pos

        if self._is_panning:
            self._cam_x = max(0.0, min(120.0, self._cam_x - dx / self._tile_size))
            self._cam_y = max(0.0, min(100.0, self._cam_y - dy / self._tile_size))
            self.cameraChanged.emit()
            self.update()
            event.accept()
            return

        if self._is_drawing and self._engine and self._active_tool in DRAGGABLE_TOOLS:
            tx, ty = self.screen_to_tile(pos.x(), pos.y())
            if 0 <= tx < 120 and 0 <= ty < 100:
                if (tx, ty) != self._last_placed_tile:
                    self._last_placed_tile = (tx, ty)
                    self._hover_x = tx
                    self._hover_y = ty
                    res = self._engine.apply_tool(self._active_tool, tx, ty)
                    self.toolApplied.emit(self._active_tool, tx, ty, res)
                    self.update()
            event.accept()
            return

        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._is_panning:
            self._is_panning = False
            self.setCursor(QCursor(Qt.ArrowCursor))
        if self._is_drawing:
            self._is_drawing = False
            self._last_placed_tile = (-1, -1)
        super().mouseReleaseEvent(event)

    def wheelEvent(self, event):
        if event.modifiers() & Qt.ShiftModifier:
            # Shift held: move the world / pan camera like grab tool or arrow keys
            p_delta = event.pixelDelta()
            if not p_delta.isNull() and (p_delta.x() != 0 or p_delta.y() != 0):
                dx = float(p_delta.x())
                dy = float(p_delta.y())
            else:
                a_delta = event.angleDelta()
                dx = float(a_delta.x()) / 2.0
                dy = float(a_delta.y()) / 2.0

            if dx != 0 or dy != 0:
                self.panBy(dx, dy)
            event.accept()
            return

        delta = event.angleDelta().y()
        if delta > 0:
            self.zoomIn()
        elif delta < 0:
            self.zoomOut()
        event.accept()

    # --- Painting Engine ---

    def _on_anim_timer(self):
        self._anim_tick = (self._anim_tick + 1) % 1000000
        self._update_trolley(0.04)
        self.update()

    def paint(self, painter: QPainter):
        w = self.width()
        h = self.height()
        if w <= 0 or h <= 0:
            return

        # Background
        painter.fillRect(0, 0, int(w), int(h), self._theme_board_bg)

        if not self._engine:
            return

        ts = self._tile_size

        # Visible tile bounds (padded by 2 tiles so multi-tile buildings render seamlessly)
        left_t = self._cam_x - (w / (2.0 * ts))
        top_t = self._cam_y - (h / (2.0 * ts))

        min_tx = max(0, int(math.floor(left_t)) - 2)
        max_tx = min(120, int(math.ceil(left_t + w / ts)) + 3)
        min_ty = max(0, int(math.floor(top_t)) - 2)
        max_ty = min(100, int(math.ceil(top_t + h / ts)) + 3)


        # Batch draw tiles
        painter.save()
        font_small = QFont("Helvetica" if sys.platform == "darwin" else "sans-serif", max(6, int(ts * 0.38)), QFont.Bold)
        painter.setFont(font_small)

        for tx in range(min_tx, max_tx):
            sx = (tx - self._cam_x) * ts + w / 2.0
            for ty in range(min_ty, max_ty):
                sy = (ty - self._cam_y) * ts + h / 2.0
                raw = self._engine.fast_get_tile(tx, ty)
                has_power = self._engine.fast_has_power(tx, ty)
                self._draw_tile(painter, raw, has_power, sx, sy, ts, tx, ty)

        # Draw Commuter Trolley on top of rail network
        self._draw_trolley(painter, ts, w, h)

        # Hovered Tool Footprint Overlay
        if 0 <= self._hover_x < 120 and 0 <= self._hover_y < 100 and self._active_tool >= 0:
            footprint = TOOL_FOOTPRINTS.get(self._active_tool, 1)
            hx, hy = self.tile_to_screen(self._hover_x, self._hover_y)
            fp_w = footprint * ts
            fp_h = footprint * ts

            # Outline and fill
            painter.setPen(QPen(QColor(137, 180, 250, 220), 2))
            painter.setBrush(QBrush(QColor(137, 180, 250, 60)))
            painter.drawRect(QRectF(hx, hy, fp_w, fp_h))

            # Dimension label if multi-tile
            if footprint > 1:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(QRectF(hx, hy, fp_w, fp_h), Qt.AlignCenter, f"{footprint}x{footprint}")

        painter.restore()

    def _draw_tile(self, painter: QPainter, raw: int, has_power: bool, sx: float, sy: float, ts: float, tx: int, ty: int):
        t = raw & 0x03FF  # Low mask for tile type
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 1. MEADOW / LAND (0, 1)
        if t <= 1:
            self._draw_ghibli_land(painter, sx, sy, ts, tx, ty)
            return

        # 2. WATER & COASTLINE (2..20)
        if 2 <= t <= 20:
            self._draw_ghibli_water(painter, sx, sy, ts, tx, ty)
            return

        # 3. LUSH WOODS & FORESTS (21..43)
        if 21 <= t <= 43:
            self._draw_ghibli_forest(painter, sx, sy, ts, tx, ty)
            return

        # 4. RUBBLE (44..47)
        if 44 <= t <= 47:
            painter.fillRect(rect, COLOR_RUBBLE)
            if ts >= 12:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.2, ts * 0.3, ts * 0.3), QColor("#666666"))
            return

        # 5. FIRE (56..63)
        if 56 <= t <= 63:
            painter.fillRect(rect, COLOR_FIRE)
            painter.fillRect(QRectF(sx + ts * 0.25, sy + ts * 0.25, ts * 0.5, ts * 0.5), QColor("#ffba08"))
            return

        # 6. ROADS, BRIDGES, AND TRAFFIC (64..207)
        if 64 <= t <= 207:
            if 64 <= t <= 79:
                self._draw_road(painter, t, sx, sy, ts, tx, ty)
            elif 80 <= t <= 95:
                # Light Traffic
                base_t = t - 16
                self._draw_road(painter, base_t, sx, sy, ts, tx, ty)
                self._draw_traffic(painter, base_t, 1, sx, sy, ts, tx, ty)
            elif 144 <= t <= 159:
                # Heavy Traffic
                base_t = t - 80
                self._draw_road(painter, base_t, sx, sy, ts, tx, ty)
                self._draw_traffic(painter, base_t, 2, sx, sy, ts, tx, ty)
            else:
                self._draw_road(painter, 66, sx, sy, ts, tx, ty)
            return

        # 7. POWER LINES & OVERHEAD CROSSINGS (208..223)
        if 208 <= t <= 223:
            if t == 221:  # RAILHPOWERV (Rail E-W, Wire N-S)
                self._draw_rail(painter, 226, sx, sy, ts, tx, ty)
                self._draw_wire_crossing(painter, 221, sx, sy, ts)
            elif t == 222:  # RAILVPOWERH (Rail N-S, Wire E-W)
                self._draw_rail(painter, 227, sx, sy, ts, tx, ty)
                self._draw_wire_crossing(painter, 222, sx, sy, ts)
            elif 208 <= t <= 209:  # Water pylons
                self._draw_wire_water(painter, t, sx, sy, ts, tx, ty)
            else:
                self._draw_wire(painter, t, sx, sy, ts, tx, ty)
            return

        # 8. RAILROADS & LEVEL CROSSINGS (224..239)
        if 224 <= t <= 239:
            if t in (237, 238):  # Level crossings
                self._draw_rail_crossing(painter, t, sx, sy, ts, tx, ty)
            elif t == 239:  # ROADVPOWERH
                self._draw_road(painter, 67, sx, sy, ts, tx, ty)
                self._draw_wire_crossing(painter, 78, sx, sy, ts)
            else:
                self._draw_rail(painter, t, sx, sy, ts, tx, ty)
            return

        # 9. RESIDENTIAL (240..422) & EXTENDED SHRINES (956..1018)
        if (240 <= t <= 422) or (956 <= t <= 1018):
            self._draw_residential_zone(painter, raw, t, has_power, sx, sy, ts, tx, ty)
            return


        # 10. COMMERCIAL (423..611)
        if 423 <= t <= 611:
            self._draw_commercial_zone(painter, raw, t, has_power, sx, sy, ts, tx, ty)
            return


        # 11. INDUSTRIAL (612..692)
        if 612 <= t <= 692:
            self._draw_industrial_zone(painter, raw, t, has_power, sx, sy, ts, tx, ty)
            return


        # 12. SEAPORT (693..708, 4x4, center 698)
        if 693 <= t <= 708:
            if t == 698 or (raw & 0x0400):
                sp = self._spec_sprites.get("port")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), COLOR_PORT)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 13. AIRPORT (709..744, 6x6, center 716)
        if 709 <= t <= 744:
            if t == 716 or (raw & 0x0400):
                sp = self._spec_sprites.get("airport")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 6 * ts, 6 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 6 * ts, 6 * ts), COLOR_AIRPORT)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 14. COAL POWER PLANT (745..760, 4x4, center 750)
        if 745 <= t <= 760:
            if t == 750 or (raw & 0x0400):
                sp = self._spec_sprites.get("coal")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), COLOR_COAL)
            return

        # 15. FIRE STATION (761..769, 3x3, center 765)
        if 761 <= t <= 769:
            if t == 765 or (raw & 0x0400):
                sp = self._spec_sprites.get("fire")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), COLOR_FIRE_DEPT)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 16. POLICE STATION (770..778, 3x3, center 774)
        if 770 <= t <= 778:
            if t == 774 or (raw & 0x0400):
                sp = self._spec_sprites.get("police")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), COLOR_POLICE_DEPT)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 17. STADIUM (779..810, 4x4, center 784, 800)
        if 779 <= t <= 810:
            if t in (784, 800) or (raw & 0x0400):
                sp = self._spec_sprites.get("stadium")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), COLOR_STADIUM)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 18. NUCLEAR POWER PLANT (811..826, 4x4, center 816)
        if 811 <= t <= 826:
            if t == 816 or (raw & 0x0400):
                sp = self._spec_sprites.get("nuke")
                if sp:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), sp)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 4 * ts, 4 * ts), COLOR_NUCLEAR)
            return


        # 19. PARK / FOUNTAIN (840..843, Animated Japanese Zen Garden & Basin)
        if 840 <= t <= 843:
            f_idx = (t - 840) % len(self._park_sprites) if self._park_sprites else 0
            if self._park_sprites:
                painter.drawImage(rect, self._park_sprites[f_idx])
            else:
                painter.fillRect(rect, COLOR_PARK)
                painter.fillRect(QRectF(sx + ts * 0.3, sy + ts * 0.3, ts * 0.4, ts * 0.4), COLOR_WATER)
            return

        # Fallback tile rendering
        painter.fillRect(rect, COLOR_DIRT)

    # --- Studio Ghibli Watercolor Nature Renderers ---

    def _is_water_tile(self, tx: int, ty: int) -> bool:
        if not (0 <= tx < 120 and 0 <= ty < 100) or not self._engine:
            return True
        raw = self._engine.fast_get_tile(tx, ty)
        t = raw & 0x03FF
        return (2 <= t <= 20) or (t in (64, 65, 79, 224, 225, 208, 209))

    def _is_land_tile(self, tx: int, ty: int) -> bool:
        return not self._is_water_tile(tx, ty)

    def _draw_ghibli_land(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)
        # 1. Unified soft Ghibli meadow base (NO per-tile checkerboard)
        painter.fillRect(rect, COLOR_MEADOW_BASE)

        # 2. Large organic rolling hill sunlight variation (continuous spatial field)
        hill_val = math.sin(tx * 0.08 + ty * 0.06) + math.cos(tx * 0.05 - ty * 0.07)
        if hill_val > 0.4:
            painter.fillRect(rect, QColor(190, 224, 130, int(min(65, (hill_val - 0.4) * 80))))
        elif hill_val < -0.6:
            painter.fillRect(rect, QColor(138, 179, 91, int(min(50, (-hill_val - 0.6) * 70))))

        # 3. Dynamic wind wave sheen rolling across grass (animated breeze)
        wind = math.sin(self._anim_tick * 0.04 + tx * 0.28 + ty * 0.16)
        if wind > 0.35:
            alpha = int(min(65, (wind - 0.35) * 100))
            painter.fillRect(rect, QColor(255, 255, 220, alpha))

        # 4. Occasional delicate wildflowers or weathered stone paver
        if ts >= 14:
            f_hash = (tx * 19 + ty * 23) % 17
            if f_hash == 0:
                fx = sx + ts * 0.45
                fy = sy + ts * 0.55
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#f4a261") if (tx + ty) % 2 == 0 else QColor("#ffffff"))
                painter.drawEllipse(QPointF(fx, fy), max(1.5, ts * 0.06), max(1.5, ts * 0.06))
                painter.setBrush(QColor("#e9c46a"))
                painter.drawEllipse(QPointF(fx + 2, fy - 2), max(1.2, ts * 0.05), max(1.2, ts * 0.05))
            elif f_hash == 1:
                painter.setPen(QPen(COLOR_SAND_DARK, max(0.8, ts * 0.03)))
                painter.setBrush(QColor("#f4ece1"))
                painter.drawRoundedRect(QRectF(sx + ts * 0.28, sy + ts * 0.38, ts * 0.36, ts * 0.22), 2.0, 2.0)

    def _draw_ghibli_water(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # Check adjacent land neighbors
        n = self._is_land_tile(tx, ty - 1)
        s = self._is_land_tile(tx, ty + 1)
        w = self._is_land_tile(tx - 1, ty)
        e = self._is_land_tile(tx + 1, ty)
        nw = self._is_land_tile(tx - 1, ty - 1)
        ne = self._is_land_tile(tx + 1, ty - 1)
        sw = self._is_land_tile(tx - 1, ty + 1)
        se = self._is_land_tile(tx + 1, ty + 1)
        has_land = n or s or w or e or nw or ne or sw or se

        if not has_land:
            # Deep open ocean
            painter.fillRect(rect, COLOR_WATER_DEEP)

            # Rare charming rocky islet with lighthouse
            if (tx * 31 + ty * 47) % 89 == 0 and ts >= 20:
                self._draw_rocky_islet(painter, sx, sy, ts)
                return

            # Gentle animated wave crests
            drift = math.sin(self._anim_tick * 0.06 + tx * 0.5 + ty * 0.3)
            if (tx * 7 + ty * 13) % 3 == 0:
                wx = sx + ts * 0.25 + drift * (ts * 0.08)
                wy = sy + ts * 0.45
                painter.setPen(QPen(COLOR_WAVE_CREST, max(1.2, ts * 0.035), Qt.SolidLine, Qt.RoundCap))
                painter.setBrush(Qt.NoBrush)
                painter.drawLine(QPointF(wx, wy), QPointF(wx + ts * 0.16, wy - 1.5))
                painter.drawLine(QPointF(wx + ts * 0.16, wy - 1.5), QPointF(wx + ts * 0.35, wy + 1.0))
            return

        # Shoreline tile:
        # 1. Translucent turquoise coastal shallow shelf
        painter.fillRect(rect, COLOR_WATER_SHALLOW)

        # 2. Sandy shoreline cliff & foam lap hugging the land
        sand_pen = QPen(COLOR_SAND_BANK, max(3.0, ts * 0.12), Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin)
        foam_pen = QPen(COLOR_WATER_FOAM, max(1.6, ts * 0.07), Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin)

        painter.setBrush(Qt.NoBrush)
        if w and not n and not s:
            painter.setPen(sand_pen)
            painter.drawLine(QPointF(sx, sy), QPointF(sx, sy + ts))
            painter.setPen(foam_pen)
            painter.drawLine(QPointF(sx + max(2.0, ts * 0.08), sy), QPointF(sx + max(2.0, ts * 0.08), sy + ts))
        elif e and not n and not s:
            painter.setPen(sand_pen)
            painter.drawLine(QPointF(sx + ts, sy), QPointF(sx + ts, sy + ts))
            painter.setPen(foam_pen)
            painter.drawLine(QPointF(sx + ts - max(2.0, ts * 0.08), sy), QPointF(sx + ts - max(2.0, ts * 0.08), sy + ts))
        elif n and not w and not e:
            painter.setPen(sand_pen)
            painter.drawLine(QPointF(sx, sy), QPointF(sx + ts, sy))
            painter.setPen(foam_pen)
            painter.drawLine(QPointF(sx, sy + max(2.0, ts * 0.08)), QPointF(sx + ts, sy + max(2.0, ts * 0.08)))
        elif s and not w and not e:
            painter.setPen(sand_pen)
            painter.drawLine(QPointF(sx, sy + ts), QPointF(sx + ts, sy + ts))
            painter.setPen(foam_pen)
            painter.drawLine(QPointF(sx, sy + ts - max(2.0, ts * 0.08)), QPointF(sx + ts, sy + ts - max(2.0, ts * 0.08)))
        else:
            path = QPainterPath()
            if nw or (n and w):
                path.moveTo(sx + ts * 0.5, sy)
                path.quadTo(sx + ts * 0.15, sy + ts * 0.15, sx, sy + ts * 0.5)
            elif ne or (n and e):
                path.moveTo(sx + ts * 0.5, sy)
                path.quadTo(sx + ts * 0.85, sy + ts * 0.15, sx + ts, sy + ts * 0.5)
            elif sw or (s and w):
                path.moveTo(sx, sy + ts * 0.5)
                path.quadTo(sx + ts * 0.15, sy + ts * 0.85, sx + ts * 0.5, sy + ts)
            elif se or (s and e):
                path.moveTo(sx + ts * 0.5, sy + ts)
                path.quadTo(sx + ts * 0.85, sy + ts * 0.85, sx + ts, sy + ts * 0.5)
            else:
                path.addRect(QRectF(sx + ts * 0.2, sy + ts * 0.2, ts * 0.6, ts * 0.6))

            painter.setPen(sand_pen)
            painter.drawPath(path)
            painter.setPen(foam_pen)
            painter.drawPath(path)

    def _draw_rocky_islet(self, painter: QPainter, sx: float, sy: float, ts: float):
        ix = sx + ts * 0.5
        iy = sy + ts * 0.5
        # Rock base
        painter.setPen(QPen(COLOR_CLIFF_EDGE, max(1.2, ts * 0.05)))
        painter.setBrush(QColor("#8f7956"))
        painter.drawEllipse(QPointF(ix, iy), ts * 0.35, ts * 0.24)
        # Grass cap
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_MEADOW_BASE)
        painter.drawEllipse(QPointF(ix - 1, iy - 1), ts * 0.22, ts * 0.14)
        # Tiny lighthouse
        painter.setPen(QPen(COLOR_CLIFF_EDGE, max(1.0, ts * 0.04)))
        painter.setBrush(QColor("#ffffff"))
        lh_w = max(3.0, ts * 0.10)
        lh_h = max(7.0, ts * 0.35)
        painter.drawRect(QRectF(ix - lh_w * 0.5, iy - lh_h, lh_w, lh_h))
        # Red band
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#d90429"))
        painter.drawRect(QRectF(ix - lh_w * 0.5, iy - lh_h * 0.65, lh_w, lh_h * 0.3))
        # Red roof
        painter.drawPolygon(QPolygonF([
            QPointF(ix - lh_w * 0.7, iy - lh_h),
            QPointF(ix + lh_w * 0.7, iy - lh_h),
            QPointF(ix, iy - lh_h - max(3.0, ts * 0.12))
        ]))

    def _draw_ghibli_forest(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int, ty: int):
        # Forest floor deep under-shadow
        painter.fillRect(QRectF(sx, sy, ts + 0.5, ts + 0.5), QColor("#1e4222"))

        # Wind sway
        sway_x = math.sin(self._anim_tick * 0.06 + tx * 0.7 + ty * 0.5) * (ts * 0.05)

        # Style: pine on western flank or deciduous in interior
        is_pine = (tx < 16)
        if is_pine:
            self._draw_ghibli_pine_tree(painter, sx + ts * 0.3 + sway_x, sy + ts * 0.45, ts * 0.75)
            self._draw_ghibli_pine_tree(painter, sx + ts * 0.75 + sway_x, sy + ts * 0.6, ts * 0.8)
            self._draw_ghibli_pine_tree(painter, sx + ts * 0.45 + sway_x, sy + ts * 0.95, ts * 0.85)
        else:
            self._draw_ghibli_decid_tree(painter, sx + ts * 0.35 + sway_x, sy + ts * 0.5, ts * 0.42)
            self._draw_ghibli_decid_tree(painter, sx + ts * 0.7 + sway_x, sy + ts * 0.85, ts * 0.46)

        # Occasional soot sprite (susuwatari) peeking from forest edge
        if (tx * 13 + ty * 19) % 17 == 0 and ts >= 16:
            self._draw_soot_sprite(painter, sx + ts * 0.85, sy + ts * 0.85, max(4.0, ts * 0.18))

    def _draw_ghibli_pine_tree(self, painter: QPainter, bx: float, by: float, h_val: float):
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_TRUNK)
        painter.drawRect(QRectF(bx - 1.5, by - 4, 3, 5))

        bw = h_val * 0.72
        painter.setPen(QPen(COLOR_CLIFF_EDGE, max(0.8, h_val * 0.03)))
        painter.setBrush(COLOR_PINE_DEEP)
        painter.drawPolygon(QPolygonF([
            QPointF(bx - bw * 0.5, by - 3), QPointF(bx + bw * 0.5, by - 3),
            QPointF(bx, by - h_val * 0.45)
        ]))
        painter.setBrush(COLOR_PINE_MID)
        painter.drawPolygon(QPolygonF([
            QPointF(bx - bw * 0.4, by - h_val * 0.35), QPointF(bx + bw * 0.4, by - h_val * 0.35),
            QPointF(bx, by - h_val * 0.72)
        ]))
        painter.setBrush(COLOR_PINE_LIGHT)
        painter.drawPolygon(QPolygonF([
            QPointF(bx - bw * 0.28, by - h_val * 0.62), QPointF(bx + bw * 0.28, by - h_val * 0.62),
            QPointF(bx, by - h_val)
        ]))

    def _draw_ghibli_decid_tree(self, painter: QPainter, bx: float, by: float, rad: float):
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_TRUNK)
        painter.drawRect(QRectF(bx - 2, by - 6, 4, 8))

        cy = by - rad - 2
        painter.setPen(QPen(COLOR_CLIFF_EDGE, max(0.8, rad * 0.05)))
        painter.setBrush(COLOR_DECID_DEEP)
        painter.drawEllipse(QPointF(bx, cy + rad * 0.2), rad * 1.05, rad * 0.95)

        painter.setBrush(COLOR_DECID_MID)
        painter.drawEllipse(QPointF(bx - rad * 0.38, cy), rad * 0.75, rad * 0.75)
        painter.drawEllipse(QPointF(bx + rad * 0.38, cy), rad * 0.75, rad * 0.75)
        painter.drawEllipse(QPointF(bx, cy - rad * 0.28), rad * 0.85, rad * 0.85)

        painter.setBrush(COLOR_DECID_LIGHT)
        painter.drawEllipse(QPointF(bx - rad * 0.18, cy - rad * 0.38), rad * 0.58, rad * 0.52)
        painter.drawEllipse(QPointF(bx + rad * 0.22, cy - rad * 0.25), rad * 0.48, rad * 0.42)

        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_DECID_CROWN)
        painter.drawEllipse(QPointF(bx - rad * 0.1, cy - rad * 0.52), rad * 0.32, rad * 0.26)

    def _draw_soot_sprite(self, painter: QPainter, sx: float, sy: float, s: float):
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_SOOT_SPRITE)
        painter.drawEllipse(QPointF(sx, sy), s, s)
        painter.setBrush(QColor("#ffffff"))
        painter.drawEllipse(QPointF(sx - s * 0.3, sy - s * 0.15), s * 0.3, s * 0.3)
        painter.drawEllipse(QPointF(sx + s * 0.3, sy - s * 0.15), s * 0.3, s * 0.3)
        painter.setBrush(QColor("#000000"))
        painter.drawEllipse(QPointF(sx - s * 0.25, sy - s * 0.15), s * 0.14, s * 0.14)
        painter.drawEllipse(QPointF(sx + s * 0.35, sy - s * 0.15), s * 0.14, s * 0.14)

    # --- Procedural Road & Bridge Renderer ---

    def _is_road_connected(self, tx: int, ty: int) -> bool:
        if not (0 <= tx < 120 and 0 <= ty < 100) or not self._engine:
            return False
        raw = self._engine.fast_get_tile(tx, ty)
        t = raw & 0x03FF
        # Roads (64..207)
        if 64 <= t <= 207:
            return True
        # Rail/Road level crossings (237, 238)
        if t in (237, 238):
            return True
        return False

    def _draw_road(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 64: Horizontal Bridge over Water
        if t == 64:
            painter.fillRect(rect, COLOR_WATER)
            # Concrete bridge deck
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts + 0.5, ts * 0.68), COLOR_BRIDGE_CONCRETE)
            # Asphalt roadway
            painter.fillRect(QRectF(sx, sy + ts * 0.24, ts + 0.5, ts * 0.52), COLOR_ROAD)
            # White guardrails
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.08)))
            painter.drawLine(QPointF(sx, sy + ts * 0.18), QPointF(sx + ts, sy + ts * 0.18))
            painter.drawLine(QPointF(sx, sy + ts * 0.82), QPointF(sx + ts, sy + ts * 0.82))
            # Dashed yellow center line
            if ts >= 12:
                pen_dash = QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine)
                painter.setPen(pen_dash)
                painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
            return

        # 65: Vertical Bridge over Water
        if t == 65:
            painter.fillRect(rect, COLOR_WATER)
            # Concrete bridge deck
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts + 0.5), COLOR_BRIDGE_CONCRETE)
            # Asphalt roadway
            painter.fillRect(QRectF(sx + ts * 0.24, sy, ts * 0.52, ts + 0.5), COLOR_ROAD)
            # White guardrails
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.08)))
            painter.drawLine(QPointF(sx + ts * 0.18, sy), QPointF(sx + ts * 0.18, sy + ts))
            painter.drawLine(QPointF(sx + ts * 0.82, sy), QPointF(sx + ts * 0.82, sy + ts))
            # Dashed yellow center line
            if ts >= 12:
                pen_dash = QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine)
                painter.setPen(pen_dash)
                painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts))
            return

        # 79: Open drawbridge / water channel
        if t == 79:
            painter.fillRect(rect, COLOR_WATER)
            painter.fillRect(QRectF(sx, sy + ts * 0.2, ts * 0.2, ts * 0.6), COLOR_BRIDGE_CONCRETE)
            painter.fillRect(QRectF(sx + ts * 0.8, sy + ts * 0.2, ts * 0.2, ts * 0.6), COLOR_BRIDGE_CONCRETE)
            return

        # Land Road Tiles
        painter.fillRect(rect, COLOR_DIRT)

        # 77: HROADPOWER (Horizontal Road with Vertical Wire Crossing)
        if t == 77:
            self._draw_road_straight_h(painter, sx, sy, ts, tx, ty)
            self._draw_wire_crossing(painter, 77, sx, sy, ts)
            return

        # 78: VROADPOWER (Vertical Road with Horizontal Wire Crossing)
        if t == 78:
            self._draw_road_straight_v(painter, sx, sy, ts, tx, ty)
            self._draw_wire_crossing(painter, 78, sx, sy, ts)
            return

        # 66: Straight Horizontal Road
        if t == 66:
            self._draw_road_straight_h(painter, sx, sy, ts, tx, ty)
            return

        # 67: Straight Vertical Road
        if t == 67:
            self._draw_road_straight_v(painter, sx, sy, ts, tx, ty)
            return

        # Curves (68..71)
        if 68 <= t <= 71:
            self._draw_road_curve(painter, t, sx, sy, ts)
            return

        # T-Junctions (72..75)
        if 72 <= t <= 75:
            self._draw_road_t_junction(painter, t, sx, sy, ts)
            return

        # 76: 4-Way Intersection
        if t == 76:
            self._draw_road_intersection(painter, sx, sy, ts)
            return

        # Generic road fallback
        self._draw_road_straight_h(painter, sx, sy, ts, tx, ty)

    def _draw_road_straight_h(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int = -1, ty: int = -1):
        # Asphalt body
        painter.fillRect(QRectF(sx, sy + ts * 0.16, ts + 0.5, ts * 0.68), COLOR_ROAD)
        # Curbs (top and bottom)
        painter.setPen(QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06)))
        painter.drawLine(QPointF(sx, sy + ts * 0.16), QPointF(sx + ts, sy + ts * 0.16))
        painter.drawLine(QPointF(sx, sy + ts * 0.84), QPointF(sx + ts, sy + ts * 0.84))

        conn_w = self._is_road_connected(tx - 1, ty) if (tx >= 0 and ty >= 0) else True
        conn_e = self._is_road_connected(tx + 1, ty) if (tx >= 0 and ty >= 0) else True

        # Dead-end capping curbs
        curb_pen = QPen(COLOR_ROAD_CURB, max(1.2, ts * 0.08))
        painter.setPen(curb_pen)
        if not conn_w:
            painter.drawLine(QPointF(sx, sy + ts * 0.16), QPointF(sx, sy + ts * 0.84))
        if not conn_e:
            painter.drawLine(QPointF(sx + ts, sy + ts * 0.16), QPointF(sx + ts, sy + ts * 0.84))

        # Dashed yellow lane
        if ts >= 10:
            x_start = sx + (ts * 0.28 if not conn_w else 0.0)
            x_end = sx + ts - (ts * 0.28 if not conn_e else 0.0)
            if x_end > x_start:
                painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
                painter.drawLine(QPointF(x_start, sy + ts * 0.5), QPointF(x_end, sy + ts * 0.5))

    def _draw_road_straight_v(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int = -1, ty: int = -1):
        # Asphalt body
        painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts + 0.5), COLOR_ROAD)
        # Curbs (left and right)
        painter.setPen(QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06)))
        painter.drawLine(QPointF(sx + ts * 0.16, sy), QPointF(sx + ts * 0.16, sy + ts))
        painter.drawLine(QPointF(sx + ts * 0.84, sy), QPointF(sx + ts * 0.84, sy + ts))

        conn_n = self._is_road_connected(tx, ty - 1) if (tx >= 0 and ty >= 0) else True
        conn_s = self._is_road_connected(tx, ty + 1) if (tx >= 0 and ty >= 0) else True

        # Dead-end capping curbs
        curb_pen = QPen(COLOR_ROAD_CURB, max(1.2, ts * 0.08))
        painter.setPen(curb_pen)
        if not conn_n:
            painter.drawLine(QPointF(sx + ts * 0.16, sy), QPointF(sx + ts * 0.84, sy))
        if not conn_s:
            painter.drawLine(QPointF(sx + ts * 0.16, sy + ts), QPointF(sx + ts * 0.84, sy + ts))

        # Dashed yellow lane
        if ts >= 10:
            y_start = sy + (ts * 0.28 if not conn_n else 0.0)
            y_end = sy + ts - (ts * 0.28 if not conn_s else 0.0)
            if y_end > y_start:
                painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
                painter.drawLine(QPointF(sx + ts * 0.5, y_start), QPointF(sx + ts * 0.5, y_end))

    def _draw_road_curve(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # 68=NE, 69=ES, 70=SW, 71=WN
        # Arc geometry: inner curb 0.16*ts, center lane 0.5*ts, outer curb 0.84*ts
        r_in = ts * 0.16
        r_mid = ts * 0.50
        r_out = ts * 0.84

        if t == 68:  # North & East (Bottom-Left of a 2x2 loop)
            cx, cy = sx + ts, sy
            start_ang, span_ang = 180.0, 90.0
        elif t == 69:  # East & South (Top-Left of a 2x2 loop)
            cx, cy = sx + ts, sy + ts
            start_ang, span_ang = 90.0, 90.0
        elif t == 70:  # South & West (Top-Right of a 2x2 loop)
            cx, cy = sx, sy + ts
            start_ang, span_ang = 0.0, 90.0
        else:  # 71: West & North (Bottom-Right of a 2x2 loop)
            cx, cy = sx, sy
            start_ang, span_ang = 270.0, 90.0

        # 1. Asphalt Body (annulus sector)
        asphalt_path = QPainterPath()
        asphalt_path.arcMoveTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang)
        asphalt_path.arcTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang, span_ang)
        asphalt_path.arcTo(QRectF(cx - r_in, cy - r_in, 2 * r_in, 2 * r_in), start_ang + span_ang, -span_ang)
        asphalt_path.closeSubpath()

        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_ROAD)
        painter.drawPath(asphalt_path)

        # 2. Curbs (inner and outer circular arcs)
        curb_pen = QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06))
        painter.setPen(curb_pen)
        painter.setBrush(Qt.NoBrush)

        inner_curb = QPainterPath()
        inner_curb.arcMoveTo(QRectF(cx - r_in, cy - r_in, 2 * r_in, 2 * r_in), start_ang)
        inner_curb.arcTo(QRectF(cx - r_in, cy - r_in, 2 * r_in, 2 * r_in), start_ang, span_ang)
        painter.drawPath(inner_curb)

        outer_curb = QPainterPath()
        outer_curb.arcMoveTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang)
        outer_curb.arcTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang, span_ang)
        painter.drawPath(outer_curb)

        # 3. Dashed Yellow Center Lane Arc
        if ts >= 10:
            lane_path = QPainterPath()
            lane_path.arcMoveTo(QRectF(cx - r_mid, cy - r_mid, 2 * r_mid, 2 * r_mid), start_ang)
            lane_path.arcTo(QRectF(cx - r_mid, cy - r_mid, 2 * r_mid, 2 * r_mid), start_ang, span_ang)
            painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
            painter.drawPath(lane_path)

    def _draw_road_t_junction(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # 72=NEW, 73=NES, 74=ESW, 75=NSW
        curb_pen = QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06))
        lane_pen = QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine)
        cw_pen = QPen(COLOR_ROAD_STOP, max(1.0, ts * 0.05))

        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_ROAD)

        if t == 72:  # NEW: Horizontal road + North stem
            # Asphalt
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts, ts * 0.68), COLOR_ROAD)
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts * 0.5), COLOR_ROAD)
            # Curbs
            painter.setPen(curb_pen)
            painter.drawLine(QPointF(sx, sy + ts * 0.84), QPointF(sx + ts, sy + ts * 0.84))
            # Corner curbs
            c1 = QPainterPath()
            c1.moveTo(sx, sy + ts * 0.16)
            c1.lineTo(sx + ts * 0.16, sy + ts * 0.16)
            c1.lineTo(sx + ts * 0.16, sy)
            painter.drawPath(c1)
            c2 = QPainterPath()
            c2.moveTo(sx + ts * 0.84, sy)
            c2.lineTo(sx + ts * 0.84, sy + ts * 0.16)
            c2.lineTo(sx + ts, sy + ts * 0.16)
            painter.drawPath(c2)
            # Dashed lanes
            if ts >= 10:
                painter.setPen(lane_pen)
                painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
                painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts * 0.5))
            # Crosswalk across North entrance
            if ts >= 14:
                painter.setPen(cw_pen)
                for i in range(3):
                    xx = sx + ts * (0.28 + i * 0.16)
                    painter.drawLine(QPointF(xx, sy + ts * 0.04), QPointF(xx, sy + ts * 0.13))

        elif t == 74:  # ESW: Horizontal road + South stem
            # Asphalt
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts, ts * 0.68), COLOR_ROAD)
            painter.fillRect(QRectF(sx + ts * 0.16, sy + ts * 0.5, ts * 0.68, ts * 0.5), COLOR_ROAD)
            # Curbs
            painter.setPen(curb_pen)
            painter.drawLine(QPointF(sx, sy + ts * 0.16), QPointF(sx + ts, sy + ts * 0.16))
            c1 = QPainterPath()
            c1.moveTo(sx, sy + ts * 0.84)
            c1.lineTo(sx + ts * 0.16, sy + ts * 0.84)
            c1.lineTo(sx + ts * 0.16, sy + ts)
            painter.drawPath(c1)
            c2 = QPainterPath()
            c2.moveTo(sx + ts * 0.84, sy + ts)
            c2.lineTo(sx + ts * 0.84, sy + ts * 0.84)
            c2.lineTo(sx + ts, sy + ts * 0.84)
            painter.drawPath(c2)
            # Dashed lanes
            if ts >= 10:
                painter.setPen(lane_pen)
                painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
                painter.drawLine(QPointF(sx + ts * 0.5, sy + ts * 0.5), QPointF(sx + ts * 0.5, sy + ts))
            # Crosswalk across South entrance
            if ts >= 14:
                painter.setPen(cw_pen)
                for i in range(3):
                    xx = sx + ts * (0.28 + i * 0.16)
                    painter.drawLine(QPointF(xx, sy + ts * 0.87), QPointF(xx, sy + ts * 0.96))

        elif t == 73:  # NES: Vertical road + East stem
            # Asphalt
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts), COLOR_ROAD)
            painter.fillRect(QRectF(sx + ts * 0.5, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            # Curbs
            painter.setPen(curb_pen)
            painter.drawLine(QPointF(sx + ts * 0.16, sy), QPointF(sx + ts * 0.16, sy + ts))
            c1 = QPainterPath()
            c1.moveTo(sx + ts * 0.84, sy)
            c1.lineTo(sx + ts * 0.84, sy + ts * 0.16)
            c1.lineTo(sx + ts, sy + ts * 0.16)
            painter.drawPath(c1)
            c2 = QPainterPath()
            c2.moveTo(sx + ts * 0.84, sy + ts)
            c2.lineTo(sx + ts * 0.84, sy + ts * 0.84)
            c2.lineTo(sx + ts, sy + ts * 0.84)
            painter.drawPath(c2)
            # Dashed lanes
            if ts >= 10:
                painter.setPen(lane_pen)
                painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts))
                painter.drawLine(QPointF(sx + ts * 0.5, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
            # Crosswalk across East entrance
            if ts >= 14:
                painter.setPen(cw_pen)
                for i in range(3):
                    yy = sy + ts * (0.28 + i * 0.16)
                    painter.drawLine(QPointF(sx + ts * 0.87, yy), QPointF(sx + ts * 0.96, yy))

        elif t == 75:  # NSW: Vertical road + West stem
            # Asphalt
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts), COLOR_ROAD)
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            # Curbs
            painter.setPen(curb_pen)
            painter.drawLine(QPointF(sx + ts * 0.84, sy), QPointF(sx + ts * 0.84, sy + ts))
            c1 = QPainterPath()
            c1.moveTo(sx + ts * 0.16, sy)
            c1.lineTo(sx + ts * 0.16, sy + ts * 0.16)
            c1.lineTo(sx, sy + ts * 0.16)
            painter.drawPath(c1)
            c2 = QPainterPath()
            c2.moveTo(sx + ts * 0.16, sy + ts)
            c2.lineTo(sx + ts * 0.16, sy + ts * 0.84)
            c2.lineTo(sx, sy + ts * 0.84)
            painter.drawPath(c2)
            # Dashed lanes
            if ts >= 10:
                painter.setPen(lane_pen)
                painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts))
                painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts * 0.5, sy + ts * 0.5))
            # Crosswalk across West entrance
            if ts >= 14:
                painter.setPen(cw_pen)
                for i in range(3):
                    yy = sy + ts * (0.28 + i * 0.16)
                    painter.drawLine(QPointF(sx + ts * 0.04, yy), QPointF(sx + ts * 0.13, yy))

    def _draw_road_intersection(self, painter: QPainter, sx: float, sy: float, ts: float):
        # 76: 4-Way Intersection
        # Full open asphalt cross
        painter.fillRect(QRectF(sx, sy + ts * 0.16, ts, ts * 0.68), COLOR_ROAD)
        painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts), COLOR_ROAD)

        # 4 Corner Curbs (leaving all 4 arms open!)
        curb_pen = QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06))
        painter.setPen(curb_pen)

        c1 = QPainterPath()
        c1.moveTo(sx, sy + ts * 0.16)
        c1.lineTo(sx + ts * 0.16, sy + ts * 0.16)
        c1.lineTo(sx + ts * 0.16, sy)
        painter.drawPath(c1)

        c2 = QPainterPath()
        c2.moveTo(sx + ts * 0.84, sy)
        c2.lineTo(sx + ts * 0.84, sy + ts * 0.16)
        c2.lineTo(sx + ts, sy + ts * 0.16)
        painter.drawPath(c2)

        c3 = QPainterPath()
        c3.moveTo(sx, sy + ts * 0.84)
        c3.lineTo(sx + ts * 0.16, sy + ts * 0.84)
        c3.lineTo(sx + ts * 0.16, sy + ts)
        painter.drawPath(c3)

        c4 = QPainterPath()
        c4.moveTo(sx + ts * 0.84, sy + ts)
        c4.lineTo(sx + ts * 0.84, sy + ts * 0.84)
        c4.lineTo(sx + ts, sy + ts * 0.84)
        painter.drawPath(c4)

        # Crosswalk zebra stripes on all 4 entrances
        if ts >= 14:
            cw_pen = QPen(COLOR_ROAD_STOP, max(1.0, ts * 0.05), Qt.SolidLine)
            painter.setPen(cw_pen)
            for i in range(3):
                xx = sx + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(xx, sy + ts * 0.04), QPointF(xx, sy + ts * 0.13))
                painter.drawLine(QPointF(xx, sy + ts * 0.87), QPointF(xx, sy + ts * 0.96))
                yy = sy + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(sx + ts * 0.04, yy), QPointF(sx + ts * 0.13, yy))
                painter.drawLine(QPointF(sx + ts * 0.87, yy), QPointF(sx + ts * 0.96, yy))

    # --- Animated Road Traffic Renderer ---

    def _draw_traffic(self, painter: QPainter, base_t: int, level: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        if ts < 10:
            return

        # Number of cars on this tile (1 for light, 2 for heavy)
        car_count = 1 if level == 1 else 2
        car_w = max(3.5, ts * 0.28)
        car_h = max(2.0, ts * 0.16)

        is_vertical = base_t in (65, 67, 73, 75)

        for i in range(car_count):
            # Deterministic smooth phase based on time tick and tile location
            phase = (self._anim_tick * 0.04 + (tx * 19 + ty * 31 + i * 47) / 100.0) % 1.0
            car_color = CAR_PALETTE[(tx * 3 + ty * 7 + i) % len(CAR_PALETTE)]

            if not is_vertical:
                # Eastbound bottom lane (i=0), Westbound top lane (i=1)
                if i % 2 == 0:
                    cx = sx + phase * ts
                    cy = sy + ts * 0.66
                    self._draw_car_sprite(painter, cx, cy, car_w, car_h, car_color, 1, 0, ts)
                else:
                    cx = sx + (1.0 - phase) * ts
                    cy = sy + ts * 0.34
                    self._draw_car_sprite(painter, cx, cy, car_w, car_h, car_color, -1, 0, ts)
            else:
                # Southbound right lane (i=0), Northbound left lane (i=1)
                if i % 2 == 0:
                    cx = sx + ts * 0.66
                    cy = sy + phase * ts
                    self._draw_car_sprite(painter, cx, cy, car_h, car_w, car_color, 0, 1, ts)
                else:
                    cx = sx + ts * 0.34
                    cy = sy + (1.0 - phase) * ts
                    self._draw_car_sprite(painter, cx, cy, car_h, car_w, car_color, 0, -1, ts)

    def _draw_car_sprite(self, painter: QPainter, cx: float, cy: float, w: float, h: float, color: QColor, dx: int, dy: int, ts: float):
        painter.save()
        # Car body
        painter.setPen(Qt.NoPen)
        painter.setBrush(color)
        painter.drawRoundedRect(QRectF(cx - w / 2.0, cy - h / 2.0, w, h), 1.0, 1.0)

        # Windshield
        painter.setBrush(QColor("#11111b"))
        if dx != 0:
            # Horizontal car windshield
            fx = cx + (w * 0.15 if dx > 0 else -w * 0.15)
            painter.drawRect(QRectF(fx - w * 0.12, cy - h * 0.35, w * 0.24, h * 0.7))
        else:
            # Vertical car windshield
            fy = cy + (h * 0.15 if dy > 0 else -h * 0.15)
            painter.drawRect(QRectF(cx - w * 0.35, fy - h * 0.12, w * 0.7, h * 0.24))

        # Tiny warm headlights if zoomed in
        if ts >= 18:
            painter.setBrush(QColor("#fff3b0"))
            if dx > 0:
                painter.drawRect(QRectF(cx + w / 2.0 - 1, cy - h * 0.4, 1.5, 1.5))
                painter.drawRect(QRectF(cx + w / 2.0 - 1, cy + h * 0.4 - 1.5, 1.5, 1.5))
            elif dx < 0:
                painter.drawRect(QRectF(cx - w / 2.0, cy - h * 0.4, 1.5, 1.5))
                painter.drawRect(QRectF(cx - w / 2.0, cy + h * 0.4 - 1.5, 1.5, 1.5))
            elif dy > 0:
                painter.drawRect(QRectF(cx - w * 0.4, cy + h / 2.0 - 1, 1.5, 1.5))
                painter.drawRect(QRectF(cx + w * 0.4 - 1.5, cy + h / 2.0 - 1, 1.5, 1.5))
            elif dy < 0:
                painter.drawRect(QRectF(cx - w * 0.4, cy - h / 2.0, 1.5, 1.5))
                painter.drawRect(QRectF(cx + w * 0.4 - 1.5, cy - h / 2.0, 1.5, 1.5))

        painter.restore()

    # --- Procedural Railroad & Crossing Renderer ---

    def _is_rail_connected(self, tx: int, ty: int) -> bool:
        if not (0 <= tx < 120 and 0 <= ty < 100) or not self._engine:
            return False
        raw = self._engine.fast_get_tile(tx, ty)
        t = raw & 0x03FF
        # Rail tiles
        if 224 <= t <= 239:
            return True
        if t in (221, 222):
            return True
        if 240 <= t <= 255:
            return True
        return False

    def _draw_rail(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 224: Horizontal Rail Bridge over Water
        if t == 224:
            painter.fillRect(rect, COLOR_WATER)
            # Heavy timber bridge beams
            painter.fillRect(QRectF(sx, sy + ts * 0.18, ts + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            self._draw_rail_straight_h(painter, sx, sy, ts, tx, ty)
            # Steel bridge guardrails
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.06)))
            painter.drawLine(QPointF(sx, sy + ts * 0.18), QPointF(sx + ts, sy + ts * 0.18))
            painter.drawLine(QPointF(sx, sy + ts * 0.82), QPointF(sx + ts, sy + ts * 0.82))
            return

        # 225: Vertical Rail Bridge over Water
        if t == 225:
            painter.fillRect(rect, COLOR_WATER)
            painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts + 0.5), COLOR_RAIL_BALLAST)
            self._draw_rail_straight_v(painter, sx, sy, ts, tx, ty)
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.06)))
            painter.drawLine(QPointF(sx + ts * 0.18, sy), QPointF(sx + ts * 0.18, sy + ts))
            painter.drawLine(QPointF(sx + ts * 0.82, sy), QPointF(sx + ts * 0.82, sy + ts))
            return

        # Land Rail Tiles
        painter.fillRect(rect, COLOR_DIRT)

        # 226: Straight Horizontal Rail
        if t == 226:
            self._draw_rail_straight_h(painter, sx, sy, ts, tx, ty)
            return

        # 227: Straight Vertical Rail
        if t == 227:
            self._draw_rail_straight_v(painter, sx, sy, ts, tx, ty)
            return

        # Curves (228..231)
        if 228 <= t <= 231:
            self._draw_rail_curve(painter, t, sx, sy, ts)
            return

        # Junctions (232..236)
        if 232 <= t <= 236:
            self._draw_rail_junction(painter, t, sx, sy, ts)
            return

        self._draw_rail_straight_h(painter, sx, sy, ts, tx, ty)

    def _draw_rail_straight_h(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int = -1, ty: int = -1):
        conn_w = self._is_rail_connected(tx - 1, ty) if (tx >= 0 and ty >= 0) else True
        conn_e = self._is_rail_connected(tx + 1, ty) if (tx >= 0 and ty >= 0) else True

        # Ballast gravel bed
        bx_start = sx + (ts * 0.12 if not conn_w else 0.0)
        bx_end = sx + ts - (ts * 0.12 if not conn_e else 0.0)
        painter.fillRect(QRectF(bx_start, sy + ts * 0.18, max(0.0, bx_end - bx_start) + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)

        # Wooden sleepers (ties) spaced along tile
        tie_w = max(1.5, ts * 0.09)
        tie_pen = QPen(COLOR_RAIL_TIE, tie_w)
        painter.setPen(tie_pen)
        num_ties = max(3, int(ts / 5.5))
        for i in range(num_ties):
            frac = (i + 0.5) / num_ties
            if not conn_w and frac < 0.25:
                continue
            if not conn_e and frac > 0.75:
                continue
            tx_pos = sx + ts * frac
            painter.drawLine(QPointF(tx_pos, sy + ts * 0.22), QPointF(tx_pos, sy + ts * 0.78))

        # Dual parallel steel tracks
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        y1 = sy + ts * 0.35
        y2 = sy + ts * 0.65
        rx_start = sx + (ts * 0.22 if not conn_w else 0.0)
        rx_end = sx + ts - (ts * 0.22 if not conn_e else 0.0)

        painter.setPen(track_dark)
        painter.drawLine(QPointF(rx_start, y1), QPointF(rx_end, y1))
        painter.drawLine(QPointF(rx_start, y2), QPointF(rx_end, y2))
        painter.setPen(track_light)
        painter.drawLine(QPointF(rx_start, y1 - 0.5), QPointF(rx_end, y1 - 0.5))
        painter.drawLine(QPointF(rx_start, y2 - 0.5), QPointF(rx_end, y2 - 0.5))

        # Buffer stops at dead ends
        if not conn_w:
            buf_x = sx + ts * 0.14
            painter.fillRect(QRectF(buf_x, sy + ts * 0.26, ts * 0.08, ts * 0.48), QColor("#6c584c"))
            painter.fillRect(QRectF(buf_x + ts * 0.02, sy + ts * 0.31, ts * 0.04, ts * 0.38), QColor("#c1121f"))
        if not conn_e:
            buf_x = sx + ts * 0.78
            painter.fillRect(QRectF(buf_x, sy + ts * 0.26, ts * 0.08, ts * 0.48), QColor("#6c584c"))
            painter.fillRect(QRectF(buf_x + ts * 0.02, sy + ts * 0.31, ts * 0.04, ts * 0.38), QColor("#c1121f"))

    def _draw_rail_straight_v(self, painter: QPainter, sx: float, sy: float, ts: float, tx: int = -1, ty: int = -1):
        conn_n = self._is_rail_connected(tx, ty - 1) if (tx >= 0 and ty >= 0) else True
        conn_s = self._is_rail_connected(tx, ty + 1) if (tx >= 0 and ty >= 0) else True

        # Ballast gravel bed
        by_start = sy + (ts * 0.12 if not conn_n else 0.0)
        by_end = sy + ts - (ts * 0.12 if not conn_s else 0.0)
        painter.fillRect(QRectF(sx + ts * 0.18, by_start, ts * 0.64, max(0.0, by_end - by_start) + 0.5), COLOR_RAIL_BALLAST)

        # Wooden sleepers (ties) spaced vertically
        tie_h = max(1.5, ts * 0.09)
        tie_pen = QPen(COLOR_RAIL_TIE, tie_h)
        painter.setPen(tie_pen)
        num_ties = max(3, int(ts / 5.5))
        for i in range(num_ties):
            frac = (i + 0.5) / num_ties
            if not conn_n and frac < 0.25:
                continue
            if not conn_s and frac > 0.75:
                continue
            ty_pos = sy + ts * frac
            painter.drawLine(QPointF(sx + ts * 0.22, ty_pos), QPointF(sx + ts * 0.78, ty_pos))

        # Dual parallel steel tracks
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        x1 = sx + ts * 0.35
        x2 = sx + ts * 0.65
        ry_start = sy + (ts * 0.22 if not conn_n else 0.0)
        ry_end = sy + ts - (ts * 0.22 if not conn_s else 0.0)

        painter.setPen(track_dark)
        painter.drawLine(QPointF(x1, ry_start), QPointF(x1, ry_end))
        painter.drawLine(QPointF(x2, ry_start), QPointF(x2, ry_end))
        painter.setPen(track_light)
        painter.drawLine(QPointF(x1 - 0.5, ry_start), QPointF(x1 - 0.5, ry_end))
        painter.drawLine(QPointF(x2 - 0.5, ry_start), QPointF(x2 - 0.5, ry_end))

        # Buffer stops at dead ends
        if not conn_n:
            buf_y = sy + ts * 0.14
            painter.fillRect(QRectF(sx + ts * 0.26, buf_y, ts * 0.48, ts * 0.08), QColor("#6c584c"))
            painter.fillRect(QRectF(sx + ts * 0.31, buf_y + ts * 0.02, ts * 0.38, ts * 0.04), QColor("#c1121f"))
        if not conn_s:
            buf_y = sy + ts * 0.78
            painter.fillRect(QRectF(sx + ts * 0.26, buf_y, ts * 0.48, ts * 0.08), QColor("#6c584c"))
            painter.fillRect(QRectF(sx + ts * 0.31, buf_y + ts * 0.02, ts * 0.38, ts * 0.04), QColor("#c1121f"))

    def _draw_rail_curve(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # 228=NE (Bottom-Left), 229=ES (Top-Left), 230=SW (Top-Right), 231=WN (Bottom-Right)
        r_in = ts * 0.35
        r_out = ts * 0.65
        r_in_b = ts * 0.18
        r_out_b = ts * 0.82

        if t == 228:  # North & East (Bottom-Left of a 2x2 loop)
            cx, cy = sx + ts, sy
            start_ang, span_ang = 180.0, 90.0
            tie_angles = [202.5, 225.0, 247.5]
        elif t == 229:  # East & South (Top-Left of a 2x2 loop)
            cx, cy = sx + ts, sy + ts
            start_ang, span_ang = 90.0, 90.0
            tie_angles = [112.5, 135.0, 157.5]
        elif t == 230:  # South & West (Top-Right of a 2x2 loop)
            cx, cy = sx, sy + ts
            start_ang, span_ang = 0.0, 90.0
            tie_angles = [22.5, 45.0, 67.5]
        else:  # 231: West & North (Bottom-Right of a 2x2 loop)
            cx, cy = sx, sy
            start_ang, span_ang = 270.0, 90.0
            tie_angles = [292.5, 315.0, 337.5]

        # 1. Ballast gravel bed (annulus sector)
        ballast_path = QPainterPath()
        ballast_path.arcMoveTo(QRectF(cx - r_out_b, cy - r_out_b, 2 * r_out_b, 2 * r_out_b), start_ang)
        ballast_path.arcTo(QRectF(cx - r_out_b, cy - r_out_b, 2 * r_out_b, 2 * r_out_b), start_ang, span_ang)
        ballast_path.arcTo(QRectF(cx - r_in_b, cy - r_in_b, 2 * r_in_b, 2 * r_in_b), start_ang + span_ang, -span_ang)
        ballast_path.closeSubpath()

        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_RAIL_BALLAST)
        painter.drawPath(ballast_path)

        # 2. Radial wooden ties (sleepers)
        tie_pen = QPen(COLOR_RAIL_TIE, max(1.5, ts * 0.09))
        painter.setPen(tie_pen)
        for ang in tie_angles:
            rad = math.radians(ang)
            tx1 = cx + ts * 0.22 * math.cos(rad)
            ty1 = cy - ts * 0.22 * math.sin(rad)
            tx2 = cx + ts * 0.78 * math.cos(rad)
            ty2 = cy - ts * 0.78 * math.sin(rad)
            painter.drawLine(QPointF(tx1, ty1), QPointF(tx2, ty2))

        # 3. Dual steel tracks (concentric circular arcs)
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        arc_in = QPainterPath()
        arc_in.arcMoveTo(QRectF(cx - r_in, cy - r_in, 2 * r_in, 2 * r_in), start_ang)
        arc_in.arcTo(QRectF(cx - r_in, cy - r_in, 2 * r_in, 2 * r_in), start_ang, span_ang)

        arc_out = QPainterPath()
        arc_out.arcMoveTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang)
        arc_out.arcTo(QRectF(cx - r_out, cy - r_out, 2 * r_out, 2 * r_out), start_ang, span_ang)

        painter.setBrush(Qt.NoBrush)
        painter.setPen(track_dark)
        painter.drawPath(arc_in)
        painter.drawPath(arc_out)
        painter.setPen(track_light)
        painter.drawPath(arc_in)
        painter.drawPath(arc_out)

    def _draw_rail_junction(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # 232=NEW, 233=NES, 234=ESW, 235=NSW, 236=NESW
        has_n = t in (232, 233, 235, 236)
        has_e = t in (232, 233, 234, 236)
        has_s = t in (233, 234, 235, 236)
        has_w = t in (232, 234, 235, 236)

        # Center ballast
        painter.fillRect(QRectF(sx + ts * 0.18, sy + ts * 0.18, ts * 0.64, ts * 0.64), COLOR_RAIL_BALLAST)
        if has_n:
            painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts * 0.25), COLOR_RAIL_BALLAST)
        if has_s:
            painter.fillRect(QRectF(sx + ts * 0.18, sy + ts * 0.75, ts * 0.64, ts * 0.25 + 0.5), COLOR_RAIL_BALLAST)
        if has_w:
            painter.fillRect(QRectF(sx, sy + ts * 0.18, ts * 0.25, ts * 0.64), COLOR_RAIL_BALLAST)
        if has_e:
            painter.fillRect(QRectF(sx + ts * 0.75, sy + ts * 0.18, ts * 0.25 + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)

        # Sleepers (ties) only on entry branches outside central crossing zone
        tie_pen = QPen(COLOR_RAIL_TIE, max(1.5, ts * 0.09))
        painter.setPen(tie_pen)
        if has_w:
            painter.drawLine(QPointF(sx + ts * 0.10, sy + ts * 0.22), QPointF(sx + ts * 0.10, sy + ts * 0.78))
        if has_e:
            painter.drawLine(QPointF(sx + ts * 0.90, sy + ts * 0.22), QPointF(sx + ts * 0.90, sy + ts * 0.78))
        if has_n:
            painter.drawLine(QPointF(sx + ts * 0.22, sy + ts * 0.10), QPointF(sx + ts * 0.78, sy + ts * 0.10))
        if has_s:
            painter.drawLine(QPointF(sx + ts * 0.22, sy + ts * 0.90), QPointF(sx + ts * 0.78, sy + ts * 0.90))

        # Parallel steel tracks
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        x1 = sx + ts * 0.35
        x2 = sx + ts * 0.65
        y1 = sy + ts * 0.35
        y2 = sy + ts * 0.65

        # Horizontal rails
        if has_w and has_e:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(sx, y1), QPointF(sx + ts, y1))
            painter.drawLine(QPointF(sx, y2), QPointF(sx + ts, y2))
            painter.setPen(track_light)
            painter.drawLine(QPointF(sx, y1 - 0.5), QPointF(sx + ts, y1 - 0.5))
            painter.drawLine(QPointF(sx, y2 - 0.5), QPointF(sx + ts, y2 - 0.5))
        elif has_w:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(sx, y1), QPointF(x2, y1))
            painter.drawLine(QPointF(sx, y2), QPointF(x2, y2))
            painter.setPen(track_light)
            painter.drawLine(QPointF(sx, y1 - 0.5), QPointF(x2, y1 - 0.5))
            painter.drawLine(QPointF(sx, y2 - 0.5), QPointF(x2, y2 - 0.5))
        elif has_e:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(x1, y1), QPointF(sx + ts, y1))
            painter.drawLine(QPointF(x1, y2), QPointF(sx + ts, y2))
            painter.setPen(track_light)
            painter.drawLine(QPointF(x1, y1 - 0.5), QPointF(sx + ts, y1 - 0.5))
            painter.drawLine(QPointF(x1, y2 - 0.5), QPointF(sx + ts, y2 - 0.5))

        # Vertical rails
        if has_n and has_s:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(x1, sy), QPointF(x1, sy + ts))
            painter.drawLine(QPointF(x2, sy), QPointF(x2, sy + ts))
            painter.setPen(track_light)
            painter.drawLine(QPointF(x1 - 0.5, sy), QPointF(x1 - 0.5, sy + ts))
            painter.drawLine(QPointF(x2 - 0.5, sy), QPointF(x2 - 0.5, sy + ts))
        elif has_n:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(x1, sy), QPointF(x1, y2))
            painter.drawLine(QPointF(x2, sy), QPointF(x2, y2))
            painter.setPen(track_light)
            painter.drawLine(QPointF(x1 - 0.5, sy), QPointF(x1 - 0.5, y2))
            painter.drawLine(QPointF(x2 - 0.5, sy), QPointF(x2 - 0.5, y2))
        elif has_s:
            painter.setPen(track_dark)
            painter.drawLine(QPointF(x1, y1), QPointF(x1, sy + ts))
            painter.drawLine(QPointF(x2, y1), QPointF(x2, sy + ts))
            painter.setPen(track_light)
            painter.drawLine(QPointF(x1 - 0.5, y1), QPointF(x1 - 0.5, sy + ts))
            painter.drawLine(QPointF(x2 - 0.5, y1), QPointF(x2 - 0.5, sy + ts))

        # Diamond crossover center frog accent for 4-way crossings
        if t == 236:
            frog_pen = QPen(COLOR_RAIL_STEEL_DARK, max(1.2, ts * 0.06))
            painter.setPen(frog_pen)
            cx, cy = sx + ts * 0.5, sy + ts * 0.5
            cr = ts * 0.06
            painter.drawRect(QRectF(cx - cr, cy - cr, cr * 2, cr * 2))

    def _draw_rail_crossing(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        # 237: HRAILROAD (Rail E-W, Road N-S)
        # 238: VRAILROAD (Rail N-S, Road E-W)
        if t == 237:
            # Draw vertical road first
            self._draw_road_straight_v(painter, sx, sy, ts)
            # Railroad timber crossing planks across the asphalt
            painter.fillRect(QRectF(sx + ts * 0.16, sy + ts * 0.26, ts * 0.68, ts * 0.48), COLOR_RAIL_CROSS_WOOD)
            # Sleepers on shoulders
            painter.setPen(QPen(COLOR_RAIL_TIE, max(1.5, ts * 0.08)))
            painter.drawLine(QPointF(sx + ts * 0.08, sy + ts * 0.24), QPointF(sx + ts * 0.08, sy + ts * 0.76))
            painter.drawLine(QPointF(sx + ts * 0.92, sy + ts * 0.24), QPointF(sx + ts * 0.92, sy + ts * 0.76))
            # Dual steel rails crossing over the road
            track_pen = QPen(COLOR_RAIL_STEEL, max(1.2, ts * 0.07))
            painter.setPen(track_pen)
            painter.drawLine(QPointF(sx, sy + ts * 0.35), QPointF(sx + ts, sy + ts * 0.35))
            painter.drawLine(QPointF(sx, sy + ts * 0.65), QPointF(sx + ts, sy + ts * 0.65))
            # Yellow warning dashed lines on road approaches
            if ts >= 12:
                warn_pen = QPen(QColor("#ffd60a"), max(1.0, ts * 0.07), Qt.DotLine)
                painter.setPen(warn_pen)
                painter.drawLine(QPointF(sx + ts * 0.18, sy + ts * 0.20), QPointF(sx + ts * 0.82, sy + ts * 0.20))
                painter.drawLine(QPointF(sx + ts * 0.18, sy + ts * 0.80), QPointF(sx + ts * 0.82, sy + ts * 0.80))
        else:
            # 238: Horizontal Road, Vertical Rail
            self._draw_road_straight_h(painter, sx, sy, ts)
            # Timber planks
            painter.fillRect(QRectF(sx + ts * 0.26, sy + ts * 0.16, ts * 0.48, ts * 0.68), COLOR_RAIL_CROSS_WOOD)
            # Sleepers on shoulders
            painter.setPen(QPen(COLOR_RAIL_TIE, max(1.5, ts * 0.08)))
            painter.drawLine(QPointF(sx + ts * 0.24, sy + ts * 0.08), QPointF(sx + ts * 0.76, sy + ts * 0.08))
            painter.drawLine(QPointF(sx + ts * 0.24, sy + ts * 0.92), QPointF(sx + ts * 0.76, sy + ts * 0.92))
            # Dual steel rails crossing over the road
            track_pen = QPen(COLOR_RAIL_STEEL, max(1.2, ts * 0.07))
            painter.setPen(track_pen)
            painter.drawLine(QPointF(sx + ts * 0.35, sy), QPointF(sx + ts * 0.35, sy + ts))
            painter.drawLine(QPointF(sx + ts * 0.65, sy), QPointF(sx + ts * 0.65, sy + ts))
            # Yellow warning dashed lines on road approaches
            if ts >= 12:
                warn_pen = QPen(QColor("#ffd60a"), max(1.0, ts * 0.07), Qt.DotLine)
                painter.setPen(warn_pen)
                painter.drawLine(QPointF(sx + ts * 0.20, sy + ts * 0.18), QPointF(sx + ts * 0.20, sy + ts * 0.82))
                painter.drawLine(QPointF(sx + ts * 0.80, sy + ts * 0.18), QPointF(sx + ts * 0.80, sy + ts * 0.82))

    # --- Procedural Powerline Renderer ---

    def _is_wire_conductive(self, tx: int, ty: int) -> bool:
        if not (0 <= tx < 120 and 0 <= ty < 100) or not self._engine:
            return False
        raw = self._engine.fast_get_tile(tx, ty)
        t = raw & 0x03FF
        # Wire tiles
        if 208 <= t <= 223:
            return True
        # Crossings that carry wire
        if t in (77, 78, 239):
            return True
        # Powered buildings & developed zones
        if (240 <= t <= 692) or (693 <= t <= 826):
            return True
        return False

    def _get_wire_connections(self, t: int, tx: int, ty: int) -> tuple:
        # Expected orientation by tile ID
        WIRE_DIRS = {
            208: (False, True, False, True),   # H water bridge
            209: (True, False, True, False),   # V water bridge
            210: (False, True, False, True),   # H straight
            211: (True, False, True, False),   # V straight
            212: (True, True, False, False),   # NE
            213: (False, True, True, False),   # ES
            214: (False, False, True, True),   # SW
            215: (True, False, False, True),   # WN
            216: (True, True, False, True),    # NEW
            217: (True, True, True, False),    # NES
            218: (False, True, True, True),    # ESW
            219: (True, False, True, True),    # NSW
            220: (True, True, True, True),     # NESW
        }
        wn, we, ws, ww = WIRE_DIRS.get(t, (False, True, False, True))

        # Only connect in directions where infrastructure actually exists!
        conn_n = wn and self._is_wire_conductive(tx, ty - 1)
        conn_e = we and self._is_wire_conductive(tx + 1, ty)
        conn_s = ws and self._is_wire_conductive(tx, ty + 1)
        conn_w = ww and self._is_wire_conductive(tx - 1, ty)

        return conn_n, conn_e, conn_s, conn_w

    def _draw_wire(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        painter.fillRect(QRectF(sx, sy, ts + 0.5, ts + 0.5), COLOR_DIRT)

        conn_n, conn_e, conn_s, conn_w = self._get_wire_connections(t, tx, ty)

        cx = sx + ts * 0.5
        cy = sy + ts * 0.5

        # 1. High-voltage cables: sleek wires only to connected directions
        wire_pen = QPen(COLOR_WIRE_CABLE, max(1.2, ts * 0.07))
        painter.setPen(wire_pen)

        if conn_n:
            painter.drawLine(QPointF(cx, cy), QPointF(cx, sy))
        if conn_e:
            painter.drawLine(QPointF(cx, cy), QPointF(sx + ts, cy))
        if conn_s:
            painter.drawLine(QPointF(cx, cy), QPointF(cx, sy + ts))
        if conn_w:
            painter.drawLine(QPointF(cx, cy), QPointF(sx, cy))

        # 2. Central Utility Pole & Crossarm
        # Neat, subtle utility pole - NOT a giant protruding comb!
        pole_r = max(1.5, ts * 0.09)
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor(0, 0, 0, 60))
        painter.drawEllipse(QRectF(cx - pole_r * 0.8, cy - pole_r * 0.3, pole_r * 1.6, pole_r * 0.8))

        # Wooden Pole
        painter.setBrush(COLOR_WIRE_POLE)
        painter.drawEllipse(QRectF(cx - pole_r, cy - pole_r, pole_r * 2.0, pole_r * 2.0))

        # Only draw a small crossarm if this tile connects in a single straight line
        is_straight_v = (conn_n or conn_s) and not (conn_e or conn_w)
        is_straight_h = (conn_e or conn_w) and not (conn_n or conn_s)

        arm_w = max(2.5, ts * 0.16)
        arm_pen = QPen(COLOR_WIRE_ARM, max(1.2, ts * 0.07))
        painter.setPen(arm_pen)

        if is_straight_v:
            painter.drawLine(QPointF(cx - arm_w, cy), QPointF(cx + arm_w, cy))
            painter.setPen(Qt.NoPen)
            painter.setBrush(COLOR_WIRE_INSULATOR)
            painter.drawEllipse(QRectF(cx - arm_w - 1, cy - 1, 2.0, 2.0))
            painter.drawEllipse(QRectF(cx + arm_w - 1, cy - 1, 2.0, 2.0))
        elif is_straight_h:
            painter.drawLine(QPointF(cx, cy - arm_w), QPointF(cx, cy + arm_w))
            painter.setPen(Qt.NoPen)
            painter.setBrush(COLOR_WIRE_INSULATOR)
            painter.drawEllipse(QRectF(cx - 1, cy - arm_w - 1, 2.0, 2.0))
            painter.drawEllipse(QRectF(cx - 1, cy + arm_w - 1, 2.0, 2.0))

    def _draw_wire_water(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        # 208=HPOWER, 209=VPOWER: Transmission Tower in Water
        painter.fillRect(QRectF(sx, sy, ts + 0.5, ts + 0.5), COLOR_WATER)

        cx, cy = sx + ts * 0.5, sy + ts * 0.5

        # Water footing foundation
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_BRIDGE_CONCRETE)
        painter.drawRect(QRectF(cx - ts * 0.24, cy - ts * 0.24, ts * 0.48, ts * 0.48))

        # Steel lattice transmission pylon
        painter.setPen(QPen(COLOR_WIRE_PYLON, max(1.2, ts * 0.08)))
        painter.drawRect(QRectF(cx - ts * 0.16, cy - ts * 0.16, ts * 0.32, ts * 0.32))
        painter.drawLine(QPointF(cx - ts * 0.16, cy - ts * 0.16), QPointF(cx + ts * 0.16, cy + ts * 0.16))
        painter.drawLine(QPointF(cx + ts * 0.16, cy - ts * 0.16), QPointF(cx - ts * 0.16, cy + ts * 0.16))

        # Heavy high-voltage transmission cables
        cable_pen = QPen(COLOR_WIRE_CABLE, max(1.2, ts * 0.07))
        painter.setPen(cable_pen)
        if t == 208:  # Horizontal water span
            painter.drawLine(QPointF(sx, cy - ts * 0.12), QPointF(sx + ts, cy - ts * 0.12))
            painter.drawLine(QPointF(sx, cy + ts * 0.12), QPointF(sx + ts, cy + ts * 0.12))
        else:  # Vertical water span
            painter.drawLine(QPointF(cx - ts * 0.12, sy), QPointF(cx - ts * 0.12, sy + ts))
            painter.drawLine(QPointF(cx + ts * 0.12, sy), QPointF(cx + ts * 0.12, sy + ts))

        # Red aviation beacon on top
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#ff0000"))
        painter.drawEllipse(QRectF(cx - 1.5, cy - 1.5, 3.0, 3.0))

    def _draw_wire_crossing(self, painter: QPainter, crossing_t: int, sx: float, sy: float, ts: float):
        # 77 (HROADPOWER) & 221 (RAILHPOWERV): Horizontal Road/Rail, Vertical Overhead Wire
        # 78 (VROADPOWER) & 222 (RAILVPOWERH): Vertical Road/Rail, Horizontal Overhead Wire
        pole_pen = QPen(COLOR_WIRE_ARM, max(1.2, ts * 0.08))
        cable_pen = QPen(COLOR_WIRE_CABLE, max(1.2, ts * 0.07))

        if crossing_t in (77, 221):
            cx = sx + ts * 0.5
            # Roadside/trackside utility poles
            painter.setPen(pole_pen)
            painter.drawLine(QPointF(cx - ts * 0.12, sy + ts * 0.08), QPointF(cx + ts * 0.12, sy + ts * 0.08))
            painter.drawLine(QPointF(cx - ts * 0.12, sy + ts * 0.92), QPointF(cx + ts * 0.12, sy + ts * 0.92))
            # Overhead wire spanning vertically across
            painter.setPen(cable_pen)
            painter.drawLine(QPointF(cx, sy), QPointF(cx, sy + ts))
        else:
            cy = sy + ts * 0.5
            # Roadside utility poles on left and right
            painter.setPen(pole_pen)
            painter.drawLine(QPointF(sx + ts * 0.08, cy - ts * 0.12), QPointF(sx + ts * 0.08, cy + ts * 0.12))
            painter.drawLine(QPointF(sx + ts * 0.92, cy - ts * 0.12), QPointF(sx + ts * 0.92, cy + ts * 0.12))
            # Overhead wire spanning horizontally across
            painter.setPen(cable_pen)
            painter.drawLine(QPointF(sx, cy), QPointF(sx + ts, cy))

    # --- Commuter Trolley Controller & Renderer ---

    def _is_rail_tile(self, t: int) -> bool:
        return (224 <= t <= 238) or (t in (221, 222))

    def _update_trolley(self, dt: float):
        if not self._engine:
            return

        # 1. Check if engine sprite is active
        try:
            sprites = self._engine.get_sprites()
            train_sp = next((s for s in sprites if s.get('type') == 1), None)
            if train_sp:
                self._trolley['active'] = True
                tx = train_sp['x'] / 16.0
                ty = train_sp['y'] / 16.0
                if self._trolley['x'] < 0:
                    self._trolley['x'] = tx
                    self._trolley['y'] = ty
                else:
                    self._trolley['x'] += (tx - self._trolley['x']) * min(1.0, dt * 8.0)
                    self._trolley['y'] += (ty - self._trolley['y']) * min(1.0, dt * 8.0)
                dx = float(train_sp.get('x_offset', 1))
                dy = float(train_sp.get('y_offset', 0))
                if dx != 0 or dy != 0:
                    self._trolley['dir'] = (dx, dy)
                return
        except Exception:
            pass

        # 2. Autonomous rail cruiser along city tracks
        self._step_autonomous_trolley(dt)

    def _step_autonomous_trolley(self, dt: float):
        tx = int(math.floor(self._trolley['x']))
        ty = int(math.floor(self._trolley['y']))

        # If current position is invalid or not on rail, find a track
        if not (0 <= tx < 120 and 0 <= ty < 100) or not self._is_rail_tile(self._engine.fast_get_tile(tx, ty) & 0x03FF):
            found = False
            for y in range(0, 100, 2):
                for x in range(0, 120, 2):
                    t = self._engine.fast_get_tile(x, y) & 0x03FF
                    if self._is_rail_tile(t):
                        self._trolley['active'] = True
                        self._trolley['x'] = float(x) + 0.5
                        self._trolley['y'] = float(y) + 0.5
                        self._trolley['dir'] = (1.0, 0.0) if t in (224, 226) else (0.0, 1.0)
                        found = True
                        break
                if found:
                    break
            if not found:
                self._trolley['active'] = False
                return

        speed = self._trolley.get('speed', 2.4)  # tiles per second
        dx, dy = self._trolley['dir']
        prev_x = self._trolley['x']
        prev_y = self._trolley['y']
        next_x = prev_x + dx * speed * dt
        next_y = prev_y + dy * speed * dt

        cx = float(tx) + 0.5
        cy = float(ty) + 0.5

        # Check if crossed tile center
        crossed = False
        if dx > 0 and prev_x < cx <= next_x:
            crossed = True
        elif dx < 0 and prev_x > cx >= next_x:
            crossed = True
        elif dy > 0 and prev_y < cy <= next_y:
            crossed = True
        elif dy < 0 and prev_y > cy >= next_y:
            crossed = True

        if crossed:
            next_x = cx
            next_y = cy
            cur_t = self._engine.fast_get_tile(tx, ty) & 0x03FF
            self._trolley['dir'] = self._pick_next_rail_dir(tx, ty, cur_t, dx, dy)

        self._trolley['x'] = next_x
        self._trolley['y'] = next_y
        self._trolley['active'] = True

    def _pick_next_rail_dir(self, tx: int, ty: int, t: int, dx: float, dy: float) -> tuple:
        # Curves handling
        if t == 228:  # NE (North <-> East)
            if dy > 0:
                return (1.0, 0.0)
            elif dx < 0:
                return (0.0, -1.0)
        elif t == 229:  # ES (East <-> South)
            if dx < 0:
                return (0.0, 1.0)
            elif dy < 0:
                return (1.0, 0.0)
        elif t == 230:  # SW (South <-> West)
            if dy < 0:
                return (-1.0, 0.0)
            elif dx > 0:
                return (0.0, 1.0)
        elif t == 231:  # WN (West <-> North)
            if dx > 0:
                return (0.0, -1.0)
            elif dy > 0:
                return (-1.0, 0.0)

        # Straight check ahead
        ntx = tx + int(round(dx))
        nty = ty + int(round(dy))
        if 0 <= ntx < 120 and 0 <= nty < 100:
            if self._is_rail_tile(self._engine.fast_get_tile(ntx, nty) & 0x03FF):
                return (dx, dy)

        # Lateral branch check for junctions
        for ldx, ldy in [(-dy, dx), (dy, -dx)]:
            ltx = tx + int(round(ldx))
            lty = ty + int(round(ldy))
            if 0 <= ltx < 120 and 0 <= lty < 100:
                if self._is_rail_tile(self._engine.fast_get_tile(ltx, lty) & 0x03FF):
                    return (ldx, ldy)

        # Dead end: reverse direction!
        return (-dx, -dy)

    def _draw_trolley(self, painter: QPainter, ts: float, w: float, h: float):
        if not self._trolley.get('active', False):
            return

        tx = self._trolley['x']
        ty = self._trolley['y']
        sx = (tx - self._cam_x) * ts + w / 2.0
        sy = (ty - self._cam_y) * ts + h / 2.0

        # Margin culling
        if sx < -ts * 2 or sx > w + ts * 2 or sy < -ts * 2 or sy > h + ts * 2:
            return

        dx, dy = self._trolley['dir']
        angle = math.degrees(math.atan2(dy, dx))

        painter.save()
        painter.translate(sx, sy)
        painter.rotate(angle)

        trolley_len = max(8.0, ts * 0.78)
        trolley_wid = max(4.0, ts * 0.38)

        # 1. Warm Glowing Headlight Beam projecting forward
        light_len = ts * 1.5
        light_path = QPainterPath()
        light_path.moveTo(trolley_len * 0.5, 0)
        light_path.lineTo(trolley_len * 0.5 + light_len, -light_len * 0.35)
        light_path.lineTo(trolley_len * 0.5 + light_len, light_len * 0.35)
        light_path.closeSubpath()

        light_grad = QLinearGradient(trolley_len * 0.5, 0, trolley_len * 0.5 + light_len, 0)
        light_grad.setColorAt(0.0, QColor(255, 234, 0, 110))
        light_grad.setColorAt(1.0, QColor(255, 234, 0, 0))
        painter.setPen(Qt.NoPen)
        painter.setBrush(QBrush(light_grad))
        painter.drawPath(light_path)

        # 2. Trolley Red Body (Classic Streetcar)
        painter.setBrush(COLOR_TROLLEY_BODY)
        painter.setPen(QPen(QColor("#780000"), max(0.8, ts * 0.04)))
        painter.drawRoundedRect(
            QRectF(-trolley_len * 0.5, -trolley_wid * 0.5, trolley_len, trolley_wid),
            trolley_wid * 0.3, trolley_wid * 0.3
        )

        # 3. Cream Accent Stripe & Roof
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_TROLLEY_CREAM)
        painter.drawRoundedRect(
            QRectF(-trolley_len * 0.35, -trolley_wid * 0.28, trolley_len * 0.7, trolley_wid * 0.56),
            2.0, 2.0
        )

        # 4. Windows (Dark Blue-Grey Glass)
        painter.setBrush(COLOR_TROLLEY_WINDOW)
        # Front windshield
        painter.drawRect(QRectF(trolley_len * 0.26, -trolley_wid * 0.24, trolley_len * 0.12, trolley_wid * 0.48))
        # Side windows
        num_windows = 3
        for wi in range(num_windows):
            wx = -trolley_len * 0.28 + wi * (trolley_len * 0.2)
            painter.drawRect(QRectF(wx, -trolley_wid * 0.32, trolley_len * 0.12, trolley_wid * 0.14))
            painter.drawRect(QRectF(wx, trolley_wid * 0.18, trolley_len * 0.12, trolley_wid * 0.14))

        # 5. Roof Pantograph Collector
        painter.setPen(QPen(QColor("#495057"), max(1.0, ts * 0.05)))
        painter.drawLine(QPointF(-trolley_len * 0.08, 0), QPointF(0, -trolley_wid * 0.15))
        painter.drawLine(QPointF(0, -trolley_wid * 0.15), QPointF(trolley_len * 0.08, 0))

        # 6. Front Headlight Lamp
        painter.setPen(Qt.NoPen)
        painter.setBrush(COLOR_TROLLEY_LIGHT)
        painter.drawEllipse(QRectF(trolley_len * 0.48 - 1.5, -1.5, 3.0, 3.0))

        painter.restore()

    def _draw_residential_zone(self, painter: QPainter, raw: int, t: int, has_power: bool, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 1. Vacant Zoned Lot (Stage 0, tiles 240..248)
        if 240 <= t <= 248:
            if t == 244 or (raw & 0x0400):
                lot_rect = QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts)
                painter.fillRect(lot_rect, QColor("#dfc492"))
                painter.setPen(QPen(QColor("#a89066"), 1, Qt.DashLine))
                painter.setBrush(Qt.NoBrush)
                painter.drawRect(lot_rect)
                painter.setPen(QPen(QColor("#1e252b"), 2))
                painter.setFont(QFont("Arial", max(8, int(ts * 0.45)), QFont.Bold))
                painter.drawText(rect, Qt.AlignCenter, "R")
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 2. Stage 1: Single Houses (tiles 249..260)
        if 249 <= t <= 260:
            painter.fillRect(rect, QColor("#dfc492"))
            if self._house_sprites:
                h_idx = (t - 249) % len(self._house_sprites)
                painter.drawImage(QRectF(sx + 1, sy + 1, ts - 2, ts - 2), self._house_sprites[h_idx])
            else:
                painter.fillRect(QRectF(sx + ts * 0.15, sy + ts * 0.15, ts * 0.7, ts * 0.7), QColor("#37474f"))
            return

        # 3. Stages 2 to 5: 3x3 Unified Residential Buildings (tiles 261..404)
        if 261 <= t <= 404:
            bld_idx = (t - 261) // 9
            sub_idx = (t - 261) % 9
            if sub_idx == 4 or (raw & 0x0400):
                r = min(3, bld_idx // 4)  # Land value: 0..3 (Low, Med, High, Lux)
                c = min(3, bld_idx % 4)   # Density: 0..3 (Stage 2, 3, 4, 5)
                # If Stage 2 Luxury compound (r=3, c=0): draw the Mayor's Walled Estate!
                if r == 3 and c == 0 and "mayor" in self._civic_sprites:
                    sprite = self._civic_sprites["mayor"]
                else:
                    sprite = self._res_sprites_3x3.get((r, c))
                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), COLOR_RES_BASE)
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 4. Hospital / Temple (Otera) (tiles 405..413, center 409)
        if 405 <= t <= 413:
            if t == 409 or (raw & 0x0400):
                sprite = self._civic_sprites.get("temple") or self._res_sprites_3x3.get((4, 0))
                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), QColor("#b71c1c"))
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 5. Traditional Church / Shinto Shrine (tiles 414..422, center 418)
        if 414 <= t <= 422:
            if t == 418 or (raw & 0x0400):
                sprite = self._civic_sprites.get("shrine") or self._res_sprites_3x3.get((4, 2))
                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), QColor("#4a148c"))
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 6. Extended Churches / Shrines / Pavilions (tiles 956..1018)
        if 956 <= t <= 1018:
            sub_t = t - 956
            if sub_t % 9 == 4 or (raw & 0x0400):
                bld_var = sub_t // 9
                if bld_var == 0:
                    sprite = self._civic_sprites.get("pavilion")
                elif bld_var == 1:
                    sprite = self._civic_sprites.get("cathedral")
                elif bld_var % 2 == 0:
                    sprite = self._civic_sprites.get("shrine")
                else:
                    sprite = self._civic_sprites.get("temple")

                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                self._check_unpowered(painter, raw, has_power, rect)
            return


    def _draw_industrial_zone(self, painter: QPainter, raw: int, t: int, has_power: bool, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 1. Vacant Industrial Lot (Stage 0, tiles 612..620)
        if 612 <= t <= 620:
            if t == 616 or (raw & 0x0400):
                lot_rect = QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts)
                painter.fillRect(lot_rect, QColor("#c89f78"))
                painter.setPen(QPen(QColor("#9e7552"), 1, Qt.DashLine))
                painter.setBrush(Qt.NoBrush)
                painter.drawRect(lot_rect)
                painter.setPen(QPen(QColor("#ffe600"), 2))
                painter.setFont(QFont("Arial", max(8, int(ts * 0.45)), QFont.Bold))
                painter.drawText(rect, Qt.AlignCenter, "I")
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 2. Stages 1 to 4: 3x3 Industrial Buildings (tiles 621..692)
        if 621 <= t <= 692:
            bld_idx = (t - 621) // 9
            sub_idx = (t - 621) % 9
            if sub_idx == 4 or (raw & 0x0400):
                r = min(1, bld_idx // 4)  # 0: Standard, 1: High Value
                c = min(3, bld_idx % 4)   # 0: Storage, 1: Warehouse, 2: Factory, 3: Smelter
                sprite = self._ind_sprites_3x3.get((r, c))
                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), COLOR_IND_BASE)
                self._check_unpowered(painter, raw, has_power, rect)
            return

    def _draw_commercial_zone(self, painter: QPainter, raw: int, t: int, has_power: bool, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 1. Vacant Commercial Lot (Stage 0, tiles 423..431)
        if 423 <= t <= 431:
            if t == 427 or (raw & 0x0400):
                lot_rect = QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts)
                painter.fillRect(lot_rect, QColor("#8fa5b8"))
                painter.setPen(QPen(QColor("#607d8b"), 1, Qt.DashLine))
                painter.setBrush(Qt.NoBrush)
                painter.drawRect(lot_rect)
                painter.setPen(QPen(QColor("#1e252b"), 2))
                painter.setFont(QFont("Arial", max(8, int(ts * 0.45)), QFont.Bold))
                painter.drawText(rect, Qt.AlignCenter, "C")
                self._check_unpowered(painter, raw, has_power, rect)
            return

        # 2. Stages 1 to 5: 3x3 Commercial Buildings (tiles 432..611)
        if 432 <= t <= 611:
            bld_idx = (t - 432) // 9
            sub_idx = (t - 432) % 9
            if sub_idx == 4 or (raw & 0x0400):
                r = min(3, bld_idx // 5)  # Land value: 0..3 (Low, Med, High, Lux)
                c = min(4, bld_idx % 5)   # Density: 0..4 (Stage 1 to 5)
                sprite = self._com_sprites_3x3.get((r, c))
                if sprite:
                    painter.drawImage(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), sprite)
                else:
                    painter.fillRect(QRectF(sx - ts, sy - ts, 3 * ts, 3 * ts), COLOR_COM_BASE)
                self._check_unpowered(painter, raw, has_power, rect)
            return

    def _check_unpowered(self, painter: QPainter, raw: int, has_power: bool, rect: QRectF):


        """Draws a warning icon on unpowered zone center tiles."""
        if (raw & 0x0400) and not has_power:
            painter.setPen(QColor("#ff0000"))
            painter.drawText(rect, Qt.AlignTop | Qt.AlignRight, "⚡")


