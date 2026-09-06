import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 480
    height: 380
    anchors.centerIn: parent
    radius: 16
    color: "#181825"
    border.color: "#45475a"
    border.width: 2
    visible: false

    property var engine: null

    signal closed()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "🗳️ Citizen Evaluation & Approval"
                color: "#cdd6f4"
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeMa.containsMouse ? "#45475a" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#cdd6f4"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closed()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        // Mayor Approval Meter
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // Circular / Box Rating
            Rectangle {
                width: 90
                height: 90
                radius: 45
                color: "#181825"
                border.color: (root.engine && root.engine.approvalRating >= 50) ? "#a6e3a1" : "#f38ba8"
                border.width: 3

                Column {
                    anchors.centerIn: parent
                    Text {
                        text: (root.engine ? root.engine.approvalRating : 75) + "%"
                        color: (root.engine && root.engine.approvalRating >= 50) ? "#a6e3a1" : "#f38ba8"
                        font.pixelSize: 22
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "APPROVAL"
                        color: "#a6adc8"
                        font.pixelSize: 8
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Mayor's Public Standing"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: (root.engine && root.engine.approvalRating >= 60)
                          ? "Citizens are pleased with your governance and city development."
                          : "Citizens are discontented. Check taxes, crime, and services."
                    color: "#a6adc8"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        // Top Citizen Concerns
        Text {
            text: "Public Opinion Polls"
            color: "#cdd6f4"
            font.pixelSize: 14
            font.bold: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { issue: "Taxes & Spending", stat: (root.engine && root.engine.taxRate > 9 ? "Too High" : "Reasonable") },
                    { issue: "Housing & Jobs", stat: "Adequate" },
                    { issue: "Road Network & Traffic", stat: "Flowing" }
                ]

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "• " + modelData.issue; color: "#cdd6f4"; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    Text { text: modelData.stat; color: "#89dceb"; font.pixelSize: 12; font.bold: true }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Close button
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 8
            color: doneMa.containsMouse ? "#45475a" : "#313244"

            Text {
                anchors.centerIn: parent
                text: "Close"
                color: "#cdd6f4"
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: doneMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closed()
            }
        }
    }
}
