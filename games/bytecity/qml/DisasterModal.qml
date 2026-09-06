import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 440
    height: 340
    anchors.centerIn: parent
    radius: 16
    color: "#181825"
    border.color: "#f38ba8"
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

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "⚠️ Disaster Command"
                color: "#f38ba8"
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

        Text {
            text: "Trigger disaster scenario drills to test city emergency response:"
            color: "#a6adc8"
            font.pixelSize: 11
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
                model: [
                    { id: 0, name: "City Fire", icon: "🔥", desc: "Spreads across dry land" },
                    { id: 1, name: "River Flood", icon: "🌊", desc: "Overflows water banks" },
                    { id: 2, name: "Giant Monster", icon: "🦖", desc: "Rampages downtown" },
                    { id: 3, name: "Tornado", icon: "🌪️", desc: "Rips through buildings" },
                    { id: 4, name: "Earthquake", icon: "⚡", desc: "Ruptures roads & wires" },
                    { id: 5, name: "Nuclear Meltdown", icon: "☢️", desc: "Power plant catastrophe" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 8
                    color: dMa.containsMouse ? "#3a2230" : "#251c24"
                    border.color: "#f38ba8"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: modelData.icon
                            font.pixelSize: 20
                        }

                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: "#f38ba8"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                text: modelData.desc
                                color: "#a6adc8"
                                font.pixelSize: 9
                            }
                        }
                    }

                    MouseArea {
                        id: dMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.engine) root.engine.trigger_disaster(modelData.id)
                            root.closed()
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
