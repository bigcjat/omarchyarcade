import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 480
    height: 640
    minimumWidth: 300
    minimumHeight: 400
    title: "Arcade Game Title"

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

    // WCAG contrast helper ensuring buttons are always readable in light/dark themes
    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameState: "ready" // "ready", "playing", "gameover", "won"
    property int score: 0
    property int bestScore: 0
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Move: Arrows, WASD, or Vim H / J / K / L\n• Action: Space\n• Restart: R\n• Sound: M\n• Help: ? or Esc"

    // =========================================================================
    // THEME & SOUND CONTROLLERS
    // =========================================================================
    signal screenshotSaved(string filePath)

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;

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
            // Light themes (e.g. Latte, Snow, Paper, Day mode)
            themeBoardBg = Qt.darker(bg, 1.06);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBorder = c8 || Qt.darker(bg, 1.15);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            // Dark themes (e.g. Catppuccin, Tokyo Night, Gruvbox, Night mode)
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        // Allow explicit overrides if present
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;

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

    function restartGame() {
        Engine.resetGame();
        gameState = "playing";
        score = 0;
        gameCanvas.requestPaint();
        playSound("click");
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
        }
        Engine.init(boardContainer.width, boardContainer.height);
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

            if (root.gameState === "gameover" || root.gameState === "won") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.restartGame();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
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
            } else if (event.key === Qt.Key_Space) {
                Engine.handleInput("action", { onSound: root.playSound });
                event.accepted = true;
            }
        }

        // =====================================================================
        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        // =====================================================================
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: Math.max(titleCol.height, scoreRow.height)

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
                    text: "Classic arcade puzzle for Omarchy"
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
            anchors.top: headerItem.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 34

            readonly property bool isCrowded: subheaderItem.width < 450

            // Left cluster (e.g. Help pill button or stats)
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
            }

            // Right cluster (Actions: Mute, Restart)
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
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
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
                        ctx.fillStyle = root.themeBoardBg;
                        ctx.fillRect(0, 0, width, height);

                        // Render starter game visual / board grid
                        ctx.fillStyle = root.themeCardBg;
                        var sz = Math.min(width, height) * 0.5;
                        ctx.fillRect((width - sz) / 2, (height - sz) / 2, sz, sz);

                        ctx.strokeStyle = root.themeAccent;
                        ctx.lineWidth = 2;
                        ctx.strokeRect((width - sz) / 2, (height - sz) / 2, sz, sz);
                    }
                }
            }
        }

        // =====================================================================
        // MODALS & OVERLAYS (Help, Game Over, Sound Toast)
        // =====================================================================
        // Help Modal
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

        // Standardized Game Over / Victory Overlay
        Rectangle {
            id: gameOverOverlay
            anchors.fill: parent
            color: "#b3000000"
            visible: root.gameState === "gameover" || root.gameState === "won"
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
                    text: root.gameState === "won" ? "VICTORY!" : "GAME OVER"
                    color: root.gameState === "won" ? root.themeAccent : "#FF5555"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Final Score: " + root.score
                    color: root.themeFg
                    font.pixelSize: 16
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
                        text: "PLAY AGAIN"
                        color: root.themeBtnFg
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: playAgainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartGame()
                    }
                }

                Text {
                    text: "Or press R / Space / Enter"
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
