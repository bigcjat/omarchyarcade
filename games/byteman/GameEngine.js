.pragma library

var COLS = 28;
var ROWS = 31;

var MAZE_TEMPLATE = [
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    "W............WW............W",
    "W.WWWW.WWWWW.WW.WWWWW.WWWW.W",
    "W*WWWW.WWWWW.WW.WWWWW.WWWW*W",
    "W.WWWW.WWWWW.WW.WWWWW.WWWW.W",
    "W..........................W",
    "W.WWWW.WW.WWWWWWWW.WW.WWWW.W",
    "W.WWWW.WW.WWWWWWWW.WW.WWWW.W",
    "W......WW....WW....WW......W",
    "WWWWWW.WWWWW WW WWWWW.WWWWWW",
    "     W.WWWWW WW WWWWW.W     ",
    "     W.WW          WW.W     ",
    "     W.WW WWWGGWWW WW.W     ",
    "WWWWWW.WW W      W WW.WWWWWW",
    "T     .   W HHHH W   .     T",
    "WWWWWW.WW W HHHH W WW.WWWWWW",
    "     W.WW WWWWWWWW WW.W     ",
    "     W.WW          WW.W     ",
    "     W.WW WWWWWWWW WW.W     ",
    "WWWWWW.WW WWWWWWWW WW.WWWWWW",
    "W............WW............W",
    "W.WWWW.WWWWW.WW.WWWWW.WWWW.W",
    "W.WWWW.WWWWW.WW.WWWWW.WWWW.W",
    "W*..WW................WW..*W",
    "WWW.WW.WW.WWWWWWWW.WW.WW.WWW",
    "WWW.WW.WW.WWWWWWWW.WW.WW.WWW",
    "W......WW....WW....WW......W",
    "W.WWWWWWWWWW.WW.WWWWWWWWWW.W",
    "W.WWWWWWWWWW.WW.WWWWWWWWWW.W",
    "W..........................W",
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWW"
];

var DIR = { NONE: 0, UP: 1, DOWN: 2, LEFT: 3, RIGHT: 4 };

var maze = [];
var totalPellets = 0;
var pelletsRemaining = 0;
var score = 0;
var highScore = 0;
var lives = 3;
var level = 1;
var gameState = "ready"; // "ready", "playing", "dying", "gameover", "cleared"

var player = null;
var ghosts = [];
var globalTimer = 0;
var frightenedTimer = 0;
var ghostsEatenCount = 0;
var pelletsEaten = 0;
var fruit = null;
var fruitTimer = 0;
var deathTimer = 0;
var clearTimer = 0;
var chompStep = false;

var FRUITS = [
    { name: "Cherry",     symbol: "🍒", points: 100,  color: "#FF2244" },
    { name: "Strawberry", symbol: "🍓", points: 300,  color: "#FF3366" },
    { name: "Peach",      symbol: "🍑", points: 500,  color: "#FFAA44" },
    { name: "Apple",      symbol: "🍎", points: 700,  color: "#EE2222" },
    { name: "Melon",      symbol: "🍈", points: 1000, color: "#88DD44" },
    { name: "Galaxian",   symbol: "🛸", points: 2000, color: "#FFDD22" },
    { name: "Bell",       symbol: "🔔", points: 3000, color: "#FFDD00" },
    { name: "Key",        symbol: "🔑", points: 5000, color: "#44DDFF" }
];

function getFruitForLevel(lvl) {
    if (lvl === 1) return FRUITS[0];
    if (lvl === 2) return FRUITS[1];
    if (lvl <= 4) return FRUITS[2];
    if (lvl <= 6) return FRUITS[3];
    if (lvl <= 8) return FRUITS[4];
    if (lvl <= 10) return FRUITS[5];
    if (lvl <= 12) return FRUITS[6];
    return FRUITS[7];
}

function init(w, h) {
    resetGame();
}

function resetGame() {
    score = 0;
    lives = 3;
    level = 1;
    gameState = "ready";
    loadMaze();
    resetPositions();
}

function loadMaze() {
    maze = [];
    totalPellets = 0;
    for (var r = 0; r < ROWS; r++) {
        var row = [];
        var templateRow = MAZE_TEMPLATE[r];
        for (var c = 0; c < COLS; c++) {
            var ch = templateRow.charAt(c);
            row.push(ch);
            if (ch === '.' || ch === '*') {
                totalPellets++;
            }
        }
        maze.push(row);
    }
    pelletsRemaining = totalPellets;
    pelletsEaten = 0;
    fruit = null;
    fruitTimer = 0;
}

function resetPositions() {
    player = {
        tileX: 13.5,
        tileY: 23,
        x: 13.5,
        y: 23,
        dir: DIR.NONE,
        nextDir: DIR.NONE,
        speed: 0.12,
        chomp: 0.2,
        chompDir: 1,
        moving: false
    };

    ghosts = [
        { id: "red",    name: "Aka",    color: "#FF3333", x: 13.5, y: 11, dir: DIR.LEFT, state: "chase", targetX: 0, targetY: 0, speed: 0.10, homeX: 25, homeY: 0, inHouse: false },
        { id: "pink",   name: "Momo",   color: "#FFB8DE", x: 13.5, y: 14, dir: DIR.UP,   state: "house", targetX: 0, targetY: 0, speed: 0.09, homeX: 2,  homeY: 0, inHouse: true, exitTimer: 60 },
        { id: "cyan",   name: "Mizu",   color: "#00FFFF", x: 11.5, y: 14, dir: DIR.UP,   state: "house", targetX: 0, targetY: 0, speed: 0.09, homeX: 27, homeY: 30, inHouse: true, exitTimer: 180 },
        { id: "orange", name: "Daidai", color: "#FFB847", x: 15.5, y: 14, dir: DIR.UP,   state: "house", targetX: 0, targetY: 0, speed: 0.09, homeX: 0,  homeY: 30, inHouse: true, exitTimer: 300 }
    ];

    frightenedTimer = 0;
    ghostsEatenCount = 0;
    fruit = null;
    fruitTimer = 0;
}

function startLevel() {
    gameState = "playing";
    player.dir = DIR.LEFT;
    player.nextDir = DIR.LEFT;
}

function setNextDirection(d) {
    if (gameState === "ready") {
        gameState = "playing";
    }
    if (player) {
        player.nextDir = d;
        if (canMove(player.tileX, player.tileY, d, false)) {
            player.dir = d;
        }
    }
}

function isWall(r, c) {
    if (r < 0 || r >= ROWS || c < 0 || c >= COLS) return true;
    var ch = maze[r][c];
    return ch === 'W';
}

function canMove(tx, ty, d, isGhost, isEyes) {
    var rx = Math.round(tx);
    var ry = Math.round(ty);
    var dx = 0, dy = 0;
    if (d === DIR.UP) dy = -1;
    else if (d === DIR.DOWN) dy = 1;
    else if (d === DIR.LEFT) dx = -1;
    else if (d === DIR.RIGHT) dx = 1;

    var targetC = rx + dx;
    var targetR = ry + dy;

    // Tunnel wraparound
    if ((targetC < 0 || targetC >= COLS) && ry === 14) {
        return true;
    }

    if (targetR < 0 || targetR >= ROWS || targetC < 0 || targetC >= COLS) return false;

    var cell = maze[targetR][targetC];
    if (cell === 'W') return false;
    if (cell === 'G' || cell === 'H') {
        // Ghost door and house interior strictly impassable for living ghosts and player
        return isEyes === true;
    }
    return true;
}

function update(callbacks) {
    if (gameState === "dying") {
        deathTimer++;
        if (deathTimer > 75) {
            lives--;
            if (callbacks && callbacks.onLivesChanged) callbacks.onLivesChanged(lives);
            if (lives <= 0) {
                gameState = "gameover";
                if (callbacks && callbacks.onGameOver) callbacks.onGameOver(score);
                if (callbacks && callbacks.onSound) callbacks.onSound("game_over");
            } else {
                resetPositions();
                gameState = "playing";
            }
        }
        return;
    }

    if (gameState === "cleared") {
        clearTimer++;
        if (clearTimer > 100) {
            level++;
            loadMaze();
            resetPositions();
            gameState = "playing";
            if (callbacks && callbacks.onLevelChanged) callbacks.onLevelChanged(level);
        }
        return;
    }

    if (gameState !== "playing") return;

    globalTimer++;

    // Frightened ghost countdown
    if (frightenedTimer > 0) {
        frightenedTimer--;
        if (frightenedTimer === 0) {
            for (var fg = 0; fg < ghosts.length; fg++) {
                if (ghosts[fg].state === "frightened") {
                    ghosts[fg].state = "chase";
                }
            }
        }
    }

    // ByteMan chomp animation
    player.chomp += 0.05 * player.chompDir;
    if (player.chomp > 0.35) {
        player.chomp = 0.35;
        player.chompDir = -1;
    } else if (player.chomp < 0.02) {
        player.chomp = 0.02;
        player.chompDir = 1;
    }

    // Try applying pre-buffered next direction
    if (player.nextDir !== player.dir) {
        var onX = Math.abs(player.x - Math.round(player.x)) < 0.18;
        var onY = Math.abs(player.y - Math.round(player.y)) < 0.18;
        var rx = Math.round(player.x);
        var ry = Math.round(player.y);

        if ((player.nextDir === DIR.LEFT || player.nextDir === DIR.RIGHT) && onY) {
            if (canMove(rx, ry, player.nextDir, false, false)) {
                player.dir = player.nextDir;
                player.y = ry;
            }
        } else if ((player.nextDir === DIR.UP || player.nextDir === DIR.DOWN) && onX) {
            if (canMove(rx, ry, player.nextDir, false, false)) {
                player.dir = player.nextDir;
                player.x = rx;
            }
        }
    }

    // Move ByteMan
    if (player.dir !== DIR.NONE) {
        var rx = Math.round(player.x);
        var ry = Math.round(player.y);
        var curCanMove = canMove(rx, ry, player.dir, false, false);

        var movingForward = true;
        if (player.dir === DIR.LEFT) {
            if (player.x - player.speed < rx && !curCanMove) {
                player.x = rx;
                movingForward = false;
            } else {
                player.x -= player.speed;
            }
        } else if (player.dir === DIR.RIGHT) {
            if (player.x + player.speed > rx && !curCanMove) {
                player.x = rx;
                movingForward = false;
            } else {
                player.x += player.speed;
            }
        } else if (player.dir === DIR.UP) {
            if (player.y - player.speed < ry && !curCanMove) {
                player.y = ry;
                movingForward = false;
            } else {
                player.y -= player.speed;
            }
        } else if (player.dir === DIR.DOWN) {
            if (player.y + player.speed > ry && !curCanMove) {
                player.y = ry;
                movingForward = false;
            } else {
                player.y += player.speed;
            }
        }
        player.moving = movingForward;

        // Tunnel wraparound
        if (player.x < -0.5) player.x = COLS - 0.5;
        if (player.x > COLS - 0.5) player.x = -0.5;

        player.tileX = Math.round(player.x);
        player.tileY = Math.round(player.y);

        // Eat pellets / energizers
        if (player.tileY >= 0 && player.tileY < ROWS && player.tileX >= 0 && player.tileX < COLS) {
            var item = maze[player.tileY][player.tileX];
            var ateDot = false;
            if (item === '.') {
                maze[player.tileY][player.tileX] = ' ';
                score += 10;
                pelletsRemaining--;
                chompStep = !chompStep;
                ateDot = true;
                if (callbacks && callbacks.onSound) callbacks.onSound("step");
                if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            } else if (item === '*') {
                maze[player.tileY][player.tileX] = ' ';
                score += 50;
                pelletsRemaining--;
                frightenedTimer = 480; // 8 seconds at 60 FPS
                ghostsEatenCount = 0;
                ateDot = true;
                for (var g = 0; g < ghosts.length; g++) {
                    if (ghosts[g].state !== "eyes" && !ghosts[g].inHouse) {
                        ghosts[g].state = "frightened";
                        // reverse direction
                        ghosts[g].dir = getOppositeDir(ghosts[g].dir);
                    }
                }
                if (callbacks && callbacks.onSound) callbacks.onSound("target");
                if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
            }

            if (ateDot) {
                pelletsEaten++;
                // Official arcade fruit spawns twice per level: at 70 and 170 pellets
                if ((pelletsEaten === 70 || pelletsEaten === 170) && fruit === null) {
                    var fInfo = getFruitForLevel(level);
                    fruit = {
                        name: fInfo.name,
                        symbol: fInfo.symbol,
                        points: fInfo.points,
                        color: fInfo.color,
                        x: 13.5,
                        y: 17
                    };
                    fruitTimer = 580; // ~9.6 seconds at 60 FPS
                }
            }

            // Check stage clear
            if (pelletsRemaining <= 0) {
                gameState = "cleared";
                clearTimer = 0;
                fruit = null;
                fruitTimer = 0;
                if (callbacks && callbacks.onSound) callbacks.onSound("win");
                return;
            }
        }
    }

    // Update active fruit
    if (fruit) {
        fruitTimer--;
        if (fruitTimer <= 0) {
            fruit = null;
        } else {
            var dFruit = Math.hypot(player.x - fruit.x, player.y - fruit.y);
            if (dFruit < 0.65) {
                var fPts = fruit.points;
                var fName = fruit.name;
                score += fPts;
                fruit = null;
                fruitTimer = 0;
                if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
                if (callbacks && callbacks.onFruitEaten) callbacks.onFruitEaten(fName, fPts);
                if (callbacks && callbacks.onSound) callbacks.onSound("win");
            }
        }
    }

    // Update ghosts
    for (var i = 0; i < ghosts.length; i++) {
        updateGhost(ghosts[i], callbacks);
    }

    // Check collision between ByteMan and ghosts
    for (var j = 0; j < ghosts.length; j++) {
        var gh = ghosts[j];
        var dist = Math.hypot(gh.x - player.x, gh.y - player.y);
        if (dist < 0.65) {
            if (gh.state === "frightened") {
                // ByteMan eats ghost!
                gh.state = "eyes";
                ghostsEatenCount++;
                var ghostScore = Math.pow(2, ghostsEatenCount) * 100; // 200, 400, 800, 1600
                score += ghostScore;
                if (callbacks && callbacks.onScoreChanged) callbacks.onScoreChanged(score);
                if (callbacks && callbacks.onSound) callbacks.onSound("push");
            } else if (gh.state !== "eyes") {
                // ByteMan dies
                gameState = "dying";
                deathTimer = 0;
                if (callbacks && callbacks.onSound) callbacks.onSound("game_over");
                return;
            }
        }
    }
}

function getOppositeDir(d) {
    if (d === DIR.UP) return DIR.DOWN;
    if (d === DIR.DOWN) return DIR.UP;
    if (d === DIR.LEFT) return DIR.RIGHT;
    if (d === DIR.RIGHT) return DIR.LEFT;
    return DIR.NONE;
}

function updateGhost(g, callbacks) {
    // Exit timer for house
    if (g.inHouse) {
        if (g.exitTimer > 0) {
            g.exitTimer--;
            // gentle vertical bobbing in pen around base y=14
            g.y = 14 + Math.sin(globalTimer * 0.15) * 0.25;
            return;
        } else {
            // Move toward center door column 13.5
            if (Math.abs(g.x - 13.5) > 0.08) {
                g.x += (g.x < 13.5 ? 0.08 : -0.08);
            } else {
                g.x = 13.5;
                // Move straight up through the door (row 12) into corridor (row 11)
                if (g.y > 11.0) {
                    g.y -= 0.08;
                } else {
                    g.y = 11.0;
                    g.inHouse = false;
                    g.state = "chase";
                    g.dir = (g.id === "cyan" || g.id === "orange") ? DIR.RIGHT : DIR.LEFT;
                }
            }
            return;
        }
    }

    var speed = (g.state === "frightened") ? 0.06 : ((g.state === "eyes") ? 0.20 : g.speed);

    // Determine target coordinate based on AI personality
    var tx = player.x, ty = player.y;
    if (g.state === "eyes") {
        tx = 13.5;
        ty = 11;
        // Check if eyes returned to ghost door
        if (Math.hypot(g.x - 13.5, g.y - 11) < 0.4) {
            g.inHouse = true;
            g.state = "house";
            g.exitTimer = 40;
            g.y = 14;
            return;
        }
    } else if (g.state === "frightened") {
        // Pseudo-random wander target
        tx = (globalTimer * 17) % COLS;
        ty = (globalTimer * 23) % ROWS;
    } else {
        // Global scatter / chase mode cycle (7s scatter, 20s chase)
        var cycle = Math.floor(globalTimer / 60) % 27;
        var isScatter = cycle < 7;
        if (isScatter) {
            tx = g.homeX;
            ty = g.homeY;
        } else {
            if (g.id === "red") {
                tx = player.x;
                ty = player.y;
            } else if (g.id === "pink") {
                var pdx = 0, pdy = 0;
                if (player.dir === DIR.UP) pdy = -4;
                else if (player.dir === DIR.DOWN) pdy = 4;
                else if (player.dir === DIR.LEFT) pdx = -4;
                else if (player.dir === DIR.RIGHT) pdx = 4;
                tx = player.x + pdx;
                ty = player.y + pdy;
            } else if (g.id === "cyan") {
                // Vector mirror targeting: pivot is 2 tiles ahead of ByteMan, doubled from Red
                var b = ghosts[0];
                var pAheadX = 0, pAheadY = 0;
                if (player.dir === DIR.UP) pAheadY = -2;
                else if (player.dir === DIR.DOWN) pAheadY = 2;
                else if (player.dir === DIR.LEFT) pAheadX = -2;
                else if (player.dir === DIR.RIGHT) pAheadX = 2;
                var pivotX = player.x + pAheadX;
                var pivotY = player.y + pAheadY;
                tx = pivotX + (pivotX - b.x);
                ty = pivotY + (pivotY - b.y);
            } else if (g.id === "orange") {
                var dToP = Math.hypot(g.x - player.x, g.y - player.y);
                if (dToP > 8) {
                    tx = player.x;
                    ty = player.y;
                } else {
                    tx = g.homeX;
                    ty = g.homeY;
                }
            }
        }
    }

    var prevX = g.x;
    var prevY = g.y;
    var nextX = prevX;
    var nextY = prevY;

    if (g.dir === DIR.LEFT) nextX -= speed;
    else if (g.dir === DIR.RIGHT) nextX += speed;
    else if (g.dir === DIR.UP) nextY -= speed;
    else if (g.dir === DIR.DOWN) nextY += speed;

    var crossed = false;
    var targetTileX = Math.round(nextX);
    var targetTileY = Math.round(nextY);

    if (g.dir === DIR.LEFT && prevX > targetTileX && nextX <= targetTileX) crossed = true;
    else if (g.dir === DIR.RIGHT && prevX < targetTileX && nextX >= targetTileX) crossed = true;
    else if (g.dir === DIR.UP && prevY > targetTileY && nextY <= targetTileY) crossed = true;
    else if (g.dir === DIR.DOWN && prevY < targetTileY && nextY >= targetTileY) crossed = true;

    if (crossed) {
        var remDist = 0;
        if (g.dir === DIR.LEFT || g.dir === DIR.RIGHT) {
            remDist = Math.abs(nextX - targetTileX);
            g.x = targetTileX;
        } else {
            remDist = Math.abs(nextY - targetTileY);
            g.y = targetTileY;
        }

        var gx = targetTileX;
        var gy = targetTileY;

        var opposite = getOppositeDir(g.dir);
        var possibleDirs = [DIR.UP, DIR.LEFT, DIR.DOWN, DIR.RIGHT];
        var validDirs = [];

        for (var d = 0; d < possibleDirs.length; d++) {
            var dirChoice = possibleDirs[d];
            if (dirChoice !== opposite) {
                if (canMove(gx, gy, dirChoice, true, g.state === "eyes")) {
                    validDirs.push(dirChoice);
                }
            }
        }

        if (validDirs.length === 0) {
            validDirs.push(opposite);
        }

        var bestDir = validDirs[0];
        var bestDist = 999999;
        for (var v = 0; v < validDirs.length; v++) {
            var vd = validDirs[v];
            var nextGx = gx + (vd === DIR.LEFT ? -1 : (vd === DIR.RIGHT ? 1 : 0));
            var nextGy = gy + (vd === DIR.UP ? -1 : (vd === DIR.DOWN ? 1 : 0));
            var distToTarget = Math.hypot(nextGx - tx, nextGy - ty);
            if (distToTarget < bestDist) {
                bestDist = distToTarget;
                bestDir = vd;
            }
        }
        g.dir = bestDir;

        if (g.dir === DIR.LEFT) g.x -= remDist;
        else if (g.dir === DIR.RIGHT) g.x += remDist;
        else if (g.dir === DIR.UP) g.y -= remDist;
        else if (g.dir === DIR.DOWN) g.y += remDist;
    } else {
        g.x = nextX;
        g.y = nextY;
    }

    // Wraparound tunnel
    if (g.x < -0.5) g.x = COLS - 0.5;
    if (g.x > COLS - 0.5) g.x = -0.5;
}
