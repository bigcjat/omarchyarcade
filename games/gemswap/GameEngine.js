.pragma library

var GRID_SIZE = 8;
var NUM_TYPES = 7;

var SPECIAL = {
    NONE: 0,
    FLAME: 1, // 3x3 explosion
    STAR: 2,  // Clears full row & col
    HYPER: 3  // Clears all of targeted color
};

var STATE = {
    IDLE: "idle",
    SWAPPING: "swapping",
    REVERTING: "reverting",
    CLEARING: "clearing",
    FALLING: "falling",
    SHUFFLING: "shuffling"
};

var board = [];
var selectedTile = null; // { r, c }
var score = 0;
var highScore = 0;
var combo = 1;
var level = 1;
var levelScore = 0;
var levelTargetScore = 1500;
var activeHint = null; // { r1, c1, r2, c2 }
var gameState = STATE.IDLE;
var swapInfo = null; // { r1, c1, r2, c2, progress, isRevert }
var clearingTiles = [];
var particles = [];
var globalTimer = 0;
var nextTileId = 1;

function init() {
    score = 0;
    combo = 1;
    level = 1;
    levelScore = 0;
    levelTargetScore = 1500;
    activeHint = null;
    gameState = STATE.IDLE;
    selectedTile = null;
    particles = [];
    clearingTiles = [];
    resetBoard();
}

function resetBoard() {
    var valid = false;
    var attempts = 0;
    while (!valid && attempts < 200) {
        attempts++;
        board = [];
        for (var r = 0; r < GRID_SIZE; r++) {
            board[r] = [];
            for (var c = 0; c < GRID_SIZE; c++) {
                var gemType = Math.floor(Math.random() * NUM_TYPES) + 1;
                // Avoid starting 3-in-a-row
                while ((c >= 2 && board[r][c-1].type === gemType && board[r][c-2].type === gemType) ||
                       (r >= 2 && board[r-1][c].type === gemType && board[r-2][c].type === gemType)) {
                    gemType = Math.floor(Math.random() * NUM_TYPES) + 1;
                }
                board[r][c] = {
                    id: nextTileId++,
                    type: gemType,
                    special: SPECIAL.NONE,
                    x: c,
                    y: r,
                    scale: 1.0,
                    alpha: 1.0
                };
            }
        }
        if (hasPossibleMoves()) {
            valid = true;
        }
    }
}

function getTile(r, c) {
    if (r >= 0 && r < GRID_SIZE && c >= 0 && c < GRID_SIZE) {
        return board[r][c];
    }
    return null;
}

function findHint() {
    for (var r = 0; r < GRID_SIZE; r++) {
        for (var c = 0; c < GRID_SIZE; c++) {
            // Test swap right
            if (c + 1 < GRID_SIZE) {
                if (testSwapCreatesMatch(r, c, r, c + 1)) {
                    return { r1: r, c1: c, r2: r, c2: c + 1 };
                }
            }
            // Test swap down
            if (r + 1 < GRID_SIZE) {
                if (testSwapCreatesMatch(r, c, r + 1, c)) {
                    return { r1: r, c1: c, r2: r + 1, c2: c };
                }
            }
        }
    }
    return null;
}

function hasPossibleMoves() {
    return findHint() !== null;
}

function testSwapCreatesMatch(r1, c1, r2, c2) {
    var t1 = board[r1][c1];
    var t2 = board[r2][c2];
    if (!t1 || !t2) return false;

    // Hyper gem swaps are always valid moves
    if (t1.special === SPECIAL.HYPER || t2.special === SPECIAL.HYPER) return true;

    // Swap types temporarily
    var tempType = t1.type;
    t1.type = t2.type;
    t2.type = tempType;

    var matches = findMatchesOnBoard();

    // Revert types
    t2.type = t1.type;
    t1.type = tempType;

    return matches.length > 0;
}

function findMatchesOnBoard() {
    var matchedCells = {};

    // Horizontal check
    for (var r = 0; r < GRID_SIZE; r++) {
        var matchLen = 1;
        for (var c = 0; c < GRID_SIZE; c++) {
            var curr = board[r][c];
            var next = (c + 1 < GRID_SIZE) ? board[r][c+1] : null;

            if (curr && next && curr.type === next.type && curr.type > 0) {
                matchLen++;
            } else {
                if (matchLen >= 3) {
                    for (var k = 0; k < matchLen; k++) {
                        var colIdx = c - k;
                        var key = r + "," + colIdx;
                        if (!matchedCells[key]) matchedCells[key] = { r: r, c: colIdx, horiz: matchLen, vert: 0 };
                        else matchedCells[key].horiz = Math.max(matchedCells[key].horiz, matchLen);
                    }
                }
                matchLen = 1;
            }
        }
    }

    // Vertical check
    for (var c = 0; c < GRID_SIZE; c++) {
        var vMatchLen = 1;
        for (var r = 0; r < GRID_SIZE; r++) {
            var currV = board[r][c];
            var nextV = (r + 1 < GRID_SIZE) ? board[r+1][c] : null;

            if (currV && nextV && currV.type === nextV.type && currV.type > 0) {
                vMatchLen++;
            } else {
                if (vMatchLen >= 3) {
                    for (var m = 0; m < vMatchLen; m++) {
                        var rowIdx = r - m;
                        var vKey = rowIdx + "," + c;
                        if (!matchedCells[vKey]) matchedCells[vKey] = { r: rowIdx, c: c, horiz: 0, vert: vMatchLen };
                        else matchedCells[vKey].vert = Math.max(matchedCells[vKey].vert, vMatchLen);
                    }
                }
                vMatchLen = 1;
            }
        }
    }

    var result = [];
    for (var key in matchedCells) {
        result.push(matchedCells[key]);
    }
    return result;
}

function trySelectOrSwap(r, c, callbacks) {
    if (gameState !== STATE.IDLE) return;
    if (r < 0 || r >= GRID_SIZE || c < 0 || c >= GRID_SIZE) return;

    activeHint = null;

    if (!selectedTile) {
        selectedTile = { r: r, c: c };
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
        return;
    }

    var r1 = selectedTile.r;
    var c1 = selectedTile.c;
    var r2 = r;
    var c2 = c;

    // Deselect if clicked same tile
    if (r1 === r2 && c1 === c2) {
        selectedTile = null;
        if (callbacks && callbacks.onSound) callbacks.onSound("click");
        return;
    }

    // Check if adjacent
    var dist = Math.abs(r1 - r2) + Math.abs(c1 - c2);
    if (dist === 1) {
        // Start swap animation
        selectedTile = null;
        startSwap(r1, c1, r2, c2, callbacks);
    } else {
        // Select new tile
        selectedTile = { r: r, c: c };
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
    }
}

function startSwap(r1, c1, r2, c2, callbacks) {
    gameState = STATE.SWAPPING;
    swapInfo = {
        r1: r1, c1: c1,
        r2: r2, c2: c2,
        progress: 0,
        isRevert: false,
        callbacks: callbacks
    };
    if (callbacks && callbacks.onSound) callbacks.onSound("move");
}

function executeSwap(r1, c1, r2, c2) {
    var temp = board[r1][c1];
    board[r1][c1] = board[r2][c2];
    board[r2][c2] = temp;
    board[r1][c1].x = c1;
    board[r1][c1].y = r1;
    board[r2][c2].x = c2;
    board[r2][c2].y = r2;
}

function processMatches(callbacks, swapOrigin) {
    var matches = findMatchesOnBoard();
    if (matches.length === 0) return false;

    // Check special tile creations
    var specialSpawn = null; // { r, c, type, special }

    for (var i = 0; i < matches.length; i++) {
        var m = matches[i];
        if (m.horiz >= 5 || m.vert >= 5) {
            specialSpawn = { r: m.r, c: m.c, type: 0, special: SPECIAL.HYPER };
            break;
        } else if (m.horiz >= 3 && m.vert >= 3) {
            specialSpawn = { r: m.r, c: m.c, type: board[m.r][m.c].type, special: SPECIAL.STAR };
            break;
        } else if ((m.horiz === 4 || m.vert === 4) && !specialSpawn) {
            specialSpawn = { r: m.r, c: m.c, type: board[m.r][m.c].type, special: SPECIAL.FLAME };
        }
    }

    // Expand matches for activated special gems
    var toClear = {};
    for (var j = 0; j < matches.length; j++) {
        toClear[matches[j].r + "," + matches[j].c] = true;
    }

    // Trigger specials
    for (var key in toClear) {
        var parts = key.split(",");
        var pr = parseInt(parts[0]);
        var pc = parseInt(parts[1]);
        var tile = board[pr][pc];
        if (!tile) continue;

        if (tile.special === SPECIAL.FLAME) {
            // 3x3 explosion
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    var er = pr + dr;
                    var ec = pc + dc;
                    if (er >= 0 && er < GRID_SIZE && ec >= 0 && ec < GRID_SIZE) {
                        toClear[er + "," + ec] = true;
                        spawnExplosionParticles(ec, er, "#ff7a93");
                    }
                }
            }
        } else if (tile.special === SPECIAL.STAR) {
            // Full row and col
            for (var sc = 0; sc < GRID_SIZE; sc++) toClear[pr + "," + sc] = true;
            for (var sr = 0; sr < GRID_SIZE; sr++) toClear[sr + "," + pc] = true;
            spawnLaserParticles(pc, pr);
        }
    }

    // Calculate score
    var clearCount = 0;
    clearingTiles = [];
    for (var cKey in toClear) {
        var coords = cKey.split(",");
        var cr = parseInt(coords[0]);
        var cc = parseInt(coords[1]);
        if (board[cr][cc]) {
            clearingTiles.push({ r: cr, c: cc, tile: board[cr][cc], alpha: 1.0, scale: 1.0 });
            spawnGemPopParticles(cc, cr, board[cr][cc].type);
            clearCount++;
        }
    }

    var earned = clearCount * 20 * combo;
    if (clearCount >= 4) earned += 50 * combo;
    if (clearCount >= 5) earned += 150 * combo;
    score += earned;
    levelScore += earned;

    if (callbacks) {
        if (callbacks.onScoreChanged) callbacks.onScoreChanged(score);
        if (callbacks.onSound) callbacks.onSound(combo > 1 ? "win" : "dock");
    }

    gameState = STATE.CLEARING;

    // Apply special gem spawn after clearing
    if (specialSpawn && toClear[specialSpawn.r + "," + specialSpawn.c]) {
        // Will be restored during fall or cleared animation
        clearingTiles.specialToSpawn = specialSpawn;
    }

    return true;
}

function checkLevelUp(callbacks) {
    if (levelScore >= levelTargetScore) {
        var leftover = levelScore - levelTargetScore;
        level++;
        levelScore = leftover;
        levelTargetScore = 1500 + (level - 1) * 1000;
        var bonus = level * 500;
        score += bonus;
        if (callbacks) {
            if (callbacks.onLevelChanged) callbacks.onLevelChanged(level, bonus);
            if (callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            if (callbacks.onSound) callbacks.onSound("win");
        }
        return true;
    }
    return false;
}

function processHyperGemSwap(r1, c1, r2, c2, callbacks) {
    var t1 = board[r1][c1];
    var t2 = board[r2][c2];
    var hyperTile = (t1.special === SPECIAL.HYPER) ? t1 : t2;
    var targetTile = (t1.special === SPECIAL.HYPER) ? t2 : t1;
    var targetColor = targetTile.type;

    var toClear = {};
    toClear[r1 + "," + c1] = true;
    toClear[r2 + "," + c2] = true;

    for (var r = 0; r < GRID_SIZE; r++) {
        for (var c = 0; c < GRID_SIZE; c++) {
            if (board[r][c] && (board[r][c].type === targetColor || hyperTile.special === SPECIAL.HYPER && targetTile.special === SPECIAL.HYPER)) {
                toClear[r + "," + c] = true;
                spawnGemPopParticles(c, r, board[r][c].type);
            }
        }
    }

    var count = 0;
    clearingTiles = [];
    for (var key in toClear) {
        var p = key.split(",");
        var pr = parseInt(p[0]);
        var pc = parseInt(p[1]);
        if (board[pr][pc]) {
            clearingTiles.push({ r: pr, c: pc, tile: board[pr][pc], alpha: 1.0, scale: 1.0 });
            count++;
        }
    }

    var earnedHyper = count * 40 * combo;
    score += earnedHyper;
    levelScore += earnedHyper;
    if (callbacks) {
        if (callbacks.onScoreChanged) callbacks.onScoreChanged(score);
        if (callbacks.onSound) callbacks.onSound("win");
    }

    gameState = STATE.CLEARING;
}

function applyGravity() {
    // Fill empty spaces from bottom up
    var maxFallDist = 0;

    for (var c = 0; c < GRID_SIZE; c++) {
        var writeRow = GRID_SIZE - 1;
        for (var r = GRID_SIZE - 1; r >= 0; r--) {
            if (board[r][c] !== null) {
                if (writeRow !== r) {
                    board[writeRow][c] = board[r][c];
                    board[writeRow][c].y = writeRow;
                    board[writeRow][c].fallDistance = writeRow - r;
                    maxFallDist = Math.max(maxFallDist, writeRow - r);
                    board[r][c] = null;
                }
                writeRow--;
            }
        }

        // Spawn new tiles for remaining empty spots
        var spawnOffset = 1;
        for (var emptyR = writeRow; emptyR >= 0; emptyR--) {
            var newType = Math.floor(Math.random() * NUM_TYPES) + 1;
            board[emptyR][c] = {
                id: nextTileId++,
                type: newType,
                special: SPECIAL.NONE,
                x: c,
                y: emptyR,
                visualY: emptyR - (writeRow + spawnOffset),
                scale: 1.0,
                alpha: 1.0
            };
            maxFallDist = Math.max(maxFallDist, (writeRow + spawnOffset));
            spawnOffset++;
        }
    }

    gameState = STATE.FALLING;
}

function update(callbacks) {
    globalTimer++;

    // Update Particles
    for (var p = particles.length - 1; p >= 0; p--) {
        var pt = particles[p];
        pt.x += pt.vx;
        pt.y += pt.vy;
        pt.life -= pt.decay;
        pt.scale *= 0.96;
        if (pt.life <= 0) {
            particles.splice(p, 1);
        }
    }

    // State Machine
    if (gameState === STATE.SWAPPING) {
        swapInfo.progress += 0.12;
        if (swapInfo.progress >= 1.0) {
            swapInfo.progress = 1.0;
            executeSwap(swapInfo.r1, swapInfo.c1, swapInfo.r2, swapInfo.c2);

            var t1 = board[swapInfo.r1][swapInfo.c1];
            var t2 = board[swapInfo.r2][swapInfo.c2];

            // Hyper gem swap check
            if (t1.special === SPECIAL.HYPER || t2.special === SPECIAL.HYPER) {
                processHyperGemSwap(swapInfo.r1, swapInfo.c1, swapInfo.r2, swapInfo.c2, swapInfo.callbacks);
                swapInfo = null;
            } else {
                var hasMatch = processMatches(swapInfo.callbacks);
                if (hasMatch) {
                    combo = 1;
                    swapInfo = null;
                } else {
                    // Revert swap
                    gameState = STATE.REVERTING;
                    swapInfo.progress = 0;
                    swapInfo.isRevert = true;
                    if (swapInfo.callbacks && swapInfo.callbacks.onSound) {
                        swapInfo.callbacks.onSound("push");
                    }
                }
            }
        }
    } else if (gameState === STATE.REVERTING) {
        swapInfo.progress += 0.12;
        if (swapInfo.progress >= 1.0) {
            executeSwap(swapInfo.r1, swapInfo.c1, swapInfo.r2, swapInfo.c2);
            swapInfo = null;
            gameState = STATE.IDLE;
        }
    } else if (gameState === STATE.CLEARING) {
        var allDone = true;
        for (var cl = 0; cl < clearingTiles.length; cl++) {
            var item = clearingTiles[cl];
            item.scale += 0.08;
            item.alpha -= 0.15;
            if (item.alpha > 0) allDone = false;
        }

        if (allDone) {
            // Nullify cleared cells
            for (var k = 0; k < clearingTiles.length; k++) {
                var cr = clearingTiles[k].r;
                var cc = clearingTiles[k].c;
                board[cr][cc] = null;
            }

            // Spawn special gem if earned
            if (clearingTiles.specialToSpawn) {
                var sp = clearingTiles.specialToSpawn;
                board[sp.r][sp.c] = {
                    id: nextTileId++,
                    type: sp.type || 1,
                    special: sp.special,
                    x: sp.c,
                    y: sp.r,
                    scale: 1.0,
                    alpha: 1.0
                };
            }

            clearingTiles = [];
            applyGravity();
        }
    } else if (gameState === STATE.FALLING) {
        var stillFalling = false;
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                var t = board[r][c];
                if (!t) continue;
                if (t.visualY !== undefined && t.visualY < t.y) {
                    t.visualY += 0.22;
                    if (t.visualY >= t.y) {
                        t.visualY = t.y;
                    } else {
                        stillFalling = true;
                    }
                }
            }
        }

        if (!stillFalling) {
            // Reset visualY
            for (var fr = 0; fr < GRID_SIZE; fr++) {
                for (var fc = 0; fc < GRID_SIZE; fc++) {
                    if (board[fr][fc]) board[fr][fc].visualY = fr;
                }
            }

            // Check cascade matches
            combo++;
            var cascaded = processMatches(callbacks);
            if (!cascaded) {
                combo = 1;
                checkLevelUp(callbacks);

                // Check if any moves remain
                if (!hasPossibleMoves()) {
                    gameState = "gameover";
                    if (callbacks) {
                        if (callbacks.onGameOver) callbacks.onGameOver(score);
                        if (callbacks.onSound) callbacks.onSound("game_over");
                    }
                } else {
                    gameState = STATE.IDLE;
                }
            }
        }
    }
}

function spawnGemPopParticles(c, r, gemType) {
    var count = 12;
    var colors = ["#e06c75", "#78b880", "#7aa2f7", "#e5c07b", "#bb9af7", "#e08b68", "#a9b1d6"];
    var col = colors[(gemType - 1) % colors.length] || "#cdd6f4";

    for (var i = 0; i < count; i++) {
        var angle = Math.random() * Math.PI * 2;
        var speed = 0.08 + Math.random() * 0.12;
        particles.push({
            x: c + 0.5,
            y: r + 0.5,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1.0,
            decay: 0.04 + Math.random() * 0.03,
            scale: 0.15 + Math.random() * 0.1,
            color: col
        });
    }
}

function spawnExplosionParticles(c, r, color) {
    for (var i = 0; i < 8; i++) {
        var angle = Math.random() * Math.PI * 2;
        var speed = 0.12 + Math.random() * 0.18;
        particles.push({
            x: c + 0.5,
            y: r + 0.5,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1.0,
            decay: 0.05,
            scale: 0.22,
            color: color
        });
    }
}

function spawnLaserParticles(c, r) {
    for (var i = 0; i < 16; i++) {
        var isHoriz = Math.random() > 0.5;
        particles.push({
            x: isHoriz ? Math.random() * GRID_SIZE : c + 0.5,
            y: isHoriz ? r + 0.5 : Math.random() * GRID_SIZE,
            vx: 0,
            vy: 0,
            life: 0.8,
            decay: 0.06,
            scale: 0.2,
            color: "#89b4fa"
        });
    }
}
