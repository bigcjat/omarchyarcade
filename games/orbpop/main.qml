import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 720
    minimumWidth: 360
    minimumHeight: 500
    title: currentThemeName.length > 0 ? "OrbPop • " + currentThemeName : "OrbPop"

    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property bool isDarkMode: colorLuminance(themeBg) < 0.5
    property color themeCardHover: isDarkMode ? "#313244" : "#f1f5f9"

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
    property int nextColor: 2
    property int level: 1
    property string gameState: "playing"

    color: themeBg

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#89b4fa";
        var c0 = data.color0 || "#1e1e2e";
        var c8 = data.color8 || data.color0 || "#313244";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = "#11111b";
            themeCardBg = "#ffffff";
            themeCardHover = "#f1f5f9";
            themeSubtext = "#6c6f85";
            themeBorder = Qt.rgba(0, 0, 0, 0.12);
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeCardHover = "#313244";
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }

        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
        if (name) currentThemeName = name;
        if (typeof gameCanvas !== "undefined" && gameCanvas) gameCanvas.requestPaint();
    }

    function cycleTheme() {
        var nextIsLight = (root.isDarkMode);
        var tData = nextIsLight ? {
            background: "#eff1f5",
            foreground: "#4c4f69",
            accent: "#1e66f5",
            cardBg: "#ffffff",
            boardBg: "#11111b",
            border: "#ccd0da",
            subtext: "#6c6f85"
        } : {
            background: "#181825",
            foreground: "#cdd6f4",
            accent: "#89b4fa",
            cardBg: "#1e1e2e",
            boardBg: "#11111b",
            border: "#313244",
            subtext: "#a6adc8"
        };
        applyTheme(tData, nextIsLight ? "Omarchy Light" : "Omarchy Dark");
        soundToast.show("🎨 " + (nextIsLight ? "Light Mode" : "Dark Mode"));
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
        Engine.init(gameCanvas.width, gameCanvas.height);
        root.gameState = "playing";
        root.level = Engine.level;
        root.score = Engine.score;
        root.nextColor = Engine.nextOrbColor;
        gameCanvas.requestPaint();
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
        var w = gameCanvas.width > 50 ? gameCanvas.width : 360;
        var h = gameCanvas.height > 50 ? gameCanvas.height : 500;
        Engine.init(w, h);
        root.nextColor = Engine.nextOrbColor;
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
                    text: "🔮 OrbPop"
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

        // =====================================================================
        // HEADER BAR BACKGROUND (Adapts to themeBg flush across top)
        // =====================================================================
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: (headerItem.visible ? headerItem.y + headerItem.height + (subheaderItem.visible ? subheaderItem.height + 20 : 12) : 0)
            color: root.themeBg
            z: 10
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
            height: visible ? 52 : 0
            z: 20

            Text {
                id: gameTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "OrbPop"
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
            z: 20

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Next Orb Badge
                Rectangle {
                    width: 76
                    height: 32
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "NEXT"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: {
                                var cols = ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7"];
                                return cols[(root.nextColor - 1) % cols.length] || "#89b4fa";
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Level Badge
                Rectangle {
                    width: 58
                    height: 32
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "LVL"
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.themeSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.level.toString()
                            font.family: root.monoFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
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
                    id: helpBtn
                    width: subheaderItem.isCrowded ? 32 : (helpRow.implicitWidth + 18)
                    height: 32
                    radius: 8
                    color: helpMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
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
                            color: root.themeAccent
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
                    id: muteBtn
                    width: subheaderItem.isCrowded ? 32 : (muteRow.implicitWidth + 18)
                    height: 32
                    radius: 8
                    color: muteMouse.containsMouse ? root.themeCardHover : root.themeCardBg
                    border.color: muteMouse.containsMouse ? root.themeAccent : root.themeBorder
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
                    id: restartBtn
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

        // =====================================================================
        // 3. BOARD CONTAINER (Flush Edge-to-Edge)
        // =====================================================================
        Rectangle {
            id: boardContainer
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerBar.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            anchors.left: parent.left
            anchors.right: parent.right
            color: root.themeBoardBg
            border.color: "transparent"
            border.width: 0
            radius: 0
            clip: true

                Canvas {
                    id: gameCanvas
                    anchors.centerIn: parent
                    property real aspect: 0.68
                    width: Math.min(parent.width - 24, (parent.height - 24) * aspect)
                    height: width / aspect

                    onWidthChanged: {
                        if (width > 50 && height > 50) {
                            Engine.init(width, height);
                            requestPaint();
                        }
                    }
                    onHeightChanged: {
                        if (width > 50 && height > 50) {
                            Engine.init(width, height);
                            requestPaint();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var rad = Engine.bubbleRadius;

                        // 1. Danger Line
                        var dangerY = rad + Engine.DANGER_ROW * Engine.rowHeight;
                        ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.4);
                        ctx.lineWidth = 1.5;
                        ctx.setLineDash([6, 6]);
                        ctx.beginPath();
                        ctx.moveTo(0, dangerY);
                        ctx.lineTo(width, dangerY);
                        ctx.stroke();
                        ctx.setLineDash([]);

                        // 2. Trajectory Laser Guide
                        if (Engine.gameState === "playing" && !Engine.projectile) {
                            var pts = Engine.getTrajectoryPoints();
                            if (pts.length > 1) {
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.4)";
                                ctx.lineWidth = 1.8;
                                ctx.setLineDash([4, 6]);
                                ctx.beginPath();
                                ctx.moveTo(pts[0].x, pts[0].y);
                                for (var pi = 1; pi < pts.length; pi++) {
                                    ctx.lineTo(pts[pi].x, pts[pi].y);
                                }
                                ctx.stroke();
                                ctx.setLineDash([]);
                            }
                        }

                        // 3. Draw Grid Bubbles
                        for (var r = 0; r < Engine.MAX_ROWS; r++) {
                            var cols = Engine.getColsForRow(r);
                            for (var c = 0; c < cols; c++) {
                                if (Engine.grid[r] && Engine.grid[r][c]) {
                                    var pos = Engine.getCellPos(r, c);
                                    drawBubble(ctx, pos.x, pos.y, rad * 0.94, Engine.grid[r][c].color);
                                }
                            }
                        }

                        // 4. Draw Falling Detached Orbs
                        for (var f = 0; f < Engine.fallingOrbs.length; f++) {
                            var fo = Engine.fallingOrbs[f];
                            drawBubble(ctx, fo.x, fo.y, fo.radius * 0.94, fo.color);
                        }

                        // 5. Draw Active Projectile
                        if (Engine.projectile) {
                            var proj = Engine.projectile;
                            drawBubble(ctx, proj.x, proj.y, proj.radius * 0.94, proj.color);
                        }

                        // 6. Draw Cannon Launcher (High-end arcade mechanical turret)
                        drawCannon(ctx, rad);

                        // 7. Draw Particles
                        for (var p = 0; p < Engine.particles.length; p++) {
                            var pt = Engine.particles[p];
                            ctx.fillStyle = pt.color;
                            ctx.globalAlpha = Math.max(0, pt.life);
                            ctx.beginPath();
                            ctx.arc(pt.x, pt.y, rad * pt.scale, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.globalAlpha = 1.0;
                        }
                    }

                    function drawCannon(ctx, rad) {
                        var cx = Engine.cannonX;
                        var cy = Engine.cannonY;
                        var angle = Engine.cannonAngle;

                        // 1. Cannon Turret Base (Fixed Mount & Rotary Ring)
                        ctx.save();

                        // Outer Swivel Gear / Base Plate
                        var baseR = rad * 1.25;
                        var baseGrad = ctx.createRadialGradient(cx - baseR * 0.25, cy - baseR * 0.25, baseR * 0.1, cx, cy, baseR);
                        baseGrad.addColorStop(0, "#363b48");
                        baseGrad.addColorStop(0.7, "#242831");
                        baseGrad.addColorStop(1, "#181a20");
                        ctx.fillStyle = baseGrad;
                        ctx.strokeStyle = "#4a5264";
                        ctx.lineWidth = 2.0;
                        ctx.beginPath();
                        ctx.arc(cx, cy, baseR, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.stroke();

                        // Mechanical Rivets on Base Ring
                        ctx.fillStyle = "#5c657a";
                        for (var i = 0; i < 8; i++) {
                            var rAngle = i * (Math.PI / 4.0);
                            var rx = cx + Math.cos(rAngle) * (baseR * 0.84);
                            var ry = cy + Math.sin(rAngle) * (baseR * 0.84);
                            ctx.beginPath();
                            ctx.arc(rx, ry, Math.max(1.5, rad * 0.08), 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // Inner Recessed Orb Cradle (Dark well)
                        var cradleR = rad * 0.96;
                        ctx.fillStyle = "#111317";
                        ctx.strokeStyle = "#2e333e";
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.arc(cx, cy, cradleR, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.stroke();

                        ctx.restore();

                        // 2. Rotating Launcher Barrel
                        ctx.save();
                        ctx.translate(cx, cy);
                        ctx.rotate(angle);

                        var bw = rad * 1.1;
                        var bh = rad * 1.55;
                        var bx = -bw * 0.5;
                        var by = -rad * 1.85;

                        // Barrel Main Body with Linear Metallic Shading
                        var barrelGrad = ctx.createLinearGradient(bx, 0, bx + bw, 0);
                        barrelGrad.addColorStop(0, "#252932");
                        barrelGrad.addColorStop(0.25, "#434a58");
                        barrelGrad.addColorStop(0.65, "#2f3440");
                        barrelGrad.addColorStop(1, "#1b1d24");
                        ctx.fillStyle = barrelGrad;
                        ctx.strokeStyle = "#505869";
                        ctx.lineWidth = 1.5;

                        ctx.beginPath();
                        var lipR = Math.max(2, rad * 0.12);
                        // Beveled / Rounded Barrel Tube
                        ctx.moveTo(bx + lipR, by);
                        ctx.lineTo(bx + bw - lipR, by);
                        ctx.quadraticCurveTo(bx + bw, by, bx + bw, by + lipR);
                        ctx.lineTo(bx + bw, by + bh);
                        ctx.lineTo(bx, by + bh);
                        ctx.lineTo(bx, by + lipR);
                        ctx.quadraticCurveTo(bx, by, bx + lipR, by);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // Reinforced Muzzle Collar at tip
                        var collarH = rad * 0.32;
                        var collarW = bw * 1.08;
                        var collarX = -collarW * 0.5;
                        var collarY = by;
                        var collarGrad = ctx.createLinearGradient(collarX, 0, collarX + collarW, 0);
                        collarGrad.addColorStop(0, "#333845");
                        collarGrad.addColorStop(0.3, "#5a6375");
                        collarGrad.addColorStop(0.7, "#3d4352");
                        collarGrad.addColorStop(1, "#22252e");
                        ctx.fillStyle = collarGrad;
                        ctx.strokeStyle = "#636d82";
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.rect(collarX, collarY, collarW, collarH);
                        ctx.fill();
                        ctx.stroke();

                        // Muzzle Aperture (Recessed dark opening where bubble fires from)
                        ctx.fillStyle = "#0c0d11";
                        ctx.beginPath();
                        ctx.ellipse(0, collarY + 1.5, bw * 0.38, collarH * 0.3, 0, 0, Math.PI * 2);
                        ctx.fill();

                        // Glowing Aim Sight / Centerline Indicator
                        ctx.strokeStyle = Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.85);
                        ctx.lineWidth = 2.0;
                        ctx.beginPath();
                        ctx.moveTo(0, by + collarH + 3);
                        ctx.lineTo(0, by + bh - 4);
                        ctx.stroke();

                        // Aim Notch at muzzle
                        ctx.fillStyle = root.themeAccent;
                        ctx.beginPath();
                        ctx.arc(0, collarY + collarH * 0.5, Math.max(1.8, rad * 0.09), 0, Math.PI * 2);
                        ctx.fill();

                        ctx.restore();

                        // 3. Loaded Orb inside Cradle
                        if (!Engine.projectile) {
                            drawBubble(ctx, cx, cy, rad * 0.85, Engine.currentOrbColor);
                        }

                        // Retaining Rim Arc in front of the orb for 3D depth
                        ctx.save();
                        ctx.strokeStyle = "rgba(74, 82, 100, 0.65)";
                        ctx.lineWidth = 2.0;
                        ctx.beginPath();
                        ctx.arc(cx, cy, rad * 0.94, Math.PI * 0.2, Math.PI * 0.8);
                        ctx.stroke();
                        ctx.restore();
                    }

                    function drawBubble(ctx, cx, cy, radius, colorIdx) {
                        var colors = [
                            { base: "#f38ba8", light: "#ffb3c6", dark: "#d85375" }, // Red
                            { base: "#a6e3a1", light: "#c2f5bd", dark: "#7dc278" }, // Green
                            { base: "#89b4fa", light: "#b8d5fc", dark: "#5b8ee8" }, // Blue
                            { base: "#f9e2af", light: "#fff6d9", dark: "#e0be75" }, // Yellow
                            { base: "#cba6f7", light: "#e4cdfc", dark: "#a678df" }  // Purple
                        ];

                        var col = colors[(colorIdx - 1) % colors.length] || colors[0];

                        // Shaded Radial Sphere
                        var grad = ctx.createRadialGradient(cx - radius * 0.3, cy - radius * 0.35, radius * 0.1, cx, cy, radius);
                        grad.addColorStop(0, col.light);
                        grad.addColorStop(0.65, col.base);
                        grad.addColorStop(1, col.dark);

                        ctx.fillStyle = grad;
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                        ctx.fill();

                        // Gloss Specular Sheen
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.65);
                        ctx.beginPath();
                        ctx.arc(cx - radius * 0.28, cy - radius * 0.32, radius * 0.25, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    // Mouse Aiming & Shooting
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.CrossCursor
                        onPositionChanged: function(mouse) {
                            Engine.setCannonAngleFromMouse(mouse.x, mouse.y);
                        }
                        onClicked: function(mouse) {
                            Engine.setCannonAngleFromMouse(mouse.x, mouse.y);
                            shoot();
                        }
                    }
                }

                // GAME OVER OVERLAY
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.85)
                    visible: root.gameState === "gameover"

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "GAME OVER"
                            font.family: root.monoFontFamily
                            font.pixelSize: 24
                            font.bold: true
                            color: root.themeAccent
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "FINAL SCORE: " + root.score
                            font.family: root.monoFontFamily
                            font.pixelSize: 15
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


            }
        }

    function shoot() {
        Engine.fireProjectile({
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
            onOrphansDropped: function(cnt) { soundToast.show("+" + (cnt * 100) + " BONUS!"); },
            onCeilingDescended: function() { soundToast.show("CEILING LOWERED"); },
            onLevelCleared: function(lvl, bonus) { soundToast.show("LEVEL " + lvl + " CLEARED!"); },
            onLevelChanged: function(lvl) {
                root.level = lvl;
                soundToast.show("LEVEL " + lvl);
            },
            onGameOver: function(s) { root.gameState = "gameover"; }
        });
        root.nextColor = Engine.nextOrbColor;
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
                onSound: function(snd) { root.playSound(snd); },
                onOrphansDropped: function(cnt) { soundToast.show("+" + (cnt * 100) + " BONUS!"); },
                onCeilingDescended: function() { soundToast.show("CEILING LOWERED"); },
                onLevelCleared: function(lvl, bonus) { soundToast.show("LEVEL " + lvl + " CLEARED!"); },
                onLevelChanged: function(lvl) {
                    root.level = lvl;
                    soundToast.show("LEVEL " + lvl);
                },
                onGameOver: function(s) { root.gameState = "gameover"; }
            });
            root.gameState = Engine.gameState;
            root.level = Engine.level;
            root.score = Engine.score;
            root.nextColor = Engine.nextOrbColor;
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
            if (event.key === Qt.Key_T) {
                root.cycleTheme();
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

            // Aiming
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                Engine.rotateCannon(-0.06);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                Engine.rotateCannon(0.06);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K || event.key === Qt.Key_Return) {
                root.shoot();
                event.accepted = true;
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
            height: Math.min(parent.height - 40, 500)
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "How to Play OrbPop"
                    font.family: root.monoFontFamily
                    font.pixelSize: 20
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Aim the rotating cannon and fire colored orbs. Form clusters of 3 or more matching orbs to pop them."
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    color: root.themeFg
                    lineHeight: 1.3
                }

                Text {
                    text: "TACTICS & BONUSES"
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "• Bank Shots: Bounce orbs off side walls to reach deep angles.\n• Orphan Drops: Popping an anchor drops all disconnected floating orbs for +100 bonus each!\n• Ceiling Descent: Every 5 misses shifts the ceiling down. Prevent orbs from reaching the danger line!"
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
                    text: "• Mouse: Move cursor to aim, Click to shoot.\n• Keys: A/D or Left/Right or Vim H/L to aim.\n• Fire: Space, W, Up arrow, or Enter.
• Full/Compact View: Shift+F (⇧F)
• Sound: Press M to toggle audio (Default: Muted)
• Restart: Press R to restart game."
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
