// Omarchy Arcade • DomainRush Game Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

var GRID_W = 90;
var GRID_H = 65;

// Colors definition
var COLORS = [
    { id: 0, name: "Neutral", fill: "#080b12", stroke: "#161e2e", glow: "#101622" },
    { id: 1, name: "You", color: "#06b6d4", fill: "rgba(6, 182, 212, 0.32)", stroke: "#22d3ee", glow: "#0891b2" },
    { id: 2, name: "Viper", color: "#f43f5e", fill: "rgba(244, 63, 94, 0.32)", stroke: "#fb7185", glow: "#e11d48" },
    { id: 3, name: "Solar", color: "#f59e0b", fill: "rgba(245, 158, 11, 0.32)", stroke: "#fbbf24", glow: "#d97706" },
    { id: 4, name: "Jade", color: "#10b981", fill: "rgba(16, 185, 129, 0.32)", stroke: "#34d399", glow: "#059669" },
    { id: 5, name: "Vapor", color: "#a855f7", fill: "rgba(168, 85, 247, 0.32)", stroke: "#c084fc", glow: "#7e22ce" }
];

// Persona Archetypes
var PERSONAS = {
    VIPER: "hunter",         // Aggressive: hunts exposed enemy trails
    SOLAR: "fortifier",      // Disciplined: tight loops, rapid steady growth
    JADE: "core_seeker",     // Opportunist: races for energy power cores
    VAPOR: "counter_attacker"// Trapper: flanks opponents venturing into open space
};

// State
var grid = new Uint8Array(GRID_W * GRID_H);
var flashGrid = new Float32Array(GRID_W * GRID_H);
var player = null;
var bots = [];
var allEntities = [];
var powerNodes = [];
var particles = [];
var shakeAmount = 0;
var gameState = "ready"; // "ready", "playing", "gameover", "won"
var endReason = "";
var cutsCount = 0;
var peakTurf = 0;
var startTime = 0;
var elapsedSeconds = 0;
var tickCount = 0;
var boostEnergy = 100;
var isBoosting = false;

// Event banner
var bannerText = "";
var bannerType = "info"; // "info", "kill", "win"
var bannerTimer = 0;

function setBanner(text, type) {
    bannerText = text;
    bannerType = type || "info";
    bannerTimer = 160; // ~2.6 seconds at 60 FPS
}

function getBanner() {
    return {
        active: bannerTimer > 0,
        text: bannerText,
        type: bannerType
    };
}

// -----------------------------------------------------------------------------
// Skimmer Class
// -----------------------------------------------------------------------------
function Skimmer(id, name, startX, startY, colorDef, isBot, persona) {
    this.id = id;
    this.name = name;
    this.x = startX;
    this.y = startY;
    this.prevX = startX;
    this.prevY = startY;
    this.startX = startX;
    this.startY = startY;
    this.dx = isBot ? (startX < 45 ? 1 : -1) : 0;
    this.dy = isBot ? (startY < 32 ? 1 : -1) : 0;
    this.nextDx = this.dx;
    this.nextDy = this.dy;
    this.started = isBot;
    this.trail = [];
    this.colorDef = colorDef;
    this.isBot = isBot;
    this.persona = persona || "none";
    this.alive = true;
    this.angle = Math.atan2(this.dy, this.dx);
    this.botTimer = 0;
    this.stepCounter = 0;
    this.boostEnergy = 100;
    this.isBoosting = false;
    this.loopSteps = 0;
    this.loopPhase = 0;

    // Spawn 7x7 initial territory
    for (var dy = -3; dy <= 3; dy++) {
        for (var dx = -3; dx <= 3; dx++) {
            var gx = startX + dx;
            var gy = startY + dy;
            if (gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H) {
                grid[gy * GRID_W + gx] = this.id;
            }
        }
    }
}

Skimmer.prototype.setDirection = function(ndx, ndy) {
    if (this.dx !== 0 && this.dy !== 0 && ndx === -this.dx && ndy === -this.dy) return;
    this.nextDx = ndx;
    this.nextDy = ndy;
    this.started = true;
};

Skimmer.prototype.update = function(callbacks) {
    if (!this.alive) return;
    if (this.dx === 0 && this.dy === 0 && !this.started) return;

    this.dx = this.nextDx;
    this.dy = this.nextDy;
    if (this.dx === 0 && this.dy === 0) return;

    this.angle = Math.atan2(this.dy, this.dx);
    this.prevX = this.x;
    this.prevY = this.y;

    this.x += this.dx;
    this.y += this.dy;

    // Boundary check
    if (this.x < 0 || this.x >= GRID_W || this.y < 0 || this.y >= GRID_H) {
        this.die("Crashed into perimeter barrier.", callbacks);
        return;
    }

    var cellIndex = this.y * GRID_W + this.x;
    var currentOwner = grid[cellIndex];

    // Check power node collection
    for (var i = powerNodes.length - 1; i >= 0; i--) {
        var pn = powerNodes[i];
        if (pn.x === this.x && pn.y === this.y) {
            powerNodes.splice(i, 1);
            this.collectPowerNode(callbacks);
        }
    }

    if (currentOwner !== this.id) {
        // In wild territory: check self-trail collision (excluding the very last point)
        for (var t = 0; t < this.trail.length - 1; t++) {
            var pt = this.trail[t];
            if (pt.x === this.x && pt.y === this.y) {
                this.die("Crossed own trail.", callbacks);
                return;
            }
        }

        this.trail.push({ x: this.x, y: this.y });

        // Thruster sparks
        if (Math.random() < 0.5) {
            particles.push({
                x: this.x * 10 + 5,
                y: this.y * 10 + 5,
                vx: -this.dx * 2 + (Math.random() - 0.5) * 2,
                vy: -this.dy * 2 + (Math.random() - 0.5) * 2,
                color: this.colorDef.color,
                life: 0.6,
                decay: 0.06,
                size: 2.5
            });
        }
    } else {
        // Returned safely to home territory -> enclose!
        if (this.trail.length > 0) {
            this.encloseTerritory(callbacks);
            this.trail = [];
            this.loopSteps = 0;
            this.loopPhase = 0;
        }
    }

    // AI decision for bots
    if (this.isBot) {
        this.updateBotAI();
    }
};

Skimmer.prototype.collectPowerNode = function(callbacks) {
    for (var k = 0; k < 25; k++) {
        particles.push({
            x: this.x * 10 + 5,
            y: this.y * 10 + 5,
            vx: (Math.random() - 0.5) * 9,
            vy: (Math.random() - 0.5) * 9,
            color: "#38bdf8",
            life: 1.0,
            decay: 0.03,
            size: 4.5
        });
    }

    if (this.id === 1) {
        shakeAmount = 6;
        boostEnergy = Math.min(100, boostEnergy + 40);
        setBanner("⚡ Energy Core Secured! Territory Pulse Activated", "info");
    } else {
        setBanner("⚡ " + this.name + " collected an Energy Core!", "info");
    }

    if (callbacks && callbacks.onSound) {
        callbacks.onSound("target");
    }

    // Instant 5x5 expansion pulse
    for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
            var gx = this.x + dx;
            var gy = this.y + dy;
            if (gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H) {
                grid[gy * GRID_W + gx] = this.id;
                flashGrid[gy * GRID_W + gx] = 1.0;
            }
        }
    }
};

Skimmer.prototype.encloseTerritory = function(callbacks) {
    var boundary = new Uint8Array(GRID_W * GRID_H);
    for (var i = 0; i < this.trail.length; i++) {
        var pt = this.trail[i];
        boundary[pt.y * GRID_W + pt.x] = 1;
    }

    var minX = GRID_W, maxX = 0, minY = GRID_H, maxY = 0;
    for (var j = 0; j < this.trail.length; j++) {
        var p = this.trail[j];
        minX = Math.min(minX, p.x);
        maxX = Math.max(maxX, p.x);
        minY = Math.min(minY, p.y);
        maxY = Math.max(maxY, p.y);
    }

    minX = Math.max(0, minX - 18);
    maxX = Math.min(GRID_W - 1, maxX + 18);
    minY = Math.max(0, minY - 18);
    maxY = Math.min(GRID_H - 1, maxY + 18);

    var outside = new Uint8Array(GRID_W * GRID_H);
    var queue = [];

    for (var x = minX; x <= maxX; x++) {
        queue.push(minY * GRID_W + x);
        queue.push(maxY * GRID_W + x);
    }
    for (var y = minY; y <= maxY; y++) {
        queue.push(y * GRID_W + minX);
        queue.push(y * GRID_W + maxX);
    }

    while (queue.length > 0) {
        var idx = queue.pop();
        if (outside[idx]) continue;
        var cx = idx % GRID_W;
        var cy = Math.floor(idx / GRID_W);

        if (cx < minX || cx > maxX || cy < minY || cy > maxY) continue;
        if (boundary[idx] || grid[idx] === this.id) continue;

        outside[idx] = 1;

        if (cx > minX) queue.push(idx - 1);
        if (cx < maxX) queue.push(idx + 1);
        if (cy > minY) queue.push(idx - GRID_W);
        if (cy < maxY) queue.push(idx + GRID_W);
    }

    var capturedCount = 0;
    for (var py = minY; py <= maxY; py++) {
        for (var px = minX; px <= maxX; px++) {
            var cidx = py * GRID_W + px;
            if (!outside[cidx]) {
                if (grid[cidx] !== this.id) {
                    grid[cidx] = this.id;
                    flashGrid[cidx] = 1.0;
                    capturedCount++;
                }
            }
        }
    }

    for (var t = 0; t < this.trail.length; t++) {
        var trailIdx = this.trail[t].y * GRID_W + this.trail[t].x;
        grid[trailIdx] = this.id;
        flashGrid[trailIdx] = 1.0;
    }

    if (this.id === 1) {
        if (capturedCount > 5) {
            shakeAmount = Math.min(shakeAmount + 4, 10);
            if (callbacks && callbacks.onSound) {
                callbacks.onSound("push");
            }
        }
    }
};

Skimmer.prototype.die = function(reason, callbacks) {
    if (!this.alive) return;
    this.alive = false;

    for (var i = 0; i < 40; i++) {
        particles.push({
            x: this.x * 10 + 5,
            y: this.y * 10 + 5,
            vx: (Math.random() - 0.5) * 10,
            vy: (Math.random() - 0.5) * 10,
            color: this.colorDef.color,
            life: 1.0,
            decay: 0.025,
            size: 3.5 + Math.random() * 4
        });
    }

    // Clear territory
    for (var g = 0; g < grid.length; g++) {
        if (grid[g] === this.id) {
            grid[g] = 0;
            flashGrid[g] = 0.35;
        }
    }
    this.trail = [];

    if (this.id === 1) {
        triggerGameOver(reason, callbacks);
    } else {
        var livingBots = getLivingBotsCount();
        if (livingBots > 0) {
            setBanner("⚡ " + this.name + " Eliminated! " + livingBots + " rival" + (livingBots === 1 ? "" : "s") + " remain.", "kill");
        } else {
            setBanner("⚡ " + this.name + " Eliminated! All rivals defeated!", "win");
        }
        checkWinConditions(callbacks);
    }
};

// -----------------------------------------------------------------------------
// Advanced Bot AI Engine: Distinct Personas & Reactive Survival
// -----------------------------------------------------------------------------
Skimmer.prototype.updateBotAI = function() {
    this.botTimer--;
    this.loopSteps++;

    // Base candidate directions (no instant 180 reverse)
    var candidates = [
        { dx: 1, dy: 0 },
        { dx: -1, dy: 0 },
        { dx: 0, dy: 1 },
        { dx: 0, dy: -1 }
    ].filter(function(c) {
        return !(c.dx === -this.dx && c.dy === -this.dy);
    }.bind(this));

    // FILTER 1: Hard Wall & Self-Trail Collision Pruning
    var validCandidates = candidates.filter(function(c) {
        var nx = this.x + c.dx;
        var ny = this.y + c.dy;

        // Perimeter barrier check (give 1 cell margin)
        if (nx < 1 || nx >= GRID_W - 1 || ny < 1 || ny >= GRID_H - 1) return false;

        // Self-trail collision check
        for (var t = 0; t < this.trail.length; t++) {
            if (this.trail[t].x === nx && this.trail[t].y === ny) return false;
        }

        // Lookahead 2 steps: avoid running directly into a 1-tile dead end
        var nnx = nx + c.dx;
        var nny = ny + c.dy;
        if (nnx < 0 || nnx >= GRID_W || nny < 0 || nny >= GRID_H) return false;

        return true;
    }.bind(this));

    if (validCandidates.length === 0) {
        validCandidates = candidates.length > 0 ? candidates : [{ dx: 1, dy: 0 }];
    }

    // -------------------------------------------------------------------------
    // Threat Evaluation: Is any opponent closing in on our active trail?
    // -------------------------------------------------------------------------
    var isThreatened = false;
    var nearestThreatDist = 999;
    var closestThreat = null;

    if (this.trail.length > 0) {
        for (var i = 0; i < allEntities.length; i++) {
            var rival = allEntities[i];
            if (!rival.alive || rival === this) continue;

            // Check distance from rival's head to our trail points
            for (var tp = 0; tp < this.trail.length; tp++) {
                var dist = Math.abs(rival.x - this.trail[tp].x) + Math.abs(rival.y - this.trail[tp].y);
                if (dist < nearestThreatDist) {
                    nearestThreatDist = dist;
                    closestThreat = rival;
                }
            }
        }
        // If an opponent is within 7 cells of our trail, EMERGENCY!
        if (nearestThreatDist <= 7) {
            isThreatened = true;
            this.isBoosting = true; // Use Nitro to escape!
        } else {
            this.isBoosting = false;
        }
    }

    // Persona-based trail limits
    var maxSafeTrail = 14;
    if (this.persona === PERSONAS.SOLAR) maxSafeTrail = 10;        // Fortifier keeps loops very compact
    else if (this.persona === PERSONAS.VIPER) maxSafeTrail = 16;   // Hunter extends further for kills
    else if (this.persona === PERSONAS.JADE) maxSafeTrail = 12;    // Core seeker keeps moderate trail
    else if (this.persona === PERSONAS.VAPOR) maxSafeTrail = 15;   // Counter-attacker

    var mustReturnHome = isThreatened || (this.trail.length >= maxSafeTrail);

    // -------------------------------------------------------------------------
    // Candidate Scoring Pipeline
    // -------------------------------------------------------------------------
    var scoredCandidates = validCandidates.map(function(cand) {
        var score = 100;
        var nx = this.x + cand.dx;
        var ny = this.y + cand.dy;
        var isOwned = grid[ny * GRID_W + nx] === this.id;

        // 1. EMERGENCY OR FINISH LOOP: Head directly toward home territory
        if (mustReturnHome) {
            score += getBestHomeHeadingScore(this, nx, ny);
        } else {
            // 2. STRATEGIC PERSONA BEHAVIORS WHEN SAFE

            // --- VIPER: THE HUNTER ---
            if (this.persona === PERSONAS.VIPER) {
                var bestEnemyTrailDist = 999;
                for (var e = 0; e < allEntities.length; e++) {
                    var enemy = allEntities[e];
                    if (!enemy.alive || enemy === this || enemy.trail.length < 2) continue;

                    for (var et = 0; et < enemy.trail.length; et++) {
                        var d = Math.abs(nx - enemy.trail[et].x) + Math.abs(ny - enemy.trail[et].y);
                        if (d < bestEnemyTrailDist) bestEnemyTrailDist = d;
                    }
                }
                if (bestEnemyTrailDist < 25) {
                    score += (300 - bestEnemyTrailDist * 12);
                } else {
                    // Wander outward to find rivals
                    score += (Math.random() * 20);
                }
            }

            // --- SOLAR: THE TERRITORIAL FORTIFIER ---
            else if (this.persona === PERSONAS.SOLAR) {
                // Expands in tight rectangular phases (3 steps out, 3 steps across, return)
                if (this.trail.length === 0) {
                    // Leave territory into neutral
                    if (!isOwned) score += 50;
                } else if (this.trail.length >= 7) {
                    // Time to curve back home
                    score += getBestHomeHeadingScore(this, nx, ny);
                } else {
                    // Continue current heading
                    if (cand.dx === this.dx && cand.dy === this.dy) score += 35;
                }
            }

            // --- JADE: THE CORE SEEKER ---
            else if (this.persona === PERSONAS.JADE) {
                if (powerNodes.length > 0) {
                    var closestNodeDist = 999;
                    for (var p = 0; p < powerNodes.length; p++) {
                        var pDist = Math.abs(nx - powerNodes[p].x) + Math.abs(ny - powerNodes[p].y);
                        if (pDist < closestNodeDist) closestNodeDist = pDist;
                    }
                    score += (250 - closestNodeDist * 10);
                } else {
                    // Expand normally
                    if (!isOwned) score += 30;
                }
            }

            // --- VAPOR: THE COUNTER-ATTACKER ---
            else if (this.persona === PERSONAS.VAPOR) {
                // Look for enemies outside their base and interpose
                var targetRival = null;
                for (var r = 0; r < allEntities.length; r++) {
                    var rEnt = allEntities[r];
                    if (rEnt.alive && rEnt !== this && rEnt.trail.length > 3) {
                        targetRival = rEnt;
                        break;
                    }
                }
                if (targetRival) {
                    var distToHead = Math.abs(nx - targetRival.x) + Math.abs(ny - targetRival.y);
                    score += (220 - distToHead * 8);
                } else {
                    // Patrol neutral borders
                    if (cand.dx === this.dx && cand.dy === this.dy) score += 25;
                }
            }
        }

        // Slight momentum preference (discourage twitchy back-and-forth)
        if (cand.dx === this.dx && cand.dy === this.dy) {
            score += 15;
        }

        return { cand: cand, score: score };
    }.bind(this));

    // Sort by highest score
    scoredCandidates.sort(function(a, b) {
        return b.score - a.score;
    });

    var best = scoredCandidates[0].cand;
    if (best) {
        this.setDirection(best.dx, best.dy);
    }
};

function getBestHomeHeadingScore(skimmer, nx, ny) {
    if (grid[ny * GRID_W + nx] === skimmer.id) {
        return 1000; // Directly stepping into owned base closes the loop!
    }
    var bestDist = 999;
    for (var r = 1; r <= 10; r++) {
        var dirs = [
            { x: nx + r, y: ny }, { x: nx - r, y: ny },
            { x: nx, y: ny + r }, { x: nx, y: ny - r },
            { x: nx + r, y: ny + r }, { x: nx - r, y: ny - r },
            { x: nx + r, y: ny - r }, { x: nx - r, y: ny + r }
        ];
        for (var d = 0; d < dirs.length; d++) {
            var px = dirs[d].x, py = dirs[d].y;
            if (px >= 0 && px < GRID_W && py >= 0 && py < GRID_H) {
                if (grid[py * GRID_W + px] === skimmer.id) {
                    bestDist = r;
                    break;
                }
            }
        }
        if (bestDist < 999) break;
    }
    if (bestDist < 999) {
        return 500 - bestDist * 25;
    }
    var distToSpawn = Math.abs(nx - skimmer.startX) + Math.abs(ny - skimmer.startY);
    return 300 - distToSpawn * 12;
}

// -----------------------------------------------------------------------------
// Game Engine Lifecycle & Loop
// -----------------------------------------------------------------------------
function init(w, h) {
    resetGame();
}

function resize(w, h) {
    // Dynamic canvas dimension resize handled by QML Canvas
}

function resetGame() {
    grid.fill(0);
    flashGrid.fill(0);
    particles = [];
    powerNodes = [];
    shakeAmount = 0;
    gameState = "playing";
    endReason = "";
    cutsCount = 0;
    peakTurf = 0;
    tickCount = 0;
    startTime = Date.now();
    elapsedSeconds = 0;
    boostEnergy = 100;
    isBoosting = false;
    bannerTimer = 0;

    // 1. Player in the DEAD CENTER
    player = new Skimmer(1, "You", 45, 32, COLORS[1], false, "player");

    // 2. Four Rivals in the Four Outer Quadrants with Distinct Personas
    bots = [
        new Skimmer(2, "Viper", 14, 12, COLORS[2], true, PERSONAS.VIPER),         // Top-Left: Tail Hunter
        new Skimmer(3, "Solar", 76, 12, COLORS[3], true, PERSONAS.SOLAR),         // Top-Right: Territorial Fortifier
        new Skimmer(4, "Jade", 14, 52, COLORS[4], true, PERSONAS.JADE),           // Bottom-Left: Core Seeker
        new Skimmer(5, "Vapor", 76, 52, COLORS[5], true, PERSONAS.VAPOR)          // Bottom-Right: Counter-Attacker
    ];

    allEntities = [player, bots[0], bots[1], bots[2], bots[3]];

    // Initial power cores
    for (var i = 0; i < 4; i++) spawnPowerNode();

    setBanner("🏁 First to 50% Turf or Last Skimmer Standing Wins!", "info");
}

function spawnPowerNode() {
    if (powerNodes.length >= 6) return;
    var x = Math.floor(Math.random() * (GRID_W - 10)) + 5;
    var y = Math.floor(Math.random() * (GRID_H - 10)) + 5;
    powerNodes.push({ x: x, y: y, pulse: 0 });
}

function checkCollisions(callbacks) {
    for (var a = 0; a < allEntities.length; a++) {
        var attacker = allEntities[a];
        if (!attacker.alive) continue;

        for (var v = 0; v < allEntities.length; v++) {
            var victim = allEntities[v];
            if (!victim.alive || attacker === victim) continue;

            for (var t = 0; t < victim.trail.length; t++) {
                var pt = victim.trail[t];
                if (attacker.x === pt.x && attacker.y === pt.y) {
                    if (attacker.id === 1 && victim.id !== 1) {
                        cutsCount++;
                        shakeAmount = 10;
                        setBanner("⚔️ You severed " + victim.name + "'s tail!", "kill");
                        if (callbacks && callbacks.onSound) {
                            callbacks.onSound("dock");
                        }
                    } else if (attacker.id !== 1 && victim.id === 1) {
                        setBanner("💀 Your tail was severed by " + attacker.name + "!", "kill");
                    }

                    victim.die("Tail severed by " + attacker.name + ".", callbacks);
                    break;
                }
            }
        }
    }
}

function checkWinConditions(callbacks) {
    if (gameState !== "playing" || !player || !player.alive) return;

    var playerTurf = calculateTurf(1);
    var playerPercent = (playerTurf / (GRID_W * GRID_H)) * 100;
    peakTurf = Math.max(peakTurf, playerPercent);

    // WIN CONDITION 1: First to 50% territory (Instant Win)
    if (playerPercent >= 50.0) {
        triggerVictory("Dominance Victory! You reached " + playerPercent.toFixed(1) + "% territory (50% target achieved)!", callbacks);
        return;
    }

    // WIN CONDITION 2: Last skimmer standing on the board
    var livingBots = getLivingBotsCount();
    if (livingBots === 0) {
        triggerVictory("Last Skimmer Standing! All 4 rivals have been eliminated!", callbacks);
        return;
    }

    // DEFEAT CONDITION: Any rival bot reaches 50% territory first
    for (var b = 0; b < bots.length; b++) {
        var bot = bots[b];
        if (!bot.alive) continue;
        var bTurf = calculateTurf(bot.id);
        var bPercent = (bTurf / (GRID_W * GRID_H)) * 100;
        if (bPercent >= 50.0) {
            triggerGameOver(bot.name + " reached 50% grid dominance first!", callbacks);
            return;
        }
    }
}

function triggerVictory(reason, callbacks) {
    gameState = "won";
    endReason = reason;
    var turfPercent = ((calculateTurf(1) / (GRID_W * GRID_H)) * 100).toFixed(1);
    peakTurf = Math.max(peakTurf, parseFloat(turfPercent));

    // 160 Celebratory Confetti Particles
    for (var i = 0; i < 160; i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 3 + Math.random() * 10;
        particles.push({
            x: (GRID_W * 10) / 2,
            y: (GRID_H * 10) / 2,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd - 3,
            color: ["#facc15", "#38bdf8", "#34d399", "#f43f5e", "#c084fc"][Math.floor(Math.random() * 5)],
            life: 2.2,
            decay: 0.012,
            size: 4 + Math.random() * 5
        });
    }

    setBanner("🏆 VICTORY ACHIEVED!", "win");

    if (callbacks && callbacks.onSound) {
        callbacks.onSound("win");
    }
    if (callbacks && callbacks.onWin) {
        callbacks.onWin(peakTurf);
    }
}

function triggerGameOver(reason, callbacks) {
    gameState = "gameover";
    endReason = reason;

    if (callbacks && callbacks.onSound) {
        callbacks.onSound("game_over");
    }
    if (callbacks && callbacks.onGameOver) {
        callbacks.onGameOver();
    }
}

function calculateTurf(id) {
    var count = 0;
    for (var i = 0; i < grid.length; i++) {
        if (grid[i] === id) count++;
    }
    return count;
}

function getLivingBotsCount() {
    var count = 0;
    for (var i = 0; i < bots.length; i++) {
        if (bots[i].alive) count++;
    }
    return count;
}

// -----------------------------------------------------------------------------
// Frame Update (~60 FPS)
// -----------------------------------------------------------------------------
function update(dt, callbacks) {
    tickCount++;
    if (bannerTimer > 0) bannerTimer--;

    // Handle Boost Energy
    if (isBoosting && boostEnergy > 5 && gameState === "playing") {
        boostEnergy = Math.max(0, boostEnergy - 1.2);
    } else {
        boostEnergy = Math.min(100, boostEnergy + 0.35);
        if (boostEnergy <= 5) isBoosting = false;
    }

    // Spawn power nodes periodically
    if (tickCount % 240 === 0) spawnPowerNode();

    // Step simulation
    if (gameState === "playing") {
        elapsedSeconds = Math.floor((Date.now() - startTime) / 1000);

        for (var i = 0; i < allEntities.length; i++) {
            var ent = allEntities[i];
            if (!ent.alive) continue;

            var isHome = grid[ent.y * GRID_W + ent.x] === ent.id;
            var boosting = (ent.id === 1 && isBoosting) || (ent.isBot && ent.isBoosting);
            var speedFactor = boosting ? 1.8 : (isHome ? 1.35 : 1.0);

            ent.stepCounter += speedFactor;
            if (ent.stepCounter >= 3.0) {
                ent.stepCounter -= 3.0;
                ent.update(callbacks);
            }
        }

        checkCollisions(callbacks);
        checkWinConditions(callbacks);
    }

    // Flash grid decay
    for (var f = 0; f < flashGrid.length; f++) {
        if (flashGrid[f] > 0) flashGrid[f] = Math.max(0, flashGrid[f] - 0.05);
    }

    // Particle simulation
    for (var p = particles.length - 1; p >= 0; p--) {
        var part = particles[p];
        part.x += part.vx;
        part.y += part.vy;
        part.life -= part.decay;
        if (part.life <= 0) particles.splice(p, 1);
    }

    // Camera shake decay
    if (shakeAmount > 0) shakeAmount *= 0.88;
}

// -----------------------------------------------------------------------------
// Input Handler
// -----------------------------------------------------------------------------
function handleInput(action, callbacks) {
    if (!player || !player.alive) return;

    if (action === "up") {
        player.setDirection(0, -1);
    } else if (action === "down") {
        player.setDirection(0, 1);
    } else if (action === "left") {
        player.setDirection(-1, 0);
    } else if (action === "right") {
        player.setDirection(1, 0);
    } else if (action === "boost_on") {
        isBoosting = true;
    } else if (action === "boost_off") {
        isBoosting = false;
    }
}

// -----------------------------------------------------------------------------
// State Export for QML Canvas
// -----------------------------------------------------------------------------
function getState() {
    var playerTurf = calculateTurf(1);
    var playerPercent = (playerTurf / (GRID_W * GRID_H)) * 100;
    peakTurf = Math.max(peakTurf, playerPercent);

    var leaderboard = allEntities.map(function(e) {
        var turf = e.alive ? ((calculateTurf(e.id) / (GRID_W * GRID_H)) * 100) : 0;
        return {
            id: e.id,
            name: e.name,
            color: e.colorDef.color,
            turf: turf,
            alive: e.alive,
            persona: e.persona
        };
    }).sort(function(a, b) {
        return b.turf - a.turf;
    });

    return {
        gridW: GRID_W,
        gridH: GRID_H,
        gameState: gameState,
        endReason: endReason,
        playerPercent: playerPercent,
        peakTurf: peakTurf,
        targetGoal: 50.0,
        livingRivalsCount: getLivingBotsCount(),
        cutsCount: cutsCount,
        elapsedSeconds: elapsedSeconds,
        boostEnergy: boostEnergy,
        isBoosting: isBoosting,
        banner: getBanner(),
        playerStarted: player ? player.started : false,
        shakeAmount: shakeAmount,
        leaderboard: leaderboard,
        entities: allEntities,
        powerNodes: powerNodes,
        particles: particles,
        colors: COLORS,
        grid: grid,
        flashGrid: flashGrid
    };
}
