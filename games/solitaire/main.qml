import QtQuick
import QtQuick.Window
import "SolitaireEngine.js" as Engine
import "Themes.js" as Themes

Window {
    id: root
    visible: true
    width: 860
    height: 720
    minimumWidth: 540
    minimumHeight: 520
    title: "Solitaire"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#0B0E14"
    property color themeFelt: "#0F281E"          // Deep Classic Casino Emerald
    property color themeCardBg: "#171D2A"
    property color themeBorder: "#232D42"
    property color themeFg: "#DCE6F5"
    property color themeSubtext: "#7B8EA8"
    property color themeAccent: "#00F0FF"        // Electric Cyan
    property color themeSecondary: "#FACC15"     // Gold
    property color themeBtnBg: themeAccent
    property color themeBtnFg: "#0B0E14"

    property string forcedTheme: ""
    property string deckStyle: "synthwave"       // "synthwave", "crimson", "sapphire", "obsidian"
    property int drawCount: 1                    // 1 or 3
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    // Solitaire Game State
    property var gameStateData: null
    property var historyStack: []
    property string gameStatus: "playing"        // "playing", "won"
    property int score: 0
    property int moves: 0
    property int elapsedTime: 0
    property int bestScore: 0
    property int fastestTime: 0

    // Selected or Dragging state
    property var selectedCard: null              // { type: "tableau"|"waste"|"foundation", col: 0, index: 0, card: obj }
    property var hintMove: null

    // UI & System State
    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false

    property string helpText: "• Klondike Solitaire Rules:\n  - Build 4 Foundations from Ace up to King by suit (♠ ♥ ♦ ♣)\n  - Build 7 Tableau columns downward in alternating colors (Red / Black)\n  - Empty tableau spaces can only be filled by Kings\n• Controls:\n  - Click card to auto-move to best legal spot (Foundation / Tableau)\n  - Drag & Drop cards or stacks onto valid columns\n  - Click Stock to draw cards (1 or 3)\n  - T to toggle Draw-1 / Draw-3\n  - D to cycle Deck Style\n  - H for Hint\n  - U to Undo\n  - R for New Deal\n  - M to Mute, ? for Help"

    signal screenshotSaved(string filePath)

    // =========================================================================
    // THEME HANDLING
    // =========================================================================
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
            themeFelt = "#1B4332";
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
        } else {
            themeFelt = "#0D231A";
            themeCardBg = c0;
            themeSubtext = "#7B8EA8";
        }
    }

    function colorLuminance(clr) {
        var c = Qt.color(clr);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
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

    function cycleDeckStyle() {
        var styles = ["synthwave", "crimson", "sapphire", "obsidian"];
        var idx = styles.indexOf(root.deckStyle);
        root.deckStyle = styles[(idx + 1) % styles.length];
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("deckStyle", root.deckStyle);
        }
        playSound("click");
        soundToast.show("Deck: " + root.deckStyle.toUpperCase());
    }

    function toggleDrawCount() {
        root.drawCount = (root.drawCount === 1) ? 3 : 1;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("drawCount", root.drawCount.toString());
        }
        playSound("click");
        soundToast.show("Draw Mode: " + root.drawCount + " Card" + (root.drawCount > 1 ? "s" : ""));
    }

    function formatTimer(totalSecs) {
        var m = Math.floor(totalSecs / 60);
        var s = totalSecs % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // =========================================================================
    // GAME ENGINE & MOVES
    // =========================================================================
    function startNewGame() {
        var deal = Engine.initDeal();
        root.gameStateData = deal;
        root.score = 0;
        root.moves = 0;
        root.elapsedTime = 0;
        root.historyStack = [];
        root.gameStatus = "playing";
        root.selectedCard = null;
        root.hintMove = null;

        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
            root.fastestTime = settingsManager.getFastestTime();
            var savedDeck = settingsManager.getValue("deckStyle", "synthwave");
            if (["synthwave", "crimson", "sapphire", "obsidian"].indexOf(savedDeck) !== -1) {
                root.deckStyle = savedDeck;
            }
            var savedDraw = parseInt(settingsManager.getValue("drawCount", "1"), 10);
            if (savedDraw === 1 || savedDraw === 3) {
                root.drawCount = savedDraw;
            }
        }

        refreshUI();
        playSound("dock");
    }

    function pushHistory() {
        if (!root.gameStateData) return;
        root.historyStack.push({
            data: Engine.deepClone(root.gameStateData),
            score: root.score,
            moves: root.moves
        });
    }

    function undoMove() {
        if (root.historyStack.length === 0 || root.gameStatus === "won") return;
        var prev = root.historyStack.pop();
        if (prev) {
            root.gameStateData = prev.data;
            root.score = prev.score;
            root.moves = prev.moves;
            root.selectedCard = null;
            root.hintMove = null;
            refreshUI();
            playSound("undo");
            soundToast.show("Move Undone");
        }
    }

    function handleStockClicked() {
        if (root.gameStatus !== "playing") return;
        pushHistory();

        var res = Engine.drawStock(root.gameStateData.stock, root.gameStateData.waste, root.drawCount);
        root.moves++;
        root.selectedCard = null;
        root.hintMove = null;

        if (res.action === "draw") {
            playSound("move");
        } else if (res.action === "recycle") {
            playSound("push");
            soundToast.show("Stock Recycled");
        }
        refreshUI();
    }

    function handleWasteClicked() {
        if (root.gameStatus !== "playing" || root.gameStateData.waste.length === 0) return;

        // Try single-click auto-move first
        var move = Engine.findBestAutoMove("waste", 0, root.gameStateData.waste.length - 1, root.gameStateData);
        if (move) {
            pushHistory();
            var card = root.gameStateData.waste.pop();
            if (move.targetType === "foundation") {
                root.gameStateData.foundations[move.targetIndex].push(card);
                playSound("dock");
            } else if (move.targetType === "tableau") {
                root.gameStateData.tableau[move.targetIndex].push(card);
                playSound("move");
            }
            root.score = Math.max(0, root.score + move.scoreDelta);
            root.moves++;
            checkEndConditions();
            refreshUI();
            return;
        }

        // Otherwise toggle selection
        if (root.selectedCard && root.selectedCard.type === "waste") {
            root.selectedCard = null;
        } else {
            root.selectedCard = {
                type: "waste",
                card: root.gameStateData.waste[root.gameStateData.waste.length - 1]
            };
            playSound("select");
        }
        refreshUI();
    }

    function handleFoundationClicked(fIndex) {
        if (root.gameStatus !== "playing") return;

        // If a card is selected, try moving to this foundation
        if (root.selectedCard) {
            var card = root.selectedCard.card;
            if (Engine.canMoveToFoundation(card, root.gameStateData.foundations[fIndex])) {
                pushHistory();
                // Remove from source
                if (root.selectedCard.type === "waste") {
                    root.gameStateData.waste.pop();
                    root.score += 10;
                } else if (root.selectedCard.type === "tableau") {
                    var col = root.gameStateData.tableau[root.selectedCard.col];
                    col.pop();
                    var flipped = Engine.checkFlipTableauTop(col);
                    root.score += 10 + (flipped ? 5 : 0);
                }
                root.gameStateData.foundations[fIndex].push(card);
                root.moves++;
                root.selectedCard = null;
                playSound("dock");
                checkEndConditions();
                refreshUI();
                return;
            }
        }
        root.selectedCard = null;
        refreshUI();
    }

    function handleTableauClicked(colIndex, cardIndex) {
        if (root.gameStatus !== "playing") return;
        var col = root.gameStateData.tableau[colIndex];
        if (!col) return;

        // Clicking on an empty tableau column
        if (col.length === 0) {
            if (root.selectedCard) {
                var movingCard = root.selectedCard.card;
                if (Engine.canMoveToTableau(movingCard, col)) {
                    pushHistory();
                    if (root.selectedCard.type === "waste") {
                        root.gameStateData.waste.pop();
                        col.push(movingCard);
                        root.score += 5;
                    } else if (root.selectedCard.type === "foundation") {
                        root.gameStateData.foundations[root.selectedCard.col].pop();
                        col.push(movingCard);
                        root.score = Math.max(0, root.score - 15);
                    } else if (root.selectedCard.type === "tableau") {
                        var srcCol = root.gameStateData.tableau[root.selectedCard.col];
                        var movingStack = srcCol.splice(root.selectedCard.index);
                        for (var s = 0; s < movingStack.length; s++) col.push(movingStack[s]);
                        var flipped = Engine.checkFlipTableauTop(srcCol);
                        if (flipped) root.score += 5;
                    }
                    root.moves++;
                    root.selectedCard = null;
                    playSound("move");
                    checkEndConditions();
                    refreshUI();
                    return;
                }
            }
            root.selectedCard = null;
            refreshUI();
            return;
        }

        var clickedCard = col[cardIndex];
        if (!clickedCard) return;

        // If clicking a face-down card at the top, flip it
        if (!clickedCard.faceUp && cardIndex === col.length - 1) {
            pushHistory();
            clickedCard.faceUp = true;
            root.score += 5;
            playSound("move");
            refreshUI();
            return;
        }

        if (!clickedCard.faceUp) return;

        // If another card was already selected, try moving it onto this column
        if (root.selectedCard && (root.selectedCard.type !== "tableau" || root.selectedCard.col !== colIndex)) {
            var sc = root.selectedCard.card;
            if (Engine.canMoveToTableau(sc, col)) {
                pushHistory();
                if (root.selectedCard.type === "waste") {
                    root.gameStateData.waste.pop();
                    col.push(sc);
                    root.score += 5;
                } else if (root.selectedCard.type === "foundation") {
                    root.gameStateData.foundations[root.selectedCard.col].pop();
                    col.push(sc);
                    root.score = Math.max(0, root.score - 15);
                } else if (root.selectedCard.type === "tableau") {
                    var sCol = root.gameStateData.tableau[root.selectedCard.col];
                    var mStack = sCol.splice(root.selectedCard.index);
                    for (var ms = 0; ms < mStack.length; ms++) col.push(mStack[ms]);
                    var fl = Engine.checkFlipTableauTop(sCol);
                    if (fl) root.score += 5;
                }
                root.moves++;
                root.selectedCard = null;
                playSound("move");
                checkEndConditions();
                refreshUI();
                return;
            }
        }

        // Try single-click auto-move to Foundation or other Tableau
        if (cardIndex === col.length - 1) {
            var auto = Engine.findBestAutoMove("tableau", colIndex, cardIndex, root.gameStateData);
            if (auto) {
                pushHistory();
                var moved = col.pop();
                if (auto.targetType === "foundation") {
                    root.gameStateData.foundations[auto.targetIndex].push(moved);
                    playSound("dock");
                } else if (auto.targetType === "tableau") {
                    root.gameStateData.tableau[auto.targetIndex].push(moved);
                    playSound("move");
                }
                var fl2 = Engine.checkFlipTableauTop(col);
                root.score = Math.max(0, root.score + auto.scoreDelta + (fl2 ? 5 : 0));
                root.moves++;
                root.selectedCard = null;
                checkEndConditions();
                refreshUI();
                return;
            }
        }

        // Otherwise select this card (or substack)
        if (Engine.isValidSubstack(col, cardIndex)) {
            if (root.selectedCard && root.selectedCard.type === "tableau" && root.selectedCard.col === colIndex && root.selectedCard.index === cardIndex) {
                root.selectedCard = null;
            } else {
                root.selectedCard = {
                    type: "tableau",
                    col: colIndex,
                    index: cardIndex,
                    card: clickedCard
                };
                playSound("select");
            }
        } else {
            root.selectedCard = null;
        }
        refreshUI();
    }

    function triggerHint() {
        if (!root.gameStateData || root.gameStatus !== "playing") return;
        var h = Engine.getHint(root.gameStateData);
        if (h) {
            root.hintMove = h;
            playSound("select");
            soundToast.show("Hint: " + h.card + " (" + h.from.toUpperCase() + " → " + h.to.toUpperCase() + ")");
        } else {
            soundToast.show("No obvious moves available.");
        }
    }

    function checkEndConditions() {
        if (!root.gameStateData) return;

        // Check Victory
        if (Engine.checkWon(root.gameStateData.foundations)) {
            root.gameStatus = "won";
            playSound("win");
            if (root.score > root.bestScore) {
                root.bestScore = root.score;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setBestScore(root.bestScore);
                }
            }
            if (root.fastestTime === 0 || root.elapsedTime < root.fastestTime) {
                root.fastestTime = root.elapsedTime;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setFastestTime(root.fastestTime);
                }
            }
            return;
        }

        // Check Auto-Complete readiness
        if (Engine.canAutoComplete(root.gameStateData.stock, root.gameStateData.waste, root.gameStateData.tableau)) {
            autoFinishTimer.start();
        }
    }

    function refreshUI() {
        wasteRepeater.model = 0;
        wasteRepeater.model = root.gameStateData ? root.gameStateData.waste.length : 0;

        foundationRepeater.model = 0;
        foundationRepeater.model = 4;

        tableauRepeater.model = 0;
        tableauRepeater.model = 7;
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

    // Auto-Complete Cascading Timer
    Timer {
        id: autoFinishTimer
        interval: 120
        repeat: true
        running: false
        onTriggered: {
            if (root.gameStatus === "won") {
                autoFinishTimer.stop();
                return;
            }
            var moved = Engine.stepAutoComplete(root.gameStateData.tableau, root.gameStateData.foundations);
            if (moved) {
                root.score += 10;
                root.moves++;
                playSound("dock");
                refreshUI();
                if (Engine.checkWon(root.gameStateData.foundations)) {
                    autoFinishTimer.stop();
                    checkEndConditions();
                }
            } else {
                autoFinishTimer.stop();
            }
        }
    }

    // Game Timer
    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        running: root.gameStatus === "playing" && splashScreen.opacity === 0
        onTriggered: {
            root.elapsedTime++;
        }
    }

    Component.onCompleted: {
        startNewGame();
    }

    // =========================================================================
    // KEYBOARD SHORTCUTS
    // =========================================================================
    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (root.showHelp) root.showHelp = false;
                else Qt.quit();
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
            } else if (event.key === Qt.Key_R) {
                root.startNewGame();
            } else if (event.key === Qt.Key_U) {
                root.undoMove();
            } else if (event.key === Qt.Key_M) {
                root.toggleMute();
            } else if (event.key === Qt.Key_T) {
                root.toggleDrawCount();
            } else if (event.key === Qt.Key_D) {
                root.cycleDeckStyle();
            } else if (event.key === Qt.Key_H) {
                root.triggerHint();
            } else if (event.key === Qt.Key_Space) {
                root.handleStockClicked();
            }
        }
    }

    // =========================================================================
    // MAIN CONTAINER & FELT BACKGROUND
    // =========================================================================
    Item {
        id: mainContainer
        anchors.fill: parent

        Rectangle {
            id: feltBg
            anchors.fill: parent
            color: root.themeFelt

            Image {
                anchors.fill: parent
                source: "assets/felt-pattern.svg"
                fillMode: Image.Tile
                opacity: 0.12
            }
        }

        // =====================================================================
        // HEADER BAR
        // =====================================================================
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            Rectangle {
                anchors.fill: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
            }

            // Left: Title + Draw Mode Badge
            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: "SOLITAIRE"
                    font.pixelSize: 20
                    font.bold: true
                    font.family: root.monoFontFamily
                    color: root.themeAccent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: drawBadgeText.implicitWidth + 12
                    height: 22
                    radius: 11
                    color: Qt.rgba(0, 0.94, 1, 0.15)
                    border.color: root.themeAccent
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: drawBadgeText
                        anchors.centerIn: parent
                        text: "DRAW " + root.drawCount
                        font.pixelSize: 9
                        font.bold: true
                        color: root.themeAccent
                    }
                }
            }

            // Stats Row (Score, Moves, Time)
            Row {
                id: statsRow
                anchors.left: titleRow.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.width >= 680

                // Score Card
                Rectangle {
                    width: 64
                    height: 36
                    radius: 6
                    color: Qt.darker(root.themeCardBg, 1.3)
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        Text { text: "SCORE"; font.pixelSize: 7; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.score.toString(); font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Moves Card
                Rectangle {
                    width: 58
                    height: 36
                    radius: 6
                    color: Qt.darker(root.themeCardBg, 1.3)
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        Text { text: "MOVES"; font.pixelSize: 7; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.moves.toString(); font.pixelSize: 12; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Timer Card
                Rectangle {
                    width: 64
                    height: 36
                    radius: 6
                    color: Qt.darker(root.themeCardBg, 1.3)
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        Text { text: "TIME"; font.pixelSize: 7; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.formatTimer(root.elapsedTime); font.pixelSize: 11; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // Right: Toolbar Action Buttons
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                readonly property bool isCrowded: root.width < 760

                // Draw Mode Toggle Button
                Rectangle {
                    width: parent.isCrowded ? 32 : 68
                    height: 32
                    radius: 6
                    color: drawMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.isCrowded ? "🃏" : "Draw " + (root.drawCount === 1 ? "3" : "1")
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: drawMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleDrawCount()
                    }
                }

                // Deck Style Switcher
                Rectangle {
                    width: parent.isCrowded ? 32 : 56
                    height: 32
                    radius: 6
                    color: deckMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.isCrowded ? "🎨" : "Deck"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: deckMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleDeckStyle()
                    }
                }

                // Hint Button
                Rectangle {
                    width: parent.isCrowded ? 32 : 56
                    height: 32
                    radius: 6
                    color: hintMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.isCrowded ? "💡" : "Hint (H)"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: hintMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerHint()
                    }
                }

                // Undo Button
                Rectangle {
                    width: parent.isCrowded ? 32 : 60
                    height: 32
                    radius: 6
                    color: undoMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.isCrowded ? "↩️" : "Undo (U)"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: undoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.undoMove()
                    }
                }

                // Sound Toggle
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: soundMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: soundMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // New Game Button
                Rectangle {
                    width: parent.isCrowded ? 32 : 82
                    height: 32
                    radius: 6
                    color: newGameMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.isCrowded ? "⚡" : "New Game"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeBtnFg
                    }

                    MouseArea {
                        id: newGameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame()
                    }
                }

                // Help Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: helpBtnMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.25) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeFg
                    }

                    MouseArea {
                        id: helpBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }
            }
        }

        // =====================================================================
        // GAME TABLE FELT PLAYING AREA
        // =====================================================================
        Item {
            id: tableFelt
            anchors.top: headerItem.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14

            // 7 perfectly aligned tracks
            readonly property real cardWidth: Math.max(68, Math.min(100, (width - 70) / 7.6))
            readonly property real cardHeight: Math.round(cardWidth * 1.42)
            readonly property real colSpacing: Math.max(8, Math.min(16, (width - (cardWidth * 7)) / 8))
            readonly property real startX: Math.round((width - (cardWidth * 7 + colSpacing * 6)) / 2)

            function getColX(idx) {
                return startX + idx * (cardWidth + colSpacing);
            }

            // -----------------------------------------------------------------
            // UPPER ROW: STOCK (0), WASTE (1), [GAP 2], FOUNDATIONS (3, 4, 5, 6)
            // -----------------------------------------------------------------
            Item {
                id: upperRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: tableFelt.cardHeight + 10

                // STOCK PILE (Aligned with Col 0)
                Rectangle {
                    id: stockSlot
                    x: tableFelt.getColX(0)
                    width: tableFelt.cardWidth
                    height: tableFelt.cardHeight
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "🔄"
                        font.pixelSize: 22
                        opacity: (root.gameStateData && root.gameStateData.stock.length === 0) ? 0.6 : 0
                    }

                    PlayingCard {
                        anchors.fill: parent
                        deckStyle: root.deckStyle
                        faceUp: false
                        visible: root.gameStateData && root.gameStateData.stock.length > 0
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 3
                        width: 20
                        height: 14
                        radius: 3
                        color: "#CC000000"
                        visible: root.gameStateData && root.gameStateData.stock.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: root.gameStateData ? root.gameStateData.stock.length.toString() : "0"
                            font.pixelSize: 9
                            font.bold: true
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleStockClicked()
                    }
                }

                // WASTE PILE (Aligned with Col 1)
                Item {
                    id: wasteSlot
                    x: tableFelt.getColX(1)
                    width: tableFelt.cardWidth
                    height: tableFelt.cardHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.20)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1.5
                    }

                    Repeater {
                        id: wasteRepeater
                        model: root.gameStateData ? root.gameStateData.waste.length : 0

                        PlayingCard {
                            readonly property var cData: (root.gameStateData && root.gameStateData.waste.length > index) ? root.gameStateData.waste[index] : null
                            cardData: cData
                            deckStyle: root.deckStyle
                            faceUp: true
                            width: tableFelt.cardWidth
                            height: tableFelt.cardHeight
                            isSelected: root.selectedCard && root.selectedCard.type === "waste" && (index === root.gameStateData.waste.length - 1)
                            visible: index === (root.gameStateData.waste.length - 1)
                            z: index

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.handleWasteClicked()
                            }
                        }
                    }
                }

                // 4 FOUNDATIONS (Aligned with Col 3, 4, 5, 6)
                Repeater {
                    id: foundationRepeater
                    model: 4

                    Item {
                        id: fSlot
                        x: tableFelt.getColX(3 + index)
                        width: tableFelt.cardWidth
                        height: tableFelt.cardHeight
                        readonly property var fPile: (root.gameStateData && root.gameStateData.foundations.length > index) ? root.gameStateData.foundations[index] : []
                        readonly property string defaultSuit: ["♠", "♥", "♦", "♣"][index]

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: fSlot.defaultSuit
                                font.pixelSize: 28
                                color: (index === 1 || index === 2) ? Qt.rgba(0.88, 0.11, 0.28, 0.25) : Qt.rgba(1, 1, 1, 0.15)
                                visible: fSlot.fPile.length === 0
                            }
                        }

                        PlayingCard {
                            anchors.fill: parent
                            readonly property var topC: fSlot.fPile.length > 0 ? fSlot.fPile[fSlot.fPile.length - 1] : null
                            cardData: topC
                            deckStyle: root.deckStyle
                            faceUp: true
                            visible: topC !== null
                            isSelected: root.selectedCard && root.selectedCard.type === "foundation" && root.selectedCard.col === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.handleFoundationClicked(index)
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // LOWER ROW: 7 TABLEAU CASCADES
            // -----------------------------------------------------------------
            Item {
                id: tableauArea
                anchors.top: upperRow.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    id: tableauRepeater
                    model: 7

                    Item {
                        id: colContainer
                        x: tableFelt.getColX(index)
                        width: tableFelt.cardWidth
                        height: tableauArea.height
                        readonly property int colIdx: index
                        readonly property var cards: (root.gameStateData && root.gameStateData.tableau.length > index) ? root.gameStateData.tableau[index] : []

                        Rectangle {
                            width: tableFelt.cardWidth
                            height: tableFelt.cardHeight
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.20)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "K"
                                font.pixelSize: 22
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: Qt.rgba(1, 1, 1, 0.15)
                                visible: colContainer.cards.length === 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.handleTableauClicked(colIdx, 0)
                            }
                        }

                        Repeater {
                            model: colContainer.cards.length

                            PlayingCard {
                                id: cascadeCard
                                readonly property var cData: (colContainer.cards.length > index) ? colContainer.cards[index] : null
                                cardData: cData
                                deckStyle: root.deckStyle
                                faceUp: cData ? (cData.faceUp === true) : false
                                width: tableFelt.cardWidth
                                height: tableFelt.cardHeight
                                isSelected: root.selectedCard && root.selectedCard.type === "tableau" && root.selectedCard.col === colIdx && root.selectedCard.index <= index

                                y: {
                                    var offset = 0;
                                    for (var i = 0; i < index; i++) {
                                        var prev = colContainer.cards[i];
                                        offset += prev.faceUp ? Math.min(28, Math.round(tableFelt.cardHeight * 0.22)) : Math.min(14, Math.round(tableFelt.cardHeight * 0.12));
                                    }
                                    return offset;
                                }
                                z: index

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleTableauClicked(colIdx, index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // NOTIFICATION TOAST
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: headerItem.bottom
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
                PauseAnimation { duration: 1100 }
                NumberAnimation { target: soundToast; property: "opacity"; from: 1; to: 0; duration: 250 }
            }
        }

        // =====================================================================
        // VICTORY OVERLAY
        // =====================================================================
        Rectangle {
            id: victoryOverlay
            anchors.fill: parent
            color: "#D9000000"
            visible: root.gameStatus === "won"
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNewGame()
            }

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "VICTORY!"
                    color: root.themeSecondary
                    font.pixelSize: 34
                    font.bold: true
                    font.family: root.monoFontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Classic Solitaire Conquered!"
                    color: root.themeFg
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 24
                    anchors.horizontalCenter: parent.horizontalCenter

                    Column {
                        Text { text: "SCORE"; font.pixelSize: 9; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.score.toString(); font.pixelSize: 18; font.bold: true; color: root.themeAccent; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    Column {
                        Text { text: "MOVES"; font.pixelSize: 9; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.moves.toString(); font.pixelSize: 18; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    Column {
                        Text { text: "TIME"; font.pixelSize: 9; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.formatTimer(root.elapsedTime); font.pixelSize: 18; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                Rectangle {
                    width: 150
                    height: 42
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
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

        // =====================================================================
        // HELP MODAL
        // =====================================================================
        Rectangle {
            id: helpOverlay
            anchors.fill: parent
            color: "#CC000000"
            visible: root.showHelp
            z: 960

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                width: Math.min(480, parent.width - 32)
                height: helpCol.implicitHeight + 40
                anchors.centerIn: parent
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1.5

                MouseArea { anchors.fill: parent }

                Column {
                    id: helpCol
                    anchors.centerIn: parent
                    width: parent.width - 36
                    spacing: 12

                    Row {
                        width: parent.width
                        Text {
                            text: "KLONDIKE SOLITAIRE GUIDE"
                            font.pixelSize: 14
                            font.bold: true
                            color: root.themeAccent
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.helpText
                        font.pixelSize: 11
                        font.family: root.monoFontFamily
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                        color: root.themeFg
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90
                        height: 30
                        radius: 6
                        color: root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "GOT IT"
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
                }
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
