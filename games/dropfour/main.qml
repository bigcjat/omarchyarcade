import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 540
    height: 620
    minimumWidth: 380
    minimumHeight: 460
    title: "DropFour"

    signal screenshotSaved(string path)

    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: "Catppuccin"

    property color themeBg: "#181825"
    property color themeFg: "#cdd6f4"
    property color themeAccent: "#89b4fa"
    property color themeBoardBg: "#1e293b"
    property color themeCellGrid: "#313244"
    property color themeCardBg: "#1e1e2e"
    property color themeCardHover: "#313244"
    property color themeSubtext: "#a6adc8"
    property color themeBorder: "#45475a"
    property color themeModalBg: "#1e1e2e"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool isDarkMode: colorLuminance(themeBg) < 0.5

    // Tokens
    property color p1Color: "#f38ba8"
    property color p2Color: "#f9e2af"

    // State
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int p1Wins: 0
    property int p2Wins: 0
    property int draws: 0
    property bool cpuThinking: false
    property string gameState: "playing"
    property int currentPlayer: 1
    property string winnerName: ""
    property string gameMode: "1p"
    property string cpuDifficulty: "pro"

    color: themeBg

    Component.onCompleted: {
        loadStats();
        Engine.init("1p", "pro");
    }

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
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
        themeBorder = data.border || data.color8 || data.color0 || "#45475a";

        p1Color = data.color1 || data.color9 || "#f38ba8";
        p2Color = data.color3 || data.color11 || "#f9e2af";

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            p1Color = data.color1 || "#e11d48";
            p2Color = data.color3 || "#eab308";
            themeBoardBg = data.boardBg || "#2563eb";
            themeCellGrid = Qt.darker(themeBoardBg, 1.2);
            themeCardBg = data.cardBg || "#ffffff";
            themeCardHover = "#f1f5f9";
            themeSubtext = data.subtext || "#64748b";
            themeBorder = data.border || "#ccd0da";
            themeModalBg = "#ffffff";
            themeBtnFg = "#ffffff";
        } else {
            themeBoardBg = data.boardBg || "#11111b";
            themeCellGrid = "#1e1e2e";
            themeCardBg = data.cardBg || "#1e1e2e";
            themeCardHover = "#313244";
            themeSubtext = data.subtext || data.color7 || "#a6adc8";
            themeBorder = data.border || "#45475a";
            themeModalBg = "#1e1e2e";
            themeBtnFg = colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff";
        }
        boardCanvas.requestPaint();
    }

    function cycleTheme() {
        if (isDarkMode) {
            applyTheme({
                name: "Omarchy Light",
                background: "#eff1f5",
                foreground: "#4c4f69",
                accent: "#1e66f5",
                color0: "#e6e9ef",
                color8: "#bcc0cc",
                cardBg: "#ffffff",
                boardBg: "#2563eb",
                border: "#ccd0da",
                subtext: "#5c5f77"
            }, "Light");
        } else {
            applyTheme({
                name: "Omarchy Dark",
                background: "#181825",
                foreground: "#cdd6f4",
                accent: "#89b4fa",
                color0: "#181825",
                color8: "#313244",
                cardBg: "#1e1e2e",
                boardBg: "#1e293b",
                border: "#313244",
                subtext: "#a6adc8"
            }, "Dark");
        }
        soundToast.show("🎨 " + currentThemeName);
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

    function loadStats() {
        if (typeof settingsManager !== "undefined") {
            p1Wins = settingsManager.getStat("p1Wins");
            p2Wins = settingsManager.getStat("p2Wins");
            draws = settingsManager.getStat("draws");
        }
    }

    function recordWin(player) {
        if (typeof settingsManager !== "undefined") {
            if (player === 1) {
                p1Wins++;
                settingsManager.setStat("p1Wins", p1Wins);
            } else if (player === 2) {
                p2Wins++;
                settingsManager.setStat("p2Wins", p2Wins);
            }
        }
    }

    function recordDraw() {
        if (typeof settingsManager !== "undefined") {
            draws++;
            settingsManager.setStat("draws", draws);
        }
    }

    function resetGame() {
        cpuTimer.stop();
        cpuThinking = false;
        Engine.init(root.gameMode, root.cpuDifficulty);
        root.gameState = "playing";
        root.currentPlayer = Engine.currentPlayer;
        root.winnerName = "";
        boardCanvas.requestPaint();
    }

    function doDrop(col) {
        if (cpuThinking || root.gameState !== "playing") return;
        var res = Engine.dropToken(col);
        if (!res || res.error) return;

        playSound("drop");
        root.currentPlayer = Engine.currentPlayer;
        boardCanvas.requestPaint();

        if (res.event === "win") {
            playSound("win");
            recordWin(res.player);
            root.winnerName = (res.player === 1) ? "Player 1" : (root.gameMode === "1p" ? "CPU" : "Player 2");
            root.gameState = "won";
            soundToast.show("🏆 " + root.winnerName + " Wins!");
            return;
        }

        if (res.event === "draw") {
            recordDraw();
            root.winnerName = "Nobody";
            root.gameState = "draw";
            soundToast.show("🤝 Draw Game!");
            return;
        }

        // Check if next turn is CPU in 1P mode
        if (root.gameMode === "1p" && Engine.currentPlayer === 2) {
            cpuThinking = true;
            cpuTimer.restart();
        }
    }

    Timer {
        id: cpuTimer
        interval: 320
        repeat: false
        onTriggered: {
            if (root.gameState !== "playing") {
                cpuThinking = false;
                return;
            }
            var cpuCol = Engine.getCpuMove();
            cpuThinking = false;
            if (cpuCol >= 0) {
                var res = Engine.dropToken(cpuCol);
                if (res) {
                    playSound("drop");
                    root.currentPlayer = Engine.currentPlayer;
                    boardCanvas.requestPaint();
                    if (res.event === "win") {
                        playSound("win");
                        recordWin(res.player);
                        root.winnerName = "CPU";
                        root.gameState = "won";
                        soundToast.show("🤖 CPU Wins!");
                    } else if (res.event === "draw") {
                        recordDraw();
                        root.winnerName = "Nobody";
                        root.gameState = "draw";
                        soundToast.show("🤝 Draw Game!");
                    }
                }
            }
        }
    }

    // roundRect helper
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

    function captureScreenshot(filePath, shouldQuit) {
        splashScreen.visible = false;
        root.contentItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // MAIN CONTAINER
    Item {
        id: mainContainer
        anchors.fill: parent
        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.gameState !== "playing") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_A || event.key === Qt.Key_R) {
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

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
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
            if (event.key === Qt.Key_Escape) {
                if (showHelp) {
                    showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            // Move column indicator
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.selectedCol = Math.max(0, Engine.selectedCol - 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.selectedCol = Math.min(Engine.COLS - 1, Engine.selectedCol + 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                doDrop(Engine.selectedCol);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_7) {
                var c = event.key - Qt.Key_1;
                Engine.selectedCol = c;
                doDrop(c);
                event.accepted = true;
            }
        }

        // Background Header Bar (flush arcade layout)
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTiledDesktopMode ? 0 : (headerItem.height + subheaderItem.height + 34)
            color: root.themeBg
            visible: !root.isTiledDesktopMode
            z: 0
        }

        // ROW 1: HEADER ITEM
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, scoreRow.height))
            z: 1

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
                    text: "DropFour"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.gameState === "won" ? "Winner: " + root.winnerName + "!" : (root.gameState === "draw" ? "Draw Game!" : (root.cpuThinking ? "CPU Thinking..." : ("Turn: " + (root.currentPlayer === 1 ? "P1 (Red)" : (root.gameMode === "1p" ? "CPU (Yellow)" : "P2 (Yellow)"))))))
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                }
            }

            // Stat Cards on Right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // P1 WINS Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "P1 WINS"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.p1Wins.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.isDarkMode ? root.themeFg : "#0f172a"
                        }
                    }
                }

                // P2 / CPU WINS Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.gameMode === "1p" ? "CPU WINS" : "P2 WINS"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.p2Wins.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.p2Wins > 0 ? (root.isDarkMode ? root.themeAccent : "#15803d") : (root.isDarkMode ? root.themeSubtext : "#94a3b8")
                        }
                    }
                }
            }
        }

        // ROW 2: SUBHEADER ACTION BAR
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : 34
            readonly property bool isCrowded: subheaderItem.width < 460
            z: 1

            // Left Controls (Help + View Mode)
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Help button
                Rectangle {
                    id: helpBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Row {
                        id: helpRow
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

                // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: viewModeMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1

                    Row {
                        id: viewModeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.fullPlayfield ? "🔲" : "⛶"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.fullPlayfield ? "Standard (⇧F)" : "Full (⇧F)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.fullPlayfield ? root.themeAccent : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: viewModeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                        }
                    }
                }
            }

            // Right Controls (Mode + Mute + New Game)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    id: modeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 36 : Math.max(54, Math.min(72, subheaderItem.width * 0.16))
                    radius: 8
                    color: modeMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: subheaderItem.isCrowded ? (root.gameMode === "1p" ? "1P" : "2P") : (root.gameMode === "1p" ? "1P vs CPU" : "2P Local")
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeAccent
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.gameMode = (root.gameMode === "1p") ? "2p" : "1p";
                            Engine.gameMode = root.gameMode;
                            resetGame();
                            soundToast.show("Mode: " + (root.gameMode === "1p" ? "1P vs CPU" : "2P Local"));
                        }
                    }
                }

                Rectangle {
                    id: muteBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Row {
                        id: muteRow
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

                Rectangle {
                    id: restartBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: subheaderItem.isCrowded
                        }
                        Text {
                            text: "New Game (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetGame()
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (Compact header active when tiled or full)
        // =====================================================================
        Rectangle {
            id: floatingTiledHUD
            visible: root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 38
            radius: 8
            z: 90
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "🔴 DropFour"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + (root.player1Wins + " - " + root.player2Wins)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("DRAWS: " + root.draws) + ")"
                    font.pixelSize: 10
                    color: root.themeSubtext
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Full Window Toggle
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "🔲"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = false;
                            soundToast.show("🔲 Standard Window");
                        }
                    }
                }

                // Help
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mute
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }
                // Restart
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "🔄"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetGame()
                    }
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playfieldContainer
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerBar.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Item {
                id: boardContainer
                anchors.fill: parent

                Item {
                    id: boardArea
                    property real availW: parent.width
                    property real availH: parent.height - 36
                    property real cellSize: Math.floor(Math.min(availW / Engine.COLS, availH / Engine.ROWS))
                    width: cellSize * Engine.COLS
                    height: cellSize * Engine.ROWS + 36
                    anchors.centerIn: parent

                    Canvas {
                        id: boardCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var cs = boardArea.cellSize;
                            var topH = 36;
                            var radius = cs * 0.38;

                            // Draw Column Drop Indicator at the top
                            if (root.gameState === "playing" && !cpuThinking) {
                                var indX = Engine.selectedCol * cs + cs / 2;
                                var indY = 16;
                                var indColor = (root.currentPlayer === 1) ? root.p1Color : root.p2Color;

                                ctx.fillStyle = indColor;
                                ctx.beginPath();
                                ctx.arc(indX, indY, radius * 0.7, 0, Math.PI * 2);
                                ctx.fill();

                                // Arrow pointing down
                                ctx.fillStyle = indColor;
                                ctx.beginPath();
                                ctx.moveTo(indX - 8, indY + radius * 0.7 + 2);
                                ctx.lineTo(indX + 8, indY + radius * 0.7 + 2);
                                ctx.lineTo(indX, indY + radius * 0.7 + 9);
                                ctx.closePath();
                                ctx.fill();
                            }

                            // Draw Board Cabinet
                            var boardY = topH;
                            ctx.fillStyle = root.themeBoardBg;
                            drawRoundRect(ctx, 0, boardY, width, height - topH, 16);
                            ctx.fill();

                            ctx.strokeStyle = root.isDarkMode ? root.themeBorder : Qt.darker(root.themeBoardBg, 1.25);
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            // Check if winning coordinates
                            function isWinning(r, c) {
                                for (var i = 0; i < Engine.winningCells.length; i++) {
                                    if (Engine.winningCells[i].r === r && Engine.winningCells[i].c === c) {
                                        return true;
                                    }
                                }
                                return false;
                            }

                            // Draw Slots & Tokens
                            for (var r = 0; r < Engine.ROWS; r++) {
                                for (var c = 0; c < Engine.COLS; c++) {
                                    var cx = c * cs + cs / 2;
                                    var cy = boardY + r * cs + cs / 2;
                                    var token = Engine.board[r][c];

                                    // Hole background: light cutout to table in light mode, dark recess in dark mode
                                    ctx.fillStyle = root.isDarkMode ? "#0c101c" : Qt.darker(root.themeBg, 1.05);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                                    ctx.fill();

                                    // Slot depth shadow
                                    ctx.strokeStyle = root.isDarkMode ? "#1e1e2e" : Qt.rgba(0, 0, 0, 0.22);
                                    ctx.lineWidth = 1.5;
                                    ctx.stroke();

                                    if (token !== 0) {
                                        var color = (token === 1) ? root.p1Color : root.p2Color;
                                        ctx.fillStyle = color;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, radius - 2, 0, Math.PI * 2);
                                        ctx.fill();

                                        // Inner highlight ring for retro arcade token feel
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
                                        ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, radius * 0.65, 0, Math.PI * 2);
                                        ctx.stroke();

                                        // Specular shine
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.4)";
                                        ctx.beginPath();
                                        ctx.arc(cx - radius * 0.28, cy - radius * 0.28, radius * 0.22, 0, Math.PI * 2);
                                        ctx.fill();

                                        if (isWinning(r, c)) {
                                            // Glow star or ring
                                            ctx.strokeStyle = "#ffffff";
                                            ctx.lineWidth = 3.5;
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, radius + 1, 0, Math.PI * 2);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPositionChanged: function(mouse) {
                                var cs = boardArea.cellSize;
                                var col = Math.floor(mouse.x / cs);
                                if (col >= 0 && col < Engine.COLS && col !== Engine.selectedCol) {
                                    Engine.selectedCol = col;
                                    boardCanvas.requestPaint();
                                }
                            }

                            onClicked: function(mouse) {
                                if (root.gameState !== "playing") {
                                    resetGame();
                                    soundToast.show("New Game Started");
                                    return;
                                }
                                var cs = boardArea.cellSize;
                                var col = Math.floor(mouse.x / cs);
                                if (col >= 0 && col < Engine.COLS) {
                                    Engine.selectedCol = col;
                                    doDrop(col);
                                }
                            }
                        }
                    }

                    // Game Over / Victory Overlay
                    Rectangle {
                        id: gameOverOverlay
                        anchors.fill: parent
                        radius: 16
                        color: Qt.rgba(0, 0, 0, 0.78)
                        visible: root.gameState !== "playing"
                        z: 60

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
                                text: root.gameState === "won" ? (root.winnerName.toUpperCase() + " WINS!") : "DRAW GAME!"
                                font.family: root.monoFontFamily
                                font.pixelSize: 24
                                font.bold: true
                                color: root.gameState === "won" ? (root.winnerName === "Player 1" ? root.p1Color : root.p2Color) : root.themeFg
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "P1: " + root.p1Wins + "  —  " + (root.gameMode === "1p" ? "CPU: " : "P2: ") + root.p2Wins
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
                                    color: root.themeBtnFg
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
            height: 400
            radius: 16
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "🔴 DropFour Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Connect 4 tokens in a row vertically, horizontally, or diagonally. Outsmart the Minimax AI or challenge a friend locally!"
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

                    Text { text: "Left / Right / A / D / H / L"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Select Column"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Space / Down / Enter"; font.bold: true; color: root.p1Color; font.pixelSize: 12 }
                    Text { text: "Drop Token"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Keys 1 - 7"; font.bold: true; color: root.p2Color; font.pixelSize: 12 }
                    Text { text: "Quick Drop in Column"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Shift+F"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Full / Compact View (⇧F)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "R / M / T"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Restart / Mute / Next Theme"; color: root.themeFg; font.pixelSize: 12 }
                }

                Item { width: 1; height: 10 }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Got It!"
                    onClicked: showHelp = false
                }

                Text {
                    text: "Created by Chris Thompson (@bigcjat) with Gemini"
                    font.pixelSize: 10
                    color: root.themeSubtext
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.75
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
