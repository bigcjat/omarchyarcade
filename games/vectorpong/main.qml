import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 600
    height: 680
    minimumWidth: 340
    minimumHeight: 460
    title: currentThemeName.length > 0 ? "VectorPong • " + currentThemeName : "VectorPong"

    property color themeBg: "#181825"
    property color themeCourtBg: "#1e1e2e"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"   // P1 Paddle (Blue)
    property color themePaddle2: "#f9e2af" // P2 / CPU Paddle (Yellow)
    property color themeBall: "#ffffff"
    property color themeCardBg: "#313244"
    property color themeBorder: "#45475a"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property color themeModalBg: "#1e1e2e"
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: ""
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeCardHover: isDarkMode ? Qt.lighter(themeCardBg, 1.15) : "#f1f5f9"

    color: themeBg

    Rectangle {
        anchors.fill: parent
        color: root.themeBg
        z: -1
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

        var bg = data.background || data.bg || themeBg;
        themeBg = bg;
        themeFg = data.foreground || data.fg || themeFg;
        themeAccent = data.accent || data.color4 || "#89b4fa";
        themePaddle2 = data.color3 || data.color11 || "#f9e2af";
        themeBall = data.color15 || data.foreground || "#ffffff";
        themeBorder = data.border || data.color8 || data.color0 || themeBorder;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeCourtBg = "#0a0e17";
            themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#ffffff";
            themeBorder = data.border || Qt.rgba(0, 0, 0, 0.12);
            themeSubtext = data.subtext || "#6c6f85";
            themeBtnFg = "#ffffff";
            themeModalBg = "#ffffff";
        } else {
            themeCourtBg = data.courtBg || "#0a0e17";
            themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#1e1e2e";
            themeBorder = data.border || "#313244";
            themeSubtext = data.subtext || "#a6adc8";
            themeBtnFg = "#0B0E14";
            themeModalBg = "#1e1e2e";
        }
        courtCanvas.requestPaint();
    }

    // Audio handlers
    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playHitPaddle();
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    // Game state
    property int score1: 0
    property int score2: 0
    property int p1Wins: 0
    property bool isOver: false
    property bool isPaused: false
    property string gameMode: "1P" // "1P" vs "2P"
    property string aiDifficulty: "Pro" // "Novice", "Pro", "Master"
    property int rallyCount: 0

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.p1Wins = settingsManager.getP1Wins();
        }
        startNewGame();
    }

    function startNewGame() {
        Engine.initGame(root.gameMode, root.aiDifficulty);
        root.isOver = false;
        root.isPaused = false;
        syncFromEngine();
        gameTimer.restart();
    }

    function syncFromEngine() {
        var st = Engine.getState();
        root.score1 = st.score1;
        root.score2 = st.score2;
        root.rallyCount = st.rallyCount;
        root.isOver = st.isOver;

        if (st.isOver) {
            gameTimer.stop();
            if (st.score1 > st.score2) {
                root.p1Wins++;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setP1Wins(root.p1Wins);
                }
            }
            if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) {
                soundManager.playGameOver();
            }
        }
        courtCanvas.requestPaint();
    }

    Timer {
        id: gameTimer
        interval: 16 // 60 FPS
        repeat: true
        running: !root.isOver && !root.isPaused && !root.showHelp && (!splashScreen.visible || splashScreen.opacity === 0)
        onTriggered: {
            var res = Engine.tick();
            if (res.hitPaddle) {
                if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) soundManager.playHitPaddle();
            } else if (res.hitWall) {
                if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) soundManager.playHitWall();
            }
            if (res.scored) {
                if (!root.isMuted && typeof soundManager !== "undefined" && soundManager) soundManager.playScore();
            }
            syncFromEngine();
        }
    }

    // Keyboard Handling
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        property bool p1Up: false
        property bool p1Down: false
        property bool p2Up: false
        property bool p2Down: false

        function updateMovement() {
            var m1 = 0;
            if (p1Up && !p1Down) m1 = -1;
            else if (p1Down && !p1Up) m1 = 1;
            Engine.setP1Movement(m1);

            if (root.gameMode === "2P") {
                var m2 = 0;
                if (p2Up && !p2Down) m2 = -1;
                else if (p2Down && !p2Up) m2 = 1;
                Engine.setP2Movement(m2);
            }
        }

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
                cycleTheme();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P) {
                if (!root.isOver) root.isPaused = !root.isPaused;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R || event.key === Qt.Key_Space) {
                if (root.isOver) {
                    startNewGame();
                } else if (event.key === Qt.Key_P || event.key === Qt.Key_Space) {
                    root.isPaused = !root.isPaused;
                }
                event.accepted = true;
                return;
            }

            // P1 Controls: W/S or Up/Down (if 1P)
            if (event.key === Qt.Key_W || (root.gameMode === "1P" && (event.key === Qt.Key_Up || event.key === Qt.Key_K))) {
                p1Up = true;
                updateMovement();
                event.accepted = true;
            } else if (event.key === Qt.Key_S || (root.gameMode === "1P" && (event.key === Qt.Key_Down || event.key === Qt.Key_J))) {
                p1Down = true;
                updateMovement();
                event.accepted = true;
            }

            // P2 Controls in 2P Mode: Up/Down or K/J
            if (root.gameMode === "2P") {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    p2Up = true;
                    updateMovement();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    p2Down = true;
                    updateMovement();
                    event.accepted = true;
                }
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_W || (root.gameMode === "1P" && (event.key === Qt.Key_Up || event.key === Qt.Key_K))) {
                p1Up = false;
                updateMovement();
            } else if (event.key === Qt.Key_S || (root.gameMode === "1P" && (event.key === Qt.Key_Down || event.key === Qt.Key_J))) {
                p1Down = false;
                updateMovement();
            }

            if (root.gameMode === "2P") {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    p2Up = false;
                    updateMovement();
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    p2Down = false;
                    updateMovement();
                }
            }
        }
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#1e66f5",
            color3: "#df8e1d",
            cardBg: "#ffffff",
            courtBg: "#0a0e17",
            border: "#ccd0da",
            subtext: "#64748b"
        } : {
            background: "#181825",
            foreground: "#cdd6f4",
            accent: "#89b4fa",
            color3: "#f9e2af",
            cardBg: "#1e1e2e",
            courtBg: "#0a0e17",
            border: "#313244",
            subtext: "#a6adc8"
        };
        applyTheme(tData, nextIsLight ? "Omarchy Light" : "Omarchy Dark");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    function cycleMode() {
        root.gameMode = (root.gameMode === "1P") ? "2P" : "1P";
        soundToast.show(root.gameMode === "1P" ? "👤 1-Player vs CPU" : "👥 2-Player Local");
        startNewGame();
    }

    function cycleDifficulty() {
        var diffs = ["Novice", "Pro", "Master"];
        var idx = (diffs.indexOf(root.aiDifficulty) + 1) % diffs.length;
        root.aiDifficulty = diffs[idx];
        soundToast.show("⚙️ CPU: " + root.aiDifficulty);
        startNewGame();
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
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, scoreRow.height))

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
                    text: "VectorPong"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.gameMode === "1P" ? ("vs CPU (" + root.aiDifficulty + ")") : "2-Player Local") + " • Rally: " + root.rallyCount
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

                // P1 SCORE Card
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
                            text: "PLAYER 1"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score1.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.isDarkMode ? root.themeAccent : "#1d4ed8"
                        }
                    }
                }

                // P2 / CPU Card
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
                            text: root.gameMode === "1P" ? "CPU" : "PLAYER 2"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score2.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.isDarkMode ? root.themePaddle2 : "#b45309"
                        }
                    }
                }
            }
        }

        // Subheader Action Bar
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

            Row {
                anchors.fill: parent
                spacing: 8

                // Help button
                Rectangle {
                    id: helpBtn
                    width: (parent.width - 32) / 5
                    height: parent.height
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
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
                            text: "Help"
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
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mode & Diff Pill
                Rectangle {
                    id: modeBtn
                    width: (parent.width - 32) / 5
                    height: parent.height
                    radius: 8
                    color: modeMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.gameMode === "1P" ? ("1P (" + root.aiDifficulty.substring(0, 3) + ")") : "2-Player"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.gameMode === "1P") {
                                root.cycleDifficulty();
                            } else {
                                root.cycleMode();
                            }
                        }
                    }
                }

                // Mute button
                Rectangle {
                    id: muteBtn
                    width: (parent.width - 32) / 5
                    height: parent.height
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

                // View Mode Pill
                Rectangle {
                    id: viewModeBtn
                    width: (parent.width - 32) / 5
                    height: parent.height
                    radius: 8
                    color: viewModeMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.fullPlayfield ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Row {
                        id: viewModeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.fullPlayfield ? "🔲" : "⛶"
                            font.pixelSize: 12
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.fullPlayfield ? "Standard" : "Full"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.fullPlayfield ? root.themeAccent : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
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

                // Primary Action Button (New Game)
                Rectangle {
                    id: restartBtn
                    width: (parent.width - 32) / 5
                    height: parent.height
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "New Game (R)"
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
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            // TILING DESKTOP FLOATING HUD
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
                        text: "🏓 VectorPong"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeAccent
                    }

                    Text {
                        text: "• " + (root.playerScore + " - " + root.aiScore)
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }
                    Text {
                        text: "(" + ("BEST: " + root.bestRally) + ")"
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
                        color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
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
                        color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                        Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = !root.showHelp
                        }
                    }

                    // Mute
                    Rectangle {
                        width: 26; height: 26; radius: 5
                        color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMute()
                        }
                    }
                    // Restart
                    Rectangle {
                        width: 26; height: 26; radius: 5
                        color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                        Text { text: "🔄"; font.pixelSize: 10; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.startNewGame()
                        }
                    }
                }
            }

            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Rectangle {
                id: courtContainer
                width: Math.min(parent.width, parent.height * (640 / 480))
                height: width * (480 / 640)
                anchors.centerIn: parent
                radius: 12
                color: root.themeCourtBg
                border.color: root.themeBorder
                border.width: 2
                clip: true

                Canvas {
                    id: courtCanvas
                    anchors.fill: parent
                    anchors.margins: 4
                    renderTarget: Canvas.FramebufferObject

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        var st = Engine.getState();
                        var sx = width / st.width;
                        var sy = height / st.height;

                        // Court surface
                        ctx.fillStyle = root.themeCourtBg;
                        ctx.fillRect(0, 0, width, height);

                        // Dashed Center Net
                        ctx.strokeStyle = root.themeBorder;
                        ctx.lineWidth = Math.max(2, 3 * sx);
                        ctx.setLineDash([8 * sy, 8 * sy]);
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 0);
                        ctx.lineTo(width / 2, height);
                        ctx.stroke();
                        ctx.setLineDash([]); // reset

                        // Huge Digital Scores in Background
                        ctx.font = "bold " + Math.round(76 * sy) + "px " + root.monoFontFamily;
                        ctx.fillStyle = Qt.rgba(root.themeSubtext.r, root.themeSubtext.g, root.themeSubtext.b, 0.22);
                        ctx.textAlign = "center";
                        ctx.fillText(st.score1.toString(), width * 0.25, height * 0.42);
                        ctx.fillText(st.score2.toString(), width * 0.75, height * 0.42);

                        // Paddle 1 (Left)
                        var p1x = st.p1.x * sx;
                        var p1y = st.p1.y * sy;
                        var pw = st.paddleW * sx;
                        var ph = st.paddleH * sy;
                        var prad = pw * 0.4;

                        ctx.fillStyle = root.themeAccent;
                        ctx.beginPath();
                        ctx.roundRect ? ctx.roundRect(p1x, p1y, pw, ph, prad) : ctx.rect(p1x, p1y, pw, ph);
                        ctx.fill();

                        // Paddle 2 (Right)
                        var p2x = st.p2.x * sx;
                        var p2y = st.p2.y * sy;

                        ctx.fillStyle = root.themePaddle2;
                        ctx.beginPath();
                        ctx.roundRect ? ctx.roundRect(p2x, p2y, pw, ph, prad) : ctx.rect(p2x, p2y, pw, ph);
                        ctx.fill();

                        // Ball
                        var bx = st.ball.x * sx;
                        var by = st.ball.y * sy;
                        var br = st.ballRadius * Math.min(sx, sy);

                        // Ball soft glow
                        var bgrad = ctx.createRadialGradient(bx, by, br * 0.2, bx, by, br * 1.8);
                        bgrad.addColorStop(0, root.themeBall);
                        bgrad.addColorStop(1, "transparent");
                        ctx.fillStyle = bgrad;
                        ctx.beginPath();
                        ctx.arc(bx, by, br * 1.8, 0, 2 * Math.PI);
                        ctx.fill();

                        // Ball core
                        ctx.fillStyle = root.themeBall;
                        ctx.beginPath();
                        ctx.arc(bx, by, br, 0, 2 * Math.PI);
                        ctx.fill();
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
                        Text { text: "PAUSED"; font.family: root.monoFontFamily; font.bold: true; font.pixelSize: 26; color: "#ffffff"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Press Space or P to resume"; font.family: root.monoFontFamily; font.pixelSize: 13; color: "#94a3b8"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Game Over / Victory Overlay
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
                        Text {
                            text: (root.score1 > root.score2) ? (root.gameMode === "1P" ? "🎉 YOU WIN!" : "🏆 PLAYER 1 WINS!") : (root.gameMode === "1P" ? "💀 CPU WINS!" : "🏆 PLAYER 2 WINS!")
                            font.family: root.monoFontFamily
                            font.bold: true
                            font.pixelSize: 24
                            color: (root.score1 > root.score2) ? root.themeAccent : root.themePaddle2
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.score1 + "  —  " + root.score2
                            font.family: root.monoFontFamily
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
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
                                color: root.themeBtnFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startNewGame()
                            }
                        }
                        Text {
                            text: "Or press R / Space / Enter"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            color: "#94a3b8"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
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
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "🏓 How to Play VectorPong"; font.bold: true; font.pixelSize: 16; color: root.themeFg }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "✕"; font.pixelSize: 16; color: root.themeSubtext; MouseArea { anchors.fill: parent; onClicked: root.showHelp = false } }
                }

                Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                Grid {
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 16
                    Text { text: "Player 1 (Left):"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "W / S or Arrow Up / Down"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Player 2 (Right):"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Arrow Up / Down (in 2P mode)"; color: root.themeFg; font.pixelSize: 12 }
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
                    text: "First player to reach 11 points wins! Hitting the ball near the paddle edge gives high-angle deflection."
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

    // Sound Toast
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
        root.splashEnabled = false;
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
