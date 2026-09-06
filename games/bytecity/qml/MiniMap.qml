import QtQuick
import QtQuick.Controls

Rectangle {
    id: miniMapRoot
    width: 256
    height: 236
    color: "#181825"
    radius: 12
    border.color: "#313244"
    border.width: 1

    property QtObject engine: null
    property var viewport: null

    // Window header
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        color: "#1e1e2e"
        radius: 12

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12
            color: "#1e1e2e"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "🗺️ WORLD RADAR"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: "#cdd6f4"
        }

        // Close button
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: closeMouse.containsMouse ? "#f38ba8" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 11
                color: closeMouse.containsMouse ? "#11111b" : "#6c7086"
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: miniMapRoot.visible = false
            }
        }
    }

    // MiniMap 120x100 Render Canvas
    Canvas {
        id: mapCanvas
        anchors.top: header.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: 240
        height: 200

        onPaint: {
            var ctx = getContext("2d");
            ctx.fillStyle = "#11111b";
            ctx.fillRect(0, 0, width, height);

            if (!miniMapRoot.engine) return;

            var scaleX = width / 120.0;
            var scaleY = height / 100.0;

            for (var x = 0; x < 120; x += 2) {
                for (var y = 0; y < 100; y += 2) {
                    var raw = miniMapRoot.engine.get_tile(x, y);
                    var t = raw & 0x03ff;
                    if (t === 1 || t === 2 || t === 3) {
                        ctx.fillStyle = "#1e4064"; // Deep Water
                    } else if (t >= 21 && t <= 36) {
                        ctx.fillStyle = "#284d22"; // Trees
                    } else if ((t >= 64 && t <= 78) || (t >= 128 && t <= 207)) {
                        ctx.fillStyle = "#4c535c"; // Road (Asphalt)
                    } else if (t >= 79 && t <= 94) {
                        ctx.fillStyle = "#b47846"; // Rail
                    } else if (t >= 208 && t <= 222) {
                        ctx.fillStyle = "#f9e2af"; // Power
                    } else if (t >= 240 && t <= 422) {
                        ctx.fillStyle = "#a6e3a1"; // Residential
                    } else if (t >= 423 && t <= 605) {
                        ctx.fillStyle = "#89dceb"; // Commercial
                    } else if (t >= 612 && t <= 692) {
                        ctx.fillStyle = "#fab387"; // Industrial
                    } else if (t > 692) {
                        ctx.fillStyle = "#cba6f7"; // Civic
                    } else {
                        ctx.fillStyle = "#3d6634"; // Grass Land
                    }
                    ctx.fillRect(x * scaleX, y * scaleY, scaleX * 2, scaleY * 2);
                }
            }

            // Draw camera view bounding box
            if (miniMapRoot.viewport) {
                var tl = miniMapRoot.viewport.screen_to_world(0, 0);
                var br = miniMapRoot.viewport.screen_to_world(miniMapRoot.viewport.width, miniMapRoot.viewport.height);

                var rx = Math.max(0, Math.min(120, tl[0])) * scaleX;
                var ry = Math.max(0, Math.min(100, tl[1])) * scaleY;
                var rw = Math.max(8, (br[0] - tl[0]) * scaleX);
                var rh = Math.max(8, (br[1] - tl[1]) * scaleY);

                ctx.strokeStyle = "#f38ba8";
                ctx.lineWidth = 1.5;
                ctx.strokeRect(rx, ry, rw, rh);
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor

            function jump(mouse) {
                var gx = Math.floor((mouse.x / width) * 120);
                var gy = Math.floor((mouse.y / height) * 100);
                if (miniMapRoot.viewport) {
                    miniMapRoot.viewport.pan_to_tile(gx, gy);
                }
            }

            onClicked: (mouse) => jump(mouse)
            onPositionChanged: (mouse) => {
                if (pressed) jump(mouse);
            }
        }
    }

    Connections {
        target: miniMapRoot.engine
        function onMapChanged() {
            mapCanvas.requestPaint();
        }
    }

    Connections {
        target: miniMapRoot.viewport
        function onCameraChanged() {
            mapCanvas.requestPaint();
        }
    }
}
