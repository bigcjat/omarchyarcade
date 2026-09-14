import QtQuick
import QtQuick.Controls
import "GameEngine.js" as Engine

ApplicationWindow {
    id: root
    visible: true
    width: 600
    height: 760
    minimumWidth: 340
    minimumHeight: 380
    title: "Slime's Adventure"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#05070B"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#00E5FF"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function getContrastingColor(bgCol) {
        return colorLuminance(bgCol) > 0.5 ? "#11111b" : "#ffffff";
    }

    // Active Slime Character Color
    property var activeCharData: Engine.SLIME_CHARACTERS[Engine.selectedCharacter] || Engine.SLIME_CHARACTERS.gooey

    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool showCharPicker: false
    property bool pausedByHelp: false
    property bool isPaused: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property int gameDistance: 0
    property int gameBestDistance: 0
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Flip Gravity: Space, Enter, Up, Down, W, or S\n• Avoid Hazards: Flip between floor and ceiling to dodge stalactites and stalagmites\n• Slime Characters: Press 1-6 to switch between Gooey, Cherry, Lime, Metal, Gold, and Shadow\n• Full/Compact View: Shift+F\n• Restart: R\n• Sound: M\n• Help: ? or Esc"

    signal screenshotSaved(string filePath)

    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeCardHover: isDarkMode ? Qt.lighter(themeCardBg, 1.15) : "#f1f5f9"

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bgVal = data.bg || data.background || root.themeBg;
        root.themeBg = bgVal;
        var dark = colorLuminance(Qt.color(bgVal)) < 0.5;

        if (!dark) {
            root.themeBoardBg = "#05070B";
            root.themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#ffffff";
            root.themeBorder = data.border || "#cbd5e1";
            root.themeFg = data.fg || data.foreground || "#0f172a";
            root.themeSubtext = data.subtext || "#64748b";
            root.themeAccent = data.accent || "#0099FF";
        } else {
            root.themeBoardBg = data.boardBg || data.board_bg || data.grid_bg || "#05070B";
            root.themeCardBg = data.cardBg || data.card_bg || data.card || data.surface || "#1e1e2e";
            root.themeBorder = data.border || "#313244";
            root.themeFg = data.fg || data.foreground || "#cdd6f4";
            root.themeSubtext = data.subtext || "#a6adc8";
            root.themeAccent = data.accent || "#00E5FF";
        }
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#0099FF",
            cardBg: "#ffffff",
            border: "#ccd0da",
            subtext: "#6c6f85"
        } : {
            background: "#080c14",
            foreground: "#cdd6f4",
            accent: "#00E5FF",
            cardBg: "#1e1e2e",
            border: "#313244",
            subtext: "#a6adc8"
        };
        applyTheme(tData, nextIsLight ? "Light Mode" : "Dark Mode");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    function playSound(soundName) {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(soundName);
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (typeof soundManager !== "undefined" && soundManager && soundManager.setMuted) {
            soundManager.setMuted(root.isMuted);
        }
        soundToast.show(root.isMuted ? "Audio Muted" : "Audio Active");
    }

    function togglePause() {
        root.isPaused = !root.isPaused;
        Engine.setPaused(root.isPaused);
        soundToast.show(root.isPaused ? "Game Paused" : "Resumed");
    }

    function openHelp() {
        if (root.showHelp) return;
        root.pausedByHelp = !root.isPaused;
        root.showHelp = true;
        if (root.pausedByHelp) {
            root.isPaused = true;
            Engine.setPaused(true);
        }
    }

    function closeHelp() {
        if (!root.showHelp) return;
        root.showHelp = false;
        if (root.pausedByHelp) {
            root.isPaused = false;
            Engine.setPaused(false);
            root.pausedByHelp = false;
            if (gameCanvas) {
                gameCanvas.forceActiveFocus();
                gameCanvas.requestPaint();
            }
        }
    }

    function toggleHelp() {
        if (root.showHelp) closeHelp();
        else openHelp();
    }

    function selectSlime(charId) {
        Engine.selectCharacter(charId);
        root.activeCharData = Engine.SLIME_CHARACTERS[charId];
        root.showCharPicker = false;
        playSound("click");
        soundToast.show("Selected " + root.activeCharData.name);
        gameCanvas.requestPaint();
    }

    function restartGame() {
        if (root.showHelp) closeHelp();
        Engine.resetGame();
        root.isPaused = false;
        Engine.setPaused(false);
        root.gameDistance = 0;
        root.gameBestDistance = Engine.bestDistance;
        playSound("select");
        gameCanvas.requestPaint();
    }

    function captureScreenshot(filePath, notify) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0 && root.splashEnabled) ? splashScreen : container;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (notify) soundToast.show("Screenshot Saved");
        });
    }

    // Load High Score
    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            Engine.bestDistance = settingsManager.getBestScore();
        }
        if (typeof soundManager !== "undefined" && soundManager && soundManager.setMuted) {
            soundManager.setMuted(root.isMuted);
        }
        Engine.init(gameCanvas.width, gameCanvas.height);
    }

    // =========================================================================
    // ROOT SHELL CONTAINER
    // =========================================================================
    Rectangle {
        id: container
        anchors.fill: parent
        color: root.themeBg
        focus: true

        Keys.onPressed: function(event) {
            if (splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                    root.closeHelp();
                    event.accepted = true;
                    return;
                }
                event.accepted = true;
                return;
            }

            // Quick Slime Character Hotkeys (1 through 6)
            if (event.key === Qt.Key_1) { root.selectSlime("gooey"); event.accepted = true; return; }
            if (event.key === Qt.Key_2) { root.selectSlime("cherry"); event.accepted = true; return; }
            if (event.key === Qt.Key_3) { root.selectSlime("lime"); event.accepted = true; return; }
            if (event.key === Qt.Key_4) { root.selectSlime("metal"); event.accepted = true; return; }
            if (event.key === Qt.Key_5) { root.selectSlime("gold"); event.accepted = true; return; }
            if (event.key === Qt.Key_6) { root.selectSlime("shadow"); event.accepted = true; return; }

            if (event.key === Qt.Key_T) {
                root.cycleTheme();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P || (event.key === Qt.Key_Escape && !root.showHelp)) {
                root.togglePause();
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

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.toggleHelp();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_C) {
                root.showCharPicker = !root.showCharPicker;
                event.accepted = true;
                return;
            }

            // Core Action: Gravity Flip!
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_W || event.key === Qt.Key_S ||
                event.key === Qt.Key_K || event.key === Qt.Key_J) {
                Engine.handleInput("flip", {
                    onSound: root.playSound,
                    onGameOver: function(dist) {
                        if (typeof settingsManager !== "undefined" && settingsManager) {
                            settingsManager.setBestScore(Engine.bestDistance);
                        }
                    }
                });
                gameCanvas.requestPaint();
                event.accepted = true;
                return;
            }
        }

        // =====================================================================
        // HEADER BAR CONTAINER (Tier 1 & Tier 2)
        // =====================================================================
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTiledDesktopMode ? 0 : (headerCol.height + 26)
            visible: !root.isTiledDesktopMode
            color: root.themeBg
            z: 20

            Column {
                id: headerCol
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                // =============================================================
                // TIER 1: 2048 STANDARD HEADER
                // =============================================================
                Item {
                    id: headerItem
                    width: parent.width
                    height: 52

                    // Left: Title & Subtitle
                    Column {
                        anchors.left: parent.left
                        anchors.right: scoreRow.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: "Slime's Adventure"
                            font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.07))
                            font.bold: true
                            color: root.activeCharData ? root.activeCharData.color : root.themeAccent
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: "Japanese Crane-Game Cavern Runner"
                            font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.03))
                            color: root.themeSubtext
                        }
                    }

                    // Right: Distance & Best Distance Stat Cards
                    Row {
                        id: scoreRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Distance Card
                        Rectangle {
                            width: Math.max(68, Math.min(95, headerItem.width * 0.17))
                            height: 50
                            radius: 8
                            color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                            border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: "DISTANCE"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.isDarkMode ? root.themeSubtext : "#64748b"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: root.gameDistance.toString() + "m"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.isDarkMode ? root.themeFg : "#0f172a"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Best Distance Card
                        Rectangle {
                            width: Math.max(68, Math.min(95, headerItem.width * 0.17))
                            height: 50
                            radius: 8
                            color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                            border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: "BEST"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.isDarkMode ? root.themeSubtext : "#64748b"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: root.gameBestDistance.toString() + "m"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.isDarkMode ? (root.activeCharData ? root.activeCharData.color : root.themeAccent) : "#15803d"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // TIER 2: ACTION SUBHEADER & CHARACTER SELECT BAR
                // =============================================================
                Item {
                    id: subheaderItem
                    width: parent.width
                    height: 32

                    property bool isCrowded: width < 480

                    // Left: How to Play + Character Picker Toggle + Full Screen Toggle
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Help Button
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
                                spacing: 5
                                Text {
                                    text: "?"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.themeAccent
                                    anchors.verticalCenter: parent.verticalCenter
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
                                onClicked: root.toggleHelp()
                            }
                        }

                        // Slime Character Picker Toggle
                        Rectangle {
                            height: 32
                            width: subheaderItem.isCrowded ? 32 : 110
                            radius: 8
                            color: charPickerMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                            border.color: root.showCharPicker ? root.activeCharData.color : (charPickerMouse.containsMouse ? root.themeAccent : root.themeBorder)
                            border.width: 1.5

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "🍮"; font.pixelSize: 12 }
                                Text {
                                    text: root.activeCharData.name
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: root.activeCharData.color
                                    visible: !subheaderItem.isCrowded
                                }
                            }

                            MouseArea {
                                id: charPickerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showCharPicker = !root.showCharPicker
                            }
                        }

                        // Full Screen Playfield Toggle
                        Rectangle {
                            height: 32
                            width: 32
                            radius: 8
                            color: fullMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                            border.color: fullMouse.containsMouse ? root.themeAccent : root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.fullPlayfield ? "🔲" : "⛶"
                                font.pixelSize: 11
                                color: root.themeFg
                            }

                            MouseArea {
                                id: fullMouse
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

                    // Right: Audio Mute + Restart
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Audio Mute
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: muteMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                            border.color: root.isMuted ? root.themeBorder : root.themeAccent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.isMuted ? "🔇" : "🔊"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMute()
                            }
                        }

                        // Restart Game
                        Rectangle {
                            height: 32
                            width: subheaderItem.isCrowded ? 32 : 110
                            radius: 8
                            color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "🔄"; font.pixelSize: 11 }
                                Text { text: "RESTART (R)"; font.bold: true; font.pixelSize: 11; color: root.themeBtnFg; visible: !subheaderItem.isCrowded }
                            }

                            MouseArea {
                                id: restartMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartGame()
                            }
                        }
                    }
                }

                // Slime Character Selection Tray
                Rectangle {
                    id: charSelectTray
                    visible: root.showCharPicker && !root.isTiledDesktopMode
                    width: parent.width
                    height: visible ? 52 : 0
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "gooey", name: "Gooey (1)", color: "#0099FF", key: "1" },
                                { id: "cherry", name: "Cherry (2)", color: "#FF3366", key: "2" },
                                { id: "lime", name: "Lime (3)", color: "#10E070", key: "3" },
                                { id: "metal", name: "Metal (4)", color: "#C0C8D8", key: "4" },
                                { id: "gold", name: "Gold (5)", color: "#FFB800", key: "5" },
                                { id: "shadow", name: "Shadow (6)", color: "#A855F7", key: "6" }
                            ]

                            Rectangle {
                                width: Math.min(84, (charSelectTray.width - 64) / 6)
                                height: 36
                                radius: 6
                                color: Engine.selectedCharacter === modelData.id ? Qt.darker(modelData.color, 2.2) : (charBtnMouse.containsMouse ? root.themeCardHover : root.themeCardBg)
                                border.color: Engine.selectedCharacter === modelData.id ? modelData.color : root.themeBorder
                                border.width: Engine.selectedCharacter === modelData.id ? 2 : 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: modelData.color
                                        border.color: "#FFFFFF"
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Engine.selectedCharacter === modelData.id ? modelData.color : root.themeFg
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: charBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectSlime(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER & CANVAS
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? parent.top : headerBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            Rectangle {
                id: boardBorder
                anchors.fill: parent
                color: root.themeBoardBg
                clip: true

                Canvas {
                    id: gameCanvas
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d");
                        Engine.render(ctx, width, height, {
                            accent: root.themeAccent,
                            border: root.themeBorder,
                            card_bg: root.themeCardBg,
                            fg: root.themeFg
                        });
                    }

                    onWidthChanged: Engine.resize(width, height)
                    onHeightChanged: Engine.resize(width, height)

                    // One-Tap / Mouse Click Gravity Flip
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Engine.handleInput("flip", {
                                onSound: root.playSound,
                                onGameOver: function(dist) {
                                    if (typeof settingsManager !== "undefined" && settingsManager) {
                                        settingsManager.setBestScore(Engine.bestDistance);
                                    }
                                }
                            });
                            gameCanvas.requestPaint();
                        }
                    }
                }

                // Floating Tiling HUD (Visible when header is hidden)
                Rectangle {
                    id: floatingTiledHUD
                    visible: root.isTiledDesktopMode
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 38
                    radius: 8
                    color: root.isDarkMode ? "#e6181825" : "#e6ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1
                    z: 90

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "🍮 " + (root.activeCharData ? root.activeCharData.name : "SLIME")
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isDarkMode ? (root.activeCharData ? root.activeCharData.color : root.themeAccent) : "#0f172a"
                        }

                        Text {
                            text: "• " + root.gameDistance + "m"
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.isDarkMode ? root.themeFg : "#0f172a"
                        }

                        Text {
                            text: "(BEST: " + root.gameBestDistance + "m)"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.isDarkMode ? root.themeSubtext : "#15803d"
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
                                onClicked: root.fullPlayfield = false
                            }
                        }

                        // Help
                        Rectangle {
                            width: 26; height: 26; radius: 5
                            color: "transparent"; border.color: root.themeBorder; border.width: 1
                            Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleHelp()
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
                            Text { text: "🔄"; font.pixelSize: 11; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartGame()
                            }
                        }
                    }
                }

                // =============================================================
                // GAME OVER OVERLAY
                // =============================================================
                Rectangle {
                    id: gameOverOverlay
                    anchors.fill: parent
                    color: "#d9000000"
                    visible: Engine.gameState === "gameover"
                    z: 950

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            text: "💥 SPLAT!"
                            color: "#FF3366"
                            font.pixelSize: 32
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Distance: " + root.gameDistance + "m"
                            color: root.themeFg
                            font.pixelSize: 20
                            font.bold: true
                            font.family: root.monoFontFamily
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Best: " + root.gameBestDistance + "m"
                            color: root.activeCharData ? root.activeCharData.color : root.themeAccent
                            font.pixelSize: 14
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Rectangle {
                            width: 180
                            height: 42
                            radius: 8
                            color: restartGameOverMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "🔄"; font.pixelSize: 13 }
                                Text {
                                    text: "TRY AGAIN (Space)"
                                    color: root.themeBtnFg
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                id: restartGameOverMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartGame()
                            }
                        }

                        Text {
                            text: "Press Space, Enter, or R to restart"
                            color: root.themeSubtext
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // =============================================================
                // PAUSE OVERLAY
                // =============================================================
                Rectangle {
                    id: pauseOverlay
                    anchors.fill: parent
                    color: "#d9000000"
                    visible: root.isPaused && Engine.gameState !== "gameover"
                    z: 960

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            text: "PAUSED"
                            color: root.themeAccent
                            font.pixelSize: 32
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Distance: " + root.gameDistance + "m • Slime: " + (root.activeCharData ? root.activeCharData.name : "")
                            color: root.themeSubtext
                            font.pixelSize: 13
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            spacing: 10
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: 120
                                height: 40
                                radius: 8
                                color: root.themeAccent
                                Text { anchors.centerIn: parent; text: "RESUME (P)"; font.bold: true; color: root.themeBtnFg; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePause() }
                            }

                            Rectangle {
                                width: 120
                                height: 40
                                radius: 8
                                color: root.themeCardBg
                                border.color: root.themeBorder
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "HOW TO PLAY"; font.bold: true; color: root.themeFg; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openHelp() }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Game Over, Sound Toast)
        // =====================================================================
        // Help Modal
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#b3000000"
            visible: root.showHelp
            z: 900

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeHelp()
            }

            Rectangle {
                width: Math.min(parent.width * 0.88, 380)
                height: helpCol.height + 40
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

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
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.helpText
                        font.pixelSize: 12
                        color: root.themeFg
                        lineHeight: 1.4
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: 120
                        height: 32
                        radius: 6
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "GOT IT"
                            font.bold: true
                            font.pixelSize: 11
                            color: root.themeBtnFg
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeHelp()
                        }
                    }

                    Text {
                        text: "Created by Chris Thompson (@bigcjat) with Gemini"
                        font.pixelSize: 9
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
            property string message: ""
            opacity: 0.0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            width: toastText.implicitWidth + 24
            height: 32
            radius: 8
            color: root.isDarkMode ? "#e611111b" : "#e6ffffff"
            border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
            border.width: 1
            z: 1200

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: soundToast.message
                font.pixelSize: 11
                font.bold: true
                color: root.isDarkMode ? root.themeFg : "#0f172a"
            }

            Timer {
                id: toastTimer
                interval: 1600
                onTriggered: soundToast.opacity = 0.0
            }

            function show(msg) {
                message = msg;
                opacity = 1.0;
                toastTimer.restart();
            }
        }

        // =====================================================================
        // 60 FPS GAME ENGINE LOOP TIMER
        // =====================================================================
        Timer {
            id: frameTimer
            interval: 16 // ~60 FPS
            running: true
            repeat: true
            onTriggered: {
                Engine.update(0.016, {
                    onSound: root.playSound,
                    onGameOver: function(dist) {
                        if (typeof settingsManager !== "undefined" && settingsManager) {
                            settingsManager.setBestScore(Engine.bestDistance);
                        }
                    }
                });
                root.gameDistance = Engine.distance;
                root.gameBestDistance = Engine.bestDistance;
                gameCanvas.requestPaint();
            }
        }
    }

    // Canonical Omarchy Arcade Splash Screen
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        z: 1000
    }
}
