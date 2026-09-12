import QtQuick
import QtQuick.Window
import "FoxEngine.js" as Engine
import "Levels.js" as Levels

Window {
    id: root
    visible: true
    width: 520
    height: 720
    minimumWidth: 320
    minimumHeight: 440
    title: "Foxtail • Cozy Woodland Path Puzzle"

    // =========================================================================
    // OMARCHY THEME TOKENS
    // =========================================================================
    property color themeBg: "#1e1e2e"
    property color themeBoardBg: "#181825"
    property color themeCardBg: "#313244"
    property color themeBorder: "#45475a"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#f97316" // Cozy warm Fox Orange
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    // Signature Fox Fur Palette (Rich burnt orange, warm highlights)
    property color foxFurColor: "#f97316"
    property color foxFurHighlight: "#fdba74"
    property color foxFurShadow: "#c2410c"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // GAME STATE
    // =========================================================================
    property int currentLevel: 1
    property string levelName: "First Snow"
    property int totalLevels: Levels.getLevelCount()
    property int filledTiles: 1
    property int totalPassable: 16
    property int progressPercent: 6
    property int movesCount: 0
    property bool isWon: false
    property bool canUndo: false
    property string facing: "right"
    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false
    property bool showLevelSelect: false
    property bool isBlinking: false
    onIsBlinkingChanged: gameCanvas.requestPaint()
    property bool isStuck: false
    onIsStuckChanged: gameCanvas.requestPaint()
    property real playfieldShakeX: 0
    property bool hintActive: false
    property int hintDx: 0
    property int hintDy: 0
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Slide: Arrow Keys, WASD, or Mouse Swipe\n• Goal: Fill 100% of the snow clearing with your fluffy tail!\n• The fox dashes until hitting a tree stump, trench wall, or its tail\n• Hint: H or 💡 button\n• Undo: U or Z\n• Restart: R\n• Level Select: L\n• Next / Prev: N / P\n• Full Playfield: Shift+F\n• Audio: M\n• Help: ? or Esc"

    // Immediate initial blink when level starts so the user sees it right away
    Timer {
        id: initialBlinkTimer
        interval: 900
        running: true
        repeat: false
        onTriggered: {
            if (!root.isWon) {
                root.isBlinking = true;
                gameCanvas.requestPaint();
                blinkCloseTimer.start();
            }
        }
    }

    // Regular blink loop
    Timer {
        id: blinkTimer
        interval: 2600
        running: !root.isWon
        repeat: true
        onTriggered: {
            root.isBlinking = true;
            gameCanvas.requestPaint();
            blinkCloseTimer.start();
        }
    }

    Timer {
        id: blinkCloseTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.isBlinking = false;
            gameCanvas.requestPaint();
            // 30% chance for an adorable quick double-blink
            if (Math.random() < 0.32) {
                doubleBlinkTimer.start();
            }
        }
    }

    Timer {
        id: doubleBlinkTimer
        interval: 110
        repeat: false
        onTriggered: {
            if (!root.isWon) {
                root.isBlinking = true;
                gameCanvas.requestPaint();
                doubleBlinkCloseTimer.start();
            }
        }
    }

    Timer {
        id: doubleBlinkCloseTimer
        interval: 170
        repeat: false
        onTriggered: {
            root.isBlinking = false;
            gameCanvas.requestPaint();
        }
    }

    Timer {
        id: hintTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.hintActive = false;
            gameCanvas.requestPaint();
        }
    }

    // Auto-reset when stuck / out of moves
    Timer {
        id: autoResetTimer
        interval: 1100
        repeat: false
        onTriggered: {
            if (root.isStuck && !root.isWon) {
                restartLevel();
                soundToast.show("↺ Level reset — try again!");
            }
        }
    }

    // Haptic screen rattle / wobble when hitting a dead end
    SequentialAnimation {
        id: stuckShakeAnim
        NumberAnimation { target: root; property: "playfieldShakeX"; to: -8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "playfieldShakeX"; to: 8; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "playfieldShakeX"; to: -6; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "playfieldShakeX"; to: 6; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "playfieldShakeX"; to: -3; duration: 40; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "playfieldShakeX"; to: 0; duration: 40; easing.type: Easing.OutQuad }
    }

    signal screenshotSaved(string filePath)

    // =========================================================================
    // THEME CONTROLLER
    // =========================================================================
    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#1e1e2e";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#f97316";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.06);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBorder = c8 || Qt.darker(bg, 1.15);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;

        gameCanvas.requestPaint();
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("select");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function syncState(state) {
        currentLevel = state.levelIndex;
        levelName = state.levelName;
        totalLevels = state.totalLevels;
        filledTiles = state.filledCount;
        totalPassable = state.totalPassable;
        progressPercent = state.progressPercent;
        movesCount = state.movesCount;
        isWon = state.isWon;
        isStuck = state.isStuck || false;
        canUndo = state.canUndo;
        facing = state.facing;
        gameCanvas.requestPaint();
    }

    function loadLevel(idx) {
        root.hintActive = false;
        root.isStuck = false;
        autoResetTimer.stop();
        root.playfieldShakeX = 0;
        var state = Engine.initLevel(idx);
        syncState(state);
        initialBlinkTimer.restart();
        playSound("click");
    }

    function triggerHint() {
        if (root.isWon) return;
        var h = Engine.getHint();
        if (!h) return;
        
        if (h.status === "ok") {
            playSound("click");
            soundToast.show("💡 Hint: " + h.message);
            root.hintActive = true;
            root.hintDx = h.dx;
            root.hintDy = h.dy;
            hintTimer.restart();
            gameCanvas.requestPaint();
        } else {
            playSound("dock");
            soundToast.show("💡 " + h.message);
        }
    }

    function move(dirX, dirY) {
        root.hintActive = false;
        var didMove = Engine.slide(dirX, dirY, {
            onStep: function(steps) {
                playSound("snow_crunch");
            },
            onBump: function() {
                playSound("dock");
            },
            onWin: function(moves) {
                root.isStuck = false;
                autoResetTimer.stop();
                playSound("win");
                winBannerAnim.restart();
            },
            onStuck: function(moves) {
                root.isStuck = true;
                playSound("game_over");
                stuckShakeAnim.restart();
                soundToast.show("❄️ Trapped! Resetting in 1s...");
                autoResetTimer.restart();
            }
        });
        syncState(Engine.getGameState());
        return didMove;
    }

    function undoMove() {
        root.hintActive = false;
        root.isStuck = false;
        autoResetTimer.stop();
        root.playfieldShakeX = 0;
        var didUndo = Engine.undo({
            onUndo: function() {
                playSound("undo");
            }
        });
        syncState(Engine.getGameState());
        return didUndo;
    }

    function restartLevel() {
        root.hintActive = false;
        root.isStuck = false;
        autoResetTimer.stop();
        root.playfieldShakeX = 0;
        var state = Engine.reset({
            onReset: function() {
                playSound("click");
            }
        });
        syncState(state);
    }

    function nextLevel() {
        var state = Engine.nextLevel();
        syncState(state);
        playSound("select");
    }

    function prevLevel() {
        var state = Engine.prevLevel();
        syncState(state);
        playSound("select");
    }

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : mainContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    Component.onCompleted: {
        var state = Engine.initLevel(1);
        syncState(state);
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLER
    // =========================================================================
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

            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.showLevelSelect) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_L) {
                    root.showLevelSelect = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.isWon) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_N) {
                    root.nextLevel();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Playfield View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.restartLevel();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U || event.key === Qt.Key_Z) {
                root.undoMove();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_L) {
                root.showLevelSelect = !root.showLevelSelect;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_N || event.key === Qt.Key_BracketRight) {
                root.nextLevel();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P || event.key === Qt.Key_BracketLeft) {
                root.prevLevel();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_Escape) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_H) {
                root.triggerHint();
                event.accepted = true;
                return;
            }

            // Directional Slides
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                root.move(-1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                root.move(1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                root.move(0, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.move(0, 1);
                event.accepted = true;
            }
        }

        // =====================================================================
        // TIER 1: HEADER (Title & Stats)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? 14 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? Math.max(titleCol.height, statsRow.height) : 0

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: statsRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 8
                    Text {
                        text: "🦊 Foxtail"
                        font.pixelSize: Math.max(20, Math.min(28, headerItem.width * 0.065))
                        font.bold: true
                        color: root.themeAccent
                    }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.levelName + " • Level " + root.currentLevel + "/" + root.totalLevels
                    font.pixelSize: Math.max(11, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                }
            }

            // Stat Cards on the right
            Row {
                id: statsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // FILL % Card
                Rectangle {
                    width: Math.max(64, Math.min(80, headerItem.width * 0.16))
                    height: 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "FILLED"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.progressPercent + "%"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.isWon ? "#22c55e" : root.themeFg
                        }
                    }
                }

                // TILES LEFT Card
                Rectangle {
                    width: Math.max(64, Math.min(80, headerItem.width * 0.16))
                    height: 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "TILES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.filledTiles + "/" + root.totalPassable
                            font.pixelSize: 14
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 2: ACTION BAR
        // =====================================================================
        Item {
            id: actionBar
            anchors.top: headerItem.visible ? headerItem.bottom : parent.top
            anchors.topMargin: headerItem.visible ? 10 : 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 38

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Help Button
                Rectangle {
                    height: 34
                    width: (actionBar.width < 440) ? 38 : 100
                    radius: 6
                    color: helpMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.1) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "?"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeFg
                        }
                        Text {
                            visible: actionBar.width >= 440
                            text: "Help"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHelp = !root.showHelp;
                            root.playSound("click");
                        }
                    }
                }

                // Full-Playfield Toggle Pill
                Rectangle {
                    height: 34
                    width: (actionBar.width < 440) ? 38 : 78
                    radius: 6
                    color: fullMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.1) : (root.fullPlayfield ? root.themeAccent : root.themeCardBg)
                    border.color: root.fullPlayfield ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "⛶"
                            font.pixelSize: 13
                            color: root.fullPlayfield ? root.themeBtnFg : root.themeFg
                        }
                        Text {
                            visible: actionBar.width >= 440
                            text: "⇧F"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.fullPlayfield ? root.themeBtnFg : root.themeSubtext
                        }
                    }

                    MouseArea {
                        id: fullMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            root.playSound("click");
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Hint Button
                Rectangle {
                    height: 34
                    width: (actionBar.width < 440) ? 38 : 84
                    radius: 6
                    color: hintMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.1) : root.themeCardBg
                    border.color: root.hintActive ? "#facc15" : root.themeBorder
                    border.width: root.hintActive ? 2 : 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "💡"
                            font.pixelSize: 13
                        }
                        Text {
                            visible: actionBar.width >= 440
                            text: "Hint (H)"
                            font.pixelSize: 12
                            font.bold: root.hintActive
                            color: root.hintActive ? "#eab308" : root.themeFg
                        }
                    }

                    MouseArea {
                        id: hintMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerHint()
                    }
                }

                // Audio Mute Button
                Rectangle {
                    height: 34
                    width: (actionBar.width < 440) ? 38 : 88
                    radius: 6
                    color: muteMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.1) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 13
                        }
                        Text {
                            visible: actionBar.width >= 440
                            text: root.isMuted ? "Muted" : "Sound"
                            font.pixelSize: 12
                            color: root.themeFg
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

                // Restart Button
                Rectangle {
                    height: 34
                    width: (actionBar.width < 440) ? 38 : 96
                    radius: 6
                    color: restartMouse.containsMouse ? Qt.darker(root.themeBtnBg, 1.1) : root.themeBtnBg

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "🔄"
                            font.pixelSize: 12
                        }
                        Text {
                            visible: actionBar.width >= 440
                            text: "Restart (R)"
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeBtnFg
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartLevel()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Rectangle {
            id: boardContainer
            anchors.top: actionBar.bottom
            anchors.topMargin: 8
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: (root.fullPlayfield ? 6 : 16) + root.playfieldShakeX
            anchors.rightMargin: (root.fullPlayfield ? 6 : 16) - root.playfieldShakeX
            radius: 12
            color: "#e5f0f8"
            border.color: root.isStuck ? "#f87171" : "#c2d9ea"
            border.width: root.isStuck ? 3 : 2
            clip: true

            Canvas {
                id: gameCanvas
                anchors.fill: parent
                antialiasing: true

                property real zzzTimer: 0
                property real snowAnim: 0

                Timer {
                    id: snowTimer
                    interval: 40
                    running: Qt.application.state === Qt.ApplicationActive
                    repeat: true
                    onTriggered: {
                        gameCanvas.snowAnim += 0.02;
                        if (root.isWon) {
                            gameCanvas.zzzTimer += 0.06;
                        }
                        gameCanvas.requestPaint();
                    }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // 1. Pristine Winter Snow Field Background
                    ctx.fillStyle = "#e5f0f8";
                    ctx.fillRect(0, 0, width, height);

                    // Scattered Soft Snow Powder Divots
                    drawSnowDivots(ctx, width, height);

                    // Scattered Ice Sparkles
                    drawIceSparkles(ctx, width, height);

                    // Ambient Drifting Snowflakes
                    drawFallingFlakes(ctx, width, height, snowAnim);

                    var state = Engine.getGameState();
                    var gw = state.width;
                    var gh = state.height;
                    var path = state.path;
                    var grid = state.grid;

                    if (!grid || grid.length === 0) return;

                    var pad = 24;
                    var availW = width - pad * 2;
                    var availH = height - pad * 2;
                    var cellSize = Math.floor(Math.min(availW / gw, availH / gh));
                    var boardW = cellSize * gw;
                    var boardH = cellSize * gh;
                    var ox = Math.floor((width - boardW) / 2);
                    var oy = Math.floor((height - boardH) / 2);

                    function isTrench(c, r) {
                        if (c >= 0 && c < gw && r >= 0 && r < gh) {
                            return grid[r][c] !== 3;
                        }
                        return false;
                    }

                    function isFloor(c, r) {
                        if (c >= 0 && c < gw && r >= 0 && r < gh) {
                            return grid[r][c] === 0 || grid[r][c] === 2;
                        }
                        return false;
                    }

                    // 2. Deep Carved Snow Trench Floor (Packed Arctic Blue Snow)
                    ctx.fillStyle = "#7aaec9";
                    for (var r = 0; r < gh; r++) {
                        for (var c = 0; c < gw; c++) {
                            if (isFloor(c, r)) {
                                ctx.fillRect(ox + c * cellSize, oy + r * cellSize, cellSize, cellSize);
                            }
                        }
                    }

                    // 3. 3D Trench Inner Wall Drop Shadows (Deep Winter Ambient Shadows)
                    var shadowDepth = Math.max(14, Math.floor(cellSize * 0.32));
                    for (var sr = 0; sr < gh; sr++) {
                        for (var sc = 0; sc < gw; sc++) {
                            if (isFloor(sc, sr)) {
                                var cellX = ox + sc * cellSize;
                                var cellY = oy + sr * cellSize;

                                // Top wall shadow (casts downward into trench)
                                if (!isFloor(sc, sr - 1)) {
                                    var gradTop = ctx.createLinearGradient(cellX, cellY, cellX, cellY + shadowDepth);
                                    gradTop.addColorStop(0.0, "rgba(38, 70, 95, 0.80)");
                                    gradTop.addColorStop(1.0, "rgba(38, 70, 95, 0.0)");
                                    ctx.fillStyle = gradTop;
                                    ctx.fillRect(cellX, cellY, cellSize, shadowDepth);
                                }

                                // Left wall shadow (casts rightward into trench)
                                if (!isFloor(sc - 1, sr)) {
                                    var gradLeft = ctx.createLinearGradient(cellX, cellY, cellX + shadowDepth, cellY);
                                    gradLeft.addColorStop(0.0, "rgba(45, 80, 105, 0.80)");
                                    gradLeft.addColorStop(1.0, "rgba(45, 80, 105, 0.0)");
                                    ctx.fillStyle = gradLeft;
                                    ctx.fillRect(cellX, cellY, shadowDepth, cellSize);
                                }

                                // Right wall subtle ambient shadow
                                if (!isFloor(sc + 1, sr)) {
                                    var rDepth = Math.floor(shadowDepth * 0.55);
                                    var gradRight = ctx.createLinearGradient(cellX + cellSize, cellY, cellX + cellSize - rDepth, cellY);
                                    gradRight.addColorStop(0.0, "rgba(40, 75, 100, 0.40)");
                                    gradRight.addColorStop(1.0, "rgba(40, 75, 100, 0.0)");
                                    ctx.fillStyle = gradRight;
                                    ctx.fillRect(cellX + cellSize - rDepth, cellY, rDepth, cellSize);
                                }
                            }
                        }
                    }

                    // 4. Obstacle Tree Stumps with Snow Caps & 2.5D Drop Shadows
                    for (var or = 0; or < gh; or++) {
                        for (var oc = 0; oc < gw; oc++) {
                            if (grid[or][oc] === 1) {
                                var oxPos = ox + oc * cellSize;
                                var oyPos = oy + or * cellSize;

                                // 2.5D Drop Shadow to the right and bottom
                                var sDist = Math.max(10, Math.floor(cellSize * 0.22));
                                ctx.save();
                                ctx.fillStyle = "rgba(38, 70, 95, 0.70)";

                                // Right shadow
                                ctx.beginPath();
                                ctx.moveTo(oxPos + cellSize, oyPos);
                                ctx.lineTo(oxPos + cellSize, oyPos + cellSize);
                                ctx.lineTo(oxPos + cellSize + sDist, oyPos + cellSize + sDist);
                                ctx.lineTo(oxPos + cellSize + sDist, oyPos + sDist);
                                ctx.closePath();
                                ctx.fill();

                                // Bottom shadow
                                ctx.beginPath();
                                ctx.moveTo(oxPos, oyPos + cellSize);
                                ctx.lineTo(oxPos + cellSize, oyPos + cellSize);
                                ctx.lineTo(oxPos + cellSize + sDist, oyPos + cellSize + sDist);
                                ctx.lineTo(oxPos + sDist, oyPos + cellSize + sDist);
                                ctx.closePath();
                                ctx.fill();
                                ctx.restore();

                                // Tree Stump Face with Snow Cap
                                drawSnowyTreeStump(ctx, oxPos, oyPos, cellSize);
                            }
                        }
                    }

                    // 5. Crisp White Perimeter Contour Border (Outer trench + obstacles)
                    ctx.save();
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 7;
                    ctx.lineCap = "square";
                    ctx.lineJoin = "miter";

                    // Outer trench edges
                    for (var br = 0; br < gh; br++) {
                        for (var bc = 0; bc < gw; bc++) {
                            if (isTrench(bc, br)) {
                                var bx = ox + bc * cellSize;
                                var by = oy + br * cellSize;

                                if (!isTrench(bc, br - 1)) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx, by);
                                    ctx.lineTo(bx + cellSize, by);
                                    ctx.stroke();
                                }
                                if (!isTrench(bc, br + 1)) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx, by + cellSize);
                                    ctx.lineTo(bx + cellSize, by + cellSize);
                                    ctx.stroke();
                                }
                                if (!isTrench(bc - 1, br)) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx, by);
                                    ctx.lineTo(bx, by + cellSize);
                                    ctx.stroke();
                                }
                                if (!isTrench(bc + 1, br)) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx + cellSize, by);
                                    ctx.lineTo(bx + cellSize, by + cellSize);
                                    ctx.stroke();
                                }
                            }
                        }
                    }

                    // White border around Obstacle Tree Stumps
                    for (var obr = 0; obr < gh; obr++) {
                        for (var obc = 0; obc < gw; obc++) {
                            if (grid[obr][obc] === 1) {
                                ctx.strokeRect(ox + obc * cellSize, oy + obr * cellSize, cellSize, cellSize);
                            }
                        }
                    }
                    ctx.restore();

                    // 6. Draw Fox Tail Body (Contiguous Orange Voxel Body in Trench)
                    if (path && path.length > 0) {
                        drawVoxelFoxBody(ctx, path, ox, oy, cellSize);
                    }

                    // 7. Draw Voxel Fox Head (with blink animation)
                    if (path && path.length > 0) {
                        var head = path[path.length - 1];
                        var hx = ox + head.x * cellSize;
                        var hy = oy + head.y * cellSize;
                        drawVoxelFoxHead(ctx, hx, hy, cellSize, state.facing || root.facing, root.isWon, root.isBlinking, root.isStuck);
                    }

                    // 8. If Won: Floating "Zzz" sleeping particles
                    if (root.isWon && path && path.length > 0) {
                        var winHead = path[path.length - 1];
                        drawSleepParticles(ctx, ox + winHead.x * cellSize, oy + winHead.y * cellSize, cellSize, gameCanvas.zzzTimer);
                    }

                    // 9. If Hint Active: Draw glowing animated hint arrow
                    if (root.hintActive && path && path.length > 0) {
                        var hintHead = path[path.length - 1];
                        var hintCx = ox + (hintHead.x + 0.5) * cellSize;
                        var hintCy = oy + (hintHead.y + 0.5) * cellSize;
                        drawHintArrow(ctx, hintCx, hintCy, cellSize, root.hintDx, root.hintDy, gameCanvas.snowAnim);
                    }
                }

                function drawHintArrow(ctx, cx, cy, size, dx, dy, anim) {
                    if (dx === 0 && dy === 0) return;
                    ctx.save();
                    var offset = size * 0.72 + Math.sin(anim * 8) * 5;
                    var ax = cx + dx * offset;
                    var ay = cy + dy * offset;
                    var angle = Math.atan2(dy, dx);

                    ctx.translate(ax, ay);
                    ctx.rotate(angle);

                    // Glowing golden arrow
                    ctx.fillStyle = "#fbbf24";
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 2.5;

                    var aLen = Math.max(16, Math.floor(size * 0.32));
                    var aW = Math.max(10, Math.floor(size * 0.20));

                    ctx.beginPath();
                    ctx.moveTo(aLen, 0);
                    ctx.lineTo(0, -aW);
                    ctx.lineTo(aLen * 0.25, -aW * 0.4);
                    ctx.lineTo(-aLen * 0.5, -aW * 0.4);
                    ctx.lineTo(-aLen * 0.5, aW * 0.4);
                    ctx.lineTo(aLen * 0.25, aW * 0.4);
                    ctx.lineTo(0, aW);
                    ctx.closePath();
                    ctx.fill();
                    ctx.stroke();

                    ctx.restore();
                }

                function drawSnowDivots(ctx, w, h) {
                    var divots = [
                        {x: 50, y: 65}, {x: w - 70, y: 95}, {x: w - 85, y: h - 110},
                        {x: 65, y: h * 0.55}, {x: 75, y: h - 85}, {x: w - 120, y: 60},
                        {x: w * 0.48, y: 45}, {x: w * 0.52, y: h - 55}
                    ];
                    for (var i = 0; i < divots.length; i++) {
                        var d = divots[i];
                        ctx.fillStyle = "#d0e3f0";
                        ctx.fillRect(d.x, d.y, 16, 16);
                        ctx.fillStyle = "#c3daf0";
                        ctx.fillRect(d.x + 2, d.y + 2, 12, 12);
                        ctx.fillStyle = "rgba(255, 255, 255, 0.75)";
                        ctx.fillRect(d.x + 1, d.y + 1, 14, 2);
                    }
                }

                function drawIceSparkles(ctx, w, h) {
                    var sparkles = [
                        {x: w - 80, y: 155}, {x: w - 45, y: 200}, {x: w - 105, y: h - 90},
                        {x: w - 65, y: h - 60}, {x: 75, y: 120}, {x: 55, y: h * 0.72}
                    ];
                    var s = 5;
                    for (var i = 0; i < sparkles.length; i++) {
                        var f = sparkles[i];
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(f.x, f.y - s, s, s);
                        ctx.fillRect(f.x, f.y + s, s, s);
                        ctx.fillRect(f.x - s, f.y, s, s);
                        ctx.fillRect(f.x + s, f.y, s, s);
                        ctx.fillStyle = "#bce3fa";
                        ctx.fillRect(f.x, f.y, s, s);
                    }
                }

                function drawFallingFlakes(ctx, w, h, anim) {
                    ctx.save();
                    ctx.fillStyle = "rgba(255, 255, 255, 0.75)";
                    var flakeCount = 18;
                    for (var f = 0; f < flakeCount; f++) {
                        var seedX = ((f * 137.5) % w);
                        var speed = 30 + (f % 5) * 12;
                        var flakeY = ((anim * speed * 25 + f * 47) % (h + 20)) - 10;
                        var driftX = seedX + Math.sin(anim * 2 + f) * 14;
                        var fSize = 2 + (f % 3);
                        ctx.fillRect(driftX, flakeY, fSize, fSize);
                    }
                    ctx.restore();
                }

                function drawSnowyTreeStump(ctx, x, y, size) {
                    ctx.save();
                    // Dark outer frosty bark
                    ctx.fillStyle = "#422919";
                    ctx.fillRect(x, y, size, size);

                    // Cut timber heartwood top face
                    var inset = Math.max(4, Math.floor(size * 0.08));
                    ctx.fillStyle = "#c49466";
                    ctx.fillRect(x + inset, y + inset, size - inset * 2, size - inset * 2);

                    // Concentric growth rings
                    ctx.strokeStyle = "#b58051";
                    ctx.lineWidth = 2;
                    var cx = x + size * 0.5;
                    var cy = y + size * 0.5;

                    ctx.beginPath();
                    ctx.arc(cx, cy, size * 0.30, 0, Math.PI * 2);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(cx, cy, size * 0.16, 0, Math.PI * 2);
                    ctx.stroke();

                    // Puffy Snow Cap resting on top of the stump
                    var snowH = Math.floor(size * 0.38);
                    ctx.fillStyle = "#c8dff0"; // snow shadow bottom
                    ctx.fillRect(x + inset, y + inset + snowH - 3, size - inset * 2, 4);

                    ctx.fillStyle = "#ffffff"; // pure white snow cap
                    ctx.fillRect(x + inset, y + inset, size - inset * 2, snowH - 3);

                    // Little scalloped puffy snow peaks
                    var scallops = 3;
                    var scW = (size - inset * 2) / scallops;
                    for (var s = 0; s < scallops; s++) {
                        var scX = x + inset + s * scW;
                        ctx.beginPath();
                        ctx.arc(scX + scW * 0.5, y + inset + snowH - 2, scW * 0.45, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    ctx.restore();
                }

                function drawVoxelFoxBody(ctx, path, ox, oy, cellSize) {
                    ctx.save();

                    // Build lookup of all body positions
                    var bodyMap = {};
                    for (var b = 0; b < path.length; b++) {
                        bodyMap[path[b].x + "," + path[b].y] = true;
                    }

                    var toothSize = Math.max(3, Math.floor(cellSize * 0.085));
                    var toothStep = toothSize * 2;

                    // 1. Draw solid body segments (from tail to neck)
                    for (var i = 0; i < path.length - 1; i++) {
                        var cell = path[i];
                        var cx = ox + cell.x * cellSize;
                        var cy = oy + cell.y * cellSize;

                        // Solid warm fiery fox orange
                        ctx.fillStyle = "#fa7014";
                        ctx.fillRect(cx, cy, cellSize, cellSize);

                        // Cute outer border fur teeth/notches (Longcat aesthetic along perimeter)
                        ctx.fillStyle = "#fbbf24";

                        // Top outer edge?
                        if (!bodyMap[cell.x + "," + (cell.y - 1)]) {
                            for (var tx = 2; tx <= cellSize - toothSize - 2; tx += toothStep) {
                                ctx.fillRect(cx + tx, cy, toothSize, toothSize);
                            }
                        }
                        // Bottom outer edge?
                        if (!bodyMap[cell.x + "," + (cell.y + 1)]) {
                            for (var bx = 2; bx <= cellSize - toothSize - 2; bx += toothStep) {
                                ctx.fillRect(cx + bx, cy + cellSize - toothSize, toothSize, toothSize);
                            }
                        }
                        // Left outer edge?
                        if (!bodyMap[(cell.x - 1) + "," + cell.y]) {
                            for (var ly = 2; ly <= cellSize - toothSize - 2; ly += toothStep) {
                                ctx.fillRect(cx, cy + ly, toothSize, toothSize);
                            }
                        }
                        // Right outer edge?
                        if (!bodyMap[(cell.x + 1) + "," + cell.y]) {
                            for (var ry = 2; ry <= cellSize - toothSize - 2; ry += toothStep) {
                                ctx.fillRect(cx + cellSize - toothSize, cy + ry, toothSize, toothSize);
                            }
                        }
                    }

                    // 2. White fluffy tail tip at start position (path[0])
                    var st = path[0];
                    var stX = ox + st.x * cellSize;
                    var stY = oy + st.y * cellSize;
                    var tipMargin = Math.max(8, Math.floor(cellSize * 0.20));
                    ctx.fillStyle = "#ffffff";
                    ctx.fillRect(stX + tipMargin, stY + tipMargin, cellSize - tipMargin * 2, cellSize - tipMargin * 2);

                    ctx.restore();
                }

                function drawVoxelFoxHead(ctx, hx, hy, size, facingDir, won, blinking, stuck) {
                    ctx.save();
                    ctx.translate(hx + size * 0.5, hy + size * 0.5);

                    var angle = 0;
                    if (facingDir === "down") angle = 0;
                    else if (facingDir === "left") angle = Math.PI * 0.5;
                    else if (facingDir === "right") angle = -Math.PI * 0.5;
                    else if (facingDir === "up") angle = Math.PI;
                    ctx.rotate(angle);

                    var half = size * 0.5;

                    // Top Orange Cranium, Bottom White Muzzle
                    ctx.fillStyle = "#fa7014";
                    ctx.fillRect(-half, -half, size, half);

                    ctx.fillStyle = "#ffffff";
                    ctx.fillRect(-half, 0, size, half);

                    // Pointed Fox Ears on top edge
                    var earW = Math.max(8, Math.floor(size * 0.20));
                    var earH = Math.max(8, Math.floor(size * 0.18));

                    // Dark Ear Tips
                    ctx.fillStyle = "#1e293b";
                    ctx.fillRect(-half + 5, -half, earW, earH);
                    ctx.fillRect(half - 5 - earW, -half, earW, earH);

                    // Cream Inner Ear
                    ctx.fillStyle = "#fed7aa";
                    ctx.fillRect(-half + 7, -half + 3, earW - 4, earH - 5);
                    ctx.fillRect(half - 3 - earW, -half + 3, earW - 4, earH - 5);

                    // Eyes
                    var eyeW = Math.max(5, Math.floor(size * 0.11));
                    var eyeH = Math.max(9, Math.floor(size * 0.20));
                    var eyeY = -half * 0.08;

                    if (won) {
                        // Happy closed sleeping eyes (^ _ ^)
                        ctx.strokeStyle = "#0f172a";
                        ctx.lineWidth = 2.5;
                        ctx.lineCap = "round";

                        ctx.beginPath();
                        ctx.arc(-half * 0.45, eyeY + 4, eyeW * 0.8, Math.PI, 0);
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.arc(half * 0.45, eyeY + 4, eyeW * 0.8, Math.PI, 0);
                        ctx.stroke();
                    } else if (stuck) {
                        // Comical bonked / dizzy squinting eyes (> <)
                        ctx.strokeStyle = "#0f172a";
                        ctx.lineWidth = Math.max(3, Math.floor(size * 0.07));
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        var eyeYMid = eyeY + eyeH * 0.55;
                        var leftCenterX = -half * 0.52 + eyeW * 0.5;
                        var rightCenterX = half * 0.52 - eyeW * 0.5;
                        var sz = Math.max(4, Math.floor(eyeW * 0.8));

                        // Left >
                        ctx.beginPath();
                        ctx.moveTo(leftCenterX - sz, eyeYMid - sz);
                        ctx.lineTo(leftCenterX + sz * 0.6, eyeYMid);
                        ctx.lineTo(leftCenterX - sz, eyeYMid + sz);
                        ctx.stroke();

                        // Right <
                        ctx.beginPath();
                        ctx.moveTo(rightCenterX + sz, eyeYMid - sz);
                        ctx.lineTo(rightCenterX - sz * 0.6, eyeYMid);
                        ctx.lineTo(rightCenterX + sz, eyeYMid + sz);
                        ctx.stroke();

                        // Cartoon sweat droplet popping near temple
                        ctx.fillStyle = "#38bdf8";
                        var swX = half * 0.72;
                        var swY = -half * 0.55;
                        ctx.beginPath();
                        ctx.arc(swX, swY, Math.max(3, Math.floor(size * 0.08)), 0, Math.PI * 2);
                        ctx.fill();
                    } else if (blinking) {
                        // Bold, expressive closed eye slits (- -)
                        ctx.strokeStyle = "#0f172a";
                        ctx.lineWidth = Math.max(3, Math.floor(size * 0.065));
                        ctx.lineCap = "round";

                        var slitY = eyeY + eyeH * 0.55;
                        var leftCenterX = -half * 0.52 + eyeW * 0.5;
                        var rightCenterX = half * 0.52 - eyeW * 0.5;
                        var halfSpan = Math.max(5, Math.floor(eyeW * 0.85));

                        ctx.beginPath();
                        ctx.moveTo(leftCenterX - halfSpan, slitY);
                        ctx.lineTo(leftCenterX + halfSpan, slitY);
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.moveTo(rightCenterX - halfSpan, slitY);
                        ctx.lineTo(rightCenterX + halfSpan, slitY);
                        ctx.stroke();
                    } else {
                        // Vertical Black Rectangle Eyes (Longcat voxel style)
                        ctx.fillStyle = "#0f172a";
                        ctx.fillRect(-half * 0.52, eyeY, eyeW, eyeH);
                        ctx.fillRect(half * 0.52 - eyeW, eyeY, eyeW, eyeH);
                    }

                    // Cute Pink Square Nose in center
                    var noseW = Math.max(7, Math.floor(size * 0.16));
                    var noseH = Math.max(5, Math.floor(size * 0.12));
                    ctx.fillStyle = "#f472b6";
                    ctx.fillRect(-noseW * 0.5, eyeY + eyeH * 0.45, noseW, noseH);

                    ctx.restore();
                }

                function drawSleepParticles(ctx, hx, hy, size, timer) {
                    ctx.save();
                    ctx.font = "bold 16px sans-serif";
                    ctx.fillStyle = "rgba(250, 112, 20, 0.95)";

                    var cx = hx + size * 0.5;
                    var cy = hy + size * 0.5;

                    for (var z = 0; z < 3; z++) {
                        var progress = ((timer * 0.7 + z * 0.35) % 1.0);
                        var zx = cx + Math.sin(progress * Math.PI * 2) * 16 + (z * 12);
                        var zy = cy - (progress * 55) - (z * 10);
                        var alpha = Math.sin(progress * Math.PI);
                        var scale = 0.7 + progress * 0.6;

                        ctx.save();
                        ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
                        ctx.translate(zx, zy);
                        ctx.scale(scale, scale);
                        ctx.fillText("Z", 0, 0);
                        ctx.restore();
                    }

                    ctx.restore();
            }

            // Mouse / Touch Swipe Area
            MouseArea {
                id: swipeArea
                anchors.fill: parent
                preventStealing: true

                property real startX: 0
                property real startY: 0
                property bool isTracking: false

                onPressed: function(mouse) {
                    startX = mouse.x;
                    startY = mouse.y;
                    isTracking = true;
                }

                onPositionChanged: function(mouse) {
                    if (!isTracking) return;
                    var dx = mouse.x - startX;
                    var dy = mouse.y - startY;
                    var dist = Math.sqrt(dx * dx + dy * dy);

                    if (dist >= 28) {
                        isTracking = false;
                        if (Math.abs(dx) > Math.abs(dy)) {
                            root.move(dx > 0 ? 1 : -1, 0);
                        } else {
                            root.move(0, dy > 0 ? 1 : -1);
                        }
                    }
                }

                onReleased: {
                    isTracking = false;
                }
            }

            // Stage Clear Celebration Banner
            Rectangle {
                id: winBanner
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 340)
                height: 140
                radius: 14
                color: root.themeCardBg
                border.color: root.themeAccent
                border.width: 2
                visible: root.isWon
                opacity: root.isWon ? 1 : 0
                scale: root.isWon ? 1 : 0.85

                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "✨ CLEARING RESTED! ✨"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.themeAccent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "The fox curled up for a cozy nap!"
                        font.pixelSize: 13
                        color: root.themeFg
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 130
                            height: 36
                            radius: 8
                            color: root.themeAccent

                            Text {
                                anchors.centerIn: parent
                                text: "Next Level ▶"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeBtnFg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextLevel()
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 36
                            radius: 8
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Replay 🔄"
                                font.pixelSize: 13
                                color: root.themeFg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartLevel()
                            }
                        }
                    }
                }

                SequentialAnimation {
                    id: winBannerAnim
                    NumberAnimation { target: winBanner; property: "scale"; from: 0.8; to: 1.05; duration: 200; easing.type: Easing.OutQuad }
                    NumberAnimation { target: winBanner; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

        // =====================================================================
        // TIER 4: BOTTOM NAVIGATION BAR (Proportional Width Partitioning)
        // =====================================================================
        Item {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 42

            Row {
                anchors.fill: parent
                spacing: 8

                // 1. UNDO (26%)
                Rectangle {
                    width: (parent.width - 24) * 0.26
                    height: parent.height
                    radius: 8
                    color: root.canUndo ? (undoMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : root.themeCardBg) : Qt.rgba(Qt.color(root.themeCardBg).r, Qt.color(root.themeCardBg).g, Qt.color(root.themeCardBg).b, 0.4)
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "↶"
                            font.pixelSize: 15
                            color: root.canUndo ? root.themeAccent : root.themeSubtext
                        }
                        Text {
                            visible: bottomBar.width >= 400
                            text: "Undo (U)"
                            font.pixelSize: 12
                            font.bold: true
                            color: root.canUndo ? root.themeFg : root.themeSubtext
                        }
                    }

                    MouseArea {
                        id: undoMouse
                        anchors.fill: parent
                        enabled: root.canUndo
                        cursorShape: root.canUndo ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.undoMove()
                    }
                }

                // 2. STAGES (26%)
                Rectangle {
                    width: (parent.width - 24) * 0.26
                    height: parent.height
                    radius: 8
                    color: stagesMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "☰"
                            font.pixelSize: 14
                            color: root.themeFg
                        }
                        Text {
                            visible: bottomBar.width >= 400
                            text: "Stages (L)"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                    }

                    MouseArea {
                        id: stagesMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showLevelSelect = !root.showLevelSelect;
                            root.playSound("click");
                        }
                    }
                }

                // 3. PREV (24%)
                Rectangle {
                    width: (parent.width - 24) * 0.24
                    height: parent.height
                    radius: 8
                    color: prevMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "◀"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                        Text {
                            visible: bottomBar.width >= 400
                            text: "Prev"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevLevel()
                    }
                }

                // 4. NEXT (24%)
                Rectangle {
                    width: (parent.width - 24) * 0.24
                    height: parent.height
                    radius: 8
                    color: nextMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            visible: bottomBar.width >= 400
                            text: "Next"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                        Text {
                            text: "▶"
                            font.pixelSize: 12
                            color: root.themeFg
                        }
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextLevel()
                    }
                }
            }
        }

        // =====================================================================
        // LEVEL SELECT MODAL
        // =====================================================================
        Rectangle {
            id: levelSelectModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showLevelSelect
            z: 90

            MouseArea {
                anchors.fill: parent
                onClicked: root.showLevelSelect = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 460)
                height: Math.min(parent.height - 64, 520)
                radius: 14
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 2

                MouseArea {
                    anchors.fill: parent // Absorb clicks
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 28
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🌲 Select Clearing (Stage)"
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeAccent
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeSubtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showLevelSelect = false
                            }
                        }
                    }

                    Text {
                        text: "Choose any clearing to solve or replay:"
                        font.pixelSize: 12
                        color: root.themeSubtext
                    }

                    // Grid of 30 Stages
                    Flickable {
                        width: parent.width
                        height: parent.height - 70
                        contentHeight: stageGrid.height
                        clip: true

                        Grid {
                            id: stageGrid
                            columns: (levelSelectModal.width < 380) ? 5 : 6
                            spacing: 8
                            width: parent.width

                            Repeater {
                                model: root.totalLevels
                                delegate: Rectangle {
                                    width: (stageGrid.width - (stageGrid.columns - 1) * stageGrid.spacing) / stageGrid.columns
                                    height: width
                                    radius: 8
                                    color: (index + 1 === root.currentLevel) ? root.themeAccent : (stageBtnMouse.containsMouse ? Qt.darker(root.themeBoardBg, 1.2) : root.themeBoardBg)
                                    border.color: (index + 1 === root.currentLevel) ? root.themeAccent : root.themeBorder
                                    border.width: 1

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: (index + 1).toString()
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: (index + 1 === root.currentLevel) ? root.themeBtnFg : root.themeFg
                                        }
                                    }

                                    MouseArea {
                                        id: stageBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.loadLevel(index + 1);
                                            root.showLevelSelect = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // HOW TO PLAY MODAL (Standard Omarchy Arcade Template)
        // =====================================================================
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showHelp
            z: 95

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 450)
                height: Math.min(parent.height - 40, 520)
                radius: 14
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 2

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    // Modal Header
                    Item {
                        width: parent.width
                        height: 28
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🦊 HOW TO PLAY FOXTAIL"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeSubtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHelp = false
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.themeBorder
                    }

                    // Scrollable Help Content
                    Flickable {
                        width: parent.width
                        height: parent.height - 110
                        contentHeight: helpContentCol.implicitHeight
                        clip: true

                        Column {
                            id: helpContentCol
                            width: parent.width
                            spacing: 10

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Guide the clever voxel fox through snowy trench labyrinths. Every slide unfurls its impossibly fluffy bushy tail!"
                                font.pixelSize: 12
                                color: root.themeFg
                                lineHeight: 1.3
                            }

                            Row {
                                spacing: 8
                                Text { text: "🎯"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Objective:</b> Pack 100% of the snow clearing with your fluffy tail to solve each stage."
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.25
                                }
                            }

                            Row {
                                spacing: 8
                                Text { text: "⚡"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Slide Dash:</b> The fox sprints until hitting a tree stump, trench wall, or its own tail."
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.25
                                }
                            }

                            Row {
                                spacing: 8
                                Text { text: "❄️"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Dead-End & Auto-Reset:</b> If trapped with no available moves, the fox rattles and automatically resets in 1s (or press <b>U</b> to rewind)."
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.25
                                }
                            }

                            Row {
                                spacing: 8
                                Text { text: "💡"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Hint Button:</b> Press <b>H</b> or tap 💡 Hint to see a golden directional arrow pointing to the optimal move."
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.25
                                }
                            }

                            Row {
                                spacing: 8
                                Text { text: "💤"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Cozy Finish:</b> At 100% coverage, the fox curls up on its tail for a peaceful nap with floating Zzz particles!"
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.25
                                }
                            }

                            Row {
                                spacing: 8
                                Text { text: "⌨️"; font.pixelSize: 14 }
                                Text {
                                    width: parent.parent.width - 28
                                    wrapMode: Text.WordWrap
                                    text: "<b>Controls:</b> Arrow Keys, WASD, Vim H/J/K/L, or Mouse Swipe\n• <b>H</b>: Hint\n• <b>U / Z</b>: Undo move\n• <b>R</b>: Restart stage\n• <b>L</b>: Stage select modal\n• <b>N / P</b>: Next / Previous stage\n• <b>M</b>: Toggle Audio / Mute\n• <b>Shift+F</b>: Toggle full playfield\n• <b>? / Esc</b>: Help overlay"
                                    font.pixelSize: 11
                                    color: root.themeFg
                                    lineHeight: 1.3
                                }
                            }
                        }
                    }

                    // Action Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 130
                        height: 32
                        radius: 8
                        color: root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "GOT IT"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }

                    // Canonical Author Attribution
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Created by Chris Thompson (@bigcjat) with Gemini"
                        font.family: root.monoFontFamily
                        font.pixelSize: 9
                        color: root.themeSubtext
                        opacity: 0.8
                    }
                }
            }
        }

        // =====================================================================
        // SOUND TOAST NOTIFICATION
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64
            anchors.horizontalCenter: parent.horizontalCenter
            height: 36
            width: toastText.implicitWidth + 32
            radius: 18
            color: root.isStuck ? "#7f1d1d" : "#1e1e2e"
            border.color: root.isStuck ? "#ef4444" : "#45475a"
            border.width: root.isStuck ? 2 : 1
            opacity: 0
            visible: opacity > 0
            z: 100

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 12
                font.bold: true
                color: root.isStuck ? "#fef2f2" : "#ffffff"
            }

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; to: 1.0; duration: 150 }
                PauseAnimation { duration: 1400 }
                NumberAnimation { target: soundToast; property: "opacity"; to: 0.0; duration: 250 }
            }
        }
    }

    // =========================================================================
    // CANONICAL OMARCHY SPLASH SCREEN (DO NOT REMOVE OR MODIFY)
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled
        onDismissed: {
            root.splashEnabled = false;
            mainContainer.forceActiveFocus();
        }
    }
}
