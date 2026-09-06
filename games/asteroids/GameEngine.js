.pragma library

var width = 600;
var height = 600;
var ship = null;
var asteroids = [];
var bullets = [];
var enemyBullets = [];
var particles = [];
var saucer = null;
var saucerTimer = 900; // ~15 seconds initial delay
var respawnPending = false;
var respawnTimer = 0;
var lives = 3;
var score = 0;
var nextBonusScore = 10000;
var level = 1;
var gameState = "ready"; // "ready", "playing", "gameover"
var invulnerableTimer = 0;

function init(w, h) {
    width = w;
    height = h;
    resetGame();
}

function resize(w, h) {
    width = w;
    height = h;
}

function resetGame() {
    score = 0;
    lives = 3;
    level = 1;
    nextBonusScore = 10000;
    gameState = "playing";
    bullets = [];
    enemyBullets = [];
    particles = [];
    saucer = null;
    saucerTimer = 800 + Math.floor(Math.random() * 600);
    respawnPending = false;
    respawnTimer = 0;
    resetShip();
    spawnAsteroids();
}

function resetShip() {
    ship = {
        x: width / 2,
        y: height / 2,
        vx: 0,
        vy: 0,
        angle: -Math.PI / 2,
        radius: 12,
        thrusting: false,
        rotLeft: false,
        rotRight: false
    };
    invulnerableTimer = 120; // 2 seconds at 60fps
}

function spawnAsteroids() {
    asteroids = [];
    var count = 3 + Math.min(8, level);
    for (var i = 0; i < count; i++) {
        var ax, ay;
        do {
            ax = Math.random() * width;
            ay = Math.random() * height;
        } while (Math.hypot(ax - width / 2, ay - height / 2) < 130);

        var speed = (0.75 + Math.random() * 0.75) * (1.0 + level * 0.08);
        var dir = Math.random() * Math.PI * 2;
        asteroids.push(createAsteroid(ax, ay, speed * Math.cos(dir), speed * Math.sin(dir), 3));
    }
}

function createAsteroid(x, y, vx, vy, tier) {
    var radius = tier === 3 ? 34 : (tier === 2 ? 20 : 12);
    var numVerts = 9 + Math.floor(Math.random() * 5);
    var offsets = [];
    for (var i = 0; i < numVerts; i++) {
        offsets.push(0.75 + Math.random() * 0.5);
    }
    return {
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        radius: radius,
        tier: tier,
        rot: Math.random() * Math.PI * 2,
        rotSpeed: (Math.random() - 0.5) * 0.04,
        numVerts: numVerts,
        offsets: offsets
    };
}

function spawnSaucer(callbacks) {
    var isSmall = (score >= 10000) || (level >= 3 && Math.random() < 0.5);
    var fromLeft = Math.random() < 0.5;
    var sx = fromLeft ? -20 : width + 20;
    var sy = height * 0.2 + Math.random() * (height * 0.6);
    var spd = isSmall ? 2.8 : 1.8;
    var vx = fromLeft ? spd : -spd;
    var vy = (Math.random() - 0.5) * 1.0;

    saucer = {
        x: sx,
        y: sy,
        vx: vx,
        vy: vy,
        baseSpeed: spd,
        radius: isSmall ? 10 : 18,
        isSmall: isSmall,
        shootCooldown: isSmall ? 60 : 85,
        turnCooldown: 90,
        scoreVal: isSmall ? 1000 : 200
    };

    if (callbacks && callbacks.onSound) {
        callbacks.onSound(isSmall ? "saucer_small" : "saucer_big");
    }
}

function hyperspace(callbacks) {
    if (gameState !== "playing" || !ship) return false;
    ship.x = Math.random() * width;
    ship.y = Math.random() * height;
    ship.vx = 0;
    ship.vy = 0;
    invulnerableTimer = 60; // 1 second grace period
    for (var i = 0; i < 24; i++) {
        var ang = Math.random() * Math.PI * 2;
        var sp = 1.0 + Math.random() * 3.5;
        particles.push({
            x: ship.x,
            y: ship.y,
            vx: Math.cos(ang) * sp,
            vy: Math.sin(ang) * sp,
            life: 20,
            maxLife: 20
        });
    }
    if (callbacks && callbacks.onSound) callbacks.onSound("thrust");
    return true;
}

function fireBullet() {
    if (gameState !== "playing" || !ship) return false;
    if (bullets.length >= 6) return false;

    var bx = ship.x + Math.cos(ship.angle) * (ship.radius + 4);
    var by = ship.y + Math.sin(ship.angle) * (ship.radius + 4);
    var speed = 8.5;
    bullets.push({
        x: bx,
        y: by,
        vx: ship.vx * 0.3 + Math.cos(ship.angle) * speed,
        vy: ship.vy * 0.3 + Math.sin(ship.angle) * speed,
        life: 52
    });
    return true;
}

function addScore(pts, callbacks) {
    score += pts;
    if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);

    // Extra life check at 10,000 pt intervals
    if (score >= nextBonusScore) {
        lives++;
        nextBonusScore += 10000;
        if (callbacks && callbacks.onLivesChanged) callbacks.onLivesChanged(lives);
        if (callbacks && callbacks.onSound) callbacks.onSound("extra_life");
    }
}

function getHeartbeatInterval() {
    // Dynamic interval based on remaining threats: 1200ms down to 240ms
    var threatCount = asteroids.length;
    return Math.max(240, Math.min(1200, 200 + threatCount * 120));
}

function destroyShip(callbacks) {
    if (!ship) return;
    for (var sp = 0; sp < 28; sp++) {
        var spAngle = Math.random() * Math.PI * 2;
        var spSpeed = 1.5 + Math.random() * 4.0;
        particles.push({
            x: ship.x,
            y: ship.y,
            vx: Math.cos(spAngle) * spSpeed,
            vy: Math.sin(spAngle) * spSpeed,
            life: 35,
            maxLife: 35
        });
    }

    ship = null;
    lives--;
    if (callbacks && callbacks.onLivesChanged) callbacks.onLivesChanged(lives);

    if (lives <= 0) {
        gameState = "gameover";
        if (callbacks && callbacks.onGameOver) callbacks.onGameOver(score);
        if (callbacks && callbacks.onSound) callbacks.onSound("game_over");
    } else {
        respawnPending = true;
        respawnTimer = 40; // minimum 40 frame pause before safe center check
        if (callbacks && callbacks.onSound) callbacks.onSound("explode_large");
    }
}

function update(callbacks) {
    if (gameState !== "playing") return;

    if (invulnerableTimer > 0) invulnerableTimer--;

    // Safe-Center Respawn logic
    if (respawnPending) {
        if (respawnTimer > 0) {
            respawnTimer--;
        } else {
            // Check if center is clear of asteroids and saucer
            var centerX = width / 2;
            var centerY = height / 2;
            var centerClear = true;
            for (var ci = 0; ci < asteroids.length; ci++) {
                if (Math.hypot(asteroids[ci].x - centerX, asteroids[ci].y - centerY) < 110) {
                    centerClear = false;
                    break;
                }
            }
            if (saucer && Math.hypot(saucer.x - centerX, saucer.y - centerY) < 110) {
                centerClear = false;
            }
            if (centerClear) {
                resetShip();
                respawnPending = false;
            }
        }
    }

    // Ship physics
    if (ship) {
        if (ship.rotLeft) ship.angle -= 0.085;
        if (ship.rotRight) ship.angle += 0.085;

        if (ship.thrusting) {
            ship.vx += Math.cos(ship.angle) * 0.16;
            ship.vy += Math.sin(ship.angle) * 0.16;
            if (Math.random() < 0.6) {
                var rearX = ship.x - Math.cos(ship.angle) * ship.radius;
                var rearY = ship.y - Math.sin(ship.angle) * ship.radius;
                particles.push({
                    x: rearX,
                    y: rearY,
                    vx: -Math.cos(ship.angle) * 2 + (Math.random() - 0.5),
                    vy: -Math.sin(ship.angle) * 2 + (Math.random() - 0.5),
                    life: 14,
                    maxLife: 14
                });
            }
        }

        ship.vx *= 0.985;
        ship.vy *= 0.985;
        var spd = Math.hypot(ship.vx, ship.vy);
        if (spd > 7) {
            ship.vx = (ship.vx / spd) * 7;
            ship.vy = (ship.vy / spd) * 7;
        }

        ship.x += ship.vx;
        ship.y += ship.vy;

        // Wraparound
        if (ship.x < 0) ship.x += width;
        else if (ship.x > width) ship.x -= width;
        if (ship.y < 0) ship.y += height;
        else if (ship.y > height) ship.y -= height;
    }

    // Player bullets update
    for (var b = bullets.length - 1; b >= 0; b--) {
        var bullet = bullets[b];
        bullet.x += bullet.vx;
        bullet.y += bullet.vy;
        bullet.life--;

        if (bullet.x < 0) bullet.x += width;
        else if (bullet.x > width) bullet.x -= width;
        if (bullet.y < 0) bullet.y += height;
        else if (bullet.y > height) bullet.y -= height;

        if (bullet.life <= 0) {
            bullets.splice(b, 1);
        }
    }

    // Enemy / Saucer bullets update
    for (var eb = enemyBullets.length - 1; eb >= 0; eb--) {
        var ebul = enemyBullets[eb];
        ebul.x += ebul.vx;
        ebul.y += ebul.vy;
        ebul.life--;

        if (ebul.x < 0) ebul.x += width;
        else if (ebul.x > width) ebul.x -= width;
        if (ebul.y < 0) ebul.y += height;
        else if (ebul.y > height) ebul.y -= height;

        if (ebul.life <= 0) {
            enemyBullets.splice(eb, 1);
            continue;
        }

        // Enemy bullet vs player ship
        if (ship && invulnerableTimer <= 0) {
            if (Math.hypot(ebul.x - ship.x, ebul.y - ship.y) < ship.radius + 3) {
                enemyBullets.splice(eb, 1);
                destroyShip(callbacks);
                continue;
            }
        }

        // Enemy bullet vs asteroids
        for (var eai = asteroids.length - 1; eai >= 0; eai--) {
            var eAst = asteroids[eai];
            if (Math.hypot(ebul.x - eAst.x, ebul.y - eAst.y) < eAst.radius + 3) {
                enemyBullets.splice(eb, 1);
                var eTier = eAst.tier;
                var ehx = eAst.x;
                var ehy = eAst.y;
                asteroids.splice(eai, 1);
                if (eTier > 1) {
                    for (var es = 0; es < 2; es++) {
                        var eDir = Math.random() * Math.PI * 2;
                        var eSpd = 1.1 * (eTier === 3 ? 1.4 : 1.8);
                        asteroids.push(createAsteroid(ehx, ehy, Math.cos(eDir) * eSpd, Math.sin(eDir) * eSpd, eTier - 1));
                    }
                }
                break;
            }
        }
    }

    // Asteroids update
    for (var a = 0; a < asteroids.length; a++) {
        var ast = asteroids[a];
        ast.x += ast.vx;
        ast.y += ast.vy;
        ast.rot += ast.rotSpeed;

        if (ast.x < -ast.radius) ast.x += width + ast.radius * 2;
        else if (ast.x > width + ast.radius) ast.x -= width + ast.radius * 2;
        if (ast.y < -ast.radius) ast.y += height + ast.radius * 2;
        else if (ast.y > height + ast.radius) ast.y -= height + ast.radius * 2;
    }

    // Saucer update & AI
    if (saucer) {
        saucer.x += saucer.vx;
        saucer.y += saucer.vy;

        // Saucer turn/zigzag timer
        saucer.turnCooldown--;
        if (saucer.turnCooldown <= 0) {
            saucer.turnCooldown = 70 + Math.floor(Math.random() * 60);
            var choices = [0, saucer.baseSpeed * 0.6, -saucer.baseSpeed * 0.6];
            saucer.vy = choices[Math.floor(Math.random() * choices.length)];
        }

        // Keep saucer in vertical bounds
        if (saucer.y < 30) saucer.vy = Math.abs(saucer.vy);
        else if (saucer.y > height - 30) saucer.vy = -Math.abs(saucer.vy);

        // Saucer firing AI
        saucer.shootCooldown--;
        if (saucer.shootCooldown <= 0) {
            saucer.shootCooldown = saucer.isSmall ? 65 : 90;
            var shootAngle = 0;
            if (saucer.isSmall && ship) {
                // Small saucer aims directly at player with slight human-like deviation
                var dx = ship.x - saucer.x;
                var dy = ship.y - saucer.y;
                shootAngle = Math.atan2(dy, dx) + (Math.random() - 0.5) * 0.25;
            } else {
                // Large saucer shoots in random direction
                shootAngle = Math.random() * Math.PI * 2;
            }

            var bspd = 6.0;
            enemyBullets.push({
                x: saucer.x,
                y: saucer.y,
                vx: Math.cos(shootAngle) * bspd,
                vy: Math.sin(shootAngle) * bspd,
                life: 55
            });
            if (callbacks && callbacks.onSound) callbacks.onSound("saucer_shoot");
        }

        // Periodic saucer audio alert
        if (Math.random() < 0.04 && callbacks && callbacks.onSound) {
            callbacks.onSound(saucer.isSmall ? "saucer_small" : "saucer_big");
        }

        // Despawn saucer when crossing screen
        if ((saucer.vx > 0 && saucer.x > width + 40) || (saucer.vx < 0 && saucer.x < -40)) {
            saucer = null;
            saucerTimer = 900 + Math.floor(Math.random() * 600);
        }
    } else {
        // Saucer spawn countdown
        saucerTimer--;
        if (saucerTimer <= 0) {
            spawnSaucer(callbacks);
        }
    }

    // Bullet vs Asteroid collision
    for (var bi = bullets.length - 1; bi >= 0; bi--) {
        var bu = bullets[bi];
        for (var ai = asteroids.length - 1; ai >= 0; ai--) {
            var targetAst = asteroids[ai];
            var dist = Math.hypot(bu.x - targetAst.x, bu.y - targetAst.y);
            if (dist < targetAst.radius + 3) {
                bullets.splice(bi, 1);
                var hitTier = targetAst.tier;
                var hx = targetAst.x;
                var hy = targetAst.y;

                for (var p = 0; p < (hitTier === 3 ? 16 : 8); p++) {
                    var pAngle = Math.random() * Math.PI * 2;
                    var pSpd = 1.0 + Math.random() * 2.5;
                    particles.push({
                        x: hx,
                        y: hy,
                        vx: Math.cos(pAngle) * pSpd,
                        vy: Math.sin(pAngle) * pSpd,
                        life: 20 + Math.floor(Math.random() * 15),
                        maxLife: 35
                    });
                }

                addScore(hitTier === 3 ? 20 : (hitTier === 2 ? 50 : 100), callbacks);

                asteroids.splice(ai, 1);
                if (hitTier > 1) {
                    var nextTier = hitTier - 1;
                    for (var s = 0; s < 2; s++) {
                        var ndir = Math.random() * Math.PI * 2;
                        var nspd = (0.9 + Math.random() * 1.2) * (hitTier === 3 ? 1.4 : 1.8);
                        asteroids.push(createAsteroid(hx, hy, Math.cos(ndir) * nspd, Math.sin(ndir) * nspd, nextTier));
                    }
                    if (callbacks && callbacks.onSound) callbacks.onSound("explode_large");
                } else {
                    if (callbacks && callbacks.onSound) callbacks.onSound("explode_small");
                }
                break;
            }
        }
    }

    // Bullet vs Saucer collision
    if (saucer) {
        for (var sbi = bullets.length - 1; sbi >= 0; sbi--) {
            var sbu = bullets[sbi];
            if (Math.hypot(sbu.x - saucer.x, sbu.y - saucer.y) < saucer.radius + 4) {
                bullets.splice(sbi, 1);
                // Destroy saucer!
                for (var scp = 0; scp < 20; scp++) {
                    var scAngle = Math.random() * Math.PI * 2;
                    var scSpd = 1.2 + Math.random() * 3.0;
                    particles.push({
                        x: saucer.x,
                        y: saucer.y,
                        vx: Math.cos(scAngle) * scSpd,
                        vy: Math.sin(scAngle) * scSpd,
                        life: 25,
                        maxLife: 25
                    });
                }
                addScore(saucer.scoreVal, callbacks);
                if (callbacks && callbacks.onSound) callbacks.onSound("explode_large");
                saucer = null;
                saucerTimer = 1100 + Math.floor(Math.random() * 600);
                break;
            }
        }
    }

    // Asteroids vs Ship collision
    if (ship && invulnerableTimer <= 0) {
        for (var ca = 0; ca < asteroids.length; ca++) {
            var collAst = asteroids[ca];
            if (Math.hypot(ship.x - collAst.x, ship.y - collAst.y) < collAst.radius + ship.radius * 0.75) {
                destroyShip(callbacks);
                break;
            }
        }
    }

    // Saucer vs Ship collision
    if (ship && saucer && invulnerableTimer <= 0) {
        if (Math.hypot(ship.x - saucer.x, ship.y - saucer.y) < saucer.radius + ship.radius * 0.8) {
            saucer = null;
            destroyShip(callbacks);
        }
    }

    // Particles update
    for (var pi = particles.length - 1; pi >= 0; pi--) {
        var part = particles[pi];
        part.x += part.vx;
        part.y += part.vy;
        part.life--;
        if (part.life <= 0) particles.splice(pi, 1);
    }

    // Check level clear
    if (asteroids.length === 0 && gameState === "playing") {
        level++;
        if (callbacks && callbacks.onLevelChanged) callbacks.onLevelChanged(level);
        saucer = null;
        saucerTimer = 600;
        spawnAsteroids();
    }
}
