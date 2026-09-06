import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: garageModal
    anchors.fill: parent
    color: "#cc020617"
    z: 100
    focus: true
    onVisibleChanged: {
        if (visible) forceActiveFocus();
    }

    property var vehicles: [
        {
            id: "keitruck",
            name: "Suzuki Carry Kei Truck",
            subtitle: "658cc 3-Cyl • 5-Speed Manual • 68 MPH",
            spriteUrl: Qt.resolvedUrl("assets/kei_straight.webp"),
            spriteW: 130,
            spriteH: 125,
            accentColor: "#facc15"
        },
        {
            id: "smart",
            name: "Smart Fortwo",
            subtitle: "599cc 3-Cyl • 5-Speed Auto-Manual • 84 MPH",
            spriteUrl: Qt.resolvedUrl("assets/smart_straight.webp"),
            spriteW: 135,
            spriteH: 120,
            accentColor: "#ef4444"
        },
        {
            id: "panda",
            name: "Fiat Panda 4x4",
            subtitle: "999cc FIRE Inline-4 • 5-Speed 4WD • 78 MPH",
            spriteUrl: Qt.resolvedUrl("assets/panda_straight.webp"),
            spriteW: 130,
            spriteH: 122,
            accentColor: "#38bdf8"
        },
        {
            id: "sidekick",
            name: "Suzuki Sidekick",
            subtitle: "1.6L 8V Inline-4 • 5-Speed 4WD • 81 MPH",
            spriteUrl: Qt.resolvedUrl("assets/sidekick_straight.webp"),
            spriteW: 130,
            spriteH: 125,
            accentColor: "#eab308"
        },
        {
            id: "wrangler",
            name: "Jeep Wrangler YJ",
            subtitle: "2.5L AMC 150 Inline-4 • 5-Speed 4WD • 78 MPH",
            spriteUrl: Qt.resolvedUrl("assets/wrangler_straight.webp"),
            spriteW: 130,
            spriteH: 125,
            accentColor: "#f59e0b"
        },
        {
            id: "vwbus",
            name: "Volkswagen Type 2 Bus",
            subtitle: "1.6L Boxer Flat-4 • 4-Speed Manual • 65 MPH",
            spriteUrl: Qt.resolvedUrl("assets/vwbus_straight.webp"),
            spriteW: 125,
            spriteH: 128,
            accentColor: "#f97316"
        }
    ]

    property int currentIndex: 0
    property var currentCar: vehicles[currentIndex]

    signal carSelected(string carId)
    signal closeRequested()

    function nextCar() {
        currentIndex = (currentIndex + 1) % vehicles.length;
        carSwitchedSound();
    }

    function prevCar() {
        currentIndex = (currentIndex - 1 + vehicles.length) % vehicles.length;
        carSwitchedSound();
    }

    function carSwitchedSound() {
        if (typeof root !== "undefined" && root.playSound) {
            root.playSound("checkpoint");
        }
    }

    function selectCurrentCar() {
        carSelected(currentCar.id);
    }

    // Dismiss by clicking outside modal card
    MouseArea {
        anchors.fill: parent
        onClicked: closeRequested()
    }

    // Compact Modal Card
    Rectangle {
        id: modalCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 380)
        height: Math.min(parent.height - 24, 280)
        color: "#0f172a"
        border.color: currentCar.accentColor
        border.width: 1.5
        radius: 12
        clip: true

        Behavior on border.color { ColorAnimation { duration: 200 } }

        // Block clicks from passing through
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "🏎️"
                    font.pixelSize: 14
                }

                Text {
                    text: "SELECT CAR"
                    font.family: root.monoFontFamily
                    font.pixelSize: 13
                    font.weight: Font.Black
                    font.letterSpacing: 1
                    color: "#f8fafc"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: (currentIndex + 1) + " / " + vehicles.length
                    font.family: root.monoFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: currentCar.accentColor
                }

                // Close Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: closeMouse.containsMouse ? "#334155" : "#1e293b"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: "#94a3b8"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closeRequested()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1e293b"
            }

            // Car Preview Carousel
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Prev Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: prevMouse.containsMouse ? "#334155" : "#1e293b"
                    border.color: currentCar.accentColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        font.pixelSize: 12
                        color: "#f8fafc"
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prevCar()
                    }
                }

                // Car Image Display
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Image {
                        id: previewSprite
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 140)
                        height: Math.min(parent.height, 95)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: currentCar.spriteUrl
                    }
                }

                // Next Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: nextMouse.containsMouse ? "#334155" : "#1e293b"
                    border.color: currentCar.accentColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        font.pixelSize: 12
                        color: "#f8fafc"
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nextCar()
                    }
                }
            }

            // Car Name & Subtitle
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: currentCar.name
                    font.family: root.monoFontFamily
                    font.pixelSize: 14
                    font.weight: Font.Black
                    color: currentCar.accentColor
                    elide: Text.ElideRight
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: currentCar.subtitle
                    font.family: root.monoFontFamily
                    font.pixelSize: 10
                    color: "#94a3b8"
                    elide: Text.ElideRight
                }
            }

            // Select Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: selectMouse.containsMouse ? Qt.lighter(currentCar.accentColor, 1.15) : currentCar.accentColor

                Text {
                    anchors.centerIn: parent
                    text: "SELECT (Enter)"
                    font.family: root.monoFontFamily
                    font.pixelSize: 12
                    font.weight: Font.Black
                    color: "#0f172a"
                }

                MouseArea {
                    id: selectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: selectCurrentCar()
                }
            }
        }
    }

    // Keyboard navigation
    Keys.onLeftPressed: prevCar()
    Keys.onRightPressed: nextCar()
    Keys.onReturnPressed: selectCurrentCar()
    Keys.onSpacePressed: selectCurrentCar()
    Keys.onEscapePressed: closeRequested()
}
