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

function isValidPreplacedPipe(grid, r, c, pieceType, isIron, valveRow, valveCol) {
    if (grid[r][c].type !== "empty") return false;
    if (r === valveRow && c === valveCol + 1) return false;
    
    var ports = CONNECTIONS[pieceType] || [];
    
    // 1. Ports cannot point into outer walls, hazards, or valve
    for (var p = 0; p < ports.length; p++) {
        var port = ports[p];
        var nr = r + DELTAS[port].r;
        var nc = c + DELTAS[port].c;
        if (nr < 0 || nr >= ROWS || nc < 0 || nc >= COLS) return false; // Outer wall deadend
        var nCell = grid[nr][nc];
        if (nCell.type === "hazard" || nCell.type === "valve") return false; // Hazard or valve deadend
    }
    
    // 2. Neighbor checks:
    // Unchangeable pipes cannot make deadends into other pipes or walls, but CAN link together
    var ALL_DIRS = ["N", "S", "E", "W"];
    for (var d = 0; d < ALL_DIRS.length; d++) {
        var dir = ALL_DIRS[d];
        var nr = r + DELTAS[dir].r;
        var nc = c + DELTAS[dir].c;
        if (nr < 0 || nr >= ROWS || nc < 0 || nc >= COLS) continue;
        var nCell = grid[nr][nc];
        if (nCell.type === "empty" || nCell.type === "hazard" || nCell.type === "valve") continue;
        
        var opp = OPPOSITE_PORT[dir];
        var nPorts = CONNECTIONS[nCell.type] || [];
        var nPointsToMe = (nPorts.indexOf(opp) !== -1);
        var mePointsToN = (ports.indexOf(dir) !== -1);
        
        // If either this piece or neighbor is an unchangeable iron pipe,
        // they must link together cleanly if facing each other, and cannot point into casing
        if (isIron || nCell.isPermanent) {
            if (nPointsToMe !== mePointsToN) return false;
        }
    }
    
    // 3. If placing iron pipe, cluster open-ports check (connected iron pipes must have >= 2 open exits)
    if (isIron) {
        var oldCell = grid[r][c];
        grid[r][c] = { type: pieceType, isPermanent: true };
        
        var queue = [{r: r, c: c}];
        var visited = {};
        visited[r + "," + c] = true;
        var openPorts = 0;
        
        while (queue.length > 0) {
            var curr = queue.shift();
            var cType = grid[curr.r][curr.c].type;
            var cPorts = CONNECTIONS[cType] || [];
            
            for (var pi = 0; pi < cPorts.length; pi++) {
                var pDir = cPorts[pi];
                var cnr = curr.r + DELTAS[pDir].r;
                var cnc = curr.c + DELTAS[pDir].c;
                if (cnr < 0 || cnr >= ROWS || cnc < 0 || cnc >= COLS) continue;
                var cNeighbor = grid[cnr][cnc];
                if (cNeighbor.isPermanent && cNeighbor.type !== "valve" && cNeighbor.type !== "empty") {
                    var key = cnr + "," + cnc;
                    if (!visited[key]) {
                        visited[key] = true;
                        queue.push({r: cnr, c: cnc});
                    }
                } else if (cNeighbor.type === "empty") {
                    openPorts++;
                }
            }
        }
        
        grid[r][c] = oldCell;
        if (openPorts < 2) return false;
    }
    
    return true;
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
                isFlowing: false,
                isSecondPass: false,
                crossFillProgress: 0.0,
                crossEntryPort: "",
                crossExitPort: "",
                isPermanent: false
            });
        }
        grid.push(row);
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
        isFlowing: false,
        isPermanent: true
    };

    // Add boiler hazard blocks for higher levels (never at valve or valve exit cell)
    var hazardCount = Math.min(6, Math.max(0, level - 2));
    var placedHazards = 0;
    var hAttempts = 0;
    while (placedHazards < hazardCount && hAttempts < 200) {
        hAttempts++;
        var hr = Math.floor(Math.random() * (ROWS - 2)) + 1;
        var hc = Math.floor(Math.random() * (COLS - 4)) + 2;
        if (hr === valveRow && (hc === valveCol || hc === valveCol + 1)) continue;
        if (grid[hr][hc].type === "empty") {
            grid[hr][hc].type = "hazard";
            placedHazards++;
        }
    }

    // Pre-placed pipe pieces (6 to 12 total pieces on every level)
    // Starting in round 2, 1 is unchangeable cast iron, increasing by 1 every round (max 12 total)
    // Unchangeable pipes can link together but never make deadends into walls or other pipes!
    var totalPreplaced = 6 + Math.floor(Math.random() * 7); // Random 6 to 12
    var unmoveableCount = Math.min(totalPreplaced, Math.max(0, level - 1));
    
    // Phase 1: Place unmoveable cast iron pipes
    var ironPlaced = 0;
    var attempts = 0;
    while (ironPlaced < unmoveableCount && attempts < 1000) {
        attempts++;
        var pr = Math.floor(Math.random() * ROWS);
        var pc = Math.floor(Math.random() * COLS);
        var pType = getRandomPiece();
        if (isValidPreplacedPipe(grid, pr, pc, pType, true, valveRow, valveCol)) {
            grid[pr][pc] = {
                type: pType,
                filled: false,
                fillProgress: 0.0,
                entryPort: "",
                exitPort: "",
                crossPasses: 0,
                isFlowing: false,
                isSecondPass: false,
                crossFillProgress: 0.0,
                crossEntryPort: "",
                crossExitPort: "",
                isPermanent: true
            };
            ironPlaced++;
        }
    }
    
    // Phase 2: Place moveable copper pipes to reach totalPreplaced
    var copperPlaced = 0;
    var copperTarget = totalPreplaced - ironPlaced;
    attempts = 0;
    while (copperPlaced < copperTarget && attempts < 1000) {
        attempts++;
        var pr = Math.floor(Math.random() * ROWS);
        var pc = Math.floor(Math.random() * COLS);
        var pType = getRandomPiece();
        if (isValidPreplacedPipe(grid, pr, pc, pType, false, valveRow, valveCol)) {
            grid[pr][pc] = {
                type: pType,
                filled: false,
                fillProgress: 0.0,
                entryPort: "",
                exitPort: "",
                crossPasses: 0,
                isFlowing: false,
                isSecondPass: false,
                crossFillProgress: 0.0,
                crossEntryPort: "",
                crossExitPort: "",
                isPermanent: false
            };
            copperPlaced++;
        }
    }
    
    // Initial 5-piece queue (guarantee first piece connects to East-facing valve)
    var queue = [];
    var validFirstPieces = ["pipe_h", "corner_2", "corner_4", "cross", "reservoir"];
    queue.push(validFirstPieces[Math.floor(Math.random() * validFirstPieces.length)]);
    for (var q = 1; q < 5; q++) {
        queue.push(getRandomPiece());
    }
    
    var countdownDuration = Math.max(8.0, 18.0 - (level - 1) * 2.0);

    return {
        level: level,
        quota: quota,
        traversedCount: 0,
        pipesPlaced: 0,
        crossBonusCount: 0,
        elapsedTime: 0.0,
        floodProgress: 0.0,
        targetOutcome: "",
        score: 0,
        state: "countdown", // "countdown", "flowing", "flooding", "round_won", "game_over"
        countdown: countdownDuration,
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
    // Permanent/iron pipes, hazards, valves, and filled/flowing pipes cannot be replaced
    if (cell.type === "hazard" || cell.type === "valve" || cell.filled || cell.isFlowing || cell.isPermanent) {
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
    cell.isSecondPass = false;
    cell.crossFillProgress = 0.0;
    cell.crossEntryPort = "";
    cell.crossExitPort = "";
    game.pipesPlaced++;
    
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
        game.elapsedTime += dt;
        var baseDuration = Math.max(1.4, 3.8 - (game.level - 1) * 0.35);
        var currentCell = game.grid[game.currentR][game.currentC];
        
        if (currentCell.type === "reservoir") {
            baseDuration *= 2.6; // Reservoir serves as tactical pressure buffer
        }
        
        var stepDuration = game.isRushing ? 0.25 : baseDuration;
        var progressDelta = dt / stepDuration;
        
        game.fillProgress += progressDelta;
        if (currentCell.isSecondPass) {
            currentCell.crossFillProgress = Math.min(1.0, game.fillProgress);
        } else {
            currentCell.fillProgress = Math.min(1.0, game.fillProgress);
        }
        
        if (game.isRushing) {
            game.score += Math.round(dt * 60);
            game.targetPsi = 95.0 + Math.sin(Date.now() * 0.02) * 5.0;
        } else {
            game.targetPsi = 62.0 + Math.sin(Date.now() * 0.005) * 3.0;
        }
        
        if (game.fillProgress >= 1.0) {
            advanceFlow(game);
        }
        return;
    }

    // 3. FLOODING STAGE (Blowout water surge covers the grid)
    if (game.state === "flooding") {
        game.floodProgress = Math.min(1.0, game.floodProgress + dt / 1.4);
        if (game.floodProgress >= 1.0) {
            game.state = game.targetOutcome;
        }
        return;
    }
}

function advanceFlow(game) {
    var currCell = game.grid[game.currentR][game.currentC];
    if (currCell.isSecondPass) {
        currCell.crossFillProgress = 1.0;
        currCell.crossPasses = 2;
    } else {
        currCell.filled = true;
        currCell.isFlowing = false;
        currCell.fillProgress = 1.0;
        if (currCell.type === "cross") {
            currCell.crossPasses = 1;
        }
    }
    
    // Only player-placed pipes count towards the level quota (valve is the source spout)
    if (currCell.type !== "valve") {
        game.traversedCount++;
        game.score += 100;
    }
    
    // Cross pipe double traversal bonus
    if (currCell.type === "cross" && currCell.isSecondPass) {
        game.score += 500; // Big cross-loop bonus!
        game.crossBonusCount++;
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
    if (nextCell.type === "cross") {
        if (nextCell.crossPasses >= 2) {
            handleBlowout(game, nextR, nextC);
            return;
        }
        if (nextCell.crossPasses === 1 && (expectedEntry === nextCell.entryPort || expectedEntry === nextCell.exitPort)) {
            handleBlowout(game, nextR, nextC);
            return;
        }
    } else if (nextCell.filled) {
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
    
    if (nextCell.type === "cross" && (nextCell.filled || nextCell.fillProgress >= 1.0)) {
        nextCell.isSecondPass = true;
        nextCell.crossEntryPort = expectedEntry;
        nextCell.crossExitPort = nextExit;
        nextCell.crossFillProgress = 0.0;
        nextCell.isFlowing = true;
    } else {
        nextCell.isSecondPass = false;
        nextCell.entryPort = expectedEntry;
        nextCell.exitPort = nextExit;
        nextCell.fillProgress = 0.0;
        nextCell.isFlowing = true;
    }
}

function handleBlowout(game, leakR, leakC) {
    game.leakPos = { r: leakR, c: leakC };
    game.targetPsi = 0.0;
    game.isRushing = false;
    
    if (game.traversedCount >= game.quota) {
        game.targetOutcome = "round_won";
        var bonus = (game.traversedCount - game.quota) * 250 + game.level * 1000;
        game.score += bonus;
    } else {
        game.targetOutcome = "game_over";
    }
    game.state = "flooding";
    game.floodProgress = 0.0;
}
