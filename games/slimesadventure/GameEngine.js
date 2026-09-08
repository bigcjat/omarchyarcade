// Omarchy Arcade: Slime's Adventure
// Fast-paced subterranean cavern gravity-flip runner featuring the iconic Japanese teardrop slime.
// Complete with dough-rolling conveyor kinematics, squash & stretch spring physics, gooey particle splats, and 6 character variants.

.pragma library

// Virtual coordinate space
var width = 640;
var height = 720;

// Corridor boundaries (Center is [0, 0])
var CORRIDOR_HEIGHT = 280; // Distance between ceiling and floor
var FLOOR_Y = CORRIDOR_HEIGHT / 2;   // +140
var CEILING_Y = -CORRIDOR_HEIGHT / 2; // -140
var RUNNER_X = -140; // Fixed horizontal position of player in the scrolling corridor

// Physical Scaling:
// - Bat wingspan: ~27px ≈ 27cm (0.27m), standard cave microbat
// - Slime width: ~36px ≈ 36cm (0.36m), Japanese crane-game plushie
// - Cavern corridor height: 280px ≈ 2.8m (~9.2ft underground ceiling)
// => 100 pixels = 1.0 meter (base speed 380 px/s = 3.8 m/s ≈ 13.7 km/h)
var PIXELS_PER_METER = 100;
var gameState = "ready"; // "ready", "playing", "gameover"
var rawDistance = 0.0;
var distance = 0;
var bestDistance = 0;
var lastMilestoneBadge = 0;
var gameTime = 0;
var currentSpeed = 380; // Pixels per second horizontal scroll (3.8 m/s)
var baseSpeed = 380;
var maxSpeed = 780; // 7.8 m/s max sprint
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
    rollPhase: 0,
    blinkTimer: 3.0,
    isBlinking: false,
    alive: true
};

// Spikes & Stalactites/Stalagmites
var spikes = [];
var nextSpikeDist = 450; // Distance to spawn next spike pattern

// Particles & Droplets
var particles = [];
var floatingBadges = [];

// Cavern Atmospheric Environment & Creatures
var caveScroll = 0;
var caveBats = [];
var caveCritters = [];
var caveMotes = [];
var waterDrops = [];
var dropTimer = 0.5;

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
    rawDistance = 0.0;
    distance = 0;
    lastMilestoneBadge = 0;
    gameTime = 0;
    currentSpeed = baseSpeed;
    screenShake = 0;
    spikes = [];
    particles = [];
    floatingBadges = [];
    nextSpikeDist = 400;

    initCavern();

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
    slime.rollPhase = 0;
    slime.blinkTimer = 2.5;
    slime.isBlinking = false;
    slime.alive = true;
}

function initCavern() {
    caveScroll = 0;
    caveBats = [];
    caveCritters = [];
    caveMotes = [];
    waterDrops = [];
    dropTimer = 0.5;

    // 1. Drifting Bioluminescent Cave Spores / Motes
    for (var i = 0; i < 26; i++) {
        caveMotes.push({
            x: (Math.random() - 0.5) * (width + 120),
            y: CEILING_Y + 18 + Math.random() * (CORRIDOR_HEIGHT - 36),
            size: 1.2 + Math.random() * 2.2,
            alpha: 0.25 + Math.random() * 0.55,
            baseAlpha: 0.25 + Math.random() * 0.55,
            floatPhase: Math.random() * Math.PI * 2,
            floatFreq: 1.5 + Math.random() * 2.5,
            driftSpeed: 18 + Math.random() * 40,
            color: Math.random() > 0.4 ? "#00E5FF" : (Math.random() > 0.5 ? "#FFD700" : "#BA68C8")
        });
    }

    // 2. Flying Cave Bats
    caveBats.push({
        x: -width * 0.2,
        baseY: CEILING_Y + 45,
        y: CEILING_Y + 45,
        vx: -200,
        flySpeed: 200,
        size: 20,
        depth: 0.85,
        wingTimer: 0,
        flapSpeed: 22,
        swoopAmp: 16,
        swoopFreq: 2.4,
        t: 0,
        eyeColor: "#FF3366"
    });
    caveBats.push({
        x: width * 0.35,
        baseY: FLOOR_Y - 50,
        y: FLOOR_Y - 50,
        vx: -240,
        flySpeed: 240,
        size: 15,
        depth: 0.55,
        wingTimer: 1.2,
        flapSpeed: 26,
        swoopAmp: 12,
        swoopFreq: 3.1,
        t: 1.2,
        eyeColor: "#FFB800"
    });
    caveBats.push({
        x: width * 0.65,
        baseY: 0,
        y: 0,
        vx: -210,
        flySpeed: 210,
        size: 22,
        depth: 0.95,
        wingTimer: 2.4,
        flapSpeed: 20,
        swoopAmp: 22,
        swoopFreq: 1.8,
        t: 2.4,
        eyeColor: "#FF4081"
    });

    // 3. Cave Critters (Crevice Peepers & Ledge Squeakers)
    caveCritters.push({ type: "peeper", x: -160, y: CEILING_Y - 14, isFloor: false, color: "#FFB800", blinkTimer: 2.5, isBlinking: false });
    caveCritters.push({ type: "peeper", x: 60, y: FLOOR_Y + 14, isFloor: true, color: "#10E070", blinkTimer: 3.8, isBlinking: false });
    caveCritters.push({ type: "peeper", x: 260, y: CEILING_Y - 12, isFloor: false, color: "#BA68C8", blinkTimer: 1.9, isBlinking: false });
    caveCritters.push({ type: "peeper", x: 420, y: FLOOR_Y + 15, isFloor: true, color: "#FF3366", blinkTimer: 4.2, isBlinking: false });

    // Cute Ledge Squeakers (Little fuzzy monsters perched on background rock ledges)
    caveCritters.push({ type: "squeaker", x: -80, y: CEILING_Y + 2, color: "#38294A", hopPhase: 0, blinkTimer: 3.1, isBlinking: false });
    caveCritters.push({ type: "squeaker", x: 210, y: FLOOR_Y - 2, color: "#2B3A4A", hopPhase: 1.8, blinkTimer: 2.4, isBlinking: false });
    caveCritters.push({ type: "squeaker", x: 380, y: CEILING_Y + 2, color: "#4A2B3A", hopPhase: 3.5, blinkTimer: 4.0, isBlinking: false });
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
            maxLife: 0.35,
            life: 0.35 + Math.random() * 0.2
        });
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

        // Progressive speed ramp: speed increases smoothly with actual distance traveled
        // Base: 380 px/s (3.8 m/s = 13.7 km/h) -> Max: 780 px/s (7.8 m/s = 28.0 km/h)
        currentSpeed = Math.min(maxSpeed, baseSpeed + Math.sqrt(rawDistance) * 16.0);
        var scrollDelta = currentSpeed * dt;
        rawDistance += scrollDelta / PIXELS_PER_METER;
        distance = Math.floor(rawDistance);

        if (distance > bestDistance) {
            bestDistance = distance;
        }

        // Milestone notifications every 100m
        if (distance > 0 && distance % 100 === 0 && (distance - lastMilestoneBadge) >= 100) {
            lastMilestoneBadge = distance;
            addFloatingBadge(distance + "m SURGE!", slime.x, 0, "#FFD700", 1.4);
            if (callbacks && callbacks.onSound) callbacks.onSound("dock");
        }

        // 1. Update Cavern Environment & Creatures
        updateCavern(dt, scrollDelta);

        // 2. Update Slime Physics & Spring Deformation
        updateSlime(dt, callbacks, scrollDelta);

        // 3. Spawn & Move Spikes
        updateSpikes(scrollDelta, dt);

        // 4. Check Collisions
        checkCollisions(callbacks);
    } else {
        updateCavern(dt, 0);
    }

    // Update Particles
    for (var p = particles.length - 1; p >= 0; p--) {
        var pt = particles[p];
        if (pt.isPuddle) {
            pt.life -= dt;
            pt.radius = Math.min(pt.maxRadius, pt.radius + dt * 24);
            pt.alpha = Math.max(0, pt.life / pt.maxLife);
        } else {
            pt.x += pt.vx * dt;
            pt.y += pt.vy * dt;
            if (pt.gravity) {
                pt.vy += pt.gravity * dt;
            }
            if (pt.isLiquid) {
                // Splash into liquid puddles on floor or ceiling
                if (pt.y >= FLOOR_Y - 2) {
                    pt.y = FLOOR_Y;
                    pt.isPuddle = true;
                    pt.maxRadius = pt.radius * 2.8;
                    pt.maxLife = 2.5;
                    pt.life = pt.maxLife;
                    pt.vx = 0;
                    pt.vy = 0;
                } else if (pt.y <= CEILING_Y + 2) {
                    pt.y = CEILING_Y;
                    pt.isPuddle = true;
                    pt.maxRadius = pt.radius * 2.8;
                    pt.maxLife = 2.5;
                    pt.life = pt.maxLife;
                    pt.vx = 0;
                    pt.vy = 0;
                }
            }
            if (pt.vRot) {
                pt.rot = (pt.rot || 0) + pt.vRot * dt;
            }
            pt.life -= dt;
            pt.alpha = Math.max(0, pt.life / pt.maxLife);
        }
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

function updateCavern(dt, scrollDelta) {
    caveScroll += scrollDelta;
    var halfW = width / 2 + 80;

    // 1. Drifting Bioluminescent Spores / Motes
    for (var m = 0; m < caveMotes.length; m++) {
        var mt = caveMotes[m];
        mt.floatPhase += dt * mt.floatFreq;
        mt.x -= (scrollDelta * 0.25 + mt.driftSpeed * dt);
        mt.y += Math.sin(mt.floatPhase) * 12 * dt;
        mt.alpha = mt.baseAlpha + Math.sin(mt.floatPhase * 1.5) * 0.15;

        if (mt.x < -halfW) {
            mt.x = halfW + Math.random() * 40;
            mt.y = CEILING_Y + 18 + Math.random() * (CORRIDOR_HEIGHT - 36);
        }
    }

    // 2. Flying Cave Bats
    for (var b = 0; b < caveBats.length; b++) {
        var bat = caveBats[b];
        bat.t += dt;
        bat.wingTimer += dt * bat.flapSpeed;
        bat.x -= (scrollDelta * bat.depth + bat.flySpeed * dt);
        bat.y = bat.baseY + Math.sin(bat.t * bat.swoopFreq) * bat.swoopAmp;

        if (bat.x < -halfW - 60) {
            bat.x = halfW + 60 + Math.random() * 150;
            bat.baseY = CEILING_Y + 30 + Math.random() * (CORRIDOR_HEIGHT - 60);
            bat.flySpeed = 160 + Math.random() * 120;
            bat.depth = 0.5 + Math.random() * 0.5;
            bat.size = 15 + Math.random() * 9;
            bat.swoopAmp = 12 + Math.random() * 18;
            bat.swoopFreq = 1.8 + Math.random() * 1.8;
            bat.flapSpeed = 18 + Math.random() * 10;
        }
    }

    // 3. Cave Critters (Crevice Peepers & Ledge Squeakers)
    for (var c = 0; c < caveCritters.length; c++) {
        var cr = caveCritters[c];
        cr.x -= scrollDelta;
        cr.blinkTimer -= dt;
        if (cr.blinkTimer <= 0) {
            if (!cr.isBlinking) {
                cr.isBlinking = true;
                cr.blinkTimer = 0.14;
            } else {
                cr.isBlinking = false;
                cr.blinkTimer = 2.0 + Math.random() * 4.0;
            }
        }
        if (cr.type === "squeaker") {
            cr.hopPhase += dt * 3.5;
        }

        if (cr.x < -halfW - 80) {
            cr.x = halfW + 80 + Math.random() * 180;
        }
    }

    // 4. Water Droplets dripping from ceiling stalactites
    dropTimer -= dt;
    if (dropTimer <= 0) {
        dropTimer = 0.45 + Math.random() * 0.65;
        for (var s = 0; s < spikes.length; s++) {
            var sp = spikes[s];
            if (!sp.isFloor && sp.x > -halfW + 40 && sp.x < halfW - 40) {
                if (Math.random() < 0.45) {
                    waterDrops.push({
                        x: sp.x,
                        y: CEILING_Y + sp.h,
                        vy: 40,
                        isFalling: true,
                        splashTimer: 0,
                        splashRadius: 0
                    });
                    break;
                }
            }
        }
    }

    for (var d = waterDrops.length - 1; d >= 0; d--) {
        var dp = waterDrops[d];
        if (dp.isFalling) {
            dp.vy += 700 * dt;
            dp.y += dp.vy * dt;
            if (dp.y >= FLOOR_Y) {
                dp.y = FLOOR_Y;
                dp.isFalling = false;
                dp.splashTimer = 0.22;
            }
        } else {
            dp.splashTimer -= dt;
            dp.splashRadius += dt * 35;
            if (dp.splashTimer <= 0) {
                waterDrops.splice(d, 1);
            }
        }
    }
}

function updateSlime(dt, callbacks, scrollDelta) {
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
            slime.scaleX = 1.55;
            slime.scaleY = 0.55;

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
                    maxLife: 0.35,
                    life: 0.25 + Math.random() * 0.2
                });
            }

            if (callbacks && callbacks.onSound) {
                callbacks.onSound("slime_land");
            }
        } else {
            slime.y += moveStep;
            // Airborne recoil: body stretches vertically in flight
            slime.scaleX += (0.88 + Math.sin(slime.wobblePhase) * 0.08 - slime.scaleX) * 14 * dt;
            slime.scaleY += (1.18 - Math.sin(slime.wobblePhase) * 0.08 - slime.scaleY) * 14 * dt;
        }
    } else {
        // Grounded: Continuous Dough-Rolling / Tank Tread Conveyor Motion
        var sDelta = (scrollDelta !== undefined ? scrollDelta : currentSpeed * dt);
        // Roll phase advances directly with ground travel
        slime.rollPhase = (slime.rollPhase || 0) + sDelta * 0.085;

        // Dynamic kneading squash & stretch rhythm (dough breathing into itself)
        var kneadCycle = Math.sin(slime.rollPhase * 1.2);
        var targetScaleX = 1.05 + kneadCycle * 0.07;
        var targetScaleY = 0.95 - kneadCycle * 0.05;

        slime.scaleX += (targetScaleX - slime.scaleX) * 14 * dt;
        slime.scaleY += (targetScaleY - slime.scaleY) * 14 * dt;

        // Micro-droplets at the rolling contact zone
        if (Math.random() < 0.12) {
            var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;
            particles.push({
                x: slime.x - slime.width * 0.35 + (Math.random() - 0.5) * 8,
                y: slime.y + (slime.gravity === 1 ? 14 : -14),
                vx: -currentSpeed * 0.35 + (Math.random() - 0.5) * 20,
                vy: (slime.gravity === 1 ? -1 : 1) * (Math.random() * 10),
                radius: 1.0 + Math.random() * 1.5,
                color: charData.particleColor,
                alpha: 0.7,
                maxLife: 0.25,
                life: 0.2
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

function createSpike(x, isFloor, w, h) {
    var colors = ["#00E5FF", "#FF3366", "#FFD700", "#76FF03", "#A855F7", "#FF9100"];
    return {
        x: x,
        isFloor: isFloor,
        w: w,
        h: h,
        crystalColor: colors[Math.floor(Math.random() * colors.length)]
    };
}

function spawnSpikePattern() {
    var startX = width / 2 + 60;
    var spikeW = 32;
    var spikeH = 52;

    // Pattern selection based on distance progression
    var r = Math.random();

    if (distance < 50) {
        // Early game (0-50m, ~13s): Single floor or ceiling spike with generous reaction time
        var isFloor = Math.random() > 0.5;
        spikes.push(createSpike(startX, isFloor, spikeW, spikeH));
        nextSpikeDist = 320 + Math.random() * 120;
    } else if (distance < 140) {
        // Mid game (50-140m): Alternating floor/ceiling zig-zags or double pairs
        if (r < 0.6) {
            // Staggered zig-zag (Floor then Ceiling)
            spikes.push(createSpike(startX, true, spikeW, spikeH));
            spikes.push(createSpike(startX + 160, false, spikeW, spikeH));
            nextSpikeDist = 340 + Math.random() * 80;
        } else {
            // Double spike cluster on floor or ceiling
            var onFloor = Math.random() > 0.5;
            spikes.push(createSpike(startX, onFloor, spikeW, spikeH));
            spikes.push(createSpike(startX + 34, onFloor, spikeW, spikeH));
            nextSpikeDist = 300 + Math.random() * 80;
        }
    } else {
        // High speed gauntlets: Rapid triplets, narrow flips, and alternating teeth
        if (r < 0.4) {
            // Rapid floor/ceiling rhythm (3 flips in quick succession)
            var fl = Math.random() > 0.5;
            spikes.push(createSpike(startX, fl, spikeW, spikeH));
            spikes.push(createSpike(startX + 130, !fl, spikeW, spikeH));
            spikes.push(createSpike(startX + 260, fl, spikeW, spikeH));
            nextSpikeDist = 380;
        } else if (r < 0.75) {
            // Double cluster floor + ceiling obstacle
            spikes.push(createSpike(startX, true, spikeW, spikeH));
            spikes.push(createSpike(startX + 32, true, spikeW, spikeH));
            spikes.push(createSpike(startX + 180, false, spikeW, spikeH));
            nextSpikeDist = 320;
        } else {
            // Wide single spike with high speed
            var side = Math.random() > 0.5;
            spikes.push(createSpike(startX, side, spikeW + 8, spikeH + 4));
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
    screenShake = 16;

    var charData = SLIME_CHARACTERS[selectedCharacter] || SLIME_CHARACTERS.gooey;

    // 1. Torn slime membrane skin shards peeling open and spinning outward
    for (var s = 0; s < 8; s++) {
        var sAngle = (s / 8) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
        var sSpeed = 70 + Math.random() * 160;
        particles.push({
            isShard: true,
            x: slime.x,
            y: slime.y,
            vx: Math.cos(sAngle) * sSpeed - currentSpeed * 0.3,
            vy: Math.sin(sAngle) * sSpeed,
            gravity: 400,
            rot: Math.random() * Math.PI * 2,
            vRot: (Math.random() - 0.5) * 14,
            radius: 6 + Math.random() * 6,
            color: charData.color,
            alpha: 1.0,
            maxLife: 1.2,
            life: 0.9 + Math.random() * 0.4
        });
    }

    // 2. High-energy viscous liquid spill & droplet fountain (60+ gelatinous blobs)
    for (var i = 0; i < 60; i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 60 + Math.random() * 320;
        var dropRadius = 2.0 + Math.random() * 4.8;
        particles.push({
            isLiquid: true,
            x: slime.x + (Math.random() - 0.5) * 14,
            y: slime.y + (Math.random() - 0.5) * 14,
            vx: Math.cos(angle) * spd - currentSpeed * 0.4,
            vy: Math.sin(angle) * spd,
            gravity: 650, // Gravity pulls spilled liquid down
            radius: dropRadius,
            color: Math.random() < 0.35 ? charData.particleColor : charData.color,
            alpha: 1.0,
            maxLife: 1.8,
            life: 0.8 + Math.random() * 1.0
        });
    }

    // 3. Central impact slime puddle where it struck
    particles.push({
        isPuddle: true,
        x: slime.x,
        y: slime.y,
        radius: 12,
        maxRadius: 26,
        color: charData.color,
        alpha: 1.0,
        maxLife: 2.5,
        life: 2.5
    });

    addFloatingBadge("SPLAT!", slime.x, slime.y, "#FF3366", 1.5);

    if (callbacks) {
        if (callbacks.onSound) callbacks.onSound("slime_burst");
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

    // 1. Subterranean Cavern Backdrop, Rock Ledges & Ambient Spores
    drawCavern(ctx, cw, ch, theme);

    // 2. Water Drops from Ceiling Stalactites
    drawWaterDrips(ctx);

    // 3. Stalactites & Stalagmites (Ceiling & Floor Hazards)
    drawStalactitesAndStalagmites(ctx, theme);

    // 4. Midground Flying Bats
    drawMidgroundBats(ctx);

    // 5. Gooey Splatter Particles
    drawParticles(ctx);

    // 6. The Japanese Teardrop Slime (Player)
    if (slime.alive) {
        drawSlime(ctx, slime, selectedCharacter, themeAccent);
    }

    // 7. Floating Badges
    drawBadges(ctx);

    ctx.restore();
}

/**
 * Cavern Atmospheric Renderer
 */
function drawCavern(ctx, cw, ch, theme) {
    var halfW = cw / 2 + 60;
    var halfH = ch / 2 + 60;

    // 1. Subterranean Ambient Gradient (Full Screen)
    var bgGrad = ctx.createLinearGradient(0, -halfH, 0, halfH);
    bgGrad.addColorStop(0, "#08050E");
    bgGrad.addColorStop(0.35, "#140D22");
    bgGrad.addColorStop(0.5, "#1A122B");
    bgGrad.addColorStop(0.65, "#140D22");
    bgGrad.addColorStop(1, "#08050E");
    ctx.fillStyle = bgGrad;
    ctx.fillRect(-halfW, -halfH, halfW * 2, halfH * 2);

    // 2. Parallax Distant Rock Formations (Layer 1 - deep background, 0.12x scroll)
    drawParallaxCaveLayer(ctx, halfW, 0.12, 120, "#100B1C", "#0D0817", 0.6);

    // 3. Parallax Midground Cavern Pillars & Arches (Layer 2 - 0.28x scroll)
    drawParallaxCaveLayer(ctx, halfW, 0.28, 80, "#1C142E", "#150F24", 0.8);

    // 4. Distant Bats (depth < 0.7)
    for (var b = 0; b < caveBats.length; b++) {
        if (caveBats[b].depth < 0.7) {
            drawBat(ctx, caveBats[b]);
        }
    }

    // 5. Drifting Bioluminescent Spores / Motes
    drawCaveMotes(ctx);

    // 6. Solid Ceiling and Floor Rock Masses
    drawCavernLedges(ctx, cw, ch, halfW, halfH);

    // 7. Cave Critters (Crevice Peepers & Ledge Squeakers)
    for (var c = 0; c < caveCritters.length; c++) {
        drawCaveCritter(ctx, caveCritters[c]);
    }
}

function drawParallaxCaveLayer(ctx, halfW, speedFactor, segmentW, colorTop, colorBottom, alpha) {
    ctx.save();
    ctx.globalAlpha = alpha;
    var scroll = (caveScroll * speedFactor) % (segmentW * 4);

    // Background Stalactite / Arch silhouettes from ceiling
    ctx.fillStyle = colorTop;
    ctx.beginPath();
    ctx.moveTo(-halfW - segmentW, CEILING_Y);
    for (var x = -halfW - segmentW; x <= halfW + segmentW * 2; x += segmentW) {
        var px = x - scroll;
        var h1 = 28 + Math.sin(x * 0.05) * 22;
        var h2 = 55 + Math.cos(x * 0.08) * 35;
        var h3 = 38 + Math.sin(x * 0.03) * 20;
        ctx.lineTo(px + segmentW * 0.25, CEILING_Y + h1);
        ctx.lineTo(px + segmentW * 0.5, CEILING_Y + h2);
        ctx.lineTo(px + segmentW * 0.75, CEILING_Y + h3);
        ctx.lineTo(px + segmentW, CEILING_Y);
    }
    ctx.lineTo(halfW + segmentW * 2, -halfW);
    ctx.lineTo(-halfW - segmentW, -halfW);
    ctx.closePath();
    ctx.fill();

    // Background Stalagmite / Ridge silhouettes from floor
    ctx.fillStyle = colorBottom;
    ctx.beginPath();
    ctx.moveTo(-halfW - segmentW, FLOOR_Y);
    for (var fx = -halfW - segmentW; fx <= halfW + segmentW * 2; fx += segmentW) {
        var fpx = fx - scroll;
        var fh1 = 25 + Math.cos(fx * 0.06) * 20;
        var fh2 = 50 + Math.sin(fx * 0.07) * 32;
        var fh3 = 32 + Math.cos(fx * 0.04) * 18;
        ctx.lineTo(fpx + segmentW * 0.25, FLOOR_Y - fh1);
        ctx.lineTo(fpx + segmentW * 0.5, FLOOR_Y - fh2);
        ctx.lineTo(fpx + segmentW * 0.75, FLOOR_Y - fh3);
        ctx.lineTo(fpx + segmentW, FLOOR_Y);
    }
    ctx.lineTo(halfW + segmentW * 2, halfW);
    ctx.lineTo(-halfW - segmentW, halfW);
    ctx.closePath();
    ctx.fill();

    ctx.restore();
}

function drawCavernLedges(ctx, cw, ch, halfW, halfH) {
    // 1. Solid Ceiling Rock Mass (from top of screen to CEILING_Y)
    var ceilGrad = ctx.createLinearGradient(0, -halfH, 0, CEILING_Y);
    ceilGrad.addColorStop(0, "#08050E");
    ceilGrad.addColorStop(0.55, "#150F22");
    ceilGrad.addColorStop(1, "#221A33");

    ctx.fillStyle = ceilGrad;
    ctx.fillRect(-halfW, -halfH, halfW * 2, CEILING_Y + halfH);

    // 2. Solid Floor Rock Mass (from FLOOR_Y to bottom of screen)
    var floorGrad = ctx.createLinearGradient(0, FLOOR_Y, 0, halfH);
    floorGrad.addColorStop(0, "#221A33");
    floorGrad.addColorStop(0.45, "#150F22");
    floorGrad.addColorStop(1, "#08050E");

    ctx.fillStyle = floorGrad;
    ctx.fillRect(-halfW, FLOOR_Y, halfW * 2, halfH - FLOOR_Y);

    // 3. Subterranean Geological Rock Strata & Mineral Seams
    ctx.strokeStyle = "rgba(74, 56, 108, 0.4)";
    ctx.lineWidth = 2.0;

    // Ceiling strata
    ctx.beginPath();
    ctx.moveTo(-halfW, CEILING_Y - 30);
    for (var bx = -halfW; bx <= halfW; bx += 36) {
        ctx.lineTo(bx, CEILING_Y - 30 + Math.sin((bx + caveScroll * 0.7) * 0.05) * 6);
    }
    ctx.stroke();

    ctx.strokeStyle = "rgba(100, 75, 145, 0.25)";
    ctx.beginPath();
    ctx.moveTo(-halfW, CEILING_Y - 65);
    for (var bx2 = -halfW; bx2 <= halfW; bx2 += 44) {
        ctx.lineTo(bx2, CEILING_Y - 65 + Math.cos((bx2 + caveScroll * 0.6) * 0.04) * 8);
    }
    ctx.stroke();

    // Floor strata
    ctx.strokeStyle = "rgba(74, 56, 108, 0.4)";
    ctx.lineWidth = 2.0;
    ctx.beginPath();
    ctx.moveTo(-halfW, FLOOR_Y + 30);
    for (var fbx = -halfW; fbx <= halfW; fbx += 36) {
        ctx.lineTo(fbx, FLOOR_Y + 30 + Math.sin((fbx + caveScroll * 0.7) * 0.05) * 6);
    }
    ctx.stroke();

    ctx.strokeStyle = "rgba(100, 75, 145, 0.25)";
    ctx.beginPath();
    ctx.moveTo(-halfW, FLOOR_Y + 65);
    for (var fbx2 = -halfW; fbx2 <= halfW; fbx2 += 44) {
        ctx.lineTo(fbx2, FLOOR_Y + 65 + Math.cos((fbx2 + caveScroll * 0.6) * 0.04) * 8);
    }
    ctx.stroke();

    // 4. Hanging Cave Roots & Creeping Vines from Ceiling
    ctx.strokeStyle = "#382946";
    ctx.lineWidth = 1.5;
    var vineStep = 64;
    var vineScroll = (caveScroll * 0.95) % vineStep;
    for (var vx = -halfW - vineStep; vx <= halfW + vineStep; vx += vineStep) {
        var rootX = vx - vineScroll;
        var rootLen = 14 + Math.sin(vx * 0.2) * 8;
        ctx.beginPath();
        ctx.moveTo(rootX, CEILING_Y);
        ctx.quadraticCurveTo(rootX + 4, CEILING_Y + rootLen * 0.5, rootX - 2, CEILING_Y + rootLen);
        ctx.stroke();
    }

    // 5. Rocky Ledge Rims (Solid stone edge)
    ctx.strokeStyle = "#4D3D6A";
    ctx.lineWidth = 3.5;
    ctx.beginPath();
    ctx.moveTo(-halfW, CEILING_Y);
    ctx.lineTo(halfW, CEILING_Y);
    ctx.moveTo(-halfW, FLOOR_Y);
    ctx.lineTo(halfW, FLOOR_Y);
    ctx.stroke();

    // 6. Emerald Cavern Moss & Lichen along walking surfaces
    ctx.fillStyle = "#2D6648";
    var mossStep = 18;
    var mossScroll = (caveScroll) % mossStep;
    for (var mx = -halfW - mossStep; mx <= halfW + mossStep; mx += mossStep) {
        var xpos = mx - mossScroll;
        var tuftH = 2.5 + Math.sin(mx * 0.3) * 1.5;
        ctx.fillRect(xpos, FLOOR_Y - tuftH, mossStep * 0.7, tuftH);
        var ceilTuftH = 2.5 + Math.cos(mx * 0.3) * 1.5;
        ctx.fillRect(xpos, CEILING_Y, mossStep * 0.7, ceilTuftH);
    }

    // Glowing subtle lichen dots (bioluminescent green specks)
    ctx.fillStyle = "#6BFF9A";
    for (var gx = -halfW - mossStep; gx <= halfW + mossStep; gx += mossStep * 2) {
        var dotX = gx - mossScroll + 4;
        ctx.fillRect(dotX, FLOOR_Y - 3.5, 2, 2);
        ctx.fillRect(dotX + 6, CEILING_Y + 1.5, 2, 2);
    }

    // 7. Bioluminescent Cave Mushrooms sprouting in clusters
    var mushStep = 210;
    var mushScroll = (caveScroll) % mushStep;
    for (var ms = -halfW - mushStep; ms <= halfW + mushStep; ms += mushStep) {
        var mX = ms - mushScroll + 18;
        var mColor = (Math.abs(ms) % 420 === 0) ? "#00E5FF" : "#FF4081";

        // Floor Mushroom
        ctx.fillStyle = "#A89AC2";
        ctx.fillRect(mX - 1, FLOOR_Y - 7, 2, 7); // Stem
        ctx.fillStyle = mColor;
        ctx.beginPath();
        ctx.arc(mX, FLOOR_Y - 7, 4.5, Math.PI, 0); // Cap
        ctx.closePath();
        ctx.fill();

        // Mushroom Soft Glow
        ctx.fillStyle = mColor;
        ctx.globalAlpha = 0.25;
        ctx.beginPath();
        ctx.arc(mX, FLOOR_Y - 7, 9, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1.0;

        // Ceiling Inverted Mushroom
        var cX = ms - mushScroll + 55;
        var cColor = (Math.abs(ms) % 180 === 0) ? "#FFD700" : "#00E5FF";
        ctx.fillStyle = "#A89AC2";
        ctx.fillRect(cX - 1, CEILING_Y, 2, 6);
        ctx.fillStyle = cColor;
        ctx.beginPath();
        ctx.arc(cX, CEILING_Y + 6, 4, 0, Math.PI);
        ctx.closePath();
        ctx.fill();

        ctx.fillStyle = cColor;
        ctx.globalAlpha = 0.25;
        ctx.beginPath();
        ctx.arc(cX, CEILING_Y + 6, 8, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1.0;
    }
}

function drawCaveMotes(ctx) {
    ctx.save();
    for (var i = 0; i < caveMotes.length; i++) {
        var mt = caveMotes[i];
        ctx.globalAlpha = Math.max(0, Math.min(1, mt.alpha));
        ctx.fillStyle = mt.color;
        ctx.beginPath();
        ctx.arc(mt.x, mt.y, mt.size, 0, Math.PI * 2);
        ctx.fill();

        ctx.globalAlpha = mt.alpha * 0.35;
        ctx.beginPath();
        ctx.arc(mt.x, mt.y, mt.size * 2.6, 0, Math.PI * 2);
        ctx.fill();
    }
    ctx.restore();
}

function drawCaveCritter(ctx, c) {
    ctx.save();
    ctx.translate(c.x, c.y);

    if (c.type === "peeper") {
        // Dark rock crevice hollow
        ctx.fillStyle = "#09060E";
        ctx.beginPath();
        ctx.ellipse(0, 0, 16, 9, 0, 0, Math.PI * 2);
        ctx.fill();

        // Glowing Eyes peeking from dark
        if (!c.isBlinking) {
            var pupilX = Math.max(-2, Math.min(2, (slime.x - c.x) * 0.02));
            var pupilY = Math.max(-1.5, Math.min(1.5, (slime.y - c.y) * 0.02));

            ctx.fillStyle = c.color;
            ctx.beginPath();
            ctx.ellipse(-6, 0, 4, 5, 0, 0, Math.PI * 2);
            ctx.ellipse(6, 0, 4, 5, 0, 0, Math.PI * 2);
            ctx.fill();

            // Dark pupils tracking the player
            ctx.fillStyle = "#0A0710";
            ctx.beginPath();
            ctx.arc(-6 + pupilX, pupilY, 1.8, 0, Math.PI * 2);
            ctx.arc(6 + pupilX, pupilY, 1.8, 0, Math.PI * 2);
            ctx.fill();

            // White eye glints
            ctx.fillStyle = "#FFFFFF";
            ctx.beginPath();
            ctx.arc(-7 + pupilX * 0.5, pupilY - 1.5, 1.0, 0, Math.PI * 2);
            ctx.arc(5 + pupilX * 0.5, pupilY - 1.5, 1.0, 0, Math.PI * 2);
            ctx.fill();
        }
    } else if (c.type === "squeaker") {
        // Orient for ceiling vs floor
        if (c.isFloor === false) {
            ctx.scale(1, -1);
        }

        // Little fluffy round cave monster on a ledge
        var hopY = Math.abs(Math.sin(c.hopPhase)) * -8;
        ctx.translate(0, hopY);

        // Monster Body (fluffy charcoal-purple)
        ctx.fillStyle = c.color || "#3A2A4D";
        ctx.beginPath();
        ctx.ellipse(0, -10, 12, 10, 0, 0, Math.PI * 2);
        ctx.fill();

        // Cute Little Pointed Monster Ears
        ctx.beginPath();
        ctx.moveTo(-9, -16);
        ctx.lineTo(-13, -24 + Math.sin(c.hopPhase * 2) * 2);
        ctx.lineTo(-5, -18);
        ctx.moveTo(9, -16);
        ctx.lineTo(13, -24 - Math.sin(c.hopPhase * 2) * 2);
        ctx.lineTo(5, -18);
        ctx.fill();

        // Pink inner ear fluff
        ctx.fillStyle = "#FF7096";
        ctx.beginPath();
        ctx.moveTo(-8, -17);
        ctx.lineTo(-11, -22 + Math.sin(c.hopPhase * 2) * 2);
        ctx.lineTo(-6, -18);
        ctx.moveTo(8, -17);
        ctx.lineTo(11, -22 - Math.sin(c.hopPhase * 2) * 2);
        ctx.lineTo(6, -18);
        ctx.fill();

        // Big cute round eyes
        if (!c.isBlinking) {
            ctx.fillStyle = "#FFFFFF";
            ctx.beginPath();
            ctx.arc(-4, -11, 3.5, 0, Math.PI * 2);
            ctx.arc(4, -11, 3.5, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = "#120B1C";
            ctx.beginPath();
            ctx.arc(-4, -11, 1.8, 0, Math.PI * 2);
            ctx.arc(4, -11, 1.8, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = "#FFFFFF";
            ctx.beginPath();
            ctx.arc(-5, -12, 1.0, 0, Math.PI * 2);
            ctx.arc(3, -12, 1.0, 0, Math.PI * 2);
            ctx.fill();
        }

        // Cute tiny rosy cheeks
        ctx.fillStyle = "rgba(255, 100, 140, 0.4)";
        ctx.beginPath();
        ctx.arc(-7, -8, 2, 0, Math.PI * 2);
        ctx.arc(7, -8, 2, 0, Math.PI * 2);
        ctx.fill();
    }

    ctx.restore();
}

function drawBat(ctx, bat) {
    ctx.save();
    ctx.translate(bat.x, bat.y);
    var s = bat.size;
    var flap = Math.sin(bat.wingTimer);

    // Direction facing movement
    ctx.scale(bat.vx < 0 ? 1 : -1, 1);

    // Bat Body (Sleek dark cave bat)
    ctx.fillStyle = bat.depth < 0.7 ? "#1C1628" : "#302642";
    ctx.beginPath();
    ctx.ellipse(0, 0, s * 0.32, s * 0.46, 0, 0, Math.PI * 2);
    ctx.fill();

    // Bat Ears
    ctx.beginPath();
    ctx.moveTo(-s * 0.25, -s * 0.35);
    ctx.lineTo(-s * 0.16, -s * 0.72);
    ctx.lineTo(0, -s * 0.35);
    ctx.lineTo(s * 0.16, -s * 0.72);
    ctx.lineTo(s * 0.25, -s * 0.35);
    ctx.closePath();
    ctx.fill();

    // Ear interior subtle tint
    ctx.fillStyle = "#6B5585";
    ctx.beginPath();
    ctx.moveTo(-s * 0.2, -s * 0.38);
    ctx.lineTo(-s * 0.16, -s * 0.62);
    ctx.lineTo(-s * 0.08, -s * 0.38);
    ctx.moveTo(s * 0.2, -s * 0.38);
    ctx.lineTo(s * 0.16, -s * 0.62);
    ctx.lineTo(s * 0.08, -s * 0.38);
    ctx.fill();

    // Glowing Eyes
    ctx.fillStyle = bat.eyeColor || "#FF4466";
    ctx.beginPath();
    ctx.arc(-s * 0.12, -s * 0.18, 1.8, 0, Math.PI * 2);
    ctx.arc(s * 0.12, -s * 0.18, 1.8, 0, Math.PI * 2);
    ctx.fill();

    // Tiny white fangs
    if (bat.depth > 0.6) {
        ctx.fillStyle = "#FFFFFF";
        ctx.beginPath();
        ctx.moveTo(-s * 0.08, s * 0.1);
        ctx.lineTo(-s * 0.05, s * 0.25);
        ctx.lineTo(-s * 0.02, s * 0.1);
        ctx.moveTo(s * 0.02, s * 0.1);
        ctx.lineTo(s * 0.05, s * 0.25);
        ctx.lineTo(s * 0.08, s * 0.1);
        ctx.fill();
    }

    // Left & Right Flapping Wings
    ctx.fillStyle = bat.depth < 0.7 ? "#231B33" : "#3B2E52";
    ctx.strokeStyle = bat.depth < 0.7 ? "#352A4D" : "#564478";
    ctx.lineWidth = 1.2;

    var wingTipY = flap * s * 0.75;
    var wingSpan = s * 1.35;

    // Left Wing
    ctx.beginPath();
    ctx.moveTo(-s * 0.2, -s * 0.1);
    ctx.quadraticCurveTo(-wingSpan * 0.5, -s * 0.5 + wingTipY * 0.5, -wingSpan, wingTipY);
    ctx.quadraticCurveTo(-wingSpan * 0.7, s * 0.35 + wingTipY * 0.4, -s * 0.5, s * 0.2 + wingTipY * 0.2);
    ctx.quadraticCurveTo(-s * 0.35, s * 0.3, -s * 0.2, s * 0.1);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Left Wing Bone Strut
    ctx.beginPath();
    ctx.moveTo(-s * 0.2, -s * 0.1);
    ctx.lineTo(-wingSpan * 0.7, s * 0.35 + wingTipY * 0.4);
    ctx.stroke();

    // Right Wing
    ctx.beginPath();
    ctx.moveTo(s * 0.2, -s * 0.1);
    ctx.quadraticCurveTo(wingSpan * 0.5, -s * 0.5 + wingTipY * 0.5, wingSpan, wingTipY);
    ctx.quadraticCurveTo(wingSpan * 0.7, s * 0.35 + wingTipY * 0.4, s * 0.5, s * 0.2 + wingTipY * 0.2);
    ctx.quadraticCurveTo(s * 0.35, s * 0.3, s * 0.2, s * 0.1);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Right Wing Bone Strut
    ctx.beginPath();
    ctx.moveTo(s * 0.2, -s * 0.1);
    ctx.lineTo(wingSpan * 0.7, s * 0.35 + wingTipY * 0.4);
    ctx.stroke();

    ctx.restore();
}

function drawMidgroundBats(ctx) {
    for (var b = 0; b < caveBats.length; b++) {
        if (caveBats[b].depth >= 0.7) {
            drawBat(ctx, caveBats[b]);
        }
    }
}

function drawWaterDrips(ctx) {
    ctx.save();
    for (var i = 0; i < waterDrops.length; i++) {
        var d = waterDrops[i];
        if (d.isFalling) {
            ctx.fillStyle = "rgba(180, 235, 255, 0.75)";
            ctx.beginPath();
            ctx.ellipse(d.x, d.y, 2, 4, 0, 0, Math.PI * 2);
            ctx.fill();
        } else {
            // Ripple splash on the cave floor
            ctx.strokeStyle = "rgba(180, 235, 255, " + (d.splashTimer / 0.22) + ")";
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.ellipse(d.x, FLOOR_Y, d.splashRadius, d.splashRadius * 0.35, 0, 0, Math.PI * 2);
            ctx.stroke();
        }
    }
    ctx.restore();
}

/**
 * Draw Geological Stalactites (Ceiling Clusters) & Stalagmites (Floor Terraced Karsts)
 */
function drawStalactitesAndStalagmites(ctx, theme) {
    for (var i = 0; i < spikes.length; i++) {
        var sp = spikes[i];
        var baseY = sp.isFloor ? FLOOR_Y : CEILING_Y;
        var tipY = sp.isFloor ? (FLOOR_Y - sp.h) : (CEILING_Y + sp.h);
        var halfW = sp.w / 2;
        var h = sp.h;

        ctx.save();

        if (sp.isFloor) {
            // =================================================================
            // STALAGMITE (Floor Hazard: Terraced Karst Mound Built by Drips)
            // =================================================================

            // 1. Wet Mineral Puddle Sheen at Base
            ctx.fillStyle = "rgba(140, 200, 240, 0.25)";
            ctx.beginPath();
            ctx.ellipse(sp.x, baseY, halfW + 12, 5, 0, 0, Math.PI * 2);
            ctx.fill();

            // 2. Broad Basalt / Limestone Foundation Mound
            ctx.fillStyle = "#1B1426";
            ctx.beginPath();
            ctx.ellipse(sp.x, baseY, halfW + 9, 6.5, 0, 0, Math.PI * 2);
            ctx.fill();

            // 3. Companion Splash Mounds / Mini-Stalagmites at Base
            // Left Mini-Mound
            var m1W = halfW * 0.38;
            var m1H = h * 0.35;
            var m1X = sp.x - halfW * 0.65;
            var gradM1 = ctx.createLinearGradient(m1X - m1W, baseY, m1X + m1W, baseY - m1H);
            gradM1.addColorStop(0, "#36284D");
            gradM1.addColorStop(0.5, "#564373");
            gradM1.addColorStop(1, "#7D669F");
            ctx.fillStyle = gradM1;
            ctx.beginPath();
            ctx.moveTo(m1X - m1W, baseY);
            ctx.quadraticCurveTo(m1X - m1W * 0.6, baseY - m1H * 0.7, m1X, baseY - m1H);
            ctx.quadraticCurveTo(m1X + m1W * 0.5, baseY - m1H * 0.6, m1X + m1W, baseY);
            ctx.closePath();
            ctx.fill();

            // Right Mini-Mound
            var m2W = halfW * 0.32;
            var m2H = h * 0.24;
            var m2X = sp.x + halfW * 0.68;
            var gradM2 = ctx.createLinearGradient(m2X - m2W, baseY, m2X + m2W, baseY - m2H);
            gradM2.addColorStop(0, "#483663");
            gradM2.addColorStop(0.7, "#251836");
            ctx.fillStyle = gradM2;
            ctx.beginPath();
            ctx.moveTo(m2X - m2W, baseY);
            ctx.quadraticCurveTo(m2X - m2W * 0.4, baseY - m2H * 0.7, m2X, baseY - m2H);
            ctx.quadraticCurveTo(m2X + m2W * 0.6, baseY - m2H * 0.5, m2X + m2W, baseY);
            ctx.closePath();
            ctx.fill();

            // 4. Primary Stalagmite: Terraced, Knobby Karst Spire
            // Left Illuminated Side (Calcite Highlights)
            var gradLit = ctx.createLinearGradient(sp.x - halfW, baseY, sp.x, tipY);
            gradLit.addColorStop(0, "#2D203F");
            gradLit.addColorStop(0.35, "#554173");
            gradLit.addColorStop(0.7, "#8770AA");
            gradLit.addColorStop(1, "#B49FD4");

            ctx.fillStyle = gradLit;
            ctx.beginPath();
            ctx.moveTo(sp.x - halfW, baseY);
            // Tier 1: Wide bulbous terrace
            ctx.bezierCurveTo(sp.x - halfW * 0.95, baseY - h * 0.15, sp.x - halfW * 0.75, baseY - h * 0.28, sp.x - halfW * 0.68, baseY - h * 0.32);
            // Tier 2: Stepped shelf inwards then bulbous rise
            ctx.lineTo(sp.x - halfW * 0.58, baseY - h * 0.35);
            ctx.bezierCurveTo(sp.x - halfW * 0.55, baseY - h * 0.52, sp.x - halfW * 0.38, baseY - h * 0.68, sp.x - halfW * 0.32, baseY - h * 0.72);
            // Tier 3: Upper column tapering to rounded crest
            ctx.lineTo(sp.x - halfW * 0.25, baseY - h * 0.75);
            ctx.bezierCurveTo(sp.x - halfW * 0.2, baseY - h * 0.88, sp.x - halfW * 0.08, tipY + 1, sp.x, tipY);
            // Centerline down
            ctx.lineTo(sp.x + 1, baseY - h * 0.6);
            ctx.lineTo(sp.x, baseY);
            ctx.closePath();
            ctx.fill();

            // Right Shadowed Side
            var gradShadow = ctx.createLinearGradient(sp.x, tipY, sp.x + halfW, baseY);
            gradShadow.addColorStop(0, "#8770AA");
            gradShadow.addColorStop(0.35, "#483563");
            gradShadow.addColorStop(0.7, "#281C38");
            gradShadow.addColorStop(1, "#150D21");

            ctx.fillStyle = gradShadow;
            ctx.beginPath();
            ctx.moveTo(sp.x, tipY);
            // Right Tier 3
            ctx.bezierCurveTo(sp.x + halfW * 0.1, tipY + 2, sp.x + halfW * 0.22, baseY - h * 0.85, sp.x + halfW * 0.26, baseY - h * 0.73);
            ctx.lineTo(sp.x + halfW * 0.35, baseY - h * 0.7);
            // Right Tier 2
            ctx.bezierCurveTo(sp.x + halfW * 0.42, baseY - h * 0.55, sp.x + halfW * 0.58, baseY - h * 0.42, sp.x + halfW * 0.65, baseY - h * 0.3);
            ctx.lineTo(sp.x + halfW * 0.75, baseY - h * 0.28);
            // Right Tier 1 to base
            ctx.bezierCurveTo(sp.x + halfW * 0.88, baseY - h * 0.18, sp.x + halfW, baseY - 2, sp.x + halfW, baseY);
            ctx.lineTo(sp.x, baseY);
            ctx.closePath();
            ctx.fill();

            // 5. Horizontal Calcite Growth Rings & Rimstone Shelves
            ctx.strokeStyle = "rgba(215, 195, 250, 0.45)";
            ctx.lineWidth = 1.3;

            // Shelf 1
            ctx.beginPath();
            ctx.ellipse(sp.x - halfW * 0.05, baseY - h * 0.3, halfW * 0.65, 3.2, 0, 0, Math.PI);
            ctx.stroke();

            // Shelf 2
            ctx.beginPath();
            ctx.ellipse(sp.x - halfW * 0.02, baseY - h * 0.68, halfW * 0.32, 2.2, 0, 0, Math.PI);
            ctx.stroke();

            // Shelf 3 (Near top)
            ctx.beginPath();
            ctx.ellipse(sp.x, baseY - h * 0.88, halfW * 0.16, 1.5, 0, 0, Math.PI);
            ctx.stroke();

            // 6. Impact Depression at Rounded Summit (Where ceiling drops hit)
            ctx.fillStyle = "#DCD0F0";
            ctx.beginPath();
            ctx.ellipse(sp.x, tipY + 1.2, halfW * 0.15, 2.0, 0, 0, Math.PI * 2);
            ctx.fill();

            // Wet Water Sheen Highlight on summit
            ctx.fillStyle = "#FFFFFF";
            ctx.beginPath();
            ctx.arc(sp.x - 1, tipY + 1.0, 1.2, 0, Math.PI * 2);
            ctx.fill();

            // 7. Glowing Crystal Nodules embedded in rock
            var cCol = sp.crystalColor || "#00E5FF";
            ctx.fillStyle = cCol;
            ctx.beginPath();
            ctx.arc(sp.x - halfW * 0.35, baseY - h * 0.45, 2.2, 0, Math.PI * 2);
            ctx.arc(sp.x + halfW * 0.4, baseY - h * 0.2, 1.8, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = cCol;
            ctx.globalAlpha = 0.35;
            ctx.beginPath();
            ctx.arc(sp.x - halfW * 0.35, baseY - h * 0.45, 5.5, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1.0;

        } else {
            // =================================================================
            // STALACTITE (Ceiling Hazard: Hanging Karst Drapery & Drip Needle Cluster)
            // =================================================================

            // 1. Broad Ceiling Rock Attachment & Mineral Crust
            ctx.fillStyle = "#1B1426";
            ctx.beginPath();
            ctx.ellipse(sp.x, baseY, halfW + 10, 6, 0, 0, Math.PI * 2);
            ctx.fill();

            // 2. Companion Baby Stalactites (Hanging Beside Main Needle)
            // Left Baby Stalactite (~45% length)
            var b1W = halfW * 0.32;
            var b1H = h * 0.46;
            var b1X = sp.x - halfW * 0.62;
            var gradB1 = ctx.createLinearGradient(b1X - b1W, baseY, b1X, baseY + b1H);
            gradB1.addColorStop(0, "#36284D");
            gradB1.addColorStop(0.6, "#655085");
            gradB1.addColorStop(1, "#8E77B1");
            ctx.fillStyle = gradB1;
            ctx.beginPath();
            ctx.moveTo(b1X - b1W, baseY);
            ctx.bezierCurveTo(b1X - b1W * 0.8, baseY + b1H * 0.3, b1X - b1W * 0.4, baseY + b1H * 0.7, b1X, baseY + b1H);
            ctx.bezierCurveTo(b1X + b1W * 0.4, baseY + b1H * 0.7, b1X + b1W * 0.7, baseY + b1H * 0.3, b1X + b1W, baseY);
            ctx.closePath();
            ctx.fill();

            // Water drop gathering at baby tip
            ctx.fillStyle = "#BCE8FF";
            ctx.beginPath();
            ctx.arc(b1X, baseY + b1H + 1.2, 1.2, 0, Math.PI * 2);
            ctx.fill();

            // Right Mineral Stub / Nub (~26% length)
            var b2W = halfW * 0.28;
            var b2H = h * 0.26;
            var b2X = sp.x + halfW * 0.64;
            var gradB2 = ctx.createLinearGradient(b2X, baseY, b2X + b2W, baseY + b2H);
            gradB2.addColorStop(0, "#564375");
            gradB2.addColorStop(1, "#281C38");
            ctx.fillStyle = gradB2;
            ctx.beginPath();
            ctx.moveTo(b2X - b2W, baseY);
            ctx.bezierCurveTo(b2X - b2W * 0.6, baseY + b2H * 0.4, b2X - b2W * 0.3, baseY + b2H * 0.8, b2X, baseY + b2H);
            ctx.bezierCurveTo(b2X + b2W * 0.3, baseY + b2H * 0.8, b2X + b2W * 0.6, baseY + b2H * 0.4, b2X + b2W, baseY);
            ctx.closePath();
            ctx.fill();

            // 3. Primary Stalactite (Hanging Drapery Flutes Tapering to Needle)
            // Left Illuminated Karst Facet (Curved Drapery Folds)
            var gradLitC = ctx.createLinearGradient(sp.x - halfW, baseY, sp.x, tipY);
            gradLitC.addColorStop(0, "#2D203F");
            gradLitC.addColorStop(0.3, "#554173");
            gradLitC.addColorStop(0.65, "#8770AA");
            gradLitC.addColorStop(1, "#B49FD4");

            ctx.fillStyle = gradLitC;
            ctx.beginPath();
            ctx.moveTo(sp.x - halfW * 0.88, baseY);
            // Bulge 1: Upper drapery flare
            ctx.bezierCurveTo(sp.x - halfW * 0.8, baseY + h * 0.12, sp.x - halfW * 0.62, baseY + h * 0.25, sp.x - halfW * 0.54, baseY + h * 0.32);
            // Neck 1: Constriction
            ctx.bezierCurveTo(sp.x - halfW * 0.48, baseY + h * 0.38, sp.x - halfW * 0.45, baseY + h * 0.45, sp.x - halfW * 0.42, baseY + h * 0.52);
            // Bulge 2: Mid-tier calcite nodule
            ctx.bezierCurveTo(sp.x - halfW * 0.42, baseY + h * 0.6, sp.x - halfW * 0.32, baseY + h * 0.72, sp.x - halfW * 0.24, baseY + h * 0.8);
            // Slender Needle to tip
            ctx.bezierCurveTo(sp.x - halfW * 0.16, baseY + h * 0.9, sp.x - halfW * 0.06, tipY - 2, sp.x, tipY);
            // Centerline back to ceiling
            ctx.lineTo(sp.x + 1, baseY + h * 0.55);
            ctx.lineTo(sp.x, baseY);
            ctx.closePath();
            ctx.fill();

            // Right Shadowed Facet
            var gradShadowC = ctx.createLinearGradient(sp.x, tipY, sp.x + halfW, baseY);
            gradShadowC.addColorStop(0, "#8770AA");
            gradShadowC.addColorStop(0.35, "#483563");
            gradShadowC.addColorStop(0.7, "#281C38");
            gradShadowC.addColorStop(1, "#150D21");

            ctx.fillStyle = gradShadowC;
            ctx.beginPath();
            ctx.moveTo(sp.x, tipY);
            // Right slender needle
            ctx.bezierCurveTo(sp.x + halfW * 0.08, tipY - 2, sp.x + halfW * 0.18, baseY + h * 0.9, sp.x + halfW * 0.24, baseY + h * 0.8);
            // Right Bulge 2
            ctx.bezierCurveTo(sp.x + halfW * 0.32, baseY + h * 0.72, sp.x + halfW * 0.38, baseY + h * 0.6, sp.x + halfW * 0.4, baseY + h * 0.5);
            // Right Neck 1
            ctx.bezierCurveTo(sp.x + halfW * 0.44, baseY + h * 0.42, sp.x + halfW * 0.5, baseY + h * 0.34, sp.x + halfW * 0.58, baseY + h * 0.28);
            // Right Bulge 1 to ceiling
            ctx.bezierCurveTo(sp.x + halfW * 0.68, baseY + h * 0.2, sp.x + halfW * 0.82, baseY + h * 0.08, sp.x + halfW * 0.88, baseY);
            ctx.lineTo(sp.x, baseY);
            ctx.closePath();
            ctx.fill();

            // 4. Horizontal Calcite Growth Rings & Dripping Striations
            ctx.strokeStyle = "rgba(215, 195, 250, 0.45)";
            ctx.lineWidth = 1.2;

            // Ring 1
            ctx.beginPath();
            ctx.ellipse(sp.x - halfW * 0.04, baseY + h * 0.3, halfW * 0.52, 2.5, 0, 0, Math.PI);
            ctx.stroke();

            // Ring 2
            ctx.beginPath();
            ctx.ellipse(sp.x - halfW * 0.02, baseY + h * 0.56, halfW * 0.36, 2.0, 0, 0, Math.PI);
            ctx.stroke();

            // Ring 3
            ctx.beginPath();
            ctx.ellipse(sp.x, baseY + h * 0.78, halfW * 0.22, 1.5, 0, 0, Math.PI);
            ctx.stroke();

            // 5. Wet Moisture Trickle down the center fluting
            ctx.strokeStyle = "rgba(180, 235, 255, 0.5)";
            ctx.lineWidth = 1.0;
            ctx.beginPath();
            ctx.moveTo(sp.x, baseY + 6);
            ctx.quadraticCurveTo(sp.x - 2, baseY + h * 0.45, sp.x, baseY + h * 0.75);
            ctx.lineTo(sp.x, tipY);
            ctx.stroke();

            // 6. Suspended Water Droplet at the Sharp Tip (Surface tension tear)
            ctx.fillStyle = "rgba(170, 235, 255, 0.9)";
            ctx.beginPath();
            ctx.moveTo(sp.x - 1.8, tipY);
            ctx.quadraticCurveTo(sp.x - 2.8, tipY + 3.0, sp.x, tipY + 4.5);
            ctx.quadraticCurveTo(sp.x + 2.8, tipY + 3.0, sp.x + 1.8, tipY);
            ctx.closePath();
            ctx.fill();

            // Droplet Glint / Sparkle
            ctx.fillStyle = "#FFFFFF";
            ctx.beginPath();
            ctx.arc(sp.x - 0.7, tipY + 2.5, 0.9, 0, Math.PI * 2);
            ctx.fill();

            // 7. Glowing Crystal Vein
            var cColC = sp.crystalColor || "#FF4081";
            ctx.fillStyle = cColC;
            ctx.beginPath();
            ctx.arc(sp.x - halfW * 0.32, baseY + h * 0.42, 2.2, 0, Math.PI * 2);
            ctx.arc(sp.x + halfW * 0.3, baseY + h * 0.65, 1.8, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = cColC;
            ctx.globalAlpha = 0.35;
            ctx.beginPath();
            ctx.arc(sp.x - halfW * 0.32, baseY + h * 0.42, 5.5, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1.0;
        }

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

    // 3. Continuous Dough-Rolling / Conveyor Tread Slime Body
    var rollPhase = s.rollPhase || 0;
    var isG = s.isGrounded;

    // 3. Continuous Dough-Rolling / Conveyor Tread Slime Body (Dragon Quest Silhouette)
    var rollPhase = s.rollPhase || 0;
    var isG = s.isGrounded;

    // Top pointy conical tip with subtle jelly jiggle
    var tipX = isG ? Math.sin(rollPhase * 0.8) * 1.2 : 0;
    var tipY = -h * 0.58 + (isG ? Math.cos(rollPhase * 1.2) * 0.8 : 0);

    var baseY = h * 0.48;
    var frontEdgeX = w * 0.38;
    var rearEdgeX = -w * 0.38;

    // Front dough fold rolling down onto the floor
    var frontRoll = isG ? Math.sin(rollPhase) * 1.8 : 0;
    // Rear dough fold curling up from the floor into the belly
    var rearRoll = isG ? Math.cos(rollPhase) * 1.8 : 0;

    // Outer Viscous Slime Body Path (Iconic DQ Onion / Water Droplet Contour)
    ctx.beginPath();
    // 1. Start at top pointy tip
    ctx.moveTo(tipX, tipY);

    // 2. Right (Front) flank: concave taper from pointy tip, then swells into plump lower bulb
    ctx.bezierCurveTo(
        tipX + w * 0.08, -h * 0.42,
        tipX + w * 0.22, -h * 0.22,
        w * 0.44 + frontRoll, -h * 0.06
    );
    ctx.bezierCurveTo(
        w * 0.54 + frontRoll, h * 0.10,
        w * 0.52 + frontRoll, h * 0.32,
        frontEdgeX, baseY
    );

    // 3. Underside continuous conveyor / dough tread
    if (isG) {
        // 3 rolling dough waves moving backward from front to rear under the belly
        var segW = (frontEdgeX - rearEdgeX) / 3;
        for (var seg = 0; seg < 3; seg++) {
            var x0 = frontEdgeX - seg * segW;
            var x1 = x0 - segW;
            var midX = (x0 + x1) * 0.5;
            var phase = rollPhase + seg * (Math.PI * 2 / 3);
            var waveLift = Math.max(0, Math.sin(phase)) * 2.2;
            ctx.quadraticCurveTo(midX, baseY - waveLift, x1, baseY);
        }
    } else {
        // Smooth rounded underside while airborne
        ctx.bezierCurveTo(
            frontEdgeX * 0.5, baseY - 2,
            rearEdgeX * 0.5, baseY - 2,
            rearEdgeX, baseY
        );
    }

    // 4. Rear (Left) flank: curves up from floor into plump rear bulb
    ctx.bezierCurveTo(
        -w * 0.52 + rearRoll, h * 0.32,
        -w * 0.54 + rearRoll, h * 0.10,
        -w * 0.44 + rearRoll, -h * 0.06
    );
    // 5. Concave taper back up to the conical pointy tip
    ctx.bezierCurveTo(
        tipX - w * 0.22, -h * 0.22,
        tipX - w * 0.08, -h * 0.42,
        tipX, tipY
    );
    ctx.closePath();

    // Body Fill: Radial Gelatinous Gradient shifting slightly toward front core
    var coreX = tipX * 0.4;
    var gelGrad = ctx.createRadialGradient(coreX - w * 0.08, -h * 0.10, 2, coreX, 0, w * 0.65);
    gelGrad.addColorStop(0, charData.coreColor);
    gelGrad.addColorStop(0.7, charData.color);
    gelGrad.addColorStop(1, charData.glowColor);
    ctx.fillStyle = gelGrad;
    ctx.fill();

    // Body Outline (Rich dark contour)
    ctx.strokeStyle = charData.glowColor;
    ctx.lineWidth = 2.2;
    ctx.stroke();

    // Internal Conveyor Flow (Translucent circulating dough ridges inside belly)
    if (isG) {
        ctx.save();
        ctx.clip(); // Keep inside the slime body contour
        ctx.lineWidth = 1.6;
        ctx.strokeStyle = "rgba(255, 255, 255, 0.22)";
        for (var k = 0; k < 3; k++) {
            var kPhase = rollPhase + k * (Math.PI * 2 / 3);
            var kMidX = ((Math.sin(kPhase) + 1) * 0.5) * (w * 0.64) - (w * 0.32);
            var kY = baseY - 4 - Math.abs(Math.sin(kPhase)) * 5;
            ctx.beginPath();
            ctx.arc(kMidX, kY, 6, Math.PI * 0.85, Math.PI * 0.15, true);
            ctx.stroke();
        }
        ctx.restore();
    }

    // Specular Curved Gloss Highlight (Upper-Left Droplet Sheen)
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(tipX - w * 0.16, -h * 0.16, w * 0.14, h * 0.07, -0.6, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 255, 255, 0.40)";
    ctx.fill();
    // Tiny gleam near tip
    ctx.beginPath();
    ctx.arc(tipX - 1.5, -h * 0.40, 1.8, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 255, 255, 0.50)";
    ctx.fill();
    ctx.restore();

    // Blush Cheeks (for Cherry)
    if (charData.hasBlush) {
        ctx.fillStyle = "rgba(255, 80, 120, 0.40)";
        ctx.beginPath();
        ctx.ellipse(-w * 0.30, h * 0.14, 4.5, 2.8, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.ellipse(w * 0.30, h * 0.14, 4.5, 2.8, 0, 0, Math.PI * 2);
        ctx.fill();
    }

    // 6. Iconic Dragon Quest Slime Eyes (Centered solid black pupils, no sparkles)
    var eyeBounce = isG ? Math.sin(rollPhase * 1.2) * 0.5 : 0;
    var eyeY = -h * 0.02 + eyeBounce;
    var leftEyeX = -w * 0.155;
    var rightEyeX = w * 0.155;
    var eyeR = 4.8;

    if (!s.isBlinking) {
        // Crisp White Sclera
        ctx.fillStyle = "#FFFFFF";
        ctx.beginPath();
        ctx.arc(leftEyeX, eyeY, eyeR, 0, Math.PI * 2);
        ctx.arc(rightEyeX, eyeY, eyeR, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = "#111827";
        ctx.lineWidth = 1.1;
        ctx.stroke();

        // Centered Solid Black Round Pupils (The signature Dragon Quest stare)
        var pupilR = 2.4;
        ctx.fillStyle = "#111827";
        ctx.beginPath();
        ctx.arc(leftEyeX, eyeY, pupilR, 0, Math.PI * 2);
        ctx.arc(rightEyeX, eyeY, pupilR, 0, Math.PI * 2);
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

    // 7. Iconic Dragon Quest Crimson Curved Ribbon Smile (Distinct gap below eyes)
    var mouthYEnds = eyeY + 9.6;
    var mouthDip = 2.6 * s.gravity;
    var mouthYMid = mouthYEnds + mouthDip;
    var mouthW = w * 0.26;

    // Dark outline behind the red smile
    ctx.beginPath();
    ctx.moveTo(-mouthW, mouthYEnds);
    ctx.quadraticCurveTo(0, mouthYMid, mouthW, mouthYEnds);
    ctx.strokeStyle = "#111827";
    ctx.lineWidth = 4.4;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();

    // Vibrant Dragon Quest bright red smile ribbon
    ctx.beginPath();
    ctx.moveTo(-mouthW, mouthYEnds);
    ctx.quadraticCurveTo(0, mouthYMid, mouthW, mouthYEnds);
    ctx.strokeStyle = "#E52521";
    ctx.lineWidth = 2.8;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();

    ctx.restore();
}

/**
 * Draw Gooey Particles, Liquid Spills & Slime Puddles
 */
function drawParticles(ctx) {
    for (var i = 0; i < particles.length; i++) {
        var pt = particles[i];
        ctx.save();
        ctx.globalAlpha = Math.max(0, Math.min(1, pt.alpha));

        if (pt.isPuddle) {
            // Glossy liquid slime puddle spread across the rock
            ctx.fillStyle = pt.color;
            ctx.beginPath();
            ctx.ellipse(pt.x, pt.y, pt.radius, pt.radius * 0.32, 0, 0, Math.PI * 2);
            ctx.fill();

            // Puddle specular highlight glint
            ctx.fillStyle = "rgba(255, 255, 255, 0.65)";
            ctx.beginPath();
            ctx.ellipse(pt.x - pt.radius * 0.25, pt.y - 1, pt.radius * 0.35, pt.radius * 0.12, 0, 0, Math.PI * 2);
            ctx.fill();
        } else if (pt.isShard) {
            // Torn membrane skin fragment
            ctx.translate(pt.x, pt.y);
            ctx.rotate(pt.rot || 0);
            ctx.fillStyle = pt.color;
            ctx.beginPath();
            ctx.moveTo(-pt.radius, -pt.radius * 0.4);
            ctx.lineTo(pt.radius * 1.1, -pt.radius * 0.7);
            ctx.lineTo(pt.radius * 0.5, pt.radius * 0.9);
            ctx.lineTo(-pt.radius * 0.7, pt.radius * 0.6);
            ctx.closePath();
            ctx.fill();

            // Inner translucent highlight
            ctx.fillStyle = "rgba(255, 255, 255, 0.4)";
            ctx.beginPath();
            ctx.arc(0, 0, pt.radius * 0.3, 0, Math.PI * 2);
            ctx.fill();
        } else {
            // Viscous liquid droplet with motion stretch
            var spd = Math.sqrt(pt.vx * pt.vx + pt.vy * pt.vy);
            if (spd > 35) {
                ctx.translate(pt.x, pt.y);
                ctx.rotate(Math.atan2(pt.vy, pt.vx));
                ctx.fillStyle = pt.color;
                ctx.beginPath();
                ctx.ellipse(0, 0, pt.radius * 1.5, pt.radius * 0.75, 0, 0, Math.PI * 2);
                ctx.fill();

                // Highlight gleam
                ctx.fillStyle = "rgba(255, 255, 255, 0.7)";
                ctx.beginPath();
                ctx.arc(-pt.radius * 0.3, -pt.radius * 0.15, pt.radius * 0.28, 0, Math.PI * 2);
                ctx.fill();
            } else {
                ctx.fillStyle = pt.color;
                ctx.beginPath();
                ctx.arc(pt.x, pt.y, pt.radius, 0, Math.PI * 2);
                ctx.fill();

                ctx.fillStyle = "rgba(255, 255, 255, 0.7)";
                ctx.beginPath();
                ctx.arc(pt.x - pt.radius * 0.3, pt.y - pt.radius * 0.3, pt.radius * 0.3, 0, Math.PI * 2);
                ctx.fill();
            }
        }
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
