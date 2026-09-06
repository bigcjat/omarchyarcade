import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 44
    width: Math.min(parent.width - 240, 680)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 18
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 22
    color: "#181825"
    border.color: "#313244"
    border.width: 1.5

    property string message: "Welcome to ByteCity!"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: "#89b4fa"
            Text {
                anchors.centerIn: parent
                text: "🎩"
                font.pixelSize: 15
            }
        }

        Text {
            text: "ADVISOR:"
            color: "#fab387"
            font.pixelSize: 11
            font.bold: true
        }

        Text {
            id: msgText
            Layout.fillWidth: true
            text: root.message
            color: "#cdd6f4"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
