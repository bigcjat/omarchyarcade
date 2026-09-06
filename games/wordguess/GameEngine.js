.pragma library

var TARGET_WORDS = [
    "ABOUT", "ABOVE", "ACTOR", "ACUTE", "ADAPT", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN",
    "AGENT", "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIKE", "ALIVE", "ALLOW", "ALONE",
    "ALONG", "ALTER", "AMONG", "ANGER", "ANGLE", "ANGRY", "APART", "APPLE", "APPLY", "ARENA",
    "ARGUE", "ARISE", "ARMOR", "ARRAY", "ARROW", "ASIDE", "ASSET", "AUDIO", "AUDIT", "AVOID",
    "AWAIT", "AWAKE", "AWARD", "AWARE", "BADGE", "BASIC", "BASIS", "BEACH", "BEAST", "BEGAN",
    "BEGIN", "BEING", "BELOW", "BENCH", "BIRTH", "BLACK", "BLADE", "BLAME", "BLANK", "BLAST",
    "BLAZE", "BLEED", "BLEND", "BLESS", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BOARD", "BOAST",
    "BOOST", "BOOTH", "BOUND", "BRAIN", "BRAND", "BREAD", "BREAK", "BREED", "BRIEF", "BRING",
    "BROAD", "BROKE", "BROWN", "BUILD", "BUILT", "BUYER", "CABLE", "CALIF", "CARRY", "CATCH",
    "CAUSE", "CHAIN", "CHAIR", "CHART", "CHASE", "CHEAP", "CHECK", "CHEST", "CHIEF", "CHILD",
    "CHINA", "CHOSE", "CIVIL", "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLICK", "CLOCK", "CLOSE",
    "CLOUD", "COACH", "COAST", "COUNT", "COURT", "COVER", "CRAFT", "CRANE", "CRASH", "CRAZY",
    "CREAM", "CRIME", "CROSS", "CROWD", "CROWN", "CRUDE", "CURVE", "CYCLE", "DAILY", "DANCE",
    "DATED", "DEALT", "DEATH", "DEBUT", "DELAY", "DEPTH", "DIRTY", "DISCO", "DOUBT", "DOZEN",
    "DRAFT", "DRAIN", "DRAMA", "DRANK", "DRAWN", "DREAM", "DRESS", "DRIFT", "DRINK", "DRIVE",
    "DROVE", "DYING", "EAGER", "EARLY", "EARTH", "EIGHT", "ELITE", "EMPTY", "ENEMY", "ENJOY",
    "ENTER", "ENTRY", "EQUAL", "ERROR", "EVENT", "EVERY", "EXACT", "EXIST", "EXTRA", "FAINT",
    "FAITH", "FALSE", "FAULT", "FIBER", "FIELD", "FIFTH", "FIFTY", "FIGHT", "FINAL", "FIRST",
    "FIXED", "FLAME", "FLASH", "FLEET", "FLOOR", "FLUID", "FOCUS", "FORCE", "FORTH", "FORTY",
    "FORUM", "FOUND", "FRAME", "FRAUD", "FRESH", "FRONT", "FRUIT", "FULLY", "GIANT", "GIVEN",
    "GLASS", "GLOBE", "GLORY", "GRACE", "GRADE", "GRAND", "GRANT", "GRAPE", "GRASP", "GRASS",
    "GRAVE", "GREAT", "GREEN", "GREET", "GRIEF", "GRILL", "GROSS", "GROUP", "GROWN", "GUARD",
    "GUESS", "GUEST", "GUIDE", "HABIT", "HAPPY", "HARSH", "HEART", "HEAVY", "HONOR", "HORSE",
    "HOTEL", "HOUSE", "HUMAN", "IDEAL", "IMAGE", "IMPLY", "INDEX", "INNER", "INPUT", "ISSUE",
    "JAPAN", "JOINT", "JUDGE", "JUICE", "KNIFE", "KNOCK", "KNOWN", "LABEL", "LABOR", "LARGE",
    "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE", "LEAST", "LEAVE", "LEGAL", "LEMON",
    "LEVEL", "LEVER", "LIGHT", "LIMIT", "LINKS", "LIVES", "LOCAL", "LOGIC", "LOOSE", "LOWER",
    "LUCKY", "LUNCH", "MAGIC", "MAJOR", "MAKER", "MARCH", "MATCH", "MAYBE", "MAYOR", "METAL",
    "METER", "MIDST", "MIGHT", "MINOR", "MINUS", "MIXED", "MODEL", "MODEM", "MONEY", "MONTH",
    "MORAL", "MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVIE", "MUSIC", "NEEDS", "NEVER", "NIGHT",
    "NOBLE", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCCUR", "OCEAN", "OFFER", "OFTEN",
    "ORDER", "OTHER", "OUGHT", "PAINT", "PANEL", "PAPER", "PARTY", "PEACE", "PETER", "PHASE",
    "PHONE", "PHOTO", "PIECE", "PILOT", "PITCH", "PLACE", "PLAIN", "PLANE", "PLANT", "PLATE",
    "POINT", "POUND", "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT", "PRIOR", "PRIZE",
    "PROUD", "PROVE", "QUEEN", "QUICK", "QUIET", "QUITE", "RADIO", "RAISE", "RANGE", "RAPID",
    "RATIO", "REACH", "READY", "REFER", "RIGHT", "RIVAL", "RIVER", "ROBOT", "ROMAN", "ROUGH",
    "ROUND", "ROUTE", "ROYAL", "RURAL", "SCALE", "SCENE", "SCOPE", "SCORE", "SENSE", "SERVE",
    "SEVEN", "SHALL", "SHAPE", "SHARE", "SHARP", "SHEET", "SHELF", "SHELL", "SHIFT", "SHINE",
    "SHIRT", "SHOCK", "SHOOT", "SHORT", "SHOWN", "SIGHT", "SINCE", "SIXTH", "SIXTY", "SIZED",
    "SKILL", "SLEEP", "SLIDE", "SMALL", "SMART", "SMILE", "SMOKE", "SOLID", "SOLVE", "SORRY",
    "SOUND", "SOUTH", "SPACE", "SPARE", "SPEAK", "SPEED", "SPEND", "SPENT", "SPLIT", "SPOKE",
    "SPORT", "STAFF", "STAGE", "STAKE", "STAND", "START", "STATE", "STEAM", "STEEL", "STICK",
    "STILL", "STOCK", "STONE", "STOOD", "STORE", "STORM", "STORY", "STRIP", "STUDY", "STYLE",
    "SUGAR", "SUITE", "SUPER", "SWEET", "TABLE", "TAKEN", "TASTE", "TAXES", "TEACH", "TEETH",
    "TERRY", "TEXAS", "THANK", "THEFT", "THEIR", "THEME", "THERE", "THESE", "THICK", "THING",
    "THINK", "THIRD", "THOSE", "THREE", "THREW", "THROW", "TIGHT", "TIMES", "TIRED", "TITLE",
    "TODAY", "TOPIC", "TOTAL", "TOUCH", "TOUGH", "TOWER", "TRACK", "TRADE", "TRAIN", "TREAT",
    "TREND", "TRIAL", "TRIED", "TRIES", "TRUCK", "TRULY", "TRUST", "TRUTH", "TWICE", "UNDER",
    "UNDUE", "UNION", "UNITY", "UNTIL", "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID",
    "VALUE", "VIDEO", "VIRUS", "VISIT", "VITAL", "VOICE", "WASTE", "WATCH", "WATER", "WHEEL",
    "WHERE", "WHICH", "WHILE", "WHITE", "WHOLE", "WHOSE", "WOMAN", "WOMEN", "WORLD", "WORRY",
    "WORSE", "WORST", "WORTH", "WOULD", "WOUND", "WRITE", "WRONG", "WROTE", "YIELD", "YOUNG",
    "YOUTH", "ZEBRA"
];

var targetWord = "";
var board = [];
var currentRow = 0;
var currentCol = 0;
var keyboardStatus = {};
var gameState = "playing"; // "playing", "won", "lost"
var shakeRow = -1;

function init() {
    resetGame();
}

function resetGame() {
    targetWord = TARGET_WORDS[Math.floor(Math.random() * TARGET_WORDS.length)];
    board = [];
    for (var r = 0; r < 6; r++) {
        var row = [];
        for (var c = 0; c < 5; c++) {
            row.push({ letter: "", status: "empty" });
        }
        board.push(row);
    }
    currentRow = 0;
    currentCol = 0;
    keyboardStatus = {};
    gameState = "playing";
    shakeRow = -1;
}

function addLetter(letter, callbacks) {
    if (gameState !== "playing" || currentCol >= 5) return;
    board[currentRow][currentCol].letter = letter.toUpperCase();
    board[currentRow][currentCol].status = "tbd";
    currentCol++;
    if (callbacks && callbacks.onSound) callbacks.onSound("key");
}

function deleteLetter(callbacks) {
    if (gameState !== "playing" || currentCol <= 0) return;
    currentCol--;
    board[currentRow][currentCol].letter = "";
    board[currentRow][currentCol].status = "empty";
    if (callbacks && callbacks.onSound) callbacks.onSound("key");
}

function submitGuess(callbacks) {
    if (gameState !== "playing") return;
    if (currentCol < 5) {
        // Incomplete word
        shakeRow = currentRow;
        if (callbacks && callbacks.onSound) callbacks.onSound("error");
        return;
    }

    var guess = "";
    for (var c = 0; c < 5; c++) {
        guess += board[currentRow][c].letter;
    }

    // Evaluate against target word
    var targetLetters = targetWord.split("");
    var guessLetters = guess.split("");
    var resultStatus = ["absent", "absent", "absent", "absent", "absent"];

    // First pass: mark correct (exact matches)
    for (var i = 0; i < 5; i++) {
        if (guessLetters[i] === targetLetters[i]) {
            resultStatus[i] = "correct";
            targetLetters[i] = null;
        }
    }

    // Second pass: mark present
    for (var j = 0; j < 5; j++) {
        if (resultStatus[j] !== "correct") {
            var matchIdx = targetLetters.indexOf(guessLetters[j]);
            if (matchIdx !== -1) {
                resultStatus[j] = "present";
                targetLetters[matchIdx] = null;
            }
        }
    }

    // Update board and keyboard map
    var allCorrect = true;
    for (var k = 0; k < 5; k++) {
        var stat = resultStatus[k];
        board[currentRow][k].status = stat;
        if (stat !== "correct") allCorrect = false;

        var char = guessLetters[k];
        // Don't downgrade correct to present
        if (keyboardStatus[char] !== "correct") {
            if (stat === "correct" || keyboardStatus[char] !== "present") {
                keyboardStatus[char] = stat;
            }
        }
    }

    if (callbacks && callbacks.onSound) callbacks.onSound("flip");

    if (allCorrect) {
        gameState = "won";
        if (callbacks && callbacks.onSound) callbacks.onSound("win");
        if (callbacks && callbacks.onGameOver) callbacks.onGameOver(true);
        return;
    }

    currentRow++;
    currentCol = 0;

    if (currentRow >= 6) {
        gameState = "lost";
        if (callbacks && callbacks.onSound) callbacks.onSound("lose");
        if (callbacks && callbacks.onGameOver) callbacks.onGameOver(false);
    }
}
