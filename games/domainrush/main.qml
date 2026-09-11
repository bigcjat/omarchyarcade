import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 960
    height: 720
    minimumWidth: 540
    minimumHeight: 460
    title: currentThemeName.length > 0 ? "DomainRush • " + currentThemeName : "DomainRush"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#080b12"
    property color themeBoardBg: "#0c101c"
    property color themeCardBg: "#121829"
    property color themeBorder: "#222c42"
    property color themeFg: "#f8fafc"
    property color themeSubtext: "#94a3b8"
    property color themeAccent: "#06b6d4" // Cyan default player
    property color themeGold: "#facc15"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#080b12" : "#ffffff"
    property string currentThemeName: ""

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE
    // =========================================================================
    property string gameState: "ready"
    property string endReason: ""
    property real domainPercent: 0.0
    property real bestDomainPercent: 0.0
    property int cutsCount: 0
    property int livingRivals: 4
    property real boostEnergy: 100.0
    property bool isBoosting: false
    property int elapsedSeconds: 0
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool isPaused: false
    property bool wasPausedBeforeHelp: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 580
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 580
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Move: Arrow Keys, WASD, or Vim H/J/K/L\n• Nitro Boost: Hold Space or Shift\n• Pause / Resume: P or Esc\n• Victory 1: First to reach 50% territory dominance!\n• Victory 2: Eliminate all 4 rival skimmers (last standing)!\n• Full View: Shift+F • Restart: R • Sound: M • Help: ?"

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        currentThemeName = name || "";

        var bg = data.background || data.bg || "#080b12";
        var fg = data.foreground || data.fg || "#f8fafc";
        var accent = data.accent || "#06b6d4";
        var c0 = data.color0 || "#121829";
        var c8 = data.color8 || "#222c42";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.08);
            themeCardBg = Qt.darker(bg, 1.04);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#94a3b8";
        }
        themeBtnBg = accent;
        themeBtnFg = colorLuminance(accent) > 0.5 ? "#080b12" : "#ffffff";

        gameCanvas.requestPaint();
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("select");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function togglePause() {
        if (root.gameState !== "playing") return;
        root.isPaused = !root.isPaused;
        playSound("click");
        soundToast.show(root.isPaused ? "⏸ Game Paused" : "▶ Game Resumed");
    }

    function handleInput(action) {
        Engine.handleInput(action, { onSound: root.playSound });
    }

    function openHelp() {
        root.wasPausedBeforeHelp = root.isPaused;
        root.isPaused = true;
        root.showHelp = true;
        playSound("click");
    }

    function closeHelp() {
        root.showHelp = false;
        if (!root.wasPausedBeforeHelp) {
            root.isPaused = false;
        }
        playSound("click");
    }

    function restartGame() {
        Engine.resetGame();
        gameState = "playing";
        endReason = "";
        domainPercent = 0.0;
        cutsCount = 0;
        livingRivals = 4;
        boostEnergy = 100.0;
        isBoosting = false;
        isPaused = false;
        showHelp = false;
        gameCanvas.requestPaint();
        playSound("click");
    }

    function onWin(scoreVal) {
        root.isPaused = false;
        if (scoreVal > root.bestDomainPercent) {
            root.bestDomainPercent = scoreVal;
        }
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setBestScore(Math.round(root.bestDomainPercent * 10));
        }
    }

    function onGameOver() {
        root.isPaused = false;
        // Game over handled in modal
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
            var raw = settingsManager.getBestScore();
            // Self-heal any values from previous buggy runs (e.g. 5180 or 5040 instead of 518)
            if (raw > 1000) {
                raw = Math.round(raw / 10);
            }
            if (raw > 1000) {
                raw = 1000;
            }
            root.bestDomainPercent = (raw > 0) ? (raw / 10.0) : 0.0;
            settingsManager.setBestScore(Math.round(root.bestDomainPercent * 10));
        }
        Engine.init(boardContainer.width, boardContainer.height);
    }

    property var leaderboardData: []
    property var bannerData: ({ active: false, text: "", type: "info" })
    property bool playerStarted: false

    // =========================================================================
    // 60 FPS SIMULATION TICK TIMER
    // =========================================================================
    Timer {
        id: simTimer
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            if (root.isPaused || root.showHelp) {
                return;
            }

            Engine.update(0.016, {
                onSound: root.playSound,
                onWin: root.onWin,
                onGameOver: root.onGameOver
            });

            var st = Engine.getState();
            root.gameState = st.gameState;
            root.endReason = st.endReason;
            root.domainPercent = st.playerPercent;
            root.cutsCount = st.cutsCount;
            root.livingRivals = st.livingRivalsCount;
            root.boostEnergy = st.boostEnergy;
            root.isBoosting = st.isBoosting;
            root.elapsedSeconds = st.elapsedSeconds;
            root.leaderboardData = st.leaderboard;
            root.bannerData = st.banner;
            root.playerStarted = st.playerStarted;

            if (st.peakTurf > root.bestDomainPercent) {
                root.bestDomainPercent = st.peakTurf;
                if (typeof settingsManager !== "undefined" && settingsManager) {
                    settingsManager.setBestScore(Math.round(st.peakTurf * 10));
                }
            }

            gameCanvas.requestPaint();
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
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_P) {
                    root.closeHelp();
                    event.accepted = true;
                    return;
                }
            }

            if (root.gameState === "gameover" || root.gameState === "won") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.restartGame();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_P) {
                root.togglePause();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape) {
                if (root.gameState === "playing") {
                    root.togglePause();
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
                if (root.showHelp) {
                    root.closeHelp();
                } else {
                    root.openHelp();
                }
                event.accepted = true;
                return;
            }

            if (root.isPaused) {
                return;
            }

            // Directional Steer
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.handleInput("left", { onSound: root.playSound });
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.handleInput("right", { onSound: root.playSound });
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.handleInput("up", { onSound: root.playSound });
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.handleInput("down", { onSound: root.playSound });
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Shift) {
                Engine.handleInput("boost_on", { onSound: root.playSound });
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Shift) {
                Engine.handleInput("boost_off", { onSound: root.playSound });
                event.accepted = true;
            }
        }

        // =====================================================================
        // ROW 1: HEADER (Title, Domain %, Goal 50%, Rivals, Cuts)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? 12 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? Math.max(titleCol.height, statsRow.height) : 0

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: statsRow.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 8
                    Text {
                        text: "⚡"
                        font.pixelSize: 22
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "DomainRush"
                        font.pixelSize: Math.max(20, Math.min(28, headerItem.width * 0.045))
                        font.bold: true
                        color: root.themeAccent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    text: "5-Player High-Octane Territory Combat"
                    font.pixelSize: 11
                    color: root.themeSubtext
                }
            }

            // Stat Cards Row
            Row {
                id: statsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // DOMAIN %
                Rectangle {
                    width: 76; height: 46; radius: 8
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { text: "DOMAIN"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.domainPercent.toFixed(1) + "%"; font.pixelSize: 15; font.bold: true; color: "#38bdf8"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // GOAL (50%)
                Rectangle {
                    width: 76; height: 46; radius: 8
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { text: "GOAL"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "50.0%"; font.pixelSize: 15; font.bold: true; color: root.themeGold; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // RIVALS REMAINING
                Rectangle {
                    width: 76; height: 46; radius: 8
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { text: "RIVALS"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.livingRivals + " Alive"; font.pixelSize: 14; font.bold: true; color: root.livingRivals <= 1 ? "#f43f5e" : root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // CUTS (TAIL KILLS)
                Rectangle {
                    width: 64; height: 46; radius: 8
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { text: "CUTS"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.cutsCount.toString(); font.pixelSize: 15; font.bold: true; color: "#34d399"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // BEST PEAK
                Rectangle {
                    width: 68; height: 46; radius: 8
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { text: "BEST"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.bestDomainPercent.toFixed(1) + "%"; font.pixelSize: 14; font.bold: true; color: root.themeSubtext; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: SUBHEADER ACTION BAR & NITRO BAR
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 8 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 32 : 0

            // Nitro Energy Meter on the Left
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    height: 28
                    width: 160
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Text {
                            text: "NITRO"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            height: 8
                            width: 100
                            radius: 4
                            color: "#14ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Rectangle {
                                height: parent.height
                                width: parent.width * (root.boostEnergy / 100.0)
                                radius: 4
                                color: root.boostEnergy > 20 ? "#38bdf8" : "#f43f5e"
                                Behavior on width { NumberAnimation { duration: 50 } }
                            }
                        }
                    }
                }

                Text {
                    text: "(Space / Shift)"
                    font.pixelSize: 10
                    color: root.themeSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Action Buttons on the Right
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Help Button
                Rectangle {
                    height: 28; width: 96; radius: 6
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.showHelp ? root.themeAccent : root.themeBorder; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent }
                        Text { text: "How to Play"; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                    }
                    MouseArea {
                        id: helpMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.showHelp) {
                                root.closeHelp();
                            } else {
                                root.openHelp();
                            }
                        }
                    }
                }

                // Pause Button
                Rectangle {
                    height: 28; width: 84; radius: 6
                    color: (root.isPaused && root.gameState === "playing") ? root.themeCardBg : (pauseMouse.containsMouse ? root.themeCardBg : root.themeBoardBg)
                    border.color: (root.isPaused && root.gameState === "playing") ? root.themeAccent : root.themeBorder; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: (root.isPaused && root.gameState === "playing") ? "▶" : "⏸"; font.pixelSize: 10; color: root.themeAccent }
                        Text { text: (root.isPaused && root.gameState === "playing") ? "Resume (P)" : "Pause (P)"; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                    }
                    MouseArea {
                        id: pauseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePause()
                    }
                }

                // Audio Mute
                Rectangle {
                    height: 28; width: 78; radius: 6
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                        Text { text: root.isMuted ? "Muted" : "Sound"; font.pixelSize: 10; font.bold: true; color: root.themeFg }
                    }
                    MouseArea {
                        id: muteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Restart Button
                Rectangle {
                    height: 28; width: 84; radius: 6
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeBtnFg }
                        Text { text: "Reset (R)"; font.pixelSize: 10; font.bold: true; color: root.themeBtnFg }
                    }
                    MouseArea {
                        id: restartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartGame()
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (When fullPlayfield is enabled)
        // =====================================================================
        Rectangle {
            id: floatingTiledHUD
            visible: root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 34
            radius: 8
            z: 90
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text { text: "⚡ DOMAINRUSH"; font.pixelSize: 11; font.bold: true; color: root.themeAccent }
                Text { text: "DOM: " + root.domainPercent.toFixed(1) + "%"; font.pixelSize: 11; font.bold: true; color: "#38bdf8"; font.family: root.monoFontFamily }
                Text { text: "GOAL: 50%"; font.pixelSize: 11; font.bold: true; color: root.themeGold; font.family: root.monoFontFamily }
                Text { text: root.livingRivals + " Rivals"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "🔲"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fullPlayfield = false }
                }
                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute() }
                }
                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.restartGame() }
                }
            }
        }

        // =====================================================================
        // PLAYFIELD BOARD CONTAINER & CANVAS
        // =====================================================================
        Item {
            id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12
                clip: true

                Canvas {
                    id: gameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var ctx = getContext("2d");
                        var st = Engine.getState();
                        var gw = st.gridW;
                        var gh = st.gridH;
                        var cellW = width / gw;
                        var cellH = height / gh;

                        // Camera shake
                        var shakeX = 0, shakeY = 0;
                        if (st.shakeAmount > 0) {
                            shakeX = (Math.random() - 0.5) * st.shakeAmount;
                            shakeY = (Math.random() - 0.5) * st.shakeAmount;
                        }

                        ctx.save();
                        ctx.translate(shakeX, shakeY);

                        // 1. Technical Dark Floor
                        ctx.fillStyle = root.themeBoardBg;
                        ctx.fillRect(0, 0, width, height);

                        // 2. Laser Grid Seams
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.035)";
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (var gx = 0; gx <= gw; gx += 5) {
                            ctx.moveTo(gx * cellW, 0);
                            ctx.lineTo(gx * cellW, height);
                        }
                        for (var gy = 0; gy <= gh; gy += 5) {
                            ctx.moveTo(0, gy * cellH);
                            ctx.lineTo(width, gy * cellH);
                        }
                        ctx.stroke();

                        // 3. Claimed Territories
                        var g = st.grid;
                        var fg = st.flashGrid;
                        var colors = st.colors;

                        for (var y = 0; y < gh; y++) {
                            for (var x = 0; x < gw; x++) {
                                var idx = y * gw + x;
                                var owner = g[idx];
                                if (owner > 0 && owner < colors.length) {
                                    ctx.fillStyle = colors[owner].fill;
                                    ctx.fillRect(x * cellW, y * cellH, cellW, cellH);

                                    if (fg[idx] > 0) {
                                        ctx.fillStyle = "rgba(255, 255, 255, " + (fg[idx] * 0.75) + ")";
                                        ctx.fillRect(x * cellW, y * cellH, cellW, cellH);
                                    }
                                }
                            }
                        }

                        // 4. Beveled Neon Border Edges
                        ctx.lineWidth = 2.5;
                        for (var by = 0; by < gh; by++) {
                            for (var bx = 0; bx < gw; bx++) {
                                var bidx = by * gw + bx;
                                var bowner = g[bidx];
                                if (bowner === 0) continue;

                                ctx.strokeStyle = colors[bowner].stroke;

                                if (by === 0 || g[bidx - gw] !== bowner) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx * cellW, by * cellH);
                                    ctx.lineTo((bx + 1) * cellW, by * cellH);
                                    ctx.stroke();
                                }
                                if (by === gh - 1 || g[bidx + gw] !== bowner) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx * cellW, (by + 1) * cellH);
                                    ctx.lineTo((bx + 1) * cellW, (by + 1) * cellH);
                                    ctx.stroke();
                                }
                                if (bx === 0 || g[bidx - 1] !== bowner) {
                                    ctx.beginPath();
                                    ctx.moveTo(bx * cellW, by * cellH);
                                    ctx.lineTo(bx * cellW, (by + 1) * cellH);
                                    ctx.stroke();
                                }
                                if (bx === gw - 1 || g[bidx + 1] !== bowner) {
                                    ctx.beginPath();
                                    ctx.moveTo((bx + 1) * cellW, by * cellH);
                                    ctx.lineTo((bx + 1) * cellW, (by + 1) * cellH);
                                    ctx.stroke();
                                }
                            }
                        }

                        // 5. Pulsing Energy Power Nodes
                        var nodes = st.powerNodes;
                        for (var n = 0; n < nodes.length; n++) {
                            var pn = nodes[n];
                            pn.pulse = (pn.pulse || 0) + 0.08;
                            var rad = 5 + Math.sin(pn.pulse) * 1.5;
                            var px = pn.x * cellW + cellW / 2;
                            var py = pn.y * cellH + cellH / 2;

                            ctx.fillStyle = "rgba(56, 189, 248, 0.25)";
                            ctx.beginPath();
                            ctx.arc(px, py, rad + 4, 0, Math.PI * 2);
                            ctx.fill();

                            ctx.fillStyle = "#38bdf8";
                            ctx.beginPath();
                            ctx.arc(px, py, rad, 0, Math.PI * 2);
                            ctx.fill();

                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(px, py, rad * 0.4, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // 6. Active Laser Trails
                        var ents = st.entities;
                        for (var e = 0; e < ents.length; e++) {
                            var ent = ents[e];
                            if (!ent.alive || ent.trail.length === 0) continue;

                            var col = ent.colorDef;

                            // Outer glow
                            ctx.strokeStyle = col.fill;
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            ctx.moveTo(ent.trail[0].x * cellW + cellW / 2, ent.trail[0].y * cellH + cellH / 2);
                            for (var t = 1; t < ent.trail.length; t++) {
                                ctx.lineTo(ent.trail[t].x * cellW + cellW / 2, ent.trail[t].y * cellH + cellH / 2);
                            }
                            ctx.lineTo(ent.x * cellW + cellW / 2, ent.y * cellH + cellH / 2);
                            ctx.stroke();

                            // Inner core
                            ctx.strokeStyle = col.stroke;
                            ctx.lineWidth = 2.5;
                            ctx.stroke();
                        }

                        // 7. Combat Skimmers
                        for (var s = 0; s < ents.length; s++) {
                            var skimmer = ents[s];
                            if (!skimmer.alive) continue;

                            var sx = skimmer.x * cellW + cellW / 2;
                            var sy = skimmer.y * cellH + cellH / 2;

                            ctx.save();
                            ctx.translate(sx, sy);
                            ctx.rotate(skimmer.angle);

                            // Drop shadow
                            ctx.fillStyle = "rgba(0, 0, 0, 0.45)";
                            ctx.beginPath();
                            ctx.arc(1, 3, 7, 0, Math.PI * 2);
                            ctx.fill();

                            // Thruster flame
                            if ((skimmer.id === 1 && st.isBoosting) || (skimmer.isBot && skimmer.isBoosting)) {
                                ctx.fillStyle = "#38bdf8";
                                ctx.beginPath();
                                ctx.moveTo(-6, -3);
                                ctx.lineTo(-13 - Math.random() * 5, 0);
                                ctx.lineTo(-6, 3);
                                ctx.closePath();
                                ctx.fill();
                            }

                            // Hull
                            ctx.fillStyle = skimmer.colorDef.color;
                            ctx.beginPath();
                            ctx.moveTo(7, 0);
                            ctx.lineTo(-5, -5);
                            ctx.lineTo(-2, 0);
                            ctx.lineTo(-5, 5);
                            ctx.closePath();
                            ctx.fill();

                            // Cockpit canopy
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(0, 0, 2, 0, Math.PI * 2);
                            ctx.fill();

                            ctx.restore();
                        }

                        // 8. Explosion / Confetti Particles
                        var parts = st.particles;
                        for (var p = 0; p < parts.length; p++) {
                            var part = parts[p];
                            ctx.fillStyle = part.color;
                            ctx.globalAlpha = Math.max(0, part.life);
                            ctx.fillRect(part.x * (width / 900) - part.size / 2, part.y * (height / 650) - part.size / 2, part.size, part.size);
                        }
                        ctx.globalAlpha = 1.0;

                        ctx.restore();
                    }
                }

                // =============================================================
                // OVERLAY 1: LIVE EVENT NOTIFICATION BANNER (KILL FEED)
                // =============================================================
                Rectangle {
                    id: eventBannerItem
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30
                    width: Math.min(parent.width * 0.8, bannerRow.implicitWidth + 28)
                    radius: 15
                    z: 50
                    visible: root.bannerData && root.bannerData.text && root.bannerData.text.length > 0
                    opacity: (root.bannerData && root.bannerData.active) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    color: {
                        var t = root.bannerData ? root.bannerData.type : "info";
                        if (t === "kill") return "#f01e0a14";
                        if (t === "win") return "#f0231c0a";
                        return "#eb0f172a";
                    }
                    border.color: {
                        var t = root.bannerData ? root.bannerData.type : "info";
                        if (t === "kill") return "#f43f5e";
                        if (t === "win") return "#facc15";
                        return "#38bdf8";
                    }
                    border.width: 1

                    Row {
                        id: bannerRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            id: bannerTextItem
                            text: root.bannerData ? root.bannerData.text : ""
                            font.pixelSize: 11
                            font.bold: true
                            color: {
                                var t = root.bannerData ? root.bannerData.type : "info";
                                if (t === "kill") return "#fda4af";
                                if (t === "win") return "#fef08a";
                                return "#e0f2fe";
                            }
                        }
                    }
                }

                // =============================================================
                // OVERLAY 2: LIVE RIVALS LEADERBOARD
                // =============================================================
                Rectangle {
                    id: leaderboardOverlay
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    width: 140
                    height: lbCol.height + 14
                    radius: 8
                    z: 40
                    color: "#d10a0e18"
                    border.color: "#14ffffff"
                    border.width: 1

                    Column {
                        id: lbCol
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        Text {
                            text: "RIVALS (5)"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }

                        Repeater {
                            model: root.leaderboardData
                            delegate: Row {
                                width: parent.width
                                spacing: 6
                                opacity: modelData.alive ? 1.0 : 0.45

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: modelData.color
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.strikeout: !modelData.alive
                                    color: modelData.alive ? root.themeFg : root.themeSubtext
                                    width: 55
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.turf.toFixed(1) + "%"
                                    font.pixelSize: 10
                                    font.family: root.monoFontFamily
                                    font.bold: true
                                    color: modelData.alive ? "#38bdf8" : root.themeSubtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // OVERLAY 3: STATIONARY LAUNCH PROMPT
                // =============================================================
                Rectangle {
                    id: launchPromptItem
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 65
                    width: 250
                    height: 32
                    radius: 8
                    z: 45
                    color: "#d1061b29"
                    border.color: "#38bdf8"
                    border.width: 1
                    visible: !root.playerStarted && root.gameState === "playing"

                    Text {
                        text: "TAP WASD OR ARROWS TO LAUNCH"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: "#38bdf8"
                        anchors.centerIn: parent
                    }
                }
            }
        }

        // =====================================================================
        // PAUSE OVERLAY
        // =====================================================================
        Rectangle {
            id: pauseOverlay
            anchors.fill: playArea
            color: "#cc06080e"
            visible: root.isPaused && !root.showHelp && root.gameState === "playing"
            z: 850
            radius: 12

            Rectangle {
                width: Math.min(parent.width * 0.88, 360)
                height: pauseCol.height + 40
                anchors.centerIn: parent
                color: "#101626"
                border.color: root.themeAccent
                border.width: 2
                radius: 16

                Column {
                    id: pauseCol
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 14

                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "⏸ GAME PAUSED"
                            font.pixelSize: 22
                            font.bold: true
                            color: root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Your domain is held safe while paused"
                            font.pixelSize: 11
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Stat Snapshot
                    Grid {
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 8
                        width: parent.width

                        Rectangle {
                            width: (parent.width - 10) / 2; height: 46; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "CURRENT DOMAIN"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.domainPercent.toFixed(1) + "%"; font.pixelSize: 15; font.bold: true; color: "#38bdf8"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 10) / 2; height: 46; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "RIVALS ALIVE"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.livingRivals.toString(); font.pixelSize: 15; font.bold: true; color: "#34d399"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }

                    // Resume Button
                    Rectangle {
                        width: parent.width; height: 40; radius: 10
                        color: resumeMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        Text {
                            text: "RESUME (P / ESC)"
                            font.pixelSize: 12; font.bold: true; color: root.themeBtnFg
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            id: resumeMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.togglePause()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // VICTORY MODAL OVERLAY
        // =====================================================================
        Rectangle {
            id: victoryModal
            anchors.fill: playArea
            color: "#cc06080e"
            visible: root.gameState === "won"
            z: 800
            radius: 12

            Rectangle {
                width: Math.min(parent.width * 0.9, 420)
                height: vicCol.height + 48
                anchors.centerIn: parent
                color: "#101626"
                border.color: "#38bdf8"
                border.width: 2
                radius: 16

                Column {
                    id: vicCol
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "🏆 VICTORY!"
                            font.pixelSize: 26
                            font.bold: true
                            color: root.themeGold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.endReason
                            font.pixelSize: 12
                            color: root.themeSubtext
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Stat Grid
                    Grid {
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10
                        width: parent.width

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "FINAL DOMAIN"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.domainPercent.toFixed(1) + "%"; font.pixelSize: 16; font.bold: true; color: root.themeGold; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "RIVALS SEVERED"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.cutsCount.toString(); font.pixelSize: 16; font.bold: true; color: "#34d399"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "SURVIVAL TIME"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.elapsedSeconds + "s"; font.pixelSize: 16; font.bold: true; color: "#38bdf8"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "PEAK RECORD"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.bestDomainPercent.toFixed(1) + "%"; font.pixelSize: 16; font.bold: true; color: root.themeFg; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }

                    // Play Again Button
                    Rectangle {
                        width: parent.width; height: 42; radius: 10
                        color: "#059669"
                        border.color: "#34d399"; border.width: 1
                        Text {
                            text: "PLAY AGAIN (SPACE / ENTER / R)"
                            font.pixelSize: 12; font.bold: true; color: "#ffffff"
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.restartGame()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // GAME OVER MODAL OVERLAY
        // =====================================================================
        Rectangle {
            id: gameOverModal
            anchors.fill: playArea
            color: "#cc06080e"
            visible: root.gameState === "gameover"
            z: 800
            radius: 12

            Rectangle {
                width: Math.min(parent.width * 0.9, 400)
                height: goCol.height + 48
                anchors.centerIn: parent
                color: "#14101e"
                border.color: "#f43f5e"
                border.width: 2
                radius: 16

                Column {
                    id: goCol
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "💀 SEVERED!"
                            font.pixelSize: 26
                            font.bold: true
                            color: "#f43f5e"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.endReason
                            font.pixelSize: 12
                            color: root.themeSubtext
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Stat Grid
                    Grid {
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10
                        width: parent.width

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "FINAL DOMAIN"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.domainPercent.toFixed(1) + "%"; font.pixelSize: 16; font.bold: true; color: "#38bdf8"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 12) / 2; height: 50; radius: 8
                            color: "#08ffffff"; border.color: "#14ffffff"; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { text: "RIVALS SEVERED"; font.pixelSize: 8; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: root.cutsCount.toString(); font.pixelSize: 16; font.bold: true; color: "#34d399"; font.family: root.monoFontFamily; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }

                    // Retry Button
                    Rectangle {
                        width: parent.width; height: 42; radius: 10
                        color: "#0284c7"
                        border.color: "#38bdf8"; border.width: 1
                        Text {
                            text: "TRY AGAIN (SPACE / ENTER / R)"
                            font.pixelSize: 12; font.bold: true; color: "#ffffff"
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.restartGame()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // HOW TO PLAY MODAL
        // =====================================================================
        Rectangle {
            id: helpModal
            anchors.fill: playArea
            color: "#cc06080e"
            visible: root.showHelp
            z: 900
            radius: 12

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeHelp()
            }

            Rectangle {
                width: Math.min(parent.width * 0.92, 440)
                height: Math.min(parent.height * 0.94, helpCol.height + 40)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentHeight: helpCol.height
                    clip: true

                    Column {
                        id: helpCol
                        width: parent.width
                        spacing: 12

                        Text {
                            text: "HOW TO PLAY DOMAINRUSH"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeAccent
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "You control the Cyan skimmer in the center of an arena with 4 rival bots.\n\n" +
                                  "🏆 WIN CONDITIONS (First to achieve wins instantly!):\n" +
                                  "1. First to 50% Domain: Capture half the grid to claim victory.\n" +
                                  "2. Last Skimmer Standing: Sever all 4 rivals to win.\n\n" +
                                  "⚔️ RULES OF COMBAT:\n" +
                                  "• Steer out of your home base to draw a laser trail. Returning to home territory encloses and captures all territory within your loop!\n" +
                                  "• While drawing a trail, your tail is vulnerable! Slicing an opponent's tail eliminates them and wipes their territory.\n" +
                                  "• Energy Cores: Collect pulsing blue cores for an instant 5x5 expansion shockwave and +40 Nitro boost.\n\n" +
                                  "⏸ CONTROLS:\n" +
                                  "• P or Esc: Pause / Resume game\n" +
                                  "• Shift+F: Toggle full / standard view\n" +
                                  "• Space or Shift: Nitro speed boost\n\n" +
                                  "🤖 4 RIVAL BOT PERSONAS:\n" +
                                  "• Viper (Red): The Tail Hunter - tracks and intercepts exposed enemy lines.\n" +
                                  "• Solar (Gold): The Fortifier - builds tight, safe loops rapidly toward 50%.\n" +
                                  "• Jade (Emerald): The Core Seeker - races for Energy Cores.\n" +
                                  "• Vapor (Purple): The Counter-Attacker - ambushes players leaving home."
                            font.pixelSize: 11
                            color: root.themeFg
                            lineHeight: 1.3
                        }

                        Rectangle {
                            width: 140; height: 34; radius: 8
                            color: gotItMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text {
                                text: "GOT IT"
                                font.pixelSize: 11; font.bold: true; color: root.themeBtnFg
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                id: gotItMouse
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.closeHelp()
                            }
                        }

                        // Credits / Canonical Author Attribution (Master Template Requirement)
                        Text {
                            text: "Created by Chris Thompson (@bigcjat) with Gemini"
                            font.pixelSize: 10
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.85
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SOUND NOTIFICATION TOAST
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32
            width: toastText.implicitWidth + 24
            radius: 16
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            opacity: 0
            z: 950

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
            }

            Timer {
                id: toastTimer
                interval: 1800
                onTriggered: soundToast.opacity = 0
            }

            function show(msg) {
                toastText.text = msg;
                soundToast.opacity = 1;
                toastTimer.restart();
            }

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // =====================================================================
        // RETRO ARCADE SPLASH SCREEN
        // =====================================================================
        SplashScreen {
            id: splashScreen
            anchors.fill: parent
            visible: root.splashEnabled && opacity > 0
            z: 1000
        }
    }
}
