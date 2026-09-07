import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "Themes.js" as Themes
import "TerminalEngine.js" as Engine

ApplicationWindow {
    id: root
    width: 1040
    height: 760
    minimumWidth: 920
    minimumHeight: 680
    visible: true
    title: "Omarchy Arcade • Video Terminal (OA-025)"
    color: isCrtMode ? "#000044" : theme.bg

    // =========================================================================
    // CONFIGURATION & PERSISTENCE
    // =========================================================================
    property bool splashEnabled: true
    property string forcedTheme: ""
    property string visualMode: "crt" // "crt" (1984 Vegas) or "cyber" (Neo-Tokyo Glass)
    property string activeGameId: "jacks_or_better"
    onActiveGameIdChanged: setupGame(activeGameId)
    property string deckStyle: "synthwave"
    property bool soundMuted: false

    readonly property bool isCrtMode: visualMode === "crt"
    readonly property var theme: Themes.getTheme(forcedTheme)

    // Machine Credits & Bets
    property int credits: 1000
    property int betCoins: 1 // 1..5
    property int lastWinAmount: 0
    property int bestWin: 0
    property int handsPlayed: 0

    // Master Game State
    // "IDLE", "DEALT", "DRAWING", "GAMBLE_OFFERED", "GAMBLE_PLAYING", "ROUND_OVER"
    property string machineState: "IDLE"
    property string statusMessage: "INSERT COIN OR PRESS DEAL TO PLAY"

    // Active Deck & Hands
    property var activeDeck: []
    property var playerHand: []      // Array of card objects
    property var dealerHand: []      // For Blackjack / War
    property var winningEvaluation: null // { key, name, rankLevel }
    property bool isWinningRound: false

    // Game-specific State
    // Red Dog
    property int redDogSpread: 0
    property string redDogStatus: "" // "spread", "consecutive", "pair"
    property int redDogRaiseBet: 0

    // Blackjack
    property int playerTotal: 0
    property int dealerTotal: 0
    property bool playerCanDouble: false

    // Casino War
    property string warState: "" // "tie", "war_dealt"
    property int warExtraBet: 0

    // Double-Up Gamble
    property bool doubleUpActive: false
    property var doubleUpDealerCard: null
    property var doubleUpPlayerCards: []
    property int doubleUpCurrentPot: 0
    property string doubleUpMessage: ""
    property bool doubleUpResolved: false

    // Modals
    property bool gameMenuOpen: false
    property bool helpModalOpen: false

    // =========================================================================
    // INITIALIZATION & SETTINGS
    // =========================================================================
    Component.onCompleted: {
        if (typeof settingsManager !== "undefined") {
            credits = settingsManager.getCredits();
            bestWin = settingsManager.getBestWin();
            handsPlayed = settingsManager.getHandsPlayed();
            var savedMode = settingsManager.getVisualMode();
            if (savedMode) visualMode = savedMode;
            var savedGame = settingsManager.getGameMode();
            if (savedGame) activeGameId = savedGame;
        }
        setupGame(activeGameId);
    }

    function saveSettings() {
        if (typeof settingsManager !== "undefined") {
            settingsManager.setCredits(credits);
            settingsManager.setBestWin(bestWin);
            settingsManager.setHandsPlayed(handsPlayed);
            settingsManager.setVisualMode(visualMode);
            settingsManager.setGameMode(activeGameId);
        }
    }

    function playAudio(soundName) {
        if (!soundMuted && typeof soundManager !== "undefined") {
            soundManager.playSound(soundName);
        }
    }

    // Screenshot helper for automated test suites
    function captureScreenshot(filePath, shouldExit) {
        var targetItem = cabinetBackground;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            if (shouldExit) {
                Qt.quit();
            }
        });
    }

    // =========================================================================
    // GAME REGISTRY METADATA
    // =========================================================================
    readonly property var gameList: [
        { id: "jacks_or_better", name: "JACKS OR BETTER", type: "poker", desc: "9/6 Full Pay Classic Video Poker. Pair of Jacks pays." },
        { id: "deuces_wild", name: "DEUCES WILD", type: "poker", desc: "All 2s are Wildcards! Natural Royal pays 800x, 4 Deuces pays 200x." },
        { id: "joker_poker", name: "JOKER POKER", type: "poker", desc: "53-Card Deck with 1 Joker. Kings or Better minimum pay." },
        { id: "double_double_bonus", name: "DOUBLE DOUBLE BONUS", type: "poker", desc: "Massive quad payouts! 4 Aces with 2-4 kicker pays 400x." },
        { id: "bonus_poker_deluxe", name: "BONUS POKER DELUXE", type: "poker", desc: "High-octane flat 80:1 jackpot for any Four of a Kind!" },
        { id: "red_dog", name: "RED DOG (IN-BETWEEN)", type: "table", desc: "Classic Acey-Deucey. Bet whether 3rd card lands between the first two." },
        { id: "blackjack", name: "SINGLE-DECK BLACKJACK", type: "table", desc: "Casino 3:2 Natural Blackjack. Dealer hits soft 16, stands on 17." },
        { id: "casino_war", name: "CASINO WAR", type: "table", desc: "High card wins. Ties offer 1:1 War Showdown or Surrender." }
    ]

    function getActiveGameMeta() {
        for (var i = 0; i < gameList.length; i++) {
            if (gameList[i].id === activeGameId) return gameList[i];
        }
        return gameList[0];
    }

    readonly property bool isPokerGame: {
        var meta = getActiveGameMeta();
        return meta && meta.type === "poker";
    }

    // =========================================================================
    // SWITCH GAMES
    // =========================================================================
    function switchGame(gameId) {
        if (machineState === "DEALT" || machineState === "DRAWING" || doubleUpActive) {
            // Can't switch mid-hand
            return;
        }
        activeGameId = gameId;
        gameMenuOpen = false;
        setupGame(gameId);
        saveSettings();
        playAudio("select");
    }

    function isPoker(id) {
        return id === "jacks_or_better" || id === "deuces_wild" || id === "joker_poker" ||
               id === "double_double_bonus" || id === "bonus_poker_deluxe";
    }

    function setupGame(gameId) {
        machineState = "IDLE";
        lastWinAmount = 0;
        winningEvaluation = null;
        isWinningRound = false;
        dealerHand = [];
        doubleUpActive = false;

        if (activeDeck.length < 15) {
            activeDeck = (gameId === "joker_poker") ? Engine.createJokerDeck() : Engine.createStandardDeck();
            activeDeck = Engine.shuffle(activeDeck);
        }

        if (isPoker(gameId)) {
            // Setup 5 blank or face-down demo cards
            var sample = [];
            for (var i = 0; i < 5; i++) {
                sample.push({
                    value: "A", suit: "♠", isRed: false, faceUp: false, held: false, isWild: false
                });
            }
            playerHand = sample;
            statusMessage = "PRESS DEAL OR BET TO START (" + getActiveGameMeta().name + ")";
        } else if (gameId === "red_dog") {
            playerHand = [
                { value: "?", suit: "♠", isRed: false, faceUp: false },
                { value: "?", suit: "♠", isRed: false, faceUp: false }
            ];
            redDogSpread = 0;
            redDogStatus = "";
            statusMessage = "RED DOG: PLACE BET AND PRESS DEAL";
        } else if (gameId === "blackjack") {
            dealerHand = [
                { value: "?", suit: "♠", isRed: false, faceUp: false },
                { value: "?", suit: "♠", isRed: false, faceUp: false }
            ];
            playerHand = [
                { value: "?", suit: "♠", isRed: false, faceUp: false },
                { value: "?", suit: "♠", isRed: false, faceUp: false }
            ];
            playerTotal = 0;
            dealerTotal = 0;
            statusMessage = "BLACKJACK: PLACE BET (1-5 COINS) AND PRESS DEAL";
        } else if (gameId === "casino_war") {
            dealerHand = [{ value: "?", suit: "♠", isRed: false, faceUp: false }];
            playerHand = [{ value: "?", suit: "♠", isRed: false, faceUp: false }];
            warState = "";
            statusMessage = "CASINO WAR: PLACE BET AND PRESS DEAL";
        }
    }

    // =========================================================================
    // BETTING CONTROLS
    // =========================================================================
    function increaseBet() {
        if (machineState !== "IDLE" && machineState !== "ROUND_OVER") return;
        if (betCoins >= 5) {
            betCoins = 1;
        } else {
            betCoins++;
        }
        playAudio("chip");
    }

    function setMaxBet() {
        if (machineState !== "IDLE" && machineState !== "ROUND_OVER") return;
        betCoins = 5;
        playAudio("chip");
        // In classic casino terminals, hitting BET MAX immediately deals!
        startDeal();
    }

    // =========================================================================
    // MASTER DEAL / ACTION DISPATCHER
    // =========================================================================
    function handlePrimaryAction() {
        if (doubleUpActive) {
            collectDoubleUp();
            return;
        }

        if (isPokerGame) {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                startDeal();
            } else if (machineState === "DEALT") {
                drawCards();
            }
        } else if (activeGameId === "red_dog") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealRedDog();
            } else if (machineState === "DEALT") {
                // Call by default if pressed
                resolveRedDog(false);
            }
        } else if (activeGameId === "blackjack") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealBlackjack();
            } else if (machineState === "DEALT") {
                blackjackHit();
            }
        } else if (activeGameId === "casino_war") {
            if (machineState === "IDLE" || machineState === "ROUND_OVER") {
                dealCasinoWar();
            }
        }
    }

    // =========================================================================
    // VIDEO POKER LOGIC (GAMES 1-5)
    // =========================================================================
    function startDeal() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS! INSERT COIN (C)";
            playAudio("bust");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        lastWinAmount = 0;
        winningEvaluation = null;
        isWinningRound = false;
        doubleUpActive = false;

        // Fresh shuffled deck
        activeDeck = (activeGameId === "joker_poker") ? Engine.createJokerDeck() : Engine.createStandardDeck();
        activeDeck = Engine.shuffle(activeDeck);

        // Deal 5 cards
        var hand = [];
        for (var i = 0; i < 5; i++) {
            var c = activeDeck.pop();
            c.faceUp = true;
            c.held = false;
            // Mark wild if Deuces Wild
            if (activeGameId === "deuces_wild" && c.rank === 2) {
                c.isWild = true;
                c.isDeuce = true;
            }
            hand.push(c);
        }
        playerHand = hand;
        machineState = "DEALT";
        statusMessage = "SELECT CARDS TO HOLD (1-5), THEN PRESS DRAW";
        playAudio("card_slide");

        // Preliminary hand check
        var evalRes = Engine.evaluateHand(activeGameId, playerHand);
        if (evalRes) {
            statusMessage = evalRes.name + " DEALT! HOLD CARDS AND DRAW";
        }
    }

    function toggleHold(index) {
        if (machineState !== "DEALT" || !isPokerGame) return;
        if (index < 0 || index >= playerHand.length) return;

        var list = [];
        for (var i = 0; i < playerHand.length; i++) {
            var card = playerHand[i];
            if (i === index) {
                card.held = !card.held;
            }
            list.push(card);
        }
        playerHand = list;
        playAudio(playerHand[index].held ? "click" : "undo");
    }

    function drawCards() {
        if (machineState !== "DEALT" || !isPokerGame) return;
        machineState = "DRAWING";

        var list = [];
        for (var i = 0; i < playerHand.length; i++) {
            var card = playerHand[i];
            if (!card.held) {
                var newCard = activeDeck.pop();
                newCard.faceUp = true;
                newCard.held = false;
                if (activeGameId === "deuces_wild" && newCard.rank === 2) {
                    newCard.isWild = true;
                    newCard.isDeuce = true;
                }
                list.push(newCard);
            } else {
                list.push(card);
            }
        }
        playerHand = list;
        playAudio("card_flip");

        // Evaluate Hand
        var evalRes = Engine.evaluateHand(activeGameId, playerHand);
        winningEvaluation = evalRes;

        if (evalRes) {
            var payout = Engine.getPayout(activeGameId, evalRes.key, betCoins);
            lastWinAmount = payout;
            credits += payout;
            if (payout > bestWin) bestWin = payout;
            isWinningRound = true;
            statusMessage = evalRes.name + "! WIN " + payout + " COINS!";
            playAudio((evalRes.key === "royal_flush" || evalRes.key === "natural_royal_flush") ? "blackjack" : "win");
            machineState = "ROUND_OVER";
        } else {
            lastWinAmount = 0;
            isWinningRound = false;
            statusMessage = "GAME OVER - NO WINNING COMBINATION";
            playAudio("bust");
            machineState = "ROUND_OVER";
        }
        saveSettings();
    }

    // =========================================================================
    // GAME 6: RED DOG (IN-BETWEEN)
    // =========================================================================
    function dealRedDog() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS!";
            playAudio("bust");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        lastWinAmount = 0;
        winningEvaluation = null;
        isWinningRound = false;
        doubleUpActive = false;
        redDogRaiseBet = 0;

        activeDeck = Engine.shuffle(Engine.createStandardDeck());
        var dealRes = Engine.initRedDogDeal(activeDeck);
        activeDeck = dealRes.remainingDeck;

        redDogSpread = dealRes.spread;
        redDogStatus = dealRes.status;

        var c1 = dealRes.card1;
        var c2 = dealRes.card2;
        c1.faceUp = true;
        c2.faceUp = true;
        playerHand = [c1, c2];

        playAudio("card_slide");

        if (redDogStatus === "consecutive") {
            // Automatic push
            credits += betCoins;
            statusMessage = "CONSECUTIVE CARDS! PUSH - BET RETURNED";
            machineState = "ROUND_OVER";
            playAudio("undo");
        } else if (redDogStatus === "pair") {
            statusMessage = "PAIR DEALT! DRAWING 3RD CARD FOR 11:1 PAYOUT...";
            machineState = "DEALT";
            // Auto draw 3rd card
            QTimer.singleShot(800, function() {
                resolveRedDog(false);
            });
        } else {
            // Spread between 1 and 11
            var multStr = "1:1";
            if (redDogSpread === 1) multStr = "5:1";
            else if (redDogSpread === 2) multStr = "4:1";
            else if (redDogSpread === 3) multStr = "2:1";

            statusMessage = "SPREAD IS " + redDogSpread + " (PAYS " + multStr + "). CALL OR RAISE?";
            machineState = "DEALT";
        }
        saveSettings();
    }

    function resolveRedDog(didRaise) {
        if (machineState !== "DEALT" || activeGameId !== "red_dog") return;

        var totalBet = betCoins;
        if (didRaise) {
            if (credits >= betCoins) {
                credits -= betCoins;
                redDogRaiseBet = betCoins;
                totalBet = betCoins * 2;
                playAudio("chip");
            }
        }

        var c3 = activeDeck.pop();
        c3.faceUp = true;

        var pList = [playerHand[0], playerHand[1], c3];
        playerHand = pList;
        playAudio("card_flip");

        var res = Engine.resolveRedDogThirdCard(playerHand[0], playerHand[1], c3, redDogSpread, redDogStatus);

        if (res.result === "win") {
            var won = totalBet + (totalBet * res.multiplier);
            credits += won;
            lastWinAmount = won;
            isWinningRound = true;
            statusMessage = res.desc + "! WON " + won + " COINS!";
            playAudio("win");
        } else if (res.result === "push") {
            credits += totalBet;
            statusMessage = res.desc + " - BET RETURNED";
            playAudio("undo");
        } else {
            lastWinAmount = 0;
            isWinningRound = false;
            statusMessage = res.desc + " - DEALER WINS";
            playAudio("bust");
        }

        machineState = "ROUND_OVER";
        saveSettings();
    }

    // =========================================================================
    // GAME 7: SINGLE-DECK BLACKJACK
    // =========================================================================
    function dealBlackjack() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS!";
            playAudio("bust");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        lastWinAmount = 0;
        winningEvaluation = null;
        isWinningRound = false;
        doubleUpActive = false;
        playerCanDouble = (credits >= betCoins);

        activeDeck = Engine.shuffle(Engine.createStandardDeck());
        var res = Engine.initBlackjackDeal(activeDeck);
        activeDeck = res.remainingDeck;

        playerHand = res.playerHand;
        dealerHand = res.dealerHand;
        playAudio("card_slide");

        playerTotal = Engine.calculateBlackjackTotal(playerHand);
        dealerTotal = Engine.calculateBlackjackTotal([dealerHand[0]]); // Upcard only

        if (res.isNaturalBlackjack) {
            // Check dealer hole card
            dealerHand[1].faceUp = true;
            dealerTotal = Engine.calculateBlackjackTotal(dealerHand);
            if (dealerTotal === 21) {
                // Push
                credits += betCoins;
                statusMessage = "BOTH HAVE BLACKJACK! PUSH - BET RETURNED";
                playAudio("undo");
            } else {
                // Natural 3:2 win! (e.g. bet 5 pays 7.5 -> rounded 8, or bet*2.5)
                var payout = betCoins + Math.round(betCoins * 1.5);
                credits += payout;
                lastWinAmount = payout;
                isWinningRound = true;
                statusMessage = "BLACKJACK! PAYS 3:2! WON " + payout + " COINS!";
                playAudio("blackjack");
            }
            machineState = "ROUND_OVER";
        } else {
            statusMessage = "HIT, STAND, OR DOUBLE DOWN? (TOTAL: " + playerTotal + ")";
            machineState = "DEALT";
        }
        saveSettings();
    }

    function blackjackHit() {
        if (machineState !== "DEALT" || activeGameId !== "blackjack") return;
        playerCanDouble = false;

        var card = activeDeck.pop();
        card.faceUp = true;
        var pList = playerHand.slice();
        pList.push(card);
        playerHand = pList;
        playAudio("card_flip");

        playerTotal = Engine.calculateBlackjackTotal(playerHand);
        if (playerTotal > 21) {
            // BUST
            dealerHand[1].faceUp = true;
            dealerTotal = Engine.calculateBlackjackTotal(dealerHand);
            statusMessage = "BUST! TOTAL " + playerTotal + " - DEALER WINS";
            playAudio("bust");
            machineState = "ROUND_OVER";
            saveSettings();
        } else if (playerTotal === 21) {
            blackjackStand();
        } else {
            statusMessage = "TOTAL IS " + playerTotal + ". HIT OR STAND?";
        }
    }

    function blackjackDouble() {
        if (machineState !== "DEALT" || activeGameId !== "blackjack" || !playerCanDouble) return;
        credits -= betCoins;
        playAudio("chip");

        var card = activeDeck.pop();
        card.faceUp = true;
        var pList = playerHand.slice();
        pList.push(card);
        playerHand = pList;
        playAudio("card_flip");

        playerTotal = Engine.calculateBlackjackTotal(playerHand);
        playerCanDouble = false;

        if (playerTotal > 21) {
            dealerHand[1].faceUp = true;
            dealerTotal = Engine.calculateBlackjackTotal(dealerHand);
            statusMessage = "BUST ON DOUBLE! TOTAL " + playerTotal + " - DEALER WINS";
            playAudio("bust");
            machineState = "ROUND_OVER";
            saveSettings();
        } else {
            // Stand with double bet
            resolveBlackjackDealer(betCoins * 2);
        }
    }

    function blackjackStand() {
        if (machineState !== "DEALT" || activeGameId !== "blackjack") return;
        resolveBlackjackDealer(betCoins);
    }

    function resolveBlackjackDealer(currentBet) {
        machineState = "ROUND_OVER";
        var res = Engine.dealerDrawBlackjack(dealerHand, activeDeck);
        dealerHand = res.dealerHand;
        dealerTotal = res.dealerTotal;
        activeDeck = res.remainingDeck;
        playAudio("card_slide");

        if (res.isBust) {
            var won = currentBet * 2;
            credits += won;
            lastWinAmount = won;
            isWinningRound = true;
            statusMessage = "DEALER BUSTS (" + dealerTotal + ")! YOU WIN " + won + " COINS!";
            playAudio("win");
        } else if (dealerTotal > playerTotal) {
            lastWinAmount = 0;
            isWinningRound = false;
            statusMessage = "DEALER WINS (" + dealerTotal + " TO " + playerTotal + ")";
            playAudio("bust");
        } else if (dealerTotal === playerTotal) {
            credits += currentBet;
            statusMessage = "PUSH (" + playerTotal + " EACH) - BET RETURNED";
            playAudio("undo");
        } else {
            var wonP = currentBet * 2;
            credits += wonP;
            lastWinAmount = wonP;
            isWinningRound = true;
            statusMessage = "YOU WIN (" + playerTotal + " TO " + dealerTotal + ")! WON " + wonP + " COINS!";
            playAudio("win");
        }
        saveSettings();
    }

    // =========================================================================
    // GAME 8: CASINO WAR
    // =========================================================================
    function dealCasinoWar() {
        if (credits < betCoins) {
            statusMessage = "OUT OF CREDITS!";
            playAudio("bust");
            return;
        }

        credits -= betCoins;
        handsPlayed++;
        lastWinAmount = 0;
        winningEvaluation = null;
        isWinningRound = false;
        doubleUpActive = false;
        warExtraBet = 0;

        activeDeck = Engine.shuffle(Engine.createStandardDeck());
        var res = Engine.initCasinoWarDeal(activeDeck);
        activeDeck = res.remainingDeck;

        var pC = res.playerCard;
        var dC = res.dealerCard;
        pC.faceUp = true;
        dC.faceUp = true;
        playerHand = [pC];
        dealerHand = [dC];
        playAudio("card_slide");

        if (res.outcome === "win") {
            var won = betCoins * 2;
            credits += won;
            lastWinAmount = won;
            isWinningRound = true;
            statusMessage = "YOU WIN! (" + pC.value + " BEATS " + dC.value + ") WON " + won + " COINS!";
            playAudio("win");
            machineState = "ROUND_OVER";
        } else if (res.outcome === "loss") {
            lastWinAmount = 0;
            isWinningRound = false;
            statusMessage = "DEALER WINS (" + dC.value + " BEATS " + pC.value + ")";
            playAudio("bust");
            machineState = "ROUND_OVER";
        } else {
            // TIE -> GO TO WAR OR SURRENDER
            warState = "tie";
            machineState = "DEALT";
            statusMessage = "WAR! TIE AT " + pC.value + "! GO TO WAR (W) OR SURRENDER (S)?";
            playAudio("target");
        }
        saveSettings();
    }

    function warSurrender() {
        if (machineState !== "DEALT" || activeGameId !== "casino_war" || warState !== "tie") return;
        var returnHalf = Math.floor(betCoins / 2);
        credits += returnHalf;
        statusMessage = "SURRENDERED: HALF BET (" + returnHalf + " COINS) RETURNED";
        machineState = "ROUND_OVER";
        playAudio("undo");
        saveSettings();
    }

    function warGoToWar() {
        if (machineState !== "DEALT" || activeGameId !== "casino_war" || warState !== "tie") return;
        if (credits < betCoins) {
            statusMessage = "INSUFFICIENT CREDITS TO GO TO WAR! SURRENDERING...";
            warSurrender();
            return;
        }

        credits -= betCoins; // Match initial bet
        warExtraBet = betCoins;
        playAudio("chip");

        var res = Engine.resolveCasinoWarGoToWar(activeDeck);
        activeDeck = res.remainingDeck;

        var pWar = res.playerWarCard;
        var dWar = res.dealerWarCard;
        pWar.faceUp = true;
        dWar.faceUp = true;

        playerHand = [playerHand[0], pWar];
        dealerHand = [dealerHand[0], dWar];
        playAudio("card_flip");

        if (res.playerWon) {
            // Standard casino war rule: War bet pays 1:1, original bet pushes (Total return = 3x bet)
            var won = (betCoins * 3);
            credits += won;
            lastWinAmount = won;
            isWinningRound = true;
            statusMessage = (res.isTie ? "WAR TIE (WINNER)! " : "WAR VICTORY! ") + "(" + pWar.value + " vs " + dWar.value + ") WON " + won + " COINS!";
            playAudio("win");
        } else {
            lastWinAmount = 0;
            isWinningRound = false;
            statusMessage = "WAR LOSS (" + dWar.value + " BEATS " + pWar.value + ") - DEALER TAKES ALL";
            playAudio("bust");
        }

        machineState = "ROUND_OVER";
        saveSettings();
    }

    // =========================================================================
    // BONUS GAME: DOUBLE-UP HIGH-CARD GAMBLE
    // =========================================================================
    function startDoubleUp() {
        if (lastWinAmount <= 0) return;
        doubleUpActive = true;
        doubleUpCurrentPot = lastWinAmount;
        doubleUpResolved = false;

        var dDeck = Engine.shuffle(Engine.createStandardDeck());
        var res = Engine.initDoubleUpGamble(dDeck);

        doubleUpDealerCard = res.dealerCard;
        doubleUpPlayerCards = res.playerCards;
        doubleUpMessage = "PICK A CARD HIGHER THAN " + doubleUpDealerCard.value + " TO DOUBLE YOUR WIN!";
        playAudio("card_slide");
    }

    function pickDoubleUpCard(index) {
        if (!doubleUpActive || doubleUpResolved) return;
        if (index < 0 || index >= doubleUpPlayerCards.length) return;

        doubleUpResolved = true;
        var picked = doubleUpPlayerCards[index];
        var outcome = Engine.resolveDoubleUp(doubleUpDealerCard, picked);

        // Update list to trigger reactivity
        var list = [];
        for (var i = 0; i < doubleUpPlayerCards.length; i++) {
            list.push(doubleUpPlayerCards[i]);
        }
        doubleUpPlayerCards = list;
        playAudio("card_flip");

        if (outcome === "win") {
            var doubled = doubleUpCurrentPot * 2;
            credits += (doubled - doubleUpCurrentPot); // Credit the extra
            doubleUpCurrentPot = doubled;
            lastWinAmount = doubled;
            doubleUpMessage = "DOUBLE UP WINNER! POT IS NOW " + doubled + " COINS! DOUBLE AGAIN OR COLLECT?";
            playAudio("win");
        } else if (outcome === "tie") {
            doubleUpMessage = "TIE! PUSH - POT REMAINS " + doubleUpCurrentPot + " COINS. PICK AGAIN OR COLLECT.";
            playAudio("undo");
            // Allow picking another card or reset
            QTimer.singleShot(1000, function() {
                startDoubleUp();
            });
        } else {
            credits -= doubleUpCurrentPot; // Forfeits win
            lastWinAmount = 0;
            doubleUpCurrentPot = 0;
            doubleUpMessage = "DEALER WINS - GAMBLE LOST!";
            playAudio("bust");
            QTimer.singleShot(1400, function() {
                doubleUpActive = false;
                machineState = "ROUND_OVER";
            });
        }
        saveSettings();
    }

    function collectDoubleUp() {
        doubleUpActive = false;
        machineState = "ROUND_OVER";
        statusMessage = "COLLECTED " + doubleUpCurrentPot + " COINS!";
        playAudio("chip");
    }

    // =========================================================================
    // KEYBOARD SHORTCUTS
    // =========================================================================
    Item {
        id: keyboardListener
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            // Hotkeys
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                handlePrimaryAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_1) {
                if (doubleUpActive) pickDoubleUpCard(0);
                else if (isPokerGame) toggleHold(0);
                else if (activeGameId === "red_dog") resolveRedDog(false); // Call
                else if (activeGameId === "blackjack") blackjackHit();
                else if (activeGameId === "casino_war" && warState === "tie") warSurrender();
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                if (doubleUpActive) pickDoubleUpCard(1);
                else if (isPokerGame) toggleHold(1);
                else if (activeGameId === "red_dog") resolveRedDog(true); // Raise
                else if (activeGameId === "blackjack") blackjackStand();
                else if (activeGameId === "casino_war" && warState === "tie") warGoToWar();
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                if (doubleUpActive) pickDoubleUpCard(2);
                else if (isPokerGame) toggleHold(2);
                else if (activeGameId === "blackjack") blackjackDouble();
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                if (doubleUpActive) pickDoubleUpCard(3);
                else if (isPokerGame) toggleHold(3);
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
                visualMode = (visualMode === "crt" ? "cyber" : "crt");
                saveSettings();
                playAudio("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_G) {
                gameMenuOpen = !gameMenuOpen;
                playAudio("select");
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                if (isWinningRound && !doubleUpActive && lastWinAmount > 0) {
                    startDoubleUp();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                if (doubleUpActive) {
                    collectDoubleUp();
                } else {
                    // Add 100 free credits
                    credits += 100;
                    playAudio("chip");
                    statusMessage = "INSERTED 100 CREDITS";
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_H) {
                helpModalOpen = !helpModalOpen;
                playAudio("select");
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (doubleUpActive) collectDoubleUp();
                if (gameMenuOpen) gameMenuOpen = false;
                if (helpModalOpen) helpModalOpen = false;
                event.accepted = true;
            }
        }
    }

    // =========================================================================
    // CRT CABINET BEZEL / BACKGROUND LAYER
    // =========================================================================
    Rectangle {
        id: cabinetBackground
        anchors.fill: parent
        color: isCrtMode ? "#020210" : theme.bg

        // Subtle gradient bezel for CRT cabinet
        Rectangle {
            anchors.fill: parent
            anchors.margins: isCrtMode ? 14 : 0
            radius: isCrtMode ? 16 : 0
            color: isCrtMode ? "#000088" : theme.bg
            border.color: isCrtMode ? "#1E293B" : theme.border
            border.width: isCrtMode ? 6 : 1
            clip: true

            // =================================================================
            // CRT SCANLINE RASTER OVERLAY (Canvas)
            // =================================================================
            Canvas {
                id: scanlineCanvas
                anchors.fill: parent
                visible: isCrtMode
                opacity: 0.18
                z: 100
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#000000";
                    for (var y = 0; y < height; y += 3) {
                        ctx.fillRect(0, y, width, 1.2);
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // CRT Subtle Curved Glass Flare
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 120
                visible: isCrtMode
                z: 101
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#22FFFFFF" }
                    GradientStop { position: 1.0; color: "#00FFFFFF" }
                }
            }

            // =================================================================
            // MAIN TERMINAL VIEWPORT
            // =================================================================
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: isCrtMode ? 16 : 20
                spacing: 10

                // -------------------------------------------------------------
                // 1. TOP HEADER & HUD BAR
                // -------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Game Title & Machine ID
                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Text {
                                text: "★ OMARCHY ARCADE"
                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                font.pixelSize: 11
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }
                            Rectangle {
                                width: 52
                                height: 16
                                radius: 3
                                color: isCrtMode ? "#DC2626" : theme.primary
                                Text {
                                    anchors.centerIn: parent
                                    text: "OA-025"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        Text {
                            text: getActiveGameMeta().name
                            font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                            font.pixelSize: 18
                            font.bold: true
                            color: isCrtMode ? "#FFFFFF" : theme.fg
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Navigation / Switcher Buttons
                    RowLayout {
                        spacing: 8

                        // Game Menu Switcher
                        Rectangle {
                            width: 100
                            height: 32
                            radius: 4
                            color: isCrtMode ? "#0284C7" : theme.surface
                            border.color: isCrtMode ? "#BAE6FD" : theme.border
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    gameMenuOpen = !gameMenuOpen;
                                    playAudio("select");
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "GAMES (G)"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }

                        // Vibe Mode Switcher (1984 CRT vs Neo-Tokyo Cyber)
                        Rectangle {
                            width: 128
                            height: 32
                            radius: 4
                            color: isCrtMode ? "#9333EA" : "#10B981"
                            border.color: isCrtMode ? "#E9D5FF" : "#A7F3D0"
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    visualMode = (visualMode === "crt" ? "cyber" : "crt");
                                    saveSettings();
                                    playAudio("click");
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: isCrtMode ? "1984 CRT [V]" : "CYBER GLASS [V]"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }

                        // Help / Rules Modal
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 4
                            color: isCrtMode ? "#334155" : theme.surface
                            border.color: isCrtMode ? "#64748B" : theme.border
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    helpModalOpen = !helpModalOpen;
                                    playAudio("select");
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                font.pixelSize: 14
                                font.bold: true
                                color: isCrtMode ? "#FFFFFF" : theme.fg
                            }
                        }

                        // Sound Mute Toggle
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 4
                            color: isCrtMode ? "#334155" : theme.surface
                            border.color: isCrtMode ? "#64748B" : theme.border
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: soundMuted = !soundMuted
                            }
                            Text {
                                anchors.centerIn: parent
                                text: soundMuted ? "🔇" : "🔊"
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 2. UPPER PAYTABLE / GAME HUD MATRIX
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: isPokerGame ? 170 : 90
                    radius: isCrtMode ? 4 : 8
                    color: isCrtMode ? "#0000AA" : (theme.bg === "#000000" ? "#111827" : theme.surface)
                    border.color: isCrtMode ? "#FEF08A" : theme.border
                    border.width: isCrtMode ? 2 : 1
                    clip: true

                    // POKER PAYTABLE GRID (5 COLUMNS)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 1
                        visible: isPokerGame

                        // Header Row (1 COIN ... 5 COINS)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.preferredWidth: 200
                                text: "HAND RANKING"
                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                font.pixelSize: 11
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }
                            Repeater {
                                model: [1, 2, 3, 4, 5]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    color: (betCoins === modelData) ? (isCrtMode ? "#FEF08A" : theme.primary) : "transparent"
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + " COIN" + (modelData > 1 ? "S" : "")
                                        font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: (betCoins === modelData) ? (isCrtMode ? "#000088" : "#FFFFFF") : (isCrtMode ? "#FFFFFF" : theme.muted)
                                    }
                                }
                            }
                        }

                        // Paytable Rows
                        Repeater {
                            model: Engine.PAYTABLES[activeGameId] ? Engine.PAYTABLES[activeGameId] : []
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                readonly property bool isWinningRow: winningEvaluation && (winningEvaluation.key === modelData.key)
                                color: isWinningRow ? (isCrtMode ? "#DC2626" : theme.accent) : "transparent"
                                radius: 2

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 2

                                    Text {
                                        Layout.preferredWidth: 200
                                        text: modelData.name
                                        font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                        font.pixelSize: 10
                                        font.bold: parent.parent.isWinningRow
                                        color: parent.parent.isWinningRow ? "#FFFFFF" : (isCrtMode ? "#FFFFFF" : theme.fg)
                                        elide: Text.ElideRight
                                    }

                                    Repeater {
                                        model: modelData.pays
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: (betCoins === index + 1) ? (isCrtMode ? "#FFFF0033" : "#38BDF822") : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                                font.pixelSize: 10
                                                font.bold: (betCoins === index + 1) || parent.parent.parent.isWinningRow
                                                color: (betCoins === index + 1) ? (isCrtMode ? "#FEF08A" : theme.accent) : (isCrtMode ? "#CBD5E1" : theme.muted)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TABLE GAME HUD: RED DOG
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        visible: activeGameId === "red_dog"

                        Text {
                            text: "RED DOG SPREAD PAYOUT TABLE"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: isCrtMode ? "#FEF08A" : theme.accent
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: [
                                    { spread: "SPREAD 1", pay: "5 TO 1" },
                                    { spread: "SPREAD 2", pay: "4 TO 1" },
                                    { spread: "SPREAD 3", pay: "2 TO 1" },
                                    { spread: "SPREAD 4-11", pay: "1 TO 1" },
                                    { spread: "PAIR (3RD SAME)", pay: "11 TO 1" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: 4
                                    color: isCrtMode ? "#000066" : theme.bg
                                    border.color: isCrtMode ? "#38BDF8" : theme.border
                                    border.width: 1
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.spread
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: isCrtMode ? "#93C5FD" : theme.muted
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.pay
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: isCrtMode ? "#FEF08A" : theme.accent
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TABLE GAME HUD: BLACKJACK
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        visible: activeGameId === "blackjack"

                        Text {
                            text: "SINGLE-DECK CASINO BLACKJACK RULES"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: isCrtMode ? "#FEF08A" : theme.accent
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: [
                                    { title: "BLACKJACK PAYS", val: "3 TO 2" },
                                    { title: "DEALER RULE", val: "STANDS ON ALL 17s" },
                                    { title: "DOUBLE DOWN", val: "ON ANY INITIAL 2 CARDS" },
                                    { title: "DECKS IN PLAY", val: "SINGLE 52-CARD SHUFFLE" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: 4
                                    color: isCrtMode ? "#000066" : theme.bg
                                    border.color: isCrtMode ? "#38BDF8" : theme.border
                                    border.width: 1
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: isCrtMode ? "#93C5FD" : theme.muted
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.val
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: isCrtMode ? "#FEF08A" : theme.accent
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TABLE GAME HUD: CASINO WAR
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        visible: activeGameId === "casino_war"

                        Text {
                            text: "CASINO WAR SHOWDOWN RULES"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: isCrtMode ? "#FEF08A" : theme.accent
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: [
                                    { title: "STANDARD WIN", val: "HIGHER CARD PAYS 1 TO 1" },
                                    { title: "ACES RANKING", val: "ACES ARE ALWAYS HIGH" },
                                    { title: "ON TIE: GO TO WAR", val: "MATCH BET • WIN PAYS 1:1" },
                                    { title: "ON TIE: SURRENDER", val: "FORFEIT 50% OF ORIGINAL BET" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: 4
                                    color: isCrtMode ? "#000066" : theme.bg
                                    border.color: isCrtMode ? "#38BDF8" : theme.border
                                    border.width: 1
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: isCrtMode ? "#93C5FD" : theme.muted
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.val
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: isCrtMode ? "#FEF08A" : theme.accent
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 3. CENTER PLAYFIELD & CARDS AREA
                // -------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: isCrtMode ? 4 : 8
                    color: isCrtMode ? "#000066" : (theme.bg === "#000000" ? "#0A0D14" : theme.surface)
                    border.color: isCrtMode ? "#0088FF" : theme.border
                    border.width: isCrtMode ? 2 : 1
                    clip: true

                    // STATUS MESSAGE BANNER
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32
                        color: isWinningRound ? (isCrtMode ? "#DC2626" : theme.accent) : (isCrtMode ? "#000088" : theme.surface)
                        z: 10

                        Text {
                            anchors.centerIn: parent
                            text: statusMessage
                            font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                            font.pixelSize: 13
                            font.bold: true
                            color: isCrtMode ? "#FEF08A" : "#FFFFFF"
                        }
                    }

                    // POKER VIEW: 5 CARDS CENTERED
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        spacing: 18
                        visible: isPokerGame

                        Repeater {
                            model: playerHand
                            Item {
                                width: 110
                                height: 160

                                PlayingCard {
                                    anchors.centerIn: parent
                                    width: 108
                                    height: 154
                                    cardData: modelData
                                    visualMode: root.visualMode
                                    deckStyle: root.deckStyle
                                    isWinning: root.isWinningRound
                                }

                                // Interactive Hold Toggle
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: (machineState === "DEALT") ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: toggleHold(index)
                                }
                            }
                        }
                    }

                    // RED DOG VIEW: 2 CARDS + 1 CENTER CARD
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        spacing: 36
                        visible: activeGameId === "red_dog" && playerHand.length >= 2

                        // Card 1
                        PlayingCard {
                            width: 114
                            height: 160
                            cardData: (playerHand.length >= 1) ? playerHand[0] : null
                            visualMode: root.visualMode
                            deckStyle: root.deckStyle
                        }

                        // Center 3rd card slot / Spread Meter
                        Item {
                            width: 140
                            height: 160
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: isCrtMode ? "#000044" : theme.bg
                                border.color: isCrtMode ? "#38BDF8" : theme.border
                                border.width: 1.5

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    visible: playerHand.length < 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "SPREAD"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: isCrtMode ? "#93C5FD" : theme.muted
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: redDogSpread.toString()
                                        font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                        font.pixelSize: 28
                                        font.bold: true
                                        color: isCrtMode ? "#FEF08A" : theme.accent
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (redDogStatus === "pair" ? "PAIR (11:1)" : (redDogStatus === "consecutive" ? "CONSECUTIVE" : "IN-BETWEEN"))
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: isCrtMode ? "#FFFFFF" : theme.fg
                                    }
                                }

                                // When 3rd card dealt
                                PlayingCard {
                                    anchors.centerIn: parent
                                    width: 114
                                    height: 160
                                    cardData: (playerHand.length >= 3) ? playerHand[2] : null
                                    visualMode: root.visualMode
                                    deckStyle: root.deckStyle
                                    visible: playerHand.length >= 3
                                }
                            }
                        }

                        // Card 2
                        PlayingCard {
                            width: 114
                            height: 160
                            cardData: (playerHand.length >= 2) ? playerHand[1] : null
                            visualMode: root.visualMode
                            deckStyle: root.deckStyle
                        }
                    }

                    // BLACKJACK VIEW: DEALER + PLAYER HANDS
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        spacing: 12
                        visible: activeGameId === "blackjack" && (playerHand.length > 0 || dealerHand.length > 0)

                        // Dealer Hand
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DEALER (" + (machineState === "ROUND_OVER" ? dealerTotal : "?") + "): "
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 13
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }
                            Repeater {
                                model: dealerHand
                                PlayingCard {
                                    width: 80
                                    height: 114
                                    cardData: modelData
                                    visualMode: root.visualMode
                                    deckStyle: root.deckStyle
                                }
                            }
                        }

                        // Player Hand
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "YOU (" + playerTotal + "): "
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 13
                                font.bold: true
                                color: isCrtMode ? "#38BDF8" : theme.fg
                            }
                            Repeater {
                                model: playerHand
                                PlayingCard {
                                    width: 80
                                    height: 114
                                    cardData: modelData
                                    visualMode: root.visualMode
                                    deckStyle: root.deckStyle
                                }
                            }
                        }
                    }

                    // CASINO WAR VIEW: SHOWDOWN
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        spacing: 40
                        visible: activeGameId === "casino_war" && playerHand.length > 0

                        // Dealer Card
                        Column {
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "DEALER"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: dealerHand
                                    PlayingCard {
                                        width: 100
                                        height: 142
                                        cardData: modelData
                                        visualMode: root.visualMode
                                        deckStyle: root.deckStyle
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "VS"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 22
                            font.bold: true
                            color: isCrtMode ? "#FFFFFF" : theme.fg
                        }

                        // Player Card
                        Column {
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "YOU"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: isCrtMode ? "#38BDF8" : theme.fg
                            }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: playerHand
                                    PlayingCard {
                                        width: 100
                                        height: 142
                                        cardData: modelData
                                        visualMode: root.visualMode
                                        deckStyle: root.deckStyle
                                    }
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 4. METERS & DIGITAL SCORE COUNTERS
                // -------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Credits Display
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 4
                        color: isCrtMode ? "#000033" : theme.surface
                        border.color: isCrtMode ? "#FEF08A" : theme.border
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            Text {
                                text: "CREDITS"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.muted
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: credits.toString()
                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                font.pixelSize: 18
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.fg
                            }
                        }
                    }

                    // Bet Display
                    Rectangle {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 38
                        radius: 4
                        color: isCrtMode ? "#000033" : theme.surface
                        border.color: isCrtMode ? "#38BDF8" : theme.border
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            Text {
                                text: "BET"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: isCrtMode ? "#38BDF8" : theme.muted
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: betCoins.toString()
                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                font.pixelSize: 18
                                font.bold: true
                                color: isCrtMode ? "#38BDF8" : theme.accent
                            }
                        }
                    }

                    // Win Display
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 4
                        color: isWinningRound ? (isCrtMode ? "#7F1D1D" : theme.accent) : (isCrtMode ? "#000033" : theme.surface)
                        border.color: isWinningRound ? "#FDE047" : (isCrtMode ? "#64748B" : theme.border)
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            Text {
                                text: "WINNER PAID"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: isWinningRound ? "#FFFFFF" : (isCrtMode ? "#94A3B8" : theme.muted)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: lastWinAmount.toString()
                                font.family: isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                                font.pixelSize: 18
                                font.bold: true
                                color: isWinningRound ? "#FEF08A" : (isCrtMode ? "#FFFFFF" : theme.fg)
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // 5. BOTTOM ARCADE PUSH BUTTONS PANEL
                // -------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 10

                    // In Poker: 5 HOLD BUTTONS
                    Repeater {
                        model: 5
                        Rectangle {
                            visible: root.isPokerGame
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 4
                            readonly property bool cardIsHeld: Boolean(playerHand && playerHand[index] && playerHand[index].held)
                            color: cardIsHeld ? (isCrtMode ? "#DC2626" : theme.primary) : (isCrtMode ? "#1E293B" : theme.surface)
                            border.color: cardIsHeld ? "#FEF08A" : (isCrtMode ? "#475569" : theme.border)
                            border.width: cardIsHeld ? 2 : 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleHold(index)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cardIsHeld ? "HELD" : "HOLD " + (index + 1)
                                    font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: cardIsHeld ? "#FEF08A" : "#FFFFFF"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "[" + (index + 1) + "]"
                                    font.pixelSize: 9
                                    color: isCrtMode ? "#94A3B8" : theme.muted
                                }
                            }
                        }
                    }

                    // In Red Dog: CALL & RAISE BUTTONS
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "red_dog" && machineState === "DEALT"
                        color: isCrtMode ? "#0284C7" : theme.surface
                        border.color: isCrtMode ? "#7DD3FC" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: resolveRedDog(false)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "CALL [1]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "(NO RAISE)"
                                font.pixelSize: 9
                                color: "#BAE6FD"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "red_dog" && machineState === "DEALT"
                        color: isCrtMode ? "#D97706" : theme.primary
                        border.color: isCrtMode ? "#FDE68A" : theme.accent
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: resolveRedDog(true)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "RAISE 2X [2]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "(+" + betCoins + " COINS)"
                                font.pixelSize: 9
                                color: "#FEF08A"
                            }
                        }
                    }

                    // In Blackjack: HIT, STAND, DOUBLE BUTTONS
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "blackjack" && machineState === "DEALT"
                        color: isCrtMode ? "#0284C7" : theme.surface
                        border.color: isCrtMode ? "#7DD3FC" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: blackjackHit()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "HIT [1]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TAKE CARD"
                                font.pixelSize: 9
                                color: "#BAE6FD"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "blackjack" && machineState === "DEALT"
                        color: isCrtMode ? "#DC2626" : theme.accent
                        border.color: isCrtMode ? "#FECACA" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: blackjackStand()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "STAND [2]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "HOLD TOTAL"
                                font.pixelSize: 9
                                color: "#FEE2E2"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "blackjack" && machineState === "DEALT" && playerCanDouble
                        color: isCrtMode ? "#D97706" : theme.primary
                        border.color: isCrtMode ? "#FDE68A" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: blackjackDouble()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "DOUBLE [3]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "2X BET + 1 CARD"
                                font.pixelSize: 9
                                color: "#FEF08A"
                            }
                        }
                    }

                    // In Casino War: GO TO WAR / SURRENDER BUTTONS ON TIE
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "casino_war" && machineState === "DEALT" && warState === "tie"
                        color: isCrtMode ? "#DC2626" : theme.surface
                        border.color: isCrtMode ? "#FECACA" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: warSurrender()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "SURRENDER [1]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "(LOSE 50% BET)"
                                font.pixelSize: 9
                                color: "#FEE2E2"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: activeGameId === "casino_war" && machineState === "DEALT" && warState === "tie"
                        color: isCrtMode ? "#16A34A" : theme.primary
                        border.color: isCrtMode ? "#BBF7D0" : theme.accent
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: warGoToWar()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "GO TO WAR [2]"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "(MATCH BET • WIN 1:1)"
                                font.pixelSize: 9
                                color: "#DCFCE7"
                            }
                        }
                    }

                    // DOUBLE-UP GAMBLE BUTTON (OFFERED AFTER WIN)
                    Rectangle {
                        Layout.preferredWidth: 124
                        Layout.preferredHeight: 52
                        radius: 4
                        visible: isWinningRound && lastWinAmount > 0 && !doubleUpActive
                        color: isCrtMode ? "#E11D48" : theme.accent
                        border.color: "#FDE047"
                        border.width: 2
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: startDoubleUp()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "DOUBLE UP [D]"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "HIGH CARD GAMBLE"
                                font.pixelSize: 8
                                font.bold: true
                                color: "#FEF08A"
                            }
                        }
                    }

                    // BET ONE COIN BUTTON
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 52
                        radius: 4
                        color: isCrtMode ? "#0D9488" : theme.surface
                        border.color: isCrtMode ? "#99F6E4" : theme.border
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: increaseBet()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "BET 1 [B]"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "UP TO 5"
                                font.pixelSize: 9
                                color: "#CCFBF1"
                            }
                        }
                    }

                    // BET MAX BUTTON
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 52
                        radius: 4
                        color: isCrtMode ? "#CA8A04" : theme.accent
                        border.color: isCrtMode ? "#FEF08A" : theme.accent
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setMaxBet()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "BET MAX [M]"
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "5 COINS"
                                font.pixelSize: 9
                                color: "#FEF9C3"
                            }
                        }
                    }

                    // MASTER DEAL / DRAW BUTTON
                    Rectangle {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 52
                        radius: 4
                        color: isCrtMode ? "#16A34A" : theme.primary
                        border.color: isCrtMode ? "#86EFAC" : theme.accent
                        border.width: 2
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: handlePrimaryAction()
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (doubleUpActive) return "COLLECT [C]";
                                    if (machineState === "DEALT" && isPokerGame) return "DRAW [SPACE]";
                                    return "DEAL [SPACE]";
                                }
                                font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#FFFFFF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (machineState === "DEALT" && isPokerGame) ? "REPLACE UNHELD" : "START HAND"
                                font.pixelSize: 9
                                color: "#DCFCE7"
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // DOUBLE-UP HIGH-CARD GAMBLE OVERLAY MODAL
    // =========================================================================
    Rectangle {
        id: doubleUpModal
        anchors.fill: parent
        color: "#E6000033"
        visible: doubleUpActive
        z: 200

        Rectangle {
            anchors.centerIn: parent
            width: 760
            height: 480
            radius: 12
            color: isCrtMode ? "#000088" : theme.surface
            border.color: isCrtMode ? "#FEF08A" : theme.accent
            border.width: 3

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                // Modal Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "★ DOUBLE-UP HIGH-CARD BONUS GAMBLE ★"
                        font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                        font.pixelSize: 18
                        font.bold: true
                        color: isCrtMode ? "#FEF08A" : theme.accent
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 100
                        height: 30
                        radius: 4
                        color: "#DC2626"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: collectDoubleUp()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "COLLECT (C)"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#FFFFFF"
                        }
                    }
                }

                // Pot Meter
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: isCrtMode ? "#000044" : theme.bg
                    border.color: "#FEF08A"
                    border.width: 1.5
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        Text {
                            text: "CURRENT POT: " + doubleUpCurrentPot + " COINS"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FEF08A"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "DOUBLE WIN VALUE: " + (doubleUpCurrentPot * 2) + " COINS"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#38BDF8"
                        }
                    }
                }

                // Instruction Message
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: doubleUpMessage
                    font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#FFFFFF"
                }

                // Card Arena: Dealer on Left, 4 Player Picks on Right
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 30

                    // Dealer Card
                    Column {
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DEALER'S CARD"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: isCrtMode ? "#FEF08A" : theme.accent
                        }
                        PlayingCard {
                            width: 110
                            height: 154
                            cardData: doubleUpDealerCard
                            visualMode: root.visualMode
                            deckStyle: root.deckStyle
                        }
                    }

                    Rectangle {
                        width: 2
                        Layout.fillHeight: true
                        color: isCrtMode ? "#38BDF8" : theme.border
                    }

                    // 4 Player Hidden Cards
                    Column {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "PICK 1 CARD TO BEAT DEALER"
                            font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: isCrtMode ? "#38BDF8" : theme.fg
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 14
                            Repeater {
                                model: doubleUpPlayerCards
                                Item {
                                    width: 104
                                    height: 150
                                    PlayingCard {
                                        anchors.centerIn: parent
                                        width: 102
                                        height: 146
                                        cardData: modelData
                                        visualMode: root.visualMode
                                        deckStyle: root.deckStyle
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
        }
    }

    // =========================================================================
    // GAME SELECTOR MODAL (8 GAMES)
    // =========================================================================
    Rectangle {
        id: gameSelectModal
        anchors.fill: parent
        color: "#CC000000"
        visible: gameMenuOpen
        z: 300

        Rectangle {
            anchors.centerIn: parent
            width: 740
            height: 520
            radius: 12
            color: isCrtMode ? "#000088" : theme.surface
            border.color: isCrtMode ? "#FEF08A" : theme.accent
            border.width: 3

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SELECT GAME TERMINAL ENGINE"
                        font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                        font.pixelSize: 16
                        font.bold: true
                        color: isCrtMode ? "#FEF08A" : theme.accent
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 4
                        color: "#DC2626"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: gameMenuOpen = false
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 13
                            color: "#FFFFFF"
                        }
                    }
                }

                // Grid of 8 Games
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: gameList
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            readonly property bool isSelected: (activeGameId === modelData.id)
                            color: isSelected ? (isCrtMode ? "#0284C7" : theme.primary) : (isCrtMode ? "#000055" : theme.bg)
                            border.color: isSelected ? "#FEF08A" : (isCrtMode ? "#38BDF8" : theme.border)
                            border.width: isSelected ? 2 : 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: switchGame(modelData.id)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 2

                                RowLayout {
                                    Text {
                                        text: modelData.name
                                        font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: parent.parent.parent.isSelected ? "#FEF08A" : "#FFFFFF"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: 44
                                        height: 16
                                        radius: 3
                                        color: modelData.type === "poker" ? "#16A34A" : "#D97706"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.type.toUpperCase()
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.desc
                                    font.pixelSize: 10
                                    color: parent.parent.isSelected ? "#E0F2FE" : (isCrtMode ? "#CBD5E1" : theme.muted)
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // HELP / RULES MODAL
    // =========================================================================
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: "#CC000000"
        visible: helpModalOpen
        z: 350

        Rectangle {
            anchors.centerIn: parent
            width: 700
            height: 520
            radius: 12
            color: isCrtMode ? "#000088" : theme.surface
            border.color: isCrtMode ? "#FEF08A" : theme.accent
            border.width: 3

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "TERMINAL INSTRUCTIONS & SHORTCUTS"
                        font.family: isCrtMode ? "Courier New, monospace" : "sans-serif"
                        font.pixelSize: 16
                        font.bold: true
                        color: isCrtMode ? "#FEF08A" : theme.accent
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 4
                        color: "#DC2626"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: helpModalOpen = false
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 13
                            color: "#FFFFFF"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: isCrtMode ? "#000044" : theme.bg
                    border.color: isCrtMode ? "#38BDF8" : theme.border
                    border.width: 1
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentHeight: helpCol.implicitHeight
                        clip: true

                        Column {
                            id: helpCol
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "KEYBOARD CONTROLS"
                                font.pixelSize: 12
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }

                            Text {
                                width: parent.width
                                text: "• [SPACE] or [ENTER]: Deal cards or Draw unheld cards\n" +
                                      "• [1] - [5]: Toggle Hold on cards 1 through 5 (or game action)\n" +
                                      "• [B]: Increase coin bet (1 to 5)\n" +
                                      "• [M]: Bet Max (5 coins) and immediately deal\n" +
                                      "• [V]: Toggle visual era (1984 Vegas CRT ↔ Neo-Tokyo Cyber Glass)\n" +
                                      "• [G]: Open Game Selection terminal menu\n" +
                                      "• [D]: Double-Up High-Card Gamble (when offered after winning hand)\n" +
                                      "• [C]: Collect Double-Up pot / Cash out, or insert free credits\n" +
                                      "• [? / H]: Toggle this instructions manual\n" +
                                      "• [ESC]: Close modals or cancel active dialogs"
                                font.pixelSize: 11
                                color: isCrtMode ? "#FFFFFF" : theme.fg
                                lineHeight: 1.3
                            }

                            Text {
                                text: "DUAL-ERA VISUAL SWITCHER"
                                font.pixelSize: 12
                                font.bold: true
                                color: isCrtMode ? "#FEF08A" : theme.accent
                            }

                            Text {
                                width: parent.width
                                text: "Switch instantly at any time by pressing [V] between:\n" +
                                      "1. 1984 Vegas CRT: Authentic cobalt blue phosphor tube with scanline raster canvas, chunky monospace typography, and tactile physical push buttons.\n" +
                                      "2. Neo-Tokyo Cyber Glass: Deep obsidian glassmorphism, dynamic theme synchronization with all 22 Omarchy desktop themes, and laser HUD columns."
                                font.pixelSize: 11
                                color: isCrtMode ? "#FFFFFF" : theme.fg
                                lineHeight: 1.3
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        z: 1000
    }
}
