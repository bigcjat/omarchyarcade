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
 * Calculates the exact or shoe-based probability of busting on the next hit.
 */
function calculateBustProbability(cards, shoe) {
    if (!cards || cards.length === 0) return 0;
    var evalRes = calculateHand(cards);
    if (evalRes.isBust) return 100;
    if (evalRes.isSoft || evalRes.total <= 11) return 0;
    
    var maxSafeCard = 21 - evalRes.total;
    
    // If shoe provided and has cards, calculate from actual remaining shoe
    if (shoe && shoe.length > 0) {
        var bustCards = 0;
        for (var i = 0; i < shoe.length; i++) {
            if (shoe[i].value === "A") continue; // Ace can count as 1, never busts
            if (shoe[i].numericValue > maxSafeCard) {
                bustCards++;
            }
        }
        return Math.round((bustCards / shoe.length) * 100);
    }
    
    // Theoretical 13-rank distribution (10/J/Q/K are 4 of 13)
    var bustWeight = 0;
    for (var v = 2; v <= 10; v++) {
        if (v > maxSafeCard) {
            bustWeight += (v === 10 ? 4 : 1);
        }
    }
    return Math.round((bustWeight / 13) * 100);
}

/**
 * Standard dealer bust probability based on visible dealer upcard.
 */
function getDealerBustProbability(dealerUpcard) {
    if (!dealerUpcard) return 0;
    var val = dealerUpcard.value;
    switch (val) {
        case "2": return 35;
        case "3": return 38;
        case "4": return 40;
        case "5": return 43;
        case "6": return 42;
        case "7": return 26;
        case "8": return 24;
        case "9": return 23;
        case "10":
        case "J":
        case "Q":
        case "K": return 21;
        case "A": return 12;
        default: return 28;
    }
}

/**
 * Mathematically optimal Basic Strategy lookup.
 */
function getBasicStrategy(cards, dealerUpcard, canDouble, canSplitPair) {
    if (!cards || cards.length === 0 || !dealerUpcard) {
        return { action: "HIT", label: "HIT", tip: "Take a card" };
    }
    
    var evalRes = calculateHand(cards);
    if (evalRes.isBust || evalRes.total >= 21) {
        return { action: "STAND", label: "STAND", tip: "Hand complete" };
    }
    
    var dVal = dealerUpcard.numericValue;
    if (dealerUpcard.value === "A") dVal = 11;
    
    // 1. Check Pair Splitting
    if (cards.length === 2 && canSplitPair && canSplit(cards)) {
        var cVal = cards[0].value;
        if (cVal === "A" || cVal === "8") {
            return { action: "SPLIT", label: "SPLIT", tip: "Always split Aces & 8s" };
        }
        if (cVal === "2" || cVal === "3") {
            if (dVal >= 4 && dVal <= 7) return { action: "SPLIT", label: "SPLIT", tip: "Split vs dealer 4-7" };
            return { action: "HIT", label: "HIT", tip: "Hit low pair vs dealer strength" };
        }
        if (cVal === "4") {
            if (dVal === 5 || dVal === 6) return { action: "SPLIT", label: "SPLIT", tip: "Split 4s vs dealer 5-6" };
            return { action: "HIT", label: "HIT", tip: "Hit hard 8" };
        }
        if (cVal === "5") {
            if (canDouble && dVal >= 2 && dVal <= 9) return { action: "DOUBLE", label: "DOUBLE", tip: "Double 10 vs dealer 2-9" };
            return { action: "HIT", label: "HIT", tip: "Hit hard 10" };
        }
        if (cVal === "6") {
            if (dVal >= 3 && dVal <= 6) return { action: "SPLIT", label: "SPLIT", tip: "Split 6s vs dealer 3-6" };
            return { action: "HIT", label: "HIT", tip: "Hit vs dealer 7+" };
        }
        if (cVal === "7") {
            if (dVal >= 2 && dVal <= 7) return { action: "SPLIT", label: "SPLIT", tip: "Split 7s vs dealer 2-7" };
            return { action: "HIT", label: "HIT", tip: "Hit vs dealer 8+" };
        }
        if (cVal === "9") {
            if (dVal === 7 || dVal === 10 || dVal === 11) return { action: "STAND", label: "STAND", tip: "Stand on 18" };
            return { action: "SPLIT", label: "SPLIT", tip: "Split 9s vs dealer 2-6, 8-9" };
        }
        if (cVal === "10" || cVal === "J" || cVal === "Q" || cVal === "K") {
            return { action: "STAND", label: "STAND", tip: "Never split 20! High winning hand" };
        }
    }
    
    // 2. Soft Hands
    if (evalRes.isSoft) {
        var softTotal = evalRes.total;
        if (softTotal >= 20) {
            return { action: "STAND", label: "STAND", tip: "Stand on strong soft 20+" };
        }
        if (softTotal === 19) {
            if (canDouble && dVal === 6) return { action: "DOUBLE", label: "DOUBLE", tip: "Double A,8 vs dealer 6" };
            return { action: "STAND", label: "STAND", tip: "Stand on soft 19" };
        }
        if (softTotal === 18) {
            if (canDouble && dVal >= 3 && dVal <= 6) return { action: "DOUBLE", label: "DOUBLE", tip: "Double soft 18 vs dealer 3-6" };
            if (dVal === 2 || dVal === 7 || dVal === 8) return { action: "STAND", label: "STAND", tip: "Stand on soft 18 vs 2, 7, 8" };
            return { action: "HIT", label: "HIT", tip: "Hit soft 18 vs strong dealer 9, 10, A" };
        }
        if (softTotal === 17) {
            if (canDouble && dVal >= 3 && dVal <= 6) return { action: "DOUBLE", label: "DOUBLE", tip: "Double soft 17 vs dealer 3-6" };
            return { action: "HIT", label: "HIT", tip: "Always hit or double soft 17" };
        }
        if (softTotal === 15 || softTotal === 16) {
            if (canDouble && dVal >= 4 && dVal <= 6) return { action: "DOUBLE", label: "DOUBLE", tip: "Double soft 15-16 vs dealer 4-6" };
            return { action: "HIT", label: "HIT", tip: "Safe hit on soft hand" };
        }
        if (softTotal === 13 || softTotal === 14) {
            if (canDouble && (dVal === 5 || dVal === 6)) return { action: "DOUBLE", label: "DOUBLE", tip: "Double soft 13-14 vs dealer 5-6" };
            return { action: "HIT", label: "HIT", tip: "Safe hit on soft hand" };
        }
    }
    
    // 3. Hard Totals
    var total = evalRes.total;
    if (total >= 17) {
        return { action: "STAND", label: "STAND", tip: "Stand on hard 17+" };
    }
    if (total >= 13 && total <= 16) {
        if (dVal >= 2 && dVal <= 6) {
            return { action: "STAND", label: "STAND", tip: "Stand: Dealer weak (" + getDealerBustProbability(dealerUpcard) + "% bust chance)" };
        }
        return { action: "HIT", label: "HIT", tip: "Hit: Dealer shows strength (" + (dVal === 11 ? "Ace" : dVal) + ")" };
    }
    if (total === 12) {
        if (dVal >= 4 && dVal <= 6) {
            return { action: "STAND", label: "STAND", tip: "Stand: Dealer bust chance is " + getDealerBustProbability(dealerUpcard) + "%" };
        }
        return { action: "HIT", label: "HIT", tip: "Hit 12 vs dealer " + (dVal === 11 ? "Ace" : dVal) };
    }
    if (total === 11) {
        if (canDouble) return { action: "DOUBLE", label: "DOUBLE", tip: "Double 11! Highest player advantage" };
        return { action: "HIT", label: "HIT", tip: "Hit 11" };
    }
    if (total === 10) {
        if (canDouble && dVal >= 2 && dVal <= 9) return { action: "DOUBLE", label: "DOUBLE", tip: "Double 10 vs dealer 2-9" };
        return { action: "HIT", label: "HIT", tip: "Hit 10 vs dealer 10 or Ace" };
    }
    if (total === 9) {
        if (canDouble && dVal >= 3 && dVal <= 6) return { action: "DOUBLE", label: "DOUBLE", tip: "Double 9 vs dealer 3-6" };
        return { action: "HIT", label: "HIT", tip: "Hit 9" };
    }
    
    return { action: "HIT", label: "HIT", tip: "Safe hit: 0% bust chance" };
}

/**
 * Checks if the dealer holds a natural 21 (Ace + 10-value card).
 */
function dealerHasNaturalBlackjack(dealerCards) {
    if (!dealerCards || dealerCards.length < 2) return false;
    var c1 = dealerCards[0];
    var c2 = dealerCards[1];
    var hasAce = (c1.value === "A" || c2.value === "A");
    var hasTen = (c1.numericValue === 10 || c2.numericValue === 10);
    return (hasAce && hasTen);
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
