import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot
    width: 86
    height: 124

    property var cardData: null
    property bool faceUp: cardData ? (cardData.faceUp === true) : true
    property bool isWinning: false
    property bool isSelected: false
    property bool isHighlighted: false
    property string deckStyle: (typeof root !== "undefined" && root.deckStyle) ? root.deckStyle : "synthwave"

    readonly property string cardBackSvg: {
        if (deckStyle === "crimson") return "assets/card_back_crimson.svg";
        if (deckStyle === "obsidian") return "assets/card_back_obsidian.svg";
        if (deckStyle === "sapphire") return "assets/card_back_sapphire.svg";
        return "assets/card_back_synthwave.svg";
    }

    readonly property color cardBackBorderColor: {
        if (deckStyle === "crimson") return "#FDE047";
        if (deckStyle === "obsidian") return "#F59E0B";
        if (deckStyle === "sapphire") return "#E2E8F0";
        return "#00F0FF";
    }

    opacity: 1
    scale: isWinning ? 1.05 : (isSelected ? 1.03 : 1.0)
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

    // Subtle drop shadow
    Rectangle {
        anchors.fill: cardContainer
        anchors.topMargin: 3
        anchors.leftMargin: 2
        anchors.rightMargin: -2
        anchors.bottomMargin: -3
        radius: 6
        color: "#55000000"
        z: 0
    }

    // Selection / Hint / Winning Glow Halo
    Rectangle {
        anchors.fill: cardContainer
        anchors.margins: -3
        radius: 9
        color: "transparent"
        border.color: {
            if (cardRoot.isWinning) return "#FACC15";
            if (cardRoot.isHighlighted) return "#10B981";
            if (cardRoot.isSelected) return "#00F0FF";
            return "transparent";
        }
        border.width: (cardRoot.isWinning || cardRoot.isSelected || cardRoot.isHighlighted) ? 2.5 : 0
        visible: cardRoot.isWinning || cardRoot.isSelected || cardRoot.isHighlighted
        z: 1

        SequentialAnimation on opacity {
            running: cardRoot.isWinning || cardRoot.isHighlighted
            loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.4; duration: 350; easing.type: Easing.InOutQuad }
        }
    }

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
                NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
            }
        }

        // =====================================================================
        // FRONT FACE (Visible when angle < 90)
        // =====================================================================
        Rectangle {
            id: frontFace
            anchors.fill: parent
            radius: 6
            color: "#FCFCFD"
            border.color: cardRoot.isSelected ? "#00F0FF" : (cardRoot.isWinning ? "#FACC15" : "#D1D5DB")
            border.width: cardRoot.isSelected ? 2 : 1.2
            clip: true
            visible: cardRotation.angle < 90

            readonly property string rankText: cardRoot.cardData ? (cardRoot.cardData.value || "") : ""
            readonly property string suitText: cardRoot.cardData ? (cardRoot.cardData.suit || "") : ""
            readonly property color suitColor: cardRoot.cardData ? (cardRoot.cardData.isRed ? "#E11D48" : "#0F172A") : "#0F172A"
            readonly property bool isFace: rankText === "K" || rankText === "Q" || rankText === "J"
            readonly property bool isAce: rankText === "A"

            // Top-Left Corner Pip
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Math.max(3, Math.round(cardRoot.width * 0.05))
                spacing: -2

                Text {
                    text: frontFace.rankText
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(9, Math.round(cardRoot.width * 0.14)) : Math.max(10, Math.round(cardRoot.width * 0.16))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(10, Math.round(cardRoot.width * 0.15))
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Bottom-Right Corner Pip (Rotated 180°)
            Column {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Math.max(3, Math.round(cardRoot.width * 0.05))
                spacing: -2
                rotation: 180

                Text {
                    text: frontFace.rankText
                    font.family: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(9, Math.round(cardRoot.width * 0.14)) : Math.max(10, Math.round(cardRoot.width * 0.16))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(10, Math.round(cardRoot.width * 0.15))
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Center Art Frame
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(cardRoot.width * 0.22)

                // Big Ace Center Emblem
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: Math.round(cardRoot.width * 0.44)
                    color: frontFace.suitColor
                    visible: frontFace.isAce
                }

                // Royal Face Card (Jack / Queen / King) Retro Badge
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.95
                    height: parent.height * 0.95
                    radius: 4
                    color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.05)
                    border.color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.25)
                    border.width: 1
                    visible: frontFace.isFace

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.rankText === "K" ? "👑" : (frontFace.rankText === "Q" ? "👸" : "⚔️")
                            font.pixelSize: Math.round(cardRoot.width * 0.24)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.suitText
                            font.pixelSize: Math.round(cardRoot.width * 0.18)
                            color: frontFace.suitColor
                        }
                    }
                }

                // Standard Number Card Center Pips (2..10)
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: Math.round(cardRoot.width * 0.32)
                    color: frontFace.suitColor
                    visible: !frontFace.isAce && !frontFace.isFace
                }
            }
        }

        // =====================================================================
        // BACK FACE (Visible when angle >= 90, flipped 180° so logo is upright)
        // =====================================================================
        Rectangle {
            id: backFace
            anchors.fill: parent
            radius: 6
            color: "#080612"
            border.color: cardRoot.cardBackBorderColor
            border.width: 1.2
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
        }
    }
}
