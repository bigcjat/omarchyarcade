import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 700
    minimumWidth: 320
    minimumHeight: 460
    title: "CyberHop"

    property color themeBg: "#181825"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#252538"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#a6e3a1" // Frog Green
    property color themeBorder: "#45475a"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property string helpText: "• Hop Forward: ↑, W, Space, or Vim K\n• Steer Left/Right: ← / →, A / D, or H / L\n• Hop Back: ↓, S, or Vim J\n• Dodge traffic & high-speed bullet trains\n• Ride floating logs across rivers\n• Full/Compact View: Shift+F\n• Sound: M | Restart: R | Help: ?\n• Keep moving—don't let the eagle catch you!"

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
            playSound("hop");
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
        gameCanvas.requestPaint();
        soundToast.show("Hop Forward!");
    }

    function doHop(dc, dr) {
        if (root.gameState === "gameover") {
            root.startNewGame();
            return;
        }
        Engine.hop(dc, dr, {
            onSound: function(snd) { root.playSound(snd); },
            onScoreChanged: function(s) {
                root.score = s;
                if (s > root.highScore) {
                    root.highScore = s;
                    if (typeof settingsManager !== "undefined" && settingsManager) {
                        settingsManager.setBestScore(root.highScore);
                    }
                }
            }
        });
        root.gameState = Engine.gameState;
        root.score = Engine.score;
        gameCanvas.requestPaint();
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

            // Directional hopping
            if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K || event.key === Qt.Key_Space) {
                root.doHop(0, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.doHop(0, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                root.doHop(-1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                root.doHop(1, 0);
                event.accepted = true;
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
                    text: "CyberHop"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.gameState === "gameover" ? "Game Over • Press R to Restart" : (root.gameState === "ready" ? "Press Space to Hop Forward" : "Cross Traffic & Rivers!"))
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
                    text: "🐸 CyberHop"
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

                    function drawRoundRect(ctx, x, y, w, h, r) {
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

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cX = width / 2;
                        var gs = Engine.GRID_SIZE;

                        // 1. Draw Lanes
                        for (var i = 0; i < Engine.lanes.length; i++) {
                            var lane = Engine.lanes[i];
                            var sy = height - (lane.row * gs - Engine.cameraY);

                            if (sy < -gs * 2 || sy > height + gs * 2) continue;

                            if (lane.type === "grass") {
                                // Grass terrain
                                ctx.fillStyle = (lane.row % 2 === 0) ? "#2b4a36" : "#243e2d";
                                ctx.fillRect(0, sy - gs, width, gs);

                                // Trees & Boulders
                                if (lane.trees) {
                                    for (var ti = 0; ti < lane.trees.length; ti++) {
                                        var tx = cX + lane.trees[ti] * gs;
                                        ctx.fillStyle = "#1e3325";
                                        drawRoundRect(ctx, tx - 15, sy - gs + 6, 30, 30, 6);
                                        ctx.fill();
                                        ctx.fillStyle = "#2d5438";
                                        drawRoundRect(ctx, tx - 12, sy - gs + 8, 24, 24, 5);
                                        ctx.fill();
                                    }
                                }
                            } else if (lane.type === "road") {
                                // Road asphalt
                                ctx.fillStyle = "#1f2029";
                                ctx.fillRect(0, sy - gs, width, gs);

                                // Dashed center lane markings
                                ctx.fillStyle = Qt.rgba(root.themeSubtext.r, root.themeSubtext.g, root.themeSubtext.b, 0.25);
                                for (var mx = 0; mx < width; mx += 36) {
                                    ctx.fillRect(mx, sy - 2, 18, 2);
                                }

                                // Vehicles
                                for (var vi = 0; vi < lane.items.length; vi++) {
                                    var veh = lane.items[vi];
                                    var vx = cX + veh.x;
                                    var vy = sy - gs + 6;
                                    var vh = gs - 12;

                                    ctx.save();
                                    // Vehicle shadow
                                    ctx.fillStyle = "rgba(0, 0, 0, 0.35)";
                                    drawRoundRect(ctx, vx - veh.len / 2 + 3, vy + 4, veh.len, vh, 6);
                                    ctx.fill();

                                    // Vehicle body
                                    if (veh.vehicleType === "truck") {
                                        ctx.fillStyle = root.themeSubtext;
                                        drawRoundRect(ctx, vx - veh.len / 2, vy, veh.len, vh, 5);
                                        ctx.fill();
                                        // Cab
                                        ctx.fillStyle = root.themeAccent;
                                        var cabX = veh.dir > 0 ? (vx + veh.len / 2 - 20) : (vx - veh.len / 2);
                                        drawRoundRect(ctx, cabX, vy + 2, 20, vh - 4, 4);
                                        ctx.fill();
                                    } else if (veh.vehicleType === "racecar") {
                                        ctx.fillStyle = "#FF5555";
                                        drawRoundRect(ctx, vx - veh.len / 2, vy + 2, veh.len, vh - 4, 7);
                                        ctx.fill();
                                        // Spoiler
                                        ctx.fillStyle = "#FFFFFF";
                                        var spX = veh.dir > 0 ? (vx - veh.len / 2) : (vx + veh.len / 2 - 6);
                                        ctx.fillRect(spX, vy, 6, vh);
                                    } else {
                                        // Standard sedan
                                        ctx.fillStyle = root.themeAccent;
                                        drawRoundRect(ctx, vx - veh.len / 2, vy + 1, veh.len, vh - 2, 6);
                                        ctx.fill();
                                        // Windshield
                                        ctx.fillStyle = "#11111b";
                                        drawRoundRect(ctx, vx - 8, vy + 3, 16, vh - 6, 3);
                                        ctx.fill();
                                    }

                                    // Headlights beam
                                    ctx.fillStyle = "rgba(255, 235, 150, 0.2)";
                                    ctx.beginPath();
                                    if (veh.dir > 0) {
                                        ctx.moveTo(vx + veh.len / 2, vy + 4);
                                        ctx.lineTo(vx + veh.len / 2 + 50, vy - 10);
                                        ctx.lineTo(vx + veh.len / 2 + 50, vy + vh + 10);
                                        ctx.lineTo(vx + veh.len / 2, vy + vh - 4);
                                    } else {
                                        ctx.moveTo(vx - veh.len / 2, vy + 4);
                                        ctx.lineTo(vx - veh.len / 2 - 50, vy - 10);
                                        ctx.lineTo(vx - veh.len / 2 - 50, vy + vh + 10);
                                        ctx.lineTo(vx - veh.len / 2, vy + vh - 4);
                                    }
                                    ctx.closePath();
                                    ctx.fill();

                                    ctx.restore();
                                }
                            } else if (lane.type === "river") {
                                // Water lane
                                ctx.fillStyle = "#1a3b5c";
                                ctx.fillRect(0, sy - gs, width, gs);

                                // Water ripple wave lines
                                ctx.strokeStyle = "#255382";
                                ctx.lineWidth = 1.5;
                                var waveShift = (Date.now() * 0.04) % 30;
                                for (var wx = -waveShift; wx < width; wx += 28) {
                                    ctx.beginPath();
                                    ctx.moveTo(wx, sy - gs / 2);
                                    ctx.lineTo(wx + 12, sy - gs / 2);
                                    ctx.stroke();
                                }

                                // Floating logs & lily pads
                                for (var li = 0; li < lane.items.length; li++) {
                                    var lg = lane.items[li];
                                    var lx = cX + lg.x;
                                    var ly = sy - gs + 5;
                                    var lh = gs - 10;

                                    if (lg.isLily) {
                                        // Lily pad circle
                                        ctx.fillStyle = "#2ecc71";
                                        ctx.beginPath();
                                        ctx.arc(lx, sy - gs / 2, 14, 0.2, Math.PI * 1.8);
                                        ctx.lineTo(lx, sy - gs / 2);
                                        ctx.closePath();
                                        ctx.fill();
                                    } else {
                                        // Wood log
                                        ctx.fillStyle = "#8a5833";
                                        drawRoundRect(ctx, lx - lg.len / 2, ly, lg.len, lh, 6);
                                        ctx.fill();
                                        // Log end rings
                                        ctx.fillStyle = "#a87146";
                                        ctx.beginPath();
                                        ctx.arc(lx - lg.len / 2 + 6, ly + lh / 2, lh / 2 - 2, 0, Math.PI * 2);
                                        ctx.arc(lx + lg.len / 2 - 6, ly + lh / 2, lh / 2 - 2, 0, Math.PI * 2);
                                        ctx.fill();
                                    }
                                }
                            } else if (lane.type === "railroad") {
                                // Gravel bed & rails
                                ctx.fillStyle = "#2a272b";
                                ctx.fillRect(0, sy - gs, width, gs);

                                // Wooden ties
                                ctx.fillStyle = "#52453c";
                                for (var rx = 0; rx < width; rx += 18) {
                                    ctx.fillRect(rx, sy - gs + 4, 8, gs - 8);
                                }

                                // Steel rails
                                ctx.fillStyle = "#adb5bd";
                                ctx.fillRect(0, sy - gs + 10, width, 3);
                                ctx.fillRect(0, sy - 13, width, 3);

                                // Train item & warning signal
                                var tr = lane.items[0];
                                if (tr) {
                                    // Flashing warning red signal
                                    if (tr.warning) {
                                        var flashOn = (Math.floor(Date.now() / 150) % 2 === 0);
                                        ctx.fillStyle = flashOn ? "#FF2222" : "#550000";
                                        ctx.beginPath();
                                        ctx.arc(40, sy - gs / 2, 8, 0, Math.PI * 2);
                                        ctx.arc(width - 40, sy - gs / 2, 8, 0, Math.PI * 2);
                                        ctx.fill();
                                    }

                                    // High-speed bullet train
                                    if (tr.hasTrain) {
                                        var trainDrawX = cX + tr.trainX;
                                        ctx.fillStyle = "#e0e0e0";
                                        drawRoundRect(ctx, trainDrawX - tr.trainLength / 2, sy - gs + 3, tr.trainLength, gs - 6, 8);
                                        ctx.fill();
                                        // Red racing stripe
                                        ctx.fillStyle = "#e63946";
                                        ctx.fillRect(trainDrawX - tr.trainLength / 2, sy - gs / 2 - 2, tr.trainLength, 5);
                                    }
                                }
                            }
                        }

                        // 2. Draw Golden Coins
                        for (var ci = 0; ci < Engine.coins.length; ci++) {
                            var cn = Engine.coins[ci];
                            if (cn.collected) continue;
                            var csy = height - (cn.row * gs - Engine.cameraY);
                            if (csy < -gs || csy > height + gs) continue;
                            var csx = cX + cn.col * gs;

                            // Spinning coin effect
                            var coinPhase = Math.cos(Date.now() * 0.008 + ci);
                            ctx.fillStyle = "#f1c40f";
                            ctx.beginPath();
                            ctx.ellipse(csx, csy - gs / 2, Math.abs(coinPhase) * 8 + 2, 10, 0, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // 3. Draw Particles
                        for (var pi = 0; pi < Engine.particles.length; pi++) {
                            var pt = Engine.particles[pi];
                            var psy = height - (pt.y - Engine.cameraY);
                            var psx = cX + pt.x;
                            var alpha = pt.life / pt.maxLife;

                            ctx.fillStyle = pt.isWater ? Qt.rgba(0.4, 0.8, 1.0, alpha) : Qt.rgba(1.0, 1.0, 1.0, alpha * 0.7);
                            ctx.beginPath();
                            ctx.arc(psx, psy, 3, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // 4. Draw Frog
                        if (Engine.frog) {
                            var fx = cX + Engine.frog.animX;
                            var fy = height - (Engine.frog.animY - Engine.cameraY) - gs / 2;

                            ctx.save();
                            ctx.translate(fx, fy);

                            // Rotate based on facing direction
                            var faceAng = 0;
                            if (Engine.frog.facing === 1) faceAng = Math.PI / 2;
                            else if (Engine.frog.facing === 2) faceAng = Math.PI;
                            else if (Engine.frog.facing === 3) faceAng = -Math.PI / 2;
                            ctx.rotate(faceAng);

                            // Shadow under frog during jump
                            if (Engine.frog.isHopping) {
                                ctx.fillStyle = "rgba(0, 0, 0, 0.25)";
                                ctx.beginPath();
                                ctx.ellipse(0, 8, 12, 6, 0, 0, Math.PI * 2);
                                ctx.fill();
                            }

                            // Frog Body (Bright neon green)
                            ctx.fillStyle = root.themeAccent;
                            drawRoundRect(ctx, -13, -12, 26, 24, 7);
                            ctx.fill();

                            // Frog Legs (hind feet)
                            ctx.fillStyle = Qt.darker(root.themeAccent, 1.25);
                            drawRoundRect(ctx, -15, 6, 8, 8, 3);
                            ctx.fill();
                            drawRoundRect(ctx, 7, 6, 8, 8, 3);
                            ctx.fill();

                            // Big Glossy Eyes
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.arc(-7, -11, 5.5, 0, Math.PI * 2);
                            ctx.arc(7, -11, 5.5, 0, Math.PI * 2);
                            ctx.fill();

                            // Pupils looking ahead
                            ctx.fillStyle = "#11111b";
                            ctx.beginPath();
                            ctx.arc(-7, -12.5, 2.5, 0, Math.PI * 2);
                            ctx.arc(7, -12.5, 2.5, 0, Math.PI * 2);
                            ctx.fill();

                            ctx.restore();
                        }

                        // 5. Draw Swooping Eagle (if timeout occurs)
                        if (Engine.eagle) {
                            var ex = cX + Engine.eagle.x;
                            var ey = height - (Engine.eagle.y - Engine.cameraY);

                            ctx.save();
                            ctx.translate(ex, ey);
                            ctx.fillStyle = "#3e2723";
                            // Eagle wingspan
                            ctx.beginPath();
                            ctx.moveTo(0, 16);
                            ctx.lineTo(45, -12);
                            ctx.lineTo(20, -6);
                            ctx.lineTo(0, -18);
                            ctx.lineTo(-20, -6);
                            ctx.lineTo(-45, -12);
                            ctx.closePath();
                            ctx.fill();
                            ctx.restore();
                        }
                    }
                }

                // Input click / tap area: tap top half to hop forward, sides to steer
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (root.gameState === "gameover") {
                            root.startNewGame();
                            return;
                        }
                        var h = height;
                        var w = width;
                        if (mouse.y < h * 0.65) {
                            if (mouse.x < w * 0.3) root.doHop(-1, 0);
                            else if (mouse.x > w * 0.7) root.doHop(1, 0);
                            else root.doHop(0, 1);
                        } else {
                            root.doHop(0, -1);
                        }
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
                            onGameOver: function(s) { root.gameState = "gameover"; },
                            onSound: function(snd) { root.playSound(snd); }
                        });
                        root.gameState = Engine.gameState;
                        root.score = Engine.score;
                        gameCanvas.requestPaint();
                    }
                }

                onWidthChanged: {
                    if (width > 50 && height > 50) Engine.resize(width, height);
                }
                onHeightChanged: {
                    if (width > 50 && height > 50) Engine.resize(width, height);
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
                        text: "Distance: " + root.score + " hops"
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

    // HOW TO PLAY MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.82)
        visible: root.showHelp
        z: 90

        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Rectangle {
            width: Math.min(parent.width - 40, 360)
            height: helpCol.implicitHeight + 40
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            anchors.centerIn: parent

            Column {
                id: helpCol
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 12

                Text {
                    text: "HOW TO PLAY"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeAccent
                    font.family: root.monoFontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.helpText
                    font.pixelSize: 12
                    color: root.themeFg
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                    width: parent.width
                    font.family: root.monoFontFamily
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
                        color: root.themeBg
                        font.bold: true
                        font.pixelSize: 11
                        font.family: root.monoFontFamily
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

    // SOUND TOAST NOTIFICATION
    Rectangle {
        id: soundToast
        property alias text: toastText.text
        width: toastText.implicitWidth + 24
        height: 32
        radius: 16
        color: Qt.rgba(0, 0, 0, 0.85)
        border.color: root.themeBorder
        border.width: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: 0
        z: 100

        Text {
            id: toastText
            anchors.centerIn: parent
            color: root.themeFg
            font.bold: true
            font.pixelSize: 11
            font.family: root.monoFontFamily
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

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }
}
