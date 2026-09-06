import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 82
    color: "#181825"
    radius: 12
    border.color: "#313244"
    border.width: 1

    property int activeTool: 9 // Default: Road
    signal toolSelected(int toolId)

    // Tool metadata list
    readonly property var tools: [
        { id: -1, name: "Pan Hand", cost: "Free",    size: "Move", icon: "✋", color: "#89b4fa" },
        { id: 7,  name: "Bulldoze", cost: "$1",      size: "1x1",  icon: "🚜", color: "#f38ba8" },
        { id: 9,  name: "Road",     cost: "$10",     size: "1x1",  icon: "🛣️", color: "#cdd6f4" },
        { id: 6,  name: "Power",    cost: "$5",      size: "1x1",  icon: "⚡", color: "#fab387" },
        { id: 8,  name: "Railroad", cost: "$20",     size: "1x1",  icon: "🛤️", color: "#f9e2af" },
        { id: 0,  name: "Res Zone", cost: "$100",    size: "3x3",  icon: "🏠", color: "#a6e3a1" },
        { id: 1,  name: "Com Zone", cost: "$100",    size: "3x3",  icon: "🏢", color: "#89dceb" },
        { id: 2,  name: "Ind Zone", cost: "$100",    size: "3x3",  icon: "🏭", color: "#fab387" },
        { id: 4,  name: "Police",   cost: "$500",    size: "3x3",  icon: "👮", color: "#89b4fa" },
        { id: 3,  name: "Fire Dept",cost: "$500",    size: "3x3",  icon: "🚒", color: "#f38ba8" },
        { id: 13, name: "Coal Pwr", cost: "$3,000",  size: "4x4",  icon: "🏭", color: "#fab387" },
        { id: 14, name: "Nuc Pwr",  cost: "$5,000",  size: "4x4",  icon: "⚛️", color: "#89dceb" },
        { id: 11, name: "Park",     cost: "$10",     size: "1x1",  icon: "🌲", color: "#a6e3a1" },
        { id: 10, name: "Stadium",  cost: "$5,000",  size: "4x4",  icon: "🏟️", color: "#cba6f7" },
        { id: 12, name: "Seaport",  cost: "$3,000",  size: "4x4",  icon: "⚓", color: "#89dceb" },
        { id: 15, name: "Airport",  cost: "$10,000", size: "6x6",  icon: "✈️", color: "#cba6f7" }
    ]

    // Active tool helper
    readonly property var currentToolInfo: {
        for (var i = 0; i < tools.length; i++) {
            if (tools[i].id === activeTool) return tools[i];
        }
        return tools[0];
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        // Scrollable tool list
        ScrollView {
            width: parent.width
            height: parent.height - 72
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Column {
                width: parent.width
                spacing: 3

                Repeater {
                    model: root.tools

                    Rectangle {
                        width: 72
                        height: 44
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 6
                        color: root.activeTool === modelData.id ? "#313244" : (mouseArea.containsMouse ? "#252538" : "#1e1e2e")
                        border.color: root.activeTool === modelData.id ? modelData.color : "#313244"
                        border.width: root.activeTool === modelData.id ? 2 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: modelData.cost
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.activeTool === modelData.id ? modelData.color : "#cdd6f4"
                                }
                                Text {
                                    text: modelData.size
                                    font.pixelSize: 8
                                    color: "#a6adc8"
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTool = modelData.id
                                root.toolSelected(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // Integrated Solid Tool Inspector at bottom (replaces broken overlapping tooltips)
        Rectangle {
            width: 72
            height: 64
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 8
            color: "#1e1e2e"
            border.color: root.currentToolInfo ? root.currentToolInfo.color : "#313244"
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentToolInfo ? root.currentToolInfo.name : ""
                    font.pixelSize: 9
                    font.bold: true
                    color: root.currentToolInfo ? root.currentToolInfo.color : "#cdd6f4"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentToolInfo ? root.currentToolInfo.cost : ""
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentToolInfo ? root.currentToolInfo.size : ""
                    font.pixelSize: 8
                    color: "#a6adc8"
                }
            }
        }
    }
}
