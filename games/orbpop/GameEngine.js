.pragma library

var COLS_EVEN = 8;
var COLS_ODD = 7;
var MAX_ROWS = 14;
var DANGER_ROW = 11;
var NUM_COLORS = 5;

var grid = []; // 2D array [r][c] = { color, id } or null
var projectile = null; // { x, y, vx, vy, color, radius }
var currentOrbColor = 1;
var nextOrbColor = 2;
var cannonAngle = 0; // in radians, 0 is straight UP
var cannonX = 0;
var cannonY = 0;
var bubbleRadius = 20;
var rowHeight = 34.64; // sqrt(3) * radius
var boardWidth = 320;
var boardHeight = 500;

var score = 0;
var highScore = 0;
var level = 1;
var clearTimer = 0;
var misses = 0;
var maxMisses = 5;
var gameState = "playing"; // "playing", "gameover", "cleared"
var fallingOrbs = [];
var particles = [];
var globalTimer = 0;
var nextId = 1;

function init(width, height) {
    boardWidth = width || 360;
    boardHeight = height || 520;
    bubbleRadius = boardWidth / (COLS_EVEN * 2);
    rowHeight = Math.sqrt(3) * bubbleRadius;
    cannonX = boardWidth * 0.5;
    cannonY = boardHeight - bubbleRadius * 1.8;

    score = 0;
    level = 1;
    misses = 0;
    clearTimer = 0;
    gameState = "playing";
    projectile = null;
    fallingOrbs = [];
    particles = [];

    resetGrid(level);
    currentOrbColor = getRandomActiveColor();
    nextOrbColor = getRandomActiveColor();
}

var topRowParity = 0;

function isEvenRow(r) {
    return ((r + topRowParity) % 2 === 0);
}

function getColsForRow(r) {
    return isEvenRow(r) ? COLS_EVEN : COLS_ODD;
}

function resetGrid(lvl) {
    lvl = lvl || level || 1;
    topRowParity = 0;
    grid = [];
    var initialRows = Math.min(7, 3 + Math.floor(lvl / 2));
    var numColorsForLevel = Math.min(NUM_COLORS, 3 + Math.floor((lvl - 1) / 2));
    for (var r = 0; r < MAX_ROWS; r++) {
        grid[r] = [];
        var cols = getColsForRow(r);
        for (var c = 0; c < cols; c++) {
            if (r < initialRows) {
                grid[r][c] = {
                    id: nextId++,
                    color: Math.floor(Math.random() * numColorsForLevel) + 1
                };
            } else {
                grid[r][c] = null;
            }
        }
    }
}

function startNextLevel(callbacks) {
    level++;
    misses = 0;
    projectile = null;
    clearTimer = 0;
    fallingOrbs = [];
    resetGrid(level);
    currentOrbColor = getRandomActiveColor();
    nextOrbColor = getRandomActiveColor();
    gameState = "playing";

    if (callbacks) {
        if (callbacks.onLevelChanged) callbacks.onLevelChanged(level);
        if (callbacks.onSound) callbacks.onSound("dock");
    }
}

function getCellPos(r, c) {
    var isEven = isEvenRow(r);
    var rOffset = isEven ? bubbleRadius : (bubbleRadius * 2);
    var x = rOffset + c * (bubbleRadius * 2);
    var y = bubbleRadius + r * rowHeight;
    return { x: x, y: y };
}

function getRandomActiveColor() {
    var activeColors = {};
    var hasAny = false;
    for (var r = 0; r < MAX_ROWS; r++) {
        var cols = getColsForRow(r);
        for (var c = 0; c < cols; c++) {
            if (grid[r] && grid[r][c]) {
                activeColors[grid[r][c].color] = true;
                hasAny = true;
            }
        }
    }
    if (!hasAny) return Math.floor(Math.random() * NUM_COLORS) + 1;
    var keys = Object.keys(activeColors);
    return parseInt(keys[Math.floor(Math.random() * keys.length)]);
}

function getNeighbors(r, c) {
    var neighbors = [];
    var isEven = isEvenRow(r);

    var offsets = isEven ? [
        { dr: 0, dc: -1 }, { dr: 0, dc: 1 },
        { dr: -1, dc: -1 }, { dr: -1, dc: 0 },
        { dr: 1, dc: -1 }, { dr: 1, dc: 0 }
    ] : [
        { dr: 0, dc: -1 }, { dr: 0, dc: 1 },
        { dr: -1, dc: 0 }, { dr: -1, dc: 1 },
        { dr: 1, dc: 0 }, { dr: 1, dc: 1 }
    ];

    for (var i = 0; i < offsets.length; i++) {
        var nr = r + offsets[i].dr;
        var nc = c + offsets[i].dc;
        if (nr >= 0 && nr < MAX_ROWS) {
            var cols = getColsForRow(nr);
            if (nc >= 0 && nc < cols) {
                neighbors.push({ r: nr, c: nc });
            }
        }
    }
    return neighbors;
}

function rotateCannon(delta) {
    cannonAngle += delta;
    var maxAngle = 1.25; // ~72 degrees
    if (cannonAngle < -maxAngle) cannonAngle = -maxAngle;
    if (cannonAngle > maxAngle) cannonAngle = maxAngle;
}

function setCannonAngleFromMouse(mx, my) {
    var dx = mx - cannonX;
    var dy = my - cannonY;
    if (dy >= -10) dy = -10; // Prevent aiming downward
    var angle = Math.atan2(dx, -dy);
    var maxAngle = 1.25;
    if (angle < -maxAngle) angle = -maxAngle;
    if (angle > maxAngle) angle = maxAngle;
    cannonAngle = angle;
}

function fireProjectile(callbacks) {
    if (projectile !== null || gameState !== "playing") return;

    var speed = 14;
    projectile = {
        x: cannonX,
        y: cannonY,
        vx: Math.sin(cannonAngle) * speed,
        vy: -Math.cos(cannonAngle) * speed,
        color: currentOrbColor,
        radius: bubbleRadius
    };

    currentOrbColor = nextOrbColor;
    nextOrbColor = getRandomActiveColor();

    if (callbacks && callbacks.onSound) {
        callbacks.onSound("push");
    }
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
        if (pt.life <= 0) particles.splice(p, 1);
    }

    // Update Falling Detached Orbs
    for (var f = fallingOrbs.length - 1; f >= 0; f--) {
        var fo = fallingOrbs[f];
        fo.vy += 0.6; // Gravity
        fo.x += fo.vx;
        fo.y += fo.vy;
        if (fo.y > boardHeight + bubbleRadius * 2) {
            fallingOrbs.splice(f, 1);
        }
    }

    if (gameState === "cleared") {
        clearTimer++;
        if (clearTimer % 6 === 0) {
            var randX = Math.random() * boardWidth;
            var randY = Math.random() * (boardHeight * 0.5);
            var randCol = Math.floor(Math.random() * 5) + 1;
            spawnBurstParticles(randX, randY, randCol);
        }
        if (clearTimer >= 85) {
            startNextLevel(callbacks);
        }
        return;
    }

    // Update Projectile
    if (projectile) {
        projectile.x += projectile.vx;
        projectile.y += projectile.vy;

        // Bounce off left / right walls
        if (projectile.x - projectile.radius <= 0) {
            projectile.x = projectile.radius;
            projectile.vx = -projectile.vx;
            if (callbacks && callbacks.onSound) callbacks.onSound("step");
        } else if (projectile.x + projectile.radius >= boardWidth) {
            projectile.x = boardWidth - projectile.radius;
            projectile.vx = -projectile.vx;
            if (callbacks && callbacks.onSound) callbacks.onSound("step");
        }

        // Ceiling collision
        if (projectile.y - projectile.radius <= 0) {
            snapProjectileToGrid(callbacks);
            return;
        }

        // Check collision with existing bubbles
        var collided = false;
        var minDist = bubbleRadius * 1.85;
        var minDistSq = minDist * minDist;

        for (var r = 0; r < MAX_ROWS; r++) {
            var cols = getColsForRow(r);
            for (var c = 0; c < cols; c++) {
                if (grid[r] && grid[r][c]) {
                    var pos = getCellPos(r, c);
                    var dx = projectile.x - pos.x;
                    var dy = projectile.y - pos.y;
                    if (dx * dx + dy * dy < minDistSq) {
                        collided = true;
                        break;
                    }
                }
            }
            if (collided) break;
        }

        if (collided) {
            snapProjectileToGrid(callbacks);
        }
    }
}

function snapProjectileToGrid(callbacks) {
    // Find closest empty cell
    var bestR = -1;
    var bestC = -1;
    var bestDistSq = Infinity;

    for (var r = 0; r < MAX_ROWS; r++) {
        var cols = getColsForRow(r);
        for (var c = 0; c < cols; c++) {
            if (!grid[r][c]) {
                var pos = getCellPos(r, c);
                var dx = projectile.x - pos.x;
                var dy = projectile.y - pos.y;
                var distSq = dx * dx + dy * dy;

                if (distSq < bestDistSq) {
                    // Check if adjacent to ceiling or an existing bubble
                    if (r === 0 || hasActiveNeighbor(r, c)) {
                        bestDistSq = distSq;
                        bestR = r;
                        bestC = c;
                    }
                }
            }
        }
    }

    if (bestR !== -1 && bestC !== -1) {
        grid[bestR][bestC] = {
            id: nextId++,
            color: projectile.color
        };

        var popped = checkMatchAndPop(bestR, bestC, callbacks);
        if (!popped) {
            misses++;
            if (callbacks && callbacks.onSound) callbacks.onSound("dock");
            if (misses >= maxMisses) {
                descendCeiling(callbacks);
                misses = 0;
            }
        }

        // Check Game Over
        checkGameOver(callbacks);
    }

    projectile = null;
}

function hasActiveNeighbor(r, c) {
    var n = getNeighbors(r, c);
    for (var i = 0; i < n.length; i++) {
        if (grid[n[i].r] && grid[n[i].r][n[i].c]) return true;
    }
    return false;
}

function checkMatchAndPop(startR, startC, callbacks) {
    var targetColor = grid[startR][startC].color;
    var matched = [];
    var visited = {};
    var queue = [{ r: startR, c: startC }];
    visited[startR + "," + startC] = true;

    while (queue.length > 0) {
        var curr = queue.shift();
        matched.push(curr);

        var n = getNeighbors(curr.r, curr.c);
        for (var i = 0; i < n.length; i++) {
            var key = n[i].r + "," + n[i].c;
            if (!visited[key] && grid[n[i].r] && grid[n[i].r][n[i].c]) {
                if (grid[n[i].r][n[i].c].color === targetColor) {
                    visited[key] = true;
                    queue.push(n[i]);
                }
            }
        }
    }

    if (matched.length >= 3) {
        // Pop matching cluster
        for (var m = 0; m < matched.length; m++) {
            var pr = matched[m].r;
            var pc = matched[m].c;
            var pPos = getCellPos(pr, pc);
            spawnBurstParticles(pPos.x, pPos.y, targetColor);
            grid[pr][pc] = null;
        }

        var pts = matched.length * 30;
        score += pts;

        // Detect disconnected floating orphans
        dropOrphans(callbacks);

        if (callbacks) {
            if (callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            if (callbacks.onSound) callbacks.onSound("win");
        }
        return true;
    }
    return false;
}

function dropOrphans(callbacks) {
    // Flood fill from ceiling (row 0)
    var anchored = {};
    var queue = [];

    var topCols = getColsForRow(0);
    for (var c = 0; c < topCols; c++) {
        if (grid[0] && grid[0][c]) {
            anchored["0," + c] = true;
            queue.push({ r: 0, c: c });
        }
    }

    while (queue.length > 0) {
        var curr = queue.shift();
        var n = getNeighbors(curr.r, curr.c);
        for (var i = 0; i < n.length; i++) {
            var key = n[i].r + "," + n[i].c;
            if (!anchored[key] && grid[n[i].r] && grid[n[i].r][n[i].c]) {
                anchored[key] = true;
                queue.push(n[i]);
            }
        }
    }

    // Any bubble not anchored is an orphan
    var orphanCount = 0;
    for (var r = 0; r < MAX_ROWS; r++) {
        var cols = getColsForRow(r);
        for (var oc = 0; oc < cols; oc++) {
            if (grid[r] && grid[r][oc] && !anchored[r + "," + oc]) {
                var oPos = getCellPos(r, oc);
                fallingOrbs.push({
                    x: oPos.x,
                    y: oPos.y,
                    vx: (Math.random() - 0.5) * 4,
                    vy: -(1 + Math.random() * 2),
                    color: grid[r][oc].color,
                    radius: bubbleRadius
                });
                grid[r][oc] = null;
                orphanCount++;
            }
        }
    }

    if (orphanCount > 0) {
        var bonus = orphanCount * 100;
        score += bonus;
        if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
        if (callbacks && callbacks.onOrphansDropped) callbacks.onOrphansDropped(orphanCount);
    }
}

function descendCeiling(callbacks) {
    // Alternate topRowParity so existing rows preserve their physical x-offset and neighbor graph
    topRowParity = (topRowParity === 0) ? 1 : 0;
    var newTopCols = getColsForRow(0);

    // Shift all rows down by 1 in the grid array
    for (var r = MAX_ROWS - 1; r > 0; r--) {
        grid[r] = grid[r - 1];
    }

    // New random row 0 with exact column count
    grid[0] = [];
    for (var c = 0; c < newTopCols; c++) {
        grid[0][c] = {
            id: nextId++,
            color: getRandomActiveColor()
        };
    }

    if (callbacks && callbacks.onCeilingDescended) {
        callbacks.onCeilingDescended();
    }
}

function checkGameOver(callbacks) {
    // Check if any bubble has reached DANGER_ROW or below
    for (var r = DANGER_ROW; r < MAX_ROWS; r++) {
        var cols = getColsForRow(r);
        for (var c = 0; c < cols; c++) {
            if (grid[r] && grid[r][c]) {
                gameState = "gameover";
                if (callbacks && callbacks.onGameOver) callbacks.onGameOver(score);
                if (callbacks && callbacks.onSound) callbacks.onSound("game_over");
                return;
            }
        }
    }

    // Check if board completely cleared
    var anyRemaining = false;
    for (var gr = 0; gr < MAX_ROWS; gr++) {
        var gcols = getColsForRow(gr);
        for (var gc = 0; gc < gcols; gc++) {
            if (grid[gr] && grid[gr][gc]) {
                anyRemaining = true;
                break;
            }
        }
        if (anyRemaining) break;
    }

    if (!anyRemaining) {
        gameState = "cleared";
        clearTimer = 0;
        var clearBonus = 1000 + level * 500;
        score += clearBonus;
        if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
        if (callbacks && callbacks.onSound) callbacks.onSound("win");
        if (callbacks && callbacks.onLevelCleared) callbacks.onLevelCleared(level, clearBonus);
    }
}

function spawnBurstParticles(x, y, colorIdx) {
    var colors = ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7"];
    var col = colors[(colorIdx - 1) % colors.length] || "#cdd6f4";

    for (var i = 0; i < 14; i++) {
        var angle = Math.random() * Math.PI * 2;
        var speed = 1.5 + Math.random() * 3.5;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1.0,
            decay: 0.04 + Math.random() * 0.03,
            scale: 0.22,
            color: col
        });
    }
}

function getTrajectoryPoints() {
    var points = [];
    var x = cannonX;
    var y = cannonY;
    var vx = Math.sin(cannonAngle) * 10;
    var vy = -Math.cos(cannonAngle) * 10;

    points.push({ x: x, y: y });

    for (var step = 0; step < 60; step++) {
        x += vx;
        y += vy;

        // Bounce check
        if (x <= bubbleRadius) {
            x = bubbleRadius;
            vx = -vx;
            points.push({ x: x, y: y });
        } else if (x >= boardWidth - bubbleRadius) {
            x = boardWidth - bubbleRadius;
            vx = -vx;
            points.push({ x: x, y: y });
        }

        if (y <= bubbleRadius) {
            points.push({ x: x, y: y });
            break;
        }

        if (step % 4 === 0) {
            points.push({ x: x, y: y });
        }
    }
    return points;
}

init(360, 500);

