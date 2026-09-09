import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 720
    minimumWidth: 360
    minimumHeight: 480
    title: "WordCircle"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#38bdf8"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameState: "playing"
    property int score: 0
    property int bestScore: 0
    property int currentLevel: 1
    property string currentChapter: "Neon Nebula"
    property int bonusCount: 0
    property int solvedCount: 0
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool showLevelSelect: true
    property int previewLength: 5
    property bool isTiledDesktopMode: root.height < 540 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 540 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Connect Letters: Click & drag across wheel or type letters\n• Submit Word: Release drag or press ENTER\n• New Game: Click 🎲 New Game or Ctrl+N\n• Shuffle Letters: Click 🔀 or press SPACE\n• Undo Letter: BACKSPACE\n• Clear Selection: ESC\n• Full/Compact View: Shift+F\n• Mute Sound: Ctrl+M\n• Restart Level: Ctrl+R"

    // Engine bindings
    property var activeIndices: Engine.activeIndices
    property string activeWord: Engine.activeWord
    property var circleLetters: Engine.circleLetters
    property var foundWords: Engine.foundWords
    property string feedbackMessage: Engine.feedbackMessage
    property string feedbackType: Engine.feedbackType
    property bool isLevelComplete: Engine.isLevelComplete

    // Mouse drag state on circle
    property bool isDragging: false
    property real dragX: 0
    property real dragY: 0

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            bestScore = settingsManager.getBestScore();
            solvedCount = settingsManager.getSolvedCount();
            loadNextPuzzle(0);
        }
    }

    function loadNextPuzzle(targetLen) {
        if (typeof settingsManager === "undefined" || !settingsManager) return;
        var pzJson = settingsManager.getNextDynamicPuzzle(targetLen || 0);
        if (pzJson && pzJson.length > 10) {
            try {
                var pz = JSON.parse(pzJson);
                Engine.loadSingleLevel(pz);
                solvedCount = settingsManager.getSolvedCount();
                currentLevel = solvedCount + 1;
                currentChapter = pz.chapter || "Neon Nebula";
                updateUIState();
                playSound("dock");
                soundToast.show("Puzzle #" + currentLevel + " • " + pz.circle_letters.length + " Letters");
            } catch(e) {
                console.log("Error loading dynamic puzzle: " + e);
            }
        }
    }

    function updateUIState() {
        if (!Engine.currentLevel) return;
        score = Engine.score;
        if (score > bestScore) {
            bestScore = score;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(bestScore);
            }
        }
        bonusCount = Engine.foundBonusWords.length;
        activeIndices = Engine.activeIndices.slice();
        activeWord = Engine.activeWord;
        circleLetters = Engine.circleLetters.slice();
        foundWords = Engine.foundWords.slice();
        feedbackMessage = Engine.feedbackMessage;
        feedbackType = Engine.feedbackType;
        isLevelComplete = Engine.isLevelComplete;
        gridCanvas.requestPaint();
        wheelCanvas.requestPaint();
    }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#38bdf8";
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

        gridCanvas.requestPaint();
        wheelCanvas.requestPaint();
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

    function restartGame() {
        Engine.startLevel(currentLevel - 1);
        updateUIState();
        playSound("click");
    }

    function jumpToLevel(lvl) {
        if (lvl < 1) lvl = 1;
        if (lvl > 100) lvl = 100;
        Engine.startLevel(lvl - 1);
        updateUIState();
        playSound("dock");
        soundToast.show("Level " + lvl + " (" + (Engine.circleLetters ? Engine.circleLetters.length : 0) + " Letters)");
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("savedLevel", lvl.toString());
        }
    }

    function doTypeLetter(ch) {
        Engine.typeChar(ch, { onSound: root.playSound });
        updateUIState();
    }

    function doSubmitWord() {
        Engine.submitWord({
            onSound: root.playSound,
            onScore: function(s) { root.score = s; },
            onLevelComplete: function(lvl) {
                if (typeof settingsManager !== "undefined" && settingsManager && Engine.currentLevel) {
                    settingsManager.markRootSolved(Engine.currentLevel.root_word);
                    root.solvedCount = settingsManager.getSolvedCount();
                }
                soundToast.show("🎉 Solved! Loading Next...");
                autoNextTimer.restart();
            }
        });
        updateUIState();
    }

    function doShuffle() {
        Engine.shuffleLetters();
        root.playSound("push");
        updateUIState();
    }

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : mainContainer;
        targetItem.grabToImage(function(result) {
            if (result.saveToFile(filePath)) {
                console.log("[Arcade] Screenshot saved to: " + filePath);
                root.screenshotSaved(filePath);
            } else {
                console.log("[Arcade] Error: Failed to save screenshot.");
            }
            if (shouldQuit) Qt.quit();
        });
    }

    // Main Game Loop Timer (~60 FPS)
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            Engine.update(0.016, {
                onSound: root.playSound,
                onScore: function(s) {
                    root.score = s;
                    if (s > root.bestScore) root.bestScore = s;
                },
                onLevelComplete: function(nextLvl) {
                    if (typeof settingsManager !== "undefined" && settingsManager) {
                        settingsManager.setValue("savedLevel", nextLvl.toString());
                    }
                }
            });
            updateUIState();
        }
    }

    // =========================================================================
    // MAIN CONTAINER
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

            // If Help modal is open, Escape closes it
            if (root.showHelp) {
                if (event.key === Qt.Key_Escape) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            // If Level Select modal is open, Escape closes it, Enter/Space starts game
            if (root.showLevelSelect) {
                if (event.key === Qt.Key_Escape) {
                    root.showLevelSelect = false;
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.loadNextPuzzle(root.previewLength);
                    root.showLevelSelect = false;
                    event.accepted = true;
                    return;
                }
            }

            // Modifier-based shortcuts only (Ctrl+N, Ctrl+M, Ctrl+R, Shift+F)
            // Plain single letters must NEVER trigger actions in a word typing game!
            var hasCtrl = (event.modifiers & Qt.ControlModifier) !== 0;

            if (hasCtrl && event.key === Qt.Key_N) {
                root.showLevelSelect = true;
                event.accepted = true;
                return;
            }

            if (hasCtrl && event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (hasCtrl && event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            // WordCircle Controls: Space = Shuffle
            if (event.key === Qt.Key_Space) {
                Engine.shuffleLetters();
                root.playSound("push");
                updateUIState();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                // Submit word
                Engine.submitWord({
                    onSound: root.playSound,
                    onScore: function(s) { root.score = s; },
                    onLevelComplete: function(lvl) {
                        if (typeof settingsManager !== "undefined" && settingsManager && Engine.currentLevel) {
                            settingsManager.markRootSolved(Engine.currentLevel.root_word);
                            root.solvedCount = settingsManager.getSolvedCount();
                        }
                        soundToast.show("🎉 Solved! Loading Next...");
                        autoNextTimer.restart();
                    }
                });
                updateUIState();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                // Backspace letter
                Engine.backspace({ onSound: root.playSound });
                updateUIState();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape) {
                // Clear selection
                Engine.clearSelection();
                updateUIState();
                event.accepted = true;
                return;
            }

            // Direct keyboard typing (A-Z)
            if (event.text && event.text.length === 1) {
                var ch = event.text.toUpperCase();
                if (ch >= "A" && ch <= "Z") {
                    Engine.typeChar(ch, { onSound: root.playSound });
                    updateUIState();
                    event.accepted = true;
                    return;
                }
            }
        }

        // --- Background Retro CRT Grid Pattern ---
        Canvas {
            anchors.fill: parent
            opacity: 0.04
            onPaint: {
                var ctx = getContext("2d");
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1;
                for (var x = 0; x < width; x += 32) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                }
                for (var y = 0; y < height; y += 32) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
            }
        }

        // =====================================================================
        // TIER 1: HEADER ITEM
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 48

            readonly property bool isNarrow: width < 420

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.title
                    font.pixelSize: headerItem.isNarrow ? 20 : 24
                    font.bold: true
                    color: root.themeAccent
                    font.letterSpacing: 1
                }

                Text {
                    text: root.currentChapter + " • Puzzle #" + root.currentLevel + (root.solvedCount > 0 ? " (Solved: " + root.solvedCount + ")" : "")
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeSubtext
                }
            }

            // Stat Cards
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Score Card
                Rectangle {
                    width: headerItem.isNarrow ? 65 : 82
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "SCORE"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.score.toString()
                            font.pixelSize: headerItem.isNarrow ? 13 : 15
                            font.bold: true
                            color: root.themeFg
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Best / Bonus Card
                Rectangle {
                    width: headerItem.isNarrow ? 65 : 82
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "BONUS"
                            font.pixelSize: 8
                            font.bold: true
                            color: "#f59e0b"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.bonusCount.toString() + " ⭐️"
                            font.pixelSize: headerItem.isNarrow ? 12 : 14
                            font.bold: true
                            color: "#fbbf24"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 2: SUBHEADER ITEM (Controls, View Mode, Help, Mute)
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 32

            readonly property bool isCrowded: width < 480

            // Left: Chapter Badge (strictly bounded to never overlap utility buttons)
            Rectangle {
                id: chapterBadge
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                radius: 6
                width: Math.min(chapterText.implicitWidth + 16, Math.max(0, subheaderItem.width - buttonRow.width - 16))
                color: Qt.alpha(root.themeAccent, 0.15)
                border.color: root.themeAccent
                border.width: 1
                visible: width > 50 && !subheaderItem.isCrowded
                clip: true

                Text {
                    id: chapterText
                    anchors.centerIn: parent
                    text: "✨ " + root.currentChapter
                    font.pixelSize: 10
                    font.bold: true
                    color: root.themeAccent
                    elide: Text.ElideRight
                }
            }

            // Right: Utility Controls
            Row {
                id: buttonRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // New Game Button (opens the Level Select / Difficulty Modal)
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 98
                    radius: 6
                    color: newPzMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeAccent
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "🎲"; font.pixelSize: 11 }
                        Text { text: "New Game"; font.pixelSize: 10; font.bold: true; color: root.themeAccent; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: newPzMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.playSound("click");
                            root.showLevelSelect = true;
                        }
                    }
                }

                // Help Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 68
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "?"; font.pixelSize: 12; font.bold: true; color: root.themeAccent }
                        Text { text: "Rules"; font.pixelSize: 10; font.bold: true; color: root.themeFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Audio Toggle
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 68
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                        Text { text: root.isMuted ? "Mute" : "Audio"; font.pixelSize: 10; font.bold: true; color: root.isMuted ? root.themeSubtext : root.themeFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Shuffle Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 76
                    radius: 6
                    color: shuffleMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "🔀"; font.pixelSize: 11 }
                        Text { text: "Shuffle"; font.pixelSize: 10; font.bold: true; color: root.themeBtnFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Engine.shuffleLetters();
                            root.playSound("push");
                            updateUIState();
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (Compact header)
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

                Text { text: "WordCircle"; font.pixelSize: 11; font.bold: true; color: root.themeAccent }
                Text { text: "LVL " + root.currentLevel; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                Text { text: "• SCORE: " + root.score; font.pixelSize: 10; color: root.themeSubtext }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 24; height: 24; radius: 4; color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "🔀"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { Engine.shuffleLetters(); root.playSound("push"); updateUIState(); }
                    }
                }

                Rectangle {
                    width: 24; height: 24; radius: 4; color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute() }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD (Crossword Grid Top + Letter Wheel Bottom)
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 8 : 14
            anchors.rightMargin: root.isTiledDesktopMode ? 8 : 14

            Column {
                anchors.fill: parent
                spacing: 6

                // 1. TOP HALF: Crossword Puzzle Board Matrix
                Rectangle {
                    id: crosswordBox
                    width: parent.width
                    height: parent.height * 0.52
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    radius: 12
                    clip: true

                    Canvas {
                        id: gridCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var lvl = Engine.currentLevel;
                            if (!lvl || !lvl.words || lvl.words.length === 0) return;

                            var rows = lvl.grid_rows || 6;
                            var cols = lvl.grid_cols || 6;

                            // Calculate optimal cell size and padding
                            var maxCellW = (width - 40) / cols;
                            var maxCellH = (height - 40) / rows;
                            var cellSize = Math.floor(Math.min(maxCellW, maxCellH, 44));
                            var cellGap = 4;

                            var totalGridW = cols * (cellSize + cellGap) - cellGap;
                            var totalGridH = rows * (cellSize + cellGap) - cellGap;
                            var startX = Math.floor((width - totalGridW) / 2);
                            var startY = Math.floor((height - totalGridH) / 2);

                            // Build full cell occupancy map
                            var cellMap = {}; // "r,c" -> { char, found }
                            var targetWords = lvl.words;
                            var foundList = Engine.foundWords || [];

                            for (var w = 0; w < targetWords.length; w++) {
                                var tw = targetWords[w];
                                var isFound = foundList.indexOf(tw.word) !== -1;
                                var dr = (tw.dir === "down") ? 1 : 0;
                                var dc = (tw.dir === "across") ? 1 : 0;

                                for (var k = 0; k < tw.word.length; k++) {
                                    var cr = tw.row + k * dr;
                                    var cc = tw.col + k * dc;
                                    var key = cr + "," + cc;
                                    var ch = tw.word.charAt(k);
                                    if (!cellMap[key]) {
                                        cellMap[key] = { char: ch, found: isFound };
                                    } else if (isFound) {
                                        cellMap[key].found = true;
                                    }
                                }
                            }

                            // Draw Crossword Tiles
                            for (var r = 0; r < rows; r++) {
                                for (var c = 0; c < cols; c++) {
                                    var kKey = r + "," + c;
                                    var cell = cellMap[kKey];
                                    if (!cell) continue;

                                    var x = startX + c * (cellSize + cellGap);
                                    var y = startY + r * (cellSize + cellGap);
                                    var rad = Math.min(6, Math.floor(cellSize * 0.18));

                                    // Tile base
                                    ctx.beginPath();
                                    ctx.moveTo(x + rad, y);
                                    ctx.lineTo(x + cellSize - rad, y);
                                    ctx.quadraticCurveTo(x + cellSize, y, x + cellSize, y + rad);
                                    ctx.lineTo(x + cellSize, y + cellSize - rad);
                                    ctx.quadraticCurveTo(x + cellSize, y + cellSize, x + cellSize - rad, y + cellSize);
                                    ctx.lineTo(x + rad, y + cellSize);
                                    ctx.quadraticCurveTo(x, y + cellSize, x, y + cellSize - rad);
                                    ctx.lineTo(x, y + rad);
                                    ctx.quadraticCurveTo(x, y, x + rad, y);
                                    ctx.closePath();

                                    if (cell.found) {
                                        // Discovered tile (glowing accent highlight)
                                        ctx.fillStyle = Qt.alpha(root.themeAccent, 0.22);
                                        ctx.fill();
                                        ctx.strokeStyle = root.themeAccent;
                                        ctx.lineWidth = 1.5;
                                        ctx.stroke();

                                        // Letter
                                        ctx.fillStyle = "#FFFFFF";
                                        ctx.font = "bold " + Math.floor(cellSize * 0.52) + "px " + root.monoFontFamily;
                                        ctx.textAlign = "center";
                                        ctx.textBaseline = "middle";
                                        ctx.fillText(cell.char, x + cellSize / 2, y + cellSize / 2);
                                    } else {
                                        // Undiscovered slot (subtle placeholder)
                                        ctx.fillStyle = Qt.alpha(root.themeCardBg, 0.9);
                                        ctx.fill();
                                        ctx.strokeStyle = Qt.alpha(root.themeBorder, 0.8);
                                        ctx.lineWidth = 1;
                                        ctx.stroke();
                                    }
                                }
                            }
                        }
                    }

                    // Celebratory Confetti Particles Canvas
                    Canvas {
                        id: particleCanvas
                        anchors.fill: parent
                        visible: Engine.particles.length > 0
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2;
                            var cy = height / 2;
                            var parts = Engine.particles;
                            for (var i = 0; i < parts.length; i++) {
                                var p = parts[i];
                                ctx.save();
                                ctx.globalAlpha = p.alpha;
                                ctx.fillStyle = p.color;
                                ctx.beginPath();
                                ctx.arc(cx + p.x, cy + p.y, p.size, 0, Math.PI * 2);
                                ctx.fill();
                                ctx.restore();
                            }
                        }
                    }
                }

                // 2. ACTIVE WORD / FEEDBACK PILL (Mid-Bar)
                Rectangle {
                    id: activeWordPill
                    width: parent.width
                    height: 36
                    radius: 8
                    color: root.feedbackMessage ? 
                           (root.feedbackType === "success" ? Qt.alpha("#22c55e", 0.18) : 
                            (root.feedbackType === "bonus" ? Qt.alpha("#f59e0b", 0.2) : Qt.alpha("#ef4444", 0.18))) :
                           (root.activeWord ? Qt.alpha(root.themeAccent, 0.14) : "transparent")
                    border.color: root.feedbackMessage ? 
                                 (root.feedbackType === "success" ? "#22c55e" : 
                                  (root.feedbackType === "bonus" ? "#f59e0b" : "#ef4444")) :
                                 (root.activeWord ? root.themeAccent : "transparent")
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.feedbackMessage ? root.feedbackMessage : (root.activeWord ? root.activeWord : "Drag or Type to Spell Words")
                        font.family: root.monoFontFamily
                        font.pixelSize: root.feedbackMessage ? 13 : (root.activeWord ? 17 : 12)
                        font.bold: true
                        font.letterSpacing: root.activeWord ? 3 : 1
                        color: root.feedbackMessage ? 
                               (root.feedbackType === "success" ? "#4ade80" : 
                                (root.feedbackType === "bonus" ? "#fbbf24" : "#f87171")) :
                               (root.activeWord ? "#FFFFFF" : root.themeSubtext)
                    }
                }

                // 3. BOTTOM HALF: Interactive Circular Letter Dial
                Rectangle {
                    id: wheelContainer
                    width: parent.width
                    height: parent.height - crosswordBox.height - activeWordPill.height - 12
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    radius: 12
                    clip: true

                    // Circular letter placement math
                    readonly property real centerX: width / 2
                    readonly property real centerY: height / 2
                    readonly property real wheelRadius: Math.max(50, Math.min(width, height) * 0.38)
                    readonly property real nodeRadius: Math.max(18, Math.min(width, height) * 0.088)

                    function getNodePosition(idx, count) {
                        var angle = (idx / count) * 2 * Math.PI - (Math.PI / 2);
                        return {
                            x: centerX + wheelRadius * Math.cos(angle),
                            y: centerY + wheelRadius * Math.sin(angle)
                        };
                    }

                    Canvas {
                        id: wheelCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var letters = Engine.circleLetters || [];
                            if (letters.length === 0) return;

                            var cx = wheelContainer.centerX;
                            var cy = wheelContainer.centerY;
                            var r = wheelContainer.wheelRadius;
                            var nr = wheelContainer.nodeRadius;
                            var count = letters.length;
                            var indices = Engine.activeIndices || [];

                            // Outer ambient guide ring
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.strokeStyle = Qt.alpha(root.themeBorder, 0.4);
                            ctx.lineWidth = 2;
                            ctx.setLineDash([4, 6]);
                            ctx.stroke();
                            ctx.setLineDash([]);

                            // Drawn connection trails between selected nodes
                            if (indices.length > 0) {
                                ctx.beginPath();
                                var firstPos = wheelContainer.getNodePosition(indices[0], count);
                                ctx.moveTo(firstPos.x, firstPos.y);

                                for (var k = 1; k < indices.length; k++) {
                                    var pos = wheelContainer.getNodePosition(indices[k], count);
                                    ctx.lineTo(pos.x, pos.y);
                                }

                                // If actively dragging with mouse, trace to mouse tip
                                if (root.isDragging) {
                                    ctx.lineTo(root.dragX, root.dragY);
                                }

                                ctx.strokeStyle = root.themeAccent;
                                ctx.lineWidth = 5;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.shadowColor = root.themeAccent;
                                ctx.shadowBlur = 12;
                                ctx.stroke();
                                ctx.shadowBlur = 0;
                            }

                            // Draw letter node disks
                            for (var i = 0; i < count; i++) {
                                var npos = wheelContainer.getNodePosition(i, count);
                                var isSelected = indices.indexOf(i) !== -1;

                                ctx.beginPath();
                                ctx.arc(npos.x, npos.y, nr, 0, Math.PI * 2);

                                if (isSelected) {
                                    ctx.fillStyle = root.themeAccent;
                                    ctx.fill();
                                    ctx.strokeStyle = "#FFFFFF";
                                    ctx.lineWidth = 2;
                                    ctx.stroke();

                                    ctx.fillStyle = root.themeBtnFg;
                                } else {
                                    ctx.fillStyle = root.themeCardBg;
                                    ctx.fill();
                                    ctx.strokeStyle = root.themeBorder;
                                    ctx.lineWidth = 1.5;
                                    ctx.stroke();

                                    ctx.fillStyle = root.themeFg;
                                }

                                ctx.font = "bold " + Math.floor(nr * 0.95) + "px " + root.monoFontFamily;
                                ctx.textAlign = "center";
                                ctx.textBaseline = "middle";
                                ctx.fillText(letters[i], npos.x, npos.y);
                            }
                        }
                    }

                    // Center Shuffle Button
                    Rectangle {
                        anchors.centerIn: parent
                        width: wheelContainer.nodeRadius * 1.5
                        height: wheelContainer.nodeRadius * 1.5
                        radius: width / 2
                        color: centerShuffleMouse.containsMouse ? Qt.alpha(root.themeAccent, 0.25) : Qt.alpha(root.themeCardBg, 0.8)
                        border.color: centerShuffleMouse.containsMouse ? root.themeAccent : root.themeBorder
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "🔀"
                            font.pixelSize: wheelContainer.nodeRadius * 0.7
                        }

                        MouseArea {
                            id: centerShuffleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.isDragging
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Engine.shuffleLetters();
                                root.playSound("push");
                                updateUIState();
                            }
                        }
                    }

                    // Mouse Drag Input Controller for the Circle
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        function checkHit(mouseX, mouseY) {
                            var letters = Engine.circleLetters || [];
                            var count = letters.length;
                            var hitRadius = wheelContainer.nodeRadius * 1.6;

                            for (var i = 0; i < count; i++) {
                                var pos = wheelContainer.getNodePosition(i, count);
                                var dx = mouseX - pos.x;
                                var dy = mouseY - pos.y;
                                if (dx * dx + dy * dy <= hitRadius * hitRadius) {
                                    Engine.selectIndex(i, { onSound: root.playSound });
                                    updateUIState();
                                    break;
                                }
                            }
                        }

                        onPressed: function(mouse) {
                            root.isDragging = true;
                            root.dragX = mouse.x;
                            root.dragY = mouse.y;
                            checkHit(mouse.x, mouse.y);
                        }

                        onPositionChanged: function(mouse) {
                            if (root.isDragging) {
                                root.dragX = mouse.x;
                                root.dragY = mouse.y;
                                checkHit(mouse.x, mouse.y);
                                wheelCanvas.requestPaint();
                            }
                        }

                        onReleased: function(mouse) {
                            if (root.isDragging) {
                                root.isDragging = false;
                                Engine.submitWord({
                                    onSound: root.playSound,
                                    onScore: function(s) { root.score = s; },
                                    onLevelComplete: function(lvl) {
                                        if (typeof settingsManager !== "undefined" && settingsManager) {
                                            settingsManager.setValue("savedLevel", lvl.toString());
                                        }
                                    }
                                });
                                updateUIState();
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help Modal, Sound Toast)
        // =====================================================================
        // Auto-advance timer when level completes
        Timer {
            id: autoNextTimer
            interval: 1300
            repeat: false
            onTriggered: root.loadNextPuzzle(0)
        }

        // =====================================================================
        // Level Select Modal (Shows at game start or when clicking Levels)
        // =====================================================================
        Rectangle {
            id: levelSelectModal
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: "#d9000000"
            visible: root.showLevelSelect
            z: 950

            MouseArea {
                anchors.fill: parent
                // Modal stays open until player selects or plays
            }

            Rectangle {
                id: levelCard
                width: Math.min(parent.width * 0.94, 460)
                height: levelSelectCol.height + 44
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeAccent
                border.width: 1.5
                radius: 14

                // Stop clicks on card from closing
                MouseArea { anchors.fill: parent }

                Column {
                    id: levelSelectCol
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 14

                    // Header
                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "🎯 CHOOSE STARTING LEVEL"
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.letterSpacing: 1
                        }
                        Text {
                            text: "Pick your preferred letter difficulty or jump right in:"
                            font.pixelSize: 11
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Letter Count Tier Buttons (4, 5, 6, 7 Letters)
                    Grid {
                        columns: 4
                        spacing: 8
                        width: parent.width

                        Repeater {
                            model: [
                                { label: "4 Letters", len: 4, sub: "Casual" },
                                { label: "5 Letters", len: 5, sub: "Medium" },
                                { label: "6 Letters", len: 6, sub: "Expert" },
                                { label: "7 Letters", len: 7, sub: "Master" }
                            ]

                            Rectangle {
                                width: (levelSelectCol.width - 24) / 4
                                height: 62
                                radius: 8
                                color: (root.previewLength === modelData.len) ? Qt.alpha(root.themeAccent, 0.22) : root.themeBoardBg
                                border.color: (root.previewLength === modelData.len) ? root.themeAccent : root.themeBorder
                                border.width: 1.5

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.themeFg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: modelData.sub
                                        font.pixelSize: 9
                                        color: (root.previewLength === modelData.len) ? root.themeAccent : root.themeSubtext
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.previewLength = modelData.len;
                                        root.playSound("click");
                                    }
                                }
                            }
                        }
                    }

                    // Level Details Summary Box
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Text {
                                text: "Selected: " + root.previewLength + " Letters Wheel"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                text: "•"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }
                            Text {
                                text: "Solves Completed: " + root.solvedCount
                                font.pixelSize: 11
                                color: root.themeFg
                            }
                        }
                    }

                    // Action Buttons Row: [ 🎲 Random Level ] [ PLAY LEVEL ▶ ]
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 120
                            height: 42
                            radius: 8
                            color: rndBtnMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                            border.color: root.themeAccent
                            border.width: 1.5

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "🎲"; font.pixelSize: 13 }
                                Text { text: "Random"; font.pixelSize: 12; font.bold: true; color: root.themeAccent }
                            }

                            MouseArea {
                                id: rndBtnMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var rndLen = [4, 5, 6, 7][Math.floor(Math.random() * 4)];
                                    root.previewLength = rndLen;
                                    root.loadNextPuzzle(rndLen);
                                    root.showLevelSelect = false;
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - 128
                            height: 42
                            radius: 8
                            color: startBtnMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "PLAY " + root.previewLength + "-LETTER PUZZLE ▶"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: root.themeBtnFg
                                }
                            }

                            MouseArea {
                                id: startBtnMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.loadNextPuzzle(root.previewLength);
                                    root.showLevelSelect = false;
                                }
                            }
                        }
                    }

                    Text {
                        text: "Press ENTER to Play • ESC to Close"
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // Help Modal
        Rectangle {
            id: helpModal
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: "#cc000000"
            visible: root.showHelp
            z: 900

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.9, 420)
                height: helpCol.height + 44
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1.5
                radius: 14

                Column {
                    id: helpCol
                    anchors.centerIn: parent
                    width: parent.width - 44
                    spacing: 14

                    Text {
                        text: "HOW TO PLAY WORDCIRCLE"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.letterSpacing: 1
                    }

                    Text {
                        text: root.helpText
                        font.pixelSize: 12
                        color: root.themeFg
                        lineHeight: 1.45
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: 120
                        height: 34
                        radius: 7
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "LET'S PLAY"
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
