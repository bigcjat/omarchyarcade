import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 740
    minimumWidth: 300
    minimumHeight: 300
    title: "Fold"

    // =========================================================================
    // OMARCHY THEME TOKENS
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#F28482" // Sakura Rose
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    // =========================================================================
    // PERSISTENCE & SETTINGS
    // =========================================================================
    property int unlockedLevel: 1
    property int lastPlayedLevel: 1
    property bool isMuted: true
    property bool showHelp: false
    property string helpText: "• Objective: Unify the entire origami paper canvas into a single solid color within the target move limit (Par).\n\n" +
                              "• How to Play:\n" +
                              "  1. Choose Color: Click a color in the bottom palette or press keys 1, 2, 3, 4.\n" +
                              "  2. Fold Paper: Tap any paper region to fold and flip it into the chosen color.\n" +
                              "  3. Merge & Expand: Adjacent matching paper regions join into one unified region.\n" +
                              "  4. Perfect Score: Solve in Par moves for 3 Stars (★★★)!\n\n" +
                              "• Keyboard Controls:\n" +
                              "  - 1..4: Select color swatch\n" +
                              "  - Click: Fold region into active color\n" +
                              "  - U / Ctrl+Z: Undo move\n" +
                              "  - R: Restart stage\n" +
                              "  - L: Stage select (1–100)\n" +
                              "  - D: Cycle mesh density (Zen / Standard / Detailed / Master)\n" +
                              "  - M: Toggle sound\n" +
                              "  - Shift+F: Compact / Tiled view\n" +
                              "  - ? / Esc: Help / Close"
    property bool showLevelSelect: false
    property bool splashEnabled: true
    property bool isTiledDesktopMode: root.height < 520 || root.width < 440
    property bool isCompactHud: root.height < 680 || root.width < 480
    property alias fullPlayfield: root.isTiledDesktopMode
    property bool stretchToFill: true

    // Hover highlight state
    property int hoveredR: -1
    property int hoveredC: -1
    property var hoveredRegionSet: ({})

    // UI state
    property var activePalette: []
    property int currentStage: 1
    property int currentMoves: 0
    property int currentPar: 1
    property int selectedColorIdx: 0
    property string levelTitle: "Stage 1 • Ukiyo-e"
    property string paletteTheme: ""
    property bool isWon: false
    property int earnedStars: 0
    property int stagePage: 0

    // Paper Mesh Density (0: Compact 16 rows, 1: Standard 24 rows, 2: Detailed 30 rows, 3: Master 36 rows)
    property int paperDensity: 1
    property var densityNames: ["Compact (16)", "Standard (24)", "Detailed (30)", "Master (36)"]

    function cyclePaperDensity() {
        paperDensity = (paperDensity + 1) % 4;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setValue("paperDensity", "" + paperDensity);
        }
        soundToast.show("📐 Paper Mesh: " + densityNames[paperDensity]);
        restartLevel();
    }

    // Active fold animation state (stops loop timer when idle for 0% idle CPU)
    property bool isFolding: false

    // Animation frame timer (~60 FPS) - only runs while paper is actively folding
    Timer {
        id: gameLoop
        interval: 16
        running: root.isFolding
        repeat: true
        onTriggered: {
            Engine.update(0.016, root.callbacks);
        }
    }

    // Callbacks passed to JS engine
    property var callbacks: ({
        onSound: function(name) {
            root.playSound(name);
        },
        onUpdateUI: function() {
            root.isFolding = (Engine.gameState === "folding");
            root.updateUI();
        },
        onNeedRedraw: function() {
            animCanvas.requestPaint();
        },
        onWin: function(moves, par, stars) {
            root.isWon = true;
            root.earnedStars = stars;
            if (typeof settingsManager !== "undefined" && settingsManager) {
                settingsManager.setStars(Engine.currentLevel, stars);
                if (Engine.currentLevel >= root.unlockedLevel) {
                    root.unlockedLevel = Engine.currentLevel + 1;
                    settingsManager.setUnlockedLevel(root.unlockedLevel);
                }}
            confettiEmitter.burst(50);
            autoAdvanceTimer.restart();
        }
    })

    function playSound(name) {
        if (!isMuted && typeof soundManager !== "undefined" && soundManager) {
            soundManager.play(name);
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (!isMuted) playSound("palette_select");
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function calculateGridSize() {
        var w = (boardContainer && boardContainer.width > 50) ? boardContainer.width : (root.width - 24);
        var h = (boardContainer && boardContainer.height > 50) ? boardContainer.height : (root.height - 180);
        if (w <= 50 || h <= 50) return { rows: 24, cols: 42 };
        var ratio = w / h;

        var baseRows = [16, 24, 30, 36][root.paperDensity] || 24;
        if (h < 420 && baseRows > 20) baseRows = Math.max(16, baseRows - 4);

        var targetCols = Math.round(baseRows * 1.732 * ratio);
        // Guarantee even number of columns for bilateral origami symmetry
        if (targetCols % 2 !== 0) targetCols += 1;
        targetCols = Math.max(12, Math.min(60, targetCols));
        return { rows: baseRows, cols: targetCols };
    }

    function updateUI() {
        activePalette = Engine.palette || [];
        currentStage = Engine.currentLevel;
        currentMoves = Engine.moves;
        currentPar = Engine.par;
        selectedColorIdx = Engine.selectedColor;
        levelTitle = Engine.levelName;
        paletteTheme = Engine.paletteTheme || "";
        isWon = (Engine.gameState === "won");
        staticCanvas.requestPaint();
        animCanvas.requestPaint();
    }

    function restartLevel() {
        isWon = false;
        isFolding = false;
        var dim = calculateGridSize();
        Engine.initLevel(Engine.currentLevel, dim.rows, dim.cols, callbacks);
        if (typeof soundManager !== "undefined" && soundManager && !isMuted) {
            soundManager.play("paper_snap");
        }
        updateUI();
    }

    function jumpToLevel(lvl) {
        autoAdvanceTimer.stop();
        isWon = false;
        isFolding = false;
        var dim = calculateGridSize();
        Engine.initLevel(lvl, dim.rows, dim.cols, callbacks);
        if (typeof settingsManager !== "undefined" && settingsManager) {
            settingsManager.setLastLevel(lvl);
        }
        updateUI();
    }

    function nextLevel() {
        autoAdvanceTimer.stop();
        isWon = false;
        isFolding = false;
        jumpToLevel(Engine.currentLevel + 1);
    }

    function prevLevel() {
        autoAdvanceTimer.stop();
        isWon = false;
        isFolding = false;
        if (Engine.currentLevel > 1) {
            jumpToLevel(Engine.currentLevel - 1);
        }
    }

    function undoMove() {
        if (isWon) return;
        isFolding = false;
        Engine.undo(callbacks);
    }

    function foldTriangle(r, c) {
        var ok = Engine.foldAt(r, c, callbacks);
        if (ok) isFolding = true;
        return ok;
    }

    function getNextHint() {
        return Engine.getHint();
    }

    function foldNextHint() {
        var hint = Engine.getHint();
        if (hint) {
            return foldTriangle(hint.r, hint.c);
        }
        return false;
    }

    function selectColor(cIdx) {
        Engine.selectPaletteColor(cIdx, callbacks);
    }

    Timer {
        id: autoAdvanceTimer
        interval: 1600
        repeat: false
        onTriggered: {
            if (root.isWon) {
                root.nextLevel();
            }
        }
    }

    function applyTheme(themeData, themeName) {
        if (!themeData) return;
        if (themeData["background"]) themeBg = themeData["background"];
        if (themeData["board_bg"]) themeBoardBg = themeData["board_bg"];
        else if (themeData["background"]) themeBoardBg = Qt.darker(themeData["background"], 1.15);
        if (themeData["surface"] || themeData["card_bg"]) themeCardBg = themeData["surface"] || themeData["card_bg"];
        if (themeData["border"]) themeBorder = themeData["border"];
        if (themeData["foreground"]) themeFg = themeData["foreground"];
        if (themeData["subtext"]) themeSubtext = themeData["subtext"];
        if (themeData["accent"]) themeAccent = themeData["accent"];
    }

    function captureScreenshot(filePath, shouldQuit) {
        var targetItem = (splashScreen && splashScreen.visible && splashScreen.opacity > 0) ? splashScreen : mainContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved to " + filePath);
            if (shouldQuit) Qt.quit();
        });
    }

    Component.onCompleted: {
        var startLvl = 1;
        if (typeof settingsManager !== "undefined" && settingsManager) {
            root.unlockedLevel = settingsManager.getUnlockedLevel();
            startLvl = settingsManager.getLastLevel();
            var savedDensity = settingsManager.getValue("paperDensity", "1");
            root.paperDensity = parseInt(savedDensity) || 1;
        }
        root.jumpToLevel(startLvl);
    }

    // =========================================================================
    // KEYBOARD NAVIGATION
    // =========================================================================
    Item {
        focus: true
        anchors.fill: parent
        Keys.onPressed: function(event) {
            if (splashScreen && splashScreen.visible) {
                splashScreen.visible = false;
                event.accepted = true;
                return;
            }

            // Quick color selection via number keys 1..9
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                var cIdx = event.key - Qt.Key_1;
                if (cIdx < Engine.palette.length) {
                    Engine.selectPaletteColor(cIdx, callbacks);
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_U || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Z)) {
                root.undoMove();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.restartLevel();
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                root.cyclePaperDensity();
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                root.showLevelSelect = !root.showLevelSelect;
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
            } else if (event.key === Qt.Key_N) {
                root.nextLevel();
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                root.prevLevel();
                event.accepted = true;
            } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ShiftModifier)) {
                root.isMicroHud = !root.isMicroHud;
                event.accepted = true;
            } else if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (root.showHelp) root.showHelp = false;
                else if (root.showLevelSelect) root.showLevelSelect = false;
                else root.isMicroHud = false;
                event.accepted = true;
            }
        }
    }

    // =========================================================================
    // MAIN CONTAINER
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg

        // =====================================================================
        // 1. STANDARD TOP HEADER (Visible when !isTiledDesktopMode)
        // =====================================================================
        Item {
            id: headerItem
            visible: !root.isTiledDesktopMode
            anchors.top: parent.top
            anchors.topMargin: visible ? (root.isCompactHud ? 6 : 10) : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.isCompactHud ? 8 : 14
            anchors.rightMargin: root.isCompactHud ? 8 : 14
            height: visible ? (root.isCompactHud ? 46 : 60) : 0

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
                    text: "Tactile Paper Folding & Crease Logic Puzzle"
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards (Stage & Moves)
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: root.isCompactHud ? 60 : 70
                    height: root.isCompactHud ? 42 : 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            text: "STAGE"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "" + root.currentStage
                            font.pixelSize: root.isCompactHud ? 15 : 17
                            font.bold: true
                            color: root.themeFg
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Rectangle {
                    width: root.isCompactHud ? 70 : 80
                    height: root.isCompactHud ? 42 : 48
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.currentMoves > root.currentPar ? "#EF4444" : root.themeBorder
                    border.width: root.currentMoves > root.currentPar ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            text: "MOVES"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Text {
                                text: "" + root.currentMoves
                                font.pixelSize: root.isCompactHud ? 15 : 17
                                font.bold: true
                                color: root.currentMoves <= root.currentPar ? root.themeAccent : "#EF4444"
                            }
                            Text {
                                text: " / " + root.currentPar
                                font.pixelSize: root.isCompactHud ? 11 : 12
                                font.bold: true
                                color: root.themeSubtext
                                anchors.baseline: parent.children[0].baseline
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. SUBHEADER CONTROLS TOOLBAR (Visible when !isTiledDesktopMode)
        // =====================================================================
        Item {
            id: subheaderItem
            visible: !root.isTiledDesktopMode
            anchors.top: headerItem.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.isCompactHud ? 4 : 6
            anchors.leftMargin: root.isCompactHud ? 8 : 14
            anchors.rightMargin: root.isCompactHud ? 8 : 14
            height: visible ? (root.isCompactHud ? 30 : 34) : 0
            property bool isCrowded: width < 420

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    // How to Play
                    Rectangle {
                        height: 32
                        width: subheaderItem.isCrowded ? 32 : 68
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "❓"; font.pixelSize: 11 }
                            Text {
                                text: "Help"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = !root.showHelp
                        }
                    }

                    // Stages Modal
                    Rectangle {
                        height: 32
                        width: subheaderItem.isCrowded ? 32 : 74
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "📑"; font.pixelSize: 11 }
                            Text {
                                text: "Stages"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showLevelSelect = !root.showLevelSelect
                        }
                    }

                    // Undo Button
                    Rectangle {
                        height: 32
                        width: subheaderItem.isCrowded ? 32 : 68
                        radius: 6
                        color: root.themeCardBg
                        border.color: Engine.undoStack.length > 0 ? root.themeAccent : root.themeBorder
                        border.width: 1
                        opacity: Engine.undoStack.length > 0 ? 1.0 : 0.45

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "↶"; font.pixelSize: 12; font.bold: true; color: root.themeFg }
                            Text {
                                text: "Undo"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.undoMove()
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    // Paper Mesh Density Selector
                    Rectangle {
                        height: 32
                        width: subheaderItem.isCrowded ? 32 : 94
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "📐"; font.pixelSize: 11 }
                            Text {
                                text: root.densityNames[root.paperDensity]
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cyclePaperDensity()
                        }
                    }

                    // Audio Mute Toggle (Icon Button)
                    Rectangle {
                        height: 32
                        width: 32
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.isMuted ? root.themeBorder : root.themeAccent
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

                    // Restart Level
                    Rectangle {
                        height: 32
                        width: subheaderItem.isCrowded ? 32 : 72
                        radius: 6
                        color: root.themeCardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "🔄"; font.pixelSize: 11 }
                            Text {
                                text: "Reset"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.themeFg
                                visible: !subheaderItem.isCrowded
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.restartLevel()
                        }
                    }
                }
            }

        // =====================================================================
        // TILING DESKTOP FLOATING HUD (Row 1 Compact when isTiledDesktopMode)
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
                    text: "Fold"
                    font.pixelSize: 12
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    text: "• LVL " + root.currentStage
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeFg
                }
                Text {
                    text: "• MOVES: " + root.currentMoves + " / " + root.currentPar
                    font.pixelSize: 10
                    color: root.currentMoves > root.currentPar ? "#EF4444" : root.themeSubtext
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↶"; font.pixelSize: 12; font.bold: true; color: root.themeFg; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.undoMove()
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "📑"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showLevelSelect = !root.showLevelSelect
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "?"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 5
                    color: "transparent"; border.color: root.themeBorder; border.width: 1
                    Text { text: "↺"; font.pixelSize: 12; font.bold: true; color: root.themeAccent; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartLevel()
                    }
                }
            }
        }

        // =====================================================================
        // 3. PLAYFIELD BOARD CONTAINER
        // =====================================================================
        Rectangle {
            id: boardContainer
            anchors.top: root.isTiledDesktopMode ? floatingTiledHUD.bottom : subheaderItem.bottom
            anchors.bottom: paletteBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.isTiledDesktopMode ? 8 : 10
            anchors.bottomMargin: 8
            anchors.leftMargin: root.isTiledDesktopMode ? 10 : (root.isCompactHud ? 8 : 12)
            anchors.rightMargin: root.isTiledDesktopMode ? 10 : (root.isCompactHud ? 8 : 12)
            radius: 12
            color: root.themeBoardBg
            border.color: root.themeBorder
            border.width: 1
            clip: true

            property real currW: 0
            property real currH: 0
            property real currHalfW: 0
            property real currOffsetX: 0
            property real currOffsetY: 0

            // 1. Static Canvas: Renders complete paper sheet once (texture, triangles, crease lines, bevels)
            // Stays completely static during fold wave animations - 0 CPU & 0 GPU draw calls while folding!
            Canvas {
                id: staticCanvas
                anchors.fill: parent
                anchors.margins: 8

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Component.onCompleted: {
                    loadImage("paper_texture.png");
                }
                onImageLoaded: {
                    requestPaint();
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var rows = Engine.rows;
                    var cols = Engine.cols;
                    if (!rows || !cols) return;

                    var W, H, halfW, offsetX, offsetY;

                    if (root.stretchToFill) {
                        H = height / rows;
                        halfW = width / (cols - 1);
                        W = halfW * 2.0;
                        offsetX = 0;
                        offsetY = 0;
                    } else {
                        var targetRatio = (cols - 1) * 0.5 / (rows * 0.866025);
                        var canvasRatio = width / height;

                        if (canvasRatio > targetRatio) {
                            H = height / rows;
                            halfW = H / 1.73205;
                            W = halfW * 2.0;
                            var totalW = (cols - 1) * halfW;
                            offsetX = (width - totalW) / 2.0;
                            offsetY = 0;
                        } else {
                            halfW = width / (cols - 1);
                            W = halfW * 2.0;
                            H = halfW * 1.73205;
                            var totalH = rows * H;
                            offsetX = 0;
                            offsetY = (height - totalH) / 2.0;
                        }
                    }

                    // Save metrics for mouse interaction and animCanvas
                    boardContainer.currW = W;
                    boardContainer.currH = H;
                    boardContainer.currHalfW = halfW;
                    boardContainer.currOffsetX = offsetX;
                    boardContainer.currOffsetY = offsetY;

                    var pal = Engine.palette;
                    if (!pal || pal.length === 0) return;

                    var sheetW = (cols - 1) * halfW;
                    var sheetH = rows * H;

                    // 1. Subtle Paper Sheet Drop Shadow on background mat
                    ctx.save();
                    ctx.fillStyle = Qt.rgba(0, 0, 0, 0.35);
                    ctx.beginPath();
                    ctx.rect(offsetX + 6, offsetY + 8, sheetW, sheetH);
                    ctx.fill();
                    ctx.restore();

                    function isTriUp(r, c) {
                        if (c === 0) return (r % 2 !== 0);
                        if (c === cols - 1) return ((r + (cols - 2) - 1) % 2 !== 0);
                        return (((r + (c - 1)) % 2) === 0);
                    }

                    function traceTri(r, c, ox, oy) {
                        var topY = oy + r * H;
                        var botY = topY + H;

                        if (c === 0) {
                            if (r % 2 === 0) {
                                ctx.moveTo(ox, topY);
                                ctx.lineTo(ox + halfW, topY);
                                ctx.lineTo(ox, botY);
                            } else {
                                ctx.moveTo(ox, topY);
                                ctx.lineTo(ox, botY);
                                ctx.lineTo(ox + halfW, botY);
                            }
                        } else if (c === cols - 1) {
                            var numMain = cols - 2;
                            var rx = ox + numMain * halfW;
                            var rx2 = ox + (numMain + 1) * halfW;
                            if ((r + numMain - 1) % 2 === 0) {
                                ctx.moveTo(rx, topY);
                                ctx.lineTo(rx2, topY);
                                ctx.lineTo(rx2, botY);
                            } else {
                                ctx.moveTo(rx, botY);
                                ctx.lineTo(rx2, topY);
                                ctx.lineTo(rx2, botY);
                            }
                        } else {
                            var origC = c - 1;
                            var bx = ox + origC * halfW;
                            if ((r + origC) % 2 === 0) {
                                ctx.moveTo(bx + halfW, topY);
                                ctx.lineTo(bx, botY);
                                ctx.lineTo(bx + W, botY);
                            } else {
                                ctx.moveTo(bx, topY);
                                ctx.lineTo(bx + W, topY);
                                ctx.lineTo(bx + halfW, botY);
                            }
                        }
                        ctx.closePath();
                    }

                    // PASS 1: Base Recessed Triangles (pointing-up)
                    for (var r = 0; r < rows; r++) {
                        for (var c = 0; c < cols; c++) {
                            if (!isTriUp(r, c)) continue;

                            var colIdx = Engine.grid[r][c];
                            var colorObj = pal[colIdx];
                            if (!colorObj) continue;

                            ctx.fillStyle = colorObj.hex;
                            ctx.beginPath();
                            traceTri(r, c, offsetX, offsetY);
                            ctx.fill();

                            // Subtle base ambient tone
                            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.04);
                            ctx.fill();

                            // Valley crease line
                            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.18);
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }
                    }

                    // Drop-shadow pass for raised triangles
                    ctx.fillStyle = Qt.rgba(0, 0, 0, 0.22);
                    for (var r = 0; r < rows; r++) {
                        for (var c = 0; c < cols; c++) {
                            if (isTriUp(r, c)) continue;

                            ctx.beginPath();
                            traceTri(r, c, offsetX + 2.5, offsetY + 3.5);
                            ctx.fill();
                        }
                    }

                    // PASS 2: Raised Triangles (pointing-down)
                    for (var r = 0; r < rows; r++) {
                        for (var c = 0; c < cols; c++) {
                            if (isTriUp(r, c)) continue;

                            var colIdx = Engine.grid[r][c];
                            var colorObj = pal[colIdx];
                            if (!colorObj) continue;

                            ctx.fillStyle = colorObj.hex;
                            ctx.beginPath();
                            traceTri(r, c, offsetX, offsetY);
                            ctx.fill();

                            // Subtle top facet highlight
                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.035);
                            ctx.fill();

                            // Top ridge paper bevel highlight
                            if (c > 0 && c < cols - 1) {
                                var origC = c - 1;
                                var bx = offsetX + origC * halfW;
                                var ty = offsetY + r * H;
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.40);
                                ctx.lineWidth = 1;
                                ctx.beginPath();
                                ctx.moveTo(bx, ty);
                                ctx.lineTo(bx + W, ty);
                                ctx.stroke();
                            }
                        }
                    }

                    // Tactile Paper Texture Overlay
                    if (isImageLoaded("paper_texture.png")) {
                        ctx.save();
                        ctx.beginPath();
                        ctx.rect(offsetX, offsetY, sheetW, sheetH);
                        ctx.clip();
                        ctx.globalAlpha = 0.22;
                        var texTile = 256;
                        for (var ty = offsetY; ty < offsetY + sheetH; ty += texTile) {
                            for (var tx = offsetX; tx < offsetX + sheetW; tx += texTile) {
                                ctx.drawImage("paper_texture.png", tx, ty);
                            }
                        }
                        ctx.restore();
                    }
                }
            }

            // 2. Animation Overlay Canvas: Only renders active flipping flaps (~5-15 triangles)
            // Cleared every frame during wave animation; zero overhead on the rest of the board
            Canvas {
                id: animCanvas
                anchors.fill: parent
                anchors.margins: 8

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var folds = Engine.activeFolds;
                    if (!folds || folds.length === 0 || !root.isFolding) return;

                    var pal = Engine.palette;
                    if (!pal || pal.length === 0) return;

                    var W = boardContainer.currW;
                    var H = boardContainer.currH;
                    var halfW = boardContainer.currHalfW;
                    var offsetX = boardContainer.currOffsetX;
                    var offsetY = boardContainer.currOffsetY;
                    var cols = Engine.cols;
                    if (!W || !H || !cols) return;

                    for (var i = 0; i < folds.length; i++) {
                        var af = folds[i];
                        if (af.elapsed < af.delay) continue;

                        var toCol = pal[af.toColor];
                        if (!toCol || !toCol.hex) continue;

                        var vOrig = Engine.getTriVertices(af.r, af.c, W, H, offsetX, offsetY);
                        if (!vOrig || vOrig.length < 3) continue;

                        // Orientation
                        var isUpTri;
                        if (af.c === 0) {
                            isUpTri = (af.r % 2 !== 0);
                        } else if (af.c === cols - 1) {
                            isUpTri = ((af.r + (cols - 2) - 1) % 2 !== 0);
                        } else {
                            isUpTri = (((af.r + (af.c - 1)) % 2) === 0);
                        }

                        // If already completed this flap flip, keep displaying the new color over static canvas
                        if (af.completed) {
                            ctx.fillStyle = toCol.hex;
                            ctx.beginPath();
                            ctx.moveTo(vOrig[0].x, vOrig[0].y);
                            ctx.lineTo(vOrig[1].x, vOrig[1].y);
                            ctx.lineTo(vOrig[2].x, vOrig[2].y);
                            ctx.closePath();
                            ctx.fill();

                            if (isUpTri) {
                                ctx.fillStyle = Qt.rgba(0, 0, 0, 0.04);
                                ctx.fill();
                                ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.18);
                                ctx.lineWidth = 1;
                                ctx.stroke();
                            } else {
                                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.035);
                                ctx.fill();
                            }
                            continue;
                        }

                        // FLAP IN MOTION:
                        // 1. Reveal hole underneath lifting flap (shows toColor)
                        ctx.fillStyle = toCol.hex;
                        ctx.beginPath();
                        ctx.moveTo(vOrig[0].x, vOrig[0].y);
                        ctx.lineTo(vOrig[1].x, vOrig[1].y);
                        ctx.lineTo(vOrig[2].x, vOrig[2].y);
                        ctx.closePath();
                        ctx.fill();

                        var baseP1, baseP2, apexP;
                        if (isUpTri) {
                            baseP1 = vOrig[1];
                            baseP2 = vOrig[2];
                            apexP = vOrig[0];
                        } else {
                            baseP1 = vOrig[0];
                            baseP2 = vOrig[1];
                            apexP = vOrig[2];
                        }

                        var t = Math.max(0, Math.min(1.0, (af.elapsed - af.delay) / af.duration));
                        var theta = t * Math.PI; // 0 to 180 degrees
                        var cosVal = Math.cos(theta);
                        var absCos = Math.abs(cosVal);
                        var sinVal = Math.sin(theta); // 0 -> 1 -> 0
                        var zHeight = sinVal * 26.0;

                        // Flap apex 2D coordinates as it rotates in 3D around hinge base
                        var currApexX = apexP.x;
                        var currApexY = baseP1.y + (apexP.y - baseP1.y) * absCos;
                        var currPts = isUpTri ? 
                            [{ x: currApexX, y: currApexY }, baseP1, baseP2] : 
                            [baseP1, baseP2, { x: currApexX, y: currApexY }];

                        // 2. Dynamic Drop Shadow cast onto sheet below lifting flap
                        if (zHeight > 0.8) {
                            ctx.save();
                            var shDx = zHeight * 0.35 + 2;
                            var shDy = zHeight * 0.45 + 3;
                            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.30 * sinVal);
                            ctx.beginPath();
                            if (isUpTri) {
                                ctx.moveTo(currApexX + shDx, currApexY + shDy);
                                ctx.lineTo(baseP1.x + 2, baseP1.y + 2);
                                ctx.lineTo(baseP2.x + 2, baseP2.y + 2);
                            } else {
                                ctx.moveTo(baseP1.x + 2, baseP1.y + 2);
                                ctx.lineTo(baseP2.x + 2, baseP2.y + 2);
                                ctx.lineTo(currApexX + shDx, currApexY + shDy);
                            }
                            ctx.closePath();
                            ctx.fill();
                            ctx.restore();
                        }

                        // 3. Folding Paper Flap Face
                        var drawColor = (theta < Math.PI / 2) ? pal[af.fromColor] : toCol;
                        if (!drawColor || !drawColor.hex) continue;
                        var flapLight = 0.85 + 0.15 * absCos;

                        ctx.save();
                        ctx.fillStyle = drawColor.hex;
                        ctx.beginPath();
                        ctx.moveTo(currPts[0].x, currPts[0].y);
                        ctx.lineTo(currPts[1].x, currPts[1].y);
                        ctx.lineTo(currPts[2].x, currPts[2].y);
                        ctx.closePath();
                        ctx.fill();

                        // Two-tone fold lighting as flap lifts and tilts
                        if (theta < Math.PI / 2) {
                            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.16 * (1.0 - absCos));
                        } else {
                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.10 * (1.0 - absCos));
                        }
                        ctx.fill();

                        // Crease line along hinge base
                        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.30);
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.moveTo(baseP1.x, baseP1.y);
                        ctx.lineTo(baseP2.x, baseP2.y);
                        ctx.stroke();

                        // Crisp lifting edge highlight
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.45 * flapLight);
                        ctx.lineWidth = 1.0;
                        ctx.beginPath();
                        ctx.moveTo(baseP1.x, baseP1.y);
                        ctx.lineTo(currApexX, currApexY);
                        ctx.lineTo(baseP2.x, baseP2.y);
                        ctx.stroke();
                        ctx.restore();
                    }
                }
            }

            // 3. Mouse Interaction on top of both canvases (strictly NO mouseover effects)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    var hit = Engine.findTriAt(mouse.x, mouse.y, boardContainer.currW, boardContainer.currH, boardContainer.currOffsetX, boardContainer.currOffsetY);
                    if (hit) {
                        Engine.foldAt(hit.r, hit.c, root.callbacks);
                    }
                }
            }
        }

        // =====================================================================
        // 4. PALETTE SELECTION DOCK AT BOTTOM
        // =====================================================================
        Rectangle {
            id: paletteBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: root.isTiledDesktopMode ? 6 : (root.isCompactHud ? 6 : 12)
            anchors.leftMargin: root.isTiledDesktopMode ? 10 : (root.isCompactHud ? 8 : 12)
            anchors.rightMargin: root.isTiledDesktopMode ? 10 : (root.isCompactHud ? 8 : 12)
            height: root.isTiledDesktopMode ? 46 : (root.isCompactHud ? 48 : 58)
            radius: 10
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: root.isCompactHud ? 8 : 14

                Repeater {
                    model: root.activePalette

                    Rectangle {
                        id: swatchItem
                        property bool isSelected: (index === root.selectedColorIdx)
                        width: root.isCompactHud ? (isSelected ? 42 : 36) : (isSelected ? 52 : 44)
                        height: root.isCompactHud ? (isSelected ? 42 : 36) : (isSelected ? 52 : 44)
                        radius: 10
                        color: modelData.hex
                        border.color: isSelected ? "#ffffff" : Qt.rgba(0, 0, 0, 0.25)
                        border.width: isSelected ? 3 : 1
                        scale: isSelected ? 1.05 : 1.0

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        // Keyboard shortcut badge (1, 2, 3...)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: -4
                            width: 18
                            height: 18
                            radius: 9
                            color: root.themeCardBg
                            border.color: swatchItem.isSelected ? root.themeAccent : root.themeBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "" + (index + 1)
                                font.pixelSize: 10
                                font.bold: true
                                color: swatchItem.isSelected ? root.themeAccent : root.themeSubtext
                            }
                        }

                        // Subtle washi paper fold sheen
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, swatchItem.isSelected ? 0.25 : 0.08)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Engine.selectPaletteColor(index, root.callbacks);
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================

        // =====================================================================
        // VICTORY OVERLAY / MODAL
        // =====================================================================
        Rectangle {
            id: winOverlay
            anchors.fill: parent
            z: 100
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.isWon
            opacity: root.isWon ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 250 } }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.86, 360)
                height: 260
                radius: 16
                color: root.themeCardBg
                border.color: root.themeAccent
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: root.earnedStars === 3 ? "✨ PERFECT! ✨" : (root.earnedStars === 2 ? "GREAT FOLD!" : "STAGE CLEARED!")
                        font.pixelSize: 22
                        font.bold: true
                        color: root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Stars row
                    Row {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: "★"; font.pixelSize: 32; color: root.earnedStars >= 1 ? "#F59E0B" : "#4B5563" }
                        Text { text: "★"; font.pixelSize: 36; color: root.earnedStars >= 2 ? "#F59E0B" : "#4B5563" }
                        Text { text: "★"; font.pixelSize: 32; color: root.earnedStars >= 3 ? "#F59E0B" : "#4B5563" }
                    }

                    Text {
                        text: "Solved in " + root.currentMoves + (root.currentMoves === 1 ? " move" : " moves") + " (Par: " + root.currentPar + ")"
                        font.pixelSize: 13
                        color: root.themeFg
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 110
                            height: 38
                            radius: 8
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "Replay (R)"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.themeFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restartLevel()
                            }
                        }

                        Rectangle {
                            width: 130
                            height: 38
                            radius: 8
                            color: root.themeAccent
                            Text {
                                anchors.centerIn: parent
                                text: "Next Stage ➔"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.themeBtnFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextLevel()
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // STAGE SELECT MODAL
        // =====================================================================
        Rectangle {
            id: stageSelectModal
            anchors.fill: parent
            z: 110
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showLevelSelect
            onVisibleChanged: {
                if (visible) root.stagePage = Math.floor((Engine.currentLevel - 1) / 20);
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.92, 440)
                height: Math.min(parent.height * 0.85, 520)
                radius: 14
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 26
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Select Stage"
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeFg
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            font.pixelSize: 16
                            color: root.themeSubtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showLevelSelect = false
                            }
                        }
                    }

                    // Grid of 20 stages per page
                    Grid {
                        columns: 5
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 20

                            Rectangle {
                                property int lvlNum: (root.stagePage * 20) + index + 1
                                property bool isUnlocked: lvlNum <= root.unlockedLevel
                                property bool isCurrent: lvlNum === Engine.currentLevel
                                property int stars: (typeof settingsManager !== "undefined" && settingsManager) ? settingsManager.getStars(lvlNum) : 0

                                width: 68
                                height: 58
                                radius: 8
                                color: isCurrent ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.25) : (isUnlocked ? root.themeBoardBg : "#111116")
                                border.color: isCurrent ? root.themeAccent : root.themeBorder
                                border.width: isCurrent ? 2 : 1
                                opacity: isUnlocked ? 1.0 : 0.4

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        text: "" + lvlNum
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: isCurrent ? root.themeAccent : root.themeFg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: stars === 3 ? "★★★" : (stars === 2 ? "★★☆" : (stars === 1 ? "★☆☆" : "☆☆☆"))
                                        font.pixelSize: 10
                                        color: stars > 0 ? "#F59E0B" : root.themeSubtext
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: isUnlocked
                                    cursorShape: isUnlocked ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.jumpToLevel(lvlNum);
                                        root.showLevelSelect = false;
                                    }
                                }
                            }
                        }
                    }

                    // Page Navigation
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        Rectangle {
                            width: 80
                            height: 32
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1
                            opacity: root.stagePage > 0 ? 1.0 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "◀ Prev"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.stagePage > 0
                                onClicked: root.stagePage--
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Page " + (root.stagePage + 1) + " / " + Math.max(1, Math.floor((root.unlockedLevel - 1) / 20) + 1)
                            font.pixelSize: 12
                            color: root.themeSubtext
                        }

                        Rectangle {
                            width: 80
                            height: 32
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1
                            opacity: root.stagePage < Math.floor((root.unlockedLevel - 1) / 20) ? 1.0 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "Next ▶"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.themeFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.stagePage < Math.floor((root.unlockedLevel - 1) / 20)
                                onClicked: root.stagePage++
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // HOW TO PLAY MODAL
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
                width: Math.min(parent.width * 0.88, 380)
                height: Math.min(parent.height * 0.92, helpCol.height + 40)
                anchors.centerIn: parent
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 12

                Flickable {
                    id: helpFlick
                    anchors.fill: parent
                    anchors.margins: 20
                    contentHeight: helpCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: helpCol
                        width: parent.width
                        spacing: 12

                        Text {
                            text: "HOW TO PLAY FOLD"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.themeAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: root.helpText
                            font.pixelSize: 11
                            color: root.themeFg
                            lineHeight: 1.38
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
        }

        // =====================================================================
        // CONFETTI PARTICLES
        // =====================================================================
        Item {
            id: confettiEmitter
            anchors.fill: parent

            function burst(count) {
                confettiModel.clear();
                for (var i = 0; i < count; i++) {
                    confettiModel.append({
                        posX: root.width / 2 + (Math.random() - 0.5) * 80,
                        posY: root.height / 2 + (Math.random() - 0.5) * 60,
                        vx: (Math.random() - 0.5) * 12,
                        vy: -Math.random() * 14 - 4,
                        rot: Math.random() * 360,
                        rotV: (Math.random() - 0.5) * 15,
                        pColor: Qt.hsla(Math.random(), 0.8, 0.65, 1.0),
                        pSize: Math.random() * 6 + 5
                    });
                }
            }

            ListModel { id: confettiModel }

            Repeater {
                model: confettiModel

                Rectangle {
                    x: model.posX
                    y: model.posY
                    width: model.pSize
                    height: model.pSize * 0.6
                    color: model.pColor
                    rotation: model.rot
                }
            }

            Timer {
                interval: 20
                running: confettiModel.count > 0
                repeat: true
                onTriggered: {
                    for (var i = confettiModel.count - 1; i >= 0; i--) {
                        var p = confettiModel.get(i);
                        p.posX += p.vx;
                        p.posY += p.vy;
                        p.vy += 0.55; // gravity
                        p.vx *= 0.98;
                        p.rot += p.rotV;
                        if (p.posY > root.height + 20) {
                            confettiModel.remove(i);
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TOAST NOTIFICATIONS
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            width: toastText.implicitWidth + 24
            height: 32
            radius: 16
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1
            opacity: 0.0

            Text {
                id: toastText
                anchors.centerIn: parent
                color: root.themeFg
                font.pixelSize: 11
                font.bold: true
            }

            function show(msg) {
                toastText.text = msg;
                toastAnim.restart();
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: soundToast; property: "opacity"; from: 0; to: 1; duration: 150 }
                PauseAnimation { duration: 1000 }
                NumberAnimation { target: soundToast; property: "opacity"; from: 1; to: 0; duration: 250 }
            }
        }
    }

    // =========================================================================
    // RETRO BOOT SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled
        onDismissed: visible = false
    }
}
