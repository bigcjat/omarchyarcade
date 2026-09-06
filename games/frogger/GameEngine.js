.pragma library

var GRID_SIZE = 42;
var width = 600;
var height = 700;

var frog = null;
var lanes = [];
var particles = [];
var coins = [];
var eagle = null; // { x, y, targetY, active, swooping }

var score = 0;
var maxRow = 0;
var highScore = 0;
var gameState = "ready"; // "ready", "playing", "gameover"

var cameraY = 0;
var targetCameraY = 0;
var minAllowedY = 0;
var idleFrames = 0;
var MAX_IDLE_FRAMES = 320; // ~5.3 seconds

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
    maxRow = 0;
    gameState = "playing";
    particles = [];
    coins = [];
    eagle = null;
    idleFrames = 0;
    lanes = [];

    var startCol = 0; // Center column is 0
    frog = {
        col: startCol,
        row: 0,
        worldX: startCol * GRID_SIZE,
        worldY: 0,
        animX: startCol * GRID_SIZE,
        animY: 0,
        isHopping: false,
        hopProgress: 1.0,
        facing: 0, // 0: up, 1: right, 2: down, 3: left
        scaleX: 1.0,
        scaleY: 1.0,
        onLog: null
    };

    cameraY = -height * 0.35;
    targetCameraY = cameraY;
    minAllowedY = -GRID_SIZE * 2;

    // Generate initial safe zone and initial 35 lanes ahead
    for (var r = -4; r <= 35; r++) {
        lanes.push(generateLane(r));
    }
}

function generateLane(rowIndex) {
    // Initial starting rows are always safe grass
    if (rowIndex <= 2) {
        return {
            row: rowIndex,
            type: "grass",
            trees: (rowIndex < 0) ? [-3, -2, 2, 3] : [],
            items: []
        };
    }

    // Lane generation algorithm with natural biome clustering
    var cycle = rowIndex % 24;
    var type = "grass";
    var dir = (Math.random() < 0.5) ? 1 : -1;
    var speed = 1.6 + Math.random() * 1.8;
    var items = [];
    var trees = [];

    if (cycle >= 3 && cycle <= 7) {
        // 5-lane highway section
        type = "road";
        speed = 1.8 + (cycle - 3) * 0.4 + Math.random() * 0.5;
        dir = (cycle % 2 === 0) ? 1 : -1;
        var numVehicles = 2 + Math.floor(Math.random() * 2);
        var spacing = Math.max(180, (width + 200) / numVehicles);
        for (var vi = 0; vi < numVehicles; vi++) {
            var vType = Math.random() < 0.35 ? "truck" : (Math.random() < 0.25 ? "racecar" : "sedan");
            var vLen = (vType === "truck") ? 78 : ((vType === "racecar") ? 42 : 52);
            var vSpeed = (vType === "racecar") ? speed * 1.35 : ((vType === "truck") ? speed * 0.85 : speed);
            items.push({
                x: vi * spacing + Math.random() * 40 - (width / 2),
                len: vLen,
                speed: vSpeed,
                dir: dir,
                vehicleType: vType
            });
        }
    } else if (cycle === 8 || cycle === 9) {
        // Safe grassy median
        type = "grass";
        for (var tc = -8; tc <= 8; tc++) {
            if (Math.abs(tc) > 1 && Math.random() < 0.22) {
                trees.push(tc);
            }
        }
    } else if (cycle >= 10 && cycle <= 13) {
        // River section with floating logs and lily pads
        type = "river";
        dir = (cycle % 2 === 0) ? 1 : -1;
        speed = 1.3 + Math.random() * 1.2;
        var numLogs = 3;
        var logSpacing = (width + 200) / numLogs;
        for (var li = 0; li < numLogs; li++) {
            var isLily = Math.random() < 0.28;
            var logLen = isLily ? 36 : (Math.random() < 0.4 ? 110 : 76);
            items.push({
                x: li * logSpacing + Math.random() * 30 - (width / 2),
                len: logLen,
                speed: speed,
                dir: dir,
                isLily: isLily
            });
        }
    } else if (cycle === 14) {
        type = "grass";
    } else if (cycle === 15 || cycle === 16) {
        // High speed railroad tracks
        type = "railroad";
        items.push({
            hasTrain: false,
            trainX: 0,
            trainSpeed: 20.0,
            trainDir: dir,
            warning: false,
            warningTimer: 80 + Math.floor(Math.random() * 140),
            trainLength: 500
        });
    } else if (cycle >= 17 && cycle <= 21) {
        // Mixed highway / road
        type = "road";
        dir = (cycle % 2 === 0) ? 1 : -1;
        speed = 2.0 + Math.random() * 1.5;
        var nVeh = 2 + Math.floor(Math.random() * 2);
        var spc = (width + 200) / nVeh;
        for (var v = 0; v < nVeh; v++) {
            var vt = Math.random() < 0.3 ? "truck" : "sedan";
            items.push({
                x: v * spc - (width / 2),
                len: vt === "truck" ? 78 : 52,
                speed: speed,
                dir: dir,
                vehicleType: vt
            });
        }
    } else {
        // Grassy resting bank
        type = "grass";
        for (var c = -8; c <= 8; c++) {
            if (Math.abs(c) > 2 && Math.random() < 0.25) {
                trees.push(c);
            }
        }
    }

    // Occasional coin pickup on grass or logs
    if (type === "grass" && Math.random() < 0.18) {
        var coinCol = Math.floor(Math.random() * 7) - 3;
        if (trees.indexOf(coinCol) === -1) {
            coins.push({ col: coinCol, row: rowIndex, collected: false });
        }
    }

    return {
        row: rowIndex,
        type: type,
        dir: dir,
        speed: speed,
        items: items,
        trees: trees
    };
}

function getLaneAtRow(r) {
    for (var i = 0; i < lanes.length; i++) {
        if (lanes[i].row === r) return lanes[i];
    }
    return null;
}

function hop(dCol, dRow, callbacks) {
    if (gameState !== "playing" || !frog) return;

    var targetCol = frog.col + dCol;
    var targetRow = frog.row + dRow;

    // Boundary check horizontal
    var halfCols = Math.max(7, Math.floor((width / 2) / GRID_SIZE) - 1);
    if (targetCol < -halfCols || targetCol > halfCols) return;

    // Check if blocked by a tree/boulder
    var lane = getLaneAtRow(targetRow);
    if (lane && lane.trees && lane.trees.indexOf(targetCol) !== -1) {
        // Bonk on tree!
        return;
    }

    // Determine facing angle
    if (dRow > 0) frog.facing = 0; // Up
    else if (dCol > 0) frog.facing = 1; // Right
    else if (dRow < 0) frog.facing = 2; // Down
    else if (dCol < 0) frog.facing = 3; // Left

    frog.col = targetCol;
    frog.row = targetRow;
    frog.worldX = targetCol * GRID_SIZE;
    frog.worldY = targetRow * GRID_SIZE;
    frog.isHopping = true;
    frog.hopProgress = 0.0;
    frog.onLog = null;
    idleFrames = 0;

    // Hop dust particles
    for (var p = 0; p < 4; p++) {
        particles.push({
            x: frog.animX,
            y: frog.animY + 8,
            vx: (Math.random() - 0.5) * 1.5,
            vy: (Math.random() - 0.5) * 1.5,
            life: 12,
            maxLife: 12,
            isWater: false
        });
    }

    if (callbacks && callbacks.onSound) callbacks.onSound("hop");

    // Check coin pickup
    for (var ci = 0; ci < coins.length; ci++) {
        var cn = coins[ci];
        if (!cn.collected && cn.col === frog.col && cn.row === frog.row) {
            cn.collected = true;
            score += 5;
            if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            if (callbacks && callbacks.onSound) callbacks.onSound("coin");
        }
    }

    // Scoring forward progress
    if (frog.row > maxRow) {
        var gained = frog.row - maxRow;
        maxRow = frog.row;
        score += gained;
        if (score > highScore) highScore = score;
        if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
    }
}

function triggerGameOver(reason, callbacks) {
    if (gameState !== "playing") return;
    gameState = "gameover";

    // Splash or squish particles
    var isSplash = (reason === "water");
    for (var p = 0; p < 18; p++) {
        var ang = Math.random() * Math.PI * 2;
        var sp = 1.0 + Math.random() * 3.0;
        particles.push({
            x: frog.animX,
            y: frog.animY,
            vx: Math.cos(ang) * sp,
            vy: Math.sin(ang) * sp,
            life: 25,
            maxLife: 25,
            isWater: isSplash
        });
    }

    if (callbacks && callbacks.onSound) {
        if (isSplash) callbacks.onSound("plunk");
        else if (reason === "eagle") callbacks.onSound("swoop");
        else callbacks.onSound("squash");
    }

    if (callbacks && callbacks.onGameOver) callbacks.onGameOver(score);
}

function update(callbacks) {
    if (gameState !== "playing") return;

    idleFrames++;

    // Smooth hop animation
    if (frog.isHopping) {
        frog.hopProgress += 0.22;
        if (frog.hopProgress >= 1.0) {
            frog.hopProgress = 1.0;
            frog.isHopping = false;
            frog.animX = frog.worldX;
            frog.animY = frog.worldY;
        } else {
            // Parabolic jump arc & squash/stretch
            var t = frog.hopProgress;
            var jumpY = Math.sin(t * Math.PI) * 16;
            frog.animX = frog.animX + (frog.worldX - frog.animX) * 0.45;
            frog.animY = frog.worldY - jumpY;
        }
    }

    // Camera follow smoothly
    targetCameraY = frog.worldY - height * 0.35;
    cameraY += (targetCameraY - cameraY) * 0.12;

    // Trailing deadline / eagle swoop
    minAllowedY += 0.22; // continuous slow creep
    var frogScreenY = frog.animY - cameraY;
    if (frogScreenY > height + 20 || idleFrames > MAX_IDLE_FRAMES) {
        if (!eagle) {
            eagle = {
                x: frog.animX,
                y: cameraY - 120,
                targetY: frog.animY + 20,
                speed: 14.0
            };
            if (callbacks && callbacks.onSound) callbacks.onSound("swoop");
        }
    }

    // Eagle update
    if (eagle) {
        eagle.y += eagle.speed;
        if (Math.hypot(eagle.x - frog.animX, eagle.y - frog.animY) < 30) {
            triggerGameOver("eagle", callbacks);
            return;
        }
    }

    // Ensure lanes are populated ahead and cleaned up behind
    var highestLaneRow = lanes.length > 0 ? lanes[lanes.length - 1].row : 0;
    while (highestLaneRow < frog.row + 30) {
        highestLaneRow++;
        lanes.push(generateLane(highestLaneRow));
    }
    while (lanes.length > 50 && lanes[0].row < frog.row - 12) {
        lanes.shift();
    }

    // Update lane objects (cars, logs, trains)
    var currentLane = getLaneAtRow(frog.row);
    var ridingLog = null;

    for (var li = 0; li < lanes.length; li++) {
        var lane = lanes[li];

        if (lane.type === "road") {
            for (var vi = 0; vi < lane.items.length; vi++) {
                var veh = lane.items[vi];
                veh.x += veh.speed * veh.dir;

                // Wraparound vehicle across widescreen width
                var halfBound = (width / 2) + 120;
                if (veh.dir > 0 && veh.x > halfBound) veh.x = -halfBound;
                else if (veh.dir < 0 && veh.x < -halfBound) veh.x = halfBound;

                // Collision with frog
                if (lane.row === frog.row && !frog.isHopping) {
                    var carLeft = veh.x - veh.len / 2;
                    var carRight = veh.x + veh.len / 2;
                    var frogX = frog.animX;
                    if (frogX + 12 > carLeft && frogX - 12 < carRight) {
                        triggerGameOver("traffic", callbacks);
                        return;
                    }
                }
            }
        } else if (lane.type === "river") {
            for (var logI = 0; logI < lane.items.length; logI++) {
                var lg = lane.items[logI];
                lg.x += lg.speed * lg.dir;

                var rBound = (width / 2) + 100;
                if (lg.dir > 0 && lg.x > rBound) lg.x = -rBound;
                else if (lg.dir < 0 && lg.x < -rBound) lg.x = rBound;

                // Check if frog is on this log
                if (lane.row === frog.row && !frog.isHopping) {
                    var logLeft = lg.x - lg.len / 2;
                    var logRight = lg.x + lg.len / 2;
                    var fX = frog.animX;
                    if (fX >= logLeft - 10 && fX <= logRight + 10) {
                        ridingLog = lg;
                    }
                }
            }
        } else if (lane.type === "railroad") {
            for (var ti = 0; ti < lane.items.length; ti++) {
                var tr = lane.items[ti];
                tr.warningTimer--;

                if (tr.warningTimer === 50) {
                    tr.warning = true;
                    if (callbacks && callbacks.onSound) callbacks.onSound("train_bell");
                }

                if (tr.warningTimer <= 0) {
                    if (!tr.hasTrain) {
                        tr.hasTrain = true;
                        tr.trainX = tr.trainDir > 0 ? -(width / 2) - tr.trainLength : (width / 2) + tr.trainLength;
                        if (callbacks && callbacks.onSound) callbacks.onSound("train_pass");
                    }

                    tr.trainX += tr.trainSpeed * tr.trainDir;

                    // Train collision check
                    if (lane.row === frog.row) {
                        var tLeft = tr.trainX - tr.trainLength / 2;
                        var tRight = tr.trainX + tr.trainLength / 2;
                        if (frog.animX >= tLeft && frog.animX <= tRight) {
                            triggerGameOver("train", callbacks);
                            return;
                        }
                    }

                    // Reset train after passing
                    var outBound = (width / 2) + tr.trainLength + 100;
                    if ((tr.trainDir > 0 && tr.trainX > outBound) || (tr.trainDir < 0 && tr.trainX < -outBound)) {
                        tr.hasTrain = false;
                        tr.warning = false;
                        tr.warningTimer = 180 + Math.floor(Math.random() * 240);
                    }
                }
            }
        }
    }

    // River physics: check if frog fell in water or is drifting on log
    if (currentLane && currentLane.type === "river" && !frog.isHopping) {
        if (ridingLog) {
            // Drift with log
            frog.animX += ridingLog.speed * ridingLog.dir;
            frog.worldX = frog.animX;
            frog.col = Math.round(frog.worldX / GRID_SIZE);

            // Off-screen check
            if (Math.abs(frog.animX) > (width / 2) + 20) {
                triggerGameOver("water", callbacks);
                return;
            }
        } else {
            // Drowned in river!
            triggerGameOver("water", callbacks);
            return;
        }
    }

    // Particles update
    for (var pi = particles.length - 1; pi >= 0; pi--) {
        var pt = particles[pi];
        pt.x += pt.vx;
        pt.y += pt.vy;
        pt.life--;
        if (pt.life <= 0) particles.splice(pi, 1);
    }
}
