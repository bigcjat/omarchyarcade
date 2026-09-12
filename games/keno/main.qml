import QtQuick
import QtQuick.Window
import "KenoEngine.js" as Engine
import "Themes.js" as Themes

Window {
    id: root
    visible: true
    width: 1024
    height: 720
    minimumWidth: 460
    minimumHeight: 460
    title: "VLT Keno • 8-in-1 Casino Terminal"

    // =========================================================================
    // VISUAL THEMES (Authentic Casino & VLT Styles)
    // 3 Curated High-End Visual Themes:
    // 1. "bartop" -> Vegas Bar-top VLT (Deep midnight obsidian + ultraviolet neon + 3D cherry red tiles)
    // 2. "ekeno"  -> Modern e-Keno Blue Glass & Bubble Tumbler
    // =========================================================================
    // GAMEPLAY & 8-IN-1 GAME THEMES
    // 1. "classic"     -> Retro Vegas Midnight Obsidian & Sapphire Blue Neon
    // 2. "power"       -> Cyberpunk Ultraviolet Abyss & Lightning Fuchsia Glow
    // 3. "super"       -> Royal Monte Carlo Mahogany & Bullion 24K Gold
    // 4. "cleopatra"   -> Egyptian Tomb Turquoise & Scarab Emerald
    // 5. "caveman"     -> Jurassic Volcanic Jungle & Amber Lava Eggs
    // 6. "extradraw"   -> Obsidian Brushed Steel & Red Alert Emergency Sirens
    // 7. "goldmine"    -> 1849 Gold Rush Mine Shaft & Sparkling Raw Nuggets
    // 8. "triplepower" -> Quantum Cyan Plasma Reactor & Arc Containment
    // =========================================================================
    property string activeVariant: "classic"

    // Dynamic Game Theme Color Tokens
    property color themeBg: activeVariant === "classic" ? "#070914" :
                            activeVariant === "power" ? "#0c0517" :
                            activeVariant === "super" ? "#120902" :
                            activeVariant === "cleopatra" ? "#120a03" :
                            activeVariant === "caveman" ? "#0e1307" :
                            activeVariant === "extradraw" ? "#150407" :
                            activeVariant === "goldmine" ? "#140e04" : "#04131d"

    property color themeBoardBg: activeVariant === "classic" ? "#0b0f22" :
                                 activeVariant === "power" ? "#15082b" :
                                 activeVariant === "super" ? "#1a0f04" :
                                 activeVariant === "cleopatra" ? "#1a1005" :
                                 activeVariant === "caveman" ? "#151b0a" :
                                 activeVariant === "extradraw" ? "#1c050a" :
                                 activeVariant === "goldmine" ? "#1d1406" : "#081e2e"

    property color themeCardBg: activeVariant === "classic" ? "#10162e" :
                                activeVariant === "power" ? "#220c42" :
                                activeVariant === "super" ? "#281706" :
                                activeVariant === "cleopatra" ? "#261708" :
                                activeVariant === "caveman" ? "#20290e" :
                                activeVariant === "extradraw" ? "#2d0711" :
                                activeVariant === "goldmine" ? "#2b1d0a" : "#0c2b42"

    property color themeBorder: activeVariant === "classic" ? "#1d4ed8" :
                                activeVariant === "power" ? "#9333ea" :
                                activeVariant === "super" ? "#b45309" :
                                activeVariant === "cleopatra" ? "#d97706" :
                                activeVariant === "caveman" ? "#84cc16" :
                                activeVariant === "extradraw" ? "#ef4444" :
                                activeVariant === "goldmine" ? "#eab308" : "#06b6d4"

    property color themeFg: activeVariant === "classic" ? "#ffffff" :
                            activeVariant === "power" ? "#fdf4ff" :
                            activeVariant === "super" ? "#fffbeb" :
                            activeVariant === "cleopatra" ? "#fffbeb" :
                            activeVariant === "caveman" ? "#f7fee7" :
                            activeVariant === "extradraw" ? "#fff1f2" :
                            activeVariant === "goldmine" ? "#fefce8" : "#ecfeff"

    property color themeSubtext: activeVariant === "classic" ? "#94a3b8" :
                                 activeVariant === "power" ? "#d8b4fe" :
                                 activeVariant === "super" ? "#fde68a" :
                                 activeVariant === "cleopatra" ? "#fde68a" :
                                 activeVariant === "caveman" ? "#bef264" :
                                 activeVariant === "extradraw" ? "#fca5a5" :
                                 activeVariant === "goldmine" ? "#fef08a" : "#67e8f9"

    property color themeAccent: activeVariant === "classic" ? "#38bdf8" :
                                activeVariant === "power" ? "#c084fc" :
                                activeVariant === "super" ? "#fbbf24" :
                                activeVariant === "cleopatra" ? "#2dd4bf" :
                                activeVariant === "caveman" ? "#a3e635" :
                                activeVariant === "extradraw" ? "#f87171" :
                                activeVariant === "goldmine" ? "#fde047" : "#22d3ee"

    property color themeMarked: activeVariant === "classic" ? "#ef4444" :
                                activeVariant === "power" ? "#e879f9" :
                                activeVariant === "super" ? "#f97316" :
                                activeVariant === "cleopatra" ? "#06b6d4" :
                                activeVariant === "caveman" ? "#ea580c" :
                                activeVariant === "extradraw" ? "#dc2626" :
                                activeVariant === "goldmine" ? "#d97706" : "#0284c7"

    property color themeMarkedDark: activeVariant === "classic" ? "#991b1b" :
                                    activeVariant === "power" ? "#86198f" :
                                    activeVariant === "super" ? "#9a3412" :
                                    activeVariant === "cleopatra" ? "#0e7490" :
                                    activeVariant === "caveman" ? "#7c2d12" :
                                    activeVariant === "extradraw" ? "#7f1d1d" :
                                    activeVariant === "goldmine" ? "#78350f" : "#0369a1"

    property color themeHit: activeVariant === "classic" ? "#fbbf24" :
                             activeVariant === "power" ? "#facc15" :
                             activeVariant === "super" ? "#fef08a" :
                             activeVariant === "cleopatra" ? "#fbbf24" :
                             activeVariant === "caveman" ? "#facc15" :
                             activeVariant === "extradraw" ? "#fef08a" :
                             activeVariant === "goldmine" ? "#fde047" : "#a5f3fc"

    property color themeTileBg: activeVariant === "classic" ? "#141c30" :
                                activeVariant === "power" ? "#1c0d38" :
                                activeVariant === "super" ? "#241406" :
                                activeVariant === "cleopatra" ? "#26180a" :
                                activeVariant === "caveman" ? "#1c240c" :
                                activeVariant === "extradraw" ? "#27080f" :
                                activeVariant === "goldmine" ? "#241605" : "#092438"

    property color themeTileBgDark: activeVariant === "classic" ? "#0a0e1a" :
                                    activeVariant === "power" ? "#100620" :
                                    activeVariant === "super" ? "#150a02" :
                                    activeVariant === "cleopatra" ? "#140c04" :
                                    activeVariant === "caveman" ? "#0f1505" :
                                    activeVariant === "extradraw" ? "#150307" :
                                    activeVariant === "goldmine" ? "#140a02" : "#041420"

    property color themeTileHover: activeVariant === "classic" ? "#253356" :
                                   activeVariant === "power" ? "#32165e" :
                                   activeVariant === "super" ? "#3c210b" :
                                   activeVariant === "cleopatra" ? "#3c2912" :
                                   activeVariant === "caveman" ? "#2e3b14" :
                                   activeVariant === "extradraw" ? "#450a17" :
                                   activeVariant === "goldmine" ? "#3a2208" : "#0f3654"

    property color themeTileHoverDark: activeVariant === "classic" ? "#18223c" :
                                       activeVariant === "power" ? "#210d3f" :
                                       activeVariant === "super" ? "#291605" :
                                       activeVariant === "cleopatra" ? "#241808" :
                                       activeVariant === "caveman" ? "#1e280c" :
                                       activeVariant === "extradraw" ? "#2a050e" :
                                       activeVariant === "goldmine" ? "#261504" : "#082338"

    property color themeTileDrawn: activeVariant === "classic" ? "#1e3a8a" :
                                   activeVariant === "power" ? "#3b0764" :
                                   activeVariant === "super" ? "#451a03" :
                                   activeVariant === "cleopatra" ? "#0d4c4c" :
                                   activeVariant === "caveman" ? "#365314" :
                                   activeVariant === "extradraw" ? "#7f1d1d" :
                                   activeVariant === "goldmine" ? "#713f12" : "#0e7490"

    property color themeTileDrawnDark: activeVariant === "classic" ? "#0f172a" :
                                       activeVariant === "power" ? "#1e0436" :
                                       activeVariant === "super" ? "#1a0800" :
                                       activeVariant === "cleopatra" ? "#062828" :
                                       activeVariant === "caveman" ? "#1a2e05" :
                                       activeVariant === "extradraw" ? "#450a0a" :
                                       activeVariant === "goldmine" ? "#422006" : "#083344"

    property color themeNeonLeft: activeVariant === "classic" ? "#2563eb" :
                                  activeVariant === "power" ? "#9333ea" :
                                  activeVariant === "super" ? "#d97706" :
                                  activeVariant === "cleopatra" ? "#f59e0b" :
                                  activeVariant === "caveman" ? "#84cc16" :
                                  activeVariant === "extradraw" ? "#ef4444" :
                                  activeVariant === "goldmine" ? "#eab308" : "#06b6d4"

    property color themeNeonRight: activeVariant === "classic" ? "#38bdf8" :
                                   activeVariant === "power" ? "#e879f9" :
                                   activeVariant === "super" ? "#fde047" :
                                   activeVariant === "cleopatra" ? "#2dd4bf" :
                                   activeVariant === "caveman" ? "#f59e0b" :
                                   activeVariant === "extradraw" ? "#f43f5e" :
                                   activeVariant === "goldmine" ? "#f59e0b" : "#38bdf8"

    property string themeGameIcon: activeVariant === "classic" ? "🎲" :
                                   activeVariant === "power" ? "⚡" :
                                   activeVariant === "super" ? "👑" :
                                   activeVariant === "cleopatra" ? "🏺" :
                                   activeVariant === "caveman" ? "🦕" :
                                   activeVariant === "extradraw" ? "🚨" :
                                   activeVariant === "goldmine" ? "⛏️" : "⚛"

    property string themeGameSubtitle: activeVariant === "classic" ? "Classic Vegas Rules • Pure Match & Catch (1 to 10 Spots)" :
                                       activeVariant === "power" ? "Power Keno • Catch the 20th Ball to Multiply All Wins 4X!" :
                                       activeVariant === "super" ? "Super Keno • Catch the 1st Ball to Multiply All Wins 4X!" :
                                       activeVariant === "cleopatra" ? "Cleopatra Keno • Egyptian Scarab on 20th Ball Awards 12 Free Games at 2X!" :
                                       activeVariant === "caveman" ? "Caveman Keno • 3 Dino Eggs on Board: Hatch 2 for 4X, Hatch 3 for 8X Multiplier!" :
                                       activeVariant === "extradraw" ? "Extra Draw Keno • Near Miss at 20th Ball Triggers 3 Free Extra Balls (21..23)!" :
                                       activeVariant === "goldmine" ? "Gold Mine Keno • Hit Gold Nuggets for Instant Credits + Dynamite Blast Radius!" :
                                       "Triple Power Keno • 1st Ball = 3X, 20th Ball = 3X, Both = 9X Super Multiplier!"

    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    function applyTheme(data, name) {
        // Theme synchronization hook
    }
    property int credits: 1000
    property int displayedCredits: 1000
    property int betAmount: 5
    property int lastWin: 0
    property int bestWin: 0
    property int currentMultiplier: 1
    property int spotsCount: 0
    property var selectedSpotsList: []
    property var drawnBallsList: []
    property var hitBallsList: []
    property int totalHits: 0
    onTotalHitsChanged: Qt.callLater(root.scrollToActivePayout)

    function scrollToActivePayout() {
        if (typeof paytableListView === "undefined" || !paytableListView || !paytableListView.model) return;
        var m = paytableListView.model;
        if (!m || m.length === 0) return;
        if (root.totalHits <= 0) {
            paytableListView.positionViewAtIndex(0, ListView.Beginning);
            return;
        }

        var targetIdx = -1;
        for (var i = 0; i < m.length; i++) {
            if (m[i].hits <= root.totalHits && m[i].mult > 0) {
                targetIdx = i;
                break;
            }
        }
        if (targetIdx >= 0) {
            paytableListView.positionViewAtIndex(targetIdx, ListView.Center);
        }
    }
    property bool isDrawing: false
    property bool isFastSpeed: false
    property bool splashEnabled: false
    property bool showGameMenu: true
    property bool isMuted: true
    property bool showHelp: false
    property bool isVerticalLayout: (root.width / Math.max(1, root.height)) < 1.05
    property bool isCompactHeader: (root.height < 550) || ((root.height < 630 || root.isTiledDesktopMode) && !root.isVerticalLayout)
    property bool isTiledDesktopMode: root.height < 520 || root.width < 500
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 500
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"

    function selectAndStartGame(v) {
        switchVariant(v);
        root.showGameMenu = false;
        playSound("keno_select");
    }

    function openGameMenu() {
        if (root.isDrawing) return;
        root.showGameMenu = true;
        playSound("keno_deselect");
    }

    // Bonus state
    property bool isPowerHit: false
    property bool isSuperHit: false
    property int freeGamesRemaining: 0
    property int freeGamesTotalWon: 0
    property bool isFreeGameActive: false
    property string statusMarqueeText: "TOUCH OR CLICK NUMBERS 1 TO 80 • PRESS PLAY TO DRAW"

    // 8-Variant specific trackers
    property var cavemanEggsList: []
    property int cavemanHatchedCount: 0
    property var goldNuggetsList: []
    property int dynamiteSpot: 0
    property int goldMineBonusWon: 0
    property bool extraDrawTriggered: false
    property bool triplePowerBall1Hit: false
    property bool triplePowerBall20Hit: false

    // Multi-ball draw execution
    property var plannedDrawList: []
    property int currentBallIndex: 0
    property int activeCallingBall: 0 // Currently called ball shown in magnifier

    // Target credits for count-up ticker
    property int targetCredits: 1000

    // Progressive Jackpot ticker
    property real progressiveJackpot: 250000.00
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.progressiveJackpot += 0.05
    }

    // =========================================================================
    // SOUND & AUDIO METHODS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("keno_select");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function cycleVariant() {
        if (isDrawing) return;
        var vars = ["classic", "power", "super", "cleopatra", "caveman", "extradraw", "goldmine", "triplepower"];
        var idx = vars.indexOf(root.activeVariant);
        var nextV = vars[(idx + 1) % vars.length];
        switchVariant(nextV);
    }

    function switchVariant(v) {
        if (isDrawing) return;
        Engine.setVariant(v);
        root.activeVariant = v;
        playSound("keno_select");
        var name = "Classic Keno (Vegas Retro)";
        if (v === "power") {
            name = "Power Keno (Cyberpunk 4X)";
            root.statusMarqueeText = "⚡ POWER KENO: 20TH BALL HITTING PAYS 4X!";
        } else if (v === "super") {
            name = "Super Keno (Royal Gold 4X)";
            root.statusMarqueeText = "👑 SUPER KENO: 1ST BALL HITTING PAYS 4X!";
        } else if (v === "cleopatra") {
            name = "Cleopatra Keno (Egyptian 2X)";
            root.statusMarqueeText = "🏺 CLEOPATRA: 20TH BALL HIT TRIGGERS 12 FREE GAMES @ 2X!";
        } else if (v === "caveman") {
            name = "Caveman Keno (Dino Eggs 4X/8X)";
            root.statusMarqueeText = "🦕 CAVEMAN: HATCH 2 EGGS FOR 4X, 3 EGGS FOR 8X MULTIPLIER!";
        } else if (v === "extradraw") {
            name = "Extra Draw Keno (Emergency +3)";
            root.statusMarqueeText = "🚨 EXTRA DRAW: 1 HIT AWAY FROM TOP PAY TRIGGERS 3 FREE EXTRA BALLS!";
        } else if (v === "goldmine") {
            name = "Gold Mine Keno (Nugget Cash & TNT)";
            root.statusMarqueeText = "⛏️ GOLD MINE: STRIKE GOLD NUGGETS FOR INSTANT CASH + TNT BLAST!";
        } else if (v === "triplepower") {
            name = "Triple Power Keno (Dual 3X = 9X)";
            root.statusMarqueeText = "⚛ TRIPLE POWER: 1ST BALL = 3X, 20TH BALL = 3X, BOTH = 9X SUPER MULTIPLIER!";
        } else {
            root.statusMarqueeText = "CLASSIC KENO: PURE MATCH-AND-CATCH";
        }
        soundToast.show(root.themeGameIcon + " " + name);
    }

    function setSpotState(num, select) {
        if (isDrawing) return;
        var changed = Engine.setSpot(num, select);
        if (changed) {
            root.selectedSpotsList = Engine.getSelectedSpots();
            root.spotsCount = root.selectedSpotsList.length;
            if (select) {
                playSound("keno_select");
            } else {
                playSound("keno_deselect");
            }
            if (root.spotsCount >= 2) {
                root.statusMarqueeText = root.spotsCount + " NUMBERS MARKED • READY TO PLAY";
            } else {
                root.statusMarqueeText = "MARK AT LEAST 2 NUMBERS TO PLAY";
            }
        }
    }

    function toggleTile(num) {
        if (isDrawing) return;
        var isSel = root.selectedSpotsList.indexOf(num) >= 0;
        setSpotState(num, !isSel);
    }

    function doQuickPick(count) {
        if (isDrawing) return;
        Engine.quickPick(count);
        root.selectedSpotsList = Engine.getSelectedSpots();
        root.spotsCount = root.selectedSpotsList.length;
        playSound("keno_select");
        soundToast.show("🎲 Quick Pick: " + root.spotsCount + " Spots");
        root.statusMarqueeText = root.spotsCount + " NUMBERS MARKED • READY TO PLAY";
    }

    function doQuickPickHot(count) {
        if (isDrawing) return;
        Engine.quickPickHot(count);
        root.selectedSpotsList = Engine.getSelectedSpots();
        root.spotsCount = root.selectedSpotsList.length;
        playSound("keno_select");
        soundToast.show("🔥 Hot Numbers: " + root.spotsCount + " Spots");
        root.statusMarqueeText = "HOT NUMBERS MARKED • READY TO PLAY";
    }

    function doQuickPickCold(count) {
        if (isDrawing) return;
        Engine.quickPickCold(count);
        root.selectedSpotsList = Engine.getSelectedSpots();
        root.spotsCount = root.selectedSpotsList.length;
        playSound("keno_select");
        soundToast.show("❄ Cold Numbers: " + root.spotsCount + " Spots");
        root.statusMarqueeText = "COLD NUMBERS MARKED • READY TO PLAY";
    }

    function clearBoard() {
        if (isDrawing) return;
        Engine.clearSpots();
        root.selectedSpotsList = [];
        root.spotsCount = 0;
        root.drawnBallsList = [];
        root.hitBallsList = [];
        root.totalHits = 0;
        root.lastWin = 0;
        root.activeCallingBall = 0;
        playSound("keno_deselect");
        soundToast.show("🧹 Board Erased");
        root.statusMarqueeText = "SELECT 2 TO 10 NUMBERS TO PLAY";
    }

    function changeBet(delta) {
        if (isDrawing) return;
        var bets = [1, 2, 5, 10, 20, 25, 50, 100];
        var idx = bets.indexOf(betAmount);
        if (idx === -1) idx = 2;
        var nextIdx = idx + delta;
        if (nextIdx >= 0 && nextIdx < bets.length) {
            betAmount = bets[nextIdx];
            Engine.betAmount = betAmount;
            playSound("keno_select");
        }
    }

    function setMaxBet() {
        if (isDrawing) return;
        betAmount = 100;
        Engine.betAmount = 100;
        playSound("keno_select");
        soundToast.show("💰 Max Bet: 100");
    }

    function startDraw() {
        if (isDrawing) return;
        if (spotsCount < 2) {
            soundToast.show("⚠️ Mark at least 2 numbers to play!");
            playSound("keno_deselect");
            return;
        }

        Engine.betAmount = betAmount;
        var prep = Engine.prepareDraw();
        if (!prep.success) {
            soundToast.show("⚠️ " + prep.reason);
            playSound("keno_deselect");
            return;
        }

        root.credits = prep.credits;
        root.displayedCredits = prep.credits;
        root.targetCredits = prep.credits;
        root.plannedDrawList = prep.fullDraw;
        root.drawnBallsList = [];
        root.hitBallsList = [];
        root.totalHits = 0;
        root.lastWin = 0;
        root.isPowerHit = false;
        root.isSuperHit = false;
        root.cavemanEggsList = prep.cavemanEggs || [];
        root.cavemanHatchedCount = 0;
        root.goldNuggetsList = prep.goldNuggets || [];
        root.dynamiteSpot = prep.dynamiteSpot || 0;
        root.goldMineBonusWon = 0;
        root.extraDrawTriggered = false;
        root.triplePowerBall1Hit = false;
        root.triplePowerBall20Hit = false;
        root.currentMultiplier = 1;
        root.currentBallIndex = 0;
        root.activeCallingBall = 0;
        root.isDrawing = true;
        if (typeof paytableListView !== "undefined" && paytableListView) paytableListView.positionViewAtIndex(0, ListView.Beginning);

        root.statusMarqueeText = (root.activeVariant === "caveman") ? "DRAWING BALLS • WATCH FOR DINO EGGS!" :
                                 (root.activeVariant === "goldmine") ? "DRAWING BALLS • MINE FOR GOLD NUGGETS & TNT!" :
                                 (root.activeVariant === "triplepower") ? "DRAWING BALLS • AIM FOR 1ST & 20TH BALL 9X!" :
                                 "DRAWING 20 BALLS...";
        playSound("keno_ball_drop");
        drawTimer.interval = root.isFastSpeed ? 75 : 180;
        drawTimer.start();
    }

    function onBallTick() {
        var targetBallCount = (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? 23 : 20;
        if (currentBallIndex >= targetBallCount || currentBallIndex >= plannedDrawList.length) {
            drawTimer.stop();
            finishRound();
            return;
        }

        var ballNum = plannedDrawList[currentBallIndex];
        var ballOrder = currentBallIndex + 1;
        var res = Engine.evaluateBall(ballNum, ballOrder, plannedDrawList);

        root.activeCallingBall = ballNum;
        var curDrawn = root.drawnBallsList.slice();
        curDrawn.push(ballNum);
        root.drawnBallsList = curDrawn;

        // Check variant-specific bonus occurrences
        if (res.bonusType === "caveman_egg") {
            root.cavemanHatchedCount = res.cavemanHatchedCount;
            playSound("keno_bonus");
            if (root.cavemanHatchedCount === 3) {
                soundToast.show("🦖 ALL 3 DINO EGGS HATCHED! 8X MEGA MULTIPLIER!");
                root.statusMarqueeText = "🦖 ALL 3 EGGS HATCHED! 8X MEGA MULTIPLIER UNLOCKED!";
            } else if (root.cavemanHatchedCount === 2) {
                soundToast.show("🥚 2 DINO EGGS HATCHED! 4X MULTIPLIER!");
                root.statusMarqueeText = "🥚 2 EGGS HATCHED! 4X MULTIPLIER UNLOCKED!";
            } else {
                soundToast.show("🥚 DINO EGG HATCHED! (" + root.cavemanHatchedCount + "/3)");
            }
        } else if (res.bonusType === "goldmine_nugget") {
            root.goldMineBonusWon = res.goldMineBonusWon;
            root.credits = res.credits;
            root.displayedCredits = res.credits;
            playSound("keno_win");
            soundToast.show("⛏️ GOLD NUGGET STRUCK! +" + res.instantBonusCredits + " CREDITS!");
            root.statusMarqueeText = "⛏️ GOLD NUGGET HIT! +" + res.instantBonusCredits + " BONUS CREDITS!";
        } else if (res.bonusType === "goldmine_dynamite") {
            playSound("keno_power_hit");
            soundToast.show("🧨 DYNAMITE BLAST! SURROUNDING SPOTS HIT!");
            root.statusMarqueeText = "🧨 TNT BLAST TRIGGERED! ADJACENT SPOTS STRUCK!";
            root.hitBallsList = Engine.hitNumbers.slice();
            root.totalHits = root.hitBallsList.length;
        } else if (res.bonusType === "extradraw_trigger") {
            root.extraDrawTriggered = true;
            playSound("keno_bonus");
            soundToast.show("🚨 EMERGENCY EXTRA DRAW! 3 EXTRA BALLS! 🚨");
            root.statusMarqueeText = "🚨 EMERGENCY ALARM: 1 HIT AWAY! DRAWING BALLS 21, 22, 23! 🚨";
        } else if (res.bonusType === "triplepower_1") {
            root.triplePowerBall1Hit = true;
            playSound("keno_super_hit");
            soundToast.show("⚡ 1ST BALL HIT! 3X MULTIPLIER LOCKED!");
            root.statusMarqueeText = "⚡ 1ST BALL HIT! 3X MULTIPLIER LOCKED!";
        } else if (res.bonusType === "triplepower_20") {
            root.triplePowerBall20Hit = true;
            playSound("keno_power_hit");
            if (root.triplePowerBall1Hit) {
                soundToast.show("💥 BOTH BALLS HIT! 9X SUPER MULTIPLIER! 💥");
                root.statusMarqueeText = "💥 DUAL 3X HITS! 9X SUPER MULTIPLIER LOCKED!";
            } else {
                soundToast.show("⚡ 20TH BALL HIT! 3X MULTIPLIER LOCKED!");
                root.statusMarqueeText = "⚡ 20TH BALL HIT! 3X MULTIPLIER LOCKED!";
            }
        }

        if (res.isHit) {
            var curHits = root.hitBallsList.slice();
            if (curHits.indexOf(ballNum) < 0) {
                curHits.push(ballNum);
                root.hitBallsList = curHits;
                root.totalHits = curHits.length;
            }

            if (res.bonusType === "power") {
                root.isPowerHit = true;
                playSound("keno_power_hit");
                soundToast.show("⚡ POWER BALL 4X HIT! ⚡");
                root.statusMarqueeText = "⚡ POWER HIT ON 20TH BALL! 4X WIN LOCKED!";
            } else if (res.bonusType === "super") {
                root.isSuperHit = true;
                playSound("keno_super_hit");
                soundToast.show("🌟 SUPER KENO 4X HIT! 🌟");
                root.statusMarqueeText = "🌟 SUPER HIT ON 1ST BALL! 4X WIN LOCKED!";
            } else if (res.bonusType === "cleopatra") {
                playSound("keno_bonus");
                soundToast.show("👑 CLEOPATRA 12 FREE GAMES WON! 👑");
                root.statusMarqueeText = "👑 12 FREE GAMES WON AT 2X MULTIPLIER!";
            } else if (res.bonusType !== "caveman_egg" && res.bonusType !== "goldmine_nugget" && res.bonusType !== "goldmine_dynamite" && res.bonusType !== "triplepower_1" && res.bonusType !== "triplepower_20") {
                playSound("keno_hit");
            }
        } else {
            playSound("keno_ball_drop");
        }

        currentBallIndex++;

        var checkTarget = (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? 23 : 20;
        if (currentBallIndex >= checkTarget || currentBallIndex >= plannedDrawList.length) {
            drawTimer.stop();
            finishRound();
        }
    }

    function finishRound() {
        var finalResult = Engine.concludeDraw(root.plannedDrawList);
        root.isDrawing = false;
        root.lastWin = finalResult.winAmount;
        root.currentMultiplier = finalResult.multiplier;
        root.credits = finalResult.credits;
        root.targetCredits = finalResult.credits;
        root.freeGamesRemaining = finalResult.freeGamesRemaining;
        root.freeGamesTotalWon = finalResult.freeGamesTotalWon;
        root.isFreeGameActive = finalResult.isFreeGameActive;

        if (root.lastWin > root.bestWin) {
            root.bestWin = root.lastWin;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(root.bestWin);
            }
        }

        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setCredits(root.credits);
        }

        if (root.lastWin > 0) {
            playSound("keno_win");
            creditTickerTimer.start();
            soundToast.show("🎉 WIN: " + root.lastWin + " CREDITS! (" + root.totalHits + " HITS)");
            root.statusMarqueeText = "★ WINNER! " + root.totalHits + " HITS PAYS " + (finalResult.multiplier > 1 ? (finalResult.baseMultiplier + "X x" + finalResult.multiplier + " = ") : "") + root.lastWin + " CREDITS! ★";
        } else {
            root.displayedCredits = root.credits;
            root.statusMarqueeText = root.totalHits > 0 ? (root.totalHits + " HITS • NO PAYOUT THIS ROUND") : "NO MATCHES • TRY AGAIN!";
        }

        if (root.freeGamesRemaining > 0 && !root.isDrawing) {
            freeGameDelayTimer.start();
        }
    }

    Timer {
        id: drawTimer
        repeat: true
        onTriggered: root.onBallTick()
    }

    Timer {
        id: creditTickerTimer
        interval: 40
        repeat: true
        onTriggered: {
            if (root.displayedCredits < root.targetCredits) {
                var diff = root.targetCredits - root.displayedCredits;
                var step = Math.max(1, Math.floor(diff / 8));
                root.displayedCredits += step;
                playSound("keno_credit");
            } else {
                root.displayedCredits = root.targetCredits;
                creditTickerTimer.stop();
            }
        }
    }

    Timer {
        id: freeGameDelayTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.freeGamesRemaining > 0 && !root.isDrawing) {
                root.startDraw();
            }
        }
    }

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : mainContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.credits = settingsManager.getCredits();
            root.displayedCredits = root.credits;
            root.targetCredits = root.credits;
            root.bestWin = settingsManager.getBestScore();
        }
        Engine.credits = root.credits;
        Engine.betAmount = root.betAmount;
    }

    // =========================================================================
    // MAIN CABINET CHASSIS & BEZEL
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true

        // Rich Themed Cabinet Backdrop Artwork
        Image {
            id: cabinetBgImage
            anchors.fill: parent
            source: root.activeVariant === "cleopatra" ? "assets/bg_cleopatra.jpg" :
                    root.activeVariant === "power" ? "assets/bg_power.jpg" :
                    root.activeVariant === "super" ? "assets/bg_super.jpg" :
                    root.activeVariant === "caveman" ? "assets/bg_caveman.jpg" :
                    root.activeVariant === "extradraw" ? "assets/bg_extradraw.jpg" :
                    root.activeVariant === "goldmine" ? "assets/bg_goldmine.jpg" :
                    root.activeVariant === "triplepower" ? "assets/bg_triplepower.jpg" : "assets/bg_classic.jpg"
            fillMode: Image.PreserveAspectCrop
            opacity: root.activeVariant === "cleopatra" ? 0.38 :
                     root.activeVariant === "caveman" ? 0.36 :
                     root.activeVariant === "extradraw" ? 0.34 :
                     root.activeVariant === "goldmine" ? 0.36 :
                     root.activeVariant === "triplepower" ? 0.34 : 0.28
            asynchronous: true
        }

        // Contrast Vignette Overlay for Crisp Readability
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.22) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
            }
        }

        // DUAL THEMED CABINET PILLARS (Iconic Physical VLT Casino Architecture)
        // Left Column: Themed Side Pillar
        Rectangle {
            id: leftNeonPillar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 26
            z: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.themeNeonLeft }
                GradientStop { position: 0.5; color: root.activeVariant === "cleopatra" ? "#fbbf24" : "#ffffff" }
                GradientStop { position: 1.0; color: root.themeNeonRight }
            }
            border.color: root.activeVariant === "cleopatra" ? "#d97706" : root.themeBorder
            border.width: 1

            // Pillar interior shading
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: root.activeVariant === "cleopatra" ? "#1a1208" :
                       root.activeVariant === "caveman" ? "#131b08" :
                       root.activeVariant === "extradraw" ? "#22050b" :
                       root.activeVariant === "goldmine" ? "#1e1304" :
                       root.activeVariant === "triplepower" ? "#061826" :
                       root.activeVariant === "power" ? "#140624" :
                       root.activeVariant === "super" ? "#1e0f03" : "#070c1e"
                opacity: 0.88
            }

            // Themed Vertical Motifs
            Column {
                anchors.centerIn: parent
                spacing: Math.max(8, (parent.height - 480) / 10)
                Repeater {
                    model: root.activeVariant === "cleopatra" ? ["𓋹", "𓁹", "𓆣", "𓉐", "𓊹", "𓃭", "𓅓", "𓆣", "𓋹"] :
                           root.activeVariant === "caveman" ? ["🦕", "🌋", "🦴", "🥚", "🦕", "🌋", "🦴", "🥚", "🦕"] :
                           root.activeVariant === "extradraw" ? ["🚨", "⚠️", "⚡", "🚨", "⚠️", "⚡", "🚨", "⚠️", "🚨"] :
                           root.activeVariant === "goldmine" ? ["⛏️", "💰", "🧨", "🪙", "⛏️", "💰", "🧨", "🪙", "⛏️"] :
                           root.activeVariant === "triplepower" ? ["⚛", "⚡", "💠", "⚛", "⚡", "💠", "⚛", "⚡", "⚛"] :
                           root.activeVariant === "power" ? ["⚡", "◈", "⚡", "◈", "⚡", "◈", "⚡", "◈", "⚡"] :
                           root.activeVariant === "super" ? ["👑", "⚜", "★", "⚜", "👑", "⚜", "★", "⚜", "👑"] :
                           ["✦", "◆", "✦", "◆", "✦", "◆", "✦", "◆", "✦"]
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        font.pixelSize: root.activeVariant === "cleopatra" ? 14 : 11
                        color: root.activeVariant === "cleopatra" ? "#fbbf24" :
                               root.activeVariant === "caveman" ? "#bef264" :
                               root.activeVariant === "extradraw" ? "#f87171" :
                               root.activeVariant === "goldmine" ? "#fde047" :
                               root.activeVariant === "triplepower" ? "#67e8f9" :
                               root.activeVariant === "power" ? "#e879f9" :
                               root.activeVariant === "super" ? "#fde047" : "#38bdf8"
                        style: Text.Outline
                        styleColor: "#000000"
                        opacity: 0.95
                    }
                }
            }

            // Center neon gas core / golden obelisk line
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 2
                color: root.activeVariant === "cleopatra" ? "#fef08a" : "#ffffff"
                opacity: 0.5
            }
        }

        // Right Column
        Rectangle {
            id: rightNeonPillar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 26
            z: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.themeNeonRight }
                GradientStop { position: 0.5; color: root.activeVariant === "cleopatra" ? "#fbbf24" : "#ffffff" }
                GradientStop { position: 1.0; color: root.themeNeonLeft }
            }
            border.color: root.activeVariant === "cleopatra" ? "#d97706" : root.themeBorder
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: root.activeVariant === "cleopatra" ? "#1a1208" :
                       root.activeVariant === "caveman" ? "#131b08" :
                       root.activeVariant === "extradraw" ? "#22050b" :
                       root.activeVariant === "goldmine" ? "#1e1304" :
                       root.activeVariant === "triplepower" ? "#061826" :
                       root.activeVariant === "power" ? "#140624" :
                       root.activeVariant === "super" ? "#1e0f03" : "#070c1e"
                opacity: 0.88
            }

            Column {
                anchors.centerIn: parent
                spacing: Math.max(8, (parent.height - 480) / 10)
                Repeater {
                    model: root.activeVariant === "cleopatra" ? ["𓋹", "𓁹", "𓆣", "𓉐", "𓊹", "𓃭", "𓅓", "𓆣", "𓋹"] :
                           root.activeVariant === "caveman" ? ["🦕", "🌋", "🦴", "🥚", "🦕", "🌋", "🦴", "🥚", "🦕"] :
                           root.activeVariant === "extradraw" ? ["🚨", "⚠️", "⚡", "🚨", "⚠️", "⚡", "🚨", "⚠️", "🚨"] :
                           root.activeVariant === "goldmine" ? ["⛏️", "💰", "🧨", "🪙", "⛏️", "💰", "🧨", "🪙", "⛏️"] :
                           root.activeVariant === "triplepower" ? ["⚛", "⚡", "💠", "⚛", "⚡", "💠", "⚛", "⚡", "⚛"] :
                           root.activeVariant === "power" ? ["⚡", "◈", "⚡", "◈", "⚡", "◈", "⚡", "◈", "⚡"] :
                           root.activeVariant === "super" ? ["👑", "⚜", "★", "⚜", "👑", "⚜", "★", "⚜", "👑"] :
                           ["✦", "◆", "✦", "◆", "✦", "◆", "✦", "◆", "✦"]
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        font.pixelSize: root.activeVariant === "cleopatra" ? 14 : 11
                        color: root.activeVariant === "cleopatra" ? "#fbbf24" :
                               root.activeVariant === "caveman" ? "#bef264" :
                               root.activeVariant === "extradraw" ? "#f87171" :
                               root.activeVariant === "goldmine" ? "#fde047" :
                               root.activeVariant === "triplepower" ? "#67e8f9" :
                               root.activeVariant === "power" ? "#e879f9" :
                               root.activeVariant === "super" ? "#fde047" : "#38bdf8"
                        style: Text.Outline
                        styleColor: "#000000"
                        opacity: 0.95
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 2
                color: root.activeVariant === "cleopatra" ? "#fef08a" : "#ffffff"
                opacity: 0.5
            }
        }

        Keys.onPressed: function(event) {
            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.showGameMenu) {
                if (event.key === Qt.Key_1) {
                    root.selectAndStartGame("classic");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_2) {
                    root.selectAndStartGame("power");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_3) {
                    root.selectAndStartGame("super");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_4) {
                    root.selectAndStartGame("cleopatra");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_5) {
                    root.selectAndStartGame("caveman");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_6) {
                    root.selectAndStartGame("extradraw");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_7) {
                    root.selectAndStartGame("goldmine");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_8) {
                    root.selectAndStartGame("triplepower");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.showGameMenu = false;
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Escape) {
                root.openGameMenu();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_T || event.key === Qt.Key_G) {
                root.cycleVariant();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.startDraw();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_1) {
                root.switchVariant("classic");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_2) {
                root.switchVariant("power");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_3) {
                root.switchVariant("super");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_4) {
                root.switchVariant("cleopatra");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_5) {
                root.switchVariant("caveman");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_6) {
                root.switchVariant("extradraw");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_7) {
                root.switchVariant("goldmine");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_8) {
                root.switchVariant("triplepower");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Q) {
                var counts = [3, 5, 7, 10];
                var nextCount = 5;
                if (root.spotsCount === 3) nextCount = 5;
                else if (root.spotsCount === 5) nextCount = 7;
                else if (root.spotsCount === 7) nextCount = 10;
                else if (root.spotsCount === 10) nextCount = 3;
                root.doQuickPick(nextCount);
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_C) {
                root.clearBoard();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_S) {
                root.isFastSpeed = !root.isFastSpeed;
                soundToast.show(root.isFastSpeed ? "⚡ Turbo Speed" : "🐢 Normal Speed");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_B) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.changeBet(-1);
                } else {
                    root.changeBet(1);
                }
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_X) {
                root.setMaxBet();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                if (root.credits <= 0) {
                    root.credits = 1000;
                    root.displayedCredits = 1000;
                    root.targetCredits = 1000;
                    Engine.credits = 1000;
                    if (typeof settingsManager !== "undefined" && settingsManager) {
                        settingsManager.setCredits(1000);
                    }
                    soundToast.show("💵 Bankroll Refilled: 1,000 Credits");
                    playSound("keno_win");
                }
                event.accepted = true;
                return;
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header with Title & Score Cards)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? 12 : 0
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 52 : 0

            // Title & Subtitle block
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - scoreRow.width - 20
                spacing: 2

                Row {
                    spacing: 8
                    Text {
                        text: root.activeVariant === "cleopatra" ? "CLEOPATRA KENO" :
                              root.activeVariant === "power" ? "POWER KENO" :
                              root.activeVariant === "super" ? "SUPER KENO" :
                              root.activeVariant === "caveman" ? "CAVEMAN KENO" :
                              root.activeVariant === "extradraw" ? "EXTRA DRAW KENO" :
                              root.activeVariant === "goldmine" ? "GOLD MINE KENO" :
                              root.activeVariant === "triplepower" ? "TRIPLE POWER KENO" : "CLASSIC KENO"
                        font.pixelSize: Math.max(20, Math.min(28, headerItem.width * 0.072))
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.activeVariant === "cleopatra" ? "#fbbf24" : root.themeAccent
                        style: Text.Raised
                        styleColor: "#000000"
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22
                        width: badgeText.implicitWidth + 16
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.activeVariant === "cleopatra" ? "#78350f" : Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.35) }
                            GradientStop { position: 1.0; color: root.activeVariant === "cleopatra" ? "#451a03" : Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.15) }
                        }
                        border.color: root.activeVariant === "cleopatra" ? "#fbbf24" : root.themeAccent
                        border.width: 1
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: root.themeGameIcon + " " + (root.activeVariant === "power" ? "POWER 4X" :
                                  root.activeVariant === "super" ? "SUPER 4X" :
                                  root.activeVariant === "cleopatra" ? "12 FREE GAMES (2X)" :
                                  root.activeVariant === "caveman" ? "4X / 8X MULTIPLIER" :
                                  root.activeVariant === "extradraw" ? "+3 EMERGENCY BALLS" :
                                  root.activeVariant === "goldmine" ? "NUGGET CASH & TNT" :
                                  root.activeVariant === "triplepower" ? "DUAL 3X = 9X MEGA" : "VEGAS ODDS")
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.activeVariant === "cleopatra" ? "#fde68a" : root.themeAccent
                        }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.themeGameSubtitle
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    font.family: root.monoFontFamily
                    color: root.themeSubtext
                }
            }

            // Stat Cards on the right: CREDITS, BET, BEST WIN
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // CREDITS Card
                Rectangle {
                    width: Math.max(76, Math.min(96, headerItem.width * 0.16))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "CREDITS"
                            font.pixelSize: 8
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.displayedCredits.toString()
                            font.pixelSize: 16
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.credits <= 10 ? "#ef4444" : root.themeFg
                        }
                    }
                }

                // BET Card
                Rectangle {
                    width: Math.max(60, Math.min(74, headerItem.width * 0.12))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BET"
                            font.pixelSize: 8
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.betAmount.toString()
                            font.pixelSize: 16
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeAccent
                        }
                    }
                }

                // BEST WIN Card
                Rectangle {
                    width: Math.max(76, Math.min(96, headerItem.width * 0.16))
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BEST WIN"
                            font.pixelSize: 8
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bestWin.toString()
                            font.pixelSize: 16
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.bestWin > 0 ? root.themeHit : root.themeSubtext
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isCompactHeader
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? (root.isVerticalLayout ? 4 : 8) : 0
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 34 : 0

            readonly property bool isCrowded: subheaderItem.width < 760 || root.isVerticalLayout

            // Left: Return to Game Menu Button (Responsive Emoji Collapse)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: subheaderItem.isCrowded ? 32 : (menuBtnRow.implicitWidth + 20)
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#2563eb" }
                    GradientStop { position: 1.0; color: "#1d4ed8" }
                }
                border.color: "#93c5fd"
                border.width: 1

                Row {
                    id: menuBtnRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "◀"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#ffffff"
                    }
                    Text {
                        text: "Game Menu [ESC]"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#ffffff"
                        visible: !subheaderItem.isCrowded
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openGameMenu()
                }
            }

            // Right: Standard Action Pills (Responsive Emoji Collapse: ? How to Play -> ?, Muted -> 🔇, Speed -> 🐢/⚡)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 4 : 6

                // Help Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "?"; font.pixelSize: 13; font.bold: true; color: root.themeAccent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "How to Play"; font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: root.themeFg; anchors.verticalCenter: parent.verticalCenter; visible: !subheaderItem.isCrowded }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mute Button
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.isMuted ? "Muted" : "Sound"; font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: root.isMuted ? root.themeSubtext : root.themeFg; anchors.verticalCenter: parent.verticalCenter; visible: !subheaderItem.isCrowded }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Game Variant Switcher (Transforms Theme & Rules)
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (variantSwitchRow.implicitWidth + 18)
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: variantSwitchRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: root.themeGameIcon; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: (root.activeVariant === "classic" ? "Classic" :
                                   root.activeVariant === "power" ? "Power 4X" :
                                   root.activeVariant === "super" ? "Super 4X" :
                                   root.activeVariant === "cleopatra" ? "Cleopatra 2X" :
                                   root.activeVariant === "caveman" ? "Caveman 4X/8X" :
                                   root.activeVariant === "extradraw" ? "Extra Draw +3" :
                                   root.activeVariant === "goldmine" ? "Gold Mine" : "Triple Power 9X") + " [T]"
                            font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleVariant()
                    }
                }

                // Speed Pill
                Rectangle {
                    height: 30
                    width: subheaderItem.isCrowded ? 30 : (speedRow.implicitWidth + 16)
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: speedRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: root.isFastSpeed ? "⚡" : "🐢"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.isFastSpeed ? "Fast" : "Normal"; font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: root.isFastSpeed ? root.themeHit : root.themeSubtext; anchors.verticalCenter: parent.verticalCenter; visible: !subheaderItem.isCrowded }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isFastSpeed = !root.isFastSpeed;
                            soundToast.show(root.isFastSpeed ? "⚡ Turbo Speed" : "🐢 Normal Speed");
                        }
                    }
                }

                // View Mode Pill
                Rectangle {
                    height: 30
                    width: 30
                    radius: 8
                    color: root.fullPlayfield ? root.themeCardBg : root.themeBoardBg
                    border.color: root.fullPlayfield ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.fullPlayfield ? "🔲" : "⛶"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                        }
                    }
                }
            }
        }

        // =====================================================================
        // COMPACT HEADER: Unified single-row bar for Half-Height & Small Screens
        // =====================================================================
        Rectangle {
            id: compactHeaderBar
            visible: root.isCompactHeader
            anchors.top: parent.top
            anchors.topMargin: visible ? 4 : 0
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: visible ? 36 : 0
            radius: 8
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            z: 20

            // Left: Menu button + Game Title
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    height: 26
                    width: compactMenuRow.implicitWidth + 14
                    radius: 6
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2563eb" }
                        GradientStop { position: 1.0; color: "#1d4ed8" }
                    }
                    border.color: "#93c5fd"
                    border.width: 1

                    Row {
                        id: compactMenuRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "◀"; font.pixelSize: 10; font.bold: true; color: "#ffffff" }
                        Text { text: root.width < 600 ? "Menu" : "Game Menu [ESC]"; font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff" }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.openGameMenu()
                    }
                }

                Text {
                    text: root.themeGameIcon + " " + (root.activeVariant === "power" ? "POWER KENO 4X" :
                          root.activeVariant === "super" ? "SUPER KENO 4X" :
                          root.activeVariant === "cleopatra" ? "CLEOPATRA KENO" :
                          root.activeVariant === "caveman" ? "CAVEMAN KENO" :
                          root.activeVariant === "extradraw" ? "EXTRA DRAW" :
                          root.activeVariant === "goldmine" ? "GOLD MINE" :
                          root.activeVariant === "triplepower" ? "TRIPLE POWER" : "CLASSIC KENO")
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.monoFontFamily
                    color: root.themeAccent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Right: Credits, Bet, Win & Quick actions
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Credits
                Rectangle {
                    height: 26
                    width: compactCreditsRow.implicitWidth + 12
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Row {
                        id: compactCreditsRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "CR:"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; font.family: root.monoFontFamily }
                        Text { text: root.displayedCredits.toString(); font.pixelSize: 12; font.bold: true; color: root.credits <= 10 ? "#ef4444" : root.themeFg; font.family: root.monoFontFamily }
                    }
                }

                // Bet
                Rectangle {
                    height: 26
                    width: compactBetRow.implicitWidth + 12
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Row {
                        id: compactBetRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "BET:"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; font.family: root.monoFontFamily }
                        Text { text: root.betAmount.toString(); font.pixelSize: 12; font.bold: true; color: root.themeAccent; font.family: root.monoFontFamily }
                    }
                }

                // Win
                Rectangle {
                    height: 26
                    width: compactWinRow.implicitWidth + 12
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    visible: root.width > 680
                    Row {
                        id: compactWinRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "WIN:"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; font.family: root.monoFontFamily }
                        Text { text: root.bestWin.toString(); font.pixelSize: 12; font.bold: true; color: root.bestWin > 0 ? root.themeHit : root.themeSubtext; font.family: root.monoFontFamily }
                    }
                }

                // Help Button
                Rectangle {
                    height: 26
                    width: 28
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.pixelSize: 12; font.bold: true; color: root.themeAccent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mute
                Rectangle {
                    height: 26
                    width: 28
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Speed
                Rectangle {
                    height: 26
                    width: 30
                    radius: 5
                    color: root.themeBoardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isFastSpeed ? "⚡" : "🐢"; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isFastSpeed = !root.isFastSpeed;
                            soundToast.show(root.isFastSpeed ? "⚡ Turbo Speed" : "🐢 Normal Speed");
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: MAIN PLAYFIELD (The 1-40 & 41-80 Split Grid + Tumbler + Paytable)
        // =====================================================================
        Rectangle {
            id: boardContainer
            anchors.top: root.isCompactHeader ? compactHeaderBar.bottom : subheaderItem.bottom
            anchors.topMargin: root.isCompactHeader ? 4 : (root.isVerticalLayout ? 4 : 6)
            anchors.bottom: bottomControlBar.top
            anchors.bottomMargin: 8
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            radius: 8
            color: root.themeBoardBg
            border.color: root.themeBorder
            border.width: 2
            clip: true

            // Themed Board Interior Backdrop Image (Egyptian Sandstone, Cyber Circuit, Royal Velvet, Vegas Felt)
            Image {
                id: boardTextureImage
                anchors.fill: parent
                anchors.margins: 2
                source: root.activeVariant === "cleopatra" ? "assets/bg_cleopatra.jpg" :
                        root.activeVariant === "power" ? "assets/bg_power.jpg" :
                        root.activeVariant === "super" ? "assets/bg_super.jpg" : "assets/bg_classic.jpg"
                fillMode: Image.PreserveAspectCrop
                opacity: root.activeVariant === "cleopatra" ? 0.22 : 0.16
                clip: true
            }

            Rectangle {
                anchors.fill: parent
                color: root.themeBoardBg
                opacity: 0.68
            }

            // Marquee Banner Bar with Progressive Jackpot Badge + Status Ticker
            Rectangle {
                id: marqueeBar
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 28
                radius: 4
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.freeGamesRemaining > 0 ? "#854d0e" :
                               root.totalHits > 0 ? "#452203" :
                               root.activeVariant === "cleopatra" ? "#281706" : "#161c2d"
                    }
                    GradientStop {
                        position: 1.0
                        color: root.freeGamesRemaining > 0 ? "#451a03" :
                               root.totalHits > 0 ? "#210f00" :
                               root.activeVariant === "cleopatra" ? "#120a02" : "#0c0e17"
                    }
                }
                border.color: root.freeGamesRemaining > 0 ? "#fbbf24" :
                              root.totalHits > 0 ? "#fbbf24" : root.themeBorder
                border.width: (root.freeGamesRemaining > 0 || root.totalHits > 0) ? 1.5 : 1

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8

                    // Left: Golden Progressive Jackpot Marquee
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 20
                            width: jackpotRow.implicitWidth + 12
                            radius: 4
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#78350f" }
                                GradientStop { position: 1.0; color: "#451a03" }
                            }
                            border.color: "#f59e0b"; border.width: 1
                            Row {
                                id: jackpotRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "★ JACKPOT:"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fde68a"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "$" + root.progressiveJackpot.toLocaleString(Qt.locale("en_US"), "f", 2); font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: "#fbbf24"; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Center / Right: Dynamic Marquee Message
                    Text {
                        anchors.right: parent.right
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: -40
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: root.freeGamesRemaining > 0 ? ("🏺 CLEOPATRA FREE GAMES: " + root.freeGamesRemaining + " OF 12 (ALL WINS 2X) 🏺") : root.statusMarqueeText
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.freeGamesRemaining > 0 ? "#fde047" :
                               root.isPowerHit ? "#c084fc" :
                               root.isSuperHit ? "#fbbf24" :
                               root.totalHits > 0 ? "#fbbf24" : root.themeAccent
                    }
                }
            }

            // Split Layout: Center Grid (Left) + Tumbler & 20-Ball List & Paytable (Right)
            Item {
                id: splitArea
                anchors.top: marqueeBar.bottom
                anchors.topMargin: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // =============================================================
                // LEFT: THE AUTHENTIC 1-40 & 41-80 SPLIT VLT KENO GRID
                // =============================================================
                Item {
                    id: gridContainer
                    anchors.top: root.isVerticalLayout ? sidePanel.bottom : parent.top
                    anchors.topMargin: root.isVerticalLayout ? 6 : 0
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: root.isVerticalLayout ? parent.right : sidePanel.left
                    anchors.rightMargin: root.isVerticalLayout ? 0 : 8

                    property int hoveredTile: -1
                    property int lastInteractedTile: -1
                    property string swipeMode: "" // "select", "deselect", or ""

                    function getTileNumberAt(px, py) {
                        if (px < 0 || px > width) return -1;

                        // TOP BANK: Numbers 1 to 40
                        if (py >= topGrid.y && py < topGrid.y + topGrid.height) {
                            var relY = py - topGrid.y;
                            var stepX = topGrid.cellW + topGrid.spacing;
                            var stepY = topGrid.cellH + topGrid.spacing;
                            var col = Math.floor(px / stepX);
                            var row = Math.floor(relY / stepY);
                            if (col >= 0 && col < 10 && row >= 0 && row < 4) {
                                return row * 10 + col + 1;
                            }
                        }

                        // BOTTOM BANK: Numbers 41 to 80
                        if (py >= bottomGrid.y && py < bottomGrid.y + bottomGrid.height) {
                            var relY2 = py - bottomGrid.y;
                            var stepX2 = bottomGrid.cellW + bottomGrid.spacing;
                            var stepY2 = bottomGrid.cellH + bottomGrid.spacing;
                            var col2 = Math.floor(px / stepX2);
                            var row2 = Math.floor(relY2 / stepY2);
                            if (col2 >= 0 && col2 < 10 && row2 >= 0 && row2 < 4) {
                                return row2 * 10 + col2 + 41;
                            }
                        }

                        return -1;
                    }

                    // TOP BANK: Numbers 1 to 40 (4 Rows x 10 Columns)
                    Grid {
                        id: topGrid
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: (parent.height - 30) / 2
                        columns: 10
                        rows: 4
                        spacing: 4

                        property real cellW: (width - 9 * spacing) / 10
                        property real cellH: (height - 3 * spacing) / 4

                        Repeater {
                            model: 40
                            Rectangle {
                                id: tileTop
                                property int number: index + 1
                                property bool isSelected: root.selectedSpotsList.indexOf(number) >= 0
                                property bool isDrawn: root.drawnBallsList.indexOf(number) >= 0
                                property bool isHit: isSelected && isDrawn
                                property bool isHovered: gridContainer.hoveredTile === number
                                property bool isCavemanEgg: root.activeVariant === "caveman" && root.cavemanEggsList.indexOf(number) >= 0
                                property bool isGoldNugget: root.activeVariant === "goldmine" && root.goldNuggetsList.indexOf(number) >= 0
                                property bool isDynamite: root.activeVariant === "goldmine" && root.dynamiteSpot === number
                                property bool isSpecialHit: isHit && (
                                    (root.activeVariant === "super" && root.drawnBallsList.indexOf(number) === 0) ||
                                    (root.activeVariant === "power" && root.drawnBallsList.indexOf(number) === 19) ||
                                    (root.activeVariant === "cleopatra" && root.drawnBallsList.indexOf(number) === 19) ||
                                    (root.activeVariant === "triplepower" && (root.drawnBallsList.indexOf(number) === 0 || root.drawnBallsList.indexOf(number) === 19)) ||
                                    (root.activeVariant === "extradraw" && root.drawnBallsList.indexOf(number) >= 20)
                                )

                                width: topGrid.cellW
                                height: topGrid.cellH
                                radius: 5

                                // 3D Beveled Casino Tile Gradient
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: tileTop.isSpecialHit ? "#c084fc" :
                                               tileTop.isHit ? "#fde047" :
                                               tileTop.isSelected ? root.themeMarked :
                                               tileTop.isDrawn ? root.themeTileDrawn :
                                               tileTop.isHovered ? root.themeTileHover : root.themeTileBg
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: tileTop.isSpecialHit ? "#7e22ce" :
                                               tileTop.isHit ? "#d97706" :
                                               tileTop.isSelected ? root.themeMarkedDark :
                                               tileTop.isDrawn ? root.themeTileDrawnDark :
                                               tileTop.isHovered ? root.themeTileHoverDark : root.themeTileBgDark
                                    }
                                }

                                border.color: tileTop.isSpecialHit ? "#f43f5e" :
                                              tileTop.isHit ? "#fef08a" :
                                              tileTop.isSelected ? "#ffffff" :
                                              tileTop.isDrawn ? root.themeAccent :
                                              tileTop.isHovered ? root.themeAccent : root.themeBorder
                                border.width: (tileTop.isHit || tileTop.isSpecialHit) ? 2 : (tileTop.isSelected ? 2 : (tileTop.isDrawn ? 1.5 : (tileTop.isHovered ? 1.5 : 1)))

                                scale: tileTop.isHit ? 1.06 : (tileTop.isHovered ? 1.03 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                // Specular top highlight line (Tactile 3D Bevel)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 1
                                    height: 1.5
                                    color: "#ffffff"
                                    opacity: tileTop.isSelected || tileTop.isHit ? 0.6 : 0.25
                                    radius: 2
                                }

                                // Animated Impact Shockwave Ring on Ball Call
                                Rectangle {
                                    id: shockwaveTop
                                    anchors.centerIn: parent
                                    width: parent.width; height: parent.height; radius: parent.radius
                                    color: "transparent"
                                    border.color: tileTop.isHit ? "#fde047" : "#38bdf8"
                                    border.width: tileTop.isHit ? 2.5 : 1.5
                                    opacity: 0.0
                                    scale: 1.0

                                    Connections {
                                        target: root
                                        function onActiveCallingBallChanged() {
                                            if (root.activeCallingBall === tileTop.number) {
                                                shockwaveTopAnim.restart();
                                            }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: shockwaveTopAnim
                                        NumberAnimation { target: shockwaveTop; property: "scale"; from: 1.0; to: 2.2; duration: 320; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: shockwaveTop; property: "opacity"; from: 0.95; to: 0.0; duration: 320; easing.type: Easing.OutQuad }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    // Special Tokens: Scarab (Cleopatra), Dino Egg (Caveman), Gold Nugget (Gold Mine)
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(topGrid.cellW - 6, topGrid.cellH - 6)
                                        height: width
                                        source: (root.activeVariant === "cleopatra" && tileTop.isSpecialHit) ? "assets/token_scarab.jpg" :
                                                tileTop.isCavemanEgg ? "assets/token_egg.jpg" :
                                                tileTop.isGoldNugget ? "assets/token_nugget.jpg" : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: ((tileTop.isSpecialHit && root.activeVariant === "cleopatra") || tileTop.isCavemanEgg || tileTop.isGoldNugget)
                                        opacity: (tileTop.isCavemanEgg && !tileTop.isDrawn) ? 0.70 : 1.0
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !(
                                            (tileTop.isSpecialHit && root.activeVariant === "cleopatra") ||
                                            (tileTop.isCavemanEgg && !tileTop.isDrawn) ||
                                            (tileTop.isGoldNugget && !tileTop.isDrawn)
                                        )
                                        text: tileTop.isDynamite ? "🧨" :
                                              (tileTop.isSpecialHit && root.activeVariant === "power") ? "⚡4X" :
                                              (tileTop.isSpecialHit && root.activeVariant === "super") ? "👑4X" :
                                              (tileTop.isSpecialHit && root.activeVariant === "triplepower") ? (root.triplePowerBall1Hit && root.triplePowerBall20Hit ? "💥9X" : "⚡3X") :
                                              (tileTop.isSpecialHit && root.activeVariant === "extradraw") ? "🚨+" :
                                              (tileTop.isCavemanEgg && tileTop.isDrawn) ? (tileTop.isHit ? "🦖" : "🥚") :
                                              (tileTop.isGoldNugget && tileTop.isDrawn) ? (tileTop.isHit ? "💰" : "🪙") :
                                              tileTop.isHit ? (
                                                  root.activeVariant === "cleopatra" ? "𓆣" :
                                                  root.activeVariant === "caveman" ? "🦖" :
                                                  root.activeVariant === "extradraw" ? "🚨" :
                                                  root.activeVariant === "goldmine" ? "⛏️" :
                                                  root.activeVariant === "triplepower" ? "⚛" : "$"
                                              ) : tileTop.number.toString()
                                        font.pixelSize: tileTop.isHit ? Math.max(12, Math.min(18, topGrid.cellH * 0.54)) : Math.max(11, Math.min(18, topGrid.cellH * 0.52))
                                        font.bold: true
                                        font.family: root.monoFontFamily
                                        color: (tileTop.isHit || tileTop.isSpecialHit) ? (root.activeVariant === "cleopatra" ? "#78350f" : "#000000") :
                                               tileTop.isSelected ? "#ffffff" :
                                               tileTop.isDrawn ? "#ffffff" : root.themeFg
                                        style: tileTop.isSelected ? Text.Raised : Text.Normal
                                        styleColor: "#000000"

                                        scale: (root.activeCallingBall === tileTop.number) ? 1.35 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                    }
                                }
                            }
                        }
                    }

                    // MIDDLE DIVIDER STRIP: Variant Feature Banner + Marked/Hits Status
                    Rectangle {
                        id: middleDivider
                        anchors.top: topGrid.bottom
                        anchors.topMargin: 3
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 24
                        radius: 4
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: root.freeGamesRemaining > 0 ? "#78350f" :
                                       root.activeVariant === "power" ? "#3b0764" :
                                       root.activeVariant === "super" ? "#451a03" :
                                       root.activeVariant === "cleopatra" ? "#281706" : "#172554"
                            }
                            GradientStop {
                                position: 1.0
                                color: root.freeGamesRemaining > 0 ? "#451a03" :
                                       root.activeVariant === "power" ? "#1a042e" :
                                       root.activeVariant === "super" ? "#1c0b02" :
                                       root.activeVariant === "cleopatra" ? "#120a02" : "#0b1020"
                            }
                        }
                        border.color: root.freeGamesRemaining > 0 ? "#fbbf24" : root.themeBorder
                        border.width: root.freeGamesRemaining > 0 ? 1.5 : 1

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "MARKED  " + root.spotsCount + " / 10"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: root.spotsCount > 0 ? root.themeMarked : root.themeSubtext
                            }

                            // Center Game Feature Callout
                            Text {
                                anchors.centerIn: parent
                                text: root.freeGamesRemaining > 0 ? ("🏺 FREE SPINS: " + root.freeGamesRemaining + " LEFT (2X MULTIPLIER) 🏺") :
                                      root.activeVariant === "power" ? "⚡ 20TH BALL = 4X WIN MULTIPLIER" :
                                      root.activeVariant === "super" ? "👑 1ST BALL = 4X WIN MULTIPLIER" :
                                      root.activeVariant === "cleopatra" ? "🏺 20TH BALL = 12 FREE SPINS (2X WINS)" :
                                      "🎲 RETRO CASINO ODDS"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: root.freeGamesRemaining > 0 ? "#fde047" : root.themeAccent
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "HITS  " + root.totalHits
                                font.pixelSize: 11
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: root.totalHits > 0 ? root.themeHit : root.themeSubtext
                            }
                        }
                    }

                    // BOTTOM BANK: Numbers 41 to 80 (4 Rows x 10 Columns)
                    Grid {
                        id: bottomGrid
                        anchors.top: middleDivider.bottom
                        anchors.topMargin: 3
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: (parent.height - 30) / 2
                        columns: 10
                        rows: 4
                        spacing: 4

                        property real cellW: (width - 9 * spacing) / 10
                        property real cellH: (height - 3 * spacing) / 4

                        Repeater {
                            model: 40
                            Rectangle {
                                id: tileBottom
                                property int number: index + 41
                                property bool isSelected: root.selectedSpotsList.indexOf(number) >= 0
                                property bool isDrawn: root.drawnBallsList.indexOf(number) >= 0
                                property bool isHit: isSelected && isDrawn
                                property bool isHovered: gridContainer.hoveredTile === number
                                property bool isCavemanEgg: root.activeVariant === "caveman" && root.cavemanEggsList.indexOf(number) >= 0
                                property bool isGoldNugget: root.activeVariant === "goldmine" && root.goldNuggetsList.indexOf(number) >= 0
                                property bool isDynamite: root.activeVariant === "goldmine" && root.dynamiteSpot === number
                                property bool isSpecialHit: isHit && (
                                    (root.activeVariant === "super" && root.drawnBallsList.indexOf(number) === 0) ||
                                    (root.activeVariant === "power" && root.drawnBallsList.indexOf(number) === 19) ||
                                    (root.activeVariant === "cleopatra" && root.drawnBallsList.indexOf(number) === 19) ||
                                    (root.activeVariant === "triplepower" && (root.drawnBallsList.indexOf(number) === 0 || root.drawnBallsList.indexOf(number) === 19)) ||
                                    (root.activeVariant === "extradraw" && root.drawnBallsList.indexOf(number) >= 20)
                                )

                                width: bottomGrid.cellW
                                height: bottomGrid.cellH
                                radius: 5

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: tileBottom.isSpecialHit ? "#c084fc" :
                                               tileBottom.isHit ? "#fde047" :
                                               tileBottom.isSelected ? root.themeMarked :
                                               tileBottom.isDrawn ? root.themeTileDrawn :
                                               tileBottom.isHovered ? root.themeTileHover : root.themeTileBg
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: tileBottom.isSpecialHit ? "#7e22ce" :
                                               tileBottom.isHit ? "#d97706" :
                                               tileBottom.isSelected ? root.themeMarkedDark :
                                               tileBottom.isDrawn ? root.themeTileDrawnDark :
                                               tileBottom.isHovered ? root.themeTileHoverDark : root.themeTileBgDark
                                    }
                                }

                                border.color: tileBottom.isSpecialHit ? "#f43f5e" :
                                              tileBottom.isHit ? "#fef08a" :
                                              tileBottom.isSelected ? "#ffffff" :
                                              tileBottom.isDrawn ? root.themeAccent :
                                              tileBottom.isHovered ? root.themeAccent : root.themeBorder
                                border.width: (tileBottom.isHit || tileBottom.isSpecialHit) ? 2 : (tileBottom.isSelected ? 2 : (tileBottom.isDrawn ? 1.5 : (tileBottom.isHovered ? 1.5 : 1)))

                                scale: tileBottom.isHit ? 1.06 : (tileBottom.isHovered ? 1.03 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 1
                                    height: 1.5
                                    color: "#ffffff"
                                    opacity: tileBottom.isSelected || tileBottom.isHit ? 0.6 : 0.25
                                    radius: 2
                                }

                                // Animated Impact Shockwave Ring on Ball Call
                                Rectangle {
                                    id: shockwaveBottom
                                    anchors.centerIn: parent
                                    width: parent.width; height: parent.height; radius: parent.radius
                                    color: "transparent"
                                    border.color: tileBottom.isHit ? "#fde047" : "#38bdf8"
                                    border.width: tileBottom.isHit ? 2.5 : 1.5
                                    opacity: 0.0
                                    scale: 1.0

                                    Connections {
                                        target: root
                                        function onActiveCallingBallChanged() {
                                            if (root.activeCallingBall === tileBottom.number) {
                                                shockwaveBottomAnim.restart();
                                            }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: shockwaveBottomAnim
                                        NumberAnimation { target: shockwaveBottom; property: "scale"; from: 1.0; to: 2.2; duration: 320; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: shockwaveBottom; property: "opacity"; from: 0.95; to: 0.0; duration: 320; easing.type: Easing.OutQuad }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    // Themed Graphic Tokens: Scarab (Cleopatra), Dino Egg (Caveman), Gold Nugget (Gold Mine)
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(bottomGrid.cellW - 6, bottomGrid.cellH - 6)
                                        height: width
                                        source: (root.activeVariant === "cleopatra" && tileBottom.isSpecialHit) ? "assets/token_scarab.jpg" :
                                                tileBottom.isCavemanEgg ? "assets/token_egg.jpg" :
                                                tileBottom.isGoldNugget ? "assets/token_nugget.jpg" : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: ((tileBottom.isSpecialHit && root.activeVariant === "cleopatra") || tileBottom.isCavemanEgg || tileBottom.isGoldNugget)
                                        opacity: (tileBottom.isCavemanEgg && !tileBottom.isDrawn) ? 0.70 : 1.0
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !(
                                            (tileBottom.isSpecialHit && root.activeVariant === "cleopatra") ||
                                            (tileBottom.isCavemanEgg && !tileBottom.isDrawn) ||
                                            (tileBottom.isGoldNugget && !tileBottom.isDrawn)
                                        )
                                        text: tileBottom.isDynamite ? "🧨" :
                                              (tileBottom.isSpecialHit && root.activeVariant === "power") ? "⚡4X" :
                                              (tileBottom.isSpecialHit && root.activeVariant === "super") ? "👑4X" :
                                              (tileBottom.isSpecialHit && root.activeVariant === "triplepower") ? (root.triplePowerBall1Hit && root.triplePowerBall20Hit ? "💥9X" : "⚡3X") :
                                              (tileBottom.isSpecialHit && root.activeVariant === "extradraw") ? "🚨+" :
                                              (tileBottom.isCavemanEgg && tileBottom.isDrawn) ? (tileBottom.isHit ? "🦖" : "🥚") :
                                              (tileBottom.isGoldNugget && tileBottom.isDrawn) ? (tileBottom.isHit ? "💰" : "🪙") :
                                              tileBottom.isHit ? (
                                                  root.activeVariant === "cleopatra" ? "𓆣" :
                                                  root.activeVariant === "caveman" ? "🦖" :
                                                  root.activeVariant === "extradraw" ? "🚨" :
                                                  root.activeVariant === "goldmine" ? "⛏️" :
                                                  root.activeVariant === "triplepower" ? "⚛" : "$"
                                              ) : tileBottom.number.toString()
                                        font.pixelSize: tileBottom.isHit ? Math.max(12, Math.min(18, bottomGrid.cellH * 0.54)) : Math.max(11, Math.min(18, bottomGrid.cellH * 0.52))
                                        font.bold: true
                                        font.family: root.monoFontFamily
                                        color: (tileBottom.isHit || tileBottom.isSpecialHit) ? (root.activeVariant === "cleopatra" ? "#78350f" : "#000000") :
                                               tileBottom.isSelected ? "#ffffff" :
                                               tileBottom.isDrawn ? "#ffffff" : root.themeFg
                                        style: tileBottom.isSelected ? Text.Raised : Text.Normal
                                        styleColor: "#000000"

                                        scale: (root.activeCallingBall === tileBottom.number) ? 1.35 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                    }
                                }
                            }
                        }
                    }

                    // Interactive Swipe & Touch Gesture Handler for continuous selection / deselection
                    MouseArea {
                        id: gridSwipeArea
                        anchors.fill: parent
                        z: 100
                        hoverEnabled: true
                        cursorShape: root.isDrawing ? Qt.ArrowCursor : (gridContainer.hoveredTile > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor)

                        onPressed: function(mouse) {
                            if (root.isDrawing) return;
                            var num = gridContainer.getTileNumberAt(mouse.x, mouse.y);
                            if (num >= 1 && num <= 80) {
                                var isSel = root.selectedSpotsList.indexOf(num) >= 0;
                                if (isSel) {
                                    gridContainer.swipeMode = "deselect";
                                    root.setSpotState(num, false);
                                } else {
                                    if (root.spotsCount < 10) {
                                        gridContainer.swipeMode = "select";
                                        root.setSpotState(num, true);
                                    } else {
                                        gridContainer.swipeMode = "blocked";
                                        soundToast.show("⚠️ Max 10 Spots Allowed");
                                        root.playSound("keno_deselect");
                                    }
                                }
                                gridContainer.lastInteractedTile = num;
                            } else {
                                gridContainer.swipeMode = "";
                                gridContainer.lastInteractedTile = -1;
                            }
                        }

                        onPositionChanged: function(mouse) {
                            var num = gridContainer.getTileNumberAt(mouse.x, mouse.y);
                            gridContainer.hoveredTile = num;

                            if (!root.isDrawing && (mouse.buttons & Qt.LeftButton) && gridContainer.swipeMode !== "" && gridContainer.swipeMode !== "blocked") {
                                if (num >= 1 && num <= 80 && num !== gridContainer.lastInteractedTile) {
                                    gridContainer.lastInteractedTile = num;
                                    var isSel = root.selectedSpotsList.indexOf(num) >= 0;

                                    if (gridContainer.swipeMode === "select") {
                                        if (!isSel) {
                                            if (root.spotsCount < 10) {
                                                root.setSpotState(num, true);
                                            } else {
                                                soundToast.show("⚠️ Max 10 Spots Reached");
                                            }
                                        }
                                    } else if (gridContainer.swipeMode === "deselect") {
                                        if (isSel) {
                                            root.setSpotState(num, false);
                                        }
                                    }
                                }
                            }
                        }

                        onReleased: function(mouse) {
                            gridContainer.swipeMode = "";
                            gridContainer.lastInteractedTile = -1;
                        }

                        onCanceled: {
                            gridContainer.swipeMode = "";
                            gridContainer.lastInteractedTile = -1;
                            gridContainer.hoveredTile = -1;
                        }

                        onExited: {
                            gridContainer.hoveredTile = -1;
                        }
                    }
                }

                // =============================================================
                // RIGHT SIDE PANEL: 3D GLASS BUBBLE TUMBLER + 20-BALL TRAY + PAYTABLE
                // =============================================================
                Item {
                    id: sidePanel
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: root.isVerticalLayout ? parent.width : Math.max(260, Math.min(320, parent.width * 0.33))
                    height: root.isVerticalLayout ? Math.max(210, Math.min(240, splitArea.height * 0.35)) : parent.height

                    // 1. DYNAMIC PNEUMATIC GLASS BLOWER & CALLING MAGNIFIER
                    Rectangle {
                        id: blowerContainer
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: root.isVerticalLayout ? Math.floor((parent.width - 8) * 0.48) : parent.width
                        height: root.isVerticalLayout ? Math.floor((parent.height - 6) * 0.58) : (root.isCompactHeader ? 78 : 106)
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#151c30" }
                            GradientStop { position: 1.0; color: "#080c18" }
                        }
                        border.color: "#28334e"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            // =========================================================
                            // HIGH-END 3D CASINO LOTTERY BLOWER TUMBLER (Canvas Physics)
                            // =========================================================
                            Item {
                                width: 106
                                height: 102
                                anchors.verticalCenter: parent.verticalCenter

                                // Polished Chrome Outer Bezel Ring
                                Rectangle {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -4
                                    width: 96; height: 96; radius: 48
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#f8fafc" }
                                        GradientStop { position: 0.25; color: "#94a3b8" }
                                        GradientStop { position: 0.75; color: "#334155" }
                                        GradientStop { position: 1.0; color: "#0f172a" }
                                    }
                                    border.color: root.isDrawing ? root.themeAccent : Qt.darker(root.themeAccent, 1.3)
                                    border.width: 2

                                    // Inner Neon Ring
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 90; height: 90; radius: 45
                                        color: "#030712"
                                        border.color: Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, root.isDrawing ? 0.8 : 0.25)
                                        border.width: 1.5
                                    }
                                }

                                // Chrome Compressor Pedestal Base
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52; height: 14; radius: 3
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#cbd5e1" }
                                        GradientStop { position: 0.45; color: "#64748b" }
                                        GradientStop { position: 1.0; color: "#1e293b" }
                                    }
                                    border.color: "#94a3b8"
                                    border.width: 1

                                    // Air Grille Slots
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Repeater {
                                            model: 5
                                            Rectangle { width: 3; height: 7; radius: 1; color: "#090d1a" }
                                        }
                                    }
                                }

                                // Interactive 2D/3D Canvas Blower Engine
                                Canvas {
                                    id: tumblerCanvas
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -4
                                    width: 88; height: 88

                                    property real turbineAngle: 0
                                    property var balls: []
                                    property var particles: []

                                    Component.onCompleted: {
                                        var colors = [
                                            "#ef4444", "#3b82f6", "#10b981", "#f59e0b",
                                            "#8b5cf6", "#ec4899", "#06b6d4", "#f97316",
                                            "#eab308", "#14b8a6", "#6366f1", "#d946ef",
                                            "#84cc16", "#0ea5e9", "#f43f5e", "#a855f7"
                                        ];
                                        var numbers = [7, 14, 21, 35, 42, 58, 77, 3, 11, 28, 49, 63, 70, 80, 19, 52];
                                        var arr = [];
                                        var cx = width / 2;
                                        var cy = height / 2;
                                        var maxR = 29;
                                        for (var i = 0; i < 16; i++) {
                                            var ang = (i / 16) * Math.PI * 2 + Math.random() * 0.3;
                                            var dist = 5 + Math.random() * (maxR - 12);
                                            arr.push({
                                                x: cx + Math.cos(ang) * dist,
                                                y: cy + Math.sin(ang) * dist,
                                                vx: (Math.random() - 0.5) * 3.0,
                                                vy: -1.5 - Math.random() * 2.5,
                                                radius: 8.8,
                                                color: colors[i % colors.length],
                                                number: numbers[i],
                                                angle: Math.random() * Math.PI * 2,
                                                va: (Math.random() - 0.5) * 0.2
                                            });
                                        }
                                        balls = arr;

                                        var pts = [];
                                        for (var p = 0; p < 12; p++) {
                                            pts.push({
                                                x: cx + (Math.random() - 0.5) * 20,
                                                y: cy + 12 + Math.random() * 16,
                                                vy: -1.8 - Math.random() * 2.2,
                                                size: 1.5 + Math.random() * 1.8
                                            });
                                        }
                                        particles = pts;
                                        requestPaint();
                                    }

                                    onPaint: {
                                        var ctx = tumblerCanvas.getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        var cx = width / 2;
                                        var cy = height / 2;
                                        var maxR = 41; // Sphere radius

                                        // 1. Clip inside glass sphere
                                        ctx.save();
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, maxR, 0, Math.PI * 2);
                                        ctx.clip();

                                        // 2. Interior Glass Chamber Gradient
                                        var chamberGrad = ctx.createRadialGradient(cx, cy, 4, cx, cy, maxR);
                                        chamberGrad.addColorStop(0.0, "#0e1c3a");
                                        chamberGrad.addColorStop(0.6, "#081026");
                                        chamberGrad.addColorStop(1.0, "#030614");
                                        ctx.fillStyle = chamberGrad;
                                        ctx.fillRect(0, 0, width, height);

                                        // 3. Air Intake Blower Turbine (Bottom)
                                        var turbY = cy + maxR - 8;
                                        ctx.save();
                                        ctx.translate(cx, turbY);
                                        ctx.fillStyle = "#1e293b";
                                        ctx.beginPath();
                                        ctx.ellipse(0, 0, 16, 5, 0, 0, Math.PI * 2);
                                        ctx.fill();

                                        ctx.strokeStyle = "#94a3b8";
                                        ctx.lineWidth = 1.5;
                                        for (var b = 0; b < 6; b++) {
                                            var blAng = turbineAngle + (b * Math.PI / 3);
                                            var bx = Math.cos(blAng) * 12;
                                            var by = Math.sin(blAng) * 3.5;
                                            ctx.beginPath();
                                            ctx.moveTo(0, 0);
                                            ctx.lineTo(bx, by);
                                            ctx.stroke();
                                        }
                                        ctx.restore();

                                        // 4. Air Vortex Stream Particles
                                        if (root.isDrawing) {
                                            ctx.fillStyle = "rgba(147, 197, 253, 0.65)";
                                            for (var pi = 0; pi < particles.length; pi++) {
                                                var pt = particles[pi];
                                                ctx.beginPath();
                                                ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
                                                ctx.fill();
                                            }
                                        }

                                        // 5. Draw 3D Numbered Lottery Balls
                                        for (var i = 0; i < balls.length; i++) {
                                            var ball = balls[i];
                                            ctx.save();
                                            ctx.translate(ball.x, ball.y);
                                            ctx.rotate(ball.angle);

                                            var br = ball.radius;

                                            // Drop shadow under ball
                                            var shadowGrad = ctx.createRadialGradient(0, br * 0.4, br * 0.3, 0, br * 0.4, br * 1.2);
                                            shadowGrad.addColorStop(0, "rgba(0,0,0,0.4)");
                                            shadowGrad.addColorStop(1, "rgba(0,0,0,0)");
                                            ctx.fillStyle = shadowGrad;
                                            ctx.beginPath();
                                            ctx.arc(0, br * 0.4, br * 1.2, 0, Math.PI * 2);
                                            ctx.fill();

                                            // 3D Sphere Shading
                                            var ballGrad = ctx.createRadialGradient(-br * 0.35, -br * 0.35, br * 0.1, 0, 0, br);
                                            ballGrad.addColorStop(0.0, "#ffffff");
                                            ballGrad.addColorStop(0.25, ball.color);
                                            ballGrad.addColorStop(0.85, ball.color);
                                            ballGrad.addColorStop(1.0, "#050814");

                                            ctx.fillStyle = ballGrad;
                                            ctx.beginPath();
                                            ctx.arc(0, 0, br, 0, Math.PI * 2);
                                            ctx.fill();

                                            // Outer Rim Highlight
                                            ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
                                            ctx.lineWidth = 0.7;
                                            ctx.stroke();

                                            // Inner White Number Badge
                                            var badgeR = br * 0.54;
                                            ctx.fillStyle = "#ffffff";
                                            ctx.beginPath();
                                            ctx.arc(0, 0, badgeR, 0, Math.PI * 2);
                                            ctx.fill();

                                            // Printed Bold Number
                                            ctx.fillStyle = "#0f172a";
                                            ctx.font = "bold 9px monospace";
                                            ctx.textAlign = "center";
                                            ctx.textBaseline = "middle";
                                            ctx.fillText(ball.number.toString(), 0, 0.5);

                                            // Specular gloss arc on top-left of ball
                                            ctx.strokeStyle = "rgba(255, 255, 255, 0.75)";
                                            ctx.lineWidth = 0.9;
                                            ctx.beginPath();
                                            ctx.arc(0, 0, br * 0.75, Math.PI * 1.0, Math.PI * 1.5);
                                            ctx.stroke();

                                            ctx.restore();
                                        }

                                        // 6. Glass Dome Reflections & Highlights (Drawn over balls)
                                        // Curved Gloss Reflection
                                        var glareGrad = ctx.createLinearGradient(cx - 24, cy - 32, cx - 8, cy - 14);
                                        glareGrad.addColorStop(0.0, "rgba(255, 255, 255, 0.55)");
                                        glareGrad.addColorStop(0.5, "rgba(255, 255, 255, 0.18)");
                                        glareGrad.addColorStop(1.0, "rgba(255, 255, 255, 0.0)");
                                        ctx.fillStyle = glareGrad;
                                        ctx.beginPath();
                                        ctx.ellipse(cx - 15, cy - 18, 15, 7.5, -Math.PI / 4, 0, Math.PI * 2);
                                        ctx.fill();

                                        // Bottom-Right Rim Reflection
                                        ctx.strokeStyle = "rgba(147, 197, 253, 0.25)";
                                        ctx.lineWidth = 2.0;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, maxR - 2, Math.PI * 0.15, Math.PI * 0.45);
                                        ctx.stroke();

                                        // Spherical Perimeter Rim Light
                                        ctx.strokeStyle = Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.45);
                                        ctx.lineWidth = 1.0;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, maxR - 1, 0, Math.PI * 2);
                                        ctx.stroke();

                                        ctx.restore(); // end clip
                                    }

                                    // 60 FPS Physics Simulation & Animation Loop
                                    Timer {
                                        interval: 16
                                        running: true
                                        repeat: true
                                        onTriggered: {
                                            var cx = tumblerCanvas.width / 2;
                                            var cy = tumblerCanvas.height / 2;
                                            var maxR = 30; // Ball movement boundary
                                            tumblerCanvas.turbineAngle += root.isDrawing ? 0.35 : 0.05;

                                            var balls = tumblerCanvas.balls;
                                            if (!balls) return;

                                            for (var i = 0; i < balls.length; i++) {
                                                var b = balls[i];

                                                if (root.isDrawing) {
                                                    // Air blower jet from bottom turbine
                                                    var dx = b.x - cx;
                                                    var dy = b.y - (cy + 25);
                                                    var distFromFan = Math.sqrt(dx*dx + dy*dy);
                                                    if (distFromFan < 55) {
                                                        b.vy -= (3.2 - distFromFan / 55 * 2.0);
                                                        b.vx += (dx > 0 ? 0.9 : -0.9) + (Math.random() - 0.5) * 2.2;
                                                    }
                                                    // Vortex cyclonic swirl around chamber
                                                    var rx = b.x - cx;
                                                    var ry = b.y - cy;
                                                    b.vx += -ry * 0.05 + (Math.random() - 0.5) * 1.5;
                                                    b.vy += rx * 0.05 + (Math.random() - 0.5) * 1.5;

                                                    // Gravity
                                                    b.vy += 0.25;
                                                } else {
                                                    // Idle: gentle settle on air cushion
                                                    b.vy += 0.32;
                                                    b.vx *= 0.94;
                                                    if (b.y > cy + 16) {
                                                        b.vy -= 0.15;
                                                    }
                                                }

                                                // Velocity damping
                                                b.vx = Math.max(-5.0, Math.min(5.0, b.vx * 0.985));
                                                b.vy = Math.max(-5.5, Math.min(5.5, b.vy * 0.985));

                                                // Update position & rotation
                                                b.x += b.vx;
                                                b.y += b.vy;
                                                b.angle += b.va;

                                                // Dome boundary collision
                                                var curDist = Math.sqrt((b.x - cx)*(b.x - cx) + (b.y - cy)*(b.y - cy));
                                                if (curDist > maxR) {
                                                    var nx = (b.x - cx) / curDist;
                                                    var ny = (b.y - cy) / curDist;
                                                    var dot = b.vx * nx + b.vy * ny;
                                                    b.vx = (b.vx - 1.8 * dot * nx) * 0.82;
                                                    b.vy = (b.vy - 1.8 * dot * ny) * 0.82;
                                                    b.x = cx + nx * maxR;
                                                    b.y = cy + ny * maxR;
                                                    b.va = (Math.random() - 0.5) * 0.4;
                                                }
                                            }

                                            // Update air vortex particles
                                            var pts = tumblerCanvas.particles;
                                            if (pts) {
                                                for (var p = 0; p < pts.length; p++) {
                                                    pts[p].y += pts[p].vy;
                                                    pts[p].x += (Math.random() - 0.5) * 1.5;
                                                    if (pts[p].y < cy - 22) {
                                                        pts[p].y = cy + 14 + Math.random() * 14;
                                                        pts[p].x = cx + (Math.random() - 0.5) * 14;
                                                    }
                                                }
                                            }

                                            tumblerCanvas.requestPaint();
                                        }
                                    }
                                }
                            }

                            // Pneumatic Glass Vacuum Chute connecting globe to caller
                            Item {
                                width: 14; height: 80
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10; height: parent.height
                                    radius: 5
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.rgba(0.2, 0.4, 0.8, 0.3) }
                                        GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, root.isDrawing ? 0.7 : 0.2) }
                                        GradientStop { position: 1.0; color: Qt.rgba(0.2, 0.4, 0.8, 0.3) }
                                    }
                                    border.color: root.isDrawing ? root.themeAccent : "#475569"
                                    border.width: 1
                                }

                                // Metallic Collar Brackets (top & bottom)
                                Rectangle {
                                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                    width: 14; height: 5; radius: 1; color: "#94a3b8"
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    width: 14; height: 5; radius: 1; color: "#94a3b8"
                                }
                            }

                            // Active Calling Ball Magnifying Lens with Pop & Shockwave Animation
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ? "🏺 SCARAB BALL 🏺" :
                                          (root.activeVariant === "power" && root.drawnBallsList.length === 20) ? "⚡ 4X POWER BALL ⚡" :
                                          (root.activeVariant === "super" && root.drawnBallsList.length === 1) ? "👑 4X SUPER BALL 👑" :
                                          (root.isDrawing ? "CALLING BALL" : "BALL CALLER")
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ? "#fbbf24" :
                                           (root.activeVariant === "power" && root.drawnBallsList.length === 20) ? "#e879f9" :
                                           (root.activeVariant === "super" && root.drawnBallsList.length === 1) ? "#fde047" : root.themeSubtext
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                // Circular Chrome Magnifying Ring
                                Item {
                                    width: 72; height: 72

                                    // Expanding Shockwave Ring on Call
                                    Rectangle {
                                        id: lensShockwave
                                        anchors.centerIn: parent
                                        width: 60; height: 60; radius: 30
                                        color: "transparent"
                                        border.color: (root.hitBallsList.indexOf(root.activeCallingBall) >= 0) ? "#fbbf24" : root.themeAccent
                                        border.width: 3
                                        scale: 1.0
                                        opacity: 0.0

                                        Connections {
                                            target: root
                                            function onActiveCallingBallChanged() {
                                                if (root.activeCallingBall > 0) {
                                                    callerLensAnim.restart();
                                                }
                                            }
                                        }

                                        ParallelAnimation {
                                            id: callerLensAnim
                                            NumberAnimation { target: lensShockwave; property: "scale"; from: 1.0; to: 1.9; duration: 320; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: lensShockwave; property: "opacity"; from: 1.0; to: 0.0; duration: 320; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: caller3DBall; property: "scale"; from: 0.15; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                            NumberAnimation { target: caller3DBall; property: "rotation"; from: -180; to: 0; duration: 250; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    // Chrome Magnifier Bezel
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 68; height: 68; radius: 34
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#f8fafc" }
                                            GradientStop { position: 0.35; color: "#64748b" }
                                            GradientStop { position: 0.75; color: "#334155" }
                                            GradientStop { position: 1.0; color: "#0f172a" }
                                        }
                                        border.color: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ? "#fbbf24" :
                                                      root.activeCallingBall > 0 ? (
                                                          (root.hitBallsList.indexOf(root.activeCallingBall) >= 0) ? "#fbbf24" : root.themeAccent
                                                      ) : "#475569"
                                        border.width: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ? 3 : 2

                                        // Dark Lens Convex Interior
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 58; height: 58; radius: 29
                                            color: "#050b18"

                                            // 3D Numbered Lottery Ball inside Magnifier
                                            Rectangle {
                                                id: caller3DBall
                                                anchors.centerIn: parent
                                                width: 50; height: 50; radius: 25
                                                scale: 1.0
                                                rotation: 0
                                                property bool isCallerSpecial: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ||
                                                                               (root.activeVariant === "caveman" && root.cavemanEggsList.indexOf(root.activeCallingBall) >= 0) ||
                                                                               (root.activeVariant === "goldmine" && root.goldNuggetsList.indexOf(root.activeCallingBall) >= 0)
                                                property bool isCallerExtraDraw: root.activeVariant === "extradraw" && root.drawnBallsList.length > 20

                                                gradient: Gradient {
                                                    GradientStop {
                                                        position: 0.0
                                                        color: caller3DBall.isCallerExtraDraw ? "#fca5a5" :
                                                               caller3DBall.isCallerSpecial ? "#fde68a" :
                                                               root.activeCallingBall > 0 ? "#ffffff" : "#334155"
                                                    }
                                                    GradientStop {
                                                        position: 0.35
                                                        color: caller3DBall.isCallerExtraDraw ? "#ef4444" :
                                                               caller3DBall.isCallerSpecial ? "#f59e0b" :
                                                               root.activeCallingBall > 0 ? (
                                                                   (root.hitBallsList.indexOf(root.activeCallingBall) >= 0) ? "#fbbf24" : "#38bdf8"
                                                               ) : "#1e293b"
                                                    }
                                                    GradientStop {
                                                        position: 1.0
                                                        color: caller3DBall.isCallerExtraDraw ? "#7f1d1d" :
                                                               caller3DBall.isCallerSpecial ? "#78350f" :
                                                               root.activeCallingBall > 0 ? (
                                                                   (root.hitBallsList.indexOf(root.activeCallingBall) >= 0) ? "#78350f" : "#0c4a6e"
                                                               ) : "#0f172a"
                                                    }
                                                }
                                                border.color: caller3DBall.isCallerExtraDraw ? "#ef4444" :
                                                              caller3DBall.isCallerSpecial ? "#fbbf24" : "#ffffff"
                                                border.width: (caller3DBall.isCallerSpecial || caller3DBall.isCallerExtraDraw) ? 2 : 1.5

                                                // Themed 3D Tokens for Cleopatra, Caveman, Gold Mine
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 42; height: 42
                                                    source: (root.activeVariant === "cleopatra" && root.drawnBallsList.length === 20) ? "assets/token_scarab.jpg" :
                                                            (root.activeVariant === "caveman" && root.cavemanEggsList.indexOf(root.activeCallingBall) >= 0) ? "assets/token_egg.jpg" :
                                                            (root.activeVariant === "goldmine" && root.goldNuggetsList.indexOf(root.activeCallingBall) >= 0) ? "assets/token_nugget.jpg" : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    visible: caller3DBall.isCallerSpecial
                                                    z: 3
                                                }

                                                // Inner White / Gold Number Badge
                                                Rectangle {
                                                    anchors.centerIn: !caller3DBall.isCallerSpecial ? parent : undefined
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: caller3DBall.isCallerSpecial ? parent.bottom : undefined
                                                    anchors.bottomMargin: caller3DBall.isCallerSpecial ? 2 : 0
                                                    width: caller3DBall.isCallerSpecial ? 30 : 26
                                                    height: caller3DBall.isCallerSpecial ? 16 : 26
                                                    radius: caller3DBall.isCallerSpecial ? 4 : 13
                                                    color: caller3DBall.isCallerSpecial ? "#fbbf24" :
                                                           (root.activeCallingBall > 0 ? "#ffffff" : "transparent")
                                                    border.color: caller3DBall.isCallerSpecial ? "#000000" : "transparent"
                                                    border.width: 1
                                                    z: 6

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.activeCallingBall > 0 ? root.activeCallingBall.toString() : "—"
                                                        font.pixelSize: caller3DBall.isCallerSpecial ? 11 : 16
                                                        font.bold: true
                                                        font.family: root.monoFontFamily
                                                        color: caller3DBall.isCallerSpecial ? "#000000" :
                                                               (root.activeCallingBall > 0 ? "#0f172a" : "#64748b")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. 20-BALL DRAWN TRAY (2 Rows of 10 Animated 3D Balls)
                    Rectangle {
                        id: drawnListCard
                        anchors.top: blowerContainer.bottom
                        anchors.topMargin: 6
                        anchors.left: parent.left
                        width: root.isVerticalLayout ? Math.floor((parent.width - 8) * 0.48) : parent.width
                        height: root.isVerticalLayout ? (parent.height - blowerContainer.height - 6) : (root.isCompactHeader ? 54 : 76)
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.activeVariant === "cleopatra" ? "#24190c" : "#161b2e" }
                            GradientStop { position: 1.0; color: root.activeVariant === "cleopatra" ? "#120a02" : "#0a0e1a" }
                        }
                        border.color: root.activeVariant === "cleopatra" ? "#b45309" : "#2d3550"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Text {
                                text: "DRAWN BALLS (" + root.drawnBallsList.length + " / " + ((root.activeVariant === "extradraw" && root.extraDrawTriggered) ? "23 [EXTRA]" : "20") + ")"
                                font.pixelSize: 8
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? "#f87171" : root.themeSubtext
                            }

                            // 2 Rows of Spherical Balls
                            Grid {
                                columns: (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? 12 : 10
                                rows: 2
                                spacing: 3
                                width: parent.width

                                Repeater {
                                    model: (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? 23 : 20
                                    Rectangle {
                                        property int slotIdx: index
                                        property bool hasBall: slotIdx < root.drawnBallsList.length
                                        property int num: hasBall ? root.drawnBallsList[slotIdx] : 0
                                        property bool isHit: hasBall && (root.hitBallsList.indexOf(num) >= 0)
                                        property bool isExtra: slotIdx >= 20
                                        property bool isSpecial: hasBall && (
                                            (root.activeVariant === "super" && slotIdx === 0 && isHit) ||
                                            (root.activeVariant === "power" && slotIdx === 19 && isHit) ||
                                            (root.activeVariant === "cleopatra" && slotIdx === 19 && isHit) ||
                                            (root.activeVariant === "triplepower" && (slotIdx === 0 || slotIdx === 19) && isHit) ||
                                            isExtra
                                        )

                                        width: (parent.width - ((parent.columns - 1) * parent.spacing)) / parent.columns
                                        height: 30
                                        radius: 15 // Spherical bead

                                        scale: hasBall ? 1.0 : 0.75
                                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: !hasBall ? "#0f172a" :
                                                       isExtra ? (isHit ? "#fef08a" : "#ef4444") :
                                                       (root.activeVariant === "cleopatra" && slotIdx === 19) ? (isSpecial ? "#fef08a" : "#f59e0b") :
                                                       isSpecial ? "#e879f9" :
                                                       isHit ? "#fef08a" : "#93c5fd"
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: !hasBall ? "#020617" :
                                                       isExtra ? (isHit ? "#b45309" : "#7f1d1d") :
                                                       (root.activeVariant === "cleopatra" && slotIdx === 19) ? (isSpecial ? "#047857" : "#78350f") :
                                                       isSpecial ? "#7e22ce" :
                                                       isHit ? "#b45309" : "#1d4ed8"
                                            }
                                        }
                                        border.color: isExtra ? (isHit ? "#fef08a" : "#fca5a5") :
                                                      (root.activeVariant === "cleopatra" && slotIdx === 19 && hasBall) ? "#fbbf24" :
                                                      (hasBall ? "#ffffff" : "#1e293b")
                                        border.width: (isHit || isExtra || (root.activeVariant === "cleopatra" && slotIdx === 19 && hasBall)) ? 2 : 0.75

                                        Text {
                                            anchors.centerIn: parent
                                            text: hasBall ? num.toString() : ""
                                            font.pixelSize: (root.activeVariant === "extradraw" && root.extraDrawTriggered) ? 9 : 10
                                            font.bold: true
                                            font.family: root.monoFontFamily
                                            color: (isHit || isSpecial || isExtra || (root.activeVariant === "cleopatra" && slotIdx === 19)) ? "#000000" : "#ffffff"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. DYNAMIC CASINO PAYTABLE CARD
                    Rectangle {
                        id: paytableCard
                        anchors.top: root.isVerticalLayout ? parent.top : drawnListCard.bottom
                        anchors.topMargin: root.isVerticalLayout ? 0 : 6
                        anchors.bottom: parent.bottom
                        anchors.left: root.isVerticalLayout ? blowerContainer.right : parent.left
                        anchors.leftMargin: root.isVerticalLayout ? 8 : 0
                        anchors.right: parent.right
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#161b2e" }
                            GradientStop { position: 1.0; color: "#0a0e1a" }
                        }
                        border.color: root.totalHits > 0 ? "#fbbf24" : "#2d3550"
                        border.width: 1.5

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Item {
                                width: parent.width
                                height: 16
                                Text {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    text: "CASINO PAYTABLE"
                                    font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily
                                    color: root.themeAccent
                                }
                                Text {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: root.spotsCount > 0 ? (root.spotsCount + " SPOTS") : "SELECT SPOTS"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily
                                    color: root.themeSubtext
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: "#2d3550" }

                            Item {
                                width: parent.width
                                height: 14
                                Text { anchors.left: parent.left; text: "HITS"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#64748b" }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MULTIPLIER"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#64748b" }
                                Text { anchors.right: parent.right; text: "PAYOUT"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#64748b" }
                            }

                            ListView {
                                id: paytableListView
                                width: parent.width
                                height: parent.height - 44
                                clip: true
                                interactive: true
                                boundsBehavior: Flickable.StopAtBounds

                                model: {
                                    var spots = root.spotsCount > 0 ? root.spotsCount : 5;
                                    var pt = Engine.getPaytableForSpots(spots);
                                    if (!pt) return [];
                                    var arr = [];
                                    var keys = Object.keys(pt).map(function(k) { return parseInt(k); }).sort(function(a, b) { return b - a; });
                                    for (var i = 0; i < keys.length; i++) {
                                        var hits = keys[i];
                                        var mult = pt[hits];
                                        arr.push({ hits: hits, mult: mult, payout: mult * root.betAmount * root.currentMultiplier });
                                    }
                                    return arr;
                                }

                                delegate: Rectangle {
                                    width: paytableListView.width
                                    height: 24
                                    radius: 3
                                    property bool isWinningTier: root.totalHits >= modelData.hits && modelData.hits > 0 || (modelData.hits === 0 && root.totalHits === 0 && root.drawnBallsList.length === 20)
                                    property bool isCurrentHitTier: {
                                        if (root.totalHits <= 0) return false;
                                        var spots = root.spotsCount > 0 ? root.spotsCount : 5;
                                        var pt = Engine.getPaytableForSpots(spots);
                                        if (!pt) return false;
                                        if (modelData.hits === root.totalHits) return true;
                                        var keys = Object.keys(pt).map(function(k) { return parseInt(k); }).sort(function(a, b) { return b - a; });
                                        for (var j = 0; j < keys.length; j++) {
                                            if (root.totalHits >= keys[j]) {
                                                return modelData.hits === keys[j];
                                            }
                                        }
                                        return false;
                                    }

                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: isCurrentHitTier ? "#f59e0b" :
                                                   isWinningTier ? Qt.rgba(0.96, 0.62, 0.04, 0.35) : "transparent"
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: isCurrentHitTier ? "#b45309" :
                                                   isWinningTier ? Qt.rgba(0.7, 0.33, 0.04, 0.2) : "transparent"
                                        }
                                    }
                                    border.color: isCurrentHitTier ? "#fef08a" : isWinningTier ? "#f59e0b" : "transparent"
                                    border.width: isCurrentHitTier ? 1.5 : (isWinningTier ? 1 : 0)

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6; anchors.rightMargin: 6

                                        Text {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.hits + " Hits"
                                            font.pixelSize: 10; font.bold: isCurrentHitTier || isWinningTier; font.family: root.monoFontFamily
                                            color: isCurrentHitTier ? "#000000" : (isWinningTier ? "#fbbf24" : "#ffffff")
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.mult + "X"
                                            font.pixelSize: 10; font.bold: isCurrentHitTier || isWinningTier; font.family: root.monoFontFamily
                                            color: isCurrentHitTier ? "#000000" : (isWinningTier ? "#fbbf24" : "#94a3b8")
                                        }

                                        Text {
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.payout + " cr"
                                            font.pixelSize: 10; font.bold: isCurrentHitTier || isWinningTier; font.family: root.monoFontFamily
                                            color: isCurrentHitTier ? "#000000" : (isWinningTier ? "#fef08a" : root.themeHit)
                                        }
                                    }
                                }

                                // Interactive scrollbar track
                                Rectangle {
                                    id: paytableScrollTrack
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    visible: paytableListView.visibleArea.heightRatio < 1.0

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        y: paytableListView.visibleArea.yPosition * paytableScrollTrack.height
                                        height: Math.max(14, paytableListView.visibleArea.heightRatio * paytableScrollTrack.height)
                                        radius: 2
                                        color: root.themeAccent
                                        opacity: 0.8
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TIER 4: THE PHYSICAL CASINO VLT CONSOLE DECK (Images 2, 4, 5)
        // =====================================================================
        Rectangle {
            id: bottomControlBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: root.isCompactHeader ? 46 : 56
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.themeCardBg }
                GradientStop { position: 0.5; color: root.themeBoardBg }
                GradientStop { position: 1.0; color: root.themeBg }
            }
            border.color: root.themeBorder
            border.width: 1.5

            readonly property bool isCrowded: bottomControlBar.width < 780

            // Highlight line across the top of the mechanical deck
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 1; height: 1; color: "#ffffff"; opacity: 0.2
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: bottomControlBar.isCrowded ? 4 : 8

                // Quick Picks: [PICK 3] [PICK 5] [PICK 10] [HOT] [ERASE]
                Rectangle {
                    width: bottomControlBar.isCrowded ? 34 : 64
                    height: bottomControlBar.isCrowded ? 34 : 40
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                        GradientStop { position: 1.0; color: root.themeCardBg }
                    }
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bottomControlBar.isCrowded ? "3" : "PICK 3"
                        font.pixelSize: bottomControlBar.isCrowded ? 12 : 11
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.doQuickPick(3)
                    }
                }

                Rectangle {
                    width: bottomControlBar.isCrowded ? 34 : 64
                    height: bottomControlBar.isCrowded ? 34 : 40
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                        GradientStop { position: 1.0; color: root.themeCardBg }
                    }
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bottomControlBar.isCrowded ? "5" : "PICK 5"
                        font.pixelSize: bottomControlBar.isCrowded ? 12 : 11
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.doQuickPick(5)
                    }
                }

                Rectangle {
                    width: bottomControlBar.isCrowded ? 36 : 68
                    height: bottomControlBar.isCrowded ? 34 : 40
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                        GradientStop { position: 1.0; color: root.themeCardBg }
                    }
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bottomControlBar.isCrowded ? "10" : "PICK 10"
                        font.pixelSize: bottomControlBar.isCrowded ? 12 : 11
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.doQuickPick(10)
                    }
                }

                Rectangle {
                    width: bottomControlBar.isCrowded ? 34 : 56
                    height: bottomControlBar.isCrowded ? 34 : 40
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#451a03" }
                        GradientStop { position: 1.0; color: "#270d02" }
                    }
                    border.color: "#f59e0b"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bottomControlBar.isCrowded ? "🔥" : "🔥 HOT"
                        font.pixelSize: bottomControlBar.isCrowded ? 12 : 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#fbbf24"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.doQuickPickHot(root.spotsCount > 0 ? root.spotsCount : 5)
                    }
                }

                Rectangle {
                    width: bottomControlBar.isCrowded ? 42 : 78
                    height: bottomControlBar.isCrowded ? 34 : 40
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#4c0519" }
                        GradientStop { position: 1.0; color: "#1f0209" }
                    }
                    border.color: "#f43f5e"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: bottomControlBar.isCrowded ? "CLR" : "ERASE [C]"
                        font.pixelSize: bottomControlBar.isCrowded ? 10 : 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#fda4af"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearBoard()
                    }
                }

                // Authentic 25¢ Gold Coin Emblem (Vegas Bartop detail - Images 2 & 5)
                Rectangle {
                    width: 40; height: 36; radius: 18
                    visible: !bottomControlBar.isCrowded
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#fef08a" }
                        GradientStop { position: 0.5; color: "#eab308" }
                        GradientStop { position: 1.0; color: "#854d0e" }
                    }
                    border.color: "#ca8a04"; border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "25¢"
                        font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                        color: "#000000"
                    }
                }

                // Bet Selector: [ - ] [ BET: X ] [ + ] [ MAX BET ]
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: bottomControlBar.isCrowded ? 3 : 4

                    Rectangle {
                        width: bottomControlBar.isCrowded ? 28 : 36
                        height: bottomControlBar.isCrowded ? 34 : 40
                        radius: 5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                            GradientStop { position: 1.0; color: root.themeCardBg }
                        }
                        border.color: root.themeBorder; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            font.pixelSize: 16; font.bold: true; font.family: root.monoFontFamily
                            color: "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeBet(-1)
                        }
                    }

                    Rectangle {
                        width: bottomControlBar.isCrowded ? 44 : 58
                        height: bottomControlBar.isCrowded ? 34 : 40
                        radius: 5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.themeTileBgDark }
                            GradientStop { position: 1.0; color: root.themeCardBg }
                        }
                        border.color: root.themeAccent; border.width: 1.5
                        Column {
                            anchors.centerIn: parent; spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "BET"
                                font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily
                                color: root.themeSubtext
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.betAmount.toString()
                                font.pixelSize: bottomControlBar.isCrowded ? 12 : 14
                                font.bold: true
                                font.family: root.monoFontFamily
                                color: root.themeAccent
                            }
                        }
                    }

                    Rectangle {
                        width: bottomControlBar.isCrowded ? 28 : 36
                        height: bottomControlBar.isCrowded ? 34 : 40
                        radius: 5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                            GradientStop { position: 1.0; color: root.themeCardBg }
                        }
                        border.color: root.themeBorder; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16; font.bold: true; font.family: root.monoFontFamily
                            color: "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeBet(1)
                        }
                    }

                    Rectangle {
                        width: bottomControlBar.isCrowded ? 46 : 68
                        height: bottomControlBar.isCrowded ? 34 : 40
                        radius: 5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(root.themeCardBg, 1.4) }
                            GradientStop { position: 1.0; color: root.themeCardBg }
                        }
                        border.color: "#f59e0b"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: bottomControlBar.isCrowded ? "MAX" : "MAX [X]"
                            font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily
                            color: "#fbbf24"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMaxBet()
                        }
                    }
                }
            }

            // Right: GIANT ILLUMINATED MECHANICAL "PLAY / DRAW" BUTTON (Images 2 & 4)
            Rectangle {
                id: playBtn
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: bottomControlBar.isCrowded ? 120 : (root.spotsCount < 2 ? 160 : 180)
                height: bottomControlBar.isCrowded ? 38 : 44
                radius: 6

                // Tactile 3D Bevel with Glass Highlight
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.isDrawing ? "#166534" :
                               playBtnMouse.containsMouse ? "#4ade80" : "#22c55e"
                    }
                    GradientStop {
                        position: 1.0
                        color: root.isDrawing ? "#052e16" :
                               playBtnMouse.containsMouse ? "#16a34a" : "#15803d"
                    }
                }
                border.color: "#bbf7d0"
                border.width: 2

                // Top specular highlight bar
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 1; height: 2; color: "#ffffff"; opacity: 0.6; radius: 2
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: root.isDrawing ? "DRAWING..." : "PLAY [SPACE]"
                        font.pixelSize: 14; font.bold: true; font.family: root.monoFontFamily
                        color: "#ffffff"
                        style: Text.Outline; styleColor: "#052e16"
                    }
                }

                MouseArea {
                    id: playBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.isDrawing ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.startDraw()
                }
            }
        }

        // =====================================================================
        // MODALS: HOW TO PLAY & CANONICAL ATTRIBUTION
        // =====================================================================
        Rectangle {
            id: helpModal
            visible: root.showHelp
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.85)
            z: 100

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(620, parent.width - 40)
                height: Math.min(520, parent.height - 40)
                radius: 10
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 2

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "HOW TO PLAY • VLT KENO TERMINAL"
                        font.pixelSize: 16; font.bold: true; font.family: root.monoFontFamily
                        color: root.themeAccent
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "1. Select 2 to 10 numbers on the board (1–80).\n" +
                              "2. Press PLAY or SPACEBAR to draw 20 balls from the tumbler.\n" +
                              "3. The more numbers you catch, the higher your multiplier payout!\n" +
                              "4. Standard Casino VLT Paytables with progressive odds."
                        font.pixelSize: 11; font.family: root.monoFontFamily
                        color: root.themeFg
                        lineHeight: 1.3
                    }

                    Text {
                        text: "8-IN-1 CASINO SUITE VARIANTS"
                        font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                        color: root.themeHit
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "• Classic [1]: Pure authentic match-and-catch Keno.\n" +
                              "• Power Keno [2]: Catch 20th ball to MULTIPLY ALL WINS BY 4X!\n" +
                              "• Super Keno [3]: Catch 1st ball to MULTIPLY ALL WINS BY 4X!\n" +
                              "• Cleopatra [4]: 20th ball Scarab awards 12 FREE GAMES @ 2X!\n" +
                              "• Caveman [5]: Hatch 2 Eggs for 4X, 3 Eggs for 8X MEGA WIN!\n" +
                              "• Extra Draw [6]: 1 hit away triggers 3 FREE EXTRA BALLS (21..23)!\n" +
                              "• Gold Mine [7]: Instant Nugget Cash Prizes + Dynamite Blast Radius!\n" +
                              "• Triple Power [8]: 1st Ball = 3X, 20th = 3X, Both = 9X MEGA BOOST!"
                        font.pixelSize: 10; font.family: root.monoFontFamily
                        color: root.themeSubtext
                        lineHeight: 1.25
                    }

                    // CANONICAL MANDATORY AUTHOR ATTRIBUTION
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 6
                        color: Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.15)
                        border.color: root.themeAccent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Created by Chris Thompson (@bigcjat) with Gemini"
                            font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                            color: root.themeAccent
                        }
                    }

                    Item { width: 1; height: 4 }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 120; height: 32; radius: 6
                        color: root.themeAccent
                        Text {
                            anchors.centerIn: parent
                            text: "CLOSE [ESC]"
                            font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                            color: root.themeBtnFg
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }
                }
            }
        }

        // Quick Sound / Notification Toast
        Rectangle {
            id: soundToast
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32
            width: toastText.implicitWidth + 24
            radius: 16
            color: Qt.rgba(15/255, 23/255, 42/255, 0.95)
            border.color: root.themeAccent
            border.width: 1
            opacity: 0
            z: 200

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                font.family: root.monoFontFamily
                color: "#ffffff"
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; to: 1.0; duration: 150 }
                PauseAnimation { duration: 1400 }
                NumberAnimation { target: soundToast; property: "opacity"; to: 0.0; duration: 250 }
            }
        }

        // =========================================================================
        // GAME SELECTION MENU MODAL (Opens at game start & via [ESC] / Game Menu)
        // =========================================================================
        Rectangle {
            id: gameMenuModal
            anchors.top: root.isCompactHeader ? compactHeaderBar.bottom : subheaderItem.bottom
            anchors.topMargin: root.isCompactHeader ? 4 : 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: leftNeonPillar.right
            anchors.right: rightNeonPillar.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            radius: 8
            border.color: root.themeBorder
            border.width: 2
            clip: true
            visible: root.showGameMenu
            opacity: visible ? 1.0 : 0.0
            z: 700
            color: "#070a14"

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            // Casino backdrop gradient
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0b0f24" }
                GradientStop { position: 0.45; color: "#060813" }
                GradientStop { position: 1.0; color: "#03040a" }
            }

            // Block clicks from passing through to underlying gameboard
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            // Top Header
            Column {
                id: menuHeader
                anchors.top: parent.top
                anchors.topMargin: Math.max(12, parent.height * 0.02)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                // Glowing Title
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SELECT YOUR KENO GAME"
                    font.pixelSize: Math.max(20, Math.min(28, gameMenuModal.width * 0.034))
                    font.bold: true
                    font.family: root.monoFontFamily
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#1d4ed8"
                }

                // Subtitle
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Touch or click a game below • Quick Start: Press [1 to 8] on keyboard"
                    font.pixelSize: 11
                    font.family: root.monoFontFamily
                    color: "#94a3b8"
                }
            }

            // 4x2 Grid of 8 Casino Game Cards
            Item {
                id: cardsContainer
                anchors.top: menuHeader.bottom
                anchors.topMargin: 10
                anchors.bottom: menuFooter.top
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 24, 980)

                Grid {
                    id: cardsGrid
                    anchors.fill: parent
                    columns: 4
                    spacing: 10

                    // CARD 1: CLASSIC KENO [1]
                    Rectangle {
                        id: cardClassic
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: classicArea.containsMouse ? "#0f2342" : "#09172e"
                        border.color: classicArea.containsMouse ? "#38bdf8" : "#1e3a8a"
                        border.width: classicArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_classic.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: classicArea.containsMouse ? 0.42 : 0.28
                        }

                        Item {
                            id: classicTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "🎲"; font.pixelSize: 15 }
                                Text {
                                    text: "CLASSIC"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#38bdf8"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#0369a1"; border.color: "#7dd3fc"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [1]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: classicTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "Pure Traditional Odds"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#93c5fd"
                            }
                            Text {
                                text: "• Pick 1–10 of 80 spots"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Authentic casino odds"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Top award up to 10,000X"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#facc15"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(56/255, 189/255, 248/255, 0.15)
                                border.color: "#38bdf8"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "CLASSIC"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#7dd3fc"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: classicArea.containsMouse ? "#38bdf8" : "#0284c7" }
                                    GradientStop { position: 1.0; color: "#0369a1" }
                                }
                                border.color: "#e0f2fe"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [1] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: classicArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("classic")
                        }
                    }

                    // CARD 2: POWER KENO [2]
                    Rectangle {
                        id: cardPower
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: powerArea.containsMouse ? "#271644" : "#1a0e2e"
                        border.color: powerArea.containsMouse ? "#c084fc" : "#581c87"
                        border.width: powerArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_power.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: powerArea.containsMouse ? 0.42 : 0.28
                        }

                        Item {
                            id: powerTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "⚡"; font.pixelSize: 15 }
                                Text {
                                    text: "POWER 4X"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#c084fc"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#7e22ce"; border.color: "#d8b4fe"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [2]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: powerTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "20th Ball Quadruple"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#e9d5ff"
                            }
                            Text {
                                text: "• Classic rules + final ball"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Catch ball 20 to trigger"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• MULTIPLIES WINS BY 4X!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#f472b6"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(192/255, 132/255, 252/255, 0.15)
                                border.color: "#c084fc"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "4X FINAL"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#e9d5ff"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: powerArea.containsMouse ? "#c084fc" : "#9333ea" }
                                    GradientStop { position: 1.0; color: "#7e22ce" }
                                }
                                border.color: "#f3e8ff"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [2] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: powerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("power")
                        }
                    }

                    // CARD 3: SUPER KENO [3]
                    Rectangle {
                        id: cardSuper
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: superArea.containsMouse ? "#3a250a" : "#261805"
                        border.color: superArea.containsMouse ? "#fbbf24" : "#78350f"
                        border.width: superArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_super.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: superArea.containsMouse ? 0.42 : 0.28
                        }

                        Item {
                            id: superTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "👑"; font.pixelSize: 15 }
                                Text {
                                    text: "SUPER 4X"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#fbbf24"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#b45309"; border.color: "#fde68a"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [3]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: superTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "1st Ball Quadruple"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#fef3c7"
                            }
                            Text {
                                text: "• Instant drop excitement"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Catch 1st ball drawn"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• MULTIPLIES WINS BY 4X!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#facc15"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(251/255, 191/255, 36/255, 0.15)
                                border.color: "#fbbf24"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "4X FIRST"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fde68a"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: superArea.containsMouse ? "#fbbf24" : "#d97706" }
                                    GradientStop { position: 1.0; color: "#b45309" }
                                }
                                border.color: "#fef9c3"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [3] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#05060d"
                                }
                            }
                        }

                        MouseArea {
                            id: superArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("super")
                        }
                    }

                    // CARD 4: CLEOPATRA KENO [4]
                    Rectangle {
                        id: cardCleo
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: cleoArea.containsMouse ? "#1c1208" : "#120a03"
                        border.color: cleoArea.containsMouse ? "#fbbf24" : "#d97706"
                        border.width: cleoArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_cleopatra.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: cleoArea.containsMouse ? 0.45 : 0.32
                        }

                        Item {
                            id: cleoTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Image {
                                    width: 16; height: 16
                                    source: "assets/token_scarab.jpg"
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "CLEOPATRA"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#fbbf24"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#b45309"; border.color: "#fbbf24"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [4]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fde68a"
                                }
                            }
                        }

                        Column {
                            anchors.top: cleoTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "12 Free Games @ 2X"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#fde68a"
                            }
                            Text {
                                text: "• Hit 20th ball Scarab"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• 12 Free Games triggered"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• ALL FREE WINS PAY 2X!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#fbbf24"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(217/255, 119/255, 6/255, 0.20)
                                border.color: "#fbbf24"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "12 SPINS"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fde68a"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: cleoArea.containsMouse ? "#fbbf24" : "#d97706" }
                                    GradientStop { position: 1.0; color: "#92400e" }
                                }
                                border.color: "#fef08a"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [4] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: cleoArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("cleopatra")
                        }
                    }

                    // CARD 5: CAVEMAN KENO [5]
                    Rectangle {
                        id: cardCaveman
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: cavemanArea.containsMouse ? "#1c260a" : "#111805"
                        border.color: cavemanArea.containsMouse ? "#a3e635" : "#4d7c0f"
                        border.width: cavemanArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_caveman.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: cavemanArea.containsMouse ? 0.45 : 0.32
                        }

                        Item {
                            id: cavemanTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Image {
                                    width: 16; height: 16
                                    source: "assets/token_egg.jpg"
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "CAVEMAN"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#bef264"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#3f6212"; border.color: "#a3e635"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [5]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: cavemanTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "Dino Eggs 4X & 8X"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#bef264"
                            }
                            Text {
                                text: "• 3 Dino Eggs on board"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Hatch 2 eggs for 4X win"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• HATCH 3 FOR 8X MEGA!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#facc15"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(132/255, 204/255, 22/255, 0.20)
                                border.color: "#84cc16"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "4X / 8X"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#bef264"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: cavemanArea.containsMouse ? "#a3e635" : "#65a30d" }
                                    GradientStop { position: 1.0; color: "#3f6212" }
                                }
                                border.color: "#d9f99d"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [5] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: cavemanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("caveman")
                        }
                    }

                    // CARD 6: EXTRA DRAW KENO [6]
                    Rectangle {
                        id: cardExtraDraw
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: extraDrawArea.containsMouse ? "#2d080f" : "#190408"
                        border.color: extraDrawArea.containsMouse ? "#f87171" : "#991b1b"
                        border.width: extraDrawArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_extradraw.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: extraDrawArea.containsMouse ? 0.45 : 0.30
                        }

                        Item {
                            id: extraDrawTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "🚨"; font.pixelSize: 15 }
                                Text {
                                    text: "EXTRA DRAW"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#f87171"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#991b1b"; border.color: "#fca5a5"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [6]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: extraDrawTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "3 Free Extra Balls"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#fca5a5"
                            }
                            Text {
                                text: "• Emergency alert sirens"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• 1 hit away from top pay"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• BALLS 21, 22, 23 DRAWN!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#fef08a"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(239/255, 68/255, 68/255, 0.20)
                                border.color: "#ef4444"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "+3 BALLS"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fca5a5"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: extraDrawArea.containsMouse ? "#f87171" : "#dc2626" }
                                    GradientStop { position: 1.0; color: "#7f1d1d" }
                                }
                                border.color: "#fecaca"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [6] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: extraDrawArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("extradraw")
                        }
                    }

                    // CARD 7: GOLD MINE KENO [7]
                    Rectangle {
                        id: cardGoldMine
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: goldMineArea.containsMouse ? "#2d1c08" : "#1a0f03"
                        border.color: goldMineArea.containsMouse ? "#facc15" : "#854d0e"
                        border.width: goldMineArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_goldmine.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: goldMineArea.containsMouse ? 0.45 : 0.32
                        }

                        Item {
                            id: goldMineTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Image {
                                    width: 16; height: 16
                                    source: "assets/token_nugget.jpg"
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "GOLD MINE"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#fde047"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#854d0e"; border.color: "#fef08a"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [7]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: goldMineTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "Nugget Cash & TNT"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#fef08a"
                            }
                            Text {
                                text: "• Hit Nuggets on board"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• Instant cash bonus prize"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• DYNAMITE BLAST RADIUS!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#facc15"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(234/255, 179/255, 8/255, 0.20)
                                border.color: "#eab308"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "NUGGETS"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#fde047"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: goldMineArea.containsMouse ? "#facc15" : "#ca8a04" }
                                    GradientStop { position: 1.0; color: "#713f12" }
                                }
                                border.color: "#fef08a"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [7] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#000000"
                                }
                            }
                        }

                        MouseArea {
                            id: goldMineArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("goldmine")
                        }
                    }

                    // CARD 8: TRIPLE POWER KENO [8]
                    Rectangle {
                        id: cardTriplePower
                        width: (cardsGrid.width - 3 * cardsGrid.spacing) / 4
                        height: (cardsGrid.height - cardsGrid.spacing) / 2
                        radius: 10
                        clip: true
                        color: triplePowerArea.containsMouse ? "#0a2638" : "#041420"
                        border.color: triplePowerArea.containsMouse ? "#22d3ee" : "#0891b2"
                        border.width: triplePowerArea.containsMouse ? 2 : 1.5

                        Image {
                            anchors.fill: parent
                            source: "assets/bg_triplepower.jpg"
                            fillMode: Image.PreserveAspectCrop
                            opacity: triplePowerArea.containsMouse ? 0.45 : 0.30
                        }

                        Item {
                            id: triplePowerTopRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 22

                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text { text: "⚛"; font.pixelSize: 15 }
                                Text {
                                    text: "TRIPLE PWR"
                                    font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily
                                    color: "#67e8f9"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 18; width: 44; radius: 5
                                color: "#0e7490"; border.color: "#a5f3fc"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "KEY [8]"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        Column {
                            anchors.top: triplePowerTopRow.bottom; anchors.topMargin: 4
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; spacing: 3

                            Text {
                                text: "Dual 3X = 9X Mega"
                                font.pixelSize: 10; font.bold: true; font.family: root.monoFontFamily; color: "#a5f3fc"
                            }
                            Text {
                                text: "• 1st ball hit pays 3X"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• 20th ball hit pays 3X"
                                font.pixelSize: 9; font.family: root.monoFontFamily; color: "#cbd5e1"
                            }
                            Text {
                                text: "• BOTH HIT PAYS 9X MEGA!"
                                font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#38bdf8"
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 10; height: 24

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                height: 20; width: 72; radius: 5
                                color: Qt.rgba(6/255, 182/255, 212/255, 0.20)
                                border.color: "#06b6d4"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "3X / 9X"
                                    font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: "#a5f3fc"
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                height: 24; width: 80; radius: 5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: triplePowerArea.containsMouse ? "#22d3ee" : "#0891b2" }
                                    GradientStop { position: 1.0; color: "#0e7490" }
                                }
                                border.color: "#cffafe"; border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: "PLAY [8] ▶"
                                    font.pixelSize: 9; font.bold: true; font.family: root.monoFontFamily; color: "#ffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: triplePowerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndStartGame("triplepower")
                        }
                    }
                }
            }

            // Bottom Footer Bar
            Item {
                id: menuFooter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.max(14, parent.height * 0.025)
                anchors.horizontalCenter: parent.horizontalCenter
                width: cardsContainer.width
                height: 42

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#0b1120"
                    border.color: "#1e293b"
                    border.width: 1

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16

                        Row {
                            spacing: 6
                            Text { text: "💵"; font.pixelSize: 12 }
                            Text {
                                text: "CREDITS: " + root.displayedCredits
                                font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                                color: "#f8fafc"
                            }
                        }

                        Rectangle { width: 1; height: 16; color: "#334155"; anchors.verticalCenter: parent.verticalCenter }

                        Row {
                            spacing: 6
                            Text { text: "🏆"; font.pixelSize: 12 }
                            Text {
                                text: "JACKPOT: $250,000.00"
                                font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                                color: "#facc15"
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // How to Play button
                        Rectangle {
                            height: 30
                            width: howToPlayRow.implicitWidth + 20
                            radius: 6
                            color: "#1e293b"
                            border.color: "#334155"
                            border.width: 1

                            Row {
                                id: howToPlayRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "?"; font.pixelSize: 12; font.bold: true; color: root.themeAccent }
                                Text {
                                    text: "How to Play"
                                    font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                                    color: "#e2e8f0"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHelp = true
                            }
                        }

                        // Resume Current Game button
                        Rectangle {
                            height: 30
                            width: resumeRow.implicitWidth + 20
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#2563eb" }
                                GradientStop { position: 1.0; color: "#1d4ed8" }
                            }
                            border.color: "#60a5fa"
                            border.width: 1

                            Row {
                                id: resumeRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "◀"; font.pixelSize: 11; font.bold: true; color: "#ffffff" }
                                Text {
                                    text: "Resume Game [ESC]"
                                    font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily
                                    color: "#ffffff"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showGameMenu = false;
                                    root.playSound("keno_select");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // SplashScreen compatibility dummy
    Item {
        id: splashScreen
        visible: false
        function dismiss() {
            root.splashEnabled = false;
        }
    }
}
