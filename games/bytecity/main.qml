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
    property bool showGraphModal: false
    property bool showAdvisorModal: false
    property bool showBudgetModal: false
    property bool showDisasterModal: false
    property bool showInspectorCard: false
    property var inspectedData: null
    property bool showMilestoneModal: false
    property string milestoneTitle: ""
    property string milestoneReward: ""
    property int milestonePop: 0
    property bool showGameOverModal: false
    property string gameOverReason: ""
    property int currentOverlay: 0
    property var budgetData: null
    property int budgetTaxRate: 7
    property real budgetRoadPct: 1.0
    property real budgetPolicePct: 1.0
    property real budgetFirePct: 1.0
    property bool budgetAuto: false
    property var urgentAlert: null
    property bool showUrgentAlert: false
    property int selectedSetupTab: 0
    property int currentSeed: 42
    property int selectedLevel: 0
    property int currentTool: 9
    property string cheatBuffer: ""
    property int fundCheatCount: 0
    property string monoFontFamily: (Qt.platform.os === "osx") ? "Menlo" : "JetBrainsMono Nerd Font"

    property string helpText: "• Pan View: Drag with Right/Middle Mouse, Shift + Trackpad Scroll, or WASD / Arrows\n• Zoom View: Mouse Wheel or + / -\n• Build: Left-click with active tool (Road, Wire, Rail, Bulldozer support drag)\n• Speed: Space (Pause), 1 (Normal), 2 (Fast), 3 (Ultra)\n• Sound: M | Help: ? or Esc\n• Advisor: Click Dr. DHH in the bottom status bar for municipal counsel!\n• Graphs: Click the RCI Demand Gauge or Graphs button to view 10-Yr & 120-Yr census data!\n\nBuild power plants, connect roads and wires, and balance Residential, Commercial, and Industrial zones to grow your metropolis!"

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

        Connections {
            target: (typeof cityEngine !== "undefined") ? cityEngine : null

            function onBudgetRequired(tf, rf, rs, pf, ps, ff, fs) {
                root.budgetData = cityEngine.get_budget_details();
                root.budgetTaxRate = cityEngine.taxRate;
                root.budgetAuto = cityEngine.autoBudget;
                root.budgetRoadPct = (rf > 0) ? Math.min(1.0, rs / rf) : 1.0;
                root.budgetPolicePct = (pf > 0) ? Math.min(1.0, ps / pf) : 1.0;
                root.budgetFirePct = (ff > 0) ? Math.min(1.0, fs / ff) : 1.0;
                root.showBudgetModal = true;
            }

            function onDhhAlert(type, title, msg, urgency) {
                root.urgentAlert = {
                    type: type,
                    title: title,
                    message: msg,
                    urgency: urgency
                };
                root.showUrgentAlert = true;
                urgentAlertTimer.restart();
            }

            function onMilestoneReached(pop, title, reward) {
                root.milestonePop = pop;
                root.milestoneTitle = title;
                root.milestoneReward = reward;
                root.showMilestoneModal = true;
            }

            function onGameOver(reason) {
                root.gameOverReason = reason;
                root.showGameOverModal = true;
            }

            function onTileQueried(data) {
                root.inspectedData = data;
                root.showInspectorCard = true;
            }
        }

        Timer {
            id: urgentAlertTimer
            interval: 9000
            onTriggered: root.showUrgentAlert = false
        }

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

                // RCI Demand Gauge Card (Clickable to open City History & Demographic Graphs)
                Rectangle {
                    id: rciCard
                    width: 76
                    height: 44
                    radius: 8
                    color: rciMouseArea.containsMouse ? Qt.lighter(root.themeCardBg, 1.1) : root.themeCardBg
                    border.color: rciMouseArea.containsMouse ? root.themeAccent : root.themeBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "R C I"
                            font.pixelSize: 9
                            font.bold: true
                            color: rciMouseArea.containsMouse ? root.themeAccent : root.themeSubtext
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

                    MouseArea {
                        id: rciMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showGraphModal = !root.showGraphModal
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
                            source: "assets/dr_dhh.svg"
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

                // City Graphs Button (Classic SimCity 10 & 120 Year Census)
                Rectangle {
                    height: 28; width: 82; radius: 6
                    color: root.showGraphModal ? root.themeAccent : root.themeCardBg
                    border.color: root.showGraphModal ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "📈"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "Graphs";
                            font.pixelSize: 11;
                            font.bold: true;
                            color: root.showGraphModal ? root.themeBtnFg : root.themeFg;
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showGraphModal = !root.showGraphModal
                    }
                }

                // Budget & Financial Audit Button
                Rectangle {
                    height: 28; width: 80; radius: 6
                    color: root.showBudgetModal ? root.themeAccent : root.themeCardBg
                    border.color: root.showBudgetModal ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🏛️"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "Budget"
                            font.pixelSize: 11; font.bold: true
                            color: root.showBudgetModal ? root.themeBtnFg : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof cityEngine !== "undefined" && cityEngine) {
                                root.budgetData = cityEngine.get_budget_details();
                                root.budgetTaxRate = cityEngine.taxRate;
                                root.budgetAuto = cityEngine.autoBudget;
                                if (root.budgetData) {
                                    var rf = root.budgetData.road_fund || 0;
                                    var rs = root.budgetData.road_spend || 0;
                                    root.budgetRoadPct = (rf > 0) ? Math.min(1.0, rs / rf) : 1.0;
                                    var pf = root.budgetData.police_fund || 0;
                                    var ps = root.budgetData.police_spend || 0;
                                    root.budgetPolicePct = (pf > 0) ? Math.min(1.0, ps / pf) : 1.0;
                                    var ff = root.budgetData.fire_fund || 0;
                                    var fs = root.budgetData.fire_spend || 0;
                                    root.budgetFirePct = (ff > 0) ? Math.min(1.0, fs / ff) : 1.0;
                                }
                            }
                            root.showBudgetModal = true;
                        }
                    }
                }

                // Emergency Disasters Control Button
                Rectangle {
                    height: 28; width: 90; radius: 6
                    color: root.showDisasterModal ? root.themeAccent : root.themeCardBg
                    border.color: root.showDisasterModal ? root.themeAccent : root.themeBorder
                    border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🌪️"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "Disasters"
                            font.pixelSize: 11; font.bold: true
                            color: root.showDisasterModal ? root.themeBtnFg : root.themeFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showDisasterModal = !root.showDisasterModal
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
                                { id: 5, icon: "❓", label: "Query", cost: "Inspect" },
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
                    overlayMode: root.currentOverlay
                }

                // Overlay Selector Bar
                Rectangle {
                    id: overlayBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 10
                    height: 28
                    width: overlayRow.implicitWidth + 12
                    radius: 7
                    color: Qt.rgba(Qt.color(root.themeCardBg).r, Qt.color(root.themeCardBg).g, Qt.color(root.themeCardBg).b, 0.88)
                    border.color: root.themeBorder
                    border.width: 1
                    z: 30

                    Row {
                        id: overlayRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: [
                                { mode: 0, label: "🏙️ Normal" },
                                { mode: 1, label: "⚡ Power" },
                                { mode: 2, label: "🟣 Smog" },
                                { mode: 3, label: "🔴 Crime" },
                                { mode: 4, label: "🟢 Value" },
                                { mode: 5, label: "🚗 Traffic" }
                            ]
                            delegate: Rectangle {
                                width: oText.implicitWidth + 14
                                height: 20
                                radius: 5
                                color: (root.currentOverlay === modelData.mode) ? root.themeAccent : (oMouse.containsMouse ? root.themeBoardBg : "transparent")
                                border.color: (root.currentOverlay === modelData.mode) ? root.themeAccent : "transparent"
                                border.width: 1

                                Text {
                                    id: oText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 10
                                    font.bold: root.currentOverlay === modelData.mode
                                    color: (root.currentOverlay === modelData.mode) ? root.themeBtnFg : root.themeFg
                                }

                                MouseArea {
                                    id: oMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentOverlay = modelData.mode;
                                        if (typeof cityEngine !== "undefined" && cityEngine) {
                                            cityEngine.set_overlay_mode(modelData.mode);
                                        }
                                        soundToast.show("Layer: " + modelData.label);
                                    }
                                }
                            }
                        }
                    }
                }

                // Dr. DHH Proactive Urgent Alert Toast Card
                Rectangle {
                    id: urgentAlertCard
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: Math.min(340, parent.width - 20)
                    height: urgentCol.implicitHeight + 20
                    radius: 10
                    color: Qt.rgba(Qt.color(root.themeCardBg).r, Qt.color(root.themeCardBg).g, Qt.color(root.themeCardBg).b, 0.96)
                    border.color: {
                        if (!root.urgentAlert) return root.themeAccent;
                        if (root.urgentAlert.urgency === 3) return "#f38ba8"; // Danger / Disaster
                        if (root.urgentAlert.urgency === 2) return "#fab387"; // Warning
                        return root.themeAccent;
                    }
                    border.width: 2
                    visible: root.showUrgentAlert && root.urgentAlert !== null
                    opacity: visible ? 1 : 0
                    z: 50

                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Row {
                        id: urgentRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.2)
                            border.color: root.themeAccent; border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                source: "assets/dr_dhh.svg"
                                width: 28; height: 28
                                anchors.centerIn: parent
                                smooth: true
                            }
                        }

                        Column {
                            id: urgentCol
                            width: parent.width - 48
                            spacing: 4

                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: root.urgentAlert ? root.urgentAlert.title : "Municipal Advisory"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: (root.urgentAlert && root.urgentAlert.urgency === 3) ? "#f38ba8" : root.themeAccent
                                    elide: Text.ElideRight
                                    width: parent.width - 24
                                }
                                Text {
                                    text: "✕"
                                    font.pixelSize: 11
                                    color: root.themeSubtext
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showUrgentAlert = false
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.urgentAlert ? root.urgentAlert.message : ""
                                font.pixelSize: 10
                                color: root.themeFg
                                wrapMode: Text.Wrap
                            }

                            Row {
                                spacing: 6
                                visible: root.urgentAlert && root.urgentAlert.type === "budget"
                                Rectangle {
                                    height: 20; width: 84; radius: 4
                                    color: root.themeAccent
                                    Text { anchors.centerIn: parent; text: "Open Budget"; font.pixelSize: 9; font.bold: true; color: root.themeBtnFg }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showUrgentAlert = false;
                                            root.showBudgetModal = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Property / Tile Inspector Card (Query Tool '?')
                Rectangle {
                    id: tileInspectorCard
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 12
                    width: 290
                    height: inspectorCol.implicitHeight + 24
                    radius: 12
                    color: Qt.rgba(Qt.color(root.themeCardBg).r, Qt.color(root.themeCardBg).g, Qt.color(root.themeCardBg).b, 0.95)
                    border.color: root.themeAccent
                    border.width: 1.5
                    visible: root.showInspectorCard && root.inspectedData !== null
                    z: 45

                    Column {
                        id: inspectorCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Top Header: Title & Close Button
                        Item {
                            width: parent.width
                            height: 18
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "🔍 Property Inspection"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✕"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.themeSubtext
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showInspectorCard = false;
                                        viewport.clearInspection();
                                    }
                                }
                            }
                        }

                        // Building Title & Zone Badge
                        Column {
                            width: parent.width
                            spacing: 2
                            Text {
                                width: parent.width
                                text: root.inspectedData ? root.inspectedData.building_name : "Land Parcel"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeFg
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 6
                                Text {
                                    text: root.inspectedData ? (root.inspectedData.zone_name + " • (" + root.inspectedData.x + ", " + root.inspectedData.y + ")") : ""
                                    font.pixelSize: 10
                                    color: root.themeSubtext
                                }
                            }
                        }

                        // Status Pills (Power & Road Access)
                        Row {
                            spacing: 8
                            // Power Pill
                            Rectangle {
                                height: 20
                                width: pText.implicitWidth + 12
                                radius: 10
                                color: (root.inspectedData && root.inspectedData.powered) ? Qt.rgba(0.13, 0.77, 0.36, 0.2) : Qt.rgba(0.95, 0.26, 0.21, 0.2)
                                border.color: (root.inspectedData && root.inspectedData.powered) ? "#22c55e" : "#ef4444"
                                border.width: 1
                                Text {
                                    id: pText
                                    anchors.centerIn: parent
                                    text: (root.inspectedData && root.inspectedData.powered) ? "⚡ Powered" : "❌ Blackout"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: (root.inspectedData && root.inspectedData.powered) ? "#22c55e" : "#ef4444"
                                }
                            }
                            // Road Access Pill
                            Rectangle {
                                height: 20
                                width: rText.implicitWidth + 12
                                radius: 10
                                color: (root.inspectedData && root.inspectedData.road_connected) ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : Qt.rgba(0.96, 0.62, 0.07, 0.2)
                                border.color: (root.inspectedData && root.inspectedData.road_connected) ? "#3b82f6" : "#f59e0b"
                                border.width: 1
                                Text {
                                    id: rText
                                    anchors.centerIn: parent
                                    text: (root.inspectedData && root.inspectedData.road_connected) ? "🚗 Road Connected" : "⚠️ No Road Access"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: (root.inspectedData && root.inspectedData.road_connected) ? "#3b82f6" : "#f59e0b"
                                }
                            }
                        }

                        // Key Metrics (Land Value, Crime, Pollution)
                        Column {
                            width: parent.width
                            spacing: 4

                            // Land Value Row
                            Row {
                                width: parent.width
                                Text { text: "Land Value:"; font.pixelSize: 10; color: root.themeSubtext; width: 80 }
                                Text {
                                    text: root.inspectedData ? (root.inspectedData.land_value_str + " (" + root.inspectedData.land_value + "/255)") : "-"
                                    font.pixelSize: 10; font.bold: true; color: "#22c55e"
                                }
                            }
                            // Crime Row
                            Row {
                                width: parent.width
                                Text { text: "Crime Rate:"; font.pixelSize: 10; color: root.themeSubtext; width: 80 }
                                Text {
                                    text: root.inspectedData ? (root.inspectedData.crime_str + " (" + root.inspectedData.crime + "/255)") : "-"
                                    font.pixelSize: 10; font.bold: true
                                    color: (root.inspectedData && root.inspectedData.crime > 100) ? "#ef4444" : root.themeFg
                                }
                            }
                            // Pollution Row
                            Row {
                                width: parent.width
                                Text { text: "Pollution:"; font.pixelSize: 10; color: root.themeSubtext; width: 80 }
                                Text {
                                    text: root.inspectedData ? (root.inspectedData.pollution_str + " (" + root.inspectedData.pollution + "/255)") : "-"
                                    font.pixelSize: 10; font.bold: true
                                    color: (root.inspectedData && root.inspectedData.pollution > 100) ? "#c084fc" : root.themeFg
                                }
                            }
                        }
                    }
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

                // Dr. DHH interactive avatar badge
                Rectangle {
                    id: drDhhStatusBadge
                    height: 24
                    width: drDhhStatusRow.implicitWidth + 14
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: drDhhStatusMouse.containsMouse ? root.themeAccent : Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.15)
                    border.color: root.themeAccent
                    border.width: 1

                    Row {
                        id: drDhhStatusRow
                        anchors.centerIn: parent
                        spacing: 4
                        Image {
                            source: "assets/dr_dhh.svg"
                            width: 18; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }
                        Text {
                            text: "Dr. DHH"
                            font.pixelSize: 10
                            font.bold: true
                            color: drDhhStatusMouse.containsMouse ? root.themeBtnFg : root.themeAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: drDhhStatusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAdvisorModal = true
                    }
                }

                Text {
                    id: advisorText
                    anchors.verticalCenter: parent.verticalCenter
                    text: cityEngine ? cityEngine.advisorMessage : "Welcome to OmarchyCity! Click Dr. DHH or build zones to begin."
                    font.pixelSize: 11
                    color: root.themeFg
                    elide: Text.ElideRight
                    width: Math.max(100, parent.width - drDhhStatusBadge.width - 240)
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
                            source: "assets/dr_dhh.svg"
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
                                text: "Executive Municipal Administration • Dr. DHH"
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
                                { idx: 2, label: "💡 Dr. DHH's Briefing" }
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

                            // Speech Bubble from Dr. DHH
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
                                        text: "Greetings, your Honor! I am Dr. DHH, your Senior Advisor. Cut the municipal bloat, keep your systems modular, and deploy with confidence!"
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

                    // TAB 2: DR. DHH'S BRIEFING
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
                                        source: "assets/dr_dhh.svg"
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
                                            text: "\"Listen closely, Mayor! A thriving city requires foresight, simplicity, and zone balance without wasteful overhead. Here are my core principles for governing OmarchyCity:\""
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
        // DR. DHH ADVISOR CONSULTATION MODAL
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
                            source: "assets/dr_dhh.svg"
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
                                text: "Dr. DHH"
                                font.pixelSize: 18
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                text: "Chief Municipal Architect • Simplicity & Sovereignty"
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
                                if (!cityEngine) return "Welcome to OmarchyCity, your Honor! Keep your systems lean, modular, and unencumbered.";
                                if (cityEngine.population === 0) return "Our territory is untouched virgin wilderness! Deploy your core power plant, zone essential residential, commercial, and industrial districts, and avoid over-engineering your road network!";
                                if (cityEngine.funds < 1500) return "Warning, Mayor! Cash flow is bleeding out ($" + cityEngine.funds.toLocaleString() + "). You cannot spend your way out of bad fundamentals—cut wasteful overhead and balance the budget!";
                                if (cityEngine.demandRes > 0.4) return "Citizens are flocking to our borders! Demand for residential living is surging—zone clean, walkable residential neighborhoods!";
                                if (cityEngine.demandCom > 0.4) return "Commercial enterprise is booming! Local merchants and businesses need commercial zoning along active transit arteries!";
                                if (cityEngine.demandInd > 0.4) return "Manufacturers and builders need land! Expand industrial zoning along rail links, away from leafy neighborhoods.";
                                return cityEngine.advisorMessage || "OmarchyCity is running smoothly, Mayor! Maintain infrastructure sanity and avoid runaway municipal bloat!";
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
        // CITY HISTORY & DEMOGRAPHIC GRAPHS MODAL (Classic SimCity 10/120 Year)
        // =====================================================================
        Rectangle {
            id: graphModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.78)
            visible: root.showGraphModal
            z: 94

            property bool is120Year: false
            property bool showRes: true
            property bool showCom: true
            property bool showInd: true
            property bool showMoney: true
            property bool showCrime: false
            property bool showPollution: false

            onVisibleChanged: {
                if (visible) graphCanvas.requestPaint();
            }

            Connections {
                target: cityEngine
                function onStatsChanged() {
                    if (root.showGraphModal) graphCanvas.requestPaint();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.showGraphModal = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(680, parent.width - 24)
                height: Math.min(500, parent.height - 30)
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                MouseArea { anchors.fill: parent; onClicked: {} } // Block click-through

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    // Header Row: Title, 10/120 Year toggle, Close button
                    Row {
                        width: parent.width
                        spacing: 10

                        Column {
                            width: parent.width - 210
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Row {
                                spacing: 8
                                Text { text: "📈"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "City History & Demographics"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: root.themeAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                text: graphModal.is120Year ? "120-Year Historical Evaluation (Annual Census)" : "10-Year Municipal Trends (Monthly Census)"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }
                        }

                        // Time span toggle: [ 10 Yrs ] [ 120 Yrs ]
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Rectangle {
                                width: 68; height: 28; radius: 6
                                color: !graphModal.is120Year ? root.themeAccent : root.themeBoardBg
                                border.color: root.themeBorder; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "10 Years"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: !graphModal.is120Year ? root.themeBtnFg : root.themeFg
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        graphModal.is120Year = false;
                                        graphCanvas.requestPaint();
                                    }
                                }
                            }

                            Rectangle {
                                width: 72; height: 28; radius: 6
                                color: graphModal.is120Year ? root.themeAccent : root.themeBoardBg
                                border.color: root.themeBorder; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "120 Years"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: graphModal.is120Year ? root.themeBtnFg : root.themeFg
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        graphModal.is120Year = true;
                                        graphCanvas.requestPaint();
                                    }
                                }
                            }
                        }

                        // Close Button
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: graphCloseMouse.containsMouse ? root.themeBorder : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 12
                                color: root.themeSubtext
                            }
                            MouseArea {
                                id: graphCloseMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showGraphModal = false
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // Series Filter Chips (R, C, I, Funds, Crime, Pollution)
                    Flow {
                        width: parent.width
                        spacing: 8

                        // 1. Residential
                        Rectangle {
                            height: 26; width: 104; radius: 6
                            color: graphModal.showRes ? Qt.rgba(0.13, 0.77, 0.37, 0.2) : root.themeBoardBg
                            border.color: graphModal.showRes ? "#22c55e" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#22c55e" }
                                Text { text: "Residential"; font.pixelSize: 11; font.bold: graphModal.showRes; color: graphModal.showRes ? "#22c55e" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showRes = !graphModal.showRes; graphCanvas.requestPaint(); }
                            }
                        }

                        // 2. Commercial
                        Rectangle {
                            height: 26; width: 106; radius: 6
                            color: graphModal.showCom ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : root.themeBoardBg
                            border.color: graphModal.showCom ? "#3b82f6" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#3b82f6" }
                                Text { text: "Commercial"; font.pixelSize: 11; font.bold: graphModal.showCom; color: graphModal.showCom ? "#3b82f6" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showCom = !graphModal.showCom; graphCanvas.requestPaint(); }
                            }
                        }

                        // 3. Industrial
                        Rectangle {
                            height: 26; width: 98; radius: 6
                            color: graphModal.showInd ? Qt.rgba(0.96, 0.62, 0.07, 0.2) : root.themeBoardBg
                            border.color: graphModal.showInd ? "#f59e0b" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#f59e0b" }
                                Text { text: "Industrial"; font.pixelSize: 11; font.bold: graphModal.showInd; color: graphModal.showInd ? "#f59e0b" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showInd = !graphModal.showInd; graphCanvas.requestPaint(); }
                            }
                        }

                        // 4. Money / Funds
                        Rectangle {
                            height: 26; width: 88; radius: 6
                            color: graphModal.showMoney ? Qt.rgba(0.06, 0.73, 0.51, 0.2) : root.themeBoardBg
                            border.color: graphModal.showMoney ? "#10b981" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#10b981" }
                                Text { text: "Funds ($)"; font.pixelSize: 11; font.bold: graphModal.showMoney; color: graphModal.showMoney ? "#10b981" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showMoney = !graphModal.showMoney; graphCanvas.requestPaint(); }
                            }
                        }

                        // 5. Crime
                        Rectangle {
                            height: 26; width: 80; radius: 6
                            color: graphModal.showCrime ? Qt.rgba(0.94, 0.27, 0.27, 0.2) : root.themeBoardBg
                            border.color: graphModal.showCrime ? "#ef4444" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#ef4444" }
                                Text { text: "Crime"; font.pixelSize: 11; font.bold: graphModal.showCrime; color: graphModal.showCrime ? "#ef4444" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showCrime = !graphModal.showCrime; graphCanvas.requestPaint(); }
                            }
                        }

                        // 6. Pollution
                        Rectangle {
                            height: 26; width: 90; radius: 6
                            color: graphModal.showPollution ? Qt.rgba(0.66, 0.33, 0.97, 0.2) : root.themeBoardBg
                            border.color: graphModal.showPollution ? "#a855f7" : root.themeBorder
                            border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 10; height: 10; radius: 2; color: "#a855f7" }
                                Text { text: "Pollution"; font.pixelSize: 11; font.bold: graphModal.showPollution; color: graphModal.showPollution ? "#a855f7" : root.themeSubtext }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { graphModal.showPollution = !graphModal.showPollution; graphCanvas.requestPaint(); }
                            }
                        }
                    }

                    // Main Chart Area Canvas
                    Rectangle {
                        width: parent.width
                        height: parent.height - 180
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1
                        clip: true

                        Canvas {
                            id: graphCanvas
                            anchors.fill: parent
                            anchors.margins: 10
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var w = width;
                                var h = height;
                                var padL = 46;
                                var padR = 20;
                                var padT = 16;
                                var padB = 28;
                                var plotW = Math.max(10, w - padL - padR);
                                var plotH = Math.max(10, h - padT - padB);

                                // Grid lines
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.07)";
                                ctx.lineWidth = 1;

                                for (var i = 0; i <= 4; i++) {
                                    var y = padT + (plotH / 4) * i;
                                    ctx.beginPath();
                                    ctx.moveTo(padL, y);
                                    ctx.lineTo(w - padR, y);
                                    ctx.stroke();
                                }

                                for (var j = 0; j <= 5; j++) {
                                    var x = padL + (plotW / 5) * j;
                                    ctx.beginPath();
                                    ctx.moveTo(x, padT);
                                    ctx.lineTo(x, padT + plotH);
                                    ctx.stroke();
                                }

                                // X-axis labels
                                ctx.fillStyle = "#8892b0";
                                ctx.font = "10px sans-serif";
                                ctx.textAlign = "center";
                                var xLabels = graphModal.is120Year ?
                                    ["-120y", "-100y", "-80y", "-60y", "-40y", "Now"] :
                                    ["-10y", "-8y", "-6y", "-4y", "-2y", "Now"];
                                for (var k = 0; k <= 5; k++) {
                                    var lx = padL + (plotW / 5) * k;
                                    ctx.fillText(xLabels[k], lx, h - 8);
                                }

                                if (!cityEngine) return;

                                var seriesConfigs = [
                                    { id: "res", enabled: graphModal.showRes, color: "#22c55e" },
                                    { id: "com", enabled: graphModal.showCom, color: "#3b82f6" },
                                    { id: "ind", enabled: graphModal.showInd, color: "#f59e0b" },
                                    { id: "money", enabled: graphModal.showMoney, color: "#10b981" },
                                    { id: "crime", enabled: graphModal.showCrime, color: "#ef4444" },
                                    { id: "pollution", enabled: graphModal.showPollution, color: "#a855f7" }
                                ];

                                var maxVal = 100;
                                var activeSeries = [];
                                for (var s = 0; s < seriesConfigs.length; s++) {
                                    var cfg = seriesConfigs[s];
                                    if (!cfg.enabled) continue;
                                    var data = cityEngine.getHistory(cfg.id, graphModal.is120Year);
                                    if (data && data.length > 0) {
                                        for (var d = 0; d < data.length; d++) {
                                            if (data[d] > maxVal) maxVal = data[d];
                                        }
                                        activeSeries.push({ cfg: cfg, data: data });
                                    }
                                }

                                // Y-axis labels
                                ctx.textAlign = "right";
                                ctx.fillText(Math.round(maxVal).toLocaleString(), padL - 6, padT + 8);
                                ctx.fillText(Math.round(maxVal / 2).toLocaleString(), padL - 6, padT + plotH / 2 + 4);
                                ctx.fillText("0", padL - 6, padT + plotH + 4);

                                // Plot active curves
                                for (var a = 0; a < activeSeries.length; a++) {
                                    var item = activeSeries[a];
                                    var pts = item.data;
                                    var col = item.cfg.color;
                                    var n = pts.length;
                                    if (n < 2) continue;

                                    ctx.strokeStyle = col;
                                    ctx.lineWidth = 2.2;
                                    ctx.beginPath();

                                    for (var p = 0; p < n; p++) {
                                        var px = padL + (p / (n - 1)) * plotW;
                                        var valNorm = Math.max(0, Math.min(1.0, pts[p] / maxVal));
                                        var py = padT + plotH - (valNorm * plotH);

                                        if (p === 0) {
                                            ctx.moveTo(px, py);
                                        } else {
                                            ctx.lineTo(px, py);
                                        }
                                    }
                                    ctx.stroke();

                                    var lastVal = pts[n - 1];
                                    var lastY = padT + plotH - (Math.max(0, Math.min(1.0, lastVal / maxVal)) * plotH);
                                    var lastX = padL + plotW;

                                    ctx.fillStyle = col;
                                    ctx.beginPath();
                                    ctx.arc(lastX, lastY, 3.5, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }
                        }
                    }

                    // Bottom status tip
                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "💡 Tip: Balanced RCI growth sustains healthy municipal cash flow with low crime & pollution."
                            font.pixelSize: 11
                            color: root.themeSubtext
                        }
                    }
                }
            }
        }

        // =====================================================================
        // HELP OVERLAY MODAL (Standard Omarchy Arcade Template)
        // =====================================================================
        Rectangle {
            id: helpModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
            visible: root.showHelp
            z: 95

            MouseArea {
                anchors.fill: parent
                onClicked: root.showHelp = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(500, parent.width - 32)
                height: 440
                radius: 12
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                MouseArea { anchors.fill: parent; onClicked: {} } // Block click inside dialog

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // Title & Subtitle
                    Column {
                        width: parent.width
                        spacing: 2
                        Text {
                            text: "OmarchyCity"
                            font.pixelSize: 18
                            font.bold: true
                            color: root.themeAccent
                        }
                        Text {
                            text: "Classic City Simulation Arcade • Built on Micropolis C++ Core"
                            font.pixelSize: 11
                            color: root.themeSubtext
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // Scrollable Help / Controls Text
                    Flickable {
                        width: parent.width
                        height: 200
                        contentHeight: helpContentCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: helpContentCol
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: root.helpText
                                font.pixelSize: 11
                                lineHeight: 1.4
                                color: root.themeFg
                            }

                            Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: "💡 Pro-Tip: Connect power grids to all zones. Keep heavy industry downwind or separated from residential districts to keep citizens happy!"
                                font.pixelSize: 10
                                color: root.themeSubtext
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.themeBorder }

                    // Got It Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 120; height: 32; radius: 6
                        color: root.themeAccent
                        Text { anchors.centerIn: parent; text: "GOT IT"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHelp = false
                        }
                    }

                    // Author Attribution (Standard Arcade Template)
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Text {
                            text: "Created by Chris Thompson (@bigcjat) with Gemini"
                            font.pixelSize: 10
                            color: root.themeSubtext
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.85
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Text {
                                text: "GitHub: github.com/bigcjat"
                                font.pixelSize: 9
                                color: root.themeAccent
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://github.com/bigcjat")
                                }
                            }

                            Text {
                                text: "•"
                                font.pixelSize: 9
                                color: root.themeSubtext
                            }

                            Text {
                                text: "X: @bigcjat"
                                font.pixelSize: 9
                                color: root.themeAccent
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://x.com/bigcjat")
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ANNUAL BUDGET & FINANCIAL AUDIT MODAL
        // =====================================================================
        Rectangle {
            id: budgetModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.78)
            visible: root.showBudgetModal
            z: 110

            MouseArea { anchors.fill: parent; onClicked: {} } // Block click-through

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(680, parent.width - 24)
                height: Math.min(640, parent.height - 20)
                radius: 14
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Modal Header
                    Row {
                        width: parent.width
                        spacing: 10
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.2)
                            border.color: root.themeAccent; border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                source: "assets/dr_dhh.svg"
                                width: 30; height: 30
                                anchors.centerIn: parent
                                smooth: true
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "🏛️ Municipal Budget & Fiscal Audit"
                                font.pixelSize: 17
                                font.bold: true
                                color: root.themeAccent
                            }
                            Text {
                                text: (cityEngine ? cityEngine.cityName : "OmarchyCity") + " • Fiscal Year " + (cityEngine ? cityEngine.year : "1900") + " Balance Sheet"
                                font.pixelSize: 11
                                color: root.themeSubtext
                            }
                        }
                    }

                    // Balance Sheet Overview Strip
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: root.themeBoardBg
                        border.color: root.themeBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 24

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "TREASURY"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: "$" + (cityEngine ? cityEngine.funds.toLocaleString() : "20,000")
                                    font.pixelSize: 14; font.bold: true; font.family: root.monoFontFamily
                                    color: (cityEngine && cityEngine.funds < 0) ? "#ef4444" : "#22c55e"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            Rectangle { width: 1; height: 28; color: root.themeBorder; anchors.verticalCenter: parent.verticalCenter }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "EST. TAX REVENUE"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: "+$" + (root.budgetData ? Math.round(root.budgetData.tax_fund * (root.budgetTaxRate / Math.max(1, root.budgetData.tax_rate))).toLocaleString() : "0")
                                    font.pixelSize: 14; font.bold: true; font.family: root.monoFontFamily; color: "#22c55e"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            Rectangle { width: 1; height: 28; color: root.themeBorder; anchors.verticalCenter: parent.verticalCenter }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "EXPENDITURES"; font.pixelSize: 9; font.bold: true; color: root.themeSubtext; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: "-$" + (root.budgetData ? Math.round((root.budgetData.road_fund * root.budgetRoadPct) + (root.budgetData.police_fund * root.budgetPolicePct) + (root.budgetData.fire_fund * root.budgetFirePct) + ((cityEngine && cityEngine.hasActiveLoan) ? 500 : 0)).toLocaleString() : "0")
                                    font.pixelSize: 14; font.bold: true; font.family: root.monoFontFamily; color: "#ef4444"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    // Sliders Section (Tax, Road, Police, Fire)
                    Column {
                        width: parent.width
                        spacing: 8

                        // 1. Tax Rate Slider
                        Rectangle {
                            width: parent.width; height: 46; radius: 6; color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 6; spacing: 4
                                Item {
                                    width: parent.width; height: 16
                                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "City Income Tax Rate"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
                                    Text {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: root.budgetTaxRate + "% (0% - 20%)"
                                        font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: root.themeAccent
                                    }
                                }
                                Rectangle {
                                    id: taxTrack
                                    width: parent.width; height: 8; radius: 4; color: "#181825"
                                    Rectangle {
                                        width: taxTrack.width * (root.budgetTaxRate / 20.0)
                                        height: parent.height; radius: 4; color: root.themeAccent
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        function updateTax(mx) {
                                            var pct = Math.max(0, Math.min(1.0, mx / taxTrack.width));
                                            root.budgetTaxRate = Math.round(pct * 20);
                                        }
                                        onPressed: updateTax(mouseX)
                                        onPositionChanged: if (pressed) updateTax(mouseX)
                                    }
                                }
                            }
                        }

                        // 2. Road Maintenance Slider
                        Rectangle {
                            width: parent.width; height: 46; radius: 6; color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 6; spacing: 4
                                Item {
                                    width: parent.width; height: 16
                                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "🛣️ Transportation / Road Funding"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
                                    Text {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(root.budgetRoadPct * 100) + "% ($" + (root.budgetData ? Math.round(root.budgetData.road_fund * root.budgetRoadPct) : 0) + " / $" + (root.budgetData ? root.budgetData.road_fund : 0) + ")"
                                        font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: "#38bdf8"
                                    }
                                }
                                Rectangle {
                                    id: roadTrack
                                    width: parent.width; height: 8; radius: 4; color: "#181825"
                                    Rectangle {
                                        width: roadTrack.width * root.budgetRoadPct
                                        height: parent.height; radius: 4; color: "#38bdf8"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        function updateRoad(mx) {
                                            root.budgetRoadPct = Math.max(0, Math.min(1.0, mx / roadTrack.width));
                                        }
                                        onPressed: updateRoad(mouseX)
                                        onPositionChanged: if (pressed) updateRoad(mouseX)
                                    }
                                }
                            }
                        }

                        // 3. Police Department Funding Slider
                        Rectangle {
                            width: parent.width; height: 46; radius: 6; color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 6; spacing: 4
                                Item {
                                    width: parent.width; height: 16
                                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "👮 Police Department Funding"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
                                    Text {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(root.budgetPolicePct * 100) + "% ($" + (root.budgetData ? Math.round(root.budgetData.police_fund * root.budgetPolicePct) : 0) + " / $" + (root.budgetData ? root.budgetData.police_fund : 0) + ")"
                                        font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: "#818cf8"
                                    }
                                }
                                Rectangle {
                                    id: policeTrack
                                    width: parent.width; height: 8; radius: 4; color: "#181825"
                                    Rectangle {
                                        width: policeTrack.width * root.budgetPolicePct
                                        height: parent.height; radius: 4; color: "#818cf8"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        function updatePolice(mx) {
                                            root.budgetPolicePct = Math.max(0, Math.min(1.0, mx / policeTrack.width));
                                        }
                                        onPressed: updatePolice(mouseX)
                                        onPositionChanged: if (pressed) updatePolice(mouseX)
                                    }
                                }
                            }
                        }

                        // 4. Fire Department Funding Slider
                        Rectangle {
                            width: parent.width; height: 46; radius: 6; color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 6; spacing: 4
                                Item {
                                    width: parent.width; height: 16
                                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "🚒 Fire Department Funding"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
                                    Text {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(root.budgetFirePct * 100) + "% ($" + (root.budgetData ? Math.round(root.budgetData.fire_fund * root.budgetFirePct) : 0) + " / $" + (root.budgetData ? root.budgetData.fire_fund : 0) + ")"
                                        font.pixelSize: 11; font.bold: true; font.family: root.monoFontFamily; color: "#f87171"
                                    }
                                }
                                Rectangle {
                                    id: fireTrack
                                    width: parent.width; height: 8; radius: 4; color: "#181825"
                                    Rectangle {
                                        width: fireTrack.width * root.budgetFirePct
                                        height: parent.height; radius: 4; color: "#f87171"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        function updateFire(mx) {
                                            root.budgetFirePct = Math.max(0, Math.min(1.0, mx / fireTrack.width));
                                        }
                                        onPressed: updateFire(mouseX)
                                        onPositionChanged: if (pressed) updateFire(mouseX)
                                    }
                                }
                            }
                        }
                    }

                    // Municipal Bank Loan Box
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 8
                        color: Qt.rgba(Qt.color(root.themeAccent).r, Qt.color(root.themeAccent).g, Qt.color(root.themeAccent).b, 0.1)
                        border.color: root.themeAccent
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Column {
                                width: parent.width - 150
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: (cityEngine && cityEngine.hasActiveLoan) ? "🏛️ Active Municipal Bank Loan ($10,000)" : "🏛️ Municipal Bank Loan Available ($10,000)"
                                    font.pixelSize: 11; font.bold: true; color: root.themeAccent
                                }
                                Text {
                                    text: (cityEngine && cityEngine.hasActiveLoan) ? ("Remaining debt: $" + (cityEngine.loanYearsRemaining * cityEngine.loanAnnualPayment).toLocaleString() + " (" + cityEngine.loanYearsRemaining + " yrs @ $500/yr)") : "Borrow $10,000 for infrastructure. Repaid over 21 years at $500/year."
                                    font.pixelSize: 9; color: root.themeSubtext
                                }
                            }

                            Rectangle {
                                height: 30; width: 130; radius: 6
                                color: (cityEngine && cityEngine.hasActiveLoan) ? "#313244" : root.themeAccent
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: (cityEngine && cityEngine.hasActiveLoan) ? "Pay Off Loan" : "Borrow $10,000"
                                    font.pixelSize: 10; font.bold: true
                                    color: (cityEngine && cityEngine.hasActiveLoan) ? root.themeFg : root.themeBtnFg
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (cityEngine) {
                                            if (cityEngine.hasActiveLoan) {
                                                cityEngine.repay_loan_full();
                                            } else {
                                                cityEngine.take_loan();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Auto-Budget Checkbox & Continue Button Row
                    Item {
                        width: parent.width
                        height: 36

                        // Auto-Budget Checkbox
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Rectangle {
                                width: 16; height: 16; radius: 4
                                color: root.budgetAuto ? root.themeAccent : root.themeBoardBg
                                border.color: root.themeBorder; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"; font.pixelSize: 11; font.bold: true
                                    color: root.themeBtnFg
                                    visible: root.budgetAuto
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.budgetAuto = !root.budgetAuto;
                                        if (cityEngine) cityEngine.set_auto_budget(root.budgetAuto);
                                    }
                                }
                            }
                            Text {
                                text: "Auto-Budget (Apply 100% funding annually)"
                                font.pixelSize: 10; color: root.themeFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Apply & Resume Button
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 36; width: 160; radius: 8
                            color: root.themeAccent
                            Text {
                                anchors.centerIn: parent
                                text: "Enact & Resume City"
                                font.pixelSize: 11; font.bold: true; color: root.themeBtnFg
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (cityEngine) {
                                        cityEngine.apply_budget(root.budgetTaxRate, root.budgetRoadPct, root.budgetPolicePct, root.budgetFirePct);
                                    }
                                    root.showBudgetModal = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // EMERGENCY DISASTERS CONTROL MODAL
        // =====================================================================
        Rectangle {
            id: disasterModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.78)
            visible: root.showDisasterModal
            z: 110

            MouseArea { anchors.fill: parent; onClicked: root.showDisasterModal = false }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(620, parent.width - 24)
                height: 440
                radius: 14
                color: root.themeCardBg
                border.color: root.themeBorder
                border.width: 1
                clip: true

                MouseArea { anchors.fill: parent; onClicked: {} } // Block click inside dialog

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Title
                    Item {
                        width: parent.width
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🌪️ Emergency Disaster Control"
                            font.pixelSize: 17; font.bold: true; color: "#f38ba8"
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"; font.pixelSize: 13; font.bold: true; color: root.themeSubtext
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showDisasterModal = false }
                        }
                    }

                    Text {
                        text: "Test your municipal emergency departments, disaster contingency plans, and civil defense services."
                        font.pixelSize: 11; color: root.themeSubtext; wrapMode: Text.Wrap; width: parent.width
                    }

                    // 6 Disaster Cards Grid
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10

                        Repeater {
                            model: [
                                { id: 0, icon: "🔥", name: "Massive Firestorm", desc: "Ignites random buildings into spreading infernos.", color: "#f87171" },
                                { id: 1, icon: "🌊", name: "Coastal Flash Flood", desc: "Water surges over riverbanks onto adjacent land.", color: "#38bdf8" },
                                { id: 2, icon: "🦖", name: "Kaiju Monster Attack", desc: "A colossal beast emerges to stomp downtown high-rises!", color: "#4ade80" },
                                { id: 3, icon: "🌪️", name: "Violent Tornado", desc: "Funnel cloud tears through infrastructure lines.", color: "#facc15" },
                                { id: 4, icon: "💥", name: "Major Earthquake", desc: "Fault line slips, shattering foundations into rubble.", color: "#fb923c" },
                                { id: 5, icon: "☢️", name: "Nuclear Meltdown", desc: "Reactor breach causes radioactive fallout zones.", color: "#c084fc" }
                            ]
                            delegate: Rectangle {
                                width: (disasterModal.width > 500) ? 285 : parent.width
                                height: 72
                                radius: 8
                                color: root.themeBoardBg
                                border.color: dMouse.containsMouse ? modelData.color : root.themeBorder
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 48
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: modelData.name
                                            font.pixelSize: 12; font.bold: true; color: modelData.color
                                        }
                                        Text {
                                            text: modelData.desc
                                            font.pixelSize: 9; color: root.themeSubtext; wrapMode: Text.Wrap; width: parent.width
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (cityEngine) {
                                            cityEngine.trigger_disaster(modelData.id);
                                        }
                                        root.showDisasterModal = false;
                                        soundToast.show("Disaster: " + modelData.name + " triggered!");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // POPULATION MILESTONE REWARD MODAL
        // =====================================================================
        Rectangle {
            id: milestoneModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.80)
            visible: root.showMilestoneModal
            z: 120

            MouseArea { anchors.fill: parent; onClicked: {} } // Block click-through

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(520, parent.width - 32)
                height: 360
                radius: 16
                color: root.themeCardBg
                border.color: "#facc15" // Golden trophy border
                border.width: 2
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    // Trophy Header
                    Column {
                        width: parent.width
                        spacing: 6
                        Text { text: "🏆"; font.pixelSize: 44; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            text: "POPULATION MILESTONE REACHED!"
                            font.pixelSize: 16; font.bold: true; color: "#facc15"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "ByteCity has officially achieved " + root.milestoneTitle.toUpperCase() + " status!"
                            font.pixelSize: 12; color: root.themeFg
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Reward Highlight Card
                    Rectangle {
                        width: parent.width; height: 60; radius: 10
                        color: Qt.rgba(0.98, 0.8, 0.08, 0.15)
                        border.color: "#facc15"; border.width: 1
                        Row {
                            anchors.centerIn: parent
                            spacing: 12
                            Text { text: "🎁"; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "CIVIC REWARD UNLOCKED"; font.pixelSize: 9; font.bold: true; color: "#facc15" }
                                Text { text: root.milestoneReward; font.pixelSize: 14; font.bold: true; color: root.themeFg }
                            }
                        }
                    }

                    // Dr. DHH Quote
                    Row {
                        width: parent.width; spacing: 10
                        Image {
                            source: "assets/dr_dhh.svg"
                            width: 32; height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }
                        Text {
                            width: parent.width - 44
                            text: "“Marvelous stewardship, Mayor! The citizenry celebrates your forward-looking urban design. Onward to the next demographic tier!”"
                            font.pixelSize: 10; font.italic: true; color: root.themeSubtext
                            wrapMode: Text.Wrap
                        }
                    }

                    // Accept Button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 38; width: 180; radius: 8
                        color: "#facc15"
                        Text {
                            anchors.centerIn: parent
                            text: "Accept Honors & Continue"
                            font.pixelSize: 11; font.bold: true; color: "#11111b"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.showMilestoneModal = false
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MUNICIPAL BANKRUPTCY GAME OVER MODAL
        // =====================================================================
        Rectangle {
            id: gameOverModal
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.88)
            visible: root.showGameOverModal
            z: 130

            MouseArea { anchors.fill: parent; onClicked: {} } // Block click-through

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(500, parent.width - 32)
                height: 340
                radius: 14
                color: root.themeCardBg
                border.color: "#ef4444"
                border.width: 2
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    Column {
                        width: parent.width; spacing: 6
                        Text { text: "🚨"; font.pixelSize: 42; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            text: "MUNICIPAL BANKRUPTCY"
                            font.pixelSize: 18; font.bold: true; color: "#ef4444"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.gameOverReason || "Treasury reserves have fallen deeply into debt (-$5,000). The state legislature has declared municipal insolvency and suspended the city council."
                        font.pixelSize: 11; color: root.themeFg; wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            height: 36; width: 140; radius: 8
                            color: root.themeAccent
                            Text { anchors.centerIn: parent; text: "Start New City"; font.pixelSize: 11; font.bold: true; color: root.themeBtnFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showGameOverModal = false;
                                    root.selectedSetupTab = 0;
                                    root.showInaugurationModal = true;
                                }
                            }
                        }

                        Rectangle {
                            height: 36; width: 140; radius: 8
                            color: root.themeBoardBg; border.color: root.themeBorder; border.width: 1
                            Text { anchors.centerIn: parent; text: "Load Scenario"; font.pixelSize: 11; font.bold: true; color: root.themeFg }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showGameOverModal = false;
                                    root.selectedSetupTab = 1;
                                    root.showInaugurationModal = true;
                                }
                            }
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
