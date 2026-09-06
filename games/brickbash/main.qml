import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "Themes.js" as OmarchyThemes
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 680
    minimumWidth: 360
    minimumHeight: 460
    title: "BrickBash"

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
    property color themeModalBg: "#1e1e2e"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    // Brick row palette
    property var brickColors: [
        "#f38ba8", // Red
        "#fab387", // Peach
        "#f9e2af", // Yellow
        "#a6e3a1", // Green
        "#89b4fa", // Blue
        "#cba6f7"  // Mauve
    ]

    // State
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"
    property int highScore: 0
    property string gameState: "ready"
    property int score: 0
    property int lives: 3

    color: themeBg
    Behavior on color { ColorAnimation { duration: 250 } }

    Component.onCompleted: {
        loadHighScore();
        Engine.init(1);
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

        brickColors = [
            data.color1 || "#f38ba8",
            data.color11 || data.color3 || "#fab387",
            data.color3 || "#f9e2af",
            data.color2 || "#a6e3a1",
            data.color4 || "#89b4fa",
            data.color5 || "#cba6f7"
        ];

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
        gameCanvas.requestPaint();
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

    function loadHighScore() {
        if (typeof settingsManager !== "undefined" && settingsManager !== null) {
            highScore = settingsManager.getHighScore();
        }
    }

    function updateHighScore() {
        if (Engine.score > highScore) {
            highScore = Engine.score;
            if (typeof settingsManager !== "undefined" && settingsManager !== null) {
                settingsManager.setHighScore(highScore);
            }
        }
    }

    function triggerGameOver() {
        Engine.gameState = "gameover";
        root.gameState = "gameover";
        gameCanvas.requestPaint();
    }

    function resetGame() {
        Engine.init(1);
        root.gameState = "ready";
        root.score = 0;
        root.lives = 3;
        gameCanvas.requestPaint();
        mainContainer.forceActiveFocus();
    }

    // 60 FPS Game Loop
    property real lastTime: 0
    Timer {
        id: loopTimer
        interval: 16
        repeat: true
        running: !splashEnabled
        onTriggered: {
            var now = Date.now();
            var dt = (lastTime === 0) ? 0.016 : Math.min(0.05, (now - lastTime) / 1000);
            lastTime = now;

            var events = Engine.update(dt);
            root.gameState = Engine.gameState;
            root.score = Engine.score;
            root.lives = Engine.lives;

            if (events && events.length > 0) {
                for (var i = 0; i < events.length; i++) {
                    var ev = events[i];
                    if (ev.type === "brick") playSound("brick");
                    else if (ev.type === "paddle") playSound("paddle");
                    else if (ev.type === "laser") playSound("laser");
                    else if (ev.type === "powerup") {
                        playSound("powerup");
                        soundToast.show("⭐ Power-Up Acquired!");
                    } else if (ev.type === "lose_life") {
                        playSound("lose_life");
                    } else if (ev.type === "cleared") {
                        playSound("powerup");
                        soundToast.show("🎉 LEVEL " + Engine.level + " CLEAR!");
                    } else if (ev.type === "gameover") {
                        updateHighScore();
                        soundToast.show("💀 GAME OVER");
                    }
                }
            }

            if (root.score > highScore) {
                updateHighScore();
            }
            gameCanvas.requestPaint();
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
            if (splashEnabled) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.gameState === "gameover" || Engine.gameState === "gameover") {
                if (event.key === Qt.Key_A || event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    resetGame();
                    soundToast.show("Restarted");
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
                resetGame();
                soundToast.show("Restarted");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_P) {
                if (Engine.gameState === "playing") {
                    Engine.gameState = "paused";
                    soundToast.show("⏸ Paused");
                } else if (Engine.gameState === "paused") {
                    Engine.gameState = "playing";
                }
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }

            // Paddle Movement Keys
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.paddle.vx = -Engine.paddle.speed;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.paddle.vx = Engine.paddle.speed;
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Up) {
                if (Engine.gameState === "ready") {
                    Engine.launchBall();
                } else if (Engine.paddle.hasLaser) {
                    var lRes = Engine.fireLaser();
                    if (lRes) playSound("laser");
                }
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H ||
                event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.paddle.vx = 0;
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
                    text: "BrickBash"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Level " + Engine.level + " • Lives: " + Engine.lives + (root.gameState === "gameover" ? " • Game Over" : (root.gameState === "levelcleared" ? " • Cleared!" : ""))
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
                            text: Engine.score.toString()
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
                    onClicked: root.resetGame()
                }
            }
        }

        // COURT PLAYING AREA
        Item {
            id: courtArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            property real courtScale: Math.min(width / Engine.COURT_W, height / Engine.COURT_H)
            property real drawW: Engine.COURT_W * courtScale
            property real drawH: Engine.COURT_H * courtScale

            Canvas {
                id: gameCanvas
                width: courtArea.drawW
                height: courtArea.drawH
                anchors.centerIn: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var scale = courtArea.courtScale;
                    ctx.save();
                    ctx.scale(scale, scale);

                    // Court background
                    ctx.fillStyle = root.themeBoardBg;
                    drawRoundRect(ctx, 0, 0, Engine.COURT_W, Engine.COURT_H, 16);
                    ctx.fill();

                    ctx.strokeStyle = root.themeBorder;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Bricks
                    for (var i = 0; i < Engine.bricks.length; i++) {
                        var b = Engine.bricks[i];
                        if (!b.active) continue;

                        var bColor = root.brickColors[b.colorIdx % root.brickColors.length];
                        ctx.fillStyle = bColor;
                        drawRoundRect(ctx, b.x, b.y, b.w, b.h, 4);
                        ctx.fill();

                        // Gloss highlight
                        ctx.fillStyle = "rgba(255, 255, 255, 0.22)";
                        ctx.beginPath();
                        ctx.rect(b.x + 2, b.y + 2, b.w - 4, b.h * 0.38);
                        ctx.fill();

                        // Border if armored
                        if (b.hits > 1) {
                            ctx.strokeStyle = "#ffffff";
                            ctx.lineWidth = 1.5;
                            ctx.stroke();
                        }
                    }

                    // Powerups
                    for (var p = 0; p < Engine.powerups.length; p++) {
                        var pup = Engine.powerups[p];
                        ctx.fillStyle = root.themeAccent;
                        drawRoundRect(ctx, pup.x, pup.y, pup.w, pup.h, pup.h / 2);
                        ctx.fill();

                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1;
                        ctx.stroke();

                        ctx.fillStyle = root.themeBg;
                        ctx.font = "bold 9px sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        var label = pup.type === "wide" ? "W" : (pup.type === "multiball" ? "M" : (pup.type === "laser" ? "L" : (pup.type === "slow" ? "S" : "+")));
                        ctx.fillText(label, pup.x + pup.w / 2, pup.y + pup.h / 2 + 1);
                    }

                    // Lasers
                    for (var l = 0; l < Engine.lasers.length; l++) {
                        var laz = Engine.lasers[l];
                        ctx.fillStyle = root.themePalette.color1 || "#f38ba8";
                        ctx.beginPath();
                        ctx.rect(laz.x - 2, laz.y - 10, 4, 12);
                        ctx.fill();

                        ctx.fillStyle = "#ffffff";
                        ctx.beginPath();
                        ctx.rect(laz.x - 1, laz.y - 8, 2, 8);
                        ctx.fill();
                    }

                    // Particles
                    for (var pt = 0; pt < Engine.particles.length; pt++) {
                        var part = Engine.particles[pt];
                        var pCol = root.brickColors[part.color % root.brickColors.length];
                        ctx.fillStyle = pCol;
                        ctx.globalAlpha = Math.max(0, part.life / part.maxLife);
                        ctx.beginPath();
                        ctx.arc(part.x, part.y, 2.5, 0, Math.PI * 2);
                        ctx.fill();
                    }
                    ctx.globalAlpha = 1.0;

                    // Paddle
                    var pad = Engine.paddle;
                    ctx.fillStyle = root.themeAccent;
                    drawRoundRect(ctx, pad.x, pad.y, pad.w, pad.h, pad.h / 2);
                    ctx.fill();

                    // Paddle highlight
                    ctx.fillStyle = "rgba(255, 255, 255, 0.4)";
                    ctx.beginPath();
                    ctx.rect(pad.x + 8, pad.y + 2, pad.w - 16, 3);
                    ctx.fill();

                    // Laser cannons if active
                    if (pad.hasLaser) {
                        ctx.fillStyle = root.themePalette.color1 || "#f38ba8";
                        ctx.fillRect(pad.x + 4, pad.y - 6, 6, 8);
                        ctx.fillRect(pad.x + pad.w - 10, pad.y - 6, 6, 8);
                    }

                    // Balls
                    for (var bIdx = 0; bIdx < Engine.balls.length; bIdx++) {
                        var ball = Engine.balls[bIdx];
                        ctx.fillStyle = "#ffffff";
                        ctx.beginPath();
                        ctx.arc(ball.x, ball.y, ball.r, 0, Math.PI * 2);
                        ctx.fill();

                        ctx.fillStyle = root.themeAccent;
                        ctx.beginPath();
                        ctx.arc(ball.x - 2, ball.y - 2, ball.r * 0.45, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    // Ready message
                    if (Engine.gameState === "ready") {
                        ctx.fillStyle = root.themeFg;
                        ctx.font = "bold 16px sans-serif";
                        ctx.textAlign = "center";
                        ctx.fillText("PRESS SPACE TO LAUNCH", Engine.COURT_W / 2, Engine.COURT_H / 2 + 30);
                    } else if (Engine.gameState === "paused") {
                        ctx.fillStyle = root.themeFg;
                        ctx.font = "bold 22px sans-serif";
                        ctx.textAlign = "center";
                        ctx.fillText("PAUSED", Engine.COURT_W / 2, Engine.COURT_H / 2);
                    }

                    ctx.restore();
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onPositionChanged: function(mouse) {
                        var scale = courtArea.courtScale;
                        var courtX = mouse.x / scale;
                        Engine.paddle.x = Math.max(10, Math.min(Engine.COURT_W - Engine.paddle.w - 10, courtX - Engine.paddle.w / 2));
                        if (Engine.gameState === "ready") {
                            for (var i = 0; i < Engine.balls.length; i++) {
                                if (Engine.balls[i].stuck) {
                                    Engine.balls[i].x = Engine.paddle.x + Engine.paddle.w / 2;
                                }
                            }
                        }
                    }

                    onClicked: {
                        if (Engine.gameState === "gameover" || root.gameState === "gameover") {
                            resetGame();
                            soundToast.show("Restarted");
                            return;
                        }
                        if (Engine.gameState === "ready") {
                            Engine.launchBall();
                        } else if (Engine.paddle.hasLaser) {
                            var lRes = Engine.fireLaser();
                            if (lRes) playSound("laser");
                        }
                    }
                }
            }

            // Game Over Overlay
            Rectangle {
                anchors.fill: gameCanvas
                color: Qt.rgba(0, 0, 0, 0.78)
                radius: 16
                visible: root.gameState === "gameover" || Engine.gameState === "gameover"
                z: 50

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        resetGame();
                        soundToast.show("Restarted");
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "GAME OVER"
                        font.family: root.monoFontFamily
                        font.pixelSize: 24
                        font.bold: true
                        color: root.themePalette.color1 || "#f38ba8"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Score: " + root.score + (root.highScore > 0 ? "  •  Best: " + root.highScore : "")
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
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeBg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                resetGame();
                                soundToast.show("Restarted");
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
                    text: "🧱 BrickBash Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Smash all bricks with the ball! Collect falling power-up capsules (Lasers, Wide paddle, Multi-ball, Slow-mo, Extra Life) to dominate."
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
                    Text { text: "Move Paddle (or Mouse)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Space / Return / Click"; font.bold: true; color: root.themePalette.color1 || "#f38ba8"; font.pixelSize: 12 }
                    Text { text: "Launch Ball / Fire Laser"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "P"; font.bold: true; color: root.themePalette.color2 || "#a6e3a1"; font.pixelSize: 12 }
                    Text { text: "Pause / Resume"; color: root.themeFg; font.pixelSize: 12 }

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
