// Galaga (Galactic Swarm) Authentic 1981 Arcade Engine
// 5 Choreographed entry waves, Boss+Escorts diving, Captive ship mechanics, Accuracy stats & Stage medals

var width = 600;
var height = 700;
var score = 0;
var highScore = 0;
var lives = 3;
var stage = 1;
var gameState = "playing"; // "playing", "gameover", "challenging"

// Accuracy Stats (Authentic Namco Results Screen)
var shotsFired = 0;
var shotsHit = 0;
var hitMissRatio = "0.0";

// Player Fighter
var ship = {
    x: 300,
    y: 630,
    width: 32,
    height: 32,
    vx: 0,
    speed: 380,
    movingLeft: false,
    movingRight: false,
    firing: false,
    fireCooldown: 0,
    isDual: false,
    invincibleTimer: 0,
    captured: false,
    capturedTractorT: 0,
    capturedBossId: null
};

// Rescued ship descending to dock with player
var rescuedShip = null;

// Abducting ship (split off from dual fighter) being pulled up
var abductingShip = null;

// Hostile rogue captive ships (shot free while boss was in grid)
var rogueShips = [];

// Bullets
var bullets = [];
var alienBullets = [];

// Enemies
var enemies = [];
var enemyIdCounter = 1;

// Explosions (authentic 4-frame pixel explosions)
var explosions = [];

// Grid Formation Layout
var gridCols = 10;
var gridRows = 5;
var gridSpacingX = 40;
var gridSpacingY = 32;
var gridOriginX = 120;
var gridOriginY = 90;
var gridBreath = 0;
var gridBreathSpeed = 1.4;
var gridOffsetX = 0;
var gridDir = 1;

// Dive Attack Scheduler
var diveTimer = 0;
var diveInterval = 2.0;

// Tractor Beam State
var activeTractor = null; // { boss, x, y, widthTop, widthBottom, length, timer, maxTimer, pulse }

// Starfield
var stars = [];
for (var s = 0; s < 70; s++) {
    stars.push({
        x: Math.random() * 800,
        y: Math.random() * 800,
        speed: 35 + Math.random() * 95,
        size: Math.random() < 0.25 ? 2 : 1,
        color: ["#FFFFFF", "#89B4FA", "#F9E2AF", "#F38BA8", "#A6E3A1"][Math.floor(Math.random() * 5)],
        twinkle: Math.random() * Math.PI * 2
    });
}

// Stage Progression & Warp Transition
var isWarping = false;
var warpTimer = 0;

// Authentic Challenging Stage Tracking (Stage 3, 7, 11, 15...)
var isChallengingStage = false;
var challengingHits = 0;
var challengingTotal = 40;
var waveTimer = 0;
var currentWave = 0;

// Callbacks
var onSoundCallback = null;

function setSoundCallback(cb) {
    onSoundCallback = cb;
}

function playSnd(name) {
    if (onSoundCallback) onSoundCallback(name);
}

function init(w, h) {
    width = w || 600;
    height = h || 700;
    resetGame();
}

function resetGame() {
    score = 0;
    lives = 3;
    stage = 1;
    gameState = "playing";
    shotsFired = 0;
    shotsHit = 0;
    hitMissRatio = "0.0";
    ship.x = width / 2;
    ship.y = height - 50;
    ship.movingLeft = false;
    ship.movingRight = false;
    ship.firing = false;
    ship.fireCooldown = 0;
    ship.isDual = false;
    ship.captured = false;
    ship.invincibleTimer = 2.0;
    rescuedShip = null;
    abductingShip = null;
    rogueShips = [];
    bullets = [];
    alienBullets = [];
    explosions = [];
    activeTractor = null;
    isWarping = false;
    warpTimer = 0;
    startStage(stage);
}

function isStageChallenging(stg) {
    return (stg === 3 || (stg > 3 && (stg - 3) % 4 === 0));
}

function startStage(stg) {
    stage = stg;
    isChallengingStage = isStageChallenging(stage);
    challengingHits = 0;
    enemies = [];
    bullets = [];
    alienBullets = [];
    explosions = [];
    rogueShips = [];
    rescuedShip = null;
    abductingShip = null;
    activeTractor = null;
    isWarping = false;
    warpTimer = 0;
    currentWave = 0;
    waveTimer = 0.5;
    diveTimer = 4.5; // Grace period while waves enter

    if (isChallengingStage) {
        playSnd("challenging");
        setupChallengingStage();
    } else {
        playSnd("intro");
        setupStandardStage();
    }
}

// 40 Enemies in 5 Authentic Choreographed Arrival Groups
function setupStandardStage() {
    gridOriginX = (width - (gridCols - 1) * gridSpacingX) / 2;
    gridOriginY = Math.max(70, height * 0.12);
    enemies = [];

    // Pre-calculate target grid slots
    // Group 1 (t=0.2s): 4 Butterflies (row 1, cols 3,4,5,6) + 4 Bosses (row 0, cols 3,4,5,6)
    spawnArrivalGroup(1, [
        { row: 1, col: 3, type: "butterfly", hp: 1 },
        { row: 1, col: 4, type: "butterfly", hp: 1 },
        { row: 1, col: 5, type: "butterfly", hp: 1 },
        { row: 1, col: 6, type: "butterfly", hp: 1 },
        { row: 0, col: 3, type: "boss", hp: 2 },
        { row: 0, col: 4, type: "boss", hp: 2 },
        { row: 0, col: 5, type: "boss", hp: 2 },
        { row: 0, col: 6, type: "boss", hp: 2 }
    ], 0.2, "top_left");

    // Group 2 (t=2.6s): 8 Blue Bees (row 3, cols 1..8)
    spawnArrivalGroup(2, [
        { row: 3, col: 1, type: "bee", hp: 1 },
        { row: 3, col: 2, type: "bee", hp: 1 },
        { row: 3, col: 3, type: "bee", hp: 1 },
        { row: 3, col: 4, type: "bee", hp: 1 },
        { row: 3, col: 5, type: "bee", hp: 1 },
        { row: 3, col: 6, type: "bee", hp: 1 },
        { row: 3, col: 7, type: "bee", hp: 1 },
        { row: 3, col: 8, type: "bee", hp: 1 }
    ], 2.6, "bottom_left");

    // Group 3 (t=5.0s): 8 Blue Bees (row 4, cols 1..8)
    spawnArrivalGroup(3, [
        { row: 4, col: 1, type: "bee", hp: 1 },
        { row: 4, col: 2, type: "bee", hp: 1 },
        { row: 4, col: 3, type: "bee", hp: 1 },
        { row: 4, col: 4, type: "bee", hp: 1 },
        { row: 4, col: 5, type: "bee", hp: 1 },
        { row: 4, col: 6, type: "bee", hp: 1 },
        { row: 4, col: 7, type: "bee", hp: 1 },
        { row: 4, col: 8, type: "bee", hp: 1 }
    ], 5.0, "bottom_right");

    // Group 4 (t=7.4s): 8 Red Butterflies (row 1 & 2 flanks: row 1 cols 1,2,7,8; row 2 cols 3,4,5,6)
    spawnArrivalGroup(4, [
        { row: 1, col: 1, type: "butterfly", hp: 1 },
        { row: 1, col: 2, type: "butterfly", hp: 1 },
        { row: 1, col: 7, type: "butterfly", hp: 1 },
        { row: 1, col: 8, type: "butterfly", hp: 1 },
        { row: 2, col: 3, type: "butterfly", hp: 1 },
        { row: 2, col: 4, type: "butterfly", hp: 1 },
        { row: 2, col: 5, type: "butterfly", hp: 1 },
        { row: 2, col: 6, type: "butterfly", hp: 1 }
    ], 7.4, "top_right");

    // Group 5 (t=9.8s): 8 Remaining Outer Bees & Butterflies (row 2 cols 1,2,7,8; row 3 & 4 cols 0, 9)
    spawnArrivalGroup(5, [
        { row: 2, col: 1, type: "butterfly", hp: 1 },
        { row: 2, col: 2, type: "butterfly", hp: 1 },
        { row: 2, col: 7, type: "butterfly", hp: 1 },
        { row: 2, col: 8, type: "butterfly", hp: 1 },
        { row: 3, col: 0, type: "bee", hp: 1 },
        { row: 3, col: 9, type: "bee", hp: 1 },
        { row: 4, col: 0, type: "bee", hp: 1 },
        { row: 4, col: 9, type: "bee", hp: 1 }
    ], 9.8, "top_center");
}

function spawnArrivalGroup(groupIndex, specs, baseDelay, pattern) {
    for (var i = 0; i < specs.length; i++) {
        var sp = specs[i];
        var targetX = gridOriginX + sp.col * gridSpacingX;
        var targetY = gridOriginY + sp.row * gridSpacingY;

        var spawnX = width / 2;
        var spawnY = -40;
        if (pattern === "top_left") { spawnX = -30; spawnY = 80; }
        else if (pattern === "top_right") { spawnX = width + 30; spawnY = 80; }
        else if (pattern === "bottom_left") { spawnX = -30; spawnY = height * 0.75; }
        else if (pattern === "bottom_right") { spawnX = width + 30; spawnY = height * 0.75; }

        var enemy = {
            id: enemyIdCounter++,
            type: sp.type,
            row: sp.row,
            col: sp.col,
            hp: sp.hp,
            maxHp: sp.hp,
            x: spawnX,
            y: spawnY,
            targetX: targetX,
            targetY: targetY,
            homeX: targetX,
            homeY: targetY,
            state: "entering",
            angle: Math.PI / 2,
            t: 0,
            pathDelay: baseDelay + (i * 0.12),
            diveSpeed: 180 + stage * 12,
            wingFlutter: Math.random() * Math.PI,
            capturedShip: null,
            escorts: [], // attached butterfly escort IDs
            parentBossId: null
        };
        enemies.push(enemy);
    }
}

function setupChallengingStage() {
    enemies = [];
    currentWave = 0;
    waveTimer = 0.5;
}

function spawnChallengingWave(waveIndex) {
    var type = (waveIndex === 0 || waveIndex === 4) ? "bee" : (waveIndex === 1 || waveIndex === 3 ? "butterfly" : "boss");
    var entrySide = (waveIndex % 2 === 0) ? -1 : 1;

    for (var i = 0; i < 8; i++) {
        var enemy = {
            id: enemyIdCounter++,
            type: type,
            hp: 1,
            maxHp: 1,
            x: entrySide === -1 ? -30 : width + 30,
            y: 100 + i * 20,
            state: "challenging_fly",
            angle: 0,
            t: 0,
            pathDelay: i * 0.14,
            wave: waveIndex,
            indexInWave: i,
            speed: 250 + stage * 10,
            wingFlutter: 0
        };
        enemies.push(enemy);
    }
}

// Authentic Galaga Dual-Missile Firing System
function fireBullet() {
    if (gameState !== "playing" || ship.captured) return false;

    var maxAllowed = ship.isDual ? 16 : 8;
    if (bullets.length >= maxAllowed) return false;

    var bulletVy = -920;

    if (ship.isDual) {
        bullets.push({ x: ship.x - 22, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        bullets.push({ x: ship.x - 8, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        bullets.push({ x: ship.x + 8, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        bullets.push({ x: ship.x + 22, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        shotsFired += 4;
    } else {
        bullets.push({ x: ship.x - 7, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        bullets.push({ x: ship.x + 7, y: ship.y - 12, vy: bulletVy, width: 3, height: 10 });
        shotsFired += 2;
    }

    hitMissRatio = (shotsHit / Math.max(1, shotsFired) * 100).toFixed(1);
    playSnd("shoot");
    return true;
}

function update(dt) {
    dt = Math.min(dt, 0.05);

    // Update Starfield
    var starSpdMult = isWarping ? 8.5 : 1.0;
    for (var s = 0; s < stars.length; s++) {
        var star = stars[s];
        star.y += star.speed * starSpdMult * dt;
        if (star.y > height) {
            star.y = -10;
            star.x = Math.random() * width;
        }
        star.twinkle += dt * 6;
    }

    // Handle Active Warp Transition
    if (isWarping) {
        warpTimer -= dt;
        if (warpTimer <= 0) {
            isWarping = false;
            startStage(stage + 1);
        }
        return;
    }

    // Update Pixel Explosions
    for (var ex = explosions.length - 1; ex >= 0; ex--) {
        var exp = explosions[ex];
        exp.timer += dt;
        if (exp.timer >= exp.frameDuration) {
            exp.timer = 0;
            exp.frame++;
            if (exp.frame >= 4) {
                explosions.splice(ex, 1);
            }
        }
    }

    if (gameState === "gameover") return;

    // Update Player Invulnerability
    if (ship.invincibleTimer > 0) {
        ship.invincibleTimer -= dt;
    }

    // Continuous Rapid Fire when Space is held
    if (ship.fireCooldown > 0) {
        ship.fireCooldown -= dt;
    }
    if (ship.firing && ship.fireCooldown <= 0) {
        if (fireBullet()) {
            ship.fireCooldown = 0.13;
        }
    }

    // Player Horizontal Movement
    var moveW = ship.isDual ? 32 : 16;
    if (!ship.captured && rescuedShip === null) {
        if (ship.movingLeft) ship.x -= ship.speed * dt;
        if (ship.movingRight) ship.x += ship.speed * dt;
        ship.x = Math.max(moveW, Math.min(width - moveW, ship.x));
    }

    // Update Rescued Ship Docking Sequence
    if (rescuedShip) {
        var targetX = ship.x + 24;
        var targetY = ship.y;
        var dx = targetX - rescuedShip.x;
        var dy = targetY - rescuedShip.y;
        rescuedShip.x += dx * 5.0 * dt;
        rescuedShip.y += dy * 5.0 * dt;

        if (Math.abs(dx) < 4 && Math.abs(dy) < 4) {
            ship.isDual = true;
            rescuedShip = null;
            playSnd("dual");
        }
    }

    // Update Hostile Rogue Captive Ships
    for (var rs = rogueShips.length - 1; rs >= 0; rs--) {
        var rship = rogueShips[rs];
        rship.y += 240 * dt;
        rship.x += Math.sin(rship.y * 0.05) * 80 * dt;

        if (!ship.captured && ship.invincibleTimer <= 0) {
            if (Math.abs(rship.x - ship.x) < 20 && Math.abs(rship.y - ship.y) < 18) {
                destroyPlayer();
                addExplosion(rship.x, rship.y);
                rogueShips.splice(rs, 1);
                continue;
            }
        }

        if (rship.y > height + 30) {
            rogueShips.splice(rs, 1);
        }
    }

    // Update Player Bullets
    for (var b = bullets.length - 1; b >= 0; b--) {
        var bul = bullets[b];
        bul.y += bul.vy * dt;
        if (bul.y < -20) {
            bullets.splice(b, 1);
            continue;
        }

        // Check collision with rogue captive ships
        var hitRogue = false;
        for (var ri = rogueShips.length - 1; ri >= 0; ri--) {
            var rog = rogueShips[ri];
            if (Math.abs(bul.x - rog.x) < 14 && Math.abs(bul.y - rog.y) < 14) {
                bullets.splice(b, 1);
                addExplosion(rog.x, rog.y);
                playSnd("hit");
                rogueShips.splice(ri, 1);
                shotsHit++;
                score += 1000;
                hitRogue = true;
                break;
            }
        }
        if (hitRogue) continue;

        // Check collision with enemies
        for (var e = enemies.length - 1; e >= 0; e--) {
            var en = enemies[e];
            var enRadius = (en.type === "boss") ? 18 : 14;
            var distSq = (bul.x - en.x) * (bul.x - en.x) + (bul.y - en.y) * (bul.y - en.y);

            // Also check if bullet hits a captive ship docked to the boss!
            if (en.capturedShip && Math.abs(bul.x - en.x) < 14 && Math.abs(bul.y - (en.y - 20)) < 12) {
                bullets.splice(b, 1);
                en.capturedShip = null;
                addExplosion(en.x, en.y - 20);
                playSnd("hit");
                shotsHit++;
                break;
            }

            if (distSq < enRadius * enRadius) {
                bullets.splice(b, 1);
                shotsHit++;
                damageEnemy(en);
                break;
            }
        }
    }

    hitMissRatio = (shotsHit / Math.max(1, shotsFired) * 100).toFixed(1);

    // Update Alien Bullets
    for (var ab = alienBullets.length - 1; ab >= 0; ab--) {
        var abul = alienBullets[ab];
        abul.x += abul.vx * dt;
        abul.y += abul.vy * dt;

        if (abul.y > height + 20 || abul.x < -20 || abul.x > width + 20) {
            alienBullets.splice(ab, 1);
            continue;
        }

        if (!ship.captured && ship.invincibleTimer <= 0) {
            var hitW = ship.isDual ? 28 : 14;
            if (Math.abs(abul.x - ship.x) < hitW && Math.abs(abul.y - ship.y) < 14) {
                alienBullets.splice(ab, 1);
                destroyPlayer();
                break;
            }
        }
    }

    // Update Formation Breathing & Drift
    gridBreath += gridBreathSpeed * dt;
    gridOffsetX += 25 * gridDir * dt;
    if (Math.abs(gridOffsetX) > 35) {
        gridDir *= -1;
    }

    // Update Enemies
    var aliveEnemies = 0;
    for (var i = 0; i < enemies.length; i++) {
        var enemy = enemies[i];
        if (enemy.hp <= 0) continue;
        aliveEnemies++;

        enemy.wingFlutter += dt * 6;

        if (enemy.pathDelay > 0) {
            enemy.pathDelay -= dt;
            continue;
        }

        enemy.t += dt;

        if (enemy.state === "entering") {
            var targetHomeX = enemy.homeX + gridOffsetX + Math.sin(gridBreath) * 10 * ((enemy.col - 4.5) / 4.5);
            var targetHomeY = enemy.homeY + Math.cos(gridBreath * 0.7) * 4;
            var tProgress = Math.min(1.0, enemy.t / 2.2);

            enemy.x += (targetHomeX - enemy.x) * 3.5 * dt;
            enemy.y += (targetHomeY - enemy.y) * 3.5 * dt;

            if (tProgress >= 0.95 && Math.abs(enemy.x - targetHomeX) < 5 && Math.abs(enemy.y - targetHomeY) < 5) {
                enemy.state = "formation";
            }
        } else if (enemy.state === "formation") {
            enemy.x = enemy.homeX + gridOffsetX + Math.sin(gridBreath) * 8 * ((enemy.col - 4.5) / 4.5);
            enemy.y = enemy.homeY + Math.cos(gridBreath * 0.7) * 4;
            enemy.angle = Math.PI / 2;
        } else if (enemy.state === "diving") {
            updateDivingEnemy(enemy, dt);
        } else if (enemy.state === "tractor") {
            updateTractorBoss(enemy, dt);
        } else if (enemy.state === "challenging_fly") {
            updateChallengingEnemy(enemy, dt);
        }
    }

    // Dive Attack Scheduling (Boss + Escorts)
    if (!isChallengingStage && enemies.length > 0) {
        diveTimer -= dt;
        if (diveTimer <= 0) {
            diveTimer = Math.max(1.3, diveInterval - stage * 0.1);
            triggerFormationDive();
        }
    }

    // Update Active Tractor Beam
    if (activeTractor) {
        updateTractorBeam(dt);
    }

    // Challenging Stage Wave Dispatch
    if (isChallengingStage) {
        waveTimer -= dt;
        if (waveTimer <= 0 && currentWave < 5) {
            spawnChallengingWave(currentWave);
            currentWave++;
            waveTimer = 3.2;
        }

        if (currentWave >= 5 && aliveEnemies === 0 && waveTimer <= 0 && !isWarping) {
            concludeChallengingStage();
        }
    } else if (enemies.length === 0 && !isWarping) {
        triggerStageWarp();
    }
}

// Boss + Escorts Formation Dive
function triggerFormationDive() {
    var bosses = [];
    var butterflies = [];
    var bees = [];

    for (var i = 0; i < enemies.length; i++) {
        var e = enemies[i];
        if (e.hp > 0 && e.state === "formation") {
            if (e.type === "boss") bosses.push(e);
            else if (e.type === "butterfly") butterflies.push(e);
            else bees.push(e);
        }
    }

    // Pick a dive attacker (Authentic arcade distribution)
    if (bosses.length > 0 && Math.random() < 0.28) {
        var boss = bosses[Math.floor(Math.random() * bosses.length)];

        // Tractor Beam only occurs occasionally during boss dives when no captive exists
        if (!activeTractor && !ship.captured && !boss.capturedShip && Math.random() < 0.35) {
            boss.state = "tractor";
            boss.t = 0;
            boss.diveStartX = boss.x;
            boss.diveStartY = boss.y;
            playSnd("dive");
            return;
        }

        // Normal Boss Dive Bomb with Escorts!
        boss.state = "diving";
        boss.t = 0;
        boss.diveStartX = boss.x;
        boss.diveStartY = boss.y;
        boss.targetPlayerX = ship.x;
        boss.hasFired = false;
        boss.escorts = [];

        // Attach up to 2 butterfly escorts
        var numEscorts = Math.min(2, butterflies.length);
        for (var esc = 0; esc < numEscorts; esc++) {
            var escort = butterflies[esc];
            escort.state = "diving";
            escort.t = 0;
            escort.parentBossId = boss.id;
            escort.escortOffset = (esc === 0) ? -24 : 24;
            escort.diveStartX = boss.x + escort.escortOffset;
            escort.diveStartY = boss.y;
            escort.targetPlayerX = ship.x + escort.escortOffset;
            escort.hasFired = false;
            boss.escorts.push(escort);
        }
        playSnd("dive");
        return;
    }

    // Normal butterfly or bee dive
    var candidates = butterflies.concat(bees);
    if (candidates.length === 0) return;

    var selected = candidates[Math.floor(Math.random() * candidates.length)];
    selected.state = "diving";
    selected.t = 0;
    selected.diveStartX = selected.x;
    selected.diveStartY = selected.y;
    selected.targetPlayerX = ship.x;
    selected.hasFired = false;
    selected.parentBossId = null;
    playSnd("dive");
}

function updateDivingEnemy(enemy, dt) {
    var diveDuration = 3.2;
    var progress = enemy.t / diveDuration;

    var p0x = enemy.diveStartX;
    var p0y = enemy.diveStartY;
    var p1x = enemy.targetPlayerX + (enemy.x > width / 2 ? -120 : 120);
    var p1y = height * 0.45;
    var p2x = enemy.targetPlayerX;
    var p2y = height - 80;
    var p3x = enemy.diveStartX;
    var p3y = height + 60;

    var u = 1 - progress;
    var prevX = enemy.x;
    var prevY = enemy.y;

    enemy.x = u * u * u * p0x + 3 * u * u * progress * p1x + 3 * u * progress * progress * p2x + progress * progress * progress * p3x;
    enemy.y = u * u * u * p0y + 3 * u * u * progress * p1y + 3 * u * progress * progress * p2y + progress * progress * progress * p3y;

    enemy.angle = Math.atan2(enemy.y - prevY, enemy.x - prevX);

    if (!enemy.hasFired && progress > 0.35 && progress < 0.65) {
        enemy.hasFired = true;
        var bulletSpeed = 280 + stage * 15;
        var bAngle = Math.atan2(ship.y - enemy.y, ship.x - enemy.x);
        alienBullets.push({
            x: enemy.x,
            y: enemy.y,
            vx: Math.cos(bAngle) * bulletSpeed,
            vy: Math.sin(bAngle) * bulletSpeed
        });
    }

    if (!ship.captured && ship.invincibleTimer <= 0) {
        var hitW = ship.isDual ? 26 : 14;
        if (Math.abs(enemy.x - ship.x) < hitW && Math.abs(enemy.y - ship.y) < 16) {
            destroyPlayer();
            damageEnemy(enemy);
        }
    }

    if (enemy.y > height + 40) {
        enemy.x = enemy.homeX;
        enemy.y = -30;
        enemy.state = "entering";
        enemy.t = 0;
        enemy.parentBossId = null;
    }
}

function updateTractorBoss(boss, dt) {
    var hoverY = height * 0.36;
    if (boss.y < hoverY) {
        boss.y += 180 * dt;
        boss.angle = Math.PI / 2;
    } else {
        boss.y = hoverY;
        if (!activeTractor) {
            activeTractor = {
                boss: boss,
                x: boss.x,
                y: boss.y + 16,
                length: height - boss.y - 40,
                widthTop: 24,
                widthBottom: 130,
                timer: 4.2,
                pulse: 0
            };
            playSnd("tractor");
        }
    }
}

function updateTractorBeam(dt) {
    if (!activeTractor) return;

    var beam = activeTractor;
    beam.timer -= dt;
    beam.pulse += dt * 10;

    beam.x = beam.boss.x;
    beam.y = beam.boss.y + 16;

    var relY = (ship.y - beam.y) / beam.length;
    if (relY > 0 && relY <= 1.0 && !ship.captured && !abductingShip && ship.invincibleTimer <= 0) {
        var beamWidthAtY = beam.widthTop + (beam.widthBottom - beam.widthTop) * relY;
        if (Math.abs(ship.x - beam.x) < beamWidthAtY / 2) {
            if (ship.isDual) {
                // Split off right ship into captivity, player keeps left ship!
                ship.isDual = false;
                ship.invincibleTimer = 2.0;
                abductingShip = {
                    x: ship.x + 14,
                    y: ship.y,
                    spinAngle: 0,
                    boss: beam.boss
                };
                playSnd("capture");
            } else {
                ship.captured = true;
                ship.capturedBossId = beam.boss.id;
                ship.spinAngle = 0;
                playSnd("capture");
            }
        }
    }

    if (ship.captured) {
        ship.spinAngle = (ship.spinAngle || 0) + dt * 14;
        ship.x += (beam.boss.x - ship.x) * 3.5 * dt;
        ship.y += (beam.boss.y - 20 - ship.y) * 2.8 * dt;

        if (Math.abs(ship.y - (beam.boss.y - 20)) < 10) {
            beam.boss.capturedShip = true;
            activeTractor = null;
            beam.boss.state = "diving";
            beam.boss.t = 1.8;

            lives--;
            if (lives <= 0) {
                triggerGameOver();
            } else {
                respawnShip();
            }
            return;
        }
    }

    if (abductingShip) {
        abductingShip.spinAngle = (abductingShip.spinAngle || 0) + dt * 14;
        abductingShip.x += (beam.boss.x - abductingShip.x) * 3.5 * dt;
        abductingShip.y += (beam.boss.y - 20 - abductingShip.y) * 2.8 * dt;

        if (Math.abs(abductingShip.y - (beam.boss.y - 20)) < 10) {
            beam.boss.capturedShip = true;
            abductingShip = null;
            activeTractor = null;
            beam.boss.state = "diving";
            beam.boss.t = 1.8;
            return;
        }
    }

    if (beam.timer <= 0) {
        if (!ship.captured && !abductingShip) {
            activeTractor = null;
            beam.boss.state = "diving";
            beam.boss.t = 1.8;
        }
    }
}

function updateChallengingEnemy(enemy, dt) {
    enemy.x += (enemy.wave % 2 === 0 ? 1 : -1) * enemy.speed * dt;
    enemy.y += Math.sin(enemy.t * 3.5) * 140 * dt + 120 * dt;
    enemy.angle = Math.atan2(Math.sin(enemy.t * 3.5) * 140 + 120, (enemy.wave % 2 === 0 ? 1 : -1) * enemy.speed);

    if (enemy.y > height + 40 || enemy.x < -60 || enemy.x > width + 60) {
        enemy.hp = 0;
    }
}

function damageEnemy(en) {
    en.hp--;
    if (en.hp <= 0) {
        addExplosion(en.x, en.y);
        playSnd("hit");

        var pts = 50;
        if (en.type === "boss") {
            pts = (en.state === "diving" || en.state === "tractor") ? 400 : 150;

            // If this boss was tractoring, terminate beam and free any ship being pulled mid-air!
            if (activeTractor && activeTractor.boss === en) {
                activeTractor = null;
                if (ship.captured) {
                    ship.captured = false;
                    ship.spinAngle = 0;
                    ship.y = height - 50;
                    ship.invincibleTimer = 2.0;
                    playSnd("start");
                }
                if (abductingShip) {
                    rescuedShip = { x: abductingShip.x, y: abductingShip.y };
                    abductingShip = null;
                    playSnd("start");
                }
            }

            // Captive Ship Rescue vs Rogue Hostile
            if (en.capturedShip) {
                if (en.state === "diving" || en.state === "tractor") {
                    // RESCUE! Liberated ship descends to dock with player into DUAL FIGHTER!
                    rescuedShip = { x: en.x, y: en.y - 20 };
                    en.capturedShip = false;
                    pts = 1000;
                    playSnd("start");
                } else {
                    // Boss destroyed in grid: Captive ship turns hostile!
                    rogueShips.push({ x: en.x, y: en.y - 20 });
                    en.capturedShip = false;
                    playSnd("dive");
                }
            }

            // Escorts break off into aggressive solo dives
            if (en.escorts && en.escorts.length > 0) {
                for (var esc = 0; esc < en.escorts.length; esc++) {
                    var escort = en.escorts[esc];
                    escort.parentBossId = null;
                }
            }
        } else if (en.type === "butterfly") {
            pts = (en.state === "diving") ? 160 : 80;
        } else {
            pts = (en.state === "diving") ? 100 : 50;
        }

        if (isChallengingStage) {
            challengingHits++;
            pts = 100;
        }

        score += pts;
        if (score > highScore) highScore = score;

        var idx = enemies.indexOf(en);
        if (idx !== -1) enemies.splice(idx, 1);

        if (!isChallengingStage && enemies.length === 0 && !isWarping) {
            triggerStageWarp();
        }
    } else {
        playSnd("boss_hit");
        addExplosion(en.x, en.y);
    }
}

function destroyPlayer() {
    addExplosion(ship.x, ship.y);
    playSnd("hit");

    if (ship.isDual) {
        ship.isDual = false;
        ship.invincibleTimer = 2.0;
        playSnd("dive");
        return;
    }

    lives--;
    if (lives <= 0) {
        triggerGameOver();
    } else {
        respawnShip();
    }
}

function triggerGameOver() {
    gameState = "gameover";
    hitMissRatio = (shotsHit / Math.max(1, shotsFired) * 100).toFixed(1);
    playSnd("results");
}

function respawnShip() {
    ship.x = width / 2;
    ship.y = height - 50;
    ship.isDual = false;
    ship.captured = false;
    ship.invincibleTimer = 2.5;
}

function concludeChallengingStage() {
    if (challengingHits === challengingTotal) {
        score += 10000;
    } else {
        score += challengingHits * 100;
    }
    if (score > highScore) highScore = score;

    triggerStageWarp();
}

function triggerStageWarp() {
    isWarping = true;
    warpTimer = 2.4;
    alienBullets = [];
    activeTractor = null;
    playSnd("start");
}

function addExplosion(x, y) {
    explosions.push({
        x: x,
        y: y,
        frame: 0,
        timer: 0,
        frameDuration: 0.07
    });
}
