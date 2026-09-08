// =============================================================================
// BĪDAMA ENGINE (ビー玉) - Head-to-Head Player vs Computer AI Dual Arena
// Bounded Non-Wrapping Chute Mechanics • True Lose Your Marbles Fidelity
// =============================================================================

.pragma library

var COLS = 5;
var ROWS = 11;
var PITCH_ROW = 5; // Center Pitch Line index (rows 0..4 top chute, 5 pitch line, 6..10 bottom chute)

var MARBLE_TYPES = ["ramune", "matcha", "sakura", "yuzu", "asagao"];

// Player 1 & AI Grids: grid[col][row] where col in 0..4, row in 0..10
var playerGrid = [];
var aiGrid = [];

// Roll angles for both boards
var playerRollAngles = [0.0, 0.0, 0.0, 0.0, 0.0];
var aiRollAngles = [0.0, 0.0, 0.0, 0.0, 0.0];

// Game State
var score = 0;
var aiScore = 0;
var playerCombo = 0;
var aiCombo = 0;
var isGameOver = false;
var winner = null; // "player", "ai", or null

// Garbage queues (marbles waiting to be dumped into the opponent's hoppers)
var playerGarbageQueue = [];
var aiGarbageQueue = [];

var nextPieceId = 1;

function createMarble(type) {
    if (!type) {
        var rnd = Math.random();
        if (rnd < 0.82) {
            type = MARBLE_TYPES[Math.floor(Math.random() * MARBLE_TYPES.length)];
        } else if (rnd < 0.94) {
            type = "hanabi";
        } else {
            type = "basalt";
        }
    }
    return {
        id: nextPieceId++,
        type: type
    };
}

// Initialize a 5x11 grid with 5 centered marbles per column (rows 3..7 filled, rows 0..2 and 8..10 empty)
function createStartingGrid() {
    var g = [];
    for (var c = 0; c < COLS; c++) {
        g[c] = [];
        for (var r = 0; r < ROWS; r++) {
            // Rows 3, 4, 5, 6, 7 have marbles initially (5 marbles deep)
            // Rows 0, 1, 2 (top) and rows 8, 9, 10 (bottom) are empty buffer slots to slide into!
            if (r >= 3 && r <= 7) {
                var mType = MARBLE_TYPES[Math.floor(Math.random() * MARBLE_TYPES.length)];
                // Avoid immediate 3-match on Pitch Line (row 5)
                if (r === PITCH_ROW && c >= 2) {
                    var left1 = g[c - 1][PITCH_ROW] ? g[c - 1][PITCH_ROW].type : null;
                    var left2 = g[c - 2][PITCH_ROW] ? g[c - 2][PITCH_ROW].type : null;
                    while (mType === left1 && mType === left2) {
                        mType = MARBLE_TYPES[Math.floor(Math.random() * MARBLE_TYPES.length)];
                    }
                }
                g[c][r] = createMarble(mType);
            } else {
                g[c][r] = null;
            }
        }
    }
    return g;
}

function initGame() {
    playerGrid = createStartingGrid();
    aiGrid = createStartingGrid();
    playerRollAngles = [0.0, 0.0, 0.0, 0.0, 0.0];
    aiRollAngles = [0.0, 0.0, 0.0, 0.0, 0.0];
    score = 0;
    aiScore = 0;
    playerCombo = 0;
    aiCombo = 0;
    isGameOver = false;
    winner = null;
    playerGarbageQueue = [];
    aiGarbageQueue = [];
}

// =============================================================================
// BOUNDED NON-WRAPPING SLIDE MECHANIC
// =============================================================================
// Checks if a column can slide in direction `dir` (-1 for UP, +1 for DOWN)
// A column can only slide if there is empty space at that end! NO WRAP AROUND.
function canSlideColumn(grid, colIdx, dir) {
    if (colIdx < 0 || colIdx >= COLS || isGameOver) return false;
    var col = grid[colIdx];

    if (dir === -1) {
        // Sliding UP: Cannot slide if top slot (0) is occupied
        return col[0] === null;
    } else if (dir === 1) {
        // Sliding DOWN: Cannot slide if bottom slot (ROWS - 1) is occupied
        return col[ROWS - 1] === null;
    }
    return false;
}

// Slides column within bounds (returns true if moved, false if blocked by chute boundary)
function slideColumnBounded(grid, rollAngles, colIdx, dir) {
    if (!canSlideColumn(grid, colIdx, dir)) return false;

    var col = grid[colIdx];

    if (dir === -1) {
        // Shift UP into empty space above
        for (var r = 0; r < ROWS - 1; r++) {
            col[r] = col[r + 1];
        }
        col[ROWS - 1] = null;
        if (rollAngles) rollAngles[colIdx] -= 0.65;
    } else if (dir === 1) {
        // Shift DOWN into empty space below
        for (var r = ROWS - 1; r > 0; r--) {
            col[r] = col[r - 1];
        }
        col[0] = null;
        if (rollAngles) rollAngles[colIdx] += 0.65;
    }

    return true;
}

// Shift the center Pitch Line horizontally (wrapping across the 5 columns)
function slidePitchLine(grid, dir) {
    if (isGameOver) return false;

    if (dir === -1) {
        var first = grid[0][PITCH_ROW];
        for (var c = 0; c < COLS - 1; c++) {
            grid[c][PITCH_ROW] = grid[c + 1][PITCH_ROW];
        }
        grid[COLS - 1][PITCH_ROW] = first;
    } else if (dir === 1) {
        var last = grid[COLS - 1][PITCH_ROW];
        for (var c = COLS - 1; c > 0; c--) {
            grid[c][PITCH_ROW] = grid[c - 1][PITCH_ROW];
        }
        grid[0][PITCH_ROW] = last;
    }
    return true;
}

// Find matches on the Pitch Line (Row 5)
function findPitchMatches(grid) {
    var matches = [];
    var bombTriggers = [];

    var pitchRow = [];
    for (var c = 0; c < COLS; c++) {
        pitchRow.push(grid[c][PITCH_ROW]);
    }

    for (var c = 0; c < COLS; c++) {
        var p = pitchRow[c];
        if (p && p.type === "hanabi") {
            bombTriggers.push(c);
        }
    }

    var runStart = 0;
    var runType = null;
    var runLen = 0;

    for (var c = 0; c <= COLS; c++) {
        var p = (c < COLS) ? pitchRow[c] : null;
        var pType = p ? p.type : null;

        if (pType && pType === runType) {
            runLen++;
        } else {
            if (runLen >= 3 && runType !== null) {
                for (var k = runStart; k < runStart + runLen; k++) {
                    if (matches.indexOf(k) === -1) {
                        matches.push(k);
                    }
                }
            }
            runStart = c;
            runType = pType;
            runLen = 1;
        }
    }

    // Basalt obstacle clearing: when a match occurs on the pitch line,
    // adjacent basalt stones on the pitch line are shattered and cleared as well
    if (matches.length > 0) {
        for (var c = 0; c < COLS; c++) {
            var p = pitchRow[c];
            if (p && p.type === "basalt" && matches.indexOf(c) === -1) {
                for (var m = 0; m < matches.length; m++) {
                    if (Math.abs(matches[m] - c) === 1) {
                        matches.push(c);
                        break;
                    }
                }
            }
        }
    }

    return {
        matchedCols: matches,
        bombCols: bombTriggers
    };
}

// Process clears, Hanabi detonations, inward gravity, and generate garbage for the rival
function processClearsAndGravity(isPlayer) {
    var grid = isPlayer ? playerGrid : aiGrid;
    var matchInfo = findPitchMatches(grid);
    var colsToClear = matchInfo.matchedCols.slice();
    var bombsDetonated = [];

    // Detonate bombs if in match or adjacent to a match
    for (var b = 0; b < matchInfo.bombCols.length; b++) {
        var bCol = matchInfo.bombCols[b];
        var shouldDetonate = (colsToClear.indexOf(bCol) !== -1);
        if (!shouldDetonate) {
            for (var m = 0; m < colsToClear.length; m++) {
                if (Math.abs(colsToClear[m] - bCol) <= 1) {
                    shouldDetonate = true;
                    break;
                }
            }
        }
        if (shouldDetonate) {
            bombsDetonated.push(bCol);
            for (var dc = -1; dc <= 1; dc++) {
                var targetCol = bCol + dc;
                if (targetCol >= 0 && targetCol < COLS) {
                    for (var dr = -1; dr <= 1; dr++) {
                        var targetRow = PITCH_ROW + dr;
                        if (targetRow >= 0 && targetRow < ROWS) {
                            grid[targetCol][targetRow] = null;
                        }
                    }
                    if (colsToClear.indexOf(targetCol) === -1) {
                        colsToClear.push(targetCol);
                    }
                }
            }
        }
    }

    var clearedCount = colsToClear.length;
    var scoreEarned = 0;
    var garbageToSend = 0;
    var basaltToSend = 0;

    if (clearedCount > 0) {
        if (isPlayer) {
            playerCombo++;
            scoreEarned = clearedCount * 100 * playerCombo;
            score += scoreEarned;
        } else {
            aiCombo++;
            scoreEarned = clearedCount * 100 * aiCombo;
            aiScore += scoreEarned;
        }

        // Garbage Attack Calculation:
        // Combo >= 2: 1 bonus garbage per combo level
        // 4-match: 2 garbage marbles to opponent
        // 5-match (Wipeout): 3 garbage marbles + 1 Kyoto basalt stone to opponent!
        var currentCombo = isPlayer ? playerCombo : aiCombo;
        var comboBonus = currentCombo >= 2 ? (currentCombo - 1) : 0;

        if (clearedCount === 4) {
            garbageToSend = 2 + comboBonus;
        } else if (clearedCount >= 5) {
            garbageToSend = 3 + comboBonus;
            basaltToSend = 1;
        } else if (comboBonus > 0) {
            garbageToSend = comboBonus;
        }

        // Clear matched marbles on Pitch Line
        for (var i = 0; i < colsToClear.length; i++) {
            grid[colsToClear[i]][PITCH_ROW] = null;
        }

        // Apply DUAL INWARD GRAVITY
        for (var c = 0; c < COLS; c++) {
            applyInwardGravityToColumn(grid, c);
        }
    }

    return {
        clearedCount: clearedCount,
        bombs: bombsDetonated,
        scoreEarned: scoreEarned,
        combo: isPlayer ? playerCombo : aiCombo,
        garbageSent: garbageToSend,
        basaltSent: basaltToSend
    };
}

// Inward dual gravity: upper stack falls down, lower stack collapses up
function applyInwardGravityToColumn(grid, c) {
    var upperItems = [];
    for (var r = 0; r < PITCH_ROW; r++) {
        if (grid[c][r] !== null) upperItems.push(grid[c][r]);
    }

    var lowerItems = [];
    for (var r = PITCH_ROW + 1; r < ROWS; r++) {
        if (grid[c][r] !== null) lowerItems.push(grid[c][r]);
    }

    if (grid[c][PITCH_ROW] === null) {
        if (upperItems.length > 0) {
            grid[c][PITCH_ROW] = upperItems.pop();
        } else if (lowerItems.length > 0) {
            grid[c][PITCH_ROW] = lowerItems.shift();
        }
    }

    for (var r = 0; r < PITCH_ROW; r++) grid[c][r] = null;
    var topFillIdx = PITCH_ROW - 1;
    while (upperItems.length > 0 && topFillIdx >= 0) {
        grid[c][topFillIdx] = upperItems.pop();
        topFillIdx--;
    }

    for (var r = PITCH_ROW + 1; r < ROWS; r++) grid[c][r] = null;
    var btmFillIdx = PITCH_ROW + 1;
    while (lowerItems.length > 0 && btmFillIdx < ROWS) {
        grid[c][btmFillIdx] = lowerItems.shift();
        btmFillIdx++;
    }
}

// Immediately inject attack penalty marbles into the recipient's chutes
function injectAttack(isTargetPlayer, garbageCount, basaltCount) {
    if (isGameOver) return 0;
    var targetGrid = isTargetPlayer ? playerGrid : aiGrid;
    var totalInjected = 0;

    var items = [];
    for (var b = 0; b < basaltCount; b++) {
        items.push("basalt");
    }
    for (var g = 0; g < garbageCount; g++) {
        items.push(null); // random artisanal marble
    }

    for (var i = 0; i < items.length; i++) {
        var mType = items[i];
        // Find chute with the most room (fewest marbles)
        var bestCol = -1;
        var minCount = 999;
        for (var c = 0; c < COLS; c++) {
            var count = 0;
            for (var r = 0; r < ROWS; r++) {
                if (targetGrid[c][r] !== null) count++;
            }
            if (count < minCount) {
                minCount = count;
                bestCol = c;
            }
        }

        if (bestCol === -1 || minCount >= ROWS) {
            // Recipient board is completely jammed -> Overflow Defeat!
            isGameOver = true;
            winner = isTargetPlayer ? "ai" : "player";
            break;
        }

        var newMarble = createMarble(mType);
        var placed = false;
        // Alternate inserting into top (row 0) and bottom (row 10)
        if (i % 2 === 0) {
            if (targetGrid[bestCol][0] === null) {
                targetGrid[bestCol][0] = newMarble;
                placed = true;
            } else if (targetGrid[bestCol][ROWS - 1] === null) {
                targetGrid[bestCol][ROWS - 1] = newMarble;
                placed = true;
            }
        } else {
            if (targetGrid[bestCol][ROWS - 1] === null) {
                targetGrid[bestCol][ROWS - 1] = newMarble;
                placed = true;
            } else if (targetGrid[bestCol][0] === null) {
                targetGrid[bestCol][0] = newMarble;
                placed = true;
            }
        }

        if (placed) {
            applyInwardGravityToColumn(targetGrid, bestCol);
            totalInjected++;
        } else {
            isGameOver = true;
            winner = isTargetPlayer ? "ai" : "player";
            break;
        }
    }

    checkGameOver();
    return totalInjected;
}

// Inject garbage or periodic single marble drop into a grid
function injectGarbageOrDrop(grid, garbageQueue) {
    if (isGameOver) return false;

    // Find column with the most room (fewest marbles)
    var bestCol = -1;
    var minCount = 999;
    for (var c = 0; c < COLS; c++) {
        var count = 0;
        for (var r = 0; r < ROWS; r++) {
            if (grid[c][r] !== null) count++;
        }
        if (count < minCount) {
            minCount = count;
            bestCol = c;
        }
    }

    if (bestCol === -1 || minCount >= ROWS) {
        // Board is full!
        return false;
    }

    var marbleType = null;
    if (garbageQueue && garbageQueue.length > 0) {
        var queued = garbageQueue.shift();
        marbleType = (queued === "basalt") ? "basalt" : null;
    }

    var newMarble = createMarble(marbleType);

    // Drop into top slot if empty, otherwise bottom slot
    if (grid[bestCol][0] === null) {
        grid[bestCol][0] = newMarble;
    } else if (grid[bestCol][ROWS - 1] === null) {
        grid[bestCol][ROWS - 1] = newMarble;
    } else {
        return false;
    }

    applyInwardGravityToColumn(grid, bestCol);
    return true;
}

// Drop an authentic full wave (1 new marble into every chute)
function dropWave(grid) {
    if (isGameOver) return { jammed: false, dropped: 0 };
    var dropped = 0;
    var jammed = false;

    for (var c = 0; c < COLS; c++) {
        var count = 0;
        for (var r = 0; r < ROWS; r++) {
            if (grid[c][r] !== null) count++;
        }

        if (count >= ROWS) {
            // Chute has reached maximum capacity (all 11 slots full) -> Overflow Jam!
            jammed = true;
            continue;
        }

        var m = createMarble(null);
        if (grid[c][0] === null) {
            grid[c][0] = m;
        } else if (grid[c][ROWS - 1] === null) {
            grid[c][ROWS - 1] = m;
        } else {
            for (var r = 0; r < ROWS; r++) {
                if (grid[c][r] === null) {
                    grid[c][r] = m;
                    break;
                }
            }
        }
        applyInwardGravityToColumn(grid, c);
        dropped++;
    }

    return { jammed: jammed, dropped: dropped };
}

// Check win / loss condition
function checkGameOver(gameMode) {
    if (isGameOver) return winner;

    var mode = gameMode || "duel";

    var playerTotalMarbles = 0;
    var playerAnyChuteFull = false;
    for (var c = 0; c < COLS; c++) {
        var pCount = 0;
        for (var r = 0; r < ROWS; r++) {
            if (playerGrid[c][r] !== null) pCount++;
        }
        playerTotalMarbles += pCount;
        if (pCount >= ROWS) playerAnyChuteFull = true;
    }

    if (mode === "solo") {
        if (playerAnyChuteFull) {
            isGameOver = true;
            winner = "jam";
        }
        return isGameOver ? winner : null;
    }

    // Duel Mode: Check AI Jam / Overflow / Empty
    var aiTotalMarbles = 0;
    var aiAnyChuteFull = false;
    for (var c = 0; c < COLS; c++) {
        var aCount = 0;
        for (var r = 0; r < ROWS; r++) {
            if (aiGrid[c][r] !== null) aCount++;
        }
        aiTotalMarbles += aCount;
        if (aCount >= ROWS) aiAnyChuteFull = true;
    }

    if (playerTotalMarbles === 0 || aiAnyChuteFull) {
        isGameOver = true;
        winner = "player";
    } else if (aiTotalMarbles === 0 || playerAnyChuteFull) {
        isGameOver = true;
        winner = "ai";
    }

    return isGameOver ? winner : null;
}

// =============================================================================
// COMPUTER OPPONENT AI HEURISTIC LOOKAHEAD
// =============================================================================
function computeBestAIMove() {
    if (isGameOver) return null;

    var bestMove = null;
    var bestScore = -1;

    // Test moving pitch line Left (-1) and Right (+1)
    var pitchDirs = [-1, 1];
    for (var p = 0; p < pitchDirs.length; p++) {
        var pDir = pitchDirs[p];
        slidePitchLine(aiGrid, pDir);
        var m = findPitchMatches(aiGrid);
        var matchScore = m.matchedCols.length * 10 + m.bombCols.length * 15;
        // Revert
        slidePitchLine(aiGrid, -pDir);

        if (matchScore > bestScore && matchScore > 0) {
            bestScore = matchScore;
            bestMove = { action: "pitch", dir: pDir };
        }
    }

    // Test sliding any of the 5 columns Up (-1) and Down (+1)
    for (var c = 0; c < COLS; c++) {
        var colDirs = [-1, 1];
        for (var d = 0; d < colDirs.length; d++) {
            var dir = colDirs[d];
            if (canSlideColumn(aiGrid, c, dir)) {
                slideColumnBounded(aiGrid, null, c, dir);
                var m = findPitchMatches(aiGrid);
                var matchScore = m.matchedCols.length * 10 + m.bombCols.length * 15;
                // Revert
                slideColumnBounded(aiGrid, null, c, -dir);

                if (matchScore > bestScore && matchScore > 0) {
                    bestScore = matchScore;
                    bestMove = { action: "col", col: c, dir: dir };
                }
            }
        }
    }

    // If no immediate match is found, pick a column with room to slide and align pairs
    if (!bestMove) {
        var candidateCols = [];
        for (var c = 0; c < COLS; c++) {
            if (canSlideColumn(aiGrid, c, -1) || canSlideColumn(aiGrid, c, 1)) {
                candidateCols.push(c);
            }
        }
        if (candidateCols.length > 0) {
            var chosenCol = candidateCols[Math.floor(Math.random() * candidateCols.length)];
            var chosenDir = canSlideColumn(aiGrid, chosenCol, -1) ? (canSlideColumn(aiGrid, chosenCol, 1) ? (Math.random() < 0.5 ? -1 : 1) : -1) : 1;
            bestMove = { action: "col", col: chosenCol, dir: chosenDir };
        }
    }

    return bestMove;
}
