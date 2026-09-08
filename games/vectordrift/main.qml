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
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool fullPlayfield: false
    readonly property bool isTiledDesktopMode: fullPlayfield || root.height < 520 || root.width < 440
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property string helpText: "• Steer: A / D, ← / →, or Vim H / L\n• Thrusters: W or ↑ or Vim K\n• Lasers: Space\n• Hyperspace: Shift, S, or ↓\n• Full/Compact View: Shift+F
• Mute: M | Restart: R | Help: ?\n• Blast asteroids and dodge fragments!"

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
    property bool respawnPending: false
    property int respawnCountdown: 0

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

    function destroyShipForTest() {
        Engine.destroyShip({
            onLivesChanged: function(l) { root.lives = l; },
            onGameOver: function(s) { root.gameState = "gameover"; },
            onSound: function(snd) { root.playSound(snd); }
        });
    }

    signal screenshotSaved(string path)

    function captureScreenshot(filePath, shouldQuit) {
        if (splashScreen) {
            splashScreen.visible = false;
            splashScreen.opacity = 0;
        }
        root.splashEnabled = false;
        var targetItem = mainContainer;
        targetItem.grabToImage(function(result) {
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

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
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
                    text: "VectorDrift"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Wave " + root.level + " • Lives: " + root.lives + (root.gameState === "gameover" ? " • Game Over" : (root.gameState === "ready" ? " • Press Space to Launch" : ""))
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
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCORE"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.highScore.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.highScore > 0 ? root.themeAccent : root.themeSubtext
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
                color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
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

            // Mute button in Center
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

            // Primary Action Button (Restart)
                            // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: root.fullPlayfield ? root.themeCardBg : (viewModeMouse.containsMouse ? root.themeCardBg : root.themeBoardBg)
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
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
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: subheaderItem.isCrowded
                    }
                    Text {
                        text: "Restart (R)"
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

        // PLAYFIELD CONTAINER
        Item {
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
                    text: "⚡ VectorDrift"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + ("SCORE: " + root.score)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("BEST: " + root.highScore) + ")"
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
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

        id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
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
                            var pulse = 0.5 + 0.5 * Math.sin(Engine.respawnTimer * 0.14);
                            ctx.save();
                            ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.35 + 0.35 * pulse);
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 38 + 6 * pulse, 0, Math.PI * 2);
                            ctx.stroke();

                            ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.5);
                            ctx.lineWidth = 1.2;
                            ctx.beginPath();
                            ctx.moveTo(cx - 56, cy); ctx.lineTo(cx - 24, cy);
                            ctx.moveTo(cx + 24, cy); ctx.lineTo(cx + 56, cy);
                            ctx.moveTo(cx, cy - 56); ctx.lineTo(cx, cy - 24);
                            ctx.moveTo(cx, cy + 24); ctx.lineTo(cx, cy + 56);
                            ctx.stroke();
                            ctx.restore();
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
                        root.respawnPending = Engine.respawnPending;
                        root.respawnCountdown = Engine.respawnCountdown;
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

            // RESPAWN COUNTDOWN OVERLAY
            Item {
                id: respawnCountdownOverlay
                anchors.centerIn: boardContainer
                visible: root.respawnPending && root.gameState === "playing"
                z: 25

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.respawnCountdown > 0 ? root.respawnCountdown.toString() : "3"
                        font.family: root.monoFontFamily
                        font.pixelSize: 46
                        font.bold: true
                        color: root.themeAccent
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: respawnLabel.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.6)
                        border.color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.4)
                        border.width: 1

                        Text {
                            id: respawnLabel
                            anchors.centerIn: parent
                            text: "RESPAWN IN " + (root.respawnCountdown > 0 ? root.respawnCountdown : "3")
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                        }
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

    // CANONICAL RETRO OMARCHY ARCADE SPLASH SCREEN
    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }
}
