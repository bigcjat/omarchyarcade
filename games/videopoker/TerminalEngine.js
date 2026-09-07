// Omarchy Arcade • Video Terminal Multi-Game Engine
// Pure JavaScript logic module (runs in QML JS engine and Node.js)
.pragma library

var SUITS = ["♠", "♥", "♦", "♣"];
var VALUES = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];

/**
 * Creates a standard 52-card deck.
 */
function createStandardDeck() {
    var deck = [];
    for (var s = 0; s < SUITS.length; s++) {
        var suit = SUITS[s];
        var isRed = (suit === "♥" || suit === "♦");
        for (var v = 0; v < VALUES.length; v++) {
            var val = VALUES[v];
            var rank = v + 2; // 2=2 ... 10=10, J=11, Q=12, K=13, A=14
            deck.push({
                suit: suit,
                value: val,
                rank: rank,
                isRed: isRed,
                isJoker: false,
                isWild: false,
                faceUp: true,
                id: suit + "_" + val + "_" + Math.random().toString(36).substring(2, 7)
            });
        }
    }
    return shuffle(deck);
}

/**
 * Creates a 53-card deck with 1 Joker wildcard (for Joker Poker).
 */
function createJokerDeck() {
    var deck = [];
    for (var s = 0; s < SUITS.length; s++) {
        var suit = SUITS[s];
        var isRed = (suit === "♥" || suit === "♦");
        for (var v = 0; v < VALUES.length; v++) {
            var val = VALUES[v];
            var rank = v + 2;
            deck.push({
                suit: suit,
                value: val,
                rank: rank,
                isRed: isRed,
                isJoker: false,
                isWild: false,
                faceUp: true,
                id: suit + "_" + val + "_" + Math.random().toString(36).substring(2, 7)
            });
        }
    }
    deck.push({
        suit: "★",
        value: "JK",
        rank: 0,
        isRed: false,
        isJoker: true,
        isWild: true,
        faceUp: true,
        id: "JOKER_" + Math.random().toString(36).substring(2, 7)
    });
    return shuffle(deck);
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

function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

// =============================================================================
// COMPLETE PAYTABLES FOR ALL 5 VIDEO POKER GAMES
// =============================================================================

var PAYTABLES = {
    // 1. Jacks or Better (9/6 Full Pay)
    "jacks_or_better": [
        { key: "royal_flush", name: "ROYAL FLUSH", pays: [250, 500, 750, 1000, 4000] },
        { key: "straight_flush", name: "STRAIGHT FLUSH", pays: [50, 100, 150, 200, 250] },
        { key: "four_of_a_kind", name: "4 OF A KIND", pays: [25, 50, 75, 100, 125] },
        { key: "full_house", name: "FULL HOUSE", pays: [9, 18, 27, 36, 45] },
        { key: "flush", name: "FLUSH", pays: [6, 12, 18, 24, 30] },
        { key: "straight", name: "STRAIGHT", pays: [4, 8, 12, 16, 20] },
        { key: "three_of_a_kind", name: "3 OF A KIND", pays: [3, 6, 9, 12, 15] },
        { key: "two_pair", name: "TWO PAIR", pays: [2, 4, 6, 8, 10] },
        { key: "jacks_or_better", name: "JACKS OR BETTER", pays: [1, 2, 3, 4, 5] }
    ],

    // 2. Deuces Wild (Full Pay)
    "deuces_wild": [
        { key: "natural_royal", name: "NATURAL ROYAL", pays: [250, 500, 750, 1000, 4000] },
        { key: "four_deuces", name: "FOUR DEUCES", pays: [200, 400, 600, 800, 1000] },
        { key: "wild_royal", name: "WILD ROYAL", pays: [25, 50, 75, 100, 125] },
        { key: "five_of_a_kind", name: "5 OF A KIND", pays: [15, 30, 45, 60, 75] },
        { key: "straight_flush", name: "STRAIGHT FLUSH", pays: [9, 18, 27, 36, 45] },
        { key: "four_of_a_kind", name: "4 OF A KIND", pays: [5, 10, 15, 20, 25] },
        { key: "full_house", name: "FULL HOUSE", pays: [3, 6, 9, 12, 15] },
        { key: "flush", name: "FLUSH", pays: [2, 4, 6, 8, 10] },
        { key: "straight", name: "STRAIGHT", pays: [2, 4, 6, 8, 10] },
        { key: "three_of_a_kind", name: "3 OF A KIND", pays: [1, 2, 3, 4, 5] }
    ],

    // 3. Joker Poker (Kings or Better)
    "joker_poker": [
        { key: "natural_royal", name: "NATURAL ROYAL", pays: [250, 500, 750, 1000, 4000] },
        { key: "five_of_a_kind", name: "5 OF A KIND", pays: [200, 400, 600, 800, 1000] },
        { key: "wild_royal", name: "WILD ROYAL", pays: [100, 200, 300, 400, 500] },
        { key: "straight_flush", name: "STRAIGHT FLUSH", pays: [50, 100, 150, 200, 250] },
        { key: "four_of_a_kind", name: "4 OF A KIND", pays: [20, 40, 60, 80, 100] },
        { key: "full_house", name: "FULL HOUSE", pays: [7, 14, 21, 28, 35] },
        { key: "flush", name: "FLUSH", pays: [5, 10, 15, 20, 25] },
        { key: "straight", name: "STRAIGHT", pays: [3, 6, 9, 12, 15] },
        { key: "three_of_a_kind", name: "3 OF A KIND", pays: [2, 4, 6, 8, 10] },
        { key: "two_pair", name: "TWO PAIR", pays: [1, 2, 3, 4, 5] },
        { key: "kings_or_better", name: "KINGS OR BETTER", pays: [1, 2, 3, 4, 5] }
    ],

    // 4. Double Double Bonus Poker
    "double_double_bonus": [
        { key: "royal_flush", name: "ROYAL FLUSH", pays: [250, 500, 750, 1000, 4000] },
        { key: "straight_flush", name: "STRAIGHT FLUSH", pays: [50, 100, 150, 200, 250] },
        { key: "four_aces_low_kicker", name: "4 ACES W/ 2,3,4", pays: [400, 800, 1200, 1600, 2000] },
        { key: "four_low_with_kicker", name: "4 2-4 W/ A,2,3,4", pays: [160, 320, 480, 640, 800] },
        { key: "four_aces", name: "4 ACES", pays: [160, 320, 480, 640, 800] },
        { key: "four_twos_threes_fours", name: "4 2s, 3s, OR 4s", pays: [80, 160, 240, 320, 400] },
        { key: "four_fives_kings", name: "4 5s THRU KINGS", pays: [50, 100, 150, 200, 250] },
        { key: "full_house", name: "FULL HOUSE", pays: [9, 18, 27, 36, 45] },
        { key: "flush", name: "FLUSH", pays: [6, 12, 18, 24, 30] },
        { key: "straight", name: "STRAIGHT", pays: [4, 8, 12, 16, 20] },
        { key: "three_of_a_kind", name: "3 OF A KIND", pays: [3, 6, 9, 12, 15] },
        { key: "two_pair", name: "TWO PAIR", pays: [1, 2, 3, 4, 5] },
        { key: "jacks_or_better", name: "JACKS OR BETTER", pays: [1, 2, 3, 4, 5] }
    ],

    // 5. Bonus Poker Deluxe
    "bonus_poker_deluxe": [
        { key: "royal_flush", name: "ROYAL FLUSH", pays: [250, 500, 750, 1000, 4000] },
        { key: "straight_flush", name: "STRAIGHT FLUSH", pays: [50, 100, 150, 200, 250] },
        { key: "four_of_a_kind", name: "4 OF A KIND (ANY)", pays: [80, 160, 240, 320, 400] },
        { key: "full_house", name: "FULL HOUSE", pays: [8, 16, 24, 32, 40] },
        { key: "flush", name: "FLUSH", pays: [6, 12, 18, 24, 30] },
        { key: "straight", name: "STRAIGHT", pays: [4, 8, 12, 16, 20] },
        { key: "three_of_a_kind", name: "3 OF A KIND", pays: [3, 6, 9, 12, 15] },
        { key: "two_pair", name: "TWO PAIR", pays: [1, 2, 3, 4, 5] },
        { key: "jacks_or_better", name: "JACKS OR BETTER", pays: [1, 2, 3, 4, 5] }
    ]
};

// =============================================================================
// HAND EVALUATORS
// =============================================================================

function isFlush(cards) {
    var s = cards[0].suit;
    for (var i = 1; i < cards.length; i++) {
        if (cards[i].suit !== s) return false;
    }
    return true;
}

function getRankCounts(cards) {
    var counts = {};
    for (var i = 0; i < cards.length; i++) {
        var r = cards[i].rank;
        counts[r] = (counts[r] || 0) + 1;
    }
    return counts;
}

function getSortedRanks(cards) {
    var ranks = cards.map(function(c) { return c.rank; });
    ranks.sort(function(a, b) { return a - b; });
    return ranks;
}

function isStraight(ranks) {
    // Normal straight check
    var normal = true;
    for (var i = 0; i < ranks.length - 1; i++) {
        if (ranks[i + 1] !== ranks[i] + 1) {
            normal = false;
            break;
        }
    }
    if (normal) return true;

    // Ace-low straight: A, 2, 3, 4, 5 -> ranks are 2, 3, 4, 5, 14
    if (ranks[0] === 2 && ranks[1] === 3 && ranks[2] === 4 && ranks[3] === 5 && ranks[4] === 14) {
        return true;
    }
    return false;
}

/**
 * 1. Evaluates Jacks or Better (9/6)
 */
function evaluateJacksOrBetter(cards) {
    if (!cards || cards.length !== 5) return null;

    var flush = isFlush(cards);
    var ranks = getSortedRanks(cards);
    var straight = isStraight(ranks);
    var counts = getRankCounts(cards);
    var countValues = Object.values(counts).sort(function(a, b) { return b - a; });

    // Royal Flush (10, J, Q, K, A suited)
    if (flush && straight && ranks[0] === 10 && ranks[4] === 14) {
        return { key: "royal_flush", name: "ROYAL FLUSH", rankLevel: 9 };
    }
    // Straight Flush
    if (flush && straight) {
        return { key: "straight_flush", name: "STRAIGHT FLUSH", rankLevel: 8 };
    }
    // Four of a Kind
    if (countValues[0] === 4) {
        return { key: "four_of_a_kind", name: "4 OF A KIND", rankLevel: 7 };
    }
    // Full House
    if (countValues[0] === 3 && countValues[1] === 2) {
        return { key: "full_house", name: "FULL HOUSE", rankLevel: 6 };
    }
    // Flush
    if (flush) {
        return { key: "flush", name: "FLUSH", rankLevel: 5 };
    }
    // Straight
    if (straight) {
        return { key: "straight", name: "STRAIGHT", rankLevel: 4 };
    }
    // Three of a Kind
    if (countValues[0] === 3) {
        return { key: "three_of_a_kind", name: "3 OF A KIND", rankLevel: 3 };
    }
    // Two Pair
    if (countValues[0] === 2 && countValues[1] === 2) {
        return { key: "two_pair", name: "TWO PAIR", rankLevel: 2 };
    }
    // Jacks or Better (Pair of J, Q, K, or A)
    if (countValues[0] === 2) {
        for (var r in counts) {
            if (counts[r] === 2 && parseInt(r, 10) >= 11) { // 11=J, 12=Q, 13=K, 14=A
                return { key: "jacks_or_better", name: "JACKS OR BETTER", rankLevel: 1 };
            }
        }
    }
    return null;
}

/**
 * 2. Evaluates Deuces Wild
 */
function evaluateDeucesWild(cards) {
    if (!cards || cards.length !== 5) return null;

    var deuces = 0;
    var naturals = [];
    for (var i = 0; i < 5; i++) {
        if (cards[i].rank === 2) {
            deuces++;
        } else {
            naturals.push(cards[i]);
        }
    }

    // Four Deuces
    if (deuces === 4) {
        return { key: "four_deuces", name: "FOUR DEUCES", rankLevel: 9.5 };
    }

    // If 0 deuces, standard evaluation with Natural Royal check
    if (deuces === 0) {
        var jb = evaluateJacksOrBetter(cards);
        if (jb) {
            if (jb.key === "royal_flush") return { key: "natural_royal", name: "NATURAL ROYAL", rankLevel: 10 };
            if (jb.key === "straight_flush") return { key: "straight_flush", name: "STRAIGHT FLUSH", rankLevel: 6 };
            if (jb.key === "four_of_a_kind") return { key: "four_of_a_kind", name: "4 OF A KIND", rankLevel: 5 };
            if (jb.key === "full_house") return { key: "full_house", name: "FULL HOUSE", rankLevel: 4 };
            if (jb.key === "flush") return { key: "flush", name: "FLUSH", rankLevel: 3 };
            if (jb.key === "straight") return { key: "straight", name: "STRAIGHT", rankLevel: 2 };
            if (jb.key === "three_of_a_kind") return { key: "three_of_a_kind", name: "3 OF A KIND", rankLevel: 1 };
        }
        return null;
    }

    // With Deuces (1, 2, or 3 wildcards)
    var nCounts = getRankCounts(naturals);
    var nCountVals = Object.values(nCounts).sort(function(a, b) { return b - a; });
    var maxRankCount = (nCountVals.length > 0) ? nCountVals[0] : 0;

    // Check 5 of a Kind
    if (maxRankCount + deuces >= 5) {
        return { key: "five_of_a_kind", name: "5 OF A KIND", rankLevel: 7 };
    }

    // Check Wild Royal Flush
    // Naturals must all be 10, J, Q, K, or A of the exact same suit
    var royalRanks = [10, 11, 12, 13, 14];
    var suitMap = {};
    for (var ni = 0; ni < naturals.length; ni++) {
        var nc = naturals[ni];
        suitMap[nc.suit] = (suitMap[nc.suit] || []);
        suitMap[nc.suit].push(nc.rank);
    }
    for (var s in suitMap) {
        var sRanks = suitMap[s];
        var isAllRoyal = true;
        for (var ri = 0; ri < sRanks.length; ri++) {
            if (royalRanks.indexOf(sRanks[ri]) === -1) {
                isAllRoyal = false; break;
            }
        }
        var uniqueRoyalRanks = Array.from(new Set(sRanks));
        if (isAllRoyal && uniqueRoyalRanks.length === sRanks.length && (uniqueRoyalRanks.length + deuces === 5)) {
            return { key: "wild_royal", name: "WILD ROYAL", rankLevel: 8 };
        }
    }

    // Check Straight Flush with Deuces
    for (var st in suitMap) {
        var suitedNaturals = suitMap[st];
        if (suitedNaturals.length + deuces >= 5) {
            // Test all possible 5-card straight windows [1..5], [2..6] ... [10..14]
            for (var low = 1; low <= 10; low++) {
                var windowRanks = (low === 1) ? [14, 2, 3, 4, 5] : [low, low+1, low+2, low+3, low+4];
                var matched = 0;
                for (var wi = 0; wi < windowRanks.length; wi++) {
                    if (windowRanks[wi] === 2) continue; // 2 is wild
                    if (suitedNaturals.indexOf(windowRanks[wi]) !== -1) matched++;
                }
                if (matched + deuces >= 5) {
                    return { key: "straight_flush", name: "STRAIGHT FLUSH", rankLevel: 6 };
                }
            }
        }
    }

    // Check 4 of a Kind
    if (maxRankCount + deuces >= 4) {
        return { key: "four_of_a_kind", name: "4 OF A KIND", rankLevel: 5 };
    }

    // Check Full House
    // E.g. with 1 deuce: two pairs + 1 deuce = full house
    if (deuces === 1 && nCountVals[0] === 2 && nCountVals[1] === 2) {
        return { key: "full_house", name: "FULL HOUSE", rankLevel: 4 };
    }

    // Check Flush with Deuces
    for (var su in suitMap) {
        if (suitMap[su].length + deuces >= 5) {
            return { key: "flush", name: "FLUSH", rankLevel: 3 };
        }
    }

    // Check Straight with Deuces
    var natRanks = Array.from(new Set(naturals.map(function(c) { return c.rank; })));
    for (var lowR = 1; lowR <= 10; lowR++) {
        var req = (lowR === 1) ? [14, 2, 3, 4, 5] : [lowR, lowR+1, lowR+2, lowR+3, lowR+4];
        var matchCount = 0;
        for (var qi = 0; qi < req.length; qi++) {
            if (req[qi] === 2) continue;
            if (natRanks.indexOf(req[qi]) !== -1) matchCount++;
        }
        if (matchCount + deuces >= 5) {
            return { key: "straight", name: "STRAIGHT", rankLevel: 2 };
        }
    }

    // Check 3 of a Kind
    if (maxRankCount + deuces >= 3) {
        return { key: "three_of_a_kind", name: "3 OF A KIND", rankLevel: 1 };
    }

    return null;
}

/**
 * 3. Evaluates Joker Poker (Kings or Better)
 */
function evaluateJokerPoker(cards) {
    if (!cards || cards.length !== 5) return null;

    var hasJoker = false;
    var naturals = [];
    for (var i = 0; i < 5; i++) {
        if (cards[i].isJoker) {
            hasJoker = true;
        } else {
            naturals.push(cards[i]);
        }
    }

    // Without Joker
    if (!hasJoker) {
        var jb = evaluateJacksOrBetter(cards);
        if (jb) {
            if (jb.key === "royal_flush") return { key: "natural_royal", name: "NATURAL ROYAL", rankLevel: 10 };
            if (jb.key === "straight_flush") return { key: "straight_flush", name: "STRAIGHT FLUSH", rankLevel: 7 };
            if (jb.key === "four_of_a_kind") return { key: "four_of_a_kind", name: "4 OF A KIND", rankLevel: 6 };
            if (jb.key === "full_house") return { key: "full_house", name: "FULL HOUSE", rankLevel: 5 };
            if (jb.key === "flush") return { key: "flush", name: "FLUSH", rankLevel: 4 };
            if (jb.key === "straight") return { key: "straight", name: "STRAIGHT", rankLevel: 3 };
            if (jb.key === "three_of_a_kind") return { key: "three_of_a_kind", name: "3 OF A KIND", rankLevel: 2 };
            if (jb.key === "two_pair") return { key: "two_pair", name: "TWO PAIR", rankLevel: 1.5 };
            if (jb.key === "jacks_or_better") {
                // Must be Kings or Better (rank 13 or 14)
                var counts = getRankCounts(cards);
                for (var r in counts) {
                    if (counts[r] === 2 && parseInt(r, 10) >= 13) {
                        return { key: "kings_or_better", name: "KINGS OR BETTER", rankLevel: 1 };
                    }
                }
            }
        }
        return null;
    }

    // With Joker (1 wild card)
    var nCounts = getRankCounts(naturals);
    var nCountVals = Object.values(nCounts).sort(function(a, b) { return b - a; });
    var maxCount = nCountVals[0];

    // 5 of a Kind (4 naturals + Joker)
    if (maxCount === 4) {
        return { key: "five_of_a_kind", name: "5 OF A KIND", rankLevel: 9 };
    }

    // Wild Royal Flush
    var isNatFlush = isFlush(naturals);
    var natRanks = naturals.map(function(c) { return c.rank; }).sort(function(a, b) { return a - b; });
    var royalRanks = [10, 11, 12, 13, 14];
    var is4ToRoyal = isNatFlush && natRanks.every(function(r) { return royalRanks.indexOf(r) !== -1; });
    if (is4ToRoyal) {
        return { key: "wild_royal", name: "WILD ROYAL", rankLevel: 8 };
    }

    // Straight Flush with Joker
    if (isNatFlush) {
        for (var low = 1; low <= 10; low++) {
            var win = (low === 1) ? [14, 2, 3, 4, 5] : [low, low+1, low+2, low+3, low+4];
            var m = 0;
            for (var w = 0; w < win.length; w++) {
                if (natRanks.indexOf(win[w]) !== -1) m++;
            }
            if (m === 4) {
                return { key: "straight_flush", name: "STRAIGHT FLUSH", rankLevel: 7 };
            }
        }
    }

    // Four of a Kind (3 naturals + Joker)
    if (maxCount === 3) {
        return { key: "four_of_a_kind", name: "4 OF A KIND", rankLevel: 6 };
    }

    // Full House (2 pair + Joker)
    if (nCountVals[0] === 2 && nCountVals[1] === 2) {
        return { key: "full_house", name: "FULL HOUSE", rankLevel: 5 };
    }

    // Flush with Joker
    if (isNatFlush) {
        return { key: "flush", name: "FLUSH", rankLevel: 4 };
    }

    // Straight with Joker
    var uniqueRanks = Array.from(new Set(natRanks));
    for (var lowR = 1; lowR <= 10; lowR++) {
        var winR = (lowR === 1) ? [14, 2, 3, 4, 5] : [lowR, lowR+1, lowR+2, lowR+3, lowR+4];
        var mc = 0;
        for (var wr = 0; wr < winR.length; wr++) {
            if (uniqueRanks.indexOf(winR[wr]) !== -1) mc++;
        }
        if (mc === 4) {
            return { key: "straight", name: "STRAIGHT", rankLevel: 3 };
        }
    }

    // Three of a Kind (1 pair + Joker)
    if (maxCount === 2) {
        return { key: "three_of_a_kind", name: "3 OF A KIND", rankLevel: 2 };
    }

    // Kings or Better (single K or A + Joker)
    for (var nr = 0; nr < natRanks.length; nr++) {
        if (natRanks[nr] >= 13) {
            return { key: "kings_or_better", name: "KINGS OR BETTER", rankLevel: 1 };
        }
    }

    return null;
}

/**
 * 4. Evaluates Double Double Bonus Poker
 */
function evaluateDoubleDoubleBonus(cards) {
    if (!cards || cards.length !== 5) return null;

    var counts = getRankCounts(cards);
    var countVals = Object.values(counts).sort(function(a, b) { return b - a; });

    // Four of a Kind special kicker rules
    if (countVals[0] === 4) {
        var quadRank = 0;
        var kickerRank = 0;
        for (var r in counts) {
            if (counts[r] === 4) quadRank = parseInt(r, 10);
            else kickerRank = parseInt(r, 10);
        }

        // 4 Aces
        if (quadRank === 14) {
            if (kickerRank >= 2 && kickerRank <= 4) {
                return { key: "four_aces_low_kicker", name: "4 ACES W/ 2,3,4", rankLevel: 8.5 };
            }
            return { key: "four_aces", name: "4 ACES", rankLevel: 7.5 };
        }

        // 4 2s, 3s, or 4s
        if (quadRank >= 2 && quadRank <= 4) {
            if (kickerRank === 14 || (kickerRank >= 2 && kickerRank <= 4)) {
                return { key: "four_low_with_kicker", name: "4 2-4 W/ A,2,3,4", rankLevel: 7.5 };
            }
            return { key: "four_twos_threes_fours", name: "4 2s, 3s, OR 4s", rankLevel: 7.2 };
        }

        // 4 5s through Kings
        return { key: "four_fives_kings", name: "4 5s THRU KINGS", rankLevel: 7.0 };
    }

    // Evaluate standard non-quad hands
    return evaluateJacksOrBetter(cards);
}

/**
 * 5. Evaluates Bonus Poker Deluxe
 */
function evaluateBonusPokerDeluxe(cards) {
    if (!cards || cards.length !== 5) return null;

    var counts = getRankCounts(cards);
    var countVals = Object.values(counts).sort(function(a, b) { return b - a; });

    // Flat 80:1 for ANY 4 of a kind
    if (countVals[0] === 4) {
        return { key: "four_of_a_kind", name: "4 OF A KIND (ANY)", rankLevel: 7.5 };
    }

    return evaluateJacksOrBetter(cards);
}

/**
 * Master hand evaluator by game type.
 */
function evaluateHand(gameType, cards) {
    switch (gameType) {
        case "deuces_wild":
            return evaluateDeucesWild(cards);
        case "joker_poker":
            return evaluateJokerPoker(cards);
        case "double_double_bonus":
            return evaluateDoubleDoubleBonus(cards);
        case "bonus_poker_deluxe":
            return evaluateBonusPokerDeluxe(cards);
        case "jacks_or_better":
        default:
            return evaluateJacksOrBetter(cards);
    }
}

/**
 * Calculates winning coin payout.
 */
function getPayout(gameType, handKey, betCoins) {
    if (!handKey || !PAYTABLES[gameType]) return 0;
    var table = PAYTABLES[gameType];
    for (var i = 0; i < table.length; i++) {
        if (table[i].key === handKey) {
            var colIdx = Math.max(0, Math.min(4, betCoins - 1));
            return table[i].pays[colIdx];
        }
    }
    return 0;
}

// =============================================================================
// GAME 6: RED DOG (ACEY-DEUCEY / IN-BETWEEN)
// =============================================================================

/**
 * Initializes a fresh Red Dog deal.
 */
function initRedDogDeal(deck) {
    if (!deck || deck.length < 5) deck = shuffle(createStandardDeck());
    var card1 = deck.pop();
    var card2 = deck.pop();

    var r1 = card1.rank;
    var r2 = card2.rank;
    var low = Math.min(r1, r2);
    var high = Math.max(r1, r2);

    // Spread = gap between them
    var spread = (high > low) ? (high - low - 1) : 0;
    var status = "spread"; // "spread", "consecutive", "pair"

    if (r1 === r2) {
        status = "pair";
    } else if (spread === 0) {
        status = "consecutive";
    }

    return {
        card1: card1,
        card2: card2,
        card3: null,
        spread: spread,
        status: status,
        remainingDeck: deck
    };
}

/**
 * Resolves Red Dog 3rd card deal.
 */
function resolveRedDogThirdCard(card1, card2, card3, spread, originalStatus) {
    var r1 = card1.rank;
    var r2 = card2.rank;
    var r3 = card3.rank;

    if (originalStatus === "pair") {
        // 3 of a kind pays 11:1, otherwise push
        if (r3 === r1) {
            return { result: "win", multiplier: 11, desc: "THREE OF A KIND! (11:1)" };
        } else {
            return { result: "push", multiplier: 0, desc: "PAIR PUSH" };
        }
    }

    if (originalStatus === "consecutive") {
        return { result: "push", multiplier: 0, desc: "CONSECUTIVE PUSH" };
    }

    var low = Math.min(r1, r2);
    var high = Math.max(r1, r2);

    if (r3 > low && r3 < high) {
        // Winner!
        var mult = 1;
        if (spread === 1) mult = 5;
        else if (spread === 2) mult = 4;
        else if (spread === 3) mult = 2;
        else mult = 1;

        return { result: "win", multiplier: mult, desc: "IN-BETWEEN WIN! (" + mult + ":1)" };
    } else {
        return { result: "loss", multiplier: 0, desc: "OUTSIDE - DEALER WINS" };
    }
}

// =============================================================================
// GAME 7: SINGLE-DECK VIDEO BLACKJACK
// =============================================================================

function calculateBlackjackTotal(cards) {
    var total = 0;
    var aces = 0;
    for (var i = 0; i < cards.length; i++) {
        var r = cards[i].rank;
        if (r === 14) {
            aces++;
            total += 11;
        } else if (r >= 10) {
            total += 10;
        } else {
            total += r;
        }
    }
    while (total > 21 && aces > 0) {
        total -= 10;
        aces--;
    }
    return total;
}

function initBlackjackDeal(deck) {
    if (!deck || deck.length < 10) deck = shuffle(createStandardDeck());
    var pCard1 = deck.pop();
    var dCard1 = deck.pop(); // Upcard
    var pCard2 = deck.pop();
    var dCard2 = deck.pop(); // Hole card (face down initially)
    dCard2.faceUp = false;

    var pHand = [pCard1, pCard2];
    var dHand = [dCard1, dCard2];

    var pTotal = calculateBlackjackTotal(pHand);
    var isNaturalBJ = (pTotal === 21);

    return {
        playerHand: pHand,
        dealerHand: dHand,
        isNaturalBlackjack: isNaturalBJ,
        remainingDeck: deck
    };
}

function dealerDrawBlackjack(dealerHand, deck) {
    dealerHand[1].faceUp = true; // Reveal hole card
    var total = calculateBlackjackTotal(dealerHand);
    while (total < 17) {
        var c = deck.pop();
        c.faceUp = true;
        dealerHand.push(c);
        total = calculateBlackjackTotal(dealerHand);
    }
    return {
        dealerHand: dealerHand,
        dealerTotal: total,
        isBust: total > 21,
        remainingDeck: deck
    };
}

// =============================================================================
// GAME 8: CASINO WAR
// =============================================================================

function initCasinoWarDeal(deck) {
    if (!deck || deck.length < 10) deck = shuffle(createStandardDeck());
    var pCard = deck.pop();
    var dCard = deck.pop();

    var pRank = pCard.rank; // Aces are 14
    var dRank = dCard.rank;

    var outcome = "tie";
    if (pRank > dRank) outcome = "win";
    else if (pRank < dRank) outcome = "loss";

    return {
        playerCard: pCard,
        dealerCard: dCard,
        outcome: outcome,
        remainingDeck: deck
    };
}

function resolveCasinoWarGoToWar(deck) {
    // Burn 3 cards
    deck.pop(); deck.pop(); deck.pop();
    var pWarCard = deck.pop();
    deck.pop(); deck.pop(); deck.pop();
    var dWarCard = deck.pop();

    var pRank = pWarCard.rank;
    var dRank = dWarCard.rank;

    // Player wins on tie or higher
    var won = (pRank >= dRank);

    return {
        playerWarCard: pWarCard,
        dealerWarCard: dWarCard,
        playerWon: won,
        isTie: (pRank === dRank),
        remainingDeck: deck
    };
}

// =============================================================================
// BONUS GAME: DOUBLE-UP HIGH-CARD GAMBLE
// =============================================================================

function initDoubleUpGamble(deck) {
    if (!deck || deck.length < 6) deck = shuffle(createStandardDeck());
    var dCard = deck.pop();
    dCard.faceUp = true;

    var pCards = [];
    for (var i = 0; i < 4; i++) {
        var c = deck.pop();
        c.faceUp = false;
        pCards.push(c);
    }

    return {
        dealerCard: dCard,
        playerCards: pCards,
        remainingDeck: deck
    };
}

function resolveDoubleUp(dealerCard, pickedCard) {
    pickedCard.faceUp = true;
    if (pickedCard.rank > dealerCard.rank) {
        return "win";
    } else if (pickedCard.rank === dealerCard.rank) {
        return "tie";
    } else {
        return "loss";
    }
}
