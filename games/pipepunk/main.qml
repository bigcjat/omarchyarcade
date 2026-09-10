import QtQuick
import QtQuick.Window
import "PipeEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 960
    height: 720
    minimumWidth: 500
    minimumHeight: 400
    title: "Pipe Punk"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#12141a"
    property color themeBoardBg: "#0d0f14"
    property color themeCardBg: "#1a1d26"
    property color themeBorder: "#2a2e3d"
    property color themeFg: "#e2e8f0"
    property color themeSubtext: "#94a3b8"
    property color themeAccent: "#f59e0b" // Steampunk warm amber / brass
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    property color themeColor0: "#1a1d26"
    property color themeColor1: "#ef4444"
    property color themeColor2: "#10b981"
    property color themeColor3: "#f59e0b"
    property color themeColor4: "#3b82f6"
    property color themeColor5: "#8b5cf6"
    property color themeColor6: "#06b6d4"

    // WCAG contrast helper ensuring buttons are always readable in light/dark themes
    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameStateStr: "ready" // "ready", "playing", "gameover", "won"
    property var gameState: null
    property string currentEngineState: "countdown"
    property real summaryTime: 0
    property int summaryPipesPlaced: 0
    property int summaryTraversed: 0
    property int summaryQuota: 0
    property int summaryCrossBonus: 0

    function updateSummaryStats() {
        if (!gameState) return;
        summaryTime = gameState.elapsedTime || 0;
        summaryPipesPlaced = gameState.pipesPlaced || 0;
        summaryTraversed = gameState.traversedCount || 0;
        summaryQuota = gameState.quota || 0;
        summaryCrossBonus = gameState.crossBonusCount || 0;
    }

    onCurrentEngineStateChanged: {
        if (currentEngineState === "round_won" || currentEngineState === "game_over") {
            updateSummaryStats();
        }
    }

    property int currentLevel: 1
    property int score: 0
    property int bestScore: 0
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property alias showHelpModal: root.showHelp
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Objective: Route pressurized municipal water from the starting valve across the grid without letting it spill.\n\n" +
                              "• Pipe Connections: Place upcoming pipe fittings (straight, corners, cross) from the vertical dispenser hopper onto the grid.\n\n" +
                              "• Pre-Placed Pipes: Each round spawns 6–12 pre-placed pipes! Moveable copper pipes can be replaced (-50 pts). Permanent cast iron pipes (starting in Round 2, +1 per round) are bolted down and unchangeable!\n\n" +
                              "• Quota Requirement: Meet or exceed the sector's required pipe quota before the chemical stream reaches an open pipe end.\n\n" +
                              "• Cross Bonus: Cross pieces can be traversed TWICE (both horizontally and vertically) for +500 bonus points!\n\n" +
                              "• Rush Pump: Hold SPACE to rush the pump at 5× speed once your pipeline is safely connected for massive score multipliers and high pressure.\n\n" +
                              "• Navigation: Arrows, WASD, or Vim (H / J / K / L) to move cursor.\n\n" +
                              "• Placement: Enter, Space, or Left Click to place current pipe.\n\n" +
                              "• Shortcuts: Restart (R), Mute (M), Full/Standard View (⇧F), Help (? or Esc)."

    // Cursor grid selection for keyboard navigation
    property int cursorR: 3
    property int cursorC: 4
    property int gridRevision: 0
    property var queueList: []

    // Screen Shake effect on blowout or rush
    property real shakeX: 0
    property real shakeY: 0
    property real flowAnimTime: 0.0
    property bool modalReady: false

    function formatTime(sec) {
        if (!sec || sec < 0) sec = 0;
        var m = Math.floor(sec / 60);
        var s = Math.floor(sec % 60);
        var ms = Math.floor((sec % 1) * 10);
        var mm = m < 10 ? "0" + m : "" + m;
        var ss = s < 10 ? "0" + s : "" + s;
        return mm + ":" + ss + "." + ms;
    }

    Timer {
        id: modalDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root.modalReady = true
    }

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;

        var bg = data.background || data.bg || "#12141a";
        var fg = data.foreground || data.fg || "#e2e8f0";
        var accent = data.accent || "#f59e0b";
        var c0 = data.color0 || "#1a1d26";
        var c8 = data.color8 || data.color0 || "#2a2e3d";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.06);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBorder = c8 || Qt.darker(bg, 1.15);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#94a3b8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;

        gridCanvas.requestPaint();
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function playSfx(name) {
        playSound(name);
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("pipe_clank");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function restartGame() {
        startNewGame(1);
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

    function placePipeAt(r, c) {
        if (!gameState || (gameState.state !== "countdown" && gameState.state !== "flowing")) return;
        if (Engine.placeNextPiece(gameState, r, c)) {
            playSound("pipe_clank");
            queueList = gameState.queue.slice();
            gridRevision++;
            if (gridCanvas) gridCanvas.requestPaint();
        }
    }

    // =========================================================================
    // GAME INITIALIZATION
    // =========================================================================
    function startNewGame(lvl) {
        currentLevel = lvl || 1;
        gameState = Engine.createGameState(currentLevel);
        currentEngineState = gameState.state;
        score = 0;
        queueList = gameState.queue.slice();
        cursorR = gameState.valveRow;
        cursorC = gameState.valveCol + 1;
        if (cursorC >= Engine.COLS) cursorC = Engine.COLS - 1;
        shakeX = 0;
        shakeY = 0;
        gridRevision++;
        if (gridCanvas) gridCanvas.requestPaint();
        playSound("pipe_clank");
    }

    function advanceToNextLevel() {
        currentLevel++;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setHighestLevel(currentLevel);
        }
        var currentScore = score;
        gameState = Engine.createGameState(currentLevel);
        gameState.score = currentScore;
        currentEngineState = gameState.state;
        queueList = gameState.queue.slice();
        cursorR = gameState.valveRow;
        cursorC = gameState.valveCol + 1;
        if (cursorC >= Engine.COLS) cursorC = Engine.COLS - 1;
        shakeX = 0;
        shakeY = 0;
        gridRevision++;
        if (gridCanvas) gridCanvas.requestPaint();
        playSound("pipe_clank");
    }

    function setupDemoBoard() {
        startNewGame(1);
        var vr = gameState.valveRow;
        var vc = gameState.valveCol;
        if (vc + 1 < Engine.COLS) {
            gameState.grid[vr][vc+1].type = "pipe_h";
            gameState.grid[vr][vc+1].entryPort = "W";
            gameState.grid[vr][vc+1].exitPort = "E";
            gameState.grid[vr][vc+1].filled = true;
            gameState.grid[vr][vc+1].fillProgress = 1.0;
        }
        if (vc + 2 < Engine.COLS) {
            gameState.grid[vr][vc+2].type = "corner_4";
            gameState.grid[vr][vc+2].entryPort = "W";
            gameState.grid[vr][vc+2].exitPort = "S";
            gameState.grid[vr][vc+2].filled = true;
            gameState.grid[vr][vc+2].fillProgress = 1.0;
        }
        if (vr + 1 < Engine.ROWS && vc + 2 < Engine.COLS) {
            gameState.grid[vr+1][vc+2].type = "pipe_v";
            gameState.grid[vr+1][vc+2].entryPort = "N";
            gameState.grid[vr+1][vc+2].exitPort = "S";
            gameState.grid[vr+1][vc+2].filled = true;
            gameState.grid[vr+1][vc+2].fillProgress = 1.0;
        }
        if (vr + 2 < Engine.ROWS && vc + 2 < Engine.COLS) {
            gameState.grid[vr+2][vc+2].type = "corner_1";
            gameState.grid[vr+2][vc+2].entryPort = "N";
            gameState.grid[vr+2][vc+2].exitPort = "E";
            gameState.grid[vr+2][vc+2].isFlowing = true;
            gameState.grid[vr+2][vc+2].fillProgress = 0.65;
        }
        if (vr + 2 < Engine.ROWS && vc + 3 < Engine.COLS) {
            gameState.grid[vr+2][vc+3].type = "cross";
        }
        if (vr + 2 < Engine.ROWS && vc + 4 < Engine.COLS) {
            gameState.grid[vr+2][vc+4].type = "reservoir";
        }
        gameState.state = "flowing";
        currentEngineState = "flowing";
        gameState.traversedCount = 4;
        gameState.psi = 46.5;
        score = 850;
        queueList = gameState.queue.slice();
        gridRevision++;
        gridCanvas.requestPaint();
    }

    function setupFloodDemo(outcome, progress) {
        setupDemoBoard();
        var gs = gameState;
        var vr = gs.valveRow;
        var vc = gs.valveCol;
        if (outcome === "round_won") {
            gs.traversedCount = 12;
            gs.quota = 10;
            gs.pipesPlaced = 14;
            gs.crossBonusCount = 2;
            gs.elapsedTime = 64.8;
            score = 4250;
            gs.score = 4250;
            gs.leakPos = { r: vr + 2, c: vc + 2 };
            if (progress >= 1.0) {
                gs.state = "round_won";
                gs.floodProgress = 1.0;
                root.modalReady = true;
            } else {
                gs.state = "flooding";
                gs.floodProgress = progress || 0.6;
            }
        } else {
            gs.traversedCount = 4;
            gs.quota = 10;
            gs.pipesPlaced = 6;
            gs.crossBonusCount = 0;
            gs.elapsedTime = 23.4;
            score = 650;
            gs.score = 650;
            gs.leakPos = { r: vr + 2, c: vc + 2 };
            if (progress >= 1.0) {
                gs.state = "game_over";
                gs.floodProgress = 1.0;
                root.modalReady = true;
            } else {
                gs.state = "flooding";
                gs.floodProgress = progress || 0.6;
            }
        }
        gameState = gs;
        currentEngineState = gs.state;
        gridRevision++;
        if (gridCanvas) gridCanvas.requestPaint();
        if (typeof floodCanvas !== "undefined" && floodCanvas) floodCanvas.requestPaint();
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
        }
        startNewGame(1);
    }

    // =========================================================================
    // GAME SIMULATION LOOP
    // =========================================================================
    Timer {
        id: simTimer
        interval: 16
        running: gameState && (!splashScreen || !splashScreen.visible || splashScreen.opacity === 0)
        repeat: true
        onTriggered: {
            if (!gameState) return;
            var prevState = gameState.state;
            var prevTraversed = gameState.traversedCount;

            Engine.updateSimulation(gameState, 0.016);
            root.flowAnimTime += 0.016 * (gameState.isRushing ? 3.5 : 1.0);
            if (root.currentEngineState !== gameState.state) {
                root.currentEngineState = gameState.state;
            }

            score = gameState.score;
            if (score > bestScore) {
                bestScore = score;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setBestScore(bestScore);
                }
            }

            // Audio cues & transitions
            if (gameState.traversedCount > prevTraversed) {
                playSound("water_flow");
            }

            if (prevState === "countdown" && gameState.state === "flowing") {
                playSound("water_flow");
            }

            if (prevState === "flowing" && gameState.state === "flooding") {
                playSound("steam_hiss");
                playSound("water_flow");
                shakeAnim.start();
                root.modalReady = false;
            } else if (prevState === "flooding" && gameState.state === "round_won") {
                playSound("level_clear");
                shakeX = 0;
                shakeY = 0;
                modalDebounceTimer.restart();
            } else if (prevState === "flooding" && gameState.state === "game_over") {
                playSound("steam_hiss");
                shakeX = 0;
                shakeY = 0;
                modalDebounceTimer.restart();
            } else if (gameState.state === "round_won" && prevState !== "round_won" && prevState !== "flooding") {
                playSound("level_clear");
                modalDebounceTimer.restart();
            }

            // Screen shake when rushing or flooding
            if (gameState.state === "flooding") {
                var floodIntensity = Math.max(0.2, 1.0 - gameState.floodProgress * 0.5);
                shakeX = (Math.random() - 0.5) * 8 * floodIntensity;
                shakeY = (Math.random() - 0.5) * 8 * floodIntensity;
            } else if (gameState.isRushing) {
                shakeX = (Math.random() - 0.5) * 4;
                shakeY = (Math.random() - 0.5) * 4;
            } else if (gameState.state !== "game_over") {
                shakeX = 0;
                shakeY = 0;
            }

            gridCanvas.requestPaint();
            if (typeof floodCanvas !== "undefined" && floodCanvas) {
                floodCanvas.requestPaint();
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 1
        NumberAnimation { target: root; property: "shakeX"; from: -8; to: 8; duration: 40 }
        NumberAnimation { target: root; property: "shakeX"; from: 8; to: -6; duration: 40 }
        NumberAnimation { target: root; property: "shakeX"; from: -6; to: 4; duration: 40 }
        NumberAnimation { target: root; property: "shakeX"; from: 4; to: 0; duration: 50 }
        NumberAnimation { target: root; property: "shakeY"; from: -6; to: 6; duration: 40 }
        NumberAnimation { target: root; property: "shakeY"; from: 6; to: 0; duration: 50 }
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLERS
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true
        Behavior on color { ColorAnimation { duration: 150 } }

        Keys.onPressed: function(event) {
            // Dismiss Splash on any key
            if (splashEnabled && splashScreen && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            // Help Modal dismiss
            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            // Game over / Won restart or advance (requires modalReady to prevent skip from rush)
            if (gameState && (gameState.state === "game_over" || gameState.state === "round_won")) {
                if (root.modalReady) {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (gameState.state === "round_won") root.advanceToNextLevel();
                        else root.startNewGame(gameState ? gameState.level : 1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_R) {
                        if (gameState.state === "round_won") root.startNewGame(gameState ? gameState.level : 1);
                        else root.startNewGame(1);
                        event.accepted = true;
                        return;
                    }
                }
                event.accepted = true;
                return;
            }

            // During flooding animation, swallow space/enter so it finishes smoothly
            if (gameState && gameState.state === "flooding") {
                event.accepted = true;
                return;
            }

            // Sound Toggle
            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            // Full Window View Toggle
            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Windowed View");
                event.accepted = true;
                return;
            }

            // Restart Hotkey
            if (event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
                return;
            }

            // Help Toggle
            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            // Space to Rush Pump (or release pump early during countdown)
            if (event.key === Qt.Key_Space) {
                if (gameState && gameState.state === "flowing") {
                    gameState.isRushing = true;
                    playSound("rush");
                    event.accepted = true;
                    return;
                } else if (gameState && gameState.state === "countdown") {
                    gameState.countdown = 0.0;
                    playSound("rush");
                    event.accepted = true;
                    return;
                }
            }

            // Enter to place pipe at cursor
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                placePipeAt(cursorR, cursorC);
                event.accepted = true;
                return;
            }

            // Vim H/J/K/L and Arrow keys for grid navigation
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_A) {
                cursorC = Math.max(0, cursorC - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_D) {
                cursorC = Math.min(Engine.COLS - 1, cursorC + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_W) {
                cursorR = Math.max(0, cursorR - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_S) {
                cursorR = Math.min(Engine.ROWS - 1, cursorR + 1);
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Space) {
                if (gameState) gameState.isRushing = false;
                event.accepted = true;
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? 16 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? Math.max(titleCol.height, scoreRow.height) : 0

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: scoreRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.title
                    font.pixelSize: Math.max(20, Math.min(32, headerItem.width * 0.075))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Victorian steampunk municipal waterworks"
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards on the right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // ANALOG BRASS PRESSURE GAUGE Card
                Rectangle {
                    width: Math.max(54, Math.min(64, headerItem.width * 0.12))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: (gameState && gameState.isRushing) ? "#ef4444" : root.themeBorder
                    border.width: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4

                        Image {
                            anchors.fill: parent
                            source: "assets/gauge_dial.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }

                        Image {
                            id: needleImg
                            width: Math.round(parent.width * 0.22)
                            height: Math.round(parent.height * 0.58)
                            x: parent.width / 2 - width / 2
                            y: parent.height / 2 - height + 2
                            source: "assets/needle.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            transformOrigin: Item.Bottom

                            rotation: {
                                var currentPsi = gameState ? gameState.psi : 24.0;
                                var clamped = Math.max(0, Math.min(120, currentPsi));
                                var baseDeg = -120 + (clamped / 120.0) * 240.0;
                                return baseDeg + (gameState && gameState.isRushing ? (Math.random() - 0.5) * 6 : 0);
                            }
                            Behavior on rotation {
                                NumberAnimation { duration: 70 }
                            }
                        }
                    }
                }

                // PIPES / QUOTA Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: (gameState && gameState.traversedCount >= gameState.quota) ? "#10b981" : root.themeBorder
                    border.width: (gameState && gameState.traversedCount >= gameState.quota) ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "PIPES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: gameState ? (gameState.traversedCount + "/" + gameState.quota) : "0/15"
                            font.pixelSize: 16
                            font.bold: true
                            color: (gameState && gameState.traversedCount >= gameState.quota) ? "#10b981" : root.themeFg
                        }
                    }
                }

                // SCORE Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCORE"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // BEST Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BEST"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bestScore.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.bestScore > 0 ? root.themeAccent : root.themeSubtext
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
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 10 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 34 : 0

            readonly property bool isCrowded: subheaderItem.width < 500

            // Left cluster (Help button & Status Pill)
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Help Button
                Rectangle {
                    id: helpBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "?"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "How to Play"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Status Indicator Pill
                Rectangle {
                    id: statusPill
                    height: 32
                    width: statusRow.implicitWidth + 16
                    radius: 8
                    color: root.themeBoardBg
                    border.color: (gameState && gameState.state === "game_over") ? "#ef4444" :
                                  (gameState && gameState.state === "round_won") ? "#10b981" :
                                  (gameState && gameState.state === "flowing") ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: (gameState && gameState.state === "countdown") ? "⏳" :
                                  (gameState && gameState.state === "round_won") ? "🏆" :
                                  (gameState && gameState.state === "game_over") ? "💥" : "🌊"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: {
                                if (!gameState) return "STANDBY";
                                if (gameState.state === "countdown") return "RELEASE: " + Math.ceil(gameState.countdown) + "s";
                                if (gameState.state === "flowing") return gameState.isRushing ? "RUSHING (5X)" : (Math.round(gameState.psi) + " PSI");
                                if (gameState.state === "round_won") return "SECTOR CLEARED";
                                if (gameState.state === "game_over") return "BLOWOUT";
                                return "OPERATIONAL";
                            }
                            color: (gameState && gameState.state === "countdown") ? root.themeAccent :
                                   (gameState && gameState.state === "round_won") ? "#10b981" :
                                   (gameState && gameState.state === "game_over") ? "#ef4444" : root.themeFg
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Right cluster (Actions: Mute, View Mode, Restart)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Mute Button
                Rectangle {
                    id: muteBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isMuted ? root.themeSubtext : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: root.fullPlayfield ? root.themeCardBg : (viewModeMouse.containsMouse ? root.themeCardBg : root.themeBoardBg)
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        id: viewModeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.fullPlayfield ? "🔲" : "⛶"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.fullPlayfield ? "Standard (⇧F)" : "Full (⇧F)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.fullPlayfield ? root.themeAccent : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: viewModeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Windowed View");
                        }
                    }
                }

                // Primary Action Button (Restart / New Game)
                Rectangle {
                    id: restartBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 13
                            visible: subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "New Game (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            visible: !subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame(1)
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (Compact header active when tiled or full)
        // =====================================================================
        Rectangle {
            id: floatingTiledHUD
            visible: root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 38
            radius: 8
            z: 90
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: root.title
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• SCORE: " + root.score
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    text: "(BEST: " + root.bestScore + ")"
                    font.pixelSize: 10
                    color: root.themeSubtext
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Full Window Toggle
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "🔲"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = false;
                            soundToast.show("🔲 Standard Windowed View");
                        }
                    }
                }

                // Help
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Mute
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Restart
                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame(1)
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD CONTAINER (Left Hopper Dispenser + Center 10×8 Grid)
        // =====================================================================
        Item {
            id: playfieldContainer
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            x: root.shakeX
            y: root.shakeY

            // 1. LEFT COLUMN: MECHANICAL HOPPER DISPENSER
            Rectangle {
                id: hopperColumn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: bottomBar.top
                anchors.bottomMargin: 10
                width: 130
                color: root.themeCardBg
                radius: 8
                border.color: root.themeBorder
                border.width: 1.5

                // Top Hopper Funnel Header
                Rectangle {
                    id: hopperHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
                    color: root.themeBoardBg
                    radius: 8

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "🔩"; font.pixelSize: 13 }
                        Text {
                            text: "NEXT FITTINGS"
                            color: root.themeAccent
                            font.family: monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

                // 5-Slot Pipe Queue
                Column {
                    anchors.top: hopperHeader.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: root.queueList

                        Rectangle {
                            width: 96
                            height: Math.min(80, (hopperColumn.height - 66) / 5 - 8)
                            color: index === 0 ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.12) : root.themeBoardBg
                            radius: 6
                            border.color: index === 0 ? root.themeAccent : root.themeBorder
                            border.width: index === 0 ? 2 : 1

                            // Pipe Sprite Preview
                            Image {
                                anchors.centerIn: parent
                                width: parent.height - 10
                                height: parent.height - 10
                                source: (typeof modelData === "string" && modelData.length > 0) ? ("assets/" + modelData + ".png") : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            // "NEXT" Tag on first item
                            Rectangle {
                                visible: index === 0
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 42
                                height: 14
                                color: root.themeAccent
                                radius: 3

                                Text {
                                    anchors.centerIn: parent
                                    text: "NEXT"
                                    color: root.themeBtnFg
                                    font.family: monoFontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // 2. CENTER-RIGHT COLUMN: THE 10×8 INDUSTRIAL PIPE GRID
            Rectangle {
                id: gridBoard
                anchors.left: hopperColumn.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: bottomBar.top
                anchors.bottomMargin: 10
                color: root.themeBoardBg
                radius: 8
                border.color: root.themeBorder
                border.width: 1.5
                clip: true

                // Grid Cells Matrix (10 Cols × 8 Rows)
                Item {
                    id: gridMatrix
                    anchors.fill: parent
                    anchors.margins: 10

                    readonly property real cellW: width / Engine.COLS
                    readonly property real cellH: height / Engine.ROWS

                    // Layer 1: Steel Base Plates
                    Repeater {
                        model: Engine.ROWS * Engine.COLS

                        Image {
                            readonly property int r: Math.floor(index / Engine.COLS)
                            readonly property int c: index % Engine.COLS
                            x: c * gridMatrix.cellW
                            y: r * gridMatrix.cellH
                            width: gridMatrix.cellW
                            height: gridMatrix.cellH
                            source: "assets/plate.png"
                            fillMode: Image.Stretch
                            smooth: true
                        }
                    }

                    // Layer 2: Fluid Simulation Canvas (flows INSIDE the pipe bore)
                    Canvas {
                        id: gridCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            if (typeof ctx.reset === "function") ctx.reset();
                            ctx.clearRect(0, 0, width, height);

                            if (!gameState || !gameState.grid || gameState.state === "countdown") return;

                            var cw = gridMatrix.cellW;
                            var ch = gridMatrix.cellH;

                            for (var r = 0; r < Engine.ROWS; r++) {
                                for (var c = 0; c < Engine.COLS; c++) {
                                    var cell = gameState.grid[r][c];
                                    if (!cell || cell.type === "empty") continue;

                                    var cx = c * cw;
                                    var cy = r * ch;

                                    if (cell.fillProgress > 0) {
                                        drawFluidInCell(ctx, cell, cx, cy, cw, ch);
                                    }

                                    if (cell.type === "cross" && cell.crossFillProgress > 0) {
                                        drawCrossSecondPass(ctx, cell, cx, cy, cw, ch);
                                    }
                                }
                            }
                        }

                        function drawBezierSub(ctx, p0, p1, p2, p3, p) {
                            if (p <= 0.001) return;
                            if (p >= 0.999) {
                                ctx.moveTo(p0.x, p0.y);
                                ctx.bezierCurveTo(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
                                return;
                            }
                            var q1x = p0.x + p * (p1.x - p0.x);
                            var q1y = p0.y + p * (p1.y - p0.y);
                            var q2x = p1.x + p * (p2.x - p1.x);
                            var q2y = p1.y + p * (p2.y - p1.y);
                            var q3x = p2.x + p * (p3.x - p2.x);
                            var q3y = p2.y + p * (p3.y - p2.y);

                            var r1x = q1x + p * (q2x - q1x);
                            var r1y = q1y + p * (q2y - q1y);
                            var r2x = q2x + p * (q3x - q2x);
                            var r2y = q2y + p * (q3y - q2y);

                            var s0x = r1x + p * (r2x - r1x);
                            var s0y = r1y + p * (r2y - r1y);

                            ctx.moveTo(p0.x, p0.y);
                            ctx.bezierCurveTo(q1x, q1y, r1x, r1y, s0x, s0y);
                        }

                        function getBezierPoint(p0, p1, p2, p3, t) {
                            var omt = 1 - t;
                            var omt2 = omt * omt;
                            var omt3 = omt2 * omt;
                            var t2 = t * t;
                            var t3 = t2 * t;
                            return {
                                x: omt3 * p0.x + 3 * omt2 * t * p1.x + 3 * omt * t2 * p2.x + t3 * p3.x,
                                y: omt3 * p0.y + 3 * omt2 * t * p1.y + 3 * omt * t2 * p2.y + t3 * p3.y
                            };
                        }

                        function getCornerControlPoints(type, entry, cx, cy, cw, ch) {
                            var k = cw * 0.276;
                            var midX = cx + cw / 2;
                            var midY = cy + ch / 2;
                            var p0, p1, p2, p3;

                            if (type === "corner_1") {
                                // N <-> E
                                if (entry === "N") {
                                    p0 = { x: midX, y: cy };
                                    p1 = { x: midX, y: cy + k };
                                    p2 = { x: cx + cw - k, y: midY };
                                    p3 = { x: cx + cw, y: midY };
                                } else {
                                    p0 = { x: cx + cw, y: midY };
                                    p1 = { x: cx + cw - k, y: midY };
                                    p2 = { x: midX, y: cy + k };
                                    p3 = { x: midX, y: cy };
                                }
                            } else if (type === "corner_2") {
                                // N <-> W
                                if (entry === "N") {
                                    p0 = { x: midX, y: cy };
                                    p1 = { x: midX, y: cy + k };
                                    p2 = { x: cx + k, y: midY };
                                    p3 = { x: cx, y: midY };
                                } else {
                                    p0 = { x: cx, y: midY };
                                    p1 = { x: cx + k, y: midY };
                                    p2 = { x: midX, y: cy + k };
                                    p3 = { x: midX, y: cy };
                                }
                            } else if (type === "corner_3") {
                                // S <-> E
                                if (entry === "S") {
                                    p0 = { x: midX, y: cy + ch };
                                    p1 = { x: midX, y: cy + ch - k };
                                    p2 = { x: cx + cw - k, y: midY };
                                    p3 = { x: cx + cw, y: midY };
                                } else {
                                    p0 = { x: cx + cw, y: midY };
                                    p1 = { x: cx + cw - k, y: midY };
                                    p2 = { x: midX, y: cy + ch - k };
                                    p3 = { x: midX, y: cy + ch };
                                }
                            } else if (type === "corner_4") {
                                // S <-> W
                                if (entry === "S") {
                                    p0 = { x: midX, y: cy + ch };
                                    p1 = { x: midX, y: cy + ch - k };
                                    p2 = { x: cx + k, y: midY };
                                    p3 = { x: cx, y: midY };
                                } else {
                                    p0 = { x: cx, y: midY };
                                    p1 = { x: cx + k, y: midY };
                                    p2 = { x: midX, y: cy + ch - k };
                                    p3 = { x: midX, y: cy + ch };
                                }
                            }
                            return { p0: p0, p1: p1, p2: p2, p3: p3 };
                        }

                        function getPathPoint(type, entry, cx, cy, cw, ch, t) {
                            var midX = cx + cw / 2;
                            var midY = cy + ch / 2;
                            if (type === "valve") {
                                // Valve liquid begins inside the valve body casing and exits East into the pipe
                                var startVx = cx + cw * 0.45;
                                var endVx = cx + cw;
                                var vx = startVx + (endVx - startVx) * t;
                                var vy = midY + Math.sin(t * 12) * (cw * 0.02);
                                return { x: vx, y: vy };
                            } else if (type === "pipe_h") {
                                var x = (entry === "W") ? (cx + cw * t) : (cx + cw * (1 - t));
                                var y = midY + Math.sin(t * 12) * (cw * 0.02);
                                return { x: x, y: y };
                            } else if (type === "pipe_v") {
                                var vx = midX + Math.sin(t * 12) * (cw * 0.02);
                                var vy = (entry === "N") ? (cy + ch * t) : (cy + ch * (1 - t));
                                return { x: vx, y: vy };
                            } else if (type === "cross") {
                                if (entry === "W") {
                                    return { x: cx + cw * t, y: midY + Math.sin(t * 12) * (cw * 0.02) };
                                } else if (entry === "E") {
                                    return { x: cx + cw * (1 - t), y: midY + Math.sin(t * 12) * (cw * 0.02) };
                                } else if (entry === "N") {
                                    return { x: midX + Math.sin(t * 12) * (cw * 0.02), y: cy + ch * t };
                                } else {
                                    return { x: midX + Math.sin(t * 12) * (cw * 0.02), y: cy + ch * (1 - t) };
                                }
                            } else if (type === "corner_1" || type === "corner_2" || type === "corner_3" || type === "corner_4") {
                                var cpts = getCornerControlPoints(type, entry, cx, cy, cw, ch);
                                return getBezierPoint(cpts.p0, cpts.p1, cpts.p2, cpts.p3, t);
                            }
                            return null;
                        }

                        function drawBubble(ctx, bx, by, rad) {
                            if (rad <= 0.5) return;
                            ctx.beginPath();
                            ctx.arc(bx, by, rad, 0, Math.PI * 2);
                            ctx.fillStyle = Qt.rgba(0.85, 1.0, 0.95, 0.75);
                            ctx.fill();

                            ctx.beginPath();
                            ctx.arc(bx - rad * 0.35, by - rad * 0.35, Math.max(0.5, rad * 0.35), 0, Math.PI * 2);
                            ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.92);
                            ctx.fill();
                        }

                        function drawFluidInCell(ctx, cell, cx, cy, cw, ch) {
                            var p = Math.max(0.0, Math.min(1.0, cell.fillProgress));
                            var entry = cell.entryPort;

                            ctx.save();
                            var grad = ctx.createLinearGradient(cx, cy, cx + cw, cy + ch);
                            grad.addColorStop(0, "#059669");
                            grad.addColorStop(0.5, "#047857");
                            grad.addColorStop(1, "#065f46");

                            ctx.strokeStyle = grad;
                            ctx.lineWidth = cw * 0.18;
                            ctx.lineCap = "butt";
                            ctx.lineJoin = "miter";

                            ctx.beginPath();
                            var midX = cx + cw / 2;
                            var midY = cy + ch / 2;

                            if (cell.type === "valve") {
                                // Liquid originates from inside the valve body and travels East into the pipeline
                                var startX = cx + cw * 0.45;
                                var targetX = cx + cw;
                                var curX = startX + (targetX - startX) * p;
                                ctx.moveTo(startX, midY);
                                ctx.lineTo(curX, midY);
                            } else if (cell.type === "pipe_h") {
                                if (entry === "W") {
                                    ctx.moveTo(cx, midY);
                                    ctx.lineTo(cx + cw * p, midY);
                                } else {
                                    ctx.moveTo(cx + cw, midY);
                                    ctx.lineTo(cx + cw * (1 - p), midY);
                                }
                            } else if (cell.type === "pipe_v") {
                                if (entry === "N") {
                                    ctx.moveTo(midX, cy);
                                    ctx.lineTo(midX, cy + ch * p);
                                } else {
                                    ctx.moveTo(midX, cy + ch);
                                    ctx.lineTo(midX, cy + ch * (1 - p));
                                }
                            } else if (cell.type === "corner_1" || cell.type === "corner_2" ||
                                       cell.type === "corner_3" || cell.type === "corner_4") {
                                var bPts = getCornerControlPoints(cell.type, entry, cx, cy, cw, ch);
                                drawBezierSub(ctx, bPts.p0, bPts.p1, bPts.p2, bPts.p3, p);
                            } else if (cell.type === "cross") {
                                if (entry === "W") {
                                    ctx.moveTo(cx, midY);
                                    ctx.lineTo(cx + cw * p, midY);
                                } else if (entry === "E") {
                                    ctx.moveTo(cx + cw, midY);
                                    ctx.lineTo(cx + cw * (1 - p), midY);
                                } else if (entry === "N") {
                                    ctx.moveTo(midX, cy);
                                    ctx.lineTo(midX, cy + ch * p);
                                } else {
                                    ctx.moveTo(midX, cy + ch);
                                    ctx.lineTo(midX, cy + ch * (1 - p));
                                }
                            } else if (cell.type === "reservoir") {
                                if (entry === "W") {
                                    ctx.moveTo(cx, midY);
                                    ctx.lineTo(cx + cw * p, midY);
                                } else {
                                    ctx.moveTo(cx + cw, midY);
                                    ctx.lineTo(cx + cw * (1 - p), midY);
                                }
                            }

                            ctx.stroke();

                            // Subtle water core stream highlight
                            if (cell.type !== "reservoir") {
                                ctx.lineWidth = cw * 0.07;
                                ctx.strokeStyle = Qt.rgba(0.5, 0.95, 0.7, 0.40);
                                ctx.stroke();
                            }

                            // Effervescent flow bubbles inside the fluid stream
                            if (cell.type !== "reservoir") {
                                var bubbleOffsets = [0.15, 0.48, 0.82];
                                for (var bi = 0; bi < bubbleOffsets.length; bi++) {
                                    var bt = (root.flowAnimTime * 0.40 + bubbleOffsets[bi]) % 1.0;
                                    if (bt <= p && bt >= 0.02) {
                                        var bPos = getPathPoint(cell.type, entry, cx, cy, cw, ch, bt);
                                        if (bPos) {
                                            var bRad = (cw * 0.024) + ((bi % 2 === 0) ? (cw * 0.007) : -(cw * 0.004));
                                            drawBubble(ctx, bPos.x, bPos.y, bRad);
                                        }
                                    }
                                }
                            } else {
                                // Reservoir liquid chamber fill & swirling bubbles
                                if (p > 0.15) {
                                    var chamberRad = (cw * 0.22) * Math.min(1.0, (p - 0.15) / 0.6);
                                    ctx.beginPath();
                                    ctx.arc(midX, midY, chamberRad, 0, Math.PI * 2);
                                    ctx.fillStyle = "#047857";
                                    ctx.fill();

                                    for (var rbi = 0; rbi < 4; rbi++) {
                                        var rAngle = root.flowAnimTime * 2.0 + rbi * (Math.PI / 2);
                                        var rDist = chamberRad * (0.3 + 0.4 * ((rbi % 2) ? 0.8 : 0.4));
                                        var rbx = midX + Math.cos(rAngle) * rDist;
                                        var rby = midY + Math.sin(rAngle) * (rDist * 0.7);
                                        drawBubble(ctx, rbx, rby, cw * 0.022);
                                    }
                                }
                            }

                            ctx.restore();
                        }

                        function drawCrossSecondPass(ctx, cell, cx, cy, cw, ch) {
                            var p = Math.max(0.0, Math.min(1.0, cell.crossFillProgress));
                            var entry = cell.crossEntryPort;

                            ctx.save();
                            var grad = ctx.createLinearGradient(cx, cy, cx + cw, cy + ch);
                            grad.addColorStop(0, "#059669");
                            grad.addColorStop(0.5, "#047857");
                            grad.addColorStop(1, "#065f46");

                            ctx.strokeStyle = grad;
                            ctx.lineWidth = cw * 0.18;
                            ctx.lineCap = "butt";

                            ctx.beginPath();
                            var midX = cx + cw / 2;
                            var midY = cy + ch / 2;

                            if (entry === "W") {
                                ctx.moveTo(cx, midY);
                                ctx.lineTo(cx + cw * p, midY);
                            } else if (entry === "E") {
                                ctx.moveTo(cx + cw, midY);
                                ctx.lineTo(cx + cw * (1 - p), midY);
                            } else if (entry === "N") {
                                ctx.moveTo(midX, cy);
                                ctx.lineTo(midX, cy + ch * p);
                            } else {
                                ctx.moveTo(midX, cy + ch);
                                ctx.lineTo(midX, cy + ch * (1 - p));
                            }
                            ctx.stroke();

                            ctx.lineWidth = cw * 0.07;
                            ctx.strokeStyle = Qt.rgba(0.5, 0.95, 0.7, 0.40);
                            ctx.stroke();

                            // Bubbles for cross second pass
                            var crossBubbleOffsets = [0.22, 0.58, 0.88];
                            for (var cbi = 0; cbi < crossBubbleOffsets.length; cbi++) {
                                var cbt = (root.flowAnimTime * 0.40 + crossBubbleOffsets[cbi]) % 1.0;
                                if (cbt <= p && cbt >= 0.02) {
                                    var cbPos = getPathPoint("cross", entry, cx, cy, cw, ch, cbt);
                                    if (cbPos) {
                                        var cbRad = (cw * 0.024) + ((cbi % 2 === 0) ? (cw * 0.007) : -(cw * 0.003));
                                        drawBubble(ctx, cbPos.x, cbPos.y, cbRad);
                                    }
                                }
                            }

                            ctx.restore();
                        }
                    }

                    // Layer 3: Placed Pipe Fittings (ON TOP of fluid, clamping fluid into the cutaway bore)
                    Repeater {
                        model: Engine.ROWS * Engine.COLS

                        Item {
                            readonly property int r: Math.floor(index / Engine.COLS)
                            readonly property int c: index % Engine.COLS
                            x: c * gridMatrix.cellW
                            y: r * gridMatrix.cellH
                            width: gridMatrix.cellW
                            height: gridMatrix.cellH

                            // Placed Pipe Fitting (Copper standard, Dark Cast Iron for permanent unchangeable pieces)
                            Image {
                                id: pipeSprite
                                anchors.fill: parent
                                fillMode: Image.Stretch
                                smooth: true
                                mipmap: true
                                source: {
                                    if (gridRevision < 0 || !gameState || !gameState.grid) return "";
                                    var cell = gameState.grid[r][c];
                                    if (!cell || cell.type === "empty") return "";
                                    if (cell.isPermanent && cell.type !== "valve") {
                                        return "assets/" + cell.type + "_iron.png";
                                    }
                                    return "assets/" + cell.type + ".png";
                                }
                            }

                            // Cell Mouse Click Handler
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: {
                                    if (!gameState || !gameState.grid) return Qt.PointingHandCursor;
                                    var cell = gameState.grid[r][c];
                                    if (cell && (cell.isPermanent || cell.hazard || cell.type === "hazard" || cell.type === "valve" || cell.filled || cell.isFlowing)) {
                                        return Qt.ForbiddenCursor;
                                    }
                                    return Qt.PointingHandCursor;
                                }
                                onClicked: {
                                    cursorR = r;
                                    cursorC = c;
                                    placePipeAt(r, c);
                                }
                                onEntered: {
                                    cursorR = r;
                                    cursorC = c;
                                }
                            }
                        }
                    }

                    // Layer 4: High-Pressure Blowout Water Flood Effect
                    Canvas {
                        id: floodCanvas
                        anchors.fill: parent
                        z: 45
                        visible: currentEngineState === "flooding" || currentEngineState === "round_won" || currentEngineState === "game_over" || (gameState && gameState.floodProgress > 0)

                        onPaint: {
                            var ctx = getContext("2d");
                            if (typeof ctx.reset === "function") ctx.reset();
                            ctx.clearRect(0, 0, width, height);

                            if (!gameState || (!gameState.floodProgress && currentEngineState !== "flooding" && currentEngineState !== "round_won" && currentEngineState !== "game_over")) return;

                            var fp = Math.max(0.0, Math.min(1.0, gameState.floodProgress));
                            var cw = gridMatrix.cellW;
                            var ch = gridMatrix.cellH;

                            // Leak position in pixels
                            var leakR = gameState.leakPos ? gameState.leakPos.r : gameState.currentR;
                            var leakC = gameState.leakPos ? gameState.leakPos.c : gameState.currentC;
                            var lx = (Math.max(0, Math.min(Engine.COLS - 1, leakC)) + 0.5) * cw;
                            var ly = (Math.max(0, Math.min(Engine.ROWS - 1, leakR)) + 0.5) * ch;

                            ctx.save();

                            // 1. Rising flood water layer across the playfield
                            var waterH = height * fp;
                            var surfaceY = height - waterH;

                            ctx.beginPath();
                            ctx.moveTo(0, height);
                            ctx.lineTo(0, surfaceY);

                            var waveAmp = (1.0 - fp * 0.4) * 8.0;
                            for (var wx = 0; wx <= width; wx += 16) {
                                var wy = surfaceY + Math.sin(wx * 0.04 + root.flowAnimTime * 8.0) * waveAmp;
                                ctx.lineTo(wx, wy);
                            }
                            ctx.lineTo(width, height);
                            ctx.closePath();

                            var floodGrad = ctx.createLinearGradient(0, surfaceY, 0, height);
                            floodGrad.addColorStop(0, "rgba(16, 185, 129, 0.65)");
                            floodGrad.addColorStop(0.3, "rgba(5, 150, 105, 0.78)");
                            floodGrad.addColorStop(1, "rgba(4, 120, 87, 0.90)");
                            ctx.fillStyle = floodGrad;
                            ctx.fill();

                            // Foam surface crest line
                            ctx.strokeStyle = "rgba(209, 250, 229, 0.90)";
                            ctx.lineWidth = 3;
                            ctx.stroke();

                            // 2. High-pressure blowout spray from leak nozzle
                            var maxBurstR = Math.min(width, height) * 0.55;
                            var burstR = maxBurstR * Math.min(1.0, fp * 1.4);

                            ctx.beginPath();
                            ctx.arc(lx, ly, burstR, 0, Math.PI * 2);
                            ctx.strokeStyle = Qt.rgba(0.7, 1.0, 0.85, (1.0 - fp * 0.8) * 0.75);
                            ctx.lineWidth = 4;
                            ctx.stroke();

                            if (burstR > 20) {
                                ctx.beginPath();
                                ctx.arc(lx, ly, burstR * 0.6, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(0.9, 1.0, 0.95, (1.0 - fp * 0.7) * 0.6);
                                ctx.lineWidth = 2.5;
                                ctx.stroke();
                            }

                            // Frothing splashing particles at blowout point
                            for (var pi = 0; pi < 8; pi++) {
                                var pAngle = pi * (Math.PI / 4) + root.flowAnimTime * 6.0;
                                var pDist = (burstR * 0.4) * (0.4 + 0.6 * ((pi % 2) ? 0.9 : 0.4));
                                var px = lx + Math.cos(pAngle) * pDist;
                                var py = ly + Math.sin(pAngle) * (pDist * 0.8);
                                ctx.beginPath();
                                ctx.arc(px, py, 4 + (pi % 3) * 2, 0, Math.PI * 2);
                                ctx.fillStyle = "rgba(240, 253, 244, 0.85)";
                                ctx.fill();
                            }

                            // Rising bubbles through the flooded water
                            for (var bi = 0; bi < 16; bi++) {
                                var bx = (bi * 67 + Math.sin(root.flowAnimTime * 2 + bi) * 30) % width;
                                var by = height - ((root.flowAnimTime * 80 + bi * 45) % Math.max(20, waterH));
                                var brad = 2.5 + (bi % 4);
                                ctx.beginPath();
                                ctx.arc(bx, by, brad, 0, Math.PI * 2);
                                ctx.fillStyle = "rgba(220, 255, 240, 0.65)";
                                ctx.fill();
                            }

                            ctx.restore();
                        }
                    }

                    // Reticle Cursor for Keyboard Nav
                    Rectangle {
                        id: cursorReticle
                        x: cursorC * gridMatrix.cellW
                        y: cursorR * gridMatrix.cellH
                        width: gridMatrix.cellW
                        height: gridMatrix.cellH
                        color: "transparent"
                        readonly property bool isCellLocked: {
                            if (gridRevision < 0 || !gameState || !gameState.grid) return false;
                            var row = gameState.grid[cursorR];
                            if (!row) return false;
                            var cell = row[cursorC];
                            return cell && (cell.isPermanent || cell.hazard || cell.type === "hazard" || cell.type === "valve" || cell.filled || cell.isFlowing);
                        }
                        border.color: isCellLocked ? "#e74c3c" : root.themeAccent
                        border.width: 2.5
                        radius: 4
                        z: 50

                        Behavior on x { NumberAnimation { duration: 50 } }
                        Behavior on y { NumberAnimation { duration: 50 } }

                        // Subtle corner rivets for steampunk feel
                        Rectangle { width: 4; height: 4; radius: 2; color: cursorReticle.border.color; x: 2; y: 2 }
                        Rectangle { width: 4; height: 4; radius: 2; color: cursorReticle.border.color; x: parent.width - 6; y: 2 }
                        Rectangle { width: 4; height: 4; radius: 2; color: cursorReticle.border.color; x: 2; y: parent.height - 6 }
                        Rectangle { width: 4; height: 4; radius: 2; color: cursorReticle.border.color; x: parent.width - 6; y: parent.height - 6 }
                    }
                }
            }

            // 3. BOTTOM BAR: Rush Pump Trigger & Keyboard Control Hints
            Rectangle {
                id: bottomBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                color: root.themeCardBg
                radius: 8
                border.color: root.themeBorder
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // Rush Pump Button
                    Rectangle {
                        id: rushBtn
                        width: 170
                        height: 32
                        color: (gameState && gameState.isRushing) ? "#b91c1c" : (rushMouse.containsMouse ? "#ea580c" : root.themeAccent)
                        radius: 6

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "⚡"; font.pixelSize: 13 }
                            Text {
                                text: (gameState && gameState.state === "countdown") ? "RELEASE NOW (SPACE)" :
                                      (gameState && gameState.isRushing) ? "RUSHING 5X!" : "RUSH PUMP (SPACE)"
                                color: root.themeBtnFg
                                font.family: monoFontFamily
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: rushMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (gameState && gameState.state === "flowing") {
                                    gameState.isRushing = true;
                                    playSound("rush");
                                } else if (gameState && gameState.state === "countdown") {
                                    gameState.countdown = 0.0;
                                    playSound("rush");
                                }
                            }
                            onReleased: {
                                if (gameState) gameState.isRushing = false;
                            }
                        }
                    }

                    // Keyboard shortcuts reminder
                    Text {
                        text: "⌨️ Move: Arrows / WASD / Vim HJKL  •  Place: Enter / Click  •  Restart: R  •  Help: ?"
                        color: root.themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Sector Badge on Right
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: sectorText.implicitWidth + 18
                    color: root.themeBoardBg
                    radius: 4
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        id: sectorText
                        anchors.centerIn: parent
                        text: "SECTOR " + root.currentLevel
                        color: root.themeAccent
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Game Over, Sound Toast)
        // =====================================================================
        // Help Modal (Canonical Omarchy Template Standard)
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#b3000000"
            visible: root.showHelp
            z: 900

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                width: Math.min(parent.width * 0.90, 520)
                height: helpCol.height + 40
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                Column {
                    id: helpCol
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 12

                    Text {
                        text: "HOW TO PLAY"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.helpText
                        font.pixelSize: 12
                        color: root.themeFg
                        lineHeight: 1.4
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: 120
                        height: 32
                        radius: 6
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "GOT IT"
                            font.bold: true
                            font.pixelSize: 11
                            color: root.themeBtnFg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }

                    Text {
                        text: "Created by Chris Thompson (@bigcjat) with Gemini"
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.75
                    }
                }
            }
        }

        // =====================================================================
        // VICTORIAN STEAMPUNK RESULTS MODAL (Sector Clear / Pressure Blowout)
        // =====================================================================
        Rectangle {
            id: resultsModal
            anchors.fill: parent
            color: "#d90b0e14"
            visible: currentEngineState === "game_over" || currentEngineState === "round_won"
            z: 950
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            // Backdrop click absorber: prevents accidental dismissals by clicking outside buttons
            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {}
            }

            Rectangle {
                id: modalFrame
                width: Math.min(parent.width * 0.92, 540)
                height: Math.min(parent.height * 0.94, modalContent.implicitHeight + 48)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: currentEngineState === "round_won" ? "#10b981" : (root.themeAccent || "#d97706")
                border.width: 2
                radius: 14

                // Subtle inner metallic highlight
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                }

                // Steampunk Corner Rivets
                Rectangle { width: 6; height: 6; radius: 3; color: root.themeAccent; x: 6; y: 6 }
                Rectangle { width: 6; height: 6; radius: 3; color: root.themeAccent; x: parent.width - 12; y: 6 }
                Rectangle { width: 6; height: 6; radius: 3; color: root.themeAccent; x: 6; y: parent.height - 12 }
                Rectangle { width: 6; height: 6; radius: 3; color: root.themeAccent; x: parent.width - 12; y: parent.height - 12 }

                Column {
                    id: modalContent
                    anchors.centerIn: parent
                    width: parent.width - 44
                    spacing: 14

                    // 1. Status Pill Badge
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: badgeRow.implicitWidth + 28
                        height: 28
                        radius: 14
                        color: currentEngineState === "round_won" ? "#2210b981" : "#22ef4444"
                        border.color: currentEngineState === "round_won" ? "#10b981" : "#ef4444"
                        border.width: 1.5

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: currentEngineState === "round_won" ? "🏆" : "⚠️"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: currentEngineState === "round_won" ? "SECTOR COMPLETED" : "PRESSURE BLOWOUT"
                                font.bold: true
                                font.pixelSize: 12
                                font.letterSpacing: 1.2
                                color: currentEngineState === "round_won" ? "#10b981" : "#ef4444"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // 2. Title & Subtitle Header
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentEngineState === "round_won" ?
                                  ("SECTOR " + (gameState && gameState.level < 10 ? "0" + gameState.level : (gameState ? gameState.level : "1")) + " CLEARED") :
                                  "PIPELINE RUPTURE!"
                            font.pixelSize: 24
                            font.bold: true
                            color: currentEngineState === "round_won" ? "#34d399" : "#f87171"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentEngineState === "round_won" ?
                                  "Municipal pressure stabilized. Pipeline integrity verified." :
                                  ("Stream escaped at open fitting before meeting the " + (gameState ? gameState.quota : 10) + "-pipe quota.")
                            font.pixelSize: 12
                            color: root.themeSubtext
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // 3. Stats 2x2 Grid (Time, Parts Used, Routed Quota, Cross Loops)
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10

                        // Stat 1: Flow Time
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 58
                            radius: 8
                            color: "#161922"
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "FLOW TIME"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: root.themeSubtext
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.formatTime(root.summaryTime)
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.themeFg
                                }
                            }
                        }

                        // Stat 2: Parts Placed / Used
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 58
                            radius: 8
                            color: "#161922"
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "PARTS USED"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: root.themeSubtext
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.summaryPipesPlaced.toString()
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.themeAccent
                                }
                            }
                        }

                        // Stat 3: Pipes Routed vs Quota
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 58
                            radius: 8
                            color: "#161922"
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "PIPES ROUTED"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: root.themeSubtext
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Text {
                                        text: root.summaryTraversed + " / " + root.summaryQuota
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: root.monoFontFamily
                                        color: root.summaryTraversed >= root.summaryQuota ? "#10b981" : "#f87171"
                                    }
                                    Text {
                                        text: root.summaryTraversed >= root.summaryQuota ? "✔" : "✗"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: root.summaryTraversed >= root.summaryQuota ? "#10b981" : "#f87171"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Stat 4: Cross Double Traversal Bonus
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 58
                            radius: 8
                            color: "#161922"
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "CROSS LOOPS"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: root.themeSubtext
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.summaryCrossBonus + " (+" + (root.summaryCrossBonus * 500) + ")"
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.summaryCrossBonus > 0 ? "#fbbf24" : root.themeFg
                                }
                            }
                        }
                    }

                    // 4. Score Banner Box
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: "#1e2230"
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 24

                            Column {
                                spacing: 2
                                Text {
                                    text: "ROUND SCORE"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: root.themeSubtext
                                }
                                Text {
                                    text: root.score.toLocaleString()
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.themeAccent
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 32
                                color: Qt.rgba(1, 1, 1, 0.15)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2
                                Row {
                                    spacing: 6
                                    Text {
                                        text: "BEST SCORE"
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.letterSpacing: 1.0
                                        color: root.themeSubtext
                                    }
                                    Text {
                                        visible: root.score >= root.bestScore && root.score > 0
                                        text: "★ NEW RECORD"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#fbbf24"
                                    }
                                }
                                Text {
                                    text: root.bestScore.toLocaleString()
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    color: root.themeFg
                                }
                            }
                        }
                    }

                    // 5. Action Buttons (Try Again or Next Game / Sector)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        // Primary Action Button (Next Sector or Try Again)
                        Rectangle {
                            id: primaryActionBtn
                            width: 190
                            height: 44
                            radius: 8
                            color: currentEngineState === "round_won" ?
                                   (primaryBtnMouse.containsMouse ? "#059669" : "#10b981") :
                                   (primaryBtnMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent)
                            border.color: Qt.rgba(1, 1, 1, 0.2)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: currentEngineState === "round_won" ? "NEXT SECTOR ➜" : "TRY AGAIN ↻"
                                    color: root.themeBtnFg
                                    font.bold: true
                                    font.pixelSize: 13
                                    font.letterSpacing: 0.8
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "SPACE / ENTER"
                                    color: root.themeBtnFg
                                    opacity: 0.75
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: primaryBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (currentEngineState === "round_won") root.advanceToNextLevel();
                                    else root.startNewGame(gameState ? gameState.level : 1);
                                }
                            }
                        }

                        // Secondary Action Button (Replay Sector or New Game)
                        Rectangle {
                            id: secondaryActionBtn
                            width: 160
                            height: 44
                            radius: 8
                            color: secondaryBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "#1f2430"
                            border.color: root.themeBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: currentEngineState === "round_won" ? "REPLAY SECTOR" : "NEW GAME"
                                    color: root.themeFg
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.letterSpacing: 0.5
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "PRESS R"
                                    color: root.themeSubtext
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: secondaryBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (currentEngineState === "round_won") root.startNewGame(gameState ? gameState.level : 1);
                                    else root.startNewGame(1);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Sound Toast
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 16
            width: toastText.implicitWidth + 24
            height: 28
            radius: 14
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            opacity: 0
            z: 800

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
            }

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; from: 0; to: 1; duration: 150 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: soundToast; property: "opacity"; from: 1; to: 0; duration: 250 }
            }
        }
    }

    // =========================================================================
    // CANONICAL OMARCHY ARCADE SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        z: 1000
    }
}
