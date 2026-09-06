import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "GameLogic.js" as Logic

ApplicationWindow {
    id: root
    visible: true
    width: 460
    height: 620
    minimumWidth: 260
    minimumHeight: 320
    title: currentThemeName.length > 0 ? "2048 • " + currentThemeName : "2048"

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
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (!root.isMuted) {
            playMergeSound(4);
        }
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function playSlideSound() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSlide();
        }
    }

    function playMergeSound(val) {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) {
            soundManager.playMerge(val);
        }
    }

    function playGameOverSound() {
        if (root.isMuted) return;
        if (typeof soundManager !== "undefined" && soundManager) {
            soundManager.playGameOver();
        }
    }

    function dismissSplash() {
        if (splashScreen) {
            splashScreen.dismiss();
        }
    }

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
        if (name) currentThemeName = name;

        var bg = data.background || "#181825";
        var fg = data.foreground || "#cdd6f4";
        var accent = data.accent || "#fab387";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            // Light theme (e.g. Snow, Paper, Latte)
            themeBoardBg = Qt.darker(bg, 1.10);
            themeCellEmpty = Qt.darker(bg, 1.05);
            themeCardBg = Qt.darker(bg, 1.08);
            themeSubtext = Qt.lighter(fg, 2.2);
            themeModalBg = bg;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            // Dark theme (e.g. Catppuccin, Gruvbox, Tokyo Night, Nord, Evergreen)
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCellEmpty = Qt.lighter(bg, 1.15);
            themeCardBg = c0;
            themeSubtext = Qt.alpha(fg, 0.7);
            themeModalBg = Qt.lighter(bg, 1.12);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }
        isCustomTheme = true;
    }

    function loadOmarchyThemeDirect() {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation);
        var tomlUrl = home + "/.config/omarchy/current/theme/colors.toml";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", tomlUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                if (xhr.responseText && xhr.responseText.length > 10) {
                    var parsed = parseSimpleToml(xhr.responseText);
                    if (parsed && parsed.background) {
                        applyTheme(parsed, "Omarchy System Theme");
                    }
                }
            }
        };
        xhr.send();
    }

    function parseSimpleToml(text) {
        var res = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line || line.startsWith("#") || line.startsWith("[")) continue;
            var eqIdx = line.indexOf("=");
            if (eqIdx !== -1) {
                var key = line.substring(0, eqIdx).trim();
                var val = line.substring(eqIdx + 1).trim();
                val = val.replace(/^["']|["']$/g, "").trim();
                res[key] = val;
            }
        }
        return res;
    }

    // Focus for keyboard navigation
    Component.onCompleted: {
        requestActivate();
        gameContainer.forceActiveFocus();
        loadOmarchyThemeDirect();
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
            Logic.setBestScore(root.bestScore);
        }
        restartGame();
    }

    property int score: 0
    property int bestScore: 0
    property bool isWon: false
    property bool isOver: false
    property bool keepPlayingAfterWin: false
    property bool showHelp: false

    function restartGame() {
        tileModel.clear();
        keepPlayingAfterWin = false;
        isWon = false;
        isOver = false;
        var st = Logic.startNewGame();
        syncFromLogic(st);
    }

    function doMove(dir) {
        if (isOver) return;
        if (isWon && !keepPlayingAfterWin) return;

        var res = Logic.move(dir);
        if (res.moved) {
            syncFromLogic(res.state);
            if (res.scoreGained > 0 && res.maxMergedVal > 0) {
                floatingScore.spawn(res.scoreGained);
                playMergeSound(res.maxMergedVal);
            } else {
                playSlideSound();
            }
            if (res.state.over) {
                playGameOverSound();
            }
        }
    }

    signal screenshotSaved(string filePath)

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : gameContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    function syncFromLogic(st) {
        root.score = st.score;
        if (st.score > root.bestScore) {
            root.bestScore = st.score;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(root.bestScore);
            }
        }
        if (st.won && !keepPlayingAfterWin) root.isWon = true;
        root.isOver = st.over;

        // Sync tileModel with Logic.tiles
        var logicTiles = st.tiles;
        
        // Mark all existing in model
        var modelMap = {};
        for (var i = 0; i < tileModel.count; i++) {
            var item = tileModel.get(i);
            modelMap[item.tileId] = i;
        }

        // Update or add
        for (var t = 0; t < logicTiles.length; t++) {
            var lt = logicTiles[t];
            if (modelMap.hasOwnProperty(lt.id)) {
                var idx = modelMap[lt.id];
                tileModel.setProperty(idx, "row", lt.row);
                tileModel.setProperty(idx, "col", lt.col);
                tileModel.setProperty(idx, "val", lt.val);
                tileModel.setProperty(idx, "toDelete", lt.toDelete);
                if (lt.isMerged) {
                    tileModel.setProperty(idx, "triggerBounce", true);
                }
                delete modelMap[lt.id];
            } else {
                // New tile
                tileModel.append({
                    "tileId": lt.id,
                    "val": lt.val,
                    "row": lt.row,
                    "col": lt.col,
                    "toDelete": false,
                    "triggerBounce": false
                });
            }
        }

        // Clean up tiles marked toDelete after animation completes
        cleanupTimer.restart();
    }

    Timer {
        id: cleanupTimer
        interval: 140
        repeat: false
        onTriggered: {
            for (var i = tileModel.count - 1; i >= 0; i--) {
                if (tileModel.get(i).toDelete) {
                    tileModel.remove(i);
                }
            }
        }
    }

    // Main Game Container & Keyboard controls (Arrows, WASD, Vim HJKL, R)
    Rectangle {
        id: gameContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true
        Behavior on color { ColorAnimation { duration: 250 } }

        // Responsive board scaling for tiling window managers (Hyprland / Omarchy)
        property real reservedVertical: gameContainer.height < 500 ? 94 : 126
        property real availableW: Math.max(160, gameContainer.width - 24)
        property real availableH: Math.max(160, gameContainer.height - reservedVertical)
        property real boardSize: Math.min(availableW, availableH)

        Keys.onPressed: function(event) {
            if (splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape) {
                if (root.showHelp) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            } else if (event.key === Qt.Key_Question) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }
            if (root.showHelp) return;

            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                root.doMove(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                root.doMove(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                root.doMove(2);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.doMove(3);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
            }
        }

        // Main Column Layout - centers dynamically in available space
        Column {
            id: mainLayout
            anchors.centerIn: parent
            spacing: Math.max(8, Math.min(14, gameContainer.boardSize * 0.028))
            width: gameContainer.boardSize

            // Header
            Item {
                id: headerItem
                width: parent.width
                height: Math.max(titleCol.height, scoreRow.height)

                Column {
                    id: titleCol
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "2048"
                        font.pixelSize: Math.max(20, Math.min(42, gameContainer.boardSize * 0.11))
                        font.bold: true
                        color: root.themeAccent
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                    Text {
                        text: "Join numbers to get 2048"
                        font.pixelSize: Math.max(9, Math.min(13, gameContainer.boardSize * 0.034))
                        color: root.themeSubtext
                        visible: gameContainer.boardSize >= 260
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }

                // Score boxes
                Row {
                    id: scoreRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.max(4, Math.min(8, gameContainer.boardSize * 0.02))

                    // Score Card
                    Rectangle {
                        width: Math.max(52, Math.min(78, gameContainer.boardSize * 0.20))
                        height: Math.max(38, Math.min(52, gameContainer.boardSize * 0.13))
                        radius: Math.max(6, width * 0.12)
                        color: root.themeCardBg
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "SCORE"
                                font.pixelSize: Math.max(8, Math.min(10, parent.parent.height * 0.22))
                                font.bold: true
                                color: root.themeSubtext
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.score.toString()
                                font.pixelSize: Math.max(12, Math.min(17, parent.parent.height * 0.38))
                                font.bold: true
                                color: root.themeFg
                            }
                        }

                        // Floating score animation
                        Text {
                            id: floatingScore
                            property int addedVal: 0
                            text: "+" + addedVal
                            font.pixelSize: Math.max(11, Math.min(15, parent.height * 0.32))
                            font.bold: true
                            color: root.themePalette.color2 || "#a6e3a1"
                            opacity: 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6

                            function spawn(val) {
                                addedVal = val;
                                floatAnim.restart();
                            }

                            SequentialAnimation {
                                id: floatAnim
                                ParallelAnimation {
                                    NumberAnimation { target: floatingScore; property: "y"; from: 6; to: -14; duration: 400; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: floatingScore; property: "opacity"; from: 1; to: 0; duration: 400 }
                                }
                                PropertyAction { target: floatingScore; property: "y"; value: 6 }
                            }
                        }
                    }

                    // Best Card
                    Rectangle {
                        width: Math.max(52, Math.min(78, gameContainer.boardSize * 0.20))
                        height: Math.max(38, Math.min(52, gameContainer.boardSize * 0.13))
                        radius: Math.max(6, width * 0.12)
                        color: root.themeCardBg
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "BEST"
                                font.pixelSize: Math.max(8, Math.min(10, parent.parent.height * 0.22))
                                font.bold: true
                                color: root.themeSubtext
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.bestScore.toString()
                                font.pixelSize: Math.max(12, Math.min(17, parent.parent.height * 0.38))
                                font.bold: true
                                color: root.themeFg
                            }
                        }
                    }
                }
            }

            // Subheader: Instructions & Restart Buttons
            Item {
                id: subheaderItem
                width: parent.width
                height: restartBtn.height

                Rectangle {
                    id: helpBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(28, Math.min(34, parent.width * 0.095))
                    width: Math.max(96, Math.min(130, parent.width * 0.34))
                    radius: Math.max(6, height * 0.24)
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
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
                            font.pixelSize: Math.max(10, Math.min(12, helpBtn.height * 0.38))
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
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

                Rectangle {
                    id: muteBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: helpBtn.height
                    width: Math.max(34, Math.min(88, parent.width * 0.24))
                    radius: helpBtn.radius
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.pixelSize: Math.max(9, Math.min(11, muteBtn.height * 0.38))
                            font.bold: true
                            color: root.isMuted ? root.themeSubtext : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: muteBtn.width >= 62
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

                Rectangle {
                    id: restartBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(96, Math.min(130, parent.width * 0.34))
                    height: Math.max(28, Math.min(34, parent.width * 0.095))
                    radius: Math.max(6, height * 0.24)
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeBtnBg, 1.15) : root.themeBtnBg
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.width < 110 ? "New (R)" : "New Game (R)"
                        font.pixelSize: Math.max(10, Math.min(12, restartBtn.height * 0.38))
                        font.bold: true
                        color: root.themeBtnFg
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

        // The Game Board - adapts dynamically to any window size / tiling layout
        Rectangle {
            id: board
            width: parent.width
            height: parent.width
            radius: Math.max(8, width * 0.035)
            color: root.themeBoardBg
            border.color: root.themeBorder
            border.width: Math.max(1, width * 0.005)
            clip: true
            Behavior on color { ColorAnimation { duration: 250 } }

            property real padding: Math.max(6, width * 0.028)
            property real spacing: Math.max(5, width * 0.024)
            property real cellSize: (width - padding * 2 - spacing * 3) / 4

            // Background Grid Cells (Empty slots)
            Grid {
                anchors.fill: parent
                anchors.margins: board.padding
                rows: 4
                columns: 4
                spacing: board.spacing

                Repeater {
                    model: 16
                    Rectangle {
                        width: board.cellSize
                        height: board.cellSize
                        radius: Math.max(4, board.cellSize * 0.10)
                        color: root.themeCellEmpty
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            // ListModel holding dynamic active tiles
            ListModel {
                id: tileModel
            }

            // Active Tiles Layer
            Repeater {
                model: tileModel

                Item {
                    id: tileItem
                    property int tVal: model.val
                    property int tRow: model.row
                    property int tCol: model.col
                    property bool toDel: model.toDelete
                    property bool bounce: model.triggerBounce

                    width: board.cellSize
                    height: board.cellSize

                    x: board.padding + tCol * (board.cellSize + board.spacing)
                    y: board.padding + tRow * (board.cellSize + board.spacing)
                    z: toDel ? 1 : 2

                    Behavior on x {
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: tileRect
                        anchors.fill: parent
                        radius: Math.max(4, board.cellSize * 0.10)
                        color: root.tileColor(tileItem.tVal)
                        scale: 0.2

                        Component.onCompleted: {
                            scaleAnim.restart();
                        }

                        NumberAnimation on scale {
                            id: scaleAnim
                            from: 0.2
                            to: 1.0
                            duration: 150
                            easing.type: Easing.OutBack
                        }

                        onColorChanged: {
                            if (tileItem.bounce) {
                                bounceAnim.restart();
                                model.triggerBounce = false;
                            }
                        }

                        SequentialAnimation {
                            id: bounceAnim
                            NumberAnimation { target: tileRect; property: "scale"; from: 1.0; to: 1.22; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: tileRect; property: "scale"; from: 1.22; to: 1.0; duration: 110; easing.type: Easing.OutBounce }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: tileItem.tVal > 0 ? tileItem.tVal.toString() : ""
                            font.pixelSize: Math.max(9, board.cellSize * (tileItem.tVal < 100 ? 0.38 : (tileItem.tVal < 1000 ? 0.31 : (tileItem.tVal < 10000 ? 0.25 : 0.20))))
                            font.bold: true
                            color: root.textColor(tileItem.tVal)
                        }
                    }
                }
            }

            // Touch / Mouse Swipe & Two-Finger Trackpad Area
            MouseArea {
                anchors.fill: parent
                property real startX: 0
                property real startY: 0
                property bool swiping: false
                property real accumulatedX: 0
                property real accumulatedY: 0
                property bool gestureLocked: false
                property double lastMoveTime: 0

                // 1-Finger Click & Drag (Mouse or Touchscreen)
                onPressed: function(mouse) {
                    startX = mouse.x;
                    startY = mouse.y;
                    swiping = true;
                }

                onReleased: function(mouse) {
                    if (!swiping) return;
                    swiping = false;
                    var dx = mouse.x - startX;
                    var dy = mouse.y - startY;
                    var threshold = 35;

                    if (Math.abs(dx) > Math.abs(dy)) {
                        if (Math.abs(dx) > threshold) {
                            if (dx > 0) root.doMove(1); // Right
                            else root.doMove(0); // Left
                        }
                    } else {
                        if (Math.abs(dy) > threshold) {
                            if (dy > 0) root.doMove(3); // Down
                            else root.doMove(2); // Up
                        }
                    }
                }

                // 2-Finger Trackpad Scroll / Flick (macOS and Linux Wayland)
                onWheel: function(wheel) {
                    if (root.isOver || root.showHelp) {
                        wheel.accepted = true;
                        return;
                    }

                    // A new physical touch gesture begins
                    if (wheel.phase === Qt.ScrollBegin) {
                        accumulatedX = 0;
                        accumulatedY = 0;
                        gestureLocked = false;
                    }

                    // If a move was already triggered during this gesture or cooldown,
                    // keep resetting the cooldown timer on every single incoming event (including momentum tail)
                    if (gestureLocked) {
                        wheelCooldownTimer.restart();
                        wheel.accepted = true;
                        return;
                    }

                    // Ignore momentum / inertia events that arrive
                    if (wheel.phase === Qt.ScrollMomentum) {
                        wheel.accepted = true;
                        return;
                    }

                    var dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x;
                    var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;

                    if (wheel.inverted) {
                        dy = -dy;
                    }

                    accumulatedX += dx;
                    accumulatedY += dy;

                    var now = Date.now();
                    var threshold = 40;

                    if (Math.abs(accumulatedX) > threshold || Math.abs(accumulatedY) > threshold) {
                        if (now - lastMoveTime >= 240) {
                            if (Math.abs(accumulatedX) > Math.abs(accumulatedY)) {
                                if (accumulatedX > 0) root.doMove(1); // Right
                                else root.doMove(0); // Left
                            } else {
                                if (accumulatedY > 0) root.doMove(2); // Up
                                else root.doMove(3); // Down
                            }
                            lastMoveTime = now;
                        }
                        // Lock gesture until trackpad goes completely silent
                        gestureLocked = true;
                        accumulatedX = 0;
                        accumulatedY = 0;
                        wheelCooldownTimer.restart();
                    }

                    wheel.accepted = true;
                }

                Timer {
                    id: wheelCooldownTimer
                    interval: 220
                    repeat: false
                    onTriggered: {
                        parent.gestureLocked = false;
                        parent.accumulatedX = 0;
                        parent.accumulatedY = 0;
                    }
                }
            }

            // Game Over Overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(root.themeBoardBg, 0.92)
                z: 100
                visible: root.isOver
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on color { ColorAnimation { duration: 250 } }

                // Block gestures behind the overlay
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Game Over!"
                        font.pixelSize: 32
                        font.bold: true
                        color: root.themePalette.color1 || "#f38ba8"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Final Score: " + root.score
                        font.pixelSize: 18
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
                            font.family: "Menlo"
                            font.bold: true
                            font.pixelSize: 13
                            color: root.themeBg
                        }

                        MouseArea {
                            id: tryAgainMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.restartGame()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Or press R / Space / Enter"
                        font.family: "Menlo"
                        font.pixelSize: 11
                        color: root.themeSubtext
                    }
                }
            }

            // Win Overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(root.themeBoardBg, 0.92)
                z: 100
                visible: root.isWon && !root.keepPlayingAfterWin
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on color { ColorAnimation { duration: 250 } }

                // Block gestures behind the overlay
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "You Win!"
                        font.pixelSize: 34
                        font.bold: true
                        color: root.themeAccent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "You reached the 2048 tile!"
                        font.pixelSize: 15
                        color: root.themeSubtext
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 110
                            height: 38
                            radius: 8
                            color: root.themePalette.color2 || "#a6e3a1"
                            Text {
                                anchors.centerIn: parent
                                text: "Keep Going"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.colorLuminance(parent.color) > 0.5 ? "#11111b" : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.keepPlayingAfterWin = true
                            }
                        }

                        Rectangle {
                            width: 110
                            height: 38
                            radius: 8
                            color: root.themeBtnBg
                            Text {
                                anchors.centerIn: parent
                                text: "Restart"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeBtnFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartGame()
                            }
                        }
                    }
                }
            }
        }
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

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

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

    // Help / Instructions Modal Overlay
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.alpha(root.themeBoardBg, 0.85)
        z: 120
        visible: root.showHelp
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 250 } }

        // Click backdrop to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Rectangle {
            id: modalCard
            anchors.centerIn: parent

            // Responsive layout states for tiling window managers
            readonly property bool isVeryTiny: root.width < 320 || root.height < 440
            readonly property bool isCompact: root.width < 390 || root.height < 540

            width: Math.min(parent.width - (isVeryTiny ? 12 : 24), isCompact ? 320 : 380)
            height: Math.min(parent.height - (isVeryTiny ? 12 : 24), modalContent.implicitHeight + (isVeryTiny ? 22 : 36))
            radius: isVeryTiny ? 10 : 14
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1
            clip: true
            Behavior on color { ColorAnimation { duration: 250 } }

            MouseArea {
                anchors.fill: parent
                // Prevent backdrop click when clicking modal card
            }

            Flickable {
                id: modalFlickable
                anchors.fill: parent
                contentHeight: modalContent.implicitHeight + (modalCard.isVeryTiny ? 22 : 36)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: modalContent
                    width: parent.width - (modalCard.isVeryTiny ? 18 : 32)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: modalCard.isVeryTiny ? 10 : 16
                    spacing: modalCard.isVeryTiny ? 7 : (modalCard.isCompact ? 9 : 13)

                    // Header Row
                    Item {
                        width: parent.width
                        height: titleText.height

                        Text {
                            id: titleText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "How to Play"
                            font.pixelSize: modalCard.isVeryTiny ? 15 : (modalCard.isCompact ? 17 : 20)
                            font.bold: true
                            color: root.themeAccent
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: modalCard.isVeryTiny ? 20 : 24
                            height: width
                            radius: width / 2
                            color: closeMouse.containsMouse ? root.themeCardBg : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : 12
                                color: closeMouse.containsMouse ? (root.themePalette.color1 || "#f38ba8") : root.themeSubtext
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHelp = false
                            }
                        }
                    }

                    // Summary Instructions (Truncated / adapted dynamically)
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: modalCard.isVeryTiny
                            ? "Merge matching numbers to reach 2048!"
                            : (modalCard.isCompact
                               ? "Swipe or press keys to merge tiles. Reach 2048 to win!"
                               : "Swipe or use keyboard keys to slide all tiles across the board. When two tiles with the same number collide, they merge into one with double value! Join numbers to reach 2048.")
                        font.pixelSize: modalCard.isVeryTiny ? 10.5 : (modalCard.isCompact ? 11.5 : 12)
                        color: root.themeSubtext
                        lineHeight: 1.2
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.themeBorder
                    }

                    Text {
                        text: "CONTROLS"
                        font.pixelSize: modalCard.isVeryTiny ? 9 : (modalCard.isCompact ? 10 : 11)
                        font.bold: true
                        color: root.themeAccent
                    }

                    // Key Bindings Rows
                    Column {
                        width: parent.width
                        spacing: modalCard.isVeryTiny ? 4 : (modalCard.isCompact ? 6 : 8)

                        // Vim Navigation
                        Row {
                            width: parent.width
                            spacing: modalCard.isVeryTiny ? 6 : 10

                            Rectangle {
                                width: modalCard.isVeryTiny ? 68 : (modalCard.isCompact ? 86 : 105)
                                height: modalCard.isVeryTiny ? 20 : (modalCard.isCompact ? 22 : 26)
                                radius: 4
                                color: root.themeCardBg
                                anchors.verticalCenter: parent.verticalCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: "H J K L"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: modalCard.isVeryTiny ? 9 : 10.5
                                    font.bold: true
                                    color: root.themeFg
                                }
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modalCard.isVeryTiny ? "Vim keys" : "Vim Navigation"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : (modalCard.isCompact ? 11 : 12)
                                color: root.themeSubtext
                            }
                        }

                        // Directional Keys
                        Row {
                            width: parent.width
                            spacing: modalCard.isVeryTiny ? 6 : 10

                            Rectangle {
                                width: modalCard.isVeryTiny ? 68 : (modalCard.isCompact ? 86 : 105)
                                height: modalCard.isVeryTiny ? 20 : (modalCard.isCompact ? 22 : 26)
                                radius: 4
                                color: root.themeCardBg
                                anchors.verticalCenter: parent.verticalCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: modalCard.isVeryTiny ? "WASD / 🠐" : "WASD / Arrows"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: modalCard.isVeryTiny ? 8.5 : 10
                                    font.bold: true
                                    color: root.themeFg
                                }
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modalCard.isVeryTiny ? "Move tiles" : "Directional Move"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : (modalCard.isCompact ? 11 : 12)
                                color: root.themeSubtext
                            }
                        }

                        // Trackpad / Mouse
                        Row {
                            width: parent.width
                            spacing: modalCard.isVeryTiny ? 6 : 10

                            Rectangle {
                                width: modalCard.isVeryTiny ? 68 : (modalCard.isCompact ? 86 : 105)
                                height: modalCard.isVeryTiny ? 20 : (modalCard.isCompact ? 22 : 26)
                                radius: 4
                                color: root.themeCardBg
                                anchors.verticalCenter: parent.verticalCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: modalCard.isVeryTiny ? "Swipe" : "Trackpad"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: modalCard.isVeryTiny ? 8.5 : 9.5
                                    font.bold: true
                                    color: root.themeFg
                                }
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modalCard.isVeryTiny ? "Swipe / Drag" : "2-finger swipe / drag"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : (modalCard.isCompact ? 11 : 12)
                                color: root.themeSubtext
                            }
                        }

                        // Restart & Esc
                        Row {
                            width: parent.width
                            spacing: modalCard.isVeryTiny ? 6 : 10

                            Rectangle {
                                width: modalCard.isVeryTiny ? 68 : (modalCard.isCompact ? 86 : 105)
                                height: modalCard.isVeryTiny ? 20 : (modalCard.isCompact ? 22 : 26)
                                radius: 4
                                color: root.themeCardBg
                                anchors.verticalCenter: parent.verticalCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: modalCard.isVeryTiny ? "R / Esc" : "R • Esc • ?"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: modalCard.isVeryTiny ? 8.5 : 10
                                    font.bold: true
                                    color: root.themeFg
                                }
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modalCard.isVeryTiny ? "Restart / Close" : "Restart / Help"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : (modalCard.isCompact ? 11 : 12)
                                color: root.themeSubtext
                            }
                        }

                        // Mute / Sound Toggle Shortcut
                        Row {
                            width: parent.width
                            spacing: modalCard.isVeryTiny ? 6 : 10

                            Rectangle {
                                width: modalCard.isVeryTiny ? 68 : (modalCard.isCompact ? 86 : 105)
                                height: modalCard.isVeryTiny ? 20 : (modalCard.isCompact ? 22 : 26)
                                radius: 4
                                color: root.themeCardBg
                                anchors.verticalCenter: parent.verticalCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: "M"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: modalCard.isVeryTiny ? 8.5 : 10
                                    font.bold: true
                                    color: root.themeFg
                                }
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modalCard.isVeryTiny ? "Mute / Unmute" : "Toggle Mute (Default: Off)"
                                font.pixelSize: modalCard.isVeryTiny ? 10 : (modalCard.isCompact ? 11 : 12)
                                color: root.themeSubtext
                            }
                        }


                    }

                    // Got It Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: modalCard.isVeryTiny ? 86 : (modalCard.isCompact ? 100 : 120)
                        height: modalCard.isVeryTiny ? 25 : (modalCard.isCompact ? 28 : 34)
                        radius: 6
                        color: gotItMouse.containsMouse ? Qt.lighter(root.themeBtnBg, 1.15) : root.themeBtnBg
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Got It"
                            font.pixelSize: modalCard.isVeryTiny ? 11 : (modalCard.isCompact ? 12 : 13)
                            font.bold: true
                            color: root.themeBtnFg
                        }

                        MouseArea {
                            id: gotItMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }

                    // Credits / Attribution Footnote
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Based on 2048 by Gabriele Cirulli • MIT License"
                        font.pixelSize: modalCard.isVeryTiny ? 8 : (modalCard.isCompact ? 9 : 10)
                        color: Qt.alpha(root.themeSubtext, 0.75)
                    }
                }
            }
        }
    }
    }

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: gameContainer
    }

    // Polished palette helper functions on root
    function tileColor(val) {
        if (!isCustomTheme || !themePalette.accent) {
            // Curated default Catppuccin Mocha palette
            switch(val) {
                case 2:    return "#313244"; // Slate 2
                case 4:    return "#45475a"; // Slate 4
                case 8:    return "#f38ba8"; // Coral Red
                case 16:   return "#fab387"; // Peach Orange
                case 32:   return "#f9e2af"; // Pastel Yellow
                case 64:   return "#a6e3a1"; // Mint Green
                case 128:  return "#94e2d5"; // Teal
                case 256:  return "#89dceb"; // Sky Blue
                case 512:  return "#74c7ec"; // Sapphire
                case 1024: return "#b4befe"; // Lavender
                case 2048: return "#cba6f7"; // Royal Mauve (2048!)
                default:   return "#f5c2e7"; // Flamingo (>2048)
            }
        }

        var p = themePalette;
        var lum = colorLuminance(themeBg);
        if (lum > 0.5) {
            // Monochromatic or light palette (e.g. Snow / Paper)
            switch(val) {
                case 2:    return Qt.darker(themeBg, 1.10);
                case 4:    return Qt.darker(themeBg, 1.20);
                case 8:    return p.color3 || Qt.darker(themeBg, 1.30);
                case 16:   return p.accent || Qt.darker(themeBg, 1.45);
                case 32:   return p.color1 || Qt.darker(themeBg, 1.60);
                case 64:   return p.color9 || p.color1 || Qt.darker(themeBg, 1.75);
                case 128:  return p.color2 || Qt.darker(themeBg, 1.90);
                case 256:  return p.color10 || p.color6 || Qt.darker(themeBg, 2.05);
                case 512:  return p.color4 || Qt.darker(themeBg, 2.20);
                case 1024: return p.color12 || p.color5 || Qt.darker(themeBg, 2.40);
                case 2048: return p.accent || "#0a0a0a";
                default:   return p.color14 || p.accent || "#000000";
            }
        }

        // Standard colorful / dark theme (Catppuccin, Gruvbox, Tokyo Night, Nord, etc.)
        switch(val) {
            case 2:    return p.color0 || "#313244";
            case 4:    return p.color8 || p.color0 || "#45475a";
            case 8:    return p.color3 || "#f9e2af"; // yellow
            case 16:   return p.accent || "#fab387"; // accent / peach
            case 32:   return p.color1 || "#f38ba8"; // red
            case 64:   return p.color9 || p.color1 || "#eba0ac"; // bright red
            case 128:  return p.color2 || "#a6e3a1"; // green
            case 256:  return p.color10 || p.color6 || "#94e2d5"; // cyan/teal
            case 512:  return p.color4 || "#89b4fa"; // blue
            case 1024: return p.color12 || p.color5 || "#b4befe"; // purple
            case 2048: return p.color5 || p.color13 || p.accent; // royal win!
            default:   return p.color14 || p.accent;
        }
    }

    function textColor(val) {
        var col = tileColor(val);
        var lum = colorLuminance(col);
        return lum > 0.55 ? "#11111b" : "#f8f8f2";
    }
}
