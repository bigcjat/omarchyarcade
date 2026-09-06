// Omarchy Arcade • Master Game Engine Template
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

// Virtual coordinate space or grid dimensions
var width = 480;
var height = 480;

// Game State
var gameState = "ready"; // "ready", "playing", "gameover", "won"
var score = 0;
var highScore = 0;
var level = 1;

// Custom Game Entities / Data
var entities = [];
var particles = [];

/**
 * Initialize game world with dimensions.
 */
function init(w, h) {
    width = w;
    height = h;
    resetGame();
}

/**
 * Handle window / viewport resize.
 */
function resize(w, h) {
    width = w;
    height = h;
}

/**
 * Reset game state for a new round.
 */
function resetGame() {
    gameState = "playing";
    score = 0;
    entities = [];
    particles = [];
}

/**
 * Frame update loop (~60 FPS).
 * @param {number} dt Delta time in seconds (~0.016)
 * @param {object} callbacks Callback handlers: { onSound(name), onScore(pts), onGameOver() }
 */
function update(dt, callbacks) {
    if (gameState !== "playing") return;

    // 1. Update entities / physics here

    // 2. Update particle effects
    for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.life -= dt;
        if (p.life <= 0) {
            particles.splice(i, 1);
        }
    }
}

/**
 * Handle directional input or action triggers.
 * @param {string} action "up", "down", "left", "right", "action", etc.
 * @param {object} callbacks
 */
function handleInput(action, callbacks) {
    if (gameState === "ready") {
        gameState = "playing";
    }
    if (gameState !== "playing") return;

    // Example sound trigger
    if (callbacks && callbacks.onSound) {
        callbacks.onSound("move");
    }
}
