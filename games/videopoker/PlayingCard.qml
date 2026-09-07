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

    readonly property string cardBackSvg: "assets/card_back_cyber.svg"

    opacity: 1
    scale: isWinning ? 1.04 : (isHeld ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Subtle dark ambient shadow
    Rectangle {
        anchors.fill: cardContainer
        anchors.topMargin: 2
        anchors.leftMargin: 1
        anchors.rightMargin: -1
        anchors.bottomMargin: -2
        radius: 6
        color: "#99000000"
        z: 0
    }

    // Winning Glow Halo
    Rectangle {
        anchors.fill: cardContainer
        anchors.margins: -3
        radius: 8
        color: "transparent"
        border.color: "#00F0FF"
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
        // FRONT FACE: Sleek Futuristic Dark Obsidian Glass with Neon Pips
        // =====================================================================
        Rectangle {
            id: frontFace
            anchors.fill: parent
            radius: 6
            color: "#0A0E18"
            border.color: {
                if (cardRoot.isWinning) return "#00F0FF";
                if (cardRoot.isHeld) return "#FF007F";
                return "#1E293B";
            }
            border.width: (cardRoot.isWinning || cardRoot.isHeld) ? 2 : 1.2
            clip: true
            visible: cardRotation.angle < 90

            readonly property bool isJokerCard: cardRoot.cardData ? (cardRoot.cardData.isJoker === true || cardRoot.cardData.suit === "joker") : false
            readonly property string rankText: cardRoot.cardData ? (isJokerCard ? "JK" : (cardRoot.cardData.value || "")) : ""
            readonly property string suitText: cardRoot.cardData ? (isJokerCard ? "★" : (cardRoot.cardData.suit || "")) : ""
            readonly property color suitColor: {
                if (isJokerCard) return "#C084FC"; // Radiant neon ultraviolet for Joker
                if (cardRoot.cardData && cardRoot.cardData.isRed) {
                    return "#FF007F"; // Radiant laser neon magenta/pink for Hearts and Diamonds
                } else {
                    return "#00F0FF"; // Radiant electric neon cyan for Spades and Clubs
                }
            }
            readonly property bool isFace: rankText === "K" || rankText === "Q" || rankText === "J"
            readonly property bool isAce: rankText === "A"

            // Futuristic Inset Glowing Accent Hairline
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2.5
                radius: 4.5
                color: "transparent"
                border.color: cardRoot.isHeld ? "#FF007F55" : (cardRoot.isWinning ? "#00F0FF55" : "#00F0FF18")
                border.width: 1
            }

            // Top-Left Corner Pip
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Math.max(3, Math.round(cardRoot.width * 0.06))
                spacing: -2

                Text {
                    text: frontFace.rankText
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
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
                anchors.margins: Math.max(3, Math.round(cardRoot.width * 0.06))
                spacing: -2
                rotation: 180

                Text {
                    text: frontFace.rankText
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
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
                        font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: Math.max(7, Math.round(cardRoot.width * 0.13))
                        font.bold: true
                        color: "#C084FC"
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

                // Royal Face Card (Jack / Queen / King) Futuristic Cyber Badge
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.94
                    height: parent.height * 0.94
                    radius: 5
                    color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.09)
                    border.color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.5)
                    border.width: 1
                    visible: frontFace.isFace && !frontFace.isJokerCard

                    // Futuristic Micro Corner Brackets
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 1.5 }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 1.5 }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 1.5 }
                    Rectangle { width: 3.5; height: 3.5; radius: 1; color: frontFace.suitColor; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 1.5 }

                    Column {
                        anchors.centerIn: parent
                        spacing: -2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.rankText
                            font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
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
                radius: 3
                color: "#00F0FF"
                border.color: "#38BDF8"
                border.width: 1
                visible: Boolean(cardRoot.isWild || (cardRoot.cardData ? (cardRoot.cardData.isDeuce === true || cardRoot.cardData.isJoker === true) : false))

                Text {
                    id: wildText
                    anchors.centerIn: parent
                    text: "WILD"
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
                    font.pixelSize: 8
                    font.bold: true
                    color: "#050811"
                }
            }

            // =================================================================
            // HOLOGRAPHIC HELD HUD BANNER (Neon Magenta Banner)
            // =================================================================
            Rectangle {
                id: heldBanner
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.round(cardRoot.height * 0.22)
                color: "#FF007F"
                border.color: "#FFB6D9"
                border.width: 1
                visible: cardRoot.isHeld
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "HELD"
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font, monospace"
                    font.pixelSize: Math.max(9, Math.round(cardRoot.width * 0.18))
                    font.bold: true
                    color: "#FFFFFF"
                }
            }
        }

        // =====================================================================
        // BACK FACE: Futuristic Cyber Holographic Matrix
        // =====================================================================
        Rectangle {
            id: backFace
            anchors.fill: parent
            radius: 6
            color: "#050811"
            border.color: "#00F0FF"
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
                radius: 4
                color: "transparent"
                border.color: "#00F0FF55"
                border.width: 1
            }
        }
    }
}
