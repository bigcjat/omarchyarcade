"""
Omarchy Arcade • ByteCity Top-Down 2D Viewport
High-performance QQuickPaintedItem rendering the 120x100 Micropolis tilemap.
Clean orthographic projection with pan, zoom, drag-to-build, and theme awareness.
"""

import sys
import math
from PySide6.QtCore import Qt, QPointF, QRectF, Signal, Property, Slot, QObject, QTimer
from PySide6.QtGui import (
    QColor, QFont, QPainter, QPainterPath, QPen, QBrush, QCursor, QRadialGradient, QLinearGradient
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

# Palette colors for 2D map
COLOR_WATER = QColor("#1e5799")
COLOR_WATER_DEEP = QColor("#164275")
COLOR_DIRT = QColor("#8d734a")
COLOR_DIRT_DARK = QColor("#7a633e")
COLOR_TREES = QColor("#2d6a4f")
COLOR_TREES_DARK = QColor("#1b4332")
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

        # Visible tile bounds
        left_t = self._cam_x - (w / (2.0 * ts))
        top_t = self._cam_y - (h / (2.0 * ts))

        min_tx = max(0, int(math.floor(left_t)))
        max_tx = min(120, int(math.ceil(left_t + w / ts)) + 1)
        min_ty = max(0, int(math.floor(top_t)))
        max_ty = min(100, int(math.ceil(top_t + h / ts)) + 1)

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

        # 1. DIRT / LAND (0, 1)
        if t <= 1:
            painter.fillRect(rect, COLOR_DIRT)
            if ts >= 16 and (tx + ty) % 3 == 0:
                painter.fillRect(QRectF(sx + ts * 0.3, sy + ts * 0.3, ts * 0.4, ts * 0.4), COLOR_DIRT_DARK)
            return

        # 2. WATER (2..20)
        if 2 <= t <= 20:
            painter.fillRect(rect, COLOR_WATER)
            if ts >= 14 and (tx + ty) % 2 == 0:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.4, ts * 0.6, ts * 0.15), COLOR_WATER_DEEP)
            return

        # 3. TREES / WOODS (21..43)
        if 21 <= t <= 43:
            painter.fillRect(rect, COLOR_TREES)
            if ts >= 14:
                painter.setPen(Qt.NoPen)
                painter.setBrush(COLOR_TREES_DARK)
                painter.drawEllipse(QRectF(sx + ts * 0.15, sy + ts * 0.15, ts * 0.7, ts * 0.7))
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

        # 9. RESIDENTIAL (240..422)
        if 240 <= t <= 422:
            painter.fillRect(rect, COLOR_RES_BASE)
            if raw & 0x0400 or t == 244:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "R")
            elif ts >= 16:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.2, ts * 0.6, ts * 0.6), QColor("#1b4332"))
            self._check_unpowered(painter, raw, has_power, rect)
            return

        # 10. COMMERCIAL (423..611)
        if 423 <= t <= 611:
            painter.fillRect(rect, COLOR_COM_BASE)
            if raw & 0x0400 or t == 427:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "C")
            elif ts >= 16:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.2, ts * 0.6, ts * 0.6), QColor("#023e8a"))
            self._check_unpowered(painter, raw, has_power, rect)
            return

        # 11. INDUSTRIAL (612..692)
        if 612 <= t <= 692:
            painter.fillRect(rect, COLOR_IND_BASE)
            if raw & 0x0400 or t == 616:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "I")
            elif ts >= 16:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.2, ts * 0.6, ts * 0.6), QColor("#7f4f24"))
            self._check_unpowered(painter, raw, has_power, rect)
            return

        # 12. SEAPORT (693..708)
        if 693 <= t <= 708:
            painter.fillRect(rect, COLOR_PORT)
            if raw & 0x0400:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "PORT")
            return

        # 13. AIRPORT (709..744)
        if 709 <= t <= 744:
            painter.fillRect(rect, COLOR_AIRPORT)
            if raw & 0x0400:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "AIR")
            return

        # 14. COAL POWER PLANT (745..760)
        if 745 <= t <= 760:
            painter.fillRect(rect, COLOR_COAL)
            if raw & 0x0400 or t == 750:
                painter.setPen(QColor("#ffba08"))
                painter.drawText(rect, Qt.AlignCenter, "COAL")
            return

        # 15. FIRE STATION (761..769)
        if 761 <= t <= 769:
            painter.fillRect(rect, COLOR_FIRE_DEPT)
            if raw & 0x0400 or t == 765:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "FIRE")
            self._check_unpowered(painter, raw, has_power, rect)
            return

        # 16. POLICE STATION (770..778)
        if 770 <= t <= 778:
            painter.fillRect(rect, COLOR_POLICE_DEPT)
            if raw & 0x0400 or t == 774:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "POL")
            self._check_unpowered(painter, raw, has_power, rect)
            return

        # 17. STADIUM (779..810)
        if 779 <= t <= 810:
            painter.fillRect(rect, COLOR_STADIUM)
            if raw & 0x0400 or t == 784:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "STAD")
            return

        # 18. NUCLEAR POWER PLANT (811..826)
        if 811 <= t <= 826:
            painter.fillRect(rect, COLOR_NUCLEAR)
            if raw & 0x0400 or t == 816:
                painter.setPen(QColor("#000000"))
                painter.drawText(rect, Qt.AlignCenter, "NUKE")
            return

        # 19. PARK / FOUNTAIN (840..843)
        if 840 <= t <= 843:
            painter.fillRect(rect, COLOR_PARK)
            painter.fillRect(QRectF(sx + ts * 0.3, sy + ts * 0.3, ts * 0.4, ts * 0.4), COLOR_WATER)
            return

        # Fallback tile rendering
        painter.fillRect(rect, COLOR_DIRT)

    # --- Procedural Road & Bridge Renderer ---

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
            self._draw_road_straight_h(painter, sx, sy, ts)
            self._draw_wire_crossing(painter, 77, sx, sy, ts)
            return

        # 78: VROADPOWER (Vertical Road with Horizontal Wire Crossing)
        if t == 78:
            self._draw_road_straight_v(painter, sx, sy, ts)
            self._draw_wire_crossing(painter, 78, sx, sy, ts)
            return

        # 66: Straight Horizontal Road
        if t == 66:
            self._draw_road_straight_h(painter, sx, sy, ts)
            return

        # 67: Straight Vertical Road
        if t == 67:
            self._draw_road_straight_v(painter, sx, sy, ts)
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
        self._draw_road_straight_h(painter, sx, sy, ts)

    def _draw_road_straight_h(self, painter: QPainter, sx: float, sy: float, ts: float):
        # Asphalt body
        painter.fillRect(QRectF(sx, sy + ts * 0.16, ts + 0.5, ts * 0.68), COLOR_ROAD)
        # Curbs
        painter.setPen(QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06)))
        painter.drawLine(QPointF(sx, sy + ts * 0.16), QPointF(sx + ts, sy + ts * 0.16))
        painter.drawLine(QPointF(sx, sy + ts * 0.84), QPointF(sx + ts, sy + ts * 0.84))
        # Dashed yellow lane
        if ts >= 10:
            painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
            painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))

    def _draw_road_straight_v(self, painter: QPainter, sx: float, sy: float, ts: float):
        # Asphalt body
        painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts + 0.5), COLOR_ROAD)
        # Curbs
        painter.setPen(QPen(COLOR_ROAD_CURB, max(1.0, ts * 0.06)))
        painter.drawLine(QPointF(sx + ts * 0.16, sy), QPointF(sx + ts * 0.16, sy + ts))
        painter.drawLine(QPointF(sx + ts * 0.84, sy), QPointF(sx + ts * 0.84, sy + ts))
        # Dashed yellow lane
        if ts >= 10:
            painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
            painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts))

    def _draw_road_curve(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # Corner curves: 68=NE, 69=ES, 70=SW, 71=WN
        # Draw central junction and the two arms
        painter.fillRect(QRectF(sx + ts * 0.16, sy + ts * 0.16, ts * 0.68, ts * 0.68), COLOR_ROAD)

        cx, cy = sx + ts * 0.5, sy + ts * 0.5
        arc_path = QPainterPath()

        if t == 68:  # North & East
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts * 0.5), COLOR_ROAD)
            painter.fillRect(QRectF(cx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            arc_path.moveTo(cx, sy)
            arc_path.quadTo(cx, cy, sx + ts, cy)
        elif t == 69:  # East & South
            painter.fillRect(QRectF(cx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            painter.fillRect(QRectF(sx + ts * 0.16, cy, ts * 0.68, ts * 0.5), COLOR_ROAD)
            arc_path.moveTo(sx + ts, cy)
            arc_path.quadTo(cx, cy, cx, sy + ts)
        elif t == 70:  # South & West
            painter.fillRect(QRectF(sx + ts * 0.16, cy, ts * 0.68, ts * 0.5), COLOR_ROAD)
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            arc_path.moveTo(cx, sy + ts)
            arc_path.quadTo(cx, cy, sx, cy)
        elif t == 71:  # West & North
            painter.fillRect(QRectF(sx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
            painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts * 0.5), COLOR_ROAD)
            arc_path.moveTo(sx, cy)
            arc_path.quadTo(cx, cy, cx, sy)

        # Curved dashed yellow lane
        if ts >= 12:
            painter.setPen(QPen(COLOR_ROAD_LANE, max(1.0, ts * 0.08), Qt.DashLine))
            painter.drawPath(arc_path)

    def _draw_road_t_junction(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # 72=NEW, 73=NES, 74=ESW, 75=NSW
        cx, cy = sx + ts * 0.5, sy + ts * 0.5
        stop_pen = QPen(COLOR_ROAD_STOP, max(1.5, ts * 0.09))

        if t in (72, 74):  # Main road is Horizontal
            self._draw_road_straight_h(painter, sx, sy, ts)
            if t == 72:  # Stem goes North
                painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts * 0.5), COLOR_ROAD)
                painter.setPen(stop_pen)
                painter.drawLine(QPointF(sx + ts * 0.2, sy + ts * 0.2), QPointF(sx + ts * 0.8, sy + ts * 0.2))
            else:  # 74: Stem goes South
                painter.fillRect(QRectF(sx + ts * 0.16, cy, ts * 0.68, ts * 0.5), COLOR_ROAD)
                painter.setPen(stop_pen)
                painter.drawLine(QPointF(sx + ts * 0.2, sy + ts * 0.8), QPointF(sx + ts * 0.8, sy + ts * 0.8))
        else:  # Main road is Vertical (73, 75)
            self._draw_road_straight_v(painter, sx, sy, ts)
            if t == 73:  # Stem goes East
                painter.fillRect(QRectF(cx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
                painter.setPen(stop_pen)
                painter.drawLine(QPointF(sx + ts * 0.8, sy + ts * 0.2), QPointF(sx + ts * 0.8, sy + ts * 0.8))
            else:  # 75: Stem goes West
                painter.fillRect(QRectF(sx, sy + ts * 0.16, ts * 0.5, ts * 0.68), COLOR_ROAD)
                painter.setPen(stop_pen)
                painter.drawLine(QPointF(sx + ts * 0.2, sy + ts * 0.2), QPointF(sx + ts * 0.2, sy + ts * 0.8))

    def _draw_road_intersection(self, painter: QPainter, sx: float, sy: float, ts: float):
        # 76: 4-Way Intersection
        painter.fillRect(QRectF(sx, sy + ts * 0.16, ts + 0.5, ts * 0.68), COLOR_ROAD)
        painter.fillRect(QRectF(sx + ts * 0.16, sy, ts * 0.68, ts + 0.5), COLOR_ROAD)

        # Crosswalks on each entrance
        if ts >= 14:
            cw_pen = QPen(COLOR_ROAD_STOP, max(1.0, ts * 0.05), Qt.SolidLine)
            painter.setPen(cw_pen)
            # North crosswalk
            for i in range(3):
                xx = sx + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(xx, sy + ts * 0.05), QPointF(xx, sy + ts * 0.14))
            # South crosswalk
            for i in range(3):
                xx = sx + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(xx, sy + ts * 0.86), QPointF(xx, sy + ts * 0.95))
            # West crosswalk
            for i in range(3):
                yy = sy + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(sx + ts * 0.05, yy), QPointF(sx + ts * 0.14, yy))
            # East crosswalk
            for i in range(3):
                yy = sy + ts * (0.28 + i * 0.16)
                painter.drawLine(QPointF(sx + ts * 0.86, yy), QPointF(sx + ts * 0.95, yy))

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

    def _draw_rail(self, painter: QPainter, t: int, sx: float, sy: float, ts: float, tx: int, ty: int):
        rect = QRectF(sx, sy, ts + 0.5, ts + 0.5)

        # 224: Horizontal Rail Bridge over Water
        if t == 224:
            painter.fillRect(rect, COLOR_WATER)
            # Heavy timber bridge beams
            painter.fillRect(QRectF(sx, sy + ts * 0.18, ts + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            self._draw_rail_straight_h(painter, sx, sy, ts)
            # Steel bridge guardrails
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.06)))
            painter.drawLine(QPointF(sx, sy + ts * 0.18), QPointF(sx + ts, sy + ts * 0.18))
            painter.drawLine(QPointF(sx, sy + ts * 0.82), QPointF(sx + ts, sy + ts * 0.82))
            return

        # 225: Vertical Rail Bridge over Water
        if t == 225:
            painter.fillRect(rect, COLOR_WATER)
            painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts + 0.5), COLOR_RAIL_BALLAST)
            self._draw_rail_straight_v(painter, sx, sy, ts)
            painter.setPen(QPen(COLOR_BRIDGE_BARRIER, max(1.0, ts * 0.06)))
            painter.drawLine(QPointF(sx + ts * 0.18, sy), QPointF(sx + ts * 0.18, sy + ts))
            painter.drawLine(QPointF(sx + ts * 0.82, sy), QPointF(sx + ts * 0.82, sy + ts))
            return

        # Land Rail Tiles
        painter.fillRect(rect, COLOR_DIRT)

        # 226: Straight Horizontal Rail
        if t == 226:
            self._draw_rail_straight_h(painter, sx, sy, ts)
            return

        # 227: Straight Vertical Rail
        if t == 227:
            self._draw_rail_straight_v(painter, sx, sy, ts)
            return

        # Curves (228..231)
        if 228 <= t <= 231:
            self._draw_rail_curve(painter, t, sx, sy, ts)
            return

        # Junctions (232..236)
        if 232 <= t <= 236:
            self._draw_rail_junction(painter, t, sx, sy, ts)
            return

        self._draw_rail_straight_h(painter, sx, sy, ts)

    def _draw_rail_straight_h(self, painter: QPainter, sx: float, sy: float, ts: float):
        # Ballast gravel bed
        painter.fillRect(QRectF(sx, sy + ts * 0.18, ts + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)

        # Wooden sleepers (ties) spaced along tile
        tie_w = max(1.5, ts * 0.09)
        tie_pen = QPen(COLOR_RAIL_TIE, tie_w)
        painter.setPen(tie_pen)
        num_ties = max(3, int(ts / 5.5))
        for i in range(num_ties):
            tx_pos = sx + ts * ((i + 0.5) / num_ties)
            painter.drawLine(QPointF(tx_pos, sy + ts * 0.22), QPointF(tx_pos, sy + ts * 0.78))

        # Dual parallel steel tracks
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        y1 = sy + ts * 0.35
        y2 = sy + ts * 0.65
        painter.setPen(track_dark)
        painter.drawLine(QPointF(sx, y1), QPointF(sx + ts, y1))
        painter.drawLine(QPointF(sx, y2), QPointF(sx + ts, y2))
        painter.setPen(track_light)
        painter.drawLine(QPointF(sx, y1 - 0.5), QPointF(sx + ts, y1 - 0.5))
        painter.drawLine(QPointF(sx, y2 - 0.5), QPointF(sx + ts, y2 - 0.5))

    def _draw_rail_straight_v(self, painter: QPainter, sx: float, sy: float, ts: float):
        # Ballast gravel bed
        painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts + 0.5), COLOR_RAIL_BALLAST)

        # Wooden sleepers (ties) spaced vertically
        tie_h = max(1.5, ts * 0.09)
        tie_pen = QPen(COLOR_RAIL_TIE, tie_h)
        painter.setPen(tie_pen)
        num_ties = max(3, int(ts / 5.5))
        for i in range(num_ties):
            ty_pos = sy + ts * ((i + 0.5) / num_ties)
            painter.drawLine(QPointF(sx + ts * 0.22, ty_pos), QPointF(sx + ts * 0.78, ty_pos))

        # Dual parallel steel tracks
        track_dark = QPen(COLOR_RAIL_STEEL_DARK, max(1.5, ts * 0.08))
        track_light = QPen(COLOR_RAIL_STEEL, max(1.0, ts * 0.05))

        x1 = sx + ts * 0.35
        x2 = sx + ts * 0.65
        painter.setPen(track_dark)
        painter.drawLine(QPointF(x1, sy), QPointF(x1, sy + ts))
        painter.drawLine(QPointF(x2, sy), QPointF(x2, sy + ts))
        painter.setPen(track_light)
        painter.drawLine(QPointF(x1 - 0.5, sy), QPointF(x1 - 0.5, sy + ts))
        painter.drawLine(QPointF(x2 - 0.5, sy), QPointF(x2 - 0.5, sy + ts))

    def _draw_rail_curve(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        cx, cy = sx + ts * 0.5, sy + ts * 0.5
        # Ballast in corner
        painter.fillRect(QRectF(sx + ts * 0.18, sy + ts * 0.18, ts * 0.64, ts * 0.64), COLOR_RAIL_BALLAST)

        # Draw arms and curved tracks
        track_pen = QPen(COLOR_RAIL_STEEL, max(1.2, ts * 0.07))
        painter.setPen(track_pen)

        p1 = QPainterPath()
        p2 = QPainterPath()

        if t == 228:  # NE
            painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts * 0.5), COLOR_RAIL_BALLAST)
            painter.fillRect(QRectF(cx, sy + ts * 0.18, ts * 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            p1.moveTo(sx + ts * 0.35, sy)
            p1.quadTo(sx + ts * 0.35, sy + ts * 0.35, sx + ts, sy + ts * 0.35)
            p2.moveTo(sx + ts * 0.65, sy)
            p2.quadTo(sx + ts * 0.65, sy + ts * 0.65, sx + ts, sy + ts * 0.65)
        elif t == 229:  # ES
            painter.fillRect(QRectF(cx, sy + ts * 0.18, ts * 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            painter.fillRect(QRectF(sx + ts * 0.18, cy, ts * 0.64, ts * 0.5), COLOR_RAIL_BALLAST)
            p1.moveTo(sx + ts, sy + ts * 0.35)
            p1.quadTo(sx + ts * 0.65, sy + ts * 0.35, sx + ts * 0.65, sy + ts)
            p2.moveTo(sx + ts, sy + ts * 0.65)
            p2.quadTo(sx + ts * 0.35, sy + ts * 0.65, sx + ts * 0.35, sy + ts)
        elif t == 230:  # SW
            painter.fillRect(QRectF(sx + ts * 0.18, cy, ts * 0.64, ts * 0.5), COLOR_RAIL_BALLAST)
            painter.fillRect(QRectF(sx, sy + ts * 0.18, ts * 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            p1.moveTo(sx + ts * 0.65, sy + ts)
            p1.quadTo(sx + ts * 0.65, sy + ts * 0.65, sx, sy + ts * 0.65)
            p2.moveTo(sx + ts * 0.35, sy + ts)
            p2.quadTo(sx + ts * 0.35, sy + ts * 0.35, sx, sy + ts * 0.35)
        elif t == 231:  # WN
            painter.fillRect(QRectF(sx, sy + ts * 0.18, ts * 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
            painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts * 0.5), COLOR_RAIL_BALLAST)
            p1.moveTo(sx, sy + ts * 0.65)
            p1.quadTo(sx + ts * 0.35, sy + ts * 0.65, sx + ts * 0.35, sy)
            p2.moveTo(sx, sy + ts * 0.35)
            p2.quadTo(sx + ts * 0.65, sy + ts * 0.35, sx + ts * 0.65, sy)

        painter.drawPath(p1)
        painter.drawPath(p2)

    def _draw_rail_junction(self, painter: QPainter, t: int, sx: float, sy: float, ts: float):
        # Full ballast junction
        painter.fillRect(QRectF(sx + ts * 0.18, sy, ts * 0.64, ts + 0.5), COLOR_RAIL_BALLAST)
        painter.fillRect(QRectF(sx, sy + ts * 0.18, ts + 0.5, ts * 0.64), COLOR_RAIL_BALLAST)
        self._draw_rail_straight_h(painter, sx, sy, ts)
        self._draw_rail_straight_v(painter, sx, sy, ts)

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
            # Road warning line on approaches
            if ts >= 12:
                painter.setPen(QPen(COLOR_ROAD_STOP, max(1.0, ts * 0.06)))
                painter.drawLine(QPointF(sx + ts * 0.22, sy + ts * 0.12), QPointF(sx + ts * 0.78, sy + ts * 0.12))
                painter.drawLine(QPointF(sx + ts * 0.22, sy + ts * 0.88), QPointF(sx + ts * 0.78, sy + ts * 0.88))
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
            # Road warning line on approaches
            if ts >= 12:
                painter.setPen(QPen(COLOR_ROAD_STOP, max(1.0, ts * 0.06)))
                painter.drawLine(QPointF(sx + ts * 0.12, sy + ts * 0.22), QPointF(sx + ts * 0.12, sy + ts * 0.78))
                painter.drawLine(QPointF(sx + ts * 0.88, sy + ts * 0.22), QPointF(sx + ts * 0.88, sy + ts * 0.78))

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

        # High-voltage wires: only drawn to valid connections!
        wire_pen = QPen(COLOR_WIRE_CABLE, max(1.0, ts * 0.06))
        painter.setPen(wire_pen)

        if conn_n:
            painter.drawLine(QPointF(cx, cy), QPointF(cx, sy))
        if conn_e:
            painter.drawLine(QPointF(cx, cy), QPointF(sx + ts, cy))
        if conn_s:
            painter.drawLine(QPointF(cx, cy), QPointF(cx, sy + ts))
        if conn_w:
            painter.drawLine(QPointF(cx, cy), QPointF(sx, cy))

        # Central Utility Pole & Crossarm
        pole_r = max(2.0, ts * 0.12)
        painter.setPen(Qt.NoPen)
        # Pole base shadow
        painter.setBrush(QColor(0, 0, 0, 70))
        painter.drawEllipse(QRectF(cx - pole_r * 0.8, cy - pole_r * 0.3, pole_r * 1.6, pole_r * 0.9))

        # Wooden Pole
        painter.setBrush(COLOR_WIRE_POLE)
        painter.drawEllipse(QRectF(cx - pole_r, cy - pole_r, pole_r * 2.0, pole_r * 2.0))

        # Crossarm perpendicular to line orientation
        is_predom_v = (conn_n or conn_s) and not (conn_e or conn_w)
        arm_pen = QPen(COLOR_WIRE_ARM, max(1.5, ts * 0.1))
        painter.setPen(arm_pen)
        if is_predom_v:
            painter.drawLine(QPointF(cx - ts * 0.22, cy), QPointF(cx + ts * 0.22, cy))
            # Ceramic insulators
            painter.setPen(Qt.NoPen)
            painter.setBrush(COLOR_WIRE_INSULATOR)
            painter.drawEllipse(QRectF(cx - ts * 0.24, cy - 1.5, 3.0, 3.0))
            painter.drawEllipse(QRectF(cx + ts * 0.16, cy - 1.5, 3.0, 3.0))
        else:
            painter.drawLine(QPointF(cx, cy - ts * 0.22), QPointF(cx, cy + ts * 0.22))
            painter.setPen(Qt.NoPen)
            painter.setBrush(COLOR_WIRE_INSULATOR)
            painter.drawEllipse(QRectF(cx - 1.5, cy - ts * 0.24, 3.0, 3.0))
            painter.drawEllipse(QRectF(cx - 1.5, cy + ts * 0.16, 3.0, 3.0))

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
        pole_pen = QPen(COLOR_WIRE_ARM, max(1.5, ts * 0.1))
        cable_pen = QPen(COLOR_WIRE_CABLE, max(1.2, ts * 0.07))

        if crossing_t in (77, 221):
            cx = sx + ts * 0.5
            # Roadside/trackside utility poles
            painter.setPen(pole_pen)
            painter.drawLine(QPointF(cx - ts * 0.15, sy + ts * 0.1), QPointF(cx + ts * 0.15, sy + ts * 0.1))
            painter.drawLine(QPointF(cx - ts * 0.15, sy + ts * 0.9), QPointF(cx + ts * 0.15, sy + ts * 0.9))
            # Overhead wire spanning vertically across
            painter.setPen(cable_pen)
            painter.drawLine(QPointF(cx, sy), QPointF(cx, sy + ts))
        else:
            cy = sy + ts * 0.5
            # Roadside utility poles on left and right
            painter.setPen(pole_pen)
            painter.drawLine(QPointF(sx + ts * 0.1, cy - ts * 0.15), QPointF(sx + ts * 0.1, cy + ts * 0.15))
            painter.drawLine(QPointF(sx + ts * 0.9, cy - ts * 0.15), QPointF(sx + ts * 0.9, cy + ts * 0.15))
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

    def _check_unpowered(self, painter: QPainter, raw: int, has_power: bool, rect: QRectF):
        """Draws a warning icon on unpowered zone center tiles."""
        if (raw & 0x0400) and not has_power:
            painter.setPen(QColor("#ff0000"))
            painter.drawText(rect, Qt.AlignTop | Qt.AlignRight, "⚡")

