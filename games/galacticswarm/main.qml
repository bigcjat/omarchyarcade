import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine
import "GalagaSprites.js" as Sprites

Window {
    id: root
    visible: true
    width: 620
    height: 740
    minimumWidth: 340
    minimumHeight: 460
    title: "GalacticSwarm"

    property color themeBg: "#181825"
    property color themeBoardBg: "#0c0c14"
    property color themeCellGrid: "#1e1e2e"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBorder: "#45475a"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property string helpText: "• Steer: A / D, ← / →, or Vim H / L\n• Rapid Twin Lasers: Space (Hold or tap)\n• Dual Fighter: Rescue your captured ship when a diving Boss is destroyed!\n• Stage Medals: Military ribbons in bottom-right reflect your campaign progress\n• Challenging Stages: Stages 3, 7, 11, 15... test your accuracy\n• Mute: M | Restart: R | Help: ?"

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    color: themeBg

    property int score: 0
    property int highScore: 0
    property int lives: 3
    property int stage: 1
    property string gameState: "playing"

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
        Engine.setSoundCallback(function(name) {
            root.playSound(name);
        });

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
        root.score = Engine.score;
        root.lives = Engine.lives;
        root.stage = Engine.stage;
        root.gameState = Engine.gameState;
        gameCanvas.requestPaint();
        soundToast.show("Fighters Deployed");
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

            if (Engine.gameState === "gameover") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_R || event.key === Qt.Key_A) {
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

            if (Engine.ship && Engine.gameState === "playing") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    Engine.ship.movingLeft = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    Engine.ship.movingRight = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    Engine.ship.firing = true;
                    Engine.fireBullet();
                    event.accepted = true;
                }
            }
        }

        Keys.onReleased: function(event) {
            if (Engine.ship) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    Engine.ship.movingLeft = false;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    Engine.ship.movingRight = false;
                } else if (event.key === Qt.Key_Space) {
                    Engine.ship.firing = false;
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
                anchors.right: scoreRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "GalacticSwarm"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (Engine.isChallengingStage ? "CHALLENGING STAGE • Stage " + root.stage : "Stage " + root.stage) + (Engine.ship && Engine.ship.isDual ? " • ⚔ DUAL FIGHTER" : " • Lives: " + root.lives)
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: Engine.ship && Engine.ship.isDual ? "#F9E2AF" : root.themeSubtext
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
                    onClicked: root.startNewGame()
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
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

                onWidthChanged: {
                    if (width > 50 && height > 50) Engine.init(width, height);
                }
                onHeightChanged: {
                    if (width > 50 && height > 50) Engine.init(width, height);
                }

                Canvas {
                    id: gameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.fillStyle = root.themeBoardBg;
                        ctx.fillRect(0, 0, width, height);

                        var pixelScale = 2.0;

                        // 1. Draw Starfield
                        for (var s = 0; s < Engine.stars.length; s++) {
                            var star = Engine.stars[s];
                            var alpha = 0.4 + 0.6 * Math.abs(Math.sin(star.twinkle));
                            ctx.globalAlpha = alpha;
                            ctx.fillStyle = star.color;
                            if (Engine.isWarping) {
                                ctx.fillRect(star.x, star.y, star.size, star.size * 14);
                            } else {
                                ctx.fillRect(star.x, star.y, star.size, star.size);
                            }
                        }
                        ctx.globalAlpha = 1.0;

                        // 2. Draw Pixelated Stepped Tractor Beam
                        if (Engine.activeTractor) {
                            var tb = Engine.activeTractor;
                            var beamSteps = 20;
                            var stepHeight = tb.length / beamSteps;

                            for (var st = 0; st < beamSteps; st++) {
                                var rel = st / beamSteps;
                                var stepW = tb.widthTop + (tb.widthBottom - tb.widthTop) * rel;
                                var stepY = tb.y + st * stepHeight;

                                var waveOffset = Math.sin(tb.pulse + st * 0.8) * 5;
                                var isAlt = ((Math.floor(tb.pulse * 1.6 + st * 0.8)) % 2 === 0);
                                ctx.fillStyle = isAlt ? "#00FFFF" : "#0066FF";
                                ctx.globalAlpha = 0.55 + 0.35 * Math.sin(tb.pulse + st * 0.5);
                                ctx.fillRect(tb.x - stepW / 2 + waveOffset, stepY, stepW, 4);
                            }
                            ctx.globalAlpha = 1.0;
                        }

                        // 3. Draw Authentic Player Twin Missiles
                        for (var b = 0; b < Engine.bullets.length; b++) {
                            var bul = Engine.bullets[b];
                            ctx.fillStyle = "#FFFF00";
                            ctx.fillRect(bul.x - 1, bul.y, 3, 3);
                            ctx.fillStyle = "#E70000";
                            ctx.fillRect(bul.x - 1, bul.y + 3, 3, bul.height - 3);
                        }

                        // 4. Draw Alien Bullets
                        for (var ab = 0; ab < Engine.alienBullets.length; ab++) {
                            var abul = Engine.alienBullets[ab];
                            ctx.fillStyle = "#FFFF00";
                            ctx.fillRect(abul.x - 1.5, abul.y, 3, 4);
                            ctx.fillStyle = "#E70000";
                            ctx.fillRect(abul.x - 1.5, abul.y + 4, 3, 4);
                        }

                        // 5. Draw Enemies with Authentic Pixel Art
                        for (var e = 0; e < Engine.enemies.length; e++) {
                            var en = Engine.enemies[e];
                            if (en.hp <= 0) continue;

                            var wingFrame = Math.floor(en.wingFlutter) % 2;
                            var spriteName = "";
                            var drawAngle = 0;

                            if (en.state === "diving" || en.state === "challenging_fly") {
                                drawAngle = en.angle - Math.PI / 2;
                            }

                            if (en.type === "boss") {
                                var prefix = (en.hp === 1) ? "boss_hit_" : "boss_";
                                spriteName = prefix + wingFrame;
                                Sprites.drawPixelSprite(ctx, spriteName, en.x, en.y, pixelScale, drawAngle);

                                if (en.capturedShip) {
                                    var capDist = 20;
                                    var capX = en.x - Math.sin(drawAngle) * capDist;
                                    var capY = en.y - Math.cos(drawAngle) * capDist;
                                    Sprites.drawPixelSprite(ctx, "fighter_captured", capX, capY, pixelScale, drawAngle + Math.PI);
                                }
                            } else if (en.type === "butterfly") {
                                spriteName = "butterfly_" + wingFrame;
                                Sprites.drawPixelSprite(ctx, spriteName, en.x, en.y, pixelScale, drawAngle);
                            } else {
                                spriteName = "bee_" + wingFrame;
                                Sprites.drawPixelSprite(ctx, spriteName, en.x, en.y, pixelScale, drawAngle);
                            }
                        }

                        // 6. Draw Hostile Rogue Captive Ships
                        for (var rs = 0; rs < Engine.rogueShips.length; rs++) {
                            var rog = Engine.rogueShips[rs];
                            Sprites.drawPixelSprite(ctx, "fighter_captured", rog.x, rog.y, pixelScale, Math.PI);
                        }

                        // 7. Draw Rescued Ship Docking
                        if (Engine.rescuedShip) {
                            Sprites.drawPixelSprite(ctx, "fighter", Engine.rescuedShip.x, Engine.rescuedShip.y, pixelScale, 0);
                        }

                        // 7b. Draw Abducting Ship (split off from dual fighter)
                        if (Engine.abductingShip) {
                            Sprites.drawPixelSprite(ctx, "fighter_captured", Engine.abductingShip.x, Engine.abductingShip.y, pixelScale, Engine.abductingShip.spinAngle || 0);
                        }

                        // 8. Draw Player Fighter
                        if (Engine.gameState !== "gameover") {
                            var blink = (Engine.ship.invincibleTimer > 0 && (Math.floor(Engine.ship.invincibleTimer * 12) % 2 === 0));
                            if (!blink) {
                                if (Engine.ship.captured) {
                                    Sprites.drawPixelSprite(ctx, "fighter_captured", Engine.ship.x, Engine.ship.y, pixelScale, Engine.ship.spinAngle || 0);
                                } else if (Engine.ship.isDual) {
                                    Sprites.drawPixelSprite(ctx, "fighter_dual", Engine.ship.x, Engine.ship.y, pixelScale, 0);
                                } else {
                                    Sprites.drawPixelSprite(ctx, "fighter", Engine.ship.x, Engine.ship.y, pixelScale, 0);
                                }
                            }
                        }

                        // 9. Draw 4-Frame Authentic Pixel Explosions
                        for (var ex = 0; ex < Engine.explosions.length; ex++) {
                            var exp = Engine.explosions[ex];
                            Sprites.drawPixelSprite(ctx, "exp_" + exp.frame, exp.x, exp.y, pixelScale * 1.5, 0);
                        }

                        // 10. Authentic Bottom HUD: Reserve Life Icons (Bottom-Left)
                        var reserveLives = Math.max(0, Engine.lives - 1);
                        var lifeIconX = 16;
                        var hudBottomY = height - 14;
                        for (var l = 0; l < reserveLives && l < 6; l++) {
                            Sprites.drawPixelSprite(ctx, "life_icon", lifeIconX + l * 18, hudBottomY, 1.4, 0);
                        }

                        // 11. Authentic Bottom HUD: Stage Badges & Medals (Bottom-Right)
                        drawStageMedals(ctx, Engine.stage, width - 20, hudBottomY);
                    }

                    function drawStageMedals(ctx, stg, rightX, yPos) {
                        var curX = rightX;
                        var rem = stg;

                        // 50s
                        while (rem >= 50 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_50", curX, yPos, 1.3, 0);
                            curX -= 22;
                            rem -= 50;
                        }
                        // 30s
                        while (rem >= 30 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_30", curX, yPos, 1.3, 0);
                            curX -= 20;
                            rem -= 30;
                        }
                        // 20s
                        while (rem >= 20 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_20", curX, yPos, 1.3, 0);
                            curX -= 20;
                            rem -= 20;
                        }
                        // 10s
                        while (rem >= 10 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_10", curX, yPos, 1.3, 0);
                            curX -= 18;
                            rem -= 10;
                        }
                        // 5s
                        while (rem >= 5 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_5", curX, yPos, 1.3, 0);
                            curX -= 16;
                            rem -= 5;
                        }
                        // 1s
                        while (rem >= 1 && curX > 160) {
                            Sprites.drawPixelSprite(ctx, "badge_1", curX, yPos, 1.3, 0);
                            curX -= 14;
                            rem -= 1;
                        }
                    }
                }

                // Stage Warp & Clear Overlay
                Item {
                    anchors.fill: parent
                    visible: Engine.isWarping

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Engine.isChallengingStage ? ("CHALLENGING STAGE: " + Engine.challengingHits + " / 40 HITS") : ("★ STAGE " + root.stage + " CLEARED ★")
                            font.family: root.monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: "#F9E2AF"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Engine.isChallengingStage ? (Engine.challengingHits === 40 ? "PERFECT 10,000 PTS BONUS!" : ("BONUS: " + (Engine.challengingHits * 100) + " PTS")) : ("WARPING TO STAGE " + (root.stage + 1))
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: "#89B4FA"
                        }
                    }
                }

                // Authentic Namco 1981 End-of-Game "- RESULTS -" Screen
                Rectangle {
                    anchors.fill: parent
                    color: "#e60c0c14"
                    visible: root.gameState === "gameover"

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        width: Math.min(parent.width * 0.9, 360)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "- RESULTS -"
                            font.family: root.monoFontFamily
                            font.pixelSize: 22
                            font.bold: true
                            color: "#F38BA8"
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#45475a"
                        }

                        // Shots Fired
                        Row {
                            width: parent.width
                            Text {
                                text: "SHOTS FIRED"
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#F9E2AF"
                            }
                            Item { width: parent.width - 200; height: 1 }
                            Text {
                                text: Engine.shotsFired.toString()
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }

                        // Number of Hits
                        Row {
                            width: parent.width
                            Text {
                                text: "NUMBER OF HITS"
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#89B4FA"
                            }
                            Item { width: parent.width - 200; height: 1 }
                            Text {
                                text: Engine.shotsHit.toString()
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }

                        // Hit-Miss Ratio
                        Row {
                            width: parent.width
                            Text {
                                text: "HIT-MISS RATIO"
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#A6E3A1"
                            }
                            Item { width: parent.width - 200; height: 1 }
                            Text {
                                text: Engine.hitMissRatio + " %"
                                font.family: root.monoFontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: "#A6E3A1"
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#45475a"
                        }

                        // Final Score
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCORE: " + root.score + "  •  BEST: " + root.highScore
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeFg
                        }

                        // Restart Button
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 150
                            height: 36
                            radius: 6
                            color: root.themeCardBg
                            border.color: root.themeAccent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "PLAY AGAIN (SPACE)"
                                font.family: root.monoFontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeAccent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startNewGame()
                            }
                        }
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
                root.score = Engine.score;
                root.highScore = Engine.highScore;
                root.lives = Engine.lives;
                root.stage = Engine.stage;
                root.gameState = Engine.gameState;

                if (typeof settingsManager !== "undefined" && settingsManager && root.score > settingsManager.getBestScore()) {
                    settingsManager.setBestScore(root.score);
                }

                gameCanvas.requestPaint();
            }
        }

        // Help Modal Overlay
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
                            text: "Galactic Swarm Manual"
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
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
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
