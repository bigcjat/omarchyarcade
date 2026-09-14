import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 480
    height: 580
    minimumWidth: 360
    minimumHeight: 440
    title: "CyberSweeper"

    // Dynamic Theme Properties
    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: "Catppuccin"

    property color themeBg: "#181825"
    property color themeFg: "#cdd6f4"
    property color themeAccent: "#89b4fa"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#313244"
    property color themeCardBg: "#313244"
    property color themeCardHover: "#45475a"
    property color themeSubtext: "#a6adc8"
    property color themeBorder: "#45475a"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property color themeModalBg: "#1e1e2e"
    readonly property bool isDarkMode: colorLuminance(themeBg) < 0.5

    // Game state
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int elapsedSeconds: 0
    property string smileyState: "normal" // "normal", "scared", "won", "dead"
    property int bestTime: 999

    color: themeBg

    Component.onCompleted: {
        updateBestTime();
        Engine.init("beginner");
    }

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        themePalette = data;
        isCustomTheme = true;
        currentThemeName = name || "";

        var bg = data.bg || data.background || "#181825";
        var fg = data.fg || data.foreground || "#cdd6f4";
        var accent = data.accent || data.color4 || "#89b4fa";
        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = data.boardBg || "#dce0e8";
            themeCardBg = data.card_bg || data.cardBg || "#ffffff";
            themeCardHover = data.card_hover || "#f1f5f9";
            themeSubtext = data.subtext || "#5c5f77";
            themeBorder = data.border || "#ccd0da";
            themeCellGrid = "#cbd5e1";
            themeModalBg = "#ffffff";
        } else {
            themeBoardBg = data.boardBg || "#1e1e2e";
            themeCardBg = data.card_bg || data.cardBg || "#313244";
            themeCardHover = data.card_hover || "#45475a";
            themeSubtext = data.subtext || "#a6adc8";
            themeBorder = data.border || "#45475a";
            themeCellGrid = "#313244";
            themeModalBg = "#1e1e2e";
        }
        boardCanvas.requestPaint();
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#1e66f5",
            card_bg: "#ffffff",
            card_hover: "#e6e9ef",
            subtext: "#6c6f85",
            border: "#ccd0da"
        } : {
            background: "#181825",
            foreground: "#cdd6f4",
            accent: "#89b4fa",
            card_bg: "#313244",
            card_hover: "#45475a",
            subtext: "#a6adc8",
            border: "#45475a"
        };
        applyTheme(tData, nextIsLight ? "Light" : "Dark");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
    }

    function toggleMute() {
        isMuted = !isMuted;
        soundToast.show(isMuted ? "🔇 Muted" : "🔊 Unmuted");
    }

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.play(name);
        }
    }

    function updateBestTime() {
        if (typeof settingsManager !== "undefined") {
            bestTime = settingsManager.getBestTime(Engine.currentDifficulty);
        }
    }

    function resetGame(diff) {
        gameTimer.stop();
        elapsedSeconds = 0;
        smileyState = "normal";
        Engine.init(diff || Engine.currentDifficulty);
        updateBestTime();
        boardCanvas.requestPaint();
    }

    function testPlay() {
        var res = Engine.reveal(4, 4);
        handleEngineEvent(res);
        boardCanvas.requestPaint();
    }

    function setDifficulty(diff) {
        resetGame(diff);
        soundToast.show("Mode: " + Engine.DIFFICULTIES[diff].label);
    }

    function handleEngineEvent(res) {
        if (!res) return;
        if (res.event === "click") {
            playSound("click");
            if (Engine.gameState === "playing" && !gameTimer.running) {
                gameTimer.start();
            }
        } else if (res.event === "flag") {
            playSound("flag");
        } else if (res.event === "unflag") {
            playSound("unflag");
        } else if (res.event === "explode") {
            gameTimer.stop();
            smileyState = "dead";
            playSound("explode");
            soundToast.show("💥 BOOM! Game Over");
        } else if (res.event === "win") {
            gameTimer.stop();
            smileyState = "won";
            playSound("win");
            if (elapsedSeconds < bestTime) {
                bestTime = elapsedSeconds;
                if (typeof settingsManager !== "undefined") {
                    settingsManager.setBestTime(Engine.currentDifficulty, bestTime);
                }
                soundToast.show("🏆 NEW RECORD: " + bestTime + "s!");
            } else {
                soundToast.show("🎉 CLEAR! Time: " + elapsedSeconds + "s");
            }
        }
        boardCanvas.requestPaint();
    }

    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (elapsedSeconds < 999) {
                elapsedSeconds++;
            }
        }
    }

    // Helper function for roundRect compatibility
    function drawRoundRect(ctx, x, y, w, h, r) {
        if (typeof ctx.roundRect === "function") {
            ctx.beginPath();
            ctx.roundRect(x, y, w, h, r);
            return;
        }
        var radius = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + w - radius, y);
        ctx.arcTo(x + w, y, x + w, y + radius, radius);
        ctx.lineTo(x + w, y + h - radius);
        ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
        ctx.lineTo(x + radius, y + h);
        ctx.arcTo(x, y + h, x, y + h - radius, radius);
        ctx.lineTo(x, y + radius);
        ctx.arcTo(x, y, x + radius, y, radius);
        ctx.closePath();
    }

    // Capture screenshot support
    signal screenshotSaved(string path)

    function captureScreenshot(filePath) {
        splashScreen.visible = false;
        root.contentItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
        });
    }

    // Main HUD & Layout
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (smileyState === "dead" || smileyState === "won") {
                if (event.key === Qt.Key_A || event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    resetGame();
                    soundToast.show("New Game Started");
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.fullPlayfield = !root.fullPlayfield;
                soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_T) {
                cycleTheme();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_R) {
                resetGame();
                soundToast.show("Restarted");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_1) {
                setDifficulty("beginner");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_2) {
                setDifficulty("intermediate");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_3) {
                setDifficulty("expert");
                event.accepted = true;
                return;
            }

            // Keyboard navigation
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.moveCursor(0, -1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.moveCursor(0, 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.moveCursor(-1, 0);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.moveCursor(1, 0);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                var res = Engine.reveal(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(res);
                event.accepted = true;
            } else if (event.key === Qt.Key_F) {
                var resF = Engine.toggleFlag(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(resF);
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                var resC = Engine.chord(Engine.cursor.r, Engine.cursor.c);
                handleEngineEvent(resC);
                event.accepted = true;
            }
        }

        // =====================================================================
        // HEADER BAR BACKGROUND (Adapts to system OS / colors.toml theme)
        // =====================================================================
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTiledDesktopMode ? 0 : (headerItem.height + subheaderItem.height + 36)
            color: root.themeBg
            visible: !root.isTiledDesktopMode
            z: 0
        }

        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : (Math.max(titleCol.height, scoreRow.height))

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
                    text: "CyberSweeper"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (bestTime === 999 ? "No Record" : "Best: " + bestTime + "s") + " • " + (Engine.currentDifficulty === "beginner" ? "Beginner (9×9)" : (Engine.currentDifficulty === "intermediate" ? "Medium (16×16)" : "Expert (30×16)"))
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                }
            }

            // Stat Cards on Right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // MINES Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MINES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🚩 " + (Engine.flagsLeft < 0 ? "0" : Engine.flagsLeft)
                            font.family: root.monoFontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: root.themePalette.color1 || "#f38ba8"
                        }
                    }
                }

                // TIME Card
                Rectangle {
                    width: Math.max(64, Math.min(84, headerItem.width * 0.16))
                    height: Math.max(42, Math.min(52, headerItem.width * 0.10))
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "TIME"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: elapsedSeconds + "s"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                        }
                    }
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 0 : 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.isTiledDesktopMode ? 0 : 34
            readonly property bool isCrowded: subheaderItem.width < 460

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Help button
                Rectangle {
                    id: helpBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeBtnFg
                            }
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
                        onClicked: showHelp = !showHelp
                    }
                }

                // Difficulty toggle pill
                Rectangle {
                    id: diffBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 42 : Math.max(56, Math.min(78, parent.width * 0.16))
                    radius: 8
                    color: diffMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: diffMouse.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Engine.currentDifficulty === "beginner" ? "9×9" : (Engine.currentDifficulty === "intermediate" ? "16²" : "30²")
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.themeFg
                    }

                    MouseArea {
                        id: diffMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var diffs = ["beginner", "intermediate", "expert"];
                            var next = (diffs.indexOf(Engine.currentDifficulty) + 1) % diffs.length;
                            setDifficulty(diffs[next]);
                        }
                    }
                }

                // View Mode Pill (Windowed vs Full Field)
                Rectangle {
                    id: viewModeBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (viewModeRow.implicitWidth + 18)
                    radius: 8
                    color: root.fullPlayfield ? root.themeCardHover : (viewModeMouse.containsMouse ? root.themeCardHover : root.themeCardBg)
                    border.color: root.fullPlayfield ? root.themeAccent : (viewModeMouse.containsMouse ? root.themeAccent : root.themeBorder)
                    border.width: 1

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
                            soundToast.show(root.fullPlayfield ? "⛶ Full Window View" : "🔲 Standard Window");
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Mute button
                Rectangle {
                    id: muteBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: root.isMuted ? root.themeBorder : root.themeAccent
                    border.width: 1

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
                        onClicked: toggleMute()
                    }
                }

                // Restart button
                Rectangle {
                    id: restartBtn
                    height: 32
                    width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: smileyState === "dead" ? "😵" : (smileyState === "won" ? "😎" : "😊")
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Reset (R)"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: resetGame()
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
                    text: "💣 CyberSweeper"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + ("FLAGS: " + root.flagsRemaining)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("TIME: " + root.timerSeconds + "s") + ")"
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

        // Playing Board Area
        Item {
            id: boardArea
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerBar.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Rectangle {
                id: boardContainer
                width: Math.min(parent.width, boardCanvas.width + 20)
                height: Math.min(parent.height, boardCanvas.height + 20)
                anchors.centerIn: parent
                color: root.isDarkMode ? "#11111b" : "#dce1ea"
                radius: 12
                border.color: root.isDarkMode ? root.themeBorder : "#b8c2d1"
                border.width: 1
            }

            property real availableWidth: width - 16
            property real availableHeight: height - 16
            property real maxCellW: availableWidth / Engine.cols
            property real maxCellH: availableHeight / Engine.rows
            property real cellSize: Math.floor(Math.min(maxCellW, maxCellH, 88))
            property real boardPixelW: cellSize * Engine.cols
            property real boardPixelH: cellSize * Engine.rows

            Canvas {
                id: boardCanvas
                width: boardArea.boardPixelW
                height: boardArea.boardPixelH
                anchors.centerIn: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cs = boardArea.cellSize;
                    var pad = Math.max(1.5, cs * 0.06);
                    var cellInner = cs - pad * 2;
                    var rad = Math.max(2, cs * 0.15);

                    var pal = root.themePalette;
                    var numColorsLight = [
                        "",
                        "#1e66f5", // 1: Blue
                        "#16a34a", // 2: Green
                        "#dc2626", // 3: Red
                        "#4338ca", // 4: Dark Indigo
                        "#b91c1c", // 5: Deep Maroon
                        "#0d9488", // 6: Teal
                        "#7c3aed", // 7: Purple
                        "#334155"  // 8: Dark Slate
                    ];
                    var numColors = root.isDarkMode ? [
                        "",
                        pal.color4 || "#89b4fa",
                        pal.color2 || "#a6e3a1",
                        pal.color1 || "#f38ba8",
                        pal.color5 || "#cba6f7",
                        pal.color11 || "#fab387",
                        pal.color6 || "#94e2d5",
                        root.themeSubtext,
                        root.themeFg
                    ] : numColorsLight;

                    for (var r = 0; r < Engine.rows; r++) {
                        for (var c = 0; c < Engine.cols; c++) {
                            var cell = Engine.board[r] ? Engine.board[r][c] : null;
                            if (!cell) continue;

                            var cx = c * cs + pad;
                            var cy = r * cs + pad;

                            if (!cell.revealed) {
                                // Elevated tactile unrevealed tile
                                var isHovered = (Engine.cursor.r === r && Engine.cursor.c === c);
                                var tileFill = root.isDarkMode
                                    ? (isHovered ? root.themeCardHover : root.themeCardBg)
                                    : (isHovered ? "#dce0e8" : "#cbd5e1");
                                var tileBorder = root.isDarkMode ? root.themeBorder : "#94a3b8";

                                ctx.fillStyle = tileFill;
                                drawRoundRect(ctx, cx, cy, cellInner, cellInner, rad);
                                ctx.fill();

                                ctx.strokeStyle = tileBorder;
                                ctx.lineWidth = 1;
                                ctx.stroke();

                                // Tactile bevel on unrevealed tiles in light mode
                                if (!root.isDarkMode) {
                                    ctx.strokeStyle = "rgba(255, 255, 255, 0.65)";
                                    ctx.lineWidth = 1.2;
                                    ctx.beginPath();
                                    ctx.moveTo(cx + rad, cy + 1.2);
                                    ctx.lineTo(cx + cellInner - rad, cy + 1.2);
                                    ctx.moveTo(cx + 1.2, cy + rad);
                                    ctx.lineTo(cx + 1.2, cy + cellInner - rad);
                                    ctx.stroke();

                                    ctx.strokeStyle = "rgba(0, 0, 0, 0.12)";
                                    ctx.beginPath();
                                    ctx.moveTo(cx + rad, cy + cellInner - 1.2);
                                    ctx.lineTo(cx + cellInner - rad, cy + cellInner - 1.2);
                                    ctx.moveTo(cx + cellInner - 1.2, cy + rad);
                                    ctx.lineTo(cx + cellInner - 1.2, cy + cellInner - rad);
                                    ctx.stroke();
                                }

                                if (cell.flagged) {
                                    // Flag icon
                                    ctx.fillStyle = root.isDarkMode ? (pal.color1 || "#f38ba8") : "#dc2626";
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.35, cy + cellInner * 0.25);
                                    ctx.lineTo(cx + cellInner * 0.75, cy + cellInner * 0.42);
                                    ctx.lineTo(cx + cellInner * 0.35, cy + cellInner * 0.6);
                                    ctx.closePath();
                                    ctx.fill();

                                    // Flag pole
                                    ctx.strokeStyle = root.isDarkMode ? root.themeSubtext : "#475569";
                                    ctx.lineWidth = Math.max(2, cs * 0.08);
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.35, cy + cellInner * 0.2);
                                    ctx.lineTo(cx + cellInner * 0.35, cy + cellInner * 0.8);
                                    ctx.stroke();

                                    // Flag base
                                    ctx.beginPath();
                                    ctx.moveTo(cx + cellInner * 0.2, cy + cellInner * 0.8);
                                    ctx.lineTo(cx + cellInner * 0.55, cy + cellInner * 0.8);
                                    ctx.stroke();
                                }
                            } else {
                                // Revealed cell: flat sunken clean surface
                                if (cell.exploded) {
                                    ctx.fillStyle = pal.color1 || "#f38ba8";
                                } else {
                                    ctx.fillStyle = root.isDarkMode ? root.themeBoardBg : "#ffffff";
                                }
                                drawRoundRect(ctx, cx, cy, cellInner, cellInner, rad);
                                ctx.fill();

                                ctx.strokeStyle = root.isDarkMode ? root.themeBg : "#e2e8f0";
                                ctx.lineWidth = 1;
                                ctx.stroke();

                                if (cell.mine) {
                                    // Draw Mine
                                    var centerX = cx + cellInner / 2;
                                    var centerY = cy + cellInner / 2;
                                    var mineRadius = cellInner * 0.24;

                                    ctx.strokeStyle = cell.exploded ? "#ffffff" : root.themeFg;
                                    ctx.lineWidth = Math.max(2, cs * 0.07);

                                    // Spikes
                                    for (var a = 0; a < 4; a++) {
                                        var angle = a * (Math.PI / 4);
                                        ctx.beginPath();
                                        ctx.moveTo(centerX - Math.cos(angle) * (mineRadius * 1.5), centerY - Math.sin(angle) * (mineRadius * 1.5));
                                        ctx.lineTo(centerX + Math.cos(angle) * (mineRadius * 1.5), centerY + Math.sin(angle) * (mineRadius * 1.5));
                                        ctx.stroke();
                                    }

                                    // Mine body
                                    ctx.fillStyle = cell.exploded ? "#ffffff" : root.themeFg;
                                    ctx.beginPath();
                                    ctx.arc(centerX, centerY, mineRadius, 0, Math.PI * 2);
                                    ctx.fill();

                                    // Specular shine
                                    ctx.fillStyle = cell.exploded ? (pal.color1 || "#f38ba8") : root.themeBoardBg;
                                    ctx.beginPath();
                                    ctx.arc(centerX - mineRadius * 0.3, centerY - mineRadius * 0.3, mineRadius * 0.3, 0, Math.PI * 2);
                                    ctx.fill();
                                } else if (cell.neighborMines > 0) {
                                    // Number
                                    ctx.fillStyle = numColors[cell.neighborMines] || root.themeFg;
                                    ctx.font = "bold " + Math.floor(cellInner * 0.6) + "px sans-serif";
                                    ctx.textAlign = "center";
                                    ctx.textBaseline = "middle";
                                    ctx.fillText(cell.neighborMines, cx + cellInner / 2, cy + cellInner / 2 + 1);
                                }
                            }

                            // Keyboard cursor indicator
                            if (Engine.cursor.r === r && Engine.cursor.c === c) {
                                ctx.strokeStyle = root.themeAccent;
                                ctx.lineWidth = 2.5;
                                drawRoundRect(ctx, cx - 1, cy - 1, cellInner + 2, cellInner + 2, rad + 1);
                                ctx.stroke();
                            }
                        }
                    }
                }

                MouseArea {
                    id: boardMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true

                    function getCellAt(mouse) {
                        var cs = boardArea.cellSize;
                        var col = Math.floor(mouse.x / cs);
                        var row = Math.floor(mouse.y / cs);
                        return { r: row, c: col };
                    }

                    onPressed: function(mouse) {
                        var cellPos = getCellAt(mouse);
                        if (cellPos.r >= 0 && cellPos.r < Engine.rows && cellPos.c >= 0 && cellPos.c < Engine.cols) {
                            Engine.cursor.r = cellPos.r;
                            Engine.cursor.c = cellPos.c;
                            if (mouse.button === Qt.LeftButton) {
                                smileyState = "scared";
                            }
                            boardCanvas.requestPaint();
                        }
                    }

                    onReleased: function(mouse) {
                        if (smileyState === "scared") smileyState = "normal";
                        var cellPos = getCellAt(mouse);
                        if (cellPos.r < 0 || cellPos.r >= Engine.rows || cellPos.c < 0 || cellPos.c >= Engine.cols) {
                            return;
                        }

                        if (mouse.button === Qt.RightButton) {
                            var resF = Engine.toggleFlag(cellPos.r, cellPos.c);
                            handleEngineEvent(resF);
                        } else if (mouse.button === Qt.LeftButton) {
                            var cell = Engine.board[cellPos.r][cellPos.c];
                            if (cell.revealed) {
                                var resC = Engine.chord(cellPos.r, cellPos.c);
                                handleEngineEvent(resC);
                            } else {
                                var res = Engine.reveal(cellPos.r, cellPos.c);
                                handleEngineEvent(res);
                            }
                        }
                    }
                }

                // Game Over / Victory Overlay
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.78)
                    visible: smileyState === "dead" || smileyState === "won"
                    z: 50

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resetGame();
                            soundToast.show("New Game Started");
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: smileyState === "won" ? "VICTORY!" : "GAME OVER"
                            font.family: root.monoFontFamily
                            font.pixelSize: 24
                            font.bold: true
                            color: smileyState === "won" ? (root.themePalette.color2 || "#a6e3a1") : (root.themePalette.color1 || "#f38ba8")
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: smileyState === "won" ? ("Time: " + elapsedSeconds + "s" + (bestTime < 9999 ? "  •  Best: " + bestTime + "s" : "")) : "Mine Detonated!"
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140
                            height: 42
                            radius: 8
                            color: root.themeAccent

                            Text {
                                anchors.centerIn: parent
                                text: "PLAY AGAIN"
                                font.family: root.monoFontFamily
                                font.bold: true
                                font.pixelSize: 13
                                color: root.themeBg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    resetGame();
                                    soundToast.show("New Game Started");
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Or press R / Space / Enter"
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            color: root.themeSubtext
                        }
                    }
                }
            }
        }
    }

    // TOAST
    Rectangle {
        id: soundToast
        property alias message: toastText.text
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 32
        height: 38
        radius: 19
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        opacity: 0
        z: 99

        function show(msg) {
            message = msg;
            toastAnim.restart();
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.pixelSize: 13
            font.bold: true
            color: root.themeFg
        }

        SequentialAnimation {
            id: toastAnim
            PropertyAnimation { target: soundToast; property: "opacity"; to: 0.95; duration: 150 }
            PauseAnimation { duration: 1600 }
            PropertyAnimation { target: soundToast; property: "opacity"; to: 0; duration: 250 }
        }
    }

    // HELP MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: showHelp
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: showHelp = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(440, parent.width - 40)
            height: 410
            radius: 16
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "💣 CyberSweeper Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Clear all mine-free tiles as quickly as possible. Flag suspicious tiles and chord revealed numbers to blaze through!"
                    font.pixelSize: 12
                    color: root.themeSubtext
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.themeBorder
                }

                Grid {
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 16

                    Text { text: "Left Click / Space / Enter"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Reveal tile"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Right Click / F"; font.bold: true; color: root.themePalette.color1 || "#f38ba8"; font.pixelSize: 12 }
                    Text { text: "Toggle Flag"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Double Click / C"; font.bold: true; color: root.themePalette.color2 || "#a6e3a1"; font.pixelSize: 12 }
                    Text { text: "Chord (reveal neighbors)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Arrow Keys / WASD / HJKL"; font.bold: true; color: root.themePalette.color5 || "#cba6f7"; font.pixelSize: 12 }
                    Text { text: "Navigate Grid"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "1 / 2 / 3"; font.bold: true; color: root.themePalette.color3 || "#f9e2af"; font.pixelSize: 12 }
                    Text { text: "Difficulty (9x9 / 16x16 / 30x16)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Shift+F"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Full / Compact View (⇧F)"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "R / M / T"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Restart / Mute / Next Theme"; color: root.themeFg; font.pixelSize: 12 }
                }

                Item { width: 1; height: 10 }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Got It!"
                    onClicked: showHelp = false
                }

                Text {
                    text: "Created by Chris Thompson (@bigcjat) with Gemini"
                    font.pixelSize: 10
                    color: root.themeSubtext
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.75
                }
            }
        }
    }

    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }
}
