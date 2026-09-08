import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 600
    height: 720
    minimumWidth: 380
    minimumHeight: 500
    title: currentThemeName.length > 0 ? "GemSwap • " + currentThemeName : "GemSwap"

    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#cba6f7" // elegant gem amethyst accent
    property color themeBtnFg: "#11111b"

    property string currentThemeName: "Catppuccin"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool fullPlayfield: false
    readonly property bool isTiledDesktopMode: fullPlayfield || root.height < 520 || root.width < 440
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property int score: 0
    property int highScore: 0
    property int combo: 1
    property int level: 1
    property int levelScore: 0
    property int levelTargetScore: 1500
    property string gameState: "idle"
    property int cursorR: 3
    property int cursorC: 3

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
        if (data.accent) themeAccent = data.accent;
        if (name) currentThemeName = name;
        boardCanvas.requestPaint();
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

    function triggerHint() {
        if (Engine.gameState !== Engine.STATE.IDLE) return;
        var h = Engine.findHint();
        if (h) {
            Engine.activeHint = h;
            playSound("select");
            soundToast.show("💡 HINT READY");
        } else {
            soundToast.show("NO MOVES FOUND");
        }
        boardCanvas.requestPaint();
    }

    function startNewGame() {
        Engine.init();
        root.score = Engine.score;
        root.combo = Engine.combo;
        root.level = Engine.level;
        root.levelScore = Engine.levelScore;
        root.levelTargetScore = Engine.levelTargetScore;
        root.gameState = Engine.gameState;
        cursorR = 3;
        cursorC = 3;
        boardCanvas.requestPaint();
        soundToast.show("NEW GAME");
        playSound("dock");
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
        Engine.init();
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.highScore = settingsManager.getBestScore();
        }
    }

    // MAIN CONTAINER FOR OPAQUE SCREENSHOTS
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
                    text: "💎 GemSwap"
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
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // 1. HEADER (Title + Score Cards)
            Item {
                id: headerItem
                visible: !root.isTiledDesktopMode
                width: parent.width
                height: root.isTiledDesktopMode ? 0 : 52

                Text {
                    id: gameTitle
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GemSwap"
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

                    // BEST SCORE BADGE
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

            // 2. SUBHEADER (Controls & Info)
            Item {
                id: subheaderItem
                width: parent.width
                height: 34

                readonly property bool isCrowded: subheaderItem.width < 530
                readonly property bool isVeryCrowded: subheaderItem.width < 360

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Level Badge
                    Rectangle {
                        width: levelBadgeRow.implicitWidth + 14
                        height: 28
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1
                        Row {
                            id: levelBadgeRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: subheaderItem.isVeryCrowded ? "L" : "LVL"
                                font.family: root.monoFontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeSubtext
                            }
                            Text {
                                text: root.level.toString()
                                font.family: root.monoFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeAccent
                            }
                        }
                    }

                    // Combo Multiplier Badge
                    Rectangle {
                        visible: root.combo > 1
                        width: comboLabel.implicitWidth + 14
                        height: 28
                        radius: 6
                        color: root.themeAccent
                        Text {
                            id: comboLabel
                            anchors.centerIn: parent
                            text: subheaderItem.isCrowded ? (root.combo + "x") : (root.combo + "x COMBO!")
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeBtnFg
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: subheaderItem.isCrowded ? 6 : 8

                    // Hint Button
                    Rectangle {
                        width: subheaderItem.isCrowded ? 32 : (hintRow.implicitWidth + 18)
                        height: 32
                        radius: 8
                        color: hintMouse.containsMouse ? Qt.lighter(root.themeCardBg, 1.2) : root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            id: hintRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "💡"
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Hint (H)"
                                font.family: root.monoFontFamily
                                font.pixelSize: 12
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }

                        MouseArea {
                            id: hintMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.triggerHint()
                        }
                    }

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

                    // Mute Button
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
                            spacing: 5
                            Text {
                                text: root.isMuted ? "🔇" : "🔊"
                                font.pixelSize: 13
                            }
                            Text {
                                text: root.isMuted ? "Muted" : "Audio"
                                font.family: root.monoFontFamily
                                font.pixelSize: 12
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

            // 3. BOARD CONTAINER (8x8 Gem Grid)
            Rectangle {
                id: boardContainer
                width: parent.width
                height: parent.height - (root.isTiledDesktopMode ? 46 : (headerItem.height + subheaderItem.height + levelProgressBar.height + 30))
                radius: 12
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                Canvas {
                    id: boardCanvas
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, parent.height - 24)
                    height: width

                    property real cellSize: width / 8.0

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cs = cellSize;

                        // 1. Draw Grid Cells
                        for (var r = 0; r < 8; r++) {
                            for (var c = 0; c < 8; c++) {
                                var cx = c * cs;
                                var cy = r * cs;

                                // Checkerboard subtle card fill
                                ctx.fillStyle = ((r + c) % 2 === 0) ?
                                    Qt.rgba(root.themeCardBg.r, root.themeCardBg.g, root.themeCardBg.b, 0.45) :
                                    Qt.rgba(root.themeCardBg.r, root.themeCardBg.g, root.themeCardBg.b, 0.25);
                                
                                roundRect(ctx, cx + 2, cy + 2, cs - 4, cs - 4, 8);
                                ctx.fill();

                                ctx.strokeStyle = Qt.rgba(root.themeBorder.r, root.themeBorder.g, root.themeBorder.b, 0.35);
                                ctx.lineWidth = 1;
                                roundRect(ctx, cx + 2, cy + 2, cs - 4, cs - 4, 8);
                                ctx.stroke();
                            }
                        }

                        // 2. Draw Gems
                        for (var gr = 0; gr < 8; gr++) {
                            for (var gc = 0; gc < 8; gc++) {
                                var tile = Engine.getTile(gr, gc);
                                if (!tile) continue;

                                var drawX = tile.x * cs;
                                var drawY = (tile.visualY !== undefined ? tile.visualY : tile.y) * cs;

                                // Swapping interpolation
                                if (Engine.gameState === Engine.STATE.SWAPPING || Engine.gameState === Engine.STATE.REVERTING) {
                                    var sw = Engine.swapInfo;
                                    if (sw) {
                                        var p = sw.progress;
                                        if (sw.isRevert) p = 1.0 - p;
                                        if (gr === sw.r1 && gc === sw.c1) {
                                            drawX = (sw.c1 + (sw.c2 - sw.c1) * p) * cs;
                                            drawY = (sw.r1 + (sw.r2 - sw.r1) * p) * cs;
                                        } else if (gr === sw.r2 && gc === sw.c2) {
                                            drawX = (sw.c2 + (sw.c1 - sw.c2) * p) * cs;
                                            drawY = (sw.r2 + (sw.r1 - sw.r2) * p) * cs;
                                        }
                                    }
                                }

                                drawGem(ctx, drawX + cs * 0.5, drawY + cs * 0.5, cs * 0.38, tile.type, tile.special, tile.scale, tile.alpha);
                            }
                        }

                        // 3. Draw Clearing Gems
                        for (var cl = 0; cl < Engine.clearingTiles.length; cl++) {
                            var clItem = Engine.clearingTiles[cl];
                            if (clItem && clItem.tile) {
                                var clX = clItem.c * cs + cs * 0.5;
                                var clY = clItem.r * cs + cs * 0.5;
                                drawGem(ctx, clX, clY, cs * 0.38, clItem.tile.type, clItem.tile.special, clItem.scale, clItem.alpha);
                            }
                        }

                        // 4. Draw Selection Reticle
                        if (Engine.selectedTile) {
                            var selX = Engine.selectedTile.c * cs;
                            var selY = Engine.selectedTile.y ? Engine.selectedTile.y * cs : Engine.selectedTile.r * cs;
                            var pulse = 0.5 + 0.5 * Math.sin(Engine.globalTimer * 0.15);

                            ctx.strokeStyle = root.themeAccent;
                            ctx.lineWidth = 2.5 + pulse * 1.5;
                            roundRect(ctx, selX + 3, selY + 3, cs - 6, cs - 6, 8);
                            ctx.stroke();
                        }

                        // 5. Draw Active Hint Highlight
                        if (Engine.activeHint) {
                            var h = Engine.activeHint;
                            var hintCells = [{ r: h.r1, c: h.c1 }, { r: h.r2, c: h.c2 }];
                            var hPulse = 0.5 + 0.5 * Math.sin(Engine.globalTimer * 0.18);
                            ctx.save();
                            ctx.strokeStyle = Qt.rgba(1.0, 0.85, 0.2, 0.7 + hPulse * 0.3);
                            ctx.lineWidth = 3.0 + hPulse * 2.0;
                            for (var hi = 0; hi < hintCells.length; hi++) {
                                var hr = hintCells[hi].r;
                                var hc = hintCells[hi].c;
                                roundRect(ctx, hc * cs + 3, hr * cs + 3, cs - 6, cs - 6, 8);
                                ctx.stroke();
                            }
                            ctx.restore();
                        }

                        // 6. Draw Keyboard Cursor
                        var curX = root.cursorC * cs;
                        var curY = root.cursorR * cs;
                        ctx.strokeStyle = Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.6);
                        ctx.lineWidth = 1.5;
                        roundRect(ctx, curX + 1, curY + 1, cs - 2, cs - 2, 8);
                        ctx.stroke();

                        // 6. Draw Particles
                        for (var pi = 0; pi < Engine.particles.length; pi++) {
                            var pt = Engine.particles[pi];
                            ctx.fillStyle = pt.color;
                            ctx.globalAlpha = Math.max(0, pt.life);
                            ctx.beginPath();
                            ctx.arc(pt.x * cs, pt.y * cs, cs * pt.scale, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.globalAlpha = 1.0;
                        }
                    }

                    function roundRect(ctx, x, y, w, h, r) {
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + w - r, y);
                        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                        ctx.lineTo(x + w, y + h - r);
                        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                        ctx.lineTo(x + r, y + h);
                        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                        ctx.lineTo(x, y + r);
                        ctx.quadraticCurveTo(x, y, x + r, y);
                        ctx.closePath();
                    }

                    function drawGem(ctx, cx, cy, rad, type, special, scale, alpha) {
                        if (alpha <= 0) return;
                        ctx.save();
                        ctx.globalAlpha = Math.max(0, Math.min(1.0, alpha));
                        ctx.translate(cx, cy);
                        ctx.scale(scale, scale);

                        // Special Glow
                        if (special === Engine.SPECIAL.FLAME) {
                            var fPulse = 0.5 + 0.5 * Math.sin(Engine.globalTimer * 0.2);
                            ctx.strokeStyle = "#ff7a93";
                            ctx.lineWidth = 3.0 + fPulse * 2.0;
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 1.25, 0, Math.PI * 2);
                            ctx.stroke();
                        } else if (special === Engine.SPECIAL.STAR) {
                            ctx.strokeStyle = "#89b4fa";
                            ctx.lineWidth = 2.5;
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 1.2, 0, Math.PI * 2);
                            ctx.stroke();
                        } else if (special === Engine.SPECIAL.HYPER) {
                            // Rainbow swirl
                            var hAngle = Engine.globalTimer * 0.08;
                            var grad = ctx.createLinearGradient(-rad, -rad, rad, rad);
                            grad.addColorStop(0, "#f38ba8");
                            grad.addColorStop(0.33, "#f9e2af");
                            grad.addColorStop(0.66, "#a6e3a1");
                            grad.addColorStop(1, "#89b4fa");
                            ctx.fillStyle = grad;
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 1.05, 0, Math.PI * 2);
                            ctx.fill();
                            // Inner star
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath();
                            ctx.arc(0, 0, rad * 0.4, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.restore();
                            return;
                        }

                        // Curated calm, chill Omarchy palette with distinct silhouettes
                        var colors = [
                            { base: "#e06c75", light: "#f0989e", dark: "#b84852" }, // 1. Ruby: Soft Rose Square
                            { base: "#78b880", light: "#a1d4a8", dark: "#528c5a" }, // 2. Emerald: Sage Green Hexagon
                            { base: "#7aa2f7", light: "#a4c0fb", dark: "#5378c8" }, // 3. Sapphire: Cornflower Tall Diamond
                            { base: "#e5c07b", light: "#edd6a4", dark: "#b8934d" }, // 4. Topaz: Muted Amber Down-Triangle
                            { base: "#bb9af7", light: "#d4beff", dark: "#8e6cc8" }, // 5. Amethyst: Lavender Up-Triangle
                            { base: "#e08b68", light: "#f0ad92", dark: "#b36240" }, // 6. Amber: Terracotta Circle
                            { base: "#a9b1d6", light: "#cfd5f0", dark: "#7982a9", ice: "#89dceb" }  // 7. Diamond: Soft Icy Slate Octagon
                        ];

                        var cIdx = (type - 1) % colors.length;
                        if (cIdx < 0) cIdx = 0;
                        var col = colors[cIdx];

                        // Faceted Shapes per Type: EVERY gem has a 100% unique silhouette!
                        if (type === 1) {
                            // Ruby: Chamfered Square (Emerald cut flat box)
                            drawSquare(ctx, 0, 0, rad * 0.9, col);
                        } else if (type === 2) {
                            // Emerald: Hexagon (6-sided)
                            drawPolygon(ctx, 0, 0, rad * 1.02, 6, col);
                        } else if (type === 3) {
                            // Sapphire: Tall Diamond (slender rhombus)
                            drawDiamond(ctx, 0, 0, rad * 0.72, rad * 1.18, col);
                        } else if (type === 4) {
                            // Topaz: Downward-pointing Triangle (inverted pyramid)
                            drawTriangle(ctx, 0, 0, rad * 1.12, true, col);
                        } else if (type === 5) {
                            // Amethyst: Upward-pointing Triangle
                            drawTriangle(ctx, 0, 0, rad * 1.12, false, col);
                        } else if (type === 6) {
                            // Amber: Faceted Round Circle / Sphere
                            drawCircleGem(ctx, 0, 0, rad * 0.96, col);
                        } else {
                            // Diamond: Brilliant Octagon (8-sided sparkling white)
                            drawOctagon(ctx, 0, 0, rad * 1.05, col);
                        }

                        ctx.restore();
                    }

                    function drawSquare(ctx, x, y, s, col) {
                        var c = s * 0.28;
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        ctx.moveTo(x - s + c, y - s);
                        ctx.lineTo(x + s - c, y - s);
                        ctx.lineTo(x + s, y - s + c);
                        ctx.lineTo(x + s, y + s - c);
                        ctx.lineTo(x + s - c, y + s);
                        ctx.lineTo(x - s + c, y + s);
                        ctx.lineTo(x - s, y + s - c);
                        ctx.lineTo(x - s, y - s + c);
                        ctx.closePath();
                        ctx.fill();

                        // Dark bottom-right bevel
                        ctx.fillStyle = col.dark;
                        ctx.beginPath();
                        ctx.moveTo(x + s - c, y + s);
                        ctx.lineTo(x - s + c, y + s);
                        ctx.lineTo(x - s * 0.5, y + s * 0.5);
                        ctx.lineTo(x + s * 0.5, y + s * 0.5);
                        ctx.closePath();
                        ctx.fill();

                        // Highlight facet
                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.arc(x - s * 0.35, y - s * 0.35, s * 0.28, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    function drawPolygon(ctx, x, y, r, sides, col) {
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        for (var i = 0; i < sides; i++) {
                            var a = (i / sides) * Math.PI * 2 - Math.PI / 2;
                            var px = x + Math.cos(a) * r;
                            var py = y + Math.sin(a) * r;
                            if (i === 0) ctx.moveTo(px, py);
                            else ctx.lineTo(px, py);
                        }
                        ctx.closePath();
                        ctx.fill();

                        // Highlight facet
                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.arc(x - r * 0.25, y - r * 0.25, r * 0.28, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    function drawDiamond(ctx, x, y, rw, rh, col) {
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        ctx.moveTo(x, y - rh);
                        ctx.lineTo(x + rw, y);
                        ctx.lineTo(x, y + rh);
                        ctx.lineTo(x - rw, y);
                        ctx.closePath();
                        ctx.fill();

                        // Inner facet
                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.moveTo(x, y - rh * 0.6);
                        ctx.lineTo(x + rw * 0.6, y);
                        ctx.lineTo(x, y);
                        ctx.lineTo(x - rw * 0.6, y);
                        ctx.closePath();
                        ctx.fill();
                    }

                    function drawTriangle(ctx, x, y, r, inverted, col) {
                        var sign = inverted ? 1 : -1;
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        ctx.moveTo(x, y + sign * r);
                        ctx.lineTo(x + r * 0.9, y - sign * r * 0.6);
                        ctx.lineTo(x - r * 0.9, y - sign * r * 0.6);
                        ctx.closePath();
                        ctx.fill();

                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.arc(x, y - sign * r * 0.2, r * 0.25, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    function drawCircleGem(ctx, x, y, r, col) {
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, Math.PI * 2);
                        ctx.fill();

                        // Shading ring
                        ctx.strokeStyle = col.dark;
                        ctx.lineWidth = r * 0.16;
                        ctx.beginPath();
                        ctx.arc(x, y, r * 0.88, 0, Math.PI * 2);
                        ctx.stroke();

                        // Glossy reflection
                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.arc(x - r * 0.3, y - r * 0.3, r * 0.32, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    function drawOctagon(ctx, x, y, r, col) {
                        ctx.fillStyle = col.base;
                        ctx.beginPath();
                        for (var i = 0; i < 8; i++) {
                            var a = (i / 8) * Math.PI * 2 - Math.PI / 8;
                            var px = x + Math.cos(a) * r;
                            var py = y + Math.sin(a) * r;
                            if (i === 0) ctx.moveTo(px, py);
                            else ctx.lineTo(px, py);
                        }
                        ctx.closePath();
                        ctx.fill();

                        // Icy facet accent
                        ctx.fillStyle = col.ice || "#38bdf8";
                        ctx.beginPath();
                        ctx.moveTo(x, y + r * 0.5);
                        ctx.lineTo(x - r * 0.4, y);
                        ctx.lineTo(x + r * 0.4, y);
                        ctx.closePath();
                        ctx.fill();

                        // Bright reflection
                        ctx.fillStyle = col.light;
                        ctx.beginPath();
                        ctx.arc(x - r * 0.25, y - r * 0.25, r * 0.3, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    // Mouse Interaction
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            var col = Math.floor(mouse.x / boardCanvas.cellSize);
                            var row = Math.floor(mouse.y / boardCanvas.cellSize);
                            root.cursorR = row;
                            root.cursorC = col;
                            Engine.trySelectOrSwap(row, col, {
                                onScoreChanged: function(s) {
                                    root.score = s;
                                    if (s > root.highScore) {
                                        root.highScore = s;
                                        if (typeof settingsManager !== "undefined" && settingsManager) {
                                            settingsManager.setBestScore(root.highScore);
                                        }
                                    }
                                },
                                onSound: function(snd) { root.playSound(snd); },
                                onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                            });
                        }
                    }
                }
            }

            // 4. LEVEL PROGRESS BAR
            Rectangle {
                id: levelProgressBar
                width: parent.width
                height: 26
                radius: 8
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                // Animated fill
                Rectangle {
                    id: levelProgressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width, Math.max(0, parent.width * (root.levelTargetScore > 0 ? (root.levelScore / root.levelTargetScore) : 0)))
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.darker(root.themeAccent, 1.25) }
                        GradientStop { position: 1.0; color: root.themeAccent }
                    }
                    Behavior on width { NumberAnimation { duration: 200 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "LEVEL " + root.level + "  •  " + root.levelScore + " / " + root.levelTargetScore + " PTS (" + Math.min(100, Math.floor(root.levelScore * 100 / Math.max(1, root.levelTargetScore))) + "%)"
                    font.family: root.monoFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: root.themeFg
                    style: Text.Outline
                    styleColor: Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.75)
                }
            }
        }
    }

    // Main 60 FPS Game Loop
    Timer {
        id: loopTimer
        interval: 16
        repeat: true
        running: !root.splashEnabled && !root.showHelp && root.gameState !== "gameover"
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
                onLevelChanged: function(lvl, bonus) {
                    root.level = lvl;
                    soundToast.show("LEVEL " + lvl + "! +" + bonus);
                },
                onGameOver: function(finalScore) {
                    root.gameState = "gameover";
                },
                onSound: function(snd) { root.playSound(snd); },
                onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
            });
            root.score = Engine.score;
            root.combo = Engine.combo;
            root.level = Engine.level;
            root.levelScore = Engine.levelScore;
            root.levelTargetScore = Engine.levelTargetScore;
            root.gameState = Engine.gameState;
            boardCanvas.requestPaint();
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

            if (event.key === Qt.Key_H) {
                root.triggerHint();
                event.accepted = true;
                return;
            }

            // Move cursor
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                if (Engine.selectedTile && (event.modifiers & Qt.ShiftModifier)) {
                    Engine.trySelectOrSwap(root.cursorR, root.cursorC - 1, {
                        onScoreChanged: function(s) { root.score = s; },
                        onSound: function(snd) { root.playSound(snd); },
                        onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                    });
                } else {
                    root.cursorC = Math.max(0, root.cursorC - 1);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                if (Engine.selectedTile && (event.modifiers & Qt.ShiftModifier)) {
                    Engine.trySelectOrSwap(root.cursorR, root.cursorC + 1, {
                        onScoreChanged: function(s) { root.score = s; },
                        onSound: function(snd) { root.playSound(snd); },
                        onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                    });
                } else {
                    root.cursorC = Math.min(7, root.cursorC + 1);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                if (Engine.selectedTile && (event.modifiers & Qt.ShiftModifier)) {
                    Engine.trySelectOrSwap(root.cursorR - 1, root.cursorC, {
                        onScoreChanged: function(s) { root.score = s; },
                        onSound: function(snd) { root.playSound(snd); },
                        onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                    });
                } else {
                    root.cursorR = Math.max(0, root.cursorR - 1);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                if (Engine.selectedTile && (event.modifiers & Qt.ShiftModifier)) {
                    Engine.trySelectOrSwap(root.cursorR + 1, root.cursorC, {
                        onScoreChanged: function(s) { root.score = s; },
                        onSound: function(snd) { root.playSound(snd); },
                        onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                    });
                } else {
                    root.cursorR = Math.min(7, root.cursorR + 1);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                Engine.trySelectOrSwap(root.cursorR, root.cursorC, {
                    onScoreChanged: function(s) { root.score = s; },
                    onSound: function(snd) { root.playSound(snd); },
                    onReshuffle: function() { soundToast.show("NO MOVES • SHUFFLING"); }
                });
                event.accepted = true;
            }
        }
    }

    // GAME OVER OVERLAY
    Rectangle {
        id: gameOverOverlay
        anchors.fill: parent
        color: Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.9)
        visible: root.gameState === "gameover"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 380)
            height: 250
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 14
                width: parent.width - 40

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO MORE MOVES"
                    font.family: root.monoFontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "GAME OVER"
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.themeSubtext
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 28

                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "FINAL SCORE"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.score.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeFg
                        }
                    }

                    Column {
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "LEVEL REACHED"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.level.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeAccent
                        }
                    }
                }

                Item { height: 4; width: 1 }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 140
                    height: 38
                    radius: 8
                    color: root.themeAccent

                    Text {
                        anchors.centerIn: parent
                        text: "Play Again (R)"
                        font.family: root.monoFontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeBtnFg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.startNewGame();
                            root.playSound("click");
                        }
                    }
                }
            }
        }
    }

    // HELP MODAL
    Rectangle {
        id: helpModal
        anchors.fill: parent
        color: Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.9)
        visible: root.showHelp
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 480)
            height: Math.min(parent.height - 40, 520)
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "How to Play GemSwap"
                    font.family: root.monoFontFamily
                    font.pixelSize: 20
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Swap adjacent gems to align 3 or more of the same gem color in a row or column to clear them and trigger cascades."
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    color: root.themeFg
                    lineHeight: 1.3
                }

                Text {
                    text: "SPECIAL GEMS & PROGRESSION"
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "• Match-4 (Flame Gem): Explodes in a 3x3 detonation.\n• Match-5 (Hyper Gem): Clears all gems of chosen color.\n• T/L Match (Star Gem): Blasts entire row and column.\n• Level Bar: Fill tube to advance level and earn bonus points."
                    font.family: root.monoFontFamily
                    font.pixelSize: 12
                    color: root.themeSubtext
                    lineHeight: 1.3
                }

                Text {
                    text: "CONTROLS"
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "• Mouse: Click gem to select, click neighbor to swap.\n• Keys: WASD / Arrows to navigate, Space to select.\n• Swap: Shift + Arrow or click adjacent gem.\n• Hint: Press H or click 💡 Hint for move suggestion.\n• Restart: Press R to reset board."
                    font.family: root.monoFontFamily
                    font.pixelSize: 12
                    color: root.themeSubtext
                    lineHeight: 1.3
                }

                Item { height: 10; width: 1 }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    height: 36
                    radius: 8
                    color: root.themeAccent

                    Text {
                        anchors.centerIn: parent
                        text: "Got It"
                        font.family: root.monoFontFamily
                        font.pixelSize: 13
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

    // HUD TOAST
    Rectangle {
        id: soundToast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastText.implicitWidth + 24
        height: 32
        radius: 16
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property alias text: toastText.text

        Text {
            id: toastText
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
