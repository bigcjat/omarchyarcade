import QtQuick
import QtQuick.Controls

Rectangle {
    id: menuBarRoot
    height: 30
    color: "#11111b"
    border.color: "#313244"
    border.width: 1

    property QtObject engine: null
    property var viewport: null

    signal openNewCity()
    signal openScenarios()
    signal toggleMiniMap()
    signal toggleBudget()
    signal toggleEval()
    signal toggleDisaster()

    // Save directory
    property string savePath: "/Users/christhompson/arcade/games/bytecity/saves/city.cty"

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // 1. City / File Menu
        Rectangle {
            width: 70
            height: 24
            radius: 4
            color: cityMenuMouse.containsMouse || cityMenu.visible ? "#313244" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "📁 City"
                font.pixelSize: 11
                font.bold: true
                color: "#cdd6f4"
            }

            MouseArea {
                id: cityMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cityMenu.open()
            }

            Menu {
                id: cityMenu
                y: parent.height

                MenuItem {
                    text: "🌱 New City..."
                    onTriggered: menuBarRoot.openNewCity()
                }
                MenuItem {
                    text: "📜 Scenarios..."
                    onTriggered: menuBarRoot.openScenarios()
                }
                MenuSeparator {}
                MenuItem {
                    text: "💾 Save City"
                    onTriggered: {
                        if (menuBarRoot.engine) {
                            menuBarRoot.engine.save_city_file(menuBarRoot.savePath);
                            menuBarRoot.engine.play_sound("beep");
                        }
                    }
                }
                MenuItem {
                    text: "📂 Load Saved City"
                    onTriggered: {
                        if (menuBarRoot.engine) {
                            menuBarRoot.engine.load_city_file(menuBarRoot.savePath);
                        }
                    }
                }
                MenuSeparator {}
                MenuItem {
                    text: "🎯 Center Camera"
                    onTriggered: {
                        if (menuBarRoot.viewport) menuBarRoot.viewport.center_on_map();
                    }
                }
            }
        }

        // 2. Options Menu
        Rectangle {
            width: 80
            height: 24
            radius: 4
            color: optMenuMouse.containsMouse || optMenu.visible ? "#313244" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "⚙️ Options"
                font.pixelSize: 11
                font.bold: true
                color: "#cdd6f4"
            }

            MouseArea {
                id: optMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: optMenu.open()
            }

            Menu {
                id: optMenu
                y: parent.height

                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.autoBulldoze ? "☑" : "☐") + " Auto-Bulldoze"
                    onTriggered: {
                        if (menuBarRoot.engine) {
                            menuBarRoot.engine.set_auto_bulldoze(!menuBarRoot.engine.autoBulldoze);
                        }
                    }
                }
                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.autoBudget ? "☑" : "☐") + " Auto-Budget"
                    onTriggered: {
                        if (menuBarRoot.engine) {
                            menuBarRoot.engine.set_auto_budget(!menuBarRoot.engine.autoBudget);
                        }
                    }
                }
                MenuSeparator {}
                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.soundEnabled ? "🔊 Sound FX: ON" : "🔇 Sound FX: MUTED")
                    onTriggered: {
                        if (menuBarRoot.engine) {
                            menuBarRoot.engine.set_sound_muted(menuBarRoot.engine.soundEnabled);
                        }
                    }
                }
            }
        }

        // 3. Disasters Menu
        Rectangle {
            width: 86
            height: 24
            radius: 4
            color: disMenuMouse.containsMouse || disMenu.visible ? "#313244" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "⚡ Disasters"
                font.pixelSize: 11
                font.bold: true
                color: "#f38ba8"
            }

            MouseArea {
                id: disMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: disMenu.open()
            }

            Menu {
                id: disMenu
                y: parent.height

                MenuItem {
                    text: "👾 Monster Attack"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(2);
                }
                MenuItem {
                    text: "🌋 Earthquake"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(4);
                }
                MenuItem {
                    text: "🌪️ Tornado"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(3);
                }
                MenuItem {
                    text: "🔥 Fire Outbreak"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(0);
                }
                MenuItem {
                    text: "🌊 River Flood"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(1);
                }
                MenuItem {
                    text: "☢️ Nuclear Meltdown"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.trigger_disaster(5);
                }
            }
        }

        // 4. Windows Menu
        Rectangle {
            width: 86
            height: 24
            radius: 4
            color: winMenuMouse.containsMouse || winMenu.visible ? "#313244" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "🪟 Windows"
                font.pixelSize: 11
                font.bold: true
                color: "#cdd6f4"
            }

            MouseArea {
                id: winMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: winMenu.open()
            }

            Menu {
                id: winMenu
                y: parent.height

                MenuItem {
                    text: "🗺️ Map Overview (Minimap)"
                    onTriggered: menuBarRoot.toggleMiniMap()
                }
                MenuItem {
                    text: "💵 City Budget & Taxes"
                    onTriggered: menuBarRoot.toggleBudget()
                }
                MenuItem {
                    text: "📊 Citizen Polls & Approval"
                    onTriggered: menuBarRoot.toggleEval()
                }
                MenuItem {
                    text: "🚨 Disaster Control"
                    onTriggered: menuBarRoot.toggleDisaster()
                }
            }
        }

        // 5. Speed Menu
        Rectangle {
            width: 76
            height: 24
            radius: 4
            color: speedMenuMouse.containsMouse || speedMenu.visible ? "#313244" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "⏱️ Speed"
                font.pixelSize: 11
                font.bold: true
                color: "#cdd6f4"
            }

            MouseArea {
                id: speedMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: speedMenu.open()
            }

            Menu {
                id: speedMenu
                y: parent.height

                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.simSpeed === 0 ? "● " : "  ") + "Pause"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.set_speed(0);
                }
                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.simSpeed === 1 ? "● " : "  ") + "Slow (1x)"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.set_speed(1);
                }
                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.simSpeed === 2 ? "● " : "  ") + "Normal (2x)"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.set_speed(2);
                }
                MenuItem {
                    text: (menuBarRoot.engine && menuBarRoot.engine.simSpeed === 3 ? "● " : "  ") + "Fast (3x)"
                    onTriggered: if (menuBarRoot.engine) menuBarRoot.engine.set_speed(3);
                }
            }
        }
    }

    // Right-aligned City Title
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: (menuBarRoot.engine ? menuBarRoot.engine.cityName : "ByteCity") + " • SimCity Classic Core"
        font.pixelSize: 11
        font.bold: true
        color: "#6c7086"
    }
}
