import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 600
    height: 780
    minimumWidth: 320
    minimumHeight: 240
    title: "Starframe"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#05070B"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#00E5FF"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    // WCAG contrast helper ensuring buttons are always readable in light/dark themes
    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameState: "ship_select" // "ship_select", "playing", "sector_cleared", "gameover", "victory"
    property string selectedShip: "interceptor"
    property int score: 0
    property int bestScore: 0
    property int lives: 3
    property int superBombs: 2
    property int currentLevel: 1
    property string levelName: "SECTOR 1: FRONTIER PATROL"
    property real shields: 500
    property real maxShields: 500
    property real health: 500
    property real maxHealth: 500
    property real ammoMG: 0
    property real ammoPlasma: 0
    property real ammoEMP: 0
    property bool hasActiveBoss: false
    property string bossName: ""
    property real bossHealthPct: 1.0

    function selectShip(shipId) {
        root.selectedShip = shipId;
        Engine.setShipClass(shipId);
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("selectedShip", shipId);
        }
        playSound("select");
    }

    function deploySelectedShip() {
        Engine.setShipClass(root.selectedShip);
        root.restartGame();
        root.gameState = "playing";
        playSound("bomb");
        soundToast.show("🚀 " + (root.selectedShip === "valkyrie" ? "VALKYRIE DEPLOYED" : (root.selectedShip === "titan" ? "TITAN DEPLOYED" : "INTERCEPTOR DEPLOYED")));
    }

    function startNewGameFlow() {
        if (root.showHelp) {
            root.showHelp = false;
            root.pausedByHelp = false;
        }
        isPaused = false;
        Engine.setPaused(false);
        Engine.gameState = "ship_select";
        root.gameState = "ship_select";
        score = 0;
        lives = 3;
        superBombs = 2;
        currentLevel = 1;
        levelName = Engine.LEVEL_NAMES[0];
        ammoMG = 0;
        ammoPlasma = 0;
        ammoEMP = 0;
        hasActiveBoss = false;
        gameCanvas.requestPaint();
        playSound("click");
    }

    function testPowerUps() {
        Engine.dropPowerUp(-130, 40, "repair");
        Engine.dropPowerUp(-78, 40, "shield");
        Engine.dropPowerUp(-26, 40, "mg");
        Engine.dropPowerUp(26, 40, "plasma");
        Engine.dropPowerUp(78, 40, "emp");
        Engine.dropPowerUp(130, 40, "super_shield");
        if (Engine.player) {
            Engine.player.ammo = [280, 200, 350];
        }
    }

    function testEnemyCritical() {
        Engine.enemies = [];
        // Spawn 1 healthy heavy tank and 1 critical heavy tank
        Engine.spawnEnemy("tank", -80, 40, 0, 2000, 1000);
        Engine.spawnEnemy("tank", 80, 40, 0, 2000, 1000);
        if (Engine.enemies.length > 1) {
            Engine.enemies[1].health = 250; // Critical <= 18%
        }
        // Spawn 1 healthy carrier and 1 critical carrier
        Engine.spawnEnemy("carrier", -50, -40, 0, 600, 400);
        Engine.spawnEnemy("carrier", 50, -40, 0, 600, 400);
        if (Engine.enemies.length > 3) {
            Engine.enemies[3].health = 100; // Critical
        }
        gameCanvas.requestPaint();
    }

    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property bool pausedByHelp: false
    property bool isPaused: false
    property bool isTiledDesktopMode: root.height < 580 || root.width < 480
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 580 || root.width < 480
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function openHelp() {
        if (!root.showHelp) {
            if (!root.isPaused && root.gameState === "playing") {
                root.pausedByHelp = true;
                root.togglePause();
            } else {
                root.pausedByHelp = false;
            }
            root.showHelp = true;
        }
    }

    function closeHelp() {
        if (root.showHelp) {
            root.showHelp = false;
            if (root.pausedByHelp) {
                root.pausedByHelp = false;
                if (root.isPaused && root.gameState === "playing") {
                    root.togglePause();
                }
            }
        }
    }

    function toggleHelp() {
        if (root.showHelp) {
            closeHelp();
        } else {
            openHelp();
        }
    }

    property string helpText: "• Flight: Move Mouse or WASD / Arrow Keys / Vim HJKL\n• Fire: Left Click or Space (Fires all 4 gun systems simultaneously!)\n• Super Bomb: Right Click or B\n• Full Playfield: Shift+F or ⛶ button\n• Pause: P or Esc\n• Kamikaze Ramming: Ram smaller enemies to vaporize them with kinetic shields!\n• Super Shield 200%: Collecting gold star capsules overcharges shields to 1000 HP for unstoppable battering ram speed!\n• Zero-Pass Penalty: Enemies escaping past the bottom border cost 1 Life!\n• 6 Drifting Power-Ups: Machine Gun [MG - Gold], Plasma [PL - Green], EMP [EMP - Purple], Hull Repair [HULL - Red (+)], Shield Recharge [SHIELDS - Cyan (○)], and 200% Super Shield [SUP - Yellow (✱)]!\n• New Game: R • Mute: M • Help: ? or Esc"

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;

        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#00E5FF";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBorder = c8 || Qt.darker(bg, 1.15);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.45);
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;

        Engine.themeAccent = themeAccent.toString();
        Engine.themeBg = themeBoardBg.toString();
        Engine.themeFg = themeFg.toString();

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
        if (gameState === "gameover" || gameState === "victory" || gameState === "sector_cleared") return;
        isPaused = !isPaused;
        Engine.setPaused(isPaused);
        soundToast.show(isPaused ? "⏸️ Game Paused" : "▶️ Game Resumed");
        gameCanvas.requestPaint();
    }

    function restartGame() {
        isPaused = false;
        Engine.setPaused(false);
        Engine.setShipClass(root.selectedShip);
        Engine.resetGame();
        gameState = "playing";
        score = 0;
        lives = 3;
        superBombs = 2;
        currentLevel = 1;
        levelName = Engine.LEVEL_NAMES[0];
        shields = Engine.player ? Engine.player.shields : 500;
        maxShields = Engine.player ? Engine.player.maxShields : 500;
        health = Engine.player ? Engine.player.health : 500;
        maxHealth = Engine.player ? Engine.player.maxHealth : 500;
        ammoMG = 0;
        ammoPlasma = 0;
        ammoEMP = 0;
        hasActiveBoss = false;
        gameCanvas.requestPaint();
        playSound("click");
    }

    function saveHighScore() {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setBestScore(root.bestScore);
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
            root.bestScore = settingsManager.getBestScore();
            var savedShip = settingsManager.getValue("selectedShip", "interceptor");
            if (savedShip === "interceptor" || savedShip === "valkyrie" || savedShip === "titan") {
                root.selectedShip = savedShip;
            }
        }
        Engine.setShipClass(root.selectedShip);
        Engine.init(boardContainer.width, boardContainer.height, root.themeAccent.toString());
        mainContainer.forceActiveFocus();
    }

    // =========================================================================
    // 60 FPS ENGINE TICKER & STATE SYNCHRONIZATION
    // =========================================================================
    Timer {
        id: gameLoopTimer
        interval: 16
        repeat: true
        running: (!splashScreen.visible || splashScreen.opacity === 0)
        onTriggered: {
            Engine.update(0.016, {
                onSound: function(snd) { root.playSound(snd); }
            });

            root.score = Engine.score;
            root.lives = Engine.lives;
            root.superBombs = Engine.superBombs;
            root.currentLevel = Engine.currentLevel;
            root.levelName = Engine.LEVEL_NAMES[Engine.currentLevel - 1] || "";
            root.gameState = Engine.gameState;

            if (Engine.player) {
                root.shields = Engine.player.shields;
                root.maxShields = Engine.player.maxShields || 500;
                root.health = Engine.player.health;
                root.maxHealth = Engine.player.maxHealth || 500;
                root.ammoMG = Engine.player.ammo[0];
                root.ammoPlasma = Engine.player.ammo[1];
                root.ammoEMP = Engine.player.ammo[2];
            }

            if (Engine.activeBoss) {
                root.hasActiveBoss = true;
                root.bossName = Engine.activeBoss.name;
                root.bossHealthPct = Math.max(0, Engine.activeBoss.health / Engine.activeBoss.maxHealth);
            } else {
                root.hasActiveBoss = false;
            }

            if (Engine.triggerDamageBlink) {
                damageBlinkAnim.restart();
            }
            if (Engine.triggerElectricFlash) {
                electricFlashAnim.restart();
            }

            if (root.score > root.bestScore) {
                root.bestScore = root.score;
                root.saveHighScore();
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
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.closeHelp();
                    event.accepted = true;
                    return;
                }
                event.accepted = true;
                return;
            }

            // Ship Selection / Hangar Navigation
            if (root.gameState === "ship_select") {
                if (event.key === Qt.Key_1) {
                    root.selectShip("interceptor");
                    root.deploySelectedShip();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_2) {
                    root.selectShip("valkyrie");
                    root.deploySelectedShip();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_3) {
                    root.selectShip("titan");
                    root.deploySelectedShip();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                    if (root.selectedShip === "titan") root.selectShip("valkyrie");
                    else if (root.selectedShip === "valkyrie") root.selectShip("interceptor");
                    else root.selectShip("titan");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                    if (root.selectedShip === "interceptor") root.selectShip("valkyrie");
                    else if (root.selectedShip === "valkyrie") root.selectShip("titan");
                    else root.selectShip("interceptor");
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.deploySelectedShip();
                    event.accepted = true;
                    return;
                }
            }

            if (root.gameState === "gameover" || root.gameState === "victory") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.startNewGameFlow();
                    event.accepted = true;
                    return;
                }
            }

            if (root.gameState === "sector_cleared") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    Engine.advanceNextLevel();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_P || (event.key === Qt.Key_Escape && !root.showHelp)) {
                root.togglePause();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window Playfield" : "🔲 Auto-Tiling View");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.startNewGameFlow();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.toggleHelp();
                event.accepted = true;
                return;
            }

            // Directional & Action Inputs
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
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Engine.setFiring(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                Engine.triggerSuperBomb({ onSound: root.playSound });
                event.accepted = true;
            }
        }

        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Engine.setFiring(false);
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
                    text: "Starframe"
                    font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.gameState === "ship_select" ? "TACTICAL HANGAR • CHOOSE FIGHTER" : root.levelName) + " • Bombs: " + root.superBombs + " • Shields: " + Math.max(0, Math.round((root.shields / root.maxShields) * 100)) + "%"
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
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
                            font.pixelSize: Math.max(12, Math.min(18, parent.width * 0.28))
                            font.bold: true
                            font.family: root.monoFontFamily
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
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bestScore.toString()
                            font.pixelSize: Math.max(12, Math.min(18, parent.width * 0.28))
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeFg
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 2 (Action Bar / Subheader)
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 12 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 32 : 0

            property bool isCrowded: width < 480

            // Left cluster ("How to Play" + "Full Field" Toggle)
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

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
                        onClicked: root.toggleHelp()
                    }
                }

                // Full Playfield View Toggle Button
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: viewModeMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: viewModeRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: root.fullPlayfield ? "🔲" : "⛶"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.fullPlayfield ? "Windowed (⇧F)" : "Full Field (⇧F)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeFg
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
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window Playfield" : "🔲 Standard Windowed View");
                        }
                    }
                }
            }

            // Right cluster (Actions: Mute, Restart)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Pause Button
                Rectangle {
                    id: pauseBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (pauseRow.implicitWidth + 18)
                    radius: 8
                    color: pauseMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isPaused ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        id: pauseRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isPaused ? "▶️" : "⏸️"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isPaused ? "Resume (P)" : "Pause (P)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isPaused ? root.themeAccent : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: pauseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePause()
                    }
                }

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

                // Primary Action Button (New Game)
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
                        onClicked: root.startNewGameFlow()
                    }
                }
            }
        }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (Active in 1/2 screen splits & full mode)
        // =====================================================================
        Rectangle {
            id: floatingTiledHUD
            visible: root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            z: 200
            color: "#d905070b"
            border.color: root.themeBorder
            border.width: 1

            property bool isNarrow: width < 720

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Title & Sector
                Text {
                    text: "STARFRAME"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: root.themeBorder
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Lives & Bombs
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "❤️ " + root.lives
                        font.pixelSize: 11
                        font.bold: true
                        color: "#FF3366"
                    }

                    Text {
                        text: "💣 " + root.superBombs
                        font.pixelSize: 11
                        font.bold: true
                        color: "#FFFF00"
                    }

                    Text {
                        text: "S" + root.currentLevel
                        font.pixelSize: 10
                        font.bold: true
                        color: root.themeSubtext
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: root.themeBorder
                    anchors.verticalCenter: parent.verticalCenter
                    visible: floatingTiledHUD.width > 440
                }

                // Hull, Shields & Ammos
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: floatingTiledHUD.width > 440

                    // Shields (Electric Cyan #00E5FF / Super Shield #FFFF00)
                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "SH"; font.pixelSize: 8; font.bold: true; color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF" }
                        Rectangle {
                            width: 36; height: 6; radius: 2; color: root.shields > root.maxShields ? "#333300" : "#00242B"; border.color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF"; border.width: 1
                            Rectangle { width: parent.width * Math.min(1.0, root.shields / root.maxShields); height: parent.height; color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF" }
                        }
                    }

                    // Hull (Crimson Red #FF3366)
                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        property bool isCrit: root.shields <= 50 && root.health <= (root.maxHealth * 0.44)
                        Text { text: "HULL"; font.pixelSize: 8; font.bold: true; color: parent.isCrit ? "#FF0033" : "#FF3366" }
                        Rectangle {
                            width: 36; height: 6; radius: 2
                            color: parent.isCrit ? "#330008" : "#2B000C"
                            border.color: parent.isCrit ? "#FF0033" : "#FF3366"
                            border.width: 1
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1.0, root.health / root.maxHealth))
                                height: parent.height
                                color: parent.parent.isCrit ? "#FF0033" : "#FF3366"
                            }
                        }
                    }

                    // Mini Ammo Indicators (MG: Gold, PL: Green, EMP: Purple)
                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: floatingTiledHUD.width > 560

                        // MG
                        Rectangle {
                            width: 16; height: 5; radius: 1; color: "#2B1F00"; border.color: "#FFB800"; border.width: 1
                            Rectangle { width: parent.width * Math.min(1.0, root.ammoMG / 500); height: parent.height; color: "#FFB800" }
                        }
                        // PL
                        Rectangle {
                            width: 16; height: 5; radius: 1; color: "#002B11"; border.color: "#00FF66"; border.width: 1
                            Rectangle { width: parent.width * Math.min(1.0, root.ammoPlasma / 500); height: parent.height; color: "#00FF66" }
                        }
                        // EMP
                        Rectangle {
                            width: 16; height: 5; radius: 1; color: "#1F002B"; border.color: "#B84DFF"; border.width: 1
                            Rectangle { width: parent.width * Math.min(1.0, root.ammoEMP / 500); height: parent.height; color: "#B84DFF" }
                        }
                    }
                }
            }

            // Right cluster: Scores + Action Buttons
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Score
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "SCORE"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext }
                    Text { text: root.score.toString(); font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily; color: root.themeFg }
                }

                // Best Score
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: floatingTiledHUD.width > 560
                    Text { text: "BEST"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext }
                    Text { text: root.bestScore.toString(); font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily; color: root.themeSubtext }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: root.themeBorder
                    anchors.verticalCenter: parent.verticalCenter
                }

                // View Toggle (Windowed / Full)
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: fullTiledMouse.containsMouse ? root.themeCardBg : "transparent"
                    border.color: root.fullPlayfield ? root.themeAccent : root.themeBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: root.fullPlayfield ? "🔲" : "⛶"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        id: fullTiledMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.fullPlayfield = !root.fullPlayfield;
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window Playfield" : "🔲 Auto-Tiling View");
                        }
                    }
                }

                // Pause
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: pauseTiledMouse.containsMouse ? root.themeCardBg : "transparent"
                    border.color: root.isPaused ? root.themeAccent : root.themeBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: root.isPaused ? "▶️" : "⏸️"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        id: pauseTiledMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePause()
                    }
                }

                // Mute
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: muteTiledMouse.containsMouse ? root.themeCardBg : "transparent"
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        id: muteTiledMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // How to Play
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: helpTiledMouse.containsMouse ? root.themeCardBg : "transparent"
                    border.color: root.showHelp ? root.themeAccent : root.themeBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "?"; font.pixelSize: 12; font.bold: true; color: root.showHelp ? root.themeAccent : root.themeFg; anchors.centerIn: parent }
                    MouseArea {
                        id: helpTiledMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleHelp()
                    }
                }

                // New Game
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: restartTiledMouse.containsMouse ? root.themeCardBg : "transparent"
                    border.color: root.themeBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🔄"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        id: restartTiledMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGameFlow()
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
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.rightMargin: root.isTiledDesktopMode ? 0 : 16

            Rectangle {
                id: boardContainer
                anchors.fill: parent
                color: root.themeBoardBg
                border.color: root.isTiledDesktopMode ? "transparent" : root.themeBorder
                border.width: root.isTiledDesktopMode ? 0 : 1
                radius: root.isTiledDesktopMode ? 0 : 12
                clip: true

                // Vector Wireframe 60 FPS Canvas (Cooperative scene graph rendering)
                Canvas {
                    id: gameCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Cooperative

                    onWidthChanged: Engine.resize(width, height)
                    onHeightChanged: Engine.resize(width, height)

                    onPaint: {
                        var ctx = getContext("2d");
                        Engine.render(ctx);
                    }
                }

                // Mouse Flight & Combat Controls
                MouseArea {
                    id: flightMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.CrossCursor

                    onPositionChanged: function(mouse) {
                        Engine.setMouseTarget(mouse.x, mouse.y, boardContainer.width, boardContainer.height);
                    }

                    onPressed: function(mouse) {
                        mainContainer.forceActiveFocus();
                        if (root.gameState === "gameover" || root.gameState === "victory") {
                            root.startNewGameFlow();
                            return;
                        }
                        if (root.gameState === "sector_cleared") {
                            Engine.advanceNextLevel();
                            return;
                        }
                        if (mouse.button === Qt.LeftButton) {
                            Engine.setFiring(true);
                        } else if (mouse.button === Qt.RightButton) {
                            Engine.triggerSuperBomb({ onSound: root.playSound });
                        }
                    }

                    onReleased: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            Engine.setFiring(false);
                        }
                    }
                }

                // =============================================================
                // SCREEN-EDGE COMBAT EFFECTS (Damage Vignette & Electric Arcs)
                // =============================================================
                // Red Damage Vignette Border
                Rectangle {
                    id: damageVignette
                    anchors.fill: parent
                    border.color: "#FF2244"
                    border.width: 4
                    color: "transparent"
                    opacity: 0
                    z: 50

                    SequentialAnimation {
                        id: damageBlinkAnim
                        NumberAnimation { target: damageVignette; property: "opacity"; from: 0.85; to: 0; duration: 220 }
                    }
                }

                // Electric Side Pick-Up Arcs
                Item {
                    id: electricSideFlash
                    anchors.fill: parent
                    opacity: 0
                    z: 51

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 5
                        color: "#00E5FF"
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 5
                        color: "#00E5FF"
                    }

                    SequentialAnimation {
                        id: electricFlashAnim
                        NumberAnimation { target: electricSideFlash; property: "opacity"; from: 1.0; to: 0; duration: 300 }
                    }
                }

                // =============================================================
                // IN-PLAYFIELD VECTOR HUD BAR (Top of playfield)
                // =============================================================
                Rectangle {
                    id: playfieldHud
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 40
                    color: Qt.rgba(Qt.color(root.themeBoardBg).r, Qt.color(root.themeBoardBg).g, Qt.color(root.themeBoardBg).b, 0.85)
                    border.color: Qt.rgba(Qt.color(root.themeBorder).r, Qt.color(root.themeBorder).g, Qt.color(root.themeBorder).b, 0.6)
                    border.width: 1
                    z: 60

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        // Left cluster: Shields, Hull & Ammo Gauges
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            // Shields Gauge (Electric Cyan #00E5FF / Super Shield #FFFF00)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: root.shields > root.maxShields ? "SUPER SHIELD" : "SHIELDS"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 52
                                    height: 7
                                    radius: 3
                                    color: root.shields > root.maxShields ? "#333300" : "#00242B"
                                    border.color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF"
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1.0, root.shields / root.maxShields))
                                        height: parent.height
                                        color: root.shields > root.maxShields ? "#FFFF00" : "#00E5FF"
                                    }
                                }
                            }

                            // Hull Gauge (Coral Crimson #FF3366, Pulses Red on Critical Danger)
                            Row {
                                id: hullRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                property bool isHullCritical: root.shields <= 50 && root.health <= (root.maxHealth * 0.44)

                                Text {
                                    text: "HULL"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: hullRow.isHullCritical ? "#FF0033" : "#FF3366"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 44
                                    height: 7
                                    radius: 3
                                    color: hullRow.isHullCritical ? "#330008" : "#2B000C"
                                    border.color: hullRow.isHullCritical ? "#FF0033" : "#FF3366"
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1.0, root.health / root.maxHealth))
                                        height: parent.height
                                        color: hullRow.isHullCritical ? "#FF0033" : "#FF3366"
                                    }
                                }

                                Text {
                                    id: critText
                                    visible: hullRow.isHullCritical
                                    text: "CRIT!"
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: "#FF0033"
                                    anchors.verticalCenter: parent.verticalCenter

                                    SequentialAnimation on opacity {
                                        running: critText.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.15; duration: 220 }
                                        NumberAnimation { from: 0.15; to: 1.0; duration: 220 }
                                    }
                                }
                            }

                            // 3-Ammo Gauges (MG: Gold #FFB800, Plasma: Green #00FF66, EMP: Violet #B84DFF)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // MG (Solar Gold #FFB800)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "MG"; font.pixelSize: 8; font.bold: true; color: "#FFB800" }
                                    Rectangle {
                                        width: 24; height: 6; radius: 2; color: "#2B1F00"; border.color: "#FFB800"; border.width: 1
                                        Rectangle { width: parent.width * Math.min(1.0, root.ammoMG / 500); height: parent.height; color: "#FFB800" }
                                    }
                                }

                                // Plasma (Neon Acid Green #00FF66)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "PL"; font.pixelSize: 8; font.bold: true; color: "#00FF66" }
                                    Rectangle {
                                        width: 24; height: 6; radius: 2; color: "#002B11"; border.color: "#00FF66"; border.width: 1
                                        Rectangle { width: parent.width * Math.min(1.0, root.ammoPlasma / 500); height: parent.height; color: "#00FF66" }
                                    }
                                }

                                // EMP (Electric Violet #B84DFF)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "EMP"; font.pixelSize: 8; font.bold: true; color: "#B84DFF" }
                                    Rectangle {
                                        width: 24; height: 6; radius: 2; color: "#1F002B"; border.color: "#B84DFF"; border.width: 1
                                        Rectangle { width: parent.width * Math.min(1.0, root.ammoEMP / 500); height: parent.height; color: "#B84DFF" }
                                    }
                                }
                            }
                        }

                        // Right cluster: Lives & Bombs indicators
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: "⚡ " + root.superBombs
                                font.pixelSize: 10
                                font.bold: true
                                color: "#FFCC00"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "🚀 " + root.lives
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // =============================================================
                // BOSS HEALTH BAR (Appears during Boss Encounters)
                // =============================================================
                Rectangle {
                    id: bossBar
                    anchors.top: playfieldHud.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    visible: root.hasActiveBoss
                    color: Qt.rgba(0.12, 0.02, 0.04, 0.9)
                    border.color: "#FF0055"
                    border.width: 1
                    z: 60

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        width: parent.width - 24

                        Text {
                            text: "⚠️ " + root.bossName
                            font.pixelSize: 10
                            font.bold: true
                            color: "#FF3366"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            height: 8
                            width: parent.width - 150
                            radius: 4
                            color: "#330011"
                            border.color: "#FF0055"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Rectangle {
                                width: parent.width * root.bossHealthPct
                                height: parent.height
                                color: "#FF0055"
                            }
                        }

                        Text {
                            text: Math.round(root.bossHealthPct * 100) + "%"
                            font.pixelSize: 9
                            font.bold: true
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Ship Select, Sector Cleared, Victory, Pause, Game Over, Help)
        // =====================================================================
        // 0. Tactical Hangar / Ship Selection Overlay
        Rectangle {
            id: shipSelectOverlay
            anchors.fill: playArea
            radius: boardContainer.radius
            color: "#f205070b"
            border.color: root.themeBorder
            border.width: root.isTiledDesktopMode ? 0 : 1
            visible: root.gameState === "ship_select"
            z: 970
            clip: true

            property real previewYaw: 0
            Timer {
                interval: 33
                repeat: true
                running: shipSelectOverlay.visible
                onTriggered: {
                    shipSelectOverlay.previewYaw = Math.sin(Date.now() * 0.0025) * 0.15;
                }
            }

            // Main Layout Container
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 600)
                spacing: parent.height < 540 ? 8 : 14

                // Header & Tactical Squadron Briefing
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 20
                        width: tagText.implicitWidth + 16
                        radius: 10
                        color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.15)
                        border.color: root.themeAccent
                        border.width: 1

                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: "TACTICAL HANGAR • CHOOSE YOUR FIGHTER"
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeAccent
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SELECT COMBAT CRAFT"
                        font.pixelSize: Math.max(16, Math.min(22, parent.parent.width * 0.048))
                        font.bold: true
                        color: root.themeFg
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Choose 1 of 3 specialized fighters • Press [1], [2], [3] or [← / →]"
                        font.pixelSize: 11
                        color: root.themeSubtext
                    }
                }

                // Cards Scrollable / Centered Container
                Flickable {
                    id: cardsFlickable
                    width: parent.width
                    height: Math.min(320, Math.max(220, shipSelectOverlay.height - 148))
                    contentWidth: cardsRow.implicitWidth
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: cardsRow
                        x: Math.max(0, (cardsFlickable.width - implicitWidth) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Repeater {
                            model: [
                                {
                                    shipId: "interceptor",
                                    badge: "MK-I BALANCED",
                                    name: "INTERCEPTOR",
                                    role: "BALANCED FIGHTER",
                                    speedPct: 0.70,
                                    armorPct: 0.65,
                                    firepowerPct: 0.70,
                                    hpText: "HP: 500 • SHIELD: 500",
                                    desc: "Twin blasters with balanced kinetic agility & shield harmonics."
                                },
                                {
                                    shipId: "valkyrie",
                                    badge: "MK-II STRIKER",
                                    name: "VALKYRIE",
                                    role: "HIGH-SPEED STRIKER",
                                    speedPct: 0.95,
                                    armorPct: 0.45,
                                    firepowerPct: 0.80,
                                    hpText: "HP: 380 • SHIELD: 400",
                                    desc: "+25% thruster velocity & rapid-cadence needle blasters."
                                },
                                {
                                    shipId: "titan",
                                    badge: "MK-III DREADNOUGHT",
                                    name: "TITAN",
                                    role: "SIEGE DREADNOUGHT",
                                    speedPct: 0.50,
                                    armorPct: 0.95,
                                    firepowerPct: 0.92,
                                    hpText: "HP: 650 • SHIELD: 650",
                                    desc: "Heavy 180t kinetic ramming mass & dual outboard siege cannons."
                                }
                            ]

                            delegate: Rectangle {
                                id: cardRoot
                                width: Math.max(140, Math.min(176, (cardsFlickable.width - 32) / 3))
                                height: cardsFlickable.height
                                radius: 10
                                property bool isSelected: root.selectedShip === modelData.shipId

                                color: isSelected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.12) : (cardMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.08) : root.themeCardBg)
                                border.color: isSelected ? root.themeAccent : (cardMouse.containsMouse ? Qt.lighter(root.themeBorder, 1.2) : root.themeBorder)
                                border.width: isSelected ? 2 : 1
                                clip: true

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectShip(modelData.shipId);
                                        root.deploySelectedShip();
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 5

                                    // Badge
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 16
                                        width: badgeText.implicitWidth + 10
                                        radius: 4
                                        color: cardRoot.isSelected ? root.themeAccent : root.themeBorder
                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: modelData.badge
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: root.monoFontFamily
                                            color: cardRoot.isSelected ? root.themeBtnFg : root.themeSubtext
                                        }
                                    }

                                    // Live Vector Wireframe Preview Canvas
                                    Canvas {
                                        id: previewCanvas
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(130, parent.width)
                                        height: Math.min(78, Math.max(50, cardRoot.height * 0.28))
                                        renderTarget: Canvas.FramebufferObject
                                        renderStrategy: Canvas.Cooperative

                                        Connections {
                                            target: shipSelectOverlay
                                            function onPreviewYawChanged() {
                                                previewCanvas.requestPaint();
                                            }
                                        }

                                        Connections {
                                            target: root
                                            function onSelectedShipChanged() {
                                                previewCanvas.requestPaint();
                                            }
                                        }

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var isSel = root.selectedShip === modelData.shipId;
                                            var shipCol = isSel ? root.themeAccent.toString() : root.themeSubtext.toString();
                                            Engine.drawShipPreview(ctx, modelData.shipId, width / 2, height / 2 + 4, 1.25, shipSelectOverlay.previewYaw, shipCol);
                                        }
                                    }

                                    // Name
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: cardRoot.isSelected ? root.themeAccent : root.themeFg
                                    }

                                    // Role
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.role
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: root.monoFontFamily
                                        color: root.themeSubtext
                                    }

                                    // Stat Bars (Speed, Armor, Firepower)
                                    Column {
                                        width: parent.width
                                        spacing: 3

                                        // Speed
                                        Row {
                                            width: parent.width
                                            Text { text: "SPD"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: root.themeSubtext; width: 26 }
                                            Rectangle {
                                                height: 4; radius: 2; color: "#222733"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26
                                                Rectangle { height: parent.height; radius: 2; width: parent.width * modelData.speedPct; color: cardRoot.isSelected ? root.themeAccent : "#5588aa" }
                                            }
                                        }

                                        // Armor
                                        Row {
                                            width: parent.width
                                            Text { text: "ARM"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: root.themeSubtext; width: 26 }
                                            Rectangle {
                                                height: 4; radius: 2; color: "#222733"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26
                                                Rectangle { height: parent.height; radius: 2; width: parent.width * modelData.armorPct; color: cardRoot.isSelected ? "#00FF66" : "#449966" }
                                            }
                                        }

                                        // Firepower
                                        Row {
                                            width: parent.width
                                            Text { text: "POW"; font.pixelSize: 8; font.bold: true; font.family: root.monoFontFamily; color: root.themeSubtext; width: 26 }
                                            Rectangle {
                                                height: 4; radius: 2; color: "#222733"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26
                                                Rectangle { height: parent.height; radius: 2; width: parent.width * modelData.firepowerPct; color: cardRoot.isSelected ? "#FF5533" : "#aa6644" }
                                            }
                                        }
                                    }

                                    // Tactical brief
                                    Text {
                                        width: parent.width
                                        text: modelData.desc
                                        font.pixelSize: 8
                                        color: root.themeSubtext
                                        wrapMode: Text.Wrap
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Item { width: 1; height: 2 }

                                    // Action / Status Pill
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 18
                                        width: statusText.implicitWidth + 12
                                        radius: 4
                                        color: cardRoot.isSelected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.25) : "transparent"
                                        border.color: cardRoot.isSelected ? root.themeAccent : root.themeBorder
                                        border.width: 1

                                        Text {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: "LAUNCH [ " + (modelData.shipId === "interceptor" ? "1" : (modelData.shipId === "valkyrie" ? "2" : "3")) + " ]"
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: root.monoFontFamily
                                            color: cardRoot.isSelected ? root.themeAccent : root.themeSubtext
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Launch / Deploy Action Button
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5

                    Rectangle {
                        id: deployBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(260, parent.parent.width - 32)
                        height: 38
                        radius: 8
                        color: deployMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "🚀"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "DEPLOY SHIP (SPACE / ENTER)"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.themeBtnFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: deployMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deploySelectedShip()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Click any ship or press [1], [2], [3] to launch • [Enter] Deploy"
                        font.pixelSize: 9
                        font.family: root.monoFontFamily
                        color: root.themeSubtext
                    }
                }
            }
        }

        // Sector Cleared Intermission Overlay
        Rectangle {
            id: sectorClearedOverlay
            anchors.fill: playArea
            radius: boardContainer.radius
            color: "#c0000000"
            visible: root.gameState === "sector_cleared"
            z: 940

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Engine.advanceNextLevel()
            }

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "SECTOR " + root.currentLevel + " CLEARED!"
                    color: "#00FF66"
                    font.pixelSize: 26
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "WARP DRIVE ENGAGING..."
                    color: root.themeAccent
                    font.pixelSize: 13
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 180
                    height: 38
                    radius: 8
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "CONTINUE NOW (Space)"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Engine.advanceNextLevel()
                    }
                }
            }
        }

        // Victory Overlay (Campaign Complete)
        Rectangle {
            id: victoryOverlay
            anchors.fill: playArea
            radius: boardContainer.radius
            color: "#d9000000"
            visible: root.gameState === "victory"
            z: 950

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNewGameFlow()
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "CAMPAIGN VICTORY!"
                    color: "#FFCC00"
                    font.pixelSize: 30
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "ALL 4 SECTORS CLEARED • STARFRAME VICTORIOUS"
                    color: root.themeAccent
                    font.pixelSize: 12
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Final Score: " + root.score
                    color: root.themeFg
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 170
                    height: 40
                    radius: 8
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "🔄"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "NEW GAME (R / Space)"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGameFlow()
                    }
                }
            }
        }

        // Pause Overlay
        Rectangle {
            id: pauseOverlay
            anchors.fill: playArea
            radius: boardContainer.radius
            color: "#d9000000"
            visible: root.isPaused && root.gameState !== "gameover" && root.gameState !== "victory"
            z: 960

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "PAUSED"
                    color: root.themeAccent
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.levelName + " • Score: " + root.score + " • Shields: " + Math.max(0, Math.round((root.shields / root.maxShields) * 100)) + "%"
                    color: root.themeSubtext
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Resume Button
                    Rectangle {
                        width: 115
                        height: 40
                        radius: 8
                        color: resumeMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "RESUME (P)"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: resumeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePause()
                        }
                    }

                    // How to Play Button
                    Rectangle {
                        width: 125
                        height: 40
                        radius: 8
                        color: helpPauseMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "?"; font.bold: true; font.pixelSize: 12; color: root.themeAccent; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "HOW TO PLAY"
                                color: root.themeFg
                                font.bold: true
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: helpPauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openHelp()
                        }
                    }

                    // New Game Button (Go to Hangar)
                    Rectangle {
                        width: 130
                        height: 40
                        radius: 8
                        color: restartPauseMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "🔄"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "NEW GAME (R)"
                                color: root.themeFg
                                font.bold: true
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: restartPauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startNewGameFlow()
                        }
                    }
                }

                Text {
                    text: "Press P or Esc to resume"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Game Over Overlay
        Rectangle {
            id: gameOverOverlay
            anchors.fill: playArea
            radius: boardContainer.radius
            color: "#d9000000"
            visible: opacity > 0.001
            opacity: root.gameState === "gameover" ? 1.0 : 0.0
            z: 950

            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNewGameFlow()
            }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "MISSION FAILED"
                    color: "#FF3366"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Final Score: " + root.score
                    color: root.themeFg
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Best: " + root.bestScore
                    color: root.themeSubtext
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // New Game Button (Go to Hangar)
                Rectangle {
                    width: 175
                    height: 40
                    radius: 8
                    color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "🔄"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "NEW GAME (R / Space)"
                            color: root.themeBtnFg
                            font.bold: true
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: playAgainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGameFlow()
                    }
                }

                Text {
                    text: "Click anywhere or press R / Space to choose fighter"
                    color: root.themeSubtext
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Help Modal
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: "#e6000000"
            visible: root.showHelp
            z: 1100

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeHelp()
            }

            Rectangle {
                width: Math.min(parent.width * 0.88, 480)
                height: helpCol.height + 44
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeAccent
                border.width: 1.5
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
                            onClicked: root.closeHelp()
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
