import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot
    width: 76
    height: 108

    property var cardData: null
    property bool faceUp: cardData ? (cardData.faceUp !== false) : true
    property bool isWinning: false
    property bool isHeld: cardData ? (cardData.held === true) : false
    property bool isWild: cardData ? (cardData.isWild === true) : false
    property bool isSelected: false
    property string visualMode: (typeof root !== "undefined" && root.visualMode) ? root.visualMode : "cyber"

    readonly property bool isCrtMode: visualMode === "crt"
    readonly property bool isCyberMode: visualMode === "cyber"

    readonly property string cardBackSvg: isCyberMode ? "assets/card_back_cyber.svg" : "assets/card_back_sapphire.svg"

    opacity: 1
    scale: isWinning ? 1.04 : (isHeld ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Subtle dark ambient shadow
    Rectangle {
        anchors.fill: cardContainer
        anchors.topMargin: isCyberMode ? 2 : 3
        anchors.leftMargin: isCyberMode ? 1 : 2
        anchors.rightMargin: isCyberMode ? -1 : -2
        anchors.bottomMargin: isCyberMode ? -2 : -3
        radius: isCyberMode ? 6 : 3
        color: isCyberMode ? "#99000000" : "#AA000000"
        z: 0
    }

    // Winning Glow Halo
    Rectangle {
        anchors.fill: cardContainer
        anchors.margins: -3
        radius: isCyberMode ? 8 : 4
        color: "transparent"
        border.color: isCyberMode ? "#00F0FF" : "#FFFF00"
        border.width: isWinning ? 2.5 : 0
        visible: isWinning
        z: 1

        SequentialAnimation on opacity {
            running: cardRoot.isWinning
            loops: Animation.Infinite
            NumberAnimation { from: 0.3; to: 1.0; duration: 250; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.3; duration: 250; easing.type: Easing.InOutQuad }
        }
    }

    property bool initialized: false
    Component.onCompleted: initialized = true

    // 3D Flipping Card Container
    Item {
        id: cardContainer
        anchors.fill: parent
        z: 2

        transform: Rotation {
            id: cardRotation
            origin.x: cardRoot.width / 2
            origin.y: cardRoot.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: cardRoot.faceUp ? 0 : 180

            Behavior on angle {
                enabled: cardRoot.initialized
                NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
            }
        }

        // =====================================================================
        // FRONT FACE: Dynamic between Dark Neon Obsidian & 1984 Vegas Ivory
        // =====================================================================
        Rectangle {
            id: frontFace
            anchors.fill: parent
            radius: isCyberMode ? 6 : 3
            color: isCyberMode ? "#0A0E18" : "#FFFFFF"
            border.color: {
                if (cardRoot.isWinning) return isCyberMode ? "#00F0FF" : "#FACC15";
                if (cardRoot.isHeld) return isCyberMode ? "#FF007F" : "#DC2626";
                return isCyberMode ? "#1E293B" : "#000000";
            }
            border.width: (cardRoot.isWinning || cardRoot.isHeld) ? 2 : (isCyberMode ? 1.2 : 1.5)
            clip: true
            visible: cardRotation.angle < 90

            readonly property bool isJokerCard: cardRoot.cardData ? (cardRoot.cardData.isJoker === true || cardRoot.cardData.suit === "joker") : false
            readonly property string rankText: cardRoot.cardData ? (isJokerCard ? "JK" : (cardRoot.cardData.value || "")) : ""
            readonly property string suitText: cardRoot.cardData ? (isJokerCard ? "★" : (cardRoot.cardData.suit || "")) : ""
            readonly property color suitColor: {
                if (isJokerCard) return isCyberMode ? "#C084FC" : "#7E22CE";
                if (cardRoot.cardData && cardRoot.cardData.isRed) {
                    return isCyberMode ? "#FF007F" : "#DC2626"; // Vibrant neon magenta in cyber, deep red in CRT
                } else {
                    return isCyberMode ? "#00F0FF" : "#000000"; // Electric neon cyan in cyber, solid black in CRT
                }
            }
            readonly property bool isFace: rankText === "K" || rankText === "Q" || rankText === "J"
            readonly property bool isAce: rankText === "A"

            // Futuristic Inset Glowing Accent Hairline (Cyber Mode only)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2.5
                radius: 4.5
                color: "transparent"
                border.color: cardRoot.isHeld ? "#FF007F55" : (cardRoot.isWinning ? "#00F0FF55" : "#00F0FF18")
                border.width: 1
                visible: isCyberMode
            }

            // Top-Left Corner Pip
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Math.max(2, Math.round(cardRoot.width * 0.06))
                spacing: -2

                Text {
                    text: frontFace.rankText
                    font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(9, Math.round(cardRoot.width * 0.16)) : Math.max(10, Math.round(cardRoot.width * 0.19))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(9, Math.round(cardRoot.width * 0.18))
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Bottom-Right Corner Pip (Rotated 180°)
            Column {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Math.max(2, Math.round(cardRoot.width * 0.06))
                spacing: -2
                rotation: 180

                Text {
                    text: frontFace.rankText
                    font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(9, Math.round(cardRoot.width * 0.16)) : Math.max(10, Math.round(cardRoot.width * 0.19))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(9, Math.round(cardRoot.width * 0.18))
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Center Art Frame
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(cardRoot.width * 0.20)

                // Joker Center Display
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: frontFace.isJokerCard

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🃏"
                        font.pixelSize: Math.round(cardRoot.width * 0.38)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "JOKER"
                        font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                        font.pixelSize: Math.max(7, Math.round(cardRoot.width * 0.13))
                        font.bold: true
                        color: frontFace.suitColor
                    }
                }

                // Big Ace Center Emblem
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: Math.round(cardRoot.width * 0.46)
                    color: frontFace.suitColor
                    visible: frontFace.isAce && !frontFace.isJokerCard
                }

                // Royal Face Card (Jack / Queen / King)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.94
                    height: parent.height * 0.94
                    radius: isCyberMode ? 5 : 2
                    color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, isCyberMode ? 0.09 : 0.05)
                    border.color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, isCyberMode ? 0.5 : 0.3)
                    border.width: 1
                    visible: frontFace.isFace && !frontFace.isJokerCard

                    // Futuristic Micro Corner Brackets (Cyber Mode)
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 1.5; visible: isCyberMode }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 1.5; visible: isCyberMode }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 1.5; visible: isCyberMode }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 1.5; visible: isCyberMode }

                    Column {
                        anchors.centerIn: parent
                        spacing: isCyberMode ? -2 : 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.rankText
                            font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                            font.pixelSize: Math.round(cardRoot.width * 0.36)
                            font.bold: true
                            color: frontFace.suitColor
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.suitText
                            font.pixelSize: Math.round(cardRoot.width * 0.22)
                            color: frontFace.suitColor
                        }
                    }
                }

                // Standard Number Card Center Pips (2..10)
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: Math.round(cardRoot.width * 0.34)
                    color: frontFace.suitColor
                    visible: !frontFace.isAce && !frontFace.isFace && !frontFace.isJokerCard
                }
            }

            // Futuristic WILD Badge (Deuces Wild or Joker)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: wildText.implicitWidth + 8
                height: 14
                radius: isCyberMode ? 3 : 2
                color: isCyberMode ? "#00F0FF" : "#F59E0B"
                border.color: isCyberMode ? "#38BDF8" : "#B45309"
                border.width: 1
                visible: Boolean(cardRoot.isWild || (cardRoot.cardData ? (cardRoot.cardData.isDeuce === true || cardRoot.cardData.isJoker === true) : false))

                Text {
                    id: wildText
                    anchors.centerIn: parent
                    text: "WILD"
                    font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                    font.pixelSize: 8
                    font.bold: true
                    color: isCyberMode ? "#050811" : "#FFFFFF"
                }
            }

            // =================================================================
            // HELD BANNER: Cyber Neon Magenta vs 1984 Vegas Red Stamp
            // =================================================================
            Rectangle {
                id: heldBanner
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.round(cardRoot.height * 0.22)
                color: isCyberMode ? "#FF007F" : "#DC2626"
                border.color: isCyberMode ? "#FFB6D9" : "#FEF08A"
                border.width: 1
                visible: cardRoot.isHeld
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "HELD"
                    font.family: isCyberMode ? ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace") : "Courier New, monospace"
                    font.pixelSize: Math.max(9, Math.round(cardRoot.width * 0.18))
                    font.bold: true
                    color: isCyberMode ? "#FFFFFF" : "#FEF08A"
                }
            }
        }

        // =====================================================================
        // BACK FACE: Cyber Holographic Matrix vs 1984 Vegas Royal Blue
        // =====================================================================
        Rectangle {
            id: backFace
            anchors.fill: parent
            radius: isCyberMode ? 6 : 3
            color: isCyberMode ? "#050811" : "#0000AA"
            border.color: isCyberMode ? "#00F0FF" : "#FFCC00"
            border.width: 1.5
            clip: true
            visible: cardRotation.angle >= 90

            Image {
                anchors.fill: parent
                source: cardRoot.cardBackSvg
                fillMode: Image.PreserveAspectCrop
                mirror: true
                smooth: true
                mipmap: true
            }

            // Glowing Inner Tech Border
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: isCyberMode ? 4 : 2
                color: "transparent"
                border.color: isCyberMode ? "#00F0FF55" : "#FFCC00"
                border.width: 1
            }
        }
    }
}
