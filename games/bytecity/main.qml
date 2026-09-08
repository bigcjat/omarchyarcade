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
    title: "OmarchyCity • Classic Metropolis Simulation"

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
    property bool showInaugurationModal: true
    property bool showAdvisorModal: false
    property int selectedSetupTab: 0
    property int currentSeed: 42
    property int selectedLevel: 0
    property int currentTool: 9
    property string cheatBuffer: ""
    property int fundCheatCount: 0
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Pan View: Drag with Right/Middle Mouse, Shift + Trackpad Scroll, or WASD / Arrows\n• Zoom View: Mouse Wheel or + / -\n• Build: Left-click with active tool (Road, Wire, Rail, Bulldozer support drag)\n• Speed: Space (Pause), 1 (Normal), 2 (Fast), 3 (Ultra)\n• Sound: M | Help: ? or Esc\n• Advisor: Click Dr. Wright in the bottom status bar for municipal counsel!\n\nBuild power plants, connect roads and wires, and balance Residential, Commercial, and Industrial zones to grow your metropolis!"

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

            if (root.showHelp || root.showAdvisorModal) {
                if (event.key === Qt.Key_Escape) {
                    root.showHelp = false;
                    root.showAdvisorModal = false;
                    event.accepted = true;
                    return;
                }
            }

            if (root.showInaugurationModal) {
                if (event.key === Qt.Key_Escape) {
                    root.showInaugurationModal = false;
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
                    text: "OmarchyCity"
                    font.pixelSize: 24
                    font.bold: true
                    color: root.themeAccent
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (cityEngine ? cityEngine.cityName : "OmarchyCity") + " • Classic Simulation"
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

                // Advisor Button
                Rectangle {
                    height: 28; width: 84; radius: 6
                    color: root.themeCardBg; border.color: root.themeAccent; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Image {
                            source: "assets/dr_wright.svg"
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }
                        Text { text: "Advisor"; font.pixelSize: 11; font.bold: true; color: root.themeAccent; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAdvisorModal = true
                    }
                }

                // Scenarios Button
                Rectangle {
                    height: 28; width: 90; radius: 6
                    color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "📜"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Scenarios"; font.pixelSize: 11; font.bold: true; color: root.themeFg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedSetupTab = 1;
                            root.showInaugurationModal = true;
                        }
                    }
                }

                // New City
                Rectangle {
                    height: 28; width: 90; radius: 6
                    color: root.themeAccent
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🏛️"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "New City"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedSetupTab = 0;
                            root.showInaugurationModal = true;
                        }
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
            height: 32
            radius: 6
            color: root.themeCardBg
            border.color: root.themeBorder
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: 8

                // Dr. Wright interactive avatar badge
                Rectangle {
                    id: drWrightStatusBadge
                    height: 24
                    width: drWrightStatusRow.implicitWidth + 14
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: drWrightStatusMouse.containsMouse ? root.themeAccent : Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.15)
                    border.color: root.themeAccent
                    border.width: 1

                    Row {
                        id: drWrightStatusRow
                        anchors.centerIn: parent
                        spacing: 4
                        Image {
                            source: "assets/dr_wright.svg"
                            width: 18; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }
                        Text {
                            text: "Dr. Wright"
                            font.pixelSize: 10
                            font.bold: true
                            color: drWrightStatusMouse.containsMouse ? root.themeBtnFg : root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: drWrightStatusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAdvisorModal = true
                    }
                }

                Text {
                    id: advisorText
                    anchors.verticalCenter: parent.verticalCenter
                    text: cityEngine ? cityEngine.advisorMessage : "Welcome to OmarchyCity! Click Dr. Wright or build zones to begin."
                    font.pixelSize: 11
                    color: root.themeFg
                    elide: Text.ElideRight
                    width: Math.max(100, parent.width - drWrightStatusBadge.width - 240)
                }

                Item { width: 10; height: 1 }

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
        // MAYORAL INAUGURATION & SETUP WIZARD (Dr. Wright)
        // =====================================================================
        Rectangle {
            id: inaugurationModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showInaugurationModal
            z: 90

            MouseArea { anchors.fill: parent; onClicked: {} } // Block clicks through scrim

            Rectangle {
                id: modalBox
                anchors.centerIn: parent
                width: Math.min(620, parent.width - 24)
                height: Math.min(520, parent.height - 24)
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Modal Header
                    Row {
                        width: parent.width
                        spacing: 12

                        Image {
                            source: "assets/dr_wright.svg"
                            width: 36
                            height: 36
                            smooth: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 80

                            Text {
                                text: "Mayoral Inauguration Chamber"
                                font.pixelSize: 17
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                text: "Executive Municipal Administration • OmarchyCity"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: closeMouse.containsMouse ? root.themeBorder : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 12
                                color: root.themeSubtext
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showInaugurationModal = false
                            }
                        }
                    }

                    // Tab Selector Bar
                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                { idx: 0, label: "🏛️ New Territory" },
                                { idx: 1, label: "📜 Historic Scenarios (8)" },
                                { idx: 2, label: "💡 Dr. Wright's Briefing" }
                            ]
                            Rectangle {
                                width: (modalBox.width - 32 - 12) / 3
                                height: 30
                                radius: 6
                                color: (root.selectedSetupTab === modelData.idx) ? root.themeAccent : root.themeBoardBg
                                border.color: (root.selectedSetupTab === modelData.idx) ? root.themeAccent : root.themeBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 11
                                    font.bold: root.selectedSetupTab === modelData.idx
                                    color: (root.selectedSetupTab === modelData.idx) ? root.themeBtnFg : root.themeFg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedSetupTab = modelData.idx
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // TAB 0: NEW TERRITORY
                    Item {
                        id: tabNewCity
                        width: parent.width
                        height: parent.height - 130
                        visible: root.selectedSetupTab === 0

                        Column {
                            anchors.fill: parent
                            spacing: 10

                            // Speech Bubble from Dr. Wright
                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: 8
                                color: root.themeBoardBg
                                border.color: root.themeBorder
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: "🗣️"
                                        font.pixelSize: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        width: parent.width - 36
                                        wrapMode: Text.Wrap
                                        text: "Greetings, your Honor! I am Dr. Wright, your Senior Advisor. Name your city, allocate our starting funds, and prepare to govern!"
                                        font.pixelSize: 11
                                        color: root.themeFg
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // City Name Input
                            Column {
                                width: parent.width
                                spacing: 4
                                Text { text: "City Name:"; font.pixelSize: 11; font.bold: true; color: root.themeSubtext }
                                Rectangle {
                                    width: parent.width; height: 32; radius: 6
                                    color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                                    TextInput {
                                        id: inaugCityNameInput
                                        anchors.fill: parent; anchors.margins: 6
                                        text: "OmarchyCity"
                                        font.pixelSize: 13; color: root.themeFg
                                    }
                                }
                            }

                            // Difficulty Level / Starting Treasury
                            Column {
                                width: parent.width
                                spacing: 4
                                Text { text: "Starting Municipal Treasury & Difficulty:"; font.pixelSize: 11; font.bold: true; color: root.themeSubtext }
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { level: 0, title: "Easy", funds: "$20,000", desc: "Ambitious Expansion" },
                                            { level: 1, title: "Medium", funds: "$10,000", desc: "Balanced Economy" },
                                            { level: 2, title: "Hard", funds: "$5,000", desc: "Fiscal Austerity" }
                                        ]
                                        Rectangle {
                                            width: (parent.width - 16) / 3
                                            height: 52
                                            radius: 8
                                            property int lvl: modelData.level
                                            color: (root.selectedLevel === lvl) ? Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.2) : root.themeBoardBg
                                            border.color: (root.selectedLevel === lvl) ? root.themeAccent : root.themeBorder
                                            border.width: (root.selectedLevel === lvl) ? 2 : 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.title + " (" + modelData.funds + ")"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: (root.selectedLevel === lvl) ? root.themeAccent : root.themeFg
                                                }
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.desc
                                                    font.pixelSize: 9
                                                    color: root.themeSubtext
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedLevel = lvl
                                            }
                                        }
                                    }
                                }
                            }

                            // Map Seed Rerolling
                            Column {
                                width: parent.width
                                spacing: 4
                                Text { text: "Geographic Territory Map Seed:"; font.pixelSize: 11; font.bold: true; color: root.themeSubtext }
                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Rectangle {
                                        width: parent.width - 140
                                        height: 32
                                        radius: 6
                                        color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text { text: "🗺️ Territory Seed:"; font.pixelSize: 11; color: root.themeSubtext }
                                            Text { text: "#" + root.currentSeed; font.pixelSize: 12; font.bold: true; font.family: root.monoFontFamily; color: root.themeAccent }
                                        }
                                    }

                                    Rectangle {
                                        width: 132
                                        height: 32
                                        radius: 6
                                        color: root.themeCardBg; border.color: root.themeBorder; border.width: 1
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "🎲"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: "Reroll Seed"; font.pixelSize: 11; font.bold: true; color: root.themeFg; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.currentSeed = Math.floor(Math.random() * 90000) + 1000;
                                                cityEngine.generate_new_city(root.currentSeed);
                                                viewport.resetView();
                                                soundToast.show("🎲 Rerolled Territory: Seed #" + root.currentSeed);
                                            }
                                        }
                                    }
                                }
                            }

                            Item { height: 4 }

                            // Action Buttons
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                Rectangle {
                                    width: 120; height: 36; radius: 8
                                    color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                                    Text { anchors.centerIn: parent; text: "⚡ Quick Play"; font.pixelSize: 12; color: root.themeFg }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cityEngine.start_new_city("OmarchyCity", 0, 42);
                                            viewport.resetView();
                                            root.showInaugurationModal = false;
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 220; height: 36; radius: 8
                                    color: root.themeAccent
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "✂️"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Inaugurate Metropolis"; font.pixelSize: 12; font.bold: true; color: root.themeBtnFg; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cname = (inaugCityNameInput.text.trim().length > 0) ? inaugCityNameInput.text.trim() : "OmarchyCity";
                                            cityEngine.start_new_city(cname, root.selectedLevel, root.currentSeed);
                                            viewport.resetView();
                                            root.showInaugurationModal = false;
                                            soundToast.show("🏛️ " + cname + " Inaugurated!");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 1: HISTORIC MAXIS SCENARIOS
                    Item {
                        id: tabScenarios
                        width: parent.width
                        height: parent.height - 130
                        visible: root.selectedSetupTab === 1

                        Column {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "Select a historic Maxis crisis to test your emergency leadership, Mayor!"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }

                            Flickable {
                                width: parent.width
                                height: parent.height - 24
                                contentHeight: scenarioGrid.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Grid {
                                    id: scenarioGrid
                                    columns: 2
                                    spacing: 8
                                    width: parent.width

                                    Repeater {
                                        model: [
                                            { id: "san_francisco", name: "San Francisco", year: "1906", icon: "🌊", desc: "Major Earthquake & Firestorm" },
                                            { id: "tokyo", name: "Tokyo", year: "1961", icon: "💥", desc: "Monster Attack & Coastal Devastation" },
                                            { id: "dullsville", name: "Dullsville", year: "1910", icon: "😴", desc: "Economic Stagnation & Apathy" },
                                            { id: "bern", name: "Bern", year: "1965", icon: "🚦", desc: "Total Traffic Gridlock Congestion" },
                                            { id: "detroit", name: "Detroit", year: "1972", icon: "🏭", desc: "Industrial Crime Wave & Civil Decay" },
                                            { id: "hamburg", name: "Hamburg", year: "1944", icon: "☢️", desc: "Firebombing Reconstruction" },
                                            { id: "boston", name: "Boston", year: "2010", icon: "💣", desc: "Nuclear Meltdown Crisis" },
                                            { id: "rio", name: "Rio de Janeiro", year: "2047", icon: "🌊", desc: "Coastal Sea-Level Flooding" }
                                        ]

                                        Rectangle {
                                            width: (scenarioGrid.width - 8) / 2
                                            height: 54
                                            radius: 8
                                            color: scenMouse.containsMouse ? Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.2) : root.themeBoardBg
                                            border.color: scenMouse.containsMouse ? root.themeAccent : root.themeBorder
                                            border.width: 1

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                Text {
                                                    text: modelData.icon
                                                    font.pixelSize: 22
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 40
                                                    spacing: 2

                                                    Row {
                                                        spacing: 4
                                                        Text {
                                                            text: modelData.name
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            color: root.themeFg
                                                        }
                                                        Text {
                                                            text: "(" + modelData.year + ")"
                                                            font.pixelSize: 10
                                                            color: root.themeAccent
                                                        }
                                                    }
                                                    Text {
                                                        text: modelData.desc
                                                        font.pixelSize: 9
                                                        color: root.themeSubtext
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: scenMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    cityEngine.load_scenario(modelData.id);
                                                    viewport.resetView();
                                                    root.showInaugurationModal = false;
                                                    soundToast.show("📜 Loaded " + modelData.name + " (" + modelData.year + ")");
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 2: DR. WRIGHT'S BRIEFING
                    Item {
                        id: tabBriefing
                        width: parent.width
                        height: parent.height - 130
                        visible: root.selectedSetupTab === 2

                        Flickable {
                            anchors.fill: parent
                            contentHeight: briefingCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: briefingCol
                                width: parent.width
                                spacing: 10

                                Row {
                                    spacing: 12
                                    width: parent.width
                                    Image {
                                        source: "assets/dr_wright.svg"
                                        width: 54
                                        height: 54
                                        smooth: true
                                    }
                                    Rectangle {
                                        width: parent.width - 66
                                        height: 54
                                        radius: 8
                                        color: root.themeBoardBg
                                        border.color: root.themeBorder
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            wrapMode: Text.Wrap
                                            text: "\"Listen closely, Mayor! A thriving city requires foresight, zone balance, and steady municipal power. Here are my top principles for governing OmarchyCity:\""
                                            font.pixelSize: 11
                                            font.italic: true
                                            color: root.themeFg
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: briefingGrid.implicitHeight + 16
                                    radius: 8
                                    color: root.themeBoardBg
                                    border.color: root.themeBorder
                                    border.width: 1

                                    Column {
                                        id: briefingGrid
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "1. ⚡ Power Grids: Zones require continuous power to develop. Build Coal or Nuclear plants and connect wires. Unpowered buildings flash ⚡."
                                            font.pixelSize: 11; color: root.themeFg
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "2. 🚗 Transportation: Every zone needs road access to connect workers to jobs. Connect roads into networks to avoid traffic bottlenecks."
                                            font.pixelSize: 11; color: root.themeFg
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "3. ⚖️ Zone Balance: Keep R, C, and I balanced. Residential houses citizens, Commercial provides commerce, and Industrial creates goods."
                                            font.pixelSize: 11; color: root.themeFg
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "4. 🛡️ Municipal Services: Police stations curb crime, and Fire stations protect against blazes. Keep dirty Industry away from leafy homes!"
                                            font.pixelSize: 11; color: root.themeFg
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "5. 💰 Treasury & Taxes: Taxes are collected every December. Keep taxes around 6-8% to encourage steady population influx."
                                            font.pixelSize: 11; color: root.themeFg
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 160; height: 34; radius: 8
                                    color: root.themeAccent
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🏛️ Ready to Govern"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: root.themeBtnFg
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedSetupTab = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // DR. WRIGHT ADVISOR CONSULTATION MODAL
        // =====================================================================
        Rectangle {
            id: advisorModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showAdvisorModal
            z: 92

            MouseArea {
                anchors.fill: parent
                onClicked: root.showAdvisorModal = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(500, parent.width - 32)
                height: 380
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                MouseArea { anchors.fill: parent; onClicked: {} } // Block click inside dialog

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Advisor Header
                    Row {
                        width: parent.width
                        spacing: 12

                        Image {
                            source: "assets/dr_wright.svg"
                            width: 52
                            height: 52
                            smooth: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 96

                            Text {
                                text: "Dr. Wright"
                                font.pixelSize: 18
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                text: "Senior Municipal Advisor & City Planner"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: advCloseMouse.containsMouse ? root.themeBorder : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 12
                                color: root.themeSubtext
                            }
                            MouseArea {
                                id: advCloseMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAdvisorModal = false
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // Advisor Dynamic Speech Box
                    Rectangle {
                        width: parent.width
                        height: 90
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            lineHeight: 1.3
                            color: root.themeFg
                            text: {
                                if (!cityEngine) return "Welcome to OmarchyCity, your Honor!";
                                if (cityEngine.population === 0) return "Our territory is untouched virgin wilderness! Begin by constructing a power plant, zoning residential, commercial, and industrial plots, and connecting them with roads!";
                                if (cityEngine.funds < 1500) return "Warning, Mayor! Our city treasury is running critically low ($" + cityEngine.funds.toLocaleString() + "). Consider adjusting taxes or holding off on large infrastructure!";
                                if (cityEngine.demandRes > 0.4) return "Citizens are flocking to our borders! Demand for Residential housing is soaring—zone more residential neighborhoods immediately!";
                                if (cityEngine.demandCom > 0.4) return "Commercial enterprise is booming! Local businesses need more Commercial zoning near active thoroughfares!";
                                if (cityEngine.demandInd > 0.4) return "Factory owners and manufacturers are requesting land! Expand Industrial zoning near railway corridors.";
                                return cityEngine.advisorMessage || "OmarchyCity is running smoothly, Mayor! Keep maintaining power networks and monitoring zone demands!";
                            }
                        }
                    }

                    // Municipal Status 4-Card Grid
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 8

                        // Approval Rating
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 48
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "Public Approval"; font.pixelSize: 10; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: (cityEngine ? cityEngine.approvalRating : 75) + "%"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#22c55e"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Population
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 48
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "City Population"; font.pixelSize: 10; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: (cityEngine ? cityEngine.population.toLocaleString() : "0") + " citizens"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.themeAccent
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Treasury
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 48
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "City Treasury"; font.pixelSize: 10; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: "$" + (cityEngine ? cityEngine.funds.toLocaleString() : "20,000")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#eab308"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Tax Rate
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 48
                            radius: 6
                            color: root.themeBoardBg
                            border.color: root.themeBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "Annual Tax Rate"; font.pixelSize: 10; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: (cityEngine ? cityEngine.taxRate : 7) + "%"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.themeFg
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    Item { height: 4 }

                    // Action Buttons
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 140; height: 32; radius: 6
                            color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Text { anchors.centerIn: parent; text: "🏛️ Setup / Scenarios"; font.pixelSize: 11; color: root.themeFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showAdvisorModal = false;
                                    root.showInaugurationModal = true;
                                }
                            }
                        }

                        Rectangle {
                            width: 130; height: 32; radius: 6
                            color: root.themeAccent
                            Text { anchors.centerIn: parent; text: "Dismiss Advisor"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAdvisorModal = false
                            }
                        }
                    }
                }
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
                            text: "OmarchyCity • Mayor's Handbook"
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
