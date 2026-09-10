import QtQuick
import QtQuick.Window
import "PipeEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 960
    height: 720
    minimumWidth: 680
    minimumHeight: 520
    title: "Pipe Punk • Steampunk Municipal Waterworks"

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
    property color themeColor0: "#1a1d26"
    property color themeColor1: "#ef4444"
    property color themeColor2: "#10b981"
    property color themeColor3: "#f59e0b"
    property color themeColor4: "#3b82f6"
    property color themeColor5: "#8b5cf6"
    property color themeColor6: "#06b6d4"

    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE
    // =========================================================================
    property var gameState: null
    property int currentLevel: 1
    property int score: 0
    property int bestScore: 0
    property bool isMuted: false
    property bool showHelpModal: false
    property bool splashActive: typeof noSplash !== "undefined" ? !noSplash : true

    // Cursor grid selection for keyboard navigation
    property int cursorR: 3
    property int cursorC: 4
    property int gridRevision: 0

    // Screen Shake effect on blowout or rush
    property real shakeX: 0
    property real shakeY: 0

    // Sound dispatcher helper
    function playSfx(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    // Capture screenshot for automated tests and arcade gallery
    function captureScreenshot(filePath, includeHelp) {
        showHelpModal = Boolean(includeHelp);
        root.requestUpdate();
        var grabItem = root.contentItem;
        grabItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved to:", filePath);
        });
    }

    // =========================================================================
    // GAME INITIALIZATION
    // =========================================================================
    function startNewGame(lvl) {
        currentLevel = lvl || 1;
        gameState = Engine.createGameState(currentLevel);
        score = 0;
        cursorR = gameState.valveRow;
        cursorC = gameState.valveCol + 1;
        if (cursorC >= Engine.COLS) cursorC = Engine.COLS - 1;
        shakeX = 0;
        shakeY = 0;
        gridRevision++;
        playSfx("pipe_clank");
    }

    function advanceToNextLevel() {
        currentLevel++;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setHighestLevel(currentLevel);
        }
        var currentScore = score;
        gameState = Engine.createGameState(currentLevel);
        gameState.score = currentScore;
        cursorR = gameState.valveRow;
        cursorC = gameState.valveCol + 1;
        if (cursorC >= Engine.COLS) cursorC = Engine.COLS - 1;
        playSfx("level_clear");
    }

    function setupDemoBoard() {
        startNewGame(1);
        var vr = gameState.valveRow;
        var vc = gameState.valveCol;
        // Pipe 1: horizontal from valve
        if (vc + 1 < Engine.COLS) {
            gameState.grid[vr][vc+1].type = "pipe_h";
            gameState.grid[vr][vc+1].entryPort = "W";
            gameState.grid[vr][vc+1].exitPort = "E";
            gameState.grid[vr][vc+1].filled = true;
            gameState.grid[vr][vc+1].fillProgress = 1.0;
        }
        // Pipe 2: corner 4 (W to S)
        if (vc + 2 < Engine.COLS) {
            gameState.grid[vr][vc+2].type = "corner_4";
            gameState.grid[vr][vc+2].entryPort = "W";
            gameState.grid[vr][vc+2].exitPort = "S";
            gameState.grid[vr][vc+2].filled = true;
            gameState.grid[vr][vc+2].fillProgress = 1.0;
        }
        // Pipe 3: vertical straight down
        if (vr + 1 < Engine.ROWS && vc + 2 < Engine.COLS) {
            gameState.grid[vr+1][vc+2].type = "pipe_v";
            gameState.grid[vr+1][vc+2].entryPort = "N";
            gameState.grid[vr+1][vc+2].exitPort = "S";
            gameState.grid[vr+1][vc+2].filled = true;
            gameState.grid[vr+1][vc+2].fillProgress = 1.0;
        }
        // Pipe 4: corner 1 (N to E) flowing
        if (vr + 2 < Engine.ROWS && vc + 2 < Engine.COLS) {
            gameState.grid[vr+2][vc+2].type = "corner_1";
            gameState.grid[vr+2][vc+2].entryPort = "N";
            gameState.grid[vr+2][vc+2].exitPort = "E";
            gameState.grid[vr+2][vc+2].isFlowing = true;
            gameState.grid[vr+2][vc+2].fillProgress = 0.65;
        }
        // Pipe 5: cross ahead
        if (vr + 2 < Engine.ROWS && vc + 3 < Engine.COLS) {
            gameState.grid[vr+2][vc+3].type = "cross";
        }
        // Pipe 6: reservoir ahead
        if (vr + 2 < Engine.ROWS && vc + 4 < Engine.COLS) {
            gameState.grid[vr+2][vc+4].type = "reservoir";
        }

        gameState.state = "flowing";
        gameState.traversedCount = 3;
        gameState.score = 420;
        root.score = 420;
        gameState.psi = 64.0;
        cursorR = Math.min(Engine.ROWS - 1, vr + 2);
        cursorC = Math.min(Engine.COLS - 1, vc + 5);
        gridRevision++;
        gridCanvas.requestPaint();
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            bestScore = settingsManager.getBestScore();
        }
        startNewGame(1);
    }

    // =========================================================================
    // GAME SIMULATION LOOP (60 FPS)
    // =========================================================================
    Timer {
        id: simTimer
        interval: 16
        running: gameState && gameState.state !== "game_over" && gameState.state !== "round_won" && !splashActive
        repeat: true
        onTriggered: {
            if (!gameState) return;
            var prevState = gameState.state;
            var prevTraversed = gameState.traversedCount;

            Engine.updateSimulation(gameState, 0.016);

            score = gameState.score;
            if (score > bestScore) {
                bestScore = score;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setBestScore(bestScore);
                }
            }

            // Audio cues
            if (gameState.traversedCount > prevTraversed) {
                playSfx("water_flow");
            }

            if (prevState === "countdown" && gameState.state === "flowing") {
                playSfx("water_flow");
            }

            if (gameState.state === "game_over" && prevState !== "game_over") {
                playSfx("steam_hiss");
                shakeAnim.start();
            } else if (gameState.state === "round_won" && prevState !== "round_won") {
                playSfx("level_clear");
            }

            // Screen shake when rushing
            if (gameState.isRushing) {
                shakeX = (Math.random() - 0.5) * 4;
                shakeY = (Math.random() - 0.5) * 4;
            } else if (gameState.state !== "game_over") {
                shakeX = 0;
                shakeY = 0;
            }

            gridCanvas.requestPaint();
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
    // KEYBOARD INPUT HANDLING
    // =========================================================================
    Item {
        id: keyboardHandler
        focus: true
        anchors.fill: parent

        Keys.onPressed: function(event) {
            if (splashActive) {
                splashActive = false;
                event.accepted = true;
                return;
            }

            // Space to Rush Pump
            if (event.key === Qt.Key_Space) {
                if (gameState && gameState.state === "flowing") {
                    gameState.isRushing = true;
                    playSfx("rush");
                } else if (gameState && gameState.state === "round_won") {
                    advanceToNextLevel();
                } else if (gameState && gameState.state === "game_over") {
                    startNewGame(1);
                }
                event.accepted = true;
                return;
            }

            // Enter to place pipe at cursor
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (gameState && (gameState.state === "countdown" || gameState.state === "flowing")) {
                    if (Engine.placeNextPiece(gameState, cursorR, cursorC)) {
                        playSfx("pipe_clank");
                        gridRevision++;
                        gridCanvas.requestPaint();
                    }
                }
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
            } else if (event.key === Qt.Key_R) {
                startNewGame(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                isMuted = !isMuted;
                event.accepted = true;
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                showHelpModal = !showHelpModal;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (showHelpModal) showHelpModal = false;
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Space) {
                if (gameState) gameState.isRushing = false;
                event.accepted = true;
            }
        }
    }

    // =========================================================================
    // MAIN APP LAYOUT
    // =========================================================================
    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 14
        x: root.shakeX
        y: root.shakeY

        // ---------------------------------------------------------------------
        // TIER 1: MAIN HEADER ROW (Template Standard: Title & Stats)
        // ---------------------------------------------------------------------
        Row {
            id: headerItem
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64
            spacing: 12

            // Title Box (Brushed Brass Aesthetic)
            Rectangle {
                width: 280
                height: parent.height
                color: themeCardBg
                radius: 8
                border.color: themeBorder
                border.width: 1.5

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "⚙️"
                        font.pixelSize: 28
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "PIPE PUNK"
                            color: themeAccent
                            font.family: monoFontFamily
                            font.pixelSize: 20
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Text {
                            text: "STEAM WATERWORKS • OA-038"
                            color: themeSubtext
                            font.family: monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }
            }

            // Center: Analog Circular Brass Pressure Gauge
            Item {
                id: headerGauge
                width: 66
                height: 66
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: "assets/gauge_dial.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Image {
                    id: needleImg
                    width: 14
                    height: 38
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height + 4
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

            Item { width: Math.max(10, headerItem.width - 280 - 66 - 24 - 360); height: 1 }

            // Stats Group: PIPES / QUOTA, SCORE, BEST
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Pipes / Quota Gauge
                Rectangle {
                    width: 120
                    height: 56
                    color: themeCardBg
                    radius: 8
                    border.color: (gameState && gameState.traversedCount >= gameState.quota) ? "#10b981" : themeBorder
                    border.width: (gameState && gameState.traversedCount >= gameState.quota) ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "PIPES / QUOTA"
                            color: themeSubtext
                            font.family: monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: gameState ? (gameState.traversedCount + " / " + gameState.quota) : "0 / 5"
                            color: (gameState && gameState.traversedCount >= gameState.quota) ? "#10b981" : themeFg
                            font.family: monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Current Score
                Rectangle {
                    width: 110
                    height: 56
                    color: themeCardBg
                    radius: 8
                    border.color: themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "SCORE"
                            color: themeSubtext
                            font.family: monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.score.toString()
                            color: themeFg
                            font.family: monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Best Score
                Rectangle {
                    width: 110
                    height: 56
                    color: themeCardBg
                    radius: 8
                    border.color: themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: "BEST"
                            color: themeSubtext
                            font.family: monoFontFamily
                            font.pixelSize: 9
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.bestScore.toString()
                            color: themeAccent
                            font.family: monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // TIER 2: SUBHEADER ROW (Template Standard: Help, Status, Actions)
        // ---------------------------------------------------------------------
        Row {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38
            spacing: 8

            // Left: How to Play Button
            Rectangle {
                id: helpBtn
                height: parent.height
                width: 120
                color: helpMouse.containsMouse ? "#282c37" : themeCardBg
                radius: 6
                border.color: themeBorder
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "❓"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "How to Play"
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: helpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: showHelpModal = true
                }
            }

            // Center: Valve / Pressure Status Box
            Rectangle {
                width: Math.max(180, subheaderItem.width - 450)
                height: parent.height
                color: themeCardBg
                radius: 6
                border.color: themeBorder
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: (gameState && gameState.state === "countdown") ? "⏳" :
                              (gameState && gameState.state === "round_won") ? "🏆" :
                              (gameState && gameState.state === "game_over") ? "💥" : "🌊"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: {
                            if (!gameState) return "STANDBY";
                            if (gameState.state === "countdown") {
                                return "VALVE RELEASE IN: " + Math.ceil(gameState.countdown) + "s";
                            }
                            if (gameState.state === "flowing") {
                                return gameState.isRushing ? "⚡ PUMP RUSHING (5X)" : "FLOW PRESSURE: " + Math.round(gameState.psi) + " PSI";
                            }
                            if (gameState.state === "round_won") {
                                return "SECTOR CLEARED! PRESS SPACE";
                            }
                            if (gameState.state === "game_over") {
                                return "BOILER BLOWOUT! PRESS SPACE";
                            }
                            return "OPERATIONAL";
                        }
                        color: (gameState && gameState.state === "countdown") ? "#f59e0b" :
                               (gameState && gameState.state === "round_won") ? "#10b981" :
                               (gameState && gameState.state === "game_over") ? "#ef4444" : themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item { width: 1; height: parent.height }

            // Right Action Buttons: Mute, Full Window, New Game
            Rectangle {
                id: muteBtn
                height: parent.height
                width: 80
                color: muteMouse.containsMouse ? "#282c37" : themeCardBg
                radius: 6
                border.color: themeBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: isMuted ? "🔇 Muted" : "🔊 Sound"
                    color: isMuted ? themeSubtext : themeFg
                    font.family: monoFontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: isMuted = !isMuted
                }
            }

            Rectangle {
                id: viewBtn
                height: parent.height
                width: 90
                color: viewMouse.containsMouse ? "#282c37" : themeCardBg
                radius: 6
                border.color: themeBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Full (⇧F)"
                    color: themeFg
                    font.family: monoFontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: viewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.visibility === Window.FullScreen) root.showNormal();
                        else root.showFullScreen();
                    }
                }
            }

            Rectangle {
                id: restartBtn
                height: parent.height
                width: 106
                color: restartMouse.containsMouse ? "#9a3412" : "#c2410c"
                radius: 6
                border.color: "#ea580c"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "New Game (R)"
                    color: "#ffffff"
                    font.family: monoFontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: restartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: startNewGame(1)
                }
            }
        }

        // ---------------------------------------------------------------------
        // TIER 3: PLAYFIELD (Left Hopper Dispenser + Center 10×8 Grid + Gauge)
        // ---------------------------------------------------------------------
        Item {
            id: playfield
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right

            // 1. LEFT COLUMN: MECHANICAL HOPPER DISPENSER
            Rectangle {
                id: hopperColumn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 140
                color: themeCardBg
                radius: 8
                border.color: themeBorder
                border.width: 1.5

                // Top Hopper Funnel Header
                Rectangle {
                    id: hopperHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 38
                    color: "#181a22"
                    radius: 8

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "🔩"; font.pixelSize: 14 }
                        Text {
                            text: "NEXT FITTINGS"
                            color: themeAccent
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
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: gameState ? gameState.queue : []

                        Rectangle {
                            width: 100
                            height: Math.min(84, (hopperColumn.height - 70) / 5 - 8)
                            color: index === 0 ? "#241f17" : "#14151a"
                            radius: 6
                            border.color: index === 0 ? themeAccent : themeBorder
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
                                color: themeAccent
                                radius: 3

                                Text {
                                    anchors.centerIn: parent
                                    text: "NEXT"
                                    color: "#11111b"
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
                anchors.bottom: parent.bottom
                color: themeBoardBg
                radius: 8
                border.color: themeBorder
                border.width: 1.5
                clip: true


                // Grid Cells Matrix (10 Cols × 8 Rows)
                Item {
                    id: gridMatrix
                    anchors.fill: parent
                    anchors.margins: 10

                    readonly property real cellW: width / Engine.COLS
                    readonly property real cellH: height / Engine.ROWS

                    // Base Plates and Pipes
                    Repeater {
                        model: Engine.ROWS * Engine.COLS

                        Item {
                            readonly property int r: Math.floor(index / Engine.COLS)
                            readonly property int c: index % Engine.COLS
                            x: c * gridMatrix.cellW
                            y: r * gridMatrix.cellH
                            width: gridMatrix.cellW
                            height: gridMatrix.cellH

                            // Steel Base Plate
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "assets/plate.png"
                                fillMode: Image.Stretch
                                smooth: true
                            }

                            // Placed Pipe Fitting
                            Image {
                                id: pipeSprite
                                anchors.fill: parent
                                anchors.margins: 1
                                fillMode: Image.Stretch
                                smooth: true
                                mipmap: true
                                source: {
                                    if (gridRevision < 0 || !gameState || !gameState.grid) return "";
                                    var cell = gameState.grid[r][c];
                                    if (!cell || cell.type === "empty") return "";
                                    return "assets/" + cell.type + ".png";
                                }
                            }

                            // Interactive Mouse Click to Place Pipe
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    cursorR = r;
                                    cursorC = c;
                                }
                                onClicked: {
                                    cursorR = r;
                                    cursorC = c;
                                    if (gameState && (gameState.state === "countdown" || gameState.state === "flowing")) {
                                        if (Engine.placeNextPiece(gameState, r, c)) {
                                            playSfx("pipe_clank");
                                            gridRevision++;
                                            gridCanvas.requestPaint();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Dynamic Liquid Overlay Canvas
                    Canvas {
                        id: gridCanvas
                        anchors.fill: parent
                        renderStrategy: Canvas.Threaded

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            if (!gameState) return;

                            var cw = gridMatrix.cellW;
                            var ch = gridMatrix.cellH;

                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            for (var r = 0; r < Engine.ROWS; r++) {
                                for (var c = 0; c < Engine.COLS; c++) {
                                    var cell = gameState.grid[r][c];
                                    if (!cell || cell.type === "empty" || cell.type === "hazard") continue;
                                    if (!cell.filled && !cell.isFlowing) continue;

                                    var cx = c * cw + cw / 2;
                                    var cy = r * ch + ch / 2;
                                    var prog = cell.filled ? 1.0 : cell.fillProgress;

                                    // Water gradient
                                    ctx.strokeStyle = "#10b981"; // Vibrant emerald
                                    ctx.lineWidth = 14;

                                    if (cell.type === "pipe_h" || cell.type === "reservoir" || (cell.type === "valve" && cell.exitPort === "E")) {
                                        var x1 = (cell.entryPort === "W") ? (c * cw) : (c * cw + cw);
                                        var x2 = (cell.entryPort === "W") ? (c * cw + cw * prog) : (c * cw + cw - cw * prog);
                                        ctx.beginPath();
                                        ctx.moveTo(x1, cy);
                                        ctx.lineTo(x2, cy);
                                        ctx.stroke();

                                        // Bright Core Stream
                                        ctx.strokeStyle = "#6ee7b7";
                                        ctx.lineWidth = 6;
                                        ctx.beginPath();
                                        ctx.moveTo(x1, cy);
                                        ctx.lineTo(x2, cy);
                                        ctx.stroke();
                                    } else if (cell.type === "pipe_v") {
                                        var y1 = (cell.entryPort === "N") ? (r * ch) : (r * ch + ch);
                                        var y2 = (cell.entryPort === "N") ? (r * ch + ch * prog) : (r * ch + ch - ch * prog);
                                        ctx.beginPath();
                                        ctx.moveTo(cx, y1);
                                        ctx.lineTo(cx, y2);
                                        ctx.stroke();

                                        ctx.strokeStyle = "#6ee7b7";
                                        ctx.lineWidth = 6;
                                        ctx.beginPath();
                                        ctx.moveTo(cx, y1);
                                        ctx.lineTo(cx, y2);
                                        ctx.stroke();
                                    } else if (cell.type.indexOf("corner_") === 0) {
                                        // Corner Arc Fluid
                                        var arcX = 0, arcY = 0, startA = 0, sweepA = 0;
                                        if (cell.type === "corner_1") { // North <-> East
                                            arcX = c * cw + cw;
                                            arcY = r * ch;
                                            if (cell.entryPort === "N") {
                                                startA = Math.PI;
                                                sweepA = -Math.PI / 2;
                                            } else {
                                                startA = Math.PI / 2;
                                                sweepA = Math.PI / 2;
                                            }
                                        } else if (cell.type === "corner_2") { // North <-> West
                                            arcX = c * cw;
                                            arcY = r * ch;
                                            if (cell.entryPort === "N") {
                                                startA = 0;
                                                sweepA = Math.PI / 2;
                                            } else {
                                                startA = Math.PI / 2;
                                                sweepA = -Math.PI / 2;
                                            }
                                        } else if (cell.type === "corner_3") { // South <-> East
                                            arcX = c * cw + cw;
                                            arcY = r * ch + ch;
                                            if (cell.entryPort === "S") {
                                                startA = Math.PI;
                                                sweepA = Math.PI / 2;
                                            } else {
                                                startA = 1.5 * Math.PI;
                                                sweepA = -Math.PI / 2;
                                            }
                                        } else if (cell.type === "corner_4") { // South <-> West
                                            arcX = c * cw;
                                            arcY = r * ch + ch;
                                            if (cell.entryPort === "S") {
                                                startA = 0;
                                                sweepA = -Math.PI / 2;
                                            } else {
                                                startA = 1.5 * Math.PI;
                                                sweepA = Math.PI / 2;
                                            }
                                        }

                                        var curEndA = startA + sweepA * prog;
                                        var isAnticlockwise = sweepA < 0;

                                        ctx.strokeStyle = "#10b981";
                                        ctx.lineWidth = 14;
                                        ctx.beginPath();
                                        ctx.arc(arcX, arcY, cw / 2, startA, curEndA, isAnticlockwise);
                                        ctx.stroke();

                                        ctx.strokeStyle = "#6ee7b7";
                                        ctx.lineWidth = 6;
                                        ctx.beginPath();
                                        ctx.arc(arcX, arcY, cw / 2, startA, curEndA, isAnticlockwise);
                                        ctx.stroke();
                                    } else if (cell.type === "cross") {
                                        // Cross can be traversed horizontally or vertically
                                        var isH = (cell.entryPort === "W" || cell.entryPort === "E");
                                        if (isH) {
                                            var hx1 = (cell.entryPort === "W") ? (c * cw) : (c * cw + cw);
                                            var hx2 = (cell.entryPort === "W") ? (c * cw + cw * prog) : (c * cw + cw - cw * prog);
                                            ctx.beginPath();
                                            ctx.moveTo(hx1, cy);
                                            ctx.lineTo(hx2, cy);
                                            ctx.stroke();
                                        } else {
                                            var vy1 = (cell.entryPort === "N") ? (r * ch) : (r * ch + ch);
                                            var vy2 = (cell.entryPort === "N") ? (r * ch + ch * prog) : (r * ch + ch - ch * prog);
                                            ctx.beginPath();
                                            ctx.moveTo(cx, vy1);
                                            ctx.lineTo(cx, vy2);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Keyboard / Mouse Cursor Reticle
                    Rectangle {
                        id: cursorReticle
                        x: cursorC * gridMatrix.cellW
                        y: cursorR * gridMatrix.cellH
                        width: gridMatrix.cellW
                        height: gridMatrix.cellH
                        color: "transparent"
                        border.color: themeAccent
                        border.width: 2.5
                        radius: 4

                        // Brass Corner Accents
                        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 6; height: 6; color: themeAccent }
                        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 6; height: 6; color: themeAccent }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 6; height: 6; color: themeAccent }
                        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 6; height: 6; color: themeAccent }

                        Behavior on x { NumberAnimation { duration: 60 } }
                        Behavior on y { NumberAnimation { duration: 60 } }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // TIER 4: BOTTOM ACTION BAR (Template Standard: Quick Actions & Status)
        // ---------------------------------------------------------------------
        Row {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            spacing: 12

            // Fast-Forward Rush Pump Button
            Rectangle {
                id: rushBtn
                width: 220
                height: parent.height
                color: (gameState && gameState.isRushing) ? "#b91c1c" : (rushMouse.containsMouse ? "#ea580c" : "#c2410c")
                radius: 8
                border.color: "#f97316"
                border.width: 1.5

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "⚡"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "RUSH PUMP (SPACE)"
                        color: "#ffffff"
                        font.family: monoFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: rushMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: {
                        if (gameState) {
                            gameState.isRushing = true;
                            playSfx("rush");
                        }
                    }
                    onReleased: {
                        if (gameState) gameState.isRushing = false;
                    }
                }
            }

            // Keyboard hints
            Rectangle {
                width: parent.width - 220 - 180 - 12
                height: parent.height
                color: themeCardBg
                radius: 8
                border.color: themeBorder
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: "🎮 Move: Arrows / HJKL / WASD"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Text {
                        text: "• Place: Enter / Click"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Text {
                        text: "• Fast-Forward: Hold Space"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            // Sector / Round Badge
            Rectangle {
                width: 180
                height: parent.height
                color: themeCardBg
                radius: 8
                border.color: themeAccent
                border.width: 1.5

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text { text: "🏭"; font.pixelSize: 14 }
                    Text {
                        text: "SECTOR " + (currentLevel < 10 ? "0" + currentLevel : currentLevel)
                        color: themeAccent
                        font.family: monoFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 1
                    }
                }
            }
        }
    }

    // =========================================================================
    // STANDARD ARCADE HELP MODAL
    // =========================================================================
    Rectangle {
        id: helpModal
        visible: showHelpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: showHelpModal = false
        }

        Rectangle {
            width: Math.min(540, parent.width - 40)
            height: Math.min(480, parent.height - 40)
            anchors.centerIn: parent
            color: themeCardBg
            radius: 12
            border.color: themeAccent
            border.width: 2

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Modal Header
                Row {
                    width: parent.width
                    Text {
                        text: "HOW TO PLAY • PIPE PUNK"
                        color: themeAccent
                        font.family: monoFontFamily
                        font.pixelSize: 16
                        font.bold: true
                        font.letterSpacing: 1
                    }
                    Item { width: parent.width - 240 - 24; height: 1 }
                    Text {
                        text: "✕"
                        color: themeSubtext
                        font.pixelSize: 16
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showHelpModal = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: themeBorder }

                // Rules
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        text: "• Route the pressurized boiler water from the starting valve across the grid without letting it spill."
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: "• Connect matching pipe ends (Horizontal, Vertical, Corners, Cross, and Delay Reservoirs)."
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: "• Cross Junctions can be traversed TWICE (horizontally and vertically) for +500 bonus points!"
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: "• Meet or exceed the sector's PIPE QUOTA to qualify for the next level."
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: "• Hold SPACE to rush the pump at 5× speed when your pipeline is secure for massive score multipliers."
                        color: themeFg
                        font.family: monoFontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }

                Rectangle { width: parent.width; height: 1; color: themeBorder }

                // Controls Cheatsheet
                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "KEYBOARD CONTROLS"
                        color: themeAccent
                        font.family: monoFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Text {
                        text: "• Move Cursor: Arrows / WASD / Vim (H, J, K, L)"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        text: "• Place Pipe: Enter or Left Mouse Click"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        text: "• Rush Pump: Hold Space"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        text: "• New Game: R  |  Mute: M  |  Full Window: Shift+F"
                        color: themeSubtext
                        font.family: monoFontFamily
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 140
                    height: 36
                    color: themeAccent
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: "GOT IT"
                        color: "#11111b"
                        font.family: monoFontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showHelpModal = false
                    }
                }
            }
        }
    }

    // =========================================================================
    // STARTUP RETRO SPLASH
    // =========================================================================
    Rectangle {
        id: splashScreen
        visible: splashActive
        anchors.fill: parent
        color: "#0a0c10"
        z: 200

        MouseArea {
            anchors.fill: parent
            onClicked: splashActive = false
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "⚙️"
                font.pixelSize: 48
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "PIPE PUNK"
                color: themeAccent
                font.family: monoFontFamily
                font.pixelSize: 32
                font.bold: true
                font.letterSpacing: 4
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "OMARCHY ARCADE • SUITE NO. 38"
                color: themeSubtext
                font.family: monoFontFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Press any key to start"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.family: monoFontFamily
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Timer {
            interval: 900
            running: splashActive
            onTriggered: splashActive = false
        }
    }
}
