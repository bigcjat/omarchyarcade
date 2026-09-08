// Omarchy Arcade: Starframe
// Fast-paced tactical neon vector arcade space shooter.
// Pure 60 FPS Glowing Vector Engine with 4 Sectors, 4 Bosses, 4-Gun Simultaneous Weapon System,
// 6 Drift Power-Ups, 200% Super Shield Kinetic Ramming, and Zero-Pass Penalty.

.pragma library

// =============================================================================
// COORDINATE SYSTEM & DIMENSIONS
// =============================================================================
var width = 640;
var height = 800;

// Coordinate space: Center is [0, 0].
// Visible playfield bounds: X: [-284, 284], Y: [-213, 213].
var BOUND_X = 284;
var BOUND_Y = 213;

// =============================================================================
// GAME STATE & METRICS
// =============================================================================
var gameState = "ship_select"; // "ship_select", "playing", "sector_cleared", "gameover", "victory"
var score = 0;
var highScore = 0;
var lives = 3;
var superBombs = 2;
var currentLevel = 1; // 1 to 4
var levelTime = 0;
var gameTime = 0;
var warpSpeedFactor = 1.0;
var screenShake = 0;
var isPaused = false;

function setPaused(p) {
    isPaused = !!p;
}

function togglePaused() {
    isPaused = !isPaused;
    return isPaused;
}

// Feedback event flags (read by QML HUD)
var triggerDamageBlink = false;
var triggerElectricFlash = false;
var floatingBadges = [];

// Level descriptions
var LEVEL_NAMES = [
    "SECTOR 1: FRONTIER PATROL",
    "SECTOR 2: ASTEROID OUTPOST",
    "SECTOR 3: NEBULA FLEET",
    "SECTOR 4: DREADNOUGHT CORE"
];

// Active Boss state
var activeBoss = null;

// =============================================================================
// PLAYER SHIP & SIMULTANEOUS WEAPON ARSENAL
// =============================================================================
var player = {
    x: 0,
    y: -150,
    targetX: 0,
    targetY: -150,
    vx: 0,
    vy: 0,
    tilt: 0,
    shipClass: "interceptor",
    speedMul: 1.0,
    mass: 100,
    width: 38,
    height: 46,
    health: 500,
    maxHealth: 500,
    shields: 500,
    maxShields: 500, // Can overcharge to 1000 with Super Shield!
    primaryDamage: 3.5,
    primaryCooldown: 0.10,
    primaryBulletSpeed: 550,
    superShieldRingAngle: 0,
    isDead: false,
    invulnerableTimer: 2.5,
    firing: false,
    // Destruction sequence state
    isDying: false,
    dyingTimer: 0,
    deathStage: 0,
    // Ammunition pools for the 3 secondary simultaneous weapon mounts:
    // ammo[0] = Machine Gun, ammo[1] = Plasma Cannon, ammo[2] = EMP Cannons
    ammo: [0, 0, 0],
    maxAmmo: 500
};

// =============================================================================
// PLAYABLE SHIP CLASSES & TACTICAL SPECIFICATIONS
// =============================================================================
var SHIP_CLASSES = {
    interceptor: {
        id: "interceptor",
        name: "MK-I INTERCEPTOR",
        role: "BALANCED FIGHTER",
        badge: "MK-I BALANCED",
        desc: "Starframe standard swept-wing fighter. Dual synchronized blasters with balanced shield harmonics and kinetic agility.",
        modelKey: "player_interceptor",
        maxHealth: 500,
        maxShields: 500,
        speedMul: 1.0,
        mass: 100,
        width: 38,
        height: 46,
        gunOffsets: [{ x: -9, y: 14 }, { x: 9, y: 14 }],
        primaryDamage: 3.5,
        primaryCooldown: 0.10,
        primaryBulletSpeed: 550,
        bulletType: "bullet",
        stats: { speed: 70, armor: 65, firepower: 70 }
    },
    valkyrie: {
        id: "valkyrie",
        name: "MK-II VALKYRIE",
        role: "HIGH-SPEED STRIKER",
        badge: "MK-II STRIKER",
        desc: "Ultra-fast delta interceptor. Rapid fire needle blasters and +25% thruster agility at the cost of lighter armor plating.",
        modelKey: "player_valkyrie",
        maxHealth: 380,
        maxShields: 400,
        speedMul: 1.25,
        mass: 75,
        width: 32,
        height: 36,
        gunOffsets: [{ x: -6, y: 16 }, { x: 6, y: 16 }],
        primaryDamage: 3.2,
        primaryCooldown: 0.082,
        primaryBulletSpeed: 640,
        bulletType: "needle",
        stats: { speed: 95, armor: 45, firepower: 80 }
    },
    titan: {
        id: "titan",
        name: "MK-III TITAN",
        role: "SIEGE DREADNOUGHT",
        badge: "MK-III DREADNOUGHT",
        desc: "Fortified armored dreadnought with dual heavy siege autocannons. Heavy 180t kinetic mass for crushing ramming attacks.",
        modelKey: "player_titan",
        maxHealth: 650,
        maxShields: 650,
        speedMul: 0.85,
        mass: 180,
        width: 36,
        height: 38,
        gunOffsets: [{ x: -12, y: 15 }, { x: 12, y: 15 }],
        primaryDamage: 4.8,
        primaryCooldown: 0.125,
        primaryBulletSpeed: 520,
        bulletType: "siege",
        stats: { speed: 50, armor: 95, firepower: 92 }
    }
};

var selectedShipId = "interceptor";

function setShipClass(shipId) {
    if (!SHIP_CLASSES[shipId]) shipId = "interceptor";
    selectedShipId = shipId;
    var def = SHIP_CLASSES[shipId];
    player.shipClass = shipId;
    player.maxHealth = def.maxHealth;
    player.maxShields = def.maxShields;
    player.health = Math.min(player.health, def.maxHealth);
    player.shields = Math.min(player.shields, def.maxShields);
    player.speedMul = def.speedMul;
    player.mass = def.mass;
    player.width = def.width;
    player.height = def.height;
    player.primaryDamage = def.primaryDamage;
    player.primaryCooldown = def.primaryCooldown;
    player.primaryBulletSpeed = def.primaryBulletSpeed;
}

function getPlayerModel(shipId) {
    var id = shipId || (player && player.shipClass) || selectedShipId || "interceptor";
    var def = SHIP_CLASSES[id];
    var key = (def && def.modelKey) || "player_interceptor";
    return VectorModels[key] || VectorModels.player;
}

function drawShipPreview(ctx, shipId, cx, cy, scale, angle, color) {
    var def = SHIP_CLASSES[shipId] || SHIP_CLASSES.interceptor;
    var model = VectorModels[def.modelKey] || VectorModels.player_interceptor;

    ctx.save();
    ctx.translate(cx, cy);
    if (angle) ctx.rotate(angle);
    if (scale) ctx.scale(scale, scale);

    // Subtle thruster glow
    ctx.strokeStyle = color || themeAccent;
    ctx.beginPath();
    ctx.moveTo(-4, 18);
    ctx.lineTo(0, 26 + (Math.sin(Date.now() * 0.015) + 1) * 3);
    ctx.lineTo(4, 18);
    ctx.lineWidth = 1.6;
    ctx.globalAlpha = 0.6;
    ctx.stroke();

    // Glow Bloom Pass
    ctx.lineWidth = 3.8;
    ctx.globalAlpha = 0.28;
    for (var m = 0; m < model.length; m++) {
        var poly = model[m];
        ctx.beginPath();
        for (var p = 0; p < poly.length; p++) {
            if (p === 0) ctx.moveTo(poly[p][0], poly[p][1]);
            else ctx.lineTo(poly[p][0], poly[p][1]);
        }
        ctx.stroke();
    }

    // Sharp Core Vector Pass
    ctx.lineWidth = 1.8;
    ctx.globalAlpha = 1.0;
    for (var m2 = 0; m2 < model.length; m2++) {
        var poly2 = model[m2];
        ctx.beginPath();
        for (var p2 = 0; p2 < poly2.length; p2++) {
            if (p2 === 0) ctx.moveTo(poly2[p2][0], poly2[p2][1]);
            else ctx.lineTo(poly2[p2][0], poly2[p2][1]);
        }
        ctx.stroke();
    }

    ctx.restore();
}

// =============================================================================
// ENTITY POOLS
// =============================================================================
var playerBullets = [];
var enemyBullets = [];
var enemies = [];
var powerUps = [];
var particles = [];
var vectorDebris = [];
var shockwaves = [];
var stars = [];
var scheduledWaves = [];

// Theme Colors (Auto-synced from Omarchy Desktop)
var themeAccent = "#00E5FF";
var themeBg = "#05070B";
var themeFg = "#CDD6F4";
var colorEnemy = "#FF3366";
var colorEnemyHeavy = "#FF9900";
var colorShield = "#00E5FF";
var colorSuperShield = "#FFFF00";
var colorPowerup = "#FFCC00";

// =============================================================================
// PROCEDURAL 2D VECTOR WIREFRAME MODELS
// =============================================================================
var VectorModels = {
    // Ship 1: Player fighter (Swept-wing twin-hull interceptor)
    player_interceptor: [
        [[-3, -18], [0, -24], [3, -18], [4, 12], [0, 18], [-4, 12], [-3, -18]],
        [[0, -16], [2, -6], [0, 2], [-2, -6], [0, -16]],
        [[-4, -2], [-14, 4], [-19, 14], [-16, 18], [-12, 16], [-10, 8], [-4, 8]],
        [[-16, 6], [-16, -8]],
        [[4, -2], [14, 4], [19, 14], [16, 18], [12, 16], [10, 8], [4, 8]],
        [[16, 6], [16, -8]],
        [[-12, 8], [-4, 2]],
        [[12, 8], [4, 2]]
    ],

    // Ship 2: High-Speed Stealth Striker / Delta Dart (Scaled to fit within radius 26 shield)
    player_valkyrie: [
        // Central sharp needle fuselage & cockpit (nose at [0, -20], aft at [0, 15])
        [[0, -20], [2, -10], [3, 6], [0, 15], [-3, 6], [-2, -10], [0, -20]],
        // Cockpit canopy
        [[0, -13], [2, -4], [0, 3], [-2, -4], [0, -13]],
        // Port swept delta wing (wingtip at [-16, 12] -> radius 20.0 < 26)
        [[-3, -3], [-11, 6], [-16, 12], [-13, 11], [-4, 7]],
        // Port needle cannon
        [[-10, 3], [-10, -9]],
        // Starboard swept delta wing (wingtip at [16, 12] -> radius 20.0 < 26)
        [[3, -3], [11, 6], [16, 12], [13, 11], [4, 7]],
        // Starboard needle cannon
        [[10, 3], [10, -9]],
        // Winglet stabilizers
        [[-16, 12], [-18, 5]],
        [[16, 12], [18, 5]],
        // Dual vectored exhaust bells
        [[-3, 9], [-2, 16], [2, 16], [3, 9]],
        // Forward sensory canards
        [[-3, -6], [-7, -3], [-3, -1]],
        [[3, -6], [7, -3], [3, -1]]
    ],

    // Ship 3: Heavy Dreadnought / Siege Gunship (Scaled to fit within radius 26 shield)
    player_titan: [
        // Heavy faceted outer armor hull (max radius 20.1 < 26)
        [[-7, -16], [7, -16], [16, -6], [18, 9], [11, 16], [-11, 16], [-18, 9], [-16, -6], [-7, -16]],
        // Forward prow ramming blade
        [[-7, -16], [0, -20], [7, -16]],
        // Heavy inner armor citadel
        [[-5, -9], [5, -9], [10, 0], [10, 9], [-10, 9], [-10, 0], [-5, -9]],
        // Command bridge
        [[0, -7], [4, -1], [0, 4], [-4, -1], [0, -7]],
        // Port Siege Autocannon nacelle (max radius 19.7 < 26)
        [[-14, -5], [-14, -17], [-10, -17], [-10, 2]],
        // Starboard Siege Autocannon nacelle
        [[14, -5], [14, -17], [10, -17], [10, 2]],
        // Armor deflection struts
        [[-8, -12], [0, -3], [8, -12]],
        // Triple heavy thruster nozzles
        [[-11, 14], [-9, 18], [-5, 14]],
        [[5, 14], [9, 18], [11, 14]],
        [[-3, 15], [0, 19], [3, 15]]
    ],

    // Player alias
    player: [
        [[-3, -18], [0, -24], [3, -18], [4, 12], [0, 18], [-4, 12], [-3, -18]],
        [[0, -16], [2, -6], [0, 2], [-2, -6], [0, -16]],
        [[-4, -2], [-14, 4], [-19, 14], [-16, 18], [-12, 16], [-10, 8], [-4, 8]],
        [[-16, 6], [-16, -8]],
        [[4, -2], [14, 4], [19, 14], [16, 18], [12, 16], [10, 8], [4, 8]],
        [[16, 6], [16, -8]],
        [[-12, 8], [-4, 2]],
        [[12, 8], [4, 2]]
    ],

    // Super Shield barrier ring (Hexagonal energetic cage)
    superShield: [
        [[0, -32], [28, -16], [28, 16], [0, 32], [-28, 16], [-28, -16], [0, -32]],
        [[0, -28], [24, -14], [24, 14], [0, 28], [-24, 14], [-24, -14], [0, -28]]
    ],

    // Straight: Dagger dart
    straight: [
        [[0, -26], [14, -8], [18, 16], [8, 24], [0, 18], [-8, 24], [-18, 16], [-14, -8], [0, -26]],
        [[0, -20], [6, 0], [0, 12], [-6, 0], [0, -20]],
        [[-14, 4], [-6, 6]],
        [[14, 4], [6, 6]]
    ],

    // Omni: 4-way cross star
    omni: [
        [[0, -20], [8, -8], [20, 0], [8, 8], [0, 20], [-8, 8], [-20, 0], [-8, -8], [0, -20]],
        [[0, -12], [12, 0], [0, 12], [-12, 0], [0, -12]],
        [[-6, -6], [6, 6]],
        [[-6, 6], [6, -6]]
    ],

    // Gnat: High-speed triangular interceptor
    gnat: [
        [[0, -16], [12, 12], [6, 16], [0, 10], [-6, 16], [-12, 12], [0, -16]],
        [[0, -8], [0, 8]]
    ],

    // RayGun Cruiser: Sniper gunship
    raygun: [
        [[-4, -28], [0, -32], [4, -28], [6, 18], [0, 24], [-6, 18], [-4, -28]],
        [[-16, -14], [-4, -10], [-4, 12], [-14, 18], [-18, 8], [-16, -14]],
        [[16, -14], [4, -10], [4, 12], [14, 18], [18, 8], [16, -14]],
        [[-16, -22], [-16, -14]],
        [[16, -22], [16, -14]]
    ],

    // Tank: Heavy armored gunship
    tank: [
        [[-24, -20], [24, -20], [28, 0], [20, 22], [-20, 22], [-28, 0], [-24, -20]],
        [[-14, -14], [14, -14], [18, 2], [10, 16], [-10, 16], [-18, 2], [-14, -14]],
        [[0, -14], [0, 16]],
        [[-12, 2], [12, 2]],
        [[-28, -4], [-34, -16], [-26, -18]],
        [[28, -4], [34, -16], [26, -18]]
    ],

    // Carrier: Heavy supply ship
    carrier: [
        [[0, -26], [20, -8], [24, 14], [12, 24], [-12, 24], [-24, 14], [-20, -8], [0, -26]],
        [[0, -18], [12, -4], [0, 16], [-12, -4], [0, -18]],
        [[0, -8], [6, 0], [0, 8], [-6, 0], [0, -8]]
    ],

    // Boss 1: RayGun Cruiser Boss (Level 1)
    boss_raygun: [
        [[-32, -36], [0, -46], [32, -36], [42, 10], [26, 38], [0, 44], [-26, 38], [-42, 10], [-32, -36]],
        [[-18, -26], [0, -34], [18, -26], [22, 14], [0, 24], [-22, 14], [-18, -26]],
        [[-32, -10], [-48, 6], [-42, 24], [-26, 18]],
        [[32, -10], [48, 6], [42, 24], [26, 18]],
        [[-48, 6], [-48, -24]],
        [[48, 6], [48, -24]],
        [[-8, 0], [8, 0], [0, 16], [-8, 0]]
    ],

    // Boss 2: Tank Dreadnought Boss (Level 2)
    boss_tank: [
        [[-44, -30], [44, -30], [54, 4], [36, 38], [-36, 38], [-54, 4], [-44, -30]],
        [[-28, -20], [28, -20], [36, 4], [20, 26], [-20, 26], [-36, 4], [-28, -20]],
        [[-14, -10], [14, -10], [14, 14], [-14, 14], [-14, -10]],
        [[-54, 0], [-68, -18], [-54, -24]],
        [[54, 0], [68, -18], [54, -24]],
        [[-24, -30], [-24, -44]],
        [[0, -30], [0, -48]],
        [[24, -30], [24, -44]]
    ],

    // Boss 3: Boss0 Flagship (Level 3) - 200 units wide behemoth
    boss0: [
        [[-95, -20], [-60, -50], [60, -50], [95, -20], [85, 30], [50, 52], [-50, 52], [-85, 30], [-95, -20]],
        [[-70, -14], [-45, -36], [45, -36], [70, -14], [60, 24], [35, 40], [-35, 40], [-60, 24], [-70, -14]],
        [[-25, -45], [0, -60], [25, -45], [20, 0], [0, 20], [-20, 0], [-25, -45]],
        [[-60, -10], [-40, 10], [-40, 24], [-60, 10], [-60, -10]],
        [[60, -10], [40, 10], [40, 24], [60, 10], [60, -10]],
        [[-85, -20], [-85, -40], [-70, -35]],
        [[85, -20], [85, -40], [70, -35]],
        [[-45, -50], [-45, -60]],
        [[-30, -50], [-30, -58]],
        [[30, -50], [30, -58]],
        [[45, -50], [45, -60]],
        [[-15, 20], [15, 20], [0, 38], [-15, 20]]
    ],

    // Boss 4: Boss1 Leviathan (Level 4) - 10,000 HP Final Dreadnought
    boss1: [
        [[-70, -55], [0, -75], [70, -55], [85, 0], [70, 55], [0, 75], [-70, 55], [-85, 0], [-70, -55]],
        [[-50, -40], [0, -55], [50, -40], [60, 0], [50, 40], [0, 55], [-50, 40], [-60, 0], [-50, -40]],
        [[-30, -25], [0, -35], [30, -25], [35, 0], [30, 25], [0, 35], [-30, 25], [-35, 0], [-30, -25]],
        [[-65, -30], [-85, -50], [-80, -20]],
        [[65, -30], [85, -50], [80, -20]],
        [[-65, 30], [-85, 50], [-80, 20]],
        [[65, 30], [85, 50], [80, 20]],
        [[-20, -55], [-20, -70]],
        [[-40, -48], [-40, -66]],
        [[20, -55], [20, -70]],
        [[40, -48], [40, -66]],
        [[0, -15], [12, 0], [0, 15], [-12, 0], [0, -15]]
    ]
};

// =============================================================================
// INITIALIZATION & SESSIONS
// =============================================================================
function init(w, h, accent) {
    width = w || 640;
    height = h || 800;
    if (accent) themeAccent = accent;

    resize(width, height);
    initStarfield();
    resetPlayerState();
    gameState = "ship_select";
}

function resize(w, h) {
    if (!w || !h || w <= 0 || h <= 0) return;
    width = w;
    height = h;

    var aspect = width / height;
    if (aspect >= 1.0) {
        // Landscape / wide window (horizontal 1/2 split or ultrawide)
        BOUND_Y = 240;
        BOUND_X = Math.round(BOUND_Y * aspect);
    } else {
        // Portrait / tall window (vertical 1/2 split or arcade cabinet)
        BOUND_X = 220;
        BOUND_Y = Math.round(BOUND_X / aspect);
    }
}

function initStarfield() {
    stars = [];
    for (var i = 0; i < 110; i++) {
        stars.push({
            x: (Math.random() - 0.5) * (BOUND_X * 2),
            y: (Math.random() - 0.5) * (BOUND_Y * 2),
            speed: 0.08 + Math.random() * 0.35,
            size: Math.random() > 0.85 ? 2.2 : 1.2,
            brightness: 0.3 + Math.random() * 0.7
        });
    }
}

function startNewGame() {
    isPaused = false;
    score = 0;
    lives = 3;
    superBombs = 2;
    currentLevel = 1;
    gameState = "playing";
    resetPlayerState();
    loadLevel(1);
}

function resetGame() {
    startNewGame();
}

function resetPlayerState() {
    var def = SHIP_CLASSES[selectedShipId] || SHIP_CLASSES.interceptor;
    var startY = -Math.round(BOUND_Y * 0.65);
    player.x = 0;
    player.y = startY;
    player.targetX = 0;
    player.targetY = startY;
    player.vx = 0;
    player.vy = 0;
    player.tilt = 0;
    player.shipClass = selectedShipId;
    player.maxHealth = def.maxHealth;
    player.health = def.maxHealth;
    player.maxShields = def.maxShields;
    player.shields = def.maxShields;
    player.speedMul = def.speedMul;
    player.mass = def.mass;
    player.width = def.width;
    player.height = def.height;
    player.primaryDamage = def.primaryDamage;
    player.primaryCooldown = def.primaryCooldown;
    player.primaryBulletSpeed = def.primaryBulletSpeed;
    player.ammo = [0, 0, 0];
    player.isDead = false;
    player.isDying = false;
    player.dyingTimer = 0;
    player.deathStage = 0;
    player.invulnerableTimer = 2.5;
    player.firing = false;
    player.superShieldRingAngle = 0;

    playerBullets = [];
    enemyBullets = [];
    shockwaves = [];
    floatingBadges = [];
}

// =============================================================================
// LEVEL & WAVE TIMELINE SCHEDULER
// =============================================================================
function loadLevel(lvl) {
    currentLevel = Math.max(1, Math.min(4, lvl));
    levelTime = 0;
    activeBoss = null;
    enemies = [];
    powerUps = [];
    scheduledWaves = [];

    warpSpeedFactor = 1.0 + (currentLevel - 1) * 0.22;

    addFloatingBadge(LEVEL_NAMES[currentLevel - 1], 0, 80, "#FFFFFF", 2.2);

    // Build timeline waves based on original Chromium B.S.U. level design
    var totalTime = 40 + currentLevel * 10; // 50s..80s before Boss
    var t = 1.2;

    while (t < totalTime) {
        var waveDuration = 4.0;
        var density = Math.min(1.5, 0.4 + (t / totalTime) * 0.7 + (currentLevel - 1) * 0.2);
        var roll = Math.random();

        if (currentLevel === 1) {
            if (roll < 0.6) {
                scheduleStraightWave(t, density);
            } else if (roll < 0.85) {
                scheduleOmniWave(t, density);
            } else {
                scheduleGnatWave(t, density);
            }
        } else if (currentLevel === 2) {
            if (roll < 0.35) {
                scheduleArrowWave("straight", t, density);
            } else if (roll < 0.6) {
                scheduleArrowWave("omni", t, density);
            } else if (roll < 0.8) {
                scheduleGnatWave(t, density);
            } else {
                scheduleTankWave(t);
            }
        } else if (currentLevel === 3) {
            if (roll < 0.3) {
                scheduleArrowWave("omni", t, density);
            } else if (roll < 0.55) {
                scheduleRayGunWave(t);
            } else if (roll < 0.8) {
                scheduleTankWave(t);
            } else {
                scheduleGnatWave(t, density * 1.3);
            }
        } else {
            // Level 4: Full Bullet Hell
            if (roll < 0.3) {
                scheduleArrowWave("straight", t, density * 1.4);
                scheduleGnatWave(t + 1.0, density);
            } else if (roll < 0.6) {
                scheduleTankWave(t);
                scheduleRayGunWave(t + 0.8);
            } else {
                scheduleOmniWave(t, density * 1.5);
            }
        }

        // Periodic Carrier Supply Drops
        if (t > 10 && Math.floor(t) % 18 === 0) {
            scheduleCarrierDrop(t + 1.0);
        }

        t += waveDuration + 1.2 + Math.random() * 1.5;
    }

    // Schedule Level Boss at the end of the timeline
    scheduledWaves.push({
        time: totalTime + 2.0,
        spawn: function() {
            spawnLevelBoss(currentLevel);
        }
    });
}

function scheduleStraightWave(time, density) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var count = Math.max(2, Math.floor(3 * density));
            var spread = Math.max(160, BOUND_X * 1.5);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 20;
            for (var i = 0; i < count; i++) {
                // Chromium BSU: Straight HP: 110, mass: 200
                spawnEnemy("straight", cx + (i - (count - 1) / 2) * 44, topY + i * 14, 0.08, 110, 200);
            }
        }
    });
}

function scheduleOmniWave(time, density) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var count = Math.max(1, Math.floor(2 * density));
            var spread = Math.max(160, BOUND_X * 1.4);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 20;
            for (var i = 0; i < count; i++) {
                // Chromium BSU: Omni HP: 45, mass: 143
                spawnEnemy("omni", cx + (i - (count - 1) / 2) * 58, topY, 0.055, 45, 143);
            }
        }
    });
}

function scheduleGnatWave(time, density) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var count = Math.max(3, Math.floor(5 * density));
            var spread = Math.max(180, BOUND_X * 1.6);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 20;
            for (var i = 0; i < count; i++) {
                var offset = (i - (count - 1) / 2) * 28;
                var delayY = Math.abs(i - (count - 1) / 2) * 22;
                // Chromium BSU: Gnat HP: 10, mass: 1
                spawnEnemy("gnat", cx + offset, topY + delayY, 0.13, 10, 1);
            }
        }
    });
}

function scheduleArrowWave(type, time, density) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var spread = Math.max(140, BOUND_X * 1.3);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 20;
            var hp = (type === "omni" ? 45 : 110);
            var mass = (type === "omni" ? 143 : 200);
            // V-formation wedge
            spawnEnemy(type, cx, topY, 0.075, hp, mass);
            spawnEnemy(type, cx - 40, topY + 22, 0.075, hp, mass);
            spawnEnemy(type, cx + 40, topY + 22, 0.075, hp, mass);
            if (density > 0.8) {
                spawnEnemy(type, cx - 80, topY + 44, 0.075, hp, mass);
                spawnEnemy(type, cx + 80, topY + 44, 0.075, hp, mass);
            }
        }
    });
}

function scheduleRayGunWave(time) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var spread = Math.max(140, BOUND_X * 1.3);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 22;
            // Chromium BSU: RayGun HP: 1000, mass: 500
            spawnEnemy("raygun", cx - 45, topY, 0.055, 1000, 500);
            spawnEnemy("raygun", cx + 45, topY, 0.055, 1000, 500);
        }
    });
}

function scheduleTankWave(time) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var spread = Math.max(140, BOUND_X * 1.3);
            var cx = (Math.random() - 0.5) * spread;
            var topY = BOUND_Y + 24;
            // Chromium BSU: Tank HP: 2000, mass: 1000
            spawnEnemy("tank", cx, topY, 0.042, 2000, 1000);
        }
    });
}

function scheduleCarrierDrop(time) {
    scheduledWaves.push({
        time: time,
        spawn: function() {
            var spread = Math.max(140, BOUND_X * 1.4);
            var topY = BOUND_Y + 20;
            spawnEnemy("carrier", (Math.random() - 0.5) * spread, topY, 0.04, 600, 400);
        }
    });
}

// =============================================================================
// BOSS ENCOUNTER SPAWNER
// =============================================================================
function spawnLevelBoss(level) {
    addFloatingBadge("⚠️ WARNING: BOSS DETECTED ⚠️", 0, Math.round(BOUND_Y * 0.35), "#FF3366", 2.5);

    var bossSpawnY = BOUND_Y + 50;
    var bossTargetY = Math.round(BOUND_Y * 0.50);

    if (level === 1) {
        // Chromium BSU Level 1 Boss: RayGunBoss (1000 HP, mass 500)
        activeBoss = {
            type: "boss_raygun",
            name: "RAYGUN CRUISER",
            x: 0,
            y: bossSpawnY,
            targetY: bossTargetY,
            speed: 0.035,
            health: 1000,
            maxHealth: 1000,
            mass: 500,
            radius: 46,
            points: 2500,
            fireTimer: 1.0,
            chargeTimer: 0,
            laserFiring: false
        };
    } else if (level === 2) {
        // Chromium BSU Level 2 Boss: Tank (2000 HP, mass 1000)
        activeBoss = {
            type: "boss_tank",
            name: "TANK DREADNOUGHT",
            x: 0,
            y: bossSpawnY,
            targetY: bossTargetY,
            speed: 0.03,
            health: 2000,
            maxHealth: 2000,
            mass: 1000,
            radius: 54,
            points: 5000,
            fireTimer: 1.4,
            salvoCount: 0
        };
    } else if (level === 3) {
        // Chromium BSU Level 3 Boss: Boss0 Flagship (10000 HP, mass 2000)
        activeBoss = {
            type: "boss0",
            name: "FLAGSHIP BEHEMOTH",
            x: 0,
            y: bossSpawnY + 20,
            targetY: Math.round(BOUND_Y * 0.45),
            speed: 0.022,
            health: 10000,
            maxHealth: 10000,
            mass: 2000,
            radius: 88,
            points: 10000,
            fireTimer: 0.8,
            omniAngle: 0,
            deathRayTimer: 0,
            deathRayFiring: false
        };
    } else {
        // Chromium BSU Level 4 Final Boss: Boss1 Leviathan (10000 HP, mass 1000)
        activeBoss = {
            type: "boss1",
            name: "VOID LEVIATHAN",
            x: 0,
            y: bossSpawnY + 30,
            targetY: Math.round(BOUND_Y * 0.42),
            speed: 0.02,
            health: 10000,
            maxHealth: 10000,
            mass: 1000,
            radius: 82,
            points: 25000,
            fireTimer: 0.5,
            missileSalvoTimer: 0
        };
    }

    activeBoss.invulnerableTimer = 1.0;
    enemies.push(activeBoss);
}

// =============================================================================
// ENEMY FACTORY
// =============================================================================
function spawnEnemy(type, x, y, speed, health, mass) {
    enemies.push({
        type: type,
        x: x,
        y: y,
        vx: 0,
        vy: -speed * 1000,
        speed: speed,
        health: health,
        maxHealth: health,
        mass: mass,
        fireTimer: Math.random() * 1.5,
        fireRate: type === "gnat" ? 1.4 : (type === "tank" ? 2.2 : (type === "raygun" ? 2.6 : 1.8)),
        rotation: 0,
        radius: type === "tank" ? 26 : (type === "omni" ? 19 : (type === "carrier" ? 24 : 14)),
        points: type === "tank" ? 450 : (type === "carrier" ? 800 : (type === "omni" ? 300 : 150)),
        beamCharging: false
    });
}

// =============================================================================
// CONTROLS & INPUT DISPATCHER
// =============================================================================
function setMouseTarget(mx, my, cw, ch) {
    if (player.isDying || player.isDead) return;
    var normX = (mx / cw - 0.5) * (BOUND_X * 2);
    var normY = (0.5 - my / ch) * (BOUND_Y * 2);
    player.targetX = Math.max(-BOUND_X + 24, Math.min(BOUND_X - 24, normX));
    player.targetY = Math.max(-BOUND_Y + 28, Math.min(BOUND_Y - 28, normY));
}

function setFiring(isFiring) {
    if (player.isDying || player.isDead) {
        player.firing = false;
        return;
    }
    player.firing = isFiring;
}

function handleInput(action, callbacks) {
    if (gameState === "gameover" || gameState === "victory") {
        startNewGame();
        return;
    }
    if (gameState === "sector_cleared") {
        advanceNextLevel();
        return;
    }

    var step = 38 * (player.speedMul || 1.0);
    if (action === "left") {
        player.targetX = Math.max(-BOUND_X + 24, player.targetX - step);
    } else if (action === "right") {
        player.targetX = Math.min(BOUND_X - 24, player.targetX + step);
    } else if (action === "up") {
        player.targetY = Math.min(BOUND_Y - 28, player.targetY + step);
    } else if (action === "down") {
        player.targetY = Math.max(-BOUND_Y + 28, player.targetY - step);
    } else if (action === "action") {
        player.firing = true;
    } else if (action === "bomb") {
        triggerSuperBomb(callbacks);
    }
}

function triggerSuperBomb(callbacks) {
    if (gameState !== "playing" || superBombs <= 0 || player.isDead) return;

    superBombs--;
    screenShake = 12;
    if (callbacks && callbacks.onSound) callbacks.onSound("explosionHuge");

    shockwaves.push({
        x: player.x,
        y: player.y,
        radius: 10,
        maxRadius: 420,
        speed: 650,
        color: "#FFFFFF"
    });

    // Clear all enemy bullets into sparks
    for (var b = 0; b < enemyBullets.length; b++) {
        var eb = enemyBullets[b];
        spawnSparkBurst(eb.x, eb.y, "#FF5577", 4);
    }
    enemyBullets = [];

    // Damage all visible enemies
    for (var e = 0; e < enemies.length; e++) {
        var en = enemies[e];
        if (en.invulnerableTimer && en.invulnerableTimer > 0) continue;
        en.health -= 450;
        spawnSparkBurst(en.x, en.y, "#FFFFFF", 8);
        if (en.health <= 0) {
            destroyEnemy(en, e, callbacks);
            e--;
        }
    }

    addFloatingBadge("EMP SUPER BOMB DETONATED!", 0, player.y + 40, "#FFFF00", 1.8);
}

// =============================================================================
// MAIN 60 FPS ENGINE TICK
// =============================================================================
function update(dt, callbacks) {
    if (isPaused) return;

    if (gameState === "ship_select") {
        for (var st = 0; st < stars.length; st++) {
            var starSelect = stars[st];
            starSelect.y -= dt * 70 * starSelect.speed;
            if (starSelect.y < -BOUND_Y - 20) {
                starSelect.y = BOUND_Y + 20;
                starSelect.x = (Math.random() - 0.5) * 2 * BOUND_X;
            }
        }
        return;
    }

    triggerDamageBlink = false;
    triggerElectricFlash = false;

    if (screenShake > 0) {
        screenShake = Math.max(0, screenShake - dt * 25);
    }

    // Starfield Parallax with Warp Acceleration
    var currentStarSpeed = (gameState === "sector_cleared" ? 900 : 250) * warpSpeedFactor;
    for (var s = 0; s < stars.length; s++) {
        var star = stars[s];
        star.y -= star.speed * dt * currentStarSpeed;
        if (star.y < -BOUND_Y) {
            star.y = BOUND_Y;
            star.x = (Math.random() - 0.5) * (BOUND_X * 2);
        }
    }

    // Floating combat text decay
    for (var fb = 0; fb < floatingBadges.length; fb++) {
        var badge = floatingBadges[fb];
        badge.y += badge.vy * dt;
        badge.life -= dt;
        if (badge.life <= 0) {
            floatingBadges.splice(fb, 1);
            fb--;
        }
    }

    if (gameState !== "playing") {
        updateDebrisAndParticles(dt);
        return;
    }

    gameTime += dt;
    levelTime += dt;

    // Execute Level Wave Timeline
    for (var w = 0; w < scheduledWaves.length; w++) {
        var wave = scheduledWaves[w];
        if (levelTime >= wave.time) {
            wave.spawn();
            scheduledWaves.splice(w, 1);
            w--;
        }
    }

    // Player Flight & Death Sequence
    if (player.isDying) {
        player.dyingTimer -= dt;
        var deathElapsed = 2.4 - player.dyingTimer;

        // Residual drift & violent tumbling
        player.x += (Math.random() - 0.5) * 12 * dt;
        player.y += -30 * dt; // slow drift downwards
        player.tilt += dt * 6.0; // spinning out of control

        // Stage 1 (0.3s): Secondary internal explosion
        if (player.deathStage === 0 && deathElapsed >= 0.3) {
            player.deathStage = 1;
            screenShake = 18;
            triggerElectricFlash = true;
            if (callbacks && callbacks.onSound) callbacks.onSound("explosion");
            spawnSparkBurst(player.x, player.y + 8, "#FFCC00", 14);
            shockwaves.push({
                x: player.x,
                y: player.y + 8,
                radius: 8,
                maxRadius: 150,
                speed: 320,
                color: "#FF8800"
            });
        }

        // Stage 2 (0.65s): Catastrophic Core Breach! The ship blows apart into vector debris!
        if (player.deathStage === 1 && deathElapsed >= 0.65) {
            player.deathStage = 2;
            player.isDead = true; // Visual wireframe disintegrates
            screenShake = 28;
            triggerDamageBlink = true;
            if (callbacks && callbacks.onSound) callbacks.onSound("explosionHuge");

            // Shatter into vector fragments and intense fire sparks
            spawnPlayerDebris(player.x, player.y);
            spawnSparkBurst(player.x, player.y, "#FFFFFF", 30);
            spawnSparkBurst(player.x, player.y, "#FF3366", 25);

            shockwaves.push({
                x: player.x,
                y: player.y,
                radius: 12,
                maxRadius: 280,
                speed: 460,
                color: "#FFFFFF"
            });
            shockwaves.push({
                x: player.x,
                y: player.y,
                radius: 8,
                maxRadius: 220,
                speed: 360,
                color: "#FF3366"
            });
        }

        // Trailing sparks while tumbling
        if (player.deathStage < 2) {
            if (Math.random() < 0.7) {
                spawnSparkBurst(player.x + (Math.random() - 0.5) * 14, player.y + (Math.random() - 0.5) * 14, "#FF3366", 2);
            }
        }

        // Stage 3: Destruction sequence finished!
        if (player.dyingTimer <= 0) {
            player.isDying = false;
            if (lives <= 0) {
                gameState = "gameover";
                if (callbacks && callbacks.onSound) callbacks.onSound("game_over");
            } else {
                respawnPlayer();
            }
        }
    } else if (!player.isDead) {
        if (player.invulnerableTimer > 0) {
            player.invulnerableTimer -= dt;
        }

        player.superShieldRingAngle += dt * 3.5;

        var dx = player.targetX - player.x;
        var dy = player.targetY - player.y;
        var followSpeed = 18 * (player.speedMul || 1.0);
        player.x += dx * Math.min(1.0, dt * followSpeed);
        player.y += dy * Math.min(1.0, dt * followSpeed);

        player.x = Math.max(-BOUND_X + 24, Math.min(BOUND_X - 24, player.x));
        player.y = Math.max(-BOUND_Y + 28, Math.min(BOUND_Y - 28, player.y));

        var targetTilt = Math.max(-0.4, Math.min(0.4, dx * 0.04));
        player.tilt += (targetTilt - player.tilt) * dt * 10;

        // Exhaust sparks
        if (Math.random() < 0.85) {
            particles.push({
                x: player.x + (Math.random() - 0.5) * 8,
                y: player.y - 18,
                vx: (Math.random() - 0.5) * 20,
                vy: -140 - Math.random() * 90,
                life: 0.22,
                maxLife: 0.22,
                color: themeAccent
            });
        }

        // Critical Hull Damage Smoke & Sparks
        if (player.shields <= 50 && player.health <= 220) {
            if (Math.random() < 0.35) {
                particles.push({
                    x: player.x + (Math.random() - 0.5) * 16,
                    y: player.y - 12 + (Math.random() - 0.5) * 8,
                    vx: (Math.random() - 0.5) * 40,
                    vy: -80 - Math.random() * 70,
                    life: 0.35,
                    maxLife: 0.35,
                    color: Math.random() < 0.65 ? "#FF1E40" : "#FFAA00"
                });
            }
        }

        // Four-Gun Simultaneous Firing Pipeline
        if (player.firing) {
            updatePlayerSimultaneousFiring(dt, callbacks);
        }
    }

    // Update Player Projectiles
    for (var b = 0; b < playerBullets.length; b++) {
        var pb = playerBullets[b];
        pb.x += pb.vx * dt;
        pb.y += pb.vy * dt;

        var hit = false;
        for (var e = 0; e < enemies.length; e++) {
            var en = enemies[e];
            var distSq = (pb.x - en.x) * (pb.x - en.x) + (pb.y - en.y) * (pb.y - en.y);
            if (distSq < (en.radius + pb.radius) * (en.radius + pb.radius)) {
                // Deflect during spawn invulnerability (e.g. bosses during first 1.0 second)
                if (en.invulnerableTimer && en.invulnerableTimer > 0) {
                    spawnSparkBurst(pb.x, pb.y, "#00E5FF", 2);
                    if (!pb.piercing) {
                        hit = true;
                        break;
                    }
                    continue;
                }

                if (pb.type === "plasma") {
                    // Chromium BSU: Plasma is permanent piercing shot, deals damage * ms / 20
                    en.health -= pb.damage * (dt / 0.020);
                    spawnSparkBurst(pb.x, pb.y, "#00FF66", 2);
                } else {
                    en.health -= pb.damage;
                    spawnSparkBurst(pb.x, pb.y, themeAccent, 4);
                }

                if (!pb.piercing) {
                    hit = true;
                }

                if (en.health <= 0) {
                    destroyEnemy(en, e, callbacks);
                    e--;
                }
                if (!pb.piercing) {
                    break;
                }
            }
        }

        if (hit || pb.y > BOUND_Y + 30 || pb.x < -BOUND_X - 30 || pb.x > BOUND_X + 30) {
            playerBullets.splice(b, 1);
            b--;
        }
    }

    // Update Enemy Projectiles
    for (var eb = 0; eb < enemyBullets.length; eb++) {
        var ebul = enemyBullets[eb];
        ebul.x += ebul.vx * dt;
        ebul.y += ebul.vy * dt;

        if (!player.isDead && player.invulnerableTimer <= 0) {
            var pDistSq = (ebul.x - player.x) * (ebul.x - player.x) + (ebul.y - player.y) * (ebul.y - player.y);
            if (pDistSq < (18 + ebul.radius) * (18 + ebul.radius)) {
                damagePlayer(ebul.damage, callbacks);
                spawnSparkBurst(ebul.x, ebul.y, colorEnemy, 6);
                enemyBullets.splice(eb, 1);
                eb--;
                continue;
            }
        }

        if (ebul.y < -BOUND_Y - 30 || ebul.y > BOUND_Y + 40 || ebul.x < -BOUND_X - 30 || ebul.x > BOUND_X + 30) {
            enemyBullets.splice(eb, 1);
            eb--;
        }
    }

    // Update Enemies & AI Behaviors
    for (var i = 0; i < enemies.length; i++) {
        var enemy = enemies[i];

        if (enemy.invulnerableTimer && enemy.invulnerableTimer > 0) {
            enemy.invulnerableTimer -= dt;
        }

        if (enemy === activeBoss) {
            updateBossAI(enemy, dt, callbacks);
        } else {
            // Standard enemy flight paths
            if (enemy.type === "omni") {
                enemy.rotation += dt * 2.5;
                enemy.y += enemy.vy * dt;
                enemy.x += Math.sin(gameTime * 3.2) * 65 * dt;
            } else if (enemy.type === "gnat") {
                enemy.y += enemy.vy * dt;
                if (enemy.y > player.y) {
                    enemy.x += (player.x - enemy.x) * dt * 1.1;
                }
            } else {
                enemy.y += enemy.vy * dt;
            }

            // Standard weapon fire
            enemy.fireTimer -= dt;
            if (enemy.fireTimer <= 0 && enemy.y > -BOUND_Y * 0.7 && enemy.y < BOUND_Y * 0.95) {
                enemy.fireTimer = enemy.fireRate;
                enemyFire(enemy);
            }
        }

        // Kinetic Shield Ramming Collision (Chromium BSU authentic collision mechanics)
        if (!player.isDead) {
            var ramDistSq = (enemy.x - player.x) * (enemy.x - player.x) + (enemy.y - player.y) * (enemy.y - player.y);
            if (ramDistSq < (enemy.radius + 20) * (enemy.radius + 20)) {
                var isSuperShield = player.shields > player.maxShields;
                var playerMass = player.mass || 100;
                // In Chromium BSU: enemy takes 40 damage (or 150 under Super Shield overcharge)
                var ramDamageToEnemy = (isSuperShield ? 150 : 40) * (playerMass / 100);
                // Player recoil damage: Math.min(35, enemy.health / 2)
                var recoilDamageToPlayer = Math.min(35, (enemy.health / 2) * (100 / playerMass));

                damagePlayer(recoilDamageToPlayer, callbacks);
                if (!enemy.invulnerableTimer || enemy.invulnerableTimer <= 0) {
                    enemy.health -= ramDamageToEnemy;
                }

                // Physics Knockback from original source
                var deltaX = (player.x - enemy.x);
                var deltaY = (player.y - enemy.y);
                player.targetX += deltaX * recoilDamageToPlayer * 0.04;
                player.targetY += deltaY * recoilDamageToPlayer * 0.04;

                var massFactor = (50 / (enemy.mass || 100)) * (playerMass / 100);
                enemy.x -= deltaX * massFactor;
                enemy.y -= deltaY * massFactor * 0.5;

                shockwaves.push({
                    x: (enemy.x + player.x) / 2,
                    y: (enemy.y + player.y) / 2,
                    radius: 6,
                    maxRadius: 45,
                    speed: 160,
                    color: isSuperShield ? colorSuperShield : colorShield
                });

                if (enemy.health <= 0) {
                    addFloatingBadge("RAM KILL! +" + enemy.points, enemy.x, enemy.y, "#00FF66", 1.4);
                    destroyEnemy(enemy, i, callbacks);
                    i--;
                    continue;
                }
            }
        }

        // Zero-Pass Penalty: Enemies escaping past the bottom danger line
        var dangerBorderY = -BOUND_Y + 14;
        if (enemy !== activeBoss && enemy.y < dangerBorderY - 5) {
            enemies.splice(i, 1);
            i--;
            onEnemyEscaped(callbacks);
            continue;
        }
    }

    // Update Drifting Power-Ups
    for (var p = 0; p < powerUps.length; p++) {
        var pu = powerUps[p];
        pu.baseY += pu.vy * dt;
        pu.timer += dt;
        pu.x = pu.baseX + 18 * Math.sin(pu.timer * 2.5);
        pu.y = pu.baseY + 6 * Math.sin(pu.timer * 4.0);
        pu.rot += dt * 3.0;

        if (!player.isDead) {
            var puDistSq = (pu.x - player.x) * (pu.x - player.x) + (pu.y - player.y) * (pu.y - player.y);
            if (puDistSq < 28 * 28) {
                collectPowerUp(pu, callbacks);
                powerUps.splice(p, 1);
                p--;
                continue;
            }
        }

        if (pu.y < -BOUND_Y - 30) {
            powerUps.splice(p, 1);
            p--;
        }
    }

    updateDebrisAndParticles(dt);
}

function updateDebrisAndParticles(dt) {
    // Shockwaves
    for (var w = 0; w < shockwaves.length; w++) {
        var sw = shockwaves[w];
        sw.radius += sw.speed * dt;
        if (sw.radius >= sw.maxRadius) {
            shockwaves.splice(w, 1);
            w--;
        }
    }

    // Vector Debris
    for (var d = 0; d < vectorDebris.length; d++) {
        var deb = vectorDebris[d];
        deb.x += deb.vx * dt;
        deb.y += deb.vy * dt;
        deb.rot += deb.vRot * dt;
        deb.life -= dt;
        if (deb.life <= 0) {
            vectorDebris.splice(d, 1);
            d--;
        }
    }

    // Particles
    for (var pt = 0; pt < particles.length; pt++) {
        var part = particles[pt];
        part.x += part.vx * dt;
        part.y += part.vy * dt;
        part.life -= dt;
        if (part.life <= 0) {
            particles.splice(pt, 1);
            pt--;
        }
    }
}

// =============================================================================
// FOUR-GUN SIMULTANEOUS FIRING SYSTEM
// =============================================================================
var defaultCooldown = 0;
var mgCooldown = 0;
var plasmaCooldown = 0;
var empCooldown = 0;

function updatePlayerSimultaneousFiring(dt, callbacks) {
    var didShootSound = false;

    // 1. Primary Blasters (Ship specific mounts, cadence, and damage)
    var shipDef = SHIP_CLASSES[player.shipClass || selectedShipId] || SHIP_CLASSES.interceptor;
    var primaryCd = player.primaryCooldown || shipDef.primaryCooldown || 0.10;
    var primaryDmg = player.primaryDamage || shipDef.primaryDamage || 3.5;
    var primarySpd = player.primaryBulletSpeed || shipDef.primaryBulletSpeed || 550;
    var gunOffsets = shipDef.gunOffsets || [{ x: -9, y: 14 }, { x: 9, y: 14 }];

    defaultCooldown -= dt;
    if (defaultCooldown <= 0) {
        defaultCooldown = primaryCd;
        var bRadius = (player.shipClass === "titan") ? 4.0 : ((player.shipClass === "valkyrie") ? 2.6 : 3.0);
        var bType = (player.shipClass === "valkyrie") ? "needle" : ((player.shipClass === "titan") ? "siege" : "bullet");
        for (var g = 0; g < gunOffsets.length; g++) {
            var go = gunOffsets[g];
            playerBullets.push({
                x: player.x + go.x,
                y: player.y + go.y,
                vx: 0,
                vy: primarySpd,
                radius: bRadius,
                damage: primaryDmg,
                type: bType,
                piercing: false
            });
        }
        didShootSound = true;
    }

    // 2. Machine Gun (Chromium BSU: rapid bullet stream, 3.5 damage, consumes 0.25 ammo)
    if (player.ammo[0] > 0) {
        mgCooldown -= dt;
        if (mgCooldown <= 0) {
            mgCooldown = 0.075;
            player.ammo[0] = Math.max(0, player.ammo[0] - 0.25);
            playerBullets.push({ x: player.x - 16, y: player.y + 6, vx: -20, vy: 600, radius: 3.2, damage: 3.5, type: "mg", piercing: false });
            playerBullets.push({ x: player.x + 16, y: player.y + 6, vx: 20, vy: 600, radius: 3.2, damage: 3.5, type: "mg", piercing: false });
            didShootSound = true;
        }
    }

    // 3. Plasma Cannon (Chromium BSU: permanent piercing sphere, 6.0 damage per 20ms tick, consumes 1.5 ammo)
    if (player.ammo[1] > 0) {
        plasmaCooldown -= dt;
        if (plasmaCooldown <= 0) {
            plasmaCooldown = 0.20;
            player.ammo[1] = Math.max(0, player.ammo[1] - 1.5);
            playerBullets.push({ x: player.x, y: player.y + 16, vx: 0, vy: 380, radius: 8, damage: 6.0, type: "plasma", piercing: true });
            didShootSound = true;
        }
    }

    // 4. EMP Arc Cannons (Chromium BSU: high-impact piercing bolts, 40.0 damage, consumes 1.5 ammo)
    if (player.ammo[2] > 0) {
        empCooldown -= dt;
        if (empCooldown <= 0) {
            empCooldown = 0.18;
            player.ammo[2] = Math.max(0, player.ammo[2] - 1.5);
            playerBullets.push({ x: player.x - 22, y: player.y - 2, vx: -35, vy: 500, radius: 4.5, damage: 40.0, type: "emp", piercing: true });
            playerBullets.push({ x: player.x + 22, y: player.y - 2, vx: 35, vy: 500, radius: 4.5, damage: 40.0, type: "emp", piercing: true });
            didShootSound = true;
        }
    }

    if (didShootSound && callbacks && callbacks.onSound) {
        callbacks.onSound("shoot");
    }
}

// =============================================================================
// ENEMY WEAPONS & PREDICTIVE AIMING (Chromium BSU Authentic Values)
// =============================================================================
function enemyFire(enemy) {
    if (enemy.type === "straight") {
        // Chromium BSU StraightShot: 75 damage
        enemyBullets.push({ x: enemy.x, y: enemy.y - 15, vx: 0, vy: -280, radius: 3, damage: 75, type: "laser" });
    } else if (enemy.type === "omni") {
        // Chromium BSU OmniShot: 6 damage
        for (var i = 0; i < 4; i++) {
            var a = enemy.rotation + (i * Math.PI / 2);
            enemyBullets.push({
                x: enemy.x + Math.cos(a) * 16,
                y: enemy.y + Math.sin(a) * 16,
                vx: Math.cos(a) * 190,
                vy: Math.sin(a) * 190,
                radius: 3,
                damage: 6,
                type: "omni"
            });
        }
    } else if (enemy.type === "raygun") {
        // Chromium BSU RayGunShot: 20 damage high-velocity sniper beam
        enemyBullets.push({ x: enemy.x - 16, y: enemy.y - 20, vx: 0, vy: -420, radius: 3.5, damage: 20, type: "beam" });
        enemyBullets.push({ x: enemy.x + 16, y: enemy.y - 20, vx: 0, vy: -420, radius: 3.5, damage: 20, type: "beam" });
    } else if (enemy.type === "tank") {
        // Chromium BSU TankShot: 100 damage heavy cannon
        var leadTime = 0.5;
        var predictedX = player.x + player.vx * leadTime;
        var predictedY = player.y + player.vy * leadTime;
        var baseAngle = Math.atan2(predictedY - enemy.y, predictedX - enemy.x);

        for (var s = -1; s <= 1; s++) {
            var a = baseAngle + s * 0.16;
            enemyBullets.push({
                x: enemy.x,
                y: enemy.y - 18,
                vx: Math.cos(a) * 230,
                vy: Math.sin(a) * 230,
                radius: 3.5,
                damage: 100,
                type: "cannon"
            });
        }
    }
}

// =============================================================================
// BOSS AI CONTROLLERS (Chromium BSU Authentic Values)
// =============================================================================
function updateBossAI(boss, dt, callbacks) {
    // Move into combat arena
    if (boss.y > boss.targetY) {
        boss.y -= 45 * dt;
    } else {
        // Hover and strafe
        boss.x = Math.sin(gameTime * 1.2) * Math.min(220, BOUND_X * 0.55);
    }

    boss.fireTimer -= dt;

    if (boss.type === "boss_raygun") {
        // Level 1: RayGun Cruiser Boss (RayGun Beams: 20 damage, Laser: 75 damage)
        if (boss.fireTimer <= 0) {
            boss.fireTimer = 1.6;
            enemyBullets.push({ x: boss.x - 48, y: boss.y - 20, vx: 0, vy: -400, radius: 4, damage: 20, type: "beam" });
            enemyBullets.push({ x: boss.x + 48, y: boss.y - 20, vx: 0, vy: -400, radius: 4, damage: 20, type: "beam" });
            enemyBullets.push({ x: boss.x - 20, y: boss.y - 30, vx: -40, vy: -280, radius: 3, damage: 75, type: "laser" });
            enemyBullets.push({ x: boss.x + 20, y: boss.y - 30, vx: 40, vy: -280, radius: 3, damage: 75, type: "laser" });
        }
    } else if (boss.type === "boss_tank") {
        // Level 2: Tank Dreadnought Boss (Heavy Cannons: 100 damage)
        if (boss.fireTimer <= 0) {
            boss.fireTimer = 1.5;
            var angle = Math.atan2(player.y - boss.y, player.x - boss.x);
            for (var i = -2; i <= 2; i++) {
                var a = angle + i * 0.18;
                enemyBullets.push({
                    x: boss.x + i * 16,
                    y: boss.y - 35,
                    vx: Math.cos(a) * 240,
                    vy: Math.sin(a) * 240,
                    radius: 4,
                    damage: 100,
                    type: "cannon"
                });
            }
        }
    } else if (boss.type === "boss0") {
        // Level 3: Boss0 Flagship (Straight: 75 damage, Omni: 6 damage, Death Ray: 20 damage continuous)
        boss.omniAngle += dt * 3.0;

        // 6-barrel straight battery
        if (boss.fireTimer <= 0) {
            boss.fireTimer = 0.55;
            for (var b = -3; b <= 3; b++) {
                if (b !== 0) {
                    enemyBullets.push({ x: boss.x + b * 22, y: boss.y - 45, vx: 0, vy: -320, radius: 3, damage: 75, type: "laser" });
                }
            }

            // Dual omni rotating spread
            for (var o = 0; o < 4; o++) {
                var oa = boss.omniAngle + (o * Math.PI / 2);
                enemyBullets.push({ x: boss.x - 60, y: boss.y, vx: Math.cos(oa) * 180, vy: Math.sin(oa) * 180, radius: 3, damage: 6, type: "omni" });
                enemyBullets.push({ x: boss.x + 60, y: boss.y, vx: Math.cos(oa) * 180, vy: Math.sin(oa) * 180, radius: 3, damage: 6, type: "omni" });
            }
        }

        // Central death-ray beam when player is beneath
        if (Math.abs(player.x - boss.x) < 32 && player.y < boss.y) {
            boss.deathRayTimer += dt;
            if (boss.deathRayTimer > 0.4) {
                enemyBullets.push({ x: boss.x, y: boss.y - 50, vx: (Math.random() - 0.5) * 20, vy: -520, radius: 6, damage: 20, type: "beam" });
            }
        } else {
            boss.deathRayTimer = 0;
        }
    } else if (boss.type === "boss1") {
        // Level 4: Boss1 Final Leviathan (Artillery Cannons: 100 damage)
        boss.missileSalvoTimer += dt;
        if (boss.fireTimer <= 0) {
            boss.fireTimer = 0.45;
            var baseA = Math.atan2(player.y - boss.y, player.x - boss.x);
            for (var m = -3; m <= 3; m++) {
                var ma = baseA + m * 0.15;
                enemyBullets.push({
                    x: boss.x + m * 20,
                    y: boss.y - 40,
                    vx: Math.cos(ma) * 220,
                    vy: Math.sin(ma) * 220,
                    radius: 3.5,
                    damage: 100,
                    type: "cannon"
                });
            }
        }
    }
}

// =============================================================================
// DAMAGE & ZERO-PASS PENALTY
// =============================================================================
function damagePlayer(amount, callbacks) {
    if (player.invulnerableTimer > 0 || player.isDead || player.isDying) return;

    var prevShields = player.shields;
    var prevHealth = player.health;

    triggerDamageBlink = true;
    screenShake = Math.min(15, screenShake + 6);

    if (player.shields > 0) {
        player.shields -= amount;
        if (player.shields < 0) {
            player.health += player.shields; // Overflow damages hull
            player.shields = 0;
        }
    } else {
        player.health -= amount;
    }

    if (player.health <= 0) {
        startPlayerDestruction(callbacks);
    } else {
        var wasCritical = (prevShields <= 50 && prevHealth <= 220);
        var nowCritical = (player.shields <= 50 && player.health <= 220);
        if (!wasCritical && nowCritical) {
            addFloatingBadge("⚠️ HULL CRITICAL! ⚠️", player.x, player.y + 35, "#FF1E40", 1.8);
            if (callbacks && callbacks.onSound) callbacks.onSound("target");
        } else {
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
        }
    }
}

function startPlayerDestruction(callbacks) {
    if (player.isDying || player.isDead) return;

    player.isDying = true;
    player.dyingTimer = 2.4;
    player.deathStage = 0;
    player.firing = false;
    player.health = 0;
    player.shields = 0;

    lives--;

    // Initial critical catastrophe
    screenShake = 22;
    triggerDamageBlink = true;
    triggerElectricFlash = true;

    if (callbacks && callbacks.onSound) callbacks.onSound("explosion");

    // Sparks spraying from damaged engines & chassis
    spawnSparkBurst(player.x - 14, player.y, "#00E5FF", 12);
    spawnSparkBurst(player.x + 14, player.y, "#FF5500", 12);

    shockwaves.push({
        x: player.x,
        y: player.y,
        radius: 8,
        maxRadius: 120,
        speed: 280,
        color: "#00E5FF"
    });
}

function killPlayer(callbacks) {
    startPlayerDestruction(callbacks);
}

function respawnPlayer() {
    var respawnY = -Math.round(BOUND_Y * 0.65);
    player.x = 0;
    player.y = respawnY;
    player.targetX = 0;
    player.targetY = respawnY;
    player.vx = 0;
    player.vy = 0;
    player.tilt = 0;
    var def = SHIP_CLASSES[player.shipClass || selectedShipId] || SHIP_CLASSES.interceptor;
    player.health = def.maxHealth;
    player.shields = def.maxShields;
    player.isDead = false;
    player.isDying = false;
    player.dyingTimer = 0;
    player.deathStage = 0;
    player.invulnerableTimer = 3.0;
    player.ammo[0] = Math.floor(player.ammo[0] * 0.5);
    player.ammo[1] = Math.floor(player.ammo[1] * 0.5);
    player.ammo[2] = Math.floor(player.ammo[2] * 0.5);

    shockwaves.push({ x: 0, y: respawnY, radius: 10, maxRadius: 120, speed: 220, color: "#00E5FF" });
    addFloatingBadge("RESPAWN • SHIELDS ACTIVE", 0, respawnY + 40, "#00E5FF", 1.8);
}

function onEnemyEscaped(callbacks) {
    if (player.isDead || player.isDying || gameState !== "playing") return;

    screenShake = 10;
    triggerDamageBlink = true;

    if (callbacks && callbacks.onSound) callbacks.onSound("explosion");

    var dangerBorderY = -BOUND_Y + 14;
    shockwaves.push({ x: 0, y: dangerBorderY, radius: 10, maxRadius: 300, speed: 450, color: "#FF2244" });
    addFloatingBadge("ZERO-PASS PENALTY: -1 LIFE!", 0, dangerBorderY + 30, "#FF2244", 1.8);

    startPlayerDestruction(callbacks);
}

// =============================================================================
// DESTRUCTION & POWER-UPS
// =============================================================================
function destroyEnemy(enemy, index, callbacks) {
    enemies.splice(index, 1);
    score += enemy.points;

    if (enemy === activeBoss) {
        onBossDefeated(enemy, callbacks);
        return;
    }

    if (callbacks && callbacks.onSound) callbacks.onSound("explosion");

    var color = (enemy.type === "tank" || enemy.type === "raygun") ? colorEnemyHeavy : colorEnemy;
    spawnVectorDebris(enemy.type, enemy.x, enemy.y, color, 10);
    spawnSparkBurst(enemy.x, enemy.y, color, 14);

    // Carrier drops 2-3 guaranteed powerups
    if (enemy.type === "carrier") {
        dropPowerUp(enemy.x - 20, enemy.y, "mg");
        dropPowerUp(enemy.x + 20, enemy.y, "shield");
        if (Math.random() < 0.5) {
            dropPowerUp(enemy.x, enemy.y - 15, "super_shield");
        }
    } else if (Math.random() < 0.14) {
        // Random drops based on original weighted table
        var r = Math.random();
        var type = "mg";
        if (r < 0.28) type = "mg";
        else if (r < 0.52) type = "plasma";
        else if (r < 0.72) type = "emp";
        else if (r < 0.86) type = "shield";
        else if (r < 0.96) type = "repair";
        else type = "super_shield";

        dropPowerUp(enemy.x, enemy.y, type);
    }
}

function dropPowerUp(x, y, type) {
    powerUps.push({
        type: type,
        baseX: x,
        baseY: y,
        x: x,
        y: y,
        vy: -45,
        timer: Math.random() * 10,
        rot: 0
    });
}

function collectPowerUp(pu, callbacks) {
    score += 250;
    triggerElectricFlash = true;

    if (callbacks && callbacks.onSound) callbacks.onSound("powerup");

    if (pu.type === "mg") {
        player.ammo[0] = Math.min(player.maxAmmo, player.ammo[0] + 150);
        addFloatingBadge("+MACHINE GUN AMMO (150)", player.x, player.y + 30, "#FFB800", 1.4);
    } else if (pu.type === "plasma") {
        player.ammo[1] = Math.min(player.maxAmmo, player.ammo[1] + 150);
        addFloatingBadge("+PLASMA CANNON AMMO (150)", player.x, player.y + 30, "#00FF66", 1.4);
    } else if (pu.type === "emp") {
        player.ammo[2] = Math.min(player.maxAmmo, player.ammo[2] + 150);
        addFloatingBadge("+EMP ARC AMMO (150)", player.x, player.y + 30, "#B84DFF", 1.4);
    } else if (pu.type === "repair") {
        player.health = player.maxHealth;
        addFloatingBadge("+HULL FULLY REPAIRED", player.x, player.y + 30, "#FF3366", 1.4);
    } else if (pu.type === "shield") {
        player.shields = Math.max(player.shields, player.maxShields);
        addFloatingBadge("+SHIELDS RECHARGED", player.x, player.y + 30, "#00E5FF", 1.4);
    } else if (pu.type === "super_shield") {
        player.health = player.maxHealth;
        player.shields = player.maxShields * 2; // Overcharge to 200%!
        addFloatingBadge("⭐ 200% SUPER SHIELD OVERCHARGE! ⭐", 0, player.y + 35, "#FFFF00", 2.0);
    }

    spawnSparkBurst(player.x, player.y, "#00FFFF", 16);
}

function onBossDefeated(boss, callbacks) {
    activeBoss = null;
    screenShake = 22;

    if (callbacks && callbacks.onSound) callbacks.onSound("explosionHuge");

    // Cascading explosion sequence
    for (var i = 0; i < 6; i++) {
        (function(idx) {
            scheduledWaves.push({
                time: levelTime + idx * 0.22,
                spawn: function() {
                    var ox = (Math.random() - 0.5) * boss.radius * 1.5;
                    var oy = (Math.random() - 0.5) * boss.radius * 1.5;
                    spawnSparkBurst(boss.x + ox, boss.y + oy, "#FFFFFF", 20);
                    shockwaves.push({ x: boss.x + ox, y: boss.y + oy, radius: 8, maxRadius: 80, speed: 200, color: themeAccent });
                    if (callbacks && callbacks.onSound) callbacks.onSound("explosionBig");
                }
            });
        })(i);
    }

    spawnVectorDebris(boss.type, boss.x, boss.y, themeAccent, 24);

    if (currentLevel >= 4) {
        // Endgame Victory!
        scheduledWaves.push({
            time: levelTime + 2.0,
            spawn: function() {
                gameState = "victory";
                if (callbacks && callbacks.onSound) callbacks.onSound("win");
            }
        });
    } else {
        // Sector Cleared Intermission
        scheduledWaves.push({
            time: levelTime + 2.0,
            spawn: function() {
                sectorCleared(callbacks);
            }
        });
    }
}

function sectorCleared(callbacks) {
    gameState = "sector_cleared";
    if (callbacks && callbacks.onSound) callbacks.onSound("win");

    var shieldBonus = Math.floor(player.shields * 5);
    var cleanBonus = 5000 * currentLevel;
    var totalBonus = shieldBonus + cleanBonus;
    score += totalBonus;

    addFloatingBadge("SECTOR " + currentLevel + " CLEARED! +" + totalBonus, 0, 40, "#00FF66", 3.0);

    // Auto-advance after 3.2 seconds
    scheduledWaves.push({
        time: levelTime + 3.2,
        spawn: function() {
            advanceNextLevel();
        }
    });
}

function advanceNextLevel() {
    if (currentLevel < 4) {
        gameState = "playing";
        loadLevel(currentLevel + 1);
    } else {
        gameState = "victory";
    }
}

// =============================================================================
// PARTICLES & DEBRIS SPAWNERS
// =============================================================================
function spawnPlayerDebris(cx, cy) {
    var model = getPlayerModel();
    var lines = [];

    for (var m = 0; m < model.length; m++) {
        var poly = model[m];
        for (var p = 0; p < poly.length - 1; p++) {
            lines.push([poly[p], poly[p+1]]);
        }
    }

    // Spawn EVERY distinct line segment of the ship model as a tumbling shard
    for (var i = 0; i < lines.length; i++) {
        var seg = lines[i];
        var midX = (seg[0][0] + seg[1][0]) * 0.5;
        var midY = (seg[0][1] + seg[1][1]) * 0.5;
        var outAngle = Math.atan2(midY, midX) + (Math.random() - 0.5) * 0.7;
        var spd = 70 + Math.random() * 200;
        vectorDebris.push({
            x: cx + midX,
            y: cy + midY,
            vx: Math.cos(outAngle) * spd,
            vy: Math.sin(outAngle) * spd - 30, // slight upward ejection
            rot: player.tilt + (Math.random() - 0.5) * 0.8,
            vRot: (Math.random() - 0.5) * 16,
            seg: [
                [seg[0][0] - midX, seg[0][1] - midY],
                [seg[1][0] - midX, seg[1][1] - midY]
            ],
            color: (i % 3 === 0) ? "#FFFFFF" : (i % 2 === 0 ? "#FF3366" : themeAccent),
            life: 2.2,
            maxLife: 2.2,
            isPlayer: true
        });
    }
}

function spawnVectorDebris(modelKey, cx, cy, color, count) {
    var model = VectorModels[modelKey] || VectorModels.gnat;
    var lines = [];

    for (var m = 0; m < model.length; m++) {
        var poly = model[m];
        for (var p = 0; p < poly.length - 1; p++) {
            lines.push([poly[p], poly[p+1]]);
        }
    }

    // Prune enemy debris while preserving player debris
    if (vectorDebris.length > 55) {
        for (var pr = 0; pr < vectorDebris.length && vectorDebris.length > 35; pr++) {
            if (!vectorDebris[pr].isPlayer) {
                vectorDebris.splice(pr, 1);
                pr--;
            }
        }
    }

    var numDebris = Math.min(lines.length, count || 10);
    for (var i = 0; i < numDebris; i++) {
        var seg = lines[Math.floor(Math.random() * lines.length)];
        var angle = Math.random() * Math.PI * 2;
        var spd = 60 + Math.random() * 160;
        vectorDebris.push({
            x: cx,
            y: cy,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd,
            rot: Math.random() * Math.PI * 2,
            vRot: (Math.random() - 0.5) * 12,
            seg: seg,
            color: color || themeAccent,
            life: 1.0,
            maxLife: 1.0,
            isPlayer: false
        });
    }
}

function spawnSparkBurst(x, y, color, count) {
    if (particles.length > 90) {
        particles.splice(0, particles.length - 75);
    }

    for (var i = 0; i < count; i++) {
        var angle = Math.random() * Math.PI * 2;
        var spd = 35 + Math.random() * 180;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(angle) * spd,
            vy: Math.sin(angle) * spd,
            life: 0.35 + Math.random() * 0.4,
            maxLife: 0.75,
            color: color || "#FFFFFF"
        });
    }
}

function addFloatingBadge(text, x, y, color, life) {
    floatingBadges.push({
        text: text,
        x: x,
        y: y,
        vy: 28,
        life: life || 1.6,
        maxLife: life || 1.6,
        color: color || "#FFFFFF"
    });
}

// =============================================================================
// VECTOR WIREFRAME RENDERER
// =============================================================================
function render(ctx) {
    var cw = width;
    var ch = height;

    ctx.clearRect(0, 0, cw, ch);
    ctx.fillStyle = themeBg;
    ctx.fillRect(0, 0, cw, ch);

    ctx.save();

    // Screen Shake
    if (screenShake > 0) {
        var shakeX = (Math.random() - 0.5) * screenShake * 2;
        var shakeY = (Math.random() - 0.5) * screenShake * 2;
        ctx.translate(shakeX, shakeY);
    }

    ctx.translate(cw / 2, ch / 2);

    var scale = width / (BOUND_X * 2);
    ctx.scale(scale, -scale);

    // 1. Starfield Parallax (Batched high-speed draw)
    ctx.fillStyle = "#FFFFFF";
    for (var s = 0; s < stars.length; s++) {
        var star = stars[s];
        ctx.globalAlpha = star.brightness;
        if (gameState === "sector_cleared") {
            ctx.strokeStyle = "#89b4fa";
            ctx.lineWidth = star.size;
            ctx.beginPath();
            ctx.moveTo(star.x, star.y);
            ctx.lineTo(star.x, star.y + 24);
            ctx.stroke();
        } else {
            ctx.fillRect(star.x, star.y, star.size, star.size);
        }
    }
    ctx.globalAlpha = 1.0;

    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    // 2. Shockwaves (Smooth vector rings)
    for (var w = 0; w < shockwaves.length; w++) {
        var sw = shockwaves[w];
        ctx.strokeStyle = sw.color;
        var alpha = Math.max(0, 1 - sw.radius / sw.maxRadius);
        ctx.beginPath();
        ctx.arc(sw.x, sw.y, sw.radius, 0, Math.PI * 2);

        // Halo Bloom
        ctx.globalAlpha = alpha * 0.35;
        ctx.lineWidth = 5.0;
        ctx.stroke();

        // Core
        ctx.globalAlpha = alpha;
        ctx.lineWidth = 2.0;
        ctx.stroke();
    }
    ctx.globalAlpha = 1.0;

    // 3. Power-Ups (Vector rotating capsules with specialized inner icons)
    for (var p = 0; p < powerUps.length; p++) {
        var pu = powerUps[p];
        ctx.save();
        ctx.translate(pu.x, pu.y);
        ctx.rotate(pu.rot);

        var pCol = pu.type === "mg" ? "#FFB800" :
                  (pu.type === "plasma" ? "#00FF66" :
                  (pu.type === "emp" ? "#B84DFF" :
                  (pu.type === "repair" ? "#FF3366" :
                  (pu.type === "shield" ? "#00E5FF" : "#FFFF00"))));

        ctx.strokeStyle = pCol;
        ctx.beginPath();
        // Outer faceted diamond capsule
        ctx.moveTo(0, 14); ctx.lineTo(14, 0); ctx.lineTo(0, -14); ctx.lineTo(-14, 0); ctx.closePath();

        // Inner specialized vector iconography matching power-up role
        if (pu.type === "repair") {
            // Health: Medical Cross (+)
            ctx.moveTo(-5, 0); ctx.lineTo(5, 0);
            ctx.moveTo(0, -5); ctx.lineTo(0, 5);
        } else if (pu.type === "shield") {
            // Shield: Kinetic barrier ring (circle)
            ctx.arc(0, 0, 5.5, 0, Math.PI * 2);
        } else if (pu.type === "mg") {
            // Machine Gun: Dual ballistic ammo tracers (||)
            ctx.moveTo(-3, -5); ctx.lineTo(-3, 5);
            ctx.moveTo(3, -5); ctx.lineTo(3, 5);
        } else if (pu.type === "plasma") {
            // Plasma: Dual concentric energy core (◎)
            ctx.arc(0, 0, 5, 0, Math.PI * 2);
            ctx.arc(0, 0, 2.2, 0, Math.PI * 2);
        } else if (pu.type === "emp") {
            // EMP: Electric lightning arc (⚡)
            ctx.moveTo(2, -6); ctx.lineTo(-3, 0); ctx.lineTo(3, 0); ctx.lineTo(-2, 6);
        } else if (pu.type === "super_shield") {
            // Super Shield: 8-point celestial starburst (✱)
            ctx.moveTo(-6, 0); ctx.lineTo(6, 0);
            ctx.moveTo(0, -6); ctx.lineTo(0, 6);
            ctx.moveTo(-4, -4); ctx.lineTo(4, 4);
            ctx.moveTo(-4, 4); ctx.lineTo(4, -4);
        } else {
            ctx.strokeRect(-4, -4, 8, 8);
        }

        // Bloom Pass
        ctx.globalAlpha = 0.32;
        ctx.lineWidth = 4.5;
        ctx.stroke();

        // Sharp Core Pass
        ctx.globalAlpha = 1.0;
        ctx.lineWidth = 1.8;
        ctx.stroke();

        ctx.restore();
    }

    // 4. Player Bullets (Batched by weapon type with matching color codes)
    var normalPBullets = [];
    var mgPBullets = [];
    var plasmaPBullets = [];
    var empPBullets = [];

    for (var pbIdx = 0; pbIdx < playerBullets.length; pbIdx++) {
        var pb = playerBullets[pbIdx];
        if (pb.type === "plasma") {
            plasmaPBullets.push(pb);
        } else if (pb.type === "emp") {
            empPBullets.push(pb);
        } else if (pb.type === "mg") {
            mgPBullets.push(pb);
        } else {
            normalPBullets.push(pb);
        }
    }

    // A. Normal, Needle & Siege Blasters (Theme Accent)
    if (normalPBullets.length > 0) {
        ctx.beginPath();
        for (var nb = 0; nb < normalPBullets.length; nb++) {
            var npb = normalPBullets[nb];
            if (npb.type === "needle") {
                ctx.moveTo(npb.x, npb.y - 12);
                ctx.lineTo(npb.x, npb.y + 12);
            } else if (npb.type === "siege") {
                ctx.moveTo(npb.x - 2, npb.y - 8);
                ctx.lineTo(npb.x + 2, npb.y - 8);
                ctx.lineTo(npb.x + 2, npb.y + 8);
                ctx.lineTo(npb.x - 2, npb.y + 8);
                ctx.closePath();
            } else {
                ctx.moveTo(npb.x, npb.y - 8);
                ctx.lineTo(npb.x, npb.y + 8);
            }
        }
        ctx.strokeStyle = themeAccent;
        ctx.lineWidth = 4.5;
        ctx.globalAlpha = 0.32;
        ctx.stroke();
        ctx.lineWidth = 1.8;
        ctx.globalAlpha = 1.0;
        ctx.stroke();
    }

    // B. Machine Gun Rapid Stream (Solar Gold #FFB800)
    if (mgPBullets.length > 0) {
        ctx.beginPath();
        for (var mb = 0; mb < mgPBullets.length; mb++) {
            var mpb = mgPBullets[mb];
            ctx.moveTo(mpb.x, mpb.y - 7);
            ctx.lineTo(mpb.x, mpb.y + 7);
        }
        ctx.strokeStyle = "#FFB800";
        ctx.lineWidth = 4.0;
        ctx.globalAlpha = 0.35;
        ctx.stroke();
        ctx.lineWidth = 1.8;
        ctx.globalAlpha = 1.0;
        ctx.stroke();
    }

    // C. Plasma Cannon Orbs (Neon Acid Green #00FF66)
    for (var pl = 0; pl < plasmaPBullets.length; pl++) {
        var ppb = plasmaPBullets[pl];
        ctx.strokeStyle = "#00FF66";
        ctx.beginPath();
        ctx.arc(ppb.x, ppb.y, ppb.radius, 0, Math.PI * 2);
        ctx.arc(ppb.x, ppb.y, ppb.radius * 0.45, 0, Math.PI * 2);
        ctx.lineWidth = 5.0;
        ctx.globalAlpha = 0.35;
        ctx.stroke();
        ctx.lineWidth = 2.0;
        ctx.globalAlpha = 1.0;
        ctx.stroke();
    }

    // D. EMP Arc Bolts (Electric Violet #B84DFF)
    if (empPBullets.length > 0) {
        ctx.beginPath();
        for (var ep = 0; ep < empPBullets.length; ep++) {
            var epb = empPBullets[ep];
            ctx.moveTo(epb.x, epb.y - 8);
            ctx.lineTo(epb.x - 3, epb.y);
            ctx.lineTo(epb.x + 3, epb.y + 4);
            ctx.lineTo(epb.x, epb.y + 10);
        }
        ctx.strokeStyle = "#B84DFF";
        ctx.lineWidth = 4.8;
        ctx.globalAlpha = 0.35;
        ctx.stroke();
        ctx.lineWidth = 1.8;
        ctx.globalAlpha = 1.0;
        ctx.stroke();
    }

    // 5. Enemy Projectiles (Batched in 1 single path!)
    if (enemyBullets.length > 0) {
        ctx.beginPath();
        for (var ebIdx = 0; ebIdx < enemyBullets.length; ebIdx++) {
            var ebul = enemyBullets[ebIdx];
            ctx.moveTo(ebul.x + ebul.radius, ebul.y);
            ctx.arc(ebul.x, ebul.y, ebul.radius, 0, Math.PI * 2);
        }
        ctx.strokeStyle = colorEnemy;
        // Bloom
        ctx.lineWidth = 4.2;
        ctx.globalAlpha = 0.30;
        ctx.stroke();
        // Core
        ctx.lineWidth = 1.8;
        ctx.globalAlpha = 1.0;
        ctx.stroke();
    }

    // 6. Enemies & Bosses (Batched multi-segment vector ships)
    for (var e = 0; e < enemies.length; e++) {
        var en = enemies[e];
        var isBoss = (en === activeBoss);
        var eColor = isBoss ? "#FF0055" :
                    ((en.type === "tank" || en.type === "raygun") ? colorEnemyHeavy :
                    (en.type === "carrier" ? "#FFCC00" : colorEnemy));

        var isInvulnerable = (en.invulnerableTimer && en.invulnerableTimer > 0);

        // Pulsing white effect when enemy is near blowing up (pure color pulse, no target reticles)
        var isEnemyCritical = (en.maxHealth > 0 && en.health < en.maxHealth && (en.health <= en.maxHealth * 0.35 || en.health <= 35));

        ctx.save();
        ctx.translate(en.x, en.y);
        if (en.rotation !== 0) ctx.rotate(en.rotation);

        if (isEnemyCritical) {
            var isEmergency = (en.health <= en.maxHealth * 0.18 || en.health <= 18);
            var pulseRate = isEmergency ? 28 : 16;
            var pulse = (Math.sin(gameTime * pulseRate) + 1) * 0.5;

            // Alternate between brilliant incandescent white (#FFFFFF) and base enemy color / dimmed tone
            if (pulse > 0.35) {
                eColor = "#FFFFFF";
            } else {
                eColor = isEmergency ? "#D8D8D8" : eColor;
            }
        }

        var model = VectorModels[en.type] || VectorModels.gnat;
        drawModel(ctx, model, eColor, isBoss || isEnemyCritical);

        // Boss initial entry shield barrier (1.0s invulnerability grace window)
        if (isBoss && isInvulnerable) {
            ctx.save();
            ctx.strokeStyle = "#00E5FF";
            ctx.lineWidth = 2.4;
            ctx.globalAlpha = 0.45 + Math.sin(gameTime * 22) * 0.35;
            ctx.beginPath();
            ctx.arc(0, 0, (en.radius || 46) + 8, 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        }

        ctx.restore();
    }

    // 7. Player Fighter & Super Shield
    if (!player.isDead) {
        ctx.save();
        ctx.translate(player.x, player.y);
        ctx.rotate(player.tilt);

        if (player.isDying) {
            // High-voltage catastrophic electrical failure prior to core detonation
            var flicker = Math.floor(gameTime * 30) % 2 === 0;
            var deathCol = flicker ? "#FFFFFF" : "#FF3366";
            ctx.save();
            ctx.translate((Math.random() - 0.5) * 6, (Math.random() - 0.5) * 6);
            drawModel(ctx, getPlayerModel(), deathCol, true);
            ctx.restore();
        } else {
            // Standard Kinetic Shield Ring
            if (player.shields > 0) {
                ctx.strokeStyle = colorShield;
                ctx.beginPath();
                ctx.arc(0, 0, 26, 0, Math.PI * 2);
                // Bloom
                ctx.lineWidth = 4.2;
                ctx.globalAlpha = 0.28;
                ctx.stroke();
                // Core
                ctx.lineWidth = 1.8;
                ctx.globalAlpha = 1.0;
                ctx.stroke();
            }

            // 200% Super Shield Outer Dual Barrier Ring
            if (player.shields > player.maxShields) {
                ctx.save();
                ctx.rotate(player.superShieldRingAngle);
                drawModel(ctx, VectorModels.superShield, colorSuperShield, false);
                ctx.restore();
            }

            // Player Ship Body & Critical Damage Pulsing Warning
            var isCritical = (player.shields <= 50 && player.health <= (player.maxHealth * 0.44));
            var shipColor = themeAccent;

            if (isCritical) {
                var isEmergency = player.health <= (player.maxHealth * 0.22);
                var pulseRate = isEmergency ? 28 : 16;
                var pulse = (Math.sin(gameTime * pulseRate) + 1) * 0.5;

                // Alternate between vibrant emergency crimson (#FF0033) and warning amber/cyan
                if (pulse > 0.35) {
                    shipColor = "#FF0033";
                } else {
                    shipColor = isEmergency ? "#FF6600" : themeAccent;
                }

                // Pulsing emergency warning reticle & hazard brackets around ship
                ctx.save();
                ctx.strokeStyle = "#FF0033";
                var hazardRadius = 25 + pulse * 6;
                ctx.lineWidth = 1.6;
                ctx.globalAlpha = 0.25 + pulse * 0.6;

                // Pulsing hazard perimeter circle
                ctx.beginPath();
                ctx.arc(0, 0, hazardRadius, 0, Math.PI * 2);
                ctx.stroke();

                // 4 warning corner brackets around the ship
                var bSize = 6;
                var bDist = hazardRadius + 3;
                ctx.beginPath();
                // Top-Left
                ctx.moveTo(-bDist, -bDist + bSize);
                ctx.lineTo(-bDist, -bDist);
                ctx.lineTo(-bDist + bSize, -bDist);
                // Top-Right
                ctx.moveTo(bDist - bSize, -bDist);
                ctx.lineTo(bDist, -bDist);
                ctx.lineTo(bDist, -bDist + bSize);
                // Bottom-Left
                ctx.moveTo(-bDist, bDist - bSize);
                ctx.lineTo(-bDist, bDist);
                ctx.lineTo(-bDist + bSize, bDist);
                // Bottom-Right
                ctx.moveTo(bDist - bSize, bDist);
                ctx.lineTo(bDist, bDist);
                ctx.lineTo(bDist, bDist - bSize);
                ctx.stroke();

                ctx.restore();
            }

            drawModel(ctx, getPlayerModel(), shipColor, isCritical);
        }

        ctx.restore();
    }

    // 8. Vector Debris
    for (var d = 0; d < vectorDebris.length; d++) {
        var deb = vectorDebris[d];
        var alpha = Math.max(0, deb.life / deb.maxLife);
        ctx.save();
        ctx.translate(deb.x, deb.y);
        ctx.rotate(deb.rot);
        ctx.strokeStyle = deb.color;

        ctx.beginPath();
        ctx.moveTo(deb.seg[0][0], deb.seg[0][1]);
        ctx.lineTo(deb.seg[1][0], deb.seg[1][1]);

        if (deb.isPlayer) {
            // Dual-pass glowing phosphor bloom for player debris
            ctx.lineWidth = 4.4;
            ctx.globalAlpha = alpha * 0.35;
            ctx.stroke();

            ctx.lineWidth = 2.0;
            ctx.globalAlpha = alpha;
            ctx.stroke();
        } else {
            ctx.lineWidth = 1.8;
            ctx.globalAlpha = alpha;
            ctx.stroke();
        }
        ctx.restore();
    }
    ctx.globalAlpha = 1.0;

    // 9. Sparks (Fast fillRects with zero shadowBlur)
    for (var pt = 0; pt < particles.length; pt++) {
        var part = particles[pt];
        ctx.fillStyle = part.color;
        ctx.globalAlpha = Math.max(0, part.life / part.maxLife);
        ctx.fillRect(part.x - 1, part.y - 1, 2.5, 2.5);
    }
    ctx.globalAlpha = 1.0;

    // 10. Floating Combat Badges
    ctx.save();
    ctx.scale(1, -1);
    ctx.font = "bold 13px monospace";
    ctx.textAlign = "center";
    for (var fbIdx = 0; fbIdx < floatingBadges.length; fbIdx++) {
        var bge = floatingBadges[fbIdx];
        ctx.fillStyle = bge.color;
        ctx.globalAlpha = Math.max(0, bge.life / bge.maxLife);
        ctx.fillText(bge.text, bge.x, -bge.y);
    }
    ctx.restore();
    ctx.globalAlpha = 1.0;

    // 11. Bottom Danger Line (Zero-Pass Penalty Border)
    var dangerY = -BOUND_Y + 14;
    ctx.strokeStyle = "#FF2244";
    ctx.lineWidth = 1.6;
    ctx.setLineDash([8, 8]);
    ctx.beginPath();
    ctx.moveTo(-BOUND_X, dangerY);
    ctx.lineTo(BOUND_X, dangerY);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.restore();
}

function drawModel(ctx, model, color, isBoss) {
    ctx.beginPath();
    for (var i = 0; i < model.length; i++) {
        var poly = model[i];
        ctx.moveTo(poly[0][0], poly[0][1]);
        for (var j = 1; j < poly.length; j++) {
            ctx.lineTo(poly[j][0], poly[j][1]);
        }
    }

    // Pass 1: CRT Vector Phosphor Bloom (pure GPU/raster line halo, zero Gaussian blur overhead)
    ctx.strokeStyle = color;
    ctx.lineWidth = isBoss ? 5.2 : 3.8;
    ctx.globalAlpha = 0.28;
    ctx.stroke();

    // Pass 2: Bright Sharp Vector Core
    ctx.lineWidth = isBoss ? 2.4 : 1.6;
    ctx.globalAlpha = 1.0;
    ctx.stroke();
}
