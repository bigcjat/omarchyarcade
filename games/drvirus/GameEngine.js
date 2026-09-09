// Dr. Virus (OA-032) • Pure JavaScript Game Engine
// Modern Dr. Mario mechanics: 8x16 bottle, 3 virus types, 2-segment vitamin capsules,
// match-4 line elimination, uncoupled split gravity cascades, and combo scoring.
.pragma library

var COLS = 8;
var ROWS = 17; // Row 0 is bottleneck spawn row; Rows 1..16 are playable bottle interior

// Colors
var EMPTY = 0;
var RED = 1;    // 🔴 Fever
var BLUE = 2;   // 🔵 Chill
var YELLOW = 3; // 🟡 Weird

// Cell Types
var TYPE_EMPTY = 0;
var TYPE_VIRUS = 1;
var TYPE_PILL = 2;

// Connected directions for pill halves:
// 'left', 'right', 'up', 'down', 'none' (single/disconnected)

var grid = []; // 17 x 8 matrix of cell objects: { type, color, connectedDir, id }
var currentCapsule = null;
var nextCapsule = null;

var score = 0;
var bestScore = 0;
var level = 1;
var speed = "MED"; // "LOW", "MED", "HI"
var virusesRemaining = 0;
var totalVirusesThisStage = 0;

var isGameOver = false;
var isStageClear = false;
var isClearing = false;
var comboCount = 0;

// Unique ID counter for tracking segments
var nextSegmentId = 1;

// =============================================================================
// INITIALIZATION
// =============================================================================
function initGame(startLevel, speedSetting) {
    if (startLevel !== undefined) level = Math.max(0, Math.min(20, startLevel));
    if (speedSetting !== undefined) speed = speedSetting;

    score = 0;
    isGameOver = false;
    isStageClear = false;
    isClearing = false;
    comboCount = 0;

    initGrid();
    generateViruses();
    nextCapsule = createRandomCapsule();
    spawnCapsule();
}

function initGrid() {
    grid = [];
    for (var r = 0; r < ROWS; r++) {
        var row = [];
        for (var c = 0; c < COLS; c++) {
            row.push({
                type: TYPE_EMPTY,
                color: EMPTY,
                connectedDir: 'none',
                id: 0
            });
        }
        grid.push(row);
    }
}

// =============================================================================
// VIRUS GENERATION
// =============================================================================
function generateViruses() {
    var count = Math.min(84, (level + 1) * 4);
    virusesRemaining = count;
    totalVirusesThisStage = count;

    // Determine highest row index viruses can spawn in (leaving top clear)
    // Level 0: rows 11..16, Level 10: rows 7..16, Level 20: rows 4..16
    var minRow = Math.max(4, 16 - Math.floor(count / 8) - 4);

    var colors = [RED, BLUE, YELLOW];
    var virusList = [];
    for (var i = 0; i < count; i++) {
        virusList.push(colors[i % 3]);
    }
    // Shuffle colors
    for (var j = virusList.length - 1; j > 0; j--) {
        var k = Math.floor(Math.random() * (j + 1));
        var temp = virusList[j];
        virusList[j] = virusList[k];
        virusList[k] = temp;
    }

    var placed = 0;
    var attempts = 0;
    while (placed < count && attempts < 2000) {
        attempts++;
        var r = minRow + Math.floor(Math.random() * (ROWS - minRow));
        var c = Math.floor(Math.random() * COLS);

        if (grid[r][c].type !== TYPE_EMPTY) continue;

        var vColor = virusList[placed];

        // Ensure placement doesn't prematurely create 3 of same color adjacent
        var left1 = (c > 0) ? grid[r][c - 1].color : EMPTY;
        var left2 = (c > 1) ? grid[r][c - 2].color : EMPTY;
        if (left1 === vColor && left2 === vColor) continue;

        var down1 = (r < ROWS - 1) ? grid[r + 1][c].color : EMPTY;
        var down2 = (r < ROWS - 2) ? grid[r + 2][c].color : EMPTY;
        if (down1 === vColor && down2 === vColor) continue;

        grid[r][c] = {
            type: TYPE_VIRUS,
            color: vColor,
            connectedDir: 'none',
            id: nextSegmentId++
        };
        placed++;
    }
}

// =============================================================================
// CAPSULE CREATION & SPAWN
// =============================================================================
function createRandomCapsule() {
    var colors = [RED, BLUE, YELLOW];
    var c1 = colors[Math.floor(Math.random() * 3)];
    var c2 = colors[Math.floor(Math.random() * 3)];
    return {
        color1: c1,
        color2: c2
    };
}

function spawnCapsule() {
    if (isGameOver || isStageClear) return;

    var pillData = nextCapsule || createRandomCapsule();
    nextCapsule = createRandomCapsule();

    // Spawns horizontally at row 0, cols 3 and 4
    currentCapsule = {
        c: 3,
        r: 0,
        rot: 0, // 0: horizontal (c1 at left, c2 at right)
                // 1: vertical (c1 at bottom, c2 at top)
                // 2: horizontal flipped (c2 at left, c1 at right)
                // 3: vertical flipped (c2 at bottom, c1 at top)
        color1: pillData.color1,
        color2: pillData.color2
    };

    // Check collision on spawn -> Game Over if blocked
    if (!canOccupy(currentCapsule.c, currentCapsule.r, currentCapsule.rot)) {
        isGameOver = true;
        currentCapsule = null;
    }
}

// Get the two block segments of the capsule
function getCapsuleSegments(capsule) {
    if (!capsule) return [];
    var c = capsule.c;
    var r = capsule.r;
    var rot = capsule.rot;

    if (rot === 0) {
        // Horizontal: segment 1 at (c, r), segment 2 at (c+1, r)
        return [
            { c: c, r: r, color: capsule.color1, connectedDir: 'right' },
            { c: c + 1, r: r, color: capsule.color2, connectedDir: 'left' }
        ];
    } else if (rot === 1) {
        // Vertical: segment 1 at (c, r), segment 2 at (c, r-1)
        return [
            { c: c, r: r, color: capsule.color1, connectedDir: 'up' },
            { c: c, r: r - 1, color: capsule.color2, connectedDir: 'down' }
        ];
    } else if (rot === 2) {
        // Horizontal flipped: segment 2 at (c, r), segment 1 at (c+1, r)
        return [
            { c: c, r: r, color: capsule.color2, connectedDir: 'right' },
            { c: c + 1, r: r, color: capsule.color1, connectedDir: 'left' }
        ];
    } else { // rot === 3
        // Vertical flipped: segment 2 at (c, r), segment 1 at (c, r-1)
        return [
            { c: c, r: r, color: capsule.color2, connectedDir: 'up' },
            { c: c, r: r - 1, color: capsule.color1, connectedDir: 'down' }
        ];
    }
}

function canOccupy(c, r, rot) {
    var tempCapsule = { c: c, r: r, rot: rot, color1: 1, color2: 1 };
    var segs = getCapsuleSegments(tempCapsule);
    for (var i = 0; i < segs.length; i++) {
        var s = segs[i];
        if (s.c < 0 || s.c >= COLS || s.r < 0 || s.r >= ROWS) return false;
        if (grid[s.r][s.c].type !== TYPE_EMPTY) return false;
    }
    return true;
}

// =============================================================================
// CONTROLS & MOVEMENT
// =============================================================================
function moveLeft() {
    if (!currentCapsule || isGameOver || isClearing) return false;
    if (canOccupy(currentCapsule.c - 1, currentCapsule.r, currentCapsule.rot)) {
        currentCapsule.c -= 1;
        return true;
    }
    return false;
}

function moveRight() {
    if (!currentCapsule || isGameOver || isClearing) return false;
    if (canOccupy(currentCapsule.c + 1, currentCapsule.r, currentCapsule.rot)) {
        currentCapsule.c += 1;
        return true;
    }
    return false;
}

function rotateCW() {
    if (!currentCapsule || isGameOver || isClearing) return false;
    var nextRot = (currentCapsule.rot + 1) % 4;

    // Standard rotation attempt
    if (canOccupy(currentCapsule.c, currentCapsule.r, nextRot)) {
        currentCapsule.rot = nextRot;
        return true;
    }
    // Ceiling kick down (e.g. at top row 0)
    if (canOccupy(currentCapsule.c, currentCapsule.r + 1, nextRot)) {
        currentCapsule.r += 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    // Wall kick left (e.g. rotating horizontal at right wall)
    if (canOccupy(currentCapsule.c - 1, currentCapsule.r, nextRot)) {
        currentCapsule.c -= 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    // Wall kick right
    if (canOccupy(currentCapsule.c + 1, currentCapsule.r, nextRot)) {
        currentCapsule.c += 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    return false;
}

function rotateCCW() {
    if (!currentCapsule || isGameOver || isClearing) return false;
    var nextRot = (currentCapsule.rot + 3) % 4;

    if (canOccupy(currentCapsule.c, currentCapsule.r, nextRot)) {
        currentCapsule.rot = nextRot;
        return true;
    }
    // Ceiling kick down
    if (canOccupy(currentCapsule.c, currentCapsule.r + 1, nextRot)) {
        currentCapsule.r += 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    if (canOccupy(currentCapsule.c - 1, currentCapsule.r, nextRot)) {
        currentCapsule.c -= 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    if (canOccupy(currentCapsule.c + 1, currentCapsule.r, nextRot)) {
        currentCapsule.c += 1;
        currentCapsule.rot = nextRot;
        return true;
    }
    return false;
}

function softDrop() {
    if (!currentCapsule || isGameOver || isClearing) return { moved: false, locked: false };
    if (canOccupy(currentCapsule.c, currentCapsule.r + 1, currentCapsule.rot)) {
        currentCapsule.r += 1;
        score += 1;
        if (score > bestScore) bestScore = score;
        return { moved: true, locked: false };
    } else {
        return lockCurrentCapsule();
    }
}

function hardDrop() {
    if (!currentCapsule || isGameOver || isClearing) return { dropped: 0, linesCleared: 0 };
    var dropDist = 0;
    while (canOccupy(currentCapsule.c, currentCapsule.r + 1, currentCapsule.rot)) {
        currentCapsule.r += 1;
        dropDist++;
    }
    score += dropDist * 2;
    if (score > bestScore) bestScore = score;

    var lockRes = lockCurrentCapsule();
    lockRes.dropped = dropDist;
    return lockRes;
}

function getGhostRow() {
    if (!currentCapsule) return 0;
    var testR = currentCapsule.r;
    while (canOccupy(currentCapsule.c, testR + 1, currentCapsule.rot)) {
        testR++;
    }
    return testR;
}

// =============================================================================
// LOCKING & ELIMINATION
// =============================================================================
function lockCurrentCapsule() {
    var segs = getCapsuleSegments(currentCapsule);
    currentCapsule = null;

    for (var i = 0; i < segs.length; i++) {
        var s = segs[i];
        if (s.r >= 0 && s.r < ROWS && s.c >= 0 && s.c < COLS) {
            grid[s.r][s.c] = {
                type: TYPE_PILL,
                color: s.color,
                connectedDir: s.connectedDir,
                id: nextSegmentId++
            };
        }
    }

    comboCount = 0;
    var matches = findMatches();
    if (matches.length > 0) {
        isClearing = true;
        return {
            moved: false,
            locked: true,
            hasMatches: true,
            matchedCoords: matches
        };
    } else {
        spawnCapsule();
        return {
            moved: false,
            locked: true,
            hasMatches: false,
            matchedCoords: []
        };
    }
}

// Search grid for horizontal and vertical runs of >= 4 cells of identical color
function findMatches() {
    var matched = [];
    var matchKeyMap = {};

    function addCell(r, c) {
        var key = r + "_" + c;
        if (!matchKeyMap[key]) {
            matchKeyMap[key] = true;
            matched.push({ r: r, c: c });
        }
    }

    // Horizontal check
    for (var r = 1; r < ROWS; r++) {
        var matchLen = 1;
        for (var c = 1; c < COLS; c++) {
            var curr = grid[r][c];
            var prev = grid[r][c - 1];
            if (curr.type !== TYPE_EMPTY && curr.color !== EMPTY && curr.color === prev.color) {
                matchLen++;
            } else {
                if (matchLen >= 4) {
                    for (var k = c - matchLen; k < c; k++) addCell(r, k);
                }
                matchLen = 1;
            }
        }
        if (matchLen >= 4) {
            for (var k2 = COLS - matchLen; k2 < COLS; k2++) addCell(r, k2);
        }
    }

    // Vertical check
    for (var col = 0; col < COLS; col++) {
        var vLen = 1;
        for (var row = 2; row < ROWS; row++) {
            var currV = grid[row][col];
            var prevV = grid[row - 1][col];
            if (currV.type !== TYPE_EMPTY && currV.color !== EMPTY && currV.color === prevV.color) {
                vLen++;
            } else {
                if (vLen >= 4) {
                    for (var m = row - vLen; m < row; m++) addCell(m, col);
                }
                vLen = 1;
            }
        }
        if (vLen >= 4) {
            for (var m2 = ROWS - vLen; m2 < ROWS; m2++) addCell(m2, col);
        }
    }

    return matched;
}

// Clear matched cells, award score, and detach partner halves
function clearMatchedCells(coords) {
    if (!coords || coords.length === 0) return { virusesEliminated: 0 };

    var virusesEliminated = 0;
    comboCount++;

    for (var i = 0; i < coords.length; i++) {
        var pt = coords[i];
        var cell = grid[pt.r][pt.c];
        if (cell.type === TYPE_VIRUS) {
            virusesEliminated++;
            virusesRemaining--;
        } else if (cell.type === TYPE_PILL) {
            // Uncouple partner half
            if (cell.connectedDir === 'left' && pt.c > 0) {
                grid[pt.r][pt.c - 1].connectedDir = 'none';
            } else if (cell.connectedDir === 'right' && pt.c < COLS - 1) {
                grid[pt.r][pt.c + 1].connectedDir = 'none';
            } else if (cell.connectedDir === 'up' && pt.r > 0) {
                grid[pt.r - 1][pt.c].connectedDir = 'none';
            } else if (cell.connectedDir === 'down' && pt.r < ROWS - 1) {
                grid[pt.r + 1][pt.c].connectedDir = 'none';
            }
        }

        // Wipe cell
        grid[pt.r][pt.c] = {
            type: TYPE_EMPTY,
            color: EMPTY,
            connectedDir: 'none',
            id: 0
        };
    }

    // Award score based on viruses eliminated & combos
    var basePts = 100 * (level + 1);
    if (speed === "MED") basePts = Math.round(basePts * 1.5);
    else if (speed === "HI") basePts = basePts * 2;

    var ptsGained = virusesEliminated * basePts * Math.pow(2, Math.max(0, comboCount - 1));
    score += ptsGained;
    if (score > bestScore) bestScore = score;

    if (virusesRemaining <= 0) {
        virusesRemaining = 0;
        isStageClear = true;
    }

    return {
        virusesEliminated: virusesEliminated,
        scoreGained: ptsGained,
        comboCount: comboCount,
        isStageClear: isStageClear
    };
}

// =============================================================================
// UNCOUPLED GRAVITY CASCADE
// =============================================================================
// Drop all floating pill blocks until everything rests on bottom or obstacles
function applyGravityStep() {
    var anyMoved = false;

    // Scan from bottom to top so lower pieces fall first
    for (var r = ROWS - 2; r >= 0; r--) {
        for (var c = 0; c < COLS; c++) {
            var cell = grid[r][c];
            if (cell.type !== TYPE_PILL) continue;

            // 1. Horizontally connected pill: both halves must move together!
            if (cell.connectedDir === 'right' && c < COLS - 1) {
                var partner = grid[r][c + 1];
                if (partner.type === TYPE_PILL && partner.connectedDir === 'left') {
                    // Check if space below BOTH halves is empty
                    if (grid[r + 1][c].type === TYPE_EMPTY && grid[r + 1][c + 1].type === TYPE_EMPTY) {
                        grid[r + 1][c] = cell;
                        grid[r + 1][c + 1] = partner;
                        grid[r][c] = { type: TYPE_EMPTY, color: EMPTY, connectedDir: 'none', id: 0 };
                        grid[r][c + 1] = { type: TYPE_EMPTY, color: EMPTY, connectedDir: 'none', id: 0 };
                        anyMoved = true;
                    }
                }
            } else if (cell.connectedDir === 'none' || cell.connectedDir === 'up' || cell.connectedDir === 'down') {
                // Single piece or vertical pillar: moves down if space directly below is empty
                if (grid[r + 1][c].type === TYPE_EMPTY) {
                    grid[r + 1][c] = cell;
                    grid[r][c] = { type: TYPE_EMPTY, color: EMPTY, connectedDir: 'none', id: 0 };
                    anyMoved = true;
                }
            }
        }
    }

    return anyMoved;
}

// Full cascade resolution: repeatedly apply gravity until settled, then check for matches
function resolveCascadeStep() {
    var moved = applyGravityStep();
    if (moved) {
        return { settling: true, hasNewMatches: false, matches: [] };
    }

    // Settled! Check for new chain-reaction matches
    var newMatches = findMatches();
    if (newMatches.length > 0) {
        return { settling: false, hasNewMatches: true, matches: newMatches };
    } else {
        isClearing = false;
        if (!isStageClear && !isGameOver) {
            spawnCapsule();
        }
        return { settling: false, hasNewMatches: false, matches: [] };
    }
}

// =============================================================================
// HELPERS & SPEED TIMINGS
// =============================================================================
function getGravityInterval() {
    var baseSec = 0.8;
    if (speed === "MED") baseSec = 0.55;
    else if (speed === "HI") baseSec = 0.35;

    var levelFactor = Math.pow(0.92, level);
    return Math.max(80, Math.round(baseSec * levelFactor * 1000));
}

function setBestScore(val) {
    bestScore = val;
}

function nextStage() {
    level++;
    isStageClear = false;
    isGameOver = false;
    isClearing = false;
    comboCount = 0;
    initGrid();
    generateViruses();
    spawnCapsule();
}

function getState() {
    var ghostR = getGhostRow();
    var ghostBlocks = [];
    if (currentCapsule && !isGameOver && !isClearing) {
        var segs = getCapsuleSegments(currentCapsule);
        var offsetR = ghostR - currentCapsule.r;
        for (var i = 0; i < segs.length; i++) {
            ghostBlocks.push({
                c: segs[i].c,
                r: segs[i].r + offsetR,
                color: segs[i].color
            });
        }
    }

    var feverCount = 0;
    var chillCount = 0;
    var weirdCount = 0;
    for (var r = 0; r < ROWS; r++) {
        for (var c = 0; c < COLS; c++) {
            if (grid[r][c].type === TYPE_VIRUS) {
                if (grid[r][c].color === RED) feverCount++;
                else if (grid[r][c].color === BLUE) chillCount++;
                else if (grid[r][c].color === YELLOW) weirdCount++;
            }
        }
    }

    return {
        grid: grid,
        currentCapsule: currentCapsule,
        currentSegments: getCapsuleSegments(currentCapsule),
        ghostBlocks: ghostBlocks,
        nextCapsule: nextCapsule,
        score: score,
        bestScore: bestScore,
        level: level,
        speed: speed,
        virusesRemaining: virusesRemaining,
        totalVirusesThisStage: totalVirusesThisStage,
        feverCount: feverCount,
        chillCount: chillCount,
        weirdCount: weirdCount,
        isGameOver: isGameOver,
        isStageClear: isStageClear,
        isClearing: isClearing,
        gravityInterval: getGravityInterval()
    };
}
