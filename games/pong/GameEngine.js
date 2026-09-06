// Pong Game Engine (Pure Deterministic JavaScript)

.pragma library

var COURT_WIDTH = 640;
var COURT_HEIGHT = 480;

var PADDLE_W = 14;
var PADDLE_H = 76;
var PADDLE_SPEED = 7.5;
var BALL_RADIUS = 7;
var INITIAL_BALL_SPEED = 5.5;

var p1 = { x: 24, y: 202, vy: 0 };
var p2 = { x: 602, y: 202, vy: 0 };
var ball = { x: 320, y: 240, vx: 5.5, vy: 2.0, speed: 5.5 };

var score1 = 0;
var score2 = 0;
var maxScore = 11;
var isOver = false;
var mode = "1P"; // "1P" vs AI or "2P"
var difficulty = "Pro"; // "Novice", "Pro", "Master"
var rallyCount = 0;

function initGame(gameMode, aiDiff) {
    if (gameMode) mode = gameMode;
    if (aiDiff) difficulty = aiDiff;
    score1 = 0;
    score2 = 0;
    isOver = false;
    rallyCount = 0;

    resetPaddles();
    resetBall(1);
}

function resetPaddles() {
    p1.y = (COURT_HEIGHT - PADDLE_H) / 2;
    p1.vy = 0;
    p2.y = (COURT_HEIGHT - PADDLE_H) / 2;
    p2.vy = 0;
}

function resetBall(direction) {
    ball.x = COURT_WIDTH / 2;
    ball.y = COURT_HEIGHT / 2;
    ball.speed = INITIAL_BALL_SPEED;

    var angle = (Math.random() * 0.8 - 0.4); // angle between -0.4 and +0.4 rad (~23 deg)
    var dir = direction >= 0 ? 1 : -1;
    ball.vx = dir * ball.speed * Math.cos(angle);
    ball.vy = ball.speed * Math.sin(angle);
    rallyCount = 0;
}

function setP1Movement(dir) {
    // dir: -1 (up), 0 (stop), 1 (down)
    p1.vy = dir * PADDLE_SPEED;
}

function setP2Movement(dir) {
    p2.vy = dir * PADDLE_SPEED;
}

function updateAI() {
    if (mode !== "1P") return;

    var aiTargetY = ball.y - PADDLE_H / 2;
    var speedLimit = PADDLE_SPEED;
    var reactionDistance = COURT_WIDTH * 0.75;

    if (difficulty === "Novice") {
        speedLimit = PADDLE_SPEED * 0.58;
        reactionDistance = COURT_WIDTH * 0.5;
        // add slight tracking jitter
        aiTargetY += Math.sin(Date.now() * 0.005) * 25;
    } else if (difficulty === "Pro") {
        speedLimit = PADDLE_SPEED * 0.82;
        reactionDistance = COURT_WIDTH * 0.70;
    } else if (difficulty === "Master") {
        speedLimit = PADDLE_SPEED * 0.98;
        reactionDistance = COURT_WIDTH * 0.90;
    }

    if (ball.vx > 0 && ball.x > COURT_WIDTH - reactionDistance) {
        var diff = aiTargetY - p2.y;
        if (Math.abs(diff) > 6) {
            p2.vy = Math.sign(diff) * Math.min(Math.abs(diff), speedLimit);
        } else {
            p2.vy = 0;
        }
    } else {
        // Return slowly to center
        var centerDiff = (COURT_HEIGHT - PADDLE_H) / 2 - p2.y;
        if (Math.abs(centerDiff) > 10) {
            p2.vy = Math.sign(centerDiff) * 2.0;
        } else {
            p2.vy = 0;
        }
    }
}

function tick() {
    if (isOver) return { scored: false, hitPaddle: false, hitWall: false, over: true };

    updateAI();

    // Move paddles
    p1.y = Math.max(8, Math.min(COURT_HEIGHT - PADDLE_H - 8, p1.y + p1.vy));
    p2.y = Math.max(8, Math.min(COURT_HEIGHT - PADDLE_H - 8, p2.y + p2.vy));

    // Move ball
    ball.x += ball.vx;
    ball.y += ball.vy;

    var hitWall = false;
    var hitPaddle = false;
    var scored = false;
    var scorer = 0;

    // Top / Bottom Wall Collisions
    if (ball.y - BALL_RADIUS <= 6) {
        ball.y = 6 + BALL_RADIUS;
        ball.vy = Math.abs(ball.vy);
        hitWall = true;
    } else if (ball.y + BALL_RADIUS >= COURT_HEIGHT - 6) {
        ball.y = COURT_HEIGHT - 6 - BALL_RADIUS;
        ball.vy = -Math.abs(ball.vy);
        hitWall = true;
    }

    // Paddle 1 Collision (Left)
    if (ball.vx < 0 &&
        ball.x - BALL_RADIUS <= p1.x + PADDLE_W &&
        ball.x + BALL_RADIUS >= p1.x &&
        ball.y >= p1.y - BALL_RADIUS &&
        ball.y <= p1.y + PADDLE_H + BALL_RADIUS) {
        
        hitPaddle = true;
        rallyCount++;
        ball.speed = Math.min(13.0, INITIAL_BALL_SPEED + rallyCount * 0.35);

        // Calculate bounce angle based on point of contact (-1 at top, 0 at center, +1 at bottom)
        var hitPos = (ball.y - (p1.y + PADDLE_H / 2)) / (PADDLE_H / 2);
        hitPos = Math.max(-1.0, Math.min(1.0, hitPos));
        var bounceAngle = hitPos * (Math.PI * 0.35); // max 63 degrees deflection

        ball.vx = Math.abs(ball.speed * Math.cos(bounceAngle));
        ball.vy = ball.speed * Math.sin(bounceAngle);
        ball.x = p1.x + PADDLE_W + BALL_RADIUS;
    }

    // Paddle 2 Collision (Right)
    if (ball.vx > 0 &&
        ball.x + BALL_RADIUS >= p2.x &&
        ball.x - BALL_RADIUS <= p2.x + PADDLE_W &&
        ball.y >= p2.y - BALL_RADIUS &&
        ball.y <= p2.y + PADDLE_H + BALL_RADIUS) {
        
        hitPaddle = true;
        rallyCount++;
        ball.speed = Math.min(13.0, INITIAL_BALL_SPEED + rallyCount * 0.35);

        var hitPos2 = (ball.y - (p2.y + PADDLE_H / 2)) / (PADDLE_H / 2);
        hitPos2 = Math.max(-1.0, Math.min(1.0, hitPos2));
        var bounceAngle2 = hitPos2 * (Math.PI * 0.35);

        ball.vx = -Math.abs(ball.speed * Math.cos(bounceAngle2));
        ball.vy = ball.speed * Math.sin(bounceAngle2);
        ball.x = p2.x - BALL_RADIUS;
    }

    // Goal Scoring
    if (ball.x < -10) { // Player 2 scores
        score2++;
        scored = true;
        scorer = 2;
        if (score2 >= maxScore) {
            isOver = true;
        } else {
            resetBall(1); // Serve towards P1
        }
    } else if (ball.x > COURT_WIDTH + 10) { // Player 1 scores
        score1++;
        scored = true;
        scorer = 1;
        if (score1 >= maxScore) {
            isOver = true;
        } else {
            resetBall(-1); // Serve towards P2
        }
    }

    return {
        scored: scored,
        scorer: scorer,
        hitPaddle: hitPaddle,
        hitWall: hitWall,
        over: isOver
    };
}

function getState() {
    return {
        width: COURT_WIDTH,
        height: COURT_HEIGHT,
        paddleW: PADDLE_W,
        paddleH: PADDLE_H,
        ballRadius: BALL_RADIUS,
        p1: p1,
        p2: p2,
        ball: ball,
        score1: score1,
        score2: score2,
        maxScore: maxScore,
        isOver: isOver,
        mode: mode,
        difficulty: difficulty,
        rallyCount: rallyCount
    };
}
