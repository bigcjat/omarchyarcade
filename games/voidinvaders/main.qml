import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 680
    minimumWidth: 360
    minimumHeight: 460
    title: "VoidInvaders"

    signal screenshotSaved(string path)

    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: "Catppuccin"

    property color themeBg: "#181825"
    property color themeFg: "#cdd6f4"
    property color themeAccent: "#89b4fa"
    property color themeBoardBg: "#0b0f19"
    property color themeCellGrid: "#1f293d"
    property color themeCardBg: "#1e1e2e"
    property color themeSubtext: "#a6adc8"
    property color themeBorder: "#45475a"
    property color themeModalBg: "#1e1e2e"
    property color themeBtnFg: "#0B0E14"

    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeCardHover: isDarkMode ? Qt.lighter(themeCardBg, 1.15) : "#f1f5f9"

    // Alien Colors
    property color squidColor: "#cba6f7"
    property color crabColor: "#89b4fa"
    property color octopusColor: "#a6e3a1"
    property color ufoColor: "#f38ba8"
    property color bunkerColor: "#a6e3a1"

    // State
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"
    property int highScore: 0
    property string gameState: "playing"
    property int score: 0
    property int wave: 1
    property int lives: 3

    color: themeBg

    Component.onCompleted: {
        loadHighScore();
        Engine.init(1);
        mainContainer.forceActiveFocus();
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

        squidColor = data.color5 || "#cba6f7";
        crabColor = data.color4 || "#89b4fa";
        octopusColor = data.color2 || "#a6e3a1";
        ufoColor = data.color1 || "#f38ba8";
        bunkerColor = data.color2 || "#a6e3a1";

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = "#0b0f19";
            themeCellGrid = "#1f293d";
            themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#ffffff";
            themeBorder = data.border || Qt.rgba(0, 0, 0, 0.12);
            themeSubtext = data.subtext || "#6c6f85";
            themeModalBg = "#ffffff";
            themeBtnFg = "#ffffff";
        } else {
            themeBoardBg = "#0b0f19";
            themeCellGrid = "#1f293d";
            themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#1e1e2e";
            themeBorder = data.border || "#313244";
            themeSubtext = data.subtext || "#a6adc8";
            themeModalBg = "#1e1e2e";
            themeBtnFg = "#0B0E14";
        }
        gameCanvas.requestPaint();
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#1e66f5",
            cardBg: "#ffffff",
            border: "#ccd0da",
            subtext: "#6c6f85",
            color1: "#d20f39",
            color2: "#40a02b",
            color4: "#1e66f5",
            color5: "#8839ef"
        } : {
            background: "#1e1e2e",
            foreground: "#cdd6f4",
            accent: "#89b4fa",
            cardBg: "#181825",
            border: "#45475a",
            subtext: "#a6adc8",
            color1: "#f38ba8",
            color2: "#a6e3a1",
            color4: "#89b4fa",
            color5: "#cba6f7"
        };
        applyTheme(tData, nextIsLight ? "Light Mode" : "Dark Mode");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
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
        if (typeof settingsManager !== "undefined") {
            highScore = settingsManager.getHighScore();
        }
    }

    function updateHighScore() {
        if (Engine.score > highScore) {
            highScore = Engine.score;
            if (typeof settingsManager !== "undefined") {
                settingsManager.setHighScore(highScore);
            }
        }
    }

    function resetGame() {
        Engine.init(1);
        root.gameState = "playing";
        root.score = 0;
        root.wave = 1;
        root.lives = 3;
        gameCanvas.requestPaint();
        mainContainer.forceActiveFocus();
    }

    // 60 FPS loop
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
            root.wave = Engine.wave;
            root.lives = Engine.lives;

            if (events && events.length > 0) {
                for (var i = 0; i < events.length; i++) {
                    var ev = events[i];
                    if (ev.type === "shoot") playSound("shoot");
                    else if (ev.type === "explode") playSound("explode");
                    else if (ev.type === "invader_move") playSound("invader_move");
                    else if (ev.type === "player_die") playSound("player_die");
                    else if (ev.type === "ufo") playSound("ufo");
                    else if (ev.type === "cleared") {
                        soundToast.show("⭐ WAVE " + root.wave + " CLEARED!");
                    } else if (ev.type === "gameover") {
                        updateHighScore();
                        soundToast.show("💀 INVASION COMPLETE - GAME OVER");
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
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // Alien Matrices (pixel patterns)
    property var squidFrames: [
        [
            "00011000",
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "00100100",
            "01011010",
            "10100101"
        ],
        [
            "00011000",
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "01011010",
            "10000001",
            "01000010"
        ]
    ]

    property var crabFrames: [
        [
            "00100000100",
            "00010001000",
            "00111111100",
            "01101110110",
            "11111111111",
            "10111111101",
            "10100000101",
            "00011011000"
        ],
        [
            "00100000100",
            "10010001001",
            "10111111101",
            "11101110111",
            "11111111111",
            "01111111110",
            "00100000100",
            "01000000010"
        ]
    ]

    property var octoFrames: [
        [
            "000011110000",
            "011111111110",
            "111111111111",
            "111001100111",
            "111111111111",
            "000110011000",
            "001101101100",
            "110000000011"
        ],
        [
            "000011110000",
            "011111111110",
            "111111111111",
            "111001100111",
            "111111111111",
            "001100001100",
            "011011110110",
            "000100001000"
        ]
    ]

    function drawPixelSprite(ctx, matrix, x, y, w, h, color) {
        var rows = matrix.length;
        var cols = matrix[0].length;
        var pw = w / cols;
        var ph = h / rows;
        ctx.fillStyle = color;
        for (var r = 0; r < rows; r++) {
            var rowStr = matrix[r];
            for (var c = 0; c < cols; c++) {
                if (rowStr[c] === '1') {
                    ctx.fillRect(x + c * pw, y + r * ph, pw + 0.5, ph + 0.5);
                }
            }
        }
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

            if (event.key === Qt.Key_T) {
                cycleTheme();
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
                resetGame();
                soundToast.show("Restarted");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_P) {
                if (Engine.gameState === "playing") {
                    Engine.gameState = "paused";
                    root.gameState = "paused";
                    soundToast.show("⏸ Paused");
                } else if (Engine.gameState === "paused") {
                    Engine.gameState = "playing";
                    root.gameState = "playing";
                }
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (showHelp) {
                    showHelp = false;
                    event.accepted = true;
                    return;
                } else {
                    if (Engine.gameState === "playing") {
                        Engine.gameState = "paused";
                        root.gameState = "paused";
                        soundToast.show("⏸ Paused");
                    } else if (Engine.gameState === "paused") {
                        Engine.gameState = "playing";
                        root.gameState = "playing";
                    }
                    event.accepted = true;
                    return;
                }
            }
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }

            // Player Cannon Movement
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.player.vx = -Engine.player.speed;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.player.vx = Engine.player.speed;
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Up) {
                var sRes = Engine.shoot();
                if (sRes) playSound("shoot");
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H ||
                event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.player.vx = 0;
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
                    text: "VoidInvaders"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Wave " + root.wave + " • Lives: " + root.lives + (root.gameState === "gameover" ? " • Game Over" : (root.gameState === "paused" ? " • Paused" : ""))
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

                // SCORE Card
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
                            text: root.highScore.toString()
                            font.pixelSize: 18
                            font.bold: true
                            color: root.highScore > 0 ? (root.isDarkMode ? root.themeAccent : "#15803d") : (root.isDarkMode ? root.themeSubtext : "#94a3b8")
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
                    width: (parent.width - 24) / 4
                    height: parent.height
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 16; height: 16; radius: 8; color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg }
                        }
                        Text {
                            text: "Help"
                            font.pixelSize: 11; font.bold: true; color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: helpMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mute button
                Rectangle {
                    width: (parent.width - 24) / 4
                    height: parent.height
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.pixelSize: 11; font.bold: true; color: root.isMuted ? root.themeSubtext : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: muteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // View Mode
                Rectangle {
                    width: (parent.width - 24) / 4
                    height: parent.height
                    radius: 8
                    color: viewModeMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: root.fullPlayfield ? "🔲" : "⛶"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: root.fullPlayfield ? "Standard" : "Full"
                            font.pixelSize: 11; font.bold: true; color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: viewModeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                        }
                    }
                }

                // Restart
                Rectangle {
                    width: (parent.width - 24) / 4
                    height: parent.height
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "🔄"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "Restart"
                            font.pixelSize: 11; font.bold: true; color: root.themeBtnFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: restartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.resetGame();
                            soundToast.show("Restarted");
                        }
                    }
                }
            }
        }

        // COURT PLAYING AREA
        Item {
            id: courtArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // Floating Tiled HUD
            Rectangle {
                id: floatingTiledHUD
                visible: root.isTiledDesktopMode
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 4
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
                        text: "👾 VoidInvaders"
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
                            onClicked: root.resetGame()
                        }
                    }
                }
            }

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

                    // UFO
                    if (Engine.ufo && Engine.ufo.active) {
                        var u = Engine.ufo;
                        ctx.fillStyle = root.ufoColor;
                        drawRoundRect(ctx, u.x, u.y + 4, 48, 12, 6);
                        ctx.fill();

                        ctx.fillStyle = "#ffffff";
                        drawRoundRect(ctx, u.x + 14, u.y, 20, 8, 4);
                        ctx.fill();
                    }

                    // Invaders
                    var frame = Engine.invaderAnimFrame;
                    for (var i = 0; i < Engine.invaders.length; i++) {
                        var inv = Engine.invaders[i];
                        if (!inv.alive) continue;

                        if (inv.type === 2) {
                            // Squid
                            drawPixelSprite(ctx, squidFrames[frame], inv.x, inv.y, inv.w, inv.h, root.squidColor);
                        } else if (inv.type === 1) {
                            // Crab
                            drawPixelSprite(ctx, crabFrames[frame], inv.x, inv.y, inv.w, inv.h, root.crabColor);
                        } else {
                            // Octopus
                            drawPixelSprite(ctx, octoFrames[frame], inv.x, inv.y, inv.w, inv.h, root.octopusColor);
                        }
                    }

                    // Bunkers (Shields)
                    for (var b = 0; b < Engine.bunkers.length; b++) {
                        var bnk = Engine.bunkers[b];
                        for (var r = 0; r < bnk.rows; r++) {
                            for (var c = 0; c < bnk.cols; c++) {
                                var hp = bnk.grid[r][c];
                                if (hp <= 0) continue;
                                var bx = bnk.x + c * bnk.cellW;
                                var by = bnk.y + r * bnk.cellH;
                                ctx.fillStyle = root.bunkerColor;
                                ctx.globalAlpha = hp / 3.0;
                                ctx.fillRect(bx, by, bnk.cellW - 0.5, bnk.cellH - 0.5);
                            }
                        }
                    }
                    ctx.globalAlpha = 1.0;

                    // Player Cannon
                    var p = Engine.player;
                    ctx.fillStyle = root.themeAccent;
                    // Cannon base
                    drawRoundRect(ctx, p.x, p.y + 6, p.w, p.h - 6, 4);
                    ctx.fill();
                    // Cannon turret
                    ctx.fillRect(p.x + p.w / 2 - 3, p.y - 3, 6, 9);

                    // Player Bullet
                    if (Engine.playerBullet) {
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(Engine.playerBullet.x - 1.5, Engine.playerBullet.y, 3, 10);
                        ctx.fillStyle = root.themeAccent;
                        ctx.fillRect(Engine.playerBullet.x - 0.5, Engine.playerBullet.y + 2, 1, 6);
                    }

                    // Alien Bullets
                    ctx.fillStyle = root.ufoColor;
                    for (var ab = 0; ab < Engine.alienBullets.length; ab++) {
                        var abullet = Engine.alienBullets[ab];
                        ctx.fillRect(abullet.x - 1.5, abullet.y, 3, 8);
                    }

                    // Particles
                    for (var pt = 0; pt < Engine.particles.length; pt++) {
                        var part = Engine.particles[pt];
                        ctx.fillStyle = root.themeFg;
                        ctx.globalAlpha = Math.max(0, part.life / part.maxLife);
                        ctx.fillRect(part.x, part.y, 2, 2);
                    }
                    ctx.globalAlpha = 1.0;

                    // Game Over / Paused overlay
                    if (Engine.gameState === "paused") {
                        ctx.fillStyle = "#ffffff";
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
                        Engine.player.x = Math.max(16, Math.min(Engine.COURT_W - Engine.player.w - 16, courtX - Engine.player.w / 2));
                    }

                    onClicked: {
                        if (Engine.gameState === "gameover" || root.gameState === "gameover") {
                            resetGame();
                            soundToast.show("Restarted");
                            return;
                        }
                        var sRes = Engine.shoot();
                        if (sRes) playSound("shoot");
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
                        text: "INVASION COMPLETE"
                        font.family: root.monoFontFamily
                        font.pixelSize: 22
                        font.bold: true
                        color: root.themePalette.color1 || "#f38ba8"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Score: " + root.score + (root.highScore > 0 ? "  •  Best: " + root.highScore : "")
                        font.family: root.monoFontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 150
                        height: 40
                        radius: 8
                        color: root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "PLAY AGAIN"
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeBtnFg
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
                        text: "Press A, R, Space, or Return"
                        font.family: root.monoFontFamily
                        font.pixelSize: 11
                        color: "#94a3b8"
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
            height: 410
            radius: 16
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "👾 VoidInvaders Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Defend Earth against marching waves of space invaders! Use bunkers for cover and blast the high-value mystery UFOs across the sky."
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
                    Text { text: "Move Cannon (or Mouse)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Space / Return / Click"; font.bold: true; color: root.themePalette.color1 || "#f38ba8"; font.pixelSize: 12 }
                    Text { text: "Fire Laser Cannon"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "P"; font.bold: true; color: root.themePalette.color2 || "#a6e3a1"; font.pixelSize: 12 }
                    Text { text: "Pause / Resume"; color: root.themeFg; font.pixelSize: 12 }

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
