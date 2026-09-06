import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "Themes.js" as OmarchyThemes
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 540
    height: 620
    minimumWidth: 380
    minimumHeight: 460
    title: "DropFour"

    property var themePalette: ({})
    property bool isCustomTheme: false
    property string currentThemeName: "Catppuccin"

    property color themeBg: "#181825"
    property color themeFg: "#cdd6f4"
    property color themeAccent: "#89b4fa"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#313244"
    property color themeCardBg: "#1e1e2e"
    property color themeSubtext: "#a6adc8"
    property color themeBorder: "#45475a"
    property color themeModalBg: "#1e1e2e"

    // Tokens
    property color p1Color: "#f38ba8"
    property color p2Color: "#f9e2af"

    // State
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int p1Wins: 0
    property int p2Wins: 0
    property int draws: 0
    property bool cpuThinking: false
    property string gameState: "playing"
    property int currentPlayer: 1
    property string winnerName: ""
    property string gameMode: "1p"
    property string cpuDifficulty: "pro"

    color: themeBg
    Behavior on color { ColorAnimation { duration: 250 } }

    Component.onCompleted: {
        loadStats();
        Engine.init("1p", "pro");
    }

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        themePalette = data;
        isCustomTheme = true;
        currentThemeName = name || "";

        var bg = data.background || themeBg;
        themeBg = bg;
        themeFg = data.foreground || themeFg;
        themeAccent = data.accent || data.color4 || "#89b4fa";
        themeBorder = data.color8 || data.color0 || "#45475a";

        p1Color = data.color1 || data.color9 || "#f38ba8";
        p2Color = data.color3 || data.color11 || "#f9e2af";

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.08);
            themeCellGrid = Qt.darker(bg, 1.15);
            themeCardBg = Qt.darker(bg, 1.05);
            themeSubtext = Qt.darker(themeFg, 1.4);
            themeModalBg = bg;
        } else {
            themeBoardBg = Qt.lighter(bg, 1.18);
            themeCellGrid = Qt.lighter(bg, 1.28);
            themeCardBg = Qt.lighter(bg, 1.25);
            themeSubtext = data.color7 || Qt.darker(themeFg, 1.3);
            themeModalBg = Qt.lighter(bg, 1.12);
        }
        boardCanvas.requestPaint();
    }

    function cycleTheme() {
        var themes = OmarchyThemes.themes;
        if (!themes || themes.length === 0) return;
        var currentId = themePalette.id || "";
        var nextIdx = 0;
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === currentId) {
                nextIdx = (i + 1) % themes.length;
                break;
            }
        }
        applyTheme(themes[nextIdx], themes[nextIdx].name);
        soundToast.show("🎨 " + themes[nextIdx].name);
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

    function loadStats() {
        if (typeof settingsManager !== "undefined") {
            p1Wins = settingsManager.getStat("p1Wins");
            p2Wins = settingsManager.getStat("p2Wins");
            draws = settingsManager.getStat("draws");
        }
    }

    function recordWin(player) {
        if (typeof settingsManager !== "undefined") {
            if (player === 1) {
                p1Wins++;
                settingsManager.setStat("p1Wins", p1Wins);
            } else if (player === 2) {
                p2Wins++;
                settingsManager.setStat("p2Wins", p2Wins);
            }
        }
    }

    function recordDraw() {
        if (typeof settingsManager !== "undefined") {
            draws++;
            settingsManager.setStat("draws", draws);
        }
    }

    function resetGame() {
        cpuTimer.stop();
        cpuThinking = false;
        Engine.init(root.gameMode, root.cpuDifficulty);
        root.gameState = "playing";
        root.currentPlayer = Engine.currentPlayer;
        root.winnerName = "";
        boardCanvas.requestPaint();
    }

    function doDrop(col) {
        if (cpuThinking || root.gameState !== "playing") return;
        var res = Engine.dropToken(col);
        if (!res || res.error) return;

        playSound("drop");
        root.currentPlayer = Engine.currentPlayer;
        boardCanvas.requestPaint();

        if (res.event === "win") {
            playSound("win");
            recordWin(res.player);
            root.winnerName = (res.player === 1) ? "Player 1" : (root.gameMode === "1p" ? "CPU" : "Player 2");
            root.gameState = "won";
            soundToast.show("🏆 " + root.winnerName + " Wins!");
            return;
        }

        if (res.event === "draw") {
            recordDraw();
            root.winnerName = "Nobody";
            root.gameState = "draw";
            soundToast.show("🤝 Draw Game!");
            return;
        }

        // Check if next turn is CPU in 1P mode
        if (root.gameMode === "1p" && Engine.currentPlayer === 2) {
            cpuThinking = true;
            cpuTimer.restart();
        }
    }

    Timer {
        id: cpuTimer
        interval: 320
        repeat: false
        onTriggered: {
            if (root.gameState !== "playing") {
                cpuThinking = false;
                return;
            }
            var cpuCol = Engine.getCpuMove();
            cpuThinking = false;
            if (cpuCol >= 0) {
                var res = Engine.dropToken(cpuCol);
                if (res) {
                    playSound("drop");
                    root.currentPlayer = Engine.currentPlayer;
                    boardCanvas.requestPaint();
                    if (res.event === "win") {
                        playSound("win");
                        recordWin(res.player);
                        root.winnerName = "CPU";
                        root.gameState = "won";
                        soundToast.show("🤖 CPU Wins!");
                    } else if (res.event === "draw") {
                        recordDraw();
                        root.winnerName = "Nobody";
                        root.gameState = "draw";
                        soundToast.show("🤝 Draw Game!");
                    }
                }
            }
        }
    }

    // roundRect helper
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

    function captureScreenshot(filePath, shouldQuit) {
        splashScreen.visible = false;
        root.contentItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // MAIN CONTAINER
    Item {
        id: mainContainer
        anchors.fill: parent
        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.gameState !== "playing") {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_A || event.key === Qt.Key_R) {
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

            // Move column indicator
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.selectedCol = Math.max(0, Engine.selectedCol - 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.selectedCol = Math.min(Engine.COLS - 1, Engine.selectedCol + 1);
                boardCanvas.requestPaint();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                doDrop(Engine.selectedCol);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_7) {
                var c = event.key - Qt.Key_1;
                Engine.selectedCol = c;
                doDrop(c);
                event.accepted = true;
            }
        }

        // TOP HEADER
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 38

            Row {
                id: leftHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "DropFour"
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeAccent
                    }
                    Text {
                        text: "P1: " + p1Wins + " • " + (root.gameMode === "1p" ? "CPU: " : "P2: ") + p2Wins
                        font.pixelSize: 10
                        font.family: root.monoFontFamily
                        color: root.themeSubtext
                    }
                }
            }

            Row {
                id: rightHeader
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // Turn / Winner Indicator Pill
                Rectangle {
                    width: 58
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: root.currentPlayer === 1 ? root.p1Color : root.p2Color
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.gameState === "won" ? "WIN!" : (root.gameState === "draw" ? "DRAW" : (root.cpuThinking ? "..." : (root.currentPlayer === 1 ? "P1" : (root.gameMode === "1p" ? "CPU" : "P2"))))
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Mode Toggle (1P / 2P)
                Rectangle {
                    width: 32
                    height: 28
                    radius: 6
                    color: modeArea.pressed ? root.themeCellGrid : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.gameMode === "1p" ? "1P" : "2P"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.monoFontFamily
                        color: root.themeAccent
                    }

                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.gameMode = (root.gameMode === "1p") ? "2p" : "1p";
                            Engine.gameMode = root.gameMode;
                            resetGame();
                            soundToast.show("Mode: " + (root.gameMode === "1p" ? "1P vs CPU" : "2P Local"));
                        }
                    }
                }

                // Restart button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: restartArea.pressed ? root.themeCellGrid : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "↺"; font.bold: true; font.pixelSize: 13; color: root.themeFg }
                    MouseArea {
                        id: restartArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: resetGame()
                    }
                }

                // Mute
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: muteArea.pressed ? root.themeCellGrid : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleMute()
                    }
                }

                // Help
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: helpArea.pressed ? root.themeCellGrid : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.pixelSize: 12; font.bold: true; color: root.themePalette.color1 || "#f38ba8" }
                    MouseArea {
                        id: helpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showHelp = !showHelp
                    }
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playfieldContainer
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12

            Item {
                id: boardContainer
                anchors.fill: parent

                Item {
                    id: boardArea
                    property real availW: parent.width
                    property real availH: parent.height - 36
                    property real cellSize: Math.floor(Math.min(availW / Engine.COLS, availH / Engine.ROWS))
                    width: cellSize * Engine.COLS
                    height: cellSize * Engine.ROWS + 36
                    anchors.centerIn: parent

                    Canvas {
                        id: boardCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var cs = boardArea.cellSize;
                            var topH = 36;
                            var radius = cs * 0.38;

                            // Draw Column Drop Indicator at the top
                            if (root.gameState === "playing" && !cpuThinking) {
                                var indX = Engine.selectedCol * cs + cs / 2;
                                var indY = 16;
                                var indColor = (root.currentPlayer === 1) ? root.p1Color : root.p2Color;

                                ctx.fillStyle = indColor;
                                ctx.beginPath();
                                ctx.arc(indX, indY, radius * 0.7, 0, Math.PI * 2);
                                ctx.fill();

                                // Arrow pointing down
                                ctx.fillStyle = indColor;
                                ctx.beginPath();
                                ctx.moveTo(indX - 8, indY + radius * 0.7 + 2);
                                ctx.lineTo(indX + 8, indY + radius * 0.7 + 2);
                                ctx.lineTo(indX, indY + radius * 0.7 + 9);
                                ctx.closePath();
                                ctx.fill();
                            }

                            // Draw Board Cabinet
                            var boardY = topH;
                            ctx.fillStyle = root.themeCardBg;
                            drawRoundRect(ctx, 0, boardY, width, height - topH, 16);
                            ctx.fill();

                            ctx.strokeStyle = root.themeBorder;
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            // Check if winning coordinates
                            function isWinning(r, c) {
                                for (var i = 0; i < Engine.winningCells.length; i++) {
                                    if (Engine.winningCells[i].r === r && Engine.winningCells[i].c === c) {
                                        return true;
                                    }
                                }
                                return false;
                            }

                            // Draw Slots & Tokens
                            for (var r = 0; r < Engine.ROWS; r++) {
                                for (var c = 0; c < Engine.COLS; c++) {
                                    var cx = c * cs + cs / 2;
                                    var cy = boardY + r * cs + cs / 2;
                                    var token = Engine.board[r][c];

                                    // Hole background
                                    ctx.fillStyle = root.themeBg;
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                                    ctx.fill();

                                    // Slot depth shadow
                                    ctx.strokeStyle = root.themeBorder;
                                    ctx.lineWidth = 1.5;
                                    ctx.stroke();

                                    if (token !== 0) {
                                        var color = (token === 1) ? root.p1Color : root.p2Color;
                                        ctx.fillStyle = color;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, radius - 2, 0, Math.PI * 2);
                                        ctx.fill();

                                        // Inner highlight ring for retro arcade token feel
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
                                        ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, radius * 0.65, 0, Math.PI * 2);
                                        ctx.stroke();

                                        // Specular shine
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.4)";
                                        ctx.beginPath();
                                        ctx.arc(cx - radius * 0.28, cy - radius * 0.28, radius * 0.22, 0, Math.PI * 2);
                                        ctx.fill();

                                        if (isWinning(r, c)) {
                                            // Glow star or ring
                                            ctx.strokeStyle = "#ffffff";
                                            ctx.lineWidth = 3.5;
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, radius + 1, 0, Math.PI * 2);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPositionChanged: function(mouse) {
                                var cs = boardArea.cellSize;
                                var col = Math.floor(mouse.x / cs);
                                if (col >= 0 && col < Engine.COLS && col !== Engine.selectedCol) {
                                    Engine.selectedCol = col;
                                    boardCanvas.requestPaint();
                                }
                            }

                            onClicked: function(mouse) {
                                if (root.gameState !== "playing") {
                                    resetGame();
                                    soundToast.show("New Game Started");
                                    return;
                                }
                                var cs = boardArea.cellSize;
                                var col = Math.floor(mouse.x / cs);
                                if (col >= 0 && col < Engine.COLS) {
                                    Engine.selectedCol = col;
                                    doDrop(col);
                                }
                            }
                        }
                    }

                    // Game Over / Victory Overlay
                    Rectangle {
                        id: gameOverOverlay
                        anchors.fill: parent
                        radius: 16
                        color: Qt.rgba(0, 0, 0, 0.78)
                        visible: root.gameState !== "playing"
                        z: 60

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
                                text: root.gameState === "won" ? (root.winnerName.toUpperCase() + " WINS!") : "DRAW GAME!"
                                font.family: root.monoFontFamily
                                font.pixelSize: 24
                                font.bold: true
                                color: root.gameState === "won" ? (root.winnerName === "Player 1" ? root.p1Color : root.p2Color) : root.themeFg
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "P1: " + root.p1Wins + "  —  " + (root.gameMode === "1p" ? "CPU: " : "P2: ") + root.p2Wins
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
            height: 370
            radius: 16
            color: root.themeModalBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "🔴 DropFour Controls"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Connect 4 tokens in a row vertically, horizontally, or diagonally. Outsmart the Minimax AI or challenge a friend locally!"
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

                    Text { text: "Left / Right / A / D / H / L"; font.bold: true; color: root.themeAccent; font.pixelSize: 12 }
                    Text { text: "Select Column"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Space / Down / Enter"; font.bold: true; color: root.p1Color; font.pixelSize: 12 }
                    Text { text: "Drop Token"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "Keys 1 - 7"; font.bold: true; color: root.p2Color; font.pixelSize: 12 }
                    Text { text: "Quick Drop in Column"; color: root.themeFg; font.pixelSize: 12 }

                    Text { text: "R / M / T"; font.bold: true; color: root.themeSubtext; font.pixelSize: 12 }
                    Text { text: "Restart / Mute / Next Theme"; color: root.themeFg; font.pixelSize: 12 }
                }

                Item { width: 1; height: 10 }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Got It!"
                    onClicked: showHelp = false
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
