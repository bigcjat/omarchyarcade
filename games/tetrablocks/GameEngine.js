// TetraBlocks Game Engine
// Standard Guideline Mechanics: 7-Bag Randomizer, SRS Wall Kicks, Lock Delay, Ghost Piece
.pragma library

var COLS = 10;
var ROWS = 22; // 20 visible rows (2..21) + 2 buffer spawn rows (0..1)

var grid = []; // 22 x 10 matrix: 0 = empty, 1..7 = piece color type
var bag = [];
var nextQueue = [];
var currentPiece = null;
var holdPieceType = null;
var canHold = true;

var score = 0;
var bestScore = 0;
var lines = 0;
var level = 1;
var gameOver = false;
var b2b = false; // Back-to-back quad clear

// 7 Standard Shapes & Relative Blocks in NxN Bounding Boxes:
// Coordinates: [x, y] where x = col, y = row
var PIECES = {
    'I': {
        colorId: 1,
        size: 4,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[0,1], [1,1], [2,1], [3,1]], // 0: horizontal
            [[2,0], [2,1], [2,2], [2,3]], // 1: vertical
            [[0,2], [1,2], [2,2], [3,2]], // 2: horizontal
            [[1,0], [1,1], [1,2], [1,3]]  // 3: vertical
        ]
    },
    'O': {
        colorId: 2,
        size: 2,
        spawnCol: 4,
        spawnRow: 0,
        shapes: [
            [[0,0], [1,0], [0,1], [1,1]],
            [[0,0], [1,0], [0,1], [1,1]],
            [[0,0], [1,0], [0,1], [1,1]],
            [[0,0], [1,0], [0,1], [1,1]]
        ]
    },
    'T': {
        colorId: 3,
        size: 3,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[1,0], [0,1], [1,1], [2,1]], // North
            [[1,0], [1,1], [2,1], [1,2]], // East
            [[0,1], [1,1], [2,1], [1,2]], // South
            [[1,0], [0,1], [1,1], [1,2]]  // West
        ]
    },
    'S': {
        colorId: 4,
        size: 3,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[1,0], [2,0], [0,1], [1,1]],
            [[1,0], [1,1], [2,1], [2,2]],
            [[1,1], [2,1], [0,2], [1,2]],
            [[0,0], [0,1], [1,1], [1,2]]
        ]
    },
    'Z': {
        colorId: 5,
        size: 3,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[0,0], [1,0], [1,1], [2,1]],
            [[2,0], [1,1], [2,1], [1,2]],
            [[0,1], [1,1], [1,2], [2,2]],
            [[1,0], [0,1], [1,1], [0,2]]
        ]
    },
    'J': {
        colorId: 6,
        size: 3,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[0,0], [0,1], [1,1], [2,1]],
            [[1,0], [2,0], [1,1], [1,2]],
            [[0,1], [1,1], [2,1], [2,2]],
            [[1,0], [1,1], [0,2], [1,2]]
        ]
    },
    'L': {
        colorId: 7,
        size: 3,
        spawnCol: 3,
        spawnRow: 0,
        shapes: [
            [[2,0], [0,1], [1,1], [2,1]],
            [[1,0], [1,1], [1,2], [2,2]],
            [[0,1], [1,1], [2,1], [0,2]],
            [[0,0], [1,0], [1,1], [1,2]]
        ]
    }
};

// SRS Wall Kick Data (offsets in [dx, dy] where +x is right, +y is UP):
var KICKS_3X3 = {
    "0->1": [[0,0], [-1,0], [-1,1], [0,-2], [-1,-2]],
    "1->0": [[0,0], [1,0], [1,-1], [0,2], [1,2]],
    "1->2": [[0,0], [1,0], [1,-1], [0,2], [1,2]],
    "2->1": [[0,0], [-1,0], [-1,1], [0,-2], [-1,-2]],
    "2->3": [[0,0], [1,0], [1,1], [0,-2], [1,-2]],
    "3->2": [[0,0], [-1,0], [-1,-1], [0,2], [-1,2]],
    "3->0": [[0,0], [-1,0], [-1,-1], [0,2], [-1,2]],
    "0->3": [[0,0], [1,0], [1,1], [0,-2], [1,-2]]
};

var KICKS_I = {
    "0->1": [[0,0], [-2,0], [1,0], [-2,-1], [1,2]],
    "1->0": [[0,0], [2,0], [-1,0], [2,1], [-1,-2]],
    "1->2": [[0,0], [-1,0], [2,0], [-1,2], [2,-1]],
    "2->1": [[0,0], [1,0], [-2,0], [1,-2], [-2,1]],
    "2->3": [[0,0], [2,0], [-1,0], [2,1], [-1,-2]],
    "3->2": [[0,0], [-2,0], [1,0], [-2,-1], [1,2]],
    "3->0": [[0,0], [1,0], [-2,0], [1,-2], [-2,1]],
    "0->3": [[0,0], [-1,0], [2,0], [-1,2], [2,-1]]
};

// 7-Bag Randomizer
function fillBag() {
    var p = ['I', 'O', 'T', 'S', 'Z', 'J', 'L'];
    for (var i = p.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var tmp = p[i];
        p[i] = p[j];
        p[j] = tmp;
    }
    bag = p;
}

function popBag() {
    if (bag.length === 0) fillBag();
    return bag.pop();
}

function initGame() {
    grid = [];
    for (var r = 0; r < ROWS; r++) {
        var row = [];
        for (var c = 0; c < COLS; c++) {
            row.push(0);
        }
        grid.push(row);
    }
    bag = [];
    nextQueue = [];
    holdPieceType = null;
    canHold = true;
    score = 0;
    lines = 0;
    level = 1;
    gameOver = false;
    b2b = false;

    // Prefill next queue with 3 pieces
    while (nextQueue.length < 4) {
        nextQueue.push(popBag());
    }
    spawnNextPiece();
}

function spawnNextPiece() {
    var nextType = nextQueue.shift();
    nextQueue.push(popBag());

    var pDef = PIECES[nextType];
    currentPiece = {
        type: nextType,
        rot: 0,
        c: pDef.spawnCol,
        r: pDef.spawnRow,
        colorId: pDef.colorId
    };
    canHold = true;

    // Check collision on spawn (Top out game over)
    if (!isValidPosition(currentPiece.type, currentPiece.rot, currentPiece.c, currentPiece.r)) {
        gameOver = true;
    }
}

function isValidPosition(type, rot, col, row) {
    var coords = PIECES[type].shapes[rot];
    for (var i = 0; i < coords.length; i++) {
        var c = col + coords[i][0];
        var r = row + coords[i][1];
        if (c < 0 || c >= COLS || r < 0 || r >= ROWS) {
            return false;
        }
        if (grid[r][c] !== 0) {
            return false;
        }
    }
    return true;
}

function getBlocks(piece) {
    if (!piece) return [];
    var coords = PIECES[piece.type].shapes[piece.rot];
    var out = [];
    for (var i = 0; i < coords.length; i++) {
        out.push({
            c: piece.c + coords[i][0],
            r: piece.r + coords[i][1],
            colorId: piece.colorId
        });
    }
    return out;
}

function getGhostRow() {
    if (!currentPiece) return 0;
    var testR = currentPiece.r;
    while (isValidPosition(currentPiece.type, currentPiece.rot, currentPiece.c, testR + 1)) {
        testR++;
    }
    return testR;
}

function moveLeft() {
    if (gameOver || !currentPiece) return false;
    if (isValidPosition(currentPiece.type, currentPiece.rot, currentPiece.c - 1, currentPiece.r)) {
        currentPiece.c -= 1;
        return true;
    }
    return false;
}

function moveRight() {
    if (gameOver || !currentPiece) return false;
    if (isValidPosition(currentPiece.type, currentPiece.rot, currentPiece.c + 1, currentPiece.r)) {
        currentPiece.c += 1;
        return true;
    }
    return false;
}

function rotateCW() {
    if (gameOver || !currentPiece) return false;
    var newRot = (currentPiece.rot + 1) % 4;
    return attemptRotation(newRot, currentPiece.rot + "->" + newRot);
}

function rotateCCW() {
    if (gameOver || !currentPiece) return false;
    var newRot = (currentPiece.rot + 3) % 4;
    return attemptRotation(newRot, currentPiece.rot + "->" + newRot);
}

function attemptRotation(newRot, transition) {
    var type = currentPiece.type;
    if (type === 'O') {
        currentPiece.rot = newRot;
        return true;
    }

    var kickTable = (type === 'I') ? KICKS_I : KICKS_3X3;
    var kicks = kickTable[transition] || [[0, 0]];

    for (var i = 0; i < kicks.length; i++) {
        var dx = kicks[i][0];
        var dy = kicks[i][1];
        var newCol = currentPiece.c + dx;
        var newRow = currentPiece.r - dy; // Convert cartesian (+y up) to grid (+y down)

        if (isValidPosition(type, newRot, newCol, newRow)) {
            currentPiece.rot = newRot;
            currentPiece.c = newCol;
            currentPiece.r = newRow;
            return true;
        }
    }
    return false;
}

function softDrop() {
    if (gameOver || !currentPiece) return { moved: false, locked: false };
    if (isValidPosition(currentPiece.type, currentPiece.rot, currentPiece.c, currentPiece.r + 1)) {
        currentPiece.r += 1;
        score += 1;
        if (score > bestScore) bestScore = score;
        return { moved: true, locked: false };
    }
    return { moved: false, locked: false };
}

function hardDrop() {
    if (gameOver || !currentPiece) return { dropped: 0, linesCleared: 0 };
    var ghostR = getGhostRow();
    var dist = ghostR - currentPiece.r;
    currentPiece.r = ghostR;
    score += dist * 2;
    if (score > bestScore) bestScore = score;

    var clearRes = lockCurrentPiece();
    return {
        dropped: dist,
        linesCleared: clearRes.linesCleared,
        clearedRows: clearRes.clearedRows
    };
}

function hold() {
    if (gameOver || !currentPiece || !canHold) return false;
    var oldType = currentPiece.type;
    if (holdPieceType === null) {
        holdPieceType = oldType;
        spawnNextPiece();
    } else {
        var swapType = holdPieceType;
        holdPieceType = oldType;
        var pDef = PIECES[swapType];
        currentPiece = {
            type: swapType,
            rot: 0,
            c: pDef.spawnCol,
            r: pDef.spawnRow,
            colorId: pDef.colorId
        };
    }
    canHold = false;
    return true;
}

function lockCurrentPiece() {
    var blocks = getBlocks(currentPiece);
    for (var i = 0; i < blocks.length; i++) {
        var b = blocks[i];
        if (b.r >= 0 && b.r < ROWS && b.c >= 0 && b.c < COLS) {
            grid[b.r][b.c] = b.colorId;
        }
    }

    // Check full rows
    var clearedRows = [];
    for (var r = 0; r < ROWS; r++) {
        var isFull = true;
        for (var c = 0; c < COLS; c++) {
            if (grid[r][c] === 0) {
                isFull = false;
                break;
            }
        }
        if (isFull) {
            clearedRows.push(r);
        }
    }

    var count = clearedRows.length;
    var pts = 0;
    var b2bApplied = false;
    if (count > 0) {
        if (count === 1) pts = 100 * level;
        else if (count === 2) pts = 300 * level;
        else if (count === 3) pts = 500 * level;
        else if (count === 4) {
            b2bApplied = b2b;
            pts = 800 * level * (b2b ? 1.5 : 1.0);
            b2b = true;
        }
        if (count < 4) b2b = false;

        score += Math.round(pts);
        lines += count;
        level = Math.floor(lines / 10) + 1;
        if (score > bestScore) bestScore = score;
        currentPiece = null; // Hide active piece during clear animation
    } else {
        spawnNextPiece();
    }

    return {
        linesCleared: count,
        clearedRows: clearedRows,
        scoreGained: Math.round(pts),
        isB2B: b2bApplied
    };
}

function collapseRows(clearedRows) {
    if (clearedRows && clearedRows.length > 0) {
        // 1. Sort descending so splicing from bottom to top preserves remaining row indices
        var sorted = clearedRows.slice().sort(function(a, b) { return b - a; });
        for (var idx = 0; idx < sorted.length; idx++) {
            grid.splice(sorted[idx], 1);
        }
        // 2. Add empty rows at the top AFTER all cleared rows have been removed
        for (var i = 0; i < sorted.length; i++) {
            var emptyRow = [];
            for (var c2 = 0; c2 < COLS; c2++) emptyRow.push(0);
            grid.unshift(emptyRow);
        }
    }
    spawnNextPiece();
}

// Returns gravity interval in milliseconds based on level
function getGravityInterval() {
    // Standard guideline speed formula
    var sec = Math.pow(0.8 - ((level - 1) * 0.007), level - 1);
    return Math.max(50, Math.round(sec * 1000));
}

function setBestScore(val) {
    bestScore = val;
}

function getState() {
    var ghostR = getGhostRow();
    var ghostBlocks = [];
    if (currentPiece && !gameOver) {
        var coords = PIECES[currentPiece.type].shapes[currentPiece.rot];
        for (var i = 0; i < coords.length; i++) {
            ghostBlocks.push({
                c: currentPiece.c + coords[i][0],
                r: ghostR + coords[i][1]
            });
        }
    }

    return {
        grid: grid,
        currentBlocks: getBlocks(currentPiece),
        ghostBlocks: ghostBlocks,
        currentPiece: currentPiece,
        holdPiece: holdPieceType,
        nextPieces: nextQueue.slice(0, 3),
        score: score,
        bestScore: bestScore,
        lines: lines,
        level: level,
        gameOver: gameOver,
        gravityInterval: getGravityInterval()
    };
}
