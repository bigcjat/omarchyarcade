// VoidInvaders - Retro Space Invaders Engine

.pragma library

var COURT_W = 600;
var COURT_H = 750;

var gameState = "playing"; // "playing", "paused", "gameover", "cleared"
var score = 0;
var lives = 3;
var wave = 1;

// Player Cannon
var player = {
    x: 280,
    y: 700,
    w: 36,
    h: 20,
    vx: 0,
    speed: 360,
    cooldown: 0
};

var playerBullet = null; // { x, y, vy }
var alienBullets = [];   // array of { x, y, vy }

// Invaders
var invaders = []; // array of { r, c, x, y, w, h, type, pts, alive }
var invaderDir = 1; // 1 = right, -1 = left
var invaderStepTimer = 0;
var invaderStepInterval = 0.65;
var invaderAnimFrame = 0;
var invaderDropDistance = 18;

// Mystery UFO
var ufo = null; // { x, y, vx, pts, active }
var ufoTimer = 18.0;

// Bunkers (4 shields)
var bunkers = []; // array of 4 bunkers, each has blocks grid [r][c]

// Particles
var particles = [];

function init(wLevel) {
    if (wLevel) wave = wLevel;
    else {
        wave = 1;
        score = 0;
        lives = 3;
    }
    gameState = "playing";
    player.x = (COURT_W - player.w) / 2;
    player.y = COURT_H - 45;
    player.vx = 0;
    player.cooldown = 0;
    playerBullet = null;
    alienBullets = [];
    particles = [];
    ufo = null;
    ufoTimer = 15.0 + Math.random() * 10;

    createInvaders();
    createBunkers();
}

function createInvaders() {
    invaders = [];
    var rows = 5;
    var cols = 11;
    var startX = 60;
    var startY = 85;
    var gapX = 42;
    var gapY = 36;

    for (var r = 0; r < rows; r++) {
        var type = 0; // 0 = octopus (10), 1 = crab (20), 2 = squid (30)
        var pts = 10;
        if (r === 0) { type = 2; pts = 30; }
        else if (r === 1 || r === 2) { type = 1; pts = 20; }
        else { type = 0; pts = 10; }

        for (var c = 0; c < cols; c++) {
            invaders.push({
                r: r,
                c: c,
                x: startX + c * gapX,
                y: startY + r * gapY,
                w: 28,
                h: 22,
                type: type,
                pts: pts,
                alive: true
            });
        }
    }
    invaderDir = 1;
    invaderStepTimer = 0;
    invaderStepInterval = Math.max(0.12, 0.70 - (wave - 1) * 0.08);
    invaderAnimFrame = 0;
}

function createBunkers() {
    bunkers = [];
    var count = 4;
    var bw = 54;
    var bh = 36;
    var totalW = count * bw;
    var spacing = (COURT_W - totalW) / (count + 1);
    var startY = COURT_H - 125;

    for (var i = 0; i < count; i++) {
        var bx = spacing + i * (bw + spacing);
        var grid = [];
        var rows = 4;
        var cols = 6;
        var cellW = bw / cols;
        var cellH = bh / rows;

        for (var r = 0; r < rows; r++) {
            var row = [];
            for (var c = 0; c < cols; c++) {
                // Notch cutout at bottom center
                if (r === 3 && (c === 2 || c === 3)) {
                    row.push(0);
                } else if (r === 0 && (c === 0 || c === 5)) {
                    row.push(0); // Cut corners at top
                } else {
                    row.push(3); // 3 health states
                }
            }
            grid.push(row);
        }

        bunkers.push({
            x: bx,
            y: startY,
            w: bw,
            h: bh,
            rows: rows,
            cols: cols,
            cellW: cellW,
            cellH: cellH,
            grid: grid
        });
    }
}

function shoot() {
    if (gameState !== "playing" || playerBullet !== null) return null;
    playerBullet = {
        x: player.x + player.w / 2,
        y: player.y - 6,
        vy: -750
    };
    return { event: "shoot" };
}

function spawnParticles(x, y, count) {
    for (var i = 0; i < (count || 8); i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 40 + Math.random() * 120;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd,
            life: 0.35 + Math.random() * 0.25,
            maxLife: 0.6
        });
    }
}

function update(dt) {
    if (gameState !== "playing") return null;

    var events = [];

    // Move player
    player.x += player.vx * dt;
    player.x = Math.max(16, Math.min(COURT_W - player.w - 16, player.x));

    // Update Particles
    for (var pt = particles.length - 1; pt >= 0; pt--) {
        var p = particles[pt];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt;
        if (p.life <= 0) particles.splice(pt, 1);
    }

    // Update Player Bullet
    if (playerBullet) {
        playerBullet.y += playerBullet.vy * dt;

        // Top edge
        if (playerBullet.y < 20) {
            spawnParticles(playerBullet.x, playerBullet.y, 4);
            playerBullet = null;
        } else {
            // Check collision with UFO
            if (ufo && ufo.active &&
                playerBullet.x >= ufo.x && playerBullet.x <= ufo.x + 48 &&
                playerBullet.y >= ufo.y && playerBullet.y <= ufo.y + 20) {
                score += ufo.pts;
                spawnParticles(ufo.x + 24, ufo.y + 10, 14);
                ufo = null;
                playerBullet = null;
                events.push({ type: "explode", pts: 200 });
            }
        }

        // Check collision with invaders
        if (playerBullet) {
            for (var i = 0; i < invaders.length; i++) {
                var inv = invaders[i];
                if (!inv.alive) continue;
                if (playerBullet.x >= inv.x && playerBullet.x <= inv.x + inv.w &&
                    playerBullet.y >= inv.y && playerBullet.y <= inv.y + inv.h) {
                    inv.alive = false;
                    score += inv.pts;
                    spawnParticles(inv.x + inv.w / 2, inv.y + inv.h / 2, 10);
                    playerBullet = null;
                    events.push({ type: "explode" });
                    break;
                }
            }
        }

        // Check collision with bunkers
        if (playerBullet) {
            for (var b = 0; b < bunkers.length; b++) {
                var bnk = bunkers[b];
                if (playerBullet.x >= bnk.x && playerBullet.x <= bnk.x + bnk.w &&
                    playerBullet.y >= bnk.y && playerBullet.y <= bnk.y + bnk.h) {
                    var col = Math.floor((playerBullet.x - bnk.x) / bnk.cellW);
                    var row = Math.floor((playerBullet.y - bnk.y) / bnk.cellH);
                    if (row >= 0 && row < bnk.rows && col >= 0 && col < bnk.cols && bnk.grid[row][col] > 0) {
                        bnk.grid[row][col]--;
                        spawnParticles(playerBullet.x, playerBullet.y, 3);
                        playerBullet = null;
                        break;
                    }
                }
            }
        }
    }

    // Count alive invaders
    var aliveCount = 0;
    var lowestInvaderY = 0;
    for (var i = 0; i < invaders.length; i++) {
        if (invaders[i].alive) {
            aliveCount++;
            if (invaders[i].y + invaders[i].h > lowestInvaderY) {
                lowestInvaderY = invaders[i].y + invaders[i].h;
            }
        }
    }

    // Wave cleared!
    if (aliveCount === 0) {
        wave++;
        score += 1000;
        init(wave);
        events.push({ type: "cleared" });
        return events;
    }

    // Invaders reached player level
    if (lowestInvaderY >= player.y) {
        lives = 0;
        gameState = "gameover";
        events.push({ type: "player_die" });
        events.push({ type: "gameover" });
        return events;
    }

    // Dynamic march speed
    var currentInterval = Math.max(0.06, (aliveCount / 55) * invaderStepInterval);
    invaderStepTimer += dt;
    if (invaderStepTimer >= currentInterval) {
        invaderStepTimer = 0;
        invaderAnimFrame = (invaderAnimFrame === 0) ? 1 : 0;
        events.push({ type: "invader_move" });

        // Check if any invader hit edge
        var hitEdge = false;
        for (var i = 0; i < invaders.length; i++) {
            if (!invaders[i].alive) continue;
            var nx = invaders[i].x + invaderDir * 12;
            if (nx < 16 || nx + invaders[i].w > COURT_W - 16) {
                hitEdge = true;
                break;
            }
        }

        if (hitEdge) {
            invaderDir = -invaderDir;
            for (var i = 0; i < invaders.length; i++) {
                if (invaders[i].alive) {
                    invaders[i].y += invaderDropDistance;
                }
            }
        } else {
            for (var i = 0; i < invaders.length; i++) {
                if (invaders[i].alive) {
                    invaders[i].x += invaderDir * 12;
                }
            }
        }
    }

    // Alien firing logic
    var maxAlienBullets = Math.min(5, 1 + wave);
    if (alienBullets.length < maxAlienBullets && Math.random() < (0.04 + wave * 0.015)) {
        // Pick random bottom-most alive alien in a column
        var colsAlive = {};
        for (var i = 0; i < invaders.length; i++) {
            var inv = invaders[i];
            if (inv.alive) {
                if (!colsAlive[inv.c] || inv.r > colsAlive[inv.c].r) {
                    colsAlive[inv.c] = inv;
                }
            }
        }
        var shooters = Object.values(colsAlive);
        if (shooters.length > 0) {
            var shooter = shooters[Math.floor(Math.random() * shooters.length)];
            alienBullets.push({
                x: shooter.x + shooter.w / 2,
                y: shooter.y + shooter.h + 2,
                vy: 240 + wave * 25
            });
        }
    }

    // Update Alien Bullets
    for (var ab = alienBullets.length - 1; ab >= 0; ab--) {
        var abullet = alienBullets[ab];
        abullet.y += abullet.vy * dt;

        // Player collision
        if (abullet.x >= player.x && abullet.x <= player.x + player.w &&
            abullet.y >= player.y && abullet.y <= player.y + player.h) {
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, 16);
            alienBullets.splice(ab, 1);
            lives--;
            events.push({ type: "player_die" });
            if (lives <= 0) {
                gameState = "gameover";
                events.push({ type: "gameover" });
            } else {
                player.x = (COURT_W - player.w) / 2;
            }
            continue;
        }

        // Bunker collision
        var hitBunker = false;
        for (var b = 0; b < bunkers.length; b++) {
            var bnk = bunkers[b];
            if (abullet.x >= bnk.x && abullet.x <= bnk.x + bnk.w &&
                abullet.y >= bnk.y && abullet.y <= bnk.y + bnk.h) {
                var col = Math.floor((abullet.x - bnk.x) / bnk.cellW);
                var row = Math.floor((abullet.y - bnk.y) / bnk.cellH);
                if (row >= 0 && row < bnk.rows && col >= 0 && col < bnk.cols && bnk.grid[row][col] > 0) {
                    bnk.grid[row][col]--;
                    spawnParticles(abullet.x, abullet.y, 3);
                    alienBullets.splice(ab, 1);
                    hitBunker = true;
                    break;
                }
            }
        }
        if (hitBunker) continue;

        // Bottom court edge
        if (abullet.y > COURT_H) {
            alienBullets.splice(ab, 1);
        }
    }

    // UFO logic
    if (!ufo) {
        ufoTimer -= dt;
        if (ufoTimer <= 0) {
            var fromLeft = Math.random() > 0.5;
            ufo = {
                x: fromLeft ? -50 : COURT_W + 10,
                y: 42,
                vx: fromLeft ? 140 : -140,
                pts: [100, 150, 200, 300][Math.floor(Math.random() * 4)],
                active: true
            };
            events.push({ type: "ufo" });
            ufoTimer = 22.0 + Math.random() * 15;
        }
    } else {
        ufo.x += ufo.vx * dt;
        if (ufo.x < -60 || ufo.x > COURT_W + 60) {
            ufo = null;
        }
    }

    return events;
}
