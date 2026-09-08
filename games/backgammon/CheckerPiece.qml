import QtQuick

Item {
    id: pieceRoot
    width: 32
    height: 32

    property int player: 1 // 1: Dark, 2: Light
    property bool isSelected: false
    property bool isHovered: false
    property int countBadge: 0

    readonly property bool isDark: player === 1
    readonly property var currentTheme: (typeof root !== "undefined" && root.activeBoardTheme) ? root.activeBoardTheme : null

    readonly property color bodyColor: currentTheme
        ? (isDark ? currentTheme.darkBody : currentTheme.lightBody)
        : (isDark ? "#282c3c" : "#ffffff")

    readonly property color outerBorder: isSelected
        ? (typeof root !== "undefined" ? root.themeAccent : "#38bdf8")
        : (currentTheme ? (isDark ? currentTheme.darkRim : currentTheme.lightRim) : (isDark ? "#94a3b8" : "#cbd5e1"))

    readonly property color innerRingColor: currentTheme
        ? (isDark ? currentTheme.darkInner : currentTheme.lightInner)
        : (isDark ? "#3f465c" : "#e2e8f0")

    readonly property color coreColor: currentTheme
        ? (isDark ? currentTheme.darkCore : currentTheme.lightCore)
        : (isDark ? "#1a1c26" : "#edf2f7")

    readonly property color pipColor: currentTheme
        ? (isDark ? currentTheme.darkPip : currentTheme.lightPip)
        : (isDark ? (typeof root !== "undefined" ? root.themeAccent : "#38bdf8") : "#64748b")

    // Soft drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2.5
        radius: width / 2
        color: "#55000000"
        opacity: pieceRoot.isSelected ? 0.7 : 0.4
    }

    // Main Checker Body
    Rectangle {
        id: body
        anchors.fill: parent
        radius: width / 2
        color: pieceRoot.bodyColor
        border.color: pieceRoot.outerBorder
        border.width: pieceRoot.isSelected ? 2.5 : 1.8

        // Lift & scale when selected
        transform: Translate {
            y: pieceRoot.isSelected ? -6 : (pieceRoot.isHovered ? -2 : 0)
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }

        // Concentric luxury lathe groove
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.74
            height: width
            radius: width / 2
            color: "transparent"
            border.color: pieceRoot.innerRingColor
            border.width: 1.4
        }

        // Inner core disc
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            radius: width / 2
            color: pieceRoot.coreColor
            border.color: pieceRoot.outerBorder
            border.width: 1

            // Center tactile pip
            Rectangle {
                anchors.centerIn: parent
                width: Math.max(3, parent.width * 0.28)
                height: width
                radius: width / 2
                color: pieceRoot.pipColor
                opacity: 0.95
            }
        }

        // Count badge for stacked piles (> 5)
        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: pieceRoot.isDark
                ? (pieceRoot.currentTheme ? pieceRoot.currentTheme.darkRim : "#38bdf8")
                : (pieceRoot.currentTheme ? pieceRoot.currentTheme.lightRim : "#1e293b")
            visible: pieceRoot.countBadge > 5

            Text {
                anchors.centerIn: parent
                text: pieceRoot.countBadge.toString()
                font.pixelSize: 10
                font.bold: true
                color: pieceRoot.isDark ? "#000000" : (pieceRoot.currentTheme ? pieceRoot.currentTheme.lightPip : "#ffffff")
            }
        }
    }
}
