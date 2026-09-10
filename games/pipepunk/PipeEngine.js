// Pipe Punk • Steampunk Pipe Routing Simulation Engine
.pragma library

var COLS = 10;
var ROWS = 8;

var CONNECTIONS = {
    "pipe_h": ["W", "E"],
    "pipe_v": ["N", "S"],
    "corner_1": ["N", "E"],
    "corner_2": ["N", "W"],
    "corner_3": ["S", "E"],
    "corner_4": ["S", "W"],
    "cross": ["N", "S", "E", "W"],
    "reservoir": ["W", "E"]
};

var OPPOSITE_PORT = {
    "N": "S",
    "S": "N",
    "E": "W",
    "W": "E"
};

var DELTAS = {
    "N": { r: -1, c: 0 },
    "S": { r: 1, c: 0 },
    "E": { r: 0, c: 1 },
    "W": { r: 0, c: -1 }
};

var PIECE_TYPES = [
    "pipe_h", "pipe_v",
    "corner_1", "corner_2", "corner_3", "corner_4",
    "cross", "reservoir"
];

var PIECE_WEIGHTS = [
    18, 18,
    11, 11, 11, 11,
    12, 8
];

function getRandomPiece() {
    var total = 0;
    for (var i = 0; i < PIECE_WEIGHTS.length; i++) total += PIECE_WEIGHTS[i];
    var rnd = Math.random() * total;
    var acc = 0;
    for (var j = 0; j < PIECE_WEIGHTS.length; j++) {
        acc += PIECE_WEIGHTS[j];
        if (rnd <= acc) return PIECE_TYPES[j];
    }
    return "pipe_h";
}

function createGameState(level) {
    level = level || 1;
    var quota = 5 + (level - 1) * 3; // L1: 5, L2: 8, L3: 11, L4: 14...
    
    // Initialize empty grid
    var grid = [];
    for (var r = 0; r < ROWS; r++) {
        var row = [];
        for (var c = 0; c < COLS; c++) {
            row.push({
                type: "empty",
                filled: false,
                fillProgress: 0.0,
                entryPort: "",
                exitPort: "",
                crossPasses: 0,
                isFlowing: false
            });
        }
        grid.push(row);
    }
    
    // Add boiler hazard blocks for higher levels
    var hazardCount = Math.min(6, Math.max(0, level - 2));
    var placedHazards = 0;
    while (placedHazards < hazardCount) {
        var hr = Math.floor(Math.random() * (ROWS - 2)) + 1;
        var hc = Math.floor(Math.random() * (COLS - 4)) + 2;
        if (grid[hr][hc].type === "empty") {
            grid[hr][hc].type = "hazard";
            placedHazards++;
        }
    }
    
    // Place starting Valve on left border pointing East
    var valveRow = Math.floor(Math.random() * (ROWS - 4)) + 2;
    var valveCol = 1;
    grid[valveRow][valveCol] = {
        type: "valve",
        filled: false,
        fillProgress: 0.0,
        entryPort: "W",
        exitPort: "E",
        crossPasses: 0,
        isFlowing: false
    };
    
    // Initial 5-piece queue
    var queue = [];
    for (var q = 0; q < 5; q++) {
        queue.push(getRandomPiece());
    }
    
    return {
        level: level,
        quota: quota,
        traversedCount: 0,
        score: 0,
        state: "countdown", // "countdown", "flowing", "round_won", "game_over"
        countdown: 10.0,
        grid: grid,
        queue: queue,
        valveRow: valveRow,
        valveCol: valveCol,
        currentR: valveRow,
        currentC: valveCol,
        entryPort: "W",
        exitPort: "E",
        fillProgress: 0.0,
        isRushing: false,
        leakPos: null,
        psi: 24.0,
        targetPsi: 24.0
    };
}

function placeNextPiece(game, r, c) {
    if (!game || r < 0 || r >= ROWS || c < 0 || c >= COLS) return false;
    var cell = game.grid[r][c];
    
    // Can only place on empty cells or un-filled pipes (replacing costs 50 pts)
    if (cell.type === "hazard" || cell.type === "valve" || cell.filled || cell.isFlowing) {
        return false;
    }
    
    if (cell.type !== "empty") {
        game.score = Math.max(0, game.score - 50);
    }
    
    var nextPiece = game.queue.shift();
    game.queue.push(getRandomPiece());
    
    cell.type = nextPiece;
    cell.filled = false;
    cell.fillProgress = 0.0;
    cell.entryPort = "";
    cell.exitPort = "";
    cell.crossPasses = 0;
    cell.isFlowing = false;
    
    return true;
}

function updateSimulation(game, dt) {
    if (!game) return;
    
    // Update PSI gauge smoothing
    var psiDiff = game.targetPsi - game.psi;
    game.psi += psiDiff * Math.min(1.0, dt * 5.0);
    
    // 1. COUNTDOWN STAGE
    if (game.state === "countdown") {
        game.countdown = Math.max(0.0, game.countdown - dt);
        game.targetPsi = 24.0 + (10.0 - game.countdown) * 3.5;
        
        if (game.countdown <= 0.0) {
            game.state = "flowing";
            game.currentR = game.valveRow;
            game.currentC = game.valveCol;
            game.entryPort = "W";
            game.exitPort = "E";
            game.fillProgress = 0.0;
            var vCell = game.grid[game.valveRow][game.valveCol];
            vCell.isFlowing = true;
            game.targetPsi = 58.0;
        }
        return;
    }
    
    // 2. FLOWING STAGE
    if (game.state === "flowing") {
        var baseDuration = 1.6 - Math.min(0.6, (game.level - 1) * 0.1);
        var currentCell = game.grid[game.currentR][game.currentC];
        
        if (currentCell.type === "reservoir") {
            baseDuration *= 2.8; // Reservoir takes longer to fill
        }
        
        var stepDuration = game.isRushing ? 0.22 : baseDuration;
        var progressDelta = dt / stepDuration;
        
        game.fillProgress += progressDelta;
        currentCell.fillProgress = Math.min(1.0, game.fillProgress);
        
        if (game.isRushing) {
            game.score += Math.round(dt * 60);
            game.targetPsi = 95.0 + Math.sin(Date.now() * 0.02) * 5.0;
        } else {
            game.targetPsi = 62.0 + Math.sin(Date.now() * 0.005) * 3.0;
        }
        
        if (game.fillProgress >= 1.0) {
            advanceFlow(game);
        }
    }
}

function advanceFlow(game) {
    var currCell = game.grid[game.currentR][game.currentC];
    currCell.filled = true;
    currCell.isFlowing = false;
    currCell.fillProgress = 1.0;
    
    game.traversedCount++;
    game.score += 100;
    
    // Cross pipe double traversal bonus
    if (currCell.type === "cross") {
        currCell.crossPasses++;
        if (currCell.crossPasses >= 2) {
            game.score += 500; // Big cross-loop bonus!
        }
    }
    
    // Compute next coordinates
    var delta = DELTAS[game.exitPort];
    var nextR = game.currentR + delta.r;
    var nextC = game.currentC + delta.c;
    var expectedEntry = OPPOSITE_PORT[game.exitPort];
    
    // Check out of bounds
    if (nextR < 0 || nextR >= ROWS || nextC < 0 || nextC >= COLS) {
        handleBlowout(game, nextR, nextC);
        return;
    }
    
    var nextCell = game.grid[nextR][nextC];
    
    // Check if next cell is valid pipe and has matching entry port
    if (nextCell.type === "empty" || nextCell.type === "hazard" || nextCell.type === "valve") {
        handleBlowout(game, nextR, nextC);
        return;
    }
    
    // Check port connectivity
    var allowedPorts = CONNECTIONS[nextCell.type] || [];
    if (allowedPorts.indexOf(expectedEntry) === -1) {
        handleBlowout(game, nextR, nextC);
        return;
    }
    
    // If it is a cross pipe already filled in the same orientation, cannot reuse same path
    if (nextCell.type === "cross" && nextCell.crossPasses >= 2) {
        handleBlowout(game, nextR, nextC);
        return;
    } else if (nextCell.type !== "cross" && nextCell.filled) {
        handleBlowout(game, nextR, nextC);
        return;
    }
    
    // Determine exit port from next cell
    var nextExit = "";
    if (nextCell.type === "cross") {
        // Cross maintains straight line
        nextExit = (expectedEntry === "W") ? "E" :
                   (expectedEntry === "E") ? "W" :
                   (expectedEntry === "N") ? "S" : "N";
    } else {
        // For other pipes, exit is the port that is not expectedEntry
        for (var p = 0; p < allowedPorts.length; p++) {
            if (allowedPorts[p] !== expectedEntry) {
                nextExit = allowedPorts[p];
                break;
            }
        }
    }
    
    // Transition flow into next cell
    game.currentR = nextR;
    game.currentC = nextC;
    game.entryPort = expectedEntry;
    game.exitPort = nextExit;
    game.fillProgress = 0.0;
    nextCell.entryPort = expectedEntry;
    nextCell.exitPort = nextExit;
    nextCell.isFlowing = true;
}

function handleBlowout(game, leakR, leakC) {
    game.leakPos = { r: leakR, c: leakC };
    game.targetPsi = 0.0;
    
    if (game.traversedCount >= game.quota) {
        game.state = "round_won";
        var bonus = (game.traversedCount - game.quota) * 250 + game.level * 1000;
        game.score += bonus;
    } else {
        game.state = "game_over";
    }
}
