import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 620
    height: 720
    minimumWidth: 340
    minimumHeight: 460
    title: currentThemeName.length > 0 ? "ByteMan • " + currentThemeName : "ByteMan"

    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#f9e2af" // classic warm golden yellow
    property color themeBtnFg: "#11111b"

    property string currentThemeName: "Catppuccin"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int score: 0
    property int highScore: 0
    property int lives: 3
    property int level: 1
    property string gameState: "ready"

    color: themeBg

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) themeBg = data.bg;
        if (data.fg) themeFg = data.fg;
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
        if (name) currentThemeName = name;
        gameCanvas.requestPaint();
    }

    function playSound(name) {
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
        if (!isMuted) playSound("click");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function startNewGame() {
        Engine.resetGame();
        root.gameState = "playing";
        root.score = Engine.score;
        root.lives = Engine.lives;
        root.level = Engine.level;
        gameCanvas.requestPaint();
        soundToast.show("CHOMP TIME");
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
            console.log("Screenshot saved successfully to " + shotPath);
            root.screenshotSaved(shotPath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    Component.onCompleted: {
        Engine.init(28, 31);
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.highScore = settingsManager.getBestScore();
        }
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg

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
                    text: "🟡 ByteMan"
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

        Column {
            id: mainLayout
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : parent.top
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

        // 1. HEADER (Title + Stat Badges)
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            width: parent.width
            height: root.isTiledDesktopMode ? 0 : 52

            Text {
                id: gameTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "ByteMan"
                font.family: root.monoFontFamily
                font.pixelSize: 32
                font.bold: true
                color: root.themeAccent
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // SCORE BADGE
                Rectangle {
                    width: 82
                    height: 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCORE"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // BEST BADGE
                Rectangle {
                    width: 82
                    height: 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BEST"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.highScore.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }
            }
        }

        // 2. SUBHEADER (Controls & Actions)
        Item {
            id: subheaderItem
            width: parent.width
            height: 34

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Lives Display
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: Math.max(0, root.lives - 1)
                        Canvas {
                            width: 16
                            height: 16
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = root.themeAccent;
                                ctx.beginPath();
                                ctx.arc(8, 8, 7, 0.25 * Math.PI, 1.75 * Math.PI, false);
                                ctx.lineTo(8, 8);
                                ctx.fill();
                            }
                        }
                    }
                }

                // Fruit Badge
                Rectangle {
                    width: 36
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var fruits = ["🍒", "🍓", "🍑", "🍎", "🍈", "🛸", "🔔", "🔑"];
                            var idx = 0;
                            if (root.level === 1) idx = 0;
                            else if (root.level === 2) idx = 1;
                            else if (root.level <= 4) idx = 2;
                            else if (root.level <= 6) idx = 3;
                            else if (root.level <= 8) idx = 4;
                            else if (root.level <= 10) idx = 5;
                            else if (root.level <= 12) idx = 6;
                            else idx = 7;
                            return fruits[idx];
                        }
                        font.pixelSize: 14
                    }
                }
            }

            readonly property bool isCrowded: subheaderItem.width < 500

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: subheaderItem.isCrowded ? 6 : 8

                // Help Button
                Rectangle {
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    height: 32
                    radius: 8
                    color: helpMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "?"
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeFg
                        }
                        Text {
                            text: "How to Play"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeFg
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHelp = !root.showHelp;
                            root.playSound("click");
                        }
                    }
                }

                // Mute Toggle
                Rectangle {
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    height: 32
                    radius: 8
                    color: muteMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.isMuted ? "🔇" : "🔊"
                            font.pixelSize: 13
                        }
                        Text {
                            text: root.isMuted ? "Muted" : "Sound"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeFg
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
                    width: subheaderItem.isCrowded ? 32 : (restartRow.implicitWidth + 18)
                    height: 32
                    radius: 8
                    color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent

                    Row {
                        id: restartRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔄"
                            font.pixelSize: 13
                            visible: subheaderItem.isCrowded
                        }
                        Text {
                            text: "Restart (R)"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeBtnFg
                            visible: !subheaderItem.isCrowded
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.startNewGame();
                            root.playSound("click");
                        }
                    }
                }
            }
        }

        // 3. BOARD CONTAINER
        Rectangle {
            id: boardContainer
            width: parent.width
            height: parent.height - (root.isTiledDesktopMode ? 46 : (headerItem.height + subheaderItem.height + 20))
            radius: 12
            color: root.themeBoardBg
            border.color: root.themeBorder
            border.width: 1
            clip: true

            Canvas {
                id: gameCanvas
                anchors.centerIn: parent
                // Scale 28 cols x 31 rows with aspect ratio
                width: Math.min(parent.width - 16, (parent.height - 16) * (28.0 / 31.0))
                height: width * (31.0 / 28.0)

                property real tileW: width / 28.0
                property real tileH: height / 31.0

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var tw = tileW;
                    var th = tileH;

                    // 1. Draw Maze Walls
                    ctx.lineWidth = Math.max(1.8, tw * 0.18);
                    ctx.strokeStyle = Qt.rgba(root.themeBorder.r, root.themeBorder.g, root.themeBorder.b, 0.95);
                    ctx.fillStyle = Qt.rgba(root.themeBorder.r, root.themeBorder.g, root.themeBorder.b, 0.25);

                    for (var r = 0; r < Engine.ROWS; r++) {
                        for (var c = 0; c < Engine.COLS; c++) {
                            var cell = Engine.maze[r] ? Engine.maze[r][c] : ' ';
                            var px = c * tw;
                            var py = r * th;

                            if (cell === 'W') {
                                ctx.fillStyle = Qt.rgba(root.themeCardBg.r, root.themeCardBg.g, root.themeCardBg.b, 0.85);
                                ctx.fillRect(px, py, tw, th);

                                // Clean boundary strokes facing paths
                                ctx.strokeStyle = root.themeBorder;
                                ctx.lineWidth = 1.6;
                                if (r === 0 || (Engine.maze[r-1] && Engine.maze[r-1][c] !== 'W')) {
                                    ctx.beginPath(); ctx.moveTo(px, py + 0.5); ctx.lineTo(px + tw, py + 0.5); ctx.stroke();
                                }
                                if (r === Engine.ROWS - 1 || (Engine.maze[r+1] && Engine.maze[r+1][c] !== 'W')) {
                                    ctx.beginPath(); ctx.moveTo(px, py + th - 0.5); ctx.lineTo(px + tw, py + th - 0.5); ctx.stroke();
                                }
                                if (c === 0 || Engine.maze[r][c-1] !== 'W') {
                                    ctx.beginPath(); ctx.moveTo(px + 0.5, py); ctx.lineTo(px + 0.5, py + th); ctx.stroke();
                                }
                                if (c === Engine.COLS - 1 || Engine.maze[r][c+1] !== 'W') {
                                    ctx.beginPath(); ctx.moveTo(px + tw - 0.5, py); ctx.lineTo(px + tw - 0.5, py + th); ctx.stroke();
                                }
                            } else if (cell === 'G') {
                                // Ghost Door
                                ctx.strokeStyle = "#FF88AA";
                                ctx.lineWidth = 2.0;
                                ctx.beginPath();
                                ctx.moveTo(px, py + th * 0.5);
                                ctx.lineTo(px + tw, py + th * 0.5);
                                ctx.stroke();
                            } else if (cell === '.') {
                                // Pellet
                                ctx.fillStyle = root.themeAccent;
                                ctx.beginPath();
                                ctx.arc(px + tw * 0.5, py + th * 0.5, tw * 0.15, 0, Math.PI * 2);
                                ctx.fill();
                            } else if (cell === '*') {
                                // Energizer
                                var pulse = 0.5 + 0.5 * Math.sin(Engine.globalTimer * 0.18);
                                ctx.fillStyle = root.themeAccent;
                                ctx.beginPath();
                                ctx.arc(px + tw * 0.5, py + th * 0.5, tw * (0.32 + 0.08 * pulse), 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }
                    }

                    // 2. Draw ByteMan
                    if (Engine.player) {
                        var bx = (Engine.player.x + 0.5) * tw;
                        var by = (Engine.player.y + 0.5) * th;
                        var brad = Math.min(tw, th) * 0.65;

                        var baseAngle = 0;
                        if (Engine.player.dir === Engine.DIR.UP) baseAngle = 1.5 * Math.PI;
                        else if (Engine.player.dir === Engine.DIR.DOWN) baseAngle = 0.5 * Math.PI;
                        else if (Engine.player.dir === Engine.DIR.LEFT) baseAngle = Math.PI;
                        else if (Engine.player.dir === Engine.DIR.RIGHT) baseAngle = 0;

                        var mouth = Engine.player.chomp * Math.PI;

                        ctx.fillStyle = root.themeAccent;
                        ctx.beginPath();
                        ctx.arc(bx, by, brad, baseAngle + mouth, baseAngle + 2 * Math.PI - mouth, false);
                        ctx.lineTo(bx, by);
                        ctx.fill();
                    }

                    // 3. Draw Fruit Bonus
                    if (Engine.fruit) {
                        var fx = (Engine.fruit.x + 0.5) * tw;
                        var fy = (Engine.fruit.y + 0.5) * th;
                        var frad = Math.min(tw, th) * 0.7;

                        // Soft pulsing aura
                        var fPulse = 0.5 + 0.5 * Math.sin(Engine.globalTimer * 0.2);
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12 + 0.08 * fPulse);
                        ctx.beginPath();
                        ctx.arc(fx, fy, frad * 1.3, 0, Math.PI * 2);
                        ctx.fill();

                        ctx.save();
                        ctx.font = Math.round(frad * 1.5) + "px sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(Engine.fruit.symbol, fx, fy + 1);
                        ctx.restore();
                    }

                    // 4. Draw Ghosts
                    for (var g = 0; g < Engine.ghosts.length; g++) {
                        var gh = Engine.ghosts[g];
                        var gx = (gh.x + 0.5) * tw;
                        var gy = (gh.y + 0.5) * th;
                        var grad = Math.min(tw, th) * 0.65;

                        var gColor = gh.color;
                        if (gh.state === "frightened" && Engine.frightenedTimer > 0) {
                            // Flash white in last 2.5 seconds (150 frames)
                            var flash = Engine.frightenedTimer < 150 && (Math.floor(Engine.frightenedTimer / 10) % 2 === 0);
                            gColor = flash ? "#FFFFFF" : "#3366FF";
                        }

                        if (gh.state !== "eyes") {
                            // Ghost Body (Dome top + Wavy skirt)
                            ctx.fillStyle = gColor;
                            ctx.beginPath();
                            ctx.arc(gx, gy - grad * 0.1, grad, Math.PI, 0, false);
                            ctx.lineTo(gx + grad, gy + grad * 0.9);

                            // 3 Bottom waves
                            var step = (grad * 2) / 3;
                            var waveOffset = Math.sin(Engine.globalTimer * 0.25) * (grad * 0.15);
                            ctx.lineTo(gx + grad - step * 0.5, gy + grad * 0.6 + waveOffset);
                            ctx.lineTo(gx + grad - step, gy + grad * 0.9);
                            ctx.lineTo(gx + grad - step * 1.5, gy + grad * 0.6 - waveOffset);
                            ctx.lineTo(gx - grad, gy + grad * 0.9);
                            ctx.closePath();
                            ctx.fill();
                        }

                        // Ghost Eyes
                        var eyeOffX = 0, eyeOffY = 0;
                        if (gh.dir === Engine.DIR.LEFT) eyeOffX = -grad * 0.2;
                        else if (gh.dir === Engine.DIR.RIGHT) eyeOffX = grad * 0.2;
                        else if (gh.dir === Engine.DIR.UP) eyeOffY = -grad * 0.2;
                        else if (gh.dir === Engine.DIR.DOWN) eyeOffY = grad * 0.2;

                        // Whites
                        ctx.fillStyle = "#FFFFFF";
                        ctx.beginPath();
                        ctx.arc(gx - grad * 0.35 + eyeOffX * 0.5, gy - grad * 0.15 + eyeOffY * 0.5, grad * 0.30, 0, Math.PI * 2);
                        ctx.arc(gx + grad * 0.35 + eyeOffX * 0.5, gy - grad * 0.15 + eyeOffY * 0.5, grad * 0.30, 0, Math.PI * 2);
                        ctx.fill();

                        // Pupils
                        ctx.fillStyle = (gh.state === "frightened") ? "#FFCC00" : "#111133";
                        ctx.beginPath();
                        ctx.arc(gx - grad * 0.35 + eyeOffX, gy - grad * 0.15 + eyeOffY, grad * 0.16, 0, Math.PI * 2);
                        ctx.arc(gx + grad * 0.35 + eyeOffX, gy - grad * 0.15 + eyeOffY, grad * 0.16, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }

            // GAME OVER OVERLAY
            Rectangle {
                id: gameOverOverlay
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.78)
                visible: root.gameState === "gameover"
                z: 50
                radius: 12

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "GAME OVER"
                        font.family: root.monoFontFamily
                        font.pixelSize: 28
                        font.bold: true
                        color: "#FF5555"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Final Score: " + root.score
                        font.family: root.monoFontFamily
                        font.pixelSize: 16
                        color: root.themeFg
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 140
                        height: 40
                        radius: 8
                        color: root.themeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "PLAY AGAIN"
                            font.family: root.monoFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.themeBtnFg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startNewGame()
                        }
                    }
                }
            }

            // READY START PROMPT
            Rectangle {
                anchors.centerIn: parent
                width: 180
                height: 38
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.75)
                border.color: root.themeAccent
                border.width: 1
                visible: root.gameState === "ready" && !root.splashEnabled

                Text {
                    anchors.centerIn: parent
                    text: "PRESS ANY KEY TO START"
                    font.family: root.monoFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }
            }
        }
    }
}

    // Main 60 FPS Game Loop
    Timer {
        id: loopTimer
        interval: 16
        repeat: true
        running: !root.splashEnabled && !root.showHelp
        onTriggered: {
            Engine.update({
                onScoreChanged: function(s) {
                    root.score = s;
                    if (s > root.highScore) {
                        root.highScore = s;
                        if (typeof settingsManager !== "undefined" && settingsManager) {
                            settingsManager.setBestScore(root.highScore);
                        }
                    }
                },
                onLivesChanged: function(l) { root.lives = l; },
                onLevelChanged: function(lv) {
                    root.level = lv;
                    soundToast.show("ROUND " + lv + " CLEARED!");
                },
                onFruitEaten: function(name, pts) {
                    soundToast.show("+" + pts + " " + name.toUpperCase() + "!");
                },
                onGameOver: function(s) { root.gameState = "gameover"; },
                onSound: function(snd) { root.playSound(snd); }
            });
            root.gameState = Engine.gameState;
            root.score = Engine.score;
            root.lives = Engine.lives;
            gameCanvas.requestPaint();
        }
    }

    // Keyboard Input
    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (root.splashEnabled) return;

            if (event.key === Qt.Key_R) {
                root.startNewGame();
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

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            // Directional Input (WASD / Arrows / Vim HJKL)
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.setNextDirection(Engine.DIR.LEFT);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.setNextDirection(Engine.DIR.RIGHT);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                Engine.setNextDirection(Engine.DIR.UP);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                Engine.setNextDirection(Engine.DIR.DOWN);
                event.accepted = true;
            }
        }
    }

    // HELP MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: root.showHelp
        z: 90

        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 420)
            height: 310
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    text: "How to Play ByteMan"
                    font.family: root.monoFontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "• Steer: W/A/S/D, Arrows, or Vim H/J/K/L\n• Chomp all dots in the circuit maze\n• Grab flashing Energizers to turn ghosts blue and hunt them down for cascading combo scores!\n• Aka (Red) gives chase, Momo (Pink) ambushes, Mizu (Cyan) flanks, and Daidai (Orange) wanders.\n• Shift+F for Full/Compact View, R to Restart, M to toggle sound."
                    font.family: root.monoFontFamily
                    font.pixelSize: 12
                    color: root.themeFg
                    lineHeight: 1.3
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 100
                    height: 32
                    radius: 6
                    color: root.themeAccent

                    Text {
                        anchors.centerIn: parent
                        text: "GOT IT"
                        font.family: root.monoFontFamily
                        font.pixelSize: 11
                        font.bold: true
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
                    font.pixelSize: 10
                    color: root.themeSubtext
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.75
                }
            }
        }
    }

    // SOUND TOAST
    Rectangle {
        id: soundToast
        property alias text: toastLabel.text
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastLabel.implicitWidth + 24
        height: 30
        radius: 15
        color: Qt.rgba(0, 0, 0, 0.78)
        border.color: root.themeAccent
        border.width: 1
        opacity: 0
        z: 80

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastLabel
            anchors.centerIn: parent
            font.family: root.monoFontFamily
            font.pixelSize: 11
            font.bold: true
            color: root.themeAccent
        }

        Timer {
            id: toastTimer
            interval: 1400
            onTriggered: soundToast.opacity = 0
        }

        function show(msg) {
            text = msg;
            opacity = 1;
            toastTimer.restart();
        }
    }

    // Canonical Retro Startup Sequence
    SplashScreen {
        id: splashScreen
    }
}
