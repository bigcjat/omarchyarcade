import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "Themes.js" as OmarchyThemes
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 480
    height: 580
    minimumWidth: 360
    minimumHeight: 440
    title: "CyberSweeper"

    // Dynamic Theme Properties
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: "Catppuccin"

    property color themeBg: "#181825"
    property color themeFg: "#cdd6f4"
    property color themeAccent: "#89b4fa"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#313244"
    property color themeCardBg: "#1e1e2e"
    property color themeSubtext: "#a6adc8"
    property color themeBorder: "#45475a"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property color themeModalBg: "#1e1e2e"

    // Game state
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int elapsedSeconds: 0
    property string smileyState: "normal" // "normal", "scared", "won", "dead"
    property int bestTime: 999

    color: themeBg

    Component.onCompleted: {
        updateBestTime();
        Engine.init("beginner");
    }

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        themePalette = data;
        isCustomTheme = true;
        currentThemeName = name || "";

        var bg = data.background || themeBg;
        themeBg = bg;
        themeFg = data.foreground || themeFg;
        themeAccent = data.accent || data.color4 || "#89b4fa";
        themeBorder = data.color8 || data.color0 || "#45475a";

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.08);
            themeCellGrid = Qt.darker(bg, 1.15);
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.darker(themeFg, 1.4);
            themeModalBg = bg;
        } else {
            themeBoardBg = Qt.lighter(bg, 1.18);
            themeCellGrid = Qt.lighter(bg, 1.28);
            themeCardBg = Qt.lighter(bg, 1.25);
            themeSubtext = data.color7 || Qt.darker(themeFg, 1.3);
            themeModalBg = Qt.lighter(bg, 1.12);
        }
        boardCanvas.requestPaint();
    }

    function cycleTheme() {
        var themes = OmarchyThemes.themes;
        if (!themes || themes.length === 0) return;
        var currentId = themePalette.id || "";
        var nextIdx = 0;
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === currentId) {
                nextIdx = (i + 1) % themes.length;
                break;
            }
        }
        applyTheme(themes[nextIdx], themes[nextIdx].name);
        soundToast.show("🎨 " + themes[nextIdx].name);
    }

    function toggleMute() {
        isMuted = !isMuted;
        soundToast.show(isMuted ? "🔇 Muted" : "🔊 Unmuted");
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.play(name);
        }
    }

    function updateBestTime() {
        if (typeof settingsManager !== "undefined") {
            bestTime = settingsManager.getBestTime(Engine.currentDifficulty);
        }
    }

    function resetGame(diff) {
        gameTimer.stop();
        elapsedSeconds = 0;
        smileyState = "normal";
        Engine.init(diff || Engine.currentDifficulty);
        updateBestTime();
        boardCanvas.requestPaint();
    }

    function setDifficulty(diff) {
        resetGame(diff);
        soundToast.show("Mode: " + Engine.DIFFICULTIES[diff].label);
    }

    function handleEngineEvent(res) {
        if (!res) return;
        if (res.event === "click") {
            playSound("click");
            if (Engine.gameState === "playing" && !gameTimer.running) {
                gameTimer.start();
            }
        } else if (res.event === "flag") {
            playSound("flag");
        } else if (res.event === "unflag") {
            playSound("unflag");
        } else if (res.event === "explode") {
            gameTimer.stop();
            smileyState = "dead";
            playSound("explode");
            soundToast.show("💥 BOOM! Game Over");
        } else if (res.event === "win") {
            gameTimer.stop();
            smileyState = "won";
            playSound("win");
            if (elapsedSeconds < bestTime) {
                bestTime = elapsedSeconds;
                if (typeof settingsManager !== "undefined") {
                    settingsManager.setBestTime(Engine.currentDifficulty, bestTime);
                }
                soundToast.show("🏆 NEW RECORD: " + bestTime + "s!");
            } else {
                soundToast.show("🎉 CLEAR! Time: " + elapsedSeconds + "s");
            }
        }
        boardCanvas.requestPaint();
    }

    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (elapsedSeconds < 999) {
                elapsedSeconds++;
            }
        }
    }

    // Helper function for roundRect compatibility
    function drawRoundRect(ctx, x, y, w, h, r) {
        if (typeof ctx.roundRect === "function") {
            ctx.beginPath();
            ctx.roundRect(x, y, w, h, r);
            return;
        }
        var radius = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + w - radius, y);
        ctx.arcTo(x + w, y, x + w, y + radius, radius);
        ctx.lineTo(x + w, y + h - radius);
        ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
        ctx.lineTo(x + radius, y + h);
        ctx.arcTo(x, y + h, x, y + h - radius, radius);
        ctx.lineTo(x, y + radius);
        ctx.arcTo(x, y, x + radius, y, radius);
        ctx.closePath();
    }

    // Capture screenshot support
    function captureScreenshot(filePath, shouldQuit) {
        splashScreen.visible = false;
        root.contentItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // Main HUD & Layout
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (smileyState === "dead" || smileyState === "won") {
                if (event.key === Qt.Key_A || event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    resetGame();
                    soundToast.show("New Game Started");
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                toggleMute();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_T) {
                cycleTheme();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_R) {
                resetGame();
                soundToast.show("Restarted");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_1) {
                setDifficulty("beginner");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_2) {
                setDifficulty("intermediate");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_3) {
                setDifficulty("expert");
                event.accepted = true;
                return;
            }

            // Keyboard navigation
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.moveCursor(0, -1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.moveCursor(0, 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.moveCursor(-1, 0);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.moveCursor(1, 0);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                var res = Engine.reveal(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(res);
                event.accepted = true;
            } else if (event.key === Qt.Key_F) {
                var resF = Engine.toggleFlag(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(resF);
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                var resC = Engine.chord(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(resC);
                event.accepted = true;
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
                anchors.right: scoreRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "CyberSweeper"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (bestTime === 999 ? "No Record" : "Best: " + bestTime + "s") + " • " + (Engine.currentDifficulty === "beginner" ? "Beginner (9×9)" : (Engine.currentDifficulty === "intermediate" ? "Medium (16×16)" : "Expert (30×16)"))
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

                // MINES Card
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
                            text: "MINES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🚩 " + (Engine.flagsLeft < 0 ? "0" : Engine.flagsLeft)
                            font.family: root.monoFontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: root.themePalette.color1 || "#f38ba8"
                        }
                    }
                }

                // TIME Card
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
                            text: "TIME"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: elapsedSeconds + "s"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
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
            height: restartBtn.height

            // Help button
            Rectangle {
                id: helpBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(28, Math.min(34, parent.width * 0.065))
                width: Math.max(85, Math.min(115, parent.width * 0.22))
                radius: Math.max(6, height * 0.24)
                color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: root.themeAccent
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                        }
                    }
                    Text {
                        text: subheaderItem.width < 370 ? "Help" : "How to Play"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: helpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: showHelp = !showHelp
                }
            }

            // Difficulty toggle pill
            Rectangle {
                id: diffBtn
                anchors.left: helpBtn.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: helpBtn.height
                width: Math.max(56, Math.min(78, parent.width * 0.16))
                radius: helpBtn.radius
                color: diffMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: Engine.currentDifficulty === "beginner" ? "9×9" : (Engine.currentDifficulty === "intermediate" ? "16²" : "30²")
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.monoFontFamily
                    color: root.themeFg
                }

                MouseArea {
                    id: diffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var diffs = ["beginner", "intermediate", "expert"];
                        var next = (diffs.indexOf(Engine.currentDifficulty) + 1) % diffs.length;
                        setDifficulty(diffs[next]);
                    }
                }
            }

            // Mute button
            Rectangle {
                id: muteBtn
                anchors.right: restartBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: helpBtn.height
                width: Math.max(54, Math.min(84, parent.width * 0.16))
                radius: helpBtn.radius
                color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: root.isMuted ? root.themeBorder : root.themeAccent
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.isMuted ? "Muted" : "Sound"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.isMuted ? root.themeSubtext : root.themeFg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: muteBtn.width >= 62
                    }
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleMute()
                }
            }

            // Primary Action Button (Smiley / Restart)
            Rectangle {
                id: restartBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: helpBtn.height
                width: Math.max(90, Math.min(125, parent.width * 0.26))
                radius: helpBtn.radius
                color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: smileyState === "dead" ? "😵" : (smileyState === "won" ? "😎" : "😊")
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: subheaderItem.width < 340 ? "Reset" : "Reset (R)"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeBtnFg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: restartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resetGame()
                }
            }
        }

        // Playing Board Area
        Item {
            id: boardArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            property real availableWidth: width
            property real availableHeight: height
            property real maxCellW: availableWidth / Engine.cols
            property real maxCellH: availableHeight / Engine.rows
            property real cellSize: Math.floor(Math.min(maxCellW, maxCellH, 88))
            property real boardPixelW: cellSize * Engine.cols
            property real boardPixelH: cellSize * Engine.rows

            Canvas {
                id: boardCanvas
                width: boardArea.boardPixelW
                height: boardArea.boardPixelH
                anchors.centerIn: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cs = boardArea.cellSize;
                    var pad = Math.max(1.5, cs * 0.06);
                    var cellInner = cs - pad * 2;
                    var rad = Math.max(2, cs * 0.15);

                    var pal = root.themePalette;
                    var numColors = [
                        "",
                        pal.color4 || "#89b4fa",
                        pal.color2 || "#a6e3a1",
                        pal.color1 || "#f38ba8",
                        pal.color5 || "#cba6f7",
                        pal.color11 || "#fab387",
                        pal.color6 || "#94e2d5",
                        root.themeSubtext,
                        root.themeFg
                    ];

                    for (var r = 0; r < Engine.rows; r++) {
                        for (var c = 0; c < Engine.cols; c++) {
                            var cell = Engine.board[r] ? Engine.board[r][c] : null;
                            if (!cell) continue;

                            var cx = c * cs + pad;
                            var cy = r * cs + pad;

                            if (!cell.revealed) {
                                // Elevated tile
                                ctx.fillStyle = root.themeCardBg;
                                drawRoundRect(ctx, cx, cy, cellInner, cellInner, rad);
                                ctx.fill();

                                ctx.strokeStyle = root.themeBorder;
                                ctx.lineWidth = 1;
                                ctx.stroke();

                                if (cell.flagged) {
                                    // Flag icon
                                    ctx.fillStyle = pal.color1 || "#f38ba8";
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.35, cy + cellInner * 0.25);
                                    ctx.lineTo(cx + cellInner * 0.75, cy + cellInner * 0.42);
                                    ctx.lineTo(cx + cellInner * 0.35, cy + cellInner * 0.6);
                                    ctx.closePath();
                                    ctx.fill();

                                    // Flag pole
                                    ctx.strokeStyle = root.themeSubtext;
                                    ctx.lineWidth = Math.max(2, cs * 0.08);
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.35, cy + cellInner * 0.2);
                                    ctx.lineTo(cx + cellInner * 0.35, cy + cellInner * 0.8);
                                    ctx.stroke();

                                    // Flag base
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.2, cy + cellInner * 0.8);
                                    ctx.lineTo(cx + cellInner * 0.55, cy + cellInner * 0.8);
                                    ctx.stroke();
                                }
                            } else {
                                // Revealed cell
                                if (cell.exploded) {
                                    ctx.fillStyle = pal.color1 || "#f38ba8";
                                } else {
                                    ctx.fillStyle = root.themeBoardBg;
                                }
                                drawRoundRect(ctx, cx, cy, cellInner, cellInner, rad);
                                ctx.fill();

                                ctx.strokeStyle = root.themeBg;
                                ctx.lineWidth = 1;
                                ctx.stroke();

                                if (cell.mine) {
                                    // Draw Mine
                                    var centerX = cx + cellInner / 2;
                                    var centerY = cy + cellInner / 2;
                                    var mineRadius = cellInner * 0.24;

                                    ctx.strokeStyle = cell.exploded ? "#ffffff" : root.themeFg;
                                    ctx.lineWidth = Math.max(2, cs * 0.07);

                                    // Spikes
                                    for (var a = 0; a < 4; a++) {
                                        var angle = a * (Math.PI / 4);
                                        ctx.beginPath();
                                        ctx.moveTo(centerX - Math.cos(angle) * (mineRadius * 1.5), centerY - Math.sin(angle) * (mineRadius * 1.5));
                                        ctx.lineTo(centerX + Math.cos(angle) * (mineRadius * 1.5), centerY + Math.sin(angle) * (mineRadius * 1.5));
                                        ctx.stroke();
                                    }

                                    // Mine body
                                    ctx.fillStyle = cell.exploded ? "#ffffff" : root.themeFg;
                                    ctx.beginPath();
                                    ctx.arc(centerX, centerY, mineRadius, 0, Math.PI * 2);
                                    ctx.fill();

                                    // Specular shine
                                    ctx.fillStyle = cell.exploded ? (pal.color1 || "#f38ba8") : root.themeBoardBg;
                                    ctx.beginPath();
                                    ctx.arc(centerX - mineRadius * 0.3, centerY - mineRadius * 0.3, mineRadius * 0.3, 0, Math.PI * 2);
                                    ctx.fill();
                                } else if (cell.neighborMines > 0) {
                                    // Number
                                    ctx.fillStyle = numColors[cell.neighborMines] || root.themeFg;
                                    ctx.font = "bold " + Math.floor(cellInner * 0.6) + "px sans-serif";
                                    ctx.textAlign = "center";
                                    ctx.textBaseline = "middle";
                                    ctx.fillText(cell.neighborMines, cx + cellInner / 2, cy + cellInner / 2 + 1);
                                }
                            }

                            // Keyboard cursor indicator
                            if (Engine.cursor.r === r && Engine.cursor.c === c) {
                                ctx.strokeStyle = root.themeAccent;
                                ctx.lineWidth = 2.5;
                                drawRoundRect(ctx, cx - 1, cy - 1, cellInner + 2, cellInner + 2, rad + 1);
                                ctx.stroke();
                            }
                        }
                    }
                }

                MouseArea {
                    id: boardMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true

                    function getCellAt(mouse) {
                        var cs = boardArea.cellSize;
                        var col = Math.floor(mouse.x / cs);
                        var row = Math.floor(mouse.y / cs);
                        return { r: row, c: col };
                    }

                    onPressed: function(mouse) {
                        var cellPos = getCellAt(mouse);
                        if (cellPos.r >= 0 && cellPos.r < Engine.rows && cellPos.c >= 0 && cellPos.c < Engine.cols) {
                            Engine.cursor.r = cellPos.r;
                            Engine.cursor.c = cellPos.c;
                            if (mouse.button === Qt.LeftButton) {
                                smileyState = "scared";
                            }
                            boardCanvas.requestPaint();
                        }
                    }

                    onReleased: function(mouse) {
                        if (smileyState === "scared") smileyState = "normal";
                        var cellPos = getCellAt(mouse);
                        if (cellPos.r < 0 || cellPos.r >= Engine.rows || cellPos.c < 0 || cellPos.c >= Engine.cols) {
                            return;
                        }

                        if (mouse.button === Qt.RightButton) {
                            var resF = Engine.toggleFlag(cellPos.r, cellPos.c);
                            handleEngineEvent(resF);
                        } else if (mouse.button === Qt.LeftButton) {
                            var cell = Engine.board[cellPos.r][cellPos.c];
                            if (cell.revealed) {
                                var resC = Engine.chord(cellPos.r, cellPos.c);
                                handleEngineEvent(resC);
                            } else {
                                var res = Engine.reveal(cellPos.r, cellPos.c);
                                handleEngineEvent(res);
                            }
                        }
                    }
                }

                // Game Over / Victory Overlay
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.78)
                    visible: smileyState === "dead" || smileyState === "won"
                    z: 50

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resetGame();
                            soundToast.show("New Game Started");
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: smileyState === "won" ? "VICTORY!" : "GAME OVER"
                            font.family: root.monoFontFamily
                            font.pixelSize: 24
                            font.bold: true
                            color: smileyState === "won" ? (root.themePalette.color2 || "#a6e3a1") : (root.themePalette.color1 || "#f38ba8")
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: smileyState === "won" ? ("Time: " + elapsedSeconds + "s" + (bestTime < 9999 ? "  •  Best: " + bestTime + "s" : "")) : "Mine Detonated!"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140
                            height: 42
                            radius: 8
                            color: root.themeAccent

                            Text {
                                anchors.centerIn: parent
                                text: "PLAY AGAIN"
                                font.family: root.monoFontFamily
                                font.bold: true
                                font.pixelSize: 13
                                color: root.themeBg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    resetGame();
                                    soundToast.show("New Game Started");
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Or press R / Space / Enter"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            color: root.themeSubtext
                        }
                    }
                }
            }
        }
    }

    // TOAST
    Rectangle {
        id: soundToast
        property alias message: toastText.text
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 32
        height: 38
        radius: 19
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        opacity: 0
        z: 99

        function show(msg) {
            message = msg;
            toastAnim.restart();
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.pixelSize: 13
            font.bold: true
            color: root.themeFg
        }

        SequentialAnimation {
            id: toastAnim
            PropertyAnimation { target: soundToast; property: "opacity"; to: 0.95; duration: 150 }
            PauseAnimation { duration: 1600 }
            PropertyAnimation { target: soundToast; property: "opacity"; to: 0; duration: 250 }
        }
    }

    // HELP MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: showHelp
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: showHelp = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(440, parent.width - 40)
            height: 380
            radius: 16
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "💣 CyberSweeper Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Clear all mine-free tiles as quickly as possible. Flag suspicious tiles and chord revealed numbers to blaze through!"
                    font.pixelSize: 12
                    color: root.themeSubtext
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.themeBorder
                }

                Grid {
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 16

                    Text { text: "Left Click / Space / Enter"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Reveal tile"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Right Click / F"; font.bold: true; color: root.themePalette.color1 || "#f38ba8"; font.pixelSize: 12 }
                    Text { text: "Toggle Flag"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Double Click / C"; font.bold: true; color: root.themePalette.color2 || "#a6e3a1"; font.pixelSize: 12 }
                    Text { text: "Chord (reveal neighbors)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Arrow Keys / WASD / HJKL"; font.bold: true; color: root.themePalette.color5 || "#cba6f7"; font.pixelSize: 12 }
                    Text { text: "Navigate Grid"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "1 / 2 / 3"; font.bold: true; color: root.themePalette.color3 || "#f9e2af"; font.pixelSize: 12 }
                    Text { text: "Difficulty (9x9 / 16x16 / 30x16)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "R / M / T"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Restart / Mute / Next Theme"; color: root.themeFg; font.pixelSize: 12 }
                }

                Item { width: 1; height: 10 }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Got It!"
                    onClicked: showHelp = false
                }
            }
        }
    }

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }
}
