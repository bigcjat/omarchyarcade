import QtQuick
import QtQuick.Window
import "GameEngine.js" as Engine

Window {
    id: root
    visible: true
    width: 520
    height: 700
    minimumWidth: 320
    minimumHeight: 460
    title: "WordGuess"

    property color themeBg: "#181825"
    property color themeBoardBg: "#1e1e2e"
    property color themeCellGrid: "#252538"
    property color themeCardBg: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#a6e3a1"
    property color themeBorder: "#45475a"
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    function colorLuminance(hex) {
        if (!hex || typeof hex !== "string") return 0.2;
        var c = Qt.color(hex);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    property string helpText: "• Guess the secret 5-letter word in 6 tries\n• Type letters and press Enter\n• Green: letter is in the correct spot\n• Yellow: letter is in the word but wrong spot\n• Gray: letter is not in the word\n• Mute: M | Restart: Ctrl+R | Help: ?"

    Behavior on themeBg { ColorAnimation { duration: 250 } }
    Behavior on themeBoardBg { ColorAnimation { duration: 250 } }
    Behavior on themeCardBg { ColorAnimation { duration: 250 } }
    Behavior on themeFg { ColorAnimation { duration: 250 } }
    Behavior on themeSubtext { ColorAnimation { duration: 250 } }
    Behavior on themeAccent { ColorAnimation { duration: 250 } }
    Behavior on themeBorder { ColorAnimation { duration: 250 } }

    color: themeBg

    property string gameState: "playing" // "playing", "won", "lost"
    property string targetWord: ""
    property int currentRow: 0
    property int wins: 0
    property int streak: 0

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        if (data.bg) themeBg = data.bg;
        if (data.fg) themeFg = data.fg;
        if (data.accent) themeAccent = data.accent;
        if (data.boardBg) themeBoardBg = data.boardBg;
        if (data.cardBg) themeCardBg = data.cardBg;
        if (data.border) themeBorder = data.border;
        if (data.subtext) themeSubtext = data.subtext;
    }

    function playSound(name) {
        if (!isMuted && typeof audioController !== "undefined" && audioController) {
            audioController.playSound(name);
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        soundToast.show(root.isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    function startNewGame() {
        Engine.resetGame();
        root.gameState = "playing";
        root.currentRow = 0;
        root.targetWord = Engine.targetWord;
        boardRepeater.model = 0;
        boardRepeater.model = 30;
        kbRow1.updateKeys();
        kbRow2.updateKeys();
        kbRow3.updateKeys();
        soundToast.show("New Word Ready");
    }

    function syncBoard() {
        root.gameState = Engine.gameState;
        root.currentRow = Engine.currentRow;
        root.targetWord = Engine.targetWord;
        boardRepeater.model = 0;
        boardRepeater.model = 30;
        kbRow1.updateKeys();
        kbRow2.updateKeys();
        kbRow3.updateKeys();
    }

    function handleKey(char) {
        Engine.addLetter(char, { onSound: function(s) { root.playSound(s); } });
        syncBoard();
    }

    function handleBackspace() {
        Engine.deleteLetter({ onSound: function(s) { root.playSound(s); } });
        syncBoard();
    }

    function handleSubmit() {
        Engine.submitGuess({
            onSound: function(s) { root.playSound(s); },
            onGameOver: function(won) {
                if (won) {
                    root.wins++;
                    root.streak++;
                } else {
                    root.streak = 0;
                }
            }
        });
        syncBoard();
    }

    signal screenshotSaved(string path)

    function captureScreenshot(filePath, shouldQuit) {
        if (splashScreen) {
            splashScreen.visible = false;
            splashScreen.opacity = 0;
        }
        root.splashEnabled = false;
        var targetItem = mainContainer;
        targetItem.grabToImage(function(result) {
            result.saveToFile(filePath);
            console.log("Screenshot saved successfully to " + filePath);
            root.screenshotSaved(filePath);
            if (shouldQuit) {
                Qt.quit();
            }
        });
    }

    // MAIN CONTAINER
    Item {
        id: mainContainer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.gameState === "won" || root.gameState === "lost") {
                if (event.key === Qt.Key_A || event.key === Qt.Key_R || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.startNewGame();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                root.startNewGame();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                showHelp = !showHelp;
                event.accepted = true;
                return;
            }

            if (root.gameState === "playing") {
                if (event.key === Qt.Key_Backspace) {
                    root.handleBackspace();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.handleSubmit();
                    event.accepted = true;
                } else if (event.text && event.text.length === 1) {
                    var ch = event.text.toUpperCase();
                    if (ch >= 'A' && ch <= 'Z') {
                        root.handleKey(ch);
                        event.accepted = true;
                    }
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 1 (Header Item)
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
                    text: "WordGuess"
                    font.pixelSize: Math.max(22, Math.min(36, headerItem.width * 0.07))
                    font.bold: true
                    color: root.themeAccent
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.gameState === "won" ? "Splendid! Word: " + root.targetWord : (root.gameState === "lost" ? "Game Over • Word: " + root.targetWord : "Guess " + (root.currentRow + 1) + " of 6 • " + (6 - root.currentRow) + " tries remaining"))
                    font.pixelSize: Math.max(10, Math.min(13, headerItem.width * 0.026))
                    color: root.themeSubtext
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Stat Cards on Right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // WINS Card
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
                            text: "WINS"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wins.toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeFg
                        }
                    }
                }

                // STREAK Card
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
                            text: "STREAK"
                            font.pixelSize: 8
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "★ " + root.streak
                            font.pixelSize: 16
                            font.bold: true
                            color: root.streak > 0 ? root.themeAccent : root.themeSubtext
                        }
                    }
                }
            }
        }

        // 2048 DESIGN STANDARD: ROW 2 (Subheader Action Bar)
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: restartBtn.height

            // Help button
            Rectangle {
                id: helpBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(28, Math.min(34, parent.width * 0.065))
                width: Math.max(105, Math.min(130, parent.width * 0.28))
                radius: Math.max(6, height * 0.24)
                color: helpMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: helpMouse.containsMouse ? root.themeAccent : root.themeBorder
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
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
                        text: subheaderItem.width < 340 ? "Help" : "How to Play"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.themeFg
                        anchors.verticalCenter: parent.verticalCenter
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

            // Mute button in Center
            Rectangle {
                id: muteBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: helpBtn.height
                width: Math.max(56, Math.min(92, parent.width * 0.20))
                radius: helpBtn.radius
                color: muteMouse.containsMouse ? root.themeCardBg : root.themeBoardBg
                border.color: root.isMuted ? root.themeBorder : root.themeAccent
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
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
                        visible: muteBtn.width >= 62
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

            // Primary Action Button (New Word)
            Rectangle {
                id: restartBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: helpBtn.height
                width: Math.max(90, Math.min(130, parent.width * 0.28))
                radius: helpBtn.radius
                color: restartMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: subheaderItem.width < 340 ? "New" : "New Word"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.themeBtnFg
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

        // PLAYFIELD CONTAINER
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

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 380)
                spacing: 14

                // 6x5 Letter Grid
                Grid {
                    id: letterGrid
                    columns: 5
                    rows: 6
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        id: boardRepeater
                        model: 30

                        Rectangle {
                            property int r: Math.floor(index / 5)
                            property int c: index % 5
                            property var tileData: (Engine.board[r] && Engine.board[r][c]) ? Engine.board[r][c] : { letter: "", status: "empty" }

                            width: Math.min(54, (letterGrid.parent.width - 28) / 5)
                            height: width
                            radius: 6

                            color: {
                                if (tileData.status === "correct") return root.themeAccent;
                                if (tileData.status === "present") return "#E5C07B";
                                if (tileData.status === "absent") return Qt.darker(root.themeCardBg, 1.3);
                                return root.themeBoardBg;
                            }

                            border.color: {
                                if (tileData.status === "correct") return root.themeAccent;
                                if (tileData.status === "present") return "#E5C07B";
                                if (tileData.status === "tbd") return root.themeFg;
                                return root.themeBorder;
                            }
                            border.width: (tileData.status === "tbd") ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: tileData.letter
                                color: {
                                    if (tileData.status === "correct") return root.themeBg;
                                    if (tileData.status === "present") return "#1e1e2e";
                                    if (tileData.status === "absent") return root.themeSubtext;
                                    return root.themeFg;
                                }
                                font.pixelSize: parent.width * 0.48
                                font.bold: true
                                font.family: root.monoFontFamily
                            }
                        }
                    }
                }

                // Virtual Keyboard
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    width: parent.width

                    // Row 1: Q W E R T Y U I O P
                    Row {
                        id: kbRow1
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        function updateKeys() {
                            for (var i = 0; i < children.length; i++) {
                                if (children[i].refreshKey) children[i].refreshKey();
                            }
                        }

                        Repeater {
                            model: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
                            delegate: Rectangle {
                                property string keyChar: modelData
                                property string stat: Engine.keyboardStatus[keyChar] || ""

                                function refreshKey() {
                                    stat = Engine.keyboardStatus[keyChar] || "";
                                }

                                width: Math.min(34, (kbRow1.parent.width - 36) / 10)
                                height: 42
                                radius: 4
                                color: {
                                    if (stat === "correct") return root.themeAccent;
                                    if (stat === "present") return "#E5C07B";
                                    if (stat === "absent") return Qt.darker(root.themeCardBg, 1.4);
                                    return root.themeCardBg;
                                }
                                border.color: root.themeBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: keyChar
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 13
                                    color: (stat === "correct" || stat === "present") ? "#1e1e2e" : (stat === "absent" ? root.themeSubtext : root.themeFg)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleKey(keyChar)
                                }
                            }
                        }
                    }

                    // Row 2: A S D F G H J K L
                    Row {
                        id: kbRow2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        function updateKeys() {
                            for (var i = 0; i < children.length; i++) {
                                if (children[i].refreshKey) children[i].refreshKey();
                            }
                        }

                        Repeater {
                            model: ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
                            delegate: Rectangle {
                                property string keyChar: modelData
                                property string stat: Engine.keyboardStatus[keyChar] || ""

                                function refreshKey() {
                                    stat = Engine.keyboardStatus[keyChar] || "";
                                }

                                width: Math.min(34, (kbRow2.parent.width - 36) / 10)
                                height: 42
                                radius: 4
                                color: {
                                    if (stat === "correct") return root.themeAccent;
                                    if (stat === "present") return "#E5C07B";
                                    if (stat === "absent") return Qt.darker(root.themeCardBg, 1.4);
                                    return root.themeCardBg;
                                }
                                border.color: root.themeBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: keyChar
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 13
                                    color: (stat === "correct" || stat === "present") ? "#1e1e2e" : (stat === "absent" ? root.themeSubtext : root.themeFg)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleKey(keyChar)
                                }
                            }
                        }
                    }

                    // Row 3: ENTER Z X C V B N M ⌫
                    Row {
                        id: kbRow3
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        function updateKeys() {
                            for (var i = 0; i < children.length; i++) {
                                if (children[i].refreshKey) children[i].refreshKey();
                            }
                        }

                        Rectangle {
                            width: Math.min(52, (kbRow3.parent.width - 36) / 7)
                            height: 42
                            radius: 4
                            color: root.themeAccent
                            border.color: root.themeBorder

                            Text {
                                anchors.centerIn: parent
                                text: "ENTER"
                                font.bold: true
                                font.family: root.monoFontFamily
                                font.pixelSize: 10
                                color: root.themeBg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.handleSubmit()
                            }
                        }

                        Repeater {
                            model: ["Z", "X", "C", "V", "B", "N", "M"]
                            delegate: Rectangle {
                                property string keyChar: modelData
                                property string stat: Engine.keyboardStatus[keyChar] || ""

                                function refreshKey() {
                                    stat = Engine.keyboardStatus[keyChar] || "";
                                }

                                width: Math.min(34, (kbRow3.parent.width - 36) / 10)
                                height: 42
                                radius: 4
                                color: {
                                    if (stat === "correct") return root.themeAccent;
                                    if (stat === "present") return "#E5C07B";
                                    if (stat === "absent") return Qt.darker(root.themeCardBg, 1.4);
                                    return root.themeCardBg;
                                }
                                border.color: root.themeBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: keyChar
                                    font.bold: true
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 13
                                    color: (stat === "correct" || stat === "present") ? "#1e1e2e" : (stat === "absent" ? root.themeSubtext : root.themeFg)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleKey(keyChar)
                                }
                            }
                        }

                        Rectangle {
                            width: Math.min(44, (kbRow3.parent.width - 36) / 8)
                            height: 42
                            radius: 4
                            color: root.themeCardBg
                            border.color: root.themeBorder

                            Text {
                                anchors.centerIn: parent
                                text: "⌫"
                                font.bold: true
                                font.family: root.monoFontFamily
                                font.pixelSize: 15
                                color: root.themeFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.handleBackspace()
                            }
                        }
                    }
                }
            }

            // STANDARDIZED GAME OVER / VICTORY OVERLAY
            Rectangle {
                id: gameOverOverlay
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.82)
                visible: root.gameState === "won" || root.gameState === "lost"
                z: 50

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startNewGame()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: root.gameState === "won" ? "VICTORY!" : "GAME OVER"
                        color: root.gameState === "won" ? root.themeAccent : "#FF5555"
                        font.pixelSize: 28
                        font.bold: true
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.gameState === "won" ? ("Solved in " + (root.currentRow + 1) + " guesses!") : ("The word was: " + root.targetWord)
                        color: root.themeFg
                        font.pixelSize: 17
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 140
                        height: 42
                        radius: 8
                        color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "PLAY AGAIN"
                            color: root.themeBg
                            font.bold: true
                            font.pixelSize: 13
                            font.family: root.monoFontFamily
                        }

                        MouseArea {
                            id: playAgainMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startNewGame()
                        }
                    }

                    Text {
                        text: "Or press R / Space / Enter"
                        color: root.themeSubtext
                        font.pixelSize: 11
                        font.family: root.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // AUDIO NOTIFICATION TOAST
    Rectangle {
        id: soundToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 24
        height: 32
        radius: 16
        color: root.themeCardBg
        border.color: root.themeBorder
        border.width: 1
        opacity: 0
        z: 200

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.family: root.monoFontFamily
            font.pixelSize: 11
            color: root.themeFg
        }

        Timer {
            id: toastTimer
            interval: 1200
            onTriggered: soundToast.opacity = 0
        }

        function show(msg) {
            toastText.text = msg;
            soundToast.opacity = 0.95;
            toastTimer.restart();
        }
    }

    // HOW TO PLAY MODAL
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
            width: Math.min(parent.width - 40, 360)
            height: helpCol.implicitHeight + 36
            anchors.centerIn: parent
            radius: 12
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Column {
                id: helpCol
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 12

                Text {
                    text: "HOW TO PLAY"
                    font.family: root.monoFontFamily
                    font.bold: true
                    font.pixelSize: 15
                    color: root.themeAccent
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.family: root.monoFontFamily
                    font.pixelSize: 11
                    color: root.themeFg
                    lineHeight: 1.3
                    text: root.helpText
                }

                Rectangle {
                    width: 100
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
                        color: root.themeBg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = false
                    }
                }
            }
        }
    }

    // CANONICAL RETRO OMARCHY ARCADE SPLASH SCREEN
    // Console Startup Splash Screen (Retro Omarchy Arcade)
    SplashScreen {
        id: splashScreen
        focusTarget: mainContainer
    }

    Component.onCompleted: {
        Engine.init();
        root.targetWord = Engine.targetWord;
    }
}
