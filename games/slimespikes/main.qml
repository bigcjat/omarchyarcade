import QtQuick
import QtQuick.Controls
import "Themes.js" as Themes
import "GameEngine.js" as Engine

ApplicationWindow {
    id: root
    visible: true
    width: 600
    height: 760
    minimumWidth: 340
    minimumHeight: 380
    title: "SlimeSpikes"

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
        var r = col.r !== undefined ? col.r : 1.0;
        var g = col.g !== undefined ? col.g : 1.0;
        var b = col.b !== undefined ? col.b : 1.0;
        return 0.299 * r + 0.587 * g + 0.114 * b;
    }

    function getContrastingColor(bgCol) {
        return colorLuminance(bgCol) > 0.5 ? "#11111b" : "#ffffff";
    }

    // Active Slime Character Color
    property var activeCharData: Engine.SLIME_CHARACTERS[Engine.selectedCharacter] || Engine.SLIME_CHARACTERS.gooey

    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false
    property bool showCharPicker: false
    property bool pausedByHelp: false
    property bool isPaused: false
    property bool fullPlayfield: false
    readonly property bool isTiledDesktopMode: fullPlayfield || root.height < 520 || root.width < 440
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Flip Gravity: Space, Enter, Up, Down, W, or S\n• Avoid Spikes: Flip between floor and ceiling to dodge hazards\n• Slime Characters: Press 1-6 to switch between Gooey, Cherry, Lime, Metal, Gold, and Shadow\n• Restart: R\n• Sound: M\n• Help: ? or Esc"

    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) root.themeBg = data.bg;
        if (data.board_bg || data.grid_bg) root.themeBoardBg = data.board_bg || data.grid_bg;
        if (data.card_bg) root.themeCardBg = data.card_bg;
        if (data.border) root.themeBorder = data.border;
        if (data.fg) root.themeFg = data.fg;
        if (data.subtext) root.themeSubtext = data.subtext;
        if (data.accent) root.themeAccent = data.accent;
    }

    function playSound(soundName) {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(soundName);
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        soundToast.show(root.isMuted ? "Audio Muted" : "Audio Active");
    }

    function togglePause() {
        root.isPaused = !root.isPaused;
        Engine.setPaused(root.isPaused);
        soundToast.show(root.isPaused ? "Game Paused" : "Resumed");
    }

    function openHelp() {
        if (!root.showHelp) {
            if (!root.isPaused && Engine.gameState === "playing") {
                root.pausedByHelp = true;
                root.togglePause();
            } else {
                root.pausedByHelp = false;
            }
            root.showHelp = true;
        }
    }

    function closeHelp() {
        if (root.showHelp) {
            root.showHelp = false;
            if (root.pausedByHelp) {
                root.pausedByHelp = false;
                if (root.isPaused && Engine.gameState === "playing") {
                    root.togglePause();
                }
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
        playSound("click");
        soundToast.show("Selected " + root.activeCharData.name);
        gameCanvas.requestPaint();
    }

    function restartGame() {
        if (root.showHelp) closeHelp();
        Engine.resetGame();
        root.isPaused = false;
        Engine.setPaused(false);
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
        Behavior on color { ColorAnimation { duration: 150 } }

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

            if (event.key === Qt.Key_F) {
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
        // TIER 1: 2048 STANDARD HEADER
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? 16 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 64 : 0

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
                    text: "SlimeSpikes"
                    font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.07))
                    font.bold: true
                    color: root.activeCharData ? root.activeCharData.color : root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Japanese Crane-Game Gravity Runner"
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
                    height: 52
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "DISTANCE"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: Engine.distance.toString() + "m"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeFg
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Best Distance Card
                Rectangle {
                    width: Math.max(68, Math.min(95, headerItem.width * 0.17))
                    height: 52
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "BEST"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: Engine.bestDistance.toString() + "m"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.activeCharData ? root.activeCharData.color : root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 2: ACTION SUBHEADER & CHARACTER SELECT BAR
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 12 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 34 : 0

            property bool isCrowded: width < 480

            // Left: How to Play + Character Picker Toggle
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
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

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
                    color: charPickerMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
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
                    color: fullMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: fullMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.fullPlayfield ? "🔲" : "⛶"
                        font.pixelSize: 11
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
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
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

        // =====================================================================
        // SLIME CHARACTER SELECTION TRAY (6 Plushie Variants)
        // =====================================================================
        Rectangle {
            id: charSelectTray
            visible: root.showCharPicker && !root.isTiledDesktopMode
            anchors.top: subheaderItem.bottom
            anchors.topMargin: visible ? 8 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 56 : 0
            radius: 10
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            z: 80

            Row {
                anchors.centerIn: parent
                spacing: 10

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
                        width: Math.min(84, (charSelectTray.width - 70) / 6)
                        height: 38
                        radius: 6
                        color: Engine.selectedCharacter === modelData.id ? Qt.darker(modelData.color, 2.2) : root.themeBoardBg
                        border.color: Engine.selectedCharacter === modelData.id ? modelData.color : root.themeBorder
                        border.width: Engine.selectedCharacter === modelData.id ? 2 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            // Little teardrop color circle
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
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectSlime(modelData.id)
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
            anchors.top: charSelectTray.visible ? charSelectTray.bottom : (subheaderItem.visible ? subheaderItem.bottom : parent.top)
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.rightMargin: root.isTiledDesktopMode ? 0 : 16

            Rectangle {
                id: boardBorder
                anchors.fill: parent
                radius: root.isTiledDesktopMode ? 0 : 12
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: root.isTiledDesktopMode ? 0 : 1
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
                    color: "#e6181825"
                    border.color: root.themeBorder
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
                            color: root.activeCharData ? root.activeCharData.color : root.themeAccent
                        }

                        Text {
                            text: "• " + Engine.distance + "m"
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeFg
                        }

                        Text {
                            text: "(BEST: " + Engine.bestDistance + "m)"
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
                            text: "Distance: " + Engine.distance + "m"
                            color: root.themeFg
                            font.pixelSize: 20
                            font.bold: true
                            font.family: root.monoFontFamily
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Best: " + Engine.bestDistance + "m"
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
                            text: "Distance: " + Engine.distance + "m • Slime: " + (root.activeCharData ? root.activeCharData.name : "")
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
            color: "#e611111b"
            border.color: root.themeBorder
            border.width: 1
            z: 1200

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: soundToast.message
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
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
