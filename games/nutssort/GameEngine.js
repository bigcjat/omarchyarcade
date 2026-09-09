// Omarchy Arcade • Nuts Sort Game Engine
// Pure JavaScript logic module
.pragma library

var NUT_COLORS = {
    "red":    { id: "red",    name: "Ruby Red",      hex: "#EF4444", top: "#F87171", shadow: "#B91C1C", rim: "#FECACA", shine: "#FCA5A5" },
    "blue":   { id: "blue",   name: "Cobalt Blue",   hex: "#3B82F6", top: "#60A5FA", shadow: "#1D4ED8", rim: "#BFDBFE", shine: "#93C5FD" },
    "yellow": { id: "yellow", name: "Amber Gold",    hex: "#F59E0B", top: "#FBBF24", shadow: "#B45309", rim: "#FEF3C7", shine: "#FDE68A" },
    "green":  { id: "green",  name: "Emerald Green", hex: "#10B981", top: "#34D399", shadow: "#047857", rim: "#A7F3D0", shine: "#6EE7B7" },
    "purple": { id: "purple", name: "Amethyst Violet",hex: "#8B5CF6", top: "#A78BFA", shadow: "#6D28D9", rim: "#DDD6FE", shine: "#C4B5FD" },
    "cyan":   { id: "cyan",   name: "Neon Cyan",     hex: "#06B6D4", top: "#22D3EE", shadow: "#0E7490", rim: "#CFFAFE", shine: "#67E8F9" },
    "orange": { id: "orange", name: "Tangerine",     hex: "#F97316", top: "#FB923C", shadow: "#C2410C", rim: "#FFEDD5", shine: "#FDBA74" },
    "pink":   { id: "pink",   name: "Hot Magenta",   hex: "#EC4899", top: "#F472B6", shadow: "#BE185D", rim: "#FCE7F3", shine: "#F472B6" },
    "silver": { id: "silver", name: "Steel Gray",    hex: "#94A3B8", top: "#CBD5E1", shadow: "#475569", rim: "#F1F5F9", shine: "#E2E8F0" },
    "lime":   { id: "lime",   name: "Acid Lime",     hex: "#84CC16", top: "#A3E635", shadow: "#4D7C0F", rim: "#ECFCCB", shine: "#BEF264" }
};

var MAX_CAPACITY = 4;

// Board State
var bolts = []; // array of arrays of color string IDs
var currentLevel = 1;
var totalLevels = 40;
var moves = 0;
var undoStack = [];
var gameState = "ready"; // "ready", "playing", "animating", "won"
var selectedBolt = -1; // index of bolt currently selected (-1 if none)
var cursorIndex = 0; // keyboard navigation cursor
var justCompletedBolts = []; // indices of bolts completed on last move

// Active Moving Nut Animation
var movingNut = null; 

// Particles
var particles = [];

// Hand-Crafted Introductory Tutorial Levels (Levels 1 & 2)
var TUTORIAL_LEVELS = [
    // Level 1: 3 bolts, 2 colors (1 empty) - simple 3-move tutorial
    [
        ["blue", "blue", "blue", "red"],
        ["red", "red", "red", "blue"],
        []
    ],
    // Level 2: 4 bolts, 2 colors (2 empty) - gentle warmup
    [
        ["blue", "red", "blue", "red"],
        ["red", "blue", "red", "blue"],
        [],
        []
    ]
];

var isCurrentLevelChallenge = false;
var difficulty = "normal"; // "casual", "normal", "hard"
var isDeadlocked = false;

/**
 * Set and apply difficulty mode ("casual", "normal", "hard").
 */
function setDifficulty(diff) {
    if (diff === "casual" || diff === "normal" || diff === "hard") {
        difficulty = diff;
        loadLevel(currentLevel);
    }
}

/**
 * Deterministic pseudo-random number generator (Mulberry32).
 */
function makePRNG(seed) {
    var s = (seed | 0) + 1234567;
    return function() {
        s = Math.imul(s ^ (s >>> 15), 1 | s);
        s = (s + Math.imul(s ^ (s >>> 7), 61 | s)) ^ s;
        return ((s ^ (s >>> 14)) >>> 0) / 4294967296;
    };
}

/**
 * Level progression rules calibrated for smooth, fair difficulty with difficulty modes.
 */
function getLevelParameters(lvl) {
    // 1. Smooth, progressive color ramp
    var numColors;
    if (lvl <= 2) {
        numColors = 2;
    } else if (lvl <= 5) {
        numColors = 3;
    } else if (lvl <= 10) {
        numColors = 4;
    } else if (lvl <= 18) {
        numColors = 5;
    } else if (lvl <= 28) {
        numColors = 6;
    } else if (lvl <= 40) {
        numColors = 7;
    } else {
        numColors = Math.min(8, 5 + Math.floor((lvl - 20) / 10));
    }

    var numEmpty = 2;
    var isChallenge = false;

    if (difficulty === "casual") {
        // Casual: Generous buffer, 3 empty bolts on larger boards, zero stress
        numEmpty = (numColors >= 5) ? 3 : 2;
        isChallenge = false;
    } else if (difficulty === "hard") {
        // Hard: Tight Squeeze 1-buffer challenge from level 3 onwards
        if (lvl > 2) {
            numEmpty = 1;
            isChallenge = true;
        } else {
            numEmpty = 2;
            isChallenge = false;
        }
    } else {
        // Normal: Gentle intro (levels 1-9 have 2 empty bolts), milestone challenges every 10th level
        if (lvl >= 10 && (lvl % 10 === 0)) {
            numEmpty = 1;
            isChallenge = true;
        } else {
            numEmpty = 2;
            isChallenge = false;
        }
    }

    return { numColors: numColors, numEmpty: numEmpty, isChallenge: isChallenge };
}

/**
 * Generate a procedural solvable level using authentic reverse-legal moves.
 * Guarantees 100% mathematical solvability from the solved state.
 */
function generateSolvableLevel(numColors, numEmpty, seed) {
    var prng = makePRNG(seed || 42);
    var paletteKeys = ["red", "blue", "yellow", "green", "purple", "cyan", "orange", "pink", "lime", "silver"];
    var colors = paletteKeys.slice(0, Math.min(paletteKeys.length, numColors));
    var numBolts = numColors + numEmpty;

    // Start with fully solved stacks
    var state = [];
    for (var i = 0; i < numColors; i++) {
        var c = colors[i];
        state.push([c, c, c, c]);
    }
    for (var e = 0; e < numEmpty; e++) {
        state.push([]);
    }

    // Scramble backward using authentic reverse-legal moves
    // In reverse, taking nut X off bolt B and putting onto bolt A is legal IF AND ONLY IF:
    // in forward play, X could legally land on B (i.e. B has length 1 or B[-1] == B[-2]).
    var targetSteps = Math.min(65, numColors * 8 + (numEmpty === 1 ? 12 : 16));
    var successfulSteps = 0;
    var maxAttempts = targetSteps * 20;

    for (var attempt = 0; attempt < maxAttempts && successfulSteps < targetSteps; attempt++) {
        var candidatesFrom = [];
        for (var b = 0; b < numBolts; b++) {
            var stk = state[b];
            if (stk.length === 1 || (stk.length > 1 && stk[stk.length - 1] === stk[stk.length - 2])) {
                candidatesFrom.push(b);
            }
        }
        if (candidatesFrom.length === 0) break;

        var fromB = candidatesFrom[Math.floor(prng() * candidatesFrom.length)];
        var nut = state[fromB].pop();

        var candidatesTo = [];
        for (var d = 0; d < numBolts; d++) {
            if (d !== fromB && state[d].length < MAX_CAPACITY) {
                candidatesTo.push(d);
            }
        }
        if (candidatesTo.length === 0) {
            state[fromB].push(nut);
            continue;
        }

        var toB = candidatesTo[Math.floor(prng() * candidatesTo.length)];
        state[toB].push(nut);
        successfulSteps++;
    }

    return state;
}

/**
 * Check if the board has any valid legal moves remaining.
 */
function hasAnyValidMoves() {
    if (checkWinCondition()) return true;
    for (var from = 0; from < bolts.length; from++) {
        if (bolts[from].length === 0) continue;
        if (isBoltComplete(from)) continue;

        for (var to = 0; to < bolts.length; to++) {
            if (from === to) continue;
            if (canMove(from, to)) {
                if (bolts[to].length === 0) {
                    var fromStk = bolts[from];
                    var isPure = true;
                    for (var k = 1; k < fromStk.length; k++) {
                        if (fromStk[k] !== fromStk[0]) {
                            isPure = false;
                            break;
                        }
                    }
                    if (!isPure || fromStk.length < MAX_CAPACITY) {
                        return true;
                    }
                } else {
                    return true;
                }
            }
        }
    }
    return false;
}

/**
 * Get level configuration for any level from 1 to 10,000+.
 */
function getLevelState(lvl) {
    if (lvl >= 1 && lvl <= TUTORIAL_LEVELS.length) {
        var tut = TUTORIAL_LEVELS[lvl - 1];
        var copy = [];
        for (var i = 0; i < tut.length; i++) {
            copy.push(tut[i].slice());
        }
        return copy;
    }
    var params = getLevelParameters(lvl);
    return generateSolvableLevel(params.numColors, params.numEmpty, lvl * 10007);
}

/**
 * Initialize game world.
 */
function init(w, h) {
    loadLevel(currentLevel);
}

/**
 * Load a specific level.
 */
function loadLevel(lvl) {
    currentLevel = Math.max(1, lvl);
    var params = getLevelParameters(currentLevel);
    isCurrentLevelChallenge = params.isChallenge;
    bolts = getLevelState(currentLevel);
    moves = 0;
    undoStack = [];
    selectedBolt = -1;
    cursorIndex = 0;
    movingNut = null;
    particles = [];
    justCompletedBolts = [];
    isDeadlocked = false;
    gameState = "playing";
}

/**
 * Check if a bolt is completely sorted (full capacity of matching color).
 */
function isBoltComplete(boltIdx) {
    if (boltIdx < 0 || boltIdx >= bolts.length) return false;
    var stack = bolts[boltIdx];
    if (stack.length !== MAX_CAPACITY) return false;
    var first = stack[0];
    for (var i = 1; i < stack.length; i++) {
        if (stack[i] !== first) return false;
    }
    return true;
}

/**
 * Check if the entire board is solved.
 */
function checkWinCondition() {
    for (var i = 0; i < bolts.length; i++) {
        var stack = bolts[i];
        if (stack.length === 0) continue;
        if (!isBoltComplete(i)) {
            return false;
        }
    }
    return true;
}

/**
 * Check if moving from bolt A to bolt B is legally allowed.
 */
function canMove(fromIdx, toIdx) {
    if (fromIdx === toIdx) return false;
    if (fromIdx < 0 || fromIdx >= bolts.length) return false;
    if (toIdx < 0 || toIdx >= bolts.length) return false;

    var fromStack = bolts[fromIdx];
    var toStack = bolts[toIdx];

    if (fromStack.length === 0) return false;
    if (toStack.length >= MAX_CAPACITY) return false;

    var movingColor = fromStack[fromStack.length - 1];

    if (toStack.length === 0) return true;

    var targetTopColor = toStack[toStack.length - 1];
    return targetTopColor === movingColor;
}

/**
 * Execute move from fromIdx to toIdx.
 */
function executeMove(fromIdx, toIdx, callbacks) {
    if (!canMove(fromIdx, toIdx)) {
        if (callbacks && callbacks.onSound) callbacks.onSound("error");
        return false;
    }

    var snapshot = {
        bolts: bolts.map(function(b) { return b.slice(); }),
        moves: moves,
        fromIdx: fromIdx,
        toIdx: toIdx
    };
    undoStack.push(snapshot);

    var movingColor = bolts[fromIdx].pop();
    bolts[toIdx].push(movingColor);
    moves++;

    if (isBoltComplete(toIdx)) {
        if (callbacks && callbacks.onBoltComplete) callbacks.onBoltComplete(toIdx);
        if (callbacks && callbacks.onSound) callbacks.onSound("bolt_complete");
    } else {
        if (callbacks && callbacks.onSound) callbacks.onSound("nut_drop");
    }

    if (checkWinCondition()) {
        gameState = "won";
        isDeadlocked = false;
        if (callbacks && callbacks.onDeadlockCleared) callbacks.onDeadlockCleared();
        if (callbacks && callbacks.onWin) callbacks.onWin();
        if (callbacks && callbacks.onSound) callbacks.onSound("win");
    } else {
        if (!hasAnyValidMoves()) {
            isDeadlocked = true;
            if (callbacks && callbacks.onDeadlock) callbacks.onDeadlock();
            if (callbacks && callbacks.onSound) callbacks.onSound("error");
        } else {
            if (isDeadlocked) {
                isDeadlocked = false;
                if (callbacks && callbacks.onDeadlockCleared) callbacks.onDeadlockCleared();
            }
        }
    }

    return true;
}

/**
 * Handle Bolt Selection / Tap / Click.
 */
function selectBolt(idx, callbacks) {
    if (gameState !== "playing") return;
    if (idx < 0 || idx >= bolts.length) return;

    cursorIndex = idx;

    if (selectedBolt === -1) {
        if (bolts[idx].length === 0) {
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
            return;
        }
        if (isBoltComplete(idx)) {
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
            return;
        }

        selectedBolt = idx;
        if (callbacks && callbacks.onSound) callbacks.onSound("nut_lift");
        return;
    }

    if (selectedBolt === idx) {
        selectedBolt = -1;
        if (callbacks && callbacks.onSound) callbacks.onSound("click");
        return;
    }

    var from = selectedBolt;
    var to = idx;

    if (canMove(from, to)) {
        selectedBolt = -1;
        executeMove(from, to, callbacks);
    } else {
        if (bolts[idx].length > 0 && !isBoltComplete(idx)) {
            selectedBolt = idx;
            if (callbacks && callbacks.onSound) callbacks.onSound("nut_lift");
        } else {
            selectedBolt = -1;
            if (callbacks && callbacks.onSound) callbacks.onSound("error");
        }
    }
}

/**
 * Undo last move.
 */
function undo(callbacks) {
    if (undoStack.length === 0 || gameState === "won") return false;
    var snap = undoStack.pop();
    bolts = snap.bolts;
    moves = snap.moves;
    selectedBolt = -1;
    isDeadlocked = false;
    if (callbacks && callbacks.onDeadlockCleared) callbacks.onDeadlockCleared();
    if (callbacks && callbacks.onSound) callbacks.onSound("undo");
    return true;
}

/**
 * Reset current level.
 */
function resetGame(callbacks) {
    isDeadlocked = false;
    if (callbacks && callbacks.onDeadlockCleared) callbacks.onDeadlockCleared();
    loadLevel(currentLevel);
    if (callbacks && callbacks.onSound) callbacks.onSound("click");
}

/**
 * Next Level.
 */
function nextLevel(callbacks) {
    loadLevel(currentLevel + 1);
    if (callbacks && callbacks.onSound) callbacks.onSound("select");
}

/**
 * Previous Level.
 */
function prevLevel(callbacks) {
    if (currentLevel > 1) {
        loadLevel(currentLevel - 1);
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
    }
}

/**
 * Particle system update.
 */
function update(dt, callbacks) {
    for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += p.gravity * dt;
        p.alpha -= dt * p.decay;
        p.rotation += p.vRot * dt;
        if (p.alpha <= 0) {
            particles.splice(i, 1);
        }
    }
}

/**
 * Spawn celebratory burst of sparkle particles over a completed bolt.
 */
function spawnSparkles(centerX, centerY, colorHex) {
    for (var i = 0; i < 28; i++) {
        var angle = Math.random() * Math.PI * 2;
        var speed = 80 + Math.random() * 180;
        particles.push({
            x: centerX,
            y: centerY,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed - 60,
            gravity: 140,
            color: colorHex || "#FBBF24",
            size: 3 + Math.random() * 5,
            alpha: 1.0,
            decay: 0.9 + Math.random() * 0.8,
            rotation: Math.random() * Math.PI * 2,
            vRot: (Math.random() - 0.5) * 8
        });
    }
}

/**
 * Spawn colorful celebratory confetti raining down across the playfield.
 */
function spawnConfetti(w, h) {
    var palette = ["#EF4444", "#3B82F6", "#F59E0B", "#10B981", "#8B5CF6", "#06B6D4", "#EC4899", "#F97316", "#84CC16", "#F43F5E", "#A855F7"];
    for (var i = 0; i < 90; i++) {
        var startX = Math.random() * w;
        var startY = -20 - Math.random() * 100;
        var speedX = (Math.random() - 0.5) * 160;
        var speedY = 140 + Math.random() * 240;
        particles.push({
            x: startX,
            y: startY,
            vx: speedX,
            vy: speedY,
            gravity: 160 + Math.random() * 120,
            color: palette[Math.floor(Math.random() * palette.length)],
            size: 6 + Math.random() * 6,
            alpha: 1.0,
            decay: 0.35 + Math.random() * 0.25,
            rotation: Math.random() * Math.PI * 2,
            vRot: (Math.random() - 0.5) * 10,
            isConfetti: true,
            aspectRatio: 0.4 + Math.random() * 0.4
        });
    }
}

/**
 * Handle Keyboard Navigation.
 */
function handleInput(action, callbacks) {
    if (gameState === "won") {
        if (action === "action" || action === "enter") {
            nextLevel(callbacks);
        }
        return;
    }

    var total = bolts.length;
    if (total === 0) return;

    if (action === "left") {
        cursorIndex = (cursorIndex - 1 + total) % total;
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
    } else if (action === "right") {
        cursorIndex = (cursorIndex + 1) % total;
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
    } else if (action === "up" || action === "down") {
        var half = Math.ceil(total / 2);
        if (cursorIndex < half && cursorIndex + half < total) {
            cursorIndex += half;
        } else if (cursorIndex >= half) {
            cursorIndex -= half;
        }
        if (callbacks && callbacks.onSound) callbacks.onSound("select");
    } else if (action === "action" || action === "enter") {
        selectBolt(cursorIndex, callbacks);
    } else if (action === "undo") {
        undo(callbacks);
    } else if (action === "reset") {
        resetGame(callbacks);
    }
}
