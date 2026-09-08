// Omarchy Arcade • Reversi (Othello) Game Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

var EMPTY = 0;
var DARK = 1;   // Black - traditionally moves first
var LIGHT = 2;  // White

var board = [];
var currentTurn = DARK;
var history = [];
var gameOver = false;
var winner = 0; // 0: none/draw, 1: dark, 2: light
var darkCount = 2;
var lightCount = 2;

// 8 Directions: [row_offset, col_offset]
var DIRECTIONS = [
    [-1, -1], [-1, 0], [-1, 1],
    [ 0, -1],          [ 0, 1],
    [ 1, -1], [ 1, 0], [ 1, 1]
];

// Classic Reversi Positional Matrix
var POSITIONAL_WEIGHTS = [
    [ 120, -20,  20,   5,   5,  20, -20,  120],
    [ -20, -40,  -5,  -5,  -5,  -5, -40,  -20],
    [  20,  -5,  15,   3,   3,  15,  -5,   20],
    [   5,  -5,   3,   3,   3,   3,  -5,    5],
    [   5,  -5,   3,   3,   3,   3,  -5,    5],
    [  20,  -5,  15,   3,   3,  15,  -5,   20],
    [ -20, -40,  -5,  -5,  -5,  -5, -40,  -20],
    [ 120, -20,  20,   5,   5,  20, -20,  120]
];

function cloneBoard(src) {
    var copy = [];
    for (var r = 0; r < 8; r++) {
        copy[r] = [];
        for (var c = 0; c < 8; c++) {
            copy[r][c] = src[r][c];
        }
    }
    return copy;
}

function init() {
    resetGame();
}

function resetGame() {
    board = [];
    for (var r = 0; r < 8; r++) {
        board[r] = [];
        for (var c = 0; c < 8; c++) {
            board[r][c] = EMPTY;
        }
    }
    // Standard Othello starting position
    board[3][3] = LIGHT;
    board[3][4] = DARK;
    board[4][3] = DARK;
    board[4][4] = LIGHT;

    currentTurn = DARK;
    history = [];
    gameOver = false;
    winner = 0;
    updateCounts();
}

function updateCounts() {
    var d = 0;
    var l = 0;
    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            if (board[r][c] === DARK) d++;
            else if (board[r][c] === LIGHT) l++;
        }
    }
    darkCount = d;
    lightCount = l;
}

function getFlipsForBoard(b, row, col, player) {
    if (row < 0 || row >= 8 || col < 0 || col >= 8) return [];
    if (b[row][col] !== EMPTY) return [];

    var opponent = (player === DARK) ? LIGHT : DARK;
    var allFlips = [];

    for (var i = 0; i < DIRECTIONS.length; i++) {
        var dr = DIRECTIONS[i][0];
        var dc = DIRECTIONS[i][1];
        var r = row + dr;
        var c = col + dc;
        var dirFlips = [];

        while (r >= 0 && r < 8 && c >= 0 && c < 8 && b[r][c] === opponent) {
            dirFlips.push({ r: r, c: c });
            r += dr;
            c += dc;
        }

        if (r >= 0 && r < 8 && c >= 0 && c < 8 && b[r][c] === player && dirFlips.length > 0) {
            for (var j = 0; j < dirFlips.length; j++) {
                allFlips.push(dirFlips[j]);
            }
        }
    }

    return allFlips;
}

function getFlips(row, col, player) {
    var p = player !== undefined ? player : currentTurn;
    return getFlipsForBoard(board, row, col, p);
}

function getValidMovesForBoard(b, player) {
    var moves = [];
    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            if (b[r][c] === EMPTY) {
                var flips = getFlipsForBoard(b, r, c, player);
                if (flips.length > 0) {
                    moves.push({ r: r, c: c, flips: flips });
                }
            }
        }
    }
    return moves;
}

function getValidMoves(player) {
    var p = player !== undefined ? player : currentTurn;
    return getValidMovesForBoard(board, p);
}

function makeMove(row, col) {
    if (gameOver) return { success: false, reason: "game_over" };

    var flips = getFlips(row, col, currentTurn);
    if (flips.length === 0) return { success: false, reason: "invalid_move" };

    // Save snapshot for Undo
    history.push({
        board: cloneBoard(board),
        currentTurn: currentTurn,
        darkCount: darkCount,
        lightCount: lightCount,
        gameOver: gameOver,
        winner: winner
    });

    // Place the piece
    board[row][col] = currentTurn;

    // Flip bracketed pieces
    for (var i = 0; i < flips.length; i++) {
        var fr = flips[i].r;
        var fc = flips[i].c;
        board[fr][fc] = currentTurn;
    }

    updateCounts();

    var nextTurn = (currentTurn === DARK) ? LIGHT : DARK;
    var nextMoves = getValidMovesForBoard(board, nextTurn);

    if (nextMoves.length > 0) {
        currentTurn = nextTurn;
        return {
            success: true,
            flips: flips,
            passed: false,
            gameOver: false,
            currentTurn: currentTurn
        };
    }

    // Next player has no moves! Check if original player has moves (Pass)
    var currMoves = getValidMovesForBoard(board, currentTurn);
    if (currMoves.length > 0) {
        var passedPlayer = nextTurn;
        // Turn stays with original player
        return {
            success: true,
            flips: flips,
            passed: true,
            passedPlayer: passedPlayer,
            gameOver: false,
            currentTurn: currentTurn
        };
    }

    // Neither player can move: Game Over!
    gameOver = true;
    if (darkCount > lightCount) winner = DARK;
    else if (lightCount > darkCount) winner = LIGHT;
    else winner = 0; // Draw

    return {
        success: true,
        flips: flips,
        passed: false,
        gameOver: true,
        winner: winner,
        darkCount: darkCount,
        lightCount: lightCount
    };
}

function undo() {
    if (history.length === 0) return false;
    var prev = history.pop();
    board = prev.board;
    currentTurn = prev.currentTurn;
    darkCount = prev.darkCount;
    lightCount = prev.lightCount;
    gameOver = prev.gameOver;
    winner = prev.winner;
    return true;
}

// =============================================================================
// AI MINIMAX & HEURISTIC ENGINE
// =============================================================================

function evaluateBoard(b, aiColor) {
    var oppColor = (aiColor === DARK) ? LIGHT : DARK;
    var emptyCount = 0;
    var aiDiscs = 0;
    var oppDiscs = 0;
    var posScore = 0;

    var corners = [
        [0, 0], [0, 7], [7, 0], [7, 7]
    ];

    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            var val = b[r][c];
            if (val === EMPTY) {
                emptyCount++;
            } else if (val === aiColor) {
                aiDiscs++;
                posScore += POSITIONAL_WEIGHTS[r][c];
            } else {
                oppDiscs++;
                posScore -= POSITIONAL_WEIGHTS[r][c];
            }
        }
    }

    // Corner dynamic stabilization:
    // If AI holds corner, neighbor X/C squares are no longer negative penalties
    for (var i = 0; i < corners.length; i++) {
        var cr = corners[i][0];
        var cc = corners[i][1];
        if (b[cr][cc] === aiColor) {
            posScore += 40;
        } else if (b[cr][cc] === oppColor) {
            posScore -= 40;
        }
    }

    // Mobility (number of available moves)
    var aiMoves = getValidMovesForBoard(b, aiColor).length;
    var oppMoves = getValidMovesForBoard(b, oppColor).length;
    var mobilityScore = 0;
    if (aiMoves + oppMoves > 0) {
        mobilityScore = 100 * (aiMoves - oppMoves) / (aiMoves + oppMoves);
    }

    // Endgame disc parity: In final 14 empty spaces, disc count is king
    if (emptyCount <= 14) {
        return (aiDiscs - oppDiscs) * 1000 + posScore;
    }

    // Mid-game composite score
    var discDiff = 0;
    if (aiDiscs + oppDiscs > 0) {
        discDiff = 100 * (aiDiscs - oppDiscs) / (aiDiscs + oppDiscs);
    }

    return posScore * 10 + mobilityScore * 5 + discDiff * 2;
}

function applyMoveToBoard(b, row, col, player, flips) {
    var nb = cloneBoard(b);
    nb[row][col] = player;
    for (var i = 0; i < flips.length; i++) {
        nb[flips[i].r][flips[i].c] = player;
    }
    return nb;
}

function minimax(b, depth, alpha, beta, isMaximizing, aiColor) {
    var oppColor = (aiColor === DARK) ? LIGHT : DARK;
    var activePlayer = isMaximizing ? aiColor : oppColor;
    var moves = getValidMovesForBoard(b, activePlayer);

    if (depth === 0) {
        return evaluateBoard(b, aiColor);
    }

    if (moves.length === 0) {
        // Player must pass. Check if opponent can move.
        var nextMoves = getValidMovesForBoard(b, 3 - activePlayer);
        if (nextMoves.length === 0) {
            // Terminal node (neither can move)
            return evaluateBoard(b, aiColor);
        }
        // Recurse with turn passed
        return minimax(b, depth - 1, alpha, beta, !isMaximizing, aiColor);
    }

    // Move ordering: evaluate corners and strong positional squares first
    moves.sort(function(m1, m2) {
        return POSITIONAL_WEIGHTS[m2.r][m2.c] - POSITIONAL_WEIGHTS[m1.r][m1.c];
    });

    if (isMaximizing) {
        var maxEval = -Infinity;
        for (var i = 0; i < moves.length; i++) {
            var m = moves[i];
            var nextBoard = applyMoveToBoard(b, m.r, m.c, aiColor, m.flips);
            var ev = minimax(nextBoard, depth - 1, alpha, beta, false, aiColor);
            maxEval = Math.max(maxEval, ev);
            alpha = Math.max(alpha, ev);
            if (beta <= alpha) break;
        }
        return maxEval;
    } else {
        var minEval = Infinity;
        for (var j = 0; j < moves.length; j++) {
            var oppM = moves[j];
            var oppNextBoard = applyMoveToBoard(b, oppM.r, oppM.c, oppColor, oppM.flips);
            var oppEv = minimax(oppNextBoard, depth - 1, alpha, beta, true, aiColor);
            minEval = Math.min(minEval, oppEv);
            beta = Math.min(beta, oppEv);
            if (beta <= alpha) break;
        }
        return minEval;
    }
}

function getBestMove(aiColor, difficulty) {
    var moves = getValidMovesForBoard(board, aiColor);
    if (moves.length === 0) return null;
    if (moves.length === 1) return moves[0];

    var diff = difficulty || "casual";

    // 1. NOVICE: Mostly greedy flips with slight randomness
    if (diff === "novice") {
        if (Math.random() < 0.35) {
            return moves[Math.floor(Math.random() * moves.length)];
        }
        moves.sort(function(a, b) {
            var wA = POSITIONAL_WEIGHTS[a.r][a.c] + a.flips.length;
            var wB = POSITIONAL_WEIGHTS[b.r][b.c] + b.flips.length;
            return wB - wA;
        });
        return moves[0];
    }

    // 2. CASUAL & MASTER: Minimax Search
    var maxDepth = 3;
    if (diff === "master") {
        var emptyCount = 64 - (darkCount + lightCount);
        maxDepth = (emptyCount <= 10) ? 6 : 4;
    }

    var bestMove = moves[0];
    var bestScore = -Infinity;

    for (var i = 0; i < moves.length; i++) {
        var m = moves[i];
        var nextBoard = applyMoveToBoard(board, m.r, m.c, aiColor, m.flips);
        var score = minimax(nextBoard, maxDepth - 1, -Infinity, Infinity, false, aiColor);

        // Add slight tie-breaker preference for corner/edge moves
        score += POSITIONAL_WEIGHTS[m.r][m.c] * 0.1;

        if (score > bestScore) {
            bestScore = score;
            bestMove = m;
        }
    }

    return bestMove;
}
