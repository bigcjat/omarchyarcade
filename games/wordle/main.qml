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
    property bool splashEnabled: true
    property bool isMuted: true
    property bool showHelp: false
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

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

        // TOP HEADER HUD
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
                        text: "WordGuess"
                        font.family: root.monoFontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeAccent
                    }
                    Text {
                        text: "Guess " + (root.currentRow + 1) + " of 6 • " + root.wins + " wins"
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

                // Tries pill
                Rectangle {
                    width: 44
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        Text { text: "TRY"; font.pixelSize: 7; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: (root.currentRow + 1) + "/6"; font.pixelSize: 11; font.bold: true; color: root.themeFg; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Streak pill
                Rectangle {
                    width: 44
                    height: 28
                    radius: 6
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        Text { text: "STREAK"; font.pixelSize: 7; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "★ " + root.streak; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Restart button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: restartArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "↺"; font.bold: true; font.pixelSize: 13; color: root.themeFg }
                    MouseArea {
                        id: restartArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startNewGame()
                    }
                }

                // Mute button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: muteArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 11 }
                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Help button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: helpArea.pressed ? Qt.darker(root.themeCardBg, 1.2) : root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.bold: true; font.pixelSize: 12; color: root.themeAccent }
                    MouseArea {
                        id: helpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showHelp = !root.showHelp
                    }
                }
            }
        }

        // PLAYFIELD CONTAINER
        Item {
            id: playArea
            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right

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
