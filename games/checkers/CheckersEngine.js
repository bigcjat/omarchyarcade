.pragma library

// Checkers (American / English Draughts) Engine
// Standard 8x8 rules with forced captures and king promotion

var WHITE = 'w';
var BLACK = 'b';
var WHITE_KING = 'W';
var BLACK_KING = 'B';
var EMPTY = '.';

function createInitialBoard() {
    var board = [];
    for (var r = 0; r < 8; r++) {
        var row = [];
        for (var c = 0; c < 8; c++) {
            if ((r + c) % 2 === 1) {
                if (r < 3) row.push(BLACK);
                else if (r > 4) row.push(WHITE);
                else row.push(EMPTY);
            } else {
                row.push(EMPTY);
            }
        }
        board.push(row);
    }
    return board;
}

function boardToStr(board) {
    var s = "";
    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            s += board[r][c];
        }
    }
    return s;
}

function isValidSquare(r, c) {
    return r >= 0 && r < 8 && c >= 0 && c < 8 && (r + c) % 2 === 1;
}

function isWhite(piece) {
    return piece === WHITE || piece === WHITE_KING;
}

function isBlack(piece) {
    return piece === BLACK || piece === BLACK_KING;
}

function isOpponent(piece, activeColor) {
    if (activeColor === WHITE) return isBlack(piece);
    return isWhite(piece);
}

function getMovesForPiece(board, r, c) {
    var piece = board[r][c];
    if (piece === EMPTY) return { quiets: [], jumps: [] };

    var color = isWhite(piece) ? WHITE : BLACK;
    var isKing = (piece === WHITE_KING || piece === BLACK_KING);

    var dirs = [];
    if (isKing) {
        dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    } else if (color === WHITE) {
        dirs = [[-1, -1], [-1, 1]]; // White moves UP
    } else {
        dirs = [[1, -1], [1, 1]];   // Black moves DOWN
    }

    // 1. Quiet Moves
    var quiets = [];
    for (var i = 0; i < dirs.length; i++) {
        var nr = r + dirs[i][0];
        var nc = c + dirs[i][1];
        if (isValidSquare(nr, nc) && board[nr][nc] === EMPTY) {
            quiets.push({
                from: [r, c],
                to: [nr, nc],
                path: [[r, c], [nr, nc]],
                captures: []
            });
        }
    }

    // 2. Jump Moves (including recursive multi-jumps)
    var jumps = [];

    function searchJumps(currR, currC, currPiece, visitedCaps, currentPath) {
        var foundAny = false;
        var currKing = (currPiece === WHITE_KING || currPiece === BLACK_KING);
        var currDirs = currKing ? [[-1, -1], [-1, 1], [1, -1], [1, 1]] : (isWhite(currPiece) ? [[-1, -1], [-1, 1]] : [[1, -1], [1, 1]]);

        for (var d = 0; d < currDirs.length; d++) {
            var midR = currR + currDirs[d][0];
            var midC = currC + currDirs[d][1];
            var destR = currR + 2 * currDirs[d][0];
            var destC = currC + 2 * currDirs[d][1];

            if (isValidSquare(destR, destC)) {
                // Check if captured square was already jumped in this chain
                var alreadyJumped = false;
                for (var v = 0; v < visitedCaps.length; v++) {
                    if (visitedCaps[v][0] === midR && visitedCaps[v][1] === midC) {
                        alreadyJumped = true;
                        break;
                    }
                }

                if (!alreadyJumped) {
                    var midPiece = board[midR][midC];
                    var destPiece = board[destR][destC];

                    if ((destPiece === EMPTY || (destR === r && destC === c)) && isOpponent(midPiece, color)) {
                        foundAny = true;
                        var nextVisited = visitedCaps.slice();
                        nextVisited.push([midR, midC]);
                        var nextPath = currentPath.slice();
                        nextPath.push([destR, destC]);

                        var becameKing = false;
                        if (!currKing) {
                            if ((color === WHITE && destR === 0) || (color === BLACK && destR === 7)) {
                                becameKing = true;
                            }
                        }

                        // Crowning ends turn immediately per American Checkers rules
                        if (becameKing) {
                            jumps.push({
                                from: [r, c],
                                to: [destR, destC],
                                path: nextPath,
                                captures: nextVisited
                            });
                        } else {
                            var subFound = searchJumps(destR, destC, currPiece, nextVisited, nextPath);
                            if (!subFound) {
                                jumps.push({
                                    from: [r, c],
                                    to: [destR, destC],
                                    path: nextPath,
                                    captures: nextVisited
                                });
                            }
                        }
                    }
                }
            }
        }
        return foundAny;
    }

    searchJumps(r, c, piece, [], [[r, c]]);
    return { quiets: quiets, jumps: jumps };
}

function getAllLegalMoves(board, activeColor) {
    var allQuiets = [];
    var allJumps = [];

    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            var p = board[r][c];
            if ((activeColor === WHITE && isWhite(p)) || (activeColor === BLACK && isBlack(p))) {
                var m = getMovesForPiece(board, r, c);
                for (var q = 0; q < m.quiets.length; q++) allQuiets.push(m.quiets[q]);
                for (var j = 0; j < m.jumps.length; j++) allJumps.push(m.jumps[j]);
            }
        }
    }

    // Mandatory jump rule: if jumps exist, only jumps are legal
    if (allJumps.length > 0) {
        return allJumps;
    }
    return allQuiets;
}

function applyMove(board, move) {
    var fromR = move.from[0];
    var fromC = move.from[1];
    var toR = move.to[0];
    var toC = move.to[1];

    var piece = board[fromR][fromC];
    board[fromR][fromC] = EMPTY;

    for (var i = 0; i < move.captures.length; i++) {
        var cr = move.captures[i][0];
        var cc = move.captures[i][1];
        board[cr][cc] = EMPTY;
    }

    var promoted = false;
    if (piece === WHITE && toR === 0) {
        piece = WHITE_KING;
        promoted = true;
    } else if (piece === BLACK && toR === 7) {
        piece = BLACK_KING;
        promoted = true;
    }

    board[toR][toC] = piece;
    return { piece: piece, promoted: promoted };
}

function countPieces(board) {
    var wMen = 0, wKings = 0;
    var bMen = 0, bKings = 0;

    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            var p = board[r][c];
            if (p === WHITE) wMen++;
            else if (p === WHITE_KING) wKings++;
            else if (p === BLACK) bMen++;
            else if (p === BLACK_KING) bKings++;
        }
    }

    return {
        whiteTotal: wMen + wKings,
        blackTotal: bMen + bKings,
        whiteKings: wKings,
        blackKings: bKings,
        whiteDiff: (wMen + wKings * 2) - (bMen + bKings * 2)
    };
}
