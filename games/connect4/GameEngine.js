// DropFour - Connect Four Engine with Minimax AI

.pragma library

var COLS = 7;
var ROWS = 6;
var board = []; // 2D array: board[r][c], 0 = empty, 1 = P1, 2 = P2/CPU
var currentPlayer = 1;
var selectedCol = 3;
var gameState = "playing"; // "playing", "won", "draw"
var winningCells = []; // array of {r, c}
var moveHistory = [];
var gameMode = "1p"; // "1p" or "2p"
var cpuDifficulty = "pro"; // "novice", "pro", "master"

function init(mode, diff) {
    if (mode) gameMode = mode;
    if (diff) cpuDifficulty = diff;
    board = [];
    for (var r = 0; r < ROWS; r++) {
        var row = [];
        for (var c = 0; c < COLS; c++) {
            row.push(0);
        }
        board.push(row);
    }
    currentPlayer = 1;
    selectedCol = 3;
    gameState = "playing";
    winningCells = [];
    moveHistory = [];
}

function getLowestEmptyRow(col) {
    if (col < 0 || col >= COLS) return -1;
    for (var r = ROWS - 1; r >= 0; r--) {
        if (board[r][col] === 0) {
            return r;
        }
    }
    return -1; // Column full
}

function dropToken(col) {
    if (gameState !== "playing") return null;
    var row = getLowestEmptyRow(col);
    if (row === -1) return { error: "full" };

    var player = currentPlayer;
    board[row][col] = player;
    moveHistory.push({ r: row, c: col, player: player });

    var win = checkWinAt(row, col, player);
    if (win) {
        gameState = "won";
        winningCells = win;
        return { event: "win", row: row, col: col, player: player, winningCells: win };
    }

    if (isBoardFull()) {
        gameState = "draw";
        return { event: "draw", row: row, col: col, player: player };
    }

    currentPlayer = (currentPlayer === 1) ? 2 : 1;
    return { event: "drop", row: row, col: col, player: player, nextPlayer: currentPlayer };
}

function checkWinAt(r, c, p) {
    var directions = [
        [[0, 1], [0, -1]],   // Horizontal
        [[1, 0], [-1, 0]],   // Vertical
        [[1, 1], [-1, -1]],  // Diagonal \
        [[1, -1], [-1, 1]]   // Diagonal /
    ];

    for (var d = 0; d < directions.length; d++) {
        var line = [{ r: r, c: c }];
        for (var s = 0; s < 2; s++) {
            var dr = directions[d][s][0];
            var dc = directions[d][s][1];
            var step = 1;
            while (true) {
                var nr = r + dr * step;
                var nc = c + dc * step;
                if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && board[nr][nc] === p) {
                    line.push({ r: nr, c: nc });
                    step++;
                } else {
                    break;
                }
            }
        }
        if (line.length >= 4) {
            return line;
        }
    }
    return null;
}

function isBoardFull() {
    for (var c = 0; c < COLS; c++) {
        if (board[0][c] === 0) return false;
    }
    return true;
}

// AI Minimax with Alpha-Beta Pruning
function getCpuMove() {
    if (gameState !== "playing") return -1;

    // Check immediate win or immediate block
    for (var c = 0; c < COLS; c++) {
        var r = getLowestEmptyRow(c);
        if (r !== -1) {
            board[r][c] = 2;
            if (checkWinAt(r, c, 2)) {
                board[r][c] = 0;
                return c;
            }
            board[r][c] = 0;
        }
    }

    for (var c = 0; c < COLS; c++) {
        var r = getLowestEmptyRow(c);
        if (r !== -1) {
            board[r][c] = 1;
            if (checkWinAt(r, c, 1)) {
                board[r][c] = 0;
                return c; // Block player 1
            }
            board[r][c] = 0;
        }
    }

    if (cpuDifficulty === "novice") {
        // Random valid column
        var valid = [];
        for (var c = 0; c < COLS; c++) {
            if (getLowestEmptyRow(c) !== -1) valid.push(c);
        }
        return valid[Math.floor(Math.random() * valid.length)];
    }

    var depth = (cpuDifficulty === "master") ? 5 : 3;
    var bestScore = -999999;
    var bestCol = 3;
    var order = [3, 2, 4, 1, 5, 0, 6]; // Search center columns first

    for (var i = 0; i < order.length; i++) {
        var col = order[i];
        var row = getLowestEmptyRow(col);
        if (row !== -1) {
            board[row][col] = 2;
            var score = minimax(depth - 1, false, -999999, 999999);
            board[row][col] = 0;
            if (score > bestScore) {
                bestScore = score;
                bestCol = col;
            }
        }
    }
    return bestCol;
}

function minimax(depth, isMaximizing, alpha, beta) {
    if (depth === 0 || isBoardFull()) {
        return evaluateBoard();
    }

    var order = [3, 2, 4, 1, 5, 0, 6];
    if (isMaximizing) {
        var maxEval = -999999;
        for (var i = 0; i < order.length; i++) {
            var c = order[i];
            var r = getLowestEmptyRow(c);
            if (r !== -1) {
                board[r][c] = 2;
                if (checkWinAt(r, c, 2)) {
                    board[r][c] = 0;
                    return 10000 + depth;
                }
                var ev = minimax(depth - 1, false, alpha, beta);
                board[r][c] = 0;
                maxEval = Math.max(maxEval, ev);
                alpha = Math.max(alpha, ev);
                if (beta <= alpha) break;
            }
        }
        return maxEval;
    } else {
        var minEval = 999999;
        for (var i = 0; i < order.length; i++) {
            var c = order[i];
            var r = getLowestEmptyRow(c);
            if (r !== -1) {
                board[r][c] = 1;
                if (checkWinAt(r, c, 1)) {
                    board[r][c] = 0;
                    return -10000 - depth;
                }
                var ev = minimax(depth - 1, true, alpha, beta);
                board[r][c] = 0;
                minEval = Math.min(minEval, ev);
                beta = Math.min(beta, ev);
                if (beta <= alpha) break;
            }
        }
        return minEval;
    }
}

function evaluateBoard() {
    var score = 0;
    // Prefer center column
    for (var r = 0; r < ROWS; r++) {
        if (board[r][3] === 2) score += 4;
        else if (board[r][3] === 1) score -= 4;
    }
    return score;
}
