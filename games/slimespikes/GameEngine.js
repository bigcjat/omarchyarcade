// Omarchy Arcade: SlimeSpikes
// Fast-paced corridor gravity-flip runner featuring the iconic Japanese crane-game teardrop slime.
// Complete with organic squash & stretch spring physics, gooey particle splats, and 6 character variants.

.pragma library

// Virtual coordinate space
var width = 640;
var height = 720;

// Corridor boundaries (Center is [0, 0])
var CORRIDOR_HEIGHT = 280; // Distance between ceiling and floor
var FLOOR_Y = CORRIDOR_HEIGHT / 2;   // +140
var CEILING_Y = -CORRIDOR_HEIGHT / 2; // -140
var RUNNER_X = -140; // Fixed horizontal position of player in the scrolling corridor

// Game State
var gameState = "ready"; // "ready", "playing", "gameover"
var distance = 0;
var bestDistance = 0;
var gameTime = 0;
var currentSpeed = 380; // Pixels per second horizontal scroll
var baseSpeed = 380;
var maxSpeed = 780;
var screenShake = 0;
var isPaused = false;

// 6 Playable Slime Characters
var SLIME_CHARACTERS = {
    gooey: {
        id: "gooey",
        name: "GOOEY",
        tagline: "Classic Arcade Blue",
        color: "#0099FF",
        coreColor: "#33B0FF",
        glowColor: "#0077CC",
        mouthColor: "#880022",
        particleColor: "#33B5FF",
        hasWings: false,
        hasCrown: false,
        hasBlush: false
    },
    cherry: {
        id: "cherry",
        name: "CHERRY",
        tagline: "Coral Sweet She-Slime",
        color: "#FF3366",
        coreColor: "#FF5C85",
        glowColor: "#D91B4C",
        mouthColor: "#6B0520",
        particleColor: "#FF6699",
        hasWings: false,
        hasCrown: false,
        hasBlush: true
    },
    lime: {
        id: "lime",
        name: "LIME",
        tagline: "Electric Bubble Slime",
        color: "#10E070",
        coreColor: "#45F092",
        glowColor: "#08A850",
        mouthColor: "#004D25",
        particleColor: "#30FF85",
        hasWings: false,
        hasCrown: false,
        hasBlush: false
    },
    metal: {
        id: "metal",
        name: "METAL",
        tagline: "Mirror Chrome Slime",
        color: "#C0C8D8",
        coreColor: "#E4E8F0",
        glowColor: "#8E9AA8",
        mouthColor: "#404855",
        particleColor: "#DEE5F5",
        hasWings: false,
        hasCrown: false,
        hasBlush: false
    },
    gold: {
        id: "gold",
        name: "GOLD",
        tagline: "Radiant King Slime",
        color: "#FFB800",
        coreColor: "#FFD04D",
        glowColor: "#D49200",
        mouthColor: "#664200",
        particleColor: "#FFE066",
        hasWings: false,
        hasCrown: true,
        hasBlush: false
    },
    shadow: {
        id: "shadow",
        name: "SHADOW",
        tagline: "Midnight Phantom Slime",
        color: "#3B2D54",
        coreColor: "#58427C",
        glowColor: "#211832",
        mouthColor: "#9C27B0",
        particleColor: "#A855F7",
        hasWings: false,
        hasCrown: false,
        hasBlush: false
    }
};

var selectedCharacter = "gooey";

// Player Slime Entity & Squash/Stretch Springs
var slime = {
    x: RUNNER_X,
    y: FLOOR_Y - 18,
    targetY: FLOOR_Y - 18,
    vy: 0,
    gravity: 1, // 1 = floor, -1 = ceiling
    isGrounded: true,
    width: 38,
    height: 38,
    radius: 15,
    // Squash & stretch factors (1.0 = neutral)
    scaleX: 1.0,
    scaleY: 1.0,
    targetScaleX: 1.0,
    targetScaleY: 1.0,
    wobblePhase: 0,
    blinkTimer: 3.0,
    isBlinking: false,
    alive: true
};

// Spikes & Obstacles
var spikes = [];
var nextSpikeDist = 450; // Distance to spawn next spike pattern

// Particles & Droplets
var particles = [];
var floatingBadges = [];

function setPaused(p) {
    isPaused = !!p;
}

function selectCharacter(charId) {
    if (SLIME_CHARACTERS[charId]) {
        selectedCharacter = charId;
    }
}

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
    gameState = "playing";
    distance = 0;
    gameTime = 0;
    currentSpeed = baseSpeed;
    screenShake = 0;
    spikes = [];
    particles = [];
    floatingBadges = [];
    nextSpikeDist = 400;

    slime.y = FLOOR_Y - 18;
    slime.targetY = FLOOR_Y - 18;
    slime.vy = 0;
    slime.gravity = 1;
    slime.isGrounded = true;
    slime.scaleX = 1.0;
    slime.scaleY = 1.0;
    slime.targetScaleX = 1.0;
    slime.targetScaleY = 1.0;
    slime.wobblePhase = 0;
    slime.blinkTimer = 2.5;
    slime.isBlinking = false;
    slime.alive = true;
}

/**
 * Handle Gravity Flip Input
 */
function handleInput(action, callbacks) {
    if (gameState === "gameover" || gameState === "ready") {
        if (action === "flip" || action === "restart" || action === "action") {
            resetGame();
            if (callbacks && callbacks.onSound) callbacks.onSound("select");
            return;
        }
    }

    if (gameState === "playing" && slime.alive) {
        if (action === "flip" || action === "action" || action === "up" || action === "down") {
            flipGravity(callbacks);
        }
    }
}

function flipGravity(callbacks) {
    slime.gravity = -slime.gravity;
    slime.isGrounded = false;

    if (slime.gravity === -1) {
        // Launch toward ceiling
        slime.targetY = CEILING_Y + 18;
        slime.vy = -850;
        // Tensile vertical stretch on launch!
        slime.scaleY = 1.65;
        slime.scaleX = 0.62;
    } else {
        // Launch toward floor
        slime.targetY = FLOOR_Y - 18;
        slime.vy = 850;
        // Tensile vertical stretch on launch!
        slime.scaleY = 1.65;
        slime.scaleX = 0.62;
    }

    // Spawn gooey launch droplets
    var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;
    for (var i = 0; i < 6; i++) {
        particles.push({
            x: slime.x + (Math.random() - 0.5) * 16,
            y: slime.y + (slime.gravity === -1 ? 12 : -12),
            vx: -currentSpeed * 0.35 + (Math.random() - 0.5) * 60,
            vy: (slime.gravity === -1 ? 1 : -1) * (40 + Math.random() * 80),
            radius: 2 + Math.random() * 3,
            color: charData.particleColor,
            alpha: 1.0,
            life: 0.35 + Math.random() * 0.2
        });
    }

    if (callbacks && callbacks.onSound) {
        callbacks.onSound("move");
    }
}

/**
 * Main 60 FPS Engine Tick
 */
function update(dt, callbacks) {
    if (isPaused) return;

    if (screenShake > 0) {
        screenShake -= dt * 18;
        if (screenShake < 0) screenShake = 0;
    }

    if (gameState === "playing") {
        gameTime += dt;

        // Progressive speed ramp: speed increases smoothly with distance
        currentSpeed = Math.min(maxSpeed, baseSpeed + Math.sqrt(distance) * 5.2);
        var scrollDelta = currentSpeed * dt;
        distance += Math.round(scrollDelta * 0.12);

        if (distance > bestDistance) {
            bestDistance = distance;
        }

        // Milestone notifications
        if (distance > 0 && distance % 1000 < 5 && floatingBadges.length === 0) {
            addFloatingBadge(distance + "m SURGE!", slime.x, 0, "#FFD700", 1.4);
            if (callbacks && callbacks.onSound) callbacks.onSound("dock");
        }

        // 1. Update Slime Physics & Spring Deformation
        updateSlime(dt, callbacks);

        // 2. Spawn & Move Spikes
        updateSpikes(scrollDelta, dt);

        // 3. Check Collisions
        checkCollisions(callbacks);
    }

    // Update Particles
    for (var p = particles.length - 1; p >= 0; p--) {
        var pt = particles[p];
        pt.x += pt.vx * dt;
        pt.y += pt.vy * dt;
        pt.life -= dt;
        pt.alpha = Math.max(0, pt.life / 0.4);
        if (pt.life <= 0) {
            particles.splice(p, 1);
        }
    }

    // Update Floating Badges
    for (var b = floatingBadges.length - 1; b >= 0; b--) {
        var badge = floatingBadges[b];
        badge.y -= dt * 25;
        badge.timer -= dt;
        if (badge.timer <= 0) {
            floatingBadges.splice(b, 1);
        }
    }
}

function updateSlime(dt, callbacks) {
    slime.wobblePhase += dt * 14;

    // Blinking
    slime.blinkTimer -= dt;
    if (slime.blinkTimer <= 0) {
        if (!slime.isBlinking) {
            slime.isBlinking = true;
            slime.blinkTimer = 0.12;
        } else {
            slime.isBlinking = false;
            slime.blinkTimer = 2.0 + Math.random() * 3.5;
        }
    }

    if (!slime.isGrounded) {
        // Airborne trajectory towards target surface
        var distToTarget = slime.targetY - slime.y;
        var snapSpeed = 1600; // Fast responsive snap
        var moveStep = slime.gravity * snapSpeed * dt;

        if (Math.abs(distToTarget) <= Math.abs(moveStep)) {
            // Impact surface!
            slime.y = slime.targetY;
            slime.vy = 0;
            slime.isGrounded = true;

            // Pancake landing squash!
            slime.scaleX = 1.62;
            slime.scaleY = 0.52;

            // Landing splat particles
            var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;
            for (var i = 0; i < 8; i++) {
                particles.push({
                    x: slime.x + (Math.random() - 0.5) * 24,
                    y: slime.y + (slime.gravity === 1 ? 12 : -12),
                    vx: -currentSpeed * 0.3 + (Math.random() - 0.5) * 120,
                    vy: (slime.gravity === 1 ? -1 : 1) * (20 + Math.random() * 60),
                    radius: 2 + Math.random() * 2.5,
                    color: charData.particleColor,
                    alpha: 1.0,
                    life: 0.25 + Math.random() * 0.2
                });
            }

            if (callbacks && callbacks.onSound) {
                callbacks.onSound("step");
            }
        } else {
            slime.y += moveStep;
            // Airborne wobble
            slime.scaleX += (0.85 + Math.sin(slime.wobblePhase) * 0.15 - slime.scaleX) * 12 * dt;
            slime.scaleY += (1.20 - Math.sin(slime.wobblePhase) * 0.15 - slime.scaleY) * 12 * dt;
        }
    } else {
        // Grounded: Running / gliding on floor or ceiling
        // Rhythmic squish & stretch breathing bounce
        var bob = Math.sin(gameTime * 18);
        var groundTargetX = 1.08 + bob * 0.08;
        var groundTargetY = 0.92 - bob * 0.08;

        // Spring smoothly back to neutral gliding deformation
        slime.scaleX += (groundTargetX - slime.scaleX) * 15 * dt;
        slime.scaleY += (groundTargetY - slime.scaleY) * 15 * dt;

        // Gliding surface dust / slime droplets trailing behind
        if (Math.random() < 0.25) {
            var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;
            particles.push({
                x: slime.x - 12,
                y: slime.y + (slime.gravity === 1 ? 14 : -14),
                vx: -currentSpeed * 0.6 + (Math.random() - 0.5) * 30,
                vy: (Math.random() - 0.5) * 20,
                radius: 1.5 + Math.random() * 2,
                color: charData.particleColor,
                alpha: 0.8,
                life: 0.25 + Math.random() * 0.15
            });
        }
    }
}

/**
 * Procedural Spike Obstacle Generator
 */
function updateSpikes(scrollDelta, dt) {
    // Scroll existing spikes
    for (var s = spikes.length - 1; s >= 0; s--) {
        var sp = spikes[s];
        sp.x -= scrollDelta;
        if (sp.x < -width / 2 - 80) {
            spikes.splice(s, 1);
        }
    }

    // Spawn new spike waves
    nextSpikeDist -= scrollDelta;
    if (nextSpikeDist <= 0) {
        spawnSpikePattern();
    }
}

function spawnSpikePattern() {
    var startX = width / 2 + 60;
    var spikeW = 28;
    var spikeH = 44;

    // Pattern selection based on distance progression
    var r = Math.random();

    if (distance < 600) {
        // Early game: Single floor or ceiling spike with generous reaction time
        var isFloor = Math.random() > 0.5;
        spikes.push({
            x: startX,
            isFloor: isFloor,
            w: spikeW,
            h: spikeH
        });
        nextSpikeDist = 320 + Math.random() * 120;
    } else if (distance < 1500) {
        // Mid game: Alternating floor/ceiling zig-zags or double pairs
        if (r < 0.6) {
            // Staggered zig-zag (Floor then Ceiling)
            spikes.push({ x: startX, isFloor: true, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 160, isFloor: false, w: spikeW, h: spikeH });
            nextSpikeDist = 340 + Math.random() * 80;
        } else {
            // Double spike cluster on floor or ceiling
            var onFloor = Math.random() > 0.5;
            spikes.push({ x: startX, isFloor: onFloor, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 34, isFloor: onFloor, w: spikeW, h: spikeH });
            nextSpikeDist = 300 + Math.random() * 80;
        }
    } else {
        // High speed gauntlets: Rapid triplets, narrow flips, and alternating teeth
        if (r < 0.4) {
            // Rapid floor/ceiling rhythm (3 flips in quick succession)
            var fl = Math.random() > 0.5;
            spikes.push({ x: startX, isFloor: fl, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 130, isFloor: !fl, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 260, isFloor: fl, w: spikeW, h: spikeH });
            nextSpikeDist = 380;
        } else if (r < 0.75) {
            // Double cluster floor + ceiling obstacle
            spikes.push({ x: startX, isFloor: true, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 32, isFloor: true, w: spikeW, h: spikeH });
            spikes.push({ x: startX + 180, isFloor: false, w: spikeW, h: spikeH });
            nextSpikeDist = 320;
        } else {
            // Wide single spike with high speed
            var side = Math.random() > 0.5;
            spikes.push({ x: startX, isFloor: side, w: spikeW + 8, h: spikeH + 4 });
            nextSpikeDist = 240 + Math.random() * 60;
        }
    }
}

/**
 * Collision Detection
 */
function checkCollisions(callbacks) {
    if (!slime.alive) return;

    var sRadius = slime.radius * 0.85; // Slightly forgiving arcade hitbox
    var sx = slime.x;
    var sy = slime.y;

    for (var i = 0; i < spikes.length; i++) {
        var sp = spikes[i];

        // Horizontal proximity pre-check
        if (Math.abs(sp.x - sx) > sp.w + sRadius) continue;

        // Spike triangle coordinates
        var tipX = sp.x;
        var leftX = sp.x - sp.w / 2;
        var rightX = sp.x + sp.w / 2;
        var tipY, baseY;

        if (sp.isFloor) {
            baseY = FLOOR_Y;
            tipY = FLOOR_Y - sp.h;
        } else {
            baseY = CEILING_Y;
            tipY = CEILING_Y + sp.h;
        }

        // Check circle collision against triangle
        if (circleIntersectsTriangle(sx, sy, sRadius, leftX, baseY, rightX, baseY, tipX, tipY)) {
            triggerGameOver(callbacks);
            break;
        }
    }
}

function circleIntersectsTriangle(cx, cy, r, x1, y1, x2, y2, x3, y3) {
    // 1. Check if circle center is inside triangle
    if (pointInTriangle(cx, cy, x1, y1, x2, y2, x3, y3)) return true;

    // 2. Check if circle intersects any of the 3 edges
    if (lineIntersectsCircle(x1, y1, x2, y2, cx, cy, r)) return true;
    if (lineIntersectsCircle(x2, y2, x3, y3, cx, cy, r)) return true;
    if (lineIntersectsCircle(x3, y3, x1, y1, cx, cy, r)) return true;

    return false;
}

function pointInTriangle(px, py, x1, y1, x2, y2, x3, y3) {
    var d1 = sign(px, py, x1, y1, x2, y2);
    var d2 = sign(px, py, x2, y2, x3, y3);
    var d3 = sign(px, py, x3, y3, x1, y1);
    var hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    var hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(hasNeg && hasPos);
}

function sign(p1x, p1y, p2x, p2y, p3x, p3y) {
    return (p1x - p3x) * (p2y - p3y) - (p2x - p3x) * (p1y - p3y);
}

function lineIntersectsCircle(x1, y1, x2, y2, cx, cy, r) {
    var dx = x2 - x1;
    var dy = y2 - y1;
    var lenSq = dx * dx + dy * dy;
    var t = Math.max(0, Math.min(1, ((cx - x1) * dx + (cy - y1) * dy) / lenSq));
    var nearestX = x1 + t * dx;
    var nearestY = y1 + t * dy;
    var distSq = (cx - nearestX) * (cx - nearestX) + (cy - nearestY) * (cy - nearestY);
    return distSq <= r * r;
}

function triggerGameOver(callbacks) {
    slime.alive = false;
    gameState = "gameover";
    screenShake = 14;

    var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;

    // Burst of 28 gooey splatter droplets flying in all directions
    for (var i = 0; i < 28; i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 60 + Math.random() * 260;
        particles.push({
            x: slime.x,
            y: slime.y,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd,
            radius: 2 + Math.random() * 4,
            color: charData.particleColor,
            alpha: 1.0,
            life: 0.5 + Math.random() * 0.4
        });
    }

    addFloatingBadge("SPLAT!", slime.x, slime.y, "#FF3366", 1.5);

    if (callbacks) {
        if (callbacks.onSound) callbacks.onSound("explosion");
        if (callbacks.onGameOver) callbacks.onGameOver(distance);
    }
}

function addFloatingBadge(text, x, y, color, duration) {
    floatingBadges.push({
        text: text,
        x: x,
        y: y,
        color: color,
        duration: duration,
        timer: duration
    });
}

// =============================================================================
// RENDERING PIPELINE (Canvas 2D / 60 FPS)
// =============================================================================
function render(ctx, cw, ch, theme) {
    var themeAccent = (theme && theme.accent) ? theme.accent : "#00E5FF";
    var themeBorder = (theme && theme.border) ? theme.border : "#313244";
    var themeCardBg = (theme && theme.card_bg) ? theme.card_bg : "#1e1e2e";
    var themeFg = (theme && theme.fg) ? theme.fg : "#cdd6f4";

    ctx.save();
    ctx.clearRect(0, 0, cw, ch);

    // Screen Shake
    if (screenShake > 0) {
        var shakeX = (Math.random() - 0.5) * screenShake * 1.5;
        var shakeY = (Math.random() - 0.5) * screenShake * 1.5;
        ctx.translate(shakeX, shakeY);
    }

    // Camera Center
    ctx.translate(cw / 2, ch / 2);

    // 1. Background Grid & Corridor Guide Lines
    drawCorridor(ctx, cw, ch, theme);

    // 2. Triangular Spikes (Floor & Ceiling)
    drawSpikes(ctx, theme);

    // 3. Gooey Splatter Particles
    drawParticles(ctx);

    // 4. The Japanese Teardrop Slime (Player)
    if (slime.alive) {
        drawSlime(ctx, slime, selectedCharacter, themeAccent);
    }

    // 5. Floating Badges
    drawBadges(ctx);

    ctx.restore();
}

/**
 * Draw Horizontal Scrolling Corridor
 */
function drawCorridor(ctx, cw, ch, theme) {
    var halfW = cw / 2 + 40;

    // Corridor Background Fill (Slightly darker neon tint)
    ctx.fillStyle = "#0A0D14";
    ctx.fillRect(-halfW, CEILING_Y, halfW * 2, CORRIDOR_HEIGHT);

    // Subtle vertical speed stripes
    ctx.save();
    ctx.strokeStyle = "#161B26";
    ctx.lineWidth = 1;
    var stripeSpacing = 64;
    var stripeOffset = (gameTime * currentSpeed * 0.4) % stripeSpacing;
    for (var x = -halfW - stripeSpacing; x < halfW + stripeSpacing; x += stripeSpacing) {
        ctx.beginPath();
        ctx.moveTo(x - stripeOffset, CEILING_Y);
        ctx.lineTo(x - stripeOffset - 20, FLOOR_Y);
        ctx.stroke();
    }
    ctx.restore();

    // Floor and Ceiling Solid Rails
    ctx.lineWidth = 3.5;
    ctx.strokeStyle = "#384358";
    // Ceiling
    ctx.beginPath();
    ctx.moveTo(-halfW, CEILING_Y);
    ctx.lineTo(halfW, CEILING_Y);
    ctx.stroke();
    // Floor
    ctx.beginPath();
    ctx.moveTo(-halfW, FLOOR_Y);
    ctx.lineTo(halfW, FLOOR_Y);
    ctx.stroke();

    // Luminous Neon Laser Tracks along Floor and Ceiling
    ctx.lineWidth = 1.6;
    ctx.strokeStyle = "#00E5FF";
    ctx.globalAlpha = 0.65;
    ctx.beginPath();
    ctx.moveTo(-halfW, CEILING_Y);
    ctx.lineTo(halfW, CEILING_Y);
    ctx.moveTo(-halfW, FLOOR_Y);
    ctx.lineTo(halfW, FLOOR_Y);
    ctx.stroke();
    ctx.globalAlpha = 1.0;
}

/**
 * Draw Floor and Ceiling Hazard Spikes
 */
function drawSpikes(ctx, theme) {
    for (var i = 0; i < spikes.length; i++) {
        var sp = spikes[i];
        var baseY = sp.isFloor ? FLOOR_Y : CEILING_Y;
        var tipY = sp.isFloor ? (FLOOR_Y - sp.h) : (CEILING_Y + sp.h);

        ctx.save();

        // Spike body gradient
        var grad = ctx.createLinearGradient(0, baseY, 0, tipY);
        if (sp.isFloor) {
            grad.addColorStop(0, "#220810");
            grad.addColorStop(1, "#FF2A55");
        } else {
            grad.addColorStop(0, "#220810");
            grad.addColorStop(1, "#FF2A55");
        }

        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.moveTo(sp.x - sp.w / 2, baseY);
        ctx.lineTo(sp.x, tipY);
        ctx.lineTo(sp.x + sp.w / 2, baseY);
        ctx.closePath();
        ctx.fill();

        // Sharp Neon Glow Outline
        ctx.strokeStyle = "#FF3366";
        ctx.lineWidth = 2.0;
        ctx.stroke();

        // White razor-sharp highlight at the very tip
        ctx.fillStyle = "#FFFFFF";
        ctx.beginPath();
        ctx.arc(sp.x, tipY, 1.8, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
    }
}

/**
 * Draw the Japanese Crane-Game Teardrop Slime with Squash & Stretch
 */
function drawSlime(ctx, s, charId, themeAccent) {
    var charData = SLIME_CHARACTERS[charId] || SLIME_CHARACTERS.gooey;

    ctx.save();
    ctx.translate(s.x, s.y);

    // Flip vertically if on ceiling so the flat base rests on the ceiling
    ctx.scale(1, s.gravity);

    // Apply squash and stretch scaling around the base
    ctx.scale(s.scaleX, s.scaleY);

    var w = s.width;
    var h = s.height;

    // Crown for Gold Slime
    if (charData.hasCrown) {
        ctx.save();
        ctx.fillStyle = "#FFEE55";
        ctx.strokeStyle = "#D48800";
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(-7, -h * 0.48);
        ctx.lineTo(-9, -h * 0.68);
        ctx.lineTo(-3, -h * 0.58);
        ctx.lineTo(0, -h * 0.72);
        ctx.lineTo(3, -h * 0.58);
        ctx.lineTo(9, -h * 0.68);
        ctx.lineTo(7, -h * 0.48);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        // Little red jewel
        ctx.fillStyle = "#FF0044";
        ctx.beginPath();
        ctx.arc(0, -h * 0.52, 1.8, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }

    // 3. Teardrop Slime Outer Body (Bezier droplet geometry)
    ctx.beginPath();
    // Start at top pointy swirl tip
    ctx.moveTo(0, -h * 0.58);
    // Right side curve down to chubby right cheek
    ctx.bezierCurveTo(w * 0.18, -h * 0.35, w * 0.56, -h * 0.05, w * 0.52, h * 0.22);
    // Bottom rounded curve
    ctx.bezierCurveTo(w * 0.50, h * 0.54, -w * 0.50, h * 0.54, -w * 0.52, h * 0.22);
    // Left side curve back up to top pointy swirl tip
    ctx.bezierCurveTo(-w * 0.56, -h * 0.05, -w * 0.18, -h * 0.35, 0, -h * 0.58);
    ctx.closePath();

    // Body Fill: Radial Gelatinous Gradient
    var gelGrad = ctx.createRadialGradient(-w * 0.12, -h * 0.12, 2, 0, 0, w * 0.55);
    gelGrad.addColorStop(0, charData.coreColor);
    gelGrad.addColorStop(0.7, charData.color);
    gelGrad.addColorStop(1, charData.glowColor);
    ctx.fillStyle = gelGrad;
    ctx.fill();

    // Body Outline (Rich dark contour)
    ctx.strokeStyle = charData.glowColor;
    ctx.lineWidth = 2.2;
    ctx.stroke();

    // 4. Specular Curved Gloss Highlight (Upper-Left Droplet Sheen)
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(-w * 0.16, -h * 0.15, w * 0.16, h * 0.08, -0.6, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 255, 255, 0.45)";
    ctx.fill();
    // Secondary tiny gleam near tip
    ctx.beginPath();
    ctx.arc(-2, -h * 0.40, 2.2, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 255, 255, 0.55)";
    ctx.fill();
    ctx.restore();

    // Blush Cheeks (for Cherry)
    if (charData.hasBlush) {
        ctx.fillStyle = "rgba(255, 80, 120, 0.40)";
        // Left Blush
        ctx.beginPath();
        ctx.ellipse(-w * 0.30, h * 0.16, 4.5, 2.8, 0, 0, Math.PI * 2);
        ctx.fill();
        // Right Blush
        ctx.beginPath();
        ctx.ellipse(w * 0.30, h * 0.16, 4.5, 2.8, 0, 0, Math.PI * 2);
        ctx.fill();
    }

    // 6. The Goofy Round Slime Eyes
    var eyeY = h * 0.08;
    var leftEyeX = -w * 0.17;
    var rightEyeX = w * 0.17;
    var eyeR = 5.2;

    if (!s.isBlinking) {
        // White sclera
        ctx.fillStyle = "#FFFFFF";
        ctx.beginPath();
        ctx.arc(leftEyeX, eyeY, eyeR, 0, Math.PI * 2);
        ctx.arc(rightEyeX, eyeY, eyeR, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = "#1A2233";
        ctx.lineWidth = 1.0;
        ctx.stroke();

        // Dark Pupils (Looking forward with slight vertical look tracking gravity)
        var pupilOffsetX = 1.4;
        var pupilOffsetY = (s.isGrounded ? 0.2 : (s.gravity === -1 ? -1.0 : 1.0));
        ctx.fillStyle = "#111827";
        ctx.beginPath();
        ctx.arc(leftEyeX + pupilOffsetX, eyeY + pupilOffsetY, 2.4, 0, Math.PI * 2);
        ctx.arc(rightEyeX + pupilOffsetX, eyeY + pupilOffsetY, 2.4, 0, Math.PI * 2);
        ctx.fill();

        // Tiny white eye sparkle
        ctx.fillStyle = "#FFFFFF";
        ctx.beginPath();
        ctx.arc(leftEyeX + pupilOffsetX - 0.8, eyeY + pupilOffsetY - 0.8, 0.9, 0, Math.PI * 2);
        ctx.arc(rightEyeX + pupilOffsetX - 0.8, eyeY + pupilOffsetY - 0.8, 0.9, 0, Math.PI * 2);
        ctx.fill();
    } else {
        // Closed happy blinking arc eyes (^ ^)
        ctx.strokeStyle = "#111827";
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.arc(leftEyeX, eyeY + 1, 4.0, Math.PI, 0, false);
        ctx.arc(rightEyeX, eyeY + 1, 4.0, Math.PI, 0, false);
        ctx.stroke();
    }

    // 7. Cheerful Open Mouth (:D)
    ctx.save();
    ctx.fillStyle = charData.mouthColor;
    ctx.beginPath();
    ctx.arc(0, h * 0.24, 4.2, 0, Math.PI, false);
    ctx.closePath();
    ctx.fill();
    // Little pink tongue inside mouth
    ctx.fillStyle = "#FF7799";
    ctx.beginPath();
    ctx.arc(0, h * 0.27, 2.2, 0, Math.PI, false);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    ctx.restore();
}

/**
 * Draw Gooey Particles
 */
function drawParticles(ctx) {
    for (var i = 0; i < particles.length; i++) {
        var pt = particles[i];
        ctx.save();
        ctx.globalAlpha = pt.alpha;
        ctx.fillStyle = pt.color;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, pt.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

/**
 * Draw Floating Distance & Splat Badges
 */
function drawBadges(ctx) {
    for (var i = 0; i < floatingBadges.length; i++) {
        var b = floatingBadges[i];
        var alpha = Math.min(1.0, b.timer / 0.4);
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.font = "bold 16px sans-serif";
        ctx.fillStyle = b.color;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(b.text, b.x, b.y);
        ctx.restore();
    }
}
