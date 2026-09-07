import QtQuick
import QtQuick.Controls
import "TerminalEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 480
    height: 640
    minimumWidth: 320
    minimumHeight: 400
    title: "Video Poker"

    // =========================================================================
    // COLOR PALETTE TOKENS (From Master Template & Theme Controller)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#00F0FF" // Neon Cyan standard
    property color themeBtnBg: "#00F0FF"
    property color themeBtnFg: "#050811"

    // Visual Mode: "cyber" (Dark Futuristic Neon) vs "crt" (Classic 1984 Vegas Cobalt Blue)
    property string visualMode: "cyber"
    readonly property bool isCrtMode: visualMode === "crt"
    readonly property bool isCyberMode: visualMode === "cyber"

    // High-contrast Neon Accent Colors
    readonly property color neonCyan: "#00F0FF"
    readonly property color neonMagenta: "#FF007F"
    readonly property color neonPurple: "#A855F7"
    readonly property color neonAmber: "#FACC15"
    readonly property color cyberObsidian: "#050811"

    function colorLuminance(c) {
        var col = Qt.color(c);
        return 0.299 * col.r + 0.587 * col.g + 0.114 * col.b;
    }

    // =========================================================================
    // AUDIO & APPLICATION PROPERTIES
    // =========================================================================
    property bool isMuted: true
    property bool splashEnabled: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"

    // Machine Credits & Bets
    property int credits: 1000
    property int betCoins: 1 // 1..5
    property int lastWinAmount: 0
    property int bestScore: 0
    property int handsPlayed: 0

    // Master Game State: "IDLE", "DEALT", "DRAWING", "ROUND_OVER"
    property string machineState: "IDLE"
    property string statusMessage: "INSERT COIN OR PRESS DEAL TO PLAY"
    property string activeGameId: "jacks_or_better"
    onActiveGameIdChanged: setupGame(activeGameId)

    // Active Deck & Hands
    property var activeDeck: []
    property var playerHand: []
    property var dealerHand: []
    property var winningEvaluation: null
    property bool isWinningRound: false
    property var winningCardIndices: (isWinningRound && winningEvaluation && root.isPokerGame) ? Engine.getWinningCardIndices(activeGameId, winningEvaluation.key, playerHand) : []

    // Table Game States
    property int redDogSpread: 0
    property string redDogStatus: ""
    property int playerTotal: 0
    property int dealerTotal: 0
    property bool playerCanDouble: false
    property string warState: ""

    // Double-Up Gamble
    property bool doubleUpActive: false
    property var doubleUpDealerCard: null
    property var doubleUpPlayerCards: []
    property int doubleUpCurrentPot: 0
    property string doubleUpMessage: ""
    property bool doubleUpResolved: false

    // Modals
    property bool gameMenuOpen: false

    // =========================================================================
    // THEME CONTROLLER (From Master Template)
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#00F0FF";
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
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("select");
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
    // INITIALIZATION & SETTINGS
    // =========================================================================
    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            credits = settingsManager.getCredits();
            bestScore = settingsManager.getBestScore();
            handsPlayed = settingsManager.getHandsPlayed();
            var savedGame = settingsManager.getGameMode();
            if (savedGame) activeGameId = savedGame;
            var savedMode = settingsManager.getVisualMode();
            if (savedMode) visualMode = savedMode;
        }
        setupGame(activeGameId);
    }

    function saveSettings() {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setCredits(credits);
            settingsManager.setBestScore(bestScore);
            settingsManager.setHandsPlayed(handsPlayed);
            settingsManager.setGameMode(activeGameId);
            settingsManager.setVisualMode(visualMode);
        }
    }

    // =========================================================================
    // GAME REGISTRY METADATA
    // =========================================================================
    readonly property var gameList: [
        { id: "jacks_or_better", name: "JACKS OR BETTER", type: "poker", desc: "9/6 Full Pay Classic. Pair of Jacks pays." },
        { id: "deuces_wild", name: "DEUCES WILD", type: "poker", desc: "All 2s are Wild! Natural Royal pays 800x, 4 Deuces pays 200x." },
        { id: "joker_poker", name: "JOKER POKER", type: "poker", desc: "53-Card Deck with 1 Joker. Kings or Better minimum pay." },
        { id: "double_double_bonus", name: "DOUBLE DOUBLE BONUS", type: "poker", desc: "High-octane Four-of-a-Kind bonus kickers up to 400x." },
        { id: "bonus_poker_deluxe", name: "BONUS POKER DELUXE", type: "poker", desc: "Flat 80:1 jackpot bonus on ANY Four of a Kind." },
        { id: "red_dog", name: "RED DOG", type: "table", desc: "High-spread card betting. In-between spread pays up to 5:1." },
        { id: "blackjack", name: "SINGLE-DECK BLACKJACK", type: "table", desc: "Classic 3:2 Vegas strip blackjack. Dealer stands on 17." },
        { id: "casino_war", name: "CASINO WAR", type: "table", desc: "Direct high-card duel against the house. Aces high." }
    ]

    readonly property var activeGameObj: {
        for (var i = 0; i < gameList.length; i++) {
            if (gameList[i].id === activeGameId) return gameList[i];
        }
        return gameList[0];
    }

    readonly property bool isPokerGame: activeGameObj.type === "poker"

    // =========================================================================
    // GAME ENGINE & DISPATCH CONTROLLERS
    // =========================================================================
    function resetPaytableScroll() {
        if (typeof paytableFlickable !== "undefined" && paytableFlickable) {
            paytableFlickable.contentY = 0;
        }
    }

    function scrollToWinningRow() {
        if (typeof paytableFlickable === "undefined" || !paytableFlickable) return;
        if (!winningEvaluation || !root.isPokerGame) return;
        var table = Engine.PAYTABLES[activeGameId];
        if (!table) return;

        var winIdx = -1;
        for (var i = 0; i < table.length; i++) {
            if (table[i].key === winningEvaluation.key) {
                winIdx = i;
                break;
            }
        }
        if (winIdx !== -1) {
            var rowH = 13; // 12px row height + 1px spacing
            var rowTop = winIdx * rowH;
            var rowBottom = rowTop + 12;
            var viewTop = paytableFlickable.contentY;
            var viewBottom = viewTop + paytableFlickable.height;
            var maxScroll = Math.max(0, paytableFlickable.contentHeight - paytableFlickable.height);

            if (rowTop < viewTop) {
                paytableFlickable.contentY = Math.max(0, rowTop - 2);
            } else if (rowBottom > viewBottom) {
                paytableFlickable.contentY = Math.min(maxScroll, rowBottom - paytableFlickable.height + 4);
            }
        }
    }

    function setupGame(gameId) {
        machineState = "IDLE";
        winningEvaluation = null;
        isWinningRound = false;
        doubleUpActive = false;
        dealerHand = [];
        playerTotal = 0;
        dealerTotal = 0;
        redDogSpread = 0;
        warState = "";
        resetPaytableScroll();

        if (gameId === "joker_poker") {
            activeDeck = Engine.createJokerDeck();
        } else {
            activeDeck = Engine.createStandardDeck();
        }

        // Initialize 5 face-down cards
        var idleCards = [];
        for (var i = 0; i < 5; i++) {
            idleCards.push({ value: "?", suit: "?", rank: 0, held: false, faceUp: false });
        }
        playerHand = idleCards;

        statusMessage = "INSERT COIN OR PRESS DEAL TO PLAY";
        saveSettings();
    }

    function switchGame(newGameId) {
        activeGameId = newGameId;
        gameMenuOpen = false;
        playSound("select");
    }

    function setMaxBet() {
        if (machineState === "DEALT" && isPokerGame) return;
        betCoins = 5;
        playSound("chip");
        handlePrimaryAction();
    }

    function increaseBet() {
        if (machineState === "DEALT" && isPokerGame) return;
        betCoins = (betCoins % 5) + 1;
        playSound("chip");
    }

    function toggleHold(index) {
        if (!isPokerGame || machineState !== "DEALT") return;
        if (index < 0 || index >= playerHand.length) return;

        var handCopy = playerHand.slice();
        handCopy[index].held = !handCopy[index].held;
        playerHand = handCopy;
        playSound("click");
    }

    function handlePrimaryAction() {
        if (doubleUpActive) return;

        if (isPokerGame) {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealPokerInitial();
            } else if (machineState === "DEALT") {
                drawPokerFinal();
            }
        } else if (activeGameId === "red_dog") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealRedDogInitial();
            }
        } else if (activeGameId === "blackjack") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealBlackjackInitial();
            }
        } else if (activeGameId === "casino_war") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealWarInitial();
            }
        }
    }

    // --- POKER DISPATCH ---
    function dealPokerInitial() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS! PRESS (C) TO ADD COINS";
            playSound("lose");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        winningEvaluation = null;
        isWinningRound = false;
        lastWinAmount = 0;
        resetPaytableScroll();

        // Fresh deck shuffle
        activeDeck = (activeGameId === "joker_poker") ? Engine.createJokerDeck() : Engine.createStandardDeck();
        Engine.shuffle(activeDeck);
        var dealt = [];
        for (var i = 0; i < 5; i++) {
            var c = activeDeck.pop();
            c.held = false;
            c.faceUp = true;
            dealt.push(c);
        }
        playerHand = dealt;
        machineState = "DEALT";
        playSound("deal");

        var preEval = evaluateHand(playerHand);
        if (preEval && preEval.winCoins > 0) {
            winningEvaluation = preEval;
            statusMessage = preEval.name + " DEALT - HOLD CARDS (1-5) & DRAW";
            scrollToWinningRow();
            var winCardIndices = Engine.getWinningCardIndices(activeGameId, preEval.key, playerHand);
            for (var h = 0; h < winCardIndices.length; h++) {
                var idx = winCardIndices[h];
                playerHand[idx].held = true;
            }
            playerHand = playerHand.slice();
        } else {
            statusMessage = "HOLD (1-5) OR PRESS DRAW";
        }
    }

    function drawPokerFinal() {
        machineState = "DRAWING";
        playSound("draw");

        var handCopy = playerHand.slice();
        for (var i = 0; i < 5; i++) {
            if (!handCopy[i].held) {
                var newCard = activeDeck.pop();
                newCard.held = false;
                newCard.faceUp = true;
                handCopy[i] = newCard;
            }
        }
        playerHand = handCopy;
        machineState = "ROUND_OVER";

        var result = evaluateHand(playerHand);
        winningEvaluation = result;

        if (result && result.winCoins > 0) {
            var winCoins = result.winCoins;
            credits += winCoins;
            lastWinAmount = winCoins;
            if (credits > bestScore) bestScore = credits;
            isWinningRound = true;

            statusMessage = result.name + " WINS " + winCoins + " CREDITS! [D] TO DOUBLE";
            if (result.key === "royal_flush" || result.key === "natural_royal") {
                playSound("jackpot");
            } else {
                playSound("win");
            }
            scrollToWinningRow();
        } else {
            isWinningRound = false;
            lastWinAmount = 0;
            statusMessage = "GAME OVER. PRESS DEAL TO PLAY AGAIN";
            playSound("lose");
        }
        saveSettings();
    }

    function evaluateHand(hand) {
        return Engine.evaluateHand(activeGameId, hand, betCoins);
    }

    // --- RED DOG DISPATCH ---
    function dealRedDogInitial() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS! PRESS (C) TO ADD COINS";
            playSound("lose");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        activeDeck = Engine.createStandardDeck();
        Engine.shuffle(activeDeck);
        var c1 = activeDeck.pop();
        var c2 = activeDeck.pop();
        c1.faceUp = true;
        c2.faceUp = true;

        var dogResult = Engine.initRedDogRound(c1, c2);
        redDogSpread = dogResult.spread;
        redDogStatus = dogResult.status;

        if (dogResult.status === "consecutive") {
            playerHand = [c1, c2];
            credits += betCoins; // Push
            machineState = "ROUND_OVER";
            statusMessage = "CONSECUTIVE CARDS! PUSH (BET RETURNED)";
            playSound("win");
        } else if (dogResult.status === "pair") {
            var c3 = activeDeck.pop();
            c3.faceUp = true;
            playerHand = [c1, c2, c3];
            machineState = "ROUND_OVER";
            if (c3.rank === c1.rank) {
                var pairWin = betCoins * 11 + betCoins;
                credits += pairWin;
                lastWinAmount = pairWin;
                isWinningRound = true;
                statusMessage = "THREE OF A KIND! WINS 11:1 (" + pairWin + " CREDITS)";
                playSound("jackpot");
            } else {
                credits += betCoins; // Push
                statusMessage = "PAIR! PUSH (BET RETURNED)";
                playSound("win");
            }
        } else {
            playerHand = [c1, c2];
            machineState = "DEALT";
            statusMessage = "SPREAD " + redDogSpread + " (PAYS " + dogResult.payoutRate + ":1) - [1] CALL or [2] RAISE 2X";
            playSound("deal");
        }
        saveSettings();
    }

    function resolveRedDog(isRaise) {
        if (activeGameId !== "red_dog" || machineState !== "DEALT") return;

        var totalRisk = betCoins;
        if (isRaise) {
            if (credits >= betCoins) {
                credits -= betCoins;
                totalRisk = betCoins * 2;
                playSound("chip");
            } else {
                statusMessage = "NOT ENOUGH CREDITS TO RAISE. CALLING...";
            }
        }

        var c3 = activeDeck.pop();
        c3.faceUp = true;
        var r1 = playerHand[0].rank;
        var r2 = playerHand[1].rank;

        var handCopy = playerHand.slice();
        handCopy.push(c3);
        playerHand = handCopy;
        machineState = "ROUND_OVER";

        var dogOutcome = Engine.evaluateRedDogThirdCard(r1, r2, c3.rank);
        if (dogOutcome.won) {
            var winPayout = totalRisk * dogOutcome.payoutRate + totalRisk;
            credits += winPayout;
            lastWinAmount = winPayout;
            isWinningRound = true;
            statusMessage = "INSIDE CARD (" + c3.value + ")! WON " + winPayout + " CREDITS!";
            playSound("win");
        } else {
            isWinningRound = false;
            lastWinAmount = 0;
            statusMessage = "OUTSIDE (" + c3.value + "). HOUSE WINS. PRESS DEAL";
            playSound("lose");
        }
        saveSettings();
    }

    // --- BLACKJACK DISPATCH ---
    function dealBlackjackInitial() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS! PRESS (C) TO ADD COINS";
            playSound("lose");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        activeDeck = Engine.createStandardDeck();
        Engine.shuffle(activeDeck);

        var p1 = activeDeck.pop(); p1.faceUp = true;
        var d1 = activeDeck.pop(); d1.faceUp = true;
        var p2 = activeDeck.pop(); p2.faceUp = true;
        var d2 = activeDeck.pop(); d2.faceUp = false;

        playerHand = [p1, p2];
        dealerHand = [d1, d2];
        playerTotal = Engine.calculateBlackjackScore(playerHand);
        dealerTotal = d1.rank === 14 ? 11 : Math.min(d1.rank, 10);
        playerCanDouble = credits >= betCoins;

        if (playerTotal === 21) {
            dealerHand[1].faceUp = true;
            var dTot = Engine.calculateBlackjackScore(dealerHand);
            dealerTotal = dTot;
            machineState = "ROUND_OVER";

            if (dTot === 21) {
                credits += betCoins;
                statusMessage = "BOTH HAVE BLACKJACK! PUSH.";
                playSound("win");
            } else {
                var bjWin = Math.floor(betCoins * 2.5);
                credits += bjWin;
                lastWinAmount = bjWin;
                isWinningRound = true;
                statusMessage = "NATURAL BLACKJACK! WINS " + bjWin + " CREDITS (3:2)!";
                playSound("jackpot");
            }
        } else {
            machineState = "DEALT";
            statusMessage = "PLAYER HAS " + playerTotal + ". [1] HIT, [2] STAND, [3] DOUBLE";
            playSound("deal");
        }
        saveSettings();
    }

    function blackjackHit() {
        if (activeGameId !== "blackjack" || machineState !== "DEALT") return;
        var card = activeDeck.pop();
        card.faceUp = true;
        var handCopy = playerHand.slice();
        handCopy.push(card);
        playerHand = handCopy;
        playerTotal = Engine.calculateBlackjackScore(playerHand);
        playSound("draw");

        if (playerTotal > 21) {
            dealerHand[1].faceUp = true;
            dealerTotal = Engine.calculateBlackjackScore(dealerHand);
            machineState = "ROUND_OVER";
            isWinningRound = false;
            lastWinAmount = 0;
            statusMessage = "BUST! PLAYER HAS " + playerTotal + ". HOUSE WINS.";
            playSound("lose");
            saveSettings();
        } else if (playerTotal === 21) {
            blackjackStand();
        } else {
            statusMessage = "PLAYER HAS " + playerTotal + ". [1] HIT, [2] STAND";
        }
    }

    function blackjackStand() {
        if (activeGameId !== "blackjack" || machineState !== "DEALT") return;
        machineState = "DRAWING";

        dealerHand[1].faceUp = true;
        var dTot = Engine.calculateBlackjackScore(dealerHand);
        while (dTot < 17) {
            var c = activeDeck.pop();
            c.faceUp = true;
            dealerHand.push(c);
            dTot = Engine.calculateBlackjackScore(dealerHand);
        }
        dealerTotal = dTot;
        machineState = "ROUND_OVER";

        if (dTot > 21) {
            var win = betCoins * 2;
            credits += win;
            lastWinAmount = win;
            isWinningRound = true;
            statusMessage = "DEALER BUSTS (" + dTot + ")! YOU WIN " + win + " CREDITS!";
            playSound("win");
        } else if (playerTotal > dTot) {
            var winP = betCoins * 2;
            credits += winP;
            lastWinAmount = winP;
            isWinningRound = true;
            statusMessage = "YOU WIN! (" + playerTotal + " vs " + dTot + ") - " + winP + " CREDITS!";
            playSound("win");
        } else if (playerTotal === dTot) {
            credits += betCoins;
            statusMessage = "PUSH (" + playerTotal + " vs " + dTot + "). BET RETURNED.";
            playSound("win");
        } else {
            isWinningRound = false;
            lastWinAmount = 0;
            statusMessage = "HOUSE WINS (" + dTot + " vs " + playerTotal + "). PRESS DEAL.";
            playSound("lose");
        }
        saveSettings();
    }

    function blackjackDouble() {
        if (activeGameId !== "blackjack" || machineState !== "DEALT" || !playerCanDouble) return;
        credits -= betCoins;
        betCoins *= 2;
        playSound("chip");

        var card = activeDeck.pop();
        card.faceUp = true;
        var handCopy = playerHand.slice();
        handCopy.push(card);
        playerHand = handCopy;
        playerTotal = Engine.calculateBlackjackScore(playerHand);

        if (playerTotal > 21) {
            dealerHand[1].faceUp = true;
            dealerTotal = Engine.calculateBlackjackScore(dealerHand);
            machineState = "ROUND_OVER";
            isWinningRound = false;
            statusMessage = "DOUBLE DOWN BUST (" + playerTotal + ")!";
            playSound("lose");
            betCoins = Math.floor(betCoins / 2);
            saveSettings();
        } else {
            blackjackStand();
            betCoins = Math.floor(betCoins / 2);
        }
    }

    // --- CASINO WAR DISPATCH ---
    function dealWarInitial() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS! PRESS (C) TO ADD COINS";
            playSound("lose");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        activeDeck = Engine.createStandardDeck();
        Engine.shuffle(activeDeck);

        var pCard = activeDeck.pop(); pCard.faceUp = true;
        var dCard = activeDeck.pop(); dCard.faceUp = true;

        playerHand = [pCard];
        dealerHand = [dCard];

        var outcome = Engine.evaluateWarDuel(pCard.rank, dCard.rank);
        if (outcome.winner === "player") {
            var w = betCoins * 2;
            credits += w;
            lastWinAmount = w;
            isWinningRound = true;
            machineState = "ROUND_OVER";
            statusMessage = "YOU WIN! " + pCard.value + " BEATS " + dCard.value + " (" + w + " CREDITS)";
            playSound("win");
        } else if (outcome.winner === "dealer") {
            isWinningRound = false;
            lastWinAmount = 0;
            machineState = "ROUND_OVER";
            statusMessage = "DEALER WINS: " + dCard.value + " BEATS " + pCard.value;
            playSound("lose");
        } else {
            machineState = "DEALT";
            warState = "TIE";
            statusMessage = "TIE CARD (" + pCard.value + ")! [1] SURRENDER (LOSE 50%) or [2] GO TO WAR!";
            playSound("draw");
        }
        saveSettings();
    }

    function warSurrender() {
        if (activeGameId !== "casino_war" || machineState !== "DEALT") return;
        var refund = Math.floor(betCoins / 2);
        credits += refund;
        machineState = "ROUND_OVER";
        statusMessage = "SURRENDERED. " + refund + " CREDITS RETURNED.";
        playSound("lose");
        saveSettings();
    }

    function warGoToWar() {
        if (activeGameId !== "casino_war" || machineState !== "DEALT") return;
        if (credits < betCoins) {
            statusMessage = "NOT ENOUGH CREDITS FOR WAR (NEED " + betCoins + "). SURRENDERING...";
            warSurrender();
            return;
        }

        credits -= betCoins;
        playSound("chip");

        // Burn 3 cards
        activeDeck.pop(); activeDeck.pop(); activeDeck.pop();

        var pWar = activeDeck.pop(); pWar.faceUp = true;
        var dWar = activeDeck.pop(); dWar.faceUp = true;

        playerHand.push(pWar);
        dealerHand.push(dWar);
        machineState = "ROUND_OVER";

        var outcome = Engine.evaluateWarDuel(pWar.rank, dWar.rank);
        if (outcome.winner === "player" || outcome.winner === "tie") {
            var winAmt = betCoins * 3;
            credits += winAmt;
            lastWinAmount = winAmt;
            isWinningRound = true;
            statusMessage = "WAR WON! " + pWar.value + " BEATS " + dWar.value + " (" + winAmt + " CREDITS)";
            playSound("jackpot");
        } else {
            isWinningRound = false;
            lastWinAmount = 0;
            statusMessage = "WAR LOST: " + dWar.value + " BEATS " + pWar.value;
            playSound("lose");
        }
        saveSettings();
    }

    // =========================================================================
    // DOUBLE-UP GAMBLE BONUS (High Card 1-vs-4 Pick)
    // =========================================================================
    function startDoubleUp() {
        if (!isWinningRound || lastWinAmount <= 0) return;
        doubleUpActive = true;
        doubleUpResolved = false;
        doubleUpCurrentPot = lastWinAmount;
        doubleUpMessage = "PICK A CARD HIGHER THAN DEALER'S CARD TO DOUBLE!";

        var bonusDeck = Engine.createStandardDeck();
        Engine.shuffle(bonusDeck);
        var dCard = bonusDeck.pop();
        dCard.faceUp = true;
        doubleUpDealerCard = dCard;

        var pCards = [];
        for (var i = 0; i < 4; i++) {
            var c = bonusDeck.pop();
            c.faceUp = false;
            pCards.push(c);
        }
        doubleUpPlayerCards = pCards;
        playSound("deal");
    }

    function pickDoubleUpCard(pickIndex) {
        if (!doubleUpActive || doubleUpResolved) return;
        if (pickIndex < 0 || pickIndex >= doubleUpPlayerCards.length) return;

        doubleUpResolved = true;
        var chosen = doubleUpPlayerCards[pickIndex];
        chosen.faceUp = true;

        var revealed = doubleUpPlayerCards.slice();
        for (var i = 0; i < revealed.length; i++) {
            revealed[i].faceUp = true;
        }
        doubleUpPlayerCards = revealed;

        var dealerRank = doubleUpDealerCard.rank;
        var playerRank = chosen.rank;

        if (playerRank > dealerRank) {
            doubleUpCurrentPot *= 2;
            doubleUpMessage = "YOU WIN! " + chosen.value + " BEATS " + doubleUpDealerCard.value + "! POT: " + doubleUpCurrentPot;
            playSound("win");
        } else if (playerRank === dealerRank) {
            doubleUpMessage = "TIE! " + chosen.value + " PUSHES " + doubleUpDealerCard.value + ". POT REMAINS " + doubleUpCurrentPot;
            playSound("draw");
        } else {
            doubleUpMessage = "DEALER WINS: " + doubleUpDealerCard.value + " BEATS " + chosen.value + ". POT LOST!";
            credits -= lastWinAmount;
            lastWinAmount = 0;
            isWinningRound = false;
            playSound("lose");
            QTimer.singleShot(1400, function() { doubleUpActive = false; });
        }
        saveSettings();
    }

    function collectDoubleUp() {
        if (!doubleUpActive) return;
        if (doubleUpCurrentPot > lastWinAmount) {
            var extra = doubleUpCurrentPot - lastWinAmount;
            credits += extra;
            lastWinAmount = doubleUpCurrentPot;
        }
        doubleUpActive = false;
        statusMessage = "COLLECTED " + doubleUpCurrentPot + " CREDITS!";
        playSound("chip");
        saveSettings();
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
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_H) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            if (gameMenuOpen) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_G) {
                    gameMenuOpen = false;
                    event.accepted = true;
                    return;
                }
            }

            if (doubleUpActive) {
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                    pickDoubleUpCard(event.key - Qt.Key_1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_C || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (doubleUpResolved) collectDoubleUp();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    collectDoubleUp();
                    event.accepted = true;
                    return;
                }
            }

            // Global Game Keys
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                handlePrimaryAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_1) {
                if (isPokerGame) toggleHold(0);
                else if (activeGameId === "red_dog") resolveRedDog(false);
                else if (activeGameId === "blackjack") blackjackHit();
                else if (activeGameId === "casino_war") warSurrender();
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                if (isPokerGame) toggleHold(1);
                else if (activeGameId === "red_dog") resolveRedDog(true);
                else if (activeGameId === "blackjack") blackjackStand();
                else if (activeGameId === "casino_war") warGoToWar();
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                if (isPokerGame) toggleHold(2);
                else if (activeGameId === "blackjack") blackjackDouble();
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                if (isPokerGame) toggleHold(3);
                event.accepted = true;
            } else if (event.key === Qt.Key_5) {
                if (isPokerGame) toggleHold(4);
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                increaseBet();
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                setMaxBet();
                event.accepted = true;
            } else if (event.key === Qt.Key_V) {
                root.visualMode = (root.visualMode === "cyber" ? "crt" : "cyber");
                root.saveSettings();
                root.playSound("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_G) {
                gameMenuOpen = !gameMenuOpen;
                playSound("select");
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                if (isWinningRound && !doubleUpActive && lastWinAmount > 0) startDoubleUp();
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                if (doubleUpActive) {
                    collectDoubleUp();
                } else {
                    credits += 100;
                    playSound("chip");
                    statusMessage = "+100 CREDITS INSERTED";
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_H) {
                root.showHelp = !root.showHelp;
                playSound("select");
                event.accepted = true;
            }
        }

        // =====================================================================
        // ROW 1: HEADER ITEM (From Master Template 2048 Standard)
        // =====================================================================
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: Math.max(titleCol.height, statRow.height)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: statRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.title
                    font.pixelSize: Math.max(18, Math.min(28, headerItem.width * 0.068))
                    font.bold: true
                    color: isCyberMode ? root.neonCyan : "#FEF08A"
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: activeGameObj.name
                    font.pixelSize: Math.max(9, Math.min(12, headerItem.width * 0.026))
                    font.bold: true
                    color: root.themeSubtext
                }
            }

            // Stat Cards on the Right
            Row {
                id: statRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // CREDITS Card
                Rectangle {
                    width: Math.max(62, Math.min(78, headerItem.width * 0.17))
                    height: Math.max(38, Math.min(46, headerItem.width * 0.11))
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "CREDITS"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.credits.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                        }
                    }
                }

                // WIN / BET Card
                Rectangle {
                    width: Math.max(62, Math.min(78, headerItem.width * 0.17))
                    height: Math.max(38, Math.min(46, headerItem.width * 0.11))
                    radius: 6
                    color: root.isWinningRound ? (isCyberMode ? "#FF007F26" : "#7F1D1D") : root.themeCardBg
                    border.color: root.isWinningRound ? (isCyberMode ? root.neonMagenta : "#FACC15") : root.themeBorder
                    border.width: root.isWinningRound ? 1.5 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.isWinningRound ? "PAID" : "BET"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.isWinningRound ? (isCyberMode ? "#FFB6D9" : "#FDE047") : root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.isWinningRound ? root.lastWinAmount.toString() : (root.betCoins + " / 5")
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.isWinningRound ? (isCyberMode ? root.neonMagenta : "#FEF08A") : (isCyberMode ? root.neonCyan : root.themeAccent)
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: SUBHEADER ACTION BAR (Responsive Toolbar with Era Switcher)
        // =====================================================================
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 30

            readonly property bool isCrowded: subheaderItem.width < 440

            // Left cluster: Games & Rules
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 4 : 6

                // Game Selector Menu Button
                Rectangle {
                    height: 28
                    width: subheaderItem.isCrowded ? 28 : (gameBtnRow.implicitWidth + 14)
                    radius: 6
                    color: gameMenuMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: gameMenuMouse.containsMouse ? (isCyberMode ? root.neonCyan : "#38BDF8") : root.themeBorder
                    border.width: 1

                    Row {
                        id: gameBtnRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🎮"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Games (G)"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }
                    MouseArea {
                        id: gameMenuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gameMenuOpen = !gameMenuOpen;
                            root.playSound("select");
                        }
                    }
                }

                // Help Button
                Rectangle {
                    height: 28
                    width: subheaderItem.isCrowded ? 28 : (helpRow.implicitWidth + 14)
                    radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? (isCyberMode ? root.neonCyan : "#38BDF8") : root.themeBorder
                    border.width: 1

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "?"
                            font.pixelSize: 11
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#38BDF8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Rules"
                            font.pixelSize: 10
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
                        onClicked: {
                            root.showHelp = !root.showHelp;
                            root.playSound("select");
                        }
                    }
                }
            }

            // Right cluster: Visual Switcher, Add Coins, Mute
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 4 : 6

                // Classic CRT ↔ Cyber Neon Switcher
                Rectangle {
                    height: 28
                    width: subheaderItem.isCrowded ? 28 : (switcherRow.implicitWidth + 14)
                    radius: 6
                    color: isCyberMode ? "#1E1B4B" : "#0C4A6E"
                    border.color: isCyberMode ? root.neonPurple : "#38BDF8"
                    border.width: 1

                    Row {
                        id: switcherRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: isCyberMode ? "📺" : "⚡"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: isCyberMode ? "Classic [V]" : "Cyber [V]"
                            font.pixelSize: 10
                            font.bold: true
                            color: isCyberMode ? "#C084FC" : "#38BDF8"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.visualMode = (root.visualMode === "cyber" ? "crt" : "cyber");
                            root.saveSettings();
                            root.playSound("click");
                        }
                    }
                }

                // Add Coins Button
                Rectangle {
                    height: 28
                    width: subheaderItem.isCrowded ? 28 : (coinRow.implicitWidth + 14)
                    radius: 6
                    color: coinMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: coinMouse.containsMouse ? (isCyberMode ? root.neonCyan : "#38BDF8") : root.themeBorder
                    border.width: 1

                    Row {
                        id: coinRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "🪙"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "+100 (C)"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }
                    MouseArea {
                        id: coinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.credits += 100;
                            root.playSound("chip");
                            root.statusMessage = "+100 CREDITS INSERTED";
                        }
                    }
                }

                // Mute Button
                Rectangle {
                    height: 28
                    width: 28
                    radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : (isCyberMode ? root.neonCyan : "#38BDF8")
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }
            }
        }

        // =====================================================================
        // ROW 3: PLAYFIELD BOARD CONTAINER (Dynamic Terminal Screen)
        // =====================================================================
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 8
            anchors.bottom: buttonDeckItem.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            readonly property int cardW: Math.max(46, Math.min(76, Math.floor((width - 44) / 5)))
            readonly property int cardH: Math.round(cardW * 1.42)

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                radius: isCyberMode ? 8 : 10
                clip: true
                color: isCyberMode ? root.cyberObsidian : "#000088"
                border.color: isCyberMode ? root.neonCyan : "#1E293B"
                border.width: isCyberMode ? 1.5 : 4

                // Cyber Mode Neon Laser Grid & Framing Lines
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 6
                    color: "transparent"
                    border.color: "#A855F733"
                    border.width: 1
                    visible: isCyberMode
                    z: 49
                }

                // Inside Terminal Screen:
                Column {
                    anchors.fill: parent
                    anchors.margins: isCyberMode ? 10 : 8
                    spacing: 5

                    // 1. Paytable Matrix / Game Table HUD
                    Rectangle {
                        width: parent.width
                        height: Math.max(88, Math.min(130, boardContainer.height * 0.28))
                        radius: isCyberMode ? 5 : 4
                        color: isCyberMode ? "#0A0F1ECC" : "#0000AA"
                        border.color: isCyberMode ? "#00F0FF33" : "#FEF08A"
                        border.width: 1
                        clip: true

                        // Poker 5-Column Paytable
                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 1
                            visible: root.isPokerGame

                            // Paytable Header Row
                            Row {
                                width: parent.width
                                height: 15
                                spacing: 2

                                Text {
                                    width: parent.width * 0.44
                                    text: "HAND"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: Math.max(7, Math.min(10, boardContainer.width * 0.021))
                                    font.bold: true
                                    color: isCyberMode ? root.neonCyan : "#FEF08A"
                                }

                                Repeater {
                                    model: [1, 2, 3, 4, 5]
                                    Rectangle {
                                        width: (parent.width * 0.56 - 8) / 5
                                        height: 15
                                        radius: 2
                                        color: (root.betCoins === modelData) ? (isCyberMode ? root.neonCyan : "#FEF08A") : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.toString()
                                            font.family: root.monoFontFamily
                                            font.pixelSize: Math.max(7, Math.min(10, boardContainer.width * 0.021))
                                            font.bold: true
                                            color: (root.betCoins === modelData) ? "#000000" : (isCyberMode ? "#38BDF8" : "#FFFFFF")
                                        }
                                    }
                                }
                            }

                            // Paytable Rows (Scrollable Flickable)
                            Flickable {
                                id: paytableFlickable
                                width: parent.width
                                height: parent.parent.height - 24
                                contentHeight: payRowsCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Behavior on contentY {
                                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                }

                                Column {
                                    id: payRowsCol
                                    width: parent.width
                                    spacing: 1

                                    Repeater {
                                        id: payRowsRepeater
                                        model: Engine.PAYTABLES[activeGameId] ? Engine.PAYTABLES[activeGameId] : []
                                        Rectangle {
                                            id: payRowRect
                                            width: parent.width
                                            height: 12
                                            readonly property bool isWinningRow: winningEvaluation && (winningEvaluation.key === modelData.key) && (isWinningRound || machineState === "DEALT")
                                            color: isWinningRow ? (isCyberMode ? root.neonMagenta : "#E11D48") : "transparent"
                                            border.color: isWinningRow ? (isCyberMode ? "#FFFFFF" : "#FEF08A") : "transparent"
                                            border.width: isWinningRow ? 1 : 0
                                            radius: 2

                                            SequentialAnimation on opacity {
                                                running: payRowRect.isWinningRow
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 0.65; to: 1.0; duration: 220; easing.type: Easing.InOutQuad }
                                                NumberAnimation { from: 1.0; to: 0.65; duration: 220; easing.type: Easing.InOutQuad }
                                            }

                                            Row {
                                                anchors.fill: parent
                                                spacing: 2

                                                Text {
                                                    width: parent.width * 0.44
                                                    text: modelData.name
                                                    font.family: root.monoFontFamily
                                                    font.pixelSize: Math.max(6, Math.min(9, boardContainer.width * 0.019))
                                                    font.bold: parent.parent.isWinningRow
                                                    color: parent.parent.isWinningRow ? "#FFFFFF" : (isCyberMode ? "#E2E8F0" : "#FFFFFF")
                                                    elide: Text.ElideRight
                                                }

                                                Repeater {
                                                    model: modelData.pays
                                                    Rectangle {
                                                        width: (parent.width * 0.56 - 8) / 5
                                                        height: 12
                                                        color: (root.betCoins === index + 1) ? (isCyberMode ? "#00F0FF22" : "#FFFF0033") : "transparent"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.toString()
                                                            font.family: root.monoFontFamily
                                                            font.pixelSize: Math.max(6, Math.min(9, boardContainer.width * 0.019))
                                                            font.bold: (root.betCoins === index + 1) || parent.parent.parent.isWinningRow
                                                            color: parent.parent.parent.isWinningRow ? "#FFFFFF" : ((root.betCoins === index + 1) ? (isCyberMode ? root.neonCyan : "#FEF08A") : (isCyberMode ? "#64748B" : "#CBD5E1"))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Table Game HUDs (Red Dog, Blackjack, War)
                        Item {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: !root.isPokerGame

                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                width: parent.width

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (activeGameId === "red_dog") return "RED DOG SPREAD PAYOUTS";
                                        if (activeGameId === "blackjack") return "SINGLE-DECK BLACKJACK (PAYS 3:2)";
                                        return "CASINO WAR (HIGH CARD WINS 1:1)";
                                    }
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: isCyberMode ? root.neonCyan : "#FEF08A"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: {
                                        if (activeGameId === "red_dog") {
                                            return "Spread 1: 5:1 • Spread 2: 4:1 • Spread 3: 2:1 • Spread 4-11: 1:1 • Pair: 11:1";
                                        }
                                        if (activeGameId === "blackjack") {
                                            return "Dealer stands on all 17s • Double Down on any 2 cards • 52-card deck";
                                        }
                                        return "Aces high • Tie: Go to War (double bet, win 1:1) or Surrender (lose 50%)";
                                    }
                                    font.pixelSize: 9
                                    color: isCyberMode ? "#94A3B8" : "#E2E8F0"
                                }
                            }
                        }
                    }

                    // 2. Status Message Banner
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 3
                        color: root.isWinningRound ? (isCyberMode ? root.neonMagenta : "#DC2626") : (isCyberMode ? "#0A1020" : "#000055")
                        border.color: root.isWinningRound ? "#FFB6D9" : (isCyberMode ? "#00F0FF33" : "#FEF08A44")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.statusMessage
                            font.family: root.monoFontFamily
                            font.pixelSize: Math.max(9, Math.min(11, boardContainer.width * 0.024))
                            font.bold: true
                            color: root.isWinningRound ? "#FFFFFF" : (isCyberMode ? root.neonCyan : "#FEF08A")
                        }
                    }

                    // 3. Main Center Card Playfield
                    Item {
                        width: parent.width
                        height: parent.height - 180

                        // POKER VIEW (5 CARDS)
                        Row {
                            anchors.centerIn: parent
                            spacing: Math.max(4, Math.floor((parent.width - playArea.cardW * 5) / 6))
                            visible: root.isPokerGame

                            Repeater {
                                model: root.playerHand
                                Item {
                                    width: playArea.cardW
                                    height: playArea.cardH

                                    PlayingCard {
                                        anchors.fill: parent
                                        cardData: modelData
                                        visualMode: root.visualMode
                                        isWinning: root.isWinningRound && (root.winningCardIndices.indexOf(index) !== -1)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: (machineState === "DEALT") ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: toggleHold(index)
                                    }
                                }
                            }
                        }

                        // RED DOG VIEW (2 Outer + 1 Center)
                        Row {
                            anchors.centerIn: parent
                            spacing: Math.max(12, Math.floor(playArea.cardW * 0.3))
                            visible: activeGameId === "red_dog"

                            PlayingCard {
                                width: playArea.cardW
                                height: playArea.cardH
                                cardData: (playerHand.length >= 1) ? playerHand[0] : null
                                visualMode: root.visualMode
                            }

                            // Center Spread Box
                            Rectangle {
                                width: playArea.cardW + 10
                                height: playArea.cardH
                                radius: 4
                                color: isCyberMode ? "#0A0F1E" : "#000044"
                                border.color: isCyberMode ? root.neonCyan : "#38BDF8"
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    visible: playerHand.length < 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "SPREAD"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: isCyberMode ? "#38BDF8" : "#93C5FD"
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: redDogSpread.toString()
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: isCyberMode ? root.neonMagenta : "#FEF08A"
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (redDogStatus === "pair" ? "PAIR" : (redDogStatus === "consecutive" ? "PUSH" : "BETWEEN"))
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }

                                PlayingCard {
                                    anchors.fill: parent
                                    cardData: (playerHand.length >= 3) ? playerHand[2] : null
                                    visualMode: root.visualMode
                                    visible: playerHand.length >= 3
                                }
                            }

                            PlayingCard {
                                width: playArea.cardW
                                height: playArea.cardH
                                cardData: (playerHand.length >= 2) ? playerHand[1] : null
                                visualMode: root.visualMode
                            }
                        }

                        // BLACKJACK VIEW (Dealer Top, Player Bottom)
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: activeGameId === "blackjack"

                            // Dealer
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "D (" + (machineState === "ROUND_OVER" ? dealerTotal : "?") + "): "
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: isCyberMode ? root.neonPurple : "#FEF08A"
                                }
                                Repeater {
                                    model: dealerHand
                                    PlayingCard {
                                        width: Math.round(playArea.cardW * 0.72)
                                        height: Math.round(playArea.cardH * 0.72)
                                        cardData: modelData
                                        visualMode: root.visualMode
                                    }
                                }
                            }

                            // Player
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "P (" + playerTotal + "): "
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: isCyberMode ? root.neonCyan : "#38BDF8"
                                }
                                Repeater {
                                    model: playerHand
                                    PlayingCard {
                                        width: Math.round(playArea.cardW * 0.72)
                                        height: Math.round(playArea.cardH * 0.72)
                                        cardData: modelData
                                        visualMode: root.visualMode
                                    }
                                }
                            }
                        }

                        // CASINO WAR VIEW
                        Row {
                            anchors.centerIn: parent
                            spacing: 16
                            visible: activeGameId === "casino_war"

                            Column {
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "DEALER"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: isCyberMode ? root.neonPurple : "#FEF08A"
                                }
                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: dealerHand
                                        PlayingCard {
                                            width: playArea.cardW
                                            height: playArea.cardH
                                            cardData: modelData
                                            visualMode: root.visualMode
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "VS"
                                font.family: root.monoFontFamily
                                font.pixelSize: 16
                                font.bold: true
                                color: isCyberMode ? root.neonCyan : "#FFFFFF"
                            }

                            Column {
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "YOU"
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: isCyberMode ? root.neonCyan : "#38BDF8"
                                }
                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: playerHand
                                        PlayingCard {
                                            width: playArea.cardW
                                            height: playArea.cardH
                                            cardData: modelData
                                            visualMode: root.visualMode
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
        // ROW 4: PHYSICAL BUTTON DECK (Underneath Screen)
        // Two compact rows: Row 1 = 5 Holds, Row 2 = Bet & Deal actions
        // =====================================================================
        Item {
            id: buttonDeckItem
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 68

            Column {
                anchors.fill: parent
                spacing: 4

                // ROW A: 5 HOLD BUTTONS (or Table Actions)
                Row {
                    width: parent.width
                    height: 30
                    spacing: Math.max(4, Math.floor((width - playArea.cardW * 5) / 6))
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.isPokerGame

                    Repeater {
                        model: 5
                        Rectangle {
                            width: playArea.cardW
                            height: 28
                            radius: isCyberMode ? 4 : 3
                            readonly property bool cardIsHeld: Boolean(playerHand && playerHand[index] && playerHand[index].held)
                            color: cardIsHeld ? (isCyberMode ? root.neonMagenta : "#DC2626") : (isCyberMode ? "#0A0F1E" : "#1E293B")
                            border.color: cardIsHeld ? (isCyberMode ? "#FFB6D9" : "#FEF08A") : (isCyberMode ? "#00F0FF33" : root.themeBorder)
                            border.width: cardIsHeld ? 1.5 : 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleHold(index)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cardIsHeld ? "HELD" : "HOLD " + (index + 1)
                                font.family: root.monoFontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: cardIsHeld ? (isCyberMode ? "#FFFFFF" : "#FEF08A") : (isCyberMode ? root.neonCyan : "#FFFFFF")
                            }
                        }
                    }
                }

                // Table Actions for Red Dog, Blackjack, War
                Row {
                    width: parent.width
                    height: 30
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.isPokerGame && machineState === "DEALT"

                    // Action 1
                    Rectangle {
                        width: (parent.width - 16) / 2
                        height: 28
                        radius: 4
                        color: isCyberMode ? "#0369A1" : "#0284C7"
                        border.color: isCyberMode ? root.neonCyan : "#38BDF8"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (activeGameId === "red_dog") return "CALL [1]";
                                if (activeGameId === "blackjack") return "HIT [1]";
                                return "SURRENDER [1]";
                            }
                            font.pixelSize: 10
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activeGameId === "red_dog") resolveRedDog(false);
                                else if (activeGameId === "blackjack") blackjackHit();
                                else warSurrender();
                            }
                        }
                    }

                    // Action 2
                    Rectangle {
                        width: (parent.width - 16) / 2
                        height: 28
                        radius: 4
                        color: isCyberMode ? root.neonMagenta : "#D97706"
                        border.color: isCyberMode ? "#FFB6D9" : "#FDE68A"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (activeGameId === "red_dog") return "RAISE 2X [2]";
                                if (activeGameId === "blackjack") return "STAND [2]";
                                return "GO TO WAR [2]";
                            }
                            font.pixelSize: 10
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activeGameId === "red_dog") resolveRedDog(true);
                                else if (activeGameId === "blackjack") blackjackStand();
                                else warGoToWar();
                            }
                        }
                    }
                }

                // ROW B: BET & DEAL ACTIONS
                Row {
                    width: parent.width
                    height: 32
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Double-Up Trigger Button (when winning)
                    Rectangle {
                        width: Math.floor(parent.width * 0.28)
                        height: 30
                        radius: 4
                        visible: isWinningRound && lastWinAmount > 0 && !doubleUpActive
                        color: isCyberMode ? root.neonMagenta : "#E11D48"
                        border.color: "#FEF08A"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "DOUBLE [D]"
                            font.family: root.monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: startDoubleUp()
                        }
                    }

                    // BET 1
                    Rectangle {
                        width: (parent.width - (isWinningRound && lastWinAmount > 0 ? parent.width * 0.28 + 18 : 12)) * 0.38
                        height: 30
                        radius: 4
                        color: isCyberMode ? "#0A0F1E" : "#0D9488"
                        border.color: isCyberMode ? root.neonCyan : "#99F6E4"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "BET 1 [B]"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: increaseBet()
                        }
                    }

                    // BET MAX
                    Rectangle {
                        width: (parent.width - (isWinningRound && lastWinAmount > 0 ? parent.width * 0.28 + 18 : 12)) * 0.30
                        height: 30
                        radius: 4
                        color: isCyberMode ? "#1E1035" : "#CA8A04"
                        border.color: isCyberMode ? root.neonPurple : "#FEF08A"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "MAX [M]"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: isCyberMode ? "#C084FC" : "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setMaxBet()
                        }
                    }

                    // DEAL / DRAW
                    Rectangle {
                        width: (parent.width - (isWinningRound && lastWinAmount > 0 ? parent.width * 0.28 + 18 : 12)) * 0.32
                        height: 30
                        radius: 4
                        color: isCyberMode ? root.neonCyan : "#16A34A"
                        border.color: isCyberMode ? "#E0F2FE" : "#86EFAC"
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: (machineState === "DEALT" && isPokerGame) ? "DRAW" : "DEAL"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: isCyberMode ? "#050811" : "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: handlePrimaryAction()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // DOUBLE-UP GAMBLE OVERLAY MODAL
        // =====================================================================
        Rectangle {
            id: doubleUpModal
            anchors.fill: parent
            color: "#E6000000"
            visible: doubleUpActive
            z: 800

            Rectangle {
                width: Math.min(parent.width * 0.92, 420)
                height: Math.min(parent.height * 0.88, 380)
                anchors.centerIn: parent
                radius: 8
                color: isCyberMode ? "#090D1A" : "#000088"
                border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                border.width: 2

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        width: parent.width
                        Text {
                            text: "DOUBLE-UP BONUS"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                        }
                        Item { width: parent.width - 200 }
                        Rectangle {
                            width: 70
                            height: 22
                            radius: 3
                            color: "#DC2626"
                            Text {
                                anchors.centerIn: parent
                                text: "COLLECT (C)"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: collectDoubleUp()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 4
                        color: isCyberMode ? "#111827" : "#000044"
                        Text {
                            anchors.centerIn: parent
                            text: "POT: " + doubleUpCurrentPot + "  →  DOUBLE: " + (doubleUpCurrentPot * 2)
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: isCyberMode ? root.neonMagenta : "#FEF08A"
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: doubleUpMessage
                        font.pixelSize: 10
                        font.bold: true
                        color: "#FFFFFF"
                    }

                    // Cards
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        // Dealer
                        Column {
                            spacing: 4
                            Text {
                                text: "DEALER"
                                font.pixelSize: 8
                                font.bold: true
                                color: "#FEF08A"
                            }
                            PlayingCard {
                                width: 56
                                height: 80
                                cardData: doubleUpDealerCard
                                visualMode: root.visualMode
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 80
                            color: "#64748B"
                        }

                        // 4 Player Hidden Picks
                        Repeater {
                            model: doubleUpPlayerCards
                            Item {
                                width: 56
                                height: 80
                                PlayingCard {
                                    anchors.fill: parent
                                    cardData: modelData
                                    visualMode: root.visualMode
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: (!doubleUpResolved) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: pickDoubleUpCard(index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // GAMES SELECTOR MODAL (8 Games)
        // =====================================================================
        Rectangle {
            id: gameSelectModal
            anchors.fill: parent
            color: "#CC000000"
            visible: gameMenuOpen
            z: 850

            Rectangle {
                width: Math.min(parent.width * 0.94, 440)
                height: Math.min(parent.height * 0.90, 520)
                anchors.centerIn: parent
                radius: 8
                color: isCyberMode ? "#090D1A" : "#000088"
                border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                border.width: 2

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        Text {
                            text: "SELECT GAME TERMINAL"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                        }
                        Item { width: parent.width - 200 }
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 3
                            color: "#DC2626"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 11
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: gameMenuOpen = false
                            }
                        }
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - 40
                        contentHeight: gameGrid.implicitHeight
                        clip: true

                        Column {
                            id: gameGrid
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: gameList
                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    radius: 4
                                    readonly property bool isSel: (activeGameId === modelData.id)
                                    color: isSel ? (isCyberMode ? "#00F0FF22" : "#0284C7") : (isCyberMode ? "#111827" : "#000055")
                                    border.color: isSel ? (isCyberMode ? root.neonCyan : "#FEF08A") : root.themeBorder
                                    border.width: isSel ? 1.5 : 1

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: switchGame(modelData.id)
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 2
                                        Row {
                                            width: parent.width
                                            Text {
                                                text: modelData.name
                                                font.family: root.monoFontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: isSel ? "#FFFFFF" : (isCyberMode ? root.neonCyan : "#FFFFFF")
                                            }
                                            Item { width: 10 }
                                            Rectangle {
                                                width: 38
                                                height: 12
                                                radius: 2
                                                color: modelData.type === "poker" ? "#16A34A" : "#D97706"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.type.toUpperCase()
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                    color: "#FFFFFF"
                                                }
                                            }
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.desc
                                            font.pixelSize: 8
                                            color: isCyberMode ? "#94A3B8" : "#CBD5E1"
                                            elide: Text.ElideRight
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
        // HOW TO PLAY / RULES MODAL (Template Standard)
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
                width: Math.min(parent.width * 0.90, 420)
                height: Math.min(parent.height * 0.88, 480)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 10

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "HOW TO PLAY & SHORTCUTS"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - 40
                        contentHeight: helpBody.implicitHeight
                        clip: true

                        Column {
                            id: helpBody
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "• [SPACE] or [ENTER]: Deal cards or Draw unheld cards\n" +
                                      "• [1] - [5]: Toggle Hold on cards 1 through 5 (or Table action)\n" +
                                      "• [B]: Increase coin bet (1 to 5)\n" +
                                      "• [M]: Bet Max (5 coins) and immediately deal\n" +
                                      "• [V]: Toggle terminal visual mode (Classic 1984 Vegas CRT ↔ Cyber Neon)\n" +
                                      "• [G]: Open Game Selection terminal menu\n" +
                                      "• [D]: Double-Up High-Card Gamble after any win\n" +
                                      "• [C]: Collect / Cash Out, or insert 100 free credits\n" +
                                      "• [? / H]: Toggle this help modal\n" +
                                      "• [ESC]: Close modals"
                                font.pixelSize: 10
                                color: root.themeFg
                                lineHeight: 1.3
                            }

                            Text {
                                text: "THE 8 CASINO ENGINES"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeAccent
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "1. Jacks or Better: Pair of Jacks or better pays, 4000 jackpot.\n" +
                                      "2. Deuces Wild: Four 2s are wildcards, Four Deuces pays 200x.\n" +
                                      "3. Joker Poker: 53-card deck with 1 Joker, Kings or better min.\n" +
                                      "4. Double Double Bonus: 4 Aces with 2-4 kicker pays 400x!\n" +
                                      "5. Bonus Poker Deluxe: Flat 80:1 on any Four of a Kind.\n" +
                                      "6. Red Dog: Spread betting on 3rd card in-between.\n" +
                                      "7. Blackjack: 3:2 Natural Blackjack, Dealer stands on 17.\n" +
                                      "8. Casino War: High card showdown against dealer."
                                font.pixelSize: 10
                                color: root.themeSubtext
                                lineHeight: 1.3
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CANONICAL RETRO SPLASH SCREEN
        // =====================================================================
        SplashScreen {
            id: splashScreen
            anchors.fill: parent
            visible: root.splashEnabled && opacity > 0
            z: 1000
        }
    }
}
