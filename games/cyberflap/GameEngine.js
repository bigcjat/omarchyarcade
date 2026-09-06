.pragma library

// Canonical Flappy Bird coordinate space: 288 x 512
var V_WIDTH = 288;
var V_HEIGHT = 512;
var GROUND_HEIGHT = 80;
var PLAY_HEIGHT = V_HEIGHT - GROUND_HEIGHT; // 432

var PIPE_WIDTH = 52;
var PIPE_GAP = 100;
var PIPE_DISTANCE = 176;
var PIPE_SPEED = 2.0;
var GRAVITY = 0.25;
var JUMP_IMPULSE = -4.6;

var bird = null;
var pipes = [];
var particles = [];
var groundScroll = 0;
var score = 0;
var highScore = 0;
var gameState = "ready"; // "ready", "playing", "gameover"
var wingPhase = 0;

function setDimensions(w, h) {
    if (h > 0 && w > 0) {
        V_HEIGHT = 512;
        GROUND_HEIGHT = 80;
        PLAY_HEIGHT = 432;
        V_WIDTH = Math.max(288, Math.round(512 * (w / h)));
    }
}

function init(w, h) {
    setDimensions(w, h);
    resetGame();
}

function resetGame() {
    score = 0;
    gameState = "ready";
    pipes = [];
    particles = [];
    groundScroll = 0;
    wingPhase = 0;

    bird = {
        x: Math.max(72, Math.min(120, Math.round(V_WIDTH * 0.2))),
        y: PLAY_HEIGHT * 0.45,
        vy: 0,
        radius: 13,
        angle: 0
    };
}

function flap(callbacks) {
    if (gameState === "ready") {
        gameState = "playing";
        spawnInitialPipes();
    }
    if (gameState !== "playing") return;

    // Reset vertical velocity directly to jump impulse (authentic Flappy physics)
    bird.vy = JUMP_IMPULSE;
    bird.angle = -0.35; // -20 degrees upward tilt
    wingPhase = 0;

    if (callbacks && callbacks.onSound) callbacks.onSound("flap");
}

function spawnInitialPipes() {
    pipes = [];
    var startX = bird.x + 220;
    while (startX < V_WIDTH + PIPE_DISTANCE) {
        spawnPipeAt(startX);
        startX += PIPE_DISTANCE;
    }
}

function spawnPipeAt(xPos) {
    var minTop = 40;
    var maxTop = PLAY_HEIGHT - PIPE_GAP - minTop;
    var topH = Math.floor(minTop + Math.random() * (maxTop - minTop));

    pipes.push({
        x: xPos,
        width: PIPE_WIDTH,
        topHeight: topH,
        bottomY: topH + PIPE_GAP,
        bottomHeight: PLAY_HEIGHT - (topH + PIPE_GAP),
        passed: false
    });
}

function update(callbacks) {
    // Animate ground scrolling at the exact same physical rate as pipes
    if (gameState !== "gameover") {
        groundScroll += PIPE_SPEED;
    }

    if (gameState === "ready") {
        // Idle gentle floating bob
        bird.y = PLAY_HEIGHT * 0.45 + Math.sin(Date.now() * 0.006) * 6;
        bird.angle = 0;
        wingPhase = Math.sin(Date.now() * 0.015) * 5;
        return;
    }

    if (gameState !== "playing") return;

    // Bird gravity & terminal velocity
    bird.vy += GRAVITY;
    if (bird.vy > 8.0) bird.vy = 8.0;
    bird.y += bird.vy;

    // Smooth nose rotation
    if (bird.vy < 0) {
        bird.angle = Math.max(-0.4, bird.angle - 0.05);
        wingPhase = Math.sin(Date.now() * 0.02) * 5;
    } else if (bird.vy > 1.2) {
        // After apex, smoothly tilt down into steep dive
        bird.angle = Math.min(1.57, bird.angle + 0.07);
        wingPhase = 0;
    }

    // Ceiling clamp
    if (bird.y - bird.radius <= 0) {
        bird.y = bird.radius;
        bird.vy = 0;
    }

    // Ground collision
    if (bird.y + bird.radius >= PLAY_HEIGHT) {
        bird.y = PLAY_HEIGHT - bird.radius;
        triggerGameOver(callbacks);
        return;
    }

    // Scroll pipes & manage fixed 176px spacing
    var lastPipeX = 0;
    for (var i = 0; i < pipes.length; i++) {
        if (pipes[i].x > lastPipeX) lastPipeX = pipes[i].x;
    }

    while (lastPipeX < V_WIDTH + PIPE_DISTANCE) {
        spawnPipeAt(lastPipeX + PIPE_DISTANCE);
        lastPipeX += PIPE_DISTANCE;
    }

    for (var pIdx = pipes.length - 1; pIdx >= 0; pIdx--) {
        var p = pipes[pIdx];
        p.x -= PIPE_SPEED;

        // Scoring check
        if (!p.passed && p.x + p.width < bird.x) {
            p.passed = true;
            score++;
            if (score > highScore) highScore = score;
            if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            if (callbacks && callbacks.onSound) callbacks.onSound("point");
        }

        // Collision check AABB vs circle
        var birdLeft = bird.x - bird.radius + 2;
        var birdRight = bird.x + bird.radius - 2;
        var birdTop = bird.y - bird.radius + 2;
        var birdBottom = bird.y + bird.radius - 2;

        if (birdRight > p.x && birdLeft < p.x + p.width) {
            // Hit top pipe or bottom pipe
            if (birdTop < p.topHeight || birdBottom > p.bottomY) {
                triggerGameOver(callbacks);
                return;
            }
        }

        // Despawn off-screen pipes
        if (p.x + p.width < -40) {
            pipes.splice(pIdx, 1);
        }
    }
}

function triggerGameOver(callbacks) {
    gameState = "gameover";
    // Explosion particles
    for (var ep = 0; ep < 20; ep++) {
        var ang = Math.random() * Math.PI * 2;
        var spd = 1.0 + Math.random() * 3.5;
        particles.push({
            x: bird.x,
            y: bird.y,
            vx: Math.cos(ang) * spd,
            vy: Math.sin(ang) * spd,
            life: 25,
            maxLife: 25
        });
    }
    if (callbacks && callbacks.onSound) {
        callbacks.onSound("hit");
        callbacks.onSound("die");
    }
    if (callbacks && callbacks.onGameOver) callbacks.onGameOver(score);
}
