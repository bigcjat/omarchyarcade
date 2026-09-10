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

    // Screen Shake effect on blowout or rush
    property real shakeX: 0
    property real shakeY: 0

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
        cursorR = gameState.valveRow;
        cursorC = gameState.valveCol + 1;
        if (cursorC >= Engine.COLS) cursorC = Engine.COLS - 1;
        shakeX = 0;
        shakeY = 0;
        gridRevision++;
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
        gameState.traversedCount = 4;
        gameState.psi = 46.5;
        score = 850;
        gridRevision++;
        gridCanvas.requestPaint();
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
        running: gameState && gameState.state !== "game_over" && gameState.state !== "round_won" && (!splashScreen || !splashScreen.visible || splashScreen.opacity === 0)
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
                playSound("water_flow");
            }

            if (prevState === "countdown" && gameState.state === "flowing") {
                playSound("water_flow");
            }

            if (gameState.state === "game_over" && prevState !== "game_over") {
                playSound("steam_hiss");
                shakeAnim.start();
            } else if (gameState.state === "round_won" && prevState !== "round_won") {
                playSound("level_clear");
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

            // Game over / Won restart or advance
            if (gameState && (gameState.state === "game_over" || gameState.state === "round_won")) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    if (gameState.state === "round_won") root.advanceToNextLevel();
                    else root.startNewGame(1);
                    event.accepted = true;
                    return;
                }
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

            // Space to Rush Pump
            if (event.key === Qt.Key_Space) {
                if (gameState && gameState.state === "flowing") {
                    gameState.isRushing = true;
                    playSound("rush");
                    event.accepted = true;
                    return;
                }
            }

            // Enter to place pipe at cursor
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (gameState && (gameState.state === "countdown" || gameState.state === "flowing")) {
                    if (Engine.placeNextPiece(gameState, cursorR, cursorC)) {
                        playSound("pipe_clank");
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
                        model: gameState ? gameState.queue : []

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

                            // Cell Mouse Click Handler
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cursorR = r;
                                    cursorC = c;
                                    if (gameState && (gameState.state === "countdown" || gameState.state === "flowing")) {
                                        if (Engine.placeNextPiece(gameState, r, c)) {
                                            playSound("pipe_clank");
                                            gridRevision++;
                                            gridCanvas.requestPaint();
                                        }
                                    }
                                }
                                onEntered: {
                                    cursorR = r;
                                    cursorC = c;
                                }
                            }
                        }
                    }

                    // Fluid Simulation Overlay Canvas
                    Canvas {
                        id: gridCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            if (!gameState || !gameState.grid) return;

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

                                    if (cell.isCross && cell.crossFillProgress > 0) {
                                        drawCrossSecondPass(ctx, cell, cx, cy, cw, ch);
                                    }
                                }
                            }
                        }

                        function drawFluidInCell(ctx, cell, cx, cy, cw, ch) {
                            var p = cell.fillProgress;
                            var entry = cell.entryPort;
                            var exit = cell.exitPort;

                            ctx.save();
                            var grad = ctx.createLinearGradient(cx, cy, cx + cw, cy + ch);
                            grad.addColorStop(0, "#10b981");
                            grad.addColorStop(0.5, "#059669");
                            grad.addColorStop(1, "#34d399");

                            ctx.strokeStyle = grad;
                            ctx.lineWidth = cw * 0.28;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            ctx.shadowColor = "#34d399";
                            ctx.shadowBlur = 8;

                            ctx.beginPath();

                            var midX = cx + cw / 2;
                            var midY = cy + ch / 2;

                            if (cell.type === "pipe_h") {
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
                            } else if (cell.type === "corner_1") {
                                if (entry === "N") {
                                    var startA = Math.PI;
                                    var endA = Math.PI - (Math.PI / 2) * p;
                                    ctx.arc(cx + cw, cy, cw / 2, startA, endA, true);
                                } else {
                                    var startA = Math.PI / 2;
                                    var endA = Math.PI / 2 + (Math.PI / 2) * p;
                                    ctx.arc(cx + cw, cy, cw / 2, startA, endA, false);
                                }
                            } else if (cell.type === "corner_2") {
                                if (entry === "N") {
                                    var startA = 0;
                                    var endA = (Math.PI / 2) * p;
                                    ctx.arc(cx, cy, cw / 2, startA, endA, false);
                                } else {
                                    var startA = Math.PI / 2;
                                    var endA = Math.PI / 2 - (Math.PI / 2) * p;
                                    ctx.arc(cx, cy, cw / 2, startA, endA, true);
                                }
                            } else if (cell.type === "corner_3") {
                                if (entry === "S") {
                                    var startA = 0;
                                    var endA = - (Math.PI / 2) * p;
                                    ctx.arc(cx, cy + ch, cw / 2, startA, endA, true);
                                } else {
                                    var startA = - Math.PI / 2;
                                    var endA = - Math.PI / 2 + (Math.PI / 2) * p;
                                    ctx.arc(cx, cy + ch, cw / 2, startA, endA, false);
                                }
                            } else if (cell.type === "corner_4") {
                                if (entry === "S") {
                                    var startA = Math.PI;
                                    var endA = Math.PI + (Math.PI / 2) * p;
                                    ctx.arc(cx + cw, cy + ch, cw / 2, startA, endA, false);
                                } else {
                                    var startA = - Math.PI / 2;
                                    var endA = - Math.PI / 2 - (Math.PI / 2) * p;
                                    ctx.arc(cx + cw, cy + ch, cw / 2, startA, endA, true);
                                }
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
                                ctx.arc(midX, midY, (cw * 0.35) * Math.min(1.0, p * 1.5), 0, Math.PI * 2);
                            }

                            ctx.stroke();

                            // Bright flowing core stream
                            ctx.lineWidth = cw * 0.12;
                            ctx.strokeStyle = "#a7f3d0";
                            ctx.shadowBlur = 0;
                            ctx.stroke();

                            ctx.restore();
                        }

                        function drawCrossSecondPass(ctx, cell, cx, cy, cw, ch) {
                            var p = cell.crossFillProgress;
                            var entry = cell.crossEntryPort;

                            ctx.save();
                            var grad = ctx.createLinearGradient(cx, cy, cx + cw, cy + ch);
                            grad.addColorStop(0, "#06b6d4");
                            grad.addColorStop(1, "#22d3ee");

                            ctx.strokeStyle = grad;
                            ctx.lineWidth = cw * 0.28;
                            ctx.lineCap = "round";
                            ctx.shadowColor = "#22d3ee";
                            ctx.shadowBlur = 8;

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

                            ctx.lineWidth = cw * 0.12;
                            ctx.strokeStyle = "#cffafe";
                            ctx.stroke();

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
                        border.color: root.themeAccent
                        border.width: 2.5
                        radius: 4
                        z: 50

                        Behavior on x { NumberAnimation { duration: 50 } }
                        Behavior on y { NumberAnimation { duration: 50 } }

                        // Subtle corner rivets for steampunk feel
                        Rectangle { width: 4; height: 4; radius: 2; color: root.themeAccent; x: 2; y: 2 }
                        Rectangle { width: 4; height: 4; radius: 2; color: root.themeAccent; x: parent.width - 6; y: 2 }
                        Rectangle { width: 4; height: 4; radius: 2; color: root.themeAccent; x: 2; y: parent.height - 6 }
                        Rectangle { width: 4; height: 4; radius: 2; color: root.themeAccent; x: parent.width - 6; y: parent.height - 6 }
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
                                text: (gameState && gameState.isRushing) ? "RUSHING 5X!" : "RUSH PUMP (SPACE)"
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

        // Standardized Game Over / Level Clear Overlay
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: gameState && (gameState.state === "game_over" || gameState.state === "round_won")
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (gameState.state === "round_won") root.advanceToNextLevel();
                    else root.startNewGame(1);
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: gameState ? (gameState.state === "round_won" ? "SECTOR CLEARED!" : "BOILER BLOWOUT!") : ""
                    color: gameState && gameState.state === "round_won" ? "#10b981" : "#ef4444"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: gameState ? (gameState.state === "round_won" ?
                          ("Pipes Used: " + gameState.traversedCount + " / " + gameState.quota + "  •  Score: " + root.score) :
                          ("Pipes Routed: " + gameState.traversedCount + " (Required " + gameState.quota + ")  •  Final Score: " + root.score)) : ""
                    color: root.themeFg
                    font.pixelSize: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 140
                    height: 40
                    radius: 8
                    color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: gameState && gameState.state === "round_won" ? "NEXT SECTOR" : "PLAY AGAIN"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: playAgainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (gameState.state === "round_won") root.advanceToNextLevel();
                            else root.startNewGame(1);
                        }
                    }
                }

                Text {
                    text: "Or press Space / Enter / R"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
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
