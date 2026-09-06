.pragma library

// Authentic Chromium T-Rex Endless Runner Engine
// Ported directly from Chromium's components/neterror/resources/offline.js (BSD-3-Clause)

var CONFIG = {
    DEFAULT_WIDTH: 600,
    DEFAULT_HEIGHT: 150,
    GRAVITY: 0.6,
    INITIAL_JUMP_VELOCITY: -10,
    DROP_VELOCITY: -5,
    SPEED_DROP_COEFFICIENT: 3,
    INITIAL_SPEED: 6.0,
    ACCELERATION: 0.001,
    MAX_SPEED: 13.0,
    BOTTOM_PAD: 16,
    INVERT_DISTANCE: 700,
    INVERT_FADE_DURATION: 12000,
    MIN_JUMP_HEIGHT: 30,
    MAX_JUMP_HEIGHT: 63,
    GAP_COEFFICIENT: 0.6,
    MAX_CLOUDS: 6,
    CLOUD_FREQUENCY: 0.5,
    BG_CLOUD_SPEED: 0.2,
    MAX_OBSTACLE_DUPLICATION: 2
};

var SPRITES = {
    TREX: { x: 1338, y: 2 },
    CACTUS_SMALL: { x: 446, y: 2 },
    CACTUS_LARGE: { x: 652, y: 2 },
    PTERODACTYL: { x: 260, y: 2 },
    HORIZON: { x: 2, y: 104 },
    CLOUD: { x: 166, y: 2 },
    MOON: { x: 954, y: 2 },
    STAR: { x: 1276, y: 2 }
};

var TREX_CONFIG = {
    WIDTH: 44,
    HEIGHT: 47,
    WIDTH_DUCK: 59,
    HEIGHT_DUCK: 25,
    START_X_POS: 50
};

var OBSTACLE_TYPES = [
    {
        type: "CACTUS_SMALL",
        width: 17,
        height: 35,
        yOffset: 12,
        multipleSpeed: 4,
        minGap: 120,
        minSpeed: 0,
        collisionBoxes: [
            { x: 0, y: 7, w: 5, h: 27 },
            { x: 4, y: 0, w: 6, h: 34 },
            { x: 10, y: 4, w: 7, h: 14 }
        ]
    },
    {
        type: "CACTUS_LARGE",
        width: 25,
        height: 50,
        yOffset: -3,
        multipleSpeed: 7,
        minGap: 120,
        minSpeed: 0,
        collisionBoxes: [
            { x: 0, y: 12, w: 7, h: 38 },
            { x: 8, y: 0, w: 7, h: 49 },
            { x: 13, y: 10, w: 10, h: 38 }
        ]
    },
    {
        type: "PTERODACTYL",
        width: 46,
        height: 40,
        yOffset: [7, -18, -43],
        multipleSpeed: 999,
        minSpeed: 8.5,
        minGap: 150,
        numFrames: 2,
        frameRate: 1000 / 6,
        speedOffset: 0.8,
        collisionBoxes: [
            { x: 15, y: 15, w: 16, h: 5 },
            { x: 18, y: 21, w: 24, h: 6 },
            { x: 2, y: 14, w: 4, h: 3 },
            { x: 6, y: 10, w: 4, h: 7 },
            { x: 10, y: 8, w: 6, h: 9 }
        ]
    }
];

var TREX_COLLISION_BOXES = {
    RUNNING: [
        { x: 22, y: 0, w: 17, h: 16 },
        { x: 1, y: 18, w: 30, h: 9 },
        { x: 10, y: 35, w: 14, h: 8 },
        { x: 1, y: 24, w: 29, h: 5 },
        { x: 5, y: 30, w: 21, h: 4 },
        { x: 9, y: 34, w: 15, h: 4 }
    ],
    DUCKING: [
        { x: 1, y: 18, w: 55, h: 25 }
    ]
};

// Game State
var gameState = "idle"; // "idle", "playing", "crashed"
var currentWidth = CONFIG.DEFAULT_WIDTH;
var currentHeight = CONFIG.DEFAULT_HEIGHT;
var currentSpeed = CONFIG.INITIAL_SPEED;
var distanceRan = 0;
var highScore = 0;
var groundYPos = CONFIG.DEFAULT_HEIGHT - TREX_CONFIG.HEIGHT - CONFIG.BOTTOM_PAD;
var runningTime = 0;

// Trex instance
var trex = {
    xPos: TREX_CONFIG.START_X_POS,
    yPos: 93,
    status: "WAITING", // "WAITING", "RUNNING", "JUMPING", "DUCKING", "CRASHED"
    jumping: false,
    ducking: false,
    speedDrop: false,
    jumpVelocity: 0,
    reachedMinHeight: false,
    timer: 0,
    currentFrame: 0,
    blinkDelay: 0,
    blinkCount: 0
};

// Horizon objects
var horizonLine = {
    xPos: [0, 600, 1200],
    sourceXPos: [2, 602, 2],
    yPos: 127
};

var clouds = [];
var obstacles = [];
var obstacleHistory = [];
var particles = [];

// Day / Night mode
var nightMode = {
    active: false,
    opacity: 0,
    timer: 0,
    moonPhase: 0,
    moonX: 600,
    moonY: 30,
    stars: []
};

// Distance meter / Flashing milestones
var flashTimer = 0;
var flashCount = 0;
var nextMilestone = 100;
var nextInvertScore = 700;

function init(w, h) {
    if (w && h && w > 0 && h > 0) {
        currentWidth = w;
        currentHeight = h;
    }
    groundYPos = currentHeight - TREX_CONFIG.HEIGHT - CONFIG.BOTTOM_PAD;
    horizonLine.yPos = groundYPos + 34;
    resetGame();
}

function resize(w, h) {
    if (!w || !h || w <= 0 || h <= 0) return;
    currentWidth = w;
    currentHeight = h;

    var oldGround = groundYPos;
    groundYPos = currentHeight - TREX_CONFIG.HEIGHT - CONFIG.BOTTOM_PAD;
    horizonLine.yPos = groundYPos + 34;

    var deltaGround = groundYPos - oldGround;

    // Adjust T-Rex position
    if (!trex.jumping) {
        trex.yPos = groundYPos;
    } else {
        trex.yPos += deltaGround;
    }

    trex.xPos = (currentWidth < 450) ? 35 : TREX_CONFIG.START_X_POS;

    // Adjust obstacle positions
    for (var i = 0; i < obstacles.length; i++) {
        var obs = obstacles[i];
        if (typeof obs.yOffset !== "undefined") {
            obs.yPos = groundYPos + obs.yOffset;
        } else {
            obs.yPos += deltaGround;
        }
    }
}

function resetGame() {
    gameState = "playing";
    currentSpeed = CONFIG.INITIAL_SPEED;
    distanceRan = 0;
    runningTime = 0;
    nextMilestone = 100;
    nextInvertScore = CONFIG.INVERT_DISTANCE;
    flashTimer = 0;
    flashCount = 0;

    groundYPos = currentHeight - TREX_CONFIG.HEIGHT - CONFIG.BOTTOM_PAD;
    horizonLine.yPos = groundYPos + 34;

    trex.xPos = (currentWidth < 450) ? 35 : TREX_CONFIG.START_X_POS;
    trex.yPos = groundYPos;
    trex.status = "RUNNING";
    trex.jumping = false;
    trex.ducking = false;
    trex.speedDrop = false;
    trex.jumpVelocity = 0;
    trex.reachedMinHeight = false;
    trex.timer = 0;
    trex.currentFrame = 0;

    horizonLine.xPos = [0, 600, 1200];
    horizonLine.sourceXPos = [2, 602, 2];
    horizonLine.yPos = groundYPos + 34;
    clouds = [];
    obstacles = [];
    obstacleHistory = [];
    particles = [];

    nightMode.active = false;
    nightMode.opacity = 0;
    nightMode.timer = 0;
    nightMode.moonPhase = 0;
    nightMode.moonX = currentWidth - 50;
    nightMode.stars = [];

    addCloud();
}

function addCloud() {
    var skyMax = Math.max(30, groundYPos - 60);
    var skyY = 15 + Math.random() * (skyMax - 15);
    clouds.push({
        xPos: currentWidth + Math.random() * 60,
        yPos: skyY,
        gap: 100 + Math.random() * 200,
        remove: false
    });
}

function addObstacle(speed) {
    var avail = [];
    for (var o = 0; o < OBSTACLE_TYPES.length; o++) {
        var ot = OBSTACLE_TYPES[o];
        if (speed >= ot.minSpeed) {
            avail.push(ot);
        }
    }
    if (avail.length === 0) avail.push(OBSTACLE_TYPES[0]);

    var chosen = avail[Math.floor(Math.random() * avail.length)];

    // Check duplicate limit
    var dupCount = 0;
    for (var h = 0; h < obstacleHistory.length; h++) {
        if (obstacleHistory[h] === chosen.type) dupCount++;
    }
    if (dupCount >= CONFIG.MAX_OBSTACLE_DUPLICATION && avail.length > 1) {
        chosen = (chosen === avail[0]) ? avail[1] : avail[0];
    }

    obstacleHistory.unshift(chosen.type);
    if (obstacleHistory.length > 3) obstacleHistory.pop();

    var size = 1;
    if (chosen.type !== "PTERODACTYL") {
        if (speed > chosen.multipleSpeed) {
            size = Math.floor(Math.random() * 3) + 1;
        }
    }

    var offset = chosen.yOffset;
    if (Array.isArray(chosen.yOffset)) {
        offset = chosen.yOffset[Math.floor(Math.random() * chosen.yOffset.length)];
    }
    var y = groundYPos + offset;

    var speedOffset = 0;
    if (chosen.speedOffset) {
        speedOffset = (Math.random() > 0.5 ? 1 : -1) * chosen.speedOffset;
    }

    var minGap = Math.round((chosen.width * size) * speed + chosen.minGap * CONFIG.GAP_COEFFICIENT);
    var maxGap = Math.round(minGap * 1.5);
    var gap = minGap + Math.floor(Math.random() * (maxGap - minGap + 1));

    // Clone and adjust collision boxes for multi-obstacle groups (double/triple cacti)
    var boxes = [];
    for (var b = 0; b < chosen.collisionBoxes.length; b++) {
        var cb = chosen.collisionBoxes[b];
        boxes.push({ x: cb.x, y: cb.y, w: cb.w, h: cb.h });
    }
    if (size > 1) {
        var totalW = chosen.width * size;
        boxes[1].w = totalW - boxes[0].w - boxes[2].w;
        boxes[2].x = totalW - boxes[2].w;
    }

    obstacles.push({
        typeConfig: chosen,
        type: chosen.type,
        size: size,
        width: chosen.width * size,
        height: chosen.height,
        xPos: currentWidth + 20,
        yPos: y,
        yOffset: offset,
        gap: gap,
        speedOffset: speedOffset,
        collisionBoxes: boxes,
        currentFrame: 0,
        frameTimer: 0,
        remove: false,
        followingCreated: false
    });
}

// User Actions
function startJump(callbacks) {
    if (gameState !== "playing") return;
    if (!trex.jumping) {
        trex.status = "JUMPING";
        trex.jumping = true;
        trex.ducking = false;
        trex.reachedMinHeight = false;
        trex.speedDrop = false;
        trex.jumpVelocity = CONFIG.INITIAL_JUMP_VELOCITY - (currentSpeed / 10);
        if (callbacks && callbacks.onSound) callbacks.onSound("jump");
    }
}

function endJump() {
    if (trex.jumping) {
        if (trex.reachedMinHeight && trex.jumpVelocity < CONFIG.DROP_VELOCITY) {
            trex.jumpVelocity = CONFIG.DROP_VELOCITY;
        }
    }
}

function setDucking(isDucking) {
    if (gameState !== "playing") return;
    if (trex.jumping) {
        if (isDucking) {
            // Speed drop fast-fall dive
            trex.speedDrop = true;
            trex.jumpVelocity = 1;
        }
    } else {
        if (isDucking) {
            trex.ducking = true;
            trex.status = "DUCKING";
        } else {
            trex.ducking = false;
            trex.status = "RUNNING";
        }
    }
}

function update(deltaTime, callbacks) {
    if (gameState !== "playing") return;

    runningTime += deltaTime;

    // Accelerate speed
    if (currentSpeed < CONFIG.MAX_SPEED) {
        currentSpeed += CONFIG.ACCELERATION;
    }

    // Distance run matching Chromium DistanceMeter (COEFFICIENT: 0.025)
    distanceRan += currentSpeed * (deltaTime / 16.666);
    var intDist = Math.floor(distanceRan * 0.025);

    // Milestone sound (every 100 points)
    if (intDist >= nextMilestone) {
        nextMilestone += 100;
        flashCount = 8; // Flash 4 times (on/off)
        flashTimer = 0;
        if (callbacks && callbacks.onSound) callbacks.onSound("score");
    }

    if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(intDist);

    // Day / Night cycle: triggers every 700 points, lasts 12 seconds
    if (intDist >= nextInvertScore && !nightMode.active) {
        nightMode.active = true;
        nightMode.timer = 0;
        nextInvertScore += CONFIG.INVERT_DISTANCE;
        nightMode.moonPhase = (nightMode.moonPhase + 1) % 7;
        nightMode.moonX = currentWidth - 50;
        nightMode.moonY = 25;
        nightMode.stars = [
            { x: currentWidth * 0.85, y: 25 },
            { x: currentWidth * 0.55, y: 45 },
            { x: currentWidth * 0.25, y: 35 },
            { x: currentWidth * 0.10, y: 55 }
        ];
    }

    if (nightMode.active) {
        nightMode.timer += deltaTime;
        // Fade in during first 1.2 seconds
        if (nightMode.timer < 1200) {
            nightMode.opacity = nightMode.timer / 1200;
        } else if (nightMode.timer > CONFIG.INVERT_FADE_DURATION - 1200) {
            // Fade out during last 1.2 seconds
            nightMode.opacity = Math.max(0, (CONFIG.INVERT_FADE_DURATION - nightMode.timer) / 1200);
        } else {
            nightMode.opacity = 1.0;
        }

        if (nightMode.timer >= CONFIG.INVERT_FADE_DURATION) {
            nightMode.active = false;
            nightMode.opacity = 0;
            nightMode.timer = 0;
        }

        // Move moon and stars
        nightMode.moonX -= 0.25 * (deltaTime / 16.666);
        for (var s = 0; s < nightMode.stars.length; s++) {
            nightMode.stars[s].x -= 0.3 * (deltaTime / 16.666);
            if (nightMode.stars[s].x < -20) {
                nightMode.stars[s].x = currentWidth + 20;
            }
        }
    } else {
        nightMode.opacity = 0;
    }

    // Update Horizon Line
    var groundInc = Math.floor(currentSpeed * (60 / 1000) * deltaTime);
    for (var h = 0; h < horizonLine.xPos.length; h++) {
        horizonLine.xPos[h] -= groundInc;
    }
    for (var h = 0; h < horizonLine.xPos.length; h++) {
        if (horizonLine.xPos[h] <= -600) {
            var maxX = -600;
            for (var k = 0; k < horizonLine.xPos.length; k++) {
                if (horizonLine.xPos[k] > maxX) maxX = horizonLine.xPos[k];
            }
            horizonLine.xPos[h] = maxX + 600;
        }
    }

    // Update Clouds
    var cloudMove = (CONFIG.BG_CLOUD_SPEED / 1000) * deltaTime * currentSpeed;
    for (var ci = clouds.length - 1; ci >= 0; ci--) {
        clouds[ci].xPos -= cloudMove;
        if (clouds[ci].xPos < -80) {
            clouds.splice(ci, 1);
        }
    }
    if (clouds.length < CONFIG.MAX_CLOUDS) {
        var lastCloud = clouds[clouds.length - 1];
        if (!lastCloud || (currentWidth - lastCloud.xPos > lastCloud.gap && Math.random() < CONFIG.CLOUD_FREQUENCY)) {
            addCloud();
        }
    }

    // Update Obstacles
    var obstacleSpeed = Math.floor(currentSpeed * (60 / 1000) * deltaTime);
    for (var oi = obstacles.length - 1; oi >= 0; oi--) {
        var obs = obstacles[oi];
        var oSpeed = obstacleSpeed;
        if (obs.speedOffset) oSpeed += obs.speedOffset;
        obs.xPos -= oSpeed;

        // Animated obstacles (Pterodactyl)
        if (obs.typeConfig.numFrames) {
            obs.frameTimer += deltaTime;
            if (obs.frameTimer >= obs.typeConfig.frameRate) {
                obs.currentFrame = (obs.currentFrame + 1) % obs.typeConfig.numFrames;
                obs.frameTimer = 0;
            }
        }

        // Spawn next obstacle
        if (!obs.followingCreated && obs.xPos + obs.width + obs.gap < currentWidth) {
            addObstacle(currentSpeed);
            obs.followingCreated = true;
        }

        if (obs.xPos + obs.width < -40) {
            obstacles.splice(oi, 1);
        }
    }
    if (obstacles.length === 0) {
        addObstacle(currentSpeed);
    }

    // Update Trex Physics & Animation
    if (trex.jumping) {
        var framesElapsed = deltaTime / (1000 / 60);
        if (trex.speedDrop) {
            trex.yPos += Math.round(trex.jumpVelocity * CONFIG.SPEED_DROP_COEFFICIENT * framesElapsed);
        } else {
            trex.yPos += Math.round(trex.jumpVelocity * framesElapsed);
        }

        trex.jumpVelocity += CONFIG.GRAVITY * framesElapsed;

        if (trex.yPos < groundYPos - CONFIG.MIN_JUMP_HEIGHT || trex.speedDrop) {
            trex.reachedMinHeight = true;
        }
        if (trex.yPos < groundYPos - CONFIG.MAX_JUMP_HEIGHT || trex.speedDrop) {
            endJump();
        }
        if (trex.yPos >= groundYPos) {
            trex.yPos = groundYPos;
            trex.jumping = false;
            trex.speedDrop = false;
            trex.jumpVelocity = 0;
            trex.status = trex.ducking ? "DUCKING" : "RUNNING";
        }
    } else {
        // Trot / Duck leg animation
        trex.timer += deltaTime;
        var msPerFrame = (trex.status === "DUCKING") ? (1000 / 8) : (1000 / 12);
        if (trex.timer >= msPerFrame) {
            trex.currentFrame = (trex.currentFrame + 1) % 2;
            trex.timer = 0;
        }
    }

    // Check Collisions
    if (obstacles.length > 0) {
        var firstObs = obstacles[0];
        if (firstObs.xPos < trex.xPos + 80 && firstObs.xPos + firstObs.width > trex.xPos) {
            if (checkCollision(trex, firstObs)) {
                triggerCrash(callbacks);
                return;
            }
        }
    }
}

// Axis-Aligned Bounding Box & Multi-box Sub-collision
function boxCompare(b1, b2) {
    return (b1.x < b2.x + b2.w &&
            b1.x + b1.w > b2.x &&
            b1.y < b2.y + b2.h &&
            b1.y + b1.h > b2.y);
}

function checkCollision(t, obs) {
    var isDucking = (t.status === "DUCKING");
    var tW = isDucking ? TREX_CONFIG.WIDTH_DUCK : TREX_CONFIG.WIDTH;
    var tH = isDucking ? TREX_CONFIG.HEIGHT_DUCK : TREX_CONFIG.HEIGHT;
    var tY = isDucking ? (groundYPos + (TREX_CONFIG.HEIGHT - TREX_CONFIG.HEIGHT_DUCK)) : t.yPos;

    var broadTrex = { x: t.xPos + 1, y: tY + 1, w: tW - 2, h: tH - 2 };
    var broadObs = { x: obs.xPos + 1, y: obs.yPos + 1, w: obs.width - 2, h: obs.height - 2 };

    if (!boxCompare(broadTrex, broadObs)) return false;

    // Detailed sub-box comparison
    var tBoxes = isDucking ? TREX_COLLISION_BOXES.DUCKING : TREX_COLLISION_BOXES.RUNNING;
    var oBoxes = obs.collisionBoxes || obs.typeConfig.collisionBoxes;

    for (var i = 0; i < tBoxes.length; i++) {
        var tb = tBoxes[i];
        var adjT = { x: t.xPos + 1 + tb.x, y: tY + 1 + tb.y, w: tb.w, h: tb.h };
        for (var j = 0; j < oBoxes.length; j++) {
            var ob = oBoxes[j];
            var adjO = { x: obs.xPos + 1 + ob.x, y: obs.yPos + 1 + ob.y, w: ob.w, h: ob.h };
            if (boxCompare(adjT, adjO)) {
                return true;
            }
        }
    }
    return false;
}

function triggerCrash(callbacks) {
    gameState = "crashed";
    trex.status = "CRASHED";
    var finalDist = Math.floor(distanceRan);
    if (finalDist > highScore) highScore = finalDist;
    if (callbacks && callbacks.onSound) callbacks.onSound("crash");
    if (callbacks && callbacks.onGameOver) callbacks.onGameOver(finalDist);
}
