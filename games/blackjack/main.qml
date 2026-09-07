import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 780
    height: 620
    minimumWidth: 500
    minimumHeight: 480
    title: "Blackjack 21"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#0F281E" // Rich casino felt
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeGold: "#FACC15"
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
    property string gameState: "betting" // "betting", "dealing", "playing", "dealer_turn", "round_over"
    property int bankroll: 1000
    property int currentBet: 25
    property int lastBet: 25
    property int score: bankroll
    property int bestScore: 1000

    property var shoe: []
    property var dealerCards: []
    property var playerCards: []

    property bool isSplit: false
    property var splitHands: [] // [ [card1, card...], [card2, card...] ]
    property int activeSplitIndex: 0 // 0 or 1
    property int splitBet: 0
    readonly property bool canSplitHand: (root.gameState === "playing" && !root.isSplit && root.playerCards.length === 2 && Engine.canSplit(root.playerCards) && root.bankroll >= root.currentBet)

    property string roundOutcome: "" // "win", "dealer", "push", "blackjack", "bust"
    property string statusMessage: "Place your bet and press DEAL"

    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• OBJECTIVE: Beat the dealer's total without exceeding 21.\n\n• CONTROLS:\n  - Space / Enter: Deal Hand\n  - H / Space: Hit (Take another card)\n  - S / Enter: Stand (Keep current total)\n  - D: Double Down (Double bet & take 1 final card)\n  - P: Split Pair (Separate identical cards into 2 hands)\n  - 1 / 2 / 3 / 4: Bet $5 / $25 / $100 / $500\n  - C: Clear Bet  |  X: Double Bet (2x)\n  - M: Toggle Sound  |  R: Re-deal Hand\n  - ? / Esc: Rules & Help\n\n• RULES:\n  - 6-Deck continuous casino shoe.\n  - Dealer stands on soft & hard 17.\n  - Natural Blackjack pays 3 to 2.\n  - Pairs can be Split into two independent hands."

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
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            if (typeof soundManager.playSound === "function") {
                soundManager.playSound(name);
            } else if (typeof soundManager.play === "function") {
                soundManager.play(name);
            }
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("click");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
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

    // =========================================================================
    // PERSISTENCE & SHOE INITIALIZATION
    // =========================================================================
    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            var savedBank = settingsManager.getBankroll();
            if (savedBank && savedBank > 0) {
                root.bankroll = savedBank;
            }
            var savedBest = settingsManager.getBestScore();
            if (savedBest && savedBest > root.bankroll) {
                root.bestScore = savedBest;
            } else {
                root.bestScore = root.bankroll;
            }
        }
        initShoe();
    }

    function saveBankroll() {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setBankroll(root.bankroll);
            if (root.bankroll > root.bestScore) {
                root.bestScore = root.bankroll;
                settingsManager.setBestScore(root.bestScore);
            }
        }
        root.score = root.bankroll;
    }

    function initShoe() {
        root.shoe = Engine.createShoe(6);
    }

    function drawCard(faceUp) {
        if (root.shoe.length < 52) {
            initShoe();
            soundToast.show("🔀 Reshuffling 6-Deck Shoe");
        }
        var c = root.shoe.pop();
        c.faceUp = (faceUp !== false);
        return c;
    }

    // =========================================================================
    // BETTING & CHIP ACTIONS
    // =========================================================================
    function addChip(amount) {
        if (root.gameState !== "betting" && root.gameState !== "round_over") return;
        if (root.gameState === "round_over") {
            root.gameState = "betting";
            root.playerCards = [];
            root.dealerCards = [];
            root.roundOutcome = "";
        }
        if (root.bankroll >= amount) {
            root.currentBet += amount;
            root.bankroll -= amount;
            root.lastBet = root.currentBet;
            saveBankroll();
            playSound("chip");
        } else {
            soundToast.show("Insufficient bankroll");
            playSound("bust");
        }
    }

    function clearBet() {
        if (root.gameState !== "betting" && root.gameState !== "round_over") return;
        if (root.currentBet > 0) {
            root.bankroll += root.currentBet;
            root.currentBet = 0;
            saveBankroll();
            playSound("chip");
        }
    }

    function doubleBet() {
        if (root.gameState !== "betting" && root.gameState !== "round_over") return;
        if (root.currentBet <= 0) return;
        if (root.bankroll >= root.currentBet) {
            root.bankroll -= root.currentBet;
            root.currentBet *= 2;
            root.lastBet = root.currentBet;
            saveBankroll();
            playSound("chip");
        } else {
            soundToast.show("Insufficient bankroll to 2x");
        }
    }

    // =========================================================================
    // GAMEPLAY ROUND LIFECYCLE
    // =========================================================================
    function dealHand() {
        if (root.gameState !== "betting" && root.gameState !== "round_over") return;
        if (root.currentBet <= 0) {
            if (root.lastBet > 0 && root.bankroll >= root.lastBet) {
                root.currentBet = root.lastBet;
                root.bankroll -= root.currentBet;
                saveBankroll();
            } else if (root.bankroll >= 25) {
                root.currentBet = 25;
                root.bankroll -= 25;
                saveBankroll();
            } else {
                soundToast.show("Place a bet first");
                return;
            }
        }

        root.gameState = "dealing";
        root.roundOutcome = "";
        root.playerCards = [];
        root.dealerCards = [];
        root.isSplit = false;
        root.splitHands = [];
        root.activeSplitIndex = 0;
        root.splitBet = 0;
        root.statusMessage = "Dealing cards...";

        // Staggered dealing sequence
        dealTimer1.restart();
    }

    Timer {
        id: dealTimer1
        interval: 180
        repeat: false
        onTriggered: {
            root.playerCards = [root.drawCard(true)];
            root.playSound("card_slide");
            dealTimer2.restart();
        }
    }

    Timer {
        id: dealTimer2
        interval: 180
        repeat: false
        onTriggered: {
            root.dealerCards = [root.drawCard(true)];
            root.playSound("card_slide");
            dealTimer3.restart();
        }
    }

    Timer {
        id: dealTimer3
        interval: 180
        repeat: false
        onTriggered: {
            var pArr = root.playerCards.slice();
            pArr.push(root.drawCard(true));
            root.playerCards = pArr;
            root.playSound("card_slide");
            dealTimer4.restart();
        }
    }

    Timer {
        id: dealTimer4
        interval: 180
        repeat: false
        onTriggered: {
            var dArr = root.dealerCards.slice();
            dArr.push(root.drawCard(false)); // Hole card face-down
            root.dealerCards = dArr;
            root.playSound("card_slide");

            // Evaluate initial naturals
            checkInitialDeal();
        }
    }

    function checkInitialDeal() {
        var pEval = Engine.calculateHand(root.playerCards);
        var dEvalFull = Engine.calculateHand([
            root.dealerCards[0],
            { value: root.dealerCards[1].value, suit: root.dealerCards[1].suit, faceUp: true }
        ]);

        if (pEval.isBlackjack) {
            revealHoleCard();
            if (dEvalFull.isBlackjack) {
                settleRound("push", "Both have Blackjack! Push (Tie).");
            } else {
                settleRound("blackjack", "BLACKJACK! Pays 3:2!");
            }
        } else {
            root.gameState = "playing";
            if (root.canSplitHand) {
                root.statusMessage = "Pair dealt! Hit, Stand, Double, or Split (P)";
            } else {
                root.statusMessage = "Hit or Stand?";
            }
        }
    }

    function splitHand() {
        if (!root.canSplitHand) return;
        root.bankroll -= root.currentBet;
        root.splitBet = root.currentBet;
        saveBankroll();
        playSound("chip");

        root.isSplit = true;
        var c1 = root.playerCards[0];
        var c2 = root.playerCards[1];
        var newCard1 = root.drawCard(true);
        var newCard2 = root.drawCard(true);
        root.splitHands = [
            [c1, newCard1],
            [c2, newCard2]
        ];
        root.activeSplitIndex = 0;
        root.statusMessage = "Playing Hand 1: Hit or Stand?";
        playSound("card_slide");
    }

    function hit() {
        if (root.gameState !== "playing") return;
        if (!root.isSplit) {
            var pArr = root.playerCards.slice();
            pArr.push(root.drawCard(true));
            root.playerCards = pArr;
            root.playSound("card_slide");

            var evalRes = Engine.calculateHand(root.playerCards);
            if (evalRes.isBust) {
                revealHoleCard();
                settleRound("bust", "Bust! Over 21.");
            } else if (evalRes.total === 21) {
                stand();
            }
        } else {
            var hands = root.splitHands.slice();
            var curHand = hands[root.activeSplitIndex].slice();
            curHand.push(root.drawCard(true));
            hands[root.activeSplitIndex] = curHand;
            root.splitHands = hands;
            root.playSound("card_slide");

            var evalHand = Engine.calculateHand(curHand);
            if (evalHand.isBust) {
                soundToast.show("Hand " + (root.activeSplitIndex + 1) + " Busts (" + evalHand.total + ")!");
                advanceSplitHand();
            } else if (evalHand.total === 21) {
                advanceSplitHand();
            }
        }
    }

    function doubleDown() {
        if (root.gameState !== "playing") return;
        if (!root.isSplit) {
            if (root.playerCards.length !== 2) return;
            if (root.bankroll < root.currentBet) {
                soundToast.show("Insufficient bankroll to double");
                return;
            }

            root.bankroll -= root.currentBet;
            root.currentBet *= 2;
            saveBankroll();
            playSound("chip");

            var pArr = root.playerCards.slice();
            pArr.push(root.drawCard(true));
            root.playerCards = pArr;
            root.playSound("card_slide");

            var evalRes = Engine.calculateHand(root.playerCards);
            if (evalRes.isBust) {
                revealHoleCard();
                settleRound("bust", "Bust on Double! Over 21.");
            } else {
                stand();
            }
        } else {
            var hands = root.splitHands.slice();
            var curHand = hands[root.activeSplitIndex].slice();
            if (curHand.length !== 2) return;
            var betToDouble = (root.activeSplitIndex === 0) ? root.currentBet : root.splitBet;
            if (root.bankroll < betToDouble) {
                soundToast.show("Insufficient bankroll to double");
                return;
            }

            root.bankroll -= betToDouble;
            if (root.activeSplitIndex === 0) root.currentBet *= 2;
            else root.splitBet *= 2;
            saveBankroll();
            playSound("chip");

            curHand.push(root.drawCard(true));
            hands[root.activeSplitIndex] = curHand;
            root.splitHands = hands;
            root.playSound("card_slide");

            advanceSplitHand();
        }
    }

    function stand() {
        if (root.gameState !== "playing") return;
        if (!root.isSplit) {
            startDealerTurn();
        } else {
            advanceSplitHand();
        }
    }

    function advanceSplitHand() {
        if (root.activeSplitIndex === 0) {
            root.activeSplitIndex = 1;
            root.statusMessage = "Playing Hand 2: Hit or Stand?";
            playSound("dock");
        } else {
            startDealerTurn();
        }
    }

    function startDealerTurn() {
        root.gameState = "dealer_turn";
        root.statusMessage = "Dealer's turn...";
        revealHoleCard();
        dealerStepTimer.restart();
    }

    function revealHoleCard() {
        if (root.dealerCards.length >= 2 && !root.dealerCards[1].faceUp) {
            var dArr = root.dealerCards.slice();
            dArr[1].faceUp = true;
            root.dealerCards = dArr;
            root.playSound("card_flip");
        }
    }

    Timer {
        id: dealerStepTimer
        interval: 420
        repeat: false
        onTriggered: {
            var dEval = Engine.calculateHand(root.dealerCards);
            if (Engine.dealerShouldHit(root.dealerCards)) {
                var dArr = root.dealerCards.slice();
                dArr.push(root.drawCard(true));
                root.dealerCards = dArr;
                root.playSound("card_slide");
                dealerStepTimer.restart();
            } else {
                evaluateFinalHands();
            }
        }
    }

    function evaluateFinalHands() {
        var dEval = Engine.calculateHand(root.dealerCards);

        if (!root.isSplit) {
            var pEval = Engine.calculateHand(root.playerCards);
            if (dEval.isBust) {
                settleRound("win", "Dealer Busts! You Win!");
            } else if (pEval.total > dEval.total) {
                settleRound("win", "You Win! " + pEval.total + " vs " + dEval.total);
            } else if (dEval.total > pEval.total) {
                settleRound("dealer", "Dealer Wins with " + dEval.total);
            } else {
                settleRound("push", "Push! Tie at " + pEval.total);
            }
        } else {
            var h1 = Engine.calculateHand(root.splitHands[0]);
            var h2 = Engine.calculateHand(root.splitHands[1]);
            var totalWinnings = 0;
            var results = [];

            // Hand 1 evaluation
            if (h1.isBust) {
                results.push("Hand 1: Bust (" + h1.total + ")");
            } else if (dEval.isBust || h1.total > dEval.total) {
                totalWinnings += root.currentBet * 2;
                results.push("Hand 1: Won (" + h1.total + " vs " + dEval.total + ")");
            } else if (h1.total === dEval.total) {
                totalWinnings += root.currentBet;
                results.push("Hand 1: Push (" + h1.total + ")");
            } else {
                results.push("Hand 1: Lost (" + h1.total + " vs " + dEval.total + ")");
            }

            // Hand 2 evaluation
            if (h2.isBust) {
                results.push("Hand 2: Bust (" + h2.total + ")");
            } else if (dEval.isBust || h2.total > dEval.total) {
                totalWinnings += root.splitBet * 2;
                results.push("Hand 2: Won (" + h2.total + " vs " + dEval.total + ")");
            } else if (h2.total === dEval.total) {
                totalWinnings += root.splitBet;
                results.push("Hand 2: Push (" + h2.total + ")");
            } else {
                results.push("Hand 2: Lost (" + h2.total + " vs " + dEval.total + ")");
            }

            root.bankroll += totalWinnings;
            saveBankroll();

            var totalBet = root.currentBet + root.splitBet;
            var net = totalWinnings - totalBet;
            var outcome = (net > 0) ? "win" : (net === 0 ? "push" : "dealer");
            var summaryMsg = results.join(" | ");

            root.gameState = "round_over";
            root.roundOutcome = outcome;
            root.statusMessage = summaryMsg;

            if (net > 0) {
                root.playSound("win");
                soundToast.show("🏆 WIN! +$" + net);
            } else if (net === 0) {
                root.playSound("dock");
                soundToast.show("🤝 PUSH (Even)");
            } else {
                root.playSound("bust");
                soundToast.show("❌ Lost -$" + Math.abs(net));
            }
        }
    }

    function settleRound(outcome, message) {
        root.gameState = "round_over";
        root.roundOutcome = outcome;
        root.statusMessage = message;

        if (outcome === "blackjack") {
            var bjWin = Math.floor(root.currentBet * 2.5); // 3:2 + original bet
            root.bankroll += bjWin;
            root.playSound("blackjack");
            soundToast.show("🎉 BLACKJACK! +" + (bjWin - root.currentBet));
        } else if (outcome === "win") {
            root.bankroll += (root.currentBet * 2);
            root.playSound("win");
            soundToast.show("🏆 WIN! +" + root.currentBet);
        } else if (outcome === "push") {
            root.bankroll += root.currentBet;
            root.playSound("dock");
            soundToast.show("🤝 PUSH (Bet Returned)");
        } else if (outcome === "bust" || outcome === "dealer") {
            root.playSound("bust");
            soundToast.show("❌ " + (outcome === "bust" ? "BUST!" : "DEALER WINS"));
        }

        saveBankroll();
    }

    // Helper evaluation values for UI badges
    readonly property var playerEvaluation: Engine.calculateHand(root.playerCards)
    readonly property var dealerEvaluation: Engine.calculateHand(root.dealerCards)

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD CONTROLLER
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

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            // Deal Hand: Space, Enter, Return, or R
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                if (root.gameState === "betting" || root.gameState === "round_over") {
                    root.dealHand();
                    event.accepted = true;
                    return;
                }
            }

            // Hit: H or Space (when playing)
            if (event.key === Qt.Key_H || (event.key === Qt.Key_Space && root.gameState === "playing")) {
                if (root.gameState === "playing") {
                    root.hit();
                    event.accepted = true;
                    return;
                }
            }

            // Stand: S or Enter (when playing)
            if (event.key === Qt.Key_S || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === "playing")) {
                if (root.gameState === "playing") {
                    root.stand();
                    event.accepted = true;
                    return;
                }
            }

            // Split: P
            if (event.key === Qt.Key_P && root.canSplitHand) {
                root.splitHand();
                event.accepted = true;
                return;
            }

            // Double: D
            if (event.key === Qt.Key_D && root.gameState === "playing") {
                if (!root.isSplit && root.playerCards.length === 2) {
                    root.doubleDown();
                    event.accepted = true;
                    return;
                } else if (root.isSplit && root.splitHands[root.activeSplitIndex] && root.splitHands[root.activeSplitIndex].length === 2) {
                    root.doubleDown();
                    event.accepted = true;
                    return;
                }
            }

            // Chips: 1 ($5), 2 ($25), 3 ($100), 4 ($500)
            if (event.key === Qt.Key_1) { root.addChip(5); event.accepted = true; }
            else if (event.key === Qt.Key_2) { root.addChip(25); event.accepted = true; }
            else if (event.key === Qt.Key_3) { root.addChip(100); event.accepted = true; }
            else if (event.key === Qt.Key_4) { root.addChip(500); event.accepted = true; }
            else if (event.key === Qt.Key_C) { root.clearBet(); event.accepted = true; }
            else if (event.key === Qt.Key_X) { root.doubleBet(); event.accepted = true; }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
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
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.title
                    font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Authentic Casino 21 • Omarchy Vector Decks"
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards on the right: BANK, BET, BEST
            Row {
                id: statsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // BANKROLL Card
                Rectangle {
                    width: Math.max(72, Math.min(94, headerItem.width * 0.16))
                    height: 48
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
                            text: "BANKROLL"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "$" + root.bankroll.toLocaleString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeGold
                        }
                    }
                }

                // BET Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.14))
                    height: 48
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
                            text: "BET"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "$" + root.currentBet.toLocaleString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
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
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 32

            readonly property bool isCrowded: subheaderItem.width < 540

            // Left cluster (Help pill button)
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    id: helpBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (helpRow.implicitWidth + 16)
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "?"
                            font.pixelSize: 12
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
            }

            // Right cluster (Actions: Mute, Deal / Re-deal)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Mute Button
                Rectangle {
                    id: muteBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (muteRow.implicitWidth + 16)
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 12
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

                // Deal / Re-deal Button
                Rectangle {
                    id: dealActionBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (dealRow.implicitWidth + 18)
                    radius: 6
                    color: dealMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: dealRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "♠"
                            font.pixelSize: 12
                            visible: subheaderItem.isCrowded
                            color: root.themeBtnFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (root.gameState === "playing" || root.gameState === "dealer_turn") ? "Playing..." : "Deal Hand (Space)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            visible: !subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dealMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: (root.gameState === "betting" || root.gameState === "round_over")
                        onClicked: root.dealHand()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER (Casino Felt Table)
        // =====================================================================
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1.5
                radius: 12
                clip: true

                // Casino felt damask pattern featuring Omarchy square emblem
                Image {
                    anchors.fill: parent
                    source: "assets/felt-pattern.svg"
                    fillMode: Image.Tile
                    sourceSize: Qt.size(80, 80)
                    opacity: 0.075
                    smooth: true
                }

                // Subtle casino felt vignette shadow
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: "#30000000"
                    border.width: 6
                }

                // Center Watermark: Omarchy Retro Wordmark + Table Rules
                Item {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: 120
                    opacity: 0.28

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        source: "assets/omarchy-wordmark.svg"
                        width: Math.min(parent.width * 0.6, 280)
                        height: 52
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Column {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Text {
                            text: "BLACKJACK PAYS 3 TO 2"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeGold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "DEALER STANDS ON 17 AND DRAWS TO 16"
                            font.family: root.monoFontFamily
                            font.pixelSize: 9
                            color: "#A7F3D0"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // =============================================================
                // DEALER SECTION
                // =============================================================
                Item {
                    id: dealerArea
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(300, dealerHandRow.width + 40)
                    height: 160

                    // Dealer Badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 22
                        width: dealerBadgeRow.implicitWidth + 14
                        radius: 11
                        color: Qt.rgba(0, 0, 0, 0.45)
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            id: dealerBadgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "DEALER"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.dealerCards.length > 0 ? root.dealerEvaluation.label : "—"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.dealerEvaluation.isBust ? "#EF4444" : root.themeGold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Dealer Cards Row (Smooth overlapping fan layout)
                    Row {
                        id: dealerHandRow
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: -24

                        Repeater {
                            model: root.dealerCards
                            PlayingCard {
                                cardData: modelData
                                faceUp: modelData ? (modelData.faceUp !== false) : true
                                isWinning: root.roundOutcome === "dealer"
                            }
                        }
                    }
                }

                // =============================================================
                // PLAYER SECTION
                // =============================================================
                Item {
                    id: playerArea
                    anchors.bottom: controlsRow.top
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.isSplit ? Math.min(parent.width - 32, 540) : Math.max(300, playerHandRow.width + 40)
                    height: 160

                    // Single Player Hand (when not split)
                    Item {
                        anchors.fill: parent
                        visible: !root.isSplit

                        Row {
                            id: playerHandRow
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -24

                            Repeater {
                                model: root.playerCards
                                PlayingCard {
                                    cardData: modelData
                                    faceUp: true
                                    isWinning: root.roundOutcome === "win" || root.roundOutcome === "blackjack"
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 22
                            width: playerBadgeRow.implicitWidth + 14
                            radius: 11
                            color: Qt.rgba(0, 0, 0, 0.45)
                            border.color: root.themeBorder
                            border.width: 1

                            Row {
                                id: playerBadgeRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "PLAYER"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.themeSubtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.playerCards.length > 0 ? root.playerEvaluation.label : "—"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: root.playerEvaluation.isBust ? "#EF4444" : (root.playerEvaluation.isBlackjack ? root.themeGold : root.themeAccent)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Split Hands Row (when split into 2 hands)
                    Row {
                        anchors.fill: parent
                        visible: root.isSplit
                        spacing: 24

                        // HAND 1
                        Item {
                            width: (parent.width - 24) / 2
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: 8
                                color: "transparent"
                                border.color: root.themeGold
                                border.width: (root.activeSplitIndex === 0 && root.gameState === "playing") ? 2 : 0
                                opacity: (root.activeSplitIndex === 0 && root.gameState === "playing") ? 0.9 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Row {
                                id: h1Row
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: -24
                                Repeater {
                                    model: (root.splitHands.length > 0) ? root.splitHands[0] : []
                                    PlayingCard {
                                        cardData: modelData
                                        faceUp: true
                                        isWinning: root.roundOutcome === "win"
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 22
                                width: h1Badge.implicitWidth + 14
                                radius: 11
                                color: (root.activeSplitIndex === 0 && root.gameState === "playing") ? Qt.rgba(0.98, 0.8, 0.08, 0.25) : Qt.rgba(0, 0, 0, 0.45)
                                border.color: (root.activeSplitIndex === 0 && root.gameState === "playing") ? root.themeGold : root.themeBorder
                                border.width: 1

                                Row {
                                    id: h1Badge
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "HAND 1"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: (root.activeSplitIndex === 0 && root.gameState === "playing") ? root.themeGold : root.themeSubtext
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.splitHands.length > 0 ? Engine.calculateHand(root.splitHands[0]).label : "—"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.themeGold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // HAND 2
                        Item {
                            width: (parent.width - 24) / 2
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: 8
                                color: "transparent"
                                border.color: root.themeGold
                                border.width: (root.activeSplitIndex === 1 && root.gameState === "playing") ? 2 : 0
                                opacity: (root.activeSplitIndex === 1 && root.gameState === "playing") ? 0.9 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Row {
                                id: h2Row
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: -24
                                Repeater {
                                    model: (root.splitHands.length > 1) ? root.splitHands[1] : []
                                    PlayingCard {
                                        cardData: modelData
                                        faceUp: true
                                        isWinning: root.roundOutcome === "win"
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 22
                                width: h2Badge.implicitWidth + 14
                                radius: 11
                                color: (root.activeSplitIndex === 1 && root.gameState === "playing") ? Qt.rgba(0.98, 0.8, 0.08, 0.25) : Qt.rgba(0, 0, 0, 0.45)
                                border.color: (root.activeSplitIndex === 1 && root.gameState === "playing") ? root.themeGold : root.themeBorder
                                border.width: 1

                                Row {
                                    id: h2Badge
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "HAND 2"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: (root.activeSplitIndex === 1 && root.gameState === "playing") ? root.themeGold : root.themeSubtext
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.splitHands.length > 1 ? Engine.calculateHand(root.splitHands[1]).label : "—"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.themeGold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Status Message Banner (floating pill)
                Rectangle {
                    anchors.centerIn: parent
                    height: 28
                    width: statusText.implicitWidth + 24
                    radius: 14
                    color: Qt.rgba(0, 0, 0, 0.75)
                    border.color: root.roundOutcome === "win" || root.roundOutcome === "blackjack" ? root.themeGold : (root.roundOutcome === "bust" || root.roundOutcome === "dealer" ? "#EF4444" : root.themeBorder)
                    border.width: 1
                    visible: root.statusMessage.length > 0

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.statusMessage
                        font.pixelSize: 11
                        font.bold: true
                        color: root.roundOutcome === "win" || root.roundOutcome === "blackjack" ? root.themeGold : (root.roundOutcome === "bust" || root.roundOutcome === "dealer" ? "#FCA5A5" : root.themeFg)
                    }
                }

                // =============================================================
                // BOTTOM CONTROL STRIP: CHIP TRAY & GAMEPLAY ACTIONS
                // =============================================================
                Rectangle {
                    id: controlsRow
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 60
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.color: root.themeBorder
                    border.width: 1

                    // Left side: Chips ($5, $25, $100, $500) + Clear + 2x
                    Row {
                        id: chipsRow
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Helper chip component
                        component ChipItem: Rectangle {
                            id: cItem
                            property int chipValue: 5
                            property color chipColor: "#E2E8F0"
                            property color textColor: "#0F172A"
                            property string keyLabel: "1"

                            width: 38
                            height: 38
                            radius: 19
                            color: chipColor
                            border.color: Qt.lighter(chipColor, 1.3)
                            border.width: 2
                            scale: cMouse.pressed ? 0.92 : (cMouse.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: -1
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "$" + cItem.chipValue
                                    font.pixelSize: cItem.chipValue >= 100 ? 9 : 10
                                    font.bold: true
                                    color: cItem.textColor
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "[" + cItem.keyLabel + "]"
                                    font.pixelSize: 7
                                    color: Qt.rgba(cItem.textColor.r, cItem.textColor.g, cItem.textColor.b, 0.6)
                                }
                            }

                            MouseArea {
                                id: cMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addChip(cItem.chipValue)
                            }
                        }

                        ChipItem { chipValue: 5; chipColor: "#F1F5F9"; textColor: "#0F172A"; keyLabel: "1" }
                        ChipItem { chipValue: 25; chipColor: "#22C55E"; textColor: "#FFFFFF"; keyLabel: "2" }
                        ChipItem { chipValue: 100; chipColor: "#1E293B"; textColor: "#FFFFFF"; keyLabel: "3" }
                        ChipItem { chipValue: 500; chipColor: "#A855F7"; textColor: "#FFFFFF"; keyLabel: "4" }

                        // Clear Bet Button (C)
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: clrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "CLR"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.themeSubtext
                            }
                            MouseArea {
                                id: clrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearBet()
                            }
                        }

                        // 2x Bet Button (X)
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: dblBetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "2X"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.themeGold
                            }
                            MouseArea {
                                id: dblBetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.doubleBet()
                            }
                        }
                    }

                    // Right side: Game Actions (HIT, STAND, DOUBLE, DEAL)
                    Row {
                        id: actionsRow
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Helper Action Button with guaranteed padding and high-contrast shortcut pill
                        component ActionBtn: Rectangle {
                            id: abRoot
                            property string btnLabel: ""
                            property string shortcutKey: ""
                            property color btnColor: root.themeAccent
                            property color fgColor: root.themeBtnFg
                            property bool isPrimary: false
                            signal triggered()

                            width: Math.max(86, btnRow.implicitWidth + 24)
                            height: 38
                            radius: 8
                            color: enabled ? (abMouse.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor) : Qt.rgba(0.2, 0.2, 0.2, 0.5)
                            border.color: enabled ? (isPrimary ? Qt.lighter(btnColor, 1.3) : root.themeBorder) : Qt.rgba(0.3, 0.3, 0.3, 0.3)
                            border.width: 1
                            scale: abMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }

                            Row {
                                id: btnRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    id: abText
                                    text: abRoot.btnLabel
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: abRoot.enabled ? abRoot.fgColor : "#64748B"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    visible: abRoot.shortcutKey.length > 0
                                    height: 18
                                    width: scText.implicitWidth + 8
                                    radius: 4
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: Qt.rgba(255, 255, 255, 0.2)
                                    border.width: 0.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        id: scText
                                        anchors.centerIn: parent
                                        text: abRoot.shortcutKey
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: abRoot.enabled ? "#FFFFFF" : "#64748B"
                                    }
                                }
                            }

                            MouseArea {
                                id: abMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: abRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (abRoot.enabled) abRoot.triggered()
                            }
                        }

                        // DEAL BUTTON (Active during betting or round over)
                        ActionBtn {
                            btnLabel: "DEAL"
                            shortcutKey: "Space"
                            btnColor: "#15803D" // Deep emerald casino green with clean white contrast
                            fgColor: "#FFFFFF"
                            isPrimary: true
                            enabled: (root.gameState === "betting" || root.gameState === "round_over")
                            visible: (root.gameState === "betting" || root.gameState === "round_over")
                            onTriggered: root.dealHand()
                        }

                        // SPLIT BUTTON (Active when pair dealt and bankroll permits)
                        ActionBtn {
                            btnLabel: "SPLIT"
                            shortcutKey: "P"
                            btnColor: "#D97706" // Warm amber gold
                            fgColor: "#FFFFFF"
                            isPrimary: true
                            enabled: root.canSplitHand
                            visible: root.canSplitHand
                            onTriggered: root.splitHand()
                        }

                        // DOUBLE BUTTON (Active when 2 cards dealt and bankroll permits)
                        ActionBtn {
                            btnLabel: "DOUBLE"
                            shortcutKey: "D"
                            btnColor: root.themeCardBg
                            fgColor: root.themeGold
                            enabled: Boolean(root.gameState === "playing" && (
                                (!root.isSplit && root.playerCards && root.playerCards.length === 2 && root.bankroll >= root.currentBet) ||
                                (root.isSplit && root.splitHands && root.activeSplitIndex < root.splitHands.length && root.splitHands[root.activeSplitIndex] && root.splitHands[root.activeSplitIndex].length === 2 && root.bankroll >= root.currentBet)
                            ))
                            visible: (root.gameState === "playing")
                            onTriggered: root.doubleDown()
                        }

                        // HIT BUTTON
                        ActionBtn {
                            btnLabel: "HIT"
                            shortcutKey: "H"
                            btnColor: root.themeAccent
                            fgColor: root.themeBtnFg
                            isPrimary: true
                            enabled: (root.gameState === "playing")
                            visible: (root.gameState === "playing")
                            onTriggered: root.hit()
                        }

                        // STAND BUTTON
                        ActionBtn {
                            btnLabel: "STAND"
                            shortcutKey: "S"
                            btnColor: "#DC2626"
                            fgColor: "#FFFFFF"
                            enabled: (root.gameState === "playing")
                            visible: (root.gameState === "playing")
                            onTriggered: root.stand()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Sound Toast)
        // =====================================================================
        // Help Modal (Standard Omarchy Arcade template)
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
                width: Math.min(parent.width * 0.88, 420)
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
                        text: "HOW TO PLAY BLACKJACK"
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

        // Sound & Notification Toast (Standard Omarchy Arcade template)
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
                PauseAnimation { duration: 1200 }
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
