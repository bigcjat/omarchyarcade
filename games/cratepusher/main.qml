import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 680
    height: 740
    minimumWidth: 340
    minimumHeight: 460
    title: "CratePusher"

    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCellGrid: "#1e1e2e"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBorder: "#45475a"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool showLevelSelect: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property string helpText: "• Move & Push: Arrows, WASD, or Vim H / J / K / L\n• Undo Step: U or Ctrl+Z\n• Restart Stage: R\n• Stage Select: L\n• Prev / Next Stage: P / N\n• Mute: M | Help: ?\n\nPush all wooden crates onto the glowing docking targets in the fewest moves possible!"

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    color: themeBg

    property string gameState: "playing"
    property int currentLevel: 1
    property int totalLevels: 50
    property string levelName: ""
    property int moves: 0
    property int pushes: 0
    property int parMoves: 30
    property int bestMoves: 0
    property int unlockedLevel: 0

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) themeBg = data.bg;
        if (data.fg) themeFg = data.fg;
        if (data.accent) {
            themeAccent = data.accent;
            themeBtnBg = data.accent;
            themeBtnFg = colorLuminance(data.accent) > 0.5 ? "#11111b" : "#ffffff";
        }
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
        gameCanvas.requestPaint();
    }

    function captureScreenshot(filePath) {
        mainContainer.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
        });
    }

    function playSound(name) {
        if (!isMuted) {
            if (typeof soundManager !== "undefined" && soundManager) {
                soundManager.playSound(name);
            }
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted) {
            playSound("select");
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    Component.onCompleted: {
        Engine.setSoundCallback(function(name) {
            root.playSound(name);
        });

        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.unlockedLevel = settingsManager.getUnlockedLevel();
        }

        root.totalLevels = Engine.LEVELS.length;
        loadStage(0);
    }

    function loadStage(idx) {
        Engine.loadLevel(idx);
        syncState();
        gameCanvas.requestPaint();
        soundToast.show("Stage " + (idx + 1) + ": " + root.levelName);
    }

    function syncState() {
        root.gameState = Engine.gameState;
        root.currentLevel = Engine.currentLevelIndex + 1;
        root.levelName = Engine.LEVELS[Engine.currentLevelIndex].name || ("Stage " + root.currentLevel);
        root.moves = Engine.moves;
        root.pushes = Engine.pushes;
        root.parMoves = Engine.getParMoves();

        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestMoves = settingsManager.getBestMoves(Engine.currentLevelIndex);
            root.unlockedLevel = Math.max(root.unlockedLevel, settingsManager.getUnlockedLevel());
        }

        if (root.gameState === "won") {
            var stars = Engine.getStarRating(root.moves);
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestMoves(Engine.currentLevelIndex, root.moves);
                settingsManager.setStars(Engine.currentLevelIndex, stars);
                settingsManager.setUnlockedLevel(Engine.currentLevelIndex + 1);
                root.unlockedLevel = Math.max(root.unlockedLevel, Engine.currentLevelIndex + 1);
                root.bestMoves = settingsManager.getBestMoves(Engine.currentLevelIndex);
            }
        }
    }

    function restartStage() {
        loadStage(Engine.currentLevelIndex);
    }

    function stepUndo() {
        if (Engine.undo()) {
            syncState();
            gameCanvas.requestPaint();
            soundToast.show("Step Undone");
        }
    }

    function nextStage() {
        if (Engine.currentLevelIndex < root.totalLevels - 1) {
            loadStage(Engine.currentLevelIndex + 1);
        }
    }

    function prevStage() {
        if (Engine.currentLevelIndex > 0) {
            loadStage(Engine.currentLevelIndex - 1);
        }
    }

    // MAIN CONTAINER
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.showLevelSelect) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_L) {
                    root.showLevelSelect = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.gameState === "won") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_A) {
                    nextStage();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                restartStage();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U || (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))) {
                stepUndo();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_L) {
                root.showLevelSelect = !root.showLevelSelect;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_N) {
                nextStage();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P) {
                prevStage();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }

            if (root.gameState === "playing") {
                var moved = false;
                if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                    moved = Engine.move(0, -1);
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                    moved = Engine.move(0, 1);
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    moved = Engine.move(-1, 0);
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    moved = Engine.move(1, 0);
                }

                if (moved) {
                    syncState();
                    gameCanvas.requestPaint();
                    event.accepted = true;
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: Math.max(titleCol.height, scoreRow.height)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "CratePusher"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    text: "Stage " + root.currentLevel + ": " + root.levelName + " • Par: " + root.parMoves
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards on Right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // MOVES Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MOVES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            id: movesVal
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.moves.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // BEST Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BEST"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            id: bestVal
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bestMoves > 0 ? root.bestMoves.toString() : "--"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.bestMoves > 0 ? root.themeAccent : root.themeSubtext
                        }
                    }
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 34

            readonly property bool isCrowded: subheaderItem.width < 450

            // Help button
            Rectangle {
                id: helpBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                radius: 8
                color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: helpRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "?"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeAccent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "How to Play"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !subheaderItem.isCrowded
                    }
                }

                MouseArea {
                    id: helpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showHelp = !root.showHelp
                }
            }

            // Mute button
            Rectangle {
                id: muteBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                radius: 8
                color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: root.isMuted ? root.themeBorder : root.themeAccent
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: muteRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.isMuted ? "Muted" : "Sound"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.isMuted ? root.themeSubtext : root.themeFg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !subheaderItem.isCrowded
                    }
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }
            }

            // Restart button
            Rectangle {
                id: restartBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                radius: 8
                color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: restartRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "🔄"
                        font.pixelSize: 13
                        visible: subheaderItem.isCrowded
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Restart (R)"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeBtnFg
                        visible: !subheaderItem.isCrowded
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: restartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restartStage()
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 2
                radius: 12
                clip: true

                Canvas {
                    id: gameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.fillStyle = root.themeBoardBg;
                        ctx.fillRect(0, 0, width, height);

                        if (Engine.rows === 0 || Engine.cols === 0) return;

                        // Calculate adaptive grid sizing
                        var padding = 20;
                        var availW = width - padding * 2;
                        var availH = height - padding * 2;
                        var cellSize = Math.min(availW / Engine.cols, availH / Engine.rows, 54);
                        var startX = (width - cellSize * Engine.cols) / 2;
                        var startY = (height - cellSize * Engine.rows) / 2;

                        // 1. Draw Floor Tiles
                        for (var y = 0; y < Engine.rows; y++) {
                            for (var x = 0; x < Engine.cols; x++) {
                                var isWall = Engine.walls[y] && Engine.walls[y][x];
                                if (!isWall) {
                                    var tileX = startX + x * cellSize;
                                    var tileY = startY + y * cellSize;

                                    ctx.fillStyle = ((x + y) % 2 === 0) ? "#181825" : "#1e1e2e";
                                    ctx.fillRect(tileX + 0.5, tileY + 0.5, cellSize - 1, cellSize - 1);

                                    // Subtle inner grid marker
                                    ctx.strokeStyle = "#252538";
                                    ctx.lineWidth = 1;
                                    ctx.strokeRect(tileX + 0.5, tileY + 0.5, cellSize - 1, cellSize - 1);
                                }
                            }
                        }

                        // 2. Draw Goal Target Bays
                        for (var g = 0; g < Engine.goals.length; g++) {
                            var goal = Engine.goals[g];
                            var gx = startX + (goal.x + 0.5) * cellSize;
                            var gy = startY + (goal.y + 0.5) * cellSize;
                            var gRadius = cellSize * 0.28;

                            ctx.beginPath();
                            ctx.arc(gx, gy, gRadius + 4, 0, Math.PI * 2);
                            ctx.fillStyle = "#1e2030";
                            ctx.fill();

                            ctx.beginPath();
                            ctx.arc(gx, gy, gRadius, 0, Math.PI * 2);
                            ctx.lineWidth = 2.5;
                            ctx.strokeStyle = root.themeAccent;
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.arc(gx, gy, cellSize * 0.12, 0, Math.PI * 2);
                            ctx.fillStyle = root.themeAccent;
                            ctx.fill();
                        }

                        // 3. Draw 3D Beveled Industrial Wall Blocks
                        for (var wy = 0; wy < Engine.rows; wy++) {
                            for (var wx = 0; wx < Engine.cols; wx++) {
                                if (Engine.walls[wy] && Engine.walls[wy][wx]) {
                                    var wallX = startX + wx * cellSize;
                                    var wallY = startY + wy * cellSize;
                                    drawWallBlock(ctx, wallX, wallY, cellSize);
                                }
                            }
                        }

                        // 4. Draw Floor Dust Particles
                        for (var p = 0; p < Engine.particles.length; p++) {
                            var pt = Engine.particles[p];
                            var px = startX + pt.x * cellSize;
                            var py = startY + pt.y * cellSize;
                            var alpha = pt.life / pt.maxLife;

                            ctx.globalAlpha = alpha * 0.7;
                            ctx.fillStyle = pt.color;
                            ctx.beginPath();
                            ctx.arc(px, py, pt.size, 0, Math.PI * 2);
                            ctx.fill();
                        }
                        ctx.globalAlpha = 1.0;

                        // 5. Draw Wooden Crates with Subpixel Easing
                        for (var c = 0; c < Engine.crates.length; c++) {
                            var cr = Engine.crates[c];
                            var cx = startX + cr.drawX * cellSize;
                            var cy = startY + cr.drawY * cellSize;
                            drawCrate(ctx, cx, cy, cellSize, cr.onGoal);
                        }

                        // 6. Draw Directional Warehouse Worker Character
                        var pw = Engine.player;
                        var pxPos = startX + pw.drawX * cellSize;
                        var pyPos = startY + pw.drawY * cellSize;
                        drawWorker(ctx, pxPos, pyPos, cellSize, pw.facing, pw.isPushing, pw.walkCycle);
                    }

                    function drawWallBlock(ctx, x, y, size) {
                        // Base wall shadow
                        ctx.fillStyle = "#313244";
                        ctx.fillRect(x + 1, y + 1, size - 2, size - 2);

                        // Top bevel highlight
                        ctx.fillStyle = "#45475a";
                        ctx.beginPath();
                        ctx.moveTo(x + 1, y + 1);
                        ctx.lineTo(x + size - 1, y + 1);
                        ctx.lineTo(x + size - 5, y + 5);
                        ctx.lineTo(x + 5, y + 5);
                        ctx.closePath();
                        ctx.fill();

                        // Right bevel shadow
                        ctx.fillStyle = "#1e1e2e";
                        ctx.beginPath();
                        ctx.moveTo(x + size - 1, y + 1);
                        ctx.lineTo(x + size - 1, y + size - 1);
                        ctx.lineTo(x + size - 5, y + size - 5);
                        ctx.lineTo(x + size - 5, y + 5);
                        ctx.closePath();
                        ctx.fill();

                        // Central brick face
                        ctx.fillStyle = "#363a4f";
                        ctx.fillRect(x + 5, y + 5, size - 10, size - 10);

                        // Mortar lines
                        ctx.strokeStyle = "#24273a";
                        ctx.lineWidth = 1;
                        ctx.strokeRect(x + 5, y + 5, size - 10, size - 10);
                        ctx.beginPath();
                        ctx.moveTo(x + 5, y + size / 2);
                        ctx.lineTo(x + size - 5, y + size / 2);
                        ctx.stroke();
                    }

                    function drawCrate(ctx, x, y, size, onGoal) {
                        var pad = size * 0.08;
                        var crateW = size - pad * 2;
                        var cx = x + pad;
                        var cy = y + pad;

                        // Crate drop shadow
                        ctx.fillStyle = "#00000044";
                        ctx.fillRect(cx + 3, cy + 4, crateW, crateW);

                        // Crate body (warm cedar/wood vs glowing docked wood)
                        ctx.fillStyle = onGoal ? "#a6e3a1" : "#fab387";
                        ctx.fillRect(cx, cy, crateW, crateW);

                        // Inner wood recessed face
                        ctx.fillStyle = onGoal ? "#40a02b" : "#e08d49";
                        ctx.fillRect(cx + 4, cy + 4, crateW - 8, crateW - 8);

                        // Diagonal wood bracing slats (X cross)
                        ctx.strokeStyle = onGoal ? "#a6e3a1" : "#fab387";
                        ctx.lineWidth = 3;
                        ctx.beginPath();
                        ctx.moveTo(cx + 6, cy + 6);
                        ctx.lineTo(cx + crateW - 6, cy + crateW - 6);
                        ctx.moveTo(cx + crateW - 6, cy + 6);
                        ctx.lineTo(cx + 6, cy + crateW - 6);
                        ctx.stroke();

                        // Metal corner brackets
                        ctx.fillStyle = onGoal ? "#cdd6f4" : "#45475a";
                        var bSize = 6;
                        // Top-left
                        ctx.fillRect(cx, cy, bSize, 3);
                        ctx.fillRect(cx, cy, 3, bSize);
                        // Top-right
                        ctx.fillRect(cx + crateW - bSize, cy, bSize, 3);
                        ctx.fillRect(cx + crateW - 3, cy, 3, bSize);
                        // Bottom-left
                        ctx.fillRect(cx, cy + crateW - 3, bSize, 3);
                        ctx.fillRect(cx, cy + crateW - bSize, 3, bSize);
                        // Bottom-right
                        ctx.fillRect(cx + crateW - bSize, cy + crateW - 3, bSize, 3);
                        ctx.fillRect(cx + crateW - 3, cy + crateW - bSize, 3, bSize);

                        // Active central lock rune
                        if (onGoal) {
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(cx + crateW / 2, cy + crateW / 2, 4, 0, Math.PI * 2);
                            ctx.fill();
                        }
                    }

                    function drawWorker(ctx, x, y, size, facing, isPushing, walkCycle) {
                        var cx = x + size / 2;
                        var cy = y + size / 2;
                        var bob = Math.sin(walkCycle) * 2;

                        // Character shadow
                        ctx.fillStyle = "#00000055";
                        ctx.beginPath();
                        ctx.ellipse(cx, cy + size * 0.32, size * 0.28, size * 0.12, 0, 0, Math.PI * 2);
                        ctx.fill();

                        // Body (Industrial yellow/orange jumpsuit)
                        ctx.fillStyle = "#f9e2af";
                        ctx.beginPath();
                        ctx.arc(cx, cy + size * 0.05 + bob, size * 0.22, 0, Math.PI * 2);
                        ctx.fill();

                        // Head / Safety Cap
                        ctx.fillStyle = "#89b4fa"; // Hardhat
                        ctx.beginPath();
                        ctx.arc(cx, cy - size * 0.15 + bob, size * 0.16, 0, Math.PI * 2);
                        ctx.fill();

                        // Cap visor based on facing direction
                        ctx.fillStyle = "#74c7ec";
                        if (facing === "down") {
                            ctx.fillRect(cx - size * 0.12, cy - size * 0.14 + bob, size * 0.24, 4);
                            // Eyes
                            ctx.fillStyle = "#11111b";
                            ctx.fillRect(cx - 5, cy - size * 0.08 + bob, 3, 3);
                            ctx.fillRect(cx + 2, cy - size * 0.08 + bob, 3, 3);
                        } else if (facing === "up") {
                            ctx.fillRect(cx - size * 0.12, cy - size * 0.22 + bob, size * 0.24, 4);
                        } else if (facing === "left") {
                            ctx.fillRect(cx - size * 0.20, cy - size * 0.14 + bob, size * 0.12, 4);
                            // Eye
                            ctx.fillStyle = "#11111b";
                            ctx.fillRect(cx - 7, cy - size * 0.08 + bob, 3, 3);
                        } else if (facing === "right") {
                            ctx.fillRect(cx + size * 0.08, cy - size * 0.14 + bob, size * 0.12, 4);
                            // Eye
                            ctx.fillStyle = "#11111b";
                            ctx.fillRect(cx + 4, cy - size * 0.08 + bob, 3, 3);
                        }

                        // Hands / Arms
                        ctx.fillStyle = "#fab387";
                        var pushExt = isPushing ? 6 : 0;
                        if (facing === "right") {
                            ctx.fillRect(cx + size * 0.14 + pushExt, cy + size * 0.02 + bob, 5, 5);
                        } else if (facing === "left") {
                            ctx.fillRect(cx - size * 0.20 - pushExt, cy + size * 0.02 + bob, 5, 5);
                        } else if (facing === "down") {
                            ctx.fillRect(cx - size * 0.20, cy + size * 0.12 + pushExt + bob, 5, 5);
                            ctx.fillRect(cx + size * 0.12, cy + size * 0.12 + pushExt + bob, 5, 5);
                        } else if (facing === "up") {
                            ctx.fillRect(cx - size * 0.20, cy - size * 0.10 - pushExt + bob, 5, 5);
                            ctx.fillRect(cx + size * 0.12, cy - size * 0.10 - pushExt + bob, 5, 5);
                        }
                    }
                }
            }
        }

        // BOTTOM ACTION BAR (Responsive Stage & Undo Navigation)
        Rectangle {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            height: 36
            width: Math.min(parent.width - 32, 420)
            radius: 8
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                // Undo
                Rectangle {
                    height: parent.height
                    width: (parent.width - parent.spacing * 3) * 0.28
                    radius: 6
                    color: undoBtnArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : (undoBtnArea.containsMouse ? Qt.lighter(root.themeCardBg, 1.15) : "transparent")
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "↶"; font.pixelSize: 12; color: root.themeAccent }
                        Text {
                            text: bottomBar.width < 340 ? "Undo" : "Undo (U)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                    MouseArea {
                        id: undoBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepUndo()
                    }
                }

                // Stages
                Rectangle {
                    height: parent.height
                    width: (parent.width - parent.spacing * 3) * 0.32
                    radius: 6
                    color: stagesBtnArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : (stagesBtnArea.containsMouse ? Qt.lighter(root.themeCardBg, 1.15) : "transparent")
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "☰"; font.pixelSize: 11; color: root.themeAccent }
                        Text {
                            text: bottomBar.width < 340 ? "Stages" : "Stages (L)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                    MouseArea {
                        id: stagesBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showLevelSelect = true
                    }
                }

                // Prev Stage
                Rectangle {
                    height: parent.height
                    width: (parent.width - parent.spacing * 3) * 0.20
                    radius: 6
                    color: prevBtnArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : (prevBtnArea.containsMouse ? Qt.lighter(root.themeCardBg, 1.15) : "transparent")
                    opacity: root.currentLevel > 1 ? 1.0 : 0.4
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "◀"; font.pixelSize: 8; color: root.themeFg }
                        Text {
                            text: bottomBar.width < 310 ? "" : "Prev"
                            visible: text !== ""
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                    MouseArea {
                        id: prevBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevStage()
                    }
                }

                // Next Stage
                Rectangle {
                    height: parent.height
                    width: (parent.width - parent.spacing * 3) * 0.20
                    radius: 6
                    color: nextBtnArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : (nextBtnArea.containsMouse ? Qt.lighter(root.themeCardBg, 1.15) : "transparent")
                    opacity: root.currentLevel < root.totalLevels ? 1.0 : 0.4
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: bottomBar.width < 310 ? "" : "Next"
                            visible: text !== ""
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                        }
                        Text { text: "▶"; font.pixelSize: 8; color: root.themeFg }
                    }
                    MouseArea {
                        id: nextBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextStage()
                    }
                }
            }
        }

        // 60 FPS Game Loop
        Timer {
            interval: 16
            running: true
            repeat: true
            onTriggered: {
                Engine.update(0.016);
                gameCanvas.requestPaint();
            }
        }

        // STAGE CLEAR VICTORY MODAL
        Rectangle {
            id: victoryModal
            anchors.fill: parent
            color: "#b30c0c14"
            visible: root.gameState === "won"
            z: 900

            Rectangle {
                width: Math.min(parent.width * 0.88, 380)
                height: 290
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: "#a6e3a1"
                border.width: 2
                radius: 12

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "★ STAGE CLEARED! ★"
                        font.family: root.monoFontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: "#a6e3a1"
                    }

                    // Star Rating
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        property int stars: Engine.getStarRating(root.moves)

                        Text { text: "★"; font.pixelSize: 28; color: parent.stars >= 1 ? "#f9e2af" : "#45475a" }
                        Text { text: "★"; font.pixelSize: 28; color: parent.stars >= 2 ? "#f9e2af" : "#45475a" }
                        Text { text: "★"; font.pixelSize: 28; color: parent.stars >= 3 ? "#f9e2af" : "#45475a" }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // Moves & Par
                    Row {
                        width: parent.width
                        Text { text: "MOVES TAKEN:"; font.family: root.monoFontFamily; font.pixelSize: 12; color: root.themeSubtext }
                        Item { width: parent.width - 180; height: 1 }
                        Text { text: root.moves + " (Par: " + root.parMoves + ")"; font.family: root.monoFontFamily; font.pixelSize: 12; font.bold: true; color: root.moves <= root.parMoves ? "#a6e3a1" : root.themeFg }
                    }

                    // Pushes
                    Row {
                        width: parent.width
                        Text { text: "BOX PUSHES:"; font.family: root.monoFontFamily; font.pixelSize: 12; color: root.themeSubtext }
                        Item { width: parent.width - 180; height: 1 }
                        Text { text: root.pushes.toString(); font.family: root.monoFontFamily; font.pixelSize: 12; font.bold: true; color: root.themeFg }
                    }

                    // Next Stage Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200
                        height: 38
                        radius: 8
                        color: root.themeAccent
                        Text {
                            anchors.centerIn: parent
                            text: "NEXT STAGE (SPACE)"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: "#11111b"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextStage()
                        }
                    }
                }
            }
        }

        // LEVEL SELECTOR MODAL
        Rectangle {
            id: levelModal
            anchors.fill: parent
            color: "#cc0c0c14"
            visible: root.showLevelSelect
            z: 950

            MouseArea {
                anchors.fill: parent
                onClicked: root.showLevelSelect = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.94, 520)
                height: Math.min(parent.height * 0.88, 540)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Row {
                        width: parent.width
                        Text {
                            text: "Select Warehouse Stage"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                        }
                        Item { width: parent.width - 240; height: 1 }
                        Text {
                            text: "✕ Close"; font.family: root.monoFontFamily; font.pixelSize: 11; color: root.themeSubtext
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showLevelSelect = false }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // 50-Level Scrollable Grid
                    Flickable {
                        id: stageFlickable
                        width: parent.width
                        height: parent.height - 60
                        contentWidth: width
                        contentHeight: stageGrid.height + 10
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Grid {
                            id: stageGrid
                            columns: 5
                            spacing: 8
                            width: parent.width

                            Repeater {
                                model: root.totalLevels
                                delegate: Rectangle {
                                    width: (parent.width - 32) / 5
                                    height: 48
                                    radius: 6
                                    property bool isUnlocked: index <= root.unlockedLevel
                                    property bool isCurrent: index === Engine.currentLevelIndex
                                    property int stageStars: (typeof settingsManager !== "undefined" && settingsManager) ? settingsManager.getStars(index) : 0

                                    color: isCurrent ? Qt.darker(root.themeAccent, 1.8) : (isUnlocked ? root.themeBoardBg : "#11111b")
                                    border.color: isCurrent ? root.themeAccent : (isUnlocked ? root.themeBorder : "#252538")
                                    border.width: isCurrent ? 2 : 1
                                    opacity: isUnlocked ? 1.0 : 0.45

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: (index + 1).toString()
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: isCurrent ? root.themeAccent : root.themeFg
                                        }
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 1
                                            visible: stageStars > 0
                                            Text { text: "★"; font.pixelSize: 8; color: stageStars >= 1 ? "#f9e2af" : "#45475a" }
                                            Text { text: "★"; font.pixelSize: 8; color: stageStars >= 2 ? "#f9e2af" : "#45475a" }
                                            Text { text: "★"; font.pixelSize: 8; color: stageStars >= 3 ? "#f9e2af" : "#45475a" }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: stageStars === 0 && !isUnlocked
                                            text: "🔒"; font.pixelSize: 9
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: isUnlocked ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (isUnlocked) {
                                                root.loadStage(index);
                                                root.showLevelSelect = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // HELP MODAL
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#80000000"
            visible: root.showHelp
            z: 900

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.88, 380)
                height: helpCol.implicitHeight + 36
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 10

                Column {
                    id: helpCol
                    anchors.centerIn: parent
                    width: parent.width - 36
                    spacing: 12

                    Row {
                        width: parent.width
                        Text {
                            text: "CratePusher Manual"
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeAccent
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.helpText
                        font.family: root.monoFontFamily
                        font.pixelSize: 11
                        color: root.themeFg
                        lineHeight: 1.3
                    }

                    Text {
                        text: "Created by Chris Thompson (@bigcjat) with Gemini"
                        font.family: root.monoFontFamily
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.75
                    }
                }
            }
        }

        // Sound Toast Notification
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 10
            width: toastText.implicitWidth + 24
            height: 28
            radius: 14
            color: "#e6181825"
            border.color: root.themeBorder
            border.width: 1
            opacity: 0
            z: 800

            property alias text: toastText.text

            Text {
                id: toastText
                anchors.centerIn: parent
                font.family: root.monoFontFamily
                font.pixelSize: 10
                font.bold: true
                color: root.themeFg
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; to: 1.0; duration: 150 }
                PauseAnimation { duration: 1200 }
                NumberAnimation { target: soundToast; property: "opacity"; to: 0.0; duration: 250 }
            }

            function show(msg) {
                text = msg;
                toastAnim.restart();
            }
        }

        // Canonical Omarchy Arcade Splash Screen
        SplashScreen {
            id: splashScreen
            focusTarget: mainContainer
        }
    }
}
