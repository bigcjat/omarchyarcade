import QtQuick
import QtQuick.Window
import "BackgammonEngine.js" as Engine
import "BackgammonThemes.js" as Themes

Window {
    id: root
    visible: true
    width: 560
    height: 720
    minimumWidth: 380
    minimumHeight: 520
    title: "Backgammon"

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

    // =========================================================================
    // LUXURY BOARD THEMES (12 Color-Theory Artisanal Palettes)
    // =========================================================================
    property string boardThemeId: "morpho"
    readonly property var activeBoardTheme: Themes.getTheme(boardThemeId)
    property bool showThemePicker: false

    function cycleBoardTheme() {
        var next = Themes.getNextTheme(boardThemeId);
        setBoardTheme(next.id);
    }

    function setBoardTheme(id) {
        boardThemeId = id;
        if (typeof settingsManager !== "undefined") {
            settingsManager.setValue("boardTheme", id);
        }
        if (pointsCanvas) {
            pointsCanvas.requestPaint();
        }
        soundToast.show("🎨 Theme: " + activeBoardTheme.name);
    }

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE
    // =========================================================================
    property var boardPoints: []    // 25 items: { count: int, player: int }
    property int barDark: 0
    property int barLight: 0
    property int offDark: 0
    property int offLight: 0
    property int darkPips: 167
    property int lightPips: 167

    property int currentTurn: 1     // 1: Dark, 2: Light
    property string phase: "roll"   // "roll", "move", "gameover"
    property var diceValues: [0, 0]
    property var remainingMoves: []

    property string gameMode: "pve" // "pve" (vs AI), "pvp" (2-Player)
    property int humanPlayer: 1     // 1: Dark
    property string aiDifficulty: "casual" // "novice", "casual", "master"
    property bool isAiThinking: false

    // Selection & Legal Destinations
    property var selectedSource: null // point number (1..24) or "bar"
    property var availableTargets: [] // array of { to: int/"off", die: int, hit: bool }

    // System state
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Object: Move all 15 checkers around the board into your home board and bear them off.\n• Movement: Dark moves clockwise (1 -> 24); Light moves counter-clockwise (24 -> 1).\n• Doubles: Rolling matching dice gives you 4 moves of that value!\n• Hitting: Landing on a single opponent checker (blot) sends it to the central Bar.\n• Re-entering: You must re-enter all checkers on the Bar before making other moves.\n• Bearing Off: Once all 15 checkers reach your home board (Points 1-6 for Light, 19-24 for Dark), you can bear them off.\n\nControls:\n• Space / Click Dice: Roll Dice\n• Click Checker: Select source, then click highlighted destination\n• T / Themes: Cycle through 12 luxury color palettes\n• U: Undo uncommitted move | D: AI Difficulty | P: Game Mode | R: Restart | ?: Help"

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

        pointsCanvas.requestPaint();
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

    function syncGameState() {
        var pts = [];
        for (var i = 0; i <= 24; i++) {
            pts.push({ count: Engine.board[i].count, player: Engine.board[i].player });
        }
        boardPoints = pts;
        barDark = Engine.bar[1];
        barLight = Engine.bar[2];
        offDark = Engine.borneOff[1];
        offLight = Engine.borneOff[2];
        darkPips = Engine.calculatePipCount(1);
        lightPips = Engine.calculatePipCount(2);

        currentTurn = Engine.currentTurn;
        phase = Engine.phase;
        diceValues = [Engine.dice[0], Engine.dice[1]];
        remainingMoves = Engine.movesLeft.slice();

        if (selectedSource !== null) {
            availableTargets = Engine.getLegalMovesForChecker(selectedSource, currentTurn, remainingMoves);
        } else {
            availableTargets = [];
        }

        if (phase === "gameover") {
            if (gameMode === "pve" && Engine.winner === humanPlayer) {
                playSound("win");
            } else {
                playSound("game_over");
            }
        }

        pointsCanvas.requestPaint();
    }

    function startNewGame() {
        aiTimer.stop();
        isAiThinking = false;
        selectedSource = null;
        availableTargets = [];
        Engine.resetGame();
        syncGameState();
        playSound("click");

        if (gameMode === "pve" && currentTurn !== humanPlayer) {
            triggerAiTurn();
        }
    }

    function handleRollDice() {
        if (phase !== "roll" || isAiThinking) return;
        if (gameMode === "pve" && currentTurn !== humanPlayer) return;

        var res = Engine.rollDice();
        playSound("click");
        triggerDiceAnimation();
        syncGameState();

        if (res && res.passed) {
            soundToast.show("⚠️ No legal moves possible (Turn Passed)");
            Engine.endTurn();
            syncGameState();

            if (gameMode === "pve" && currentTurn !== humanPlayer) {
                triggerAiTurn();
            }
        }
    }

    function triggerDiceAnimation() {
        dieItem1.rollAnim();
        dieItem2.rollAnim();
        if (dieItem3.visible) dieItem3.rollAnim();
        if (dieItem4.visible) dieItem4.rollAnim();
    }

    function handleSelectSource(sourcePt) {
        if (phase !== "move" || isAiThinking) return;
        if (gameMode === "pve" && currentTurn !== humanPlayer) return;

        // If clicking currently selected source, deselect
        if (selectedSource === sourcePt) {
            selectedSource = null;
            availableTargets = [];
            return;
        }

        // If clicking a target of the currently selected source, execute the move!
        for (var i = 0; i < availableTargets.length; i++) {
            if (availableTargets[i].to === sourcePt) {
                executePlayerMove(selectedSource, availableTargets[i].to, availableTargets[i].die);
                return;
            }
        }

        // Otherwise select new source
        var moves = Engine.getLegalMovesForChecker(sourcePt, currentTurn, remainingMoves);
        if (moves.length > 0) {
            selectedSource = sourcePt;
            availableTargets = moves;
            playSound("select");
        } else {
            selectedSource = null;
            availableTargets = [];
        }
    }

    function handleTargetClick(destPt, dieVal) {
        if (selectedSource === null) return;
        executePlayerMove(selectedSource, destPt, dieVal);
    }

    function executePlayerMove(fromPt, toPt, dieVal) {
        var res = Engine.executeMove(fromPt, toPt, dieVal);
        if (res.success) {
            playSound(res.hit ? "move" : (toPt === "off" ? "win" : "dock"));
            selectedSource = null;
            availableTargets = [];
            syncGameState();

            if (res.turnFinished && phase !== "gameover") {
                if (gameMode === "pve" && currentTurn !== humanPlayer) {
                    triggerAiTurn();
                }
            }
        }
    }

    function triggerAiTurn() {
        if (phase === "gameover") return;
        isAiThinking = true;
        aiTimer.restart();
    }

    function performAiTurn() {
        isAiThinking = false;
        if (phase === "gameover") return;

        // 1. Roll dice if in roll phase
        if (Engine.phase === "roll") {
            var rollRes = Engine.rollDice();
            playSound("click");
            triggerDiceAnimation();
            syncGameState();

            if (rollRes && rollRes.passed) {
                soundToast.show("⚠️ AI has no legal moves (Passed)");
                Engine.endTurn();
                syncGameState();
                return;
            }
        }

        // 2. Compute best turn sequence
        var movesSeq = Engine.getBestAiTurn(aiDifficulty);
        if (!movesSeq || movesSeq.length === 0) {
            Engine.endTurn();
            syncGameState();
            return;
        }

        // Execute moves with smooth sequential pace
        executeAiMoveSequence(movesSeq, 0);
    }

    function executeAiMoveSequence(seq, idx) {
        if (idx >= seq.length || Engine.phase === "gameover") {
            syncGameState();
            return;
        }

        var m = seq[idx];
        var res = Engine.executeMove(m.from, m.to, m.die);
        playSound(res.hit ? "move" : (m.to === "off" ? "win" : "dock"));
        syncGameState();

        if (idx + 1 < seq.length && !res.gameOver) {
            aiMoveDelayTimer.interval = 320;
            aiMoveDelayTimer.pendingSeq = seq;
            aiMoveDelayTimer.pendingIdx = idx + 1;
            aiMoveDelayTimer.restart();
        }
    }

    Timer {
        id: aiTimer
        interval: 420
        repeat: false
        onTriggered: root.performAiTurn()
    }

    Timer {
        id: aiMoveDelayTimer
        property var pendingSeq: []
        property int pendingIdx: 0
        interval: 320
        repeat: false
        onTriggered: root.executeAiMoveSequence(pendingSeq, pendingIdx)
    }

    function handleUndo() {
        if (isAiThinking || phase === "roll") return;
        var didUndo = Engine.undoMove();
        if (didUndo) {
            selectedSource = null;
            availableTargets = [];
            syncGameState();
            playSound("undo");
            soundToast.show("↶ Move Undone");
        }
    }

    function toggleDifficulty() {
        if (aiDifficulty === "novice") aiDifficulty = "casual";
        else if (aiDifficulty === "casual") aiDifficulty = "master";
        else aiDifficulty = "novice";
        playSound("select");
        soundToast.show("AI: " + aiDifficulty.toUpperCase());
    }

    function toggleGameMode() {
        gameMode = (gameMode === "pve") ? "pvp" : "pve";
        playSound("select");
        startNewGame();
        soundToast.show(gameMode === "pve" ? "Mode: Player vs AI" : "Mode: Local 2-Player");
    }

    function isTarget(toPt) {
        if (!availableTargets || availableTargets.length === 0) return false;
        for (var i = 0; i < availableTargets.length; i++) {
            if (availableTargets[i].to === toPt) return true;
        }
        return false;
    }

    function getDieForTarget(toPt) {
        if (!availableTargets || availableTargets.length === 0) return 0;
        for (var i = 0; i < availableTargets.length; i++) {
            if (availableTargets[i].to === toPt) return availableTargets[i].die;
        }
        return 0;
    }

    function isHitTarget(toPt) {
        if (!availableTargets || availableTargets.length === 0) return false;
        for (var i = 0; i < availableTargets.length; i++) {
            if (availableTargets[i].to === toPt && availableTargets[i].hit) return true;
        }
        return false;
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
        if (typeof settingsManager !== "undefined") {
            var savedTheme = settingsManager.getValue("boardTheme", "morpho");
            if (savedTheme) {
                boardThemeId = savedTheme;
            }
        }
        Engine.init();
        syncGameState();
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

            if (root.showThemePicker) {
                if (event.key === Qt.Key_Escape) {
                    root.showThemePicker = false;
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_T) {
                root.cycleBoardTheme();
                event.accepted = true;
                return;
            }

            if (root.phase === "gameover") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.startNewGame();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Space) {
                if (root.phase === "roll") {
                    root.handleRollDice();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.startNewGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U) {
                root.handleUndo();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_D) {
                root.toggleDifficulty();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P) {
                root.toggleGameMode();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }
        }

        // =====================================================================
        // ROW 1: HEADER ITEM
        // =====================================================================
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: Math.max(titleCol.height, scoreRow.height)

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
                    text: "Backgammon"
                    font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.075))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.isAiThinking ? "AI is moving checkers..." :
                          (root.phase === "roll" ? (root.currentTurn === 1 ? "Dark to Roll (Space)" : "Light to Roll") :
                          (root.currentTurn === 1 ? "Dark's Turn to Move" : "Light's Turn to Move"))
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    font.bold: true
                    color: root.themeSubtext
                }
            }

            // Stat Cards: DARK vs LIGHT
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // DARK Stat Card
                Rectangle {
                    width: Math.max(68, Math.min(84, headerItem.width * 0.17))
                    height: Math.max(44, Math.min(52, headerItem.width * 0.11))
                    radius: 8
                    color: root.themeCardBg
                    border.color: (root.currentTurn === 1 && root.phase !== "gameover") ? root.themeAccent : root.themeBorder
                    border.width: (root.currentTurn === 1 && root.phase !== "gameover") ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5
                            Rectangle {
                                width: 9; height: 9; radius: 4.5
                                color: "#282c3c"
                                border.color: "#94a3b8"
                                border.width: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "DARK"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.themeSubtext
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.offDark + "/15"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // LIGHT Stat Card
                Rectangle {
                    width: Math.max(68, Math.min(84, headerItem.width * 0.17))
                    height: Math.max(44, Math.min(52, headerItem.width * 0.11))
                    radius: 8
                    color: root.themeCardBg
                    border.color: (root.currentTurn === 2 && root.phase !== "gameover") ? root.themeAccent : root.themeBorder
                    border.width: (root.currentTurn === 2 && root.phase !== "gameover") ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5
                            Rectangle {
                                width: 9; height: 9; radius: 4.5
                                color: "#ffffff"
                                border.color: "#94a3b8"
                                border.width: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "LIGHT"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.themeSubtext
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.offLight + "/15"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: ACTION BAR
        // =====================================================================
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 34

            readonly property bool isCrowded: subheaderItem.width < 490

            // Left: How to Play
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
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
                            text: "Rules"
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

                // 12 Board Themes Gallery Button
                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (themeRow.implicitWidth + 16)
                    radius: 8
                    color: (themeMouse.containsMouse || root.showThemePicker) ? root.themeCardBg : root.themeBoardBg
                    border.color: root.showThemePicker ? root.themeAccent : (themeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1

                    Row {
                        id: themeRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "🎨"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: subheaderItem.width < 620 ? "Themes" : (root.activeBoardTheme ? root.activeBoardTheme.name : "Themes")
                            font.pixelSize: 11
                            font.bold: true
                            color: root.showThemePicker ? root.themeAccent : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: themeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showThemePicker = !root.showThemePicker
                    }
                }
            }

            // Right: Sound, Mode, Action (Roll / Restart)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Mute button
                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Row {
                        id: muteRow
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

                // Mode toggle
                Rectangle {
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (modeRow.implicitWidth + 16)
                    radius: 8
                    color: modeMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.gameMode === "pve" ? "🤖" : "👥"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.gameMode === "pve" ? "vs AI" : "2-Player"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGameMode()
                    }
                }

                // Primary Action Button: Roll Dice or New Game
                Rectangle {
                    id: actionBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (actionRow.implicitWidth + 18)
                    radius: 8
                    color: actionMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: actionRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.phase === "roll" ? "🎲" : "🔄"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.phase === "roll" ? "Roll Dice (Space)" : "New Game (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            visible: !subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.phase === "roll") root.handleRollDice();
                            else root.startNewGame();
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 8
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // Outer Wooden / Leather Frame
            Rectangle {
                id: boardFrame
                anchors.fill: parent
                color: root.activeBoardTheme ? root.activeBoardTheme.frame : "#1a1c27"
                border.color: root.activeBoardTheme ? root.activeBoardTheme.frameBorder : "#2a2e40"
                border.width: 2
                radius: 12

                // Inner Table Felt Container
                Rectangle {
                    id: boardContainer
                    anchors.fill: parent
                    anchors.margins: 4
                    color: root.activeBoardTheme ? root.activeBoardTheme.felt : "#0d1019"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    radius: 9
                    clip: true

                    // Layout Dimensions
                    property real trayWidth: Math.max(34, width * 0.08)
                    property real barWidth: Math.max(30, width * 0.075)
                    property real totalPlayWidth: width - trayWidth - barWidth - 12
                    property real quadrantWidth: totalPlayWidth / 2.0
                    property real pointWidth: quadrantWidth / 6.0
                    property real pointHeight: height * 0.40

                    // Canvas for 24 Inlaid Point Triangles
                    Canvas {
                        id: pointsCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var pw = boardContainer.pointWidth;
                            var ph = boardContainer.pointHeight;
                            var barW = boardContainer.barWidth;
                            var th = root.activeBoardTheme;

                            function drawInlaidPoint(x, y, w, h, isTop, isDark) {
                                ctx.fillStyle = isDark ? (th ? th.pointDark : Qt.rgba(0.82, 0.38, 0.12, 0.42)) : (th ? th.pointLight : Qt.rgba(0.60, 0.68, 0.82, 0.28));
                                ctx.strokeStyle = isDark ? (th ? th.pointDarkStroke : "#ea580c") : (th ? th.pointLightStroke : "#cbd5e1");
                                ctx.lineWidth = 1.2;

                                ctx.beginPath();
                                if (isTop) {
                                    ctx.moveTo(x, y);
                                    ctx.lineTo(x + w, y);
                                    ctx.lineTo(x + w / 2, y + h);
                                } else {
                                    ctx.moveTo(x, y + h);
                                    ctx.lineTo(x + w, y + h);
                                    ctx.lineTo(x + w / 2, y);
                                }
                                ctx.closePath();
                                ctx.fill();
                                ctx.stroke();
                            }

                            // Top Left: Points 13 to 18
                            for (var i = 0; i < 6; i++) {
                                var xTL = 6 + i * pw;
                                drawInlaidPoint(xTL, 4, pw, ph, true, i % 2 === 0);
                            }

                            // Top Right: Points 19 to 24
                            for (var j = 0; j < 6; j++) {
                                var xTR = 6 + boardContainer.quadrantWidth + barW + j * pw;
                                drawInlaidPoint(xTR, 4, pw, ph, true, j % 2 === 0);
                            }

                            // Bottom Left: Points 12 to 7
                            for (var k = 0; k < 6; k++) {
                                var xBL = 6 + k * pw;
                                drawInlaidPoint(xBL, height - ph - 4, pw, ph, false, k % 2 === 1);
                            }

                            // Bottom Right: Points 6 to 1
                            for (var l = 0; l < 6; l++) {
                                var xBR = 6 + boardContainer.quadrantWidth + barW + l * pw;
                                drawInlaidPoint(xBR, height - ph - 4, pw, ph, false, l % 2 === 1);
                            }
                        }
                    }

                    // Point Numbers Stamped on Felt (1..24)
                    Repeater {
                        model: 24
                        Text {
                            readonly property int pt: index + 1
                            readonly property bool isTop: pt >= 13
                            readonly property real pw: boardContainer.pointWidth
                            readonly property real barW: boardContainer.barWidth

                            x: {
                                if (pt >= 13 && pt <= 18) return 6 + (pt - 13) * pw + (pw / 2) - (width / 2);
                                if (pt >= 19 && pt <= 24) return 6 + boardContainer.quadrantWidth + barW + (pt - 19) * pw + (pw / 2) - (width / 2);
                                if (pt >= 7 && pt <= 12)  return 6 + (12 - pt) * pw + (pw / 2) - (width / 2);
                                return 6 + boardContainer.quadrantWidth + barW + (6 - pt) * pw + (pw / 2) - (width / 2);
                            }
                            y: isTop ? 5 : (boardContainer.height - height - 5)
                            text: pt.toString()
                            font.pixelSize: 8
                            font.bold: true
                            color: root.activeBoardTheme ? root.activeBoardTheme.feltText : root.themeSubtext
                            opacity: 0.75
                        }
                    }

                    // Central Dividing Bar with Inlaid Brass Strip
                    Rectangle {
                        id: centerBar
                        x: 6 + boardContainer.quadrantWidth
                        y: 4
                        width: boardContainer.barWidth
                        height: parent.height - 8
                        color: root.activeBoardTheme ? root.activeBoardTheme.bar : "#161824"
                        border.color: root.activeBoardTheme ? root.activeBoardTheme.frameBorder : "#2a2e40"
                        border.width: 1.5
                        radius: 6

                        // Brass Inlaid Center Line
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1.5
                            color: root.activeBoardTheme ? root.activeBoardTheme.brass : Qt.rgba(0.9, 0.7, 0.3, 0.4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "BAR"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.activeBoardTheme ? root.activeBoardTheme.brass : root.themeAccent
                            rotation: -90
                            opacity: 0.85
                        }

                        // Checkers on Bar: Dark on bottom, Light on top
                        Column {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -14

                            Repeater {
                                model: root.barDark
                                CheckerPiece {
                                    width: Math.min(centerBar.width - 4, 30)
                                    height: width
                                    player: 1
                                    isSelected: root.selectedSource === "bar" && root.currentTurn === 1

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.currentTurn === 1) root.handleSelectSource("bar");
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -14

                            Repeater {
                                model: root.barLight
                                CheckerPiece {
                                    width: Math.min(centerBar.width - 4, 30)
                                    height: width
                                    player: 2
                                    isSelected: root.selectedSource === "bar" && root.currentTurn === 2

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.currentTurn === 2) root.handleSelectSource("bar");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bear-Off Tray (Far Right)
                    Rectangle {
                        id: bearOffTray
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: boardContainer.trayWidth
                        color: root.activeBoardTheme ? root.activeBoardTheme.bar : "#161824"
                        border.color: root.isTarget("off") ? root.themeAccent : (root.activeBoardTheme ? root.activeBoardTheme.frameBorder : "#2a2e40")
                        border.width: root.isTarget("off") ? 2 : 1
                        radius: 6

                        // Highlight when bearing off is a legal target!
                        Rectangle {
                            anchors.fill: parent
                            color: root.themeAccent
                            opacity: root.isTarget("off") ? 0.30 : 0
                            radius: 6
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "OFF"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.isTarget("off") ? root.themeAccent : root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Light Bear-off stack
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2
                                Repeater {
                                    model: Math.min(root.offLight, 7)
                                    Rectangle {
                                        width: bearOffTray.width - 12
                                        height: 3
                                        radius: 1.5
                                        color: root.activeBoardTheme ? root.activeBoardTheme.lightBody : "#ffffff"
                                        border.color: root.activeBoardTheme ? root.activeBoardTheme.lightRim : "#94a3b8"
                                        border.width: 0.5
                                    }
                                }
                            }

                            Text {
                                text: root.offLight.toString()
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeBoardTheme ? root.activeBoardTheme.lightRim : "#ffffff"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Rectangle {
                                width: parent.width - 12
                                height: 1
                                color: root.activeBoardTheme ? root.activeBoardTheme.frameBorder : "#2a2e40"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Dark Bear-off stack
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2
                                Repeater {
                                    model: Math.min(root.offDark, 7)
                                    Rectangle {
                                        width: bearOffTray.width - 12
                                        height: 3
                                        radius: 1.5
                                        color: root.activeBoardTheme ? root.activeBoardTheme.darkBody : "#282c3c"
                                        border.color: root.activeBoardTheme ? root.activeBoardTheme.darkRim : "#94a3b8"
                                        border.width: 0.5
                                    }
                                }
                            }

                            Text {
                                text: root.offDark.toString()
                                font.pixelSize: 10
                                font.bold: true
                                color: root.activeBoardTheme ? root.activeBoardTheme.darkRim : "#94a3b8"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.isTarget("off")
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var d = root.getDieForTarget("off");
                                root.handleTargetClick("off", d);
                            }
                        }
                    }

                    // Interactive 24 Points & Checkers
                    Repeater {
                        model: 24

                        Item {
                            id: pointItem
                            readonly property int pt: index + 1 // 1..24
                            readonly property bool isTop: pt >= 13
                            readonly property real pw: boardContainer.pointWidth
                            readonly property real ph: boardContainer.pointHeight
                            readonly property real barW: boardContainer.barWidth

                            x: {
                                if (pt >= 13 && pt <= 18) return 6 + (pt - 13) * pw;
                                if (pt >= 19 && pt <= 24) return 6 + boardContainer.quadrantWidth + barW + (pt - 19) * pw;
                                if (pt >= 7 && pt <= 12)  return 6 + (12 - pt) * pw;
                                return 6 + boardContainer.quadrantWidth + barW + (6 - pt) * pw;
                            }
                            y: isTop ? 4 : (boardContainer.height - ph - 4)
                            width: pw
                            height: ph

                            readonly property var ptData: (root.boardPoints.length > pt) ? root.boardPoints[pt] : { count: 0, player: 0 }
                            readonly property bool isSelected: root.selectedSource === pt
                            readonly property bool isLegalTarget: root.isTarget(pt)
                            readonly property bool isHit: root.isHitTarget(pt)

                            // Target Landing Ring Indicator
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(pw * 0.78, 28)
                                height: width
                                radius: width / 2
                                color: pointItem.isHit ? Qt.rgba(1, 0.2, 0.2, 0.3) : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.2)
                                border.color: pointItem.isHit ? "#ff5555" : root.themeAccent
                                border.width: 2
                                visible: pointItem.isLegalTarget
                                z: 10

                                Text {
                                    anchors.centerIn: parent
                                    text: pointItem.isHit ? "⚔" : ("+" + root.getDieForTarget(pointItem.pt))
                                    font.pixelSize: pointItem.isHit ? 11 : 9
                                    font.bold: true
                                    color: pointItem.isHit ? "#ff5555" : root.themeAccent
                                }
                            }

                            // Stack of Checkers
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: pointItem.isTop ? parent.top : undefined
                                anchors.bottom: pointItem.isTop ? undefined : parent.bottom
                                anchors.topMargin: 16
                                anchors.bottomMargin: 16
                                spacing: -Math.max(4, Math.min(16, (pointItem.ptData.count > 5 ? 18 : 8)))

                                Repeater {
                                    model: Math.min(pointItem.ptData.count, 6)

                                    CheckerPiece {
                                        width: Math.min(pw * 0.90, 31)
                                        height: width
                                        player: pointItem.ptData.player
                                        isSelected: pointItem.isSelected
                                        countBadge: (index === 0) ? pointItem.ptData.count : 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (pointItem.isLegalTarget || (pointItem.ptData.player === root.currentTurn && pointItem.ptData.count > 0)) ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    if (pointItem.isLegalTarget) {
                                        var d = root.getDieForTarget(pointItem.pt);
                                        root.handleTargetClick(pointItem.pt, d);
                                    } else if (pointItem.ptData.player === root.currentTurn && pointItem.ptData.count > 0) {
                                        root.handleSelectSource(pointItem.pt);
                                    }
                                }
                            }
                        }
                    }

                    // Center Vector Domino Dice Tray
                    Item {
                        anchors.centerIn: parent
                        width: 220
                        height: 52
                        visible: root.phase !== "gameover"

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            DieView {
                                id: dieItem1
                                value: root.diceValues[0] > 0 ? root.diceValues[0] : 1
                                isSpent: root.remainingMoves.indexOf(root.diceValues[0]) === -1
                                visible: root.diceValues[0] > 0
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.phase === "roll"
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleRollDice()
                                }
                            }

                            DieView {
                                id: dieItem2
                                value: root.diceValues[1] > 0 ? root.diceValues[1] : 1
                                isSpent: (root.remainingMoves.length === 0) || (root.remainingMoves.length === 1 && root.diceValues[0] === root.diceValues[1]) || (root.remainingMoves.indexOf(root.diceValues[1]) === -1)
                                visible: root.diceValues[1] > 0
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.phase === "roll"
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleRollDice()
                                }
                            }

                            // Extra dice for Doubles (4 moves)
                            DieView {
                                id: dieItem3
                                value: root.diceValues[0]
                                isSpent: root.remainingMoves.length < 3
                                visible: root.diceValues[0] > 0 && root.diceValues[0] === root.diceValues[1]
                            }

                            DieView {
                                id: dieItem4
                                value: root.diceValues[0]
                                isSpent: root.remainingMoves.length < 4
                                visible: root.diceValues[0] > 0 && root.diceValues[0] === root.diceValues[1]
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 4: BOTTOM ACTION BAR (Undo, Difficulty, Pip Race)
        // =====================================================================
        Item {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 32, 420)
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3

                    // 1. Undo Button (30%)
                    Rectangle {
                        width: parent.width * 0.30
                        height: parent.height
                        radius: 8
                        color: undoMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "↶"
                                font.pixelSize: 13
                                color: root.themeAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Undo (U)"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: undoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.handleUndo()
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height - 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.themeBorder
                    }

                    // 2. AI Difficulty (36%)
                    Rectangle {
                        width: parent.width * 0.36
                        height: parent.height
                        radius: 8
                        color: diffMouse.containsMouse ? Qt.darker(root.themeCardBg, 1.15) : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "🧠"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.aiDifficulty.toUpperCase() + " (D)"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: diffMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDifficulty()
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height - 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.themeBorder
                    }

                    // 3. Pip Count Comparison (Remaining width)
                    Item {
                        width: parent.width - (parent.width * 0.30) - (parent.width * 0.36) - 2
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "Pips:"
                                font.pixelSize: 10
                                color: root.themeSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.darkPips + " / " + root.lightPips
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & NOTIFICATIONS
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
                        text: "HOW TO PLAY BACKGAMMON"
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.helpText
                        font.pixelSize: 11
                        color: root.themeFg
                        lineHeight: 1.35
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: 110
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
                        text: "Created for Omarchy Arcade"
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.7
                    }
                }
            }
        }

        // =====================================================================
        // Theme Picker Modal (12 Luxury Color-Theory Sets)
        // =====================================================================
        Rectangle {
            id: themePickerModal
            anchors.fill: parent
            color: "#b3000000"
            visible: root.showThemePicker
            z: 920

            MouseArea {
                anchors.fill: parent
                onClicked: root.showThemePicker = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.94, 460)
                height: Math.min(parent.height * 0.88, 560)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 14
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Title Row
                    Item {
                        width: parent.width
                        height: 26

                        Text {
                            text: "BOARD PALETTES (" + Themes.themes.length + ")"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeAccent
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 13
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeSubtext
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showThemePicker = false
                            }
                        }
                    }

                    Text {
                        text: "Crafted with color theory & luxury artisanal materials. Press 'T' anytime to cycle."
                        font.pixelSize: 10
                        color: root.themeSubtext
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    // Grid of 12 themes
                    Flickable {
                        width: parent.width
                        height: parent.height - 80
                        contentHeight: themeGrid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Grid {
                            id: themeGrid
                            columns: (parent.width > 380) ? 2 : 1
                            spacing: 8
                            width: parent.width

                            Repeater {
                                model: Themes.themes
                                Rectangle {
                                    readonly property var tItem: modelData
                                    readonly property bool isSelected: root.boardThemeId === tItem.id
                                    width: (themeGrid.columns === 2) ? ((themeGrid.width - 8) / 2) : themeGrid.width
                                    height: 64
                                    radius: 10
                                    color: isSelected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.15) : (tCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : root.themeBoardBg)
                                    border.color: isSelected ? root.themeAccent : (tCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : root.themeBorder)
                                    border.width: isSelected ? 2 : 1

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 10

                                        // Mini Board Swatch
                                        Rectangle {
                                            width: 44
                                            height: 48
                                            radius: 6
                                            color: tItem.felt
                                            border.color: tItem.frameBorder
                                            border.width: 1.5
                                            clip: true
                                            anchors.verticalCenter: parent.verticalCenter

                                            // Triangles Preview
                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);
                                                    ctx.fillStyle = tItem.pointDark;
                                                    ctx.beginPath();
                                                    ctx.moveTo(4, 0); ctx.lineTo(16, 0); ctx.lineTo(10, 24);
                                                    ctx.closePath(); ctx.fill();

                                                    ctx.fillStyle = tItem.pointLight;
                                                    ctx.beginPath();
                                                    ctx.moveTo(18, 0); ctx.lineTo(30, 0); ctx.lineTo(24, 24);
                                                    ctx.closePath(); ctx.fill();
                                                }
                                            }

                                            // Mini Checkers Preview (Dark & Light)
                                            Row {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 4
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 4

                                                // Dark Checker
                                                Rectangle {
                                                    width: 14; height: 14; radius: 7
                                                    color: tItem.darkBody
                                                    border.color: tItem.darkRim
                                                    border.width: 1.2
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 4; height: 4; radius: 2
                                                        color: tItem.darkPip
                                                    }
                                                }

                                                // Light Checker
                                                Rectangle {
                                                    width: 14; height: 14; radius: 7
                                                    color: tItem.lightBody
                                                    border.color: tItem.lightRim
                                                    border.width: 1.2
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 4; height: 4; radius: 2
                                                        color: tItem.lightPip
                                                    }
                                                }
                                            }
                                        }

                                        // Theme Info
                                        Column {
                                            width: parent.width - 60
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Row {
                                                spacing: 4
                                                Text {
                                                    text: tItem.name
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: isSelected ? root.themeAccent : root.themeFg
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: isSelected ? "✓" : ""
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: root.themeAccent
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: tItem.subtitle
                                                font.pixelSize: 9
                                                color: root.themeSubtext
                                                elide: Text.ElideRight
                                                opacity: 0.85
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.setBoardTheme(tItem.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Victory Modal
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.phase === "gameover"
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNewGame()
            }

            Rectangle {
                width: Math.min(parent.width * 0.88, 360)
                height: endCol.height + 44
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                Column {
                    id: endCol
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: {
                            var pName = (Engine.winner === 1) ? "DARK" : "LIGHT";
                            var tName = (Engine.winType === "backgammon") ? "BACKGAMMON!" :
                                        (Engine.winType === "gammon" ? "GAMMON!" : "WINS!");
                            return pName + " " + tName;
                        }
                        color: (Engine.winner === root.humanPlayer) ? root.themeAccent : "#FF5555"
                        font.pixelSize: 26
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "All 15 checkers successfully borne off!"
                        font.pixelSize: 13
                        color: root.themeFg
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 130
                        height: 38
                        radius: 8
                        color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "PLAY AGAIN"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 11
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
                        text: "Or press Space / R"
                        color: root.themeSubtext
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // Notification Toast
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
                PauseAnimation { duration: 1100 }
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
