// 2048 Game Engine for QML
.pragma library

var SIZE = 4;
var grid = [];
var tiles = [];
var score = 0;
var bestScore = 0;
var won = false;
var over = false;
var nextId = 1;
var hasMoved = false;

function init() {
    grid = [];
    for (var r = 0; r < SIZE; r++) {
        var row = [];
        for (var c = 0; c < SIZE; c++) {
            row.push(null);
        }
        grid.push(row);
    }
    tiles = [];
    score = 0;
    won = false;
    over = false;
    nextId = 1;
}

function getAvailableCells() {
    var cells = [];
    for (var r = 0; r < SIZE; r++) {
        for (var c = 0; c < SIZE; c++) {
            if (grid[r][c] === null) {
                cells.push({ r: r, c: c });
            }
        }
    }
    return cells;
}

function spawnRandomTile() {
    var cells = getAvailableCells();
    if (cells.length === 0) return null;
    
    var cell = cells[Math.floor(Math.random() * cells.length)];
    var val = Math.random() < 0.9 ? 2 : 4;
    var tile = {
        id: nextId++,
        val: val,
        row: cell.r,
        col: cell.c,
        isNew: true,
        isMerged: false,
        toDelete: false
    };
    grid[cell.r][cell.c] = tile;
    tiles.push(tile);
    return tile;
}

function startNewGame() {
    init();
    spawnRandomTile();
    spawnRandomTile();
    return getState();
}

function getState() {
    return {
        tiles: tiles.slice(),
        score: score,
        won: won,
        over: over
    };
}

// Direction vectors:
// 0: Left, 1: Right, 2: Up, 3: Down
function move(direction) {
    var moved = false;
    var scoreGained = 0;
    var maxMergedVal = 0;

    // Clear previous transient animation flags
    for (var i = tiles.length - 1; i >= 0; i--) {
        if (tiles[i].toDelete) {
            tiles.splice(i, 1);
        } else {
            tiles[i].isNew = false;
            tiles[i].isMerged = false;
        }
    }

    // Rebuild grid reference
    for (var r = 0; r < SIZE; r++) {
        for (var c = 0; c < SIZE; c++) {
            grid[r][c] = null;
        }
    }
    for (var t = 0; t < tiles.length; t++) {
        var tile = tiles[t];
        grid[tile.row][tile.col] = tile;
    }

    var lines = [];
    for (var i = 0; i < SIZE; i++) {
        var line = [];
        for (var j = 0; j < SIZE; j++) {
            if (direction === 0) line.push({ r: i, c: j }); // Left
            else if (direction === 1) line.push({ r: i, c: SIZE - 1 - j }); // Right
            else if (direction === 2) line.push({ r: j, c: i }); // Up
            else if (direction === 3) line.push({ r: SIZE - 1 - j, c: i }); // Down
        }
        lines.push(line);
    }

    for (var l = 0; l < lines.length; l++) {
        var coords = lines[l];
        var nonNull = [];
        for (var k = 0; k < coords.length; k++) {
            var tObj = grid[coords[k].r][coords[k].c];
            if (tObj !== null) nonNull.push(tObj);
        }

        var targetIdx = 0;
        var p = 0;
        while (p < nonNull.length) {
            var current = nonNull[p];
            var destPos = coords[targetIdx];

            if (p + 1 < nonNull.length && nonNull[p].val === nonNull[p + 1].val) {
                // Merge two tiles
                var nextT = nonNull[p + 1];
                var mergedVal = current.val * 2;
                if (mergedVal > maxMergedVal) maxMergedVal = mergedVal;

                if (current.row !== destPos.r || current.col !== destPos.c) moved = true;
                if (nextT.row !== destPos.r || nextT.col !== destPos.c) moved = true;
                moved = true; // A merge is always a valid state change

                // current becomes the merged tile
                current.row = destPos.r;
                current.col = destPos.c;
                current.val = mergedVal;
                current.isMerged = true;

                // nextT slides to same cell and gets deleted
                nextT.row = destPos.r;
                nextT.col = destPos.c;
                nextT.toDelete = true;

                scoreGained += mergedVal;
                if (mergedVal === 2048) won = true;

                p += 2;
            } else {
                // Move single tile
                if (current.row !== destPos.r || current.col !== destPos.c) {
                    moved = true;
                    current.row = destPos.r;
                    current.col = destPos.c;
                }
                p += 1;
            }
            targetIdx++;
        }
    }

    if (moved) {
        score += scoreGained;
        if (score > bestScore) bestScore = score;

        // Rebuild grid after movement to spawn safely
        for (var r2 = 0; r2 < SIZE; r2++) {
            for (var c2 = 0; c2 < SIZE; c2++) {
                grid[r2][c2] = null;
            }
        }
        for (var t2 = 0; t2 < tiles.length; t2++) {
            if (!tiles[t2].toDelete) {
                grid[tiles[t2].row][tiles[t2].col] = tiles[t2];
            }
        }

        spawnRandomTile();
        over = checkGameOver();
    }

    return {
        moved: moved,
        scoreGained: scoreGained,
        maxMergedVal: maxMergedVal,
        state: getState()
    };
}

function checkGameOver() {
    if (getAvailableCells().length > 0) return false;

    // Check horizontal and vertical neighbors
    for (var r = 0; r < SIZE; r++) {
        for (var c = 0; c < SIZE; c++) {
            var val = grid[r][c] ? grid[r][c].val : 0;
            if (r + 1 < SIZE && grid[r + 1][c] && grid[r + 1][c].val === val) return false;
            if (c + 1 < SIZE && grid[r][c + 1] && grid[r][c + 1].val === val) return false;
        }
    }
    return true;
}

function setBestScore(val) {
    bestScore = val;
}
