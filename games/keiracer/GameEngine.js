// =============================================================================
// KeiRacer • Pseudo-3D Arcade Racing Engine
// OutRun-style scanline road projection, track elevation, AI traffic,
// authentic multi-vehicle drivetrain simulation, transmission gear physics,
// and dynamic particle systems.
// =============================================================================

.pragma library

// --- Configuration Constants ---
var ROAD_WIDTH = 2000;
var SEGMENT_LENGTH = 200;
var RUMBLE_LENGTH = 3;
var LANES = 3;
var FIELD_OF_VIEW = 100;
var CAMERA_HEIGHT = 1000;
var CAMERA_DEPTH = 1 / Math.tan((FIELD_OF_VIEW / 2) * Math.PI / 180);
var DRAW_DISTANCE = 100;
var FOG_DENSITY = 5;

// --- Vehicle Drivetrain Presets & Transmission Specs ---
var VEHICLE_PRESETS = {
    keitruck: {
        id: "keitruck",
        prefix: "kei",
        name: "Suzuki Carry Kei",
        tagline: "The Star • 658cc Naturally Aspirated",
        type: "manual",
        gears: [4.42, 2.50, 1.63, 1.00, 0.82],
        finalDrive: 5.125,
        kRPMPerSpeed: 12.38,
        idleRPM: 850,
        peakPowerRPM: 5500,
        shiftRPM: 5600,
        redlineRPM: 6800,
        gaugeMaxRPM: 8000,
        downshiftRPM: 2700,
        shiftTime: 0.16,
        topSpeed: 110, // km/h (~68 mph)
        zeroSixtyTime: 18.5,
        brakePower: 29.0, // km/h/s (~3.8s from top speed to 0)
        engineSound: "engine_kei",
        hasTurbo: false,
        baseH: 212,
        aspectStraight: 439 / 466,
        spriteKey: "kei_straight"
    },
    smart: {
        id: "smart",
        prefix: "smart",
        name: "Smart Fortwo",
        tagline: "City Micro • 599cc 3-Cylinder",
        type: "manual",
        gears: [3.31, 2.05, 1.39, 0.98, 0.76],
        finalDrive: 4.12,
        kRPMPerSpeed: 10.54,
        idleRPM: 900,
        peakPowerRPM: 5250,
        shiftRPM: 5100,
        redlineRPM: 6000,
        gaugeMaxRPM: 7000,
        downshiftRPM: 2400,
        shiftTime: 0.22,
        topSpeed: 135, // km/h (~84 mph, factory governed)
        zeroSixtyTime: 15.5,
        brakePower: 38.0, // km/h/s (~3.5s from top speed to 0, crisp modern ABS)
        engineSound: "engine_smart",
        hasTurbo: false,
        baseH: 202,
        aspectStraight: 462 / 427,
        spriteKey: "smart_straight"
    },
    panda: {
        id: "panda",
        prefix: "panda",
        name: "Fiat Panda 4x4",
        tagline: "Box on Wheels • 999cc FIRE",
        type: "manual",
        gears: [3.91, 2.16, 1.48, 1.12, 0.83],
        finalDrive: 4.47,
        kRPMPerSpeed: 10.51,
        idleRPM: 850,
        peakPowerRPM: 5250,
        shiftRPM: 4900,
        redlineRPM: 6000,
        gaugeMaxRPM: 7000,
        downshiftRPM: 2200,
        shiftTime: 0.18,
        topSpeed: 125, // km/h (~78 mph)
        zeroSixtyTime: 17.5,
        brakePower: 31.0, // km/h/s (~4.0s from top speed to 0)
        engineSound: "engine_panda",
        hasTurbo: false,
        baseH: 200,
        aspectStraight: 432 / 425,
        spriteKey: "panda_straight"
    },
    sidekick: {
        id: "sidekick",
        prefix: "sidekick",
        name: "Suzuki Sidekick",
        tagline: "Rugged Mini-4x4 • 1.6L 8-Valve",
        type: "manual",
        gears: [3.65, 1.95, 1.38, 1.00, 0.86],
        finalDrive: 5.12,
        kRPMPerSpeed: 8.63,
        idleRPM: 800,
        peakPowerRPM: 5400,
        shiftRPM: 5100,
        redlineRPM: 6000,
        gaugeMaxRPM: 7000,
        downshiftRPM: 2400,
        shiftTime: 0.18,
        topSpeed: 130, // km/h (~81 mph)
        zeroSixtyTime: 14.5,
        brakePower: 30.0, // km/h/s (~4.3s from top speed to 0)
        engineSound: "engine_sidekick",
        hasTurbo: false,
        baseH: 205,
        aspectStraight: 437 / 439,
        spriteKey: "sidekick_straight"
    },
    wrangler: {
        id: "wrangler",
        prefix: "wrangler",
        name: "Jeep Wrangler YJ",
        tagline: "Square Headlights • 2.5L AMC 150",
        type: "manual",
        gears: [3.83, 2.33, 1.44, 1.00, 0.79],
        finalDrive: 4.10,
        kRPMPerSpeed: 7.44,
        idleRPM: 750,
        peakPowerRPM: 5200,
        shiftRPM: 4300, // Optimal shift point in the 3,200 torque sweet spot!
        redlineRPM: 5250,
        gaugeMaxRPM: 6000,
        downshiftRPM: 2000,
        shiftTime: 0.20,
        topSpeed: 125, // km/h (~78 mph real-world aero limit)
        zeroSixtyTime: 14.8,
        brakePower: 28.0, // km/h/s (~4.4s from top speed to 0, solid axles)
        engineSound: "engine_wrangler",
        hasTurbo: false,
        baseH: 208,
        aspectStraight: 376 / 367,
        spriteKey: "wrangler_straight"
    },
    vwbus: {
        id: "vwbus",
        prefix: "vwbus",
        name: "Volkswagen Type 2 Bus",
        tagline: "Air-Cooled Classic • 1.6L Flat-4",
        type: "manual",
        gears: [3.80, 2.06, 1.26, 0.82],
        finalDrive: 4.375,
        kRPMPerSpeed: 10.03,
        idleRPM: 850,
        peakPowerRPM: 4000,
        shiftRPM: 3900, // Power falls rapidly past 4,000 RPM
        redlineRPM: 4400,
        gaugeMaxRPM: 5000,
        downshiftRPM: 1800,
        shiftTime: 0.24,
        topSpeed: 105, // km/h (~65 mph)
        zeroSixtyTime: 23.5,
        brakePower: 22.0, // km/h/s (~4.7s from top speed to 0, classic drum brakes)
        engineSound: "engine_vwbus",
        hasTurbo: false,
        baseH: 220,
        aspectStraight: 347 / 355,
        spriteKey: "vwbus_straight"
    }
};

// Speeds & Physics
var selectedCar = "keitruck";
var MAX_SPEED = 110; // km/h (updated per car)
var ACCEL = (96.5 / 18.5) * 1.05;
var BREAKING = -29.0;
var DECEL = -MAX_SPEED / 15.0;
var OFF_ROAD_DECEL = -MAX_SPEED / 2.5;
var OFF_ROAD_LIMIT = MAX_SPEED / 4.0;
var CENTRIFUGAL = 0.32;

// Drivetrain State
var currentGear = 1;
var currentRPM = 850;
var idleRPM = 850;
var redlineRPM = 6800;
var shiftRPM = 5600;
var gaugeMaxRPM = 8000;
var shiftCutTimer = 0;
var isShiftCut = false;
var wasAccelerating = false;

// --- Engine State ---
var width = 800;
var height = 500;
var segments = [];
var trackLength = 0;

var playerX = 0; // -1 (left shoulder) to 1 (right shoulder)
var playerZ = 0; // distance along track
var speed = 0;
var steering = 0; // -1 (left) to 1 (right)
var playerSteerTime = 0; // 0.0 to 3.0 seconds turning duration
var playerSteerDir = 0;  // -1 (left), 0 (center), 1 (right)
var isBraking = false;
var isDrifting = false;
var driftAngle = 0;
var boostTimer = 0;
var turboFlames = 0;
var bounce = 0;

var score = 0;
var distanceTraveled = 0;
var timeLeft = 50.0;
var gameOver = false;
var stageCompleted = false;
var stage = 1;
var totalCheckpoints = 0;

// Camera shake
var shakeIntensity = 0;
var engineSoundTimer = 0;
var offroadSoundTimer = 0;
var collisionCooldown = 0;

// Particles (smoke, sparks, turbo flame)
var particles = [];

// AI Traffic (Slow Car Racing League)
var cars = [];
var CAR_TYPES = [
    { id: "keitruck", prefix: "kei", name: "Suzuki Carry", spriteKey: "kei_straight", color: "#f8fafc", roof: "#e2e8f0", speedRatio: 0.55 },
    { id: "smart", prefix: "smart", name: "Smart Fortwo", spriteKey: "smart_straight", color: "#ef4444", roof: "#0f172a", speedRatio: 0.58 },
    { id: "panda", prefix: "panda", name: "Fiat Panda", spriteKey: "panda_straight", color: "#38bdf8", roof: "#0f172a", speedRatio: 0.52 },
    { id: "sidekick", prefix: "sidekick", name: "Suzuki Sidekick", spriteKey: "sidekick_straight", color: "#eab308", roof: "#1e293b", speedRatio: 0.56 },
    { id: "wrangler", prefix: "wrangler", name: "Wrangler YJ", spriteKey: "wrangler_straight", color: "#1e293b", roof: "#0f172a", speedRatio: 0.57 },
    { id: "vwbus", prefix: "vwbus", name: "VW Bus", spriteKey: "vwbus_straight", color: "#f97316", roof: "#f8fafc", speedRatio: 0.45 }
];

// Roadside Scenery Objects
var SPRITE_TYPES = {
    PALM: { width: 380, height: 760 },
    BILLBOARD_OMARCHY: { width: 550, height: 320 },
    BILLBOARD_QUATTRO: { width: 550, height: 320 },
    NEON_SIGN: { width: 380, height: 380 },
    STREET_LIGHT: { width: 200, height: 620 },
    CHECKPOINT_ARCH: { width: 2200, height: 600 }
};

// --- Math & Helper Utilities ---
function easeIn(a, b, percent) {
    return a + (b - a) * Math.pow(percent, 2);
}

function easeOut(a, b, percent) {
    return a + (b - a) * (1 - Math.pow(1 - percent, 2));
}

function easeInOut(a, b, percent) {
    return a + (b - a) * ((-Math.cos(percent * Math.PI) / 2) + 0.5);
}

function percentRemaining(n, total) {
    return (n % total) / total;
}

function interpolate(a, b, percent) {
    return a + (b - a) * percent;
}

function findSegment(z) {
    var index = Math.floor(z / SEGMENT_LENGTH) % segments.length;
    if (index < 0) index += segments.length;
    return segments[index];
}

// 3D to 2D projection
function project(point, cameraX, cameraY, cameraZ, cameraDepth, screenWidth, screenHeight, roadW) {
    var transX = point.world.x - cameraX;
    var transY = point.world.y - cameraY;
    var transZ = point.world.z - cameraZ;

    point.camera.x = transX;
    point.camera.y = transY;
    point.camera.z = transZ;

    point.screen.scale = cameraDepth / Math.max(1, transZ);
    point.screen.x = Math.round((screenWidth / 2) + (point.screen.scale * transX * screenWidth / 2));
    point.screen.y = Math.round((screenHeight / 2) - (point.screen.scale * transY * screenHeight / 2));
    point.screen.w = Math.round(point.screen.scale * roadW * screenWidth / 2);
}

// --- Track Generation ---
function addSegment(curve, y) {
    var n = segments.length;
    var lastY = n > 0 ? segments[n - 1].p2.world.y : 0;
    segments.push({
        index: n,
        p1: { world: { x: 0, y: lastY, z: n * SEGMENT_LENGTH }, camera: {}, screen: {} },
        p2: { world: { x: 0, y: y, z: (n + 1) * SEGMENT_LENGTH }, camera: {}, screen: {} },
        curve: curve,
        sprites: [],
        cars: [],
        color: {
            road: (Math.floor(n / RUMBLE_LENGTH) % 2) ? "#1e1b2e" : "#171424",
            grass: (Math.floor(n / RUMBLE_LENGTH) % 2) ? "#120e22" : "#0d0a1b",
            rumble: (Math.floor(n / RUMBLE_LENGTH) % 2) ? "#ff007f" : "#00f0ff",
            lane: (Math.floor(n / RUMBLE_LENGTH) % 2) ? "#ffffff" : null
        },
        isCheckpoint: false
    });
}

function addRoad(enter, hold, leave, curve, y) {
    var startY = segments.length > 0 ? segments[segments.length - 1].p2.world.y : 0;
    var endY = startY + y;
    var total = enter + hold + leave;
    for (var i = 0; i < enter; i++) {
        addSegment(easeIn(0, curve, i / enter), easeInOut(startY, endY, i / total));
    }
    for (var j = 0; j < hold; j++) {
        addSegment(curve, easeInOut(startY, endY, (enter + j) / total));
    }
    for (var k = 0; k < leave; k++) {
        addSegment(easeInOut(curve, 0, k / leave), easeInOut(startY, endY, (enter + hold + k) / total));
    }
}

function addStraight(num) {
    num = num || 50;
    addRoad(num, num, num, 0, 0);
}

function addHill(num, height) {
    num = num || 50;
    height = height || 800;
    addRoad(num, num, num, 0, height);
}

function addCurve(num, curve, height) {
    num = num || 60;
    curve = curve || 3;
    height = height || 0;
    addRoad(num, num, num, curve, height);
}

function addLowRollingHills(num, height) {
    num = num || 60;
    height = height || 400;
    addRoad(num, num, num, 0, height / 2);
    addRoad(num, num, num, 0, -height);
    addRoad(num, num, num, 0, height / 2);
}

function addSCurves() {
    addRoad(40, 40, 40, -2.5, 200);
    addRoad(40, 40, 40, 3.0, -150);
    addRoad(40, 40, 40, 1.8, 0);
    addRoad(40, 40, 40, -3.2, 250);
    addRoad(40, 40, 40, -1.8, -300);
}

function buildTrack() {
    segments = [];
    
    // Stage 1: Neon Boulevard & Highway
    addStraight(50);
    addLowRollingHills(60, 400);
    addCurve(60, 2.2, 200);
    addHill(50, -400);
    addSCurves();
    addStraight(40);

    // Mark Sector 1 Checkpoint
    if (segments.length > 0) {
        var cp1 = segments[segments.length - 1];
        cp1.isCheckpoint = true;
        cp1.sprites.push({ type: "CHECKPOINT_ARCH", offset: 0 });
    }

    // Stage 2: Mountain Ridge & High Speed Pass
    addCurve(70, -2.8, 600);
    addHill(60, -600);
    addStraight(50);
    addCurve(80, 3.2, 400);
    addLowRollingHills(60, 500);
    addSCurves();
    addStraight(60);

    // Mark Sector 2 Checkpoint
    if (segments.length > 0) {
        var cp2 = segments[segments.length - 1];
        cp2.isCheckpoint = true;
        cp2.sprites.push({ type: "CHECKPOINT_ARCH", offset: 0 });
    }

    // Stage 3: Coastal Turbo Run
    addHill(50, 500);
    addCurve(90, -3.5, -400);
    addStraight(70);
    addCurve(70, 3.0, -400);
    addHill(40, 0);
    addSCurves();
    addStraight(80);

    // Finish Arch
    if (segments.length > 0) {
        var cp3 = segments[segments.length - 1];
        cp3.isCheckpoint = true;
        cp3.isFinish = true;
        cp3.sprites.push({ type: "CHECKPOINT_ARCH", offset: 0 });
    }

    trackLength = segments.length * SEGMENT_LENGTH;

    // Decorate Track with Roadside Scenery (Properly spaced)
    for (var i = 0; i < segments.length; i += 8) {
        var side = (i % 16 === 0) ? -1.6 : 1.6;
        
        if (i % 96 === 0) {
            segments[i].sprites.push({
                type: (i % 192 === 0) ? "BILLBOARD_OMARCHY" : "BILLBOARD_QUATTRO",
                offset: side * 1.4
            });
        } else if (i % 48 === 0) {
            segments[i].sprites.push({
                type: "NEON_SIGN",
                offset: side * 1.3
            });
        } else if (i % 16 === 0) {
            segments[i].sprites.push({
                type: "PALM",
                offset: side
            });
            // Matching streetlight on inner curve
            if (i % 32 === 0) {
                segments[i].sprites.push({
                    type: "STREET_LIGHT",
                    offset: -side * 1.15
                });
            }
        }
    }
}

// --- AI Traffic Setup ---
function resetCars() {
    cars = [];
    var carCount = 28;
    for (var i = 0; i < carCount; i++) {
        var offset = (i % 3 === 0) ? 0 : (i % 3 === 1 ? -0.6 : 0.6);
        var z = (12 + (i * 14)) * SEGMENT_LENGTH;
        var carType = CAR_TYPES[i % CAR_TYPES.length];
        var carSpeed = (MAX_SPEED * carType.speedRatio * (0.85 + (i % 4) * 0.08));

        var car = {
            id: i,
            offset: offset,
            z: z,
            speed: carSpeed,
            percent: 0,
            type: carType,
            overtaken: false
        };
        cars.push(car);
    }
}

function debugPlaceCarNextToPlayer() {
    if (cars && cars.length > 0) {
        var visualZ = (playerZ + ((CAMERA_HEIGHT * CAMERA_DEPTH) * 0.25)) % trackLength;
        var seg = findSegment(visualZ);
        // remove car from whatever segment it was in
        for (var s = 0; s < segments.length; s++) {
            var idx = segments[s].cars.indexOf(cars[0]);
            if (idx >= 0) segments[s].cars.splice(idx, 1);
        }
        cars[0].z = visualZ;
        cars[0].offset = -0.55;
        cars[0].speed = 0;
        cars[0].type = CAR_TYPES[0]; // Suzuki Carry
        seg.cars.push(cars[0]);
    }
}

// --- Active Vehicle Configuration ---
function setActiveVehicle(carId) {
    if (!carId || !VEHICLE_PRESETS[carId]) carId = "keitruck";
    selectedCar = carId;
    var preset = VEHICLE_PRESETS[carId];
    currentGear = 1;
    idleRPM = preset.idleRPM;
    redlineRPM = preset.redlineRPM;
    shiftRPM = preset.shiftRPM;
    gaugeMaxRPM = preset.gaugeMaxRPM || preset.redlineRPM;
    currentRPM = idleRPM;
    shiftCutTimer = 0;
    wasAccelerating = false;
    engineSoundTimer = 0;
    MAX_SPEED = preset.topSpeed;
    ACCEL = (96.5 / preset.zeroSixtyTime) * 1.05;
    BREAKING = -(preset.brakePower || 30.0);
    DECEL = -MAX_SPEED / 15.0;
    OFF_ROAD_LIMIT = MAX_SPEED / 4.0;
    OFF_ROAD_DECEL = -MAX_SPEED / 2.5;
}

// --- Multi-Vehicle Drivetrain & Transmission Simulation ---
function updateDrivetrain(dt, isAccelerating, isBraking, soundCallback) {
    var preset = VEHICLE_PRESETS[selectedCar] || VEHICLE_PRESETS.keitruck;
    var gears = preset.gears;
    var finalDrive = preset.finalDrive;
    var topGearIdx = gears.length - 1;
    var topRatio = gears[topGearIdx] * finalDrive;
    var currentTotalRatio = gears[currentGear - 1] * finalDrive;
    var kRPM = preset.kRPMPerSpeed || 9.0;
    var wheelRPM = speed * currentTotalRatio * kRPM;

    if (shiftCutTimer > 0) {
        shiftCutTimer -= dt;
    }

    if (shiftCutTimer > 0) {
        isShiftCut = true;
        // Shift cut: clutch disengaged, drop RPM toward new gear RPM
        var targetNextRPM = Math.max(preset.idleRPM, wheelRPM);
        currentRPM = Math.max(targetNextRPM, currentRPM - (dt * 14000));
    } else if (isAccelerating) {
        isShiftCut = false;
        if (speed < 1.0) {
            // Initial launch revs
            currentRPM = Math.min(preset.redlineRPM, currentRPM + dt * 12000);
        } else {
            currentRPM = Math.max(preset.idleRPM, wheelRPM);
        }

        // Power & Torque curve:
        // Peak torque is in the midrange; if revved past peakPowerRPM toward redline, acceleration tapers off
        var powerCurve = 1.0;
        if (currentRPM > preset.peakPowerRPM) {
            var overRevFraction = Math.min(1.0, (currentRPM - preset.peakPowerRPM) / Math.max(1, preset.redlineRPM - preset.peakPowerRPM));
            powerCurve = 1.0 - (overRevFraction * overRevFraction * 0.45);
        }

        // Gear torque leverage: lower gears pull harder
        var gearLeverage = (1.0 + (topRatio / currentTotalRatio) * 0.22) * powerCurve;
        // Aerodynamic drag increases with square of speed; reaches equilibrium at topSpeed
        var drag = Math.pow(speed / preset.topSpeed, 2) * (ACCEL * 0.55);
        var effAccel = (ACCEL * gearLeverage) - drag;
        speed = Math.min(preset.topSpeed, speed + effAccel * dt);

        // Automatic upshift at optimal torque shift RPM
        if (currentGear < gears.length && currentRPM >= preset.shiftRPM) {
            currentGear++;
            shiftCutTimer = preset.shiftTime;
            if (soundCallback) soundCallback("shift_click");
        }
    } else if (isBraking) {
        isShiftCut = false;
        speed = Math.max(0, speed + (BREAKING * dt));
        currentRPM = Math.max(preset.idleRPM, wheelRPM);
    } else {
        // Coasting / engine braking
        isShiftCut = false;
        speed = Math.max(0, speed + (DECEL * dt));
        currentRPM = Math.max(preset.idleRPM, wheelRPM);
    }

    // Automatic downshift when decelerating below downshiftRPM
    if (!isAccelerating && shiftCutTimer <= 0 && currentGear > 1) {
        var lowerRatio = gears[currentGear - 2] * finalDrive;
        var lowerRPM = speed * lowerRatio * kRPM;
        if (currentRPM < preset.downshiftRPM && lowerRPM < preset.redlineRPM * 0.90) {
            currentGear--;
            currentRPM = lowerRPM;
            if (soundCallback) soundCallback("shift_click");
        }
    }

    // Clamp RPM
    currentRPM = Math.max(preset.idleRPM, Math.min(preset.redlineRPM, currentRPM));

    // Turbo blow-off valve flutter on throttle release
    if (wasAccelerating && !isAccelerating && preset.hasTurbo && currentRPM > preset.redlineRPM * 0.55 && speed > 30) {
        if (soundCallback) soundCallback("bov_flutter");
        turboFlames = 8;
    }

    wasAccelerating = isAccelerating;
}

// --- Initialization ---
function init(w, h) {
    width = w || 800;
    height = h || 500;
    
    playerX = 0;
    playerZ = 0;
    speed = 0;
    steering = 0;
    playerSteerTime = 0;
    playerSteerDir = 0;
    isBraking = false;
    isDrifting = false;
    driftAngle = 0;
    boostTimer = 0;
    turboFlames = 0;
    bounce = 0;

    score = 0;
    distanceTraveled = 0;
    timeLeft = 50.0;
    gameOver = false;
    stageCompleted = false;
    stage = 1;
    totalCheckpoints = 0;
    shakeIntensity = 0;
    offroadSoundTimer = 0;
    particles = [];

    setActiveVehicle(selectedCar);
    buildTrack();
    resetCars();
}

// --- Particle Emitter ---
function emitDriftSmoke(x, y, scale, angle) {
    for (var i = 0; i < 3; i++) {
        particles.push({
            x: x + (Math.random() * 20 - 10) * scale,
            y: y + (Math.random() * 10 - 5) * scale,
            vx: -angle * (2 + Math.random() * 3),
            vy: -(1 + Math.random() * 2),
            size: (6 + Math.random() * 8) * scale,
            alpha: 0.65,
            decay: 0.04 + Math.random() * 0.03,
            color: "#e2e8f0"
        });
    }
}

function emitTurboFlames(x, y, scale) {
    for (var i = 0; i < 2; i++) {
        particles.push({
            x: x + (Math.random() * 6 - 3),
            y: y + (Math.random() * 4),
            vx: (Math.random() * 2 - 1),
            vy: 2 + Math.random() * 3,
            size: (4 + Math.random() * 5) * scale,
            alpha: 0.9,
            decay: 0.12,
            color: Math.random() > 0.5 ? "#00f0ff" : "#ff007f"
        });
    }
}

function emitCrashSparks(x, y) {
    for (var i = 0; i < 16; i++) {
        var ang = Math.random() * Math.PI * 2;
        var spd = 3 + Math.random() * 6;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(ang) * spd,
            vy: Math.sin(ang) * spd,
            size: 3 + Math.random() * 3,
            alpha: 1.0,
            decay: 0.05 + Math.random() * 0.05,
            color: "#fbbf24"
        });
    }
}

function updateParticles(dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.size *= 1.04;
        p.alpha -= p.decay;
        if (p.alpha <= 0) {
            particles.splice(i, 1);
        }
    }
}

// --- Main Engine Update Loop ---
function update(dt, input, soundCallback) {
    if (gameOver) return;

    var step = dt;
    if (collisionCooldown > 0) collisionCooldown -= step;

    // Checkpoint countdown timer
    if (speed > 5) {
        timeLeft -= step;
        if (timeLeft <= 0) {
            timeLeft = 0;
            gameOver = true;
            if (soundCallback) soundCallback("crash");
            return;
        }
    }

    var playerSegment = findSegment(playerZ + (CAMERA_HEIGHT * CAMERA_DEPTH));
    var playerPercent = percentRemaining(playerZ + (CAMERA_HEIGHT * CAMERA_DEPTH), SEGMENT_LENGTH);
    var speedPercent = speed / MAX_SPEED;

    // Advance player along track
    playerZ = (playerZ + (speed * 100 * step)) % trackLength;
    distanceTraveled += (speed * 100 * step);
    score += Math.round(speed * step * 2);

    // Off-road detection & deceleration
    var offRoad = (playerX < -1.0 || playerX > 1.0);
    if (offRoad) {
        if (speed > OFF_ROAD_LIMIT) {
            speed = Math.max(OFF_ROAD_LIMIT, speed + (OFF_ROAD_DECEL * step));
        }
        // Off-road camera judder
        shakeIntensity = Math.min(6, shakeIntensity + 0.4);

        // Off-road gravel/dirt acoustic rumble
        if (speed > 8) {
            offroadSoundTimer += step;
            if (offroadSoundTimer >= 0.16) {
                offroadSoundTimer = 0;
                if (soundCallback) soundCallback("offroad");
            }
        } else {
            offroadSoundTimer = 0;
        }
    } else {
        offroadSoundTimer = 0;
        shakeIntensity = Math.max(0, shakeIntensity - step * 10);
    }

    // Input Handling
    isBraking = input.down || input.s;
    var isAccelerating = input.up || input.w;
    var isSteeringLeft = input.left || input.a || input.h;
    var isSteeringRight = input.right || input.d || input.l;
    var handbrake = input.space;

    // Drivetrain & Transmission Acceleration Physics
    updateDrivetrain(step, isAccelerating, isBraking, soundCallback);

    // Steering & Lateral Movement: Analog 1-second per 10° turn-in, crisp 0.25s per 10° return
    var steerSpeed = Math.min(3.4, (speed / 110.0) * 2.8);
    if (isSteeringRight) {
        if (playerSteerDir === -1) {
            playerSteerTime -= step * 6.0; // Rapid counter-steer transition across center
            if (playerSteerTime <= 0) {
                playerSteerTime = 0;
                playerSteerDir = 1;
            }
        } else {
            playerSteerDir = 1;
            playerSteerTime = Math.min(3.0, playerSteerTime + step);
        }
    } else if (isSteeringLeft) {
        if (playerSteerDir === 1) {
            playerSteerTime -= step * 6.0; // Rapid counter-steer transition across center
            if (playerSteerTime <= 0) {
                playerSteerTime = 0;
                playerSteerDir = -1;
            }
        } else {
            playerSteerDir = -1;
            playerSteerTime = Math.min(3.0, playerSteerTime + step);
        }
    } else {
        // Return to center: 0.25s per 10° step (30° -> 20° -> 10° -> 0° in 0.75s total)
        playerSteerTime = Math.max(0.0, playerSteerTime - (step * 4.0));
        if (playerSteerTime <= 0) playerSteerDir = 0;
    }

    steering = playerSteerDir * (playerSteerTime / 3.0);

    // Progressive lateral rate per steering angle
    if (playerSteerDir !== 0 && playerSteerTime > 0.02) {
        var latRate = playerSteerTime < 1.0 ? (0.45 + playerSteerTime * 0.35) : (0.80 + (playerSteerTime - 1.0) * 0.35);
        playerX += playerSteerDir * latRate * steerSpeed * step;
    }

    // Centrifugal curve physics (pulls car outwards on turns)
    playerX = playerX - (steerSpeed * step * playerSegment.curve * CENTRIFUGAL);

    // Drifting physics
    isDrifting = (handbrake && speed > 30) || (Math.abs(steering) > 0.55 && speed > (MAX_SPEED * 0.40));
    if (isDrifting) {
        driftAngle = steering * 0.35;
        score += Math.round(30 * step * 10); // Drift score
    } else {
        driftAngle *= 0.8;
    }

    // Turbo backfire effects at high speed throttle lift
    if (!isAccelerating && speed > (MAX_SPEED * 0.70) && Math.random() < 0.2) {
        turboFlames = 6;
    }
    if (turboFlames > 0) turboFlames--;

    // Suspension bounce based on speed & hill grade
    bounce = (1.5 * Math.random() * (speed / MAX_SPEED) * (width / 800));

    // Checkpoint detection
    if (playerSegment.isCheckpoint && !playerSegment.checked) {
        playerSegment.checked = true;
        totalCheckpoints++;
        timeLeft += 30.0;
        score += 5000;
        if (soundCallback) soundCallback("checkpoint");

        if (playerSegment.isFinish) {
            stage++;
            stageCompleted = true;
        }
    }

    // --- Update AI Traffic Cars ---
    for (var i = 0; i < cars.length; i++) {
        var car = cars[i];
        var oldSegment = findSegment(car.z);
        car.z = (car.z + (car.speed * 100 * step)) % trackLength;
        car.percent = percentRemaining(car.z, SEGMENT_LENGTH);
        var newSegment = findSegment(car.z);

        if (oldSegment !== newSegment) {
            var index = oldSegment.cars.indexOf(car);
            if (index !== -1) oldSegment.cars.splice(index, 1);
            newSegment.cars.push(car);
        }

        // Slight AI lateral lane weaving
        car.offset += Math.sin(car.z / 1000) * 0.003;

        // AI Computer Turn Progression: 1 second per 10° (10° -> 20° -> 30° -> 20° -> 10° -> 0°)
        if (typeof car.turnTimer === "undefined") {
            car.turnTimer = 0;
            car.turnDir = 0;
            car.angleName = "straight";
        }

        var currentCurve = newSegment.curve;
        // Look ahead 1.5 seconds down the highway to anticipate turn completion
        var lookAheadDistance = car.speed * 100 * 1.5;
        var lookAheadSeg = findSegment((car.z + lookAheadDistance) % trackLength);
        var futureCurve = lookAheadSeg ? lookAheadSeg.curve : 0;

        var isTurning = Math.abs(currentCurve) > 0.35;
        var curveSign = currentCurve > 0 ? 1 : -1;
        var futureStraightening = Math.abs(futureCurve) < 0.30 || (futureCurve > 0 ? 1 : -1) !== curveSign;

        if (isTurning) {
            if (!futureStraightening) {
                // Building or holding turn: increase 10° for every second of the turn
                if (car.turnDir !== curveSign) {
                    car.turnDir = curveSign;
                    car.turnTimer = 0;
                }
                car.turnTimer = Math.min(3.0, car.turnTimer + step);
            } else {
                // Approaching exit of turn: computer starts winding down the turn
                car.turnTimer = Math.max(0.0, car.turnTimer - step);
                if (car.turnTimer <= 0) car.turnDir = 0;
            }
        } else {
            // Straight highway: wind down any remaining turn angle
            car.turnTimer = Math.max(0.0, car.turnTimer - step);
            if (car.turnTimer <= 0) car.turnDir = 0;
        }

        // Determine AI visual sprite angle (10° per second)
        if (car.turnDir === 0 || car.turnTimer < 0.05) {
            car.angleName = "straight";
        } else {
            var dirPfx = car.turnDir > 0 ? "r" : "l";
            if (car.turnTimer < 1.0) {
                car.angleName = dirPfx + "10";
            } else if (car.turnTimer < 2.0) {
                car.angleName = dirPfx + "20";
            } else {
                car.angleName = dirPfx + "30";
            }
        }

        // Visual plane: player vehicle is rendered at playerScreenY = 0.90 * height
        // In 3D space, this visual plane is at playerZ + (CAMERA_HEIGHT * CAMERA_DEPTH * 0.25)
        var visualPlayerZ = (playerZ + ((CAMERA_HEIGHT * CAMERA_DEPTH) * 0.25)) % trackLength;

        // Collision detection between player and AI car when side-by-side
        if (Math.abs(visualPlayerZ - car.z) < 130) {
            if (Math.abs(playerX - car.offset) < 0.45) {
                // Impact!
                speed = Math.max(20, speed * 0.4);
                car.speed = Math.max(30, car.speed * 0.6);
                if (collisionCooldown <= 0) {
                    shakeIntensity = 10;
                    emitCrashSparks(width / 2, height * 0.75);
                    if (soundCallback) soundCallback("crash");
                    collisionCooldown = 0.6; // 600ms cooldown so it doesn't machine-gun spam
                }
            }
        }

        // Overtake detection (player passes rival cleanly at speed)
        if (!car.overtaken && visualPlayerZ > car.z && (visualPlayerZ - car.z) < 300) {
            car.overtaken = true;
            score += 250;
            if (soundCallback) soundCallback("pass");
        } else if (visualPlayerZ < car.z) {
            car.overtaken = false;
        }
    }

    // Update Particles
    updateParticles(step);
}

// --- Render Helpers for Vector Polygons ---
function drawPolygon(ctx, x1, y1, x2, y2, x3, y3, x4, y4, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.lineTo(x3, y3);
    ctx.lineTo(x4, y4);
    ctx.closePath();
    ctx.fill();
}

function drawSegment(ctx, w, lanes, x1, y1, w1, x2, y2, w2, color) {
    if (y1 - y2 < 1) return;

    var r1 = w1 / Math.max(6, 2 * lanes);
    var r2 = w2 / Math.max(6, 2 * lanes);
    var l1 = w1 / Math.max(32, 8 * lanes);
    var l2 = w2 / Math.max(32, 8 * lanes);

    // Rumble Strips (curbs)
    drawPolygon(ctx, x1 - w1 - r1, y1, x1 - w1, y1, x2 - w2, y2, x2 - w2 - r2, y2, color.rumble);
    drawPolygon(ctx, x1 + w1 + r1, y1, x1 + w1, y1, x2 + w2, y2, x2 + w2 + r2, y2, color.rumble);

    // Road Asphalt
    drawPolygon(ctx, x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, color.road);

    // Dashed Lane Lines
    if (color.lane && (y1 - y2 >= 2)) {
        var lanew1 = w1 * 2 / lanes;
        var lanew2 = w2 * 2 / lanes;
        var lanex1 = x1 - w1 + lanew1;
        var lanex2 = x2 - w2 + lanew2;
        for (var lane = 1; lane < lanes; lanex1 += lanew1, lanex2 += lanew2, lane++) {
            drawPolygon(ctx, lanex1 - l1 / 2, y1, lanex1 + l1 / 2, y1, lanex2 + l2 / 2, y2, lanex2 - l2 / 2, y2, color.lane);
        }
    }
}

function drawRoundedRect(ctx, x, y, w, h, r) {
    if (w < 2 * r) r = w / 2;
    if (h < 2 * r) r = h / 2;
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
}

// --- Player Vehicle Renderer (All Selectable Garage Vehicles) ---
function drawPlayerVehicle(ctx, screenX, screenY, carW, carH, steer, braking, drift, canvas, spriteUrl, brakeUrl, isMirrored) {
    if (canvas && spriteUrl && canvas.isImageLoaded(spriteUrl)) {
        ctx.save();
        ctx.translate(screenX, screenY + bounce);

        // Lateral tilt during drift/steering
        var angle = (steer * 0.08) + (drift * 0.12);
        ctx.rotate(angle);

        // Dynamically mirror left-turn sprites for right turns
        if (isMirrored) {
            ctx.scale(-1, 1);
        }

        var w = carW;
        var h = carH;
        var hw = w / 2;

        // 1. Underbody Shadow directly under tires
        ctx.fillStyle = "rgba(0, 0, 0, 0.45)";
        ctx.beginPath();
        ctx.ellipse(0, -h * 0.03, hw * 0.85, h * 0.08, 0, 0, Math.PI * 2);
        ctx.fill();

        // 2. Render Vehicle Sprite
        ctx.drawImage(spriteUrl, -hw, -h, w, h);

        // 3. Glowing Brake Lights if braking (exact artist vector overlay PNG)
        if (braking && brakeUrl && canvas.isImageLoaded(brakeUrl)) {
            ctx.drawImage(brakeUrl, -hw, -h, w, h);
        }

        // 4. Turbo Flame Bursts
        var carPreset = VEHICLE_PRESETS[selectedCar] || VEHICLE_PRESETS.keitruck;
        if (turboFlames > 0 && carPreset.hasTurbo) {
            var exX = -hw * 0.35;
            ctx.fillStyle = "#38bdf8";
            ctx.beginPath();
            ctx.arc(exX, -h * 0.05 + (Math.random() * 4), 6, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(exX, -h * 0.05 + (Math.random() * 2), 3, 0, Math.PI * 2);
            ctx.fill();
        }

        ctx.restore();
        return;
    }

    // --- Vector Fallback ---
    ctx.save();
    ctx.translate(screenX, screenY + bounce);

    // Lateral tilt during drift/steering
    var angle = (steer * 0.12) + (drift * 0.18);
    ctx.rotate(angle);

    var w = carW;
    var h = carH;
    var hw = w / 2;

    // 1. Underbody Shadow
    ctx.fillStyle = "rgba(0, 0, 0, 0.45)";
    ctx.beginPath();
    ctx.ellipse(0, h * 0.38, hw * 1.05, h * 0.14, 0, 0, Math.PI * 2);
    ctx.fill();

    // 2. Wide Rally Box-Flares (Wheel Arches)
    ctx.fillStyle = "#1e293b"; // Dark rally fender liner
    // Left wheel arch
    ctx.fillRect(-hw * 0.98, h * 0.15, hw * 0.28, h * 0.25);
    // Right wheel arch
    ctx.fillRect(hw * 0.70, h * 0.15, hw * 0.28, h * 0.25);

    // 3. Wide Tires (Tarmac Spec Rally Rubber)
    ctx.fillStyle = "#09090b";
    drawRoundedRect(ctx, -hw * 0.96, h * 0.18, hw * 0.24, h * 0.24, 3);
    ctx.fill();
    drawRoundedRect(ctx, hw * 0.72, h * 0.18, hw * 0.24, h * 0.24, 3);
    ctx.fill();

    // White Rally Wheel Rims (Speedline/Ronal 5-spoke rally spec)
    ctx.fillStyle = "#f8fafc";
    ctx.beginPath();
    ctx.arc(-hw * 0.84, h * 0.30, h * 0.08, 0, Math.PI * 2);
    ctx.arc(hw * 0.84, h * 0.30, h * 0.08, 0, Math.PI * 2);
    ctx.fill();

    // 4. Main Bodywork (Alpine White Rally Shell)
    ctx.fillStyle = "#f1f5f9"; // Alpine White
    ctx.beginPath();
    // Lower bumper to blistered arches and upper beltline
    ctx.moveTo(-hw * 0.88, h * 0.35);
    ctx.lineTo(hw * 0.88, h * 0.35);
    ctx.lineTo(hw * 0.86, h * 0.05);
    ctx.lineTo(hw * 0.78, -h * 0.08); // High muscular rear quarter
    ctx.lineTo(-hw * 0.78, -h * 0.08);
    ctx.lineTo(-hw * 0.86, h * 0.05);
    ctx.closePath();
    ctx.fill();

    // Subtle rally body shading
    ctx.fillStyle = "rgba(15, 23, 42, 0.12)";
    ctx.beginPath();
    ctx.moveTo(-hw * 0.88, h * 0.35);
    ctx.lineTo(hw * 0.88, h * 0.35);
    ctx.lineTo(hw * 0.84, h * 0.22);
    ctx.lineTo(-hw * 0.84, h * 0.22);
    ctx.closePath();
    ctx.fill();

    // 5. Rear Greenhouse / Cabin & Slanted C-Pillar
    ctx.fillStyle = "#e2e8f0"; // Roof pillar
    ctx.beginPath();
    ctx.moveTo(-hw * 0.74, -h * 0.08);
    ctx.lineTo(-hw * 0.60, -h * 0.38); // Steep Quattro C-pillar rake
    ctx.lineTo(hw * 0.60, -h * 0.38);
    ctx.lineTo(hw * 0.74, -h * 0.08);
    ctx.closePath();
    ctx.fill();

    // Tinted Rear Heated Window with subtle horizontal defroster lines
    ctx.fillStyle = "#090d16";
    ctx.beginPath();
    ctx.moveTo(-hw * 0.68, -h * 0.09);
    ctx.lineTo(-hw * 0.55, -h * 0.35);
    ctx.lineTo(hw * 0.55, -h * 0.35);
    ctx.lineTo(hw * 0.68, -h * 0.09);
    ctx.closePath();
    ctx.fill();

    // Rear Window Glass Highlights (Gloss Reflection)
    ctx.strokeStyle = "rgba(56, 189, 248, 0.35)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-hw * 0.40, -h * 0.32);
    ctx.lineTo(-hw * 0.10, -h * 0.12);
    ctx.stroke();

    // 6. Signature Audi Sport Quattro Rear Wing / Rally Spoiler
    ctx.fillStyle = "#0f172a"; // Matte black rally aerofoil
    // Left & right wing uprights
    ctx.fillRect(-hw * 0.65, -h * 0.18, hw * 0.10, h * 0.14);
    ctx.fillRect(hw * 0.55, -h * 0.18, hw * 0.10, h * 0.14);
    // Upper horizontal spoiler blade
    drawRoundedRect(ctx, -hw * 0.78, -h * 0.22, hw * 1.56, h * 0.07, 2);
    ctx.fill();

    // 7. Signature Black Tailgate Trim Strip & Audi Emblem
    ctx.fillStyle = "#18181b"; // Classic 80s ribbed center trim
    ctx.fillRect(-hw * 0.72, h * 0.03, hw * 1.44, h * 0.14);

    // Quad Tail Light Clusters (Brake & Turn Signals)
    var lightColor = braking ? "#ff1a1a" : "#dc2626";
    ctx.fillStyle = lightColor;

    // Left Tail Light (Outer Stop + Inner Reverse)
    ctx.fillRect(-hw * 0.70, h * 0.05, hw * 0.26, h * 0.10);
    // Right Tail Light
    ctx.fillRect(hw * 0.44, h * 0.05, hw * 0.26, h * 0.10);

    // Amber Turn Indicator Accents
    ctx.fillStyle = "#f59e0b";
    ctx.fillRect(-hw * 0.70, h * 0.05, hw * 0.07, h * 0.10);
    ctx.fillRect(hw * 0.63, h * 0.05, hw * 0.07, h * 0.10);

    // Quattro Badge / License Plate
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(-hw * 0.16, h * 0.06, hw * 0.32, h * 0.07);
    ctx.fillStyle = "#000000";
    ctx.font = "bold 8px monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("QUATTRO", 0, h * 0.095);

    // 8. Dual Rally Exhaust Pipes & Turbo Flames
    ctx.fillStyle = "#64748b"; // Chrome/steel tips
    ctx.beginPath();
    ctx.arc(-hw * 0.48, h * 0.33, 4, 0, Math.PI * 2);
    ctx.arc(-hw * 0.38, h * 0.33, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#09090b";
    ctx.beginPath();
    ctx.arc(-hw * 0.48, h * 0.33, 2.5, 0, Math.PI * 2);
    ctx.arc(-hw * 0.38, h * 0.33, 2.5, 0, Math.PI * 2);
    ctx.fill();

    // Turbo Flame Bursts on throttle overrun / high revs
    if (turboFlames > 0) {
        ctx.fillStyle = "#38bdf8";
        ctx.beginPath();
        ctx.arc(-hw * 0.43, h * 0.36 + (Math.random() * 4), 6, 0, Math.PI * 2);
        ctx.fill();
    }

    ctx.restore();
}

// --- Traffic / Rival Vehicle Renderer ---
function drawTrafficCar(ctx, screenX, screenY, scale, car, canvas, spriteUrls) {
    var type = car.type;
    var preset = (type && type.id && VEHICLE_PRESETS[type.id]) ? VEHICLE_PRESETS[type.id] :
                 (type && type.spriteKey && VEHICLE_PRESETS[type.spriteKey.replace("_straight", "")]) ? VEHICLE_PRESETS[type.spriteKey.replace("_straight", "")] :
                 VEHICLE_PRESETS.keitruck;

    // Perspective calibration:
    var scaleAtPlayer = 0.80 / CAMERA_HEIGHT;
    var relativeScale = scale / scaleAtPlayer;
    var carAngle = car.angleName || "straight";
    var prefix = (type && type.prefix) ? type.prefix :
                 (preset && preset.prefix) ? preset.prefix : "kei";

    var isMirrored = false;
    var lookupAngle = carAngle;
    if (lookupAngle && lookupAngle.charAt(0) === 'r') {
        isMirrored = true;
        lookupAngle = "l" + lookupAngle.substring(1);
    }

    var spriteKey = prefix + "_" + lookupAngle;
    var spriteUrl = (spriteUrls && spriteUrls[spriteKey]) ? spriteUrls[spriteKey] :
                    (spriteUrls && spriteUrls[prefix + "_straight"]) ? spriteUrls[prefix + "_straight"] : null;
    if (!spriteUrls || !spriteUrls[spriteKey]) {
        isMirrored = false;
    }

    var aspectMultiplier = 1.0;
    if (carAngle.indexOf("10") !== -1) aspectMultiplier = 1.15;
    else if (carAngle.indexOf("20") !== -1) aspectMultiplier = 1.22;
    else if (carAngle.indexOf("30") !== -1) aspectMultiplier = 1.30;

    var h = (preset.baseH || 210) * (width / 800) * relativeScale;
    var w = h * (preset.aspectStraight || 1.0) * aspectMultiplier;
    if (w < 8 || h < 4) return;

    if (canvas && spriteUrl && canvas.isImageLoaded(spriteUrl)) {
        ctx.save();
        ctx.translate(screenX, screenY);
        var hw = w / 2;

        // Ground Shadow
        ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
        ctx.beginPath();
        ctx.ellipse(0, -h * 0.04, hw * 0.85, h * 0.09, 0, 0, Math.PI * 2);
        ctx.fill();

        // Subtle lateral body tilt into turn
        if (car.turnDir && car.turnTimer) {
            ctx.rotate(car.turnDir * (car.turnTimer / 3.0) * 0.05);
        }

        // Dynamically mirror left-turn sprites for right turns
        if (isMirrored) {
            ctx.scale(-1, 1);
        }

        // Draw Rival / Traffic Vehicle Sprite with authentic angle
        ctx.drawImage(spriteUrl, -hw, -h, w, h);

        ctx.restore();
        return;
    }

    ctx.save();
    ctx.translate(screenX, screenY);
    var hw = w / 2;

    // Ground Shadow
    ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
    ctx.beginPath();
    ctx.ellipse(0, h * 0.4, hw * 1.05, h * 0.15, 0, 0, Math.PI * 2);
    ctx.fill();

    // Wide Supercar Tires
    ctx.fillStyle = "#09090b";
    ctx.fillRect(-hw * 0.95, h * 0.16, hw * 0.22, h * 0.26);
    ctx.fillRect(hw * 0.73, h * 0.16, hw * 0.22, h * 0.26);

    // Car Bodywork
    ctx.fillStyle = type.color;
    drawRoundedRect(ctx, -hw * 0.88, -h * 0.05, hw * 1.76, h * 0.42, 4);
    ctx.fill();

    // Aerodynamic Greenhouse / Canopy
    ctx.fillStyle = type.roof;
    ctx.beginPath();
    ctx.moveTo(-hw * 0.65, -h * 0.05);
    ctx.lineTo(-hw * 0.45, -h * 0.38);
    ctx.lineTo(hw * 0.45, -h * 0.38);
    ctx.lineTo(hw * 0.65, -h * 0.05);
    ctx.closePath();
    ctx.fill();

    // Dark Rear Glass Window
    ctx.fillStyle = "#020617";
    ctx.beginPath();
    ctx.moveTo(-hw * 0.58, -h * 0.06);
    ctx.lineTo(-hw * 0.40, -h * 0.34);
    ctx.lineTo(hw * 0.40, -h * 0.34);
    ctx.lineTo(hw * 0.58, -h * 0.06);
    ctx.closePath();
    ctx.fill();

    // High GT Wing for Supercars (Zonda / Agera / GT3 RS)
    if (type.wing) {
        ctx.fillStyle = "#0f172a";
        ctx.fillRect(-hw * 0.55, -h * 0.22, hw * 0.08, h * 0.18);
        ctx.fillRect(hw * 0.47, -h * 0.22, hw * 0.08, h * 0.18);
        drawRoundedRect(ctx, -hw * 0.85, -h * 0.26, hw * 1.70, h * 0.06, 2);
        ctx.fill();
    }

    // Rear LED Taillights (Hypercar signature light strips)
    ctx.fillStyle = "#ef4444";
    ctx.fillRect(-hw * 0.78, h * 0.08, hw * 0.30, h * 0.08);
    ctx.fillRect(hw * 0.48, h * 0.08, hw * 0.30, h * 0.08);

    // Diffuser & Exhausts
    ctx.fillStyle = "#1e293b";
    ctx.fillRect(-hw * 0.40, h * 0.26, hw * 0.80, h * 0.12);

    ctx.restore();
}

// --- Procedural Roadside Scenery Renderer ---
function drawRoadsideSprite(ctx, screenX, screenY, scale, spriteType) {
    var w = spriteType.width * scale * width / 2;
    var h = spriteType.height * scale * width / 2;
    if (w < 8 || h < 8) return;

    ctx.save();
    ctx.translate(screenX, screenY);

    if (spriteType === SPRITE_TYPES.PALM) {
        // Neon Palm Tree
        // Trunk
        ctx.strokeStyle = "#475569";
        ctx.lineWidth = Math.max(3, 8 * scale * width / 2);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(w * 0.1, -h * 0.5, 0, -h);
        ctx.stroke();

        // Lush Synthwave Palm Fronds
        ctx.fillStyle = "#06b6d4";
        for (var i = 0; i < 5; i++) {
            var ang = (i / 4) * Math.PI - (Math.PI / 2);
            ctx.beginPath();
            ctx.ellipse(Math.cos(ang) * w * 0.4, -h + Math.sin(ang) * h * 0.2, w * 0.35, h * 0.08, ang, 0, Math.PI * 2);
            ctx.fill();
        }

    } else if (spriteType === SPRITE_TYPES.BILLBOARD_OMARCHY || spriteType === SPRITE_TYPES.BILLBOARD_QUATTRO) {
        if (w >= 16) {
            // Neon Synthwave Billboard
            // Support Posts
            ctx.fillStyle = "#334155";
            ctx.fillRect(-w * 0.35, -h * 0.4, Math.max(2, w * 0.06), h * 0.4);
            ctx.fillRect(w * 0.30, -h * 0.4, Math.max(2, w * 0.06), h * 0.4);

            // Signboard
            ctx.fillStyle = "#0f172a";
            ctx.strokeStyle = (spriteType === SPRITE_TYPES.BILLBOARD_OMARCHY) ? "#f43f5e" : "#00f0ff";
            ctx.lineWidth = Math.max(1, Math.round(w * 0.015));
            drawRoundedRect(ctx, -w / 2, -h, w, h * 0.65, Math.min(6, w * 0.05));
            ctx.fill();
            ctx.stroke();

            // Billboard Text (Only if visible enough)
            if (w > 45) {
                ctx.fillStyle = (spriteType === SPRITE_TYPES.BILLBOARD_OMARCHY) ? "#f43f5e" : "#00f0ff";
                ctx.font = "bold " + Math.max(9, Math.round(h * 0.22)) + "px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText((spriteType === SPRITE_TYPES.BILLBOARD_OMARCHY) ? "OMARCHY" : "QUATTRO S1", 0, -h * 0.68);
            }
        }

    } else if (spriteType === SPRITE_TYPES.CHECKPOINT_ARCH) {
        // Grand Finish / Sector Checkpoint Gantry Arch spanning across the entire road
        ctx.fillStyle = "#0f172a";
        // Left Column
        ctx.fillRect(-w * 0.48, -h, Math.max(6, w * 0.08), h);
        // Right Column
        ctx.fillRect(w * 0.40, -h, Math.max(6, w * 0.08), h);
        // Cross Truss
        ctx.fillStyle = "#1e293b";
        ctx.fillRect(-w * 0.50, -h, w, h * 0.30);

        // Neon Checkpoint Banner
        ctx.fillStyle = "#fbbf24";
        ctx.font = "bold " + Math.max(14, Math.round(h * 0.18)) + "px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText("CHECKPOINT", 0, -h * 0.85);

        // Flashing Gantry Lights
        for (var l = -4; l <= 4; l++) {
            ctx.fillStyle = (Math.floor(Date.now() / 250) % 2 === 0) ? "#ef4444" : "#22c55e";
            ctx.beginPath();
            ctx.arc(l * (w * 0.08), -h * 0.72, Math.max(2, w * 0.015), 0, Math.PI * 2);
            ctx.fill();
        }

    } else {
        // Default Neon Grid Marker
        ctx.fillStyle = "#ec4899";
        ctx.fillRect(-w * 0.2, -h, w * 0.4, h);
    }

    ctx.restore();
}

// --- Background Synthwave Horizon & Sun Renderer ---
function drawSkyAndHorizon(ctx, w, h, theme) {
    // 1. Synthwave Sky Gradient
    var skyGrad = ctx.createLinearGradient(0, 0, 0, h * 0.6);
    skyGrad.addColorStop(0, theme.bg || "#090a0f");
    skyGrad.addColorStop(0.5, "#1e1035");
    skyGrad.addColorStop(0.85, "#4a1240");
    skyGrad.addColorStop(1, "#831843");
    ctx.fillStyle = skyGrad;
    ctx.fillRect(0, 0, w, h * 0.5);

    // Ground shoulder base fill (pre-fills entire road base once)
    ctx.fillStyle = "#100c1e";
    ctx.fillRect(0, h * 0.5, w, h * 0.5);

    // 2. Retro Neon Blinds Sun (Horizontal Raster Slices)
    var sunRadius = h * 0.22;
    var sunCenterX = w * 0.5;
    var sunCenterY = h * 0.36;

    var sunGrad = ctx.createLinearGradient(0, sunCenterY - sunRadius, 0, sunCenterY + sunRadius);
    sunGrad.addColorStop(0, "#fde047");
    sunGrad.addColorStop(0.6, "#f43f5e");
    sunGrad.addColorStop(1, "#be185d");

    ctx.save();
    ctx.beginPath();
    ctx.arc(sunCenterX, sunCenterY, sunRadius, 0, Math.PI * 2);
    ctx.clip();

    ctx.fillStyle = sunGrad;
    ctx.fillRect(sunCenterX - sunRadius, sunCenterY - sunRadius, sunRadius * 2, sunRadius * 2);

    // Horizontal blind gaps cutting through the sun
    ctx.fillStyle = "#1e1035";
    var numBars = 7;
    for (var b = 0; b < numBars; b++) {
        var barY = sunCenterY - (sunRadius * 0.1) + (b * (sunRadius * 1.1 / numBars));
        var barH = 2 + (b * 2.2);
        ctx.fillRect(sunCenterX - sunRadius, barY, sunRadius * 2, barH);
    }
    ctx.restore();

    // 3. Distant Parallax Mountain Silhouettes
    var playerSegment = findSegment(playerZ);
    var curveVal = (playerSegment && typeof playerSegment.curve !== "undefined") ? playerSegment.curve : 0;
    var parallaxOffset = (playerX * 60) + (curveVal * 15);

    ctx.fillStyle = "#160b26";
    ctx.beginPath();
    ctx.moveTo(0, h * 0.50);
    for (var m = 0; m <= w; m += 30) {
        var peakH = Math.sin((m + parallaxOffset) * 0.015) * 28 + Math.sin((m + parallaxOffset) * 0.04) * 14 + 10;
        ctx.lineTo(m, h * 0.50 - peakH);
    }
    ctx.lineTo(w, h * 0.50);
    ctx.closePath();
    ctx.fill();

    // 4. Horizon Glow Line
    ctx.strokeStyle = "#f43f5e";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, h * 0.50);
    ctx.lineTo(w, h * 0.50);
    ctx.stroke();
}

// --- Main Render Pipeline ---
function render(ctx, w, h, theme, canvas, spriteUrls, selectedCar) {
    width = w || 800;
    height = h || 500;

    ctx.clearRect(0, 0, width, height);

    ctx.save();
    // Apply camera shake if any
    if (shakeIntensity > 0) {
        var sx = (Math.random() * 2 - 1) * shakeIntensity;
        var sy = (Math.random() * 2 - 1) * shakeIntensity;
        ctx.translate(sx, sy);
    }

    // 1. Draw Synthwave Sky, Mountains, and Sun
    drawSkyAndHorizon(ctx, width, height, theme || {});

    // 2. Project Road Segments from Back to Front
    var baseSegment = findSegment(playerZ);
    var basePercent = percentRemaining(playerZ, SEGMENT_LENGTH);
    var playerSegment = findSegment(playerZ + (CAMERA_HEIGHT * CAMERA_DEPTH));
    var playerPercent = percentRemaining(playerZ + (CAMERA_HEIGHT * CAMERA_DEPTH), SEGMENT_LENGTH);

    var camX = playerX * ROAD_WIDTH;
    var camY = CAMERA_HEIGHT + playerSegment.p1.world.y;
    var camZ = playerZ - (CAMERA_HEIGHT * CAMERA_DEPTH);

    var maxY = height;
    var x = 0;
    var dx = -(baseSegment.curve * basePercent);

    // List of sprites and cars to render after road polygons
    var renderQueue = [];

    for (var n = 0; n < DRAW_DISTANCE; n++) {
        var segment = segments[(baseSegment.index + n) % segments.length];
        var looped = segment.index < baseSegment.index;

        project(segment.p1, camX - x, camY, camZ - (looped ? trackLength : 0), CAMERA_DEPTH, width, height, ROAD_WIDTH);
        project(segment.p2, camX - x - dx, camY, camZ - (looped ? trackLength : 0), CAMERA_DEPTH, width, height, ROAD_WIDTH);

        x = x + dx;
        dx = dx + segment.curve;

        if ((segment.p1.camera.z <= CAMERA_DEPTH) || (segment.p2.screen.y >= maxY)) {
            continue;
        }

        // Draw Road Segment Polygons
        drawSegment(ctx, width, LANES,
                    segment.p1.screen.x, segment.p1.screen.y, segment.p1.screen.w,
                    segment.p2.screen.x, segment.p2.screen.y, segment.p2.screen.w,
                    segment.color);

        maxY = segment.p2.screen.y;

        // Queue Roadside Sprites
        for (var s = 0; s < segment.sprites.length; s++) {
            var spriteObj = segment.sprites[s];
            renderQueue.push({
                kind: "sprite",
                segment: segment,
                spriteObj: spriteObj,
                scale: segment.p1.screen.scale,
                x: segment.p1.screen.x + (spriteObj.offset * segment.p1.screen.w),
                y: segment.p1.screen.y
            });
        }

        // Queue AI Traffic Cars on this segment
        for (var c = 0; c < segment.cars.length; c++) {
            var car = segment.cars[c];
            var carPercent = car.percent;
            var carScale = interpolate(segment.p1.screen.scale, segment.p2.screen.scale, carPercent);
            var segW = interpolate(segment.p1.screen.w, segment.p2.screen.w, carPercent);
            var carX = interpolate(segment.p1.screen.x, segment.p2.screen.x, carPercent) + (car.offset * segW);
            var carY = interpolate(segment.p1.screen.y, segment.p2.screen.y, carPercent);

            renderQueue.push({
                kind: "car",
                car: car,
                scale: carScale,
                x: carX,
                y: carY
            });
        }
    }

    // 3. Render Roadside Scenery and Traffic Cars (Sorted by depth far-to-near)
    renderQueue.sort(function(a, b) {
        return a.scale - b.scale;
    });

    for (var r = 0; r < renderQueue.length; r++) {
        var item = renderQueue[r];
        if (item.kind === "sprite") {
            var spriteType = SPRITE_TYPES[item.spriteObj.type] || SPRITE_TYPES.PALM;
            drawRoadsideSprite(ctx, item.x, item.y, item.scale, spriteType);
        } else if (item.kind === "car") {
            drawTrafficCar(ctx, item.x, item.y, item.scale, item.car, canvas, spriteUrls);
        }
    }

    // 4. Render Dynamic Particles (Tire smoke, turbo flames, sparks)
    for (var p = 0; p < particles.length; p++) {
        var part = particles[p];
        ctx.fillStyle = part.color;
        ctx.globalAlpha = Math.max(0, part.alpha);
        ctx.beginPath();
        ctx.arc(part.x, part.y, part.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1.0;
    }

    // 5. Render Player Vehicle (Kei Truck, Quattro, Zonda, Agera, Porsche, Tesla, R34)
    var currentCarId = selectedCar || "keitruck";
    var preset = VEHICLE_PRESETS[currentCarId] || VEHICLE_PRESETS.keitruck;
    var playerBaseH = (preset.baseH || 205) * (width / 800);
    var playerScreenX = width / 2;
    var gaugesH = Math.max(54, Math.min(68, height * 0.125));
    var playerScreenY = height - gaugesH - 12;

    var spriteUrl = null;
    var carAspect = preset.aspectStraight || 1.25;
    var angleName = "straight";
    var isMirrored = false;
    if (spriteUrls) {
        var prefix = preset.prefix || "kei";
        var baseAspect = preset.aspectStraight || 1.0;

        if (isDrifting && Math.abs(driftAngle) > 0.1) {
            var driftDir = driftAngle > 0 ? "r" : "l";
            angleName = driftDir + "30";
            carAspect = baseAspect * 1.30;
        } else if (playerSteerDir === 0 || playerSteerTime < 0.05) {
            angleName = "straight";
            carAspect = baseAspect;
        } else {
            var dirPfx = playerSteerDir > 0 ? "r" : "l";
            if (playerSteerTime < 1.0) {
                angleName = dirPfx + "10";
                carAspect = baseAspect * 1.15;
            } else if (playerSteerTime < 2.0) {
                angleName = dirPfx + "20";
                carAspect = baseAspect * 1.22;
            } else {
                angleName = dirPfx + "30";
                carAspect = baseAspect * 1.30;
            }
        }

        var lookupAngle = angleName;
        if (lookupAngle.charAt(0) === 'r') {
            isMirrored = true;
            lookupAngle = "l" + lookupAngle.substring(1);
        }

        spriteUrl = spriteUrls[prefix + "_" + lookupAngle];

        if (!spriteUrl) {
            spriteUrl = spriteUrls[prefix + "_straight"] || spriteUrls.kei_straight;
            isMirrored = false;
        }
    }
    var playerH = playerBaseH;
    var playerW = playerBaseH * carAspect;

    // Emit drift tire smoke behind rear wheels if sliding
    if (isDrifting) {
        emitDriftSmoke(playerScreenX - (playerW * 0.38), playerScreenY + (playerH * 0.10), width / 800, driftAngle);
        emitDriftSmoke(playerScreenX + (playerW * 0.38), playerScreenY + (playerH * 0.10), width / 800, driftAngle);
    }

    var brakeUrl = null;
    if (spriteUrls && isBraking) {
        var brakeAngle = (angleName.charAt(0) === 'r') ? ("l" + angleName.substring(1)) : angleName;
        brakeUrl = spriteUrls[prefix + "_" + brakeAngle + "_brakes"];
    }

    drawPlayerVehicle(ctx, playerScreenX, playerScreenY, playerW, playerH, steering, isBraking, driftAngle, canvas, spriteUrl, brakeUrl, isMirrored);

    ctx.restore();
}
