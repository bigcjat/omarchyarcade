import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 720
    minimumWidth: 340
    minimumHeight: 460
    title: "Nuts Sort"

    // =========================================================================
    // OMARCHY THEME TOKENS
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#F59E0B"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // GAME STATE
    // =========================================================================
    property var boardBolts: []
    property int currentLevel: 1
    property int unlockedLevel: 1
    property int moves: 0
    property int bestMoves: 0
    property int selectedBoltIndex: -1
    property int cursorIndex: 0
    property string difficulty: "normal" // "casual", "normal", "hard"
    property bool isDeadlocked: false
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool showLevelSelect: false
    property int stagePage: 0
    onShowLevelSelectChanged: {
        if (showLevelSelect) {
            stagePage = Math.floor((root.currentLevel - 1) / 50);
        }
    }
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained

    property string helpText: "• OBJECTIVE: Sort all matching colored nuts onto their own bolts.\n• PICK & PLACE: Click a bolt (or press Space/Enter) to unscrew and lift the top nut, then click the destination bolt.\n• RULES:\n  1. Destination must have space (max 4 nuts per bolt).\n  2. A nut can only land on an EMPTY bolt or on a nut of the SAME COLOR.\n• DIFFICULTY:\n  - Casual: Generous buffer (+extra buffer bolts)\n  - Normal: Balanced progression (2 buffer bolts, milestone challenges)\n  - Hard: Tight Squeeze (1 buffer bolt challenges)\n• CONTROLS:\n  - Mouse: Click bolt to lift / drop\n  - Arrows / WASD / Vim (H/J/K/L): Navigate cursor\n  - Space / Enter: Lift / Place nut\n  - 1–9: Direct select bolt #1 to #9\n  - U: Undo move\n  - R: Restart level\n  - L: Level selector\n  - M: Mute audio\n  - Shift+F: Compact / Tiled view"

    // Animation ticker (~60 FPS)
    property real animTime: 0
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            root.animTime += 0.016;
            Engine.update(0.016, callbacks);
        }
    }

    // Callbacks
    readonly property var callbacks: {
        return {
            onSound: function(name) { root.playSound(name); },
            onDeadlock: function() {
                root.isDeadlocked = true;
                root.playSound("error");
            },
            onDeadlockCleared: function() {
                root.isDeadlocked = false;
            },
            onBoltComplete: function(boltIdx) {
                var center = getBoltCenter(boltIdx);
                Engine.spawnSparkles(center.x, center.y - 100, "#FBBF24");
                soundToast.show("✨ Bolt Complete!");
            },
            onWin: function() {
                root.isDeadlocked = false;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setUnlockedLevel(Engine.currentLevel + 1);
                    settingsManager.setBestMoves(Engine.currentLevel, Engine.moves);
                    settingsManager.setLastLevel(Engine.currentLevel + 1);
                    root.unlockedLevel = settingsManager.getUnlockedLevel();
                    root.bestMoves = settingsManager.getBestMoves(Engine.currentLevel);
                }
                Engine.spawnConfetti(boardContainer.width, boardContainer.height);
                soundToast.show("🎉 Level " + root.currentLevel + " Solved!");
                autoAdvanceTimer.restart();
            }
        };
    }

    Timer {
        id: autoAdvanceTimer
        interval: 1300
        repeat: false
        onTriggered: {
            Engine.nextLevel(callbacks);
            root.updateUI();
        }
    }

    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#F59E0B";
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

    function restartLevel() {
        flyingNut.visible = false;
        Engine.resetGame(callbacks);
        updateUI();
    }

    function jumpToLevel(lvl) {
        flyingNut.visible = false;
        Engine.loadLevel(lvl);
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setLastLevel(Engine.currentLevel);
        }
        updateUI();
    }

    function setDifficulty(diff) {
        if (diff === "casual" || diff === "normal" || diff === "hard") {
            root.difficulty = diff;
            Engine.setDifficulty(diff);
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setValue("difficulty", diff);
            }
            var toastMsg = "Difficulty: " + (diff === "casual" ? "☕ Casual (+Buffer Bolts)" : (diff === "hard" ? "🔥 Hard (Tight Squeeze)" : "★ Normal (Balanced)"));
            soundToast.show(toastMsg);
            playSound("select");
            updateUI();
        }
    }

    function cycleDifficulty() {
        var next = "normal";
        if (root.difficulty === "casual") next = "normal";
        else if (root.difficulty === "normal") next = "hard";
        else if (root.difficulty === "hard") next = "casual";
        setDifficulty(next);
    }

    function updateUI() {
        currentLevel = Engine.currentLevel;
        moves = Engine.moves;
        boardBolts = Engine.bolts.slice();
        selectedBoltIndex = Engine.selectedBolt;
        cursorIndex = Engine.cursorIndex;
        isDeadlocked = Engine.isDeadlocked;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            bestMoves = settingsManager.getBestMoves(currentLevel);
        }
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
        var startLvl = 1;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.unlockedLevel = settingsManager.getUnlockedLevel();
            startLvl = settingsManager.getLastLevel();
            var savedDiff = settingsManager.getValue("difficulty", "normal");
            if (savedDiff === "casual" || savedDiff === "normal" || savedDiff === "hard") {
                root.difficulty = savedDiff;
                Engine.difficulty = savedDiff;
            }
        }
        Engine.currentLevel = startLvl;
        Engine.init(boardContainer.width, boardContainer.height);
        updateUI();
    }

    function getNutFrame(boltIdx, slotIdx) {
        var offsets = [
            [1, 5, 2, 7],
            [6, 2, 8, 3],
            [3, 7, 0, 5],
            [8, 4, 1, 6],
            [2, 6, 3, 8],
            [5, 1, 7, 2],
            [0, 4, 8, 3],
            [7, 3, 5, 1],
            [4, 8, 2, 6]
        ];
        var b = (boltIdx >= 0) ? (boltIdx % offsets.length) : 0;
        var s = (slotIdx >= 0) ? (slotIdx % 4) : 0;
        return offsets[b][s];
    }

    // Dynamic aspect-ratio packing: finds the optimal (cols, rows) grid to maximize bolt scale
    readonly property int boltCount: root.boardBolts ? root.boardBolts.length : 0
    readonly property var currentLayout: computeLayout(boltCount, playfieldArea.width, playfieldArea.height)

    function computeLayout(total, w, h) {
        if (total <= 0 || w <= 0 || h <= 0) {
            return { cols: 1, rows: 1, bScale: 1.0, centers: [] };
        }

        var boltBaseW = 140;
        var boltBaseH = 240;

        var bestScale = 0;
        var bestCols = 1;
        var bestRows = total;

        for (var c = 1; c <= total; c++) {
            var r = Math.ceil(total / c);
            if (total <= 3 && r > 1) continue; // Keep 1 to 3 bolts on a single row

            var sX = (w * 0.92) / (Math.max(1, (c - 1) * 1.18 + 1.05) * boltBaseW);
            var vertFactor = (r === 1) ? 1.0 : ((r - 1) * 1.15 + 1.0);
            var sY = (h * 0.88) / (vertFactor * boltBaseH);
            var s = Math.min(sX, sY);
            s = Math.min(1.02, Math.max(0.35, s));

            if (s > bestScale * 1.02 || (Math.abs(s - bestScale) <= 0.02 && r < bestRows)) {
                bestScale = s;
                bestCols = c;
                bestRows = r;
            }
        }

        var cols = bestCols;
        var rows = bestRows;
        var bScale = bestScale;

        // Distribute bolts evenly across rows
        var rowCounts = [];
        var rem = total;
        for (var rIdx = 0; rIdx < rows; rIdx++) {
            var count = Math.ceil(rem / (rows - rIdx));
            rowCounts.push(count);
            rem -= count;
        }

        var horizSpacing = Math.min(w / (cols + 0.1), boltBaseW * bScale * 1.25);
        var vertSpacing = (rows > 1) ? (boltBaseH * bScale * 1.16) : 0;
        if (rows > 1) {
            var maxVert = (h * 0.88 - boltBaseH * bScale) / (rows - 1);
            vertSpacing = Math.min(vertSpacing, maxVert);
            vertSpacing = Math.max(vertSpacing, boltBaseH * bScale * 1.08);
        }

        var totalGridH = (rows - 1) * vertSpacing;
        var startY = (h / 2) - (totalGridH / 2) + (boltBaseH * bScale * 0.28);

        var centers = [];
        for (var ri = 0; ri < rows; ri++) {
            var countInRow = rowCounts[ri];
            var rowY = startY + ri * vertSpacing;

            // Horizontally center this specific row!
            var rowWidth = (countInRow - 1) * horizSpacing;
            var startX = (w / 2) - (rowWidth / 2);

            for (var ci = 0; ci < countInRow; ci++) {
                var colX = (countInRow === 1) ? (w / 2) : (startX + ci * horizSpacing);
                centers.push({ x: colX, y: rowY, bScale: bScale, row: ri, col: ci });
            }
        }

        return { cols: cols, rows: rows, bScale: bScale, centers: centers };
    }

    function getBoltCenter(idx) {
        var layout = currentLayout;
        if (layout && layout.centers && idx >= 0 && idx < layout.centers.length) {
            return layout.centers[idx];
        }
        return { x: playfieldArea.width / 2, y: playfieldArea.height / 2, bScale: 1.0 };
    }

    // Handle Transfer Animation
    function animateNutTransfer(fromIdx, toIdx) {
        if (flyingNut.running) return;

        var fromPos = getBoltCenter(fromIdx);
        var toPos = getBoltCenter(toIdx);
        var stackFrom = Engine.bolts[fromIdx];
        var stackTo = Engine.bolts[toIdx];

        var movingColor = stackFrom[stackFrom.length - 1];

        // Bolt scale from dynamic layout
        var bScale = (root.currentLayout && root.currentLayout.bScale) ? root.currentLayout.bScale : 1.0;

        var fromBoltItemY = fromPos.y - (210 * bScale);
        var toBoltItemY = toPos.y - (210 * bScale);

        var startX = fromPos.x;
        var startY = fromBoltItemY - (20 * bScale);
        var hoverToY = toBoltItemY - (20 * bScale);
        var targetY = toBoltItemY + ((124 - stackTo.length * 26) * bScale);

        var fromBaseFrame = getNutFrame(fromIdx, stackFrom.length - 1);
        var fromLiftDist = ((124 - (stackFrom.length - 1) * 26) - (-20)) * bScale;
        var threadPitch = 6.5 * bScale;
        var turns = Math.round((fromLiftDist / threadPitch) * 72);
        var initialFrame = (fromBaseFrame - turns) % 12;
        if (initialFrame < 0) initialFrame += 12;

        var targetBaseFrame = getNutFrame(toIdx, stackTo.length);

        flyingNut.bScale = bScale;
        flyingNut.colorId = movingColor;
        flyingNut.startX = startX;
        flyingNut.startY = startY;
        flyingNut.endX = toPos.x;
        flyingNut.hoverToY = hoverToY;
        flyingNut.endY = targetY;
        flyingNut.toBoltItemY = toBoltItemY;
        flyingNut.toBoltCenterY = toPos.y;
        flyingNut.fromIdx = fromIdx;
        flyingNut.toIdx = toIdx;
        flyingNut.initialFrame = initialFrame;
        flyingNut.targetBaseFrame = targetBaseFrame;
        flyingNut.descentDuration = Math.max(220, Math.min(520, Math.round((targetY - hoverToY) * 1.8)));

        flyingNut.startFlight();
    }

    // Bolt Selection & Transfer Logic
    function handleBoltClick(idx) {
        if (flyingNut.running || Engine.gameState !== "playing") return;
        if (idx < 0 || idx >= Engine.bolts.length) return;

        Engine.cursorIndex = idx;
        root.cursorIndex = idx;

        if (root.selectedBoltIndex === -1) {
            // Pick up top nut
            if (Engine.bolts[idx].length === 0) {
                root.playSound("click");
                return;
            }
            if (Engine.isBoltComplete(idx)) {
                root.playSound("click");
                return;
            }

            Engine.selectedBolt = idx;
            root.selectedBoltIndex = idx;
            root.playSound("nut_lift");
        } else {
            // Drop nut
            if (idx === root.selectedBoltIndex) {
                // Deselect: place nut back down
                Engine.selectedBolt = -1;
                root.selectedBoltIndex = -1;
                root.playSound("click");
            } else {
                var from = root.selectedBoltIndex;
                if (Engine.canMove(from, idx)) {
                    // Start 3D flight & spin animation
                    root.animateNutTransfer(from, idx);
                } else {
                    root.playSound("error");
                    soundToast.show("❌ Invalid Move");
                }
            }
        }
    }


    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLERS
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

            if (root.showLevelSelect) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_L) {
                    root.showLevelSelect = false;
                    event.accepted = true;
                    return;
                }
            }

            if (Engine.gameState === "won") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_N) {
                    Engine.nextLevel(callbacks);
                    root.updateUI();
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
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                root.cycleDifficulty();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.restartLevel();
                soundToast.show("🔄 Level Restarted");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U) {
                if (Engine.undo(callbacks)) {
                    root.updateUI();
                    soundToast.show("↶ Move Undone");
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_L) {
                root.showLevelSelect = !root.showLevelSelect;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P) {
                Engine.prevLevel(callbacks);
                root.updateUI();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_N) {
                Engine.nextLevel(callbacks);
                root.updateUI();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                var boltIdx = event.key - Qt.Key_1;
                if (boltIdx < Engine.bolts.length) {
                    root.handleBoltClick(boltIdx);
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.handleInput("left", callbacks);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.handleInput("right", callbacks);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.handleInput("up", callbacks);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.handleInput("down", callbacks);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.handleBoltClick(Engine.cursorIndex);
                event.accepted = true;
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
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
            height: visible ? Math.max(titleCol.height, scoreRow.height) : 0

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
                    text: root.title
                    font.pixelSize: Math.max(20, Math.min(32, headerItem.width * 0.075))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Engine.isCurrentLevelChallenge ? "🔥 TIGHT SQUEEZE: ONLY 1 BUFFER BOLT!" : "Tactile Nut & Bolt Color Sorting Puzzle"
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    font.bold: Engine.isCurrentLevelChallenge
                    color: Engine.isCurrentLevelChallenge ? "#EF4444" : root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: Math.max(60, Math.min(78, headerItem.width * 0.15))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: Engine.isCurrentLevelChallenge ? "#EF4444" : root.themeBorder
                    border.width: Engine.isCurrentLevelChallenge ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Engine.isCurrentLevelChallenge ? "CHALLENGE" : "LEVEL"
                            font.pixelSize: 8
                            font.bold: true
                            color: Engine.isCurrentLevelChallenge ? "#EF4444" : root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentLevel.toString() + (Engine.isCurrentLevelChallenge ? " 🔥" : "")
                            font.pixelSize: 16
                            font.bold: true
                            color: Engine.isCurrentLevelChallenge ? "#EF4444" : root.themeAccent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showLevelSelect = !root.showLevelSelect
                    }
                }

                Rectangle {
                    width: Math.max(60, Math.min(78, headerItem.width * 0.15))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
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
                            text: "MOVES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.moves.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
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

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 108
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
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
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 92
                    radius: 8
                    color: levelsMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: levelsMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "☰"
                            font.pixelSize: 13
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Stages"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: levelsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showLevelSelect = !root.showLevelSelect
                    }
                }

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 98
                    radius: 8
                    color: diffMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.difficulty === "hard" ? "#EF4444" : (root.difficulty === "casual" ? "#10B981" : (diffMouse.containsMouse ? root.themeAccent : root.themeBorder))
                    border.width: root.difficulty === "hard" ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.difficulty === "casual" ? "☕" : (root.difficulty === "hard" ? "🔥" : "★")
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.difficulty === "casual" ? "Casual" : (root.difficulty === "hard" ? "Hard" : "Normal")
                            font.pixelSize: 11
                            font.bold: true
                            color: root.difficulty === "hard" ? "#EF4444" : (root.difficulty === "casual" ? "#10B981" : root.themeFg)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: diffMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleDifficulty()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 88
                    radius: 8
                    color: root.isDeadlocked ? Qt.rgba(0.93, 0.26, 0.26, 0.25) : (undoMouse.containsMouse ? root.themeCardBg : root.themeBoardBg)
                    border.color: root.isDeadlocked ? "#EF4444" : (undoMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: root.isDeadlocked ? 2 : 1
                    opacity: Engine.undoStack.length > 0 ? 1.0 : 0.5
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "↶"
                            font.pixelSize: 14
                            color: root.isDeadlocked ? "#EF4444" : root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isDeadlocked ? "Undo!" : "Undo (U)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isDeadlocked ? "#EF4444" : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: undoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Engine.undo(callbacks)) {
                                root.updateUI();
                                soundToast.show("↶ Move Undone");
                            }
                        }
                    }
                }

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 84
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 13
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

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : 96
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Reset (R)"
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
                        onClicked: {
                            root.restartLevel();
                            soundToast.show("🔄 Level Restarted");
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD
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
                    text: "Nuts Sort"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    text: "• LVL " + root.currentLevel
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "• MOVES: " + root.moves
                    font.pixelSize: 10
                    color: root.themeSubtext
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↶"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Engine.undo(callbacks)) root.updateUI();
                        }
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartLevel()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER WITH 3D PRE-RENDERED HARDWARE SPRITES
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 10 : 16
            anchors.rightMargin: root.isTiledDesktopMode ? 10 : 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12
                clip: true

                Item {
                    id: playfieldArea
                    anchors.fill: parent

                    // Bolt elements repeater
                    Repeater {
                        id: boltRepeater
                        model: root.boardBolts

                        Item {
                            id: boltItem
                            readonly property int boltIndex: index
                            readonly property var centerPos: root.getBoltCenter(index)
                            readonly property bool isSelected: (root.selectedBoltIndex === index)
                            readonly property bool isCursor: (root.cursorIndex === index)
                            readonly property bool isComplete: Engine.isBoltComplete(index)
                            readonly property var stack: (root.boardBolts && root.boardBolts[index]) ? root.boardBolts[index] : []

                            // Responsive scaling from dynamic aspect-ratio layout
                            readonly property real bScale: (root.currentLayout && root.currentLayout.bScale) ? root.currentLayout.bScale : 1.0

                            x: centerPos.x - (width / 2)
                            y: centerPos.y - (height - 30 * bScale)
                            z: Math.floor(centerPos.y)
                            width: 140 * bScale
                            height: 240 * bScale

                            // 1. Bolt Base (Metallic pedestal & contact shadow)
                            Image {
                                id: boltBaseImg
                                anchors.fill: parent
                                source: "sprites/bolt_base.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                z: 1
                            }

                            // Lift animation state for top nut
                            property real liftProgress: (isSelected && stack.length > 0 && !flyingNut.visible) ? 1.0 : 0.0
                            Behavior on liftProgress {
                                NumberAnimation { duration: Math.max(220, Math.min(500, Math.round(boltItem.topLiftDist * 1.8))); easing.type: Easing.InOutQuad }
                            }
                            readonly property bool isTopNutPresent: stack.length > 0 && !(flyingNut.visible && flyingNut.fromIdx === boltIndex)
                            readonly property string topNutColor: (stack.length > 0) ? stack[stack.length - 1] : "red"
                            readonly property real topSeatedY: (124 - (stack.length - 1) * 26) * bScale
                            readonly property real topHoverY: -20 * bScale
                            readonly property real topNutY: topSeatedY + (topHoverY - topSeatedY) * liftProgress
                            readonly property real topLiftDist: topSeatedY - topNutY
                            readonly property int topBaseFrame: (stack.length > 0) ? root.getNutFrame(boltIndex, stack.length - 1) : 0
                            readonly property int topNutFrame: {
                                var threadPitch = 6.5 * bScale;
                                var turns = Math.round((topLiftDist / threadPitch) * 72);
                                var f = (topBaseFrame - turns) % 12;
                                return (f < 0) ? f + 12 : f;
                            }

                            // 2. Stationary Nut Back Halves (below top nut)
                            Repeater {
                                model: Math.max(0, boltItem.stack.length - 1)

                                Item {
                                    z: 10 + index
                                    width: 140 * boltItem.bScale
                                    height: 100 * boltItem.bScale
                                    x: 0
                                    y: (124 - index * 26) * boltItem.bScale

                                    Image {
                                        anchors.fill: parent
                                        source: "sprites/nut_back_" + boltItem.stack[index] + "_" + root.getNutFrame(boltItem.boltIndex, index) + ".png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                            }

                            // 3. Top Nut Back Half (unscrews up & down the rod)
                            Item {
                                visible: boltItem.isTopNutPresent
                                z: 20
                                width: 140 * boltItem.bScale
                                height: 100 * boltItem.bScale
                                x: 0
                                y: boltItem.topNutY

                                Image {
                                    anchors.fill: parent
                                    source: "sprites/nut_back_" + boltItem.topNutColor + "_" + boltItem.topNutFrame + ".png"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            // 4. Bolt Rod (Threaded shaft passing through seated & lifted nuts)
                            Image {
                                id: boltRodImg
                                anchors.fill: parent
                                source: "sprites/bolt_rod.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                z: 50
                            }

                            // 5. Stationary Nut Front Halves (below top nut)
                            Repeater {
                                model: Math.max(0, boltItem.stack.length - 1)

                                Item {
                                    z: 60 + index
                                    width: 140 * boltItem.bScale
                                    height: 100 * boltItem.bScale
                                    x: 0
                                    y: (124 - index * 26) * boltItem.bScale

                                    Image {
                                        anchors.fill: parent
                                        source: "sprites/nut_front_" + boltItem.stack[index] + "_" + root.getNutFrame(boltItem.boltIndex, index) + ".png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                            }

                            // 6. Top Nut Front Half (unscrews up & down the rod)
                            Item {
                                visible: boltItem.isTopNutPresent
                                z: 70
                                width: 140 * boltItem.bScale
                                height: 100 * boltItem.bScale
                                x: 0
                                y: boltItem.topNutY

                                Image {
                                    anchors.fill: parent
                                    source: "sprites/nut_front_" + boltItem.topNutColor + "_" + boltItem.topNutFrame + ".png"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                            }


                            // Bolt Base Number Pill (keyboard play indicator)
                            Rectangle {
                                id: boltPill
                                width: Math.max(20, Math.round(24 * boltItem.bScale))
                                height: Math.max(20, Math.round(24 * boltItem.bScale))
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: Math.round(-12 * boltItem.bScale)
                                z: 80
                                color: boltItem.isComplete ? "#10B981" : (boltItem.isCursor ? root.themeAccent : root.themeCardBg)
                                border.color: boltItem.isComplete ? "#10B981" : (boltItem.isCursor ? root.themeAccent : root.themeBorder)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: boltItem.isComplete ? "✓" : (boltItem.boltIndex + 1).toString()
                                    font.pixelSize: boltItem.isComplete ? Math.max(10, Math.round(12 * boltItem.bScale)) : Math.max(9, Math.round(11 * boltItem.bScale))
                                    font.bold: true
                                    color: boltItem.isComplete ? "#FFFFFF" : (boltItem.isCursor ? root.themeBtnFg : root.themeFg)
                                }
                            }

                            // Interactive Mouse Click
                            MouseArea {
                                anchors.fill: parent
                                anchors.topMargin: -40
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.handleBoltClick(boltItem.boltIndex);
                                }
                            }
                        }
                    }

                    // 4. Flying / Transferring 3D Nut Animation
                    Item {
                        id: flyingNut
                        visible: false
                        z: isDescending ? (Math.floor(toBoltCenterY) + 5) : 2000

                        property string colorId: "red"
                        property real startX: 0
                        property real startY: 0
                        property real endX: 0
                        property real hoverToY: 0
                        property real endY: 0
                        property real toBoltItemY: 0
                        property real toBoltCenterY: 0
                        property int fromIdx: -1
                        property int toIdx: -1
                        property int initialFrame: 0
                        property int targetBaseFrame: 0
                        property real bScale: 1.0

                        property real flightX: 0
                        property real flightY: 0
                        property real flightProgress: 0.0
                        property bool isDescending: false

                        property int descentDuration: 220

                        width: 140 * bScale
                        height: 100 * bScale
                        x: flightX - width / 2
                        y: flightY

                        readonly property bool running: flightAnim.running

                        onFlightProgressChanged: {
                            if (!isDescending) {
                                var p = flightProgress;
                                flightX = startX + (endX - startX) * p;
                                var linearY = startY + (hoverToY - startY) * p;
                                // 3D parabolic carry arc through the air
                                var arcH = 45 * bScale;
                                var arcOffset = 4 * arcH * p * (1 - p);
                                flightY = linearY - arcOffset;
                            }
                        }

                        readonly property int spinFrame: {
                            if (!isDescending) {
                                return initialFrame;
                            }
                            var dist = endY - flightY;
                            var threadPitch = 6.5 * bScale;
                            var turns = Math.round((dist / threadPitch) * 72);
                            var f = (targetBaseFrame - turns) % 12;
                            return (f < 0) ? f + 12 : f;
                        }

                        // Nut Back Half
                        Image {
                            anchors.fill: parent
                            source: "sprites/nut_back_" + flyingNut.colorId + "_" + flyingNut.spinFrame + ".png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            z: 1
                        }

                        // Destination bolt rod passing through the nut while screwing down
                        Item {
                            visible: flyingNut.isDescending
                            anchors.fill: parent
                            clip: true
                            z: 2

                            Image {
                                width: 140 * flyingNut.bScale
                                height: 240 * flyingNut.bScale
                                x: 0
                                y: flyingNut.toBoltItemY - flyingNut.y
                                source: "sprites/bolt_rod.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                        }

                        // Nut Front Half
                        Image {
                            anchors.fill: parent
                            source: "sprites/nut_front_" + flyingNut.colorId + "_" + flyingNut.spinFrame + ".png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            z: 3
                        }

                        SequentialAnimation {
                            id: flightAnim

                            // Phase 1: Float with 3D carry arc across through empty air (steady orientation)
                            NumberAnimation {
                                target: flyingNut
                                property: "flightProgress"
                                from: 0.0
                                to: 1.0
                                duration: 280
                                easing.type: Easing.InOutQuad
                            }

                            // Switch to descending on target bolt
                            PropertyAction {
                                target: flyingNut
                                property: "isDescending"
                                value: true
                            }

                            // Phase 2: Screw down the destination bolt rod into the target slot
                            NumberAnimation {
                                target: flyingNut
                                property: "flightY"
                                from: flyingNut.hoverToY
                                to: flyingNut.endY
                                duration: flyingNut.descentDuration
                                easing.type: Easing.InQuad
                            }

                            ScriptAction {
                                script: {
                                    flyingNut.visible = false;
                                    flyingNut.isDescending = false;
                                    root.playSound("nut_drop");
                                    Engine.executeMove(flyingNut.fromIdx, flyingNut.toIdx, root.callbacks);
                                    Engine.selectedBolt = -1;
                                    root.selectedBoltIndex = -1;
                                    root.updateUI();
                                }
                            }
                        }

                        function startFlight() {
                            isDescending = false;
                            flightProgress = 0.0;
                            flightX = startX;
                            flightY = startY;
                            visible = true;
                            flightAnim.restart();
                        }
                    }

                    // 5. Sparkle Burst Particles on Complete Bolt
                    Canvas {
                        id: particleCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        z: 600

                        Timer {
                            interval: 16
                            running: Engine.particles.length > 0
                            repeat: true
                            onTriggered: particleCanvas.requestPaint()
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            for (var i = 0; i < Engine.particles.length; i++) {
                                var p = Engine.particles[i];
                                ctx.save();
                                ctx.globalAlpha = Math.max(0, p.alpha);
                                ctx.translate(p.x, p.y);
                                ctx.rotate(p.rotation);
                                ctx.fillStyle = p.color;
                                if (p.isConfetti) {
                                    var ar = p.aspectRatio || 0.45;
                                    ctx.fillRect(-p.size / 2, (-p.size * ar) / 2, p.size, p.size * ar);
                                } else {
                                    ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size);
                                }
                                ctx.restore();
                            }
                        }
                    }

                    // 6. Deadlock / No Moves Remaining Alert Banner
                    Rectangle {
                        id: deadlockBanner
                        visible: root.isDeadlocked && root.gameState !== "won"
                        z: 750
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        width: Math.min(parent.width - 32, 420)
                        height: deadlockCol.height + 24
                        radius: 12
                        color: root.themeCardBg
                        border.color: "#EF4444"
                        border.width: 2

                        // Warning glow
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "#EF4444"
                            opacity: 0.12
                        }

                        Column {
                            id: deadlockCol
                            anchors.centerIn: parent
                            width: parent.width - 28
                            spacing: 8

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                Text {
                                    text: "⚠️"
                                    font.pixelSize: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "NO MOVES POSSIBLE"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#EF4444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: "Every bolt is blocked with no matching slots! Step back with Undo or restart the stage."
                                font.pixelSize: 11
                                color: root.themeSubtext
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                Rectangle {
                                    width: 120
                                    height: 32
                                    radius: 6
                                    color: undoBannerMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.1) : root.themeAccent

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text { text: "↶"; font.pixelSize: 13; color: root.themeBtnFg }
                                        Text { text: "Undo (U)"; font.bold: true; font.pixelSize: 11; color: root.themeBtnFg }
                                    }

                                    MouseArea {
                                        id: undoBannerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (Engine.undo(callbacks)) {
                                                root.updateUI();
                                                soundToast.show("↶ Move Undone");
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 120
                                    height: 32
                                    radius: 6
                                    color: restartBannerMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                                    border.color: root.themeBorder
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text { text: "🔄"; font.pixelSize: 13; color: root.themeFg }
                                        Text { text: "Restart (R)"; font.bold: true; font.pixelSize: 11; color: root.themeFg }
                                    }

                                    MouseArea {
                                        id: restartBannerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.restartLevel();
                                            soundToast.show("🔄 Stage Restarted");
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
        // MODALS & OVERLAYS
        // =====================================================================
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
                        text: "HOW TO PLAY NUTS SORT"
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.helpText
                        font.pixelSize: 11
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

        Rectangle {
            id: levelModal
            anchors.fill: parent
            color: "#b3000000"
            visible: root.showLevelSelect
            z: 920

            MouseArea {
                anchors.fill: parent
                onClicked: root.showLevelSelect = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.90, 420)
                height: Math.min(parent.height * 0.80, 460)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Header
                    Item {
                        width: parent.width
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "SELECT STAGE"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "10,000+ Endless Stages"
                            font.pixelSize: 10
                            color: root.themeSubtext
                        }
                    }

                    // Difficulty Mode Selector
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "casual", label: "☕ Casual" },
                                { id: "normal", label: "★ Normal" },
                                { id: "hard",   label: "🔥 Hard" }
                            ]

                            Rectangle {
                                width: 100
                                height: 26
                                radius: 13
                                color: root.difficulty === modelData.id ? root.themeAccent : root.themeBoardBg
                                border.color: root.difficulty === modelData.id ? root.themeAccent : root.themeBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 11
                                    font.bold: root.difficulty === modelData.id
                                    color: root.difficulty === modelData.id ? root.themeBtnFg : root.themeFg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setDifficulty(modelData.id)
                                }
                            }
                        }
                    }

                    // Page Navigator
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: root.stagePage > 0 ? root.themeBoardBg : "transparent"
                            opacity: root.stagePage > 0 ? 1.0 : 0.25
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "◀"
                                color: root.themeFg
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.stagePage > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (root.stagePage > 0) root.stagePage--
                            }
                        }

                        Rectangle {
                            height: 28
                            width: 150
                            radius: 14
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Stages " + (root.stagePage * 50 + 1) + " – " + ((root.stagePage + 1) * 50)
                                color: root.themeFg
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: root.themeFg
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stagePage++
                            }
                        }
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - 110
                        contentWidth: width
                        contentHeight: levelGrid.implicitHeight
                        clip: true

                        Grid {
                            id: levelGrid
                            width: parent.width
                            columns: 5
                            spacing: 8

                            Repeater {
                                model: 50

                                Rectangle {
                                    id: lvlBtn
                                    width: (levelGrid.width - 32) / 5
                                    height: width
                                    radius: 8
                                    readonly property int lvlNum: root.stagePage * 50 + index + 1
                                    readonly property bool isCurrent: root.currentLevel === lvlNum
                                    readonly property bool isUnlocked: lvlNum <= root.unlockedLevel
                                    color: isCurrent ? root.themeAccent : (isUnlocked ? root.themeBoardBg : "#181822")
                                    border.color: isCurrent ? root.themeAccent : (isUnlocked ? root.themeBorder : "transparent")
                                    border.width: 1
                                    opacity: isUnlocked ? 1.0 : 0.40

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: lvlNum.toString()
                                            font.pixelSize: lvlNum > 999 ? 10 : (lvlNum > 99 ? 11 : 13)
                                            font.bold: true
                                            color: isCurrent ? root.themeBtnFg : (isUnlocked ? root.themeFg : root.themeSubtext)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: isUnlocked ? "★" : "🔒"
                                            font.pixelSize: 9
                                            color: isCurrent ? root.themeBtnFg : "#F59E0B"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: lvlBtn.isUnlocked ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (lvlBtn.isUnlocked) {
                                                root.jumpToLevel(lvlBtn.lvlNum);
                                                root.showLevelSelect = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 90
                        height: 26
                        radius: 6
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "CLOSE"
                            font.bold: true
                            font.pixelSize: 10
                            color: root.themeFg
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showLevelSelect = false
                        }
                    }
                }
            }
        }

        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#c0000000"
            visible: false
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Engine.nextLevel(callbacks);
                    root.updateUI();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "LEVEL " + root.currentLevel + " COMPLETE!"
                    color: root.themeAccent
                    font.pixelSize: 24
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text { text: "★"; font.pixelSize: 28; color: "#F59E0B" }
                    Text { text: "★"; font.pixelSize: 34; color: "#F59E0B" }
                    Text { text: "★"; font.pixelSize: 28; color: "#F59E0B" }
                }

                Text {
                    text: "Solved in " + root.moves + " moves"
                    color: root.themeFg
                    font.pixelSize: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 160
                    height: 42
                    radius: 8
                    color: nextLvlMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "NEXT LEVEL (N)"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: nextLvlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Engine.nextLevel(callbacks);
                            root.updateUI();
                        }
                    }
                }

                Text {
                    text: "Or press Space / Enter / N"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Sound Toast
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 16
            width: toastText.implicitWidth + 24
            height: 28
            radius: 14
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            opacity: 0
            z: 800

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
                NumberAnimation { target: soundToast; property: "opacity"; from: 0; to: 1; duration: 150 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: soundToast; property: "opacity"; from: 1; to: 0; duration: 250 }
            }
        }
    }

    // =========================================================================
    // CANONICAL OMARCHY ARCADE SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        z: 1000
    }
}
