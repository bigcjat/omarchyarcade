// Snake Game Engine (Pure Deterministic JavaScript)

.pragma library

var GRID_SIZE = 22;
var snake = [];
var direction = { x: 1, y: 0 };
var nextDirection = { x: 1, y: 0 };
var food = { x: 15, y: 11 };
var score = 0;
var bestScore = 0;
var level = 1;
var isOver = false;
var wrapWalls = false;

function initGame(wrap) {
    wrapWalls = !!wrap;
    score = 0;
    level = 1;
    isOver = false;
    direction = { x: 1, y: 0 };
    nextDirection = { x: 1, y: 0 };

    var startX = Math.floor(GRID_SIZE / 3);
    var startY = Math.floor(GRID_SIZE / 2);
    snake = [
        { x: startX, y: startY },
        { x: startX - 1, y: startY },
        { x: startX - 2, y: startY }
    ];

    spawnFood();
}

function spawnFood() {
    var emptyCells = [];
    var occupied = {};
    for (var i = 0; i < snake.length; i++) {
        occupied[snake[i].x + "_" + snake[i].y] = true;
    }
    for (var x = 0; x < GRID_SIZE; x++) {
        for (var y = 0; y < GRID_SIZE; y++) {
            if (!occupied[x + "_" + y]) {
                emptyCells.push({ x: x, y: y });
            }
        }
    }
    if (emptyCells.length > 0) {
        var idx = Math.floor(Math.random() * emptyCells.length);
        food = emptyCells[idx];
    }
}

function setDirection(dx, dy) {
    // Prevent 180° immediate reversal
    if (dx === -direction.x && dy === -direction.y) return false;
    if (dx === direction.x && dy === direction.y) return false;
    nextDirection = { x: dx, y: dy };
    return true;
}

function tick() {
    if (isOver) return { moved: false, ate: false, over: true };

    direction = nextDirection;
    var head = snake[0];
    var nx = head.x + direction.x;
    var ny = head.y + direction.y;

    if (wrapWalls) {
        nx = (nx + GRID_SIZE) % GRID_SIZE;
        ny = (ny + GRID_SIZE) % GRID_SIZE;
    } else {
        if (nx < 0 || nx >= GRID_SIZE || ny < 0 || ny >= GRID_SIZE) {
            isOver = true;
            return { moved: false, ate: false, over: true };
        }
    }

    // Check self collision (excluding tail tip since it moves unless eating)
    for (var i = 0; i < snake.length - 1; i++) {
        if (snake[i].x === nx && snake[i].y === ny) {
            isOver = true;
            return { moved: false, ate: false, over: true };
        }
    }

    var ate = (nx === food.x && ny === food.y);
    snake.unshift({ x: nx, y: ny });

    if (ate) {
        score += 10;
        level = Math.floor(score / 50) + 1;
        spawnFood();
    } else {
        snake.pop();
    }

    return { moved: true, ate: ate, over: false };
}

function getInterval() {
    return Math.max(55, 140 - (level - 1) * 9);
}

function getState() {
    return {
        gridSize: GRID_SIZE,
        snake: snake,
        food: food,
        score: score,
        level: level,
        isOver: isOver,
        wrapWalls: wrapWalls,
        direction: direction
    };
}
