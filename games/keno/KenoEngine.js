// =============================================================================
// Modern Keno • Complete Game Engine (8-in-1 Casino Multi-Game Terminal)
// =============================================================================

.pragma library

// Active game state
// Variants: "classic", "power", "super", "cleopatra", "caveman", "extradraw", "goldmine", "triplepower"
var activeVariant = "classic";
var selectedSpots = [];        // Player picks: integers 1..80
var drawnNumbers = [];         // Drawn numbers in order
var hitNumbers = [];           // Intersection of selectedSpots and drawnNumbers
var drawIndex = 0;             // Current ball being revealed (1..20 or 23)
var isDrawing = false;
var betAmount = 5;
var credits = 1000;
var lastWin = 0;
var multiplier = 1;

// Variant-specific state flags & bonus trackers
var isPowerHit = false;
var isSuperHit = false;
var freeGamesRemaining = 0;
var freeGamesTotalWon = 0;
var isFreeGameActive = false;

// 1. Caveman Keno: 3 Dinosaur Eggs randomly placed at round start
var cavemanEggs = [];          // 3 numbers 1..80
var cavemanHatchedCount = 0;   // 0, 1, 2, or 3

// 2. Extra Draw Keno: When 1 hit away from a paytier, 3 extra balls (21..23) are drawn
var extraDrawTriggered = false;

// 3. Gold Mine Keno: 4 Gold Nuggets awarding instant credits + 1 Dynamite Stick
var goldNuggets = [];          // 4 numbers 1..80
var dynamiteSpot = 0;          // 1 number 1..80
var goldMineBonusWon = 0;      // Instant credit bonus won during the draw

// 4. Triple Power Keno: 1st ball = 3X, 20th ball = 3X, both = 9X Super Multiplier
var triplePowerBall1Hit = false;
var triplePowerBall20Hit = false;

// Statistics: frequency map for 1..80
var numberFrequencies = {};
for (var i = 1; i <= 80; i++) {
    numberFrequencies[i] = 0;
}
var totalRoundsPlayed = 0;

// Standard Casino VLT Paytables: paytable[spots_count][hits_count] = multiplier
var PAYTABLES = {
    2: { 2: 11 },
    3: { 2: 2, 3: 45 },
    4: { 2: 1, 3: 4, 4: 120 },
    5: { 3: 3, 4: 18, 5: 800 },
    6: { 3: 1, 4: 7, 5: 90, 6: 1600 },
    7: { 3: 1, 4: 3, 5: 20, 6: 400, 7: 7000 },
    8: { 4: 2, 5: 10, 6: 80, 7: 1500, 8: 10000 },
    9: { 4: 1, 5: 5, 6: 40, 7: 300, 8: 4000, 9: 15000 },
    10: { 0: 5, 5: 3, 6: 20, 7: 100, 8: 1000, 9: 5000, 10: 25000 }
};

var VALID_VARIANTS = [
    "classic", "power", "super", "cleopatra",
    "caveman", "extradraw", "goldmine", "triplepower"
];

function setVariant(variant) {
    if (VALID_VARIANTS.indexOf(variant) >= 0) {
        activeVariant = variant;
    }
}

function getVariant() {
    return activeVariant;
}

function getCavemanEggs() {
    return cavemanEggs.slice();
}

function getCavemanHatchedCount() {
    return cavemanHatchedCount;
}

function getGoldNuggets() {
    return goldNuggets.slice();
}

function getDynamiteSpot() {
    return dynamiteSpot;
}

function isExtraDrawTriggered() {
    return extraDrawTriggered;
}

function getSelectedSpots() {
    return selectedSpots.slice().sort(function(a, b) { return a - b; });
}

function toggleSpot(num) {
    if (isDrawing) return false;
    num = parseInt(num);
    if (isNaN(num) || num < 1 || num > 80) return false;

    var idx = selectedSpots.indexOf(num);
    if (idx >= 0) {
        selectedSpots.splice(idx, 1);
        return false;
    } else {
        if (selectedSpots.length >= 10) return false;
        selectedSpots.push(num);
        return true;
    }
}

function setSpot(num, select) {
    if (isDrawing) return false;
    num = parseInt(num);
    if (isNaN(num) || num < 1 || num > 80) return false;

    var idx = selectedSpots.indexOf(num);
    if (select) {
        if (idx === -1) {
            if (selectedSpots.length >= 10) return false;
            selectedSpots.push(num);
            return true;
        }
    } else {
        if (idx >= 0) {
            selectedSpots.splice(idx, 1);
            return true;
        }
    }
    return false;
}

function isSpotSelected(num) {
    return selectedSpots.indexOf(num) >= 0;
}

function clearSpots() {
    if (isDrawing) return;
    selectedSpots = [];
}

function quickPick(count) {
    if (isDrawing) return;
    count = Math.max(2, Math.min(10, count || 5));
    selectedSpots = [];
    var pool = [];
    for (var i = 1; i <= 80; i++) pool.push(i);
    for (var j = pool.length - 1; j > 0; j--) {
        var k = Math.floor(Math.random() * (j + 1));
        var temp = pool[j];
        pool[j] = pool[k];
        pool[k] = temp;
    }
    selectedSpots = pool.slice(0, count);
}

function quickPickHot(count) {
    if (isDrawing) return;
    count = Math.max(2, Math.min(10, count || 5));
    var sorted = getHotNumbers();
    selectedSpots = sorted.slice(0, count);
}

function quickPickCold(count) {
    if (isDrawing) return;
    count = Math.max(2, Math.min(10, count || 5));
    var sorted = getColdNumbers();
    selectedSpots = sorted.slice(0, count);
}

function getHotNumbers() {
    var list = [];
    for (var i = 1; i <= 80; i++) {
        list.push({ num: i, count: numberFrequencies[i] || 0 });
    }
    list.sort(function(a, b) {
        if (b.count !== a.count) return b.count - a.count;
        return a.num - b.num;
    });
    return list.map(function(item) { return item.num; });
}

function getColdNumbers() {
    var list = [];
    for (var i = 1; i <= 80; i++) {
        list.push({ num: i, count: numberFrequencies[i] || 0 });
    }
    list.sort(function(a, b) {
        if (a.count !== b.count) return a.count - b.count;
        return a.num - b.num;
    });
    return list.map(function(item) { return item.num; });
}

function getPaytableForSpots(spotsCount) {
    return PAYTABLES[spotsCount] || null;
}

function getPayoutMultiplier(spotsCount, hitCount) {
    var table = PAYTABLES[spotsCount];
    if (!table) return 0;
    return table[hitCount] || 0;
}

function prepareDraw() {
    if (selectedSpots.length < 2) {
        return { success: false, reason: "Pick at least 2 spots" };
    }
    if (!isFreeGameActive && credits < betAmount) {
        return { success: false, reason: "Insufficient credits" };
    }

    if (!isFreeGameActive) {
        credits -= betAmount;
    }

    totalRoundsPlayed++;
    isDrawing = true;
    drawnNumbers = [];
    hitNumbers = [];
    drawIndex = 0;
    lastWin = 0;
    multiplier = 1;
    isPowerHit = false;
    isSuperHit = false;
    extraDrawTriggered = false;
    goldMineBonusWon = 0;
    triplePowerBall1Hit = false;
    triplePowerBall20Hit = false;

    // Shuffle pool of 80 numbers
    var pool = [];
    for (var i = 1; i <= 80; i++) pool.push(i);
    for (var j = pool.length - 1; j > 0; j--) {
        var r = Math.floor(Math.random() * (j + 1));
        var tmp = pool[j];
        pool[j] = pool[r];
        pool[r] = tmp;
    }

    // Always draw up to 23 balls so Extra Draw has prepared numbers ready
    var finalDraw = pool.slice(0, 23);

    // Setup Caveman Eggs: 3 random numbers on the board
    cavemanEggs = [];
    cavemanHatchedCount = 0;
    if (activeVariant === "caveman") {
        var eggPool = [];
        for (var e = 1; e <= 80; e++) eggPool.push(e);
        for (var ep = eggPool.length - 1; ep > 0; ep--) {
            var er = Math.floor(Math.random() * (ep + 1));
            var etmp = eggPool[ep];
            eggPool[ep] = eggPool[er];
            eggPool[er] = etmp;
        }
        cavemanEggs = eggPool.slice(0, 3);
    }

    // Setup Gold Mine Nuggets & Dynamite
    goldNuggets = [];
    dynamiteSpot = 0;
    if (activeVariant === "goldmine") {
        var goldPool = [];
        for (var g = 1; g <= 80; g++) goldPool.push(g);
        for (var gp = goldPool.length - 1; gp > 0; gp--) {
            var gr = Math.floor(Math.random() * (gp + 1));
            var gtmp = goldPool[gp];
            goldPool[gp] = goldPool[gr];
            goldPool[gr] = gtmp;
        }
        goldNuggets = goldPool.slice(0, 4);
        dynamiteSpot = goldPool[4];
    }

    // Update frequencies for the first 20 balls initially
    for (var k = 0; k < 20; k++) {
        var num = finalDraw[k];
        numberFrequencies[num] = (numberFrequencies[num] || 0) + 1;
    }

    return {
        success: true,
        fullDraw: finalDraw,
        credits: credits,
        cavemanEggs: cavemanEggs,
        goldNuggets: goldNuggets,
        dynamiteSpot: dynamiteSpot
    };
}

function evaluateBall(ballNumber, ballOrder, fullDraw) {
    drawnNumbers.push(ballNumber);
    drawIndex = ballOrder; // 1 to 23

    // Update frequency for extra draw balls (21..23)
    if (ballOrder > 20) {
        numberFrequencies[ballNumber] = (numberFrequencies[ballNumber] || 0) + 1;
    }

    var isHit = selectedSpots.indexOf(ballNumber) >= 0;
    if (isHit && hitNumbers.indexOf(ballNumber) < 0) {
        hitNumbers.push(ballNumber);
    }

    var isBonusBall = false;
    var bonusType = "none";
    var instantBonusCredits = 0;

    // 1. Super Keno: 1st Ball Hit
    if (activeVariant === "super" && ballOrder === 1 && isHit) {
        isSuperHit = true;
        isBonusBall = true;
        bonusType = "super";
    }

    // 2. Power Keno: 20th Ball Hit
    if (activeVariant === "power" && ballOrder === 20 && isHit) {
        isPowerHit = true;
        isBonusBall = true;
        bonusType = "power";
    }

    // 3. Cleopatra Keno: 20th Ball Hit
    var triggeredCleopatra = false;
    if (activeVariant === "cleopatra" && ballOrder === 20 && isHit) {
        isBonusBall = true;
        bonusType = "cleopatra";
    }

    // 4. Caveman Keno: Egg Hatches when drawn
    if (activeVariant === "caveman" && cavemanEggs.indexOf(ballNumber) >= 0) {
        cavemanHatchedCount++;
        isBonusBall = true;
        bonusType = "caveman_egg";
    }

    // 5. Triple Power Keno: 1st Ball = 3X, 20th Ball = 3X
    if (activeVariant === "triplepower") {
        if (ballOrder === 1 && isHit) {
            triplePowerBall1Hit = true;
            isBonusBall = true;
            bonusType = "triplepower_1";
        } else if (ballOrder === 20 && isHit) {
            triplePowerBall20Hit = true;
            isBonusBall = true;
            bonusType = "triplepower_20";
        }
    }

    // 6. Gold Mine Keno: Instant Gold Nugget & Dynamite
    if (activeVariant === "goldmine") {
        if (goldNuggets.indexOf(ballNumber) >= 0) {
            // Gold nugget struck! Awards 5x bet instant bonus
            var nuggetWin = betAmount * 5;
            goldMineBonusWon += nuggetWin;
            credits += nuggetWin;
            instantBonusCredits = nuggetWin;
            isBonusBall = true;
            bonusType = "goldmine_nugget";
        } else if (ballNumber === dynamiteSpot) {
            isBonusBall = true;
            bonusType = "goldmine_dynamite";
            // Dynamite blast triggers adjacent hits if marked
            var adjacent = [ballNumber - 1, ballNumber + 1, ballNumber - 10, ballNumber + 10];
            for (var a = 0; a < adjacent.length; a++) {
                var adjNum = adjacent[a];
                if (adjNum >= 1 && adjNum <= 80 && selectedSpots.indexOf(adjNum) >= 0) {
                    if (hitNumbers.indexOf(adjNum) < 0) {
                        hitNumbers.push(adjNum);
                    }
                }
            }
        }
    }

    // 7. Extra Draw Keno Evaluation at Ball 20:
    // If 1 hit away from a paytier or near-jackpot, trigger 3 extra balls!
    if (activeVariant === "extradraw" && ballOrder === 20 && !extraDrawTriggered) {
        var spotsCountED = selectedSpots.length;
        var hitCountED = hitNumbers.length;
        var curMultED = getPayoutMultiplier(spotsCountED, hitCountED);
        var nextMultED = getPayoutMultiplier(spotsCountED, hitCountED + 1);

        // Near-miss condition: 1 hit away from higher paytier or within 2 hits of jackpot
        if (spotsCountED >= 2 && (nextMultED > curMultED || (hitCountED >= Math.max(1, spotsCountED - 2) && hitCountED < spotsCountED))) {
            extraDrawTriggered = true;
            isBonusBall = true;
            bonusType = "extradraw_trigger";
        }
    }

    // Determine if round is complete:
    // If Extra Draw was triggered, complete at ball 23; otherwise ball 20.
    var targetBallCount = (activeVariant === "extradraw" && extraDrawTriggered) ? 23 : 20;
    var isRoundComplete = (ballOrder === targetBallCount);
    var roundWin = 0;
    var baseMultiplier = 0;

    if (isRoundComplete) {
        isDrawing = false;
        var spotsCount = selectedSpots.length;
        var hitCount = hitNumbers.length;
        baseMultiplier = getPayoutMultiplier(spotsCount, hitCount);

        multiplier = 1;
        if (activeVariant === "power" && isPowerHit) {
            multiplier = 4;
        } else if (activeVariant === "super" && isSuperHit) {
            multiplier = 4;
        } else if (activeVariant === "caveman") {
            if (cavemanHatchedCount >= 3) {
                multiplier = 8;
            } else if (cavemanHatchedCount === 2) {
                multiplier = 4;
            }
        } else if (activeVariant === "triplepower") {
            if (triplePowerBall1Hit && triplePowerBall20Hit) {
                multiplier = 9; // 3X x 3X Super Multiplier!
            } else if (triplePowerBall1Hit || triplePowerBall20Hit) {
                multiplier = 3;
            }
        }

        if (isFreeGameActive) {
            multiplier *= 2; // Cleopatra Free Games pay 2x
        }

        if (baseMultiplier > 0) {
            roundWin = baseMultiplier * betAmount * multiplier;
            credits += roundWin;
            lastWin = roundWin + goldMineBonusWon;
            if (isFreeGameActive) {
                freeGamesTotalWon += roundWin;
            }

            // Cleopatra check: Did ball #20 hit on a winning ticket?
            if (activeVariant === "cleopatra" && isHit) {
                triggeredCleopatra = true;
                freeGamesRemaining += 12;
            }
        } else {
            lastWin = goldMineBonusWon;
        }

        // Manage free games state
        if (isFreeGameActive) {
            freeGamesRemaining--;
            if (freeGamesRemaining <= 0) {
                isFreeGameActive = false;
            }
        } else if (triggeredCleopatra) {
            isFreeGameActive = true;
        }
    }

    return {
        ball: ballNumber,
        order: ballOrder,
        isHit: isHit,
        totalHitsSoFar: hitNumbers.length,
        isBonusBall: isBonusBall,
        bonusType: bonusType,
        instantBonusCredits: instantBonusCredits,
        isRoundComplete: isRoundComplete,
        roundWin: roundWin,
        baseMultiplier: baseMultiplier,
        finalMultiplier: multiplier,
        credits: credits,
        cavemanHatchedCount: cavemanHatchedCount,
        extraDrawTriggered: extraDrawTriggered,
        goldMineBonusWon: goldMineBonusWon,
        triplePowerBall1Hit: triplePowerBall1Hit,
        triplePowerBall20Hit: triplePowerBall20Hit,
        triggeredCleopatra: triggeredCleopatra,
        freeGamesRemaining: freeGamesRemaining,
        isFreeGameActive: isFreeGameActive
    };
}

function concludeDraw(fullDraw) {
    isDrawing = false;
    var spotsCount = selectedSpots.length;
    var hitCount = hitNumbers.length;
    var baseMult = getPayoutMultiplier(spotsCount, hitCount);

    return {
        winAmount: lastWin,
        baseMultiplier: baseMult,
        multiplier: multiplier,
        credits: credits,
        hitsCount: hitCount,
        cavemanHatchedCount: cavemanHatchedCount,
        extraDrawTriggered: extraDrawTriggered,
        goldMineBonusWon: goldMineBonusWon,
        triplePowerMultiplier: multiplier,
        freeGamesRemaining: freeGamesRemaining,
        freeGamesTotalWon: freeGamesTotalWon,
        isFreeGameActive: isFreeGameActive
    };
}

function resetGame() {
    isDrawing = false;
    drawnNumbers = [];
    hitNumbers = [];
    drawIndex = 0;
    lastWin = 0;
    multiplier = 1;
    isPowerHit = false;
    isSuperHit = false;
    freeGamesRemaining = 0;
    freeGamesTotalWon = 0;
    isFreeGameActive = false;
    cavemanEggs = [];
    cavemanHatchedCount = 0;
    extraDrawTriggered = false;
    goldNuggets = [];
    dynamiteSpot = 0;
    goldMineBonusWon = 0;
    triplePowerBall1Hit = false;
    triplePowerBall20Hit = false;
}
