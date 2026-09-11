import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: sidebarView
    anchors.fill: parent

    property var games: []
    property int selectedIndex: 0
    property var activeGame: (games && selectedIndex >= 0 && selectedIndex < games.length) ? games[selectedIndex] : null

    // Responsive breakpoints
    readonly property bool isNarrow: sidebarView.width < 900
    readonly property bool isUltraNarrow: sidebarView.width < 740

    signal gameSelected(int index)
    signal gameLaunched(string gameId)
    signal detailRequested(var gameData)

    onSelectedIndexChanged: {
        if (sidebarList.currentIndex !== selectedIndex && selectedIndex >= 0 && selectedIndex < games.length) {
            sidebarList.currentIndex = selectedIndex;
            sidebarList.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
        // Reset right pane scroll to top when changing game
        if (rightFlickable) {
            rightFlickable.contentY = 0;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // 1. LEFT SIDEBAR: Vertical Game Library List (Responsive Width)
        // =====================================================================
        Rectangle {
            // Give the right details pane the majority of space on small screens
            Layout.preferredWidth: sidebarView.isUltraNarrow ? 180 : (sidebarView.isNarrow ? 215 : 270)
            Layout.minimumWidth: 170
            Layout.maximumWidth: 300
            Layout.fillHeight: true
            color: "#111118"
            border.color: "#1e1e2c"
            border.width: 1
            z: 10

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Library Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: "#14141e"
                    border.color: "#1f1f2e"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: sidebarView.isNarrow ? 10 : 14
                        anchors.rightMargin: sidebarView.isNarrow ? 10 : 14

                        Text {
                            text: sidebarView.isUltraNarrow ? "TITLES" : "LIBRARY TITLES"
                            font.family: "monospace"
                            font.pixelSize: sidebarView.isNarrow ? 10 : 11
                            font.bold: true
                            color: "#94a3b8"
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 18
                            radius: 9
                            color: "#1e2232"
                            width: countLabel.implicitWidth + 10

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: sidebarView.games ? sidebarView.games.length : "0"
                                font.family: "monospace"
                                font.pixelSize: 10
                                font.bold: true
                                color: themeAccent
                            }
                        }
                    }
                }

                // Vertical List View
                ListView {
                    id: sidebarList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: sidebarView.games
                    currentIndex: sidebarView.selectedIndex
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: rowItem
                        width: sidebarList.width
                        height: sidebarView.isNarrow ? 48 : 52
                        color: isSelected ? "#1c1f2e" : (rowMouse.containsMouse ? "#151722" : "transparent")

                        readonly property bool isSelected: index === sidebarView.selectedIndex
                        readonly property bool installed: modelData ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(modelData.id) : true) : true
                        readonly property bool hasUpdate: modelData ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(modelData.id, modelData.version || "") : (typeof arcadeBackend !== "undefined" && arcadeBackend.hasGameUpdate ? arcadeBackend.hasGameUpdate(modelData.id, modelData.version || "") : false)) : false

                        // Left active indicator strip
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3
                            color: themeAccent
                            visible: rowItem.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: sidebarView.isNarrow ? 8 : 12
                            anchors.rightMargin: sidebarView.isNarrow ? 8 : 12
                            spacing: sidebarView.isNarrow ? 8 : 10

                            // 3.5" Disk Icon thumbnail
                            Rectangle {
                                width: sidebarView.isNarrow ? 28 : 32
                                height: sidebarView.isNarrow ? 28 : 32
                                radius: 4
                                color: modelData && modelData.floppy_color ? modelData.floppy_color : "#20202a"
                                border.color: "#0a0a0f"
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    height: parent.height - 4
                                    fillMode: Image.PreserveAspectFit
                                    source: {
                                        if (!modelData) return "";
                                        if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                            return arcadeBackend.getDiskIconUrl(modelData.id);
                                        }
                                        return "../games/" + modelData.id + "/assets/disk_icon.png";
                                    }
                                }
                            }

                            // Title & Category Subtitle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData ? modelData.title : ""
                                    font.pixelSize: sidebarView.isNarrow ? 11 : 12
                                    font.bold: rowItem.isSelected
                                    color: rowItem.isSelected ? "#FFFFFF" : (rowMouse.containsMouse ? "#e2e8f0" : "#94a3b8")
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData ? (modelData.category + (modelData.size ? " • " + modelData.size : "")) : ""
                                    font.pixelSize: sidebarView.isNarrow ? 9 : 10
                                    color: rowItem.isSelected ? themeAccent : "#64748b"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Status dot / update badge / get badge
                            Rectangle {
                                readonly property bool showBadge: rowItem.hasUpdate || !rowItem.installed
                                width: rowItem.hasUpdate ? (sidebarView.isNarrow ? 44 : 50) : (!rowItem.installed ? (sidebarView.isNarrow ? 36 : 42) : (sidebarView.isNarrow ? 6 : 8))
                                height: showBadge ? (sidebarView.isNarrow ? 15 : 18) : (sidebarView.isNarrow ? 6 : 8)
                                radius: showBadge ? 4 : (width / 2)
                                color: rowItem.hasUpdate ? "#0284c7" : (!rowItem.installed ? "#065f46" : "#22c55e")
                                border.color: rowItem.hasUpdate ? "#38bdf8" : (!rowItem.installed ? "#34d399" : "transparent")
                                border.width: showBadge ? 1 : 0

                                Row {
                                    anchors.centerIn: parent
                                    visible: rowItem.hasUpdate
                                    spacing: 2
                                    Text {
                                        text: "🔄"
                                        font.pixelSize: sidebarView.isNarrow ? 7 : 8
                                    }
                                    Text {
                                        text: "UPDATE"
                                        font.family: "monospace"
                                        font.pixelSize: sidebarView.isNarrow ? 7 : 8
                                        font.bold: true
                                        color: "#f0f9ff"
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    visible: !rowItem.hasUpdate && !rowItem.installed
                                    spacing: 2
                                    Text {
                                        text: "⬇"
                                        font.pixelSize: sidebarView.isNarrow ? 7 : 8
                                        color: "#ecfdf5"
                                    }
                                    Text {
                                        text: "GET"
                                        font.family: "monospace"
                                        font.pixelSize: sidebarView.isNarrow ? 7 : 8
                                        font.bold: true
                                        color: "#ecfdf5"
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sidebarView.gameSelected(index);
                                if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
                                    root.restoreKeyboardFocus();
                                }
                            }
                            onDoubleClicked: {
                                sidebarView.gameSelected(index);
                                if (modelData) {
                                    sidebarView.gameLaunched(modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. RIGHT PANE: Rich Full-Profile Game Details & Hero Showcase
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0c0d14"
            clip: true

            // Empty state if no game is selected, but games exist in list
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: !activeGame && games && games.length > 0

                Text {
                    text: "📑"
                    font.pixelSize: 42
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Select a game from the library list"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#94a3b8"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // High-Performance Native Flickable with Vertical ScrollBar
            Flickable {
                id: rightFlickable
                anchors.fill: parent
                clip: true
                visible: !!activeGame
                contentWidth: width
                contentHeight: contentCol.implicitHeight + 48
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                WheelHandler {
                    target: rightFlickable
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        rightFlickable.flick(0, delta * 5);
                    }
                }

                Column {
                    id: contentCol
                    width: rightFlickable.width
                    spacing: 20

                    // HERO BANNER SECTION (Top)
                    Item {
                        width: parent.width
                        height: sidebarView.isNarrow ? 300 : 330

                        // Hero Screenshot / Cover background
                        AnimatedImage {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            source: {
                                if (!activeGame) return "";
                                if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getScreenshotUrl) {
                                    return arcadeBackend.getScreenshotUrl(activeGame.folder);
                                }
                                return "../" + activeGame.folder + "/screenshot.png";
                            }
                            onStatusChanged: {
                                if (status === AnimatedImage.Error && source.toString().indexOf("http") === 0) {
                                    if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getFallbackScreenshotUrl) {
                                        var fb = arcadeBackend.getFallbackScreenshotUrl(activeGame ? activeGame.folder : "");
                                        if (fb) source = fb;
                                    }
                                }
                            }

                            // Vignette / Scanline shader effect
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "#20000000" }
                                    GradientStop { position: 0.45; color: "#850c0d14" }
                                    GradientStop { position: 1.0; color: "#0c0d14" }
                                }
                            }
                        }

                        // Hero Overlay Content
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: sidebarView.isNarrow ? 18 : 26
                            spacing: sidebarView.isNarrow ? 8 : 12

                            // Tags & Category row
                            Row {
                                spacing: 6

                                Rectangle {
                                    height: 20
                                    radius: 4
                                    color: (activeGame && activeGame.grid_color) ? activeGame.grid_color : themeAccent
                                    width: heroCatText.implicitWidth + 12

                                    Text {
                                        id: heroCatText
                                        anchors.centerIn: parent
                                        text: activeGame ? activeGame.category : ""
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#09090e"
                                    }
                                }

                                Rectangle {
                                    height: 20
                                    radius: 4
                                    color: "#181d2a"
                                    border.color: "#2c364e"
                                    border.width: 1
                                    width: yrText.implicitWidth + 12

                                    Text {
                                        id: yrText
                                        anchors.centerIn: parent
                                        text: activeGame && activeGame.release_year ? activeGame.release_year : "2026"
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#94a3b8"
                                    }
                                }

                                Rectangle {
                                    height: 20
                                    radius: 4
                                    color: "#161926"
                                    border.color: "#3b4261"
                                    border.width: 1
                                    width: verText.implicitWidth + 12
                                    visible: Boolean(activeGame && activeGame.version)

                                    Text {
                                        id: verText
                                        anchors.centerIn: parent
                                        text: activeGame && activeGame.version ? ("v" + activeGame.version) : ""
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#93c5fd"
                                    }
                                }

                                Rectangle {
                                    height: 20
                                    radius: 4
                                    color: "#181d2a"
                                    border.color: "#2c364e"
                                    border.width: 1
                                    width: szText.implicitWidth + 12

                                    Text {
                                        id: szText
                                        anchors.centerIn: parent
                                        text: activeGame && activeGame.size ? activeGame.size : ""
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#94a3b8"
                                    }
                                }
                            }

                            // Big Hero Title
                            Text {
                                width: parent.width
                                text: activeGame ? activeGame.title : ""
                                font.pixelSize: sidebarView.isNarrow ? 26 : 34
                                font.bold: true
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }

                            // Tagline
                            Text {
                                width: parent.width
                                text: activeGame ? activeGame.tagline : ""
                                font.pixelSize: sidebarView.isNarrow ? 13 : 15
                                font.italic: true
                                color: themeAccent
                                elide: Text.ElideRight
                            }

                            // Action Buttons (Flow wrapping prevents clipping on small widths!)
                            Flow {
                                id: actionButtonsFlow
                                width: parent.width
                                spacing: 10

                                readonly property bool activeHasUpdate: activeGame ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(activeGame.id, activeGame.version || "") : (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.hasGameUpdate ? arcadeBackend.hasGameUpdate(activeGame.id, activeGame.version || "") : false)) : false
                                readonly property bool activeInstalled: activeGame ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(activeGame.id) : (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.isGameInstalled ? arcadeBackend.isGameInstalled(activeGame.id) : true)) : true

                                // Update Button (prominent cyan)
                                Rectangle {
                                    visible: actionButtonsFlow.activeHasUpdate
                                    height: sidebarView.isNarrow ? 38 : 44
                                    width: sidebarView.isNarrow ? 150 : 180
                                    radius: 8
                                    color: sidebarUpdateMouse.containsMouse ? "#38bdf8" : "#0284c7"
                                    border.color: "#38bdf8"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "🔄"; font.pixelSize: sidebarView.isNarrow ? 12 : 14; color: "#f0f9ff" }
                                        Text {
                                            text: "UPDATE (v" + (activeGame ? (activeGame.version || "") : "") + ")"
                                            font.pixelSize: sidebarView.isNarrow ? 11 : 13
                                            font.bold: true
                                            color: "#f0f9ff"
                                        }
                                    }

                                    MouseArea {
                                        id: sidebarUpdateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeGame) {
                                                sidebarView.detailRequested(activeGame);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    height: sidebarView.isNarrow ? 38 : 44
                                    width: sidebarView.isNarrow ? 150 : 180
                                    radius: 8
                                    color: !actionButtonsFlow.activeInstalled ? (sidebarPlayMouse.containsMouse ? "#10b981" : "#059669") : (sidebarPlayMouse.containsMouse ? Qt.lighter(themeAccent, 1.15) : themeAccent)
                                    border.color: !actionButtonsFlow.activeInstalled ? "#34d399" : Qt.lighter(themeAccent, 1.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: !actionButtonsFlow.activeInstalled ? "⬇" : "▶"
                                            font.pixelSize: sidebarView.isNarrow ? 12 : 14
                                            color: !actionButtonsFlow.activeInstalled ? "#ffffff" : "#09090e"
                                        }
                                        Text {
                                            text: !actionButtonsFlow.activeInstalled ? ("GET (" + (activeGame && activeGame.size ? activeGame.size : "") + ")") : "PLAY GAME"
                                            font.pixelSize: sidebarView.isNarrow ? 11 : 13
                                            font.bold: true
                                            color: !actionButtonsFlow.activeInstalled ? "#ffffff" : "#09090e"
                                        }
                                    }

                                    MouseArea {
                                        id: sidebarPlayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeGame) {
                                                if (!actionButtonsFlow.activeInstalled || actionButtonsFlow.activeHasUpdate) {
                                                    sidebarView.detailRequested(activeGame);
                                                } else {
                                                    sidebarView.gameLaunched(activeGame.id);
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    height: sidebarView.isNarrow ? 38 : 44
                                    width: sidebarView.isNarrow ? 120 : 140
                                    radius: 8
                                    color: sidebarInfoMouse.containsMouse ? "#272a3c" : "#1b1d2a"
                                    border.color: "#353950"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "ℹ"; font.pixelSize: 12; color: "#94a3b8" }
                                        Text { text: "Full Details"; font.pixelSize: sidebarView.isNarrow ? 11 : 12; font.bold: true; color: "#cbd5e1" }
                                    }

                                    MouseArea {
                                        id: sidebarInfoMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeGame) sidebarView.detailRequested(activeGame);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // PROFILE BODY DETAILS (Cards with adaptive horizontal padding)
                    Column {
                        width: parent.width - (sidebarView.isNarrow ? 36 : 52)
                        x: sidebarView.isNarrow ? 18 : 26
                        spacing: 16

                        // Synopsis Card
                        Rectangle {
                            width: parent.width
                            implicitHeight: synCol.implicitHeight + 28
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            Column {
                                id: synCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8

                                Text {
                                    text: "ABOUT THIS GAME"
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: themeAccent
                                }

                                Text {
                                    width: parent.width
                                    text: activeGame ? activeGame.description : ""
                                    font.pixelSize: 12
                                    lineHeight: 1.4
                                    color: "#cbd5e1"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // Controls & Keybindings Card (Clean stacked layout so it never clips)
                        Rectangle {
                            width: parent.width
                            implicitHeight: ctrlCol.implicitHeight + 24
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            Column {
                                id: ctrlCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 6

                                Text {
                                    text: "🎮 CONTROLS"
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: themeAccent
                                }

                                Text {
                                    width: parent.width
                                    text: activeGame && activeGame.controls ? (typeof activeGame.controls === "string" ? activeGame.controls : (activeGame.controls.keyboard || activeGame.controls.mouse || "Keyboard & Mouse")) : "Keyboard & Mouse"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#f1f5f9"
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }
                            }
                        }

                        // Metadata Grid Card (Flow wrap prevents any truncation on small screens!)
                        Rectangle {
                            width: parent.width
                            implicitHeight: statsFlow.implicitHeight + 24
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            Flow {
                                id: statsFlow
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: sidebarView.isNarrow ? 14 : 24

                                Column {
                                    spacing: 2
                                    Text { text: "PLATFORM"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "Omarchy Linux Native"; font.pixelSize: 11; font.bold: true; color: "#e2e8f0" }
                                }

                                Column {
                                    spacing: 2
                                    Text { text: "AUDIO ENGINE"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "PySide6 / QAudio (Offline)"; font.pixelSize: 11; font.bold: true; color: "#e2e8f0" }
                                }

                                Column {
                                    spacing: 2
                                    Text { text: "TELEMETRY"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "Zero Tracking / Local Only"; font.pixelSize: 11; font.bold: true; color: "#22c55e" }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 20
                        }
                    }
                }
            }
        }
    }
}
