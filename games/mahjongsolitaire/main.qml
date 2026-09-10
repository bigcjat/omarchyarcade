import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import "MahjongEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 1120
    height: 800
    minimumWidth: 500
    minimumHeight: 400
    title: "Mahjong Solitaire"

    // =========================================================================
    // OMARCHY THEME TOKENS (Auto-synchronized from colors.toml)
    // =========================================================================
    property color themeBg: "#080a10"
    property color themeBoardBg: "#0c0f18"
    property color themeCardBg: "#121726"
    property color themeBorder: "#1e263c"
    property color themeFg: "#e2e8f0"
    property color themeSubtext: "#94a3b8"
    property color themeAccent: "#00F0FF"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#0a0c12" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE GAME STATE PROPERTIES
    // =========================================================================
    property string gameState: "ready"
    property int score: 0
    property int bestScore: 0
    property bool isMuted: false
    property bool soundEnabled: !isMuted
    property bool showHelp: false
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Match Pairs: Select matching pairs of identical free tiles.\n" +
                              "• Free Tile Rule: A tile is free if no tile rests on top of it and either its left or right side is unblocked.\n" +
                              "• Seasons & Flowers: Any season matches any season; any flower matches any flower.\n" +
                              "• 5 Depth Levels (L): L0 Blue, L1 Green, L2 Yellow, L3 Purple, L4 Red.\n" +
                              "• Camera Controls: 2-finger drag or A / D / W / S to orbit. V for top-down.\n" +
                              "• Shortcuts: Hint (H), Undo (U), Restart (R), Sound (M), Fullscreen (⇧F)."

    // Board & Gameplay State
    property string currentLayout: (typeof initialLayout !== "undefined" && initialLayout) ? initialLayout : "turtle"
    property var boardTiles: []
    property int selectedTileId: -1
    property var selectedTile: null
    property int hoveredTileId: -1
    property var hintPairIds: []
    property var undoStack: []
    property int matchesCount: 0
    property int comboStreak: 0
    property real lastMatchTime: 0
    property int gameTimeSeconds: 0
    property bool isPlaying: false
    property bool isWon: false
    property var particles: []

    // Camera & Depth Controls
    property real cameraPitch: -38
    property real cameraYaw: 40
    property real cameraDistance: 500
    property string viewMode: "3d" // "3d" or "overhead"
    property bool showLayerDepth: true

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#080a10";
        var fg = data.foreground || data.fg || "#e2e8f0";
        var accent = data.accent || "#00F0FF";
        var c0 = data.color0 || "#121726";
        var c8 = data.color8 || data.color0 || "#1e263c";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;
        themeCardBg = c0;
        themeBoardBg = Qt.darker(bg, 1.15);
        themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
        themeBtnBg = accent;
        themeBtnFg = colorLuminance(accent) > 0.5 ? "#0a0c12" : "#ffffff";
    }

    function playAudio(name) {
        if (!isMuted && typeof soundManager !== "undefined") {
            soundManager.playSound(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playAudio("tile_match");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function setViewMode(mode) {
        viewMode = mode;
        if (mode === "overhead") {
            cameraPitch = -89;
            cameraYaw = 0;
            cameraDistance = 440;
        } else {
            cameraPitch = -38;
            cameraYaw = 40;
            cameraDistance = 500;
        }
    }

    function rotateCameraYaw(deltaDeg) {
        viewMode = "3d";
        cameraYaw += deltaDeg;
    }

    function zoomCamera(deltaDist) {
        cameraDistance = Math.max(320, Math.min(850, cameraDistance + deltaDist));
    }

    function resetCamera() {
        setViewMode("3d");
    }

    function hexToRgb(hex) {
        var c = Qt.color(hex);
        return Math.floor(c.r * 255) + ", " + Math.floor(c.g * 255) + ", " + Math.floor(c.b * 255);
    }

    function captureScreenshot(filePath, shouldQuit) {
        mainContainer.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved to " + filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // =========================================================================
    // GAMEPLAY LOGIC
    // =========================================================================
    function startNewGame(layoutName) {
        if (layoutName) currentLayout = layoutName;
        selectedTileId = -1;
        selectedTile = null;
        hoveredTileId = -1;
        hintPairIds = [];
        undoStack = [];
        score = 0;
        matchesCount = 0;
        comboStreak = 0;
        lastMatchTime = 0;
        gameTimeSeconds = 0;
        isWon = false;
        isPlaying = true;
        particles = [];

        if (typeof settingsManager !== "undefined") {
            settingsManager.incrementGamesPlayed();
        }

        boardTiles = Engine.generateBoard(currentLayout);
        playAudio("tile_slide");
    }

    function handleTileClick(tile) {
        if (!tile || !tile.free || isWon) return;

        hintPairIds = [];

        if (!selectedTile) {
            // First tile selected
            selectedTile = tile;
            selectedTileId = tile.id;
            playAudio("tile_click");
            spawn3DClickWave(tile);
            return;
        }

        if (selectedTile.id === tile.id) {
            // Deselect same tile
            selectedTile = null;
            selectedTileId = -1;
            playAudio("tile_slide");
            return;
        }

        // Check if second tile matches
        if (Engine.canMatch(selectedTile, tile)) {
            // MATCH SUCCESS!
            var t1 = selectedTile;
            var t2 = tile;
            selectedTile = null;
            selectedTileId = -1;

            // Score & Streak calculation
            var now = gameTimer.elapsedSec;
            if (lastMatchTime > 0 && (now - lastMatchTime) <= 4.5) {
                comboStreak = Math.min(comboStreak + 1, 8);
            } else {
                comboStreak = 1;
            }
            lastMatchTime = now;

            var matchPoints = 100 * comboStreak;
            score += matchPoints;
            matchesCount++;

            // Push to undo stack
            undoStack.push({
                tileA: cloneTile(t1),
                tileB: cloneTile(t2),
                scoreDelta: matchPoints,
                streak: comboStreak
            });

            // Particles at both 3D tiles
            spawn3DMatchParticles(t1);
            spawn3DMatchParticles(t2);
            playAudio("tile_match");

            // Remove tiles from board
            removeTileFromBoard(t1.id);
            removeTileFromBoard(t2.id);

            // Recalculate freedom
            Engine.refreshTileFreedom(boardTiles);
            boardTiles = boardTiles.slice();

            // Check for victory
            if (boardTiles.length === 0) {
                isWon = true;
                isPlaying = false;
                playAudio("victory");
                if (typeof settingsManager !== "undefined") {
                    settingsManager.setBestScore(score);
                    settingsManager.setFastestTime(gameTimeSeconds);
                    settingsManager.incrementGamesWon();
                }
                spawnFireworks();
            }
        } else {
            // Incompatible tile: switch selection
            selectedTile = tile;
            selectedTileId = tile.id;
            playAudio("tile_click");
            spawn3DClickWave(tile);
        }
    }

    function cloneTile(t) {
        return {
            id: t.id,
            type: t.type,
            category: t.category,
            sprite: t.sprite,
            name: t.name,
            x: t.x,
            y: t.y,
            z: t.z,
            free: t.free
        };
    }

    function removeTileFromBoard(tileId) {
        var idx = -1;
        for (var i = 0; i < boardTiles.length; i++) {
            if (boardTiles[i].id === tileId) {
                idx = i;
                break;
            }
        }
        if (idx !== -1) {
            boardTiles.splice(idx, 1);
        }
    }

    function undoMove() {
        if (undoStack.length === 0 || isWon) return;
        var last = undoStack.pop();
        if (last) {
            score = Math.max(0, score - last.scoreDelta);
            matchesCount = Math.max(0, matchesCount - 1);
            comboStreak = 1;
            boardTiles.push(last.tileA);
            boardTiles.push(last.tileB);
            Engine.refreshTileFreedom(boardTiles);
            boardTiles = boardTiles.slice();
            selectedTile = null;
            selectedTileId = -1;
            hintPairIds = [];
            playAudio("tile_slide");
        }
    }

    function showHint() {
        if (boardTiles.length === 0 || isWon) return;
        var moves = Engine.findAvailableMoves(boardTiles);
        if (moves.length > 0) {
            var pair = moves[0];
            hintPairIds = [pair[0].id, pair[1].id];
            playAudio("hint");
            hintAnimTimer.restart();
        } else {
            playAudio("tile_click");
        }
    }

    function reshuffleBoard() {
        if (boardTiles.length <= 2 || isWon) return;
        playAudio("tile_slide");
        var activeSlots = [];
        var tileTypes = [];
        for (var i = 0; i < boardTiles.length; i++) {
            activeSlots.push({ x: boardTiles[i].x, y: boardTiles[i].y, z: boardTiles[i].z });
            tileTypes.push({
                type: boardTiles[i].type,
                category: boardTiles[i].category,
                sprite: boardTiles[i].sprite,
                name: boardTiles[i].name
            });
        }

        var newTiles = [];
        var workingSlots = activeSlots.slice();
        var pairs = [];
        for (var i = 0; i < tileTypes.length; i += 2) {
            pairs.push([tileTypes[i], tileTypes[i + 1]]);
        }
        Engine.shuffleArray(pairs);

        while (workingSlots.length > 0 && pairs.length > 0) {
            var freeIdxs = [];
            for (var i = 0; i < workingSlots.length; i++) {
                if (Engine.isTileFree(workingSlots[i], workingSlots)) freeIdxs.push(i);
            }
            if (freeIdxs.length < 2) break;

            var iA = freeIdxs[Math.floor(Math.random() * freeIdxs.length)];
            var sA = workingSlots[iA];
            workingSlots.splice(iA, 1);

            var freeIdxsB = [];
            for (var i = 0; i < workingSlots.length; i++) {
                if (Engine.isTileFree(workingSlots[i], workingSlots)) freeIdxsB.push(i);
            }
            if (freeIdxsB.length === 0) break;
            var iB = freeIdxsB[Math.floor(Math.random() * freeIdxsB.length)];
            var sB = workingSlots[iB];
            workingSlots.splice(iB, 1);

            var p = pairs.pop();
            var t1 = p[0];
            var t2 = p[1];
            t1.x = sA.x; t1.y = sA.y; t1.z = sA.z;
            t1.id = Math.floor(Math.random() * 999999);
            t1.free = false;

            t2.x = sB.x; t2.y = sB.y; t2.z = sB.z;
            t2.id = Math.floor(Math.random() * 999999);
            t2.free = false;

            newTiles.push(t1);
            newTiles.push(t2);
        }

        if (workingSlots.length === 0 && pairs.length === 0) {
            boardTiles = newTiles;
        } else {
            Engine.shuffleArray(activeSlots);
            for (var i = 0; i < boardTiles.length; i++) {
                boardTiles[i].x = activeSlots[i].x;
                boardTiles[i].y = activeSlots[i].y;
                boardTiles[i].z = activeSlots[i].z;
            }
        }

        selectedTile = null;
        selectedTileId = -1;
        hintPairIds = [];
        Engine.refreshTileFreedom(boardTiles);
        boardTiles = boardTiles.slice();
    }

    // =========================================================================
    // 3D -> 2D PARTICLE FX
    // =========================================================================
    function getTile3DPos(tile) {
        return Qt.vector3d((tile.x - 14.0) * 11.2, tile.z * 8.0 + 5.0, (tile.y - 8.0) * 15.2);
    }

    function spawn3DMatchParticles(tile) {
        var pos3d = getTile3DPos(tile);
        var pt2d = v3d.mapFrom3DScene(pos3d);
        var cx = pt2d.x;
        var cy = pt2d.y;
        var colors = [themeAccent, "#FFE500", "#10b981", "#f43f5e", "#a855f7"];
        var col = colors[Math.floor(Math.random() * colors.length)];

        for (var i = 0; i < 24; i++) {
            var angle = Math.random() * Math.PI * 2;
            var speed = 40 + Math.random() * 140;
            particles.push({
                x: cx,
                y: cy,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed - 25,
                size: 3 + Math.random() * 5,
                alpha: 1.0,
                color: col,
                life: 0.6 + Math.random() * 0.4
            });
        }
    }

    function spawn3DClickWave(tile) {
        var pos3d = getTile3DPos(tile);
        var pt2d = v3d.mapFrom3DScene(pos3d);
        var cx = pt2d.x;
        var cy = pt2d.y;
        for (var i = 0; i < 8; i++) {
            var angle = (i / 8) * Math.PI * 2;
            var speed = 35 + Math.random() * 40;
            particles.push({
                x: cx,
                y: cy,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                size: 2.5,
                alpha: 0.8,
                color: themeAccent,
                life: 0.35
            });
        }
    }

    function spawnFireworks() {
        var w = root.width;
        var h = root.height;
        for (var f = 0; f < 6; f++) {
            var cx = w * 0.2 + Math.random() * (w * 0.6);
            var cy = h * 0.2 + Math.random() * (h * 0.5);
            var colors = ["#00F0FF", "#FFE500", "#10b981", "#f43f5e", "#a855f7"];
            var col = colors[f % colors.length];
            for (var p = 0; p < 32; p++) {
                var angle = Math.random() * Math.PI * 2;
                var speed = 80 + Math.random() * 180;
                particles.push({
                    x: cx,
                    y: cy,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed,
                    size: 4 + Math.random() * 4,
                    alpha: 1.0,
                    color: col,
                    life: 1.2 + Math.random() * 0.6
                });
            }
        }
    }

    // =========================================================================
    // TIMERS
    // =========================================================================
    Timer {
        id: gameTimer
        interval: 1000
        running: isPlaying && !isWon
        repeat: true
        property int elapsedSec: 0
        onTriggered: {
            elapsedSec++;
            gameTimeSeconds = elapsedSec;
        }
    }

    property real hintGlowPulse: 0.0
    Timer {
        id: hintAnimTimer
        interval: 16
        running: hintPairIds.length > 0
        repeat: true
        property real phase: 0.0
        onTriggered: {
            phase += 0.12;
            hintGlowPulse = 0.5 + 0.5 * Math.sin(phase);
            if (phase > Math.PI * 6) {
                hintPairIds = [];
                phase = 0.0;
                running = false;
            }
        }
    }

    Timer {
        id: animTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (particles.length > 0) {
                var dt = 0.016;
                for (var i = particles.length - 1; i >= 0; i--) {
                    var p = particles[i];
                    p.x += p.vx * dt;
                    p.y += p.vy * dt;
                    p.vy += 65 * dt;
                    p.life -= dt;
                    p.alpha = Math.max(0.0, p.life);
                    if (p.life <= 0) {
                        particles.splice(i, 1);
                    }
                }
                particleCanvas.requestPaint();
            }
        }
    }

    // =========================================================================
    // UI LAYOUT
    // =========================================================================
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        // Keyboard Shortcuts (Intuitive WASD / Arrow / V / L / + / -)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_H) {
                showHint();
                event.accepted = true;
            } else if (event.key === Qt.Key_U || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Z)) {
                undoMove();
                event.accepted = true;
            } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                reshuffleBoard();
                event.accepted = true;
            } else if (event.key === Qt.Key_V) {
                setViewMode(viewMode === "3d" ? "overhead" : "3d");
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                showLayerDepth = !showLayerDepth;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                rotateCameraYaw(45);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                rotateCameraYaw(-45);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) {
                cameraPitch = Math.min(-15, cameraPitch + 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
                cameraPitch = Math.max(-89, cameraPitch - 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                zoomCamera(-50);
                event.accepted = true;
            } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
                zoomCamera(50);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                startNewGame(currentLayout);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                if (isWon) {
                    startNewGame(currentLayout);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                toggleMute();
                event.accepted = true;
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
            } else if (event.key === Qt.Key_1) {
                startNewGame("turtle");
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                startNewGame("fortress");
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                startNewGame("dragon");
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (root.showHelp) {
                    root.showHelp = false;
                } else if (selectedTile) {
                    selectedTile = null;
                    selectedTileId = -1;
                }
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
            z: 20

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

                // TILES LEFT Card
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
                            text: "TILES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: boardTiles.length.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

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
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.topMargin: visible ? 10 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: visible ? 34 : 0
            z: 20

            readonly property bool isCrowded: subheaderItem.width < 450

            // Left cluster (Help pill button)
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

            // Right cluster (Actions: Mute, View Mode, Restart)
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

                // View Mode Pill (Windowed vs Full Field)
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
                        onClicked: root.startNewGame(root.currentLayout)
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
                    text: "• TILES: " + boardTiles.length
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }

                Text {
                    text: "SCORE: " + root.score
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
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
                            soundToast.show("🔲 Standard Windowed View");
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
                    Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame(root.currentLayout)
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 3D VIEWPORT (Hardware-Accelerated QtQuick3D Scene)
        // ---------------------------------------------------------------------
        View3D {
            id: v3d
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            camera: camera

            environment: SceneEnvironment {
                backgroundMode: SceneEnvironment.Color
                clearColor: themeBg
                antialiasingMode: SceneEnvironment.MSAA
                antialiasingQuality: SceneEnvironment.High
            }

            Node {
                id: sceneRoot

                // Camera Rig with smooth transitions
                Node {
                    id: camRig
                    eulerRotation.x: cameraPitch
                    eulerRotation.y: cameraYaw

                    Behavior on eulerRotation.x {
                        enabled: !boardMouseArea.isDragging
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                    Behavior on eulerRotation.y {
                        enabled: !boardMouseArea.isDragging
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    PerspectiveCamera {
                        id: camera
                        z: cameraDistance
                        fieldOfView: 39
                        clipNear: 10
                        clipFar: 3500

                        Behavior on z {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }

                    // 1. CAMERA-ATTACHED STUDIO FILL LIGHT (Tiles facing the camera are ALWAYS illuminated!)
                    DirectionalLight {
                        eulerRotation.x: -25
                        eulerRotation.y: -15
                        color: "#ffffff"
                        brightness: 1.15
                        castsShadow: false
                    }

                    // Camera rim light
                    DirectionalLight {
                        eulerRotation.x: -20
                        eulerRotation.y: 40
                        color: themeAccent
                        brightness: 0.65
                        castsShadow: false
                    }
                }

                // 2. WORLD DIRECTIONAL SHADOW LIGHT (Angled 52° so deep shadows fall across layers from above)
                DirectionalLight {
                    eulerRotation.x: -50
                    eulerRotation.y: -38
                    eulerRotation.z: 0
                    color: "#ffffff"
                    brightness: 1.15
                    castsShadow: true
                    shadowFactor: 80
                    shadowMapQuality: Light.ShadowMapQualityVeryHigh
                }

                // Soft overall top ambient
                PointLight {
                    x: 0; y: 450; z: 0
                    color: "#ffffff"
                    brightness: 0.65
                    castsShadow: false
                }

                // Table Floor
                Model {
                    id: floorMat
                    source: "#Rectangle"
                    eulerRotation.x: -90
                    scale: Qt.vector3d(9.5, 7.5, 1.0)
                    y: -1
                    materials: [
                        PrincipledMaterial {
                            baseColor: "#0a0c14"
                            roughness: 0.9
                            metalness: 0.1
                        }
                    ]
                }

                // 3D Physical Tiles
                Repeater3D {
                    id: tilesRepeater
                    model: boardTiles

                    delegate: Node {
                        id: tileNode
                        property bool isSelected: selectedTileId === modelData.id
                        property bool isHovered: hoveredTileId === modelData.id
                        property bool isHinted: hintPairIds.indexOf(modelData.id) !== -1

                        x: (modelData.x - 14.0) * 11.2
                        z: (modelData.y - 8.0) * 15.2
                        y: modelData.z * 8.0 + (isSelected ? 6.5 : (isHovered && modelData.free ? 2.5 : 0.0))

                        Behavior on y {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        // Contact Drop Shadow under elevated tiles (offset to bottom-right)
                        Model {
                            visible: modelData.z > 0
                            source: "#Cube"
                            x: 2.0
                            z: 2.5
                            y: -0.8
                            scale: Qt.vector3d(0.22, 0.005, 0.30)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: "#010204"
                                    roughness: 1.0
                                    metalness: 0.0
                                }
                            ]
                        }

                        // 1. Neon / Titanium Base Pedestal (Altitude Tint)
                        Model {
                            source: "#Cube"
                            y: 1.5
                            scale: Qt.vector3d(0.22, 0.03, 0.30)
                            pickable: true
                            property var tileData: modelData
                            materials: [
                                PrincipledMaterial {
                                    baseColor: {
                                        if (isSelected) return "#FFE500";
                                        if (isHinted) return "#FFD700";
                                        if (showLayerDepth) {
                                            if (modelData.free) {
                                                if (modelData.z === 0) return "#0066FF"; // Level 0: Deep Pure Blue
                                                if (modelData.z === 1) return "#00FF00"; // Level 1: Pure Lime Green (zero blue)
                                                if (modelData.z === 2) return "#FFD600"; // Level 2: Golden Yellow
                                                if (modelData.z === 3) return "#D500F9"; // Level 3: Electric Purple
                                                return "#FF1744";                        // Level 4: Fiery Red
                                            }
                                            return "#121520";
                                        }
                                        if (modelData.free) return "#00E5FF";
                                        // Altitude base tint
                                        if (modelData.z === 0) return "#141822";
                                        if (modelData.z === 1) return "#182236";
                                        if (modelData.z === 2) return "#1e2e48";
                                        if (modelData.z === 3) return "#253a5c";
                                        return "#384e78";
                                    }
                                    emissiveFactor: {
                                        if (isSelected) return Qt.vector3d(1.0, 0.85, 0.0);
                                        if (isHinted) return Qt.vector3d(1.0 * hintGlowPulse, 0.8 * hintGlowPulse, 0.0);
                                        if (showLayerDepth) {
                                            if (modelData.free) {
                                                if (modelData.z === 0) return Qt.vector3d(0.0, 0.25, 1.0);
                                                if (modelData.z === 1) return Qt.vector3d(0.0, 1.0, 0.0); // 100% Pure Green
                                                if (modelData.z === 2) return Qt.vector3d(1.0, 0.85, 0.0);
                                                if (modelData.z === 3) return Qt.vector3d(0.9, 0.0, 1.0);
                                                return Qt.vector3d(1.0, 0.0, 0.1);
                                            }
                                            return Qt.vector3d(0.0, 0.0, 0.0);
                                        }
                                        if (modelData.free) return Qt.vector3d(0.0, 0.85, 1.0);
                                        return Qt.vector3d(0.0, 0.0, 0.0);
                                    }
                                    roughness: (isSelected || isHinted || modelData.free) ? 0.2 : 0.65
                                    metalness: (isSelected || isHinted || modelData.free) ? 0.1 : 0.8
                                }
                            ]
                        }

                        // 2. Obsidian Black Glass Body
                        Model {
                            source: "#Cube"
                            y: 5.0
                            scale: Qt.vector3d(0.22, 0.045, 0.30)
                            pickable: true
                            property var tileData: modelData
                            materials: [
                                PrincipledMaterial {
                                    baseColor: {
                                        if (modelData.z === 0) return "#07080c";
                                        if (modelData.z === 1) return "#0c0e16";
                                        if (modelData.z === 2) return "#121522";
                                        if (modelData.z === 3) return "#181d2e";
                                        return "#222a42";
                                    }
                                    roughness: 0.32
                                    metalness: 0.65
                                    clearcoatAmount: 0.85
                                    clearcoatRoughnessAmount: 0.15
                                }
                            ]
                        }

                        // 3. Layer Elevation Glowing Bezel Rim (EXCLUSIVELY DIFFERENT FOR EVERY SINGLE LEVEL!)
                        // Level 0: Deep Pure Blue (#0066FF)
                        // Level 1: Pure Lime Green (#00FF00) - NO BLUE WHATSOEVER
                        // Level 2: Golden Yellow (#FFD600)
                        // Level 3: Vivid Purple (#D500F9)
                        // Level 4 (Peak): Fiery Crimson Red (#FF1744)
                        Model {
                            visible: showLayerDepth
                            source: "#Rectangle"
                            y: 7.33
                            eulerRotation.x: -90
                            scale: Qt.vector3d(0.225, 0.305, 1.0)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: {
                                        if (modelData.z === 0) return "#0066FF"; // Level 0: Deep Pure Blue
                                        if (modelData.z === 1) return "#00FF00"; // Level 1: Pure Lime Green
                                        if (modelData.z === 2) return "#FFD600"; // Level 2: Golden Yellow
                                        if (modelData.z === 3) return "#D500F9"; // Level 3: Electric Purple
                                        return "#FF1744";                        // Level 4: Crimson Red Peak
                                    }
                                    emissiveFactor: {
                                        if (modelData.z === 0) return Qt.vector3d(0.0, 0.25, 1.0);
                                        if (modelData.z === 1) return Qt.vector3d(0.0, 1.0, 0.0); // 100% Pure Green
                                        if (modelData.z === 2) return Qt.vector3d(1.0, 0.85, 0.0);
                                        if (modelData.z === 3) return Qt.vector3d(0.9, 0.0, 1.0);
                                        return Qt.vector3d(1.0, 0.0, 0.1);
                                    }
                                    roughness: 0.2
                                }
                            ]
                        }

                        // 4. Top Face with Borderless Neon Intaglio Texture
                        Model {
                            source: "#Rectangle"
                            y: 7.37
                            eulerRotation.x: -90
                            scale: Qt.vector3d(0.21, 0.29, 1.0)
                            pickable: true
                            property var tileData: modelData
                            materials: [
                                PrincipledMaterial {
                                    baseColor: "#ffffff"
                                    baseColorMap: Texture {
                                        source: Qt.resolvedUrl("assets/faces/" + modelData.sprite)
                                    }
                                    roughness: 0.25
                                    metalness: 0.1
                                    clearcoatAmount: 0.9
                                }
                            ]
                        }
                    }
                }
            }

            // Interactive Controls on 3D Viewport (Touchpad Two-Finger Drag + Mouse)
            MouseArea {
                id: boardMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                property int startX: 0
                property int startY: 0
                property bool isDragging: false

                cursorShape: {
                    if (hoveredTileId !== -1) {
                        for (var i = 0; i < boardTiles.length; i++) {
                            if (boardTiles[i].id === hoveredTileId) {
                                return boardTiles[i].free ? Qt.PointingHandCursor : Qt.ArrowCursor;
                            }
                        }
                    }
                    return Qt.ArrowCursor;
                }

                onPressed: function(mouse) {
                    startX = mouse.x;
                    startY = mouse.y;
                    isDragging = false;
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var dx = mouse.x - startX;
                        var dy = mouse.y - startY;
                        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                            isDragging = true;
                            cameraYaw += dx * 0.35;
                            cameraPitch = Math.max(-89, Math.min(-15, cameraPitch - dy * 0.35));
                            startX = mouse.x;
                            startY = mouse.y;
                            viewMode = "3d";
                        }
                    } else {
                        var hit = v3d.pick(mouse.x, mouse.y);
                        if (hit && hit.objectHit && hit.objectHit.tileData) {
                            hoveredTileId = hit.objectHit.tileData.id;
                        } else {
                            hoveredTileId = -1;
                        }
                    }
                }

                onReleased: function(mouse) {
                    if (!isDragging) {
                        var hit = v3d.pick(mouse.x, mouse.y);
                        if (hit && hit.objectHit && hit.objectHit.tileData) {
                            handleTileClick(hit.objectHit.tileData);
                        } else {
                            if (selectedTile) {
                                selectedTile = null;
                                selectedTileId = -1;
                                playAudio("tile_slide");
                            }
                        }
                    }
                    isDragging = false;
                }

                // Touchpad Two-Finger Navigation & Mouse Wheel
                onWheel: function(wheel) {
                    // Check if horizontal swipe or vertical swipe on touchpad
                    if (wheel.modifiers & Qt.ControlModifier) {
                        // Pinch to Zoom
                        zoomCamera(-wheel.angleDelta.y * 0.35);
                    } else if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) {
                        // Horizontal trackpad swipe: orbit yaw smoothly!
                        rotateCameraYaw(wheel.angleDelta.x * 0.15);
                    } else {
                        // Vertical trackpad swipe / mouse wheel: tilt or zoom
                        // If near top-down, scroll adjusts zoom; otherwise adjusts tilt
                        if (Math.abs(wheel.angleDelta.y) >= 120) {
                            // Standard discrete mouse wheel click: zoom
                            zoomCamera(-wheel.angleDelta.y * 0.3);
                        } else {
                            // Smooth touchpad 2-finger vertical scroll: orbit pitch!
                            cameraPitch = Math.max(-89, Math.min(-15, cameraPitch + wheel.angleDelta.y * 0.18));
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2D PARTICLE FX OVERLAY
        // ---------------------------------------------------------------------
        Canvas {
            id: particleCanvas
            anchors.fill: v3d
            z: 5
            enabled: false

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                for (var pIdx = 0; pIdx < particles.length; pIdx++) {
                    var p = particles[pIdx];
                    ctx.save();
                    ctx.shadowColor = p.color;
                    ctx.shadowBlur = 8;
                    ctx.fillStyle = "rgba(" + hexToRgb(p.color) + ", " + p.alpha + ")";
                    ctx.beginPath();
                    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                }
            }
        }

        // ---------------------------------------------------------------------
        // FLOATING LEVEL DEPTH LEGEND (Active when showLayerDepth is ON)
        // ---------------------------------------------------------------------
        Rectangle {
            visible: showLayerDepth
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56
            anchors.horizontalCenter: parent.horizontalCenter
            height: 30
            width: depthLegendRow.implicitWidth + 24
            radius: 15
            color: Qt.rgba(10/255, 14/255, 24/255, 0.90)
            border.color: Qt.rgba(0, 240/255, 255/255, 0.35)
            border.width: 1
            z: 10

            Row {
                id: depthLegendRow
                anchors.centerIn: parent
                spacing: 14

                Repeater {
                    model: [
                        { label: "L0 BASE", color: "#0066FF" },
                        { label: "L1", color: "#00FF00" },
                        { label: "L2", color: "#FFD600" },
                        { label: "L3", color: "#D500F9" },
                        { label: "L4 PEAK", color: "#FF1744" }
                    ]
                    Row {
                        spacing: 5
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                            border.color: "#ffffff"
                            border.width: 1
                        }
                        Text {
                            text: modelData.label
                            color: "#e2e8f0"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // FLOATING TOUCHPAD QUICK-CONTROLS HUD
        // ---------------------------------------------------------------------
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            height: 36
            width: quickControlsRow.implicitWidth + 24
            radius: 8
            color: Qt.rgba(14/255, 18/255, 28/255, 0.92)
            border.color: Qt.rgba(0, 240/255, 255/255, 0.35)
            border.width: 1
            z: 10

            Row {
                id: quickControlsRow
                anchors.centerIn: parent
                spacing: 8

                // Layouts
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: [
                            { id: "turtle", name: "Turtle" },
                            { id: "fortress", name: "Fortress" },
                            { id: "dragon", name: "Dragon" }
                        ]
                        Rectangle {
                            height: 26
                            width: 50
                            radius: 5
                            color: currentLayout === modelData.id ? Qt.rgba(0, 240/255, 255/255, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                            border.color: currentLayout === modelData.id ? themeAccent : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                font.pixelSize: 10
                                font.bold: true
                                color: currentLayout === modelData.id ? themeAccent : themeFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: startNewGame(modelData.id)
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 18; color: Qt.rgba(255, 255, 255, 0.15); anchors.verticalCenter: parent.verticalCenter }

                // Hint Button
                Rectangle {
                    height: 26
                    width: 54
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    border.color: themeAccent
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "💡"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Hint"; font.pixelSize: 10; font.bold: true; color: themeAccent; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showHint()
                    }
                }

                // Undo Button
                Rectangle {
                    height: 26
                    width: 54
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    border.color: undoStack.length > 0 ? root.themeBorder : Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                    opacity: undoStack.length > 0 ? 1.0 : 0.4
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "↶"; font.pixelSize: 11; font.bold: true; color: themeFg; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Undo"; font.pixelSize: 10; font.bold: true; color: themeFg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: undoStack.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: undoMove()
                    }
                }

                Rectangle { width: 1; height: 18; color: Qt.rgba(255, 255, 255, 0.15); anchors.verticalCenter: parent.verticalCenter }

                // Rotate Left
                Rectangle {
                    width: 32
                    height: 26
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    Text { anchors.centerIn: parent; text: "⟲"; font.pixelSize: 14; font.weight: Font.Bold; color: themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rotateCameraYaw(45) }
                }

                // Rotate Right
                Rectangle {
                    width: 32
                    height: 26
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    Text { anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; font.weight: Font.Bold; color: themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rotateCameraYaw(-45) }
                }

                // Zoom Out
                Rectangle {
                    width: 32
                    height: 26
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    Text { anchors.centerIn: parent; text: "－"; font.pixelSize: 14; font.weight: Font.Bold; color: themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: zoomCamera(60) }
                }

                // Zoom In
                Rectangle {
                    width: 32
                    height: 26
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    Text { anchors.centerIn: parent; text: "＋"; font.pixelSize: 14; font.weight: Font.Bold; color: themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: zoomCamera(-60) }
                }

                Rectangle { width: 1; height: 18; color: Qt.rgba(255, 255, 255, 0.15); anchors.verticalCenter: parent.verticalCenter }

                // Top-down / 3D Toggle
                Rectangle {
                    width: 52
                    height: 26
                    radius: 5
                    color: viewMode === "overhead" ? Qt.rgba(0, 240/255, 255/255, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                    border.color: viewMode === "overhead" ? themeAccent : Qt.rgba(255, 255, 255, 0.15)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: viewMode === "overhead" ? "📐 TOP" : "🌐 3D"; font.pixelSize: 10; font.weight: Font.Bold; color: viewMode === "overhead" ? themeAccent : themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: setViewMode(viewMode === "3d" ? "overhead" : "3d") }
                }

                // Depth Toggle
                Rectangle {
                    width: 58
                    height: 26
                    radius: 5
                    color: showLayerDepth ? Qt.rgba(255, 23, 68, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                    border.color: showLayerDepth ? "#FF1744" : Qt.rgba(255, 255, 255, 0.15)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "📊 DEPTH"; font.pixelSize: 10; font.weight: Font.Bold; color: showLayerDepth ? "#FF80AB" : themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showLayerDepth = !showLayerDepth }
                }

                // Reset Camera
                Rectangle {
                    width: 48
                    height: 26
                    radius: 5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    Text { anchors.centerIn: parent; text: "RESET"; font.pixelSize: 10; font.weight: Font.Bold; color: themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: resetCamera() }
                }
            }
        }

        // ---------------------------------------------------------------------
        // VICTORY OVERLAY MODAL
        // ---------------------------------------------------------------------
        Rectangle {
            id: victoryModal
            anchors.fill: parent
            color: Qt.rgba(5/255, 8/255, 15/255, 0.88)
            visible: isWon
            z: 100

            Rectangle {
                anchors.centerIn: parent
                width: 460
                height: 380
                radius: 16
                color: "#111420"
                border.color: themeAccent
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 18

                    Text {
                        text: "🎉 CYBER VICTORY! 🎉"
                        font.pixelSize: 24
                        font.weight: Font.Black
                        font.letterSpacing: 2
                        color: themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "ALL 144 OBSIDIAN TILES PURGED"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: themeFg
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 360
                        height: 120
                        radius: 10
                        color: Qt.rgba(255, 255, 255, 0.04)
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Row {
                                spacing: 40
                                anchors.horizontalCenter: parent.horizontalCenter
                                Column {
                                    Text { text: "FINAL SCORE"; font.pixelSize: 10; font.weight: Font.Bold; color: Qt.rgba(226/255, 232/255, 240/255, 0.6); anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: score.toLocaleString(); font.pixelSize: 20; font.weight: Font.Black; color: themeAccent; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                Column {
                                    Text { text: "CLEARED TIME"; font.pixelSize: 10; font.weight: Font.Bold; color: Qt.rgba(226/255, 232/255, 240/255, 0.6); anchors.horizontalCenter: parent.horizontalCenter }
                                    Text {
                                        text: {
                                            var m = Math.floor(gameTimeSeconds / 60);
                                            var s = gameTimeSeconds % 60;
                                            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                                        }
                                        font.pixelSize: 20
                                        font.weight: Font.Black
                                        color: themeFg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 16
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 140
                            height: 40
                            radius: 8
                            color: themeAccent

                            Text {
                                anchors.centerIn: parent
                                text: "PLAY AGAIN"
                                font.pixelSize: 12
                                font.weight: Font.Black
                                font.letterSpacing: 1
                                color: "#0a0c12"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: startNewGame(currentLayout)
                            }
                        }

                        Rectangle {
                            width: 140
                            height: 40
                            radius: 8
                            color: Qt.rgba(255, 255, 255, 0.08)
                            border.color: Qt.rgba(255, 255, 255, 0.2)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "CHANGE LAYOUT"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: themeFg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var next = currentLayout === "turtle" ? "fortress" : (currentLayout === "fortress" ? "dragon" : "turtle");
                                    startNewGame(next);
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CANONICAL OMARCHY TEMPLATE: HELP MODAL & SOUND TOAST
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
                width: Math.min(parent.width * 0.90, 520)
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

    Component.onCompleted: {
        startNewGame(currentLayout);
    }
}
