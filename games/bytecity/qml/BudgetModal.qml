import QtQuick
import QtQuick.Controls
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
    property int currentTax: engine ? engine.taxRate : 7

    signal closed()

    // Consume clicks so they don't fall through to viewport
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Title Row
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "📊 Annual City Budget"
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

        // Tax Rate Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Property Tax Rate"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: taxSlider.value + "%"
                    color: "#a6e3a1"
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            Slider {
                id: taxSlider
                Layout.fillWidth: true
                from: 0
                to: 20
                stepSize: 1
                value: root.currentTax
                onMoved: {
                    if (root.engine) root.engine.set_tax_rate(value)
                }
            }

            Text {
                text: "Recommended: 5% - 9%. Higher taxes cause residents and businesses to leave."
                color: "#a6adc8"
                font.pixelSize: 11
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        // Financial Summary
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Current Treasury:"; color: "#a6adc8"; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text {
                    text: "$" + (root.engine ? root.engine.funds.toLocaleString() : "0")
                    color: "#a6e3a1"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "City Population:"; color: "#a6adc8"; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text {
                    text: (root.engine ? root.engine.population.toLocaleString() : "0")
                    color: "#89dceb"
                    font.pixelSize: 13
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Projected Annual Tax Revenue:"; color: "#a6adc8"; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text {
                    property int proj: root.engine ? Math.round(root.engine.population * (taxSlider.value / 100.0) * 12) : 0
                    text: "+$" + proj.toLocaleString()
                    color: "#a6e3a1"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Done button
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 8
            color: doneMa.containsMouse ? "#74c7ec" : "#89b4fa"

            Text {
                anchors.centerIn: parent
                text: "Apply & Close"
                color: "#11111b"
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
