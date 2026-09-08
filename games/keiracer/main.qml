import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 640
    height: 640
    minimumWidth: 320
    minimumHeight: 400
    title: currentThemeName.length > 0 ? "KeiRacer • " + currentThemeName : "KeiRacer"

    // Dynamic Omarchy Theme Properties
    property color themeBg: "#0f172a"
    property color themeBoardBg: "#020617"
    property color themeCardBg: "#1e293b"
    property color themeBorder: "#334155"
    property color themeFg: "#f8fafc"
    property color themeSubtext: "#94a3b8"
    property color themeAccent: "#00f0ff"
    property color themeBtnFg: "#0f172a"
    property color themePink: "#ff007f"

    property string currentThemeName: "Catppuccin"
    property bool splashEnabled: true
    property bool showCarSelect: true
    property bool isMuted: true
    property bool fullPlayfield: false
    readonly property bool isTiledDesktopMode: fullPlayfield || root.height < 520 || root.width < 440
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"
    property string helpText: "• Steer: Arrow Keys / WASD / HJKL\n• Accelerate / Brake: Up / Down or W / S\n• Drift: Spacebar at speed for lateral slide\n• Garage: Press C to switch Kei cars\n• View: Shift+F for compact/full playfield\n• Sound: Press M to toggle audio\n• Restart: Press R for a new run\n• Checkpoints: Cross arch gates for +30s\n• Near Miss / Pass: Draft and pass rivals for points"

    // Game & Drivetrain state properties bound to Engine
    property string selectedCar: "keitruck"
    onSelectedCarChanged: {
        Engine.setActiveVehicle(selectedCar);
        redlineRPM = Engine.redlineRPM;
        idleRPM = Engine.idleRPM;
        shiftRPM = Engine.shiftRPM;
        gaugeMaxRPM = Engine.gaugeMaxRPM;
    }
    property int currentSpeed: 0
    property int currentRPM: 850
    property int currentGear: 1
    property int redlineRPM: 6800
    property int idleRPM: 850
    property int shiftRPM: 5600
    property int gaugeMaxRPM: 8000
    property int currentScore: 0
    property int highScore: 0
    property real currentTimeLeft: 50.0
    property int currentStage: 1
    property bool isGameOver: false
    property bool isStageComplete: false
    property string bannerText: ""
    property int bannerTimer: 0

    // Key states
    property var keysPressed: ({
        up: false,
        down: false,
        left: false,
        right: false,
        w: false,
        s: false,
        a: false,
        d: false,
        h: false,
        j: false,
        k: false,
        l: false,
        space: false
    })

    color: themeBg

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.highScore = settingsManager.getBestScore();
        }
    }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) themeBg = data.bg;
        if (data.fg) themeFg = data.fg;
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
        if (data.accent) themeAccent = data.accent;
        if (name) currentThemeName = name;
        gameCanvas.requestPaint();
    }

    function playSound(name) {
        if (name === "screech") return;
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            if (typeof soundManager.playSound === "function") {
                soundManager.playSound(name);
            } else if (typeof soundManager.play === "function") {
                soundManager.play(name);
            }
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("checkpoint");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
        if (typeof soundManager !== "undefined" && soundManager && typeof soundManager.updateEngineAudio === "function") {
            var isAccel = root.keysPressed.up || root.keysPressed.w || root.keysPressed.k;
            soundManager.updateEngineAudio(root.selectedCar, Engine.currentRPM, isAccel, Engine.speed, Engine.isShiftCut, root.isMuted);
        }
    }

    function startNewGame() {
        Engine.init(gameCanvas.width, gameCanvas.height);
        Engine.setActiveVehicle(root.selectedCar);
        root.isGameOver = false;
        root.isStageComplete = false;
        root.currentScore = 0;
        root.currentSpeed = 0;
        root.currentRPM = Engine.idleRPM;
        root.currentGear = 1;
        root.redlineRPM = Engine.redlineRPM;
        root.idleRPM = Engine.idleRPM;
        root.currentTimeLeft = 50.0;
        root.currentStage = 1;
        bannerText = "STAGE 1 START";
        bannerTimer = 90;
        gameCanvas.requestPaint();
        soundToast.show("NEW GAME");
    }

    function debugSideBySide() {
        Engine.debugPlaceCarNextToPlayer();
        gameCanvas.requestPaint();
    }

    function triggerSound(name) {
        playSound(name);
        if (name === "checkpoint") {
            bannerText = "CHECKPOINT EXTENSION +30s";
            bannerTimer = 90;
        } else if (name === "crash") {
            bannerText = "COLLISION!";
            bannerTimer = 40;
        }
    }

    signal screenshotSaved(string path)

    function captureScreenshot(filePath, shouldQuit) {
        if (splashScreen) {
            splashScreen.visible = false;
            splashScreen.opacity = 0;
        }
        root.splashEnabled = false;
        var shotPath = filePath || "screenshot.png";
        mainContainer.grabToImage(function(result) {
            var success = result.saveToFile(shotPath);
            console.log("Screenshot saved to " + shotPath);
            root.screenshotSaved(shotPath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // Main Container
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, scoreRow.height))

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: scoreRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "KeiRacer"
                    font.family: root.monoFontFamily
                    font.pixelSize: Math.max(20, Math.min(30, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Slow Car Racing League"
                    font.family: root.monoFontFamily
                    font.pixelSize: Math.max(10, Math.min(12, headerItem.width * 0.024))
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
                    width: Math.max(54, Math.min(76, headerItem.width * 0.14))
                    height: Math.max(38, Math.min(46, headerItem.width * 0.09))
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
                            font.family: root.monoFontFamily
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentScore.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // BEST Card
                Rectangle {
                    width: Math.max(54, Math.min(76, headerItem.width * 0.14))
                    height: Math.max(38, Math.min(46, headerItem.width * 0.09))
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
                            font.family: root.monoFontFamily
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.max(root.highScore, root.currentScore).toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: root.highScore > 0 ? root.themeAccent : root.themeSubtext
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
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: root.isTiledDesktopMode ? 0 : 32

            readonly property bool isCrowded: subheaderItem.width < 450

            // Left cluster: Garage & Help
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Garage Button
                Rectangle {
                    id: garageBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 32 : (garageRow.implicitWidth + 18)
                    radius: 7
                    color: garageMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: garageRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🏎️"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Garage (C)"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: garageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showCarSelect = !root.showCarSelect
                    }
                }

                // Help Button
                Rectangle {
                    id: helpBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 7
                    color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "?"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "How to Play"
                            font.family: root.monoFontFamily
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

            // Right cluster: Mute & Restart
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Mute Button
                Rectangle {
                    id: muteBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 7
                    color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.family: root.monoFontFamily
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

                // Restart Button
                Rectangle {
                    id: restartBtn
                    height: 30
                    width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                    radius: 7
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 12
                            visible: subheaderItem.isCrowded
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "New Game (R)"
                            font.family: root.monoFontFamily
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
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

        // =====================================================================
        // TIER 3: PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Item {
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
                    text: "🏎️ KeiRacer"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + ("SCORE: " + root.score)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("BEST: " + root.highScore) + ")"
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
                            soundToast.show("🔲 Standard Window");
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
                    Text { text: "🔄"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame()
                    }
                }
            }
        }

        id: playArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14

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

                    property var spriteUrls: ({
                        // Suzuki Carry Kei Truck (Base Sprites + Vector Brake Overlays)
                        kei_straight: Qt.resolvedUrl("assets/kei_straight.webp"),
                        kei_straight_brakes: Qt.resolvedUrl("assets/kei_straight_brakes.webp"),
                        kei_l10: Qt.resolvedUrl("assets/kei_l10.webp"),
                        kei_l10_brakes: Qt.resolvedUrl("assets/kei_l10_brakes.webp"),
                        kei_l20: Qt.resolvedUrl("assets/kei_l20.webp"),
                        kei_l20_brakes: Qt.resolvedUrl("assets/kei_l20_brakes.webp"),
                        kei_l30: Qt.resolvedUrl("assets/kei_l30.webp"),
                        kei_l30_brakes: Qt.resolvedUrl("assets/kei_l30_brakes.webp"),
                        // Smart Fortwo (Base Sprites + Vector Brake Overlays)
                        smart_straight: Qt.resolvedUrl("assets/smart_straight.webp"),
                        smart_straight_brakes: Qt.resolvedUrl("assets/smart_straight_brakes.webp"),
                        smart_l10: Qt.resolvedUrl("assets/smart_l10.webp"),
                        smart_l10_brakes: Qt.resolvedUrl("assets/smart_l10_brakes.webp"),
                        smart_l20: Qt.resolvedUrl("assets/smart_l20.webp"),
                        smart_l20_brakes: Qt.resolvedUrl("assets/smart_l20_brakes.webp"),
                        smart_l30: Qt.resolvedUrl("assets/smart_l30.webp"),
                        smart_l30_brakes: Qt.resolvedUrl("assets/smart_l30_brakes.webp"),
                        // Fiat Panda 4x4 (Base Sprites + Vector Brake Overlays)
                        panda_straight: Qt.resolvedUrl("assets/panda_straight.webp"),
                        panda_straight_brakes: Qt.resolvedUrl("assets/panda_straight_brakes.webp"),
                        panda_l10: Qt.resolvedUrl("assets/panda_l10.webp"),
                        panda_l10_brakes: Qt.resolvedUrl("assets/panda_l10_brakes.webp"),
                        panda_l20: Qt.resolvedUrl("assets/panda_l20.webp"),
                        panda_l20_brakes: Qt.resolvedUrl("assets/panda_l20_brakes.webp"),
                        panda_l30: Qt.resolvedUrl("assets/panda_l30.webp"),
                        panda_l30_brakes: Qt.resolvedUrl("assets/panda_l30_brakes.webp"),
                        // Suzuki Sidekick (Base Sprites + Vector Brake Overlays)
                        sidekick_straight: Qt.resolvedUrl("assets/sidekick_straight.webp"),
                        sidekick_straight_brakes: Qt.resolvedUrl("assets/sidekick_straight_brakes.webp"),
                        sidekick_l10: Qt.resolvedUrl("assets/sidekick_l10.webp"),
                        sidekick_l10_brakes: Qt.resolvedUrl("assets/sidekick_l10_brakes.webp"),
                        sidekick_l20: Qt.resolvedUrl("assets/sidekick_l20.webp"),
                        sidekick_l20_brakes: Qt.resolvedUrl("assets/sidekick_l20_brakes.webp"),
                        sidekick_l30: Qt.resolvedUrl("assets/sidekick_l30.webp"),
                        sidekick_l30_brakes: Qt.resolvedUrl("assets/sidekick_l30_brakes.webp"),
                        // Jeep Wrangler YJ (Base Sprites + Vector Brake Overlays)
                        wrangler_straight: Qt.resolvedUrl("assets/wrangler_straight.webp"),
                        wrangler_straight_brakes: Qt.resolvedUrl("assets/wrangler_straight_brakes.webp"),
                        wrangler_l10: Qt.resolvedUrl("assets/wrangler_l10.webp"),
                        wrangler_l10_brakes: Qt.resolvedUrl("assets/wrangler_l10_brakes.webp"),
                        wrangler_l20: Qt.resolvedUrl("assets/wrangler_l20.webp"),
                        wrangler_l20_brakes: Qt.resolvedUrl("assets/wrangler_l20_brakes.webp"),
                        wrangler_l30: Qt.resolvedUrl("assets/wrangler_l30.webp"),
                        wrangler_l30_brakes: Qt.resolvedUrl("assets/wrangler_l30_brakes.webp"),
                        // Volkswagen Type 2 Bus (Base Sprites + Vector Brake Overlays)
                        vwbus_straight: Qt.resolvedUrl("assets/vwbus_straight.webp"),
                        vwbus_straight_brakes: Qt.resolvedUrl("assets/vwbus_straight_brakes.webp"),
                        vwbus_l10: Qt.resolvedUrl("assets/vwbus_l10.webp"),
                        vwbus_l10_brakes: Qt.resolvedUrl("assets/vwbus_l10_brakes.webp"),
                        vwbus_l20: Qt.resolvedUrl("assets/vwbus_l20.webp"),
                        vwbus_l20_brakes: Qt.resolvedUrl("assets/vwbus_l20_brakes.webp"),
                        vwbus_l30: Qt.resolvedUrl("assets/vwbus_l30.webp"),
                        vwbus_l30_brakes: Qt.resolvedUrl("assets/vwbus_l30_brakes.webp")
                    })

                    Component.onCompleted: {
                        for (var k in spriteUrls) {
                            loadImage(spriteUrls[k]);
                        }
                    }

                    onImageLoaded: {
                        requestPaint();
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        Engine.render(ctx, width, height, {
                            bg: root.themeBg,
                            boardBg: root.themeBoardBg,
                            cardBg: root.themeCardBg,
                            accent: root.themeAccent,
                            fg: root.themeFg
                        }, gameCanvas, spriteUrls, root.selectedCar);
                    }

                    onWidthChanged: {
                        Engine.init(width, height);
                        requestPaint();
                    }

                    onHeightChanged: {
                        Engine.init(width, height);
                        requestPaint();
                    }
                }

                // In-Game Banner Flash (Checkpoint / Collision / Stage)
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: bannerLabel.width + 36
                    height: 32
                    radius: 16
                    color: root.themeCardBg
                    border.color: root.themePink
                    border.width: 1.5
                    visible: root.bannerTimer > 0
                    opacity: Math.min(1.0, root.bannerTimer / 20.0)

                    Text {
                        id: bannerLabel
                        anchors.centerIn: parent
                        text: root.bannerText
                        font.family: root.monoFontFamily
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: root.themeAccent
                    }
                }

                // GAME OVER OVERLAY
                Rectangle {
                    anchors.fill: parent
                    color: "#e0020617"
                    visible: root.isGameOver
                    z: 20

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "TIME EXPIRED"
                            font.family: root.monoFontFamily
                            font.pixelSize: Math.max(20, Math.min(30, root.width * 0.065))
                            font.bold: true
                            font.letterSpacing: 3
                            color: root.themePink
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "FINAL SCORE: " + root.currentScore
                            font.family: root.monoFontFamily
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 150
                            height: 38
                            radius: 8
                            color: retryMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "RETRY (R)"
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeBtnFg
                            }

                            MouseArea {
                                id: retryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startNewGame()
                            }
                        }
                    }
                }

                // Cockpit Instrument Gauges at the bottom of the boardContainer
                CockpitGauges {
                    id: cockpitGauges
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 16, 420)
                    height: Math.max(54, Math.min(68, boardContainer.height * 0.14))
                    z: 10

                    currentSpeed: root.currentSpeed
                    currentRPM: root.currentRPM
                    currentGear: root.currentGear
                    shiftRPM: root.shiftRPM
                    redlineRPM: root.redlineRPM
                    gaugeMaxRPM: root.gaugeMaxRPM
                    idleRPM: root.idleRPM
                    currentTimeLeft: root.currentTimeLeft

                    themeCardBg: root.themeCardBg
                    themeAccent: root.themeAccent
                    themePink: root.themePink
                    themeBorder: root.themeBorder
                    themeFg: root.themeFg
                    themeSubtext: root.themeSubtext
                    monoFontFamily: root.monoFontFamily
                }

                // Sound Toast Notification inside boardContainer
                Rectangle {
                    id: soundToast
                    anchors.bottom: cockpitGauges.top
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 28
                    width: toastText.implicitWidth + 28
                    radius: 14
                    color: root.themeCardBg
                    border.color: root.themeAccent
                    border.width: 1
                    opacity: 0
                    z: 40

                    property alias text: toastText.text

                    Text {
                        id: toastText
                        anchors.centerIn: parent
                        font.family: root.monoFontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                    }

                    SequentialAnimation on opacity {
                        id: toastAnim
                        running: false
                        NumberAnimation { to: 1.0; duration: 150 }
                        PauseAnimation { duration: 1200 }
                        NumberAnimation { to: 0.0; duration: 300 }
                    }

                    function show(msg) {
                        soundToast.text = msg;
                        toastAnim.restart();
                    }
                }
            }
        }

        // =====================================================================
        // HELP MODAL (Standard Omarchy Arcade Template)
        // =====================================================================
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
                width: Math.min(parent.width * 0.85, 380)
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
                        font.family: root.monoFontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.helpText
                        font.family: root.monoFontFamily
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
                            font.family: root.monoFontFamily
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
                        font.family: root.monoFontFamily
                        font.pixelSize: 9
                        color: root.themeSubtext
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.75
                    }
                }
            }
        }


        // ---------------------------------------------------------------------
        // SPLASH SCREEN
        // ---------------------------------------------------------------------
        // CAR SELECT GARAGE SHOWROOM
        // ---------------------------------------------------------------------
        CarSelectModal {
            id: carSelectModal
            visible: root.showCarSelect
            onCarSelected: function(carId) {
                root.selectedCar = carId;
                Engine.setActiveVehicle(carId);
                root.showCarSelect = false;
                var carName = currentCar ? currentCar.name : carId.toUpperCase();
                soundToast.show("🏎️ Selected: " + carName);
                gameCanvas.requestPaint();
                mainContainer.forceActiveFocus();
            }
            onCloseRequested: {
                root.showCarSelect = false;
                mainContainer.forceActiveFocus();
            }
        }

        // ---------------------------------------------------------------------
        // SPLASH SCREEN
        // ---------------------------------------------------------------------
        SplashScreen {
            id: splashScreen
            onDismissed: {
                root.splashEnabled = false;
                root.showCarSelect = true;
                root.startNewGame();
            }
        }

        // ---------------------------------------------------------------------
        // 60 FPS ENGINE TICK LOOP
        // ---------------------------------------------------------------------
        Timer {
            id: gameLoop
            interval: 16 // ~60 FPS
            running: !root.splashEnabled && !root.showHelp && !root.showCarSelect
            repeat: true
            onTriggered: {
                Engine.update(0.016, root.keysPressed, root.triggerSound);

                root.currentSpeed = Math.round(Engine.speed);
                root.currentRPM = Math.round(Engine.currentRPM);
                root.currentGear = Engine.currentGear;
                root.redlineRPM = Engine.redlineRPM;
                root.idleRPM = Engine.idleRPM;
                root.shiftRPM = Engine.shiftRPM;
                root.gaugeMaxRPM = Engine.gaugeMaxRPM;
                root.currentScore = Engine.score;
                root.currentTimeLeft = Engine.timeLeft;
                root.isGameOver = Engine.gameOver;
                root.isStageComplete = Engine.stageCompleted;
                root.currentStage = Engine.stage;

                if (root.bannerTimer > 0) root.bannerTimer--;

                if (root.currentScore > root.highScore) {
                    root.highScore = root.currentScore;
                    if (typeof settingsManager !== "undefined" && settingsManager) {
                        settingsManager.setBestScore(root.highScore);
                    }
                }

                // Sync 60 FPS real-time state with continuous procedural audio engine
                if (typeof soundManager !== "undefined" && soundManager && typeof soundManager.updateEngineAudio === "function") {
                    var isAccel = root.keysPressed.up || root.keysPressed.w || root.keysPressed.k;
                    soundManager.updateEngineAudio(
                        root.selectedCar,
                        Engine.currentRPM,
                        isAccel,
                        Engine.speed,
                        Engine.isShiftCut,
                        root.isMuted
                    );
                }

                gameCanvas.requestPaint();
            }
        }

        // ---------------------------------------------------------------------
        // KEYBOARD EVENT LISTENERS
        // ---------------------------------------------------------------------
        Keys.onPressed: function(event) {
            if (event.isAutoRepeat) return;

            if (root.showCarSelect) {
                if (event.key === Qt.Key_Left) {
                    carSelectModal.prevCar();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right) {
                    carSelectModal.nextCar();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    carSelectModal.selectCurrentCar();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_C) {
                    root.showCarSelect = false;
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question) {
                root.showHelp = !root.showHelp;
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
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }


            if (event.key === Qt.Key_C) {
                root.showCarSelect = !root.showCarSelect;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.startNewGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Up) keysPressed.up = true;
            if (event.key === Qt.Key_W) keysPressed.w = true;
            if (event.key === Qt.Key_K) keysPressed.k = true;

            if (event.key === Qt.Key_Down) keysPressed.down = true;
            if (event.key === Qt.Key_S) keysPressed.s = true;
            if (event.key === Qt.Key_J) keysPressed.j = true;

            if (event.key === Qt.Key_Left) keysPressed.left = true;
            if (event.key === Qt.Key_A) keysPressed.a = true;
            if (event.key === Qt.Key_H) keysPressed.h = true;

            if (event.key === Qt.Key_Right) keysPressed.right = true;
            if (event.key === Qt.Key_D) keysPressed.d = true;
            if (event.key === Qt.Key_L) keysPressed.l = true;

            if (event.key === Qt.Key_Space) keysPressed.space = true;

            event.accepted = true;
        }

        Keys.onReleased: function(event) {
            if (event.isAutoRepeat) return;

            if (event.key === Qt.Key_Up) keysPressed.up = false;
            if (event.key === Qt.Key_W) keysPressed.w = false;
            if (event.key === Qt.Key_K) keysPressed.k = false;

            if (event.key === Qt.Key_Down) keysPressed.down = false;
            if (event.key === Qt.Key_S) keysPressed.s = false;
            if (event.key === Qt.Key_J) keysPressed.j = false;

            if (event.key === Qt.Key_Left) keysPressed.left = false;
            if (event.key === Qt.Key_A) keysPressed.a = false;
            if (event.key === Qt.Key_H) keysPressed.h = false;

            if (event.key === Qt.Key_Right) keysPressed.right = false;
            if (event.key === Qt.Key_D) keysPressed.d = false;
            if (event.key === Qt.Key_L) keysPressed.l = false;

            if (event.key === Qt.Key_Space) keysPressed.space = false;

            event.accepted = true;
        }
    }
}
