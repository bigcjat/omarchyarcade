import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine
import "Themes.js" as OmarchyThemes

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
    property color themeModalBg: "#1e1e2e"
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: ""
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    color: themeBg
    Behavior on color { ColorAnimation { duration: 250 } }

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
        themePaddle2 = data.color3 || data.color11 || "#f9e2af";
        themeBall = data.color15 || data.foreground || "#ffffff";
        themeBorder = data.color8 || data.color0 || themeBorder;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeCourtBg = Qt.darker(bg, 1.08);
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.darker(themeFg, 1.4);
            themeModalBg = bg;
        } else {
            themeCourtBg = Qt.lighter(bg, 1.15);
            themeCardBg = Qt.lighter(bg, 1.25);
            themeSubtext = data.color7 || Qt.darker(themeFg, 1.3);
            themeModalBg = Qt.lighter(bg, 1.12);
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

    // Main Layout
    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header HUD
        Item {
            width: parent.width
            height: 38

            // Logo & Title
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "VectorPong"
                        font.family: root.monoFontFamily
                        font.bold: true
                        font.pixelSize: 15
                        color: root.themeAccent
                    }
                    Text {
                        text: root.gameMode === "1P" ? ("vs CPU • " + root.aiDifficulty) : "2-Player Local"
                        font.family: root.monoFontFamily
                        font.pixelSize: 10
                        color: root.themeSubtext
                    }
                }
            }

            // Mode, Diff, Restart, Mute, Help
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // Mode Button
                Rectangle {
                    width: 32
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.gameMode
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.themeAccent
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.cycleMode() }
                }

                // Difficulty Button (1P mode only)
                Rectangle {
                    width: 38
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    visible: root.gameMode === "1P"
                    Text {
                        anchors.centerIn: parent
                        text: root.aiDifficulty.substring(0, 3).toUpperCase()
                        font.pixelSize: 9
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.themePaddle2
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.cycleDifficulty() }
                }

                // Restart Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "↺"; font.bold: true; font.pixelSize: 13; color: root.themeFg }
                    MouseArea { anchors.fill: parent; onClicked: root.startNewGame() }
                }

                // Action Buttons
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; onClicked: root.toggleMute() }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.bold: true; color: root.themePalette.color1 || "#f38ba8"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: root.showHelp = !root.showHelp }
                }
            }
        }

        // Court Container
        Item {
            width: parent.width
            height: parent.height - y - 10

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
                        Text { text: "PAUSED"; font.family: root.monoFontFamily; font.bold: true; font.pixelSize: 26; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Press Space or P to resume"; font.family: root.monoFontFamily; font.pixelSize: 13; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
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
                            color: root.themeFg
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
                                color: root.themeBg
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
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
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
            height: 360
            radius: 12
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1
            anchors.centerIn: parent

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

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
                    Text { text: "Player 1 Move:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "W / S (or Up / Down in 1P mode)"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Player 2 Move (2P):"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Up / Down Arrow Keys"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Pause / Resume:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Space or P"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Restart:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "R"; color: root.themeFg; font.pixelSize: 12 }
                    Text { text: "Cycle Theme:"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "T (cycles all 22 Omarchy palettes)"; color: root.themeFg; font.pixelSize: 12 }
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
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : root.contentItem;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }
}
