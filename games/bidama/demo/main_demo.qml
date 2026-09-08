import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root
    visible: true
    width: 900
    height: 720
    title: "Bīdama (ビー玉) • Artisanal 3D Glass Marble & Tatami Visual Demo"
    color: "#18181b"

    property real rollAngle: 0.0
    property real rollSpeed: 0.0
    property bool autoRoll: true
    property int selectedMarbleIndex: 0

    function captureScreenshot(filePath) {
        tatamiSection.parent.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Visual demo screenshot saved to " + filePath);
        });
    }

    // Master list of 7 marbles in the demo column
    property var columnMarbles: [
        { type: "ramune", label: "Ramune Codd Glass" },
        { type: "matcha", label: "Matcha Swirl Ribbon" },
        { type: "sakura", label: "Sakura Blossom & Gold" },
        { type: "yuzu", label: "Yuzu Amber Helix" },
        { type: "asagao", label: "Asagao Night Galaxy" },
        { type: "basalt", label: "Kyoto Basalt Stone" },
        { type: "matcha", label: "Matcha Swirl (2nd)" }
    ]

    // Auto-roll ticker
    Timer {
        interval: 16
        running: root.autoRoll
        repeat: true
        onTriggered: {
            root.rollAngle += 0.025;
            if (root.rollAngle > Math.PI * 2) {
                root.rollAngle -= Math.PI * 2;
            }
        }
    }

    // Keyboard handlers
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_W) {
                root.autoRoll = false;
                root.rollAngle -= 0.08;
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
                root.autoRoll = false;
                root.rollAngle += 0.08;
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                root.autoRoll = !root.autoRoll;
                event.accepted = true;
            }
        }
    }

    // Main Layout: Left = Tatami Chute & Interactive Column; Right = 4x Magnifier & Controls
    Row {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // =====================================================================
        // LEFT: TATAMI VERANDA & CARVED HINOKI CHUTE (420px wide)
        // =====================================================================
        Rectangle {
            id: tatamiSection
            width: 440
            height: parent.height
            radius: 16
            color: "#37472F" // Authentic olive green aged igusa rush
            border.color: "#1B2418"
            border.width: 4
            clip: true

            // 1. Procedural Woven Tatami Mat Weave
            Canvas {
                anchors.fill: parent
                opacity: 0.22
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 1;
                    // Horizontal rush reeds
                    for (var y = 0; y < height; y += 4) {
                        ctx.beginPath();
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                        ctx.stroke();
                    }
                    // Vertical warp threads every 28px
                    ctx.strokeStyle = "rgba(0, 0, 0, 0.4)";
                    ctx.lineWidth = 1.5;
                    for (var x = 0; x < width; x += 28) {
                        ctx.beginPath();
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                        ctx.stroke();
                    }
                }
            }

            // 2. Left & Right Traditional Silk Brocade Borders (Heri) with Gold Monograms
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 22
                color: "#111812"

                // Inlaid gold stitch seam
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: "#d4af37"
                    opacity: 0.75
                }
                // Repeating diamond crests
                Column {
                    anchors.centerIn: parent
                    spacing: 36
                    Repeater {
                        model: 12
                        Text {
                            text: "❖"
                            font.pixelSize: 10
                            color: "#d4af37"
                            opacity: 0.45
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 22
                color: "#111812"

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: "#d4af37"
                    opacity: 0.75
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 36
                    Repeater {
                        model: 12
                        Text {
                            text: "❖"
                            font.pixelSize: 10
                            color: "#d4af37"
                            opacity: 0.45
                        }
                    }
                }
            }

            // 3. Central Carved Hinoki Cypress Chute Tray
            Rectangle {
                id: chuteTray
                anchors.centerIn: parent
                width: 130
                height: parent.height - 40
                radius: 14
                color: "#D7B588" // Warm Hinoki cypress wood
                border.color: "#8C6A42"
                border.width: 3

                // Hinoki Wood Grain texture
                Canvas {
                    anchors.fill: parent
                    opacity: 0.15
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.strokeStyle = "#5C3E1F";
                        ctx.lineWidth = 1;
                        for (var y = 0; y < height; y += 12) {
                            ctx.beginPath();
                            ctx.moveTo(0, y);
                            ctx.bezierCurveTo(width * 0.3, y + 4, width * 0.7, y - 4, width, y);
                            ctx.stroke();
                        }
                    }
                }

                // Deep Carved Center Marble Flute (concave trough)
                Rectangle {
                    id: grooveFlute
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    width: 84
                    radius: 42
                    color: "#B59062" // Shadowed recess of carved trough
                    border.color: "#6B4926"
                    border.width: 2

                    // Inner depth drop shadow along left & right sides of trough
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        color: "#000000"
                        opacity: 0.25
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        color: "#000000"
                        opacity: 0.25
                    }

                    // Interactive Draggable Column of 7 Marbles
                    Item {
                        id: marbleColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 76
                        height: parent.height

                        // Drag mouse area: Drag up/down to roll marbles with true 1:1 physical rotation!
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.OpenHandCursor
                            preventStealing: true

                            property real lastY: 0

                            onPressed: function(mouse) {
                                root.autoRoll = false;
                                lastY = mouse.y;
                                dragArea.cursorShape = Qt.ClosedHandCursor;
                            }

                            onReleased: {
                                dragArea.cursorShape = Qt.OpenHandCursor;
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var dy = mouse.y - lastY;
                                    lastY = mouse.y;
                                    // Rolling formula: theta = distance / radius (r = 34px)
                                    root.rollAngle += (dy / 34.0);
                                }
                            }
                        }

                        // The 7 Marbles stacked vertically
                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            Repeater {
                                model: root.columnMarbles.length

                                Item {
                                    id: marbleWrapper
                                    width: 72
                                    height: 72

                                    // Ground contact shadow in carved flute
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        width: 54
                                        height: 16
                                        radius: 8
                                        color: "#000000"
                                        opacity: 0.45
                                    }

                                    // Selection highlight halo
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 76
                                        height: 76
                                        radius: 38
                                        color: "transparent"
                                        border.color: "#38bdf8"
                                        border.width: 2.5
                                        visible: root.selectedMarbleIndex === index
                                        opacity: 0.85
                                    }

                                    // 3D Glass Marble
                                    Marble3D {
                                        anchors.centerIn: parent
                                        width: 70
                                        height: 70
                                        marbleType: root.columnMarbles[index].type
                                        rollAngle: root.rollAngle
                                    }

                                    // Click to inspect
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedMarbleIndex = index;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Overlay Hint Banner
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                width: 280
                height: 30
                radius: 15
                color: Qt.rgba(0, 0, 0, 0.7)
                border.color: "#d4af37"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "🖱️ Drag chute or Press ↑ / ↓ to roll"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#f8fafc"
                }
            }
        }

        // =====================================================================
        // RIGHT: 4X MAGNIFIER INSPECTOR & ARTISANAL STYLE SELECTOR (390px wide)
        // =====================================================================
        Rectangle {
            id: inspectorPanel
            width: parent.width - tatamiSection.width - 24
            height: parent.height
            radius: 16
            color: "#27272a"
            border.color: "#3f3f46"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // Title
                Row {
                    spacing: 10
                    Text {
                        text: "🔮"
                        font.pixelSize: 22
                    }
                    Column {
                        Text {
                            text: "Artisanal Studio Glass Inspector"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }
                        Text {
                            text: "Raytraced 3D spherical rolling & internal refraction"
                            font.pixelSize: 11
                            color: "#a1a1aa"
                        }
                    }
                }

                // 4x Magnifier Card
                Rectangle {
                    width: parent.width
                    height: 220
                    radius: 12
                    color: "#18181b"
                    border.color: "#38bdf8"
                    border.width: 1.5

                    // Background dark wood pad
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 10
                        radius: 8
                        color: "#09090b"

                        // Large 4X Close-up 3D Marble
                        Marble3D {
                            id: bigMarble
                            anchors.centerIn: parent
                            width: 170
                            height: 170
                            marbleType: root.columnMarbles[root.selectedMarbleIndex].type
                            rollAngle: root.rollAngle
                            specularStrength: 1.15
                        }

                        // Badge with active style name
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            height: 24
                            width: activeLabel.implicitWidth + 16
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.color: "#38bdf8"
                            border.width: 1

                            Text {
                                id: activeLabel
                                anchors.centerIn: parent
                                text: root.columnMarbles[root.selectedMarbleIndex].label
                                font.pixelSize: 11
                                font.bold: true
                                color: "#38bdf8"
                            }
                        }

                        // Live Math Readout (Bottom Right)
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 8
                            text: "θ = " + ((root.rollAngle * 180 / Math.PI) % 360).toFixed(1) + "°"
                            font.pixelSize: 11
                            font.family: "Monospace"
                            color: "#a1a1aa"
                        }
                    }
                }

                // Continuous Auto-Roll Controls
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 8
                    color: "#18181b"
                    border.color: "#3f3f46"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            height: 32
                            width: 140
                            radius: 6
                            color: root.autoRoll ? "#0284c7" : "#3f3f46"
                            Text {
                                anchors.centerIn: parent
                                text: root.autoRoll ? "⏸️ Pause Auto-Roll" : "▶️ Start Auto-Roll"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.autoRoll = !root.autoRoll
                            }
                        }

                        Rectangle {
                            height: 32
                            width: 100
                            radius: 6
                            color: "#27272a"
                            border.color: "#52525b"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "↺ Reset θ"
                                font.pixelSize: 12
                                color: "#e4e4e7"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.rollAngle = 0.0;
                                }
                            }
                        }
                    }
                }

                // Style Switcher (Click to change selected marble's style)
                Text {
                    text: "Select Marble Style To Test:"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#d4d4d8"
                }

                Grid {
                    columns: 2
                    spacing: 8
                    width: parent.width

                    // 1. Ramune
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "ramune" ? "#083344" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "ramune" ? "#06b6d4" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🩵"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Ramune Codd"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Floating inner ball & fizz"; font.pixelSize: 9; color: "#06b6d4" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "ramune", label: "Ramune Codd Glass" };
                                root.columnMarbles = copy;
                            }
                        }
                    }

                    // 2. Matcha
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "matcha" ? "#052e16" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "matcha" ? "#22c55e" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🍵"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Matcha Swirl"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Double latticino ribbon"; font.pixelSize: 9; color: "#86efac" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "matcha", label: "Matcha Swirl Ribbon" };
                                root.columnMarbles = copy;
                            }
                        }
                    }

                    // 3. Sakura
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "sakura" ? "#500724" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "sakura" ? "#f43f5e" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🌸"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Sakura Blossom"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Petals & gold leaf flakes"; font.pixelSize: 9; color: "#fda4af" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "sakura", label: "Sakura Blossom & Gold" };
                                root.columnMarbles = copy;
                            }
                        }
                    }

                    // 4. Yuzu
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "yuzu" ? "#451a03" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "yuzu" ? "#f59e0b" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🍊"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Yuzu Amber"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Fiery double helix twist"; font.pixelSize: 9; color: "#fcd34d" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "yuzu", label: "Yuzu Amber Helix" };
                                root.columnMarbles = copy;
                            }
                        }
                    }

                    // 5. Asagao
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "asagao" ? "#1e1b4b" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "asagao" ? "#818cf8" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🌌"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Asagao Galaxy"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Dichroic glitter starfield"; font.pixelSize: 9; color: "#c7d2fe" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "asagao", label: "Asagao Night Galaxy" };
                                root.columnMarbles = copy;
                            }
                        }
                    }

                    // 6. Basalt
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 42
                        radius: 8
                        color: root.columnMarbles[root.selectedMarbleIndex].type === "basalt" ? "#0f172a" : "#18181b"
                        border.color: root.columnMarbles[root.selectedMarbleIndex].type === "basalt" ? "#94a3b8" : "#3f3f46"
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "🪨"; font.pixelSize: 14 }
                            Column {
                                Text { text: "Kyoto Basalt"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                                Text { text: "Matte volcanic stone & quartz"; font.pixelSize: 9; color: "#cbd5e1" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var copy = root.columnMarbles.slice();
                                copy[root.selectedMarbleIndex] = { type: "basalt", label: "Kyoto Basalt Stone" };
                                root.columnMarbles = copy;
                            }
                        }
                    }
                }
            }
        }
    }
}
