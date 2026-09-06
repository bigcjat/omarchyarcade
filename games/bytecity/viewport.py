import math
import random
from PySide6.QtCore import Qt, QPointF, QRectF, Signal, Property, Slot, QObject, QTimer
from PySide6.QtGui import (
    QColor, QFont, QLinearGradient, QPainter, QPainterPath, QPen, QPolygonF, QCursor
)
from PySide6.QtQuick import QQuickPaintedItem

# Tool footprint sizes (width in tiles)
TOOL_FOOTPRINTS = {
    -1: 1, # Hand
    7: 1,  # Bulldozer
    9: 1,  # Road
    6: 1,  # Wire
    8: 1,  # Rail
    11: 1, # Park
    0: 3,  # Residential
    1: 3,  # Commercial
    2: 3,  # Industrial
    3: 3,  # Fire
    4: 3,  # Police
    10: 4, # Stadium
    12: 4, # Seaport
    13: 4, # Coal
    14: 4, # Nuclear
    15: 6, # Airport
}

TOOL_COSTS = {
    -1: 0,
    7: 1,
    9: 10,
    6: 5,
    8: 20,
    11: 10,
    0: 100,
    1: 100,
    2: 100,
    3: 500,
    4: 500,
    10: 5000,
    12: 3000,
    13: 3000,
    14: 5000,
    15: 10000,
}

class CityViewport(QQuickPaintedItem):
    hoverChanged = Signal(int, int)
    toolApplied = Signal(int, int, int, int)
    cameraChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptedMouseButtons(Qt.LeftButton | Qt.RightButton | Qt.MiddleButton)
        self.setAcceptHoverEvents(True)
        self.setAntialiasing(True)
        self.setFlag(QQuickPaintedItem.ItemHasContents, True)
        self.setFlag(QQuickPaintedItem.ItemIsFocusScope, True)

        self._engine = None
        self._selected_tool = 9 # Default: Road; -1 = Hand
        self._zoom = 1.0
        self._cam_x = 0.0
        self._cam_y = 0.0

        # Interaction state
        self._dragging = False
        self._tool_dragging = False
        self._last_applied_gx = -1
        self._last_applied_gy = -1
        self._space_held = False
        self._keys_down = set()
        self._last_mouse_pos = QPointF(0, 0)
        self._hover_x = -1
        self._hover_y = -1

        # Smooth keyboard pan timer (~60fps)
        self._pan_timer = QTimer(self)
        self._pan_timer.setInterval(16)
        self._pan_timer.timeout.connect(self._on_pan_tick)

        # Pulse animation timer for unpowered ⚡, traffic, trains, beacons, and steam (20 fps smooth)
        self._anim_phase = 0.0
        self._anim_timer = QTimer(self)
        self._anim_timer.setInterval(50)
        self._anim_timer.timeout.connect(self._on_anim_tick)
        self._anim_timer.start()

        # Moving Traffic & Train Simulation
        self._traffic_cars = []  # list of active vehicles on roads
        self._train_cars = []    # active train carriages on rails
        self._traffic_spawn_timer = 0
        self._train_spawn_timer = 0

        # 2.5D Dimetric Isometric Base Tile Dimensions
        self._base_tw = 64.0
        self._base_th = 32.0

        # Authentic Retro Colors applied to 2.5D Isometric
        self._col_bg = QColor("#11111b")
        self._col_grass = QColor("#3d6634")
        self._col_grass_grid = QColor("#33552b")
        self._col_grass_fleck = QColor("#46733c")

        self._col_water_deep = QColor("#16304d")
        self._col_water_mid = QColor("#1e4064")
        self._col_water_wave = QColor("#2d5580")

        self._col_road = QColor("#363a4f")
        self._col_road_border = QColor("#181825")
        self._col_road_dash = QColor("#f9e2af")
        self._col_rail = QColor("#b47846")

        self._col_wire_pole = QColor("#8c6239")
        self._col_wire_line = QColor("#fab387")

        # 3D Building Colors
        self._col_res = QColor("#528857")
        self._col_com = QColor("#477599")
        self._col_ind = QColor("#996e47")
        self._col_civic = QColor("#70598f")

        self._update_cursor()

    def _on_anim_tick(self):
        self._anim_phase += 0.05
        if self._anim_phase > 1000.0:
            self._anim_phase = 0.0
        self._update_traffic()
        self._update_train()
        self.update()

    def _update_cursor(self):
        if self._space_held or self._selected_tool == -1:
            if self._dragging:
                self.setCursor(QCursor(Qt.ClosedHandCursor))
            else:
                self.setCursor(QCursor(Qt.OpenHandCursor))
        else:
            self.setCursor(QCursor(Qt.CrossCursor))

    # --- Engine Property ---
    def get_engine(self):
        return self._engine

    def set_engine(self, eng):
        if self._engine != eng:
            if self._engine:
                try:
                    self._engine.mapChanged.disconnect(self.update)
                except Exception:
                    pass
            self._engine = eng
            if self._engine:
                try:
                    self._engine.mapChanged.connect(self.update)
                except Exception:
                    pass
                self.center_on_map()
            self.update()

    engine = Property(QObject, get_engine, set_engine)

    def get_tool(self):
        return self._selected_tool

    def set_tool(self, t):
        if self._selected_tool != t:
            self._selected_tool = t
            self._update_cursor()
            self.update()

    selectedTool = Property(int, get_tool, set_tool)

    def get_zoom(self):
        return self._zoom

    def set_zoom(self, z):
        z = max(0.4, min(3.0, z))
        if self._zoom != z:
            self._zoom = z
            self.update()
            self.cameraChanged.emit()

    zoom = Property(float, get_zoom, set_zoom)

    # --- 2.5D Dimetric Isometric Coordinate Transforms ---
    def world_to_screen(self, gx, gy, gz=0.0):
        tw = self._base_tw * self._zoom
        th = self._base_th * self._zoom
        sx = self._cam_x + (gx - gy) * (tw / 2.0)
        sy = self._cam_y + (gx + gy) * (th / 2.0) - (gz * th)
        return sx, sy

    @Slot(float, float, result=list)
    def screen_to_world(self, sx, sy):
        tw = self._base_tw * self._zoom
        th = self._base_th * self._zoom
        dx = (sx - self._cam_x) / (tw / 2.0)
        dy = (sy - self._cam_y) / (th / 2.0)
        gx = (dx + dy) / 2.0
        gy = (dy - dx) / 2.0
        return [int(math.floor(gx)), int(math.floor(gy))]

    @Slot()
    def center_on_map(self):
        w = self.width() if self.width() > 0 else 1200
        h = self.height() if self.height() > 0 else 800
        tw = self._base_tw * self._zoom
        th = self._base_th * self._zoom
        self._cam_x = (w / 2.0) - (5.0 * tw)
        self._cam_y = (h / 2.0) - (55.0 * th)
        self.update()
        self.cameraChanged.emit()

    @Slot(int, int)
    def pan_to_tile(self, gx, gy):
        w = self.width() if self.width() > 0 else 1200
        h = self.height() if self.height() > 0 else 800
        tw = self._base_tw * self._zoom
        th = self._base_th * self._zoom
        self._cam_x = (w / 2.0) - (gx - gy) * (tw / 2.0)
        self._cam_y = (h / 2.0) - (gx + gy) * (th / 2.0)
        self.update()
        self.cameraChanged.emit()

    # --- Keyboard Panning ---
    def _on_pan_tick(self):
        step = 18.0
        changed = False
        if Qt.Key_Left in self._keys_down or Qt.Key_A in self._keys_down or Qt.Key_H in self._keys_down:
            self._cam_x += step
            changed = True
        if Qt.Key_Right in self._keys_down or Qt.Key_D in self._keys_down or Qt.Key_L in self._keys_down:
            self._cam_x -= step
            changed = True
        if Qt.Key_Up in self._keys_down or Qt.Key_W in self._keys_down or Qt.Key_K in self._keys_down:
            self._cam_y += step
            changed = True
        if Qt.Key_Down in self._keys_down or Qt.Key_S in self._keys_down or Qt.Key_J in self._keys_down:
            self._cam_y -= step
            changed = True

        if changed:
            self.update()
            self.cameraChanged.emit()

    def keyPressEvent(self, event):
        key = event.key()
        if key in (Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down,
                   Qt.Key_W, Qt.Key_A, Qt.Key_S, Qt.Key_D,
                   Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L):
            self._keys_down.add(key)
            if not self._pan_timer.isActive():
                self._pan_timer.start()
            event.accept()
            return
        elif key == Qt.Key_Space:
            self._space_held = True
            self._update_cursor()
            event.accept()
            return
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        key = event.key()
        if key in self._keys_down:
            self._keys_down.discard(key)
            if not self._keys_down:
                self._pan_timer.stop()
            event.accept()
            return
        elif key == Qt.Key_Space:
            self._space_held = False
            self._update_cursor()
            event.accept()
            return
        super().keyReleaseEvent(event)

    # --- Mouse Events ---
    def mousePressEvent(self, event):
        self.forceActiveFocus()
        is_drag_btn = event.button() in (Qt.RightButton, Qt.MiddleButton)
        is_pan_tool = (self._selected_tool == -1)
        
        if is_drag_btn or is_pan_tool or self._space_held:
            self._dragging = True
            self._last_mouse_pos = event.position()
            self.setKeepMouseGrab(True)
            self._update_cursor()
            event.accept()
            return
        elif event.button() == Qt.LeftButton:
            res = self.screen_to_world(event.position().x(), event.position().y())
            gx, gy = res[0], res[1]
            if 0 <= gx < 120 and 0 <= gy < 100:
                if self._engine:
                    tool_res = self._engine.apply_tool(self._selected_tool, gx, gy)
                    self.toolApplied.emit(self._selected_tool, gx, gy, tool_res)
                    self._last_applied_gx = gx
                    self._last_applied_gy = gy
                    self._tool_dragging = True
                    self.setKeepMouseGrab(True)
                    self.update()
            event.accept()

    def mouseMoveEvent(self, event):
        if self._dragging:
            delta = event.position() - self._last_mouse_pos
            self._cam_x += delta.x()
            self._cam_y += delta.y()
            self._last_mouse_pos = event.position()
            self.update()
            self.cameraChanged.emit()
            event.accept()
        elif self._tool_dragging and self._engine and self._selected_tool != -1:
            res = self.screen_to_world(event.position().x(), event.position().y())
            gx, gy = res[0], res[1]
            if 0 <= gx < 120 and 0 <= gy < 100:
                if gx != self._last_applied_gx or gy != self._last_applied_gy:
                    tool_res = self._engine.apply_tool(self._selected_tool, gx, gy)
                    self.toolApplied.emit(self._selected_tool, gx, gy, tool_res)
                    self._last_applied_gx = gx
                    self._last_applied_gy = gy
                    self.update()
            event.accept()

    def mouseReleaseEvent(self, event):
        if self._dragging:
            self._dragging = False
            self.setKeepMouseGrab(False)
            self._update_cursor()
            event.accept()
        if self._tool_dragging:
            self._tool_dragging = False
            self.setKeepMouseGrab(False)
            self._last_applied_gx = -1
            self._last_applied_gy = -1
            event.accept()

    def hoverMoveEvent(self, event):
        pos = event.position()
        res = self.screen_to_world(pos.x(), pos.y())
        gx, gy = res[0], res[1]
        if gx != self._hover_x or gy != self._hover_y:
            self._hover_x = gx
            self._hover_y = gy
            self.hoverChanged.emit(gx, gy)
            self.update()
        event.accept()

    def hoverEnterEvent(self, event):
        pos = event.position()
        res = self.screen_to_world(pos.x(), pos.y())
        self._hover_x = res[0]
        self._hover_y = res[1]
        self.update()
        event.accept()

    def hoverLeaveEvent(self, event):
        self._hover_x = -1
        self._hover_y = -1
        self.update()
        event.accept()

    def wheelEvent(self, event):
        pos = event.position()
        old_zoom = self._zoom
        delta = event.angleDelta().y()
        factor = 1.15 if delta > 0 else (1.0 / 1.15)
        new_zoom = max(0.4, min(3.0, old_zoom * factor))
        
        if new_zoom != old_zoom:
            mouse_x = pos.x()
            mouse_y = pos.y()
            self._cam_x = mouse_x - (mouse_x - self._cam_x) * (new_zoom / old_zoom)
            self._cam_y = mouse_y - (mouse_y - self._cam_y) * (new_zoom / old_zoom)
            self._zoom = new_zoom
            self.update()
            self.cameraChanged.emit()
        event.accept()

    # --- 2.5D Dimetric Isometric Painting ---
    def paint(self, painter: QPainter):
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.fillRect(QRectF(0, 0, self.width(), self.height()), self._col_bg)

        if not self._engine or not self._engine._handle:
            return

        tw = self._base_tw * self._zoom
        th = self._base_th * self._zoom
        hw = tw / 2.0
        hh = th / 2.0

        # Frustum culling
        top_left = self.screen_to_world(0, 0)
        top_right = self.screen_to_world(self.width(), 0)
        bottom_left = self.screen_to_world(0, self.height())
        bottom_right = self.screen_to_world(self.width(), self.height())

        min_gx = max(0, min(top_left[0], top_right[0], bottom_left[0], bottom_right[0]) - 4)
        max_gx = min(120, max(top_left[0], top_right[0], bottom_left[0], bottom_right[0]) + 4)
        min_gy = max(0, min(top_left[1], top_right[1], bottom_left[1], bottom_right[1]) - 4)
        max_gy = min(100, max(top_left[1], top_right[1], bottom_left[1], bottom_right[1]) + 4)

        # Draw Isometric Tiles in Depth Order (d = gx + gy)
        for d in range(min_gx + min_gy, max_gx + max_gy + 1):
            for gx in range(max(min_gx, d - max_gy), min(max_gx, d - min_gy) + 1):
                gy = d - gx
                if 0 <= gx < 120 and 0 <= gy < 100:
                    raw = self._engine.fast_get_tile(gx, gy)
                    self._draw_isometric_tile(painter, gx, gy, raw, tw, th, hw, hh)

        # Draw dynamic moving traffic and trains in 2.5D space
        self._draw_traffic(painter, tw, th, hw, hh)
        self._draw_train(painter, tw, th, hw, hh)

        # Draw Snapping 2.5D Isometric Placement Footprint
        if 0 <= self._hover_x < 120 and 0 <= self._hover_y < 100 and self._selected_tool != -1:
            self._draw_isometric_footprint(painter, tw, th, hw, hh)

    def _draw_isometric_tile(self, painter: QPainter, gx, gy, raw, tw, th, hw, hh):
        tile_id = raw & 0x03ff
        is_zone_center = bool(raw & 0x0400) # ZONEBIT: True only on center tile of a zone
        has_power = bool(raw & 0x8000) or (self._engine.fast_has_power(gx, gy) if self._engine else False)
        sx, sy = self.world_to_screen(gx, gy)

        diamond = QPolygonF([
            QPointF(sx, sy - hh),
            QPointF(sx + hw, sy),
            QPointF(sx, sy + hh),
            QPointF(sx - hw, sy)
        ])

        # 1. Base Terrain: Water vs Grass
        if tile_id in (1, 2, 3): # Water (deep retro blue)
            painter.setPen(Qt.NoPen)
            painter.setBrush(self._col_water_mid)
            painter.drawPolygon(diamond)
            # Gentle calm wave arc
            painter.setPen(QPen(self._col_water_wave, 1.2))
            painter.drawLine(QPointF(sx - hw * 0.35, sy), QPointF(sx + hw * 0.35, sy))
            return
        else: # Grass Land (rich retro green)
            painter.setPen(QPen(self._col_grass_grid, 0.8))
            painter.setBrush(self._col_grass)
            painter.drawPolygon(diamond)

        # 2. Trees (21..36)
        if 21 <= tile_id <= 36:
            self._draw_isometric_trees(painter, sx, sy, hw, hh)
            return

        # 2b. Parks (40..43, 840)
        if (40 <= tile_id <= 43) or tile_id == 840:
            self._draw_isometric_park(painter, sx, sy, hw, hh, tile_id)
            return

        # 3. Roads (64..94, 128..207) - 16-Way Autotiled Retro Asphalt (including 79..94 road bridges)
        if (64 <= tile_id <= 94) or (128 <= tile_id <= 207):
            self._draw_isometric_autotiled_road(painter, gx, gy, sx, sy, hw, hh)
            return

        # 4. Road-over-Wire Crossings (95..109)
        if 95 <= tile_id <= 109:
            self._draw_isometric_road_wire_crossing(painter, gx, gy, sx, sy, hw, hh, has_power)
            return

        # 5. Power Lines (208..222)
        if 208 <= tile_id <= 222:
            self._draw_isometric_autotiled_wire(painter, gx, gy, sx, sy, hw, hh, has_power)
            return

        # 6. Railroads (224..238)
        if 224 <= tile_id <= 238:
            self._draw_isometric_rail(painter, gx, gy, sx, sy, hw, hh)
            return

        # 7. Single-Tile Residential Houses (249..260)
        if 249 <= tile_id <= 260:
            self._draw_isometric_residential_house(painter, gx, gy, sx, sy, hw, hh, tile_id, has_power)
            return

        # 7b. Zones & 3D Elevated Buildings (240..692)
        if 240 <= tile_id <= 692:
            self._draw_isometric_zone_building(painter, sx, sy, hw, hh, tile_id, has_power, is_zone_center)
            return

        # 8. Special structures (Coal, Nuclear, Stadium, etc.)
        if tile_id > 692:
            self._draw_isometric_special(painter, sx, sy, hw, hh, tile_id, has_power, is_zone_center)
            return

        # 9. Rubble / Fire
        if 44 <= tile_id <= 47: # Fire
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#f38ba8"))
            painter.drawPolygon(diamond)
        elif 48 <= tile_id <= 51: # Rubble
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#585b70"))
            painter.drawPolygon(diamond)

    # --- 16-Way Autotiled Roads in 2.5D Isometric (Authentic Retro Asphalt) ---
    def _is_road(self, x, y):
        if x < 0 or x >= 120 or y < 0 or y >= 100:
            return False
        if not self._engine:
            return False
        t = self._engine.fast_get_tile(x, y) & 0x03ff
        return ((64 <= t <= 94) or (95 <= t <= 109) or (128 <= t <= 207) or (t in (237, 238)))

    def _draw_isometric_autotiled_road(self, painter: QPainter, gx, gy, sx, sy, hw, hh):
        n = self._is_road(gx, gy - 1) # Up-Right
        e = self._is_road(gx + 1, gy) # Down-Right
        s = self._is_road(gx, gy + 1) # Down-Left
        w = self._is_road(gx - 1, gy) # Up-Left

        w_ratio = 0.54 # Robust authentic street width

        # Tile outer vertices
        vt = QPointF(sx, sy - hh)
        vr = QPointF(sx + hw, sy)
        vb = QPointF(sx, sy + hh)
        vl = QPointF(sx - hw, sy)

        # Edge boundary connection points
        # NE Edge (vt to vr):
        p_ne_l = QPointF(sx + 0.5 * (1.0 - w_ratio) * hw, sy - 0.5 * (1.0 + w_ratio) * hh)
        p_ne_r = QPointF(sx + 0.5 * (1.0 + w_ratio) * hw, sy - 0.5 * (1.0 - w_ratio) * hh)
        m_ne   = QPointF(sx + 0.5 * hw, sy - 0.5 * hh)

        # SE Edge (vr to vb):
        p_se_t = QPointF(sx + 0.5 * (1.0 + w_ratio) * hw, sy + 0.5 * (1.0 - w_ratio) * hh)
        p_se_b = QPointF(sx + 0.5 * (1.0 - w_ratio) * hw, sy + 0.5 * (1.0 + w_ratio) * hh)
        m_se   = QPointF(sx + 0.5 * hw, sy + 0.5 * hh)

        # SW Edge (vb to vl):
        p_sw_r = QPointF(sx - 0.5 * (1.0 - w_ratio) * hw, sy + 0.5 * (1.0 + w_ratio) * hh)
        p_sw_l = QPointF(sx - 0.5 * (1.0 + w_ratio) * hw, sy + 0.5 * (1.0 - w_ratio) * hh)
        m_sw   = QPointF(sx - 0.5 * hw, sy + 0.5 * hh)

        # NW Edge (vl to vt):
        p_nw_b = QPointF(sx - 0.5 * (1.0 + w_ratio) * hw, sy - 0.5 * (1.0 - w_ratio) * hh)
        p_nw_t = QPointF(sx - 0.5 * (1.0 - w_ratio) * hw, sy - 0.5 * (1.0 + w_ratio) * hh)
        m_nw   = QPointF(sx - 0.5 * hw, sy - 0.5 * hh)

        # Central junction corners:
        c_t = QPointF(sx, sy - w_ratio * hh)
        c_r = QPointF(sx + w_ratio * hw, sy)
        c_b = QPointF(sx, sy + w_ratio * hh)
        c_l = QPointF(sx - w_ratio * hw, sy)
        cp  = QPointF(sx, sy)

        # 1. Asphalt Fill
        painter.setPen(Qt.NoPen)
        painter.setBrush(self._col_road)

        if not (n or e or s or w):
            full_diamond = QPolygonF([vt, vr, vb, vl])
            painter.drawPolygon(full_diamond)
            painter.setPen(QPen(self._col_road_border, 1.8 * self._zoom))
            painter.drawPolygon(full_diamond)
            dash_pen = QPen(self._col_road_dash, 2.0 * self._zoom, Qt.DashLine)
            painter.setPen(dash_pen)
            painter.drawLine(QPointF(sx - hw * 0.5, sy), QPointF(sx + hw * 0.5, sy))
            return

        # Core center polygon
        painter.drawPolygon(QPolygonF([c_t, c_r, c_b, c_l]))

        # Straight branches (pure non-intersecting quads)
        if n: painter.drawPolygon(QPolygonF([c_t, p_ne_l, p_ne_r, c_r]))
        if e: painter.drawPolygon(QPolygonF([c_r, p_se_t, p_se_b, c_b]))
        if s: painter.drawPolygon(QPolygonF([c_b, p_sw_r, p_sw_l, c_l]))
        if w: painter.drawPolygon(QPolygonF([c_l, p_nw_b, p_nw_t, c_t]))

        # Seamless corner joins when roads turn
        if n and e: painter.drawPolygon(QPolygonF([c_r, p_ne_r, vr, p_se_t]))
        if e and s: painter.drawPolygon(QPolygonF([c_b, p_se_b, vb, p_sw_r]))
        if s and w: painter.drawPolygon(QPolygonF([c_l, p_sw_l, vl, p_nw_b]))
        if w and n: painter.drawPolygon(QPolygonF([c_t, p_nw_t, vt, p_ne_l]))

        # 2. Curbs & Edge Borders (#181825)
        curb_pen = QPen(self._col_road_border, 1.6 * self._zoom)
        painter.setPen(curb_pen)

        # Top-Right quadrant
        if n:
            painter.drawLine(c_t, p_ne_l)
        if e:
            painter.drawLine(c_r, p_se_t)
        if not (n or e):
            painter.drawLine(c_t, c_r)
        elif n and e:
            painter.drawLine(p_ne_r, vr)
            painter.drawLine(vr, p_se_t)
        elif n and not e:
            painter.drawLine(c_r, p_ne_r)

        # Bottom-Right quadrant
        if e:
            painter.drawLine(c_b, p_se_b)
        if s:
            painter.drawLine(c_b, p_sw_r)
        if not (e or s):
            painter.drawLine(c_r, c_b)
        elif e and s:
            painter.drawLine(p_se_b, vb)
            painter.drawLine(vb, p_sw_r)
        elif e and not s:
            painter.drawLine(c_b, p_se_b)

        # Bottom-Left quadrant
        if s:
            painter.drawLine(c_l, p_sw_l)
        if w:
            painter.drawLine(c_l, p_nw_b)
        if not (s or w):
            painter.drawLine(c_b, c_l)
        elif s and w:
            painter.drawLine(p_sw_l, vl)
            painter.drawLine(vl, p_nw_b)
        elif s and not w:
            painter.drawLine(c_l, p_sw_l)

        # Top-Left quadrant
        if w:
            painter.drawLine(c_t, p_nw_t)
        if n and not w:
            painter.drawLine(c_t, p_ne_l)
        if not (w or n):
            painter.drawLine(c_l, c_t)
        elif w and n:
            painter.drawLine(p_nw_t, vt)
            painter.drawLine(vt, p_ne_l)

        # 3. Yellow Dashed Centerlines (#f9e2af)
        dash_pen = QPen(self._col_road_dash, 2.0 * self._zoom, Qt.DashLine)
        painter.setPen(dash_pen)

        if n and s and not e and not w:
            painter.drawLine(m_ne, m_sw)
        elif e and w and not n and not s:
            painter.drawLine(m_nw, m_se)
        else:
            if n: painter.drawLine(cp, m_ne)
            if e: painter.drawLine(cp, m_se)
            if s: painter.drawLine(cp, m_sw)
            if w: painter.drawLine(cp, m_nw)

    # --- Road-over-Wire Crossing in 2.5D Isometric ---
    def _draw_isometric_road_wire_crossing(self, painter: QPainter, gx, gy, sx, sy, hw, hh, powered):
        # Draw base asphalt road
        self._draw_isometric_autotiled_road(painter, gx, gy, sx, sy, hw, hh)

        # Draw wooden utility poles on both sides of road
        pole_h = 14.0 * self._zoom
        painter.setPen(QPen(self._col_wire_pole, 2.0 * self._zoom))
        painter.drawLine(QPointF(sx - hw * 0.35, sy + hh * 0.35),
                         QPointF(sx - hw * 0.35, sy + hh * 0.35 - pole_h))
        painter.drawLine(QPointF(sx + hw * 0.35, sy - hh * 0.35),
                         QPointF(sx + hw * 0.35, sy - hh * 0.35 - pole_h))

        # Wire spanning across overhead
        wire_col = QColor("#f9e2af") if powered else self._col_wire_line
        painter.setPen(QPen(wire_col, 1.4))
        painter.drawLine(QPointF(sx - hw * 0.35, sy + hh * 0.35 - pole_h * 0.85),
                         QPointF(sx + hw * 0.35, sy - hh * 0.35 - pole_h * 0.85))

    # --- 16-Way Autotiled Wires in 2.5D Isometric ---
    def _is_wire(self, x, y):
        if x < 0 or x >= 120 or y < 0 or y >= 100:
            return False
        t = self._engine.get_tile(x, y) & 0x03ff
        return (208 <= t <= 222) or (95 <= t <= 109)

    def _draw_isometric_autotiled_wire(self, painter: QPainter, gx, gy, sx, sy, hw, hh, powered):
        pole_h = 13.0 * self._zoom

        # Center wooden pole
        painter.setPen(QPen(self._col_wire_pole, 2.0 * self._zoom))
        painter.drawLine(QPointF(sx, sy), QPointF(sx, sy - pole_h))
        # Crossbar
        painter.drawLine(QPointF(sx - 4.0 * self._zoom, sy - pole_h * 0.85),
                         QPointF(sx + 4.0 * self._zoom, sy - pole_h * 0.85))

        # Wires connecting to active neighbors across diamond edges
        wire_col = QColor("#f9e2af") if powered else self._col_wire_line
        painter.setPen(QPen(wire_col, 1.3))

        n = self._is_wire(gx, gy - 1)
        e = self._is_wire(gx + 1, gy)
        s = self._is_wire(gx, gy + 1)
        w = self._is_wire(gx - 1, gy)

        top_wire_y = sy - pole_h * 0.85
        cp = QPointF(sx, top_wire_y)
        if n: painter.drawLine(cp, QPointF(sx + 0.5 * hw, sy - 0.5 * hh - pole_h * 0.85))
        if e: painter.drawLine(cp, QPointF(sx + 0.5 * hw, sy + 0.5 * hh - pole_h * 0.85))
        if s: painter.drawLine(cp, QPointF(sx - 0.5 * hw, sy + 0.5 * hh - pole_h * 0.85))
        if w: painter.drawLine(cp, QPointF(sx - 0.5 * hw, sy - 0.5 * hh - pole_h * 0.85))

    # --- Railroad in 2.5D Isometric (Ballast, Ties, Shining Dual Steel Rails) ---
    def _is_rail(self, x, y):
        if x < 0 or x >= 120 or y < 0 or y >= 100:
            return False
        if not self._engine:
            return False
        t = self._engine.fast_get_tile(x, y) & 0x03ff
        return (224 <= t <= 238)

    def _draw_isometric_rail(self, painter: QPainter, gx, gy, sx, sy, hw, hh):
        rn = self._is_rail(gx, gy - 1)
        re = self._is_rail(gx + 1, gy)
        rs = self._is_rail(gx, gy + 1)
        rw = self._is_rail(gx - 1, gy)

        m_ne = QPointF(sx + 0.5 * hw, sy - 0.5 * hh)
        m_se = QPointF(sx + 0.5 * hw, sy + 0.5 * hh)
        m_sw = QPointF(sx - 0.5 * hw, sy + 0.5 * hh)
        m_nw = QPointF(sx - 0.5 * hw, sy - 0.5 * hh)
        cp = QPointF(sx, sy)

        # 1. Dark gravel ballast embankment
        ballast_poly = QPolygonF([
            QPointF(sx, sy - hh * 0.58),
            QPointF(sx + hw * 0.58, sy),
            QPointF(sx, sy + hh * 0.58),
            QPointF(sx - hw * 0.58, sy)
        ])
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#24273a"))
        painter.drawPolygon(ballast_poly)

        # 2. Wooden crossties (sleepers)
        tie_pen = QPen(QColor("#583b28"), 2.2 * self._zoom)
        painter.setPen(tie_pen)

        tw_d = 4.2 * self._zoom
        th_d = 2.1 * self._zoom

        def draw_ties(p_start, p_end, perp_dx, perp_dy):
            for frac in (0.22, 0.50, 0.78):
                tx = p_start.x() + (p_end.x() - p_start.x()) * frac
                ty = p_start.y() + (p_end.y() - p_start.y()) * frac
                painter.drawLine(QPointF(tx - perp_dx, ty - perp_dy), QPointF(tx + perp_dx, ty + perp_dy))

        if rn: draw_ties(cp, m_ne, tw_d, th_d)
        if re: draw_ties(cp, m_se, -tw_d, th_d)
        if rs: draw_ties(cp, m_sw, tw_d, th_d)
        if rw: draw_ties(cp, m_nw, -tw_d, th_d)

        if not (rn or re or rs or rw):
            draw_ties(m_nw, m_se, -tw_d, th_d)

        # 3. Shining dual steel rails (#bac2de)
        rail_pen = QPen(QColor("#bac2de"), 1.6 * self._zoom)
        painter.setPen(rail_pen)

        g_x = 2.8 * self._zoom
        g_y = 1.4 * self._zoom

        def draw_twin_rails(p1, p2, off_x, off_y):
            painter.drawLine(QPointF(p1.x() - off_x, p1.y() - off_y), QPointF(p2.x() - off_x, p2.y() - off_y))
            painter.drawLine(QPointF(p1.x() + off_x, p1.y() + off_y), QPointF(p2.x() + off_x, p2.y() + off_y))

        if rn and rs and not re and not rw:
            draw_twin_rails(m_ne, m_sw, g_x, g_y)
        elif re and rw and not rn and not rs:
            draw_twin_rails(m_nw, m_se, -g_x, g_y)
        elif not (rn or re or rs or rw):
            draw_twin_rails(m_nw, m_se, -g_x, g_y)
        else:
            if rn: draw_twin_rails(cp, m_ne, g_x, g_y)
            if re: draw_twin_rails(cp, m_se, -g_x, g_y)
            if rs: draw_twin_rails(cp, m_sw, g_x, g_y)
            if rw: draw_twin_rails(cp, m_nw, -g_x, g_y)

    # --- Parks in 2.5D Isometric (Lawn, Stone Paths, Fountain, Benches, Trees) ---
    def _draw_isometric_park(self, painter: QPainter, sx, sy, hw, hh, tile_id):
        diamond = QPolygonF([QPointF(sx, sy - hh), QPointF(sx + hw, sy), QPointF(sx, sy + hh), QPointF(sx - hw, sy)])
        # Manicured lush grass lawn
        painter.setPen(QPen(QColor("#40a02b"), 1.0))
        painter.setBrush(QColor("#368024"))
        painter.drawPolygon(diamond)

        # Inner stone promenade border
        painter.setPen(QPen(QColor("#eed49f"), 1.2 * self._zoom))
        inner_diamond = QPolygonF([
            QPointF(sx, sy - hh * 0.88),
            QPointF(sx + hw * 0.88, sy),
            QPointF(sx, sy + hh * 0.88),
            QPointF(sx - hw * 0.88, sy)
        ])
        painter.setBrush(QColor("#43932e"))
        painter.drawPolygon(inner_diamond)

        if tile_id == 840: # Fountain park
            # Paved stone plaza
            painter.setPen(QPen(QColor("#6c7086"), 1.0))
            painter.setBrush(QColor("#9399b2"))
            painter.drawEllipse(QPointF(sx, sy), hw * 0.62, hh * 0.62)
            # Water basin
            painter.setBrush(QColor("#209fb5"))
            painter.drawEllipse(QPointF(sx, sy), hw * 0.48, hh * 0.48)
            # Tiered fountain pedestal
            painter.setBrush(QColor("#cad3f5"))
            painter.drawEllipse(QPointF(sx, sy - 2.5 * self._zoom), hw * 0.22, hh * 0.22)
            # Animated fountain water spray
            spray_y = sy - 5.0 * self._zoom - (int(self._anim_phase * 12) % 6) * 0.7 * self._zoom
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(180, 230, 255, 200))
            painter.drawEllipse(QPointF(sx, spray_y), 2.5 * self._zoom, 2.5 * self._zoom)
            return

        # Paved flagstone walking path winding through park
        painter.setPen(QPen(QColor("#eed49f"), 2.2 * self._zoom))
        painter.drawLine(QPointF(sx - hw * 0.6, sy + hh * 0.2), QPointF(sx + hw * 0.6, sy - hh * 0.2))

        # Park trees (ornamental round trees)
        tree_pos = [(-hw * 0.35, -hh * 0.35), (hw * 0.35, hh * 0.35), (-hw * 0.2, hh * 0.45)]
        for tx_off, ty_off in tree_pos:
            tx = sx + tx_off
            ty = sy + ty_off
            # Trunk
            painter.setPen(QPen(QColor("#6e4a2e"), 1.5 * self._zoom))
            painter.drawLine(QPointF(tx, ty), QPointF(tx, ty - 7.0 * self._zoom))
            # Lush canopy
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#236118"))
            painter.drawEllipse(QPointF(tx, ty - 9.0 * self._zoom), 4.5 * self._zoom, 4.5 * self._zoom)
            painter.setBrush(QColor("#2ea31e"))
            painter.drawEllipse(QPointF(tx - 1.0 * self._zoom, ty - 10.0 * self._zoom), 3.0 * self._zoom, 3.0 * self._zoom)

        # Flowerbeds (tulips & marigolds)
        flower_colors = [QColor("#f38ba8"), QColor("#fab387"), QColor("#f9e2af")]
        for i, (fx, fy) in enumerate([(hw * 0.2, -hh * 0.3), (0, -hh * 0.15), (hw * 0.4, 0)]):
            painter.setPen(Qt.NoPen)
            painter.setBrush(flower_colors[i % len(flower_colors)])
            painter.drawEllipse(QPointF(sx + fx, sy + fy), 2.0 * self._zoom, 2.0 * self._zoom)

        # Wooden park bench
        bx, by = sx + hw * 0.1, sy + hh * 0.1
        painter.setPen(QPen(QColor("#181825"), 1.0))
        painter.setBrush(QColor("#a67c52"))
        painter.drawRect(QRectF(bx - 3.0 * self._zoom, by - 1.5 * self._zoom, 6.0 * self._zoom, 3.0 * self._zoom))

    # --- Trees in 2.5D Isometric ---
    def _draw_isometric_trees(self, painter: QPainter, sx, sy, hw, hh):
        for ox, oy in [(-hw * 0.25, -hh * 0.15), (0, 0), (hw * 0.25, hh * 0.15)]:
            tx = sx + ox
            ty = sy + oy - 3.0 * self._zoom
            # Trunk
            painter.setPen(QPen(QColor("#7f849c"), 1.5 * self._zoom))
            painter.drawLine(QPointF(tx, ty), QPointF(tx, ty - 6.0 * self._zoom))
            # Foliage
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#2d5a27"))
            r = 4.0 * self._zoom
            painter.drawEllipse(QPointF(tx, ty - 8.0 * self._zoom), r, r)

    # --- Authentic 2.5D Isometric Residential Houses (249..260) ---
    def _draw_isometric_residential_house(self, painter: QPainter, gx, gy, sx, sy, hw, hh, tile_id, has_power):
        def iso_pt(u, v, z=0.0):
            # u: axis from top-left towards bottom-right [0..1]
            # v: axis from top-right towards bottom-left [0..1]
            # z: vertical pixel elevation
            return QPointF(sx + (u - v) * hw, sy + (u + v - 1.0) * hh - z)

        # 1. Manicured suburban lawn base
        lawn = QPolygonF([
            iso_pt(0.0, 0.0, 0.0),
            iso_pt(1.0, 0.0, 0.0),
            iso_pt(1.0, 1.0, 0.0),
            iso_pt(0.0, 1.0, 0.0)
        ])
        painter.setPen(QPen(QColor("#2d5a27"), 0.8))
        painter.setBrush(QColor("#3d6634"))
        painter.drawPolygon(lawn)

        variant = ((gx ^ (gy * 3)) + (tile_id - 249)) % 4
        stage = max(0, min(11, tile_id - 249))

        # Architectural Color Themes:
        palettes = [
            {
                # Classic Craftsman / Colonial: Warm Cream clapboard with Slate/Charcoal roof
                "wall_light": QColor("#fbf1c7"),
                "wall_dark": QColor("#d5c4a1"),
                "roof_light": QColor("#45475a"),
                "roof_dark": QColor("#313244"),
                "trim": QColor("#ffffff"),
                "door": QColor("#9d0006"), # Deep red door
                "chimney": QColor("#af3a03"),
            },
            {
                # Terracotta Bungalow / Mediterranean: Warm Sand stucco with Terracotta tile roof
                "wall_light": QColor("#f5e0dc"),
                "wall_dark": QColor("#d5c4a1"),
                "roof_light": QColor("#d27352"),
                "roof_dark": QColor("#b35438"),
                "trim": QColor("#eed49f"),
                "door": QColor("#076678"), # Teal door
                "chimney": QColor("#d27352"),
            },
            {
                # Coastal Cape Cod: Soft Wedgewood Blue with Weathered Cedar shake roof
                "wall_light": QColor("#b8c0d9"),
                "wall_dark": QColor("#8992b0"),
                "roof_light": QColor("#795548"),
                "roof_dark": QColor("#5d4037"),
                "trim": QColor("#fbf1c7"),
                "door": QColor("#d79921"), # Warm amber door
                "chimney": QColor("#7f849c"),
            },
            {
                # Forest Sage Craftsman: Sage Olive clapboard with Forest Slate roof
                "wall_light": QColor("#cad3b8"),
                "wall_dark": QColor("#9da88a"),
                "roof_light": QColor("#3d5a45"),
                "roof_dark": QColor("#283d2e"),
                "trim": QColor("#fbf1c7"),
                "door": QColor("#5c4033"), # Dark oak door
                "chimney": QColor("#8f3f20"),
            }
        ]
        pal = palettes[variant]

        # Stone garden walkway on the lawn (z=0)
        path_poly = QPolygonF([
            iso_pt(0.70, 0.45, 0.0),
            iso_pt(1.00, 0.45, 0.0),
            iso_pt(1.00, 0.58, 0.0),
            iso_pt(0.70, 0.58, 0.0)
        ])
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#d5c8b5")) # Light stone path
        painter.drawPolygon(path_poly)

        # Footprint of house
        u0, u1 = 0.22, 0.78
        v0, v1 = 0.22, 0.78
        wall_h = (12.0 + (stage // 3) * 3.0) * self._zoom
        pitch = (7.5 + (stage // 4) * 1.5) * self._zoom

        # Base and Top of walls
        b_back  = iso_pt(u0, v0, 0.0)
        b_right = iso_pt(u1, v0, 0.0)
        b_front = iso_pt(u1, v1, 0.0)
        b_left  = iso_pt(u0, v1, 0.0)

        t_back  = iso_pt(u0, v0, wall_h)
        t_right = iso_pt(u1, v0, wall_h)
        t_front = iso_pt(u1, v1, wall_h)
        t_left  = iso_pt(u0, v1, wall_h)

        # Draw Left Wall Facade (shaded)
        poly_left_wall = QPolygonF([b_left, b_front, t_front, t_left])
        painter.setPen(QPen(QColor("#181825"), 0.8))
        painter.setBrush(pal["wall_dark"])
        painter.drawPolygon(poly_left_wall)

        # Draw Right Wall Facade (sunlit)
        poly_right_wall = QPolygonF([b_front, b_right, t_right, t_front])
        painter.setPen(QPen(QColor("#181825"), 0.8))
        painter.setBrush(pal["wall_light"])
        painter.drawPolygon(poly_right_wall)

        # Gable Orientation:
        # If variant in (0, 2): Gable ridge runs along U (front triangular gable faces camera-right at u=u1)
        # If variant in (1, 3): Gable ridge runs along V (front triangular gable faces camera-left at v=v1)
        overhang = 0.04
        if variant in (0, 2):
            v_mid = 0.50
            # Ridge peak elevated by pitch
            r0 = iso_pt(u0 - overhang, v_mid, wall_h + pitch)
            r1 = iso_pt(u1 + overhang, v_mid, wall_h + pitch)
            r1_wall = iso_pt(u1, v_mid, wall_h + pitch)

            # Triangular Gable End Wall (at u=u1, facing down-right)
            gable_wall = QPolygonF([t_front, t_right, r1_wall])
            painter.setPen(QPen(QColor("#181825"), 0.8))
            painter.setBrush(pal["wall_light"])
            painter.drawPolygon(gable_wall)

            # Attic louver / window in gable peak
            attic_pt = iso_pt(u1, v_mid, wall_h + pitch * 0.5)
            painter.setPen(QPen(pal["trim"], 0.8))
            painter.setBrush(QColor("#313244"))
            painter.drawEllipse(attic_pt, 2.0 * self._zoom, 2.0 * self._zoom)

            # Eaves lines
            e_left0  = iso_pt(u0 - overhang, v1 + overhang, wall_h - 1.0 * self._zoom)
            e_left1  = iso_pt(u1 + overhang, v1 + overhang, wall_h - 1.0 * self._zoom)
            e_right0 = iso_pt(u0 - overhang, v0 - overhang, wall_h - 1.0 * self._zoom)
            e_right1 = iso_pt(u1 + overhang, v0 - overhang, wall_h - 1.0 * self._zoom)

            # Sloped Roof Facets
            roof_left = QPolygonF([e_left0, e_left1, r1, r0])
            roof_right = QPolygonF([r0, r1, e_right1, e_right0])

            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(pal["roof_dark"])
            painter.drawPolygon(roof_left)
            painter.setBrush(pal["roof_light"])
            painter.drawPolygon(roof_right)

            # Ridge crest line
            painter.setPen(QPen(pal["roof_light"].lighter(130), 1.5 * self._zoom))
            painter.drawLine(r0, r1)

            # Chimney position
            ch_top = iso_pt(u0 + 0.20, v0 + 0.10, wall_h + pitch + 4.0 * self._zoom)
        else:
            u_mid = 0.50
            # Ridge peak elevated by pitch
            r0 = iso_pt(u_mid, v0 - overhang, wall_h + pitch)
            r1 = iso_pt(u_mid, v1 + overhang, wall_h + pitch)
            r1_wall = iso_pt(u_mid, v1, wall_h + pitch)

            # Triangular Gable End Wall (at v=v1, facing down-left)
            gable_wall = QPolygonF([t_left, t_front, r1_wall])
            painter.setPen(QPen(QColor("#181825"), 0.8))
            painter.setBrush(pal["wall_dark"])
            painter.drawPolygon(gable_wall)

            # Attic louver / window in gable peak
            attic_pt = iso_pt(u_mid, v1, wall_h + pitch * 0.5)
            painter.setPen(QPen(pal["trim"], 0.8))
            painter.setBrush(QColor("#313244"))
            painter.drawEllipse(attic_pt, 2.0 * self._zoom, 2.0 * self._zoom)

            # Eaves lines
            e_left0  = iso_pt(u0 - overhang, v0 - overhang, wall_h - 1.0 * self._zoom)
            e_left1  = iso_pt(u0 - overhang, v1 + overhang, wall_h - 1.0 * self._zoom)
            e_right0 = iso_pt(u1 + overhang, v0 - overhang, wall_h - 1.0 * self._zoom)
            e_right1 = iso_pt(u1 + overhang, v1 + overhang, wall_h - 1.0 * self._zoom)

            # Sloped Roof Facets
            roof_left = QPolygonF([e_left0, e_left1, r1, r0])
            roof_right = QPolygonF([r0, r1, e_right1, e_right0])

            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(pal["roof_dark"])
            painter.drawPolygon(roof_left)
            painter.setBrush(pal["roof_light"])
            painter.drawPolygon(roof_right)

            # Ridge crest line
            painter.setPen(QPen(pal["roof_light"].lighter(130), 1.5 * self._zoom))
            painter.drawLine(r0, r1)

            # Chimney position
            ch_top = iso_pt(u0 + 0.10, v0 + 0.20, wall_h + pitch + 4.0 * self._zoom)

        # Brick Chimney
        cw = 2.4 * self._zoom
        ch_rect = QRectF(ch_top.x() - cw * 0.5, ch_top.y(), cw, 5.0 * self._zoom)
        painter.setPen(QPen(QColor("#181825"), 0.8))
        painter.setBrush(pal["chimney"])
        painter.drawRect(ch_rect)
        # Chimney flue cap
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#181825"))
        painter.drawRect(QRectF(ch_top.x() - cw * 0.6, ch_top.y() - 1.0 * self._zoom, cw * 1.2, 1.2 * self._zoom))

        # Animated Smoke Puff from Chimney (if powered)
        if has_power:
            for s_idx in range(3):
                s_phase = (self._anim_phase * 4.0 + s_idx * 1.3) % 4.0
                sy_drift = s_phase * 4.5 * self._zoom
                sx_drift = (s_phase * 1.2) * self._zoom
                s_rad = (1.5 + s_phase * 0.9) * self._zoom
                s_alpha = max(0, int(150 - s_phase * 35))
                painter.setBrush(QColor(235, 235, 245, s_alpha))
                painter.drawEllipse(QPointF(ch_top.x() + sx_drift, ch_top.y() - 2.0 * self._zoom - sy_drift), s_rad, s_rad * 0.8)

        # Front Door with White Trim Frame and Porch Stoop
        door_pt = iso_pt(u1, 0.50, 0.0)
        dw = 2.4 * self._zoom
        dh = 5.2 * self._zoom
        # Porch step
        step_rect = QRectF(door_pt.x() - dw * 0.7, door_pt.y() - 0.8 * self._zoom, dw * 1.4, 1.6 * self._zoom)
        painter.setPen(QPen(QColor("#181825"), 0.6))
        painter.setBrush(QColor("#d5c4a1"))
        painter.drawRect(step_rect)
        # Door frame
        door_frame = QRectF(door_pt.x() - dw * 0.55, door_pt.y() - dh - 0.5 * self._zoom, dw * 1.1, dh + 0.5 * self._zoom)
        painter.setPen(Qt.NoPen)
        painter.setBrush(pal["trim"])
        painter.drawRect(door_frame)
        # Door slab
        door_slab = QRectF(door_pt.x() - dw * 0.45, door_pt.y() - dh, dw * 0.9, dh)
        painter.setBrush(pal["door"])
        painter.drawRect(door_slab)
        # Brass door knob
        painter.setBrush(QColor("#fab387"))
        painter.drawEllipse(QPointF(door_pt.x() + dw * 0.2, door_pt.y() - dh * 0.45), 0.7 * self._zoom, 0.7 * self._zoom)

        # Divided-Pane Windows with White Frame & Warm Illumination
        win_col = QColor("#f9e2af") if has_power else QColor("#313244")
        win_size = 2.4 * self._zoom

        # Windows on right illuminated facade (at v=0.30 and v=0.70)
        for v_win in [0.30, 0.70]:
            wpt = iso_pt(u1, v_win, 3.5 * self._zoom)
            # White window surround
            painter.setPen(Qt.NoPen)
            painter.setBrush(pal["trim"])
            painter.drawRect(QRectF(wpt.x() - win_size * 0.6, wpt.y() - win_size * 0.6, win_size * 1.2, win_size * 1.2))
            # Lit glass
            painter.setBrush(win_col)
            painter.drawRect(QRectF(wpt.x() - win_size * 0.45, wpt.y() - win_size * 0.45, win_size * 0.9, win_size * 0.9))
            # Window cross-mullion
            painter.setPen(QPen(QColor("#181825"), 0.5))
            painter.drawLine(QPointF(wpt.x(), wpt.y() - win_size * 0.45), QPointF(wpt.x(), wpt.y() + win_size * 0.45))
            painter.drawLine(QPointF(wpt.x() - win_size * 0.45, wpt.y()), QPointF(wpt.x() + win_size * 0.45, wpt.y()))

            # Upper floor window if 2-story house
            if wall_h > 13.0 * self._zoom:
                wpt2 = iso_pt(u1, v_win, 8.5 * self._zoom)
                painter.setPen(Qt.NoPen)
                painter.setBrush(pal["trim"])
                painter.drawRect(QRectF(wpt2.x() - win_size * 0.6, wpt2.y() - win_size * 0.6, win_size * 1.2, win_size * 1.2))
                painter.setBrush(win_col)
                painter.drawRect(QRectF(wpt2.x() - win_size * 0.45, wpt2.y() - win_size * 0.45, win_size * 0.9, win_size * 0.9))
                painter.setPen(QPen(QColor("#181825"), 0.5))
                painter.drawLine(QPointF(wpt2.x(), wpt2.y() - win_size * 0.45), QPointF(wpt2.x(), wpt2.y() + win_size * 0.45))
                painter.drawLine(QPointF(wpt2.x() - win_size * 0.45, wpt2.y()), QPointF(wpt2.x() + win_size * 0.45, wpt2.y()))

        # Windows on left shaded facade (at u=0.45)
        wpt_l = iso_pt(0.45, v1, 3.5 * self._zoom)
        painter.setPen(Qt.NoPen)
        painter.setBrush(pal["trim"].darker(120))
        painter.drawRect(QRectF(wpt_l.x() - win_size * 0.6, wpt_l.y() - win_size * 0.6, win_size * 1.2, win_size * 1.2))
        painter.setBrush(win_col)
        painter.drawRect(QRectF(wpt_l.x() - win_size * 0.45, wpt_l.y() - win_size * 0.45, win_size * 0.9, win_size * 0.9))
        painter.setPen(QPen(QColor("#181825"), 0.5))
        painter.drawLine(QPointF(wpt_l.x(), wpt_l.y() - win_size * 0.45), QPointF(wpt_l.x(), wpt_l.y() + win_size * 0.45))
        painter.drawLine(QPointF(wpt_l.x() - win_size * 0.45, wpt_l.y()), QPointF(wpt_l.x() + win_size * 0.45, wpt_l.y()))

        # Ornamental Garden Tree in the Yard
        tree_u = 0.28 if variant % 2 == 0 else 0.88
        tree_v = 0.88 if variant % 2 == 0 else 0.28
        tree_base = iso_pt(tree_u, tree_v, 0.0)
        # Trunk
        painter.setPen(QPen(QColor("#5c4033"), 1.8 * self._zoom))
        painter.drawLine(tree_base, QPointF(tree_base.x(), tree_base.y() - 7.0 * self._zoom))
        # Layered Lush Foliage
        painter.setPen(QPen(QColor("#181825"), 0.6))
        if variant == 1:
            foliage_dark = QColor("#d27352")
            foliage_light = QColor("#f38ba8")
        else:
            foliage_dark = QColor("#2d5a27")
            foliage_light = QColor("#4a783e")
        tr_rad = 4.2 * self._zoom
        painter.setBrush(foliage_dark)
        painter.drawEllipse(QPointF(tree_base.x(), tree_base.y() - 9.0 * self._zoom), tr_rad, tr_rad * 0.85)
        painter.setPen(Qt.NoPen)
        painter.setBrush(foliage_light)
        painter.drawEllipse(QPointF(tree_base.x() - 1.0 * self._zoom, tree_base.y() - 10.0 * self._zoom), tr_rad * 0.7, tr_rad * 0.6)

    # --- 3D Elevated Isometric Zones & Buildings ---
    def _draw_isometric_zone_building(self, painter: QPainter, sx, sy, hw, hh, tile_id, has_power, is_zone_center):
        if 240 <= tile_id <= 422: # Residential (Apartments, Estates, Hospital, Church)
            is_unbuilt = (tile_id <= 248)
            is_hospital = (405 <= tile_id <= 413)
            is_church = (414 <= tile_id <= 422)
            if is_hospital:
                base_col = QColor("#cad3f5") # Clean civic hospital white/limestone
                roof_col = QColor("#5b6078")
            elif is_church:
                base_col = QColor("#6c7086") # Historic stone church
                roof_col = QColor("#313244")
            else:
                base_col = QColor("#8f4d38") # Warm brownstone brick
                roof_col = QColor("#363a4f")
            height = 18.0 * self._zoom if not is_unbuilt else 0.0
            is_high_density = (tile_id > 300)
            if is_high_density: height = 30.0 * self._zoom
        elif 423 <= tile_id <= 611: # Commercial
            base_col = QColor("#458588") # Cyan/blue glass & steel
            roof_col = QColor("#569b9e")
            is_unbuilt = (tile_id <= 431)
            height = 22.0 * self._zoom if not is_unbuilt else 0.0
            is_high_density = (tile_id > 500)
            if is_high_density: height = 36.0 * self._zoom
        else: # 612..692 Industrial
            base_col = QColor("#d79921") # Amber / heavy industrial brick
            roof_col = QColor("#504945")
            is_unbuilt = (tile_id <= 620)
            height = 14.0 * self._zoom if not is_unbuilt else 0.0
            is_high_density = (tile_id > 650)
            if is_high_density: height = 24.0 * self._zoom

        diamond = QPolygonF([
            QPointF(sx, sy - hh),
            QPointF(sx + hw, sy),
            QPointF(sx, sy + hh),
            QPointF(sx - hw, sy)
        ])

        if is_unbuilt:
            # Clean zoned lawn with subtle tinted border
            painter.setPen(QPen(base_col.lighter(130), 1.0))
            painter.setBrush(QColor(base_col.red(), base_col.green(), base_col.blue(), 25))
            painter.drawPolygon(diamond)
            # Surveyor corner marker on center tile
            if is_zone_center:
                painter.setPen(QPen(QColor("#fab387"), 1.8 * self._zoom))
                painter.drawLine(QPointF(sx, sy), QPointF(sx, sy - 8.0 * self._zoom))
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#fab387"))
                painter.drawEllipse(QPointF(sx, sy - 8.0 * self._zoom), 2.5 * self._zoom, 2.5 * self._zoom)
        else:
            # 3D Extruded Architectural Isometric Building
            bw = hw * 0.82
            bh = hh * 0.82

            top_poly = QPolygonF([
                QPointF(sx, sy - bh - height),
                QPointF(sx + bw, sy - height),
                QPointF(sx, sy + bh - height),
                QPointF(sx - bw, sy - height)
            ])
            left_poly = QPolygonF([
                QPointF(sx - bw, sy - height),
                QPointF(sx, sy + bh - height),
                QPointF(sx, sy + bh),
                QPointF(sx - bw, sy)
            ])
            right_poly = QPolygonF([
                QPointF(sx, sy + bh - height),
                QPointF(sx + bw, sy - height),
                QPointF(sx + bw, sy),
                QPointF(sx, sy + bh)
            ])

            # Draw shaded 3D walls
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(base_col.darker(155)) # Left shaded wall
            painter.drawPolygon(left_poly)
            painter.setBrush(base_col.darker(120)) # Right illuminated wall
            painter.drawPolygon(right_poly)
            painter.setBrush(roof_col)              # Roof
            painter.drawPolygon(top_poly)

            # Architectural Details
            if 240 <= tile_id <= 422: # Residential Developments, Hospital, Church
                if is_hospital:
                    # Rooftop Helipad with Red Emergency Cross
                    hr = 6.0 * self._zoom
                    painter.setPen(QPen(QColor("#eed49f"), 1.2 * self._zoom))
                    painter.setBrush(QColor("#313244"))
                    painter.drawEllipse(QPointF(sx, sy - height), hr, hr * 0.55)
                    # Red Cross
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor("#e64553"))
                    painter.drawRect(QRectF(sx - 1.2 * self._zoom, sy - height - 3.5 * self._zoom, 2.4 * self._zoom, 7.0 * self._zoom))
                    painter.drawRect(QRectF(sx - 3.5 * self._zoom, sy - height - 1.2 * self._zoom, 7.0 * self._zoom, 2.4 * self._zoom))
                elif is_church:
                    # Tall Gothic Spire with Golden Cross
                    sp_x, sp_y = sx, sy - height
                    painter.setPen(QPen(QColor("#181825"), 1.0))
                    painter.setBrush(QColor("#45475a"))
                    spire_poly = QPolygonF([
                        QPointF(sp_x - 3.5 * self._zoom, sp_y),
                        QPointF(sp_x + 3.5 * self._zoom, sp_y),
                        QPointF(sp_x, sp_y - 14.0 * self._zoom)
                    ])
                    painter.drawPolygon(spire_poly)
                    # Golden Cross atop steeple
                    cr_y = sp_y - 14.0 * self._zoom
                    painter.setPen(QPen(QColor("#eed49f"), 1.6 * self._zoom))
                    painter.drawLine(QPointF(sp_x, cr_y), QPointF(sp_x, cr_y - 6.0 * self._zoom))
                    painter.drawLine(QPointF(sp_x - 2.5 * self._zoom, cr_y - 4.0 * self._zoom), QPointF(sp_x + 2.5 * self._zoom, cr_y - 4.0 * self._zoom))
                else:
                    # Classic NYC / Chicago Rooftop Wooden Water Tower & Elevator Penthouse
                    wt_x = sx + bw * 0.25
                    wt_y = sy - height - 5.0 * self._zoom
                    wt_w = 4.5 * self._zoom
                    wt_h = 6.0 * self._zoom
                    painter.setPen(QPen(QColor("#181825"), 0.8))
                    painter.setBrush(QColor("#8f5c38")) # Cedar tank
                    painter.drawRect(QRectF(wt_x, wt_y, wt_w, wt_h))
                    # Conical roof on water tower
                    wt_roof = QPolygonF([
                        QPointF(wt_x - 0.8 * self._zoom, wt_y),
                        QPointF(wt_x + wt_w + 0.8 * self._zoom, wt_y),
                        QPointF(wt_x + wt_w * 0.5, wt_y - 3.5 * self._zoom)
                    ])
                    painter.setBrush(QColor("#363a4f"))
                    painter.drawPolygon(wt_roof)
                    # Water tank steel bands
                    painter.setPen(QPen(QColor("#181825"), 0.6))
                    painter.drawLine(QPointF(wt_x, wt_y + wt_h * 0.35), QPointF(wt_x + wt_w, wt_y + wt_h * 0.35))
                    painter.drawLine(QPointF(wt_x, wt_y + wt_h * 0.70), QPointF(wt_x + wt_w, wt_y + wt_h * 0.70))
            elif 423 <= tile_id <= 611: # Commercial Office
                # Rooftop AC chiller box
                ac_w = 6.0 * self._zoom
                ac_h = 3.5 * self._zoom
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#45475a"))
                painter.drawRect(QRectF(sx - ac_w * 0.5, sy - height - ac_h * 0.5, ac_w, ac_h))
            else: # Industrial Warehouse
                # Factory chimney
                st_x = sx - bw * 0.3
                st_y = sy - height - 8.0 * self._zoom
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#313244"))
                painter.drawRect(QRectF(st_x, st_y, 4.0 * self._zoom, 9.0 * self._zoom))
                # Animated smoke puff
                if has_power:
                    puff_y = st_y - (int(self._anim_phase * 15) % 12) * self._zoom
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor(220, 220, 230, 160))
                    painter.drawEllipse(QPointF(st_x + 2.0 * self._zoom, puff_y), 3.0 * self._zoom, 2.5 * self._zoom)

            # Lit Windows on illuminated facade
            if height > 10.0 * self._zoom and has_power:
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#f9e2af"))
                ws = 2.2 * self._zoom
                painter.drawRect(QRectF(sx + bw * 0.25, sy - height * 0.45, ws, ws))
                painter.drawRect(QRectF(sx + bw * 0.55, sy - height * 0.45, ws, ws))
                if height > 20.0 * self._zoom:
                    painter.drawRect(QRectF(sx + bw * 0.25, sy - height * 0.75, ws, ws))
                    painter.drawRect(QRectF(sx + bw * 0.55, sy - height * 0.75, ws, ws))

        # Flashing Unpowered Lightning Bolt (⚡) in 2.5D Isometric
        # CRITICAL: ONLY drawn once per zone on the center tile!
        if is_zone_center and not has_power:
            if int(self._anim_phase * 2) % 2 == 0:
                self._draw_isometric_lightning(painter, sx, sy - height * 0.7 - hh * 0.4, hw)

    def _draw_isometric_special(self, painter: QPainter, sx, sy, hw, hh, tile_id, has_power, is_zone_center):
        # 1. Coal Power Plant (745..760) - 4x4 Industrial Power Facility
        if 745 <= tile_id <= 760:
            sub = tile_id - 745
            # Concrete foundation pad
            diamond = QPolygonF([
                QPointF(sx, sy - hh),
                QPointF(sx + hw, sy),
                QPointF(sx, sy + hh),
                QPointF(sx - hw, sy)
            ])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#313244"))
            painter.drawPolygon(diamond)

            # Generator Turbine Hall (sub 0, 1, 4, 5)
            if sub in (0, 1, 4, 5):
                h = 24.0 * self._zoom
                bw, bh = hw * 0.85, hh * 0.85
                left_p = QPolygonF([QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx, sy + bh), QPointF(sx - bw, sy)])
                right_p = QPolygonF([QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h), QPointF(sx + bw, sy), QPointF(sx, sy + bh)])
                top_p = QPolygonF([QPointF(sx, sy - bh - h), QPointF(sx + bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx - bw, sy - h)])
                painter.setBrush(QColor("#45475a"))
                painter.drawPolygon(left_p)
                painter.setBrush(QColor("#585b70"))
                painter.drawPolygon(right_p)
                painter.setBrush(QColor("#313244"))
                painter.drawPolygon(top_p)
                if has_power:
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor("#f9e2af"))
                    painter.drawRect(QRectF(sx + bw * 0.25, sy - h * 0.5, 3.0 * self._zoom, 3.0 * self._zoom))
                    painter.drawRect(QRectF(sx + bw * 0.60, sy - h * 0.5, 3.0 * self._zoom, 3.0 * self._zoom))

            # Hyperbolic Cooling Towers (sub 2, 3, 6, 7)
            elif sub in (2, 3, 6, 7):
                th = 28.0 * self._zoom
                tr = hw * 0.45
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#6c7086"))
                tower_poly = QPolygonF([
                    QPointF(sx - tr * 0.8, sy - th),
                    QPointF(sx + tr * 0.8, sy - th),
                    QPointF(sx + tr, sy),
                    QPointF(sx - tr, sy)
                ])
                painter.drawPolygon(tower_poly)
                # Tower rim
                painter.setBrush(QColor("#313244"))
                painter.drawEllipse(QPointF(sx, sy - th), tr * 0.8, tr * 0.35)
                # Animated cooling steam
                steam_y = sy - th - (int(self._anim_phase * 10) % 15) * self._zoom
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(235, 237, 245, 140))
                painter.drawEllipse(QPointF(sx, steam_y), tr * 0.7, tr * 0.4)

            # Smokestacks with red/white hazard stripes (sub 8, 9, 12, 13)
            elif sub in (8, 9, 12, 13):
                sh = 38.0 * self._zoom
                sw = 4.0 * self._zoom
                painter.setPen(QPen(QColor("#181825"), 1.0))
                # Red base
                painter.setBrush(QColor("#e64553"))
                painter.drawRect(QRectF(sx - sw * 0.5, sy - sh, sw, sh * 0.5))
                # White stripe
                painter.setBrush(QColor("#cdd6f4"))
                painter.drawRect(QRectF(sx - sw * 0.5, sy - sh * 0.5, sw, sh * 0.25))
                # Red stripe
                painter.setBrush(QColor("#e64553"))
                painter.drawRect(QRectF(sx - sw * 0.5, sy - sh * 0.25, sw, sh * 0.25))
                # Animated rising smoke puff
                smoke_y = sy - sh - (int(self._anim_phase * 18) % 18) * self._zoom
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(180, 185, 195, 180))
                painter.drawEllipse(QPointF(sx + 1.0 * self._zoom, smoke_y), 4.5 * self._zoom, 3.5 * self._zoom)

            # Coal storage / Conveyor yard (sub 10, 11, 14, 15)
            else:
                # Coal mound
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#181825"))
                painter.drawEllipse(QPointF(sx, sy), hw * 0.5, hh * 0.5)
                # Steel gantry
                painter.setPen(QPen(QColor("#7f849c"), 1.5 * self._zoom))
                painter.drawLine(QPointF(sx - hw * 0.3, sy - 6.0 * self._zoom), QPointF(sx + hw * 0.3, sy - 12.0 * self._zoom))

        # 2. Nuclear Power Plant (811..826) - 4x4 High-Tech Nuclear Generation Compound
        elif 811 <= tile_id <= 826:
            sub = tile_id - 811
            diamond = QPolygonF([QPointF(sx, sy - hh), QPointF(sx + hw, sy), QPointF(sx, sy + hh), QPointF(sx - hw, sy)])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#313244"))
            painter.drawPolygon(diamond)

            # Center Reactor Containment Dome (sub 5, 6, 9, 10)
            if sub == 5: # Zone center tile: draw the massive 3D Reactor Containment Dome
                dh = 34.0 * self._zoom
                dr = hw * 1.55
                painter.setPen(QPen(QColor("#181825"), 1.2 * self._zoom))
                painter.setBrush(QColor("#9399b2"))
                painter.drawEllipse(QPointF(sx + hw * 0.5, sy - dh * 0.5), dr, dh * 0.75)
                painter.setBrush(QColor("#cad3f5"))
                painter.drawEllipse(QPointF(sx + hw * 0.4, sy - dh * 0.6), dr * 0.75, dh * 0.5)
                # Hazard caution band
                painter.setPen(QPen(QColor("#f9e2af"), 2.0 * self._zoom))
                painter.drawArc(QRectF(sx + hw * 0.5 - dr * 0.8, sy - dh * 0.5 - dh * 0.25, dr * 1.6, dh * 0.6), 0, 180 * 16)
                # Apex vent cupola & glowing energy beacon
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#a6e3a1") if int(self._anim_phase * 4) % 2 == 0 else QColor("#94e2d5"))
                painter.drawEllipse(QPointF(sx + hw * 0.5, sy - dh * 0.85), 4.5 * self._zoom, 4.5 * self._zoom)

            # Turbine Generator Hall (sub 0, 1, 4)
            elif sub in (0, 1, 4):
                h = 22.0 * self._zoom
                bw, bh = hw * 0.85, hh * 0.85
                left_p = QPolygonF([QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx, sy + bh), QPointF(sx - bw, sy)])
                right_p = QPolygonF([QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h), QPointF(sx + bw, sy), QPointF(sx, sy + bh)])
                top_p = QPolygonF([QPointF(sx, sy - bh - h), QPointF(sx + bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx - bw, sy - h)])
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#363a4f"))
                painter.drawPolygon(left_p)
                painter.setBrush(QColor("#45475a"))
                painter.drawPolygon(right_p)
                painter.setBrush(QColor("#24273a"))
                painter.drawPolygon(top_p)
                # Control room windows
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#f9e2af"))
                painter.drawRect(QRectF(sx + bw * 0.2, sy - h * 0.4, 4.0 * self._zoom, 2.5 * self._zoom))
                painter.drawRect(QRectF(sx + bw * 0.55, sy - h * 0.4, 4.0 * self._zoom, 2.5 * self._zoom))

            # High-Voltage Transformer Substation (sub 2, 3, 7)
            elif sub in (2, 3, 7):
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#585b70"))
                painter.drawRect(QRectF(sx - hw * 0.3, sy - 8.0 * self._zoom, 6.0 * self._zoom, 8.0 * self._zoom))
                painter.drawRect(QRectF(sx + hw * 0.1, sy - 8.0 * self._zoom, 6.0 * self._zoom, 8.0 * self._zoom))
                painter.setPen(QPen(QColor("#7f849c"), 1.5 * self._zoom))
                painter.drawLine(QPointF(sx, sy - 8.0 * self._zoom), QPointF(sx, sy - 18.0 * self._zoom))
                painter.drawLine(QPointF(sx - 4.0 * self._zoom, sy - 14.0 * self._zoom), QPointF(sx + 4.0 * self._zoom, sy - 14.0 * self._zoom))
                if int(self._anim_phase * 6) % 3 == 0:
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor("#89dceb"))
                    painter.drawEllipse(QPointF(sx, sy - 18.0 * self._zoom), 2.5 * self._zoom, 2.5 * self._zoom)

            # Cooling Towers & Scrubbers (sub 8, 12, 13)
            elif sub in (8, 12, 13):
                th = 26.0 * self._zoom
                tr = hw * 0.42
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#6c7086"))
                tower_poly = QPolygonF([
                    QPointF(sx - tr * 0.8, sy - th),
                    QPointF(sx + tr * 0.8, sy - th),
                    QPointF(sx + tr, sy),
                    QPointF(sx - tr, sy)
                ])
                painter.drawPolygon(tower_poly)
                painter.setBrush(QColor("#313244"))
                painter.drawEllipse(QPointF(sx, sy - th), tr * 0.8, tr * 0.35)
                steam_y = sy - th - (int(self._anim_phase * 10) % 14) * self._zoom
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor(235, 237, 245, 140))
                painter.drawEllipse(QPointF(sx, steam_y), tr * 0.65, tr * 0.4)

            # Security Perimeter Gatehouse & Staff Lot (sub 14, 15)
            else:
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#45475a"))
                painter.drawRect(QRectF(sx - hw * 0.25, sy - 6.0 * self._zoom, 8.0 * self._zoom, 6.0 * self._zoom))
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#f9e2af"))
                painter.drawEllipse(QPointF(sx - hw * 0.1, sy - 5.0 * self._zoom), 1.8 * self._zoom, 1.8 * self._zoom)

        # 3. Police Station (770..778) - 3x3 Municipal Headquarters Compound
        elif 770 <= tile_id <= 778:
            self._draw_isometric_police_station(painter, sx, sy, hw, hh, tile_id, has_power, is_zone_center)

        # 4. Fire Station (761..769) - 3x3 Municipal Firehouse Compound
        elif 761 <= tile_id <= 769:
            self._draw_isometric_fire_station(painter, sx, sy, hw, hh, tile_id, has_power, is_zone_center)

        # 5. Stadium (779..794) - 4x4 Major League Arena
        elif 779 <= tile_id <= 794:
            sub = tile_id - 779
            diamond = QPolygonF([QPointF(sx, sy - hh), QPointF(sx + hw, sy), QPointF(sx, sy + hh), QPointF(sx - hw, sy)])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#24273a"))
            painter.drawPolygon(diamond)

            # Center 2x2 Field / Pitch (sub 5, 6, 9, 10)
            if sub in (5, 6, 9, 10):
                painter.setBrush(QColor("#40a02b"))
                painter.drawPolygon(diamond)
                painter.setPen(QPen(QColor("#ffffff"), 1.2 * self._zoom))
                if sub == 5:
                    painter.drawEllipse(QPointF(sx + hw * 0.5, sy), hw * 0.4, hh * 0.4)
                    painter.drawLine(QPointF(sx + hw * 0.5, sy - hh * 0.5), QPointF(sx + hw * 0.5, sy + hh * 0.5))
                elif sub in (6, 9):
                    painter.drawLine(QPointF(sx - hw * 0.4, sy), QPointF(sx + hw * 0.4, sy))
                elif sub == 10:
                    painter.drawRect(QRectF(sx - hw * 0.3, sy - hh * 0.3, hw * 0.6, hh * 0.6))

            # Corner Floodlight Pylon Towers (sub 0, 3, 12, 15)
            elif sub in (0, 3, 12, 15):
                th = 28.0 * self._zoom
                painter.setPen(QPen(QColor("#7f849c"), 1.8 * self._zoom))
                painter.drawLine(QPointF(sx, sy), QPointF(sx, sy - th))
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#f9e2af"))
                painter.drawRect(QRectF(sx - 4.0 * self._zoom, sy - th - 3.0 * self._zoom, 8.0 * self._zoom, 3.0 * self._zoom))

            # Tiered Grandstands with Spectators (sub 1, 2, 4, 7, 8, 11, 13, 14)
            else:
                sh = 14.0 * self._zoom
                painter.setPen(QPen(QColor("#181825"), 1.0))
                painter.setBrush(QColor("#45475a"))
                stand_poly = QPolygonF([
                    QPointF(sx - hw * 0.7, sy - sh),
                    QPointF(sx + hw * 0.7, sy - sh),
                    QPointF(sx + hw * 0.8, sy),
                    QPointF(sx - hw * 0.8, sy)
                ])
                painter.drawPolygon(stand_poly)
                seat_cols = [QColor("#cba6f7"), QColor("#89b4fa"), QColor("#ed8796"), QColor("#f9e2af")]
                painter.setPen(Qt.NoPen)
                for r_idx in range(3):
                    painter.setBrush(seat_cols[(sub + r_idx) % len(seat_cols)])
                    painter.drawRect(QRectF(sx - hw * 0.6 + r_idx * 2.0 * self._zoom, sy - sh + 3.0 * self._zoom + r_idx * 3.0 * self._zoom, hw * 1.2 - r_idx * 4.0 * self._zoom, 2.0 * self._zoom))

        # 6. Default civic
        else:
            h = 16.0 * self._zoom
            bw, bh = hw * 0.8, hh * 0.8
            top_p = QPolygonF([QPointF(sx, sy - bh - h), QPointF(sx + bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx - bw, sy - h)])
            left_p = QPolygonF([QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx, sy + bh), QPointF(sx - bw, sy)])
            right_p = QPolygonF([QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h), QPointF(sx + bw, sy), QPointF(sx, sy + bh)])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#45475a"))
            painter.drawPolygon(left_p)
            painter.setBrush(QColor("#585b70"))
            painter.drawPolygon(right_p)
            painter.setBrush(QColor("#70598f"))
            painter.drawPolygon(top_p)

        # Flashing ⚡: ONLY if zone center, unpowered, and NOT a power plant
        is_power_plant = (745 <= tile_id <= 760) or (811 <= tile_id <= 826)
        if is_zone_center and not has_power and not is_power_plant:
            if int(self._anim_phase * 2) % 2 == 0:
                self._draw_isometric_lightning(painter, sx, sy - 18.0 * self._zoom - hh * 0.4, hw)

    def _draw_isometric_police_station(self, painter: QPainter, sx, sy, hw, hh, tile_id, has_power, is_zone_center):
        if not is_zone_center:
            # Paved municipal concrete apron
            pad = QPolygonF([QPointF(sx, sy - hh), QPointF(sx + hw, sy), QPointF(sx, sy + hh), QPointF(sx - hw, sy)])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#313244"))
            painter.drawPolygon(pad)

            # Marked parking stalls on perimeter tiles
            if tile_id in (770, 771, 772, 776, 778):
                painter.setPen(QPen(QColor("#bac2de"), 1.2 * self._zoom))
                painter.drawLine(QPointF(sx - hw * 0.4, sy - hh * 0.2), QPointF(sx + hw * 0.4, sy + hh * 0.2))

            # Parked Black & White Police Cruiser on stall tiles (771 or 777)
            if tile_id in (771, 777):
                car_w = 7.0 * self._zoom
                car_h = 3.5 * self._zoom
                # Black chassis
                painter.setPen(QPen(QColor("#11111b"), 1.0))
                painter.setBrush(QColor("#181825"))
                painter.drawRoundedRect(QRectF(sx - car_w * 0.5, sy - car_h * 0.5, car_w, car_h), 1.0, 1.0)
                # White roof
                painter.setBrush(QColor("#cdd6f4"))
                painter.drawRect(QRectF(sx - car_w * 0.25, sy - car_h * 0.35, car_w * 0.5, car_h * 0.7))
                # Flashing blue rooftop emergency strobe
                if has_power and int(self._anim_phase * 4) % 2 == 0:
                    painter.setPen(Qt.NoPen)
                    painter.setBrush(QColor("#89b4fa"))
                    painter.drawEllipse(QPointF(sx, sy - car_h * 0.5), 2.2 * self._zoom, 2.2 * self._zoom)
            return

        # --- Center Tile: 3D Grand Police Precinct Headquarters ---
        h = 24.0 * self._zoom
        bw = hw * 1.12
        bh = hh * 1.12

        top_p = QPolygonF([QPointF(sx, sy - bh - h), QPointF(sx + bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx - bw, sy - h)])
        left_p = QPolygonF([QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx, sy + bh), QPointF(sx - bw, sy)])
        right_p = QPolygonF([QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h), QPointF(sx + bw, sy), QPointF(sx, sy + bh)])

        # Shaded granite & limestone walls
        painter.setPen(QPen(QColor("#11111b"), 1.0))
        painter.setBrush(QColor("#243147")) # Dark left shaded wall
        painter.drawPolygon(left_p)
        painter.setBrush(QColor("#3b5278")) # Civic police blue illuminated wall
        painter.drawPolygon(right_p)
        painter.setBrush(QColor("#1e2530")) # Slate roof
        painter.drawPolygon(top_p)

        # Stone cornice band (#bac2de)
        painter.setPen(QPen(QColor("#bac2de"), 1.8 * self._zoom))
        painter.drawLine(QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h))
        painter.drawLine(QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h))

        # Grand Entrance Portico & Steps on right facade
        ent_w = 8.0 * self._zoom
        ent_h = 10.0 * self._zoom
        ex = sx + bw * 0.35
        ey = sy + bh * 0.35 - ent_h
        painter.setPen(QPen(QColor("#11111b"), 1.0))
        painter.setBrush(QColor("#181825")) # Doorway
        painter.drawRect(QRectF(ex, ey, ent_w, ent_h))

        # Twin blue precinct globe lamps
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#89dceb") if has_power else QColor("#45475a"))
        painter.drawEllipse(QPointF(ex - 2.5 * self._zoom, ey + 4.0 * self._zoom), 2.0 * self._zoom, 2.0 * self._zoom)
        painter.drawEllipse(QPointF(ex + ent_w + 2.5 * self._zoom, ey + 4.0 * self._zoom), 2.0 * self._zoom, 2.0 * self._zoom)

        # Lit Precinct Windows (Amber #f9e2af)
        if has_power:
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#f9e2af"))
            ws = 2.4 * self._zoom
            painter.drawRect(QRectF(sx + bw * 0.15, sy - h * 0.35, ws, ws))
            painter.drawRect(QRectF(sx + bw * 0.45, sy - h * 0.35, ws, ws))
            painter.drawRect(QRectF(sx + bw * 0.75, sy - h * 0.35, ws, ws))
            painter.drawRect(QRectF(sx - bw * 0.45, sy - h * 0.35, ws, ws))
            painter.drawRect(QRectF(sx - bw * 0.75, sy - h * 0.35, ws, ws))

        # Gold "POLICE" crest plaque above entrance
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#f9e2af"))
        painter.drawRect(QRectF(ex + 1.0 * self._zoom, ey - 3.0 * self._zoom, ent_w - 2.0 * self._zoom, 2.2 * self._zoom))

        # Rooftop Communications & Mechanical Equipment (Satellite Dish, Whip Antenna, HVAC)
        # 1. Dual rooftop HVAC chiller units
        hvac_x = sx - bw * 0.1
        hvac_y = sy - h - 1.0 * self._zoom
        painter.setPen(QPen(QColor("#181825"), 1.0))
        painter.setBrush(QColor("#45475a"))
        painter.drawRect(QRectF(hvac_x, hvac_y - 4.0 * self._zoom, 6.0 * self._zoom, 4.0 * self._zoom))
        painter.setBrush(QColor("#585b70"))
        painter.drawRect(QRectF(hvac_x + 7.0 * self._zoom, hvac_y - 3.5 * self._zoom, 5.0 * self._zoom, 3.5 * self._zoom))

        # 2. Angled Communications Satellite Dish on pedestal
        dish_x = sx + bw * 0.35
        dish_y = sy - h - 4.0 * self._zoom
        painter.setPen(QPen(QColor("#7f849c"), 1.5 * self._zoom))
        painter.drawLine(QPointF(dish_x, sy - h), QPointF(dish_x, dish_y))
        painter.setPen(QPen(QColor("#181825"), 1.0))
        painter.setBrush(QColor("#cad3f5"))
        painter.drawEllipse(QPointF(dish_x, dish_y - 3.0 * self._zoom), 5.0 * self._zoom, 3.2 * self._zoom)
        painter.setBrush(QColor("#313244"))
        painter.drawEllipse(QPointF(dish_x + 1.2 * self._zoom, dish_y - 3.0 * self._zoom), 1.8 * self._zoom, 1.8 * self._zoom)

        # 3. Radio Whip Needle Antenna (Vertical rod ONLY, no crossbar)
        mast_h = 20.0 * self._zoom
        ant_x = sx - bw * 0.35
        painter.setPen(QPen(QColor("#cdd6f4"), 1.6 * self._zoom))
        painter.drawLine(QPointF(ant_x, sy - h), QPointF(ant_x, sy - h - mast_h))

        # Flashing police blue beacon atop whip antenna
        if has_power and int(self._anim_phase * 4) % 2 == 0:
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#89b4fa"))
            painter.drawEllipse(QPointF(ant_x, sy - h - mast_h), 2.8 * self._zoom, 2.8 * self._zoom)

    def _draw_isometric_fire_station(self, painter: QPainter, sx, sy, hw, hh, tile_id, has_power, is_zone_center):
        if not is_zone_center:
            # Station driveway & staging apron
            pad = QPolygonF([QPointF(sx, sy - hh), QPointF(sx + hw, sy), QPointF(sx, sy + hh), QPointF(sx - hw, sy)])
            painter.setPen(QPen(QColor("#181825"), 1.0))
            painter.setBrush(QColor("#383a4c"))
            painter.drawPolygon(pad)

            # Emergency response yellow crosshatch markings (#fab387)
            painter.setPen(QPen(QColor("#fab387"), 1.2 * self._zoom, Qt.DashLine))
            painter.drawLine(QPointF(sx - hw * 0.5, sy), QPointF(sx + hw * 0.5, sy))

            # Parked Fire Engine on front apron (tile 767/768)
            if tile_id in (767, 768):
                truck_w = 11.0 * self._zoom
                truck_h = 5.0 * self._zoom
                # Red cab and equipment body
                painter.setPen(QPen(QColor("#11111b"), 1.0))
                painter.setBrush(QColor("#ba3b3b"))
                painter.drawRoundedRect(QRectF(sx - truck_w * 0.5, sy - truck_h * 0.5, truck_w, truck_h), 1.5, 1.5)
                # Windshield
                painter.setBrush(QColor("#89dceb"))
                painter.drawRect(QRectF(sx + truck_w * 0.2, sy - truck_h * 0.35, truck_w * 0.25, truck_h * 0.7))
                # Silver ladder on rack
                painter.setPen(QPen(QColor("#cdd6f4"), 1.5 * self._zoom))
                painter.drawLine(QPointF(sx - truck_w * 0.45, sy - truck_h * 0.3), QPointF(sx + truck_w * 0.1, sy - truck_h * 0.3))
                # Amber headlights
                painter.setPen(Qt.NoPen)
                painter.setBrush(QColor("#f9e2af"))
                painter.drawEllipse(QPointF(sx + truck_w * 0.5, sy - truck_h * 0.25), 1.5 * self._zoom, 1.5 * self._zoom)
                painter.drawEllipse(QPointF(sx + truck_w * 0.5, sy + truck_h * 0.25), 1.5 * self._zoom, 1.5 * self._zoom)
            return

        # --- Center Tile: 3D Classic Red-Brick Firehouse Headquarters ---
        h = 22.0 * self._zoom
        bw = hw * 1.12
        bh = hh * 1.12

        top_p = QPolygonF([QPointF(sx, sy - bh - h), QPointF(sx + bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx - bw, sy - h)])
        left_p = QPolygonF([QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h), QPointF(sx, sy + bh), QPointF(sx - bw, sy)])
        right_p = QPolygonF([QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h), QPointF(sx + bw, sy), QPointF(sx, sy + bh)])

        # Shaded red-brick facade
        painter.setPen(QPen(QColor("#11111b"), 1.0))
        painter.setBrush(QColor("#7c2d2a")) # Dark brick left wall
        painter.drawPolygon(left_p)
        painter.setBrush(QColor("#ba3b3b")) # Rich brick red illuminated wall
        painter.drawPolygon(right_p)
        painter.setBrush(QColor("#313244")) # Dark gravel roof
        painter.drawPolygon(top_p)

        # Terra-cotta coping cornice
        painter.setPen(QPen(QColor("#e06c75"), 1.8 * self._zoom))
        painter.drawLine(QPointF(sx - bw, sy - h), QPointF(sx, sy + bh - h))
        painter.drawLine(QPointF(sx, sy + bh - h), QPointF(sx + bw, sy - h))

        # Dual Arched Apparatus Garage Bays on front facade
        bay_w = 7.0 * self._zoom
        bay_h = 10.0 * self._zoom
        for i, bx_off in enumerate([bw * 0.2, bw * 0.55]):
            bx = sx + bx_off
            by = sy + bh * 0.35 - bay_h + (i * 2.0 * self._zoom)
            # Stone arch frame
            painter.setPen(QPen(QColor("#bac2de"), 1.5 * self._zoom))
            painter.setBrush(QColor("#962d22")) # Red roll-up door
            painter.drawRoundedRect(QRectF(bx, by, bay_w, bay_h), 2.0, 2.0)
            # Yellow hazard caution stripes (#fab387)
            painter.setPen(QPen(QColor("#fab387"), 1.2 * self._zoom))
            painter.drawLine(QPointF(bx + 1, by + bay_h * 0.7), QPointF(bx + bay_w - 1, by + bay_h * 0.7))
            painter.drawLine(QPointF(bx + 1, by + bay_h * 0.85), QPointF(bx + bay_w - 1, by + bay_h * 0.85))

        # Gold "FIRE DEPT" badge plaque above bays
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#f9e2af"))
        painter.drawRect(QRectF(sx + bw * 0.3, sy - h * 0.25, 12.0 * self._zoom, 2.5 * self._zoom))

        # Square Hose-Drying Watchtower rising at back corner
        tw_w = 6.0 * self._zoom
        tw_h = 14.0 * self._zoom
        tx = sx - bw * 0.5
        ty = sy - h - tw_h
        painter.setPen(QPen(QColor("#11111b"), 1.0))
        painter.setBrush(QColor("#5e211e"))
        painter.drawRect(QRectF(tx, ty, tw_w, tw_h))
        # Tower hip roof
        painter.setBrush(QColor("#7c2d2a"))
        painter.drawPolygon(QPolygonF([
            QPointF(tx - 1.0 * self._zoom, ty),
            QPointF(tx + tw_w * 0.5, ty - 4.0 * self._zoom),
            QPointF(tx + tw_w + 1.0 * self._zoom, ty)
        ]))

        # Lit station dorm windows
        if has_power:
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#f9e2af"))
            ws = 2.2 * self._zoom
            painter.drawRect(QRectF(sx + bw * 0.25, sy - h * 0.5, ws, ws))
            painter.drawRect(QRectF(sx + bw * 0.6, sy - h * 0.5, ws, ws))

        # Animated Flashing Emergency Rooftop Beacon (Red strobe)
        if has_power and int(self._anim_phase * 4) % 2 == 0:
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#e64553"))
            painter.drawEllipse(QPointF(sx + bw * 0.4, sy - h - 3.0 * self._zoom), 3.5 * self._zoom, 3.5 * self._zoom)
            painter.setBrush(QColor("#ffffff"))
            painter.drawEllipse(QPointF(sx + bw * 0.4, sy - h - 3.0 * self._zoom), 1.5 * self._zoom, 1.5 * self._zoom)

    # --- Flashing 2.5D Isometric Lightning Badge (⚡) ---
    def _draw_isometric_lightning(self, painter: QPainter, cx, cy, hw):
        r = hw * 0.35
        painter.setPen(QPen(QColor("#ffffff"), 1.0))
        painter.setBrush(QColor("#e64553"))
        painter.drawEllipse(QPointF(cx, cy), r, r)

        # Yellow bolt
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#f9e2af"))
        bolt = QPolygonF([
            QPointF(cx + 1, cy - r * 0.6),
            QPointF(cx - r * 0.4, cy + r * 0.05),
            QPointF(cx, cy + r * 0.05),
            QPointF(cx - 1, cy + r * 0.6),
            QPointF(cx + r * 0.4, cy - r * 0.05),
            QPointF(cx, cy - r * 0.05),
        ])
        painter.drawPolygon(bolt)

    # --- Snapping 2.5D Isometric Placement Footprint ---
    def _draw_isometric_footprint(self, painter: QPainter, tw, th, hw, hh):
        footprint = TOOL_FOOTPRINTS.get(self._selected_tool, 1)
        cost = TOOL_COSTS.get(self._selected_tool, 0)
        funds = self._engine.funds if self._engine else 0

        gx = self._hover_x
        gy = self._hover_y

        # Validate buildability
        can_afford = (funds >= cost)
        is_clear = True
        for dx in range(footprint):
            for dy in range(footprint):
                tx = gx + dx
                ty = gy + dy
                if tx >= 120 or ty >= 100:
                    is_clear = False
                    break
                t = self._engine.get_tile(tx, ty) & 0x03ff
                if self._selected_tool == 7: # Bulldoze
                    pass
                elif self._selected_tool == 9: # Road
                    if t in (1, 2, 3) and not (self._is_road(tx - 1, ty) or self._is_road(tx + 1, ty)):
                        is_clear = False
                elif t in (1, 2, 3): # Water blocks non-bridges
                    is_clear = False
            if not is_clear:
                break

        is_valid = can_afford and is_clear

        border_col = QColor("#a6e3a1") if is_valid else QColor("#f38ba8")
        fill_col = QColor(166, 227, 161, 45) if is_valid else QColor(243, 139, 168, 45)

        # Exact 4 outer vertices of an N x N isometric footprint:
        # Top:    Top vertex of tile (gx, gy)
        # Right:  Right vertex of tile (gx + footprint - 1, gy)
        # Bottom: Bottom vertex of tile (gx + footprint - 1, gy + footprint - 1)
        # Left:   Left vertex of tile (gx, gy + footprint - 1)
        sx, sy = self.world_to_screen(gx, gy)
        N = footprint

        v_top = QPointF(sx, sy - hh)
        v_right = QPointF(sx + N * hw, sy + (N - 1) * hh)
        v_bottom = QPointF(sx, sy + (2 * N - 1) * hh)
        v_left = QPointF(sx - N * hw, sy + (N - 1) * hh)

        poly = QPolygonF([v_top, v_right, v_bottom, v_left])

        painter.setPen(QPen(border_col, 2.0))
        painter.setBrush(fill_col)
        painter.drawPolygon(poly)

        # Draw inner dashed grid lines for multi-tile zones
        if N > 1:
            painter.setPen(QPen(border_col, 1.0, Qt.DashLine))
            for i in range(1, N):
                # Line along gy direction: from tile (gx + i, gy) top-left edge to opposite
                p1 = QPointF(sx + i * hw, sy + (i - 1) * hh)
                p2 = QPointF(sx + (i - N) * hw, sy + (N + i - 1) * hh)
                painter.drawLine(p1, p2)

                # Line along gx direction: from tile (gx, gy + i) top-right edge to opposite
                q1 = QPointF(sx - i * hw, sy + (i - 1) * hh)
                q2 = QPointF(sx + (N - i) * hw, sy + (N + i - 1) * hh)
                painter.drawLine(q1, q2)

        # Price tag badge
        tag_w = 64
        tag_h = 24
        tag_x = v_right.x() + 10
        tag_y = v_right.y() - 12
        painter.setPen(QPen(border_col, 1.2))
        painter.setBrush(QColor("#181825ee"))
        painter.drawRoundedRect(QRectF(tag_x, tag_y, tag_w, tag_h), 5, 5)

        painter.setPen(border_col)
        painter.setFont(QFont("sans-serif", 9, QFont.Bold))
        cost_txt = f"${cost:,}" if cost > 0 else "Free"
        painter.drawText(QRectF(tag_x, tag_y, tag_w, tag_h), Qt.AlignCenter, cost_txt)

    # --- Dynamic Moving Traffic Simulation ---
    def _update_traffic(self):
        if not self._engine:
            return

        surviving_cars = []
        for car in self._traffic_cars:
            car['t'] += car['speed']
            if car['t'] >= 1.0:
                cgx, cgy = car['next_gx'], car['next_gy']
                if not self._is_road(cgx, cgy):
                    continue

                car['gx'], car['gy'] = cgx, cgy
                car['t'] = 0.0

                candidates = []
                for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                    nx, ny = cgx + dx, cgy + dy
                    if 0 <= nx < 120 and 0 <= ny < 100 and self._is_road(nx, ny):
                        if (nx, ny) != (car.get('prev_gx', -1), car.get('prev_gy', -1)):
                            candidates.append((nx, ny))

                if not candidates:
                    for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                        nx, ny = cgx + dx, cgy + dy
                        if 0 <= nx < 120 and 0 <= ny < 100 and self._is_road(nx, ny):
                            candidates.append((nx, ny))

                if candidates:
                    next_tile = random.choice(candidates)
                    car['prev_gx'], car['prev_gy'] = cgx, cgy
                    car['next_gx'], car['next_gy'] = next_tile
                    surviving_cars.append(car)
            else:
                surviving_cars.append(car)

        self._traffic_cars = surviving_cars

        # Maintain a lively fleet of cars on active roads
        if len(self._traffic_cars) < 14:
            self._traffic_spawn_timer += 1
            if self._traffic_spawn_timer >= 2:
                self._traffic_spawn_timer = 0
                top_left = self.screen_to_world(0, 0)
                bottom_right = self.screen_to_world(self.width(), self.height())
                min_x = max(0, min(top_left[0], bottom_right[0]) - 3)
                max_x = min(120, max(top_left[0], bottom_right[0]) + 3)
                min_y = max(0, min(top_left[1], bottom_right[1]) - 3)
                max_y = min(100, max(top_left[1], bottom_right[1]) + 3)

                if max_x > min_x and max_y > min_y:
                    for _ in range(12):
                        rx = random.randint(min_x, max_x - 1)
                        ry = random.randint(min_y, max_y - 1)
                        if self._is_road(rx, ry):
                            neighbors = []
                            for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                                nx, ny = rx + dx, ry + dy
                                if 0 <= nx < 120 and 0 <= ny < 100 and self._is_road(nx, ny):
                                    neighbors.append((nx, ny))
                            if neighbors:
                                nxt = random.choice(neighbors)
                                cols = [QColor("#ed8796"), QColor("#f9e2af"), QColor("#8aadf4"), QColor("#a6da95"), QColor("#cad3f5")]
                                self._traffic_cars.append({
                                    'gx': rx, 'gy': ry,
                                    'next_gx': nxt[0], 'next_gy': nxt[1],
                                    'prev_gx': rx, 'prev_gy': ry,
                                    't': random.random() * 0.5,
                                    'speed': 0.05 + random.random() * 0.03,
                                    'color': random.choice(cols)
                                })
                                break

    def _draw_traffic(self, painter: QPainter, tw, th, hw, hh):
        for car in self._traffic_cars:
            p1 = self.world_to_screen(car['gx'], car['gy'])
            p2 = self.world_to_screen(car['next_gx'], car['next_gy'])
            t = car['t']
            cx = p1[0] * (1.0 - t) + p2[0] * t
            cy = p1[1] * (1.0 - t) + p2[1] * t

            cw = 6.5 * self._zoom
            ch = 3.5 * self._zoom

            # Shadow
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(17, 17, 27, 130))
            painter.drawRoundedRect(QRectF(cx - cw * 0.5, cy - ch * 0.3, cw, ch), 1.0, 1.0)

            # Colored chassis
            painter.setPen(QPen(QColor("#181825"), 0.8))
            painter.setBrush(car['color'])
            painter.drawRoundedRect(QRectF(cx - cw * 0.5, cy - ch * 0.5 - 1.5 * self._zoom, cw, ch), 1.0, 1.0)

            # Windshield / Cab
            painter.setBrush(QColor("#181825"))
            painter.drawRect(QRectF(cx - cw * 0.25, cy - ch * 0.5 - 2.5 * self._zoom, cw * 0.5, ch * 0.6))

            # Headlights
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#f9e2af"))
            dx = p2[0] - p1[0]
            dy = p2[1] - p1[1]
            hx = cx + (cw * 0.38 if dx >= 0 else -cw * 0.38)
            hy = cy - 1.5 * self._zoom + (ch * 0.2 if dy >= 0 else -ch * 0.2)
            painter.drawEllipse(QPointF(hx, hy), 1.4 * self._zoom, 1.4 * self._zoom)

    # --- Moving Train Simulation ---
    def _update_train(self):
        if not self._engine:
            return

        if not self._train_cars:
            top_left = self.screen_to_world(0, 0)
            bottom_right = self.screen_to_world(self.width(), self.height())
            min_x = max(0, min(top_left[0], bottom_right[0]) - 5)
            max_x = min(120, max(top_left[0], bottom_right[0]) + 5)
            min_y = max(0, min(top_left[1], bottom_right[1]) - 5)
            max_y = min(100, max(top_left[1], bottom_right[1]) + 5)

            found = None
            for x in range(min_x, max_x):
                for y in range(min_y, max_y):
                    if self._is_rail(x, y):
                        for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < 120 and 0 <= ny < 100 and self._is_rail(nx, ny):
                                found = (x, y, nx, ny)
                                break
                    if found: break
                if found: break

            if found:
                self._train_cars = [{
                    'gx': found[0], 'gy': found[1],
                    'next_gx': found[2], 'next_gy': found[3],
                    'prev_gx': found[0], 'prev_gy': found[1],
                    't': 0.0,
                    'speed': 0.045
                }]
            return

        train = self._train_cars[0]
        train['t'] += train['speed']
        if train['t'] >= 1.0:
            tgx, tgy = train['next_gx'], train['next_gy']
            if not self._is_rail(tgx, tgy):
                self._train_cars = []
                return

            train['gx'], train['gy'] = tgx, tgy
            train['t'] = 0.0

            candidates = []
            for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                nx, ny = tgx + dx, tgy + dy
                if 0 <= nx < 120 and 0 <= ny < 100 and self._is_rail(nx, ny):
                    if (nx, ny) != (train['prev_gx'], train['prev_gy']):
                        candidates.append((nx, ny))

            if not candidates:
                for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                    nx, ny = tgx + dx, tgy + dy
                    if 0 <= nx < 120 and 0 <= ny < 100 and self._is_rail(nx, ny):
                        candidates.append((nx, ny))

            if candidates:
                nxt = random.choice(candidates)
                train['prev_gx'], train['prev_gy'] = tgx, tgy
                train['next_gx'], train['next_gy'] = nxt
            else:
                self._train_cars = []

    def _draw_train(self, painter: QPainter, tw, th, hw, hh):
        if not self._train_cars:
            return

        train = self._train_cars[0]
        p1 = self.world_to_screen(train['gx'], train['gy'])
        p2 = self.world_to_screen(train['next_gx'], train['next_gy'])
        t = train['t']
        cx = p1[0] * (1.0 - t) + p2[0] * t
        cy = p1[1] * (1.0 - t) + p2[1] * t

        lw = 13.0 * self._zoom
        lh = 6.5 * self._zoom

        # Shadow
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor(17, 17, 27, 140))
        painter.drawRoundedRect(QRectF(cx - lw * 0.5, cy - lh * 0.2, lw, lh), 2.0, 2.0)

        # Locomotive Shell (Navy #1e2030 with Orange stripe #ea999c)
        painter.setPen(QPen(QColor("#11111b"), 1.0))
        painter.setBrush(QColor("#1e2030"))
        painter.drawRoundedRect(QRectF(cx - lw * 0.5, cy - lh * 0.5 - 3.0 * self._zoom, lw, lh), 2.0, 2.0)
        painter.setBrush(QColor("#ea999c"))
        painter.drawRect(QRectF(cx - lw * 0.5, cy - 2.0 * self._zoom, lw, 2.0 * self._zoom))

        # Streamlined cab & windows
        painter.setBrush(QColor("#89dceb"))
        painter.drawRect(QRectF(cx - lw * 0.2, cy - lh * 0.5 - 4.5 * self._zoom, lw * 0.4, 2.5 * self._zoom))

        # High-power headlight beam
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor(249, 226, 175, 180))
        painter.drawEllipse(QPointF(cx + lw * 0.5, cy - 2.0 * self._zoom), 3.0 * self._zoom, 3.0 * self._zoom)
