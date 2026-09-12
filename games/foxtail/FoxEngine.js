// FoxEngine.js - Game logic and physics for Foxtail
.pragma library
.import "Levels.js" as Levels

var currentLevelIndex = 1;
var levelData = null;
var width = 4;
var height = 4;
var grid = []; // 0: empty, 1: obstacle, 2: tail
var path = []; // [{x, y}, ...] - path[0] is start/tail-tip, path[last] is head
var history = []; // [{cells: [{x, y}, ...], facing: "right"}]
var totalPassable = 0;
var movesCount = 0;
var isWon = false;
var facing = "right";
var startPos = {x: 0, y: 0};

// Initialize or reload level
function initLevel(levelIndex) {
    currentLevelIndex = levelIndex;
    levelData = Levels.getLevel(levelIndex);
    width = levelData.width;
    height = levelData.height;
    
    grid = [];
    path = [];
    history = [];
    movesCount = 0;
    isWon = false;
    totalPassable = 0;
    
    var foundStart = false;
    
    for (var y = 0; y < height; y++) {
        var rowStr = levelData.grid[y];
        var row = [];
        for (var x = 0; x < width; x++) {
            var char = (x < rowStr.length) ? rowStr.charAt(x) : '.';
            if (char === '#') {
                row.push(1); // Tree stump obstacle inside trench
            } else if (char === 'X' || char === ' ') {
                row.push(3); // Void / ground outside trench
            } else if (char === 'S') {
                row.push(2); // Start tile / occupied
                startPos = {x: x, y: y};
                path.push({x: x, y: y});
                totalPassable++;
                foundStart = true;
            } else {
                row.push(0); // Empty passable floor
                totalPassable++;
            }
        }
        grid.push(row);
    }
    
    if (!foundStart) {
        startPos = {x: 0, y: 0};
        grid[0][0] = 2;
        path.push({x: 0, y: 0});
        totalPassable++;
    }
    
    // Choose sensible initial facing
    facing = determineInitialFacing();
    
    return getGameState();
}

function determineInitialFacing() {
    var lvl = Levels.getLevel(currentLevelIndex);
    if (lvl && lvl.solution && lvl.solution.length > 0) {
        var first = lvl.solution[0];
        if (first === "R") return "right";
        if (first === "L") return "left";
        if (first === "U") return "up";
        if (first === "D") return "down";
    }
    var x = startPos.x;
    var y = startPos.y;
    if (x + 1 < width && grid[y][x + 1] === 0) return "right";
    if (y + 1 < height && grid[y + 1][x] === 0) return "down";
    if (x - 1 >= 0 && grid[y][x - 1] === 0) return "left";
    if (y - 1 >= 0 && grid[y - 1][x] === 0) return "up";
    return "right";
}

function getHead() {
    if (path.length === 0) return startPos;
    return path[path.length - 1];
}

function canMove(dirX, dirY) {
    if (isWon) return false;
    var head = getHead();
    var nx = head.x + dirX;
    var ny = head.y + dirY;
    if (nx < 0 || nx >= width || ny < 0 || ny >= height) return false;
    if (grid[ny][nx] !== 0) return false;
    return true;
}

function slide(dirX, dirY, callbacks) {
    if (isWon) return false;
    if (!canMove(dirX, dirY)) {
        if (callbacks && callbacks.onBump) {
            callbacks.onBump();
        }
        return false;
    }
    
    if (dirX === 1) facing = "right";
    else if (dirX === -1) facing = "left";
    else if (dirY === 1) facing = "down";
    else if (dirY === -1) facing = "up";
    
    var addedCells = [];
    var head = getHead();
    var cx = head.x;
    var cy = head.y;
    
    while (true) {
        var nx = cx + dirX;
        var ny = cy + dirY;
        
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) break;
        if (grid[ny][nx] !== 0) break;
        
        grid[ny][nx] = 2;
        path.push({x: nx, y: ny});
        addedCells.push({x: nx, y: ny});
        cx = nx;
        cy = ny;
    }
    
    if (addedCells.length > 0) {
        history.push({
            cells: addedCells,
            facing: facing,
            dirX: dirX,
            dirY: dirY
        });
        movesCount++;
        
        if (callbacks && callbacks.onStep) {
            callbacks.onStep(addedCells.length);
        }
        
        // Check win condition
        if (path.length === totalPassable) {
            isWon = true;
            if (callbacks && callbacks.onWin) {
                callbacks.onWin(movesCount);
            }
        } else if (!hasAvailableMoves()) {
            if (callbacks && callbacks.onStuck) {
                callbacks.onStuck(movesCount);
            }
        }
        
        return true;
    }
    
    return false;
}

function hasAvailableMoves() {
    return canMove(1, 0) || canMove(-1, 0) || canMove(0, 1) || canMove(0, -1);
}

function undo(callbacks) {
    if (history.length === 0) return false;
    
    var lastMove = history.pop();
    for (var i = lastMove.cells.length - 1; i >= 0; i--) {
        var cell = lastMove.cells[i];
        grid[cell.y][cell.x] = 0;
        path.pop();
    }
    
    if (isWon) isWon = false;
    if (movesCount > 0) movesCount--;
    
    // Recalculate facing
    if (history.length > 0) {
        facing = history[history.length - 1].facing;
    } else {
        facing = determineInitialFacing();
    }
    
    if (callbacks && callbacks.onUndo) {
        callbacks.onUndo();
    }
    
    return true;
}

function reset(callbacks) {
    initLevel(currentLevelIndex);
    if (callbacks && callbacks.onReset) {
        callbacks.onReset();
    }
    return getGameState();
}

function nextLevel() {
    var nextIdx = currentLevelIndex + 1;
    if (nextIdx > Levels.getLevelCount()) {
        nextIdx = 1;
    }
    return initLevel(nextIdx);
}

function prevLevel() {
    var prevIdx = currentLevelIndex - 1;
    if (prevIdx < 1) {
        prevIdx = Levels.getLevelCount();
    }
    return initLevel(prevIdx);
}

function getGameState() {
    return {
        levelIndex: currentLevelIndex,
        levelName: levelData ? levelData.name : "Level " + currentLevelIndex,
        width: width,
        height: height,
        grid: grid,
        path: path,
        head: getHead(),
        startPos: startPos,
        facing: facing,
        totalPassable: totalPassable,
        filledCount: path.length,
        progressPercent: totalPassable > 0 ? Math.floor((path.length / totalPassable) * 100) : 0,
        movesCount: movesCount,
        isWon: isWon,
        isStuck: !isWon && path.length < totalPassable && !hasAvailableMoves(),
        canUndo: history.length > 0,
        totalLevels: Levels.getLevelCount()
    };
}

function getHint() {
    if (isWon) return null;
    
    var lvl = Levels.getLevel(currentLevelIndex);
    if (!lvl || !lvl.solution) return null;
    
    // 1. Check if the moves made so far match the certified solution prefix
    var matchesPrefix = true;
    for (var i = 0; i < history.length; i++) {
        var h = history[i];
        var s = (i < lvl.solution.length) ? lvl.solution[i] : "";
        var dirName = "";
        if (h.dirX === 1) dirName = "R";
        else if (h.dirX === -1) dirName = "L";
        else if (h.dirY === 1) dirName = "D";
        else if (h.dirY === -1) dirName = "U";
        
        if (dirName !== s) {
            matchesPrefix = false;
            break;
        }
    }
    
    if (matchesPrefix && history.length < lvl.solution.length) {
        var nextCode = lvl.solution[history.length];
        var moveName = "Right", arrow = "➔", dx = 1, dy = 0;
        if (nextCode === "U") { moveName = "Up"; arrow = "⬆"; dx = 0; dy = -1; }
        else if (nextCode === "D") { moveName = "Down"; arrow = "⬇"; dx = 0; dy = 1; }
        else if (nextCode === "L") { moveName = "Left"; arrow = "⬅"; dx = -1; dy = 0; }
        else if (nextCode === "R") { moveName = "Right"; arrow = "➔"; dx = 1; dy = 0; }
        
        return {
            status: "ok",
            direction: moveName,
            arrow: arrow,
            dx: dx,
            dy: dy,
            message: "Slide " + moveName + " " + arrow
        };
    }
    
    // 2. If diverged, find dynamic solution from current state
    var dyn = solveFromCurrentState();
    if (dyn && dyn.length > 0) {
        var dCode = dyn[0];
        var dName = "Right", dArrow = "➔", dDx = 1, dDy = 0;
        if (dCode === "U") { dName = "Up"; dArrow = "⬆"; dDx = 0; dDy = -1; }
        else if (dCode === "D") { dName = "Down"; dArrow = "⬇"; dDx = 0; dDy = 1; }
        else if (dCode === "L") { dName = "Left"; dArrow = "⬅"; dDx = -1; dDy = 0; }
        else if (dCode === "R") { dName = "Right"; dArrow = "➔"; dDx = 1; dDy = 0; }
        
        return {
            status: "ok",
            direction: dName,
            arrow: dArrow,
            dx: dDx,
            dy: dDy,
            message: "Slide " + dName + " " + dArrow
        };
    }
    
    // 3. Trapped / dead end
    return {
        status: "trapped",
        direction: "Undo",
        arrow: "↺",
        dx: 0,
        dy: 0,
        message: "Trapped! Press Undo (U) to rewind."
    };
}

function solveFromCurrentState() {
    var head = getHead();
    var dirs = [
        {name: "U", dx: 0, dy: -1},
        {name: "R", dx: 1, dy: 0},
        {name: "D", dx: 0, dy: 1},
        {name: "L", dx: -1, dy: 0}
    ];
    
    var sol = null;
    
    function testSlide(cx, cy, dx, dy, localGrid) {
        var added = [];
        var x = cx, y = cy;
        while (true) {
            var nx = x + dx;
            var ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) break;
            if (localGrid[ny][nx] !== 0) break;
            added.push({x: nx, y: ny});
            x = nx;
            y = ny;
        }
        return {head: {x: x, y: y}, added: added};
    }
    
    function dfs(cx, cy, localGrid, pathLen, moves) {
        if (pathLen === totalPassable) {
            sol = moves.slice();
            return true;
        }
        for (var d = 0; d < 4; d++) {
            var res = testSlide(cx, cy, dirs[d].dx, dirs[d].dy, localGrid);
            if (res.added.length === 0) continue;
            for (var a = 0; a < res.added.length; a++) {
                localGrid[res.added[a].y][res.added[a].x] = 2;
            }
            moves.push(dirs[d].name);
            if (dfs(res.head.x, res.head.y, localGrid, pathLen + res.added.length, moves)) {
                return true;
            }
            moves.pop();
            for (var r = 0; r < res.added.length; r++) {
                localGrid[res.added[r].y][res.added[r].x] = 0;
            }
        }
        return false;
    }
    
    var clonedGrid = [];
    for (var y = 0; y < height; y++) {
        clonedGrid.push(grid[y].slice());
    }
    
    dfs(head.x, head.y, clonedGrid, path.length, []);
    return sol;
}
