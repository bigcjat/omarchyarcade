// CyberSweeper Game Logic Engine

.pragma library

var DIFFICULTIES = {
    beginner: { cols: 9, rows: 9, mines: 10, label: "Beginner" },
    intermediate: { cols: 16, rows: 16, mines: 40, label: "Intermediate" },
    expert: { cols: 30, rows: 16, mines: 99, label: "Expert" }
};

var currentDifficulty = "beginner";
var cols = 9;
var rows = 9;
var totalMines = 10;
var board = []; // 2D array: board[r][c]
var gameState = "idle"; // "idle", "playing", "won", "lost"
var flagsLeft = 10;
var firstClick = true;
var cursor = { r: 4, c: 4 };

function init(diffKey) {
    if (diffKey && DIFFICULTIES[diffKey]) {
        currentDifficulty = diffKey;
    }
    var config = DIFFICULTIES[currentDifficulty];
    cols = config.cols;
    rows = config.rows;
    totalMines = config.mines;
    flagsLeft = totalMines;
    gameState = "idle";
    firstClick = true;
    cursor = { r: Math.floor(rows / 2), c: Math.floor(cols / 2) };

    board = [];
    for (var r = 0; r < rows; r++) {
        var row = [];
        for (var c = 0; c < cols; c++) {
            row.push({
                mine: false,
                revealed: false,
                flagged: false,
                neighborMines: 0,
                exploded: false
            });
        }
        board.push(row);
    }
}

function placeMines(safeR, safeC) {
    var placed = 0;
    while (placed < totalMines) {
        var r = Math.floor(Math.random() * rows);
        var c = Math.floor(Math.random() * cols);

        // Don't place on or directly around first click if possible
        if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1 && (rows * cols - 9 >= totalMines)) {
            continue;
        }
        if (r === safeR && c === safeC) {
            continue;
        }
        if (!board[r][c].mine) {
            board[r][c].mine = true;
            placed++;
        }
    }

    // Compute neighbor mine counts
    for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
            if (board[r][c].mine) continue;
            var count = 0;
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    var nr = r + dr;
                    var nc = c + dc;
                    if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc].mine) {
                        count++;
                    }
                }
            }
            board[r][c].neighborMines = count;
        }
    }
}

function reveal(r, c) {
    if (gameState === "won" || gameState === "lost") return null;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;

    var cell = board[r][c];
    if (cell.flagged || cell.revealed) return null;

    if (firstClick) {
        firstClick = false;
        gameState = "playing";
        placeMines(r, c);
    }

    if (cell.mine) {
        cell.revealed = true;
        cell.exploded = true;
        gameState = "lost";
        revealAllMines();
        return { event: "explode" };
    }

    // Flood fill reveal
    var queue = [{ r: r, c: c }];
    cell.revealed = true;

    while (queue.length > 0) {
        var curr = queue.shift();
        var curCell = board[curr.r][curr.c];

        if (curCell.neighborMines === 0 && !curCell.mine) {
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    var nr = curr.r + dr;
                    var nc = curr.c + dc;
                    if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                        var neighbor = board[nr][nc];
                        if (!neighbor.revealed && !neighbor.flagged && !neighbor.mine) {
                            neighbor.revealed = true;
                            if (neighbor.neighborMines === 0) {
                                queue.push({ r: nr, c: nc });
                            }
                        }
                    }
                }
            }
        }
    }

    if (checkWin()) {
        gameState = "won";
        flagsLeft = 0;
        return { event: "win" };
    }

    return { event: "click" };
}

function toggleFlag(r, c) {
    if (gameState === "lost" || gameState === "won") return null;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;

    var cell = board[r][c];
    if (cell.revealed) return null;

    if (firstClick) {
        // can still flag before first click
        firstClick = false;
        gameState = "playing";
        placeMines(-1, -1);
    }

    if (!cell.flagged) {
        cell.flagged = true;
        flagsLeft--;
        return { event: "flag" };
    } else {
        cell.flagged = false;
        flagsLeft++;
        return { event: "unflag" };
    }
}

function chord(r, c) {
    if (gameState !== "playing") return null;
    var cell = board[r][c];
    if (!cell.revealed || cell.neighborMines === 0) return null;

    // Count adjacent flags
    var flagCount = 0;
    for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
            var nr = r + dr;
            var nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc].flagged) {
                flagCount++;
            }
        }
    }

    if (flagCount === cell.neighborMines) {
        var hitMine = false;
        for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
                var nr = r + dr;
                var nc = c + dc;
                if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                    var nCell = board[nr][nc];
                    if (!nCell.flagged && !nCell.revealed) {
                        var res = reveal(nr, nc);
                        if (res && res.event === "explode") hitMine = true;
                        if (res && res.event === "win") return { event: "win" };
                    }
                }
            }
        }
        if (hitMine) return { event: "explode" };
        return { event: "click" };
    }
    return null;
}

function checkWin() {
    var revealedCount = 0;
    for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
            if (board[r][c].revealed && !board[r][c].mine) {
                revealedCount++;
            }
        }
    }
    return (revealedCount === (rows * cols - totalMines));
}

function revealAllMines() {
    for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
            if (board[r][c].mine) {
                board[r][c].revealed = true;
            }
        }
    }
}

function moveCursor(dr, dc) {
    var nr = Math.max(0, Math.min(rows - 1, cursor.r + dr));
    var nc = Math.max(0, Math.min(cols - 1, cursor.c + dc));
    cursor.r = nr;
    cursor.c = nc;
}
