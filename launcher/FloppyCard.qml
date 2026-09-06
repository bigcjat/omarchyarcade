import QtQuick
import QtQuick.Controls

Item {
    id: card
    width: 220
    height: 286

    property var gameData: null
    property bool isSelected: false
    property bool isFocused: false
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isUnreleased: gameData && gameData.status === "unreleased"

    signal clicked()

    z: card.isFocused ? 30 : (card.isHovered ? 10 : 1)
    scale: mouseArea.pressed ? 0.97 : (isFocused ? 1.05 : (isHovered ? 1.04 : 1.0))
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Drop shadow / glow halo when hovered or keyboard-focused
    Rectangle {
        anchors.fill: floppyBody
        anchors.margins: card.isFocused ? -6 : -4
        radius: 12
        color: "transparent"
        border.color: card.isFocused ? "#00f0ff" : (card.isHovered ? (gameData ? gameData.grid_color : "#00f0ff") : "transparent")
        border.width: card.isFocused ? 3.5 : 2
        opacity: card.isFocused ? 1.0 : (card.isHovered ? 0.85 : 0)
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // --- 1. 3.5" Floppy Disk Body ---
    Rectangle {
        id: floppyBody
        anchors.fill: parent
        anchors.margins: 4
        radius: 8
        color: gameData ? gameData.floppy_color : "#232328"
        border.color: "#111115"
        border.width: 2
        clip: true

        // Top-right beveled notch
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: 16
            height: 16
            color: "#121215"
            rotation: 45
            x: 8
            y: -8
        }

        // Drive arrow indicator (Top-Left)
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            text: "▲"
            font.pixelSize: 13
            font.bold: true
            color: Qt.darker(floppyBody.color, 1.4)
            opacity: 0.6
        }

        // High Density (HD) Logo (Top-Right)
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            text: "HD"
            font.family: "monospace"
            font.pixelSize: 12
            font.bold: true
            color: Qt.darker(floppyBody.color, 1.4)
            opacity: 0.6
        }

        // Bottom left & right sensor cutouts
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 8
            width: 10
            height: 10
            radius: 1
            color: "#0a0a0e"
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 8
            width: 10
            height: 10
            radius: 1
            color: "#0a0a0e"
        }

        // --- 2. Metal Sliding Shutter (Top Center) ---
        Rectangle {
            id: shutter
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.48
            height: parent.height * 0.26
            radius: 2
            color: "#B4B8C0"
            border.color: "#8A8E96"
            border.width: 1.5

            // Shutter vertical read-head aperture cutout
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.38
                height: parent.height * 0.72
                radius: 1
                color: Qt.darker(floppyBody.color, 1.2)
                border.color: "#737780"
                border.width: 1
            }
        }

        // --- 3. Sega Master System Label ---
        Rectangle {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: parent.width * 0.88
            height: parent.height * 0.64
            radius: 5
            color: "#FFFFFF"
            border.color: "#2B2B33"
            border.width: 1.5
            clip: true

            // Top Header: Sega Grid Header with "OMARCHY ARCADE"
            Rectangle {
                id: labelHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                color: gameData ? gameData.grid_color : "#06B6D4"

                // Procedural Grid Lines
                Canvas {
                    anchors.fill: parent
                    opacity: 0.35
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.strokeStyle = "#FFFFFF";
                        ctx.lineWidth = 1;
                        for (var x = 0; x < width; x += 10) {
                            ctx.beginPath();
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, height);
                            ctx.stroke();
                        }
                        for (var y = 0; y < height; y += 8) {
                            ctx.beginPath();
                            ctx.moveTo(0, y);
                            ctx.lineTo(width, y);
                            ctx.stroke();
                        }
                    }
                }

                // Header Brand Typography (Uniform across all disks)
                Text {
                    anchors.centerIn: parent
                    text: "OMARCHY ARCADE"
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.5
                    color: "#FFFFFF"
                }
            }

            // Game Title (Uniform retro typography)
            Text {
                id: titleText
                anchors.top: labelHeader.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 12
                text: gameData ? gameData.title.toUpperCase() : ""
                font.family: "monospace"
                font.pixelSize: 15
                font.bold: true
                color: "#18181F"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Center Artwork Frame
            Rectangle {
                id: artWindow
                anchors.top: titleText.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                anchors.bottom: footerStrip.top
                anchors.bottomMargin: 6
                color: "#181820"
                radius: 2
                border.color: "#282830"
                border.width: 1.5
                clip: true

                // Procedural Vector Game Badges (Fallback)
                Loader {
                    id: badgeLoader
                    anchors.fill: parent
                    anchors.margins: 4
                    sourceComponent: getBadgeComponent(gameData ? gameData.id : "")
                    visible: rasterArt.status !== Image.Ready
                }

                // Painted Retro Box Art Raster (Spirit of the Game)
                Image {
                    id: rasterArt
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    sourceSize.width: 360
                    sourceSize.height: 270
                    source: (typeof arcadeBackend !== "undefined" && gameData && gameData.id) ? arcadeBackend.getCoverUrl(gameData.id) : ((gameData && gameData.id) ? ("../assets/covers/" + gameData.id + ".png") : "")
                    visible: status === Image.Ready
                }
            }

            // Bottom Technical Strip (NO MB SIZE!)
            Rectangle {
                id: footerStrip
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 20
                color: "#F1F2F6"
                border.color: "#E2E4E9"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    text: gameData ? (gameData.category.toUpperCase() + " • " + gameData.ref) : ""
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.bold: true
                    color: "#475569"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }

        // --- 4. Unreleased "COMING SOON" Badge Overlay ---
        Rectangle {
            id: unreleasedOverlay
            anchors.fill: parent
            color: "#cc0a0a10"
            visible: isUnreleased
            z: 50

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: 32
                radius: 6
                color: "#f59e0b"
                border.color: "#d97706"
                border.width: 1.5
                rotation: -6

                Text {
                    anchors.centerIn: parent
                    text: "COMING SOON"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                    color: "#18181b"
                }
            }
        }
    }

    // --- Interactive Mouse Area ---
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }

    // Helper to select the procedural vector badge
    function getBadgeComponent(id) {
        switch(id) {
            case "2048": return comp2048;
            case "tetrablocks": return compTetra;
            case "bytesnake": return compSnake;
            case "vectorpong": return compPong;
            case "cybersweeper": return compSweeper;
            case "dropfour": return compDropFour;
            case "brickbash": return compBrick;
            case "voidinvaders": return compInvaders;
            case "vectordrift": return compDrift;
            case "cyberflap": return compFlap;
            case "cyberhop": return compHop;
            case "cratepusher": return compCrate;
            case "dinorunner": return compDino;
            case "wordguess": return compWord;
            case "bytecity": return compCity;
            case "galacticswarm": return compGalaga;
            case "byteman": return compPacman;
            case "gemswap": return compGems;
            case "orbpop": return compOrbPop;
            case "keiracer": return compKeiRacer;
            default: return compDefault;
        }
    }

    // =========================================================================
    // PROCEDURAL VECTOR GAME BADGES (Crisp vector / pixel art per game)
    // =========================================================================

    // 1. 2048 Badge
    Component {
        id: comp2048
        Grid {
            columns: 4; spacing: 3; anchors.centerIn: parent
            Repeater {
                model: [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4]
                Rectangle {
                    width: 28; height: 16; radius: 3
                    color: modelData >= 1024 ? "#f59e0b" : (modelData >= 64 ? "#f97316" : (modelData >= 8 ? "#38bdf8" : "#64748b"))
                    Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 8; font.bold: true; color: "#FFFFFF" }
                }
            }
        }
    }

    // 2. TetraBlocks Badge
    Component {
        id: compTetra
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var s = 10;
                var colors = ["#00f0ff", "#f59e0b", "#a855f7", "#22c55e", "#ef4444", "#3b82f6"];
                for (var r = 0; r < 4; r++) {
                    for (var c = 0; c < 7; c++) {
                        if ((r + c) % 2 === 0 || r === 3) {
                            ctx.fillStyle = colors[(r * 3 + c) % colors.length];
                            ctx.fillRect(c * (s + 2) + 18, r * (s + 2) + 12, s, s);
                        }
                    }
                }
            }
        }
    }

    // 3. ByteSnake Badge
    Component {
        id: compSnake
        Item {
            anchors.fill: parent
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 6
                    Rectangle {
                        width: 12; height: 12; radius: 2
                        color: index === 5 ? "#4ade80" : "#22c55e"
                        Rectangle {
                            visible: index === 5
                            width: 3; height: 3; radius: 1; color: "#000000"
                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2
                        }
                    }
                }
                Item { width: 14; height: 1 } // gap
                Rectangle { width: 12; height: 12; radius: 6; color: "#ef4444" } // Apple
            }
        }
    }

    // 4. VectorPong Badge
    Component {
        id: compPong
        Item {
            anchors.fill: parent
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 32; radius: 2; color: "#22c55e" }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 32; radius: 2; color: "#ef4444" }
            Rectangle { anchors.centerIn: parent; width: 8; height: 8; color: "#FFFFFF" }
            // Dashed net
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.fill: parent
                spacing: 4
                Repeater {
                    model: 8
                    Rectangle { width: 2; height: 6; color: "#334155" }
                }
            }
        }
    }

    // 5. CyberSweeper Badge
    Component {
        id: compSweeper
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var startX = Math.round((width - 4 * 24 - 3 * 3) / 2);
                var startY = Math.round((height - 3 * 20 - 2 * 3) / 2);
                var grid = [
                    ["1", "flag", "2", "mine"],
                    ["2", "3", "1", "1"],
                    ["mine", "1", "flag", "2"]
                ];
                for (var r = 0; r < 3; r++) {
                    for (var c = 0; c < 4; c++) {
                        var cellX = startX + c * 27;
                        var cellY = startY + r * 23;
                        var val = grid[r][c];
                        var isRevealed = (val !== "flag");
                        ctx.fillStyle = isRevealed ? "#94a3b8" : "#cbd5e1";
                        ctx.fillRect(cellX, cellY, 24, 20);
                        ctx.strokeStyle = isRevealed ? "#64748b" : "#f1f5f9";
                        ctx.strokeRect(cellX, cellY, 24, 20);

                        if (val === "flag") {
                            ctx.fillStyle = "#1e293b";
                            ctx.fillRect(cellX + 11, cellY + 4, 2, 12);
                            ctx.fillRect(cellX + 7, cellY + 15, 10, 2);
                            ctx.fillStyle = "#ef4444";
                            ctx.beginPath();
                            ctx.moveTo(cellX + 11, cellY + 4);
                            ctx.lineTo(cellX + 4, cellY + 7);
                            ctx.lineTo(cellX + 11, cellY + 10);
                            ctx.closePath();
                            ctx.fill();
                        } else if (val === "mine") {
                            var mx = cellX + 12;
                            var my = cellY + 10;
                            ctx.strokeStyle = "#0f172a";
                            ctx.lineWidth = 1.5;
                            for (var a = 0; a < 8; a++) {
                                var rad = a * Math.PI / 4;
                                ctx.beginPath();
                                ctx.moveTo(mx + Math.cos(rad) * 3, my + Math.sin(rad) * 3);
                                ctx.lineTo(mx + Math.cos(rad) * 7.5, my + Math.sin(rad) * 7.5);
                                ctx.stroke();
                            }
                            ctx.fillStyle = "#0f172a";
                            ctx.beginPath();
                            ctx.arc(mx, my, 5, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(mx - 1.5, my - 1.5, 1.2, 0, Math.PI * 2);
                            ctx.fill();
                        } else {
                            ctx.font = "bold 12px monospace";
                            ctx.fillStyle = val === "1" ? "#1d4ed8" : (val === "2" ? "#15803d" : "#b91c1c");
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(val, cellX + 12, cellY + 11);
                        }
                    }
                }
            }
        }
    }

    // 6. DropFour Badge
    Component {
        id: compDropFour
        Grid {
            columns: 6; spacing: 3; anchors.centerIn: parent
            Repeater {
                model: 18
                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: index % 5 === 0 ? "#ef4444" : (index % 3 === 0 ? "#eab308" : "#1e293b")
                    border.color: "#3b82f6"; border.width: 1.5
                }
            }
        }
    }

    // 7. BrickBash Badge
    Component {
        id: compBrick
        Item {
            anchors.fill: parent
            Column {
                anchors.top: parent.top; anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                Repeater {
                    model: ["#ef4444", "#f97316", "#eab308", "#22c55e", "#38bdf8"]
                    Row {
                        spacing: 2
                        Repeater {
                            model: 6
                            Rectangle { width: 16; height: 7; radius: 1; color: modelData }
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter; width: 34; height: 6; radius: 2; color: "#06b6d4" }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 16; x: parent.width * 0.58; width: 6; height: 6; radius: 3; color: "#FFFFFF" }
        }
    }

    // 8. VoidInvaders Badge
    Component {
        id: compInvaders
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var squid = [
                    "00011000",
                    "00111100",
                    "01111110",
                    "11011011",
                    "11111111",
                    "00100100",
                    "01011010",
                    "10100101"
                ];

                var crab = [
                    "00100000100",
                    "00010001000",
                    "00111111100",
                    "01101110110",
                    "11111111111",
                    "10111111101",
                    "10100000101",
                    "00011011000"
                ];

                function drawMatrix(mat, ox, oy, pSize, col) {
                    ctx.fillStyle = col;
                    for (var r = 0; r < mat.length; r++) {
                        for (var c = 0; c < mat[r].length; c++) {
                            if (mat[r][c] === "1") {
                                ctx.fillRect(ox + c * pSize, oy + r * pSize, pSize, pSize);
                            }
                        }
                    }
                }

                drawMatrix(squid, 24, 8, 1.8, "#c084fc");
                drawMatrix(squid, 66, 8, 1.8, "#c084fc");
                drawMatrix(squid, 108, 8, 1.8, "#c084fc");

                drawMatrix(crab, 20, 26, 1.6, "#38bdf8");
                drawMatrix(crab, 63, 26, 1.6, "#38bdf8");
                drawMatrix(crab, 106, 26, 1.6, "#38bdf8");

                ctx.fillStyle = "#22c55e";
                ctx.fillRect(66, 52, 20, 8);
                ctx.fillRect(73, 47, 6, 5);
                ctx.fillRect(75, 43, 2, 4);
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(75, 36, 2, 5);
            }
        }
    }

    // 9. VectorDrift Badge
    Component {
        id: compDrift
        Item {
            anchors.fill: parent
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.strokeStyle = "#00f0ff";
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    ctx.moveTo(35, 45);
                    ctx.lineTo(15, 25);
                    ctx.lineTo(25, 45);
                    ctx.lineTo(15, 65);
                    ctx.closePath();
                    ctx.stroke();

                    ctx.strokeStyle = "#94a3b8";
                    ctx.beginPath();
                    ctx.arc(85, 30, 16, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(95, 55, 9, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }
        }
    }

    // 10. CyberFlap Badge
    Component {
        id: compFlap
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#15803d";
                ctx.strokeStyle = "#4ade80";
                ctx.lineWidth = 1.5;

                // Pillar 1
                ctx.fillRect(20, 0, 16, 26);
                ctx.strokeRect(20, 0, 16, 26);
                ctx.fillRect(18, 23, 20, 5);
                ctx.strokeRect(18, 23, 20, 5);

                ctx.fillRect(20, 48, 16, 22);
                ctx.strokeRect(20, 48, 16, 22);
                ctx.fillRect(18, 46, 20, 5);
                ctx.strokeRect(18, 46, 20, 5);

                // Pillar 2
                ctx.fillRect(108, 0, 16, 20);
                ctx.strokeRect(108, 0, 16, 20);
                ctx.fillRect(106, 17, 20, 5);
                ctx.strokeRect(106, 17, 20, 5);

                ctx.fillRect(108, 42, 16, 28);
                ctx.strokeRect(108, 42, 16, 28);
                ctx.fillRect(106, 40, 20, 5);
                ctx.strokeRect(106, 40, 20, 5);

                // Vector Flappy Bird
                var bx = 64;
                var by = 35;
                ctx.fillStyle = "#facc15";
                ctx.strokeStyle = "#ca8a04";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.ellipse(bx, by, 12, 10, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();

                ctx.fillStyle = "#fef08a";
                ctx.beginPath();
                ctx.ellipse(bx - 4, by + 1, 6, 4, -0.3, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();

                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.arc(bx + 4, by - 4, 4, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#0f172a";
                ctx.beginPath();
                ctx.arc(bx + 5.5, by - 4, 1.8, 0, Math.PI * 2);
                ctx.fill();

                ctx.fillStyle = "#f97316";
                ctx.beginPath();
                ctx.moveTo(bx + 9, by - 2);
                ctx.lineTo(bx + 16, by + 1);
                ctx.lineTo(bx + 9, by + 4);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // 11. CyberHop Badge
    Component {
        id: compHop
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#1e3a8a";
                ctx.fillRect(0, 4, width, 28);
                ctx.strokeStyle = "#3b82f6";
                ctx.lineWidth = 1;
                for (var wx = 8; wx < width; wx += 24) {
                    ctx.beginPath();
                    ctx.moveTo(wx, 10); ctx.lineTo(wx + 10, 10);
                    ctx.moveTo(wx + 6, 26); ctx.lineTo(wx + 16, 26);
                    ctx.stroke();
                }

                // Log
                ctx.fillStyle = "#78350f";
                ctx.strokeStyle = "#451a03";
                ctx.lineWidth = 1;
                ctx.fillRect(14, 11, 48, 14);
                ctx.strokeRect(14, 11, 48, 14);

                // Frog
                var fx = 38, fy = 18;
                ctx.fillStyle = "#15803d";
                ctx.beginPath();
                ctx.ellipse(fx - 7, fy + 4, 3, 2, 0, 0, Math.PI * 2);
                ctx.ellipse(fx + 7, fy + 4, 3, 2, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#22c55e";
                ctx.beginPath();
                ctx.ellipse(fx, fy, 7, 6, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.arc(fx - 4, fy - 5, 2.5, 0, Math.PI * 2);
                ctx.arc(fx + 4, fy - 5, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#0f172a";
                ctx.beginPath();
                ctx.arc(fx - 4, fy - 5.5, 1.2, 0, Math.PI * 2);
                ctx.arc(fx + 4, fy - 5.5, 1.2, 0, Math.PI * 2);
                ctx.fill();

                // Road & Car
                ctx.fillStyle = "#1e293b";
                ctx.fillRect(0, 36, width, 28);
                ctx.strokeStyle = "#cbd5e1";
                ctx.lineWidth = 1;
                ctx.setLineDash([6, 6]);
                ctx.beginPath();
                ctx.moveTo(0, 50); ctx.lineTo(width, 50);
                ctx.stroke();
                ctx.setLineDash([]);

                var rx = 86, ry = 42;
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(rx, ry, 34, 14);
                ctx.fillStyle = "#0f172a";
                ctx.fillRect(rx + 8, ry + 2, 12, 10);
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(rx + 2, ry, 3, 14);
                ctx.fillStyle = "#fef08a";
                ctx.fillRect(rx + 33, ry + 1, 2, 3);
                ctx.fillRect(rx + 33, ry + 10, 2, 3);
            }
        }
    }

    // 12. CratePusher Badge
    Component {
        id: compCrate
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = Math.round((width - 4 * 22) / 2);
                var cy = Math.round((height - 2 * 22) / 2);

                function drawFloor(x, y) {
                    ctx.fillStyle = "#1e293b";
                    ctx.fillRect(x, y, 20, 20);
                    ctx.strokeStyle = "#334155";
                    ctx.lineWidth = 1;
                    ctx.strokeRect(x, y, 20, 20);
                }

                function drawCrate(x, y) {
                    ctx.fillStyle = "#d97706";
                    ctx.fillRect(x, y, 20, 20);
                    ctx.strokeStyle = "#78350f";
                    ctx.lineWidth = 1.5;
                    ctx.strokeRect(x, y, 20, 20);
                    ctx.beginPath();
                    ctx.moveTo(x + 2, y + 2); ctx.lineTo(x + 18, y + 18);
                    ctx.moveTo(x + 18, y + 2); ctx.lineTo(x + 2, y + 18);
                    ctx.stroke();
                }

                function drawGoal(x, y) {
                    drawFloor(x, y);
                    ctx.fillStyle = "#10b981";
                    ctx.beginPath();
                    ctx.moveTo(x + 10, y + 3);
                    ctx.lineTo(x + 17, y + 10);
                    ctx.lineTo(x + 10, y + 17);
                    ctx.lineTo(x + 3, y + 10);
                    ctx.closePath();
                    ctx.fill();
                }

                function drawWorker(x, y) {
                    drawFloor(x, y);
                    ctx.fillStyle = "#2563eb";
                    ctx.fillRect(x + 5, y + 10, 10, 8);
                    ctx.fillStyle = "#eab308";
                    ctx.beginPath();
                    ctx.arc(x + 10, y + 7, 5, Math.PI, 0, false);
                    ctx.fill();
                    ctx.fillRect(x + 4, y + 7, 12, 2);
                    ctx.fillStyle = "#fed7aa";
                    ctx.fillRect(x + 6, y + 9, 8, 3);
                }

                drawGoal(cx, cy);
                drawCrate(cx + 22, cy);
                drawFloor(cx + 44, cy);
                drawGoal(cx + 66, cy);

                drawCrate(cx, cy + 22);
                drawWorker(cx + 22, cy + 22);
                drawCrate(cx + 44, cy + 22);
                drawFloor(cx + 66, cy + 22);
            }
        }
    }

    // 13. DinoRunner Badge
    Component {
        id: compDino
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#475569";
                ctx.fillRect(8, 54, width - 16, 2);
                ctx.fillRect(20, 58, 8, 1);
                ctx.fillRect(60, 58, 14, 1);
                ctx.fillRect(100, 58, 6, 1);

                ctx.fillStyle = "#cbd5e1";
                ctx.fillRect(28, 18, 18, 14);
                ctx.clearRect(33, 20, 3, 3);
                ctx.clearRect(40, 26, 6, 3);
                ctx.fillRect(22, 28, 14, 14);
                ctx.fillRect(36, 33, 5, 2);
                ctx.fillRect(39, 35, 2, 3);
                ctx.fillRect(16, 30, 6, 7);
                ctx.fillRect(12, 32, 4, 4);
                ctx.fillRect(24, 42, 3, 10);
                ctx.fillRect(26, 50, 4, 2);
                ctx.fillRect(31, 42, 3, 8);
                ctx.fillRect(33, 48, 4, 2);

                ctx.fillStyle = "#16a34a";
                ctx.fillRect(68, 30, 5, 24);
                ctx.fillRect(62, 36, 7, 3);
                ctx.fillRect(62, 32, 3, 5);
                ctx.fillRect(72, 38, 7, 3);
                ctx.fillRect(76, 34, 3, 5);

                ctx.fillRect(94, 24, 6, 30);
                ctx.fillRect(87, 32, 8, 3);
                ctx.fillRect(87, 27, 3, 6);
                ctx.fillRect(99, 34, 8, 3);
                ctx.fillRect(104, 29, 3, 6);

                ctx.fillStyle = "#94a3b8";
                ctx.fillRect(52, 10, 12, 3);
                ctx.fillRect(55, 7, 6, 3);
                ctx.fillRect(48, 11, 4, 2);
                ctx.fillRect(64, 9, 3, 2);
            }
        }
    }

    // 14. WordGuess Badge
    Component {
        id: compWord
        Grid {
            columns: 5; spacing: 2; anchors.centerIn: parent
            Repeater {
                model: [
                    {t:"P", c:"#22c55e"}, {t:"L", c:"#22c55e"}, {t:"A", c:"#22c55e"}, {t:"N", c:"#eab308"}, {t:"T", c:"#64748b"},
                    {t:"S", c:"#64748b"}, {t:"P", c:"#eab308"}, {t:"A", c:"#22c55e"}, {t:"C", c:"#22c55e"}, {t:"E", c:"#22c55e"}
                ]
                Rectangle {
                    width: 18; height: 18; radius: 2
                    color: modelData.c
                    Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 10; font.bold: true; color: "#FFFFFF" }
                }
            }
        }
    }

    // 15. ByteCity Badge
    Component {
        id: compCity
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#0f172a";
                ctx.fillRect(0, 54, width, 14);

                ctx.fillStyle = "#0284c7";
                ctx.fillRect(16, 20, 26, 34);
                ctx.fillStyle = "#38bdf8";
                ctx.fillRect(14, 18, 30, 2);
                ctx.fillStyle = "#fde047";
                for (var r = 0; r < 5; r++) {
                    ctx.fillRect(20, 24 + r * 6, 4, 3);
                    ctx.fillRect(28, 24 + r * 6, 4, 3);
                    ctx.fillRect(34, 24 + r * 6, 4, 3);
                }

                ctx.fillStyle = "#075985";
                ctx.fillRect(48, 8, 34, 46);
                ctx.fillStyle = "#06b6d4";
                ctx.fillRect(63, 1, 4, 7);
                ctx.fillRect(46, 6, 38, 2);
                ctx.fillStyle = "#fef08a";
                for (var r2 = 0; r2 < 7; r2++) {
                    ctx.fillRect(52, 12 + r2 * 6, 5, 3);
                    ctx.fillRect(62, 12 + r2 * 6, 5, 3);
                    ctx.fillRect(72, 12 + r2 * 6, 5, 3);
                }

                ctx.fillStyle = "#0369a1";
                ctx.fillRect(88, 28, 28, 26);
                ctx.fillStyle = "#38bdf8";
                ctx.fillRect(86, 26, 32, 2);
                ctx.fillStyle = "#fde047";
                for (var r3 = 0; r3 < 4; r3++) {
                    ctx.fillRect(92, 32 + r3 * 5, 6, 3);
                    ctx.fillRect(104, 32 + r3 * 5, 6, 3);
                }

                ctx.strokeStyle = "#f59e0b";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(122, 54); ctx.lineTo(122, 14);
                ctx.moveTo(110, 18); ctx.lineTo(138, 18);
                ctx.moveTo(122, 14); ctx.lineTo(134, 18);
                ctx.stroke();
            }
        }
    }

    // 16. GalacticSwarm Badge
    Component {
        id: compGalaga
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#ffffff";
                ctx.fillRect(16, 12, 1.5, 1.5);
                ctx.fillRect(45, 6, 2, 2);
                ctx.fillRect(88, 10, 1.5, 1.5);
                ctx.fillRect(124, 22, 2, 2);
                ctx.fillRect(28, 44, 1.5, 1.5);
                ctx.fillRect(118, 50, 2, 2);

                // Boss Galaga
                var bx = 68, by = 12;
                ctx.fillStyle = "#22c55e";
                ctx.fillRect(bx - 8, by - 4, 16, 6);
                ctx.fillRect(bx - 5, by - 8, 10, 4);
                ctx.fillStyle = "#0284c7";
                ctx.fillRect(bx - 10, by + 2, 20, 4);
                ctx.fillStyle = "#eab308";
                ctx.fillRect(bx - 7, by - 10, 2, 4);
                ctx.fillRect(bx + 5, by - 10, 2, 4);

                // Red Butterfly
                var ux = 32, uy = 14;
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(ux - 7, uy - 5, 14, 8);
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(ux - 2, uy - 6, 4, 10);
                ctx.fillStyle = "#3b82f6";
                ctx.fillRect(ux - 6, uy, 4, 4);
                ctx.fillRect(ux + 2, uy, 4, 4);

                // Yellow Bee
                var ex = 104, ey = 14;
                ctx.fillStyle = "#eab308";
                ctx.fillRect(ex - 6, ey - 5, 12, 8);
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(ex - 2, ey - 6, 4, 10);
                ctx.fillStyle = "#38bdf8";
                ctx.fillRect(ex - 7, ey - 1, 3, 4);
                ctx.fillRect(ex + 4, ey - 1, 3, 4);

                // Dual Lasers
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(63, 28, 2, 8);
                ctx.fillRect(71, 28, 2, 8);

                // Galaga Fighter
                var fx = 68, fy = 48;
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.moveTo(fx, fy - 8); ctx.lineTo(fx - 4, fy + 8); ctx.lineTo(fx + 4, fy + 8);
                ctx.closePath(); ctx.fill();
                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.moveTo(fx - 4, fy); ctx.lineTo(fx - 12, fy + 8); ctx.lineTo(fx - 4, fy + 8);
                ctx.closePath(); ctx.fill();
                ctx.beginPath();
                ctx.moveTo(fx + 4, fy); ctx.lineTo(fx + 12, fy + 8); ctx.lineTo(fx + 4, fy + 8);
                ctx.closePath(); ctx.fill();
                ctx.fillStyle = "#2563eb";
                ctx.fillRect(fx - 2, fy + 6, 4, 4);
            }
        }
    }

    // 17. ByteMan Badge
    Component {
        id: compPacman
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Pac-Man
                var px = 26, py = 34, pr = 15;
                ctx.fillStyle = "#ffd700";
                ctx.beginPath();
                ctx.arc(px, py, pr, 0.25 * Math.PI, 1.75 * Math.PI, false);
                ctx.lineTo(px, py);
                ctx.closePath();
                ctx.fill();

                // Dots & Energizer
                ctx.fillStyle = "#fef08a";
                ctx.beginPath();
                ctx.arc(48, py, 2.5, 0, Math.PI * 2);
                ctx.arc(58, py, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(70, py, 5, 0, Math.PI * 2);
                ctx.fill();

                function drawGhost(gx, gy, gr, col) {
                    ctx.fillStyle = col;
                    ctx.beginPath();
                    ctx.arc(gx, gy - gr * 0.2, gr, Math.PI, 0, false);
                    ctx.lineTo(gx + gr, gy + gr * 0.85);
                    var step = (gr * 2) / 3;
                    ctx.lineTo(gx + gr - step * 0.5, gy + gr * 0.55);
                    ctx.lineTo(gx + gr - step, gy + gr * 0.85);
                    ctx.lineTo(gx + gr - step * 1.5, gy + gr * 0.55);
                    ctx.lineTo(gx - gr, gy + gr * 0.85);
                    ctx.closePath();
                    ctx.fill();

                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.arc(gx - gr * 0.35 - 2, gy - gr * 0.2, gr * 0.32, 0, Math.PI * 2);
                    ctx.arc(gx + gr * 0.35 - 2, gy - gr * 0.2, gr * 0.32, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillStyle = "#1d4ed8";
                    ctx.beginPath();
                    ctx.arc(gx - gr * 0.35 - 3.5, gy - gr * 0.2, gr * 0.16, 0, Math.PI * 2);
                    ctx.arc(gx + gr * 0.35 - 3.5, gy - gr * 0.2, gr * 0.16, 0, Math.PI * 2);
                    ctx.fill();
                }

                drawGhost(92, 34, 12, "#ef4444");
                drawGhost(118, 34, 12, "#06b6d4");
            }
        }
    }

    // 18. GemSwap Badge
    Component {
        id: compGems
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                function drawFacetedGem(gx, gy, gr, shape, cBase, cLight, cDark) {
                    ctx.save();
                    ctx.translate(gx, gy);

                    if (shape === "square") {
                        ctx.fillStyle = cBase;
                        ctx.fillRect(-gr, -gr, gr * 2, gr * 2);
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.moveTo(-gr, -gr); ctx.lineTo(gr, -gr); ctx.lineTo(gr * 0.6, -gr * 0.6); ctx.lineTo(-gr * 0.6, -gr * 0.6);
                        ctx.fill();
                        ctx.fillStyle = cDark;
                        ctx.beginPath();
                        ctx.moveTo(-gr, gr); ctx.lineTo(gr, gr); ctx.lineTo(gr * 0.6, gr * 0.6); ctx.lineTo(-gr * 0.6, gr * 0.6);
                        ctx.fill();
                    } else if (shape === "rhombus") {
                        ctx.fillStyle = cBase;
                        ctx.beginPath();
                        ctx.moveTo(0, -gr * 1.3); ctx.lineTo(gr * 0.9, 0); ctx.lineTo(0, gr * 1.3); ctx.lineTo(-gr * 0.9, 0);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.moveTo(0, -gr * 1.3); ctx.lineTo(0, gr * 1.3); ctx.lineTo(-gr * 0.9, 0);
                        ctx.closePath(); ctx.fill();
                    } else if (shape === "triDown") {
                        ctx.fillStyle = cBase;
                        ctx.beginPath();
                        ctx.moveTo(-gr, -gr * 0.9); ctx.lineTo(gr, -gr * 0.9); ctx.lineTo(0, gr * 1.2);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.moveTo(-gr, -gr * 0.9); ctx.lineTo(0, -gr * 0.9); ctx.lineTo(0, gr * 1.2);
                        ctx.closePath(); ctx.fill();
                    } else if (shape === "triUp") {
                        ctx.fillStyle = cBase;
                        ctx.beginPath();
                        ctx.moveTo(0, -gr * 1.2); ctx.lineTo(gr, gr * 0.9); ctx.lineTo(-gr, gr * 0.9);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.moveTo(0, -gr * 1.2); ctx.lineTo(-gr, gr * 0.9); ctx.lineTo(0, gr * 0.9);
                        ctx.closePath(); ctx.fill();
                    } else if (shape === "circle") {
                        ctx.fillStyle = cBase;
                        ctx.beginPath();
                        ctx.arc(0, 0, gr, 0, Math.PI * 2); ctx.fill();
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.arc(-gr * 0.3, -gr * 0.3, gr * 0.45, 0, Math.PI * 2); ctx.fill();
                    } else if (shape === "diamond") {
                        ctx.fillStyle = cBase;
                        ctx.beginPath();
                        for (var i = 0; i < 8; i++) {
                            var ang = i * Math.PI / 4;
                            var px = Math.cos(ang) * gr;
                            var py = Math.sin(ang) * gr;
                            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = cLight;
                        ctx.beginPath();
                        ctx.arc(-gr * 0.25, -gr * 0.25, gr * 0.4, 0, Math.PI * 2); ctx.fill();
                    }
                    ctx.restore();
                }

                drawFacetedGem(28, 20, 11, "square", "#e11d48", "#fda4af", "#9f1239");
                drawFacetedGem(68, 20, 11, "circle", "#16a34a", "#86efac", "#14532d");
                drawFacetedGem(108, 20, 11, "rhombus", "#2563eb", "#93c5fd", "#1e3a8a");

                drawFacetedGem(28, 46, 11, "triDown", "#f59e0b", "#fde68a", "#b45309");
                drawFacetedGem(68, 46, 11, "triUp", "#9333ea", "#d8b4fe", "#581c87");
                drawFacetedGem(108, 46, 11, "diamond", "#06b6d4", "#cffafe", "#0e7490");
            }
        }
    }

    // 19. OrbPop Badge
    Component {
        id: compOrbPop
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                function drawBubble(bx, by, rad, cBase, cLight) {
                    ctx.fillStyle = cBase;
                    ctx.beginPath();
                    ctx.arc(bx, by, rad, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillStyle = cLight;
                    ctx.beginPath();
                    ctx.arc(bx - rad * 0.35, by - rad * 0.35, rad * 0.35, 0, Math.PI * 2);
                    ctx.fill();
                }

                var r1 = [
                    {b:"#ef4444", l:"#fca5a5"},
                    {b:"#38bdf8", l:"#bae6fd"},
                    {b:"#eab308", l:"#fef08a"},
                    {b:"#a855f7", l:"#e9d5ff"},
                    {b:"#22c55e", l:"#bbf7d0"}
                ];
                for (var i = 0; i < 5; i++) {
                    drawBubble(28 + i * 20, 14, 8, r1[i].b, r1[i].l);
                }

                var r2 = [
                    {b:"#38bdf8", l:"#bae6fd"},
                    {b:"#ef4444", l:"#fca5a5"},
                    {b:"#22c55e", l:"#bbf7d0"},
                    {b:"#eab308", l:"#fef08a"}
                ];
                for (var j = 0; j < 4; j++) {
                    drawBubble(38 + j * 20, 29, 8, r2[j].b, r2[j].l);
                }

                var cx = 68, cy = 56;
                ctx.fillStyle = "#475569";
                ctx.beginPath();
                ctx.arc(cx, cy, 10, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = "#94a3b8";
                ctx.lineWidth = 1.5;
                ctx.stroke();

                ctx.strokeStyle = "#f59e0b";
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.moveTo(cx, cy); ctx.lineTo(cx + 6, cy - 14);
                ctx.stroke();

                drawBubble(cx, cy, 6, "#ef4444", "#fca5a5");
            }
        }
    }

    // 20. KeiRacer Badge
    Component {
        id: compKeiRacer
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Synthwave Sky & Sun
                var skyGrad = ctx.createLinearGradient(0, 0, 0, 42);
                skyGrad.addColorStop(0, "#090d16");
                skyGrad.addColorStop(1, "#2e1065");
                ctx.fillStyle = skyGrad;
                ctx.fillRect(0, 0, width, 42);

                // Neon Sun
                ctx.fillStyle = "#f59e0b";
                ctx.beginPath();
                ctx.arc(width / 2, 38, 22, Math.PI, 0, false);
                ctx.fill();

                // Road
                ctx.fillStyle = "#0f172a";
                ctx.beginPath();
                ctx.moveTo(width * 0.40, 42);
                ctx.lineTo(width * 0.60, 42);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();
                ctx.fill();

                // Road Center Lines
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(width / 2, 42);
                ctx.lineTo(width / 2, height);
                ctx.stroke();

                // Mini Kei Truck
                var cx = width / 2;
                var cy = height - 12;
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(cx - 14, cy - 18, 28, 18);
                // Cab window
                ctx.fillStyle = "#1e293b";
                ctx.fillRect(cx - 10, cy - 16, 20, 8);
                // Wheels
                ctx.fillStyle = "#020617";
                ctx.fillRect(cx - 15, cy - 2, 6, 6);
                ctx.fillRect(cx + 9, cy - 2, 6, 6);
                // Taillights
                ctx.fillStyle = "#ef4444";
                ctx.fillRect(cx - 12, cy - 6, 4, 3);
                ctx.fillRect(cx + 8, cy - 6, 4, 3);
            }
        }
    }

    // Default Fallback
    Component {
        id: compDefault
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.fillStyle = "#1e293b";
                ctx.strokeStyle = "#475569";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(46, 36, 18, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();

                ctx.strokeStyle = "#cbd5e1";
                ctx.lineWidth = 4;
                ctx.beginPath();
                ctx.moveTo(46, 36); ctx.lineTo(40, 20);
                ctx.stroke();

                ctx.fillStyle = "#ef4444";
                ctx.beginPath();
                ctx.arc(38, 16, 8, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = "#fca5a5";
                ctx.beginPath();
                ctx.arc(36, 14, 2.5, 0, Math.PI * 2);
                ctx.fill();

                ctx.fillStyle = "#3b82f6";
                ctx.beginPath();
                ctx.arc(88, 38, 8, 0, Math.PI * 2); ctx.fill();
                ctx.fillStyle = "#eab308";
                ctx.beginPath();
                ctx.arc(106, 28, 8, 0, Math.PI * 2); ctx.fill();
            }
        }
    }
}
