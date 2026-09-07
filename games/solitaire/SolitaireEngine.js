// Omarchy Arcade • Klondike Solitaire Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

var SUITS = ["♠", "♥", "♦", "♣"];
var VALUES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

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
            var rank = v + 1; // A=1, 2=2, ..., 10=10, J=11, Q=12, K=13
            deck.push({
                suit: suit,
                value: val,
                rank: rank,
                isRed: isRed,
                faceUp: false,
                id: suit + "_" + val + "_" + Math.random().toString(36).substring(2, 7)
            });
        }
    }
    return deck;
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
 * Deep clones any JS object or array.
 */
function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

/**
 * Initializes a standard Klondike Solitaire deal.
 * 7 tableau columns (28 cards), 4 empty foundations, remaining 24 in stock.
 */
function initDeal() {
    var deck = shuffle(createDeck());
    var tableau = [[], [], [], [], [], [], []];

    // Deal 7 tableau columns
    for (var col = 0; col < 7; col++) {
        for (var row = 0; row <= col; row++) {
            var card = deck.pop();
            // Top-most card of each column is face up
            card.faceUp = (row === col);
            tableau[col].push(card);
        }
    }

    // Foundations (4 empty piles: indices 0..3 for ♠, ♥, ♦, ♣)
    var foundations = [[], [], [], []];

    // Stock pile (remaining 24 cards, all face down)
    var stock = [];
    while (deck.length > 0) {
        var c = deck.pop();
        c.faceUp = false;
        stock.push(c);
    }

    // Waste pile (initially empty)
    var waste = [];

    return {
        tableau: tableau,
        foundations: foundations,
        stock: stock,
        waste: waste,
        score: 0,
        moves: 0
    };
}

/**
 * Checks if a single card can legally be placed on a foundation pile.
 */
function canMoveToFoundation(card, foundationPile) {
    if (!card || !card.faceUp) return false;

    if (foundationPile.length === 0) {
        // Only Aces (rank 1) can start a foundation
        return card.rank === 1;
    }

    var topCard = foundationPile[foundationPile.length - 1];
    return (card.suit === topCard.suit && card.rank === topCard.rank + 1);
}

/**
 * Finds the index of a foundation pile that can accept this card (or -1 if none).
 */
function findTargetFoundation(card, foundations) {
    for (var f = 0; f < 4; f++) {
        if (canMoveToFoundation(card, foundations[f])) {
            return f;
        }
    }
    return -1;
}

/**
 * Checks if a card (or base of a stack) can legally be placed on a tableau column.
 */
function canMoveToTableau(card, tableauCol) {
    if (!card || !card.faceUp) return false;

    if (tableauCol.length === 0) {
        // Only Kings (rank 13) can be placed in an empty tableau space
        return card.rank === 13;
    }

    var topCard = tableauCol[tableauCol.length - 1];
    if (!topCard.faceUp) return false;

    // Must alternate colors and descend by rank by exactly 1
    return (card.isRed !== topCard.isRed && card.rank === topCard.rank - 1);
}

/**
 * Checks if a sequence of cards in a tableau column starting at startIndex is valid to move.
 * Must be all faceUp and descending alternating colors.
 */
function isValidSubstack(col, startIndex) {
    if (startIndex < 0 || startIndex >= col.length) return false;
    for (var i = startIndex; i < col.length - 1; i++) {
        var curr = col[i];
        var next = col[i + 1];
        if (!curr.faceUp || !next.faceUp) return false;
        if (curr.isRed === next.isRed || curr.rank !== next.rank + 1) return false;
    }
    return col[startIndex].faceUp;
}

/**
 * Draws from stock into waste according to drawCount (1 or 3).
 * If stock is empty, recycles waste back into stock.
 */
function drawStock(stock, waste, drawCount) {
    if (drawCount !== 3) drawCount = 1;

    if (stock.length > 0) {
        var count = Math.min(drawCount, stock.length);
        for (var i = 0; i < count; i++) {
            var card = stock.pop();
            card.faceUp = true;
            waste.push(card);
        }
        return { action: "draw", count: count };
    } else if (waste.length > 0) {
        // Recycle waste back into stock (flipped face-down, in reverse draw order)
        while (waste.length > 0) {
            var c = waste.pop();
            c.faceUp = false;
            stock.push(c);
        }
        return { action: "recycle", count: stock.length };
    }
    return { action: "none", count: 0 };
}

/**
 * Auto-exposes the top card of a tableau column if it was face-down.
 * Returns true if a card was flipped.
 */
function checkFlipTableauTop(col) {
    if (col && col.length > 0) {
        var top = col[col.length - 1];
        if (!top.faceUp) {
            top.faceUp = true;
            return true;
        }
    }
    return false;
}

/**
 * Finds the best single-click legal move for a card.
 * Priority:
 * 1. Foundation
 * 2. Another Tableau column
 */
function findBestAutoMove(sourceType, sourceIndex, cardIndex, state) {
    var card = null;
    var movingStack = [];

    if (sourceType === "waste") {
        if (state.waste.length === 0) return null;
        card = state.waste[state.waste.length - 1];
        movingStack = [card];
    } else if (sourceType === "tableau") {
        var col = state.tableau[sourceIndex];
        if (!col || cardIndex < 0 || cardIndex >= col.length) return null;
        card = col[cardIndex];
        if (!card.faceUp) return null;
        if (!isValidSubstack(col, cardIndex)) return null;
        movingStack = col.slice(cardIndex);
    } else if (sourceType === "foundation") {
        // Moving from foundation to tableau
        var fPile = state.foundations[sourceIndex];
        if (!fPile || fPile.length === 0) return null;
        card = fPile[fPile.length - 1];
        movingStack = [card];
    }

    if (!card) return null;

    // 1. Try Foundation (only for single cards)
    if (movingStack.length === 1 && sourceType !== "foundation") {
        var fTarget = findTargetFoundation(card, state.foundations);
        if (fTarget !== -1) {
            return {
                targetType: "foundation",
                targetIndex: fTarget,
                scoreDelta: (sourceType === "waste") ? 10 : 10
            };
        }
    }

    // 2. Try Tableau
    for (var t = 0; t < 7; t++) {
        if (sourceType === "tableau" && sourceIndex === t) continue;
        if (canMoveToTableau(card, state.tableau[t])) {
            // Avoid useless moving of King to another empty column
            if (card.rank === 13 && state.tableau[t].length === 0) {
                if (sourceType === "tableau" && cardIndex === 0) continue;
            }
            return {
                targetType: "tableau",
                targetIndex: t,
                scoreDelta: (sourceType === "waste") ? 5 : (sourceType === "foundation" ? -15 : 0)
            };
        }
    }

    return null;
}

/**
 * Checks if the game is won (all 4 foundations have 13 cards = 52 total).
 */
function checkWon(foundations) {
    var total = 0;
    for (var f = 0; f < 4; f++) {
        total += foundations[f].length;
    }
    return total === 52;
}

/**
 * Checks if all remaining unplaced cards are face-up and stock/waste are clear.
 * When true, player has solved the puzzle and can auto-finish.
 */
function canAutoComplete(stock, waste, tableau) {
    if (stock.length > 0 || waste.length > 0) return false;
    for (var c = 0; c < 7; c++) {
        for (var r = 0; r < tableau[c].length; r++) {
            if (!tableau[c][r].faceUp) return false;
        }
    }
    return true;
}

/**
 * Executes a single auto-complete step.
 * Moves one card from a tableau to its matching foundation.
 * Returns true if a move was made, false if none available.
 */
function stepAutoComplete(tableau, foundations) {
    for (var c = 0; c < 7; c++) {
        if (tableau[c].length > 0) {
            var top = tableau[c][tableau[c].length - 1];
            var fIdx = findTargetFoundation(top, foundations);
            if (fIdx !== -1) {
                foundations[fIdx].push(tableau[c].pop());
                return true;
            }
        }
    }
    return false;
}

/**
 * Generates a helpful hint for the user.
 */
function getHint(state) {
    // 1. Check waste to foundation
    if (state.waste.length > 0) {
        var wc = state.waste[state.waste.length - 1];
        var f = findTargetFoundation(wc, state.foundations);
        if (f !== -1) {
            return { from: "waste", to: "foundation " + (f + 1), card: wc.value + wc.suit };
        }
    }

    // 2. Check tableau to foundation
    for (var c = 0; c < 7; c++) {
        if (state.tableau[c].length > 0) {
            var tc = state.tableau[c][state.tableau[c].length - 1];
            var fIdx = findTargetFoundation(tc, state.foundations);
            if (fIdx !== -1) {
                return { from: "col " + (c + 1), to: "foundation " + (fIdx + 1), card: tc.value + tc.suit };
            }
        }
    }

    // 3. Check tableau to tableau
    for (var c1 = 0; c1 < 7; c1++) {
        var col1 = state.tableau[c1];
        for (var r = 0; r < col1.length; r++) {
            if (col1[r].faceUp && isValidSubstack(col1, r)) {
                var card = col1[r];
                for (var c2 = 0; c2 < 7; c2++) {
                    if (c1 === c2) continue;
                    if (canMoveToTableau(card, state.tableau[c2])) {
                        if (card.rank === 13 && state.tableau[c2].length === 0 && r === 0) continue;
                        return { from: "col " + (c1 + 1), to: "col " + (c2 + 1), card: card.value + card.suit };
                    }
                }
            }
        }
    }

    // 4. Check waste to tableau
    if (state.waste.length > 0) {
        var wCard = state.waste[state.waste.length - 1];
        for (var t = 0; t < 7; t++) {
            if (canMoveToTableau(wCard, state.tableau[t])) {
                return { from: "waste", to: "col " + (t + 1), card: wCard.value + wCard.suit };
            }
        }
    }

    // 5. Stock draw available?
    if (state.stock.length > 0 || state.waste.length > 0) {
        return { from: "stock", to: "waste", card: "Draw Card" };
    }

    return null;
}
