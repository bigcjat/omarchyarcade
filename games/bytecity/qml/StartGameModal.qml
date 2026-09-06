import QtQuick
import QtQuick.Controls

Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.75)
    visible: true
    z: 100

    property QtObject engine: null
    property var viewport: null

    signal gameStarted()

    Rectangle {
        id: card
        width: 760
        height: 560
        anchors.centerIn: parent
        color: "#181825"
        radius: 16
        border.color: "#313244"
        border.width: 1

        // Header
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "#1e1e2e"
            radius: 16

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 16
                color: "#1e1e2e"
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    text: "🏛️"
                    font.pixelSize: 24
                }

                Column {
                    Text {
                        text: "BYTECITY HALL • CHOOSE YOUR CITY"
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: "#cdd6f4"
                    }
                    Text {
                        text: "Powered by the authentic 1989 Micropolis simulation core"
                        font.pixelSize: 11
                        color: "#a6adc8"
                    }
                }
            }

            // Close button (only active if game is already running)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: closeMouse.containsMouse ? "#f38ba8" : "#313244"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 12
                    color: closeMouse.containsMouse ? "#11111b" : "#cdd6f4"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modalRoot.visible = false
                        if (modalRoot.viewport) modalRoot.viewport.forceActiveFocus();
                    }
                }
            }
        }

        // Mode Switcher Tabs (New City vs Classic Scenarios)
        Row {
            id: tabRow
            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            property int currentTab: 0 // 0 = New City, 1 = Scenarios

            Rectangle {
                width: 200
                height: 38
                radius: 8
                color: tabRow.currentTab === 0 ? "#89b4fa" : "#313244"

                Text {
                    anchors.centerIn: parent
                    text: "🌱 Build New City"
                    font.pixelSize: 13
                    font.bold: true
                    color: tabRow.currentTab === 0 ? "#11111b" : "#cdd6f4"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tabRow.currentTab = 0
                }
            }

            Rectangle {
                width: 200
                height: 38
                radius: 8
                color: tabRow.currentTab === 1 ? "#89b4fa" : "#313244"

                Text {
                    anchors.centerIn: parent
                    text: "📜 Classic Scenarios (8)"
                    font.pixelSize: 13
                    font.bold: true
                    color: tabRow.currentTab === 1 ? "#11111b" : "#cdd6f4"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tabRow.currentTab = 1
                }
            }
        }

        // ================= TAB 0: NEW CITY BUILDER =================
        Item {
            id: newCityTab
            anchors.top: tabRow.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: tabRow.currentTab === 0

            property int selectedLevel: 0 // 0=Easy, 1=Medium, 2=Hard
            property int currentSeed: 42

            Row {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 32

                // Left Column: Configuration
                Column {
                    width: 380
                    spacing: 16

                    // City Name
                    Column {
                        spacing: 6
                        Text {
                            text: "CITY NAME:"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#a6adc8"
                        }
                        Rectangle {
                            width: 380
                            height: 38
                            radius: 8
                            color: "#1e1e2e"
                            border.color: "#45475a"

                            TextInput {
                                id: cityNameInput
                                anchors.fill: parent
                                anchors.margins: 10
                                text: "New Haven"
                                font.pixelSize: 14
                                color: "#cdd6f4"
                                selectByMouse: true
                            }
                        }
                    }

                    // Difficulty Level
                    Column {
                        spacing: 6
                        Text {
                            text: "DIFFICULTY LEVEL:"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#a6adc8"
                        }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [
                                    { title: "Easy", funds: "$20,000", level: 0 },
                                    { title: "Medium", funds: "$10,000", level: 1 },
                                    { title: "Hard", funds: "$5,000", level: 2 }
                                ]
                                Rectangle {
                                    width: 121
                                    height: 52
                                    radius: 8
                                    color: newCityTab.selectedLevel === modelData.level ? "#a6e3a1" : "#1e1e2e"
                                    border.color: newCityTab.selectedLevel === modelData.level ? "#a6e3a1" : "#45475a"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: newCityTab.selectedLevel === modelData.level ? "#11111b" : "#cdd6f4"
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.funds
                                            font.pixelSize: 11
                                            color: newCityTab.selectedLevel === modelData.level ? "#181825" : "#a6adc8"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newCityTab.selectedLevel = modelData.level
                                    }
                                }
                            }
                        }
                    }

                    // Seed Control
                    Column {
                        spacing: 6
                        Text {
                            text: "TERRAIN SEED:"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#a6adc8"
                        }
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 200
                                height: 36
                                radius: 8
                                color: "#1e1e2e"
                                border.color: "#45475a"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Seed #" + newCityTab.currentSeed
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#f9e2af"
                                }
                            }

                            Rectangle {
                                width: 172
                                height: 36
                                radius: 8
                                color: rollMouse.containsMouse ? "#89b4fa" : "#313244"

                                Text {
                                    anchors.centerIn: parent
                                    text: "🎲 Roll New Land"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: rollMouse.containsMouse ? "#11111b" : "#cdd6f4"
                                }

                                MouseArea {
                                    id: rollMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        newCityTab.currentSeed = Math.floor(Math.random() * 9999) + 1;
                                        if (modalRoot.engine) {
                                            modalRoot.engine.generate_new_city(newCityTab.currentSeed);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Right Column: Start Button & Instructions
                Column {
                    width: 280
                    spacing: 16

                    Rectangle {
                        width: 280
                        height: 170
                        radius: 12
                        color: "#1e1e2e"
                        border.color: "#313244"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                text: "MAYOR'S HANDBOOK:"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#89b4fa"
                            }
                            Text {
                                width: parent.width
                                text: "• Zone Residential, Commercial, and Industrial plots.\n• Power zones from a Coal or Nuclear plant.\n• Interconnect with Roads or Rail.\n• Maintain safety with Fire and Police precincts.\n• Balance taxes in the annual Budget."
                                font.pixelSize: 11
                                lineHeight: 1.3
                                color: "#bac2de"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Start Mayorship Button
                    Rectangle {
                        width: 280
                        height: 48
                        radius: 10
                        color: startMouse.containsMouse ? "#a6e3a1" : "#94e2d5"

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "🚀"
                                font.pixelSize: 16
                            }
                            Text {
                                text: "BEGIN MAYORSHIP"
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 1
                                color: "#11111b"
                            }
                        }

                        MouseArea {
                            id: startMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modalRoot.engine) {
                                    modalRoot.engine.start_new_city(
                                        cityNameInput.text,
                                        newCityTab.selectedLevel,
                                        newCityTab.currentSeed
                                    );
                                }
                                if (modalRoot.viewport) {
                                    modalRoot.viewport.center_on_map();
                                    modalRoot.viewport.forceActiveFocus();
                                }
                                modalRoot.visible = false;
                                modalRoot.gameStarted();
                            }
                        }
                    }
                }
            }
        }

        // ================= TAB 1: SCENARIOS =================
        Item {
            id: scenarioTab
            anchors.top: tabRow.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: tabRow.currentTab === 1

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 12

                Repeater {
                    model: [
                        { id: "san_francisco", icon: "🌋", name: "San Francisco (1906)", desc: "Recover from the devastating magnitude 7.9 earthquake and firestorm." },
                        { id: "tokyo", icon: "👾", name: "Tokyo (1957)", desc: "Rebuild Tokyo Bay following a catastrophic giant monster rampage." },
                        { id: "hamburg", icon: "🔥", name: "Hamburg (1944)", desc: "Reconstruct the historic harbor metropolis devastated by bombing firestorms." },
                        { id: "bern", icon: "🚗", name: "Bern (1965)", desc: "Solve severe traffic paralysis by redesigning transit and laying commuter rail." },
                        { id: "detroit", icon: "🚨", name: "Detroit (1972)", desc: "Tackle economic depression, high unemployment, and rampant violent crime." },
                        { id: "boston", icon: "☢️", name: "Boston (2010)", desc: "Contain and evacuate a nuclear plant core meltdown along the coast." },
                        { id: "rio", icon: "🌊", name: "Rio de Janeiro (2047)", desc: "Combat rising sea levels and catastrophic shoreline flooding." },
                        { id: "dullsville", icon: "💤", name: "Dullsville (1900)", desc: "Revitalize an economically stagnant, sleepy town into a thriving metropolis." }
                    ]

                    Rectangle {
                        width: 345
                        height: 86
                        radius: 10
                        color: scenMouse.containsMouse ? "#313244" : "#1e1e2e"
                        border.color: scenMouse.containsMouse ? "#89b4fa" : "#313244"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Text {
                                text: modelData.icon
                                font.pixelSize: 28
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: 260
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: modelData.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#cdd6f4"
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.desc
                                    font.pixelSize: 10
                                    color: "#a6adc8"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        MouseArea {
                            id: scenMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modalRoot.engine) {
                                    modalRoot.engine.load_scenario(modelData.id);
                                }
                                if (modalRoot.viewport) {
                                    modalRoot.viewport.center_on_map();
                                    modalRoot.viewport.forceActiveFocus();
                                }
                                modalRoot.visible = false;
                                modalRoot.gameStarted();
                            }
                        }
                    }
                }
            }
        }
    }
}
