// =============================================================================
// Mahjong Solitaire • High-Performance Solitaire Engine
// Multi-layer isometric 3D coordinate system, guaranteed solvable generator,
// and real-time state analysis.
// =============================================================================

.pragma library

// -----------------------------------------------------------------------------
// TILE DEFINITIONS & PAIR FACTORY
// -----------------------------------------------------------------------------
function getStandardDeck() {
    var deck = [];
    var idCounter = 1;

    // Wan (Characters) 1..9 (4 of each)
    for (var i = 1; i <= 9; i++) {
        for (var c = 0; c < 4; c++) {
            deck.push({
                id: idCounter++,
                type: "wan_" + i,
                category: "wan",
                sprite: "wan_" + i + ".png",
                name: i + " Wan"
            });
        }
    }

    // Pin (Dots) 1..9 (4 of each)
    for (var i = 1; i <= 9; i++) {
        for (var c = 0; c < 4; c++) {
            deck.push({
                id: idCounter++,
                type: "pin_" + i,
                category: "pin",
                sprite: "pin_" + i + ".png",
                name: i + " Pin"
            });
        }
    }

    // Sou (Bamboo) 1..9 (4 of each)
    for (var i = 1; i <= 9; i++) {
        for (var c = 0; c < 4; c++) {
            deck.push({
                id: idCounter++,
                type: "sou_" + i,
                category: "sou",
                sprite: "sou_" + i + ".png",
                name: i + " Sou"
            });
        }
    }

    // Winds (4 of each)
    var winds = ["east", "south", "west", "north"];
    for (var w = 0; w < winds.length; w++) {
        for (var c = 0; c < 4; c++) {
            deck.push({
                id: idCounter++,
                type: "wind_" + winds[w],
                category: "wind",
                sprite: "wind_" + winds[w] + ".png",
                name: winds[w].toUpperCase() + " Wind"
            });
        }
    }

    // Dragons (4 of each)
    var dragons = ["red", "green", "white"];
    for (var d = 0; d < dragons.length; d++) {
        for (var c = 0; c < 4; c++) {
            deck.push({
                id: idCounter++,
                type: "dragon_" + dragons[d],
                category: "dragon",
                sprite: "dragon_" + dragons[d] + ".png",
                name: dragons[d].toUpperCase() + " Dragon"
            });
        }
    }

    // Seasons (1 of each, 4 total: match any other season)
    var seasons = ["spring", "summer", "autumn", "winter"];
    for (var s = 0; s < seasons.length; s++) {
        deck.push({
            id: idCounter++,
            type: "season_" + seasons[s],
            category: "season",
            sprite: "season_" + seasons[s] + ".png",
            name: seasons[s].toUpperCase()
        });
    }

    // Flowers (1 of each, 4 total: match any other flower)
    var flowers = ["plum", "orchid", "chrysanthemum", "bamboo"];
    for (var f = 0; f < flowers.length; f++) {
        deck.push({
            id: idCounter++,
            type: "flower_" + flowers[f],
            category: "flower",
            sprite: "flower_" + flowers[f] + ".png",
            name: flowers[f].toUpperCase()
        });
    }

    return deck;
}

// Convert deck into 72 matched pairs for reverse generation
function buildMatchedPairs() {
    var deck = getStandardDeck();
    var pairs = [];

    // Separate into regular matching, seasons, and flowers
    var regularMap = {};
    var seasonTiles = [];
    var flowerTiles = [];

    for (var i = 0; i < deck.length; i++) {
        var t = deck[i];
        if (t.category === "season") {
            seasonTiles.push(t);
        } else if (t.category === "flower") {
            flowerTiles.push(t);
        } else {
            if (!regularMap[t.type]) regularMap[t.type] = [];
            regularMap[t.type].push(t);
        }
    }

    // Regular pairs
    for (var typeKey in regularMap) {
        var list = regularMap[typeKey];
        while (list.length >= 2) {
            pairs.push([list.pop(), list.pop()]);
        }
    }

    // Seasons pairs (any 2 seasons match)
    shuffleArray(seasonTiles);
    while (seasonTiles.length >= 2) {
        pairs.push([seasonTiles.pop(), seasonTiles.pop()]);
    }

    // Flowers pairs (any 2 flowers match)
    shuffleArray(flowerTiles);
    while (flowerTiles.length >= 2) {
        pairs.push([flowerTiles.pop(), flowerTiles.pop()]);
    }

    shuffleArray(pairs);
    return pairs;
}

function shuffleArray(arr) {
    for (var i = arr.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }
}

// Check if two tiles are legally matchable
function canMatch(tA, tB) {
    if (!tA || !tB || tA.id === tB.id) return false;
    if (tA.category === "season" && tB.category === "season") return true;
    if (tA.category === "flower" && tB.category === "flower") return true;
    return tA.type === tB.type;
}

// -----------------------------------------------------------------------------
// LAYOUT DEFINITIONS (144 Slots Each)
// -----------------------------------------------------------------------------
function getTurtleSlots() {
    var slots = [];
    // Layer 0 (87 slots)
    for (var x = 2; x <= 24; x += 2) slots.push({ x: x, y: 1, z: 0 });
    for (var x = 6; x <= 20; x += 2) slots.push({ x: x, y: 3, z: 0 });
    for (var x = 4; x <= 22; x += 2) slots.push({ x: x, y: 5, z: 0 });
    slots.push({ x: 0, y: 7, z: 0 });
    for (var x = 2; x <= 24; x += 2) slots.push({ x: x, y: 7, z: 0 });
    slots.push({ x: 26, y: 7, z: 0 });
    slots.push({ x: 28, y: 7, z: 0 });
    for (var x = 2; x <= 24; x += 2) slots.push({ x: x, y: 9, z: 0 });
    for (var x = 4; x <= 22; x += 2) slots.push({ x: x, y: 11, z: 0 });
    for (var x = 6; x <= 20; x += 2) slots.push({ x: x, y: 13, z: 0 });
    for (var x = 2; x <= 24; x += 2) slots.push({ x: x, y: 15, z: 0 });

    // Layer 1 (36 slots: 6x6)
    for (var x = 8; x <= 18; x += 2) {
        for (var y = 3; y <= 13; y += 2) {
            slots.push({ x: x, y: y, z: 1 });
        }
    }

    // Layer 2 (16 slots: 4x4)
    for (var x = 10; x <= 16; x += 2) {
        for (var y = 5; y <= 11; y += 2) {
            slots.push({ x: x, y: y, z: 2 });
        }
    }

    // Layer 3 (4 slots: 2x2)
    for (var x = 12; x <= 14; x += 2) {
        for (var y = 7; y <= 9; y += 2) {
            slots.push({ x: x, y: y, z: 3 });
        }
    }

    // Layer 4 (1 peak slot)
    slots.push({ x: 13, y: 8, z: 4 });

    return slots;
}

function getFortressSlots() {
    var slots = [];
    // Layer 0 (68)
    for (var xi = 0; xi < 3; xi++) {
        var lx = [2, 4, 6][xi];
        for (var y = 3; y <= 13; y += 2) slots.push({ x: lx, y: y, z: 0 });
    }
    for (var xi = 0; xi < 3; xi++) {
        var rx = [20, 22, 24][xi];
        for (var y = 3; y <= 13; y += 2) slots.push({ x: rx, y: y, z: 0 });
    }
    for (var x = 8; x <= 18; x += 2) {
        var rowList = [5, 7, 9, 11];
        for (var ri = 0; ri < rowList.length; ri++) slots.push({ x: x, y: rowList[ri], z: 0 });
    }
    var gateXs = [10, 12, 14, 16];
    for (var gi = 0; gi < gateXs.length; gi++) {
        slots.push({ x: gateXs[gi], y: 3, z: 0 });
        slots.push({ x: gateXs[gi], y: 13, z: 0 });
    }

    // Layer 1 (40)
    for (var xi = 0; xi < 3; xi++) {
        var lx = [2, 4, 6][xi];
        var y1List = [5, 7, 9, 11];
        for (var yi = 0; yi < y1List.length; yi++) slots.push({ x: lx, y: y1List[yi], z: 1 });
    }
    for (var xi = 0; xi < 3; xi++) {
        var rx = [20, 22, 24][xi];
        var y1List = [5, 7, 9, 11];
        for (var yi = 0; yi < y1List.length; yi++) slots.push({ x: rx, y: y1List[yi], z: 1 });
    }
    for (var gi = 0; gi < gateXs.length; gi++) {
        slots.push({ x: gateXs[gi], y: 7, z: 1 });
        slots.push({ x: gateXs[gi], y: 9, z: 1 });
    }
    var sideXs = [8, 18];
    for (var si = 0; si < sideXs.length; si++) {
        var y1List = [5, 7, 9, 11];
        for (var yi = 0; yi < y1List.length; yi++) slots.push({ x: sideXs[si], y: y1List[yi], z: 1 });
    }

    // Layer 2 (20)
    var l2xs = [3, 5];
    for (var i = 0; i < l2xs.length; i++) {
        var y2List = [6, 8, 10];
        for (var yi = 0; yi < y2List.length; yi++) slots.push({ x: l2xs[i], y: y2List[yi], z: 2 });
    }
    var r2xs = [21, 23];
    for (var i = 0; i < r2xs.length; i++) {
        var y2List = [6, 8, 10];
        for (var yi = 0; yi < y2List.length; yi++) slots.push({ x: r2xs[i], y: y2List[yi], z: 2 });
    }
    for (var gi = 0; gi < gateXs.length; gi++) {
        slots.push({ x: gateXs[gi], y: 7, z: 2 });
        slots.push({ x: gateXs[gi], y: 9, z: 2 });
    }

    // Layer 3 (12)
    slots.push({ x: 4, y: 7, z: 3 });
    slots.push({ x: 4, y: 9, z: 3 });
    slots.push({ x: 3, y: 8, z: 3 });
    slots.push({ x: 5, y: 8, z: 3 });
    slots.push({ x: 22, y: 7, z: 3 });
    slots.push({ x: 22, y: 9, z: 3 });
    slots.push({ x: 21, y: 8, z: 3 });
    slots.push({ x: 23, y: 8, z: 3 });
    slots.push({ x: 12, y: 7, z: 3 });
    slots.push({ x: 14, y: 7, z: 3 });
    slots.push({ x: 12, y: 9, z: 3 });
    slots.push({ x: 14, y: 9, z: 3 });

    // Layer 4 (4)
    slots.push({ x: 13, y: 7, z: 4 });
    slots.push({ x: 13, y: 9, z: 4 });
    slots.push({ x: 4, y: 8, z: 4 });
    slots.push({ x: 22, y: 8, z: 4 });

    return slots;
}

function getDragonSlots() {
    var slots = [];
    // Layer 0 (80)
    var tailTip = [0, 2];
    for (var i = 0; i < tailTip.length; i++) {
        slots.push({ x: tailTip[i], y: 11, z: 0 });
        slots.push({ x: tailTip[i], y: 13, z: 0 });
    }
    var tailBody = [4, 6];
    for (var i = 0; i < tailBody.length; i++) {
        slots.push({ x: tailBody[i], y: 9, z: 0 });
        slots.push({ x: tailBody[i], y: 11, z: 0 });
        slots.push({ x: tailBody[i], y: 13, z: 0 });
    }
    var midB1 = [8, 10];
    for (var i = 0; i < midB1.length; i++) {
        slots.push({ x: midB1[i], y: 7, z: 0 });
        slots.push({ x: midB1[i], y: 9, z: 0 });
        slots.push({ x: midB1[i], y: 11, z: 0 });
    }
    var midB2 = [12, 14];
    for (var i = 0; i < midB2.length; i++) {
        slots.push({ x: midB2[i], y: 5, z: 0 });
        slots.push({ x: midB2[i], y: 7, z: 0 });
        slots.push({ x: midB2[i], y: 9, z: 0 });
        slots.push({ x: midB2[i], y: 11, z: 0 });
        slots.push({ x: midB2[i], y: 13, z: 0 });
    }
    var midB3 = [16, 18];
    for (var i = 0; i < midB3.length; i++) {
        slots.push({ x: midB3[i], y: 3, z: 0 });
        slots.push({ x: midB3[i], y: 5, z: 0 });
        slots.push({ x: midB3[i], y: 7, z: 0 });
        slots.push({ x: midB3[i], y: 9, z: 0 });
    }
    var headBase = [20, 22, 24];
    for (var i = 0; i < headBase.length; i++) {
        slots.push({ x: headBase[i], y: 1, z: 0 });
        slots.push({ x: headBase[i], y: 3, z: 0 });
        slots.push({ x: headBase[i], y: 5, z: 0 });
        slots.push({ x: headBase[i], y: 7, z: 0 });
        slots.push({ x: headBase[i], y: 9, z: 0 });
    }
    var snout = [26, 28];
    for (var i = 0; i < snout.length; i++) {
        slots.push({ x: snout[i], y: 3, z: 0 });
        slots.push({ x: snout[i], y: 5, z: 0 });
    }
    slots.push({ x: 6, y: 15, z: 0 });
    slots.push({ x: 8, y: 15, z: 0 });
    slots.push({ x: 16, y: 1, z: 0 });
    slots.push({ x: 18, y: 1, z: 0 });
    for (var i = 0; i < midB1.length; i++) {
        slots.push({ x: midB1[i], y: 5, z: 0 });
        slots.push({ x: midB1[i], y: 13, z: 0 });
    }
    for (var i = 0; i < midB2.length; i++) {
        slots.push({ x: midB2[i], y: 3, z: 0 });
        slots.push({ x: midB2[i], y: 15, z: 0 });
    }
    for (var i = 0; i < tailBody.length; i++) {
        slots.push({ x: tailBody[i], y: 7, z: 0 });
    }
    var belly2 = [2, 4];
    for (var i = 0; i < belly2.length; i++) slots.push({ x: belly2[i], y: 5, z: 0 });
    for (var i = 0; i < midB3.length; i++) {
        slots.push({ x: midB3[i], y: 11, z: 0 });
        slots.push({ x: midB3[i], y: 13, z: 0 });
    }
    slots.push({ x: 20, y: 11, z: 0 });
    slots.push({ x: 22, y: 11, z: 0 });
    slots.push({ x: 26, y: 1, z: 0 });
    slots.push({ x: 26, y: 7, z: 0 });
    slots.push({ x: 10, y: 1, z: 0 });
    slots.push({ x: 12, y: 1, z: 0 });
    slots.push({ x: 14, y: 1, z: 0 });

    // Layer 1 (38)
    for (var x = 6; x <= 18; x += 2) {
        slots.push({ x: x, y: 7, z: 1 });
        slots.push({ x: x, y: 9, z: 1 });
    }
    var m1xs = [12, 14, 16];
    for (var i = 0; i < m1xs.length; i++) {
        slots.push({ x: m1xs[i], y: 5, z: 1 });
        slots.push({ x: m1xs[i], y: 11, z: 1 });
    }
    for (var i = 0; i < headBase.length; i++) {
        slots.push({ x: headBase[i], y: 3, z: 1 });
        slots.push({ x: headBase[i], y: 5, z: 1 });
        slots.push({ x: headBase[i], y: 7, z: 1 });
    }
    var t1xs = [2, 4];
    for (var i = 0; i < t1xs.length; i++) {
        slots.push({ x: t1xs[i], y: 9, z: 1 });
        slots.push({ x: t1xs[i], y: 11, z: 1 });
    }
    slots.push({ x: 26, y: 3, z: 1 });
    slots.push({ x: 26, y: 5, z: 1 });
    slots.push({ x: 8, y: 5, z: 1 });
    slots.push({ x: 18, y: 5, z: 1 });
    slots.push({ x: 20, y: 9, z: 1 });

    // Layer 2 (18)
    var crestXs = [10, 12, 14, 16];
    for (var i = 0; i < crestXs.length; i++) {
        slots.push({ x: crestXs[i], y: 7, z: 2 });
        slots.push({ x: crestXs[i], y: 9, z: 2 });
    }
    var h2xs = [20, 22];
    for (var i = 0; i < h2xs.length; i++) {
        slots.push({ x: h2xs[i], y: 3, z: 2 });
        slots.push({ x: h2xs[i], y: 5, z: 2 });
        slots.push({ x: h2xs[i], y: 7, z: 2 });
    }
    slots.push({ x: 18, y: 7, z: 2 });
    slots.push({ x: 18, y: 9, z: 2 });
    slots.push({ x: 24, y: 5, z: 2 });
    slots.push({ x: 24, y: 7, z: 2 });

    // Layer 3 (6)
    slots.push({ x: 12, y: 8, z: 3 });
    slots.push({ x: 14, y: 8, z: 3 });
    slots.push({ x: 21, y: 4, z: 3 });
    slots.push({ x: 21, y: 6, z: 3 });
    slots.push({ x: 23, y: 4, z: 3 });
    slots.push({ x: 23, y: 6, z: 3 });

    // Layer 4 (2)
    slots.push({ x: 13, y: 8, z: 4 });
    slots.push({ x: 22, y: 5, z: 4 });

    return slots;
}

// -----------------------------------------------------------------------------
// ADJACENCY & FREEDOM LOGIC
// -----------------------------------------------------------------------------
function isTileFree(tile, activeTiles) {
    var tx = tile.x;
    var ty = tile.y;
    var tz = tile.z;

    // Check if covered from any layer above
    for (var i = 0; i < activeTiles.length; i++) {
        var other = activeTiles[i];
        if (other.z > tz) {
            if (Math.abs(other.x - tx) < 2 && Math.abs(other.y - ty) < 2) {
                return false;
            }
        }
    }

    // Check lateral blockage at same layer
    var leftBlocked = false;
    var rightBlocked = false;

    for (var i = 0; i < activeTiles.length; i++) {
        var other = activeTiles[i];
        if (other.z === tz) {
            if (Math.abs(other.y - ty) < 2) {
                if (other.x < tx && other.x > tx - 2.01) {
                    leftBlocked = true;
                } else if (other.x > tx && other.x < tx + 2.01) {
                    rightBlocked = true;
                }
            }
        }
        if (leftBlocked && rightBlocked) return false;
    }

    return !leftBlocked || !rightBlocked;
}

// Update the 'free' property on all tiles currently in activeTiles list
function refreshTileFreedom(activeTiles) {
    for (var i = 0; i < activeTiles.length; i++) {
        activeTiles[i].free = isTileFree(activeTiles[i], activeTiles);
    }
}

// -----------------------------------------------------------------------------
// SOLVABLE GENERATOR (Reverse Construction)
// -----------------------------------------------------------------------------
function generateBoard(layoutName) {
    var slots = [];
    if (layoutName === "dragon") {
        slots = getDragonSlots();
    } else if (layoutName === "fortress") {
        slots = getFortressSlots();
    } else {
        slots = getTurtleSlots(); // default
    }

    var maxRetries = 20;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
        var pairs = buildMatchedPairs(); // 72 pairs
        // Clone slots into working list
        var workingSlots = [];
        for (var s = 0; s < slots.length; s++) {
            workingSlots.push({
                x: slots[s].x,
                y: slots[s].y,
                z: slots[s].z
            });
        }

        var boardTiles = [];
        var stuck = false;

        while (workingSlots.length > 0) {
            var freeIndices = [];
            for (var i = 0; i < workingSlots.length; i++) {
                if (isTileFree(workingSlots[i], workingSlots)) {
                    freeIndices.push(i);
                }
            }

            if (freeIndices.length < 2) {
                stuck = true;
                break;
            }

            // Pick 2 random free indices
            var idxA = freeIndices[Math.floor(Math.random() * freeIndices.length)];
            var slotA = workingSlots[idxA];
            // Remove slotA
            workingSlots.splice(idxA, 1);

            // Recompute or pick second
            var freeIndicesB = [];
            for (var i = 0; i < workingSlots.length; i++) {
                if (isTileFree(workingSlots[i], workingSlots)) {
                    freeIndicesB.push(i);
                }
            }
            if (freeIndicesB.length === 0) {
                stuck = true;
                break;
            }
            var idxB = freeIndicesB[Math.floor(Math.random() * freeIndicesB.length)];
            var slotB = workingSlots[idxB];
            workingSlots.splice(idxB, 1);

            var pair = pairs.pop();
            var tile1 = pair[0];
            var tile2 = pair[1];

            tile1.x = slotA.x;
            tile1.y = slotA.y;
            tile1.z = slotA.z;
            tile1.free = false;
            tile1.selected = false;
            tile1.lift = 0;

            tile2.x = slotB.x;
            tile2.y = slotB.y;
            tile2.z = slotB.z;
            tile2.free = false;
            tile2.selected = false;
            tile2.lift = 0;

            boardTiles.push(tile1);
            boardTiles.push(tile2);
        }

        if (!stuck && boardTiles.length === 144) {
            refreshTileFreedom(boardTiles);
            return boardTiles;
        }
    }

    // Fallback: if somehow retries exhausted, assign pairs directly to slots
    console.log("Solvable generator fallback used for layout " + layoutName);
    var fallbackPairs = buildMatchedPairs();
    var fallbackTiles = [];
    var shuffledSlots = slots.slice();
    shuffleArray(shuffledSlots);
    for (var i = 0; i < shuffledSlots.length; i += 2) {
        var p = fallbackPairs.pop();
        var t1 = p[0];
        var t2 = p[1];
        t1.x = shuffledSlots[i].x;
        t1.y = shuffledSlots[i].y;
        t1.z = shuffledSlots[i].z;
        t1.free = false;
        t1.selected = false;
        t1.lift = 0;

        t2.x = shuffledSlots[i + 1].x;
        t2.y = shuffledSlots[i + 1].y;
        t2.z = shuffledSlots[i + 1].z;
        t2.free = false;
        t2.selected = false;
        t2.lift = 0;

        fallbackTiles.push(t1);
        fallbackTiles.push(t2);
    }
    refreshTileFreedom(fallbackTiles);
    return fallbackTiles;
}

// -----------------------------------------------------------------------------
// HINT SOLVER & AVAILABLE MATCH DETECTOR
// -----------------------------------------------------------------------------
function findAvailableMoves(boardTiles) {
    var freeTiles = [];
    for (var i = 0; i < boardTiles.length; i++) {
        if (boardTiles[i].free) {
            freeTiles.push(boardTiles[i]);
        }
    }

    var moves = [];
    for (var i = 0; i < freeTiles.length; i++) {
        for (var j = i + 1; j < freeTiles.length; j++) {
            if (canMatch(freeTiles[i], freeTiles[j])) {
                moves.push([freeTiles[i], freeTiles[j]]);
            }
        }
    }
    return moves;
}

// -----------------------------------------------------------------------------
// SORT TILES FOR CORRECT 2.5D DRAWING ORDER
// Back-to-front: lowest Z first, then lowest Y, then lowest X
// -----------------------------------------------------------------------------
function sortTilesForRender(boardTiles) {
    return boardTiles.slice().sort(function(a, b) {
        if (a.z !== b.z) return a.z - b.z;
        if (a.y !== b.y) return a.y - b.y;
        return a.x - b.x;
    });
}
