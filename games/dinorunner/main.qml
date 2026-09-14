import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 680
    height: 560
    minimumWidth: 360
    minimumHeight: 340
    title: "DinoRunner"

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            cardBg: "#ffffff",
            border: "#cbd5e1",
            subtext: "#64748b",
            accent: "#1e66f5"
        } : {
            background: "#181825",
            foreground: "#cdd6f4",
            cardBg: "#313244",
            border: "#45475a",
            subtext: "#a6adc8",
            accent: "#89b4fa"
        };
        applyTheme(tData, nextIsLight ? "Omarchy Light" : "Omarchy Dark");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    function lerpColor(c1, c2, t) {
        var a = Qt.color(c1);
        var b = Qt.color(c2);
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        );
    }

    property bool baseIsLight: false
    property var lightPalette: ({
        bg: "#eff1f5",
        boardBg: "#ffffff",
        cardBg: "#ffffff",
        cardHover: "#f1f5f9",
        fg: "#4c4f69",
        subtext: "#5c5f77",
        border: "#ccd0da",
        accent: "#1e66f5",
        btnFg: "#ffffff"
    })

    property var darkPalette: ({
        bg: "#181825",
        boardBg: "#1e1e2e",
        cardBg: "#313244",
        cardHover: "#45475a",
        fg: "#cdd6f4",
        subtext: "#a6adc8",
        border: "#45475a",
        accent: "#89b4fa",
        btnFg: "#11111b"
    })

    property real rawInvert: 0.0
    readonly property real darkRatio: baseIsLight ? rawInvert : (1.0 - rawInvert)

    property color themeBg: lerpColor(lightPalette.bg, darkPalette.bg, darkRatio)
    property color themeBoardBg: lerpColor(lightPalette.boardBg, darkPalette.boardBg, darkRatio)
    property color themeCellGrid: lerpColor("#e6e9ef", "#252538", darkRatio)
    property color themeCardBg: lerpColor(lightPalette.cardBg, darkPalette.cardBg, darkRatio)
    property color themeCardHover: lerpColor(lightPalette.cardHover, darkPalette.cardHover, darkRatio)
    property color themeFg: lerpColor(lightPalette.fg, darkPalette.fg, darkRatio)
    property color themeSubtext: lerpColor(lightPalette.subtext, darkPalette.subtext, darkRatio)
    property color themeAccent: lerpColor(lightPalette.accent, darkPalette.accent, darkRatio)
    property color themeBorder: lerpColor(lightPalette.border, darkPalette.border, darkRatio)
    property color themeBtnBg: themeAccent
    property color themeBtnFg: lerpColor(lightPalette.btnFg, darkPalette.btnFg, darkRatio)
    readonly property bool isDarkMode: darkRatio > 0.5
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 440 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 440 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Jump: Space, W, ↑, or Vim K\n• Fast Drop / Duck: S, ↓, or Vim J\n• Duck under flying Pterodactyls\n• Day/Night cycle inverts every 700m\n• Milestone chime every 100m\n• Invert toggle: I | Pterodactyl: P\n• Full/Compact View: Shift+F\n• Mute: M | Restart: R | Help: ?"

    color: themeBg

    property string gameState: "playing"
    property int score: 0
    property int highScore: 0
    property bool flashVisible: true

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.bg || data.background || "#181825";
        var fg = data.fg || data.foreground || "#cdd6f4";
        var accent = data.accent || "#89b4fa";
        var lum = colorLuminance(bg);
        baseIsLight = (lum > 0.5);

        if (baseIsLight) {
            lightPalette = {
                bg: bg,
                boardBg: "#ffffff",
                cardBg: data.card_bg || data.cardBg || "#ffffff",
                cardHover: data.card_hover || "#f1f5f9",
                fg: fg,
                subtext: data.subtext || "#5c5f77",
                border: data.border || "#ccd0da",
                accent: accent,
                btnFg: colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff"
            };
            darkPalette = {
                bg: "#181825",
                boardBg: "#1e1e2e",
                cardBg: "#313244",
                cardHover: "#45475a",
                fg: "#cdd6f4",
                subtext: "#a6adc8",
                border: "#45475a",
                accent: "#89b4fa",
                btnFg: "#11111b"
            };
        } else {
            darkPalette = {
                bg: bg,
                boardBg: "#1e1e2e",
                cardBg: data.card_bg || data.cardBg || "#313244",
                cardHover: data.card_hover || "#45475a",
                fg: fg,
                subtext: data.subtext || "#a6adc8",
                border: data.border || "#45475a",
                accent: accent,
                btnFg: colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff"
            };
            lightPalette = {
                bg: "#eff1f5",
                boardBg: "#ffffff",
                cardBg: "#ffffff",
                cardHover: "#f1f5f9",
                fg: "#4c4f69",
                subtext: "#5c5f77",
                border: "#ccd0da",
                accent: "#1e66f5",
                btnFg: "#ffffff"
            };
        }
        if (gameCanvas) {
            gameCanvas.loadImage(gameCanvas.daySprite);
            gameCanvas.loadImage(gameCanvas.nightSprite);
            gameCanvas.requestPaint();
        }
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function startNewGame() {
        Engine.resetGame();
        root.gameState = "playing";
        root.score = 0;
        gameCanvas.requestPaint();
        soundToast.show("Dash Started");
    }

    function spawnPterodactyl() {
        if (root.gameState !== "playing") return;
        Engine.obstacles = [];
        Engine.addObstacle(10.0);
        for (var i = 0; i < Engine.obstacles.length; i++) {
            Engine.obstacles[i].type = "PTERODACTYL";
            Engine.obstacles[i].typeConfig = Engine.OBSTACLE_TYPES[2];
            Engine.obstacles[i].width = 46;
            Engine.obstacles[i].height = 40;
            Engine.obstacles[i].yPos = Engine.groundYPos - 18;
            Engine.obstacles[i].yOffset = -18;
            Engine.obstacles[i].xPos = Engine.currentWidth * 0.65;
        }
        gameCanvas.requestPaint();
        soundToast.show("🦅 Pterodactyl Incoming!");
    }

    function toggleNightMode() {
        if (Engine.nightMode.active) {
            Engine.nightMode.active = false;
            Engine.nightMode.opacity = 0;
            root.rawInvert = 0.0;
            soundToast.show(root.darkRatio < 0.5 ? "☀️ Day Mode" : "🌙 Night Mode");
        } else {
            Engine.nightMode.active = true;
            Engine.nightMode.opacity = 1.0;
            Engine.nightMode.timer = 3000;
            Engine.nightMode.moonPhase = (Engine.nightMode.moonPhase + 1) % 7;
            Engine.nightMode.moonX = Engine.currentWidth - 50;
            Engine.nightMode.moonY = 25;
            Engine.nightMode.stars = [
                { x: Engine.currentWidth * 0.85, y: 25 },
                { x: Engine.currentWidth * 0.55, y: 45 },
                { x: Engine.currentWidth * 0.25, y: 35 },
                { x: Engine.currentWidth * 0.10, y: 55 }
            ];
            root.rawInvert = 1.0;
            soundToast.show(root.darkRatio < 0.5 ? "🌙 Night Mode Invert" : "☀️ Day Mode Invert");
        }
        gameCanvas.requestPaint();
    }

    function formatScore(num) {
        var s = "00000" + num;
        return s.substring(s.length - 5);
    }

    signal screenshotSaved(string filePath)

    function captureScreenshot(filePath) {
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
        });
    }

    // MAIN CONTAINER
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.gameState === "crashed") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_R || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
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
                startNewGame();
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

            if (event.key === Qt.Key_P) {
                spawnPterodactyl();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_I) {
                toggleNightMode();
                event.accepted = true;
                return;
            }

            if (root.gameState === "playing") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                    Engine.startJump({ onSound: function(s) { root.playSound(s); } });
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                    Engine.setDucking(true);
                    event.accepted = true;
                }
            }
        }

        Keys.onReleased: function(event) {
            if (root.gameState === "playing") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                    Engine.endJump();
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                    Engine.setDucking(false);
                }
            }
        }

        // =====================================================================
        // HEADER BAR BACKGROUND (Adapts to system OS / colors.toml theme)
        // =====================================================================
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTiledDesktopMode ? 0 : (headerItem.height + subheaderItem.height + 36)
            color: root.themeBg
            visible: !root.isTiledDesktopMode
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
                    text: "DinoRunner"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "T-Rex Endless Runner • " + root.formatScore(root.score) + "m"
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
                    width: Math.max(68, Math.min(88, headerItem.width * 0.17))
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
                            font.pixelSize: 8
                            font.bold: true
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.formatScore(root.score)
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.flashVisible ? (root.isDarkMode ? root.themeFg : "#0f172a") : "transparent"
                        }
                    }
                }

                // HI (BEST) Card
                Rectangle {
                    width: Math.max(68, Math.min(88, headerItem.width * 0.17))
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
                            text: "HI"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.isDarkMode ? root.themeSubtext : "#64748b"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.formatScore(root.highScore)
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.highScore > 0 ? (root.isDarkMode ? root.themeAccent : "#15803d") : (root.isDarkMode ? root.themeSubtext : "#94a3b8")
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

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

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
                    color: root.fullPlayfield ? root.themeCardHover : (viewModeMouse.containsMouse ? root.themeCardHover : root.themeCardBg)
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

            // Mute button in Center
            Rectangle {
                id: muteBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
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

            // Primary Action Button (Restart) on Right
            Rectangle {
                id: restartBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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
                    text: "🦖 DinoRunner"
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
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 2
                radius: 12
                clip: true

                Canvas {
                    id: gameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    property string daySprite: "assets/offline-sprite-themed.png"
                    property string nightSprite: "assets/offline-sprite-night.png"
                    property bool isReady: false

                    onWidthChanged: {
                        if (width > 0 && height > 0) {
                            Engine.resize(width, height);
                            requestPaint();
                        }
                    }
                    onHeightChanged: {
                        if (width > 0 && height > 0) {
                            Engine.resize(width, height);
                            requestPaint();
                        }
                    }

                    Component.onCompleted: {
                        loadImage(daySprite);
                        loadImage(nightSprite);
                        if (width > 0 && height > 0) {
                            Engine.resize(width, height);
                        }
                    }

                    onImageLoaded: {
                        if (isImageLoaded(daySprite) && isImageLoaded(nightSprite)) {
                            isReady = true;
                            requestPaint();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.imageSmoothingEnabled = false;
                        ctx.clearRect(0, 0, width, height);

                        if (!isReady) return;

                        var dr = root.darkRatio;

                        function drawSprite(sX, sY, sW, sH, dX, dY, dW, dH) {
                            if (dr <= 0.01) {
                                ctx.drawImage(daySprite, sX, sY, sW, sH, dX, dY, dW, dH);
                            } else if (dr >= 0.99) {
                                ctx.drawImage(nightSprite, sX, sY, sW, sH, dX, dY, dW, dH);
                            } else {
                                ctx.save();
                                ctx.globalAlpha = 1.0 - dr;
                                ctx.drawImage(daySprite, sX, sY, sW, sH, dX, dY, dW, dH);
                                ctx.globalAlpha = dr;
                                ctx.drawImage(nightSprite, sX, sY, sW, sH, dX, dY, dW, dH);
                                ctx.restore();
                            }
                        }

                        // Draw Night Mode sky elements if darkRatio > 0.05
                        if (dr > 0.05) {
                            ctx.save();
                            ctx.globalAlpha = dr;

                            // Draw Stars
                            for (var si = 0; si < Engine.nightMode.stars.length; si++) {
                                var st = Engine.nightMode.stars[si];
                                var starY = 2 + (si % 3) * 18;
                                ctx.drawImage(nightSprite,
                                    1276, starY, 18, 18,
                                    st.x, st.y, 9, 9);
                            }

                            // Draw Moon with authentic phase mapping
                            var moonPhases = [140, 120, 100, 60, 40, 20, 0];
                            var phase = Math.abs(Engine.nightMode.moonPhase) % 7;
                            var moonX = Engine.SPRITES.MOON.x + (moonPhases[phase] * 2);
                            var moonW = (phase === 3) ? 80 : 40;
                            var destW = (phase === 3) ? 40 : 20;
                            ctx.drawImage(nightSprite,
                                moonX, Engine.SPRITES.MOON.y, moonW, 80,
                                Engine.nightMode.moonX, Engine.nightMode.moonY, destW, 40);

                            ctx.restore();
                        }

                        // Draw Clouds when daylight/twilight
                        if (dr < 0.95) {
                            ctx.save();
                            ctx.globalAlpha = 1.0 - dr * 0.7;
                            for (var ci = 0; ci < Engine.clouds.length; ci++) {
                                var cl = Engine.clouds[ci];
                                drawSprite(Engine.SPRITES.CLOUD.x, Engine.SPRITES.CLOUD.y, 92, 28,
                                    cl.xPos, cl.yPos, 46, 14);
                            }
                            ctx.restore();
                        }

                        // Draw Horizon Line
                        for (var hi = 0; hi < Engine.horizonLine.xPos.length; hi++) {
                            var hx = Engine.horizonLine.xPos[hi];
                            if (hx < width && hx + 600 > 0) {
                                drawSprite(Engine.SPRITES.HORIZON.x, Engine.SPRITES.HORIZON.y, 1200, 24,
                                    hx, Engine.horizonLine.yPos, 600, 12);
                            }
                        }

                        // Draw Obstacles
                        for (var oi = 0; oi < Engine.obstacles.length; oi++) {
                            var obs = Engine.obstacles[oi];
                            var sourceW = obs.typeConfig.width * 2;
                            var sourceH = obs.typeConfig.height * 2;
                            var sPos = Engine.SPRITES[obs.type];

                            if (obs.type === "PTERODACTYL") {
                                var frameOffset = obs.currentFrame * 92;
                                drawSprite(sPos.x + frameOffset, sPos.y, 92, 80,
                                    obs.xPos, obs.yPos, 46, 40);
                            } else {
                                var sX = (sourceW * obs.size) * (0.5 * (obs.size - 1)) + sPos.x;
                                drawSprite(sX, sPos.y, sourceW * obs.size, sourceH,
                                    obs.xPos, obs.yPos, obs.width, obs.height);
                            }
                        }

                        // Draw T-Rex
                        var t = Engine.trex;
                        var isDucking = (t.status === "DUCKING");

                        if (isDucking) {
                            var duckSourceX = (t.currentFrame === 0) ? 1866 : 1984;
                            drawSprite(duckSourceX, 2, 118, 94,
                                t.xPos, t.yPos, 59, 47);
                        } else if (t.status === "CRASHED") {
                            // Crashed with X_X eyes
                            drawSprite(1338 + 4 * 88, 2, 88, 94,
                                t.xPos, t.yPos, 44, 47);
                        } else if (t.jumping) {
                            // Jumping / Standing
                            drawSprite(1338, 2, 88, 94,
                                t.xPos, t.yPos, 44, 47);
                        } else {
                            // Running trot (alternating legs)
                            var runSourceX = (t.currentFrame === 0) ? (1338 + 2 * 88) : (1338 + 3 * 88);
                            drawSprite(runSourceX, 2, 88, 94,
                                t.xPos, t.yPos, 44, 47);
                        }
                    }
                }

                // 60 FPS Game Loop
                Timer {
                    id: loopTimer
                    interval: 16
                    repeat: true
                    running: !root.splashEnabled && !root.showHelp
                    property real lastTime: Date.now()

                    onTriggered: {
                        var now = Date.now();
                        var dt = Math.min(32, Math.max(8, now - lastTime));
                        lastTime = now;

                        Engine.update(dt, {
                            onScoreChanged: function(s) {
                                root.score = s;
                                if (s > root.highScore) {
                                    root.highScore = s;
                                    if (typeof settingsManager !== "undefined" && settingsManager) {
                                        settingsManager.setHighScore(s);
                                    }
                                }
                            },
                            onGameOver: function(s) {
                                root.gameState = "crashed";
                                if (typeof settingsManager !== "undefined" && settingsManager) {
                                    settingsManager.setHighScore(s);
                                }
                            },
                            onSound: function(snd) {
                                root.playSound(snd);
                            }
                        });

                        // Score milestone flashing animation
                        if (Engine.flashCount > 0) {
                            Engine.flashTimer += dt;
                            if (Engine.flashTimer >= 150) {
                                Engine.flashTimer = 0;
                                Engine.flashCount--;
                                root.flashVisible = (Engine.flashCount % 2 === 0);
                            }
                        } else {
                            root.flashVisible = true;
                        }

                        root.rawInvert = (typeof Engine !== "undefined" && Engine.nightMode) ? Engine.nightMode.opacity : 0.0;
                        root.gameState = Engine.gameState;
                        gameCanvas.requestPaint();
                    }
                }
            }

            // STANDARDIZED RETRO GAME OVER OVERLAY
            Rectangle {
                id: gameOverOverlay
                anchors.fill: boardContainer
                color: Qt.rgba(0, 0, 0, 0.76)
                visible: root.gameState === "crashed"
                z: 50
                radius: 12

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNewGame()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "G A M E   O V E R"
                        color: "#FF5555"
                        font.pixelSize: 24
                        font.bold: true
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Distance: " + root.score + "m" + (root.score >= root.highScore && root.score > 0 ? " • NEW BEST!" : "")
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 140
                        height: 38
                        radius: 8
                        color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "RUN AGAIN"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 12
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
                        text: "Press Space, Up, or R to restart"
                        color: "#a6adc8"
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
        anchors.bottomMargin: 20
        width: toastText.implicitWidth + 24
        height: 30
        radius: 15
        color: root.isDarkMode ? root.themeCardBg : "#ffffff"
        border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
        border.width: 1
        opacity: 0
        z: 200

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.family: root.monoFontFamily
            font.pixelSize: 11
            color: root.isDarkMode ? root.themeFg : "#0f172a"
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
            width: Math.min(parent.width - 40, 380)
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
                    height: 30
                    radius: 6
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "GOT IT"
                        font.family: root.monoFontFamily
                        font.bold: true
                        font.pixelSize: 11
                        color: root.themeBtnFg
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
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.highScore = settingsManager.getHighScore();
            Engine.highScore = root.highScore;
        }
        Engine.init(600, 150);
    }
}
