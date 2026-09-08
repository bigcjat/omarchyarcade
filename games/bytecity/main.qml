import QtQuick
import QtQuick.Window
import QtQuick.Controls
import ByteCity 1.0

Window {
    id: root
    visible: true
    width: 1024
    height: 720
    minimumWidth: 640
    minimumHeight: 480
    title: "ByteCity • Classic Metropolis Simulation"

    // =========================================================================
    // OMARCHY THEME TOKENS
    // =========================================================================
    property color themeBg: "#181825"
    property color themeBoardBg: "#11111b"
    property color themeCardBg: "#1e1e2e"
    property color themeBorder: "#313244"
    property color themeFg: "#cdd6f4"
    property color themeSubtext: "#a6adc8"
    property color themeAccent: "#89b4fa"
    property color themeBtnBg: themeAccent
    property color themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"

    function colorLuminance(col) {
        var c = Qt.color(col);
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    color: themeBg

    // =========================================================================
    // DECLARATIVE STATE
    // =========================================================================
    property bool splashEnabled: true
    property bool isMuted: false
    property bool showHelp: false
    property bool showNewCityDialog: false
    property int currentTool: 9
    property string cheatBuffer: ""
    property int fundCheatCount: 0
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Pan View: Drag with Right Mouse, Middle Mouse, or WASD / Arrows\n• Zoom View: Mouse Wheel or + / -\n• Build: Left-click with active tool (Road, Wire, Rail, Bulldozer support drag)\n• Speed: Space (Pause), 1 (Normal), 2 (Fast), 3 (Ultra)\n• Sound: M | Help: ? or Esc\n\nBuild power plants, connect roads and wires, and balance Residential, Commercial, and Industrial zones to grow your metropolis!"

    function applyTheme(data, name) {
        if (!data || typeof data !== "object") return;
        var bg = data.background || data.bg || "#181825";
        var fg = data.foreground || data.fg || "#cdd6f4";
        var accent = data.accent || "#89b4fa";
        var c0 = data.color0 || "#313244";
        var c8 = data.color8 || data.color0 || "#45475a";

        themeBg = bg;
        themeFg = fg;
        themeAccent = accent;
        themeBorder = c8;

        var lum = colorLuminance(bg);
        if (lum > 0.5) {
            themeBoardBg = Qt.darker(bg, 1.06);
            themeCardBg = Qt.darker(bg, 1.03);
            themeSubtext = Qt.rgba(Qt.color(fg).r, Qt.color(fg).g, Qt.color(fg).b, 0.65);
            themeBorder = c8 || Qt.darker(bg, 1.15);
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        } else {
            themeBoardBg = Qt.darker(bg, 1.25);
            themeCardBg = c0;
            themeSubtext = "#a6adc8";
            themeBorder = c8;
            themeBtnBg = accent;
            themeBtnFg = colorLuminance(accent) > 0.5 ? "#11111b" : "#ffffff";
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (typeof cityEngine !== "undefined" && cityEngine) {
            cityEngine.set_sound_muted(isMuted);
        }
        soundToast.show(isMuted ? "🔇 Audio Muted" : "🔊 Audio Enabled");
    }

    // =========================================================================
    // MAIN CONTAINER & KEYBOARD HANDLERS
    // =========================================================================
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.themeBg
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: function(event) {
            if (splashEnabled && splashScreen.visible && splashScreen.opacity > 0) {
                splashScreen.dismiss();
                event.accepted = true;
                return;
            }

            if (root.showHelp || root.showNewCityDialog) {
                if (event.key === Qt.Key_Escape) {
                    root.showHelp = false;
                    root.showNewCityDialog = false;
                    event.accepted = true;
                    return;
                }
            }

            // Classic SimCity Cheat Codes ('fund', 'buddamus')
            if (event.text && event.text.length > 0) {
                root.cheatBuffer += event.text.toLowerCase();
                if (root.cheatBuffer.length > 20) {
                    root.cheatBuffer = root.cheatBuffer.slice(-20);
                }

                // 1989 'fund' cheat (+$10,000; 4th abuse triggers an Earthquake penalty!)
                if (root.cheatBuffer.endsWith("fund")) {
                    root.fundCheatCount++;
                    if (root.fundCheatCount <= 3) {
                        cityEngine.add_funds(10000);
                        soundToast.show("💰 Cheat: +$10,000 Treasury! (" + root.fundCheatCount + "/4)");
                    } else {
                        cityEngine.add_funds(10000);
                        cityEngine.trigger_disaster(4); // Major Earthquake!
                        soundToast.show("💥 Greed Penalty: Major Earthquake!");
                        root.fundCheatCount = 0;
                    }
                    root.cheatBuffer = "";
                    event.accepted = true;
                    return;
                }

                // 'buddamus' cheat (+$500,000)
                if (root.cheatBuffer.endsWith("buddamus")) {
                    cityEngine.add_funds(500000);
                    soundToast.show("💰 Buddamus Cheat: +$500,000 Treasury!");
                    root.cheatBuffer = "";
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_M) {
                root.toggleMute();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) {
                root.showHelp = !root.showHelp;
                event.accepted = true;
                return;
            }

            // Speed shortcuts
            if (event.key === Qt.Key_Space) {
                var newSpd = (cityEngine.simSpeed === 0) ? 1 : 0;
                cityEngine.set_speed(newSpd);
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_1) {
                cityEngine.set_speed(1);
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_2) {
                cityEngine.set_speed(2);
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_3) {
                cityEngine.set_speed(3);
                event.accepted = true;
                return;
            }

            // Camera panning with WASD or Arrows
            var panStep = 32;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_H) {
                viewport.panBy(panStep, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_L) {
                viewport.panBy(-panStep, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.key === Qt.Key_K) {
                viewport.panBy(0, panStep);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S || event.key === Qt.Key_J) {
                viewport.panBy(0, -panStep);
                event.accepted = true;
            } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                viewport.zoomIn();
                event.accepted = true;
            } else if (event.key === Qt.Key_Minus) {
                viewport.zoomOut();
                event.accepted = true;
            }
        }

        // =====================================================================
        // ROW 1: HEADER ITEM (Title & Stat Cards)
        // =====================================================================
        Item {
            id: headerItem
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: Math.max(titleCol.implicitHeight, scoreRow.implicitHeight)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: scoreRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "ByteCity"
                    font.pixelSize: 24
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (cityEngine ? cityEngine.cityName : "Metropolis") + " • Classic Simulation"
                    font.pixelSize: 12
                    color: root.themeSubtext
                }
            }

            // Stat Cards on the right
            Row {
                id: scoreRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Treasury / Funds Card
                Rectangle {
                    width: Math.max(88, fundsText.implicitWidth + 20)
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "FUNDS"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            id: fundsText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "$" + (cityEngine ? Number(cityEngine.funds).toLocaleString() : "20,000")
                            font.pixelSize: 14
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: (cityEngine && cityEngine.funds < 500) ? "#ef4444" : "#10b981"
                        }
                    }
                }

                // Population Card
                Rectangle {
                    width: Math.max(84, popText.implicitWidth + 20)
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "POPULATION"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            id: popText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (cityEngine ? Number(cityEngine.population).toLocaleString() : "0")
                            font.pixelSize: 14
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeFg
                        }
                    }
                }

                // Date Card
                Rectangle {
                    width: Math.max(84, dateText.implicitWidth + 20)
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DATE"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Text {
                            id: dateText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cityEngine ? (cityEngine.monthName + " " + cityEngine.year) : "Jan 1900"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: root.monoFontFamily
                            color: root.themeAccent
                        }
                    }
                }

                // RCI Demand Gauge Card
                Rectangle {
                    width: 76
                    height: 44
                    radius: 8
                    color: root.themeCardBg
                    border.color: root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "R C I"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.themeSubtext
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            // R bar
                            Rectangle {
                                width: 8
                                height: 20
                                radius: 2
                                color: "#1e1e2e"
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, Math.min(20, (cityEngine ? (cityEngine.demandRes + 1.0) * 10 : 10)))
                                    color: "#22c55e"
                                    radius: 2
                                }
                            }
                            // C bar
                            Rectangle {
                                width: 8
                                height: 20
                                radius: 2
                                color: "#1e1e2e"
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, Math.min(20, (cityEngine ? (cityEngine.demandCom + 1.0) * 10 : 10)))
                                    color: "#3b82f6"
                                    radius: 2
                                }
                            }
                            // I bar
                            Rectangle {
                                width: 8
                                height: 20
                                radius: 2
                                color: "#1e1e2e"
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, Math.min(20, (cityEngine ? (cityEngine.demandInd + 1.0) * 10 : 10)))
                                    color: "#f59e0b"
                                    radius: 2
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: SUBHEADER ITEM (Speed & Utility Buttons)
        // =====================================================================
        Item {
            id: subheaderItem
            anchors.top: headerItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 32

            // Speed controls on left
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Pause (0)
                Rectangle {
                    width: 32; height: 28; radius: 6
                    color: (cityEngine && cityEngine.simSpeed === 0) ? root.themeAccent : root.themeCardBg
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "⏸"
                        font.pixelSize: 11
                        color: (cityEngine && cityEngine.simSpeed === 0) ? root.themeBtnFg : root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: cityEngine.set_speed(0)
                    }
                }

                // Normal (1)
                Rectangle {
                    width: 32; height: 28; radius: 6
                    color: (cityEngine && cityEngine.simSpeed === 1) ? root.themeAccent : root.themeCardBg
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        font.pixelSize: 11
                        color: (cityEngine && cityEngine.simSpeed === 1) ? root.themeBtnFg : root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: cityEngine.set_speed(1)
                    }
                }

                // Fast (2)
                Rectangle {
                    width: 32; height: 28; radius: 6
                    color: (cityEngine && cityEngine.simSpeed === 2) ? root.themeAccent : root.themeCardBg
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "▶▶"
                        font.pixelSize: 10
                        color: (cityEngine && cityEngine.simSpeed === 2) ? root.themeBtnFg : root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: cityEngine.set_speed(2)
                    }
                }

                // Ultra (3)
                Rectangle {
                    width: 36; height: 28; radius: 6
                    color: (cityEngine && cityEngine.simSpeed === 3) ? root.themeAccent : root.themeCardBg
                    border.color: root.themeBorder; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "▶▶▶"
                        font.pixelSize: 9
                        color: (cityEngine && cityEngine.simSpeed === 3) ? root.themeBtnFg : root.themeFg
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: cityEngine.set_speed(3)
                    }
                }
            }

            // Utilities on right (Zoom, Reset View, Mute, Help, New City)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Zoom Out
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 14; font.bold: true; color: root.themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: viewport.zoomOut() }
                }

                // Zoom In
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 14; font.bold: true; color: root.themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: viewport.zoomIn() }
                }

                // Reset Camera Center
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Text { anchors.centerIn: parent; text: "⌖"; font.pixelSize: 13; color: root.themeFg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: viewport.resetView() }
                }

                // Mute
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: root.themeCardBg; border.color: root.isMuted ? root.themeBorder : root.themeAccent; border.width: 1
                    Text { anchors.centerIn: parent; text: root.isMuted ? "🔇" : "🔊"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute() }
                }

                // Help
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Text { anchors.centerIn: parent; text: "?"; font.pixelSize: 13; font.bold: true; color: root.themeAccent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showHelp = !root.showHelp }
                }

                // New City
                Rectangle {
                    height: 28; width: 84; radius: 6
                    color: root.themeAccent
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🔄"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "New City"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showNewCityDialog = true
                    }
                }
            }
        }

        // =====================================================================
        // ROW 3: PLAYFIELD CONTAINER (Tool Palette & 2D Viewport)
        // =====================================================================
        Item {
            id: playArea
            anchors.top: subheaderItem.bottom
            anchors.topMargin: 8
            anchors.bottom: statusBar.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // Left Tool Palette Dock
            Rectangle {
                id: toolPalette
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 60
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 10
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: toolCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: toolCol
                        width: parent.width
                        spacing: 4

                        // Helper component for tool buttons
                        Component {
                            id: toolButtonComp
                            Rectangle {
                                id: tBtn
                                width: parent.width
                                height: 38
                                radius: 6
                                color: (root.currentTool === modelData.id) ? root.themeAccent : (tMouse.containsMouse ? root.themeBoardBg : "transparent")
                                border.color: (root.currentTool === modelData.id) ? root.themeAccent : "transparent"
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: (root.currentTool === modelData.id) ? root.themeBtnFg : root.themeSubtext
                                    }
                                }

                                MouseArea {
                                    id: tMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentTool = modelData.id;
                                        soundToast.show(modelData.label + " selected (" + modelData.cost + ")");
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { id: -1, icon: "✋", label: "Pan", cost: "Free" },
                                { id: 7, icon: "🚜", label: "Doze", cost: "$1" },
                                { id: 9, icon: "🛣️", label: "Road", cost: "$10" },
                                { id: 6, icon: "⚡", label: "Wire", cost: "$5" },
                                { id: 8, icon: "🚆", label: "Rail", cost: "$20" },
                                { id: 0, icon: "🟢", label: "Res", cost: "$100" },
                                { id: 1, icon: "🔵", label: "Com", cost: "$100" },
                                { id: 2, icon: "🟡", label: "Ind", cost: "$100" },
                                { id: 13, icon: "🏭", label: "Coal", cost: "$3,000" },
                                { id: 14, icon: "☢️", label: "Nuke", cost: "$5,000" },
                                { id: 4, icon: "👮", label: "Police", cost: "$500" },
                                { id: 3, icon: "🚒", label: "Fire", cost: "$500" },
                                { id: 11, icon: "🌲", label: "Park", cost: "$10" },
                                { id: 10, icon: "🏟️", label: "Stad", cost: "$5,000" },
                                { id: 12, icon: "⚓", label: "Port", cost: "$3,000" },
                                { id: 15, icon: "✈️", label: "Air", cost: "$10,000" }
                            ]
                            delegate: toolButtonComp
                        }
                    }
                }
            }

            // Main 2D Viewport Container
            Rectangle {
                id: viewportContainer
                anchors.left: toolPalette.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: root.themeBoardBg
                border.color: root.themeBorder
                border.width: 1
                radius: 10
                clip: true

                CityViewport {
                    id: viewport
                    anchors.fill: parent
                    cityEngine: (typeof cityEngine !== "undefined") ? cityEngine : null
                    activeTool: root.currentTool
                }
            }
        }

        // =====================================================================
        // ROW 4: STATUS BAR & ADVISOR BANNER
        // =====================================================================
        Rectangle {
            id: statusBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 28
            radius: 6
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "📰"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: advisorText
                    anchors.verticalCenter: parent.verticalCenter
                    text: cityEngine ? cityEngine.advisorMessage : "Welcome to ByteCity! Build roads, power, and zones."
                    font.pixelSize: 11
                    color: root.themeFg
                    elide: Text.ElideRight
                    width: parent.width - 240
                }

                Item { width: 20; height: 1 }

                // Hover Coordinate Display
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (viewport && viewport.hoverX >= 0 && viewport.hoverY >= 0) ? ("Tile: (" + viewport.hoverX + ", " + viewport.hoverY + ")") : "Grid: 120×100"
                    font.pixelSize: 10
                    font.family: root.monoFontFamily
                    color: root.themeSubtext
                }
            }
        }

        // =====================================================================
        // NEW CITY DIALOG MODAL
        // =====================================================================
        Rectangle {
            id: newCityModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.7)
            visible: root.showNewCityDialog
            z: 90

            MouseArea { anchors.fill: parent; onClicked: {} } // Block clicks

            Rectangle {
                anchors.centerIn: parent
                width: 380
                height: 280
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Text {
                        text: "Inaugurate New City"
                        font.pixelSize: 18
                        font.bold: true
                        color: root.themeAccent
                    }

                    // City Name Input
                    Column {
                        width: parent.width
                        spacing: 4
                        Text { text: "City Name:"; font.pixelSize: 11; color: root.themeSubtext }
                        Rectangle {
                            width: parent.width; height: 32; radius: 6
                            color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            TextInput {
                                id: cityNameInput
                                anchors.fill: parent; anchors.margins: 6
                                text: "ByteCity"
                                font.pixelSize: 13; color: root.themeFg
                            }
                        }
                    }

                    // Difficulty Level
                    Column {
                        width: parent.width
                        spacing: 4
                        Text { text: "Difficulty / Starting Funds:"; font.pixelSize: 11; color: root.themeSubtext }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [
                                    { level: 0, label: "Easy ($20k)" },
                                    { level: 1, label: "Medium ($10k)" },
                                    { level: 2, label: "Hard ($5k)" }
                                ]
                                Rectangle {
                                    width: 104; height: 28; radius: 6
                                    property int lvl: modelData.level
                                    color: (newCityModal.selectedLevel === lvl) ? root.themeAccent : root.themeBoardBg
                                    border.color: root.themeBorder; border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: (newCityModal.selectedLevel === lvl) ? root.themeBtnFg : root.themeFg
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: newCityModal.selectedLevel = lvl
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 8 }

                    // Action Buttons
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 100; height: 32; radius: 6
                            color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: root.themeFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showNewCityDialog = false
                            }
                        }

                        Rectangle {
                            width: 120; height: 32; radius: 6
                            color: root.themeAccent
                            Text { anchors.centerIn: parent; text: "Start City"; font.pixelSize: 12; font.bold: true; color: root.themeBtnFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var seed = Math.floor(Math.random() * 10000);
                                    cityEngine.start_new_city(cityNameInput.text, newCityModal.selectedLevel, seed);
                                    viewport.resetView();
                                    root.showNewCityDialog = false;
                                }
                            }
                        }
                    }
                }
                property int selectedLevel: 0
            }
        }

        // =====================================================================
        // HELP OVERLAY MODAL
        // =====================================================================
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.7)
            visible: root.showHelp
            z: 95

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(480, parent.width - 40)
                height: 380
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Row {
                        width: parent.width
                        Text {
                            text: "ByteCity • Mayor's Handbook"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeAccent
                        }
                        Item { width: 20; height: 1 }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.helpText
                        font.pixelSize: 12
                        lineHeight: 1.4
                        color: root.themeFg
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "💡 Pro-Tip: Zones must be connected to power and roads to develop. Keep industrial zones away from residential areas to minimize pollution!"
                        font.pixelSize: 11
                        color: root.themeSubtext
                    }

                    Item { height: 10 }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 100; height: 32; radius: 6
                        color: root.themeAccent
                        Text { anchors.centerIn: parent; text: "Got It"; font.pixelSize: 12; font.bold: true; color: root.themeBtnFg }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }
                }
            }
        }

        // =====================================================================
        // NOTIFICATION TOAST
        // =====================================================================
        Rectangle {
            id: soundToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: statusBar.top
            anchors.bottomMargin: 16
            height: 32
            width: toastLabel.implicitWidth + 28
            radius: 8
            color: root.themeCardBg
            border.color: root.themeAccent
            border.width: 1
            opacity: 0
            z: 80

            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                id: toastLabel
                anchors.centerIn: parent
                font.pixelSize: 11
                font.bold: true
                color: root.themeFg
            }

            Timer {
                id: toastTimer
                interval: 1800
                onTriggered: soundToast.opacity = 0
            }

            function show(msg) {
                toastLabel.text = msg;
                soundToast.opacity = 1;
                toastTimer.restart();
            }
        }
    }

    // =========================================================================
    // CANONICAL OMARCHY ARCADE SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: root.splashEnabled && opacity > 0
        z: 1000
    }
}
