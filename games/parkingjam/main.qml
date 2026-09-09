import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    width: 480
    height: 640
    minimumWidth: 300
    minimumHeight: 400
    title: "Parking Jam"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    readonly property color colExitGreen: "#10b981"
    readonly property color colWarningYellow: "#f59e0b"
    readonly property color colDangerRed: "#ef4444"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // GAME STATE & PROGRESSION (Never-ending with 3 difficulty modes)
    // =========================================================================
    property string currentDifficulty: "easy" // "easy", "medium", "hard"
    property int currentLevel: 1
    property int moves: 0
    property int parMoves: 0
    property int slideMovesRequired: 0
    property int boardCols: 5
    property int boardRows: 5
    property bool isWon: false
    property int selectedCarUid: 0

    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Tap an unblocked car (green EXIT beacon) to drive off into the street.\n• Drag or tap blocked cars to slide them along their track into empty stalls.\n• Untangle the gridlock to clear the lot in as few moves as possible!\n\n• Move / Slide: Arrows, WASD, or Vim H / J / K / L\n• Action: Space or Enter\n• Select Car: Tab\n• Undo: U or Ctrl+Z\n• Restart: R\n• Sound: M\n• Help: ? or Esc"

    property var undoStack: []

    ListModel {
        id: carModel
    }

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#89b4fa";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.08);
            themeCardBg = Qt.darker(bg, 1.04);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.30);
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (lotCanvas) lotCanvas.requestPaint();
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

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : mainContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) Qt.quit();
        });
    }

    // =========================================================================
    // LEVEL LOADER & RESTART
    // =========================================================================
    function loadLevel(diff, lvlNum) {
        currentDifficulty = diff;
        currentLevel = Math.max(1, lvlNum);
        moves = 0;
        isWon = false;
        undoStack = [];
        carModel.clear();

        var raw = "{}";
        if (typeof levelVaultManager !== "undefined" && levelVaultManager) {
            raw = levelVaultManager.getLevelJson(currentDifficulty, currentLevel);
        }

        try {
            var data = JSON.parse(raw);
            boardCols = data.cols || 5;
            boardRows = data.rows || 5;
            parMoves = data.minMoves || (data.cars ? data.cars.length + 2 : 8);
            slideMovesRequired = data.slideMoves || 2;

            if (data.cars) {
                for (var i = 0; i < data.cars.length; i++) {
                    var c = data.cars[i];
                    carModel.append({
                        uid: i,
                        carId: c.carId || "taxi",
                        gx: c.gx,
                        gy: c.gy,
                        orient: c.orient,
                        dir: c.dir,
                        length: c.length || 2,
                        exited: false,
                        isClearToExit: false
                    });
                }
            }
        } catch (e) {
            console.log("[loadLevel] JSON error:", e);
        }

        selectedCarUid = 0;
        recalculateExitStatus();
        if (lotCanvas) lotCanvas.requestPaint();
    }

    function restartGame() {
        loadLevel(currentDifficulty, currentLevel);
        playSound("click");
    }

    function nextLevel() {
        loadLevel(currentDifficulty, currentLevel + 1);
        playSound("select");
    }

    function switchDifficulty(newDiff) {
        if (newDiff === currentDifficulty) return;
        currentDifficulty = newDiff;
        loadLevel(currentDifficulty, 1);
        playSound("select");
    }

    Component.onCompleted: {
        loadLevel("easy", 1);
    }

    // =========================================================================
    // GAME LOGIC: OCCUPANCY & EXIT VALIDATION
    // =========================================================================
    function isCellOccupied(cx, cy, ignoreUid) {
        if (cx < 0 || cx >= boardCols || cy < 0 || cy >= boardRows) return true;
        for (var i = 0; i < carModel.count; i++) {
            var c = carModel.get(i);
            if (c.exited || c.uid === ignoreUid) continue;
            var isH = c.orient === "H";
            for (var t = 0; t < c.length; t++) {
                var tx = c.gx + (isH ? t : 0);
                var ty = c.gy + (isH ? 0 : t);
                if (tx === cx && ty === cy) return true;
            }
        }
        return false;
    }

    function canCarExit(uid) {
        var c = carModel.get(uid);
        if (c.exited) return false;

        if (c.orient === "H") {
            if (c.dir === "east") {
                for (var x = c.gx + c.length; x < boardCols; x++) {
                    if (isCellOccupied(x, c.gy, uid)) return false;
                }
                return true;
            } else if (c.dir === "west") {
                for (var x = 0; x < c.gx; x++) {
                    if (isCellOccupied(x, c.gy, uid)) return false;
                }
                return true;
            }
        } else {
            if (c.dir === "south") {
                for (var y = c.gy + c.length; y < boardRows; y++) {
                    if (isCellOccupied(c.gx, y, uid)) return false;
                }
                return true;
            } else if (c.dir === "north") {
                for (var y = 0; y < c.gy; y++) {
                    if (isCellOccupied(c.gx, y, uid)) return false;
                }
                return true;
            }
        }
        return false;
    }

    function recalculateExitStatus() {
        for (var i = 0; i < carModel.count; i++) {
            var c = carModel.get(i);
            if (!c.exited) {
                var clear = canCarExit(c.uid);
                carModel.setProperty(i, "isClearToExit", clear);
            }
        }
    }

    function checkWin() {
        for (var i = 0; i < carModel.count; i++) {
            if (!carModel.get(i).exited) return;
        }
        isWon = true;
        playSound("win");
        if (typeof settingsManager !== "undefined" && settingsManager) {
            var best = settingsManager.getBestScore();
            if (best === 0 || root.moves < best) {
                settingsManager.setBestScore(root.moves);
            }
        }
    }

    function tapCar(uid) {
        var item = carRepeater.itemAt(uid);
        if (item) item.handleCarTap();
    }

    function trySlideCar(uid, delta) {
        var c = carModel.get(uid);
        if (c.exited) return false;

        var isH = c.orient === "H";
        var newGx = c.gx;
        var newGy = c.gy;

        if (isH) {
            newGx += delta;
            if (newGx < 0 || newGx + c.length > boardCols) return false;
            var checkX = delta > 0 ? c.gx + c.length : newGx;
            if (isCellOccupied(checkX, c.gy, uid)) return false;
        } else {
            newGy += delta;
            if (newGy < 0 || newGy + c.length > boardRows) return false;
            var checkY = delta > 0 ? c.gy + c.length : newGy;
            if (isCellOccupied(c.gx, checkY, uid)) return false;
        }

        undoStack.push({
            type: "slide",
            uid: uid,
            prevGx: c.gx,
            prevGy: c.gy
        });

        carModel.setProperty(uid, "gx", newGx);
        carModel.setProperty(uid, "gy", newGy);
        moves++;
        playSound("move");
        recalculateExitStatus();
        return true;
    }

    function triggerExit(uid) {
        var c = carModel.get(uid);
        if (c.exited || !c.isClearToExit) return false;

        undoStack.push({
            type: "exit",
            uid: uid,
            prevGx: c.gx,
            prevGy: c.gy
        });

        moves++;
        playSound("push");
        return true;
    }

    function undoLastMove() {
        if (undoStack.length === 0 || isWon) return;
        var last = undoStack.pop();
        if (last.type === "slide") {
            carModel.setProperty(last.uid, "gx", last.prevGx);
            carModel.setProperty(last.uid, "gy", last.prevGy);
        } else if (last.type === "exit") {
            carModel.setProperty(last.uid, "exited", false);
            carModel.setProperty(last.uid, "gx", last.prevGx);
            carModel.setProperty(last.uid, "gy", last.prevGy);
        }
        if (moves > 0) moves--;
        recalculateExitStatus();
        playSound("undo");
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLER
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true
        Behavior on color { ColorAnimation { duration: 150 } }

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

            if (root.isWon) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
                soundToast.show(root.fullPlayfield ? "⛶ Compact Window View" : "🔲 Standard Window View");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U || (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))) {
                root.undoLastMove();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            // Tab cycles active vehicle selection
            if (event.key === Qt.Key_Tab) {
                var nextUid = (root.selectedCarUid + 1) % carModel.count;
                for (var i = 0; i < carModel.count; i++) {
                    var idx = (root.selectedCarUid + 1 + i) % carModel.count;
                    if (!carModel.get(idx).exited) {
                        root.selectedCarUid = idx;
                        break;
                    }
                }
                event.accepted = true;
                return;
            }

            // Directional controls for active vehicle
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                root.trySlideCar(root.selectedCarUid, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                root.trySlideCar(root.selectedCarUid, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                root.trySlideCar(root.selectedCarUid, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.trySlideCar(root.selectedCarUid, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var c = carModel.get(root.selectedCarUid);
                if (c && c.isClearToExit) {
                    var item = carRepeater.itemAt(root.selectedCarUid);
                    if (item) item.handleCarTap();
                }
                event.accepted = true;
            }
        }

        // =====================================================================
        // ROW 1: HEADER (Visible in Standard Window Mode)
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
            height: visible ? Math.max(titleCol.height, statRow.height) : 0

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: statRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.title
                    font.pixelSize: Math.max(18, Math.min(26, headerItem.width * 0.065))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Classic arcade puzzle for Omarchy"
                    font.pixelSize: Math.max(10, Math.min(12, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards on right: LEVEL, MOVES, PAR
            Row {
                id: statRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // LEVEL Card
                Rectangle {
                    width: Math.max(54, Math.min(68, headerItem.width * 0.14))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "LEVEL"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentLevel.toString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                        }
                    }
                }

                // MOVES Card
                Rectangle {
                    width: Math.max(54, Math.min(68, headerItem.width * 0.14))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MOVES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.moves.toString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // PAR Card
                Rectangle {
                    width: Math.max(54, Math.min(68, headerItem.width * 0.14))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "PAR"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.parMoves.toString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeSubtext
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: SUBHEADER ACTION BAR (Difficulty Toggle, Help, Mute, Restart)
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 10 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 34 : 0

            readonly property bool isCrowded: subheaderItem.width < 450

            // Left: Help Button
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    height: 30
                    width: 30
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Text {
                        text: "?"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeAccent
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Undo Button
                Rectangle {
                    height: 30
                    width: 30
                    radius: 6
                    color: undoMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.undoStack.length > 0 ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Text {
                        text: "↶"
                        font.pixelSize: 14
                        font.bold: true
                        color: root.undoStack.length > 0 ? root.themeFg : root.themeSubtext
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: undoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.undoLastMove()
                    }
                }
            }

            // Center: 3 Difficulty Selector Pills (Easy, Medium, Hard)
            Rectangle {
                anchors.centerIn: parent
                height: 30
                width: diffRow.implicitWidth + 8
                radius: 6
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1

                Row {
                    id: diffRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Easy
                    Rectangle {
                        width: 48; height: 24; radius: 4
                        color: root.currentDifficulty === "easy" ? root.themeAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "Easy"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.currentDifficulty === "easy" ? root.themeBtnFg : root.themeSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchDifficulty("easy")
                        }
                    }

                    // Medium
                    Rectangle {
                        width: 58; height: 24; radius: 4
                        color: root.currentDifficulty === "medium" ? root.themeAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "Medium"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.currentDifficulty === "medium" ? root.themeBtnFg : root.themeSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchDifficulty("medium")
                        }
                    }

                    // Hard
                    Rectangle {
                        width: 48; height: 24; radius: 4
                        color: root.currentDifficulty === "hard" ? root.themeAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "Hard"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.currentDifficulty === "hard" ? root.themeBtnFg : root.themeSubtext
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchDifficulty("hard")
                        }
                    }
                }
            }

            // Right: Mute, Full-View, Restart
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Mute
                Rectangle {
                    height: 30
                    width: 30
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Text {
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Restart / New Game
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (restartRow.implicitWidth + 14)
                    radius: 6
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Reset (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            visible: !subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
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
        // TILING DESKTOP FLOATING HUD (Compact header active when 1/2 or 1/4 screen)
        // =====================================================================
        Rectangle {
            id: floatingTiledHUD
            visible: root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 34
            radius: 6
            z: 90
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: "LVL " + root.currentLevel
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                // Diff Pill
                Rectangle {
                    width: 44; height: 18; radius: 4
                    color: root.themeBoardBg
                    Text {
                        anchors.centerIn: parent
                        text: root.currentDifficulty.toUpperCase()
                        font.pixelSize: 8
                        font.bold: true
                        color: root.themeSubtext
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var nxt = root.currentDifficulty === "easy" ? "medium" : (root.currentDifficulty === "medium" ? "hard" : "easy");
                            root.switchDifficulty(nxt);
                        }
                    }
                }

                Text {
                    text: "• " + root.moves + "m / par " + root.parMoves
                    font.pixelSize: 10
                    color: root.themeFg
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // Undo
                Rectangle {
                    width: 22; height: 22; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↶"; font.pixelSize: 11; anchors.centerIn: parent; color: root.undoStack.length > 0 ? root.themeFg : root.themeSubtext }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.undoLastMove()
                    }
                }

                // Mute
                Rectangle {
                    width: 22; height: 22; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Restart
                Rectangle {
                    width: 22; height: 22; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartGame()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.rightMargin: root.isTiledDesktopMode ? 8 : 12

            // Concrete Parking Compound
            Rectangle {
                id: boardContainer
                anchors.centerIn: parent

                // Responsive tile sizing supporting 1/4 screen down to 300x400
                property real maxCellW: (playArea.width - 24) / (root.boardCols + 0.6)
                property real maxCellH: (playArea.height - 24) / (root.boardRows + 0.6)
                property real cellSize: Math.max(34, Math.min(84, Math.floor(Math.min(maxCellW, maxCellH))))

                width: (root.boardCols + 0.6) * cellSize
                height: (root.boardRows + 0.6) * cellSize
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 2
                radius: 12
                clip: false

                // Parking Surface
                Rectangle {
                    id: parkingLotSurface
                    anchors.centerIn: parent
                    width: root.boardCols * boardContainer.cellSize
                    height: root.boardRows * boardContainer.cellSize
                    color: "#131620"
                    radius: 6

                    // Painted Bays Canvas
                    Canvas {
                        id: lotCanvas
                        anchors.fill: parent
                        z: 5

                        Connections {
                            target: root
                            function onBoardColsChanged() { lotCanvas.requestPaint(); }
                            function onBoardRowsChanged() { lotCanvas.requestPaint(); }
                            function onCurrentLevelChanged() { lotCanvas.requestPaint(); }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var ts = boardContainer.cellSize;

                            // Dashed guide lines
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                            ctx.lineWidth = 1;
                            ctx.setLineDash([4, 4]);

                            for (var c = 1; c < root.boardCols; c++) {
                                ctx.beginPath();
                                ctx.moveTo(c * ts, 0); ctx.lineTo(c * ts, height);
                                ctx.stroke();
                            }
                            for (var r = 1; r < root.boardRows; r++) {
                                ctx.beginPath();
                                ctx.moveTo(0, r * ts); ctx.lineTo(width, r * ts);
                                ctx.stroke();
                            }

                            // Bay Corner Brackets
                            ctx.setLineDash([]);
                            for (var r = 0; r < root.boardRows; r++) {
                                for (var c = 0; c < root.boardCols; c++) {
                                    var bx = c * ts;
                                    var by = r * ts;
                                    var arm = Math.max(8, ts * 0.16);

                                    ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                                    ctx.lineWidth = 1.5;

                                    ctx.beginPath();
                                    ctx.moveTo(bx + 3, by + arm); ctx.lineTo(bx + 3, by + 3); ctx.lineTo(bx + arm, by + 3);
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.moveTo(bx + ts - arm, by + 3); ctx.lineTo(bx + ts - 3, by + 3); ctx.lineTo(bx + ts - 3, by + arm);
                                    ctx.stroke();

                                    // Stenciled Stall Number
                                    var stall = (r * root.boardCols + c + 1);
                                    ctx.fillStyle = "rgba(255, 255, 255, 0.07)";
                                    ctx.font = "bold 9px sans-serif";
                                    ctx.fillText(stall < 10 ? "0" + stall : "" + stall, bx + 6, by + 14);
                                }
                            }
                        }
                    }

                    // Japanese "止まれ" Road Marking
                    Text {
                        anchors.centerIn: parent
                        text: "止まれ"
                        font.pixelSize: Math.max(16, boardContainer.cellSize * 0.35)
                        font.bold: true
                        color: "#ffffff"
                        opacity: 0.07
                        z: 6
                    }

                    // Exit Beacons on Borders
                    // North Exit
                    Rectangle {
                        anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.6; height: 10; color: colExitGreen; radius: 3; opacity: 0.8
                        Text { text: "▲ EXIT"; font.pixelSize: 8; font.bold: true; color: "#000000"; anchors.centerIn: parent }
                    }
                    // South Exit
                    Rectangle {
                        anchors.top: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.6; height: 10; color: colExitGreen; radius: 3; opacity: 0.8
                        Text { text: "▼ EXIT"; font.pixelSize: 8; font.bold: true; color: "#000000"; anchors.centerIn: parent }
                    }
                    // East Exit
                    Rectangle {
                        anchors.left: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: parent.height * 0.6; color: colExitGreen; radius: 3; opacity: 0.8
                    }
                    // West Exit
                    Rectangle {
                        anchors.right: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: parent.height * 0.6; color: colExitGreen; radius: 3; opacity: 0.8
                    }

                    // ---------------------------------------------------------
                    // VEHICLES LAYER
                    // ---------------------------------------------------------
                    Repeater {
                        id: carRepeater
                        model: carModel

                        Item {
                            id: carDelegate
                            property int carUid: model.uid
                            property string carId: model.carId
                            property int gx: model.gx
                            property int gy: model.gy
                            property string orient: model.orient
                            property string dir: model.dir
                            property int carLen: model.length
                            property bool isH: orient === "H"
                            property bool isClear: model.isClearToExit
                            property bool isExited: model.exited
                            property string animState: "idle"

                            x: gx * boardContainer.cellSize
                            y: gy * boardContainer.cellSize
                            width: isH ? (carLen * boardContainer.cellSize) : boardContainer.cellSize
                            height: isH ? boardContainer.cellSize : (carLen * boardContainer.cellSize)
                            z: isExited ? 100 : (dragMa.drag.active ? 60 : 20)
                            visible: opacity > 0

                            Behavior on x {
                                enabled: !dragMa.drag.active && !driveAnim.running
                                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                            }
                            Behavior on y {
                                enabled: !dragMa.drag.active && !driveAnim.running
                                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                            }

                            // Shudder / Honk Bump Animation
                            SequentialAnimation {
                                id: bumpAnim
                                property real bx: 0
                                property real by: 0
                                ParallelAnimation {
                                    NumberAnimation { target: carSpriteBox; property: "x"; to: bumpAnim.bx; duration: 50 }
                                    NumberAnimation { target: carSpriteBox; property: "y"; to: bumpAnim.by; duration: 50 }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: carSpriteBox; property: "x"; to: 0; duration: 70; easing.type: Easing.OutBounce }
                                    NumberAnimation { target: carSpriteBox; property: "y"; to: 0; duration: 70; easing.type: Easing.OutBounce }
                                }
                                onFinished: carDelegate.animState = "idle"
                            }

                            // Drive Out Animation
                            SequentialAnimation {
                                id: driveAnim
                                property real tx: carDelegate.x
                                property real ty: carDelegate.y
                                ScriptAction { script: carDelegate.animState = "drive" }
                                ParallelAnimation {
                                    NumberAnimation { target: carDelegate; property: "x"; to: driveAnim.tx; duration: 320; easing.type: Easing.InQuad }
                                    NumberAnimation { target: carDelegate; property: "y"; to: driveAnim.ty; duration: 320; easing.type: Easing.InQuad }
                                }
                                NumberAnimation { target: carDelegate; property: "opacity"; to: 0; duration: 80 }
                                ScriptAction {
                                    script: {
                                        carModel.setProperty(carUid, "exited", true);
                                        root.recalculateExitStatus();
                                        root.checkWin();
                                    }
                                }
                            }

                            function handleCarTap() {
                                if (isExited || bumpAnim.running || driveAnim.running) return;
                                root.selectedCarUid = carUid;

                                if (isClear) {
                                    root.triggerExit(carUid);
                                    var offDist = 550;
                                    var destX = carDelegate.x;
                                    var destY = carDelegate.y;
                                    if (dir === "east") destX += offDist;
                                    else if (dir === "west") destX -= offDist;
                                    else if (dir === "south") destY += offDist;
                                    else if (dir === "north") destY -= offDist;
                                    driveAnim.tx = destX;
                                    driveAnim.ty = destY;
                                    driveAnim.start();
                                } else {
                                    // Try sliding forward
                                    var fwdDelta = (dir === "east" || dir === "south") ? 1 : -1;
                                    var slid = root.trySlideCar(carUid, fwdDelta);
                                    if (!slid) {
                                        // Try sliding backward
                                        slid = root.trySlideCar(carUid, -fwdDelta);
                                    }

                                    if (!slid) {
                                        // Blocked! Honk & shudder
                                        carDelegate.animState = "brake";
                                        var nudge = 8;
                                        bumpAnim.bx = (dir === "east") ? nudge : ((dir === "west") ? -nudge : 0);
                                        bumpAnim.by = (dir === "south") ? nudge : ((dir === "north") ? -nudge : 0);
                                        bumpAnim.start();
                                        root.playSound("push");
                                        blockedToast.opacity = 1.0;
                                        blockedFade.restart();
                                    }
                                }
                            }

                            Item {
                                id: carSpriteBox
                                anchors.fill: parent

                                // Shadow
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.88
                                    height: parent.height * 0.88
                                    radius: carDelegate.isH ? 8 : 10
                                    color: "#000000"
                                    opacity: 0.50
                                }

                                // Pulsing Green Exit Beacon
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: carDelegate.isH ? 8 : 10
                                    color: "transparent"
                                    border.color: colExitGreen
                                    border.width: 2
                                    visible: carDelegate.isClear && !carDelegate.isExited

                                    SequentialAnimation on opacity {
                                        running: parent.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 550 }
                                        NumberAnimation { to: 0.95; duration: 550 }
                                    }
                                }

                                // Selected Car Indicator Ring
                                Rectangle {
                                    anchors.fill: parent
                                    radius: carDelegate.isH ? 8 : 10
                                    color: "transparent"
                                    border.color: root.themeAccent
                                    border.width: 1.5
                                    visible: (root.selectedCarUid === carUid) && !carDelegate.isExited && !carDelegate.isClear
                                    opacity: 0.85
                                }

                                // Vehicle Sprite
                                Image {
                                    id: sprite
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    source: "sprites/" + carDelegate.carId + "/" + (carDelegate.dir === "west" ? "east" : carDelegate.dir) + "_" + carDelegate.animState + ".png"
                                    mirror: carDelegate.dir === "west"
                                }

                                // Exit Tag
                                Rectangle {
                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 2
                                    width: 24; height: 14; radius: 3
                                    color: colExitGreen
                                    visible: carDelegate.isClear && !carDelegate.isExited
                                    Text { anchors.centerIn: parent; text: "EXIT"; font.pixelSize: 7; font.bold: true; color: "#000000" }
                                }

                                // Blocked Bubble
                                Rectangle {
                                    id: blockedToast
                                    anchors.centerIn: parent
                                    width: 52; height: 18; radius: 9
                                    color: colDangerRed
                                    opacity: 0.0
                                    Text { anchors.centerIn: parent; text: "BLOCKED"; font.pixelSize: 8; font.bold: true; color: "#ffffff" }
                                    NumberAnimation { id: blockedFade; target: blockedToast; property: "opacity"; to: 0; duration: 450; easing.type: Easing.InQuad }
                                }
                            }

                            MouseArea {
                                id: dragMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: carDelegate.isClear ? Qt.PointingHandCursor : (dragMa.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                drag.target: carDelegate
                                drag.axis: carDelegate.isH ? Drag.XAxis : Drag.YAxis
                                drag.minimumX: 0
                                drag.maximumX: (root.boardCols - (carDelegate.isH ? carDelegate.carLen : 1)) * boardContainer.cellSize
                                drag.minimumY: 0
                                drag.maximumY: (root.boardRows - (carDelegate.isH ? 1 : carDelegate.carLen)) * boardContainer.cellSize

                                property real startDragX: 0
                                property real startDragY: 0
                                property bool wasDragged: false

                                onPressed: {
                                    startDragX = carDelegate.x;
                                    startDragY = carDelegate.y;
                                    wasDragged = false;
                                    root.selectedCarUid = carUid;
                                }

                                onPositionChanged: {
                                    var dist = Math.abs(carDelegate.x - startDragX) + Math.abs(carDelegate.y - startDragY);
                                    if (dist > 8) wasDragged = true;
                                }

                                onReleased: {
                                    if (!wasDragged) {
                                        carDelegate.handleCarTap();
                                        return;
                                    }

                                    var ts = boardContainer.cellSize;
                                    var targetGx = Math.round(carDelegate.x / ts);
                                    var targetGy = Math.round(carDelegate.y / ts);
                                    var origGx = carDelegate.gx;
                                    var origGy = carDelegate.gy;

                                    if (carDelegate.isH) {
                                        var delta = targetGx - origGx;
                                        if (delta !== 0) {
                                            var step = delta > 0 ? 1 : -1;
                                            var totalSlid = 0;
                                            for (var s = 0; s < Math.abs(delta); s++) {
                                                if (root.trySlideCar(carUid, step)) totalSlid += step;
                                                else break;
                                            }
                                        }
                                    } else {
                                        var delta = targetGy - origGy;
                                        if (delta !== 0) {
                                            var step = delta > 0 ? 1 : -1;
                                            var totalSlid = 0;
                                            for (var s = 0; s < Math.abs(delta); s++) {
                                                if (root.trySlideCar(carUid, step)) totalSlid += step;
                                                else break;
                                            }
                                        }
                                    }

                                    // Snap to discrete cell coordinates
                                    carDelegate.x = carDelegate.gx * ts;
                                    carDelegate.y = carDelegate.gy * ts;
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // LEVEL WON VICTORY OVERLAY
        // =====================================================================
        Rectangle {
            id: winOverlay
            anchors.fill: parent
            visible: root.isWon
            color: Qt.rgba(0, 0, 0, 0.78)
            z: 200

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(320, parent.width * 0.85)
                height: 220
                radius: 12
                color: root.themeCardBg
                border.color: colExitGreen
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    width: parent.width - 40

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🎉 LOT CLEARED!"
                        font.pixelSize: 20
                        font.bold: true
                        color: colExitGreen
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Level " + root.currentLevel + " (" + root.currentDifficulty.toUpperCase() + ")"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeFg
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18

                        Column {
                            Text { text: "MOVES"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: root.moves.toString(); font.pixelSize: 18; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        Column {
                            Text { text: "PAR"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: root.parMoves.toString(); font.pixelSize: 18; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }

                    // Next Level Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 38
                        radius: 8
                        color: nextMa.containsMouse ? Qt.lighter(colExitGreen, 1.15) : colExitGreen

                        Text {
                            anchors.centerIn: parent
                            text: "Next Level (Space) ▶"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#000000"
                        }

                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextLevel()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Game Over, Sound Toast)
        // =====================================================================
        // Help Modal (Canonical Template Standard)
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#b3000000"
            visible: root.showHelp
            z: 900

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
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
                            onClicked: root.showHelp = false
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

        // =====================================================================
        // SOUND TOAST NOTIFICATION
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: toastText.implicitWidth + 24
            height: 30
            radius: 15
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            opacity: 0.0
            z: 250

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
            }

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; to: 1.0; duration: 150 }
                PauseAnimation { duration: 1000 }
                NumberAnimation { target: soundToast; property: "opacity"; to: 0.0; duration: 250 }
            }
        }

        // =====================================================================
        // CANONICAL SPLASH SCREEN
        // =====================================================================
        SplashScreen {
            id: splashScreen
            anchors.fill: parent
            visible: root.splashEnabled && opacity > 0
            z: 1000
        }
    }
}
