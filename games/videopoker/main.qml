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
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool splashEnabled: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"

    readonly property string helpText:
        "★ GOAL & RULES\n" +
        "Bet coins (1 to 5) and deal a 5-card poker hand. Choose which cards to HOLD, then DRAW to replace unheld cards. Payoffs increase with higher rank hands. At 5 coins, Royal Flush pays the maximum 4000 jackpot!\n\n" +
        "★ 8 CASINO ENGINES\n" +
        "1. Jacks or Better: Pair of Jacks or better pays.\n" +
        "2. Deuces Wild: All four 2s are Wild. Four Deuces pays 200x.\n" +
        "3. Joker Poker: 53-card deck with 1 Joker. Kings or better min.\n" +
        "4. Double Double Bonus: 4 Aces with kicker pays up to 400x!\n" +
        "5. Bonus Poker Deluxe: Flat 80:1 on any Four of a Kind.\n" +
        "6. Red Dog: Card spread betting. In-between card pays up to 5:1.\n" +
        "7. Blackjack: 3:2 Natural Blackjack. Dealer stands on 17.\n" +
        "8. Casino War: Direct high-card duel against dealer.\n\n" +
        "★ KEYBOARD CONTROLS\n" +
        "• [SPACE] / [ENTER]: Deal / Draw / Table Action\n" +
        "• [1] - [5]: Toggle Hold on cards 1 through 5\n" +
        "• [B]: Increase coin bet (1 to 5)\n" +
        "• [X]: Bet Max (5 coins) and deal\n" +
        "• [Shift+F]: Toggle Full / Compact View\n" +
        "• [M]: Toggle Mute audio\n" +
        "• [G]: Open Game Selection menu (navigate with Arrows)\n" +
        "• [D]: Double-Up High-Card Gamble after any win\n" +
        "• [C]: Collect Double-Up pot / Cash out free credits\n" +
        "• [V]: Toggle Classic 1984 CRT ↔ Cyber Neon\n" +
        "• [? / H]: Toggle this Help & About window\n" +
        "• [ESC]: Close open windows"

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
    property int doubleUpChosenIndex: -1
    property string doubleUpOutcome: ""

    // Modals
    property bool gameMenuOpen: true
    property int menuSelectedIndex: 0
    readonly property int menuCols: (typeof menuFlickable !== "undefined" && menuFlickable && menuFlickable.height > 0 && menuFlickable.height < 230) ? 3 : 2

    onGameMenuOpenChanged: {
        if (gameMenuOpen) {
            for (var i = 0; i < gameList.length; i++) {
                if (gameList[i].id === activeGameId) {
                    menuSelectedIndex = i;
                    break;
                }
            }
        }
    }

    Timer {
        id: doubleUpCloseTimer
        interval: 1400
        repeat: false
        onTriggered: doubleUpActive = false
    }

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
            var targetY = Math.max(0, (winIdx * rowH) - Math.floor((paytableFlickable.height - 12) / 2));
            var maxScroll = Math.max(0, paytableFlickable.contentHeight - paytableFlickable.height);
            paytableFlickable.contentY = Math.min(maxScroll, targetY);
        }
    }

    function ensureMenuVisible() {
        if (typeof menuFlickable === "undefined" || !menuFlickable) return;
        var cols = root.menuCols;
        var row = Math.floor(menuSelectedIndex / cols);
        var spacing = (cols === 3) ? 6 : 8;
        var cardH = (cols === 3)
            ? Math.max(36, Math.min(46, Math.floor((menuFlickable.height - (spacing * 2)) / 3)))
            : Math.max(44, Math.min(54, Math.floor((menuFlickable.height - (spacing * 3)) / 4)));
        var rowH = cardH + spacing;
        var targetTop = row * rowH;
        var targetBottom = targetTop + cardH;
        if (targetTop < menuFlickable.contentY) {
            menuFlickable.contentY = Math.max(0, targetTop - 4);
        } else if (targetBottom > menuFlickable.contentY + menuFlickable.height) {
            var maxScroll = Math.max(0, menuFlickable.contentHeight - menuFlickable.height);
            menuFlickable.contentY = Math.min(maxScroll, targetBottom - menuFlickable.height + 4);
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

        // Initialize face-down cards
        var idleCards = [];
        var count = (gameId === "red_dog") ? 2 : (gameId === "blackjack" ? 2 : (gameId === "casino_war" ? 1 : 5));
        for (var i = 0; i < count; i++) {
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

        var liveEval = evaluateHand(playerHand);
        if (liveEval && liveEval.winCoins > 0) {
            winningEvaluation = liveEval;
            scrollToWinningRow();
        } else {
            winningEvaluation = null;
            resetPaytableScroll();
        }
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
        doubleUpChosenIndex = -1;
        doubleUpOutcome = "";
        doubleUpCurrentPot = lastWinAmount;
        doubleUpMessage = "PICK A HIGHER CARD TO DOUBLE! (KEYS 1-4 OR CLICK)";

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
        doubleUpChosenIndex = pickIndex;
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
            doubleUpOutcome = "WIN";
            doubleUpMessage = "YOU WIN! " + chosen.value + " BEATS " + doubleUpDealerCard.value + "! [D] TO DOUBLE AGAIN OR [C] TO COLLECT";
            playSound("win");
        } else if (playerRank === dealerRank) {
            doubleUpOutcome = "TIE";
            doubleUpMessage = "PUSH! " + chosen.value + " MATCHES " + doubleUpDealerCard.value + ". [D] TO TRY AGAIN OR [C] TO COLLECT";
            playSound("draw");
        } else {
            doubleUpOutcome = "LOSE";
            doubleUpMessage = "DEALER WINS: " + doubleUpDealerCard.value + " BEATS " + chosen.value + ". POT LOST!";
            credits -= lastWinAmount;
            lastWinAmount = 0;
            isWinningRound = false;
            playSound("lose");
            doubleUpCloseTimer.restart();
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
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_H || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
                event.accepted = true;
                return;
            }

            if (gameMenuOpen) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_G) {
                    gameMenuOpen = false;
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Up) {
                    var upCols = root.menuCols;
                    if (menuSelectedIndex >= upCols) menuSelectedIndex -= upCols;
                    playSound("select");
                    ensureMenuVisible();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Down) {
                    var downCols = root.menuCols;
                    if (menuSelectedIndex + downCols < gameList.length) {
                        menuSelectedIndex += downCols;
                    } else {
                        var curRow = Math.floor(menuSelectedIndex / downCols);
                        var maxRow = Math.floor((gameList.length - 1) / downCols);
                        if (curRow < maxRow) {
                            menuSelectedIndex = gameList.length - 1;
                        }
                    }
                    playSound("select");
                    ensureMenuVisible();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Left) {
                    if (menuSelectedIndex > 0) menuSelectedIndex -= 1;
                    playSound("select");
                    ensureMenuVisible();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right) {
                    if (menuSelectedIndex + 1 < gameList.length) menuSelectedIndex += 1;
                    playSound("select");
                    ensureMenuVisible();
                    event.accepted = true;
                    return;
                }
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
                    var numIdx = event.key - Qt.Key_1;
                    if (numIdx < gameList.length) {
                        menuSelectedIndex = numIdx;
                        switchGame(gameList[menuSelectedIndex].id);
                    }
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (menuSelectedIndex >= 0 && menuSelectedIndex < gameList.length) {
                        switchGame(gameList[menuSelectedIndex].id);
                    }
                    event.accepted = true;
                    return;
                }
                // Intercept all other keys while game selection menu is open
                event.accepted = true;
                return;
            }

            if (doubleUpActive) {
                if (!doubleUpResolved) {
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                        pickDoubleUpCard(event.key - Qt.Key_1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_C || event.key === Qt.Key_Escape) {
                        collectDoubleUp();
                        event.accepted = true;
                        return;
                    }
                } else {
                    if ((doubleUpOutcome === "WIN" || doubleUpOutcome === "TIE") && (event.key === Qt.Key_D)) {
                        startDoubleUp();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_C || event.key === Qt.Key_Escape || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        collectDoubleUp();
                        event.accepted = true;
                        return;
                    }
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
            } else if (event.key === Qt.Key_X) {
                setMaxBet();
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }
 else if (event.key === Qt.Key_V) {
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
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, statRow.height))

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
                    color: root.themeCardBg
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
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: root.isTiledDesktopMode ? 0 : 30

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
                            font.family: root.monoFontFamily
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
                    text: "🎰 VideoPoker"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + ("CREDITS: " + root.credits)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("BET: " + root.bet) + ")"
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
            }
        }

        id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 8
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
                        id: paytableRect
                        width: parent.width
                        // Dynamically give way to the card playfield:
                        // Keeps at least playArea.cardH + statusBannerRect.height + margins for the cards!
                        height: Math.max(34, Math.min(135, boardContainer.height - playArea.cardH - 22 - 32))
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
                                height: Math.max(13, paytableRect.height - 21)
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
                            anchors.margins: (paytableRect.height <= 44) ? 2 : 6
                            visible: !root.isPokerGame

                            Column {
                                anchors.centerIn: parent
                                spacing: (paytableRect.height <= 44) ? 1 : 4
                                width: parent.width

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (activeGameId === "red_dog") return "RED DOG SPREAD PAYOUTS";
                                        if (activeGameId === "blackjack") return "SINGLE-DECK BLACKJACK (PAYS 3:2)";
                                        return "CASINO WAR (HIGH CARD WINS 1:1)";
                                    }
                                    font.family: root.monoFontFamily
                                    font.pixelSize: (paytableRect.height <= 44) ? 9 : 10
                                    font.bold: true
                                    color: isCyberMode ? root.neonCyan : "#FEF08A"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: {
                                        if (activeGameId === "red_dog") {
                                            return "Spread 1: 5:1 • Spread 2: 4:1 • Spread 3: 2:1 • Spread 4-11: 1:1 • Pair: 11:1";
                                        }
                                        if (activeGameId === "blackjack") {
                                            return "Dealer stands on all 17s • Double Down on any 2 cards • 52-card deck";
                                        }
                                        return "Aces high • Tie: Go to War (double bet, win 1:1) or Surrender (lose 50%)";
                                    }
                                    font.pixelSize: (paytableRect.height <= 44) ? 8 : 9
                                    color: isCyberMode ? "#94A3B8" : "#E2E8F0"
                                }
                            }
                        }
                    }

                    // 2. Status Message Banner
                    Rectangle {
                        id: statusBannerRect
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
                        id: cardPlayfield
                        width: parent.width
                        height: Math.max(playArea.cardH + 8, parent.height - paytableRect.height - statusBannerRect.height - (parent.spacing * 2))

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
                                        text: (machineState === "IDLE") ? "—" : redDogSpread.toString()
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: isCyberMode ? root.neonMagenta : "#FEF08A"
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (machineState === "IDLE") ? "IN-BETWEEN" : (redDogStatus === "pair" ? "PAIR" : (redDogStatus === "consecutive" ? "PUSH" : ("PAYS " + (Engine.getRedDogPayoutRate ? Engine.getRedDogPayoutRate(redDogSpread) : 1) + ":1")))
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
                    visible: !root.isPokerGame
                    opacity: (machineState === "DEALT") ? 1.0 : 0.45

                    // Action 1
                    Rectangle {
                        width: (parent.width - 16) / 2
                        height: 28
                        radius: 4
                        color: (machineState === "DEALT") ? (isCyberMode ? "#0369A1" : "#0284C7") : (isCyberMode ? "#0A192F" : "#1E293B")
                        border.color: (machineState === "DEALT") ? (isCyberMode ? root.neonCyan : "#38BDF8") : (isCyberMode ? "#1E293B" : "#475569")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (activeGameId === "red_dog") return "CALL [1]";
                                if (activeGameId === "blackjack") return "HIT [1]";
                                return "SURRENDER [1]";
                            }
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: (machineState === "DEALT") ? "#FFFFFF" : (isCyberMode ? "#64748B" : "#94A3B8")
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: (machineState === "DEALT") ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: (machineState === "DEALT")
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
                        color: (machineState === "DEALT") ? (isCyberMode ? root.neonMagenta : "#D97706") : (isCyberMode ? "#1A0B2E" : "#1E293B")
                        border.color: (machineState === "DEALT") ? (isCyberMode ? "#FFB6D9" : "#FDE68A") : (isCyberMode ? "#1E293B" : "#475569")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (activeGameId === "red_dog") return "RAISE 2X [2]";
                                if (activeGameId === "blackjack") return "STAND [2]";
                                return "GO TO WAR [2]";
                            }
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: (machineState === "DEALT") ? "#FFFFFF" : (isCyberMode ? "#64748B" : "#94A3B8")
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: (machineState === "DEALT") ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: (machineState === "DEALT")
                            onClicked: {
                                if (activeGameId === "red_dog") resolveRedDog(true);
                                else if (activeGameId === "blackjack") blackjackStand();
                                else warGoToWar();
                            }
                        }
                    }
                }

                // ROW B: BET & DEAL ACTIONS (Integrated In-Machine Console)
                Row {
                    width: parent.width
                    height: 32
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter

                    readonly property bool showDouble: isWinningRound && lastWinAmount > 0 && !doubleUpActive
                    readonly property real availW: parent.width - (showDouble ? 20 : 15)

                    // GAMES [G] (Cabinet Touch Button)
                    Rectangle {
                        width: Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.22))
                        height: 30
                        radius: 4
                        color: isCyberMode ? "#1E1B4B" : "#1E3A8A"
                        border.color: isCyberMode ? root.neonPurple : "#60A5FA"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "GAMES [G]"
                            font.family: root.monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            color: isCyberMode ? "#C084FC" : "#FEF08A"
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                gameMenuOpen = true;
                                playSound("select");
                            }
                        }
                    }

                    // Double-Up Trigger Button (when winning)
                    Rectangle {
                        width: Math.floor(parent.availW * 0.22)
                        height: 30
                        radius: 4
                        visible: parent.showDouble
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
                        width: Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.24))
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
                        width: Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.24))
                        height: 30
                        radius: 4
                        color: isCyberMode ? "#1E1035" : "#CA8A04"
                        border.color: isCyberMode ? root.neonPurple : "#FEF08A"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "MAX [X]"
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
                        width: parent.availW - (Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.22)) + (parent.showDouble ? Math.floor(parent.availW * 0.22) : 0) + Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.24)) + Math.floor(parent.availW * (parent.showDouble ? 0.18 : 0.24)))
                        height: 30
                        radius: 4
                        color: isCyberMode ? root.neonCyan : "#16A34A"
                        border.color: isCyberMode ? "#E0F2FE" : "#86EFAC"
                        border.width: 1.5
                        opacity: (!isPokerGame && machineState === "DEALT") ? 0.4 : 1.0

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
                            cursorShape: (!isPokerGame && machineState === "DEALT") ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: (isPokerGame || machineState !== "DEALT")
                            onClicked: handlePrimaryAction()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // DOUBLE-UP GAMBLE OVERLAY (Contained within Game Playing Area Screen)
        // =====================================================================
        Rectangle {
            id: doubleUpModal
            anchors.fill: playArea
            radius: isCyberMode ? 8 : 10
            clip: true
            color: isCyberMode ? "#090D1C" : "#000066"
            border.color: isCyberMode ? root.neonCyan : "#FEF08A"
            border.width: 3
            visible: doubleUpActive
            z: 800

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 1. Header Bar
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "★ DOUBLE-OR-NOTHING BONUS ★"
                        font.family: root.monoFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: isCyberMode ? root.neonCyan : "#FEF08A"
                    }

                    // Collect Button (Docked right, no overlap!)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        height: 24
                        radius: 3
                        color: collectMouse.containsMouse ? "#EF4444" : "#DC2626"
                        border.color: "#FFFFFF"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "COLLECT [C]"
                            font.family: root.monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            id: collectMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: collectDoubleUp()
                        }
                    }
                }

                // 2. Stakes HUD Marquee
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 3
                    color: isCyberMode ? "#111827" : "#000033"
                    border.color: isCyberMode ? root.neonPurple : "#38BDF8"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "CURRENT POT: " + doubleUpCurrentPot
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: isCyberMode ? "#C084FC" : "#FBBF24"
                        }
                        Text {
                            text: "➔"
                            font.pixelSize: 11
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                        }
                        Text {
                            text: "DOUBLE: " + (doubleUpCurrentPot * 2)
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                        }
                    }
                }

                // 3. Status Announcement Banner
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 3
                    color: {
                        if (!doubleUpResolved) return isCyberMode ? "#1E1B4B" : "#1E3A8A";
                        if (doubleUpOutcome === "WIN") return "#14532D";
                        if (doubleUpOutcome === "TIE") return "#0C4A6E";
                        return "#7F1D1D";
                    }
                    border.color: {
                        if (!doubleUpResolved) return isCyberMode ? root.neonCyan : "#60A5FA";
                        if (doubleUpOutcome === "WIN") return "#22C55E";
                        if (doubleUpOutcome === "TIE") return "#38BDF8";
                        return "#EF4444";
                    }
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: doubleUpMessage
                        font.family: root.monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: {
                            if (!doubleUpResolved) return isCyberMode ? "#E0E7FF" : "#FEF08A";
                            if (doubleUpOutcome === "WIN") return "#86EFAC";
                            if (doubleUpOutcome === "TIE") return "#BAE6FD";
                            return "#FCA5A5";
                        }
                    }
                }

                // 4. Card Arena (Dealer Pedestal vs 4 Player Picks)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    // DEALER PEDESTAL
                    Column {
                        spacing: 3

                        Text {
                            text: "DEALER"
                            font.family: root.monoFontFamily
                            font.pixelSize: 8
                            font.bold: true
                            color: isCyberMode ? root.neonCyan : "#FEF08A"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Rectangle {
                            width: 66
                            height: 94
                            radius: 4
                            color: isCyberMode ? "#0F172A" : "#000044"
                            border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                            border.width: 1.5

                            PlayingCard {
                                anchors.fill: parent
                                cardData: doubleUpDealerCard
                                visualMode: root.visualMode
                            }
                        }

                        Rectangle {
                            width: 66
                            height: 16
                            radius: 2
                            color: isCyberMode ? "#1E293B" : "#000044"
                            border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "TO BEAT"
                                font.family: root.monoFontFamily
                                font.pixelSize: 8
                                font.bold: true
                                color: isCyberMode ? root.neonCyan : "#FEF08A"
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: 1
                        height: 114
                        color: isCyberMode ? "#334155" : "#1E3A8A"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 4 PLAYER PICK CARDS
                    Column {
                        spacing: 3

                        Text {
                            text: doubleUpResolved ? "REVEALED CARDS" : "CHOOSE 1 CARD (KEYS 1-4 OR CLICK):"
                            font.family: root.monoFontFamily
                            font.pixelSize: 8
                            font.bold: true
                            color: isCyberMode ? root.neonMagenta : "#FEF08A"
                        }

                        Row {
                            spacing: 6

                            Repeater {
                                model: doubleUpPlayerCards
                                Column {
                                    spacing: 3

                                    Rectangle {
                                        id: pickCardBox
                                        width: 66
                                        height: 94
                                        radius: 4
                                        color: "transparent"
                                        border.color: {
                                            if (doubleUpResolved && index === doubleUpChosenIndex) {
                                                return (doubleUpOutcome === "WIN") ? "#22C55E" : (doubleUpOutcome === "TIE" ? "#38BDF8" : "#EF4444");
                                            }
                                            return pickCardArea.containsMouse && !doubleUpResolved ? (isCyberMode ? root.neonCyan : "#FEF08A") : "transparent";
                                        }
                                        border.width: (doubleUpResolved && index === doubleUpChosenIndex) ? 2.5 : (pickCardArea.containsMouse ? 1.5 : 0)

                                        PlayingCard {
                                            anchors.fill: parent
                                            cardData: modelData
                                            visualMode: root.visualMode
                                            isWinning: doubleUpResolved && (index === doubleUpChosenIndex) && (doubleUpOutcome === "WIN")
                                        }

                                        MouseArea {
                                            id: pickCardArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: (!doubleUpResolved) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: pickDoubleUpCard(index)
                                        }
                                    }

                                    // Badge / Key Indicator
                                    Rectangle {
                                        width: 66
                                        height: 16
                                        radius: 2
                                        color: (doubleUpResolved && index === doubleUpChosenIndex) ? (doubleUpOutcome === "WIN" ? "#16A34A" : "#991B1B") : (isCyberMode ? "#111827" : "#000044")
                                        border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: (doubleUpResolved && index === doubleUpChosenIndex) ? "YOUR PICK" : ("[ " + (index + 1) + " ]")
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 5. Bottom Action Controls
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: doubleUpResolved && (doubleUpOutcome === "WIN" || doubleUpOutcome === "TIE")

                    Rectangle {
                        width: 150
                        height: 30
                        radius: 4
                        color: isCyberMode ? root.neonMagenta : "#16A34A"
                        border.color: "#FFFFFF"
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "DOUBLE AGAIN [D]"
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

                    Rectangle {
                        width: 150
                        height: 30
                        radius: 4
                        color: isCyberMode ? "#1E1035" : "#D97706"
                        border.color: isCyberMode ? root.neonPurple : "#FEF08A"
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "COLLECT [C]"
                            font.family: root.monoFontFamily
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
            }
        }

        // =====================================================================
        // GAMES SELECTOR (Contained within Game Playing Area Screen)
        // =====================================================================
        Rectangle {
            id: gameSelectModal
            anchors.fill: playArea
            radius: isCyberMode ? 8 : 10
            clip: true
            color: isCyberMode ? "#0A0F1E" : "#000088"
            border.color: isCyberMode ? root.neonCyan : "#FEF08A"
            border.width: isCyberMode ? 2 : 3
            visible: gameMenuOpen
            z: 850

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Modal Header
                Item {
                    width: parent.width
                    height: 26

                    Text {
                        anchors.centerIn: parent
                        text: "SELECT A GAME"
                        font.family: root.monoFontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: isCyberMode ? root.neonCyan : "#FEF08A"
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        height: 24
                        radius: 3
                        color: isCyberMode ? (closeGameMenuArea.containsMouse ? root.neonCyan : "#1E293B") : (closeGameMenuArea.containsMouse ? "#FEF08A" : "#D97706")
                        border.color: isCyberMode ? root.neonCyan : "#FEF08A"
                        border.width: 1

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1.5
                            radius: 2
                            color: isCyberMode ? "#0A0F1D" : "#7F1D1D"

                            Text {
                                anchors.centerIn: parent
                                text: "EXIT [ESC]"
                                font.family: root.monoFontFamily
                                font.pixelSize: 8
                                font.bold: true
                                color: isCyberMode ? root.neonCyan : "#FEF08A"
                            }
                        }

                        MouseArea {
                            id: closeGameMenuArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: gameMenuOpen = false
                        }
                    }
                }

                // 3D Beveled Touch Buttons Grid (IGT Game King Style - 3 Columns, Zero Scroll)
                Flickable {
                    id: menuFlickable
                    width: parent.width
                    height: Math.max(100, parent.height - 62)
                    contentHeight: gameGrid.implicitHeight
                    clip: true

                    Grid {
                        id: gameGrid
                        width: parent.width
                        columns: root.menuCols
                        spacing: root.menuCols === 3 ? 6 : 8

                        Repeater {
                            model: gameList
                            Rectangle {
                                id: gameCardItem
                                width: Math.floor((gameGrid.width - (gameGrid.spacing * (root.menuCols - 1))) / root.menuCols)
                                height: root.menuCols === 3
                                    ? Math.max(36, Math.min(46, Math.floor((menuFlickable.height - (gameGrid.spacing * 2)) / 3)))
                                    : Math.max(44, Math.min(54, Math.floor((menuFlickable.height - (gameGrid.spacing * 3)) / 4)))
                                radius: 4
                                readonly property bool isSel: (menuSelectedIndex === index)
                                readonly property bool isCurActive: (activeGameId === modelData.id)
                                readonly property bool isHov: btnMouseArea.containsMouse

                                // Green selection highlight border (exact IGT machine style)
                                color: isSel ? "#22C55E" : (isCurActive ? (isCyberMode ? root.neonCyan : "#FEF08A") : (isCyberMode ? (isHov ? root.neonCyan : "#1E293B") : (isHov ? "#FEF08A" : "#D97706")))

                                // Outer Beveled Rim
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: isSel ? 2.5 : 1.5
                                    radius: 3
                                    color: isCyberMode ? (isSel ? "#00F0FF33" : "#0F172A") : (isSel ? "#FEF08A" : "#F59E0B")

                                    // Inner Button Face
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: isCyberMode ? 1 : 2
                                        radius: 2
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: isCyberMode ? (gameCardItem.isSel ? "#1E293B" : "#0A0F1D") : (gameCardItem.isSel ? "#DC2626" : (gameCardItem.isHov ? "#B91C1C" : "#991B1B"))
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: isCyberMode ? (gameCardItem.isSel ? "#0F172A" : "#030712") : (gameCardItem.isSel ? "#991B1B" : (gameCardItem.isHov ? "#881337" : "#7F1D1D"))
                                            }
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            width: parent.width - 6

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: (modelData.type === "poker" ? "VIDEO POKER" : "TABLE GAME") + (gameCardItem.isCurActive ? " ★" : "")
                                                font.family: root.monoFontFamily
                                                font.pixelSize: 8
                                                font.bold: true
                                                color: gameCardItem.isSel ? "#86EFAC" : (isCyberMode ? root.neonCyan : "#FEF08A")
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.name
                                                font.family: root.monoFontFamily
                                                font.pixelSize: root.menuCols === 3 ? Math.max(8, Math.min(10, Math.round(gameCardItem.width * 0.046))) : Math.max(9, Math.min(12, Math.round(gameCardItem.width * 0.052)))
                                                font.bold: true
                                                color: "#FFFFFF"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btnMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: menuSelectedIndex = index
                                    onClicked: {
                                        menuSelectedIndex = index;
                                        switchGame(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Arcade Prompt (Exact IGT Casino Legend)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ARROWS: NAVIGATE  •  [ENTER]: SELECT GAME  •  [ESC]: CLOSE"
                    font.family: root.monoFontFamily
                    font.pixelSize: 9
                    font.bold: true
                    color: isCyberMode ? root.neonCyan : "#FEF08A"
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS: HELP & ABOUT (Template Standard)
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
                height: Math.min(parent.height * 0.90, 480)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                MouseArea {
                    anchors.fill: parent
                }

                // Close Button in top-right corner
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    width: 28
                    height: 28
                    radius: 4
                    color: closeHelpMouse.containsMouse ? root.themeBorder : "transparent"
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        font.bold: true
                        color: root.themeSubtext
                    }
                    MouseArea {
                        id: closeHelpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = false
                    }
                }

                Column {
                    id: helpCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Text {
                        text: "HOW TO PLAY"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - 110
                        contentHeight: helpContentCol.implicitHeight
                        clip: true

                        Column {
                            id: helpContentCol
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width
                                text: root.helpText
                                font.pixelSize: 11
                                color: root.themeFg
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
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
        // CANONICAL RETRO SPLASH SCREEN
        // =====================================================================
                // =====================================================================
        // FLOATING SOUND TOAST NOTIFICATION
        // =====================================================================
        Rectangle {
            id: soundToast
            z: 1100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(16, root.height * 0.05)
            width: toastText.implicitWidth + 36
            height: 38
            radius: 19
            color: root.themeCardBg
            border.color: root.themeAccent
            border.width: 1.5
            opacity: 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: ""
                font.pixelSize: 13
                font.bold: true
                color: root.themeFg
            }

            Timer {
                id: toastTimer
                interval: 1200
                repeat: false
                onTriggered: soundToast.opacity = 0
            }

            function show(msg) {
                toastText.text = msg;
                soundToast.opacity = 0.95;
                toastTimer.restart();
            }
        }

        SplashScreen {
            id: splashScreen
            anchors.fill: parent
            visible: root.splashEnabled && opacity > 0
            z: 1000
        }
    }
}
