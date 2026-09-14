import QtQuick
import QtQuick.Window
import "ReversiEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 680
    minimumWidth: 340
    minimumHeight: 480
    title: "Reversi"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeCardHover: isDarkMode ? Qt.lighter(themeCardBg, 1.2) : "#f1f5f9"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    // Reversi specific colors
    readonly property color feltBg: isDarkMode ? "#143826" : "#166534"
    readonly property color feltGrid: isDarkMode ? "#1f4d36" : "#15803d"
    readonly property color darkDiscColor: "#0f172a"
    readonly property color darkDiscBorder: isDarkMode ? "#475569" : "#334155"
    readonly property color lightDiscColor: "#f8fafc"
    readonly property color lightDiscBorder: isDarkMode ? "#cbd5e1" : "#e2e8f0"

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function cycleTheme() {
        var nextIsLight = root.isDarkMode;
        if (nextIsLight) {
            applyTheme({
                background: "#f8fafc",
                board_bg: "#f1f5f9",
                card_bg: "#ffffff",
                border: "#cbd5e1",
                foreground: "#0f172a",
                subtext: "#64748b",
                accent: "#2563eb"
            }, "Light");
        } else {
            applyTheme({
                background: "#181825",
                board_bg: "#11111b",
                card_bg: "#313244",
                border: "#45475a",
                foreground: "#cdd6f4",
                subtext: "#a6adc8",
                accent: "#89b4fa"
            }, "Dark");
        }
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE
    // =========================================================================
    property var boardState: []
    property int currentTurn: 1        // 1: Dark (Black), 2: Light (White)
    property int darkScore: 2
    property int lightScore: 2
    property string gameState: "playing" // "playing", "gameover", "won"
    property string gameMode: "pve"    // "pve" (vs AI), "pvp" (Pass & Play)
    property int humanColor: 1         // 1: Dark (First), 2: Light
    property string aiDifficulty: "casual" // "novice", "casual", "master"
    property bool isAiThinking: false

    property var validMoves: []
    property var hoveredMove: null
    property var lastMove: null
    property var lastFlips: []

    // Keyboard navigation cursor
    property int cursorRow: 3
    property int cursorCol: 2
    property bool keyboardActive: false

    // App state
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Rules: Trap one or more opponent discs between your discs to flip them to your color.\n• Legal Moves: You must flip at least one disc on every turn.\n• Passing: If you have no legal moves, your turn is automatically passed.\n• Victory: The game ends when the board is full or neither player can move. The player with the most discs wins!\n\nControls:\n• Click or tap any highlighted circle to play\n• Keyboard: Arrows / WASD / Vim HJKL to navigate, Space to place\n• U: Undo Move | D: Change Difficulty | P: Toggle Mode | Shift+F: Full/Compact View | R: Restart | M: Sound | ?: Help"

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

        var lum = colorLuminance(bg);
        isDarkMode = lum <= 0.5;
        if (!isDarkMode) {
            themeBoardBg = data.board_bg || data.boardBg || "#f1f5f9";
            themeCardBg = data.card_bg || data.cardBg || "#ffffff";
            themeCardHover = "#f1f5f9";
            themeSubtext = data.subtext || "#64748b";
            themeBorder = data.border || "#cbd5e1";
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = data.board_bg || data.boardBg || Qt.darker(bg, 1.25);
            themeCardBg = data.card_bg || data.cardBg || c0;
            themeCardHover = Qt.lighter(c0, 1.25);
            themeSubtext = data.subtext || "#a6adc8";
            themeBorder = data.border || c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (!isDarkMode && colorLuminance(themeBoardBg) < 0.5) {
            themeBoardBg = "#f1f5f9";
        }
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

    function syncBoard() {
        var b = [];
        var raw = Engine.board;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                b.push(raw[r][c]);
            }
        }
        boardState = b;
        darkScore = Engine.darkCount;
        lightScore = Engine.lightCount;
        currentTurn = Engine.currentTurn;

        if (Engine.gameOver) {
            gameState = "gameover";
            if (Engine.winner === humanColor && gameMode === "pve") {
                gameState = "won";
                playSound("win");
            } else {
                playSound("game_over");
            }
        } else {
            gameState = "playing";
            validMoves = Engine.getValidMoves(currentTurn);
        }
    }

    function startNewGame() {
        aiTimer.stop();
        isAiThinking = false;
        Engine.resetGame();
        lastMove = null;
        lastFlips = [];
        hoveredMove = null;
        gameState = "playing";
        syncBoard();
        playSound("click");

        if (gameMode === "pve" && humanColor === 2) {
            triggerAiMove();
        }
    }

    function executePlayerMove(row, col) {
        if (isAiThinking || gameState !== "playing") return;
        if (gameMode === "pve" && currentTurn !== humanColor) return;

        var res = Engine.makeMove(row, col);
        if (!res.success) {
            playSound("select");
            return;
        }

        lastMove = { r: row, c: col };
        lastFlips = res.flips;
        playSound(res.flips.length > 2 ? "move" : "dock");
        syncBoard();

        if (res.passed) {
            var whoPassed = (res.passedPlayer === 1) ? "Dark" : "White";
            soundToast.show("⚠️ " + whoPassed + " has no legal moves (Passed)");
            playSound("select");
        }

        if (gameState === "playing" && gameMode === "pve" && currentTurn !== humanColor) {
            triggerAiMove();
        }
    }

    function triggerAiMove() {
        if (gameState !== "playing") return;
        isAiThinking = true;
        aiTimer.restart();
    }

    function performAiMove() {
        isAiThinking = false;
        if (gameState !== "playing") return;

        var aiColor = (humanColor === 1) ? 2 : 1;
        var best = Engine.getBestMove(aiColor, aiDifficulty);
        if (!best) {
            syncBoard();
            return;
        }

        var res = Engine.makeMove(best.r, best.c);
        if (res.success) {
            lastMove = { r: best.r, c: best.c };
            lastFlips = res.flips;
            playSound("dock");
            syncBoard();

            if (res.passed) {
                var whoPassed = (res.passedPlayer === 1) ? "Dark" : "White";
                soundToast.show("⚠️ " + whoPassed + " has no legal moves (Passed)");
                playSound("select");

                // If human has to pass again, AI continues
                if (currentTurn === aiColor && !Engine.gameOver) {
                    triggerAiMove();
                }
            }
        } else {
            syncBoard();
        }
    }

    function handleUndo() {
        if (isAiThinking) return;
        aiTimer.stop();

        if (gameMode === "pve") {
            // In PvE, undo both the AI move and the player's prior move
            var didUndoAi = Engine.undo();
            if (didUndoAi && Engine.currentTurn !== humanColor) {
                Engine.undo();
            }
        } else {
            Engine.undo();
        }

        lastMove = null;
        lastFlips = [];
        syncBoard();
        playSound("undo");
        soundToast.show("↶ Move Undone");
    }

    function toggleDifficulty() {
        if (aiDifficulty === "novice") aiDifficulty = "casual";
        else if (aiDifficulty === "casual") aiDifficulty = "master";
        else aiDifficulty = "novice";
        playSound("select");
        soundToast.show("AI Difficulty: " + aiDifficulty.toUpperCase());
    }

    function toggleGameMode() {
        gameMode = (gameMode === "pve") ? "pvp" : "pve";
        playSound("select");
        startNewGame();
        soundToast.show(gameMode === "pve" ? "Mode: Player vs AI" : "Mode: Local 2-Player");
    }

    function isCellLegal(r, c) {
        if (!validMoves || validMoves.length === 0) return false;
        for (var i = 0; i < validMoves.length; i++) {
            if (validMoves[i].r === r && validMoves[i].c === c) return true;
        }
        return false;
    }

    function getCellFlips(r, c) {
        if (!validMoves || validMoves.length === 0) return [];
        for (var i = 0; i < validMoves.length; i++) {
            if (validMoves[i].r === r && validMoves[i].c === c) return validMoves[i].flips;
        }
        return [];
    }

    function isFlipping(r, c) {
        if (!hoveredMove || !hoveredMove.flips) return false;
        for (var i = 0; i < hoveredMove.flips.length; i++) {
            if (hoveredMove.flips[i].r === r && hoveredMove.flips[i].c === c) return true;
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

    Timer {
        id: aiTimer
        interval: 380
        repeat: false
        onTriggered: root.performAiMove()
    }

    Component.onCompleted: {
        Engine.init();
        syncBoard();
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

            if (root.gameState === "gameover" || root.gameState === "won") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.startNewGame();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_T) {
                root.cycleTheme();
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

            // Keyboard grid navigation (Arrows, WASD, Vim HJKL)
            var handled = false;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                root.cursorCol = Math.max(0, root.cursorCol - 1);
                root.keyboardActive = true;
                handled = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                root.cursorCol = Math.min(7, root.cursorCol + 1);
                root.keyboardActive = true;
                handled = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                root.cursorRow = Math.max(0, root.cursorRow - 1);
                root.keyboardActive = true;
                handled = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.cursorRow = Math.min(7, root.cursorRow + 1);
                root.keyboardActive = true;
                handled = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.executePlayerMove(root.cursorRow, root.cursorCol);
                handled = true;
            }

            if (handled) {
                event.accepted = true;
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        // =====================================================================
        // Header background bar
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTiledDesktopMode ? (floatingTiledHUD.y + floatingTiledHUD.height + 8) : (subheaderItem.y + subheaderItem.height + 12)
            color: root.themeBg
            z: 10
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        // =====================================================================
        Item {
            id: headerItem
            z: 20
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 14
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
                    text: "Reversi"
                    font.pixelSize: Math.max(22, Math.min(32, headerItem.width * 0.08))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.isAiThinking ? "AI is calculating..." : (root.currentTurn === 1 ? "Dark's Turn" : "Light's Turn")
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.028))
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
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: (root.currentTurn === 1 && root.gameState === "playing") ? root.themeAccent : (root.isDarkMode ? root.themeBorder : "#cbd5e1")
                    border.width: (root.currentTurn === 1 && root.gameState === "playing") ? 2 : 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: root.darkDiscColor
                            border.color: root.darkDiscBorder
                            border.width: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "DARK"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.isDarkMode ? root.themeSubtext : "#64748b"
                            }
                            Text {
                                text: root.darkScore.toString()
                                font.pixelSize: 16
                                font.bold: true
                                color: root.isDarkMode ? root.themeFg : "#0f172a"
                            }
                        }
                    }
                }

                // LIGHT Stat Card
                Rectangle {
                    width: Math.max(68, Math.min(84, headerItem.width * 0.17))
                    height: Math.max(44, Math.min(52, headerItem.width * 0.11))
                    radius: 8
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: (root.currentTurn === 2 && root.gameState === "playing") ? root.themeAccent : (root.isDarkMode ? root.themeBorder : "#cbd5e1")
                    border.width: (root.currentTurn === 2 && root.gameState === "playing") ? 2 : 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: root.lightDiscColor
                            border.color: root.lightDiscBorder
                            border.width: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "LIGHT"
                                font.pixelSize: 8
                                font.bold: true
                                color: root.isDarkMode ? root.themeSubtext : "#64748b"
                            }
                            Text {
                                text: root.lightScore.toString()
                                font.pixelSize: 16
                                font.bold: true
                                color: root.isDarkMode ? root.themeFg : "#0f172a"
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 2 (Action Bar)
        // =====================================================================
        Item {
            id: subheaderItem
            z: 20
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : 34

            readonly property bool isCrowded: subheaderItem.width < 450

            // Left cluster: How to Play
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                Rectangle {
                    id: helpBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: helpMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff")
                    border.color: helpMouse.containsMouse ? root.themeAccent : (root.isDarkMode ? root.themeBorder : "#cbd5e1")
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
                            color: root.isDarkMode ? root.themeFg : "#0f172a"
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
            }

            // Right cluster: Sound, Mode Toggle, Restart
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Sound Toggle Button
                Rectangle {
                    id: muteBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff")
                    border.color: root.isMuted ? (root.isDarkMode ? root.themeBorder : "#cbd5e1") : root.themeAccent
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
                            color: root.isMuted ? (root.isDarkMode ? root.themeSubtext : "#64748b") : (root.isDarkMode ? root.themeFg : "#0f172a")
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

                // Mode Toggle Button
                Rectangle {
                    id: modeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (modeRow.implicitWidth + 16)
                    radius: 8
                    color: modeMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : (root.isDarkMode ? root.themeCardBg : "#ffffff")
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
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
                            color: root.isDarkMode ? root.themeFg : "#0f172a"
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

                // New Game Action Button
                Rectangle {
                    id: restartBtn
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
                            font.pixelSize: 13
                            visible: subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "New Game (R)"
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
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

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
            z: 20
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "⚫ Reversi"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + (root.darkScore + " - " + root.lightScore)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("TURN: " + (root.currentTurn === 1 ? "Dark" : "Light")) + ")"
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

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Item {
            id: playArea
            anchors.top: headerBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            z: 1

            Rectangle {
                anchors.fill: parent
                color: root.themeBoardBg
            }

            Rectangle {
                id: boardContainer
                width: Math.min(parent.width - 24, parent.height - (root.isTiledDesktopMode ? 24 : 64))
                height: width
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.isTiledDesktopMode ? 0 : -22
                color: root.feltBg
                border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                border.width: 1
                radius: 12
                clip: true

                // Board Coordinate Labels (A-H, 1-8)
                property real coordMargin: Math.max(14, width * 0.04)
                property real gridAreaSize: width - (coordMargin * 2)
                property real cellSize: gridAreaSize / 8.0

                // Horizontal column labels (A-H) Top & Bottom
                Repeater {
                    model: ["A", "B", "C", "D", "E", "F", "G", "H"]
                    Text {
                        x: boardContainer.coordMargin + (index * boardContainer.cellSize) + (boardContainer.cellSize / 2) - (width / 2)
                        y: 2
                        text: modelData
                        font.pixelSize: 8
                        font.bold: true
                        color: "#ffffff"
                        opacity: 0.75
                    }
                }

                // Vertical row labels (1-8) Left & Right
                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8"]
                    Text {
                        x: 3
                        y: boardContainer.coordMargin + (index * boardContainer.cellSize) + (boardContainer.cellSize / 2) - (height / 2)
                        text: modelData
                        font.pixelSize: 8
                        font.bold: true
                        color: "#ffffff"
                        opacity: 0.75
                    }
                }

                // The 8x8 Grid Area
                Item {
                    id: gridArea
                    x: boardContainer.coordMargin
                    y: boardContainer.coordMargin
                    width: boardContainer.gridAreaSize
                    height: boardContainer.gridAreaSize

                    // Star Points at (2,2), (2,6), (6,2), (6,6)
                    Repeater {
                        model: [
                            { r: 2, c: 2 }, { r: 2, c: 6 },
                            { r: 6, c: 2 }, { r: 6, c: 6 }
                        ]
                        Rectangle {
                            x: modelData.c * boardContainer.cellSize - 2.5
                            y: modelData.r * boardContainer.cellSize - 2.5
                            width: 5
                            height: 5
                            radius: 2.5
                            color: root.themeBorder
                            opacity: 0.8
                            z: 2
                        }
                    }

                    // 64 Grid Cells
                    Grid {
                        id: boardGrid
                        columns: 8
                        rows: 8
                        anchors.fill: parent

                        Repeater {
                            model: 64

                            Rectangle {
                                id: cellItem
                                width: boardContainer.cellSize
                                height: boardContainer.cellSize
                                color: "transparent"
                                border.color: root.feltGrid
                                border.width: 0.75

                                readonly property int r: Math.floor(index / 8)
                                readonly property int c: index % 8
                                readonly property int piece: (root.boardState.length === 64) ? root.boardState[index] : 0
                                readonly property bool isLegal: root.isCellLegal(r, c)
                                readonly property bool isCursorHere: root.keyboardActive && root.cursorRow === r && root.cursorCol === c
                                readonly property bool isHovered: cellMouse.containsMouse && isLegal
                                readonly property bool isLastMoveCell: root.lastMove && root.lastMove.r === r && root.lastMove.c === c
                                readonly property bool isBeingFlipped: root.isFlipping(r, c)

                                // Cell background highlight on hover / legal
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: cellItem.isCursorHere ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.18) :
                                           (cellItem.isHovered ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.12) : "transparent")
                                }

                                // Last move marker
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    color: "transparent"
                                    border.color: root.themeAccent
                                    border.width: 1.5
                                    radius: 4
                                    opacity: cellItem.isLastMoveCell ? 0.75 : 0
                                }

                                // Ghost indicator for legal moves
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.max(8, boardContainer.cellSize * 0.28)
                                    height: width
                                    radius: width / 2
                                    visible: cellItem.isLegal && cellItem.piece === 0
                                    color: cellItem.isHovered ? root.themeAccent : "transparent"
                                    border.color: root.themeAccent
                                    border.width: 1.5
                                    opacity: cellItem.isHovered ? 0.9 : 0.45

                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }

                                // Disc Item
                                Rectangle {
                                    id: disc
                                    anchors.centerIn: parent
                                    width: Math.max(16, boardContainer.cellSize * 0.78)
                                    height: width
                                    radius: width / 2
                                    visible: cellItem.piece !== 0

                                    color: cellItem.piece === 1 ? root.darkDiscColor : root.lightDiscColor
                                    border.color: cellItem.piece === 1 ? root.darkDiscBorder : root.lightDiscBorder
                                    border.width: Math.max(1, width * 0.05)

                                    // Subtle concentric depth ring
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.76
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.color: cellItem.piece === 1 ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                                        border.width: 1
                                    }

                                    // Hover flip preview glow
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: root.themeAccent
                                        opacity: cellItem.isBeingFlipped ? 0.45 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    // Smooth 3D-style flip animation
                                    transform: Scale {
                                        id: discScale
                                        origin.x: disc.width / 2
                                        origin.y: disc.height / 2
                                        xScale: 1
                                    }

                                    property int prevPiece: cellItem.piece
                                    Connections {
                                        target: cellItem
                                        function onPieceChanged() {
                                            if (disc.prevPiece !== 0 && cellItem.piece !== 0 && disc.prevPiece !== cellItem.piece) {
                                                flipAnim.restart();
                                            }
                                            disc.prevPiece = cellItem.piece;
                                        }
                                    }

                                    SequentialAnimation {
                                        id: flipAnim
                                        NumberAnimation { target: discScale; property: "xScale"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.InQuad }
                                        NumberAnimation { target: discScale; property: "xScale"; from: 0.0; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
                                    }
                                }

                                // Interaction
                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: cellItem.isLegal ? Qt.PointingHandCursor : Qt.ArrowCursor

                                    onEntered: {
                                        root.keyboardActive = false;
                                        if (cellItem.isLegal) {
                                            root.hoveredMove = { r: cellItem.r, c: cellItem.c, flips: root.getCellFlips(cellItem.r, cellItem.c) };
                                        } else {
                                            root.hoveredMove = null;
                                        }
                                    }

                                    onExited: {
                                        if (root.hoveredMove && root.hoveredMove.r === cellItem.r && root.hoveredMove.c === cellItem.c) {
                                            root.hoveredMove = null;
                                        }
                                    }

                                    onClicked: {
                                        root.executePlayerMove(cellItem.r, cellItem.c);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =====================================================================
            // TIER 4: BOTTOM ACTION BAR (Undo, Difficulty, Turn Status)
            // =====================================================================
            Item {
                id: bottomBar
                z: 10
                visible: !root.isTiledDesktopMode
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 32, 420)
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: root.isDarkMode ? root.themeCardBg : "#ffffff"
                    border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        // 1. Undo Button (30% width)
                        Rectangle {
                            width: parent.width * 0.30
                            height: parent.height
                            radius: 8
                            color: undoMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : "transparent"

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
                                    color: root.isDarkMode ? root.themeFg : "#0f172a"
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

                        // Vertical divider
                        Rectangle {
                            width: 1
                            height: parent.height - 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                        }

                        // 2. AI Difficulty Button (38% width)
                        Rectangle {
                            width: parent.width * 0.38
                            height: parent.height
                            radius: 8
                            color: diffMouse.containsMouse ? (root.isDarkMode ? root.themeCardHover : "#f1f5f9") : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
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

                        // Vertical divider
                        Rectangle {
                            width: 1
                            height: parent.height - 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
                        }

                        // 3. Status Summary Pill (remaining width)
                        Item {
                            width: parent.width - (parent.width * 0.30) - (parent.width * 0.38) - 2
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: root.currentTurn === 1 ? root.darkDiscBorder : root.lightDiscColor
                                    border.color: root.isDarkMode ? "#00000000" : "#94a3b8"
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.currentTurn === 1 ? "Dark" : "Light"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.isDarkMode ? root.themeSubtext : "#64748b"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
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
                        text: "HOW TO PLAY REVERSI"
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
                        text: "Created by Chris Thompson (@bigcjat) with Gemini"
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.75
                    }
                }
            }
        }

        // Game Over / Victory Modal
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.gameState === "gameover" || root.gameState === "won"
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
                            if (root.darkScore === root.lightScore) return "TIE GAME!";
                            if (root.darkScore > root.lightScore) {
                                return (root.gameMode === "pve" && root.humanColor === 1) ? "VICTORY!" : "DARK WINS!";
                            } else {
                                return (root.gameMode === "pve" && root.humanColor === 2) ? "VICTORY!" : "LIGHT WINS!";
                            }
                        }
                        color: (root.gameState === "won" || (root.darkScore > root.lightScore && root.humanColor === 1)) ? root.themeAccent : "#FF5555"
                        font.pixelSize: 26
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Score Box
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 24

                        Column {
                            spacing: 3
                            Text {
                                text: "DARK"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.darkScore.toString()
                                font.pixelSize: 22
                                font.bold: true
                                color: root.themeFg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Text {
                            text: "—"
                            font.pixelSize: 20
                            color: root.themeSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 3
                            Text {
                                text: "LIGHT"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.lightScore.toString()
                                font.pixelSize: 22
                                font.bold: true
                                color: root.themeFg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
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
                        text: "Or press R / Space"
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
            color: root.isDarkMode ? root.themeCardBg : "#ffffff"
            border.color: root.isDarkMode ? root.themeBorder : "#cbd5e1"
            border.width: 1
            opacity: 0
            z: 800

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.isDarkMode ? root.themeFg : "#0f172a"
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
