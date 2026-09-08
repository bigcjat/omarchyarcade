import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: sidebarView
    anchors.fill: parent

    property var games: []
    property int selectedIndex: 0
    property var activeGame: (games && selectedIndex >= 0 && selectedIndex < games.length) ? games[selectedIndex] : null

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
        // 1. LEFT SIDEBAR: Vertical Game Library List
        // =====================================================================
        Rectangle {
            Layout.preferredWidth: 320
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
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        Text {
                            text: "LIBRARY TITLES"
                            font.family: "monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#94a3b8"
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 18
                            radius: 9
                            color: "#1e2232"
                            width: countLabel.implicitWidth + 12

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
                        height: 52
                        color: isSelected ? "#1c1f2e" : (rowMouse.containsMouse ? "#151722" : "transparent")

                        readonly property bool isSelected: index === sidebarView.selectedIndex
                        readonly property bool installed: modelData ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(modelData.id) : true) : true

                        // Left active indicator strip
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3.5
                            color: themeAccent
                            visible: rowItem.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            // 3.5" Disk Icon thumbnail
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 4
                                color: modelData && modelData.floppy_color ? modelData.floppy_color : "#20202a"
                                border.color: "#0a0a0f"
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    fillMode: Image.PreserveAspectFit
                                    source: {
                                        if (!modelData) return "";
                                        if (typeof arcadeBackend !== "undefined" && arcadeBackend.getDiskIconUrl) {
                                            return arcadeBackend.getDiskIconUrl(modelData.id);
                                        }
                                        return "../games/" + modelData.id + "/assets/disk_icon.png";
                                    }
                                }
                            }

                            // Title & Category Subtitle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData ? modelData.title : ""
                                    font.pixelSize: 12
                                    font.bold: rowItem.isSelected
                                    color: rowItem.isSelected ? "#FFFFFF" : (rowMouse.containsMouse ? "#e2e8f0" : "#94a3b8")
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData ? (modelData.category + (modelData.size ? " • " + modelData.size : "")) : ""
                                    font.pixelSize: 10
                                    color: rowItem.isSelected ? themeAccent : "#64748b"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Status dot
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: rowItem.installed ? "#22c55e" : "#f59e0b"
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

            // Empty state if list is empty
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: !activeGame

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
                    spacing: 24

                    // HERO BANNER SECTION (Top)
                    Item {
                        width: parent.width
                        height: 330

                        // Hero Screenshot / Cover background
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            source: {
                                if (!activeGame) return "";
                                if (typeof arcadeBackend !== "undefined" && arcadeBackend.getScreenshotUrl) {
                                    return arcadeBackend.getScreenshotUrl(activeGame.folder);
                                }
                                return "../" + activeGame.folder + "/screenshot.png";
                            }

                            // Vignette / Scanline shader effect
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "#20000000" }
                                    GradientStop { position: 0.5; color: "#800c0d14" }
                                    GradientStop { position: 1.0; color: "#0c0d14" }
                                }
                            }
                        }

                        // Hero Overlay Content
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 28
                            spacing: 12

                            // Tags & Category row (Row ensures badges do not squish!)
                            Row {
                                spacing: 8

                                Rectangle {
                                    height: 22
                                    radius: 4
                                    color: (activeGame && activeGame.grid_color) ? activeGame.grid_color : themeAccent
                                    width: heroCatText.implicitWidth + 14

                                    Text {
                                        id: heroCatText
                                        anchors.centerIn: parent
                                        text: activeGame ? activeGame.category : ""
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#09090e"
                                    }
                                }

                                Rectangle {
                                    height: 22
                                    radius: 4
                                    color: "#181d2a"
                                    border.color: "#2c364e"
                                    border.width: 1
                                    width: yrText.implicitWidth + 14

                                    Text {
                                        id: yrText
                                        anchors.centerIn: parent
                                        text: activeGame && activeGame.release_year ? activeGame.release_year : "2026"
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#94a3b8"
                                    }
                                }

                                Rectangle {
                                    height: 22
                                    radius: 4
                                    color: "#181d2a"
                                    border.color: "#2c364e"
                                    border.width: 1
                                    width: szText.implicitWidth + 14

                                    Text {
                                        id: szText
                                        anchors.centerIn: parent
                                        text: activeGame && activeGame.size ? activeGame.size : ""
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#94a3b8"
                                    }
                                }
                            }

                            // Big Hero Title
                            Text {
                                width: parent.width
                                text: activeGame ? activeGame.title : ""
                                font.pixelSize: 34
                                font.bold: true
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }

                            // Tagline
                            Text {
                                width: parent.width
                                text: activeGame ? activeGame.tagline : ""
                                font.pixelSize: 15
                                font.italic: true
                                color: themeAccent
                                elide: Text.ElideRight
                            }

                            // Big Action Buttons
                            Row {
                                spacing: 14

                                Rectangle {
                                    height: 44
                                    width: 180
                                    radius: 8
                                    color: sidebarPlayMouse.containsMouse ? Qt.lighter(themeAccent, 1.15) : themeAccent
                                    border.color: Qt.lighter(themeAccent, 1.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "▶"; font.pixelSize: 14; color: "#09090e" }
                                        Text { text: "PLAY GAME"; font.pixelSize: 13; font.bold: true; color: "#09090e" }
                                    }

                                    MouseArea {
                                        id: sidebarPlayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeGame) sidebarView.gameLaunched(activeGame.id);
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 44
                                    width: 140
                                    radius: 8
                                    color: sidebarInfoMouse.containsMouse ? "#272a3c" : "#1b1d2a"
                                    border.color: "#353950"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "ℹ"; font.pixelSize: 13; color: "#94a3b8" }
                                        Text { text: "Full Details"; font.pixelSize: 12; font.bold: true; color: "#cbd5e1" }
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

                    // PROFILE BODY DETAILS (Cards with horizontal margins)
                    Column {
                        width: parent.width - 56
                        x: 28
                        spacing: 20

                        // Synopsis Card
                        Rectangle {
                            width: parent.width
                            implicitHeight: synCol.implicitHeight + 32
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            Column {
                                id: synCol
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: "ABOUT THIS GAME"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: themeAccent
                                }

                                Text {
                                    width: parent.width
                                    text: activeGame ? activeGame.description : ""
                                    font.pixelSize: 13
                                    lineHeight: 1.45
                                    color: "#cbd5e1"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // Controls & Keybindings Card
                        Rectangle {
                            width: parent.width
                            implicitHeight: 70
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Text {
                                    text: "CONTROLS"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: themeAccent
                                }

                                Rectangle {
                                    width: 1
                                    Layout.fillHeight: true
                                    color: "#22273a"
                                }

                                Text {
                                    text: activeGame && activeGame.controls ? (typeof activeGame.controls === "string" ? activeGame.controls : (activeGame.controls.keyboard || activeGame.controls.mouse || "Keyboard & Mouse")) : "Keyboard & Mouse"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#f1f5f9"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // Metadata Grid Card
                        Rectangle {
                            width: parent.width
                            implicitHeight: 64
                            radius: 10
                            color: "#12141e"
                            border.color: "#1e2232"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 28

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "PLATFORM"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "Omarchy Linux Native"; font.pixelSize: 11; font.bold: true; color: "#e2e8f0" }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "AUDIO ENGINE"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "PySide6 / QAudio (Offline)"; font.pixelSize: 11; font.bold: true; color: "#e2e8f0" }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "TELEMETRY"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
                                    Text { text: "Zero Tracking / Local Only"; font.pixelSize: 11; font.bold: true; color: "#22c55e" }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 24
                        }
                    }
                }
            }
        }
    }
}
