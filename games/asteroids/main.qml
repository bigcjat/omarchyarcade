import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 620
    height: 700
    minimumWidth: 320
    minimumHeight: 460
    title: "VectorDrift"

    property color themeBg: "#181825"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#252538"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBorder: "#45475a"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Steer: A / D, ← / →, or Vim H / L\n• Thrusters: W or ↑ or Vim K\n• Lasers: Space\n• Hyperspace: Shift, S, or ↓\n• Mute: M | Restart: R | Help: ?\n• Blast asteroids and dodge fragments!"

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    color: themeBg

    property string gameState: "ready" // "ready", "playing", "gameover"
    property int score: 0
    property int highScore: 0
    property int lives: 3
    property int level: 1

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) themeBg = data.bg;
        if (data.fg) themeFg = data.fg;
        if (data.accent) themeAccent = data.accent;
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
        gameCanvas.requestPaint();
    }

    function playSound(name) {
        if (!isMuted) {
            if (typeof soundManager !== "undefined" && soundManager) {
                soundManager.playSound(name);
            } else if (typeof audioController !== "undefined" && audioController) {
                audioController.playSound(name);
            }
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted) {
            playSound("shoot");
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.highScore = settingsManager.getBestScore();
        }
        if (boardContainer.width > 50 && boardContainer.height > 50) {
            Engine.init(boardContainer.width, boardContainer.height);
        }
        startNewGame();
    }

    function startNewGame() {
        if (boardContainer.width > 50 && boardContainer.height > 50) {
            Engine.init(boardContainer.width, boardContainer.height);
        } else {
            Engine.resetGame();
        }
        root.gameState = "playing";
        root.score = Engine.score;
        root.lives = Engine.lives;
        root.level = Engine.level;
        gameCanvas.requestPaint();
        soundToast.show("Battle Stations");
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

            if (root.gameState === "gameover") {
                if (event.key === Qt.Key_A || event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.startNewGame();
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
                startNewGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }

            if (Engine.ship && root.gameState === "playing") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    Engine.ship.rotLeft = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    Engine.ship.rotRight = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                    Engine.ship.thrusting = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    if (Engine.fireBullet()) {
                        root.playSound("shoot");
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Shift || event.key === Qt.Key_Down || event.key === Qt.Key_S) {
                    Engine.hyperspace({
                        onSound: function(snd) { root.playSound(snd); }
                    });
                    event.accepted = true;
                }
            }
        }

        Keys.onReleased: function(event) {
            if (Engine.ship) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    Engine.ship.rotLeft = false;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    Engine.ship.rotRight = false;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                    Engine.ship.thrusting = false;
                }
            }
        }

        // TOP HEADER HUD
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 38

            Row {
                id: leftHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "VectorDrift"
                        font.family: root.monoFontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeAccent
                    }
                    Text {
                        text: "Wave " + root.level + " • " + (root.lives > 0 ? ("♥ ").repeat(root.lives).trim() : "GAMEOVER")
                        font.pixelSize: 10
                        font.family: root.monoFontFamily
                        color: root.lives > 1 ? root.themeSubtext : "#FF5555"
                    }
                }
            }

            Row {
                id: rightHeader
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // Score pill
                Rectangle {
                    width: Math.max(48, scoreVal.implicitWidth + 14)
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        Text { text: "SCORE"; font.pixelSize: 7; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { id: scoreVal; text: root.score.toString(); font.pixelSize: 11; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Best pill
                Rectangle {
                    width: Math.max(48, bestVal.implicitWidth + 14)
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        Text { text: "BEST"; font.pixelSize: 7; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { id: bestVal; text: root.highScore.toString(); font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Restart button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: restartArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "↺"; font.bold: true; font.pixelSize: 13; color: root.themeFg }
                    MouseArea {
                        id: restartArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame()
                    }
                }

                // Mute button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: muteArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Help button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: helpArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.bold: true; font.pixelSize: 12; color: root.themeAccent }
                    MouseArea {
                        id: helpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playArea
            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12

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

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        // Authentic phosphor beam vector glow
                        ctx.shadowColor = root.themeAccent;
                        ctx.shadowBlur = 4;

                        // Draw particles
                        for (var p = 0; p < Engine.particles.length; p++) {
                            var pt = Engine.particles[p];
                            var alpha = pt.life / pt.maxLife;
                            ctx.fillStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, alpha);
                            ctx.fillRect(pt.x - 1.5, pt.y - 1.5, 3, 3);
                        }

                        // Draw player bullets
                        ctx.fillStyle = root.themeFg;
                        for (var b = 0; b < Engine.bullets.length; b++) {
                            var bu = Engine.bullets[b];
                            ctx.beginPath();
                            ctx.arc(bu.x, bu.y, 2.5, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // Draw enemy / saucer bullets (high intensity amber/red)
                        ctx.fillStyle = "#FF5555";
                        for (var eb = 0; eb < Engine.enemyBullets.length; eb++) {
                            var ebu = Engine.enemyBullets[eb];
                            ctx.beginPath();
                            ctx.arc(ebu.x, ebu.y, 2.8, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // Draw Flying Saucer (Classic Atari vector UFO)
                        if (Engine.saucer) {
                            ctx.save();
                            ctx.translate(Engine.saucer.x, Engine.saucer.y);
                            ctx.strokeStyle = Engine.saucer.isSmall ? "#FF5577" : root.themeAccent;
                            ctx.lineWidth = 2.0;
                            var sr = Engine.saucer.radius;
                            ctx.beginPath();
                            // Bottom hull
                            ctx.moveTo(-sr, 0);
                            ctx.lineTo(sr, 0);
                            ctx.lineTo(sr * 0.6, sr * 0.45);
                            ctx.lineTo(-sr * 0.6, sr * 0.45);
                            ctx.closePath();
                            // Middle waistline
                            ctx.moveTo(-sr, 0);
                            ctx.lineTo(-sr * 0.5, -sr * 0.45);
                            ctx.lineTo(sr * 0.5, -sr * 0.45);
                            ctx.lineTo(sr, 0);
                            // Top dome
                            ctx.moveTo(-sr * 0.28, -sr * 0.45);
                            ctx.lineTo(-sr * 0.14, -sr * 0.85);
                            ctx.lineTo(sr * 0.14, -sr * 0.85);
                            ctx.lineTo(sr * 0.28, -sr * 0.45);
                            ctx.stroke();
                            ctx.restore();
                        }

                        // Draw asteroids (geometric procedural wireframes)
                        ctx.strokeStyle = root.themeSubtext;
                        ctx.lineWidth = 1.8;
                        for (var a = 0; a < Engine.asteroids.length; a++) {
                            var ast = Engine.asteroids[a];
                            ctx.save();
                            ctx.translate(ast.x, ast.y);
                            ctx.rotate(ast.rot);
                            ctx.beginPath();
                            var count = ast.numVerts;
                            for (var i = 0; i < count; i++) {
                                var ang = (i / count) * Math.PI * 2;
                                var rad = ast.radius * ast.offsets[i];
                                var vx = Math.cos(ang) * rad;
                                var vy = Math.sin(ang) * rad;
                                if (i === 0) ctx.moveTo(vx, vy);
                                else ctx.lineTo(vx, vy);
                            }
                            ctx.closePath();
                            ctx.stroke();
                            ctx.restore();
                        }

                        // Safe-center respawn reticle
                        if (Engine.respawnPending) {
                            var cx = width / 2;
                            var cy = height / 2;
                            ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.4);
                            ctx.lineWidth = 1.0;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 26, 0, Math.PI * 2);
                            ctx.moveTo(cx - 36, cy); ctx.lineTo(cx + 36, cy);
                            ctx.moveTo(cx, cy - 36); ctx.lineTo(cx, cy + 36);
                            ctx.stroke();
                        }

                        // Draw ship (vector wireframe with invulnerability strobe)
                        if (Engine.ship && (Engine.invulnerableTimer <= 0 || Math.floor(Engine.invulnerableTimer / 8) % 2 === 0)) {
                            ctx.save();
                            ctx.translate(Engine.ship.x, Engine.ship.y);
                            ctx.rotate(Engine.ship.angle);
                            ctx.strokeStyle = root.themeAccent;
                            ctx.lineWidth = 2.0;

                            ctx.beginPath();
                            ctx.moveTo(Engine.ship.radius + 2, 0);
                            ctx.lineTo(-Engine.ship.radius, -Engine.ship.radius * 0.75);
                            ctx.lineTo(-Engine.ship.radius * 0.5, 0);
                            ctx.lineTo(-Engine.ship.radius, Engine.ship.radius * 0.75);
                            ctx.closePath();
                            ctx.stroke();

                            if (Engine.ship.thrusting) {
                                ctx.strokeStyle = "#FF8800";
                                ctx.beginPath();
                                ctx.moveTo(-Engine.ship.radius * 0.5, -3);
                                ctx.lineTo(-Engine.ship.radius - 8, 0);
                                ctx.lineTo(-Engine.ship.radius * 0.5, 3);
                                ctx.stroke();
                            }
                            ctx.restore();
                        }
                    }
                }

                // Heartbeat tension audio generator
                Timer {
                    id: heartbeatTimer
                    property bool beatToggle: false
                    interval: 1000
                    repeat: true
                    running: !root.splashEnabled && !root.showHelp && root.gameState === "playing"
                    onTriggered: {
                        beatToggle = !beatToggle;
                        root.playSound(beatToggle ? "beat1" : "beat2");
                        interval = Engine.getHeartbeatInterval();
                    }
                }

                Timer {
                    id: loopTimer
                    interval: 16
                    repeat: true
                    running: !root.splashEnabled && !root.showHelp
                    onTriggered: {
                        Engine.update({
                            onScoreChanged: function(s) {
                                root.score = s;
                                if (s > root.highScore) {
                                    root.highScore = s;
                                    if (typeof settingsManager !== "undefined" && settingsManager) {
                                        settingsManager.setBestScore(root.highScore);
                                    }
                                }
                            },
                            onLivesChanged: function(l) {
                                if (l > root.lives) {
                                    soundToast.show("⭐ EXTRA SHIP AWARDED! (Lives: " + l + ")");
                                }
                                root.lives = l;
                            },
                            onLevelChanged: function(lv) {
                                root.level = lv;
                                soundToast.show("SECTOR " + lv + " REACHED");
                            },
                            onGameOver: function(s) { root.gameState = "gameover"; },
                            onSound: function(snd) { root.playSound(snd); }
                        });
                        root.gameState = Engine.gameState;
                        root.score = Engine.score;
                        root.lives = Engine.lives;
                        gameCanvas.requestPaint();
                    }
                }

                onWidthChanged: {
                    if (width > 50 && height > 50) {
                        Engine.resize(width, height);
                    }
                }
                onHeightChanged: {
                    if (width > 50 && height > 50) {
                        Engine.resize(width, height);
                    }
                }
            }

            // STANDARDIZED GAME OVER OVERLAY
            Rectangle {
                id: gameOverOverlay
                anchors.fill: boardContainer
                color: Qt.rgba(0, 0, 0, 0.78)
                visible: root.gameState === "gameover"
                z: 50
                radius: 12

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNewGame()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: "GAME OVER"
                        color: "#FF5555"
                        font.pixelSize: 28
                        font.bold: true
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Score: " + root.score
                        color: root.themeFg
                        font.pixelSize: 18
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 140
                        height: 42
                        radius: 8
                        color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "PLAY AGAIN"
                            color: root.themeBg
                            font.bold: true
                            font.pixelSize: 13
                            font.family: root.monoFontFamily
                        }

                        MouseArea {
                            id: playAgainMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startNewGame()
                        }
                    }

                    Text {
                        text: "Or press R / Space / Enter"
                        color: root.themeSubtext
                        font.pixelSize: 11
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // AUDIO NOTIFICATION TOAST
    Rectangle {
        id: soundToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 24
        height: 32
        radius: 16
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        opacity: 0
        z: 200

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.family: root.monoFontFamily
            font.pixelSize: 11
            color: root.themeFg
        }

        Timer {
            id: toastTimer
            interval: 1200
            onTriggered: soundToast.opacity = 0
        }

        function show(msg) {
            toastText.text = msg;
            soundToast.opacity = 0.95;
            toastTimer.restart();
        }
    }

    // HOW TO PLAY MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: root.showHelp
        z: 90

        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Rectangle {
            width: Math.min(parent.width - 40, 360)
            height: helpCol.implicitHeight + 36
            anchors.centerIn: parent
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                id: helpCol
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 12

                Text {
                    text: "HOW TO PLAY"
                    font.family: root.monoFontFamily
                    font.bold: true
                    font.pixelSize: 15
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.family: root.monoFontFamily
                    font.pixelSize: 11
                    color: root.themeFg
                    lineHeight: 1.3
                    text: root.helpText
                }

                Rectangle {
                    width: 100
                    height: 32
                    radius: 6
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "GOT IT"
                        font.family: root.monoFontFamily
                        font.bold: true
                        font.pixelSize: 11
                        color: root.themeBg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = false
                    }
                }
            }
        }
    }

    // CANONICAL RETRO OMARCHY ARCADE SPLASH SCREEN
    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }
}
