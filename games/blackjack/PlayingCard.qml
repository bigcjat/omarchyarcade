import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot
    width: 94
    height: 136

    property var cardData: null
    property bool faceUp: true
    property bool isWinning: false
    property bool isSelected: false

    // Deal slide-in animation
    opacity: 1
    scale: isWinning ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    // Subtle drop shadow
    Rectangle {
        anchors.fill: cardContainer
        anchors.topMargin: 4
        anchors.leftMargin: 2
        anchors.rightMargin: -2
        anchors.bottomMargin: -4
        radius: 7
        color: "#50000000"
        z: 0
    }

    // Winning Gold Halo Glow
    Rectangle {
        anchors.fill: cardContainer
        anchors.margins: -4
        radius: 10
        color: "transparent"
        border.color: "#FACC15"
        border.width: 3
        visible: cardRoot.isWinning
        z: 1

        SequentialAnimation on opacity {
            running: cardRoot.isWinning
            loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.4; duration: 400; easing.type: Easing.InOutQuad }
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
                NumberAnimation { duration: 280; easing.type: Easing.InOutCubic }
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
            border.color: cardRoot.isWinning ? "#FACC15" : "#D1D5DB"
            border.width: 1.5
            clip: true
            visible: cardRotation.angle < 90

            readonly property string rankText: cardRoot.cardData ? (cardRoot.cardData.value || cardRoot.cardData.rank || "") : ""
            readonly property string suitText: cardRoot.cardData ? (cardRoot.cardData.suit || "") : ""
            readonly property color suitColor: cardRoot.cardData ? (cardRoot.cardData.isRed ? "#E11D48" : "#0F172A") : "#0F172A"
            readonly property bool isFace: rankText === "K" || rankText === "Q" || rankText === "J"
            readonly property bool isAce: rankText === "A"

            // Top-Left Corner Pip
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 5
                spacing: -2

                Text {
                    text: frontFace.rankText
                    font.family: "monospace"
                    font.pixelSize: frontFace.rankText === "10" ? 12 : 14
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: 13
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Bottom-Right Corner Pip (Rotated 180°)
            Column {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 5
                spacing: -2
                rotation: 180

                Text {
                    text: frontFace.rankText
                    font.family: "monospace"
                    font.pixelSize: frontFace.rankText === "10" ? 12 : 14
                    font.bold: true
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: frontFace.suitText
                    font.pixelSize: 13
                    color: frontFace.suitColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Center Art Frame
            Item {
                anchors.fill: parent
                anchors.margins: 22

                // Big Ace Center Emblem
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: 42
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
                            font.pixelSize: 22
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: frontFace.suitText
                            font.pixelSize: 18
                            color: frontFace.suitColor
                        }
                    }
                }

                // Standard Number Card Center Pips (2..10)
                Text {
                    anchors.centerIn: parent
                    text: frontFace.suitText
                    font.pixelSize: 28
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
            border.color: "#00F0FF"
            border.width: 1.5
            clip: true
            visible: cardRotation.angle >= 90

            Image {
                anchors.fill: parent
                source: "assets/card_back_synthwave.svg"
                fillMode: Image.PreserveAspectCrop
                mirror: true
                smooth: true
                mipmap: true
            }
        }
    }
}
