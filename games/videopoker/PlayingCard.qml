import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot
    width: 100
    height: 144

    property var cardData: null
    property bool faceUp: cardData ? (cardData.faceUp !== false) : true
    property bool isWinning: false
    property bool isHeld: cardData ? (cardData.held === true) : false
    property bool isWild: cardData ? (cardData.isWild === true) : false
    property bool isSelected: false
    property string visualMode: (typeof root !== "undefined" && root.visualMode) ? root.visualMode : "crt"
    property string deckStyle: (typeof root !== "undefined" && root.deckStyle) ? root.deckStyle : "synthwave"

    readonly property bool isCrtMode: visualMode === "crt"

    readonly property string cardBackSvg: {
        if (deckStyle === "crimson") return "assets/card_back_crimson.svg";
        if (deckStyle === "obsidian") return "assets/card_back_obsidian.svg";
        if (deckStyle === "sapphire") return "assets/card_back_sapphire.svg";
        return "assets/card_back_synthwave.svg";
    }

    readonly property color cardBackBorderColor: {
        if (isCrtMode) return "#FFCC00";
        if (deckStyle === "crimson") return "#FDE047";
        if (deckStyle === "obsidian") return "#F59E0B";
        if (deckStyle === "sapphire") return "#E2E8F0";
        return "#00F0FF";
    }

    opacity: 1
    scale: isWinning ? 1.05 : (isHeld ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Subtle drop shadow
    Rectangle {
        anchors.fill: cardContainer
        anchors.topMargin: isCrtMode ? 4 : 3
        anchors.leftMargin: isCrtMode ? 4 : 2
        anchors.rightMargin: isCrtMode ? -4 : -2
        anchors.bottomMargin: isCrtMode ? -4 : -3
        radius: isCrtMode ? 4 : 8
        color: isCrtMode ? "#AA000000" : "#55000000"
        z: 0
    }

    // Winning Glow Halo
    Rectangle {
        anchors.fill: cardContainer
        anchors.margins: -4
        radius: isCrtMode ? 4 : 10
        color: "transparent"
        border.color: isCrtMode ? "#FFFF00" : "#FACC15"
        border.width: isWinning ? 3 : 0
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
                NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
            }
        }

        // =====================================================================
        // FRONT FACE (Visible when angle < 90)
        // =====================================================================
        Rectangle {
            id: frontFace
            anchors.fill: parent
            radius: cardRoot.isCrtMode ? 4 : 8
            color: cardRoot.isCrtMode ? "#FFFFFF" : "#FCFCFD"
            border.color: {
                if (cardRoot.isWinning) return "#FACC15";
                if (cardRoot.isHeld) return (cardRoot.isCrtMode ? "#FFCC00" : "#38BDF8");
                return (cardRoot.isCrtMode ? "#000000" : "#CBD5E1");
            }
            border.width: (cardRoot.isWinning || cardRoot.isHeld) ? 2.5 : (cardRoot.isCrtMode ? 2 : 1.2)
            clip: true
            visible: cardRotation.angle < 90

            readonly property bool isJokerCard: cardRoot.cardData ? (cardRoot.cardData.isJoker === true || cardRoot.cardData.suit === "joker") : false
            readonly property string rankText: cardRoot.cardData ? (isJokerCard ? "JK" : (cardRoot.cardData.value || "")) : ""
            readonly property string suitText: cardRoot.cardData ? (isJokerCard ? "★" : (cardRoot.cardData.suit || "")) : ""
            readonly property color suitColor: {
                if (isJokerCard) return "#9333EA";
                return (cardRoot.cardData && cardRoot.cardData.isRed) ? "#DC2626" : "#0F172A";
            }
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
                    font.family: cardRoot.isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(10, Math.round(cardRoot.width * 0.14)) : Math.max(12, Math.round(cardRoot.width * 0.17))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(11, Math.round(cardRoot.width * 0.16))
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
                    font.family: cardRoot.isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                    font.pixelSize: frontFace.rankText === "10" ? Math.max(10, Math.round(cardRoot.width * 0.14)) : Math.max(12, Math.round(cardRoot.width * 0.17))
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: Math.max(11, Math.round(cardRoot.width * 0.16))
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Center Art Frame
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(cardRoot.width * 0.22)

                // Joker Center Display
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: frontFace.isJokerCard

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🃏"
                        font.pixelSize: Math.round(cardRoot.width * 0.36)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "JOKER"
                        font.pixelSize: Math.round(cardRoot.width * 0.13)
                        font.bold: true
                        color: "#9333EA"
                    }
                }

                // Big Ace Center Emblem
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: Math.round(cardRoot.width * 0.44)
                    color: frontFace.suitColor
                    visible: frontFace.isAce && !frontFace.isJokerCard
                }

                // Royal Face Card (Jack / Queen / King) Retro Badge
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.95
                    height: parent.height * 0.95
                    radius: cardRoot.isCrtMode ? 2 : 4
                    color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.06)
                    border.color: Qt.rgba(frontFace.suitColor.r, frontFace.suitColor.g, frontFace.suitColor.b, 0.3)
                    border.width: 1
                    visible: frontFace.isFace && !frontFace.isJokerCard

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
                    visible: !frontFace.isAce && !frontFace.isFace && !frontFace.isJokerCard
                }
            }

            // WILD Badge (Deuces Wild or Joker)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: wildText.implicitWidth + 8
                height: 15
                radius: 3
                color: "#F59E0B"
                border.color: "#B45309"
                border.width: 1
                visible: cardRoot.isWild || (cardRoot.cardData ? (cardRoot.cardData.isDeuce === true || cardRoot.cardData.isJoker === true) : false)

                Text {
                    id: wildText
                    anchors.centerIn: parent
                    text: "WILD"
                    font.pixelSize: 9
                    font.bold: true
                    color: "#FFFFFF"
                }
            }

            // =================================================================
            // HELD BANNER (The Iconic Video Poker Stamp)
            // =================================================================
            Rectangle {
                id: heldBanner
                anchors.top: parent.top
                anchors.topMargin: 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.round(cardRoot.height * 0.22)
                color: cardRoot.isCrtMode ? "#DC2626" : "#E11D48"
                border.color: cardRoot.isCrtMode ? "#FEF08A" : "#FFFFFF"
                border.width: 1.5
                visible: cardRoot.isHeld
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "HELD"
                    font.family: cardRoot.isCrtMode ? "Courier New, monospace" : ((Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font")
                    font.pixelSize: Math.max(11, Math.round(cardRoot.width * 0.18))
                    font.bold: true
                    color: cardRoot.isCrtMode ? "#FEF08A" : "#FFFFFF"
                }
            }
        }

        // =====================================================================
        // BACK FACE (Visible when angle >= 90, flipped 180° so logo is upright)
        // =====================================================================
        Rectangle {
            id: backFace
            anchors.fill: parent
            radius: cardRoot.isCrtMode ? 4 : 8
            color: cardRoot.isCrtMode ? "#0000AA" : "#080612"
            border.color: cardRoot.cardBackBorderColor
            border.width: cardRoot.isCrtMode ? 2 : 1.2
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

            // In CRT mode, if no custom back svg, display classic cross-hatch or solid blue retro border
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: "transparent"
                border.color: "#FFCC00"
                border.width: 1
                visible: cardRoot.isCrtMode
            }
        }
    }
}
