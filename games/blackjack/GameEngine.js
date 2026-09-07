// Omarchy Arcade • Blackjack Game Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

// Virtual coordinate space
var width = 780;
var height = 620;

// Game State
var gameState = "betting"; // "betting", "dealing", "player_turn", "dealer_turn", "round_over"
var score = 0;
var highScore = 0;
var level = 1;

// Card constants
var SUITS = ["♠", "♥", "♦", "♣"];
var VALUES = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];

/**
 * Creates a standard 52-card deck.
 */
function createDeck() {
    var deck = [];
    for (var s = 0; s < SUITS.length; s++) {
        var suit = SUITS[s];
        var isRed = (suit === "♥" || suit === "♦");
        for (var v = 0; v < VALUES.length; v++) {
            var val = VALUES[v];
            var num = 0;
            if (val === "A") num = 11;
            else if (val === "K" || val === "Q" || val === "J" || val === "10") num = 10;
            else num = parseInt(val, 10);

            deck.push({
                suit: suit,
                value: val,
                numericValue: num,
                isRed: isRed,
                faceUp: true,
                id: suit + "_" + val + "_" + Math.random().toString(36).substring(2, 7)
            });
        }
    }
    return deck;
}

/**
 * Creates and shuffles a continuous casino shoe of multiple decks.
 */
function createShoe(numDecks) {
    if (!numDecks || numDecks < 1) numDecks = 6;
    var shoe = [];
    for (var d = 0; d < numDecks; d++) {
        shoe = shoe.concat(createDeck());
    }
    return shuffle(shoe);
}

/**
 * Fisher-Yates shuffle algorithm.
 */
function shuffle(array) {
    var m = array.length, t, i;
    while (m) {
        i = Math.floor(Math.random() * m--);
        t = array[m];
        array[m] = array[i];
        array[i] = t;
    }
    return array;
}

/**
 * Evaluates a hand of cards, correctly accounting for soft/hard Aces.
 */
function calculateHand(cards) {
    if (!cards || cards.length === 0) {
        return { total: 0, isSoft: false, isBlackjack: false, isBust: false, label: "0" };
    }

    var total = 0;
    var aces = 0;
    var visibleCount = 0;

    for (var i = 0; i < cards.length; i++) {
        var c = cards[i];
        if (c.faceUp === false) continue; // Skip hidden hole cards in display evaluation
        visibleCount++;
        if (c.value === "A") {
            aces++;
            total += 11;
        } else if (c.value === "K" || c.value === "Q" || c.value === "J" || c.value === "10") {
            total += 10;
        } else {
            total += parseInt(c.value, 10);
        }
    }

    var isSoft = false;
    while (total > 21 && aces > 0) {
        total -= 10;
        aces--;
    }

    if (aces > 0 && total <= 21) {
        isSoft = true;
    }

    var isBlackjack = (visibleCount === 2 && total === 21 && cards.length === 2);
    var isBust = (total > 21);

    var label = total.toString();
    if (isBlackjack) {
        label = "BJ (21)";
    } else if (isSoft && total < 21) {
        label = (total - 10) + "/" + total;
    }

    return {
        total: total,
        isSoft: isSoft,
        isBlackjack: isBlackjack,
        isBust: isBust,
        label: label
    };
}

function canSplit(cards) {
    if (!cards || cards.length !== 2) return false;
    return (cards[0].value === cards[1].value || (cards[0].numericValue === 10 && cards[1].numericValue === 10));
}

/**
 * Standard dealer AI rules: Stand on 17 (or soft 17 if table rule stands on all 17).
 */
function dealerShouldHit(dealerCards) {
    var evalRes = calculateHand(dealerCards);
    // Dealer stands on all 17s and higher, hits on 16 or lower
    return (evalRes.total < 17);
}

/**
 * Template required functions
 */
function init(w, h) {
    width = w;
    height = h;
    resetGame();
}

function resize(w, h) {
    width = w;
    height = h;
}

function resetGame() {
    gameState = "betting";
    score = 0;
}

function update(dt, callbacks) {
    // Blackjack is turn/event-driven rather than 60 FPS physics
}

function handleInput(action, callbacks) {
    if (callbacks && callbacks.onAction) {
        callbacks.onAction(action);
    }
}
