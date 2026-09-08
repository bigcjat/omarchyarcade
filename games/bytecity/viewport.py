"""
Omarchy Arcade • ByteCity Top-Down 2D Viewport
High-performance QQuickPaintedItem rendering the 120x100 Micropolis tilemap.
Clean orthographic projection with pan, zoom, drag-to-build, and theme awareness.
"""

import sys
import math
from PySide6.QtCore import Qt, QPointF, QRectF, Signal, Property, Slot, QObject
from PySide6.QtGui import (
    QColor, QFont, QPainter, QPainterPath, QPen, QBrush, QCursor
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
COLOR_TREES = QColor("#2d6a4f")
COLOR_TREES_DARK = QColor("#1b4332")
COLOR_RUBBLE = QColor("#404040")
COLOR_FIRE = QColor("#e63946")
COLOR_ROAD = QColor("#2b2d42")
COLOR_ROAD_MARK = QColor("#f4a261")
COLOR_RAIL = QColor("#4a3b32")
COLOR_RAIL_LINE = QColor("#8d99ae")
COLOR_WIRE = QColor("#222222")
COLOR_WIRE_POST = QColor("#e9c46a")
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
            # Subtle earth grain texture
            if ts >= 16 and (tx + ty) % 3 == 0:
                painter.fillRect(QRectF(sx + ts * 0.3, sy + ts * 0.3, ts * 0.4, ts * 0.4), QColor("#7a633e"))
            return

        # 2. WATER (2..20)
        if 2 <= t <= 20:
            painter.fillRect(rect, COLOR_WATER)
            if ts >= 14 and (tx + ty) % 2 == 0:
                painter.fillRect(QRectF(sx + ts * 0.2, sy + ts * 0.4, ts * 0.6, ts * 0.15), QColor("#2b6cb0"))
            return

        # 3. TREES / WOODS (21..43)
        if 21 <= t <= 43:
            painter.fillRect(rect, COLOR_TREES)
            if ts >= 14:
                # Stylized tree canopies
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

        # 6. ROADS & BRIDGES (64..207)
        if 64 <= t <= 207:
            painter.fillRect(rect, COLOR_ROAD)
            # Road center lines
            if ts >= 12:
                painter.fillRect(QRectF(sx + ts * 0.4, sy + ts * 0.4, ts * 0.2, ts * 0.2), COLOR_ROAD_MARK)
            return

        # 7. POWER LINES (208..222)
        if 208 <= t <= 222:
            painter.fillRect(rect, COLOR_DIRT)
            # Pylon and wires
            painter.fillRect(QRectF(sx + ts * 0.42, sy + ts * 0.42, ts * 0.16, ts * 0.16), COLOR_WIRE_POST)
            painter.setPen(QPen(COLOR_WIRE, 1))
            painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
            painter.drawLine(QPointF(sx + ts * 0.5, sy), QPointF(sx + ts * 0.5, sy + ts))
            return

        # 8. RAILROADS (224..238)
        if 224 <= t <= 238:
            painter.fillRect(rect, COLOR_RAIL)
            painter.setPen(QPen(COLOR_RAIL_LINE, 2))
            painter.drawLine(QPointF(sx, sy + ts * 0.5), QPointF(sx + ts, sy + ts * 0.5))
            return

        # 9. RESIDENTIAL (240..422)
        if 240 <= t <= 422:
            painter.fillRect(rect, COLOR_RES_BASE)
            # Zone center tile indicator
            if raw & 0x0400 or t == 244:
                painter.setPen(QColor("#ffffff"))
                painter.drawText(rect, Qt.AlignCenter, "R")
            elif ts >= 16:
                # House roof pattern
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

    def _check_unpowered(self, painter: QPainter, raw: int, has_power: bool, rect: QRectF):
        """Draws a warning icon on unpowered zone center tiles."""
        if (raw & 0x0400) and not has_power:
            painter.setPen(QColor("#ff0000"))
            painter.drawText(rect, Qt.AlignTop | Qt.AlignRight, "⚡")
