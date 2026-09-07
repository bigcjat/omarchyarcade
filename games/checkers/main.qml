import QtQuick
import QtQuick.Window
import "CheckersEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 560
    height: 720
    minimumWidth: 380
    minimumHeight: 520
    title: "Checkers"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#0B0E14"
    property color themeBoardBg: "#10141D"
    property color themeCardBg: "#171D2A"
    property color themeBorder: "#232D42"
    property color themeFg: "#DCE6F5"
    property color themeSubtext: "#7B8EA8"
    property color themeAccent: "#00F0FF"       // Electric Cyan
    property color themeSecondary: "#FF4D6D"    // Neon Coral
    property color themeBtnBg: themeAccent
    property color themeBtnFg: "#0B0E14"

    // Checkers Vector Palette
    readonly property color cyanPiece: "#00F0FF"
    readonly property color coralPiece: "#FF4D6D"
    readonly property color tileDark: "#151B27"
    readonly property color tileLight: "#20283A"
    readonly property color tileLastMove: "#1A3548"
    readonly property color tileSelected: "#183F57"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE
    // =========================================================================
    property var boardState: []         // 8x8 array of characters
    property string currentTurn: "w"    // "w" (White/Cyan) or "b" (Black/Coral)
    property string playerColor: "w"    // Perspective: "w" at bottom, "b" at bottom
    property string gameState: "playing"// "playing", "won", "gameover", "draw"
    property bool isAiThinking: false
    property string difficulty: "casual"// "novice", "casual", "club", "expert"
    property string statusMessage: "Your turn (Cyan)"

    // Selection & Legal Move Highlighting
    property var selectedSquare: null   // [r, c] or null
    property var validMoves: []         // Legal move objects from selected square
    property var allLegalMoves: []      // All legal moves on board for current player
    property var lastMoveFrom: null     // [r, c] or null
    property var lastMoveTo: null       // [r, c] or null
    property var historyStack: []       // For undo support

    // Piece Counts & Material
    property int whiteTotal: 12
    property int blackTotal: 12
    property int whiteKings: 0
    property int blackKings: 0
    property int materialDiff: 0

    // Multi-jump state
    property var activeMultiJumper: null // [r, c] if locked into multi-jump

    // UI & System State
    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Move Pieces: Click piece then destination square, or Drag & Drop\n• Forced Jumps: If a jump is available, it must be taken!\n• Kings: Pieces reaching the far rank become Kings (can move & jump backwards)\n• Undo Move: U\n• Flip Board: F\n• AI Difficulty: D (Novice, Casual, Club, Expert)\n• New Game: R\n• Sound: M\n• Help: ? or Esc"

    // =========================================================================
    // CONNECTIONS TO PYTHON AI BACKEND
    // =========================================================================
    Connections {
        target: (typeof checkersBackend !== "undefined" && checkersBackend) ? checkersBackend : null

        function onAiMoveReady(move) {
            root.isAiThinking = false;
            if (!move || !move.from || !move.to) {
                syncGameState();
                return;
            }

            try {
                executeMove(move);
            } catch (e) {
                console.log("Error executing AI move:", e);
                root.isAiThinking = false;
                syncGameState();
            }
        }

        function onThinkingChanged(thinking) {
            root.isAiThinking = thinking;
        }
    }

    // =========================================================================
    // SOUND & THEME DISPATCHERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#0B0E14";
        var fg = data.foreground || data.fg || "#DCE6F5";
        var accent = data.accent || "#00F0FF";
        var c0 = data.color0 || "#171D2A";
        var c8 = data.color8 || data.color0 || "#232D42";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.06);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#0B0E14" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#7B8EA8";
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#0B0E14" : "#ffffff";
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

    function cycleDifficulty() {
        var diffs = ["novice", "casual", "club", "expert"];
        var idx = diffs.indexOf(root.difficulty);
        root.difficulty = diffs[(idx + 1) % diffs.length];
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("difficulty", root.difficulty);
        }
        playSound("click");
        soundToast.show("Difficulty: " + root.difficulty.toUpperCase());
    }

    function toggleBoardFlip() {
        root.playerColor = (root.playerColor === "w") ? "b" : "w";
        playSound("click");
        soundToast.show(root.playerColor === "w" ? "Playing White (Cyan)" : "Playing Black (Coral)");
        syncGameState();
        if (root.gameState === "playing" && root.currentTurn !== root.playerColor && !root.isAiThinking) {
            triggerAiMove();
        }
    }

    // =========================================================================
    // GAME INITIALIZATION & MOVE LOGIC
    // =========================================================================
    function initCheckersGame() {
        root.boardState = Engine.createInitialBoard();
        root.currentTurn = "w";
        root.selectedSquare = null;
        root.validMoves = [];
        root.lastMoveFrom = null;
        root.lastMoveTo = null;
        root.historyStack = [];
        root.gameState = "playing";
        root.activeMultiJumper = null;

        if (typeof settingsManager !== "undefined" && settingsManager) {
            var savedDiff = settingsManager.getValue("difficulty", "casual");
            if (["novice", "casual", "club", "expert"].indexOf(savedDiff) !== -1) {
                root.difficulty = savedDiff;
            }
        }

        syncGameState();

        // If player chose black, AI moves first
        if (root.playerColor === "b" && root.currentTurn === "w") {
            triggerAiMove();
        }
    }

    function restartGame() {
        initCheckersGame();
        playSound("click");
    }

    function syncGameState() {
        // Calculate piece counts
        var counts = Engine.countPieces(root.boardState);
        root.whiteTotal = counts.whiteTotal;
        root.blackTotal = counts.blackTotal;
        root.whiteKings = counts.whiteKings;
        root.blackKings = counts.blackKings;
        root.materialDiff = counts.whiteDiff;

        // Check legal moves
        root.allLegalMoves = Engine.getAllLegalMoves(root.boardState, root.currentTurn);

        // Win / Loss detection
        if (root.whiteTotal === 0) {
            root.gameState = (root.playerColor === "b") ? "won" : "gameover";
            root.statusMessage = "Black (Coral) wins!";
            root.playSound(root.gameState === "won" ? "win" : "game_over");
        } else if (root.blackTotal === 0) {
            root.gameState = (root.playerColor === "w") ? "won" : "gameover";
            root.statusMessage = "White (Cyan) wins!";
            root.playSound(root.gameState === "won" ? "win" : "game_over");
        } else if (root.allLegalMoves.length === 0) {
            var winner = (root.currentTurn === "w") ? "Black" : "White";
            root.gameState = (winner === (root.playerColor === "w" ? "White" : "Black")) ? "won" : "gameover";
            root.statusMessage = "No moves left! " + winner + " wins!";
            root.playSound(root.gameState === "won" ? "win" : "game_over");
        } else {
            var hasJumps = (root.allLegalMoves.length > 0 && root.allLegalMoves[0].captures.length > 0);
            if (root.currentTurn === root.playerColor) {
                root.statusMessage = hasJumps ? "JUMP REQUIRED!" : ("Your turn (" + (root.playerColor === "w" ? "Cyan" : "Coral") + ")");
            } else {
                root.statusMessage = "AI thinking (" + root.difficulty.toUpperCase() + ")...";
            }
        }

        // Refresh grid
        boardGridRepeater.model = 0;
        boardGridRepeater.model = 64;
        piecesRepeater.model = 0;
        piecesRepeater.model = 64;
    }

    function triggerAiMove() {
        if (root.gameState !== "playing") return;
        if (typeof checkersBackend !== "undefined" && checkersBackend) {
            root.isAiThinking = true;
            var bStr = Engine.boardToStr(root.boardState);
            checkersBackend.requestAiMove(bStr, root.currentTurn, root.difficulty);
        }
    }

    function handleSquareClicked(r, c) {
        if (root.gameState !== "playing" || root.isAiThinking) return;

        // If a piece is already selected, check if clicked square is a valid destination
        if (root.selectedSquare !== null) {
            for (var i = 0; i < root.validMoves.length; i++) {
                var mv = root.validMoves[i];
                if (mv.to[0] === r && mv.to[1] === c) {
                    executeMove(mv);
                    return;
                }
            }
        }

        // Otherwise select piece if it has legal moves
        var piece = root.boardState[r][c];
        var isPlayerPiece = (root.playerColor === "w" && Engine.isWhite(piece)) || (root.playerColor === "b" && Engine.isBlack(piece));

        if (isPlayerPiece && root.currentTurn === root.playerColor) {
            var pieceMoves = [];
            for (var j = 0; j < root.allLegalMoves.length; j++) {
                var lm = root.allLegalMoves[j];
                if (lm.from[0] === r && lm.from[1] === c) {
                    pieceMoves.push(lm);
                }
            }

            if (pieceMoves.length > 0) {
                root.selectedSquare = [r, c];
                root.validMoves = pieceMoves;
                root.playSound("select");
            } else {
                root.selectedSquare = null;
                root.validMoves = [];
                var hasJumps = (root.allLegalMoves.length > 0 && root.allLegalMoves[0].captures.length > 0);
                if (hasJumps) {
                    root.playSound("push");
                    soundToast.show("JUMP REQUIRED! Checkers rules mandate captures.");
                }
            }
        } else {
            root.selectedSquare = null;
            root.validMoves = [];
        }
    }

    function executeMove(move) {
        // Push board to undo history
        root.historyStack.push({
            board: JSON.parse(JSON.stringify(root.boardState)),
            turn: root.currentTurn,
            lastFrom: root.lastMoveFrom,
            lastTo: root.lastMoveTo
        });

        var res = Engine.applyMove(root.boardState, move);

        root.lastMoveFrom = move.from;
        root.lastMoveTo = move.to;
        root.selectedSquare = null;
        root.validMoves = [];

        try {
            if (move.captures && move.captures.length > 0) {
                root.playSound("push");
            } else {
                root.playSound("move");
            }

            if (res && res.promoted) {
                root.playSound("dock");
                if (soundToast && typeof soundToast.show === "function") {
                    soundToast.show("CROWNED KING!");
                }
            }
        } catch (e) {
            console.log("Sound/toast notification error:", e);
        }

        // Switch turn ALWAYS
        root.currentTurn = (root.currentTurn === "w") ? "b" : "w";
        syncGameState();

        // Trigger AI if it's now AI's turn
        if (root.gameState === "playing" && root.currentTurn !== root.playerColor) {
            triggerAiMove();
        }
    }

    function undoMove() {
        if (root.historyStack.length === 0 || root.isAiThinking) return;

        // If playing against AI, undo 2 moves (computer + player)
        var item = root.historyStack.pop();
        if (root.currentTurn !== root.playerColor && root.historyStack.length > 0) {
            item = root.historyStack.pop();
        }

        if (item) {
            root.boardState = item.board;
            root.currentTurn = item.turn;
            root.lastMoveFrom = item.lastFrom;
            root.lastMoveTo = item.lastTo;
            root.selectedSquare = null;
            root.validMoves = [];
            root.gameState = "playing";
            syncGameState();
            playSound("undo");
            soundToast.show("Move Undone");
        }
    }

    // Grid mapping helper (supporting board flip)
    function getBoardRow(displayRow) {
        return (root.playerColor === "w") ? displayRow : (7 - displayRow);
    }

    function getBoardCol(displayCol) {
        return (root.playerColor === "w") ? displayCol : (7 - displayCol);
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
        initCheckersGame();
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLERS
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

            if (root.gameState === "gameover" || root.gameState === "won") {
                if (event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                    root.restartGame();
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
                root.restartGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_U) {
                root.undoMove();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F) {
                root.toggleBoardFlip();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_D) {
                root.cycleDifficulty();
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
            height: Math.max(titleCol.height, statsRow.height)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: statsRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 8
                    Text {
                        text: "CHECKERS"
                        font.pixelSize: Math.max(18, Math.min(24, headerItem.width * 0.06))
                        font.bold: true
                        color: root.themeAccent
                        font.family: root.monoFontFamily
                    }

                    // Turn Badge Indicator
                    Rectangle {
                        height: 20
                        width: turnText.implicitWidth + 14
                        radius: 10
                        color: (root.currentTurn === "w") ? Qt.rgba(0, 0.94, 1, 0.15) : Qt.rgba(1, 0.3, 0.43, 0.15)
                        border.color: (root.currentTurn === "w") ? root.cyanPiece : root.coralPiece
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: turnText
                            anchors.centerIn: parent
                            text: (root.isAiThinking) ? "THINKING..." : (root.currentTurn === root.playerColor ? "YOUR TURN" : "AI TURN")
                            font.pixelSize: 9
                            font.bold: true
                            color: (root.currentTurn === "w") ? root.cyanPiece : root.coralPiece
                            font.family: root.monoFontFamily
                        }
                    }
                }

                Text {
                    text: root.statusMessage
                    font.pixelSize: 11
                    color: (root.statusMessage.indexOf("REQUIRED") !== -1) ? root.coralPiece : root.themeSubtext
                    elide: Text.ElideRight
                    width: parent.width
                    font.bold: (root.statusMessage.indexOf("REQUIRED") !== -1)
                }
            }

            // Stat Cards (AI Level + Diff)
            Row {
                id: statsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Difficulty Pill Button
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: 42
                    radius: 8
                    color: diffMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "AI LEVEL"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.difficulty.toUpperCase()
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeAccent
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

                // Pieces Left / Diff Card
                Rectangle {
                    width: Math.max(54, Math.min(74, headerItem.width * 0.14))
                    height: 42
                    radius: 8
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DIFF"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.materialDiff === 0) ? "EVEN" : ((root.materialDiff > 0 ? "+" : "") + root.materialDiff)
                            font.pixelSize: 12
                            font.bold: true
                            color: (root.materialDiff > 0) ? root.cyanPiece : ((root.materialDiff < 0) ? root.coralPiece : root.themeFg)
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: SUBHEADER ACTION BAR
        // =====================================================================
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 32

            readonly property bool isCrowded: subheaderItem.width < 450

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Help Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 80
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "?"; font.pixelSize: 12; font.bold: true; color: root.themeAccent }
                        Text { text: "Help"; font.pixelSize: 11; font.bold: true; color: root.themeFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Flip Board Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 84
                    radius: 6
                    color: flipMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "🔄"; font.pixelSize: 11 }
                        Text { text: "Flip (F)"; font.pixelSize: 11; font.bold: true; color: root.themeFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: flipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBoardFlip()
                    }
                }

                // Undo Move Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 84
                    radius: 6
                    color: undoMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "↩️"; font.pixelSize: 11 }
                        Text { text: "Undo (U)"; font.pixelSize: 11; font.bold: true; color: root.themeFg; visible: !subheaderItem.isCrowded }
                    }

                    MouseArea {
                        id: undoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.undoMove()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Mute Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 70
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 12 }
                        Text { text: root.isMuted ? "Muted" : "Sound"; font.pixelSize: 11; font.bold: true; color: root.themeFg; visible: !subheaderItem.isCrowded }
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
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : 96
                    radius: 6
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "⚡"; font.pixelSize: 11 }
                        Text { text: "New Game"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg; visible: !subheaderItem.isCrowded }
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
        // CAPTURED PIECES TRAY: OPPONENT (TOP TRAY)
        // =====================================================================
        Item {
            id: topTray
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 8
            anchors.left: boardWrapper.left
            anchors.right: boardWrapper.right
            height: 22

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "AI (" + (root.playerColor === "w" ? "CORAL" : "CYAN") + "):"
                    font.pixelSize: 9
                    font.bold: true
                    color: root.themeSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: (root.playerColor === "w") ? (12 - root.whiteTotal) : (12 - root.blackTotal)
                    Image {
                        width: 14
                        height: 14
                        sourceSize.width: 14
                        sourceSize.height: 14
                        source: "assets/man_" + (root.playerColor === "w" ? "cyan.svg" : "coral.svg")
                    }
                }
            }
        }

        // =====================================================================
        // CHECKERS BOARD AREA
        // =====================================================================
        Item {
            id: boardWrapper
            anchors.top: topTray.bottom
            anchors.topMargin: 4
            anchors.bottom: bottomTray.top
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 32, height)
            height: Math.min(mainContainer.height - 230, mainContainer.width - 32)

            readonly property real boardSize: Math.floor(Math.min(width, height))
            readonly property real cellSize: Math.floor(boardSize / 8)

            Rectangle {
                id: boardContainer
                width: boardWrapper.cellSize * 8
                height: boardWrapper.cellSize * 8
                anchors.centerIn: parent
                color: root.themeBoardBg
                radius: 8
                border.color: root.themeBorder
                border.width: 2
                clip: true

                // 8x8 Board Tiles Grid
                Grid {
                    id: boardGrid
                    columns: 8
                    rows: 8
                    anchors.centerIn: parent
                    width: boardWrapper.cellSize * 8
                    height: boardWrapper.cellSize * 8

                    Repeater {
                        id: boardGridRepeater
                        model: 64

                        Rectangle {
                            id: tileItem
                            width: boardWrapper.cellSize
                            height: boardWrapper.cellSize

                            readonly property int displayCol: index % 8
                            readonly property int displayRow: Math.floor(index / 8)
                            readonly property int r: root.getBoardRow(displayRow)
                            readonly property int c: root.getBoardCol(displayCol)
                            readonly property bool isDark: (r + c) % 2 === 1

                            readonly property bool isSelected: root.selectedSquare !== null && root.selectedSquare[0] === r && root.selectedSquare[1] === c
                            readonly property bool isLastMove: (root.lastMoveFrom !== null && root.lastMoveFrom[0] === r && root.lastMoveFrom[1] === c) || (root.lastMoveTo !== null && root.lastMoveTo[0] === r && root.lastMoveTo[1] === c)

                            // Check if this square is a valid destination for selected piece
                            readonly property var validMoveForTile: {
                                for (var i = 0; i < root.validMoves.length; i++) {
                                    if (root.validMoves[i].to[0] === r && root.validMoves[i].to[1] === c) {
                                        return root.validMoves[i];
                                    }
                                }
                                return null;
                            }

                            // Base tile color
                            color: isSelected ? root.tileSelected : (isLastMove ? root.tileLastMove : (isDark ? root.tileDark : root.tileLight))

                            // Subtle neon border for selected square
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: root.themeAccent
                                border.width: 2
                                visible: tileItem.isSelected
                            }

                            // Board Coordinate Labels
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: 2
                                anchors.rightMargin: 3
                                text: String.fromCharCode(97 + tileItem.c)
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: tileItem.isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                                visible: tileItem.displayRow === 7
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: 2
                                anchors.leftMargin: 3
                                text: (8 - tileItem.r).toString()
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: tileItem.isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                                visible: tileItem.displayCol === 0
                            }

                            // Legal Move Target Reticle
                            Item {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                visible: tileItem.validMoveForTile !== null

                                // Quiet Move: glowing cyan center pip
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.max(8, boardWrapper.cellSize * 0.24)
                                    height: width
                                    radius: width / 2
                                    color: Qt.rgba(0, 0.94, 1, 0.6)
                                    visible: tileItem.validMoveForTile !== null && tileItem.validMoveForTile.captures.length === 0
                                }

                                // Capture Jump Move: neon coral hazard ring
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: boardWrapper.cellSize * 0.78
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: root.coralPiece
                                    border.width: 2.5
                                    visible: tileItem.validMoveForTile !== null && tileItem.validMoveForTile.captures.length > 0

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.5; to: 1.0; duration: 400 }
                                        NumberAnimation { from: 1.0; to: 0.5; duration: 400 }
                                    }
                                }
                            }

                            // Square Mouse Area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (tileItem.validMoveForTile !== null || (root.boardState.length > 0 && root.boardState[tileItem.r][tileItem.c] !== '.')) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.handleSquareClicked(tileItem.r, tileItem.c)
                            }
                        }
                    }
                }

                // Dynamic Pieces Layer
                Repeater {
                    id: piecesRepeater
                    model: 64

                    Item {
                        id: pieceContainer
                        width: boardWrapper.cellSize
                        height: boardWrapper.cellSize

                        readonly property int displayCol: index % 8
                        readonly property int displayRow: Math.floor(index / 8)
                        readonly property int r: root.getBoardRow(displayRow)
                        readonly property int c: root.getBoardCol(displayCol)
                        readonly property string pieceChar: (root.boardState.length > r && root.boardState[r].length > c) ? root.boardState[r][c] : "."
                        readonly property bool hasPiece: pieceChar !== "."

                        x: displayCol * boardWrapper.cellSize
                        y: displayRow * boardWrapper.cellSize
                        visible: hasPiece
                        z: dragArea.drag.active ? 100 : 10

                        Image {
                            id: pieceImage
                            anchors.centerIn: parent
                            width: boardWrapper.cellSize * 0.84
                            height: boardWrapper.cellSize * 0.84
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true

                            source: {
                                if (pieceContainer.pieceChar === 'w') return "assets/man_cyan.svg";
                                if (pieceContainer.pieceChar === 'W') return "assets/king_cyan.svg";
                                if (pieceContainer.pieceChar === 'b') return "assets/man_coral.svg";
                                if (pieceContainer.pieceChar === 'B') return "assets/king_coral.svg";
                                return "";
                            }

                            scale: (root.selectedSquare !== null && root.selectedSquare[0] === pieceContainer.r && root.selectedSquare[1] === pieceContainer.c) ? 1.10 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150 } }
                        }

                        // Drag & Drop
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: {
                                var isTurn = (root.currentTurn === root.playerColor);
                                var isPlayerPiece = (root.playerColor === "w" && Engine.isWhite(pieceContainer.pieceChar)) || (root.playerColor === "b" && Engine.isBlack(pieceContainer.pieceChar));
                                return (isTurn && isPlayerPiece) ? pieceContainer : null;
                            }
                            cursorShape: (pieceContainer.hasPiece && ((root.playerColor === "w" && Engine.isWhite(pieceContainer.pieceChar)) || (root.playerColor === "b" && Engine.isBlack(pieceContainer.pieceChar)))) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onPressed: {
                                root.handleSquareClicked(pieceContainer.r, pieceContainer.c);
                            }

                            onReleased: {
                                if (drag.active) {
                                    var dropDisplayCol = Math.round(pieceContainer.x / boardWrapper.cellSize);
                                    var dropDisplayRow = Math.round(pieceContainer.y / boardWrapper.cellSize);
                                    if (dropDisplayCol >= 0 && dropDisplayCol < 8 && dropDisplayRow >= 0 && dropDisplayRow < 8) {
                                        var targetR = root.getBoardRow(dropDisplayRow);
                                        var targetC = root.getBoardCol(dropDisplayCol);
                                        for (var i = 0; i < root.validMoves.length; i++) {
                                            var mv = root.validMoves[i];
                                            if (mv.to[0] === targetR && mv.to[1] === targetC) {
                                                root.executeMove(mv);
                                                break;
                                            }
                                        }
                                    }
                                    pieceContainer.x = pieceContainer.displayCol * boardWrapper.cellSize;
                                    pieceContainer.y = pieceContainer.displayRow * boardWrapper.cellSize;
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CAPTURED PIECES TRAY: PLAYER (BOTTOM TRAY)
        // =====================================================================
        Item {
            id: bottomTray
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: boardWrapper.left
            anchors.right: boardWrapper.right
            height: 22

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "YOU (" + (root.playerColor === "w" ? "CYAN" : "CORAL") + "):"
                    font.pixelSize: 9
                    font.bold: true
                    color: root.themeSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: (root.playerColor === "w") ? (12 - root.blackTotal) : (12 - root.whiteTotal)
                    Image {
                        width: 14
                        height: 14
                        sourceSize.width: 14
                        sourceSize.height: 14
                        source: "assets/man_" + (root.playerColor === "w" ? "coral.svg" : "cyan.svg")
                    }
                }
            }
        }

        // =====================================================================
        // HELP MODAL
        // =====================================================================
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#CC000000"
            visible: root.showHelp
            z: 950

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
        // GAME OVER / VICTORY OVERLAY
        // =====================================================================
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#CC000000"
            visible: root.gameState === "gameover" || root.gameState === "won"
            z: 960

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.restartGame()
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: root.gameState === "won" ? "VICTORY!" : "GAME OVER"
                    color: root.gameState === "won" ? root.themeAccent : "#FF5555"
                    font.pixelSize: 26
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.statusMessage
                    color: root.themeFg
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 140
                    height: 40
                    radius: 8
                    color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "PLAY AGAIN"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: playAgainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartGame()
                    }
                }

                Text {
                    text: "Or press R to restart"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // =====================================================================
        // SOUND TOAST
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
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
