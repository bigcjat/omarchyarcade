import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine
import "Themes.js" as OmarchyThemes

Window {
    id: root
    visible: true
    width: 520
    height: 680
    minimumWidth: 320
    minimumHeight: 460
    title: currentThemeName.length > 0 ? "TetraBlocks • " + currentThemeName : "TetraBlocks"

    // Dynamic Omarchy Theme Properties (Defaults to Catppuccin Mocha)
    property color themeBg: "#181825"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellEmpty: "#252538"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#fab387"
    property color themeBtnBg: "#89b4fa"
    property color themeBtnFg: "#11111b"
    property color themeBorder: "#45475a"
    property color themeModalBg: "#1e1e2e"
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: ""
    property bool splashEnabled: true
    property bool isMuted: true // Defaults to MUTED as requested
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    color: themeBg
    Behavior on color { ColorAnimation { duration: 250 } }

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
        themeAccent = data.accent || themeAccent;
        themeBtnBg = data.accent || themeBtnBg;
        themeBtnFg = data.background || "#11111b";
        themeBorder = data.color8 || data.color0 || themeBorder;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.08);
            themeCellEmpty = Qt.darker(bg, 1.15);
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.darker(themeFg, 1.4);
            themeModalBg = bg;
        } else {
            themeBoardBg = Qt.lighter(bg, 1.18);
            themeCellEmpty = Qt.lighter(bg, 1.32);
            themeCardBg = Qt.lighter(bg, 1.25);
            themeSubtext = data.color7 || Qt.darker(themeFg, 1.3);
            themeModalBg = Qt.lighter(bg, 1.12);
        }
    }

    // Piece colors derived from Omarchy theme palette
    function getPieceColor(colorId) {
        var p = themePalette;
        switch(colorId) {
            case 1: return p.color6 || p.color14 || "#89dceb"; // I: Cyan / Sky
            case 2: return p.color3 || p.color11 || "#f9e2af"; // O: Yellow
            case 3: return p.color5 || p.color13 || "#cba6f7"; // T: Purple / Mauve
            case 4: return p.color2 || p.color10 || "#a6e3a1"; // S: Green
            case 5: return p.color1 || p.color9  || "#f38ba8"; // Z: Red
            case 6: return p.color4 || p.color12 || "#89b4fa"; // J: Blue
            case 7: return p.color9 || p.accent  || "#fab387"; // L: Orange / Peach
            default: return "#45475a";
        }
    }

    // Audio handlers (zero-overhead early return when muted)
    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted) {
            playRotate();
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function playMove() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playMove();
    }

    function playRotate() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playRotate();
    }

    function playHardDrop() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playHardDrop();
    }

    function playLock() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playLock();
    }

    function playLineClear() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playLineClear();
    }

    function playQuadClear() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playQuadClear();
    }

    function playGameOver() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) soundManager.playGameOver();
    }

    // Game state properties
    property int score: 0
    property int bestScore: 0
    property int lines: 0
    property int level: 1
    property bool isOver: false
    property bool isPaused: false
    onIsPausedChanged: {
        if (isPaused) lockTimer.stop();
    }
    property bool showHelp: false
    property var lastDownPressTime: 0

    property var clearingRowIndices: []
    property bool isClearing: false
    property string clearBannerText: ""

    function handleLockResult(res) {
        root.lastDownPressTime = 0;
        if (res.linesCleared > 0) {
            root.isClearing = true;
            root.clearingRowIndices = res.clearedRows;

            var title = "";
            if (res.linesCleared === 1) title = "SINGLE";
            else if (res.linesCleared === 2) title = "DOUBLE";
            else if (res.linesCleared === 3) title = "TRIPLE";
            else if (res.linesCleared >= 4) title = res.isB2B ? "🔥 B2B TETRA! 🔥" : "★ TETRA! ★";

            root.clearBannerText = title + " +" + res.scoreGained;
            clearBannerAnim.restart();

            if (res.linesCleared >= 4) {
                playQuadClear();
            } else {
                playLineClear();
            }

            syncFromEngine();
            collapseTimer.clearedRows = res.clearedRows;
            collapseTimer.restart();
        } else {
            playLock();
            syncFromEngine();
        }
    }

    Timer {
        id: collapseTimer
        property var clearedRows: []
        interval: 180
        repeat: false
        onTriggered: {
            Engine.collapseRows(clearedRows);
            root.isClearing = false;
            root.clearingRowIndices = [];
            syncFromEngine();
        }
    }

    // Grid model: 200 items (20 rows x 10 cols)
    ListModel { id: gridModel }

    Component.onCompleted: {
        requestActivate();
        gameArea.forceActiveFocus();
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
            Engine.setBestScore(root.bestScore);
        }
        initGridModel();
        startNewGame();
    }

    function initGridModel() {
        gridModel.clear();
        for (var r = 2; r < 22; r++) {
            for (var c = 0; c < 10; c++) {
                gridModel.append({
                    "row": r,
                    "col": c,
                    "colorId": 0,
                    "isGhost": false,
                    "isActive": false,
                    "isClearing": false
                });
            }
        }
    }

    function startNewGame() {
        Engine.initGame();
        root.isOver = false;
        root.isPaused = false;
        syncFromEngine();
        gravityTimer.interval = Engine.getGravityInterval();
        gravityTimer.restart();
    }

    function syncFromEngine() {
        var st = Engine.getState();
        root.score = st.score;
        if (st.score > root.bestScore) {
            root.bestScore = st.score;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(root.bestScore);
            }
        }
        root.lines = st.lines;
        root.level = st.level;
        root.isOver = st.gameOver;
        gravityTimer.interval = st.gravityInterval;

        if (st.gameOver) {
            gravityTimer.stop();
            lockTimer.stop();
            playGameOver();
        }

        // Fast map of active blocks
        var activeMap = {};
        for (var a = 0; a < st.currentBlocks.length; a++) {
            var ab = st.currentBlocks[a];
            if (ab.r >= 2 && ab.r < 22) {
                activeMap[ab.r + "_" + ab.c] = ab.colorId;
            }
        }

        // Fast map of ghost blocks
        var ghostMap = {};
        for (var g = 0; g < st.ghostBlocks.length; g++) {
            var gb = st.ghostBlocks[g];
            if (gb.r >= 2 && gb.r < 22) {
                ghostMap[gb.r + "_" + gb.c] = true;
            }
        }

        // Update 200 grid model cells
        var modelIdx = 0;
        for (var r = 2; r < 22; r++) {
            var isClearingThisRow = (root.clearingRowIndices.indexOf(r) !== -1);
            for (var c = 0; c < 10; c++) {
                var key = r + "_" + c;
                var staticVal = st.grid[r][c];
                var cellActive = activeMap.hasOwnProperty(key);
                var cellGhost = ghostMap.hasOwnProperty(key) && !cellActive && staticVal === 0;
                var cid = cellActive ? activeMap[key] : staticVal;

                gridModel.setProperty(modelIdx, "colorId", cid);
                gridModel.setProperty(modelIdx, "isActive", cellActive);
                gridModel.setProperty(modelIdx, "isGhost", cellGhost);
                gridModel.setProperty(modelIdx, "isClearing", isClearingThisRow);
                modelIdx++;
            }
        }

        // Update Hold & Next UI
        holdPreview.updatePiece(st.holdPiece);
        nextPreview.updateQueue(st.nextPieces);
    }

    // Gravity Timer
    Timer {
        id: gravityTimer
        interval: 800
        repeat: true
        running: !root.isOver && !root.isPaused && !root.showHelp && !root.isClearing
        onTriggered: {
            var res = Engine.softDrop();
            if (res.moved) {
                syncFromEngine();
            } else {
                if (!lockTimer.running) {
                    lockTimer.restart();
                }
            }
        }
    }

    // Lock Delay Timer (~480ms grace period on landing)
    Timer {
        id: lockTimer
        interval: 480
        repeat: false
        onTriggered: {
            var res = Engine.softDrop();
            if (!res.moved) {
                var hardRes = Engine.hardDrop();
                handleLockResult(hardRes);
            }
        }
    }

    // Keyboard & Input Controls
    Item {
        id: gameArea
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape || event.key === Qt.Key_P) {
                if (root.showHelp) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
                if (!root.isOver) {
                    root.isPaused = !root.isPaused;
                    if (root.isPaused) lockTimer.stop();
                }
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_Question) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_M) {
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
 else if (event.key === Qt.Key_R) {
                root.startNewGame();
                event.accepted = true;
                return;
            }

            if (root.showHelp || root.isPaused || root.isOver || root.isClearing) return;

            // Movement & Rotation
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                if (Engine.moveLeft()) {
                    playMove();
                    syncFromEngine();
                    if (lockTimer.running) lockTimer.restart();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                if (Engine.moveRight()) {
                    playMove();
                    syncFromEngine();
                    if (lockTimer.running) lockTimer.restart();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                if (Engine.rotateCW()) {
                    playRotate();
                    syncFromEngine();
                    if (lockTimer.running) lockTimer.restart();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Z) {
                if (Engine.rotateCCW()) {
                    playRotate();
                    syncFromEngine();
                    if (lockTimer.running) lockTimer.restart();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                var now = Date.now();
                if (!event.isAutoRepeat && (now - root.lastDownPressTime < 280)) {
                    // Double press down -> slam!
                    root.lastDownPressTime = 0;
                    var slamRes = Engine.hardDrop();
                    lockTimer.stop();
                    playHardDrop();
                    handleLockResult(slamRes);
                    event.accepted = true;
                    return;
                }
                if (!event.isAutoRepeat) {
                    root.lastDownPressTime = now;
                }
                var sRes = Engine.softDrop();
                if (sRes.moved) {
                    syncFromEngine();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                var hRes = Engine.hardDrop();
                lockTimer.stop();
                playHardDrop();
                handleLockResult(hRes);
                event.accepted = true;
            } else if (event.key === Qt.Key_C || event.key === Qt.Key_Shift) {
                if (Engine.hold()) {
                    playRotate();
                    lockTimer.stop();
                    syncFromEngine();
                }
                event.accepted = true;
            }
        }
    }

    // Main Container - Dynamically scales to fit tiling windows
    Item {
        id: container
        anchors.fill: parent
        anchors.margins: Math.max(8, Math.min(18, parent.width * 0.03))

        // Header (Score & Title)
        Item {
            id: headerRow
            width: Math.min(parent.width, arena.arenaTotalWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.max(36, Math.min(52, container.height * 0.08))
            anchors.top: parent.top

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "TETRABLOCKS"
                    font.pixelSize: Math.round(Math.max(16, Math.min(26, parent.parent.width * 0.052)))
                    font.bold: true
                    font.letterSpacing: 1.5
                    color: root.themeAccent
                }
                Text {
                    text: "Classic Falling Block Puzzle"
                    font.pixelSize: Math.round(Math.max(9, Math.min(11, parent.parent.width * 0.024)))
                    color: root.themeSubtext
                    visible: container.height > 520
                }
            }

            // High Score & Score Badges
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: Math.max(54, Math.min(84, container.width * 0.17))
                    height: headerRow.height * 0.88
                    radius: 6
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        Text {
                            text: "SCORE"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.score.toString()
                            font.pixelSize: Math.round(Math.max(11, Math.min(15, parent.parent.height * 0.45)))
                            font.bold: true
                            color: root.themeFg
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Rectangle {
                    width: Math.max(54, Math.min(84, container.width * 0.17))
                    height: headerRow.height * 0.88
                    radius: 6
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        Text {
                            text: "BEST"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.bestScore.toString()
                            font.pixelSize: Math.round(Math.max(11, Math.min(15, parent.parent.height * 0.45)))
                            font.bold: true
                            color: root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // Subheader Controls Row (Help, Pause, Mute, New Game)
        Item {
            id: subheaderRow
            width: Math.min(parent.width, arena.arenaTotalWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32
            anchors.top: headerRow.bottom
            anchors.topMargin: 8
            readonly property bool isCrowded: subheaderRow.width < 450

            Row {
                anchors.fill: parent
                spacing: 6

                // Help Button
                Rectangle {
                    id: helpBtn
                    width: (parent.width - 12) / 4
                    height: parent.height
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "❓"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "How to Play"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderRow.isCrowded
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

                // Sound / Mute Button
                Rectangle {
                    id: muteBtn
                    width: (parent.width - 12) / 4
                    height: parent.height
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isMuted ? root.themeSubtext : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderRow.isCrowded
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

                // New Game Button
                                // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    width: (parent.width - 12) / 4
                    height: parent.height
                    radius: 6
                    color: root.fullPlayfield ? root.themeCardBg : (viewModeMouse.containsMouse ? root.themeCardBg : root.themeBoardBg)
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: root.fullPlayfield ? "🔲" : "⛶"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Full (⇧F)"; font.pixelSize: 10; font.bold: true; color: root.themeFg; visible: !subheaderRow.isCrowded; anchors.verticalCenter: parent.verticalCenter }
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
                    width: (parent.width - 12) / 4
                    height: parent.height
                    radius: 6
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeBtnBg, 1.15) : root.themeBtnBg
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: subheaderRow.isCrowded
                        }
                        Text {
                            text: "New Game (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderRow.isCrowded
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
        }

        // Gameplay Arena (Hold Panel, Central Board, Next Panel)
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
                    text: "🧱 TetraBlocks"
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
                    text: "(" + ("LINES: " + root.lines) + ")"
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
            id: arena
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderRow.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right

            property real cellPixelSize: {
                var availH = height - 16;
                var availW = width - 16;
                var byH = (availH - 14) / 20.0;
                var byW = (availW - 28) / 18.2;
                return Math.floor(Math.max(14, Math.min(byH, byW)));
            }
            property real sidebarWidth: Math.max(68, Math.round(cellPixelSize * 3.6))
            property real arenaSpacing: Math.max(8, Math.min(22, Math.round(cellPixelSize * 0.45)))
            property real arenaTotalWidth: sidebarWidth * 2 + (cellPixelSize * 10 + 12) + arenaSpacing * 2

            Row {
                id: arenaLayout
                anchors.centerIn: parent
                spacing: arena.arenaSpacing

                // Left Sidebar: HOLD Box + Level/Lines
                Column {
                    width: arena.sidebarWidth
                    spacing: Math.max(6, Math.min(12, Math.round(arena.cellPixelSize * 0.3)))
                    anchors.top: boardCard.top

                    // Hold Box
                    Rectangle {
                        width: parent.width
                        height: Math.round(width * 1.05)
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: Math.max(3, Math.round(arena.sidebarWidth * 0.04))
                            Text {
                                text: "HOLD (C)"
                                font.pixelSize: Math.max(9, Math.min(13, Math.round(arena.sidebarWidth * 0.09)))
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            MiniPieceGrid {
                                id: holdPreview
                                cellSize: Math.max(9, Math.round(arena.sidebarWidth * 0.18))
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Level Box
                    Rectangle {
                        width: parent.width
                        height: Math.max(38, Math.round(width * 0.52))
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: "LEVEL"
                                font.pixelSize: Math.max(9, Math.min(13, Math.round(arena.sidebarWidth * 0.09)))
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.level.toString()
                                font.pixelSize: Math.max(14, Math.min(22, Math.round(arena.sidebarWidth * 0.18)))
                                font.bold: true
                                color: root.themeFg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Lines Box
                    Rectangle {
                        width: parent.width
                        height: Math.max(38, Math.round(width * 0.52))
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: "LINES"
                                font.pixelSize: Math.max(9, Math.min(13, Math.round(arena.sidebarWidth * 0.09)))
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.lines.toString()
                                font.pixelSize: Math.max(14, Math.min(22, Math.round(arena.sidebarWidth * 0.18)))
                                font.bold: true
                                color: root.themeFg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Center Matrix (10 x 20)
                Rectangle {
                    id: boardCard
                    width: cellPixelSize * 10 + 12
                    height: cellPixelSize * 20 + 12
                    radius: Math.max(8, Math.round(cellPixelSize * 0.3))
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1.5

                    property real cellPixelSize: arena.cellPixelSize

                    MouseArea {
                        id: boardClickArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.isOver && !root.showHelp && !root.isPaused
                        onClicked: {
                            root.isPaused = true;
                            lockTimer.stop();
                            gameArea.forceActiveFocus();
                        }
                    }

                    Grid {
                        id: mainGrid
                        anchors.centerIn: parent
                        columns: 10
                        rows: 20
                        spacing: 1

                        Repeater {
                            model: gridModel
                            Rectangle {
                                width: boardCard.cellPixelSize - 1
                                height: boardCard.cellPixelSize - 1
                                radius: Math.max(2, boardCard.cellPixelSize * 0.16)

                                color: {
                                    if (model.isClearing) {
                                        return "#ffffff";
                                    } else if (model.colorId > 0) {
                                        return root.getPieceColor(model.colorId);
                                    } else if (model.isGhost) {
                                        return Qt.alpha(root.getPieceColor(Engine.currentPiece ? Engine.currentPiece.colorId : 1), 0.18);
                                    } else {
                                        return root.themeCellEmpty;
                                    }
                                }

                                border.width: model.isGhost ? 1 : (model.isClearing ? 1.5 : 0)
                                border.color: model.isClearing ? root.themeAccent : (model.isGhost ? Qt.alpha(root.getPieceColor(Engine.currentPiece ? Engine.currentPiece.colorId : 1), 0.55) : "transparent")

                                Behavior on color { ColorAnimation { duration: 40 } }
                            }
                        }
                    }

                    // Row Flash Beams
                    Repeater {
                        model: root.clearingRowIndices
                        Rectangle {
                            x: 6
                            y: 6 + (modelData - 2) * boardCard.cellPixelSize
                            width: boardCard.cellPixelSize * 10
                            height: boardCard.cellPixelSize
                            radius: 3
                            color: "#ffffff"
                            z: 15
                            opacity: 0.9
                            SequentialAnimation on opacity {
                                NumberAnimation { to: 1.0; duration: 40 }
                                NumberAnimation { to: 0.0; duration: 140 }
                            }
                        }
                    }

                    // Floating Line Clear Banner
                    Item {
                        id: clearBannerItem
                        anchors.centerIn: parent
                        z: 25
                        opacity: 0
                        scale: 0.8

                        Rectangle {
                            anchors.centerIn: parent
                            width: bannerText.implicitWidth + 28
                            height: Math.round(Math.max(30, boardCard.cellPixelSize * 1.1))
                            radius: 8
                            color: root.themeModalBg
                            border.color: root.themeAccent
                            border.width: 1.5

                            Text {
                                id: bannerText
                                anchors.centerIn: parent
                                text: root.clearBannerText
                                font.pixelSize: Math.round(Math.max(12, boardCard.cellPixelSize * 0.42))
                                font.bold: true
                                color: root.themeAccent
                            }
                        }

                        SequentialAnimation {
                            id: clearBannerAnim
                            ParallelAnimation {
                                NumberAnimation { target: clearBannerItem; property: "opacity"; from: 0; to: 1; duration: 60 }
                                NumberAnimation { target: clearBannerItem; property: "scale"; from: 0.8; to: 1.12; duration: 100; easing.type: Easing.OutBack }
                            }
                            PauseAnimation { duration: 320 }
                            ParallelAnimation {
                                NumberAnimation { target: clearBannerItem; property: "opacity"; to: 0; duration: 180 }
                                NumberAnimation { target: clearBannerItem; property: "scale"; to: 1.25; duration: 180 }
                            }
                        }
                    }

                    // Pause / Game Over Overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(root.themeBoardBg, 0.88)
                        visible: root.isOver || root.isPaused
                        z: 10

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.isPaused && !root.isOver
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isPaused = false;
                                gameArea.forceActiveFocus();
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                text: root.isOver ? "GAME OVER" : "PAUSED"
                                font.pixelSize: 22
                                font.bold: true
                                color: root.isOver ? "#f38ba8" : root.themeAccent
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: root.isOver ? "Score: " + root.score : "Press P, Esc or click to Resume"
                                font.pixelSize: 13
                                color: root.themeFg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Rectangle {
                                width: 140
                                height: 42
                                radius: 8
                                color: root.themeAccent
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.isOver

                                Text {
                                    anchors.centerIn: parent
                                    text: "PLAY AGAIN"
                                    font.family: root.monoFontFamily
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: root.themeBg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startNewGame()
                                }
                            }

                            Text {
                                text: "Or press R / Space / Enter"
                                font.family: root.monoFontFamily
                                font.pixelSize: 11
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.isOver
                            }

                            Rectangle {
                                width: 110
                                height: 32
                                radius: 6
                                color: root.themeBtnBg
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.isPaused && !root.isOver

                                Text {
                                    anchors.centerIn: parent
                                    text: "Resume (P)"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: root.themeBtnFg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isPaused = false;
                                        gameArea.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // Right Sidebar: NEXT Queue
                Column {
                    width: arena.sidebarWidth
                    spacing: 8
                    anchors.top: boardCard.top

                    Rectangle {
                        width: parent.width
                        height: Math.min(boardCard.height, nextCol.implicitHeight + 16)
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1
                        clip: true

                        Column {
                            id: nextCol
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            spacing: Math.max(4, Math.round(arena.sidebarWidth * 0.05))

                            Text {
                                text: "NEXT"
                                font.pixelSize: Math.max(9, Math.min(13, Math.round(arena.sidebarWidth * 0.09)))
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            NextQueueItem {
                                id: nextPreview
                                cellSize: Math.max(8, Math.round(arena.sidebarWidth * 0.16))
                            }
                        }
                    }
                }
            }
        }
    }

    // Mini Piece Grid Component (for Hold)
    component MiniPieceGrid: Item {
        id: miniGrid
        property real cellSize: 12
        property var pieceType: null

        width: cellSize * 4
        height: cellSize * 4

        function updatePiece(type) {
            miniGrid.pieceType = type;
            miniCanvas.requestPaint();
        }

        Canvas {
            id: miniCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!miniGrid.pieceType) return;

                var pDef = Engine.PIECES[miniGrid.pieceType];
                if (!pDef) return;
                var coords = pDef.shapes[0];
                var color = root.getPieceColor(pDef.colorId);

                // Center in 4x4
                var minX = 4, maxX = 0, minY = 4, maxY = 0;
                for (var i = 0; i < coords.length; i++) {
                    minX = Math.min(minX, coords[i][0]);
                    maxX = Math.max(maxX, coords[i][0]);
                    minY = Math.min(minY, coords[i][1]);
                    maxY = Math.max(maxY, coords[i][1]);
                }
                var pW = (maxX - minX + 1) * miniGrid.cellSize;
                var pH = (maxY - minY + 1) * miniGrid.cellSize;
                var offX = (width - pW) * 0.5 - minX * miniGrid.cellSize;
                var offY = (height - pH) * 0.5 - minY * miniGrid.cellSize;

                ctx.fillStyle = color;
                for (var j = 0; j < coords.length; j++) {
                    var bx = offX + coords[j][0] * miniGrid.cellSize;
                    var by = offY + coords[j][1] * miniGrid.cellSize;
                    ctx.fillRect(bx, by, miniGrid.cellSize - 1, miniGrid.cellSize - 1);
                }
            }
        }
    }

    // Next Queue Item Component
    component NextQueueItem: Column {
        id: nQueue
        property real cellSize: 11
        spacing: 4
        anchors.horizontalCenter: parent.horizontalCenter

        function updateQueue(types) {
            if (!types) return;
            p1.updatePiece(types[0] || null);
            p2.updatePiece(types[1] || null);
            p3.updatePiece(types[2] || null);
        }

        MiniPieceGrid { id: p1; cellSize: nQueue.cellSize; height: cellSize * 2.8 }
        MiniPieceGrid { id: p2; cellSize: nQueue.cellSize; height: cellSize * 2.8 }
        MiniPieceGrid { id: p3; cellSize: nQueue.cellSize; height: cellSize * 2.8 }
    }

    // Floating Sound Toast Notification
    Rectangle {
        id: soundToast
        z: 110
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(16, root.height * 0.05)
        width: toastText.implicitWidth + 36
        height: 38
        radius: 19
        color: root.themeModalBg
        border.color: root.isMuted ? root.themeBorder : root.themeAccent
        border.width: 1.5
        opacity: 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: ""
            font.pixelSize: 13
            font.bold: true
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

    // Help / Instructions Modal Dialog
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.alpha(root.themeBoardBg, 0.88)
        z: 120
        visible: root.showHelp
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Rectangle {
            id: modalCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 24, 380)
            height: Math.min(parent.height - 24, modalContent.implicitHeight + 36)
            radius: 12
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
                // absorb clicks
            }

            Column {
                id: modalContent
                width: parent.width - 32
                anchors.centerIn: parent
                spacing: 11

                Item {
                    width: parent.width
                    height: titleText.implicitHeight
                    Text {
                        id: titleText
                        anchors.left: parent.left
                        text: "How to Play"
                        font.pixelSize: 18
                        font.bold: true
                        color: root.themeAccent
                    }
                    Text {
                        text: "✕"
                        font.pixelSize: 14
                        color: root.themeSubtext
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Move and rotate falling tetrominoes to fill complete horizontal lines. Clear lines to score points and level up!"
                    font.pixelSize: 12
                    color: root.themeFg
                    lineHeight: 1.25
                }

                // Keybindings list
                Column {
                    width: parent.width
                    spacing: 6

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "A / D • ← →"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Move Left / Right"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "W / ↑ / Z"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Rotate CW / CCW"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "Space / 2x ↓"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Hard Drop (Instant Slam)"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "S / ↓"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Soft Drop"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "C / Shift"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Hold Piece"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "Shift+F"; font.family: root.monoFontFamily; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Full / Compact View (⇧F)"; font.pixelSize: 11; color: root.themeSubtext }
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 86; height: 22; radius: 4
                            color: root.themeCardBg
                            Text { anchors.centerIn: parent; text: "P • Esc • M • R"; font.family: root.monoFontFamily; font.pixelSize: 9; font.bold: true; color: root.themeFg }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Pause • Mute • Restart"; font.pixelSize: 11; color: root.themeSubtext }
                    }
                }

                // Got It button
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 105; height: 30; radius: 6
                    color: gotItMouse.containsMouse ? Qt.lighter(root.themeBtnBg, 1.15) : root.themeBtnBg
                    Text { anchors.centerIn: parent; text: "Got It"; font.pixelSize: 12; font.bold: true; color: root.themeBtnFg }
                    MouseArea {
                        id: gotItMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = false
                    }
                }

                // Legal / Attribution Footnote
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Created by Chris Thompson (@bigcjat) with Gemini\nTetraBlocks • Public Domain Rules • MIT License"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 9
                    color: Qt.alpha(root.themeSubtext, 0.7)
                }
            }
        }
    }

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: gameArea
    }

    signal screenshotSaved(string filePath)

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : root.contentItem;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }
}
