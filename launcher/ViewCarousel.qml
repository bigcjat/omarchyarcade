import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: carouselView
    anchors.fill: parent

    property var games: []
    property int selectedIndex: 0
    property var activeGame: (games && selectedIndex >= 0 && selectedIndex < games.length) ? games[selectedIndex] : null

    signal gameSelected(int index)
    signal gameLaunched(string gameId)
    signal detailRequested(var gameData)

    onSelectedIndexChanged: {
        if (carouselList.currentIndex !== selectedIndex && selectedIndex >= 0 && selectedIndex < games.length) {
            carouselList.currentIndex = selectedIndex;
            carouselList.positionViewAtIndex(selectedIndex, ListView.Center);
        }
    }

    onGamesChanged: {
        if (selectedIndex >= games.length) {
            selectedIndex = Math.max(0, games.length - 1);
        }
    }

    // --- Ambient Glow Background ---
    Rectangle {
        anchors.fill: parent
        color: "#0c0c11"

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.9
            height: parent.height * 0.8
            radius: 200
            color: activeGame && activeGame.floppy_color ? activeGame.floppy_color : themeAccent
            opacity: 0.08
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // 1. MAIN STAGE (Top 68%): Hero Screenshot & Rich Details
        // =====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 320

            // Empty state if no games match filter
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: !activeGame && games && games.length > 0

                Text {
                    text: "💾"
                    font.pixelSize: 42
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "No games to showcase in this category"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#94a3b8"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 32
                visible: !!activeGame

                // Left: Large Screenshot / Cover Showcase Card
                Rectangle {
                    Layout.preferredWidth: Math.min(parent.width * 0.44, 480)
                    Layout.fillHeight: true
                    radius: 12
                    color: "#161622"
                    border.color: (activeGame && activeGame.floppy_color) ? activeGame.floppy_color : themeAccent
                    border.width: 1.5
                    clip: true

                    // Screenshot Image
                    AnimatedImage {
                        id: heroScreenshot
                        anchors.fill: parent
                        anchors.margins: 6
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

                        // Subtle CRT scanline overlay
                        Rectangle {
                            anchors.fill: parent
                            opacity: 0.15
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: "#000000" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    // Bottom gradient bar on screenshot with category
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 52
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#0d0d16" }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.bottomMargin: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                height: 22
                                radius: 4
                                color: (activeGame && activeGame.grid_color) ? activeGame.grid_color : themeAccent
                                width: catText.implicitWidth + 14
                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: activeGame ? activeGame.category : ""
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#0a0a10"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: activeGame && activeGame.version ? ("v" + activeGame.version) : ""
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#93c5fd"
                                visible: Boolean(activeGame && activeGame.version)
                            }

                            Text {
                                text: activeGame && activeGame.size ? activeGame.size : ""
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#94a3b8"
                            }
                        }
                    }
                }

                // Right: Detailed Info, Description, Action Buttons
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Title Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: activeGame ? activeGame.title : ""
                            font.pixelSize: 26
                            font.bold: true
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Installed badge
                        Rectangle {
                            readonly property bool installed: activeGame ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(activeGame.id) : true) : false
                            width: instLabel.implicitWidth + 14
                            height: 22
                            radius: 11
                            color: installed ? "#103522" : "#2d2010"
                            border.color: installed ? "#22c55e" : "#f59e0b"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: parent.parent.installed ? "●" : "○"
                                    font.pixelSize: 8
                                    color: parent.parent.installed ? "#22c55e" : "#f59e0b"
                                }
                                Text {
                                    id: instLabel
                                    text: parent.parent.installed ? "INSTALLED" : "DOWNLOADABLE"
                                    font.family: "monospace"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: parent.parent.installed ? "#4ade80" : "#fbbf24"
                                }
                            }
                        }
                    }

                    // Tagline
                    Text {
                        text: activeGame ? activeGame.tagline : ""
                        font.pixelSize: 14
                        font.italic: true
                        color: "#94a3b8"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Full Description
                    Text {
                        text: activeGame ? activeGame.description : ""
                        font.pixelSize: 13
                        lineHeight: 1.35
                        color: "#cbd5e1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.maximumHeight: 90
                        elide: Text.ElideRight
                    }

                    // Controls summary badge box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: "#161622"
                        border.color: "#28283a"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "🎮"
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                text: "CONTROLS:"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#94a3b8"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: activeGame && activeGame.controls ? (typeof activeGame.controls === "string" ? activeGame.controls : (activeGame.controls.keyboard || activeGame.controls.mouse || "Keyboard & Mouse")) : "Keyboard & Mouse"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#f1f5f9"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        // Primary Play / Launch Button
                        Rectangle {
                            id: playBtn
                            readonly property bool isActiveInstalled: activeGame ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(activeGame.id) : false) : false
                            readonly property bool isActiveHasUpdate: activeGame ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(activeGame.id, activeGame.version || "") : false) : false

                            height: 44
                            Layout.fillWidth: true
                            Layout.maximumWidth: 260
                            radius: 8
                            color: isActiveHasUpdate ? (playMouse.containsMouse ? "#38bdf8" : "#0284c7") : (isActiveInstalled ? (playMouse.containsMouse ? Qt.lighter(themeAccent, 1.15) : themeAccent) : (playMouse.containsMouse ? "#10b981" : "#059669"))
                            border.color: isActiveHasUpdate ? "#7dd3fc" : (isActiveInstalled ? Qt.lighter(themeAccent, 1.4) : "#34d399")
                            border.width: 1
                            scale: playMouse.pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Item {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: playBtn.isActiveHasUpdate ? "🔄" : (playBtn.isActiveInstalled ? "▶" : "⬇")
                                        font.pixelSize: 14
                                        color: (playBtn.isActiveHasUpdate || !playBtn.isActiveInstalled) ? "#FFFFFF" : "#0a0a10"
                                    }
                                }
                                Text {
                                    text: playBtn.isActiveHasUpdate ? "UPDATE GAME" : (playBtn.isActiveInstalled ? "PLAY GAME" : ("GET (" + (activeGame && activeGame.size ? activeGame.size : "") + ")"))
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                    color: (playBtn.isActiveHasUpdate || !playBtn.isActiveInstalled) ? "#FFFFFF" : "#0a0a10"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: "[Enter]"
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    color: (playBtn.isActiveHasUpdate || !playBtn.isActiveInstalled) ? "#e2e8f0" : "#1e293b"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (activeGame) {
                                        if (!playBtn.isActiveInstalled || playBtn.isActiveHasUpdate) {
                                            carouselView.detailRequested(activeGame);
                                        } else {
                                            carouselView.gameLaunched(activeGame.id);
                                        }
                                    }
                                }
                            }
                        }

                        // Details Modal Button
                        Rectangle {
                            height: 44
                            Layout.preferredWidth: 150
                            radius: 8
                            color: detailMouse.containsMouse ? "#262638" : "#1a1a24"
                            border.color: detailMouse.containsMouse ? "#4b4b66" : "#303042"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Item {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "ℹ"
                                        font.pixelSize: 13
                                        color: "#94a3b8"
                                    }
                                }
                                Text {
                                    text: "Full Details"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: detailMouse.containsMouse ? "#FFFFFF" : "#cbd5e1"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: detailMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (activeGame) {
                                        carouselView.detailRequested(activeGame);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. BOTTOM CAROUSEL SHELF (Bottom 32%)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            color: "#0e0e16"
            border.color: "#1f1f2e"
            border.width: 1

            // Shelf metallic rail header line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: themeAccent }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Left arrow button
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 54
                radius: 6
                color: leftArrowMouse.containsMouse ? "#252538" : "#161622"
                border.color: leftArrowMouse.containsMouse ? themeAccent : "#2d2d3e"
                border.width: 1
                z: 20

                Text {
                    anchors.centerIn: parent
                    text: "◀"
                    font.pixelSize: 14
                    color: leftArrowMouse.containsMouse ? themeAccent : "#94a3b8"
                }

                MouseArea {
                    id: leftArrowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (carouselView.selectedIndex > 0) {
                            carouselView.gameSelected(carouselView.selectedIndex - 1);
                        } else if (games.length > 0) {
                            carouselView.gameSelected(games.length - 1);
                        }
                    }
                }
            }

            // Right arrow button
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 54
                radius: 6
                color: rightArrowMouse.containsMouse ? "#252538" : "#161622"
                border.color: rightArrowMouse.containsMouse ? themeAccent : "#2d2d3e"
                border.width: 1
                z: 20

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    font.pixelSize: 14
                    color: rightArrowMouse.containsMouse ? themeAccent : "#94a3b8"
                }

                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (carouselView.selectedIndex < games.length - 1) {
                            carouselView.gameSelected(carouselView.selectedIndex + 1);
                        } else if (games.length > 0) {
                            carouselView.gameSelected(0);
                        }
                    }
                }
            }

            // Horizontal Carousel Track
            ListView {
                id: carouselList
                anchors.fill: parent
                anchors.leftMargin: 48
                anchors.rightMargin: 48
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                snapMode: ListView.SnapToItem
                model: carouselView.games
                currentIndex: carouselView.selectedIndex

                WheelHandler {
                    target: carouselList
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        if (delta < 0) {
                            if (carouselView.selectedIndex < games.length - 1) {
                                carouselView.gameSelected(carouselView.selectedIndex + 1);
                            }
                        } else if (delta > 0) {
                            if (carouselView.selectedIndex > 0) {
                                carouselView.gameSelected(carouselView.selectedIndex - 1);
                            }
                        }
                    }
                }

                delegate: Item {
                    id: diskItem
                    width: 120
                    height: 165
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    readonly property bool isCurrent: index === carouselView.selectedIndex
                    readonly property bool isHovered: diskMouse.containsMouse

                    // Elevate and scale selected disk
                    y: isCurrent ? -12 : (isHovered ? -6 : 0)
                    scale: isCurrent ? 1.08 : (isHovered ? 1.02 : 0.94)
                    opacity: isCurrent ? 1.0 : (isHovered ? 0.9 : 0.65)

                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Neon highlight halo behind active disk
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 8
                        color: "transparent"
                        border.color: (modelData && modelData.floppy_color) ? modelData.floppy_color : themeAccent
                        border.width: diskItem.isCurrent ? 2.5 : 1
                        visible: diskItem.isCurrent || diskItem.isHovered
                    }

                    // Floppy Disk Body
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: modelData && modelData.floppy_color ? modelData.floppy_color : "#23232a"
                        border.color: "#121218"
                        border.width: 1.5
                        clip: true

                        // Top metal shutter
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.65
                            height: 36
                            color: "#8a8f98"
                            border.color: "#555b64"
                            border.width: 1
                            radius: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 14
                                height: 22
                                color: "#25272b"
                                radius: 2
                            }
                        }

                        // Disk Sticker Label
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 44
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 12
                            height: 98
                            radius: 4
                            color: "#FFFFFF"
                            clip: true

                            // Header stripe on label
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 16
                                color: modelData && modelData.grid_color ? modelData.grid_color : themeAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData ? modelData.category : ""
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: "#0a0a10"
                                    elide: Text.ElideRight
                                    width: parent.width - 4
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // Disk Thumbnail Cover Art
                            Image {
                                anchors.top: parent.top
                                anchors.topMargin: 18
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 3
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                source: {
                                    if (!modelData) return "";
                                    if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getCoverUrl) {
                                        return arcadeBackend.getCoverUrl(modelData.id);
                                    }
                                    return "../assets/covers/" + modelData.id + ".png";
                                }
                            }
                        }

                        // Bottom Title Bar
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 20
                            color: "#0f0f15"

                            Text {
                                anchors.centerIn: parent
                                text: modelData ? modelData.title : ""
                                font.pixelSize: 9
                                font.bold: true
                                color: diskItem.isCurrent ? themeAccent : "#e2e8f0"
                                elide: Text.ElideRight
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    MouseArea {
                        id: diskMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            carouselView.gameSelected(index);
                        }
                        onDoubleClicked: {
                            carouselView.gameSelected(index);
                            if (modelData) {
                                carouselView.gameLaunched(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
