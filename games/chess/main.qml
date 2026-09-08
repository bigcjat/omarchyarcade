import QtQuick
import QtQuick.Window
import "chess.js" as ChessJS

Window {
    id: root
    visible: true
    width: 560
    height: 720
    minimumWidth: 380
    minimumHeight: 520
    title: "Chess"

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

    // Chess Vector Palette
    readonly property color cyanPiece: "#00F0FF"
    readonly property color coralPiece: "#FF4D6D"
    readonly property color tileDark: "#151B27"
    readonly property color tileLight: "#20283A"
    readonly property color tileLastMove: "#1A3548"
    readonly property color tileSelected: "#183F57"
    readonly property color tileCheck: "#4A1828"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // GAME ENGINE & LOGIC PROPERTIES
    // =========================================================================
    property var chessGame: null
    property string gameState: "playing" // "playing", "checkmate", "stalemate", "draw"
    property string playerColor: "w"    // "w" (White / Cyan) or "b" (Black / Coral)
    property string currentTurn: "w"
    property bool isAiThinking: false
    property string difficulty: "casual" // "novice", "casual", "club", "expert"
    property string statusMessage: "White to move"

    // Selection & Highlighting
    property string selectedSquare: ""
    property var validMoves: []        // Array of square strings (e.g. ["e3", "e4"])
    property string lastMoveFrom: ""
    property string lastMoveTo: ""
    property string checkSquare: ""

    // Captured pieces & Material evaluation
    property var capturedWhite: []
    property var capturedBlack: []
    property int materialDiff: 0       // Positive = White ahead, Negative = Black ahead

    // Pawn Promotion Dialog State
    property bool showPromotionModal: false
    property var pendingPromotionMove: null

    // UI & System State
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Move Pieces: Click piece then destination square, or Drag & Drop\n• Undo Move: U\n• Flip Board: F\n• AI Difficulty: D (Novice, Casual, Club, Expert)\n• New Game: R\n• Full/Compact View: Shift+F
• Sound: M\n• Help: ? or Esc"

    // =========================================================================
    // CONNECTIONS TO PYTHON AI BACKEND
    // =========================================================================
    Connections {
        target: (typeof chessBackend !== "undefined" && chessBackend) ? chessBackend : null

        function onAiMoveReady(fromSquare, toSquare, promo) {
            root.isAiThinking = false;
            if (!fromSquare || !toSquare) {
                syncGameState();
                return;
            }

            // Execute AI move in local engine
            var move = root.chessGame.move({
                from: fromSquare,
                to: toSquare,
                promotion: promo ? promo : "q"
            });

            if (move) {
                root.lastMoveFrom = fromSquare;
                root.lastMoveTo = toSquare;
                if (move.captured) {
                    root.playSound("push");
                } else {
                    root.playSound("move");
                }
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
    // GAME INITIALIZATION & BOARD LOGIC
    // =========================================================================
    function initChessGame() {
        root.chessGame = ChessJS.createGame();
        root.selectedSquare = "";
        root.validMoves = [];
        root.lastMoveFrom = "";
        root.lastMoveTo = "";
        root.checkSquare = "";
        root.capturedWhite = [];
        root.capturedBlack = [];
        root.materialDiff = 0;
        root.gameState = "playing";
        root.showPromotionModal = false;
        root.pendingPromotionMove = null;

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
        initChessGame();
        playSound("click");
    }

    function undoMove() {
        if (!root.chessGame || root.isAiThinking) return;

        // If playing against AI, undo 2 plies (computer's move + player's move)
        var undone1 = root.chessGame.undo();
        if (undone1) {
            if (root.currentTurn !== root.playerColor) {
                root.chessGame.undo();
            }
            root.selectedSquare = "";
            root.validMoves = [];
            root.lastMoveFrom = "";
            root.lastMoveTo = "";
            root.gameState = "playing";
            syncGameState();
            playSound("undo");
            soundToast.show("Move Undone");
        }
    }

    function syncGameState() {
        if (!root.chessGame) return;

        root.currentTurn = root.chessGame.turn();

        // Check for Check, Checkmate, Stalemate, Draw
        root.checkSquare = "";
        if (root.chessGame.in_check()) {
            var kingColor = root.currentTurn;
            var board = root.chessGame.board();
            for (var r = 0; r < 8; r++) {
                for (var c = 0; c < 8; c++) {
                    var p = board[r][c];
                    if (p && p.type === 'k' && p.color === kingColor) {
                        var file = String.fromCharCode(97 + c);
                        var rank = (8 - r).toString();
                        root.checkSquare = file + rank;
                        break;
                    }
                }
            }
        }

        if (root.chessGame.in_checkmate()) {
            root.gameState = "checkmate";
            var winner = (root.currentTurn === "w") ? "Black" : "White";
            root.statusMessage = "Checkmate! " + winner + " wins!";
            if ((winner === "White" && root.playerColor === "w") || (winner === "Black" && root.playerColor === "b")) {
                root.playSound("win");
            } else {
                root.playSound("game_over");
            }
        } else if (root.chessGame.in_stalemate()) {
            root.gameState = "stalemate";
            root.statusMessage = "Stalemate! Game is a draw.";
            root.playSound("game_over");
        } else if (root.chessGame.in_draw()) {
            root.gameState = "draw";
            root.statusMessage = "Draw by repetition or 50-move rule.";
            root.playSound("game_over");
        } else if (root.checkSquare !== "") {
            root.statusMessage = (root.currentTurn === "w" ? "White" : "Black") + " is in check!";
            root.playSound("target");
        } else {
            root.statusMessage = (root.currentTurn === root.playerColor) ? "Your turn (" + (root.playerColor === "w" ? "Cyan" : "Coral") + ")" : "AI thinking (" + root.difficulty.toUpperCase() + ")...";
        }

        // Calculate captured pieces & material differential
        updateMaterialAndCaptures();

        // Refresh board and pieces
        boardGridRepeater.model = 0;
        boardGridRepeater.model = 64;
        piecesRepeater.model = 0;
        piecesRepeater.model = 64;
    }

    function updateMaterialAndCaptures() {
        var pieceValues = { 'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9, 'k': 0 };
        var totalPieces = {
            'w': { 'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1 },
            'b': { 'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1 }
        };

        var currentPieces = {
            'w': { 'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0 },
            'b': { 'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0 }
        };

        var b = root.chessGame.board();
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = b[r][c];
                if (p && p.type !== 'k') {
                    currentPieces[p.color][p.type]++;
                }
            }
        }

        var capW = [];
        var capB = [];
        var wScore = 0;
        var bScore = 0;

        for (var t in totalPieces['w']) {
            var diffW = totalPieces['w'][t] - currentPieces['w'][t];
            for (var i = 0; i < diffW; i++) capW.push(t);
            wScore += currentPieces['w'][t] * pieceValues[t];
        }

        for (var tb in totalPieces['b']) {
            var diffB = totalPieces['b'][tb] - currentPieces['b'][tb];
            for (var j = 0; j < diffB; j++) capB.push(tb);
            bScore += currentPieces['b'][tb] * pieceValues[tb];
        }

        root.capturedWhite = capW;
        root.capturedBlack = capB;
        root.materialDiff = wScore - bScore;
    }

    function triggerAiMove() {
        if (!root.chessGame || root.gameState !== "playing") return;
        if (typeof chessBackend !== "undefined" && chessBackend) {
            root.isAiThinking = true;
            chessBackend.requestAiMove(root.chessGame.fen(), root.difficulty);
        }
    }

    // =========================================================================
    // SQUARE & MOVE INTERACTION
    // =========================================================================
    function getSquareName(col, row) {
        var file = (root.playerColor === "w") ? String.fromCharCode(97 + col) : String.fromCharCode(104 - col);
        var rank = (root.playerColor === "w") ? (8 - row).toString() : (1 + row).toString();
        return file + rank;
    }

    function getColRowFromSquare(sq) {
        var file = sq.charCodeAt(0) - 97;
        var rank = parseInt(sq.charAt(1));
        var col = (root.playerColor === "w") ? file : 7 - file;
        var row = (root.playerColor === "w") ? 8 - rank : rank - 1;
        return { col: col, row: row };
    }

    function getPieceAt(sq) {
        if (!root.chessGame) return null;
        var file = sq.charCodeAt(0) - 97;
        var rank = parseInt(sq.charAt(1));
        var r = 8 - rank;
        var c = file;
        var b = root.chessGame.board();
        return b[r][c];
    }

    function handleSquareClicked(sq) {
        if (root.gameState !== "playing" || root.isAiThinking) return;

        // If piece is already selected and target is in legal moves:
        if (root.selectedSquare !== "" && root.validMoves.indexOf(sq) !== -1) {
            commitMove(root.selectedSquare, sq);
            return;
        }

        // Otherwise select piece if it belongs to active player
        var piece = getPieceAt(sq);
        if (piece && piece.color === root.currentTurn && piece.color === root.playerColor) {
            root.selectedSquare = sq;
            var moves = root.chessGame.moves({ square: sq, verbose: true });
            var targets = [];
            for (var i = 0; i < moves.length; i++) {
                targets.push(moves[i].to);
            }
            root.validMoves = targets;
            root.playSound("select");
        } else {
            root.selectedSquare = "";
            root.validMoves = [];
        }
    }

    function commitMove(fromSq, toSq, promo) {
        var piece = getPieceAt(fromSq);
        // Check if pawn promotion is needed
        if (piece && piece.type === 'p') {
            var destRank = toSq.charAt(1);
            if ((piece.color === 'w' && destRank === '8') || (piece.color === 'b' && destRank === '1')) {
                if (!promo) {
                    root.pendingPromotionMove = { from: fromSq, to: toSq };
                    root.showPromotionModal = true;
                    return;
                }
            }
        }

        var move = root.chessGame.move({
            from: fromSq,
            to: toSq,
            promotion: promo ? promo : 'q'
        });

        if (move) {
            root.lastMoveFrom = fromSq;
            root.lastMoveTo = toSq;
            root.selectedSquare = "";
            root.validMoves = [];

            if (move.captured) {
                root.playSound("push");
            } else {
                root.playSound("move");
            }

            syncGameState();

            // Trigger AI if still playing and it's AI's turn
            if (root.gameState === "playing" && root.currentTurn !== root.playerColor) {
                triggerAiMove();
            }
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
        initChessGame();
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

            if (root.showPromotionModal) {
                if (event.key === Qt.Key_Q) { root.commitMove(root.pendingPromotionMove.from, root.pendingPromotionMove.to, 'q'); root.showPromotionModal = false; event.accepted = true; return; }
                if (event.key === Qt.Key_R) { root.commitMove(root.pendingPromotionMove.from, root.pendingPromotionMove.to, 'r'); root.showPromotionModal = false; event.accepted = true; return; }
                if (event.key === Qt.Key_B) { root.commitMove(root.pendingPromotionMove.from, root.pendingPromotionMove.to, 'b'); root.showPromotionModal = false; event.accepted = true; return; }
                if (event.key === Qt.Key_N) { root.commitMove(root.pendingPromotionMove.from, root.pendingPromotionMove.to, 'n'); root.showPromotionModal = false; event.accepted = true; return; }
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
            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
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
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, statsRow.height))

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
                        text: "CHESS"
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
                    color: root.themeSubtext
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // Stat Cards (Difficulty + Material)
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

                // Material Score Pill
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
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : 32

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
                    text: "♟️ Chess"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + (root.turnColor + " TURN")
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("WINS: " + root.whiteScore + "-" + root.blackScore) + ")"
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
                        onClicked: root.restartGame()
                    }
                }
            }
        }

        id: topTray
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 8
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
                    model: (root.playerColor === "w") ? root.capturedWhite : root.capturedBlack
                    Image {
                        width: 14
                        height: 14
                        sourceSize.width: 14
                        sourceSize.height: 14
                        source: "assets/" + (modelData === 'p' ? "pawn" : (modelData === 'n' ? "knight" : (modelData === 'b' ? "bishop" : (modelData === 'r' ? "rook" : "queen")))) + (root.playerColor === "w" ? "_cyan.svg" : "_coral.svg")
                    }
                }
            }
        }

        // =====================================================================
        // CHESS BOARD AREA
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

                            readonly property int col: index % 8
                            readonly property int row: Math.floor(index / 8)
                            readonly property string sqName: root.getSquareName(col, row)
                            readonly property bool isDark: (col + row) % 2 === 1
                            readonly property bool isSelected: root.selectedSquare === sqName
                            readonly property bool isLastMove: root.lastMoveFrom === sqName || root.lastMoveTo === sqName
                            readonly property bool isCheck: root.checkSquare === sqName
                            readonly property bool isValidTarget: root.validMoves.indexOf(sqName) !== -1

                            // Base tile color
                            color: isCheck ? root.tileCheck : (isSelected ? root.tileSelected : (isLastMove ? root.tileLastMove : (isDark ? root.tileDark : root.tileLight)))

                            // Subtle neon border for selected square
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: root.themeAccent
                                border.width: 2
                                visible: tileItem.isSelected
                            }

                            // Pulsing In-Check Indicator
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: "#FF0055"
                                border.width: 2
                                visible: tileItem.isCheck

                                SequentialAnimation on opacity {
                                    running: tileItem.isCheck
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 400 }
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 400 }
                                }
                            }

                            // File & Rank Board Coordinate Labels
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: 2
                                anchors.rightMargin: 3
                                text: (root.playerColor === "w") ? String.fromCharCode(97 + tileItem.col) : String.fromCharCode(104 - tileItem.col)
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: tileItem.isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                                visible: tileItem.row === 7
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: 2
                                anchors.leftMargin: 3
                                text: (root.playerColor === "w") ? (8 - tileItem.row).toString() : (1 + tileItem.row).toString()
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: tileItem.isDark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                                visible: tileItem.col === 0
                            }

                            // Target Reticle (Move or Capture)
                            Item {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                visible: tileItem.isValidTarget

                                readonly property var targetPiece: root.getPieceAt(tileItem.sqName)

                                // Non-capture move: soft glowing center pip
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.max(8, boardWrapper.cellSize * 0.24)
                                    height: width
                                    radius: width / 2
                                    color: Qt.rgba(0, 0.94, 1, 0.6)
                                    visible: !parent.targetPiece
                                }

                                // Capture move: outer neon capture hazard ring
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: boardWrapper.cellSize * 0.78
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: root.coralPiece
                                    border.width: 2.5
                                    visible: parent.targetPiece !== null
                                }
                            }

                            // Square Mouse Area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (tileItem.isValidTarget || root.getPieceAt(tileItem.sqName)) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.handleSquareClicked(tileItem.sqName)
                            }
                        }
                    }
                }

                // Dynamic Piece Layer
                Repeater {
                    id: piecesRepeater
                    model: 64

                    Item {
                        id: pieceContainer
                        width: boardWrapper.cellSize
                        height: boardWrapper.cellSize

                        readonly property int col: index % 8
                        readonly property int row: Math.floor(index / 8)
                        readonly property string sqName: root.getSquareName(col, row)
                        readonly property var pieceData: root.getPieceAt(sqName)

                        x: col * boardWrapper.cellSize
                        y: row * boardWrapper.cellSize
                        visible: pieceData !== null
                        z: dragArea.drag.active ? 100 : 10

                        Image {
                            id: pieceImage
                            anchors.centerIn: parent
                            width: boardWrapper.cellSize * 0.82
                            height: boardWrapper.cellSize * 0.82
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true

                            source: pieceContainer.pieceData ? ("assets/" + (pieceContainer.pieceData.type === 'p' ? "pawn" : (pieceContainer.pieceData.type === 'n' ? "knight" : (pieceContainer.pieceData.type === 'b' ? "bishop" : (pieceContainer.pieceData.type === 'r' ? "rook" : (pieceContainer.pieceData.type === 'q' ? "queen" : "king"))))) + (pieceContainer.pieceData.color === 'w' ? "_cyan.svg" : "_coral.svg")) : ""

                            scale: (root.selectedSquare === pieceContainer.sqName) ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150 } }
                        }

                        // Drag and drop interaction
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: (pieceContainer.pieceData && pieceContainer.pieceData.color === root.currentTurn && pieceContainer.pieceData.color === root.playerColor) ? pieceContainer : null
                            cursorShape: (pieceContainer.pieceData && pieceContainer.pieceData.color === root.playerColor) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onPressed: {
                                root.handleSquareClicked(pieceContainer.sqName);
                            }

                            onReleased: {
                                if (drag.active) {
                                    var dropCol = Math.round(pieceContainer.x / boardWrapper.cellSize);
                                    var dropRow = Math.round(pieceContainer.y / boardWrapper.cellSize);
                                    if (dropCol >= 0 && dropCol < 8 && dropRow >= 0 && dropRow < 8) {
                                        var targetSq = root.getSquareName(dropCol, dropRow);
                                        if (root.validMoves.indexOf(targetSq) !== -1) {
                                            root.commitMove(pieceContainer.sqName, targetSq);
                                        }
                                    }
                                    pieceContainer.x = pieceContainer.col * boardWrapper.cellSize;
                                    pieceContainer.y = pieceContainer.row * boardWrapper.cellSize;
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
                    model: (root.playerColor === "w") ? root.capturedBlack : root.capturedWhite
                    Image {
                        width: 14
                        height: 14
                        sourceSize.width: 14
                        sourceSize.height: 14
                        source: "assets/" + (modelData === 'p' ? "pawn" : (modelData === 'n' ? "knight" : (modelData === 'b' ? "bishop" : (modelData === 'r' ? "rook" : "queen")))) + (root.playerColor === "w" ? "_coral.svg" : "_cyan.svg")
                    }
                }
            }
        }

        // =====================================================================
        // PAWN PROMOTION MODAL
        // =====================================================================
        Rectangle {
            id: promotionModal
            anchors.fill: parent
            color: "#CC000000"
            visible: root.showPromotionModal
            z: 920

            Rectangle {
                width: 280
                height: 120
                radius: 12
                color: root.themeCardBg
                border.color: root.themeAccent
                border.width: 2
                anchors.centerIn: parent

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "PROMOTE PAWN"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: [
                                { name: "Queen", code: "q", icon: "queen" },
                                { name: "Rook", code: "r", icon: "rook" },
                                { name: "Bishop", code: "b", icon: "bishop" },
                                { name: "Knight", code: "n", icon: "knight" }
                            ]

                            Rectangle {
                                width: 50
                                height: 50
                                radius: 8
                                color: promoMouse.containsMouse ? root.themeBoardBg : "transparent"
                                border.color: promoMouse.containsMouse ? root.themeAccent : root.themeBorder
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 36
                                    height: 36
                                    sourceSize.width: 36
                                    sourceSize.height: 36
                                    source: "assets/" + modelData.icon + (root.playerColor === "w" ? "_cyan.svg" : "_coral.svg")
                                }

                                MouseArea {
                                    id: promoMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.commitMove(root.pendingPromotionMove.from, root.pendingPromotionMove.to, modelData.code);
                                        root.showPromotionModal = false;
                                    }
                                }
                            }
                        }
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
        // GAME OVER / CHECKMATE OVERLAY
        // =====================================================================
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#CC000000"
            visible: root.gameState === "checkmate" || root.gameState === "stalemate" || root.gameState === "draw"
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
                    text: root.gameState === "checkmate" ? "CHECKMATE!" : "GAME DRAWN"
                    color: (root.gameState === "checkmate" && root.statusMessage.indexOf("wins") !== -1) ? root.themeAccent : "#FF5555"
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
