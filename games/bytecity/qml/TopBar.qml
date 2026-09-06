import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 56
    color: "#181825"
    border.color: "#313244"
    border.width: 1

    property var engine: null

    signal budgetClicked()
    signal evalClicked()
    signal disasterClicked()
    signal newMapClicked()
    signal centerClicked()
    signal miniMapClicked()
    signal soundClicked()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        // City Brand
        RowLayout {
            spacing: 8
            Text {
                text: "🏙️"
                font.pixelSize: 22
            }
            Column {
                Text {
                    text: "ByteCity"
                    color: "#cdd6f4"
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: "Micropolis Core"
                    color: "#6c7086"
                    font.pixelSize: 10
                }
            }
        }

        Rectangle { width: 1; height: 32; color: "#313244" }

        // Date & Population
        RowLayout {
            spacing: 16
            Column {
                Text {
                    text: "DATE"
                    color: "#a6adc8"
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    text: (root.engine ? root.engine.monthName : "Jan") + " " + (root.engine ? root.engine.year : "1900")
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Column {
                Text {
                    text: "FUNDS"
                    color: "#a6adc8"
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    text: "$" + (root.engine ? root.engine.funds.toLocaleString() : "20,000")
                    color: "#a6e3a1"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            Column {
                Text {
                    text: "POPULATION"
                    color: "#a6adc8"
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    text: (root.engine ? root.engine.population.toLocaleString() : "0")
                    color: "#89dceb"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        Rectangle { width: 1; height: 32; color: "#313244" }

        // RCI Demand Meters
        RowLayout {
            spacing: 8
            Text {
                text: "RCI"
                color: "#a6adc8"
                font.pixelSize: 10
                font.bold: true
            }

            // Demand Bars Container
            Row {
                spacing: 4
                // R Bar
                Rectangle {
                    width: 10
                    height: 28
                    radius: 2
                    color: "#1e1e2e"
                    border.color: "#313244"
                    border.width: 1
                    clip: true
                    Rectangle {
                        width: parent.width
                        height: Math.max(2, Math.min(28, (root.engine ? (root.engine.demandRes + 1.0) / 2.0 : 0.5) * 28))
                        anchors.bottom: parent.bottom
                        color: "#a6e3a1"
                    }
                }
                // C Bar
                Rectangle {
                    width: 10
                    height: 28
                    radius: 2
                    color: "#1e1e2e"
                    border.color: "#313244"
                    border.width: 1
                    clip: true
                    Rectangle {
                        width: parent.width
                        height: Math.max(2, Math.min(28, (root.engine ? (root.engine.demandCom + 1.0) / 2.0 : 0.5) * 28))
                        anchors.bottom: parent.bottom
                        color: "#89dceb"
                    }
                }
                // I Bar
                Rectangle {
                    width: 10
                    height: 28
                    radius: 2
                    color: "#1e1e2e"
                    border.color: "#313244"
                    border.width: 1
                    clip: true
                    Rectangle {
                        width: parent.width
                        height: Math.max(2, Math.min(28, (root.engine ? (root.engine.demandInd + 1.0) / 2.0 : 0.5) * 28))
                        anchors.bottom: parent.bottom
                        color: "#fab387"
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Simulation Speed Controls
        RowLayout {
            spacing: 4

            Repeater {
                model: [
                    { speed: 0, label: "⏸" },
                    { speed: 1, label: "▶" },
                    { speed: 2, label: "▶▶" },
                    { speed: 3, label: "⚡" }
                ]

                Rectangle {
                    width: 30
                    height: 30
                    radius: 6
                    color: (root.engine && root.engine.simSpeed === modelData.speed) ? "#89b4fa" : (spMa.containsMouse ? "#313244" : "#1e1e2e")
                    border.color: "#45475a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: (root.engine && root.engine.simSpeed === modelData.speed) ? "#11111b" : "#cdd6f4"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: spMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.engine) root.engine.set_speed(modelData.speed)
                    }
                }
            }
        }

        Rectangle { width: 1; height: 32; color: "#313244" }

        // Modals & Action Buttons
        RowLayout {
            spacing: 6

            // Budget Button
            Rectangle {
                width: 76
                height: 32
                radius: 6
                color: bMa.containsMouse ? "#313244" : "#1e1e2e"
                border.color: "#45475a"
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "📊"; font.pixelSize: 12 }
                    Text { text: "Budget"; color: "#cdd6f4"; font.pixelSize: 11; font.bold: true }
                }
                MouseArea {
                    id: bMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.budgetClicked()
                }
            }

            // Evaluation Button
            Rectangle {
                width: 76
                height: 32
                radius: 6
                color: evMa.containsMouse ? "#313244" : "#1e1e2e"
                border.color: "#45475a"
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "🗳️"; font.pixelSize: 12 }
                    Text { text: "Polls"; color: "#cdd6f4"; font.pixelSize: 11; font.bold: true }
                }
                MouseArea {
                    id: evMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.evalClicked()
                }
            }

            // Disasters Button
            Rectangle {
                width: 80
                height: 32
                radius: 6
                color: disMa.containsMouse ? "#452230" : "#2a1e28"
                border.color: "#f38ba8"
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "🌪️"; font.pixelSize: 12 }
                    Text { text: "Disasters"; color: "#f38ba8"; font.pixelSize: 11; font.bold: true }
                }
                MouseArea {
                    id: disMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.disasterClicked()
                }
            }

            // MiniMap Button
            Rectangle {
                width: 68
                height: 32
                radius: 6
                color: mapMa.containsMouse ? "#313244" : "#1e1e2e"
                border.color: "#45475a"
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "🗺️"; font.pixelSize: 12 }
                    Text { text: "Map"; color: "#cdd6f4"; font.pixelSize: 11; font.bold: true }
                }
                MouseArea {
                    id: mapMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.miniMapClicked()
                }
            }

            // Sound FX Button
            Rectangle {
                width: 34
                height: 32
                radius: 6
                color: sndMa.containsMouse ? "#313244" : "#1e1e2e"
                border.color: "#45475a"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: (root.engine && root.engine.soundEnabled) ? "🔊" : "🔇"
                    font.pixelSize: 13
                }
                MouseArea {
                    id: sndMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.soundClicked()
                }
            }

            // Center View Button
            Rectangle {
                width: 32
                height: 32
                radius: 6
                color: cMa.containsMouse ? "#313244" : "#1e1e2e"
                border.color: "#45475a"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "🎯"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: cMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.centerClicked()
                }
            }
        }
    }
}
