// Omarchy Arcade • Backgammon Game Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

var EMPTY = 0;
var DARK = 1;   // Moves 1 -> 24 (Home: 19-24)
var LIGHT = 2;  // Moves 24 -> 1 (Home: 1-6)

var board = []; // 1-indexed array of 25 objects: { count: int, player: int }
var bar = { 1: 0, 2: 0 };
var borneOff = { 1: 0, 2: 0 };

var currentTurn = DARK;
var dice = [0, 0];
var movesLeft = [];
var phase = "roll"; // "roll", "move", "gameover"
var winner = 0;
var winType = "single"; // "single", "gammon", "backgammon"
var turnHistory = [];   // Moves made in current turn for Undo support

function cloneState() {
    var bCopy = [];
    for (var i = 0; i <= 24; i++) {
        bCopy[i] = { count: board[i].count, player: board[i].player };
    }
    return {
        board: bCopy,
        bar: { 1: bar[1], 2: bar[2] },
        borneOff: { 1: borneOff[1], 2: borneOff[2] },
        currentTurn: currentTurn,
        dice: [dice[0], dice[1]],
        movesLeft: movesLeft.slice(),
        phase: phase,
        winner: winner,
        winType: winType
    };
}

function restoreState(s) {
    board = [];
    for (var i = 0; i <= 24; i++) {
        board[i] = { count: s.board[i].count, player: s.board[i].player };
    }
    bar = { 1: s.bar[1], 2: s.bar[2] };
    borneOff = { 1: s.borneOff[1], 2: s.borneOff[2] };
    currentTurn = s.currentTurn;
    dice = [s.dice[0], s.dice[1]];
    movesLeft = s.movesLeft.slice();
    phase = s.phase;
    winner = s.winner;
    winType = s.winType;
}

function init() {
    resetGame();
}

function resetGame() {
    board = [];
    for (var i = 0; i <= 24; i++) {
        board[i] = { count: 0, player: EMPTY };
    }

    // Standard Backgammon Starting Layout (15 checkers each)
    // Dark (Player 1, moves 1 -> 24)
    board[1]  = { count: 2, player: DARK };
    board[12] = { count: 5, player: DARK };
    board[17] = { count: 3, player: DARK };
    board[19] = { count: 5, player: DARK };

    // Light (Player 2, moves 24 -> 1)
    board[24] = { count: 2, player: LIGHT };
    board[13] = { count: 5, player: LIGHT };
    board[8]  = { count: 3, player: LIGHT };
    board[6]  = { count: 5, player: LIGHT };

    bar = { 1: 0, 2: 0 };
    borneOff = { 1: 0, 2: 0 };

    currentTurn = DARK;
    dice = [0, 0];
    movesLeft = [];
    phase = "roll";
    winner = 0;
    winType = "single";
    turnHistory = [];
}

function rollDice() {
    if (phase !== "roll") return null;

    var d1 = Math.floor(Math.random() * 6) + 1;
    var d2 = Math.floor(Math.random() * 6) + 1;
    dice = [d1, d2];

    if (d1 === d2) {
        movesLeft = [d1, d1, d1, d1]; // Doubles gives 4 moves
    } else {
        movesLeft = [d1, d2];
    }

    turnHistory = [];
    phase = "move";

    var legalMoves = getAllLegalMoves(currentTurn, movesLeft);
    if (legalMoves.length === 0) {
        // No legal moves possible: pass turn immediately
        return { dice: dice, passed: true, movesLeft: [] };
    }

    return { dice: dice, passed: false, movesLeft: movesLeft };
}

function endTurn() {
    turnHistory = [];
    movesLeft = [];
    phase = "roll";
    currentTurn = (currentTurn === DARK) ? LIGHT : DARK;
}

function canBearOff(player) {
    if (bar[player] > 0) return false;
    var totalInHome = borneOff[player];

    if (player === LIGHT) {
        for (var p = 1; p <= 6; p++) {
            if (board[p].player === LIGHT) {
                totalInHome += board[p].count;
            }
        }
    } else {
        for (var p = 19; p <= 24; p++) {
            if (board[p].player === DARK) {
                totalInHome += board[p].count;
            }
        }
    }

    return totalInHome === 15;
}

function getLegalMovesForChecker(fromPoint, player, availMoves) {
    if (availMoves.length === 0) return [];

    var results = [];
    var opp = (player === DARK) ? LIGHT : DARK;
    var uniqueDice = [];
    for (var i = 0; i < availMoves.length; i++) {
        if (uniqueDice.indexOf(availMoves[i]) === -1) {
            uniqueDice.push(availMoves[i]);
        }
    }

    // 1. If player has checkers on the bar, ONLY bar checkers can move!
    if (bar[player] > 0) {
        if (fromPoint !== "bar") return [];

        for (var d = 0; d < uniqueDice.length; d++) {
            var die = uniqueDice[d];
            var entryPt = (player === DARK) ? die : (25 - die);

            if (board[entryPt].player !== opp || board[entryPt].count <= 1) {
                results.push({
                    from: "bar",
                    to: entryPt,
                    die: die,
                    hit: (board[entryPt].player === opp && board[entryPt].count === 1)
                });
            }
        }
        return results;
    }

    // 2. Regular point movement
    if (fromPoint === "bar") return [];
    if (board[fromPoint].player !== player || board[fromPoint].count <= 0) return [];

    var bearingAllowed = canBearOff(player);

    for (var d = 0; d < uniqueDice.length; d++) {
        var die = uniqueDice[d];
        var destPt = (player === DARK) ? (fromPoint + die) : (fromPoint - die);

        // Check regular destination within 1..24
        if (destPt >= 1 && destPt <= 24) {
            if (board[destPt].player !== opp || board[destPt].count <= 1) {
                results.push({
                    from: fromPoint,
                    to: destPt,
                    die: die,
                    hit: (board[destPt].player === opp && board[destPt].count === 1)
                });
            }
        }
        // Bearing off destination
        else if (bearingAllowed) {
            if (player === LIGHT && destPt <= 0) {
                // Exact roll bear off
                if (fromPoint === die) {
                    results.push({ from: fromPoint, to: "off", die: die, hit: false });
                }
                // Higher die bear off: allowed only if no friendly checkers on higher points (p > fromPoint up to 6)
                else if (die > fromPoint) {
                    var higherExists = false;
                    for (var p = fromPoint + 1; p <= 6; p++) {
                        if (board[p].player === LIGHT && board[p].count > 0) {
                            higherExists = true;
                            break;
                        }
                    }
                    if (!higherExists) {
                        results.push({ from: fromPoint, to: "off", die: die, hit: false });
                    }
                }
            } else if (player === DARK && destPt >= 25) {
                var dist = 25 - fromPoint;
                if (dist === die) {
                    results.push({ from: fromPoint, to: "off", die: die, hit: false });
                } else if (die > dist) {
                    var deeperExists = false;
                    for (var p = 19; p < fromPoint; p++) {
                        if (board[p].player === DARK && board[p].count > 0) {
                            deeperExists = true;
                            break;
                        }
                    }
                    if (!deeperExists) {
                        results.push({ from: fromPoint, to: "off", die: die, hit: false });
                    }
                }
            }
        }
    }

    return results;
}

function getAllLegalMoves(player, availMoves) {
    if (!availMoves || availMoves.length === 0) return [];
    var all = [];

    if (bar[player] > 0) {
        return getLegalMovesForChecker("bar", player, availMoves);
    }

    for (var p = 1; p <= 24; p++) {
        if (board[p].player === player && board[p].count > 0) {
            var moves = getLegalMovesForChecker(p, player, availMoves);
            for (var m = 0; m < moves.length; m++) {
                all.push(moves[m]);
            }
        }
    }
    return all;
}

function executeMove(from, to, dieVal, isSim) {
    if (phase !== "move") return { success: false, reason: "not_in_move_phase" };

    // Record turn snapshot for Undo (only if not a simulation)
    if (!isSim) {
        turnHistory.push(cloneState());
    }

    var player = currentTurn;
    var opp = (player === DARK) ? LIGHT : DARK;
    var wasHit = false;

    // Remove checker from source
    if (from === "bar") {
        bar[player]--;
    } else {
        board[from].count--;
        if (board[from].count === 0) {
            board[from].player = EMPTY;
        }
    }

    // Place checker at destination
    if (to === "off") {
        borneOff[player]++;
    } else {
        if (board[to].player === opp && board[to].count === 1) {
            // Hit blot!
            wasHit = true;
            board[to].player = player;
            board[to].count = 1;
            bar[opp]++;
        } else {
            board[to].player = player;
            board[to].count++;
        }
    }

    // Remove used die value from movesLeft
    var idx = movesLeft.indexOf(dieVal);
    if (idx !== -1) {
        movesLeft.splice(idx, 1);
    }

    // Check Victory
    if (borneOff[player] === 15) {
        phase = "gameover";
        winner = player;

        if (borneOff[opp] === 0) {
            if (bar[opp] > 0) {
                winType = "backgammon";
            } else {
                var inOppHome = false;
                if (player === DARK) {
                    for (var p = 19; p <= 24; p++) {
                        if (board[p].player === opp && board[p].count > 0) {
                            inOppHome = true;
                            break;
                        }
                    }
                } else {
                    for (var p = 1; p <= 6; p++) {
                        if (board[p].player === opp && board[p].count > 0) {
                            inOppHome = true;
                            break;
                        }
                    }
                }
                winType = inOppHome ? "backgammon" : "gammon";
            }
        } else {
            winType = "single";
        }

        return {
            success: true,
            hit: wasHit,
            gameOver: true,
            winner: winner,
            winType: winType
        };
    }

    // Check if more moves are possible
    var nextLegal = getAllLegalMoves(player, movesLeft);
    var turnFinished = (movesLeft.length === 0 || nextLegal.length === 0);

    if (turnFinished && !isSim) {
        endTurn();
    }

    return {
        success: true,
        hit: wasHit,
        gameOver: false,
        turnFinished: turnFinished,
        movesLeft: movesLeft
    };
}

function undoMove() {
    if (turnHistory.length === 0) return false;
    var prev = turnHistory.pop();
    restoreState(prev);
    return true;
}

function calculatePipCount(player) {
    var pips = 0;
    if (player === LIGHT) {
        pips += bar[LIGHT] * 25;
        for (var p = 1; p <= 24; p++) {
            if (board[p].player === LIGHT) {
                pips += board[p].count * p;
            }
        }
    } else {
        pips += bar[DARK] * 25;
        for (var p = 1; p <= 24; p++) {
            if (board[p].player === DARK) {
                pips += board[p].count * (25 - p);
            }
        }
    }
    return pips;
}

// =============================================================================
// AI MOVE GENERATOR & HEURISTIC EVALUATION
// =============================================================================

function evaluateBoardForAi(player) {
    var opp = (player === DARK) ? LIGHT : DARK;
    var score = 0;

    // 1. Borne off checkers (huge weight)
    score += borneOff[player] * 120;
    score -= borneOff[opp] * 120;

    // 2. Opponent on bar (huge advantage)
    score += bar[opp] * 80;
    score -= bar[player] * 90;

    // 3. Pip race advantage
    var myPips = calculatePipCount(player);
    var oppPips = calculatePipCount(opp);
    score += (oppPips - myPips) * 2;

    // 4. Anchors & Points made (points with >= 2 checkers)
    for (var p = 1; p <= 24; p++) {
        if (board[p].player === player) {
            if (board[p].count >= 2) {
                score += 15;
                // Home board points are extra valuable
                if (player === LIGHT && p <= 6) score += 20;
                if (player === DARK && p >= 19) score += 20;
            } else if (board[p].count === 1) {
                // Vulnerable blot penalty
                score -= 25;
                // Blots in opponent home are especially risky
                if (player === LIGHT && p >= 19) score -= 15;
                if (player === DARK && p <= 6) score -= 15;
            }
        }
    }

    return score;
}

function generateAllTurnSequences(player) {
    var sequences = [];
    var base = cloneState();

    function search(seqSoFar) {
        var legal = getAllLegalMoves(player, movesLeft);
        if (legal.length === 0 || movesLeft.length === 0) {
            if (seqSoFar.length > 0) {
                sequences.push({
                    moves: seqSoFar,
                    finalState: cloneState()
                });
            }
            return;
        }

        for (var i = 0; i < legal.length; i++) {
            var m = legal[i];
            var snap = cloneState();
            executeMove(m.from, m.to, m.die, true);
            search(seqSoFar.concat([m]));
            restoreState(snap);
        }
    }

    search([]);
    restoreState(base);
    return sequences;
}

function getBestAiTurn(difficulty) {
    if (phase !== "move") return [];

    var sequences = generateAllTurnSequences(currentTurn);
    if (sequences.length === 0) return [];

    var diff = difficulty || "casual";

    // 1. NOVICE: Random or basic blot hits
    if (diff === "novice") {
        if (Math.random() < 0.40) {
            return sequences[Math.floor(Math.random() * sequences.length)].moves;
        }
    }

    // Maximize dice used first (Backgammon rule of using max dice), then score
    var maxLen = 0;
    for (var i = 0; i < sequences.length; i++) {
        if (sequences[i].moves.length > maxLen) {
            maxLen = sequences[i].moves.length;
        }
    }

    var bestSeq = sequences[0].moves;
    var bestScore = -Infinity;
    var baseState = cloneState();

    for (var j = 0; j < sequences.length; j++) {
        var s = sequences[j];
        if (s.moves.length < maxLen) continue; // Must use maximum dice possible

        restoreState(s.finalState);
        var score = evaluateBoardForAi(currentTurn);

        // Add slight randomness in casual
        if (diff === "casual") {
            score += (Math.random() * 8) - 4;
        }

        if (score > bestScore) {
            bestScore = score;
            bestSeq = s.moves;
        }
    }

    restoreState(baseState);
    return bestSeq;
}
