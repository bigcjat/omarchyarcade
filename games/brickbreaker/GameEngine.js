// BrickBash - Retro Modern Breakout Engine

.pragma library

var COURT_W = 600;
var COURT_H = 750;

var gameState = "ready"; // "ready", "playing", "paused", "gameover", "cleared"
var score = 0;
var lives = 3;
var level = 1;

// Paddle
var paddle = {
    x: 250,
    y: 700,
    w: 100,
    baseW: 100,
    h: 14,
    vx: 0,
    speed: 550,
    hasLaser: false,
    laserTimer: 0,
    isSticky: false
};

// Balls
var balls = [];
var baseBallSpeed = 420;

// Bricks
var bricks = []; // array of { x, y, w, h, hits, maxHits, colorIdx, active }
var powerups = []; // array of { x, y, type, vy, active }
var lasers = []; // array of { x, y, vy, active }
var particles = []; // array of { x, y, vx, vy, life, maxLife, color }

var BRICK_ROWS = 6;
var BRICK_COLS = 8;

function init(lvl) {
    if (lvl) level = lvl;
    else {
        level = 1;
        score = 0;
        lives = 3;
    }
    gameState = "ready";
    paddle.w = paddle.baseW;
    paddle.x = (COURT_W - paddle.w) / 2;
    paddle.y = COURT_H - 45;
    paddle.hasLaser = false;
    paddle.laserTimer = 0;
    paddle.isSticky = false;

    balls = [];
    resetBall();

    powerups = [];
    lasers = [];
    particles = [];

    createBricks();
}

function resetBall() {
    balls = [{
        x: paddle.x + paddle.w / 2,
        y: paddle.y - 9,
        r: 8,
        vx: 0,
        vy: 0,
        speed: baseBallSpeed + (level - 1) * 35,
        stuck: true
    }];
}

function launchBall() {
    for (var i = 0; i < balls.length; i++) {
        if (balls[i].stuck) {
            balls[i].stuck = false;
            var angle = -Math.PI / 2 + (Math.random() * 0.5 - 0.25);
            balls[i].vx = Math.cos(angle) * balls[i].speed;
            balls[i].vy = Math.sin(angle) * balls[i].speed;
        }
    }
    gameState = "playing";
}

function createBricks() {
    bricks = [];
    var pad = 6;
    var topMargin = 75;
    var sideMargin = 20;
    var bw = (COURT_W - sideMargin * 2 - (BRICK_COLS - 1) * pad) / BRICK_COLS;
    var bh = 20;

    for (var r = 0; r < BRICK_ROWS; r++) {
        var hits = (r === 0 && level > 1) ? 2 : 1;
        for (var c = 0; c < BRICK_COLS; c++) {
            var bx = sideMargin + c * (bw + pad);
            var by = topMargin + r * (bh + pad);
            bricks.push({
                x: bx,
                y: by,
                w: bw,
                h: bh,
                hits: hits,
                maxHits: hits,
                colorIdx: r % 6,
                active: true
            });
        }
    }
}

function spawnPowerup(x, y) {
    if (Math.random() > 0.24) return; // 24% drop rate
    var types = ["wide", "multiball", "laser", "slow", "life"];
    var t = types[Math.floor(Math.random() * types.length)];
    powerups.push({
        x: x,
        y: y,
        w: 26,
        h: 14,
        type: t,
        vy: 160,
        active: true
    });
}

function spawnParticles(x, y, color) {
    for (var i = 0; i < 8; i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 60 + Math.random() * 120;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd,
            life: 0.35 + Math.random() * 0.25,
            maxLife: 0.6,
            color: color
        });
    }
}

function fireLaser() {
    if (!paddle.hasLaser || gameState !== "playing") return;
    lasers.push({ x: paddle.x + 12, y: paddle.y - 4, vy: -650, active: true });
    lasers.push({ x: paddle.x + paddle.w - 12, y: paddle.y - 4, vy: -650, active: true });
    return { event: "laser" };
}

function update(dt) {
    if (gameState !== "playing" && gameState !== "ready") return null;

    var events = [];

    // Laser timer countdown
    if (paddle.hasLaser) {
        paddle.laserTimer -= dt;
        if (paddle.laserTimer <= 0) {
            paddle.hasLaser = false;
        }
    }

    // Move paddle
    paddle.x += paddle.vx * dt;
    paddle.x = Math.max(10, Math.min(COURT_W - paddle.w - 10, paddle.x));

    // Handle stuck balls
    for (var i = 0; i < balls.length; i++) {
        if (balls[i].stuck) {
            balls[i].x = paddle.x + paddle.w / 2;
            balls[i].y = paddle.y - balls[i].r - 1;
        }
    }

    if (gameState !== "playing") return events;

    // Update Lasers
    for (var l = lasers.length - 1; l >= 0; l--) {
        var laz = lasers[l];
        laz.y += laz.vy * dt;
        if (laz.y < 0) {
            lasers.splice(l, 1);
            continue;
        }

        // Check laser collision with bricks
        for (var b = 0; b < bricks.length; b++) {
            var brk = bricks[b];
            if (!brk.active) continue;
            if (laz.x >= brk.x && laz.x <= brk.x + brk.w &&
                laz.y >= brk.y && laz.y <= brk.y + brk.h) {
                laz.active = false;
                brk.hits--;
                if (brk.hits <= 0) {
                    brk.active = false;
                    score += 100 * level;
                    spawnPowerup(brk.x + brk.w / 2, brk.y + brk.h / 2);
                    spawnParticles(brk.x + brk.w / 2, brk.y + brk.h / 2, brk.colorIdx);
                }
                events.push({ type: "brick" });
                break;
            }
        }
        if (!laz.active) lasers.splice(l, 1);
    }

    // Update Powerups
    for (var p = powerups.length - 1; p >= 0; p--) {
        var pup = powerups[p];
        pup.y += pup.vy * dt;

        // Catch with paddle
        if (pup.y + pup.h >= paddle.y && pup.y <= paddle.y + paddle.h &&
            pup.x + pup.w >= paddle.x && pup.x <= paddle.x + paddle.w) {
            applyPowerup(pup.type);
            events.push({ type: "powerup" });
            powerups.splice(p, 1);
            continue;
        }

        if (pup.y > COURT_H) {
            powerups.splice(p, 1);
        }
    }

    // Update Particles
    for (var pt = particles.length - 1; pt >= 0; pt--) {
        var part = particles[pt];
        part.x += part.vx * dt;
        part.y += part.vy * dt;
        part.life -= dt;
        if (part.life <= 0) {
            particles.splice(pt, 1);
        }
    }

    // Update Balls
    var activeBalls = 0;
    for (var i = balls.length - 1; i >= 0; i--) {
        var ball = balls[i];
        if (ball.stuck) {
            activeBalls++;
            continue;
        }

        ball.x += ball.vx * dt;
        ball.y += ball.vy * dt;

        // Left / Right walls
        if (ball.x - ball.r <= 10) {
            ball.x = 10 + ball.r;
            ball.vx = Math.abs(ball.vx);
            events.push({ type: "paddle" });
        } else if (ball.x + ball.r >= COURT_W - 10) {
            ball.x = COURT_W - 10 - ball.r;
            ball.vx = -Math.abs(ball.vx);
            events.push({ type: "paddle" });
        }

        // Top wall
        if (ball.y - ball.r <= 10) {
            ball.y = 10 + ball.r;
            ball.vy = Math.abs(ball.vy);
            events.push({ type: "paddle" });
        }

        // Paddle collision
        if (ball.vy > 0 &&
            ball.y + ball.r >= paddle.y &&
            ball.y - ball.r <= paddle.y + paddle.h &&
            ball.x + ball.r >= paddle.x &&
            ball.x - ball.r <= paddle.x + paddle.w) {

            // Deflection angle based on where it hits paddle (-1 to 1)
            var hitOffset = ((ball.x - paddle.x) / paddle.w - 0.5) * 2;
            var maxBounceAngle = Math.PI * 0.40; // 72 degrees
            var bounceAngle = hitOffset * maxBounceAngle - Math.PI / 2;

            ball.vx = Math.cos(bounceAngle) * ball.speed;
            ball.vy = Math.sin(bounceAngle) * ball.speed;
            ball.y = paddle.y - ball.r - 1;
            events.push({ type: "paddle" });
        }

        // Brick collision
        for (var b = 0; b < bricks.length; b++) {
            var brk = bricks[b];
            if (!brk.active) continue;

            // Simple AABB vs circle collision
            var testX = Math.max(brk.x, Math.min(ball.x, brk.x + brk.w));
            var testY = Math.max(brk.y, Math.min(ball.y, brk.y + brk.h));
            var distX = ball.x - testX;
            var distY = ball.y - testY;

            if (distX * distX + distY * distY <= ball.r * ball.r) {
                // Determine bounce axis
                var prevX = ball.x - ball.vx * dt;
                var prevY = ball.y - ball.vy * dt;

                if (prevX < brk.x || prevX > brk.x + brk.w) {
                    ball.vx = -ball.vx;
                } else {
                    ball.vy = -ball.vy;
                }

                brk.hits--;
                if (brk.hits <= 0) {
                    brk.active = false;
                    score += 100 * level;
                    spawnPowerup(brk.x + brk.w / 2, brk.y + brk.h / 2);
                    spawnParticles(brk.x + brk.w / 2, brk.y + brk.h / 2, brk.colorIdx);
                }
                events.push({ type: "brick" });
                break;
            }
        }

        // Bottom pit (lost ball)
        if (ball.y - ball.r > COURT_H) {
            balls.splice(i, 1);
        } else {
            activeBalls++;
        }
    }

    // Check if lost all balls
    if (activeBalls === 0) {
        lives--;
        events.push({ type: "lose_life" });
        if (lives <= 0) {
            gameState = "gameover";
            events.push({ type: "gameover" });
        } else {
            gameState = "ready";
            resetBall();
        }
    }

    // Check level clear
    var remainingBricks = 0;
    for (var b = 0; b < bricks.length; b++) {
        if (bricks[b].active) remainingBricks++;
    }
    if (remainingBricks === 0) {
        score += 1000 * level;
        level++;
        init(level);
        events.push({ type: "cleared" });
    }

    return events;
}

function applyPowerup(type) {
    if (type === "wide") {
        paddle.w = Math.min(COURT_W * 0.38, paddle.w + 40);
    } else if (type === "multiball") {
        if (balls.length > 0) {
            var src = balls[0];
            for (var k = 0; k < 2; k++) {
                var angle = (Math.random() * Math.PI) - Math.PI;
                balls.push({
                    x: src.x,
                    y: src.y,
                    r: src.r,
                    vx: Math.cos(angle) * src.speed,
                    vy: Math.sin(angle) * src.speed,
                    speed: src.speed,
                    stuck: false
                });
            }
        }
    } else if (type === "laser") {
        paddle.hasLaser = true;
        paddle.laserTimer = 12.0;
    } else if (type === "slow") {
        for (var i = 0; i < balls.length; i++) {
            balls[i].speed = Math.max(300, balls[i].speed * 0.75);
        }
    } else if (type === "life") {
        lives = Math.min(5, lives + 1);
    }
}
