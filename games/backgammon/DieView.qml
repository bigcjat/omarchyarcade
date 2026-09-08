import QtQuick

Item {
    id: dieRoot
    width: 44
    height: 44

    property int value: 1
    property bool isSpent: false
    property int player: (typeof root !== "undefined") ? root.currentTurn : 1

    readonly property var currentTheme: (typeof root !== "undefined" && root.activeBoardTheme) ? root.activeBoardTheme : null
    readonly property bool isDark: player === 1

    property color dieBg: isSpent
        ? (currentTheme ? Qt.rgba(Qt.color(currentTheme.felt).r, Qt.color(currentTheme.felt).g, Qt.color(currentTheme.felt).b, 0.7) : Qt.darker(root.themeCardBg, 1.2))
        : (currentTheme ? (isDark ? currentTheme.diceDarkBg : currentTheme.diceLightBg) : root.themeCardBg)

    property color dieBorder: isSpent
        ? (currentTheme ? Qt.rgba(Qt.color(currentTheme.feltText).r, Qt.color(currentTheme.feltText).g, Qt.color(currentTheme.feltText).b, 0.3) : root.themeBorder)
        : (currentTheme ? (isDark ? currentTheme.diceDarkBorder : currentTheme.diceLightBorder) : root.themeAccent)

    property color pipColor: isSpent
        ? (currentTheme ? Qt.rgba(Qt.color(currentTheme.feltText).r, Qt.color(currentTheme.feltText).g, Qt.color(currentTheme.feltText).b, 0.4) : root.themeSubtext)
        : (currentTheme ? (isDark ? currentTheme.diceDarkPip : currentTheme.diceLightPip) : root.themeFg)

    // Soft drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.leftMargin: 1
        radius: 9
        color: "#40000000"
    }

    // Die Cube Body
    Rectangle {
        id: dieBody
        anchors.fill: parent
        radius: 9
        color: dieRoot.dieBg
        border.color: dieRoot.dieBorder
        border.width: dieRoot.isSpent ? 1 : 1.8
        opacity: dieRoot.isSpent ? 0.45 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Subtle bevel inner highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 8
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
        }

        // Pips (Dominos 1-6)
        Item {
            anchors.fill: parent
            anchors.margins: 8

            readonly property real dSize: 6.5
            readonly property real dRad: dSize / 2

            // Pip 1: Top-Left (2, 3, 4, 5, 6)
            Rectangle {
                x: 0; y: 0
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value >= 2 && dieRoot.value <= 6
            }

            // Pip 2: Bottom-Right (2, 3, 4, 5, 6)
            Rectangle {
                x: parent.width - width; y: parent.height - height
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value >= 2 && dieRoot.value <= 6
            }

            // Pip 3: Center (1, 3, 5)
            Rectangle {
                anchors.centerIn: parent
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value === 1 || dieRoot.value === 3 || dieRoot.value === 5
            }

            // Pip 4: Top-Right (4, 5, 6)
            Rectangle {
                x: parent.width - width; y: 0
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value >= 4 && dieRoot.value <= 6
            }

            // Pip 5: Bottom-Left (4, 5, 6)
            Rectangle {
                x: 0; y: parent.height - height
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value >= 4 && dieRoot.value <= 6
            }

            // Pip 6: Middle-Left (6)
            Rectangle {
                x: 0; y: (parent.height - height) / 2
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value === 6
            }

            // Pip 7: Middle-Right (6)
            Rectangle {
                x: parent.width - width; y: (parent.height - height) / 2
                width: parent.dSize; height: parent.dSize; radius: parent.dRad
                color: dieRoot.pipColor
                visible: dieRoot.value === 6
            }
        }
    }

    // Roll animation
    function rollAnim() {
        shakeAnim.restart();
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: dieBody; property: "rotation"; from: 0; to: -14; duration: 60 }
        NumberAnimation { target: dieBody; property: "rotation"; from: -14; to: 14; duration: 80 }
        NumberAnimation { target: dieBody; property: "rotation"; from: 14; to: -8; duration: 60 }
        NumberAnimation { target: dieBody; property: "rotation"; from: -8; to: 0; duration: 60 }
    }
}
