// WordCircle Game Engine
// Pure JavaScript logic module (runs in QML JS engine)
.pragma library

var allLevels = [];
var currentLevelIndex = 0;
var currentLevel = null;

// Game state
var score = 0;
var highScore = 0;
var bonusCoins = 0;
var foundWords = [];       // List of target words found on crossword board
var foundBonusWords = [];  // List of bonus words found
var activeIndices = [];    // Array of indices in circle_letters currently selected
var activeWord = "";       // String of current selection
var circleLetters = [];    // Current arrangement of letters on the dial

// Transient feedback
var feedbackMessage = "";
var feedbackType = "";     // "success", "bonus", "info", "error"
var feedbackTimer = 0;
var isLevelComplete = false;
var levelCompleteTimer = 0;

var particles = [];

/**
 * Loads levels data from parsed JSON.
 */
function loadLevels(data) {
    if (data && data.levels && data.levels.length > 0) {
        allLevels = data.levels;
    } else {
        allLevels = [];
    }
}

var gridMatrix = [];      // 2D matrix of crossword cells for active puzzle

function buildGridMatrix() {
    if (!currentLevel || !currentLevel.words) {
        gridMatrix = [];
        return;
    }
    var rows = currentLevel.grid_rows || 1;
    var cols = currentLevel.grid_cols || 1;

    for (var i = 0; i < currentLevel.words.length; i++) {
        var w = currentLevel.words[i];
        var endR = (w.dir === "down") ? (w.row + w.word.length) : (w.row + 1);
        var endC = (w.dir === "across") ? (w.col + w.word.length) : (w.col + 1);
        if (endR > rows) rows = endR;
        if (endC > cols) cols = endC;
    }

    var mat = [];
    for (var r = 0; r < rows; r++) {
        var rowArr = [];
        for (var c = 0; c < cols; c++) {
            rowArr.push({
                active: false,
                char: "",
                found: false,
                wordRefs: []
            });
        }
        mat.push(rowArr);
    }

    for (var wi = 0; wi < currentLevel.words.length; wi++) {
        var item = currentLevel.words[wi];
        var wr = item.row;
        var wc = item.col;
        for (var k = 0; k < item.word.length; k++) {
            var cr = (item.dir === "down") ? (wr + k) : wr;
            var cc = (item.dir === "across") ? (wc + k) : wc;
            if (cr < rows && cc < cols) {
                mat[cr][cc].active = true;
                mat[cr][cc].char = item.word[k];
                if (mat[cr][cc].wordRefs.indexOf(item.word) === -1) {
                    mat[cr][cc].wordRefs.push(item.word);
                }
            }
        }
    }

    for (var r2 = 0; r2 < rows; r2++) {
        for (var c2 = 0; c2 < cols; c2++) {
            if (mat[r2][c2].active) {
                var cellFound = false;
                for (var f = 0; f < mat[r2][c2].wordRefs.length; f++) {
                    if (foundWords.indexOf(mat[r2][c2].wordRefs[f]) !== -1) {
                        cellFound = true;
                        break;
                    }
                }
                mat[r2][c2].found = cellFound;
            }
        }
    }

    gridMatrix = mat;
}

function loadSingleLevel(lvlData) {
    if (!lvlData) return;
    currentLevel = lvlData;
    foundWords = [];
    foundBonusWords = [];
    activeIndices = [];
    activeWord = "";
    isLevelComplete = false;
    levelCompleteTimer = 0;
    feedbackMessage = "";
    circleLetters = currentLevel.circle_letters.slice();
    buildGridMatrix();
}

/**
 * Initializes engine and loads specified level.
 */
function init(levelIdx) {
    if (allLevels.length === 0) return;
    currentLevelIndex = Math.max(0, Math.min(levelIdx, allLevels.length - 1));
    startLevel(currentLevelIndex);
}

function getLevelData(idx) {
    if (!allLevels || idx < 0 || idx >= allLevels.length) return null;
    return allLevels[idx];
}

/**
 * Starts a specific level.
 */
function startLevel(idx) {
    if (!allLevels || allLevels.length === 0) return;
    currentLevelIndex = Math.max(0, Math.min(idx, allLevels.length - 1));
    currentLevel = allLevels[currentLevelIndex];

    foundWords = [];
    foundBonusWords = [];
    activeIndices = [];
    activeWord = "";
    isLevelComplete = false;
    levelCompleteTimer = 0;
    feedbackMessage = "";

    // Copy circle letters
    circleLetters = currentLevel.circle_letters.slice();
    buildGridMatrix();
}

/**
 * Shuffles letters around the circular dial.
 */
function shuffleLetters() {
    if (!circleLetters || circleLetters.length <= 1) return;
    var arr = circleLetters.slice();
    for (var i = arr.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }
    circleLetters = arr;
    // Clear active selection on shuffle
    activeIndices = [];
    activeWord = "";
}

/**
 * Tries to add a letter node index to the active swipe path.
 */
function selectIndex(idx, callbacks) {
    if (isLevelComplete) return false;
    if (idx < 0 || idx >= circleLetters.length) return false;

    // If already in path:
    // If it's the second to last index, backtrack (undo last letter)
    if (activeIndices.length >= 2 && activeIndices[activeIndices.length - 2] === idx) {
        activeIndices.pop();
        updateActiveWord();
        if (callbacks && callbacks.onSound) callbacks.onSound("step");
        return true;
    }

    // If already selected elsewhere, ignore
    if (activeIndices.indexOf(idx) !== -1) {
        return false;
    }

    activeIndices.push(idx);
    updateActiveWord();
    if (callbacks && callbacks.onSound) callbacks.onSound("click");
    return true;
}

/**
 * Keyboard input helper: types a letter if available on the dial.
 */
function typeChar(ch, callbacks) {
    if (isLevelComplete) return false;
    var upper = ch.toUpperCase();
    for (var i = 0; i < circleLetters.length; i++) {
        if (circleLetters[i] === upper && activeIndices.indexOf(i) === -1) {
            activeIndices.push(i);
            updateActiveWord();
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
            return true;
        }
    }
    return false;
}

/**
 * Backspaces / removes last selected letter.
 */
function backspace(callbacks) {
    if (activeIndices.length > 0) {
        activeIndices.pop();
        updateActiveWord();
        if (callbacks && callbacks.onSound) callbacks.onSound("step");
        return true;
    }
    return false;
}

function updateActiveWord() {
    var str = "";
    for (var i = 0; i < activeIndices.length; i++) {
        str += circleLetters[activeIndices[i]];
    }
    activeWord = str;
}

function clearSelection() {
    activeIndices = [];
    activeWord = "";
}

/**
 * Submits the current active word.
 */
function submitWord(callbacks) {
    if (!currentLevel || activeWord.length < 2 || isLevelComplete) {
        clearSelection();
        return;
    }

    var word = activeWord.toUpperCase();
    var isTarget = false;
    var targetList = currentLevel.words || [];

    for (var i = 0; i < targetList.length; i++) {
        if (targetList[i].word === word) {
            isTarget = true;
            break;
        }
    }

    // 1. Target Crossword Word
    if (isTarget) {
        if (foundWords.indexOf(word) !== -1) {
            // Already found
            setFeedback("Already found: " + word, "info");
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
        } else {
            // New word found!
            foundWords.push(word);
            buildGridMatrix();
            var pts = word.length * 10;
            score += pts;
            if (score > highScore) highScore = score;

            setFeedback("+" + pts + " " + word + "!", "success");
            if (callbacks && callbacks.onSound) callbacks.onSound("target");
            if (callbacks && callbacks.onScore) callbacks.onScore(score);

            // Spawn celebration particles
            spawnParticles(35, "#38bdf8");

            // Check if level complete
            if (foundWords.length >= targetList.length) {
                isLevelComplete = true;
                levelCompleteTimer = 1.8; // seconds until auto next
                score += 50; // Level bonus
                if (score > highScore) highScore = score;
                setFeedback("LEVEL COMPLETE!", "success");
                spawnParticles(80, "#22c55e");
                if (callbacks && callbacks.onSound) callbacks.onSound("win");
                if (callbacks && callbacks.onLevelComplete) callbacks.onLevelComplete(currentLevelIndex + 1);
            }
        }
    }
    // 2. Bonus Word
    else if (currentLevel.bonus_words && currentLevel.bonus_words.indexOf(word) !== -1) {
        if (foundBonusWords.indexOf(word) !== -1) {
            setFeedback("Already in bonus jar: " + word, "info");
            if (callbacks && callbacks.onSound) callbacks.onSound("click");
        } else {
            foundBonusWords.push(word);
            bonusCoins += 1;
            score += 25;
            if (score > highScore) highScore = score;
            setFeedback("Bonus Word! " + word + " (+25)", "bonus");
            spawnParticles(25, "#f59e0b");
            if (callbacks && callbacks.onSound) callbacks.onSound("push");
            if (callbacks && callbacks.onScore) callbacks.onScore(score);
        }
    }
    // 3. Invalid / Not in puzzle
    else {
        if (word.length >= 3) {
            setFeedback("Not in puzzle", "error");
            if (callbacks && callbacks.onSound) callbacks.onSound("undo");
        }
    }

    clearSelection();
}

function setFeedback(msg, type) {
    feedbackMessage = msg;
    feedbackType = type;
    feedbackTimer = 2.0;
}

/**
 * Particle system for confetti / spark animations.
 */
function spawnParticles(count, color) {
    for (var i = 0; i < count; i++) {
        var angle = Math.random() * Math.PI * 2;
        var speed = 80 + Math.random() * 240;
        particles.push({
            x: 0,
            y: 0,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed - 60,
            size: 3 + Math.random() * 5,
            color: color || "#38bdf8",
            alpha: 1.0,
            life: 0.8 + Math.random() * 0.6
        });
    }
}

/**
 * Frame update loop (~60 FPS).
 */
function update(dt, callbacks) {
    // Update feedback timer
    if (feedbackTimer > 0) {
        feedbackTimer -= dt;
        if (feedbackTimer <= 0) {
            feedbackMessage = "";
        }
    }

    // Update level complete countdown
    if (isLevelComplete && levelCompleteTimer > 0) {
        levelCompleteTimer -= dt;
        if (levelCompleteTimer <= 0) {
            // Auto advance to next level
            if (currentLevelIndex < allLevels.length - 1) {
                startLevel(currentLevelIndex + 1);
            }
        }
    }

    // Update particles
    for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += 220 * dt; // gravity
        p.life -= dt;
        p.alpha = Math.max(0, p.life / 1.2);
        if (p.life <= 0) {
            particles.splice(i, 1);
        }
    }
}
