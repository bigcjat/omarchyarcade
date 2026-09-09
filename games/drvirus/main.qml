import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 500
    height: 680
    minimumWidth: 320
    minimumHeight: 440
    title: currentThemeName.length > 0 ? "Dr. Virus • " + currentThemeName : "Dr. Virus"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: ""

    // Virus & Pill color palette mapped to active theme
    property color feverColor: themePalette.color1 || themePalette.color9 || "#f38ba8"  // Red
    property color chillColor: themePalette.color4 || themePalette.color12 || "#89b4fa" // Blue/Cyan
    property color weirdColor: themePalette.color3 || themePalette.color11 || "#f9e2af" // Yellow

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameState: "ready" // "ready", "playing", "gameover", "stageclear", "paused"
    property int score: 0
    property int bestScore: 0
    property int level: 1
    property string speed: "MED" // "LOW", "MED", "HI"
    property int virusesRemaining: 0
    property int totalVirusesThisStage: 0
    property int feverRemaining: 0
    property int chillRemaining: 0
    property int weirdRemaining: 0
    property int comboCount: 0

    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Objective: Eradicate all viruses by matching 4 or more pieces of the same color horizontally or vertically.\n\n" +
                              "• Capsule Controls:\n" +
                              "  - Move: A / D, Left / Right, or Vim H / L\n" +
                              "  - Rotate CW: W, Up, K, or X\n" +
                              "  - Rotate CCW: Z\n" +
                              "  - Soft Drop: S, Down, or Vim J\n" +
                              "  - Hard Drop: Space\n\n" +
                              "• Cascading Gravity:\n" +
                              "  When a capsule half clears, its remaining partner detaches and free-falls into spaces below, triggering multi-stage combo multipliers!\n\n" +
                              "• Shortcuts:\n" +
                              "  - Full / Compact: Shift+F\n" +
                              "  - Restart: R\n" +
                              "  - Sound: M\n" +
                              "  - Help: ? or Esc"

    // Animation states
    property var matchedCells: []
    property bool isFlashingClear: false
    property real animTick: 0.0
    property bool virusesLaughing: false

    Timer {
        id: laughTimer
        interval: 1600
        repeat: false
        onTriggered: {
            root.virusesLaughing = false;
            bottleCanvas.requestPaint();
        }
    }

    function triggerVirusLaugh() {
        virusesLaughing = true;
        laughTimer.restart();
        bottleCanvas.requestPaint();
    }

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        themePalette = data;
        isCustomTheme = true;
        currentThemeName = name || "";

        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#89b4fa";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

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
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        feverColor = data.color1 || data.color9 || "#f38ba8";
        chillColor = data.color4 || data.color12 || "#89b4fa";
        weirdColor = data.color3 || data.color11 || "#f9e2af";

        bottleCanvas.requestPaint();
        previewCanvas.requestPaint();
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("isMuted", isMuted ? "true" : "false");
        }
        if (!isMuted) playSound("rotate");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function restartGame() {
        startNewGame(1, speed);
    }

    function retryStage() {
        startNewGame(level, speed);
    }

    function captureScreenshot(filePath, shouldQuit) {
        var isSplashShot = (filePath && filePath.indexOf("screenshot_splash") !== -1);
        var targetItem = (isSplashShot && splashScreen) ? splashScreen : mainContainer;
        if (!isSplashShot && splashScreen) {
            splashScreen.visible = false;
            splashScreen.opacity = 0;
        }
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    function getPillColor(cId) {
        if (cId === 1) return feverColor;
        if (cId === 2) return chillColor;
        if (cId === 3) return weirdColor;
        return "#7f849c";
    }

    // =========================================================================
    // LIFECYCLE & ENGINE INTEGRATION
    // =========================================================================
    Component.onCompleted: {
        mainContainer.forceActiveFocus();
        if (typeof settingsManager !== "undefined" && settingsManager) {
            bestScore = settingsManager.getBestScore();
            Engine.setBestScore(bestScore);
            var savedMute = settingsManager.getValue("isMuted", "true");
            isMuted = (savedMute === "true");
            var savedSpeed = settingsManager.getValue("speed", "MED");
            if (savedSpeed === "LOW" || savedSpeed === "MED" || savedSpeed === "HI") {
                speed = savedSpeed;
            }
            var savedLevel = parseInt(settingsManager.getValue("level", "1"));
            if (!isNaN(savedLevel) && savedLevel >= 0 && savedLevel <= 20) {
                level = savedLevel;
            }
        }
        startNewGame(level, speed);
    }

    function startNewGame(lvl, spd) {
        if (lvl !== undefined) level = lvl;
        if (spd !== undefined) speed = spd;

        Engine.initGame(level, speed);
        gameState = "playing";
        matchedCells = [];
        isFlashingClear = false;
        cascadeTimer.stop();
        flashTimer.stop();

        syncFromEngine();
        gravityTimer.interval = Engine.getGravityInterval();
        gravityTimer.restart();
    }

    function nextStage() {
        Engine.nextStage();
        gameState = "playing";
        matchedCells = [];
        isFlashingClear = false;
        cascadeTimer.stop();
        flashTimer.stop();

        syncFromEngine();
        gravityTimer.interval = Engine.getGravityInterval();
        gravityTimer.restart();
    }

    function syncFromEngine() {
        var st = Engine.getState();
        score = st.score;
        if (score > bestScore) {
            bestScore = score;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(bestScore);
            }
        }
        level = st.level;
        speed = st.speed;
        virusesRemaining = st.virusesRemaining;
        totalVirusesThisStage = st.totalVirusesThisStage;
        feverRemaining = st.feverCount !== undefined ? st.feverCount : 0;
        chillRemaining = st.chillCount !== undefined ? st.chillCount : 0;
        weirdRemaining = st.weirdCount !== undefined ? st.weirdCount : 0;
        gravityTimer.interval = st.gravityInterval;

        if (st.isGameOver) {
            gameState = "gameover";
            gravityTimer.stop();
            cascadeTimer.stop();
            flashTimer.stop();
            playSound("game_over");
        } else if (st.isStageClear) {
            gameState = "stageclear";
            gravityTimer.stop();
            cascadeTimer.stop();
            flashTimer.stop();
            playSound("win");
        }

        bottleCanvas.requestPaint();
        previewCanvas.requestPaint();
    }

    function handleLockResult(res) {
        gravityTimer.stop();
        if (res.hasMatches && res.matchedCoords && res.matchedCoords.length > 0) {
            matchedCells = res.matchedCoords;
            isFlashingClear = true;
            bottleCanvas.requestPaint();
            flashTimer.restart();
        } else {
            playSound("lock");
            // Pill locked without making any matches: viruses mock and laugh at player!
            triggerVirusLaugh();
            syncFromEngine();
            if (gameState === "playing") {
                gravityTimer.restart();
            }
        }
    }

    // Downward gravity timer
    Timer {
        id: gravityTimer
        interval: 600
        repeat: true
        running: false
        onTriggered: {
            if (gameState !== "playing") return;
            var res = Engine.softDrop();
            if (res.locked) {
                handleLockResult(res);
            } else {
                bottleCanvas.requestPaint();
            }
        }
    }

    // Match 4+ flash pop timer
    Timer {
        id: flashTimer
        interval: 180
        repeat: false
        onTriggered: {
            isFlashingClear = false;
            var res = Engine.clearMatchedCells(matchedCells);
            matchedCells = [];

            if (res.virusesEliminated > 0 || res.comboCount > 1) {
                playSound(res.comboCount > 1 ? "quad_clear" : "line_clear");
            } else {
                // If only pill halves cleared but no viruses were eliminated, viruses taunt!
                triggerVirusLaugh();
                playSound("line_clear");
            }

            syncFromEngine();
            if (gameState === "playing") {
                cascadeTimer.restart();
            }
        }
    }

    // Cascade gravity step timer
    Timer {
        id: cascadeTimer
        interval: 120
        repeat: true
        running: false
        onTriggered: {
            if (gameState !== "playing") {
                cascadeTimer.stop();
                return;
            }

            var stepRes = Engine.resolveCascadeStep();
            bottleCanvas.requestPaint();

            if (stepRes.settling) return;

            if (stepRes.hasNewMatches && stepRes.matches.length > 0) {
                cascadeTimer.stop();
                matchedCells = stepRes.matches;
                isFlashingClear = true;
                flashTimer.restart();
            } else {
                cascadeTimer.stop();
                syncFromEngine();
                if (gameState === "playing") {
                    gravityTimer.restart();
                }
            }
        }
    }

    // Idle animation timer
    Timer {
        id: animTimer
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.animTick += 0.08;
            if (root.animTick > 1000) root.animTick = 0;
            bottleCanvas.requestPaint();
            if (miniFeverCanvas.visible) miniFeverCanvas.requestPaint();
            if (miniChillCanvas.visible) miniChillCanvas.requestPaint();
            if (miniWeirdCanvas.visible) miniWeirdCanvas.requestPaint();
        }
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
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.showHelp) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                    root.showHelp = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.gameState === "gameover") {
                if (event.key === Qt.Key_R) {
                    root.restartGame();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.retryStage();
                    event.accepted = true;
                    return;
                }
            } else if (root.gameState === "stageclear") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.nextStage();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.restartGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_P || event.key === Qt.Key_Escape) {
                if (root.gameState === "playing") {
                    root.gameState = "paused";
                    gravityTimer.stop();
                    cascadeTimer.stop();
                } else if (root.gameState === "paused") {
                    root.gameState = "playing";
                    gravityTimer.restart();
                }
                event.accepted = true;
                return;
            }

            // Directional & Action Inputs
            if (root.gameState === "playing") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                    if (Engine.moveLeft()) {
                        root.playSound("move");
                        bottleCanvas.requestPaint();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                    if (Engine.moveRight()) {
                        root.playSound("move");
                        bottleCanvas.requestPaint();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K || event.key === Qt.Key_X) {
                    if (Engine.rotateCW()) {
                        root.playSound("rotate");
                        bottleCanvas.requestPaint();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Z) {
                    if (Engine.rotateCCW()) {
                        root.playSound("rotate");
                        bottleCanvas.requestPaint();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                    var resS = Engine.softDrop();
                    if (resS.moved) {
                        root.score = Engine.getState().score;
                        bottleCanvas.requestPaint();
                    } else if (resS.locked) {
                        root.handleLockResult(resS);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    root.playSound("hard_drop");
                    var resH = Engine.hardDrop();
                    root.score = Engine.getState().score;
                    root.handleLockResult(resH);
                    event.accepted = true;
                }
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
                    text: "Dr. Virus"
                    font.pixelSize: Math.max(20, Math.min(28, headerItem.width * 0.070))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Classic arcade medicine puzzle for Omarchy"
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
                spacing: 6

                // SCORE Card
                Rectangle {
                    width: Math.max(54, Math.min(70, headerItem.width * 0.14))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
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
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // BEST Card
                Rectangle {
                    width: Math.max(54, Math.min(70, headerItem.width * 0.14))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
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
                            font.pixelSize: 15
                            font.bold: true
                            color: root.bestScore > 0 ? root.themeAccent : root.themeSubtext
                        }
                    }
                }

                // STAGE Card
                Rectangle {
                    width: Math.max(50, Math.min(62, headerItem.width * 0.12))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
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
                            text: "STAGE"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.level.toString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // VIRUSES Card
                Rectangle {
                    width: Math.max(50, Math.min(62, headerItem.width * 0.12))
                    height: Math.max(42, Math.min(50, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.virusesRemaining > 0 ? root.feverColor : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "VIRUSES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.feverColor
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.virusesRemaining.toString()
                            font.pixelSize: 15
                            font.bold: true
                            color: root.feverColor
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

            readonly property bool isCrowded: subheaderItem.width < 460

            // Left cluster: Help button
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

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
            }

            // Right cluster: Mute, View Mode, Restart
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

                // View Mode Pill
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

                // Restart Button
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
                        onClicked: root.restartGame()
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

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartGame()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isTiledDesktopMode ? 10 : 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 10 : 16
            anchors.rightMargin: root.isTiledDesktopMode ? 10 : 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12
                clip: true

                // Main Playfield Canvas (The Medicine Bottle)
                Canvas {
                    id: bottleCanvas
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: sidePanel.visible ? sidePanel.left : parent.right
                    anchors.rightMargin: sidePanel.visible ? 8 : 0

                    property real cs: 0 // Cell size
                    property real bottleX: 0
                    property real bottleY: 0
                    property real bottleW: 0
                    property real bottleH: 0

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var availW = width - 16;
                        var availH = height - 20;
                        cs = Math.floor(Math.min(availW / 8.0, availH / 17.5));
                        if (cs < 12) cs = 12;

                        bottleW = cs * 8.0;
                        bottleH = cs * 16.0;
                        bottleX = Math.floor((width - bottleW) * 0.5);
                        bottleY = Math.floor(height - bottleH - 8);

                        var neckH = cs * 0.9;
                        var neckW = cs * 2.4;
                        var neckX = bottleX + (bottleW - neckW) * 0.5;
                        var neckY = bottleY - neckH;

                        // 1. Draw Bottle Glass Silhouette
                        ctx.save();
                        ctx.fillStyle = Qt.rgba(root.themeCardBg.r, root.themeCardBg.g, root.themeCardBg.b, 0.55);
                        drawBottlePath(ctx, bottleX, bottleY, bottleW, bottleH, neckX, neckY, neckW, neckH, cs);
                        ctx.fill();

                        // Glass Rim Outline
                        ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.45);
                        ctx.lineWidth = 2.5;
                        drawBottlePath(ctx, bottleX, bottleY, bottleW, bottleH, neckX, neckY, neckW, neckH, cs);
                        ctx.stroke();

                        // Bottle Lip Cap
                        ctx.strokeStyle = Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.6);
                        ctx.lineWidth = 3.5;
                        ctx.beginPath();
                        ctx.moveTo(neckX - cs * 0.3, neckY);
                        ctx.lineTo(neckX + neckW + cs * 0.3, neckY);
                        ctx.stroke();

                        // Subtle inner grid lines
                        ctx.strokeStyle = Qt.rgba(root.themeBorder.r, root.themeBorder.g, root.themeBorder.b, 0.25);
                        ctx.lineWidth = 1;
                        for (var c = 1; c < 8; c++) {
                            ctx.beginPath();
                            ctx.moveTo(bottleX + c * cs, bottleY);
                            ctx.lineTo(bottleX + c * cs, bottleY + bottleH);
                            ctx.stroke();
                        }
                        for (var r = 1; r < 16; r++) {
                            ctx.beginPath();
                            ctx.moveTo(bottleX, bottleY + r * cs);
                            ctx.lineTo(bottleX + bottleW, bottleY + r * cs);
                            ctx.stroke();
                        }

                        // Specular Glass Highlight Line
                        ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.08);
                        ctx.lineWidth = 4;
                        ctx.beginPath();
                        ctx.moveTo(bottleX + cs * 0.4, bottleY + cs * 0.8);
                        ctx.lineTo(bottleX + cs * 0.4, bottleY + bottleH - cs * 0.8);
                        ctx.stroke();

                        var st = Engine.getState();
                        var grid = st.grid;

                        // 2. Draw Ghost Blocks
                        if (st.ghostBlocks && st.ghostBlocks.length > 0 && !st.isGameOver) {
                            for (var g = 0; g < st.ghostBlocks.length; g++) {
                                var gb = st.ghostBlocks[g];
                                if (gb.r >= 1 && gb.r <= 16) {
                                    var gbx = bottleX + gb.c * cs;
                                    var gby = bottleY + (gb.r - 1) * cs;
                                    drawPillSegment(ctx, gbx, gby, cs, gb.color, 'none', true);
                                }
                            }
                        }

                        // 3. Draw Locked Grid Cells (Viruses & Settled Pills)
                        for (var gr = 1; gr <= 16; gr++) {
                            for (var gc = 0; gc < 8; gc++) {
                                var cell = grid[gr][gc];
                                if (cell.type === Engine.TYPE_EMPTY) continue;

                                var cellX = bottleX + gc * cs;
                                var cellY = bottleY + (gr - 1) * cs;

                                var isMatch = false;
                                for (var mi = 0; mi < root.matchedCells.length; mi++) {
                                    if (root.matchedCells[mi].r === gr && root.matchedCells[mi].c === gc) {
                                        isMatch = true;
                                        break;
                                    }
                                }

                                if (isMatch && root.isFlashingClear) {
                                    drawMatchedPop(ctx, cellX + cs * 0.5, cellY + cs * 0.5, cs * 0.44, cell.color, cell.type === Engine.TYPE_VIRUS);
                                    continue;
                                }

                                if (cell.type === Engine.TYPE_VIRUS) {
                                    drawVirus(ctx, cellX + cs * 0.5, cellY + cs * 0.5, cs * 0.44, cell.color, gr, gc, st);
                                } else if (cell.type === Engine.TYPE_PILL) {
                                    drawPillSegment(ctx, cellX, cellY, cs, cell.color, cell.connectedDir, false);
                                }
                            }
                        }

                        // 4. Draw Active Falling Capsule
                        if (st.currentSegments && st.currentSegments.length > 0 && !st.isGameOver) {
                            for (var s = 0; s < st.currentSegments.length; s++) {
                                var seg = st.currentSegments[s];
                                var segX = bottleX + seg.c * cs;
                                var segY = bottleY + (seg.r - 1) * cs;

                                if (seg.r === 0) segY = bottleY - cs;

                                drawPillSegment(ctx, segX, segY, cs, seg.color, seg.connectedDir, false);
                            }
                        }

                        ctx.restore();
                    }

                    function drawBottlePath(ctx, bx, by, bw, bh, nx, ny, nw, nh, cs) {
                        var rad = cs * 0.6;
                        ctx.beginPath();
                        ctx.moveTo(nx, ny);
                        ctx.lineTo(nx, by);
                        ctx.quadraticCurveTo(nx, by + cs * 0.6, bx + rad, by);
                        ctx.lineTo(bx + rad, by);
                        ctx.quadraticCurveTo(bx, by, bx, by + rad);
                        ctx.lineTo(bx, by + bh - rad);
                        ctx.quadraticCurveTo(bx, by + bh, bx + rad, by + bh);
                        ctx.lineTo(bx + bw - rad, by + bh);
                        ctx.quadraticCurveTo(bx + bw, by + bh, bx + bw, by + bh - rad);
                        ctx.lineTo(bx + bw, by + rad);
                        ctx.quadraticCurveTo(bx + bw, by, bx + bw - rad, by);
                        ctx.lineTo(nx + nw, by);
                        ctx.lineTo(nx + nw, ny);
                        ctx.closePath();
                    }

                    function drawPillSegment(ctx, x, y, cs, colorId, dir, isGhost) {
                        var col = getPillColor(colorId);
                        var pad = cs * 0.08;
                        var px = x + pad;
                        var py = y + pad;
                        var pw = cs - pad * 2;
                        var ph = cs - pad * 2;
                        var r = cs * 0.42;

                        ctx.save();
                        if (isGhost) {
                            ctx.globalAlpha = 0.30;
                            ctx.strokeStyle = col;
                            ctx.lineWidth = 1.5;
                            ctx.strokeRect(px + 2, py + 2, pw - 4, ph - 4);
                            ctx.restore();
                            return;
                        }

                        ctx.fillStyle = col;
                        ctx.beginPath();

                        if (dir === 'right') {
                            ctx.moveTo(px + r, py);
                            ctx.lineTo(px + pw, py);
                            ctx.lineTo(px + pw, py + ph);
                            ctx.lineTo(px + r, py + ph);
                            ctx.quadraticCurveTo(px, py + ph, px, py + ph - r);
                            ctx.lineTo(px, py + r);
                            ctx.quadraticCurveTo(px, py, px + r, py);
                        } else if (dir === 'left') {
                            ctx.moveTo(px, py);
                            ctx.lineTo(px + pw - r, py);
                            ctx.quadraticCurveTo(px + pw, py, px + pw, py + r);
                            ctx.lineTo(px + pw, py + ph - r);
                            ctx.quadraticCurveTo(px + pw, py + ph, px + pw - r, py + ph);
                            ctx.lineTo(px, py + ph);
                            ctx.lineTo(px, py);
                        } else if (dir === 'down') {
                            ctx.moveTo(px + r, py);
                            ctx.lineTo(px + pw - r, py);
                            ctx.quadraticCurveTo(px + pw, py, px + pw, py + r);
                            ctx.lineTo(px + pw, py + ph);
                            ctx.lineTo(px, py + ph);
                            ctx.lineTo(px, py + r);
                            ctx.quadraticCurveTo(px, py, px + r, py);
                        } else if (dir === 'up') {
                            ctx.moveTo(px, py);
                            ctx.lineTo(px + pw, py);
                            ctx.lineTo(px + pw, py + ph - r);
                            ctx.quadraticCurveTo(px + pw, py + ph, px + pw - r, py + ph);
                            ctx.lineTo(px + r, py + ph);
                            ctx.quadraticCurveTo(px, py + ph, px, py + ph - r);
                            ctx.lineTo(px, py);
                        } else {
                            ctx.arc(px + pw * 0.5, py + ph * 0.5, r, 0, Math.PI * 2);
                        }
                        ctx.closePath();
                        ctx.fill();

                        // Specular glint
                        ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.40);
                        ctx.beginPath();
                        ctx.ellipse(px + pw * 0.5, py + ph * 0.32, pw * 0.28, ph * 0.14);
                        ctx.fill();

                        // Divider seam line
                        ctx.strokeStyle = Qt.rgba(0.0, 0.0, 0.0, 0.35);
                        ctx.lineWidth = 1.5;
                        if (dir === 'right') {
                            ctx.beginPath(); ctx.moveTo(px + pw, py + 2); ctx.lineTo(px + pw, py + ph - 2); ctx.stroke();
                        } else if (dir === 'left') {
                            ctx.beginPath(); ctx.moveTo(px, py + 2); ctx.lineTo(px, py + ph - 2); ctx.stroke();
                        } else if (dir === 'down') {
                            ctx.beginPath(); ctx.moveTo(px + 2, py + ph); ctx.lineTo(px + pw - 2, py + ph); ctx.stroke();
                        } else if (dir === 'up') {
                            ctx.beginPath(); ctx.moveTo(px + 2, py); ctx.lineTo(px + pw - 2, py); ctx.stroke();
                        }

                        ctx.restore();
                    }

                    function drawMatchedPop(ctx, cx, cy, rad, colorId, isVirus) {
                        ctx.save();
                        ctx.translate(cx, cy);

                        var popPulse = 1.0 + 0.25 * Math.sin(root.animTick * 22.0);
                        ctx.scale(popPulse, popPulse);

                        if (isVirus) {
                            var col = getPillColor(colorId);
                            ctx.fillStyle = col;
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 0.90, 0, Math.PI * 2);
                            ctx.fill();

                            // Shocked X X eyes before popping!
                            ctx.strokeStyle = "#ffffff";
                            ctx.lineWidth = 2.4;
                            // Left X
                            ctx.beginPath();
                            ctx.moveTo(-rad * 0.38, -rad * 0.22); ctx.lineTo(-rad * 0.16, 0);
                            ctx.moveTo(-rad * 0.16, -rad * 0.22); ctx.lineTo(-rad * 0.38, 0);
                            // Right X
                            ctx.moveTo(rad * 0.16, -rad * 0.22); ctx.lineTo(rad * 0.38, 0);
                            ctx.moveTo(rad * 0.38, -rad * 0.22); ctx.lineTo(rad * 0.16, 0);
                            ctx.stroke();

                            // Shocked open mouth
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(0, rad * 0.24, rad * 0.18, 0, Math.PI * 2);
                            ctx.fill();

                            // Starburst pop rays
                            ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.85);
                            ctx.lineWidth = 2.0;
                            for (var sp = 0; sp < 6; sp++) {
                                var sAng = sp * (Math.PI / 3.0) + root.animTick * 6.0;
                                ctx.beginPath();
                                ctx.moveTo(Math.cos(sAng) * rad * 1.05, Math.sin(sAng) * rad * 1.05);
                                ctx.lineTo(Math.cos(sAng) * rad * 1.35, Math.sin(sAng) * rad * 1.35);
                                ctx.stroke();
                            }
                        } else {
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 0.90, 0, Math.PI * 2);
                            ctx.fill();
                        }
                        ctx.restore();
                    }

                    function drawVirus(ctx, cx, cy, rad, colorId, gr, gc, st) {
                        ctx.save();

                        // 1. Gaze & Threat Environmental Analysis
                        var isThreatened = false;
                        var lookDX = 0;
                        var lookDY = 0;

                        if (st && st.currentCapsule && !st.isGameOver) {
                            var capC = st.currentCapsule.c + 0.5;
                            var capR = st.currentCapsule.r;
                            var dc = capC - (gc + 0.5);
                            var dr = capR - gr; // negative when capsule is above this virus

                            if (dr < 0) {
                                // Capsule is directly above us in the bottle! Gaze upward towards it
                                lookDY = -rad * 0.26;
                                lookDX = Math.max(-rad * 0.24, Math.min(rad * 0.24, dc * (rad * 0.14)));
                            } else if (Math.abs(dr) <= 1) {
                                lookDX = Math.max(-rad * 0.24, Math.min(rad * 0.24, dc * (rad * 0.20)));
                                lookDY = 0;
                            }

                            // Threat check:
                            // Capsule directly overhead in same or adjacent column and close (within 3 rows)
                            if (dr >= -3 && dr < 0 && Math.abs(dc) <= 1.1) {
                                isThreatened = true;
                            }

                            // Ghost block directly above:
                            if (st.ghostBlocks && st.ghostBlocks.length > 0) {
                                for (var gbi = 0; gbi < st.ghostBlocks.length; gbi++) {
                                    var gb = st.ghostBlocks[gbi];
                                    if (gb.c === gc) {
                                        if (gb.r === gr - 1) {
                                            isThreatened = true;
                                            break;
                                        } else if (gb.r < gr && (gr - gb.r) <= 2) {
                                            isThreatened = true;
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        // Laughing / Taunting State
                        var isLaughing = root.virusesLaughing || (st && st.isGameOver);

                        // Boredom Cycle (staggered per virus so they don't yawn/roll eyes all together)
                        var boredPhase = (root.animTick * 0.7 + gr * 2.8 + gc * 1.9) % 18.0;
                        var isYawning = (!isThreatened && !isLaughing && colorId === 2 && boredPhase > 12.0 && boredPhase < 16.5);
                        var isEyeRolling = (!isThreatened && !isLaughing && colorId === 1 && boredPhase > 10.0 && boredPhase < 14.5);
                        var isDaydreaming = (!isThreatened && !isLaughing && colorId === 3 && boredPhase > 9.0 && boredPhase < 13.5);

                        // Position modifications based on state:
                        var posX = cx;
                        var posY = cy;
                        var scaleX = 1.0;
                        var scaleY = 1.0;

                        if (isLaughing) {
                            // Bouncing / taunting hop
                            var hop = Math.abs(Math.sin(root.animTick * 12.0 + gc * 0.9)) * (rad * 0.38);
                            posY -= hop;
                            var squish = 1.0 + 0.12 * Math.sin(root.animTick * 12.0 + gc * 0.9);
                            scaleX = squish;
                            scaleY = 1.0 / squish;
                        } else if (isThreatened) {
                            // Shivering / cowering in terror under the falling piece!
                            var jitter = Math.sin(root.animTick * 36.0 + gr * 7.0) * 1.6;
                            posX += jitter;
                            scaleX = 1.15;
                            scaleY = 0.86;
                            posY += rad * 0.08;
                        } else {
                            // Idle breathing / sickness tremors
                            if (colorId === 1) {
                                // Fever: heavy fever chest heaving
                                var feverBreath = 1.0 + 0.07 * Math.sin(root.animTick * 2.6 + gc);
                                scaleX = feverBreath;
                                scaleY = feverBreath;
                            } else if (colorId === 2) {
                                // Chill: high frequency shivering jitter
                                var shiver = Math.sin(root.animTick * 28.0 + gr * 3.0) * 1.2;
                                posX += shiver;
                            } else if (colorId === 3) {
                                // Weird: woozy jelly wobble
                                var wobble = Math.sin(root.animTick * 3.2 + gc * 1.5) * 0.08;
                                scaleX = 1.0 + wobble;
                                scaleY = 1.0 - wobble;
                            }
                        }

                        ctx.translate(posX, posY);
                        ctx.scale(scaleX, scaleY);

                        var col = getPillColor(colorId);

                        // Draw virus by color identity:
                        if (colorId === 1) {
                            // =====================================================================
                            // 🔴 FEVER (Red Virus) - Spiky, Hot, Feverish, Furious / Panicked
                            // =====================================================================
                            
                            // Heat / steam rising from head when feverish
                            if (!isThreatened) {
                                var steamTick = root.animTick * 2.0;
                                // Steam puff 1 (left)
                                var s1y = -rad * 1.05 - (steamTick % 6) * 1.8;
                                var s1o = Math.max(0, 1.0 - (steamTick % 6) / 6.0);
                                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, s1o * 0.5);
                                ctx.lineWidth = 1.4;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.35, -rad * 0.85);
                                ctx.quadraticCurveTo(-rad * 0.50, s1y + 4, -rad * 0.30, s1y);
                                ctx.stroke();

                                // Steam puff 2 (right)
                                var s2y = -rad * 1.05 - ((steamTick + 3) % 6) * 1.8;
                                var s2o = Math.max(0, 1.0 - ((steamTick + 3) % 6) / 6.0);
                                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, s2o * 0.5);
                                ctx.beginPath();
                                ctx.moveTo(rad * 0.35, -rad * 0.85);
                                ctx.quadraticCurveTo(rad * 0.50, s2y + 4, rad * 0.30, s2y);
                                ctx.stroke();
                            }

                            // Spiky Virus Body
                            ctx.fillStyle = col;
                            ctx.beginPath();
                            for (var a = 0; a < 8; a++) {
                                var ang = a * (Math.PI / 4.0);
                                var rOut = rad * 1.10;
                                var rIn = rad * 0.76;
                                var ox = Math.cos(ang) * rOut;
                                var oy = Math.sin(ang) * rOut;
                                var ix = Math.cos(ang + Math.PI / 8.0) * rIn;
                                var iy = Math.sin(ang + Math.PI / 8.0) * rIn;
                                if (a === 0) ctx.moveTo(ox, oy);
                                else ctx.lineTo(ox, oy);
                                ctx.lineTo(ix, iy);
                            }
                            ctx.closePath();
                            ctx.fill();

                            // Flushed Fever Cheeks (hot pink spots)
                            ctx.fillStyle = Qt.rgba(1.0, 0.25, 0.45, 0.55);
                            ctx.beginPath();
                            ctx.arc(-rad * 0.42, rad * 0.12, rad * 0.16, 0, Math.PI * 2);
                            ctx.arc(rad * 0.42, rad * 0.12, rad * 0.16, 0, Math.PI * 2);
                            ctx.fill();

                            // Eyes & Expressions
                            if (isLaughing) {
                                // Laughing squint eyes: ^  ^
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 2.4;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.44, -rad * 0.05);
                                ctx.lineTo(-rad * 0.30, -rad * 0.25);
                                ctx.lineTo(-rad * 0.16, -rad * 0.05);
                                ctx.moveTo(rad * 0.16, -rad * 0.05);
                                ctx.lineTo(rad * 0.30, -rad * 0.25);
                                ctx.lineTo(rad * 0.44, -rad * 0.05);
                                ctx.stroke();

                                // Big open laughing mouth with shaking pink tongue
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.15, rad * 0.32, 0, Math.PI);
                                ctx.closePath();
                                ctx.fill();
                                // Pink tongue inside
                                ctx.fillStyle = "#f38ba8";
                                ctx.beginPath();
                                var tongueWobble = Math.sin(root.animTick * 25.0) * 1.5;
                                ctx.arc(tongueWobble, rad * 0.32, rad * 0.16, Math.PI, Math.PI * 2);
                                ctx.fill();

                            } else if (isThreatened) {
                                // Big wide panicked eyes staring straight up!
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30, -rad * 0.14, rad * 0.26, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30, -rad * 0.14, rad * 0.26, 0, Math.PI * 2);
                                ctx.fill();

                                // Tiny pinprick pupils looking UP
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30 + lookDX * 0.5, -rad * 0.24, rad * 0.07, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30 + lookDX * 0.5, -rad * 0.24, rad * 0.07, 0, Math.PI * 2);
                                ctx.fill();

                                // Blue panic sweat drop flying off top-right
                                ctx.fillStyle = "#89b4fa";
                                ctx.beginPath();
                                ctx.arc(rad * 0.65, -rad * 0.70, rad * 0.12, 0, Math.PI * 2);
                                ctx.fill();

                                // Terrified screaming open "O" mouth
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.26, rad * 0.20, 0, Math.PI * 2);
                                ctx.fill();

                            } else {
                                // Normal / Bored / Sick Fever
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.32, -rad * 0.12, rad * 0.22, 0, Math.PI * 2);
                                ctx.arc(rad * 0.32, -rad * 0.12, rad * 0.22, 0, Math.PI * 2);
                                ctx.fill();

                                // Pupil position
                                var pX = lookDX;
                                var pY = lookDY;
                                if (isEyeRolling) {
                                    // Bored eye roll
                                    pX = Math.cos(boredPhase * 3.5) * rad * 0.13;
                                    pY = Math.sin(boredPhase * 3.5) * rad * 0.13;
                                }

                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30 + pX, -rad * 0.12 + pY, rad * 0.11, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30 + pX, -rad * 0.12 + pY, rad * 0.11, 0, Math.PI * 2);
                                ctx.fill();

                                // Angry / grumpy eyebrows
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 1.8;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.50, -rad * 0.35);
                                ctx.lineTo(-rad * 0.15, -rad * 0.20);
                                ctx.moveTo(rad * 0.50, -rad * 0.35);
                                ctx.lineTo(rad * 0.15, -rad * 0.20);
                                ctx.stroke();

                                // Mouth: heavy sick panting or grimace
                                ctx.beginPath();
                                if (isEyeRolling) {
                                    // Flat bored sigh line
                                    ctx.moveTo(-rad * 0.22, rad * 0.28);
                                    ctx.lineTo(rad * 0.22, rad * 0.28);
                                } else {
                                    // Hot panting mouth
                                    ctx.arc(0, rad * 0.26, rad * 0.14, 0.1, Math.PI - 0.1);
                                }
                                ctx.stroke();
                            }

                        } else if (colorId === 2) {
                            // =====================================================================
                            // 🔵 CHILL (Blue Virus) - Shivering, Drippy Nose, Yawning, Cold
                            // =====================================================================
                            
                            // Ice crests / ears on top
                            ctx.fillStyle = col;
                            ctx.beginPath();
                            ctx.moveTo(-rad * 0.42, -rad * 0.65);
                            ctx.lineTo(-rad * 0.24, -rad * 1.10);
                            ctx.lineTo(0, -rad * 0.65);
                            ctx.lineTo(rad * 0.24, -rad * 1.10);
                            ctx.lineTo(rad * 0.42, -rad * 0.65);
                            ctx.closePath();
                            ctx.fill();

                            // Round main body
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 0.88, 0, Math.PI * 2);
                            ctx.fill();

                            // Frosty cheeks
                            ctx.fillStyle = Qt.rgba(0.7, 0.95, 1.0, 0.45);
                            ctx.beginPath();
                            ctx.arc(-rad * 0.40, rad * 0.12, rad * 0.14, 0, Math.PI * 2);
                            ctx.arc(rad * 0.40, rad * 0.12, rad * 0.14, 0, Math.PI * 2);
                            ctx.fill();

                            // Expressions
                            if (isLaughing) {
                                // Cheerful taunting laughing eyes: > <
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 2.4;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.44, -rad * 0.20);
                                ctx.lineTo(-rad * 0.24, -rad * 0.08);
                                ctx.lineTo(-rad * 0.44, rad * 0.04);
                                ctx.moveTo(rad * 0.44, -rad * 0.20);
                                ctx.lineTo(rad * 0.24, -rad * 0.08);
                                ctx.lineTo(rad * 0.44, rad * 0.04);
                                ctx.stroke();

                                // Wide open cackling mouth with tongue
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.14, rad * 0.32, 0, Math.PI);
                                ctx.closePath();
                                ctx.fill();
                                ctx.fillStyle = "#f38ba8";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.30, rad * 0.15, Math.PI, Math.PI * 2);
                                ctx.fill();

                            } else if (isThreatened) {
                                // Shocked wide eyes looking up at impending doom
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30, -rad * 0.12, rad * 0.26, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30, -rad * 0.12, rad * 0.26, 0, Math.PI * 2);
                                ctx.fill();

                                // Tiny terrified pupils gazing up
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30 + lookDX * 0.5, -rad * 0.22, rad * 0.07, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30 + lookDX * 0.5, -rad * 0.22, rad * 0.07, 0, Math.PI * 2);
                                ctx.fill();

                                // Big panic sweat drop
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.65, -rad * 0.65, rad * 0.12, 0, Math.PI * 2);
                                ctx.fill();

                                // Teeth chattering in terror
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.28, rad * 0.26);
                                ctx.lineTo(rad * 0.28, rad * 0.26);
                                ctx.stroke();

                            } else if (isYawning) {
                                // Bored Yawn! Sleepy closed arcs
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 2.0;
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30, -rad * 0.06, rad * 0.14, Math.PI, Math.PI * 2);
                                ctx.arc(rad * 0.30, -rad * 0.06, rad * 0.14, Math.PI, Math.PI * 2);
                                ctx.stroke();

                                // Big yawning mouth
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.26, rad * 0.22, 0, Math.PI * 2);
                                ctx.fill();

                                // Floating "Z"
                                ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.85);
                                ctx.font = "bold 9px " + root.monoFontFamily;
                                ctx.fillText("z", rad * 0.35, -rad * 0.75 - ((root.animTick * 3) % 8));

                            } else {
                                // Normal Chill: half-lidded cold eyes looking at pill
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30, -rad * 0.06, rad * 0.22, 0, Math.PI);
                                ctx.arc(rad * 0.30, -rad * 0.06, rad * 0.22, 0, Math.PI);
                                ctx.fill();

                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.30 + lookDX, rad * 0.02 + lookDY, rad * 0.10, 0, Math.PI * 2);
                                ctx.arc(rad * 0.30 + lookDX, rad * 0.02 + lookDY, rad * 0.10, 0, Math.PI * 2);
                                ctx.fill();

                                // Runny nose drop (cyan drip)
                                ctx.fillStyle = "#a6e3a1";
                                ctx.beginPath();
                                var dripLen = rad * 0.16 + Math.sin(root.animTick * 3.0) * (rad * 0.06);
                                ctx.arc(0, rad * 0.18 + dripLen, rad * 0.07, 0, Math.PI * 2);
                                ctx.fill();

                                // Shivering zig-zag teeth chattering mouth
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.26, rad * 0.32);
                                ctx.lineTo(-rad * 0.12, rad * 0.25);
                                ctx.lineTo(0, rad * 0.35);
                                ctx.lineTo(rad * 0.12, rad * 0.25);
                                ctx.lineTo(rad * 0.26, rad * 0.32);
                                ctx.stroke();
                            }

                        } else {
                            // =====================================================================
                            // 🟡 WEIRD (Yellow Virus) - Goofy, Jelly Wobble, Derpy Eyes, Tongue
                            // =====================================================================
                            
                            // Antenna horns with bouncy round bulbs
                            var antSway = Math.sin(root.animTick * 4.0 + gc) * (rad * 0.08);
                            ctx.fillStyle = col;
                            ctx.beginPath();
                            // Left antenna
                            ctx.arc(-rad * 0.48 + antSway, -rad * 0.74, rad * 0.18, 0, Math.PI * 2);
                            // Right antenna
                            ctx.arc(rad * 0.48 - antSway, -rad * 0.74, rad * 0.18, 0, Math.PI * 2);
                            ctx.fill();

                            // Round squishy body
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 0.86, 0, Math.PI * 2);
                            ctx.fill();

                            // Cheeks
                            ctx.fillStyle = Qt.rgba(1.0, 0.6, 0.2, 0.45);
                            ctx.beginPath();
                            ctx.arc(-rad * 0.38, rad * 0.12, rad * 0.13, 0, Math.PI * 2);
                            ctx.arc(rad * 0.38, rad * 0.12, rad * 0.13, 0, Math.PI * 2);
                            ctx.fill();

                            // Expressions
                            if (isLaughing) {
                                // Bouncing goofy laughing face: inverted happy eyes
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 2.4;
                                ctx.beginPath();
                                ctx.arc(-rad * 0.28, -rad * 0.08, rad * 0.16, Math.PI, Math.PI * 2);
                                ctx.arc(rad * 0.28, -rad * 0.08, rad * 0.16, Math.PI, Math.PI * 2);
                                ctx.stroke();

                                // Wide open cackle with tongue sticking out
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.15, rad * 0.30, 0, Math.PI);
                                ctx.closePath();
                                ctx.fill();
                                // Goofy tongue flapping out to side
                                ctx.fillStyle = "#f38ba8";
                                ctx.beginPath();
                                var tongueFlap = Math.sin(root.animTick * 20.0) * (rad * 0.10);
                                ctx.arc(rad * 0.12, rad * 0.32 + tongueFlap, rad * 0.14, 0, Math.PI * 2);
                                ctx.fill();

                            } else if (isThreatened) {
                                // Bugged-out mismatched terrified eyes
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.28, -rad * 0.14, rad * 0.28, 0, Math.PI * 2);
                                ctx.arc(rad * 0.28, -rad * 0.14, rad * 0.24, 0, Math.PI * 2);
                                ctx.fill();

                                // Disoriented pupils gazing upward in panic
                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.28 + lookDX * 0.5, -rad * 0.24, rad * 0.08, 0, Math.PI * 2);
                                ctx.arc(rad * 0.28 + lookDX * 0.5, -rad * 0.24, rad * 0.07, 0, Math.PI * 2);
                                ctx.fill();

                                // Panic droplet
                                ctx.fillStyle = "#89dceb";
                                ctx.beginPath();
                                ctx.arc(rad * 0.60, -rad * 0.60, rad * 0.11, 0, Math.PI * 2);
                                ctx.fill();

                                // Screaming squiggly mouth
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 2.0;
                                ctx.beginPath();
                                ctx.moveTo(-rad * 0.24, rad * 0.26);
                                ctx.quadraticCurveTo(-rad * 0.10, rad * 0.18, 0, rad * 0.28);
                                ctx.quadraticCurveTo(rad * 0.10, rad * 0.38, rad * 0.24, rad * 0.26);
                                ctx.stroke();

                            } else {
                                // Normal / Bored / Goofy Weird
                                ctx.fillStyle = "#ffffff";
                                ctx.beginPath();
                                // One eye slightly larger for derpiness!
                                ctx.arc(-rad * 0.28, -rad * 0.10, rad * 0.23, 0, Math.PI * 2);
                                ctx.arc(rad * 0.28, -rad * 0.10, rad * 0.20, 0, Math.PI * 2);
                                ctx.fill();

                                // Pupils: derpy offset or looking at piece
                                var p1x = lookDX;
                                var p1y = lookDY;
                                var p2x = lookDX;
                                var p2y = lookDY;
                                if (isDaydreaming) {
                                    // Cross-eyed or lazy eye!
                                    p1x = rad * 0.10;
                                    p2x = -rad * 0.10;
                                }

                                ctx.fillStyle = "#11111b";
                                ctx.beginPath();
                                ctx.arc(-rad * 0.26 + p1x, -rad * 0.08 + p1y, rad * 0.12, 0, Math.PI * 2);
                                ctx.arc(rad * 0.26 + p2x, -rad * 0.08 + p2y, rad * 0.10, 0, Math.PI * 2);
                                ctx.fill();

                                // Goofy smirk or mouth with sticking-out tongue
                                ctx.strokeStyle = "#11111b";
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.arc(0, rad * 0.14, rad * 0.28, 0.2, Math.PI - 0.2);
                                ctx.stroke();

                                // Little pink tongue sticking out
                                ctx.fillStyle = "#f38ba8";
                                ctx.beginPath();
                                ctx.arc(rad * 0.12, rad * 0.30, rad * 0.09, 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }

                        ctx.restore();
                    }
                }

                // Side Laboratory Panel (Next Pill & Virus Specimen Counters)
                Rectangle {
                    id: sidePanel
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    anchors.rightMargin: 12
                    width: 110
                    visible: !root.isTiledDesktopMode
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    radius: 10

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // NEXT Capsule Tray
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "NEXT"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 6
                                color: root.themeBoardBg
                                border.color: root.themeBorder
                                border.width: 1

                                Canvas {
                                    id: previewCanvas
                                    width: 52
                                    height: 26
                                    anchors.centerIn: parent

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        var nxt = Engine.getState().nextCapsule;
                                        if (!nxt) return;

                                        var segW = 20;
                                        var segH = 20;
                                        var startX = (width - segW * 2) * 0.5;
                                        var startY = (height - segH) * 0.5;

                                        drawPreviewHalf(ctx, startX, startY, segW, segH, nxt.color1, 'right');
                                        drawPreviewHalf(ctx, startX + segW, startY, segW, segH, nxt.color2, 'left');
                                    }

                                    function drawPreviewHalf(ctx, px, py, pw, ph, colorId, dir) {
                                        var col = getPillColor(colorId);
                                        var r = pw * 0.42;
                                        ctx.fillStyle = col;
                                        ctx.beginPath();
                                        if (dir === 'right') {
                                            ctx.moveTo(px + r, py);
                                            ctx.lineTo(px + pw, py);
                                            ctx.lineTo(px + pw, py + ph);
                                            ctx.lineTo(px + r, py + ph);
                                            ctx.quadraticCurveTo(px, py + ph, px, py + ph - r);
                                            ctx.lineTo(px, py + r);
                                            ctx.quadraticCurveTo(px, py, px + r, py);
                                        } else {
                                            ctx.moveTo(px, py);
                                            ctx.lineTo(px + pw - r, py);
                                            ctx.quadraticCurveTo(px + pw, py, px + pw, py + r);
                                            ctx.lineTo(px + pw, py + ph - r);
                                            ctx.quadraticCurveTo(px + pw, py + ph, px + pw - r, py + ph);
                                            ctx.lineTo(px, py + ph);
                                            ctx.lineTo(px, py);
                                        }
                                        ctx.closePath();
                                        ctx.fill();

                                        ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.40);
                                        ctx.beginPath();
                                        ctx.ellipse(px + pw * 0.5, py + ph * 0.32, pw * 0.28, ph * 0.14);
                                        ctx.fill();
                                    }
                                }
                            }
                        }

                        // SPECIMENS Countdown
                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "VIRUSES"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Fever
                            Row {
                                width: parent.width
                                spacing: 6
                                Canvas {
                                    id: miniFeverCanvas
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        bottleCanvas.drawVirus(ctx, 7, 7, 5.5, 1, 0, 0, null);
                                    }
                                }
                                Text {
                                    text: "Fever"
                                    font.pixelSize: 10
                                    color: root.themeFg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item { width: parent.width - 58; height: 1 }
                                Text {
                                    text: root.feverRemaining > 0 ? root.feverRemaining.toString() : "✓"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.feverRemaining > 0 ? root.feverColor : root.themeAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Chill
                            Row {
                                width: parent.width
                                spacing: 6
                                Canvas {
                                    id: miniChillCanvas
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        bottleCanvas.drawVirus(ctx, 7, 7, 5.5, 2, 0, 0, null);
                                    }
                                }
                                Text {
                                    text: "Chill"
                                    font.pixelSize: 10
                                    color: root.themeFg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item { width: parent.width - 58; height: 1 }
                                Text {
                                    text: root.chillRemaining > 0 ? root.chillRemaining.toString() : "✓"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.chillRemaining > 0 ? root.chillColor : root.themeAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Weird
                            Row {
                                width: parent.width
                                spacing: 6
                                Canvas {
                                    id: miniWeirdCanvas
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        bottleCanvas.drawVirus(ctx, 7, 7, 5.5, 3, 0, 0, null);
                                    }
                                }
                                Text {
                                    text: "Weird"
                                    font.pixelSize: 10
                                    color: root.themeFg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item { width: parent.width - 58; height: 1 }
                                Text {
                                    text: root.weirdRemaining > 0 ? root.weirdRemaining.toString() : "✓"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.weirdRemaining > 0 ? root.weirdColor : root.themeAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // SPEED SELECTION
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "SPEED"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.themeSubtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2
                                Repeater {
                                    model: ["LOW", "MED", "HI"]
                                    Rectangle {
                                        width: 28
                                        height: 20
                                        radius: 4
                                        color: root.speed === modelData ? root.themeAccent : root.themeBoardBg
                                        border.color: root.speed === modelData ? root.themeAccent : root.themeBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.bold: true
                                            font.pixelSize: 8
                                            color: root.speed === modelData ? root.themeBtnFg : root.themeSubtext
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.speed = modelData;
                                                if (typeof settingsManager !== "undefined" && settingsManager) {
                                                    settingsManager.setValue("speed", modelData);
                                                }
                                                root.startNewGame(root.level, modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Game Over, Stage Clear, Pause, Toast)
        // =====================================================================

        // Help Modal (Standardized Omarchy template modal with author credits)
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
                width: Math.min(parent.width * 0.88, 380)
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
                        font.pixelSize: 11
                        color: root.themeFg
                        lineHeight: 1.35
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

        // Game Over Overlay
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.gameState === "gameover"
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.restartGame()
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "INFECTION SPREAD"
                    color: root.feverColor
                    font.pixelSize: 26
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Stage " + root.level + " Failed • Score: " + root.score
                    color: root.themeFg
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Retry current stage
                    Rectangle {
                        width: 130
                        height: 38
                        radius: 8
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "RETRY STAGE " + root.level
                            color: root.themeFg
                            font.bold: true
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.retryStage()
                        }
                    }

                    // New game from stage 1
                    Rectangle {
                        width: 130
                        height: 38
                        radius: 8
                        color: root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "NEW GAME (ST. 1)"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.restartGame()
                        }
                    }
                }

                Text {
                    text: "Press R for New Game (Stage 1) • Space / Enter to Retry"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Stage Clear Overlay
        Rectangle {
            id: stageClearOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.gameState === "stageclear"
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextStage()
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "★ STAGE CLEARED! ★"
                    color: root.themeAccent
                    font.pixelSize: 26
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "All Viruses Eradicated! • Score: " + root.score
                    color: root.themeFg
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 140
                    height: 40
                    radius: 8
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "NEXT STAGE"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextStage()
                    }
                }

                Text {
                    text: "Or press Space / Enter"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Pause Overlay
        Rectangle {
            id: pauseOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.gameState === "paused"
            z: 850

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.gameState = "playing";
                    gravityTimer.restart();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "PAUSED"
                    font.bold: true
                    font.pixelSize: 24
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Press P or Esc to Resume"
                    font.pixelSize: 12
                    color: root.themeSubtext
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
            z: 1000

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
            }

            Behavior on opacity { NumberAnimation { duration: 150 } }

            Timer {
                id: toastTimer
                interval: 1200
                onTriggered: soundToast.opacity = 0
            }

            function show(msg) {
                toastText.text = msg;
                soundToast.opacity = 1;
                toastTimer.restart();
            }
        }
    }

    // =========================================================================
    // CANONICAL OMARCHY SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
        onDismissed: {
            mainContainer.forceActiveFocus();
        }
    }
}
