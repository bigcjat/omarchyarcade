.pragma library

var LEVELS = [
  {
    "name": "First Step",
    "par": 30,
    "map": [
      "####",
      "# .#",
      "#  ###",
      "#*@  #",
      "#  $ #",
      "#  ###",
      "####"
    ]
  },
  {
    "name": "Double Corner",
    "par": 42,
    "map": [
      "######",
      "#    #",
      "# #@ #",
      "# $* #",
      "# .* #",
      "#    #",
      "######"
    ]
  },
  {
    "name": "The Nook",
    "par": 30,
    "map": [
      "  ####",
      "###  ####",
      "#     $ #",
      "# #  #$ #",
      "# . .#@ #",
      "#########"
    ]
  },
  {
    "name": "The Corridor",
    "par": 42,
    "map": [
      "########",
      "#      #",
      "# .**$@#",
      "#      #",
      "#####  #",
      "    ####"
    ]
  },
  {
    "name": "Crossroads",
    "par": 54,
    "map": [
      " #######",
      " #     #",
      " # .$. #",
      "## $@$ #",
      "#  .$. #",
      "#      #",
      "########"
    ]
  },
  {
    "name": "Turnabout",
    "par": 42,
    "map": [
      "###### #####",
      "#    ###   #",
      "# $$     #@#",
      "# $ #...   #",
      "#   ########",
      "#####"
    ]
  },
  {
    "name": "Six Pack",
    "par": 78,
    "map": [
      "#######",
      "#     #",
      "# .$. #",
      "# $.$ #",
      "# .$. #",
      "# $.$ #",
      "#  @  #",
      "#######"
    ]
  },
  {
    "name": "The Alley",
    "par": 30,
    "map": [
      "  ######",
      "  # ..@#",
      "  # $$ #",
      "  ## ###",
      "   # #",
      "   # #",
      "#### #",
      "#    ##",
      "# #   #",
      "#   # #",
      "###   #",
      "  #####"
    ]
  },
  {
    "name": "Tight Fit",
    "par": 30,
    "map": [
      "#####",
      "#.  ##",
      "#@$$ #",
      "##   #",
      " ##  #",
      "  ##.#",
      "   ###"
    ]
  },
  {
    "name": "Dual Chambers",
    "par": 42,
    "map": [
      "      #####",
      "      #.  #",
      "      #.# #",
      "#######.# #",
      "# @ $ $ $ #",
      "# # # # ###",
      "#       #",
      "#########"
    ]
  },
  {
    "name": "The Squeeze",
    "par": 30,
    "map": [
      "  ######",
      "  #    #",
      "  # ##@##",
      "### # $ #",
      "# ..# $ #",
      "#       #",
      "#  ######",
      "####"
    ]
  },
  {
    "name": "Twin Locks",
    "par": 30,
    "map": [
      "#####",
      "#   ##",
      "# $  #",
      "## $ ####",
      " ###@.  #",
      "  #  .# #",
      "  #     #",
      "  #######"
    ]
  },
  {
    "name": "Pillar Shift",
    "par": 42,
    "map": [
      "####",
      "#. ##",
      "#.@ #",
      "#. $#",
      "##$ ###",
      " # $  #",
      " #    #",
      " #  ###",
      " ####"
    ]
  },
  {
    "name": "The alcove",
    "par": 30,
    "map": [
      "#######",
      "#     #",
      "# # # #",
      "#. $*@#",
      "#   ###",
      "#####"
    ]
  },
  {
    "name": "Step Back",
    "par": 30,
    "map": [
      "     ###",
      "######@##",
      "#    .* #",
      "#   #   #",
      "#####$# #",
      "    #   #",
      "    #####"
    ]
  },
  {
    "name": "Roundabout",
    "par": 42,
    "map": [
      " ####",
      " #  ####",
      " #     ##",
      "## ##   #",
      "#. .# @$##",
      "#   # $$ #",
      "#  .#    #",
      "##########"
    ]
  },
  {
    "name": "Side Step",
    "par": 42,
    "map": [
      "#####",
      "# @ #",
      "#...#",
      "#$$$##",
      "#    #",
      "#    #",
      "######"
    ]
  },
  {
    "name": "The Bridge",
    "par": 30,
    "map": [
      "#######",
      "#     #",
      "#. .  #",
      "# ## ##",
      "#  $ #",
      "###$ #",
      "  #@ #",
      "  #  #",
      "  ####"
    ]
  },
  {
    "name": "Hook & Eye",
    "par": 30,
    "map": [
      "########",
      "#   .. #",
      "#  @$$ #",
      "##### ##",
      "   #  #",
      "   #  #",
      "   #  #",
      "   ####"
    ]
  },
  {
    "name": "Bifurcation",
    "par": 30,
    "map": [
      "#######",
      "#     ###",
      "#  @$$..#",
      "#### ## #",
      "  #     #",
      "  #  ####",
      "  #  #",
      "  ####"
    ]
  },
  {
    "name": "Switchback",
    "par": 30,
    "map": [
      "####",
      "#  ####",
      "# . . #",
      "# $$#@#",
      "##    #",
      " ######"
    ]
  },
  {
    "name": "The Pocket",
    "par": 30,
    "map": [
      "#####",
      "#   ###",
      "#. .  #",
      "#   # #",
      "## #  #",
      " #@$$ #",
      " #    #",
      " #  ###",
      " ####"
    ]
  },
  {
    "name": "Centerpiece",
    "par": 30,
    "map": [
      "#######",
      "#  *  #",
      "#     #",
      "## # ##",
      " #$@.#",
      " #   #",
      " #####"
    ]
  },
  {
    "name": "Narrow Gate",
    "par": 30,
    "map": [
      "# #####",
      "  #   #",
      "###$$@#",
      "#   ###",
      "#     #",
      "# . . #",
      "#######"
    ]
  },
  {
    "name": "The Loop",
    "par": 42,
    "map": [
      " ####",
      " #  ###",
      " # $$ #",
      "##... #",
      "#  @$ #",
      "#   ###",
      "#####"
    ]
  },
  {
    "name": "Square Off",
    "par": 42,
    "map": [
      " #####",
      " # @ #",
      " #   #",
      "###$ #",
      "# ...#",
      "# $$ #",
      "###  #",
      "  ####"
    ]
  },
  {
    "name": "Anchor Point",
    "par": 30,
    "map": [
      "######",
      "#   .#",
      "# ## ##",
      "#  $$@#",
      "# #   #",
      "#.  ###",
      "#####"
    ]
  },
  {
    "name": "Dead End",
    "par": 30,
    "map": [
      "#####",
      "#   #",
      "# @ #",
      "# $$###",
      "##. . #",
      " #    #",
      " ######"
    ]
  },
  {
    "name": "The Vault",
    "par": 30,
    "map": [
      "     #####",
      "     #   ##",
      "     #    #",
      " ######   #",
      "##     #. #",
      "# $ $ @  ##",
      "# ######.#",
      "#        #",
      "##########"
    ]
  },
  {
    "name": "Parallel Lines",
    "par": 42,
    "map": [
      "####",
      "#  ###",
      "# $$ #",
      "#... #",
      "# @$ #",
      "#   ##",
      "#####"
    ]
  },
  {
    "name": "The Funnel",
    "par": 42,
    "map": [
      "  ####",
      " ##  #",
      "##@$.##",
      "# $$  #",
      "# . . #",
      "###   #",
      "  #####"
    ]
  },
  {
    "name": "Keyhole",
    "par": 42,
    "map": [
      " ####",
      "##  ###",
      "#     #",
      "#.**$@#",
      "#   ###",
      "##  #",
      " ####"
    ]
  },
  {
    "name": "Split Chamber",
    "par": 42,
    "map": [
      "#######",
      "#. #  #",
      "#  $  #",
      "#. $#@#",
      "#  $  #",
      "#. #  #",
      "#######"
    ]
  },
  {
    "name": "Crossfire",
    "par": 54,
    "map": [
      "  ####",
      "###  ####",
      "#       #",
      "#@$***. #",
      "#       #",
      "#########"
    ]
  },
  {
    "name": "Corner Trap",
    "par": 66,
    "map": [
      "  ####",
      " ##  #",
      " #. $#",
      " #.$ #",
      " #.$ #",
      " #.$ #",
      " #. $##",
      " #   @#",
      " ##   #",
      "  #####"
    ]
  },
  {
    "name": "The Trench",
    "par": 66,
    "map": [
      "####",
      "#  ############",
      "# $ $ $ $ $ @ #",
      "# .....       #",
      "###############"
    ]
  },
  {
    "name": "Bypass",
    "par": 42,
    "map": [
      "      ###",
      "##### #.#",
      "#   ###.#",
      "#   $ #.#",
      "# $  $  #",
      "#####@# #",
      "    #   #",
      "    #####"
    ]
  },
  {
    "name": "The Maze",
    "par": 42,
    "map": [
      "##########",
      "#        #",
      "# ##.### #",
      "# # $$ . #",
      "# . @$## #",
      "#####    #",
      "    ######"
    ]
  },
  {
    "name": "Staging Area",
    "par": 30,
    "map": [
      "#####",
      "#   ####",
      "# # # .#",
      "#    $ ###",
      "### #$.  #",
      "#   #@   #",
      "# # ######",
      "#   #",
      "#####"
    ]
  },
  {
    "name": "Twin Peaks",
    "par": 42,
    "map": [
      " #####",
      " #   #",
      "##   ##",
      "# $$$ #",
      "# .+. #",
      "#######"
    ]
  },
  {
    "name": "The Shuttle",
    "par": 42,
    "map": [
      "#######",
      "#     #",
      "#@$$$ ##",
      "#  #...#",
      "##    ##",
      " ######"
    ]
  },
  {
    "name": "Depot Yard",
    "par": 42,
    "map": [
      "   ####",
      "   #  #",
      "   #@ #",
      "####$.#",
      "#   $.#",
      "# # $.#",
      "#    ##",
      "######"
    ]
  },
  {
    "name": "Perilous Turn",
    "par": 42,
    "map": [
      "     ####",
      "     # @#",
      "     #  #",
      "###### .#",
      "#   $  .#",
      "#  $$# .#",
      "#    ####",
      "###  #",
      "  ####"
    ]
  },
  {
    "name": "The Depot",
    "par": 18,
    "map": [
      "#####",
      "#@$.#",
      "#####"
    ]
  },
  {
    "name": "Crossover",
    "par": 42,
    "map": [
      "######",
      "#... #",
      "#  $ #",
      "# #$##",
      "#  $ #",
      "#  @ #",
      "######"
    ]
  },
  {
    "name": "Four Corners",
    "par": 30,
    "map": [
      " ######",
      "##    #",
      "#  ## #",
      "# # $ #",
      "#  * .#",
      "## #@##",
      " #   #",
      " #####"
    ]
  },
  {
    "name": "The Lattice",
    "par": 30,
    "map": [
      "  #######",
      "###     #",
      "# $ $   #",
      "# ### #####",
      "# @ . .   #",
      "#   ###   #",
      "##### #####"
    ]
  },
  {
    "name": "The Citadel",
    "par": 42,
    "map": [
      "######",
      "#  @ #",
      "#  # ##",
      "# .#  ##",
      "# .$$$ #",
      "# .#   #",
      "####   #",
      "   #####"
    ]
  },
  {
    "name": "Grand Junction",
    "par": 42,
    "map": [
      "######",
      "# @  #",
      "# $# #",
      "# $  #",
      "# $ ##",
      "### ####",
      " #  #  #",
      " #...  #",
      " #     #",
      " #######"
    ]
  },
  {
    "name": "Master Chamber",
    "par": 30,
    "map": [
      "  ####",
      "###  #####",
      "#  $  @..#",
      "# $    # #",
      "### #### #",
      "  #      #",
      "  ########"
    ]
  }
];

var currentLevelIndex = 0;
var rows = 0;
var cols = 0;
var walls = [];
var goals = [];
var crates = [];
var crateIdCounter = 1;

var player = {
    x: 0,
    y: 0,
    drawX: 0,
    drawY: 0,
    facing: "down",
    isMoving: false,
    isPushing: false,
    moveTimer: 0,
    walkCycle: 0
};

var particles = [];
var history = [];
var moves = 0;
var pushes = 0;
var gameState = "playing";
var winTimer = 0;
var MOVE_DURATION = 0.12;

var soundCallback = null;
function setSoundCallback(cb) {
    soundCallback = cb;
}
function playSnd(name) {
    if (soundCallback) soundCallback(name);
}

function init() {
    loadLevel(currentLevelIndex);
}

function loadLevel(idx) {
    if (idx < 0) idx = 0;
    if (idx >= LEVELS.length) idx = LEVELS.length - 1;
    currentLevelIndex = idx;

    var lvl = LEVELS[idx];
    var raw = lvl.map;
    rows = raw.length;
    cols = 0;
    for (var r = 0; r < rows; r++) {
        if (raw[r].length > cols) cols = raw[r].length;
    }

    walls = [];
    goals = [];
    crates = [];
    crateIdCounter = 1;
    particles = [];
    history = [];
    moves = 0;
    pushes = 0;
    gameState = "playing";
    winTimer = 0;

    for (var y = 0; y < rows; y++) {
        walls[y] = [];
        var line = raw[y];
        for (var x = 0; x < cols; x++) {
            walls[y][x] = false;
            var ch = (x < line.length) ? line[x] : ' ';

            if (ch === '#') {
                walls[y][x] = true;
            } else if (ch === '.') {
                goals.push({ x: x, y: y });
            } else if (ch === '$') {
                crates.push({
                    id: crateIdCounter++,
                    x: x,
                    y: y,
                    drawX: x,
                    drawY: y,
                    isMoving: false,
                    onGoal: false
                });
            } else if (ch === '*') {
                goals.push({ x: x, y: y });
                crates.push({
                    id: crateIdCounter++,
                    x: x,
                    y: y,
                    drawX: x,
                    drawY: y,
                    isMoving: false,
                    onGoal: true
                });
            } else if (ch === '@') {
                player.x = x;
                player.y = y;
                player.drawX = x;
                player.drawY = y;
            } else if (ch === '+') {
                goals.push({ x: x, y: y });
                player.x = x;
                player.y = y;
                player.drawX = x;
                player.drawY = y;
            }
        }
    }

    player.facing = "down";
    player.isMoving = false;
    player.isPushing = false;
    player.moveTimer = 0;
    player.walkCycle = 0;

    updateCrateGoalStatus();
}

function updateCrateGoalStatus() {
    for (var i = 0; i < crates.length; i++) {
        var c = crates[i];
        c.onGoal = isGoalAt(c.x, c.y);
    }
}

function isGoalAt(x, y) {
    for (var i = 0; i < goals.length; i++) {
        if (goals[i].x === x && goals[i].y === y) return true;
    }
    return false;
}

function getCrateAt(x, y) {
    for (var i = 0; i < crates.length; i++) {
        if (crates[i].x === x && crates[i].y === y) return crates[i];
    }
    return null;
}

function isWallAt(x, y) {
    if (y < 0 || y >= rows || x < 0 || x >= cols) return true;
    return walls[y][x] === true;
}

function move(dx, dy) {
    if (gameState !== "playing") return false;

    if (dx === 1) player.facing = "right";
    else if (dx === -1) player.facing = "left";
    else if (dy === 1) player.facing = "down";
    else if (dy === -1) player.facing = "up";

    var targetX = player.x + dx;
    var targetY = player.y + dy;

    if (isWallAt(targetX, targetY)) {
        return false;
    }

    var pushedCrate = getCrateAt(targetX, targetY);

    if (pushedCrate) {
        var crateTargetX = targetX + dx;
        var crateTargetY = targetY + dy;

        if (isWallAt(crateTargetX, crateTargetY) || getCrateAt(crateTargetX, crateTargetY) !== null) {
            return false;
        }

        saveSnapshot();

        pushedCrate.startX = pushedCrate.x;
        pushedCrate.startY = pushedCrate.y;
        pushedCrate.x = crateTargetX;
        pushedCrate.y = crateTargetY;
        pushedCrate.isMoving = true;
        pushedCrate.moveTimer = MOVE_DURATION;

        player.startX = player.x;
        player.startY = player.y;
        player.x = targetX;
        player.y = targetY;
        player.isMoving = true;
        player.isPushing = true;
        player.moveTimer = MOVE_DURATION;

        moves++;
        pushes++;

        var willDock = isGoalAt(crateTargetX, crateTargetY);
        playSnd(willDock ? "dock" : "push");
        spawnPushDust(pushedCrate.startX, pushedCrate.startY, dx, dy);

        checkWinCondition();
        return true;
    }

    saveSnapshot();

    player.startX = player.x;
    player.startY = player.y;
    player.x = targetX;
    player.y = targetY;
    player.isMoving = true;
    player.isPushing = false;
    player.moveTimer = MOVE_DURATION;

    moves++;
    playSnd("step");
    return true;
}

function saveSnapshot() {
    var crateStates = [];
    for (var i = 0; i < crates.length; i++) {
        crateStates.push({
            id: crates[i].id,
            x: crates[i].x,
            y: crates[i].y
        });
    }

    history.push({
        playerX: player.x,
        playerY: player.y,
        playerFacing: player.facing,
        crates: crateStates,
        moves: moves,
        pushes: pushes
    });
}

function undo() {
    if (gameState === "won") return false;
    if (history.length === 0) return false;

    var snap = history.pop();

    player.startX = player.x;
    player.startY = player.y;
    player.x = snap.playerX;
    player.y = snap.playerY;
    player.facing = snap.playerFacing;
    player.isMoving = true;
    player.isPushing = false;
    player.moveTimer = MOVE_DURATION * 0.7;

    for (var i = 0; i < snap.crates.length; i++) {
        var savedC = snap.crates[i];
        for (var j = 0; j < crates.length; j++) {
            if (crates[j].id === savedC.id) {
                if (crates[j].x !== savedC.x || crates[j].y !== savedC.y) {
                    crates[j].startX = crates[j].x;
                    crates[j].startY = crates[j].y;
                    crates[j].x = savedC.x;
                    crates[j].y = savedC.y;
                    crates[j].isMoving = true;
                    crates[j].moveTimer = MOVE_DURATION * 0.7;
                }
                break;
            }
        }
    }

    moves = snap.moves;
    pushes = snap.pushes;
    updateCrateGoalStatus();
    playSnd("undo");
    return true;
}

function checkWinCondition() {
    updateCrateGoalStatus();
    for (var i = 0; i < crates.length; i++) {
        if (!crates[i].onGoal) return false;
    }

    gameState = "won";
    winTimer = 0;
    playSnd("win");
    return true;
}

function update(dt) {
    dt = Math.min(dt, 0.05);

    if (player.isMoving) {
        player.moveTimer -= dt;
        player.walkCycle += dt * 18;
        if (player.moveTimer <= 0) {
            player.isMoving = false;
            player.isPushing = false;
            player.drawX = player.x;
            player.drawY = player.y;
        } else {
            var t = 1.0 - (player.moveTimer / MOVE_DURATION);
            player.drawX = player.startX + (player.x - player.startX) * t;
            player.drawY = player.startY + (player.y - player.startY) * t;
        }
    } else {
        player.drawX = player.x;
        player.drawY = player.y;
    }

    for (var i = 0; i < crates.length; i++) {
        var c = crates[i];
        if (c.isMoving) {
            c.moveTimer -= dt;
            if (c.moveTimer <= 0) {
                c.isMoving = false;
                c.drawX = c.x;
                c.drawY = c.y;
                c.onGoal = isGoalAt(c.x, c.y);
            } else {
                var ct = 1.0 - (c.moveTimer / MOVE_DURATION);
                c.drawX = c.startX + (c.x - c.startX) * ct;
                c.drawY = c.startY + (c.y - c.startY) * ct;
            }
        } else {
            c.drawX = c.x;
            c.drawY = c.y;
        }
    }

    for (var p = particles.length - 1; p >= 0; p--) {
        var pt = particles[p];
        pt.x += pt.vx * dt;
        pt.y += pt.vy * dt;
        pt.life -= dt;
        if (pt.life <= 0) {
            particles.splice(p, 1);
        }
    }

    if (gameState === "won") {
        winTimer += dt;
    }
}

function spawnPushDust(gridX, gridY, dx, dy) {
    for (var i = 0; i < 6; i++) {
        particles.push({
            x: gridX + 0.5 + (Math.random() - 0.5) * 0.4,
            y: gridY + 0.5 + (Math.random() - 0.5) * 0.4,
            vx: -dx * (1.2 + Math.random() * 1.5) + (Math.random() - 0.5) * 0.8,
            vy: -dy * (1.2 + Math.random() * 1.5) + (Math.random() - 0.5) * 0.8,
            size: 2.0 + Math.random() * 2.5,
            color: "#a6adc8",
            life: 0.28,
            maxLife: 0.28
        });
    }
}

function getParMoves() {
    return LEVELS[currentLevelIndex].par || 30;
}

function getStarRating(currentMoves) {
    var par = getParMoves();
    if (currentMoves <= par) return 3;
    if (currentMoves <= Math.floor(par * 1.35)) return 2;
    return 1;
}

function nextLevel() {
    if (currentLevelIndex < LEVELS.length - 1) {
        loadLevel(currentLevelIndex + 1);
        return true;
    }
    return false;
}

function prevLevel() {
    if (currentLevelIndex > 0) {
        loadLevel(currentLevelIndex - 1);
        return true;
    }
    return false;
}
