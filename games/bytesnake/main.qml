import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 680
    minimumWidth: 320
    minimumHeight: 460
    title: currentThemeName.length > 0 ? "ByteSnake • " + currentThemeName : "ByteSnake"

    property color themeBg: "#181825"
    property color themeBoardBg: "#0a0e14"
    property color themeCellGrid: "#141d28"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#a6e3a1" // Green snake by default
    property color themeFood: "#f38ba8"   // Red apple food
    property color themeBtnBg: "#89b4fa"
    property color themeBtnFg: "#11111b"
    property color themeBorder: "#45475a"
    property color themeModalBg: "#1e1e2e"
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: ""
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeCardHover: isDarkMode ? Qt.lighter(themeCardBg, 1.15) : "#f1f5f9"

    color: themeBg
    Behavior on color { ColorAnimation { duration: 250 } }

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
        themeAccent = data.accent || data.color2 || "#a6e3a1";
        themeFood = data.color1 || data.color9 || "#f38ba8";
        themeBtnBg = data.accent || themeBtnBg;
        themeBtnFg = data.background || "#11111b";
        themeBorder = data.border || data.color8 || themeBorder;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = data.boardBg || "#e6eaf1";
            themeCellGrid = Qt.rgba(100/255, 116/255, 139/255, 0.18);
            themeCardBg = data.cardBg || "#ffffff";
            themeSubtext = data.subtext || "#64748b";
            themeBorder = data.border || "#ccd0da";
            themeBtnFg = "#ffffff";
            themeModalBg = bg;
        } else {
            themeBoardBg = data.boardBg || "#0a0e14";
            themeCellGrid = "#141d28";
            themeCardBg = data.cardBg || Qt.lighter(bg, 1.25);
            themeSubtext = data.color7 || Qt.darker(themeFg, 1.3);
            themeBtnFg = colorLuminance(themeBtnBg) > 0.5 ? "#11111b" : "#ffffff";
            themeModalBg = Qt.lighter(bg, 1.12);
        }
        boardCanvas.requestPaint();
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#40a02b",
            color1: "#d20f39",
            color2: "#40a02b",
            color8: "#bcc0cc",
            cardBg: "#ffffff",
            boardBg: "#e6eaf1",
            border: "#ccd0da",
            subtext: "#5c5f77"
        } : {
            background: "#181825",
            foreground: "#cdd6f4",
            accent: "#a6e3a1",
            color1: "#f38ba8",
            color2: "#a6e3a1",
            color8: "#313244",
            cardBg: "#1e1e2e",
            boardBg: "#11111b",
            border: "#313244",
            subtext: "#a6adc8"
        };
        applyTheme(tData, nextIsLight ? "Omarchy Light" : "Omarchy Dark");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    // Audio handlers
    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playEat();
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    // Game state
    property int score: 0
    property int bestScore: 0
    property int level: 1
    property bool isOver: false
    property bool isPaused: false
    property bool wrapWalls: false

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
        }
        startNewGame();
    }

    function startNewGame() {
        Engine.initGame(root.wrapWalls);
        root.isOver = false;
        root.isPaused = false;
        syncFromEngine();
        gameTimer.interval = Engine.getInterval();
        gameTimer.restart();
    }

    function syncFromEngine() {
        var st = Engine.getState();
        root.score = st.score;
        if (st.score > root.bestScore) {
            root.bestScore = st.score;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(root.bestScore);
            }
        }
        root.level = st.level;
        root.isOver = st.isOver;
        gameTimer.interval = Engine.getInterval();
        boardCanvas.requestPaint();
    }

    Timer {
        id: gameTimer
        interval: 120
        repeat: true
        running: !root.isOver && !root.isPaused && !root.showHelp && (!splashScreen.visible || splashScreen.opacity === 0)
        onTriggered: {
            var res = Engine.tick();
            if (res.ate) {
                if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) soundManager.playEat();
            } else if (res.moved) {
                // optional light move tick
            }
            if (res.over) {
                gameTimer.stop();
                if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) soundManager.playGameOver();
            }
            syncFromEngine();
        }
    }

    // Main Keyboard Controls
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape) {
                if (root.showHelp) {
                    root.showHelp = false;
                } else if (!root.isOver) {
                    root.isPaused = !root.isPaused;
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
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
                root.cycleTheme();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier || root.isOver || root.isPaused)) {
                root.wrapWalls = !root.wrapWalls;
                soundToast.show(root.wrapWalls ? "🌐 Wrap Walls: ON" : "🧱 Wrap Walls: OFF (Solid)");
                Engine.initGame(root.wrapWalls);
                syncFromEngine();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P) {
                if (!root.isOver) root.isPaused = !root.isPaused;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                startNewGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Space || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.isOver)) {
                if (root.isOver) {
                    startNewGame();
                } else {
                    root.isPaused = !root.isPaused;
                }
                event.accepted = true;
                return;
            }

            if (root.isPaused || root.isOver || root.showHelp) return;

            // Direction inputs: Arrow, WASD, Vim (H, J, K, L)
            if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.setDirection(0, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.setDirection(0, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.setDirection(-1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.setDirection(1, 0);
                event.accepted = true;
            }
        }
    }

    // =====================================================================
    // TOP OS-THEMED HEADER BAR (Adapts strictly to user desktop OS theme)
    // =====================================================================
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.isTiledDesktopMode ? 0 : (subheaderItem.y + subheaderItem.height + 12)
        visible: !root.isTiledDesktopMode
        color: root.themeBg
        border.color: root.themeBorder
        border.width: 1
        z: 0
    }

    // 2048 DESIGN STANDARD: ROW 1 (Header Item)
    Item {
        id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : Math.max(titleCol.height, scoreRow.height)

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
                    text: "ByteSnake"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.wrapWalls ? "Wrap: ON" : "Solid Walls") + " • Speed: " + root.level
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

                // SCORE Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCORE"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.isDarkMode ? root.themeFg : "#0f172a"
                        }
                    }
                }

                // BEST Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BEST"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bestScore.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.bestScore > 0 ? (root.isDarkMode ? root.themeAccent : "#15803d") : (root.isDarkMode ? root.themeSubtext : "#94a3b8")
                        }
                    }
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
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
            readonly property bool isCrowded: subheaderItem.width < 450

            // Help button
            Rectangle {
                id: helpBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                radius: 8
                color: helpMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff")
                border.color: helpMouse.containsMouse ? root.themeAccent : (root.isDarkMode ? root.themeBorder : "#cbd5e1")
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

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
                        color: root.isDarkMode ? root.themeFg : "#1e293b"
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

            // Right controls: Mute, View Mode Toggle, Restart
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Mute button
                Rectangle {
                    id: muteBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff")
                    border.color: root.isMuted ? (root.isDarkMode ? root.themeBorder : "#cbd5e1") : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

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
                            color: root.isMuted ? (root.isDarkMode ? root.themeSubtext : "#64748b") : (root.isDarkMode ? root.themeFg : "#1e293b")
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

                // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: root.fullPlayfield ? (root.isDarkMode ? root.themeCardBg : "#e2e8f0") : (viewModeMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff"))
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : (root.isDarkMode ? root.themeBorder : "#cbd5e1"))
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

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
                            color: root.fullPlayfield ? root.themeAccent : (root.isDarkMode ? root.themeFg : "#1e293b")
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

                // Primary Action Button (Restart)
                Rectangle {
                    id: restartBtn
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
                        onClicked: root.startNewGame()
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
            color: root.isDarkMode ? root.themeCardBg : "#ffffff"
            border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "🐍 ByteSnake"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• SCORE: " + root.score
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    text: "(BEST: " + root.bestScore + ")"
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
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerBar.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            Rectangle {
                id: boardContainer
                width: Math.min(parent.width, parent.height)
                height: width
                anchors.centerIn: parent
                radius: 12
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 2
                clip: true

                Canvas {
                    id: boardCanvas
                    anchors.fill: parent
                    anchors.margins: 6
                    renderTarget: Canvas.FramebufferObject

                    function drawRoundRect(ctx, x, y, w, h, r) {
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + w - r, y);
                        ctx.arcTo(x + w, y, x + w, y + r, r);
                        ctx.lineTo(x + w, y + h - r);
                        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                        ctx.lineTo(x + r, y + h);
                        ctx.arcTo(x, y + h, x, y + h - r, r);
                        ctx.lineTo(x, y + r);
                        ctx.arcTo(x, y, x + r, y, r);
                        ctx.closePath();
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        var st = Engine.getState();
                        var gs = st.gridSize;
                        var cellW = width / gs;
                        var cellH = height / gs;

                        // Background grid
                        ctx.fillStyle = root.themeBoardBg;
                        ctx.fillRect(0, 0, width, height);

                        // Subtle grid dots/lines
                        ctx.strokeStyle = root.themeCellGrid;
                        ctx.lineWidth = 1;
                        for (var i = 1; i < gs; i++) {
                            ctx.beginPath();
                            ctx.moveTo(i * cellW, 0);
                            ctx.lineTo(i * cellW, height);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(0, i * cellH);
                            ctx.lineTo(width, i * cellH);
                            ctx.stroke();
                        }

                        // Draw Food Pellet
                        var fx = st.food.x * cellW + cellW / 2;
                        var fy = st.food.y * cellH + cellH / 2;
                        var frad = Math.min(cellW, cellH) * 0.42;

                        // Food outer soft glow
                        var radGrad = ctx.createRadialGradient(fx, fy, frad * 0.2, fx, fy, frad * 1.5);
                        radGrad.addColorStop(0, root.themeFood);
                        radGrad.addColorStop(1, "transparent");
                        ctx.fillStyle = radGrad;
                        ctx.beginPath();
                        ctx.arc(fx, fy, frad * 1.5, 0, 2 * Math.PI);
                        ctx.fill();

                        // Food core circle
                        ctx.fillStyle = root.themeFood;
                        ctx.beginPath();
                        ctx.arc(fx, fy, frad, 0, 2 * Math.PI);
                        ctx.fill();
                        // Food highlight
                        ctx.fillStyle = "#ffffff";
                        ctx.beginPath();
                        ctx.arc(fx - frad * 0.3, fy - frad * 0.3, frad * 0.35, 0, 2 * Math.PI);
                        ctx.fill();

                        // Draw Snake
                        var s = st.snake;
                        if (!s || s.length === 0) return;

                        // Body Segments
                        for (var b = s.length - 1; b >= 0; b--) {
                            var seg = s[b];
                            var bx = seg.x * cellW + cellW * 0.08;
                            var by = seg.y * cellH + cellH * 0.08;
                            var bw = cellW * 0.84;
                            var bh = cellH * 0.84;
                            var brad = bw * 0.35;

                            var alpha = 0.55 + (0.45 * (s.length - b) / s.length);
                            ctx.fillStyle = (b === 0) ? root.themeAccent : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, alpha);

                            // Rounded rectangle
                            drawRoundRect(ctx, bx, by, bw, bh, brad);
                            ctx.fill();

                            // Head details (Eyes)
                            if (b === 0) {
                                var dir = st.direction;
                                var cx = seg.x * cellW + cellW / 2;
                                var cy = seg.y * cellH + cellH / 2;
                                var eyeOffset = bw * 0.24;
                                var eyeSize = bw * 0.18;

                                var e1x = cx, e1y = cy, e2x = cx, e2y = cy;
                                if (dir.x === 1) { // Moving Right
                                    e1x = cx + eyeOffset; e1y = cy - eyeOffset;
                                    e2x = cx + eyeOffset; e2y = cy + eyeOffset;
                                } else if (dir.x === -1) { // Moving Left
                                    e1x = cx - eyeOffset; e1y = cy - eyeOffset;
                                    e2x = cx - eyeOffset; e2y = cy + eyeOffset;
                                } else if (dir.y === -1) { // Moving Up
                                    e1x = cx - eyeOffset; e1y = cy - eyeOffset;
                                    e2x = cx + eyeOffset; e2y = cy - eyeOffset;
                                } else { // Moving Down
                                    e1x = cx - eyeOffset; e1y = cy + eyeOffset;
                                    e2x = cx + eyeOffset; e2y = cy + eyeOffset;
                                }

                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(e1x, e1y, eyeSize, 0, 2 * Math.PI);
                                ctx.arc(e2x, e2y, eyeSize, 0, 2 * Math.PI);
                                ctx.fill();

                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(e1x + dir.x * 0.8, e1y + dir.y * 0.8, eyeSize * 0.55, 0, 2 * Math.PI);
                                ctx.arc(e2x + dir.x * 0.8, e2y + dir.y * 0.8, eyeSize * 0.55, 0, 2 * Math.PI);
                                ctx.fill();
                            }
                        }
                    }
                }

                // Pause Overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.65)
                    visible: root.isPaused && !root.isOver
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { text: "PAUSED"; font.family: root.monoFontFamily; font.bold: true; font.pixelSize: 26; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Press Space or P to resume"; font.family: root.monoFontFamily; font.pixelSize: 13; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Game Over Overlay
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.78)
                    visible: root.isOver
                    z: 50

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame()
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        Text { text: "GAME OVER"; font.family: root.monoFontFamily; font.bold: true; font.pixelSize: 24; color: root.themeFood; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Score: " + root.score + (root.highScore > 0 ? "  •  HI " + root.highScore : ""); font.family: root.monoFontFamily; font.bold: true; font.pixelSize: 15; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                        Rectangle {
                            width: 140
                            height: 42
                            radius: 8
                            color: root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
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
                                onClicked: root.startNewGame()
                            }
                        }
                        Text { text: "Or press R / Space / Enter"; font.family: root.monoFontFamily; font.pixelSize: 11; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

    // Help Modal
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: root.showHelp
        z: 90

        MouseArea { anchors.fill: parent; onClicked: root.showHelp = false }

        Rectangle {
            width: Math.min(parent.width * 0.9, 400)
            height: 410
            radius: 12
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1
            anchors.centerIn: parent

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Item {
                    width: parent.width
                    height: 24
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "🎮 How to Play ByteSnake"; font.bold: true; font.pixelSize: 16; color: root.themeFg }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "✕"; font.pixelSize: 16; color: root.themeSubtext; MouseArea { anchors.fill: parent; onClicked: root.showHelp = false } }
                }

                Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                Grid {
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 16
                    Text { text: "Move Snake:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Arrow Keys, WASD, Vim (H,J,K,L)"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Pause / Resume:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Space or P"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Restart:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "R"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Cycle Theme:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "T (cycles all 22 Omarchy palettes)"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Full / Compact View:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Shift+F (⇧F)"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Toggle Mute:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "M"; color: root.themeFg; font.pixelSize: 12 }
                }

                Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                Text {
                    text: "Eat the glowing food to grow. Avoid crashing into walls and your own tail!"
                    wrapMode: Text.WordWrap
                    width: parent.width
                    font.pixelSize: 12
                    color: root.themeSubtext
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

    // Sound / Action Toast
    Rectangle {
        id: soundToast
        width: toastText.implicitWidth + 24
        height: 34
        radius: 8
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: 0
        z: 100

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.family: root.monoFontFamily
            font.pixelSize: 12
            font.bold: true
            color: root.themeFg
        }

        Timer {
            id: toastTimer
            interval: 1400
            onTriggered: soundToast.opacity = 0
        }

        function show(msg) {
            toastText.text = msg;
            soundToast.opacity = 1;
            toastTimer.restart();
        }
    }

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: keyHandler
    }

    function captureScreenshot(filePath, shouldQuit) {
        if (splashScreen) {
            splashScreen.visible = false;
            splashScreen.opacity = 0;
        }
        var targetItem = root.contentItem;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }
}
