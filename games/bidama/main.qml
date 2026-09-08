import QtQuick
import QtQuick.Controls
import "BidamaEngine.js" as Engine

ApplicationWindow {
    id: root
    visible: true
    width: 960
    height: 700
    minimumWidth: 380
    minimumHeight: 440
    title: "Bīdama (ビー玉) • Japanese Tatami Marbles"
    color: themeBg

    // =========================================================================
    // SYSTEM THEME & JAPANESE TATAMI PALETTE
    // =========================================================================
    property color themeBg: "#121215"
    property color themeFg: "#F8FAFC"
    property color themeCardBg: "#1C1C22"
    property color themeBoardBg: "#25252E"
    property color themeBorder: "#2E2E3A"
    property color themeAccent: "#0284C7"
    property color themeBtnFg: "#FFFFFF"
    property color themeSubtext: "#94A3B8"

    property string helpText: "• OBJECTIVE:\nAlign 3 or more matching glass marbles along the central black Urushi Pitch Line to clear them and trigger inward gravity collapse. In Duel mode, empty all your chutes or cause your opponent to jam and overflow to win!\n\n• CONTROLS:\n  ◄ / ► or Click Chute: Select chute\n  ▲ / ▼ or Mouse Drag: Slide active chute UP / DOWN (Bounded - no wrap!)\n  Space / Q / E: Shift Pitch Line horizontally\n  Shift+F: Toggle Full / Compact View\n  M: Toggle sound (Default muted)\n  R: Rematch / New Game\n  ? / Esc: Toggle this Guide\n\n• MECHANICS:\n  - 3-Match: Clears line and pulls remaining marbles inward.\n  - 4 or 5-Match: Sends penalty marbles and Kyoto basalt stones to the opponent's chutes.\n  - Drop Wave: A fresh wave of marbles drops across all chutes as the timer counts down.\n  - Overflow Jam: If any chute reaches max capacity (11 marbles), that player jams and loses!"

    property color tatamiGreen: "#33442A"   // Woven igusa rush mat
    property color tatamiBorder: "#141A12"  // Silk brocade border (heri)
    property color hinokiWood: "#DDBE94"    // Light cypress wood tray
    property color hinokiDark: "#8F6B3F"    // Carved flute trough shadow
    property color urushiPitch: "#0A0A0E"   // Polished black Urushi lacquer
    property color kintsugiGold: "#D4AF37"  // Inlaid Kintsugi gold leaf seam

    // =========================================================================
    // GAME STATE (DEFAULT SOUND MUTED AS REQUESTED)
    // =========================================================================
    property bool isMuted: true             // DEFAULT MUTED
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool _spaceConstrained: root.height < 520 || root.width < 440
    on_SpaceConstrainedChanged: isTiledDesktopMode = _spaceConstrained
    property string gameMode: "duel"        // "duel" (Player vs AI) or "solo" (Practice for points)
    property int selectedCol: 2             // Active player column (0..4)
    property int aiSelectedCol: 2           // Current AI target column
    property var playerBoard: []            // 5 cols x 11 rows
    property var aiBoard: []                // 5 cols x 11 rows
    property var playerRollAngles: [0.0, 0.0, 0.0, 0.0, 0.0]
    property var aiRollAngles: [0.0, 0.0, 0.0, 0.0, 0.0]

    property int playerScore: 0
    property int aiScore: 0
    property int bestScore: 0
    property int playerGarbageCount: 0
    property int aiGarbageCount: 0
    property bool isGameOver: false
    property string winner: ""
    property bool showHelp: false
    property bool splashEnabled: true
    property bool isPlayerAnimating: false

    // Wave drop timer (Full row wave drops across all chutes every 16s)
    property real dropCountdown: 16.0

    signal playSoundRequested(string soundName)
    signal screenshotSaved(string path)

    function playSound(name) {
        if (!isMuted) {
            playSoundRequested(name);
            if (typeof soundManager !== "undefined" && soundManager) {
                soundManager.playSound(name);
            }
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("muted", isMuted ? "true" : "false");
        }
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function syncBoards() {
        var pFlat = [];
        var aFlat = [];
        for (var c = 0; c < Engine.COLS; c++) {
            var pCol = [];
            var aCol = [];
            for (var r = 0; r < Engine.ROWS; r++) {
                var pp = Engine.playerGrid[c][r];
                var ap = Engine.aiGrid[c][r];
                pCol.push(pp ? { id: pp.id, type: pp.type } : null);
                aCol.push(ap ? { id: ap.id, type: ap.type } : null);
            }
            pFlat.push(pCol);
            aFlat.push(aCol);
        }
        playerBoard = pFlat;
        aiBoard = aFlat;
        playerRollAngles = Engine.playerRollAngles.slice();
        aiRollAngles = Engine.aiRollAngles.slice();
        playerScore = Engine.score;
        aiScore = Engine.aiScore;
        playerGarbageCount = Engine.playerGarbageQueue.length;
        aiGarbageCount = Engine.aiGarbageQueue.length;

        var winStatus = Engine.checkGameOver(gameMode);
        if (winStatus) {
            isGameOver = true;
            winner = winStatus;
            playSound(winner === "player" ? "win" : "game_over");
            soundToast.show(gameMode === "duel"
                ? (winner === "player" ? "🏆 Victory! You Defeated the Rival!" : "💀 Defeat! Chute Overwhelmed!")
                : "💀 Practice Finished! Final Score: " + playerScore);
        } else {
            isGameOver = false;
            winner = "";
        }

        if (playerScore > bestScore) {
            bestScore = playerScore;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setBestScore(bestScore);
            }
        }
    }

    function startNewMatch() {
        isGameOver = false;
        winner = "";
        dropCountdown = 16.0;
        selectedCol = 2;
        aiSelectedCol = 2;
        isPlayerAnimating = false;
        Engine.initGame();
        syncBoards();
        if (gameMode === "duel") {
            aiLoopTimer.restart();
        } else {
            aiLoopTimer.stop();
        }
        dropTimer.restart();
        playSound("select");
        soundToast.show(gameMode === "duel" ? "⚔️ New Duel: Player vs Rival Master" : "🧘 Solo Practice: Match Marbles for High Score");
    }

    // =========================================================================
    // PLAYER SLIDE (BOUNDED, NO WRAP)
    // =========================================================================
    function handlePlayerSlide(colIdx, dir) {
        if (isGameOver || isPlayerAnimating) return;
        selectedCol = colIdx;

        if (!Engine.canSlideColumn(Engine.playerGrid, colIdx, dir)) {
            // Cannot slide: column has reached its boundary
            soundToast.show("⚠️ Chute Boundary Reached");
            return;
        }

        var chuteObj = playerColRepeater.itemAt(colIdx);
        if (chuteObj && chuteObj.slideTrack) {
            isPlayerAnimating = true;
            playSound("slide");
            chuteObj.slideTrack(dir, function() {
                Engine.slideColumnBounded(Engine.playerGrid, Engine.playerRollAngles, colIdx, dir);
                syncBoards();
                isPlayerAnimating = false;
                evaluatePlayerClears();
            });
        } else {
            Engine.slideColumnBounded(Engine.playerGrid, Engine.playerRollAngles, colIdx, dir);
            syncBoards();
            evaluatePlayerClears();
        }
    }

    // Shift Player Pitch Line horizontally (Space / Q / E)
    function handlePlayerPitchShift(dir) {
        if (isGameOver || isPlayerAnimating) return;
        playSound("slide");
        Engine.slidePitchLine(Engine.playerGrid, dir);
        syncBoards();
        evaluatePlayerClears();
    }

    function evaluatePlayerClears() {
        if (isGameOver) return;
        var matchInfo = Engine.findPitchMatches(Engine.playerGrid);

        if (matchInfo.matchedCols.length > 0 || matchInfo.bombCols.length > 0) {
            isPlayerAnimating = true;
            var cols = matchInfo.matchedCols.slice();
            for (var b = 0; b < matchInfo.bombCols.length; b++) {
                if (cols.indexOf(matchInfo.bombCols[b]) === -1) cols.push(matchInfo.bombCols[b]);
            }

            for (var i = 0; i < cols.length; i++) {
                var chuteItem = playerColRepeater.itemAt(cols[i]);
                if (chuteItem && chuteItem.shatterRow5) chuteItem.shatterRow5();
            }

            if (matchInfo.bombCols.length > 0) {
                playSound("bomb");
            } else if (Engine.playerCombo >= 1) {
                playSound("furin");
            } else {
                playSound("clear");
            }

            playerShatterDelay.restart();
        } else {
            Engine.playerCombo = 0;
        }
    }

    function launchAttack(isPlayer, garbageCount, basaltCount) {
        if (isGameOver) return;
        attackProjectile.isPlayerAttacking = isPlayer;
        attackProjectile.queuedGarbage = garbageCount;
        attackProjectile.queuedBasalt = basaltCount;

        var startX = isPlayer ? (playerTatami.x + playerTatami.width * 0.75) : (aiTatami.x + aiTatami.width * 0.25);
        var targetX = isPlayer ? (aiTatami.x + aiTatami.width * 0.25) : (playerTatami.x + playerTatami.width * 0.75);

        attackProjectile.x = startX;
        attackProjectile.y = dualArena.height * 0.5 - 18;
        attackProjectile.visible = true;

        projAnim.from = startX;
        projAnim.to = targetX;
        projAnim.restart();
    }

    Timer {
        id: playerShatterDelay
        interval: 220
        repeat: false
        onTriggered: {
            var res = Engine.processClearsAndGravity(true);
            if (res.clearedCount > 0) {
                if (root.gameMode === "duel" && (res.garbageSent > 0 || res.basaltSent > 0)) {
                    if (res.basaltSent > 0) {
                        soundToast.show("💥 WIPEOUT! Sent " + res.garbageSent + " Penalty + 1 Basalt Stone to Rival!");
                    } else if (res.clearedCount === 4) {
                        soundToast.show("⚡ 4-MATCH STRIKE! Sent 2 Penalty Marbles to Rival!");
                    } else {
                        soundToast.show("🔥 Combo Chain x" + res.combo + "! Sent " + res.garbageSent + " Garbage to Rival!");
                    }
                    root.launchAttack(true, res.garbageSent, res.basaltSent);
                } else if (root.gameMode === "solo") {
                    if (res.clearedCount >= 5) {
                        soundToast.show("💥 WIPEOUT! Pitch Cleared! +1,500 Bonus!");
                        Engine.score += 1500;
                    } else if (res.clearedCount === 4) {
                        soundToast.show("⚡ 4-MATCH CLEAR! +500 Bonus!");
                        Engine.score += 500;
                    } else if (res.combo >= 2) {
                        soundToast.show("🔥 Combo Chain x" + res.combo + "! +" + res.scoreEarned);
                    } else {
                        soundToast.show("✨ Pitch Cleared! +" + res.scoreEarned);
                    }
                } else {
                    soundToast.show("✨ Pitch Cleared! +" + res.scoreEarned);
                }
                playSound("clack");
                syncBoards();
                playerCascadeTimer.restart();
            } else {
                isPlayerAnimating = false;
            }
        }
    }

    Timer {
        id: playerCascadeTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.evaluatePlayerClears();
            root.isPlayerAnimating = false;
        }
    }

    // =========================================================================
    // COMPUTER OPPONENT AI LOOP
    // =========================================================================
    Timer {
        id: aiLoopTimer
        interval: 1500 // AI makes a move every 1.5s
        repeat: true
        running: !isGameOver && (root.gameMode === "duel") && (splashScreen ? !splashScreen.visible : true)
        onTriggered: {
            if (isGameOver) return;
            var move = Engine.computeBestAIMove();
            if (move) {
                if (move.action === "pitch") {
                    Engine.slidePitchLine(Engine.aiGrid, move.dir);
                    syncBoards();
                    evaluateAIClears();
                } else if (move.action === "col") {
                    aiSelectedCol = move.col;
                    var chuteObj = aiColRepeater.itemAt(move.col);
                    if (chuteObj && chuteObj.slideTrack) {
                        chuteObj.slideTrack(move.dir, function() {
                            Engine.slideColumnBounded(Engine.aiGrid, Engine.aiRollAngles, move.col, move.dir);
                            syncBoards();
                            evaluateAIClears();
                        });
                    } else {
                        Engine.slideColumnBounded(Engine.aiGrid, Engine.aiRollAngles, move.col, move.dir);
                        syncBoards();
                        evaluateAIClears();
                    }
                }
            }
        }
    }

    function evaluateAIClears() {
        if (isGameOver) return;
        var matchInfo = Engine.findPitchMatches(Engine.aiGrid);
        if (matchInfo.matchedCols.length > 0 || matchInfo.bombCols.length > 0) {
            for (var i = 0; i < matchInfo.matchedCols.length; i++) {
                var chuteItem = aiColRepeater.itemAt(matchInfo.matchedCols[i]);
                if (chuteItem && chuteItem.shatterRow5) chuteItem.shatterRow5();
            }
            aiShatterDelay.restart();
        } else {
            Engine.aiCombo = 0;
        }
    }

    Timer {
        id: aiShatterDelay
        interval: 220
        repeat: false
        onTriggered: {
            var res = Engine.processClearsAndGravity(false);
            if (res.clearedCount > 0) {
                if (res.garbageSent > 0 || res.basaltSent > 0) {
                    if (res.basaltSent > 0) {
                        soundToast.show("⚠️ RIVAL WIPEOUT! Rival sent " + res.garbageSent + " Penalty + 1 Basalt to You!");
                    } else if (res.clearedCount === 4) {
                        soundToast.show("⚠️ Rival 4-Match Attack! Sent 2 Penalty Marbles to You!");
                    } else {
                        soundToast.show("⚠️ Rival Counterattack! Sent " + res.garbageSent + " Garbage to You!");
                    }
                    root.launchAttack(false, res.garbageSent, res.basaltSent);
                }
                syncBoards();
            }
        }
    }

    // =========================================================================
    // GRADUAL MARBLE DROP & GARBAGE INJECTION TIMER
    // =========================================================================
    Timer {
        id: dropTimer
        interval: 100
        repeat: true
        running: !isGameOver && (splashScreen ? !splashScreen.visible : true)
        onTriggered: {
            root.dropCountdown -= 0.1;
            if (root.dropCountdown <= 0) {
                root.dropCountdown = 16.0;
                // Authentic Lose Your Marbles Drop Wave: Add a full row across all 5 chutes!
                var pDrop = Engine.dropWave(Engine.playerGrid);
                var aDrop = null;
                if (root.gameMode === "duel") {
                    aDrop = Engine.dropWave(Engine.aiGrid);
                }
                root.playSound("slide");
                soundToast.show("🌊 DROP WAVE! Full row added to chutes!");
                root.syncBoards();

                if (pDrop.jammed) {
                    root.isGameOver = true;
                    root.winner = (root.gameMode === "duel") ? "ai" : "jam";
                    root.playSound("game_over");
                    soundToast.show(root.gameMode === "duel" ? "💀 Defeat! Chute Overwhelmed!" : "💀 Practice Over! Chutes Jammed!");
                } else if (root.gameMode === "duel" && aDrop && aDrop.jammed) {
                    root.isGameOver = true;
                    root.winner = "player";
                    root.playSound("win");
                    soundToast.show("🏆 Victory! Rival Chutes Jammed!");
                }
            }
        }
    }

    function applyTheme(colors, themeName) {
        if (!colors) return;
        if (colors.bg || colors.background) themeBg = colors.bg || colors.background;
        if (colors.fg || colors.foreground) themeFg = colors.fg || colors.foreground;
        if (colors.card_bg) themeCardBg = colors.card_bg;
        if (colors.board_bg) themeBoardBg = colors.board_bg;
        if (colors.border) themeBorder = colors.border;
        if (colors.accent) themeAccent = colors.accent;
    }

    function captureScreenshot(filePath, shouldQuit) {
        mainContainer.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) Qt.quit();
        });
    }

    Component.onCompleted: {
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.bestScore = settingsManager.getBestScore();
            var savedMode = settingsManager.getValue("gameMode", "duel");
            if (savedMode === "solo" || savedMode === "duel") {
                root.gameMode = savedMode;
            }
        }
        Engine.initGame();
        root.syncBoards();
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLERS
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                mainContainer.forceActiveFocus();
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

            if (root.isGameOver) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R) {
                    root.startNewMatch();
                    event.accepted = true;
                    return;
                }
            }

            // Select Column Left/Right OR Shift Pitch Line with Shift+Left / Shift+Right
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.handlePlayerPitchShift(-1);
                } else {
                    root.selectedCol = Math.max(0, root.selectedCol - 1);
                    root.playSound("select");
                }
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.handlePlayerPitchShift(1);
                } else {
                    root.selectedCol = Math.min(Engine.COLS - 1, root.selectedCol + 1);
                    root.playSound("select");
                }
                event.accepted = true;
                return;
            }

            // Slide Active Column UP or DOWN (Bounded, No Wrap)
            if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                root.handlePlayerSlide(root.selectedCol, -1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                root.handlePlayerSlide(root.selectedCol, 1);
                event.accepted = true;
                return;
            }

            // Space: Shift Center Pitch Line Horizontally (Lose Your Marbles rule)
            if (event.key === Qt.Key_Space) {
                root.handlePlayerPitchShift(1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Q) {
                root.handlePlayerPitchShift(-1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_E) {
                root.handlePlayerPitchShift(1);
                event.accepted = true;
                return;
            }

            // Game Control Shortcuts
            if (event.key === Qt.Key_R) {
                root.startNewMatch();
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

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash || event.key === Qt.Key_F1) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (root.showHelp) {
                    root.showHelp = false;
                } else {
                    Qt.quit();
                }
                event.accepted = true;
                return;
            }
        }

        // =====================================================================
        // HEADER: TITLE & CONTROLS
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: root.isTiledDesktopMode ? 0 : (40)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: "BĪDAMA"
                    font.pixelSize: (headerItem.width < 450) ? 16 : 18
                    font.bold: true
                    font.letterSpacing: 2
                    color: root.themeFg
                }
                Rectangle {
                    height: 16
                    width: 40
                    radius: 4
                    color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.20)
                    border.color: root.themeAccent
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "OA-028"
                        font.pixelSize: 8
                        font.bold: true
                        color: root.themeAccent
                    }
                }
                Text {
                    text: root.gameMode === "duel" ? "ビー玉 • Duel" : "ビー玉 • Solo"
                    font.pixelSize: 12
                    color: root.kintsugiGold
                    anchors.verticalCenter: parent.verticalCenter
                    visible: headerItem.width >= 460
                }
            }

            // Mode Selector: Segmented Pill (Duel vs Solo)
            Rectangle {
                anchors.centerIn: parent
                visible: headerItem.width >= 580
                height: 28
                width: 170
                radius: 14
                color: Qt.darker(root.themeCardBg, 1.2)
                border.color: root.themeBorder
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Duel tab
                    Rectangle {
                        width: (parent.width - 2) / 2
                        height: parent.height
                        radius: 12
                        color: root.gameMode === "duel" ? root.themeAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "⚔️ Duel"
                            font.pixelSize: 11
                            font.bold: root.gameMode === "duel"
                            color: root.gameMode === "duel" ? "#ffffff" : Qt.darker(root.themeFg, 1.3)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.gameMode !== "duel") {
                                    root.gameMode = "duel";
                                    if (typeof settingsManager !== "undefined" && settingsManager) {
                                        settingsManager.setValue("gameMode", "duel");
                                    }
                                    root.startNewMatch();
                                }
                            }
                        }
                    }

                    // Solo tab
                    Rectangle {
                        width: (parent.width - 2) / 2
                        height: parent.height
                        radius: 12
                        color: root.gameMode === "solo" ? root.themeAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "🧘 Solo"
                            font.pixelSize: 11
                            font.bold: root.gameMode === "solo"
                            color: root.gameMode === "solo" ? "#ffffff" : Qt.darker(root.themeFg, 1.3)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.gameMode !== "solo") {
                                    root.gameMode = "solo";
                                    if (typeof settingsManager !== "undefined" && settingsManager) {
                                        settingsManager.setValue("gameMode", "solo");
                                    }
                                    root.startNewMatch();
                                }
                            }
                        }
                    }
                }
            }

            // Right header controls
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Compact Mode Toggle Button (when window is narrow < 580)
                Rectangle {
                    visible: headerItem.width < 580
                    height: 28
                    width: 64
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeAccent
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.gameMode === "duel" ? "⚔️ Duel" : "🧘 Solo"
                        font.pixelSize: 10
                        font.bold: true
                        color: root.themeAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.gameMode = (root.gameMode === "duel") ? "solo" : "duel";
                            if (typeof settingsManager !== "undefined" && settingsManager) {
                                settingsManager.setValue("gameMode", root.gameMode);
                            }
                            root.startNewMatch();
                        }
                    }
                }

                // Mute button
                Rectangle {
                    height: 28
                    width: 30
                    radius: 6
                    color: root.isMuted ? "#3f3f46" : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.isMuted ? "🔇" : "🔊"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Help button
                Rectangle {
                    height: 28
                    width: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        font.pixelSize: 12
                        font.bold: true
                        color: root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                // Restart button
                Rectangle {
                    height: 28
                    width: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "↺"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewMatch()
                    }
                }
            }
        }

        // =====================================================================
        // DUAL TATAMI ARENA (LEFT: PLAYER 1, CENTER: STATUS, RIGHT: RIVAL AI)
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
                    text: "⚪ Bīdama"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeAccent
                }

                Text {
                    text: "• " + (root.p1Score + " - " + root.p2Score)
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "(" + ("STAGE: " + root.currentStage) + ")"
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
            }
        }

        id: dualArena
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : headerItem.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: (root.width < 500) ? 6 : 10

            readonly property bool isSolo: root.gameMode === "solo"
            readonly property real centerWidth: (width < 640) ? 54 : 76
            readonly property real boardWidth: isSolo
                ? Math.min(width - 16, Math.max(260, height * 0.72))
                : Math.max(130, (width - centerWidth - 16) / 2.0)

            // -----------------------------------------------------------------
            // LEFT BOARD: PLAYER 1 (YOU)
            // -----------------------------------------------------------------
            Rectangle {
                id: playerTatami
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: dualArena.isSolo ? Math.round((parent.width - width) / 2) : 0
                width: dualArena.boardWidth
                color: root.tatamiGreen
                radius: 12
                border.color: root.tatamiBorder
                border.width: 3
                clip: true

                property real shakeOffset: 0.0
                transform: Translate { x: playerTatami.shakeOffset }

                // Tatami rush weave
                Canvas {
                    anchors.fill: parent
                    opacity: 0.20
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1;
                        for (var y = 0; y < height; y += 4) {
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                        }
                    }
                }

                // Silk Heri border left
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 14; color: root.tatamiBorder
                    Rectangle { anchors.right: parent.right; width: 1.5; height: parent.height; color: root.kintsugiGold; opacity: 0.7 }
                }

                // Player Hinoki Board
                Rectangle {
                    id: playerHinoki
                    anchors.fill: parent
                    anchors.margins: (parent.width < 220) ? 6 : 12
                    anchors.leftMargin: (parent.width < 220) ? 10 : 18
                    color: root.hinokiWood
                    border.color: root.hinokiDark
                    border.width: 2.5
                    radius: 10

                    readonly property real fluteWidth: (width - 24) / 5.0
                    readonly property real slotHeight: (height - 24) / 11.0
                    readonly property real marbleSize: Math.min(fluteWidth * 0.88, slotHeight * 0.94)


                    // Urushi Pitch Line Underlay (Row 5)
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 4
                        y: 12 + 5 * playerHinoki.slotHeight
                        height: playerHinoki.slotHeight
                        color: root.urushiPitch
                        border.color: root.kintsugiGold
                        border.width: 1.5
                        radius: 6
                        z: 0

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            text: "PITCH"; font.pixelSize: 8; font.bold: true; color: root.kintsugiGold; opacity: 0.8
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            text: "得点線"; font.pixelSize: 8; font.bold: true; color: root.kintsugiGold; opacity: 0.8
                        }
                    }

                    // 5 Chutes
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        z: 10

                        Repeater {
                            id: playerColRepeater
                            model: 5

                            Item {
                                id: pColItem
                                readonly property int cIdx: index
                                width: playerHinoki.fluteWidth
                                height: playerHinoki.height - 18
                                clip: true

                                property real trackOffsetY: 0.0
                                property real colRoll: root.playerRollAngles[cIdx]

                                function slideTrack(dir, onDone) {
                                    var targetY = (dir === -1) ? -playerHinoki.slotHeight : playerHinoki.slotHeight;
                                    var targetRoll = (dir === -1) ? (colRoll - 1.25) : (colRoll + 1.25);
                                    pSlideAnim.toY = targetY;
                                    pSlideAnim.toRoll = targetRoll;
                                    pSlideAnim.callback = onDone;
                                    pSlideAnim.restart();
                                }

                                function shatterRow5() {
                                    var m5 = pSlotRepeater.itemAt(5);
                                    if (m5 && m5.triggerPieceShatter) m5.triggerPieceShatter();
                                }

                                SequentialAnimation {
                                    id: pSlideAnim
                                    property real toY: 0
                                    property real toRoll: 0
                                    property var callback: null

                                    ParallelAnimation {
                                        NumberAnimation { target: pColItem; property: "trackOffsetY"; to: pSlideAnim.toY; duration: 140; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: pColItem; property: "colRoll"; to: pSlideAnim.toRoll; duration: 140; easing.type: Easing.OutQuad }
                                    }
                                    ScriptAction {
                                        script: {
                                            pColItem.trackOffsetY = 0.0;
                                            if (pSlideAnim.callback) pSlideAnim.callback();
                                        }
                                    }
                                }

                                // Trough background
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: (root.selectedCol === cIdx) ? Qt.darker(root.hinokiWood, 1.22) : Qt.darker(root.hinokiWood, 1.12)
                                    border.color: (root.selectedCol === cIdx) ? root.themeAccent : root.hinokiDark
                                    border.width: (root.selectedCol === cIdx) ? 2.5 : 1.2

                                    // Urushi Pitch Line Inlay inside chute
                                    Rectangle {
                                        y: 5 * playerHinoki.slotHeight + (parent.height - 11 * playerHinoki.slotHeight) / 2
                                        width: parent.width
                                        height: playerHinoki.slotHeight
                                        color: root.urushiPitch
                                        opacity: 0.88
                                        border.color: root.kintsugiGold
                                        border.width: 1.2
                                    }
                                }

                                // Active selection arrow
                                Rectangle {
                                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: -6; width: 18; height: 10; radius: 3
                                    color: root.themeAccent; visible: root.selectedCol === cIdx; z: 25
                                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 6; color: "#fff" }
                                }

                                // Movable track
                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 11 * playerHinoki.slotHeight
                                    y: ((parent.height - height) / 2) + pColItem.trackOffsetY

                                    Column {
                                        anchors.fill: parent
                                        spacing: 0

                                        Repeater {
                                            id: pSlotRepeater
                                            model: 11

                                            Item {
                                                readonly property int rIdx: index
                                                width: playerHinoki.fluteWidth
                                                height: playerHinoki.slotHeight

                                                function triggerPieceShatter() {
                                                    if (pMarble.visible) pMarble.triggerShatter();
                                                }


                                                MarblePiece {
                                                    id: pMarble
                                                    anchors.centerIn: parent
                                                    width: playerHinoki.marbleSize
                                                    height: playerHinoki.marbleSize
                                                    visible: root.playerBoard[cIdx] && root.playerBoard[cIdx][rIdx] !== null
                                                    marbleType: (root.playerBoard[cIdx] && root.playerBoard[cIdx][rIdx]) ? root.playerBoard[cIdx][rIdx].type : "ramune"
                                                    rollAngle: pColItem.colRoll
                                                    z: 15
                                                }
                                            }
                                        }
                                    }
                                }

                                // Mouse Area for dragging
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.OpenHandCursor
                                    preventStealing: true

                                    property real startY: 0
                                    property real initialRoll: 0
                                    property bool isDragging: false

                                    onPressed: function(mouse) {
                                        if (root.isPlayerAnimating) return;
                                        root.selectedCol = cIdx;
                                        startY = mouse.y;
                                        initialRoll = pColItem.colRoll;
                                        isDragging = true;
                                        cursorShape = Qt.ClosedHandCursor;
                                        mainContainer.forceActiveFocus();
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (isDragging) {
                                            var dy = mouse.y - startY;
                                            // Check bounds
                                            if (dy < 0 && !Engine.canSlideColumn(Engine.playerGrid, cIdx, -1)) dy = 0;
                                            if (dy > 0 && !Engine.canSlideColumn(Engine.playerGrid, cIdx, 1)) dy = 0;
                                            pColItem.trackOffsetY = Math.max(-playerHinoki.slotHeight * 1.1, Math.min(playerHinoki.slotHeight * 1.1, dy));
                                            pColItem.colRoll = initialRoll - (dy / (playerHinoki.marbleSize * 0.5));
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (!isDragging) return;
                                        isDragging = false;
                                        cursorShape = Qt.OpenHandCursor;
                                        var threshold = playerHinoki.slotHeight * 0.38;

                                        if (pColItem.trackOffsetY <= -threshold && Engine.canSlideColumn(Engine.playerGrid, cIdx, -1)) {
                                            root.handlePlayerSlide(cIdx, -1);
                                        } else if (pColItem.trackOffsetY >= threshold && Engine.canSlideColumn(Engine.playerGrid, cIdx, 1)) {
                                            root.handlePlayerSlide(cIdx, 1);
                                        } else {
                                            pSnapBack.restart();
                                        }
                                    }

                                    NumberAnimation {
                                        id: pSnapBack; target: pColItem; property: "trackOffsetY"; to: 0; duration: 90; easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // CENTER DIVIDER: SCOREBOARD, TIMER, & GARBAGE GAUGES
            // -----------------------------------------------------------------
            Rectangle {
                id: centerDivider
                visible: !dualArena.isSolo
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: Math.round((parent.width - width) / 2)
                width: dualArena.centerWidth
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 10

                Column {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: (dualArena.height < 520) ? 6 : 12

                    // VS Emblem
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: (parent.width < 60) ? 28 : 36
                        height: (parent.width < 60) ? 28 : 36
                        radius: width / 2
                        color: "#ef4444"
                        border.color: "#ffffff"; border.width: 1.5
                        Text { anchors.centerIn: parent; text: "VS"; font.pixelSize: (parent.width < 60) ? 10 : 12; font.bold: true; color: "#fff" }
                    }

                    // Scoreboard
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        Text { text: "YOU"; font.pixelSize: 8; font.bold: true; color: "#38bdf8"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.playerScore.toLocaleString(); font.pixelSize: (parent.width < 60) ? 10 : 12; font.bold: true; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter }
                        Rectangle { width: (parent.width < 60) ? 36 : 46; height: 1; color: root.themeBorder; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "RIVAL"; font.pixelSize: 8; font.bold: true; color: "#f87171"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: root.aiScore.toLocaleString(); font.pixelSize: (parent.width < 60) ? 10 : 12; font.bold: true; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    // Drop countdown indicator
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        Text { text: "DROP"; font.pixelSize: 7; font.bold: true; color: "#a1a1aa"; anchors.horizontalCenter: parent.horizontalCenter }
                        Rectangle {
                            width: 10; height: (dualArena.height < 520) ? 36 : 48; radius: 5; color: "#27272a"
                            anchors.horizontalCenter: parent.horizontalCenter
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: parent.height * (root.dropCountdown / 16.0)
                                radius: 5; color: root.dropCountdown <= 3 ? "#ef4444" : "#eab308"
                            }
                        }
                        Text { text: Math.ceil(root.dropCountdown) + "s"; font.pixelSize: 8; font.bold: true; color: "#eab308"; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    // Garbage indicators
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        visible: dualArena.height >= 480
                        Text { text: "IN"; font.pixelSize: 7; color: "#a1a1aa"; anchors.horizontalCenter: parent.horizontalCenter }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Text { text: "P:" + root.playerGarbageCount; font.pixelSize: 8; color: "#38bdf8" }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Text { text: "AI:" + root.aiGarbageCount; font.pixelSize: 8; color: "#f87171" }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // RIGHT BOARD: COMPUTER AI (RIVAL MASTER)
            // -----------------------------------------------------------------
            Rectangle {
                id: aiTatami
                visible: !dualArena.isSolo
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: parent.width - width
                width: dualArena.boardWidth
                color: root.tatamiGreen
                radius: 12
                border.color: root.tatamiBorder
                border.width: 3
                clip: true

                property real shakeOffset: 0.0
                transform: Translate { x: aiTatami.shakeOffset }

                Canvas {
                    anchors.fill: parent
                    opacity: 0.20
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1;
                        for (var y = 0; y < height; y += 4) {
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                        }
                    }
                }

                // Silk Heri border right
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 14; color: root.tatamiBorder
                    Rectangle { anchors.left: parent.left; width: 1.5; height: parent.height; color: root.kintsugiGold; opacity: 0.7 }
                }

                Rectangle {
                    id: aiHinoki
                    anchors.fill: parent
                    anchors.margins: (parent.width < 220) ? 6 : 12
                    anchors.rightMargin: (parent.width < 220) ? 10 : 18
                    color: root.hinokiWood
                    border.color: root.hinokiDark
                    border.width: 2.5
                    radius: 10

                    readonly property real fluteWidth: (width - 24) / 5.0
                    readonly property real slotHeight: (height - 24) / 11.0
                    readonly property real marbleSize: Math.min(fluteWidth * 0.88, slotHeight * 0.94)


                    // Urushi Pitch Line Underlay (Row 5)
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 4
                        y: 12 + 5 * aiHinoki.slotHeight
                        height: aiHinoki.slotHeight
                        color: root.urushiPitch
                        border.color: root.kintsugiGold
                        border.width: 1.5
                        radius: 6
                        z: 0

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            text: "PITCH"; font.pixelSize: 8; font.bold: true; color: root.kintsugiGold; opacity: 0.8
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            text: "得点線"; font.pixelSize: 8; font.bold: true; color: root.kintsugiGold; opacity: 0.8
                        }
                    }

                    // 5 Chutes
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        z: 10

                        Repeater {
                            id: aiColRepeater
                            model: 5

                            Item {
                                id: aColItem
                                readonly property int cIdx: index
                                width: aiHinoki.fluteWidth
                                height: aiHinoki.height - 18
                                clip: true

                                property real trackOffsetY: 0.0
                                property real colRoll: root.aiRollAngles[cIdx]

                                function slideTrack(dir, onDone) {
                                    var targetY = (dir === -1) ? -aiHinoki.slotHeight : aiHinoki.slotHeight;
                                    var targetRoll = (dir === -1) ? (colRoll - 1.25) : (colRoll + 1.25);
                                    aSlideAnim.toY = targetY;
                                    aSlideAnim.toRoll = targetRoll;
                                    aSlideAnim.callback = onDone;
                                    aSlideAnim.restart();
                                }

                                function shatterRow5() {
                                    var m5 = aSlotRepeater.itemAt(5);
                                    if (m5 && m5.triggerPieceShatter) m5.triggerPieceShatter();
                                }

                                SequentialAnimation {
                                    id: aSlideAnim
                                    property real toY: 0
                                    property real toRoll: 0
                                    property var callback: null

                                    ParallelAnimation {
                                        NumberAnimation { target: aColItem; property: "trackOffsetY"; to: aSlideAnim.toY; duration: 140; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: aColItem; property: "colRoll"; to: aSlideAnim.toRoll; duration: 140; easing.type: Easing.OutQuad }
                                    }
                                    ScriptAction {
                                        script: {
                                            aColItem.trackOffsetY = 0.0;
                                            if (aSlideAnim.callback) aSlideAnim.callback();
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: (root.aiSelectedCol === cIdx) ? Qt.darker(root.hinokiWood, 1.20) : Qt.darker(root.hinokiWood, 1.12)
                                    border.color: (root.aiSelectedCol === cIdx) ? "#f87171" : root.hinokiDark
                                    border.width: (root.aiSelectedCol === cIdx) ? 2.0 : 1.2

                                    Rectangle {
                                        y: 5 * aiHinoki.slotHeight + (parent.height - 11 * aiHinoki.slotHeight) / 2
                                        width: parent.width; height: aiHinoki.slotHeight
                                        color: root.urushiPitch; opacity: 0.88; border.color: root.kintsugiGold; border.width: 1.2
                                    }
                                }

                                // AI Active Selection Arrow
                                Rectangle {
                                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: -6; width: 18; height: 10; radius: 3
                                    color: "#f87171"; visible: root.aiSelectedCol === cIdx; z: 25
                                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 6; color: "#fff" }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 11 * aiHinoki.slotHeight
                                    y: ((parent.height - height) / 2) + aColItem.trackOffsetY

                                    Column {
                                        anchors.fill: parent
                                        spacing: 0

                                        Repeater {
                                            id: aSlotRepeater
                                            model: 11

                                            Item {
                                                readonly property int rIdx: index
                                                width: aiHinoki.fluteWidth
                                                height: aiHinoki.slotHeight

                                                function triggerPieceShatter() {
                                                    if (aMarble.visible) aMarble.triggerShatter();
                                                }


                                                MarblePiece {
                                                    id: aMarble
                                                    anchors.centerIn: parent
                                                    width: aiHinoki.marbleSize
                                                    height: aiHinoki.marbleSize
                                                    visible: root.aiBoard[cIdx] && root.aiBoard[cIdx][rIdx] !== null
                                                    marbleType: (root.aiBoard[cIdx] && root.aiBoard[cIdx][rIdx]) ? root.aiBoard[cIdx][rIdx].type : "ramune"
                                                    rollAngle: aColItem.colRoll
                                                    z: 15
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Board Shake Animations
            SequentialAnimation {
                id: playerShakeAnim
                NumberAnimation { target: playerTatami; property: "shakeOffset"; to: -10; duration: 35 }
                NumberAnimation { target: playerTatami; property: "shakeOffset"; to: 10; duration: 35 }
                NumberAnimation { target: playerTatami; property: "shakeOffset"; to: -6; duration: 35 }
                NumberAnimation { target: playerTatami; property: "shakeOffset"; to: 6; duration: 35 }
                NumberAnimation { target: playerTatami; property: "shakeOffset"; to: 0; duration: 35 }
            }

            SequentialAnimation {
                id: aiShakeAnim
                NumberAnimation { target: aiTatami; property: "shakeOffset"; to: -10; duration: 35 }
                NumberAnimation { target: aiTatami; property: "shakeOffset"; to: 10; duration: 35 }
                NumberAnimation { target: aiTatami; property: "shakeOffset"; to: -6; duration: 35 }
                NumberAnimation { target: aiTatami; property: "shakeOffset"; to: 6; duration: 35 }
                NumberAnimation { target: aiTatami; property: "shakeOffset"; to: 0; duration: 35 }
            }

            // Flying Attack Projectile
            Item {
                id: attackProjectile
                width: 36
                height: 36
                visible: false
                z: 140

                property bool isPlayerAttacking: true
                property int queuedGarbage: 0
                property int queuedBasalt: 0

                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    color: attackProjectile.isPlayerAttacking ? "#38bdf8" : "#ef4444"
                    border.color: "#ffffff"; border.width: 2.5
                    opacity: 0.95

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: 6
                        color: "#ffffff"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 42; height: 42; radius: 21
                        color: "transparent"
                        border.color: attackProjectile.isPlayerAttacking ? "#7dd3fc" : "#fca5a5"
                        border.width: 2
                        opacity: 0.75
                    }
                }

                NumberAnimation {
                    id: projAnim
                    target: attackProjectile
                    property: "x"
                    duration: 250
                    easing.type: Easing.InOutQuad
                    onStopped: {
                        attackProjectile.visible = false;
                        root.playSound("clack");
                        if (attackProjectile.isPlayerAttacking) {
                            aiShakeAnim.restart();
                        } else {
                            playerShakeAnim.restart();
                        }
                        Engine.injectAttack(!attackProjectile.isPlayerAttacking, attackProjectile.queuedGarbage, attackProjectile.queuedBasalt);
                        root.syncBoards();
                    }
                }
            }

            // Game Over Modal Backdrop
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.72)
                visible: root.isGameOver
                z: 149
                MouseArea { anchors.fill: parent }
            }

            // Game Over Modal Card
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 380)
                height: 200
                radius: 14
                color: root.themeCardBg
                border.color: (root.winner === "player" || (root.gameMode === "solo" && root.playerScore > 0)) ? "#22c55e" : "#ef4444"
                border.width: 2.5
                visible: root.isGameOver
                z: 150

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Text {
                        text: (root.gameMode === "solo")
                            ? "PRACTICE OVER"
                            : (root.winner === "player" ? "VICTORY!" : "CHUTE OVERFLOW")
                        font.pixelSize: 22; font.bold: true
                        color: (root.winner === "player" || (root.gameMode === "solo" && root.playerScore > 0)) ? "#22c55e" : "#ef4444"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: (root.gameMode === "solo")
                            ? ("Final Score: " + root.playerScore.toLocaleString() + " • Best: " + root.bestScore.toLocaleString())
                            : (root.winner === "player" ? "You overwhelmed the Rival Master!" : "Your chutes were completely jammed!")
                        font.pixelSize: 13; color: "#f8fafc"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Rectangle {
                        height: 38; width: 160; radius: 8; color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text { anchors.centerIn: parent; text: (root.gameMode === "solo") ? "Play Again (R)" : "Rematch (R)"; font.pixelSize: 13; font.bold: true; color: "#fff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.startNewMatch() }
                    }
                }
            }
        }

        // =====================================================================
        // TEMPLATE-STANDARDIZED HELP MODAL
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
                width: Math.min(parent.width * 0.90, 420)
                height: Math.min(parent.height * 0.90, helpCol.implicitHeight + 48)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1.5
                radius: 12
                clip: true

                MouseArea { anchors.fill: parent }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 20
                    contentHeight: helpCol.implicitHeight
                    clip: true

                    Column {
                        id: helpCol
                        width: parent.width
                        spacing: 14

                        Text {
                            text: "HOW TO PLAY BĪDAMA"
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
                            height: 34
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
        }

        // =====================================================================
        // TOAST NOTIFICATIONS (Attacks, Drops, Status)
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.top: headerItem.bottom
            anchors.topMargin: root.isTiledDesktopMode ? 6 : 10
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            width: toastText.implicitWidth + 32
            radius: 17
            color: "#13131c"
            border.color: root.kintsugiGold
            border.width: 1.5
            opacity: 0
            z: 300

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: "#FFFFFF"
            }

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; to: 1; duration: 150 }
                PauseAnimation { duration: 2200 }
                NumberAnimation { target: soundToast; property: "opacity"; to: 0; duration: 250 }
            }
        }
    }

    // Canonical Splash Screen
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        focusTarget: mainContainer
        z: 1000
    }
}
