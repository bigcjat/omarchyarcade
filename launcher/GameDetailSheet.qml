import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: detailSheet
    anchors.fill: parent
    color: "#e60a0a10"
    z: 200
    visible: opacity > 0
    opacity: 0

    property var gameData: null
    readonly property bool isUnreleased: gameData && gameData.status === "unreleased"
    property bool isInstalled: true
    property bool hasUpdate: false
    property bool isDownloading: false
    property bool confirmingUninstall: false

    Timer {
        id: confirmTimer
        interval: 3500
        onTriggered: detailSheet.confirmingUninstall = false
    }

    property var favoritesList: []

    signal playRequested(string gameId)
    signal closeRequested()

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    Connections {
        target: (typeof arcadeBackend !== "undefined") ? arcadeBackend : null
        function onGameInstalled(gameId) {
            if (gameData && gameData.id === gameId) {
                detailSheet.isDownloading = false;
                detailSheet.isInstalled = true;
                detailSheet.hasUpdate = false;
                detailSheet.confirmingUninstall = false;
            }
        }
        function onGameUninstalled(gameId) {
            if (gameData && gameData.id === gameId) {
                detailSheet.isDownloading = false;
                detailSheet.isInstalled = false;
                detailSheet.hasUpdate = false;
                detailSheet.confirmingUninstall = false;
            }
        }
        function onFavoritesChanged(favs) {
            detailSheet.favoritesList = favs;
        }
    }

    function open(data) {
        gameData = data;
        isDownloading = false;
        confirmingUninstall = false;
        confirmTimer.stop();
        if (typeof arcadeBackend !== "undefined" && data) {
            isInstalled = arcadeBackend.isGameInstalled(data.id);
            hasUpdate = arcadeBackend.hasGameUpdate(data.id, data.version || "");
            if (arcadeBackend.getFavorites) {
                favoritesList = arcadeBackend.getFavorites();
            }
        } else {
            isInstalled = true;
            hasUpdate = false;
        }
        opacity = 1;
        modalScroll.ScrollBar.vertical.position = 0;
        contentBox.forceActiveFocus();
    }

    function close() {
        confirmingUninstall = false;
        confirmTimer.stop();
        opacity = 0;
        closeRequested();
        if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
            root.restoreKeyboardFocus();
        } else if (typeof root !== "undefined" && root.forceActiveFocus) {
            root.forceActiveFocus();
        }
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: detailSheet.close()
    }

    // Modal Box Container
    Rectangle {
        id: contentBox
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 840)
        height: Math.min(parent.height - 24, 600)
        radius: 12
        color: "#181822"
        border.color: gameData ? Qt.alpha(gameData.grid_color, 0.6) : "#334155"
        border.width: 1.5
        clip: true

        readonly property bool isNarrow: width < 620

        // Trap mouse clicks inside content box
        MouseArea { anchors.fill: parent }


        // Close button (Top-Right)
        Rectangle {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 32
            height: 32
            radius: 16
            color: closeMouse.containsMouse ? "#334155" : "#22222e"
            z: 30

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 14
                font.bold: true
                color: closeMouse.containsMouse ? "#FFFFFF" : "#94a3b8"
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: detailSheet.close()
            }
        }

        // Continuous unbroken outer border overlay (z: 100 ensures border is never obscured)
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.color: gameData ? Qt.alpha(gameData.grid_color, 0.7) : "#334155"
            border.width: 1.5
            z: 100
        }

        // Pinned Action Footer Bar (Always visible at bottom, never pushed off)
        Rectangle {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 1.5
            anchors.leftMargin: 1.5
            anchors.rightMargin: 1.5
            height: 56
            radius: 11
            color: "#13131c"
            z: 20

            // Fill top corners square so only bottom corners are rounded
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 14
                color: "#13131c"
            }

            // Top divider line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#252538"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                // Keyboard shortcut hints on the left
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                    visible: contentBox.width >= 560

                    Rectangle {
                        width: escText.implicitWidth + 12
                        height: 22
                        radius: 4
                        color: "#1a1a26"
                        border.color: "#2e2e42"
                        border.width: 1
                        Text {
                            id: escText
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#94a3b8"
                        }
                    }
                    Text {
                        text: "Close"
                        font.pixelSize: 11
                        color: "#64748b"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 6; height: 1 }

                    Rectangle {
                        width: enterText.implicitWidth + 12
                        height: 22
                        radius: 4
                        color: "#1a1a26"
                        border.color: "#2e2e42"
                        border.width: 1
                        visible: !detailSheet.isUnreleased
                        Text {
                            id: enterText
                            anchors.centerIn: parent
                            text: "↵ ENTER"
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#94a3b8"
                        }
                    }
                    Text {
                        text: "Launch"
                        font.pixelSize: 11
                        color: "#64748b"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !detailSheet.isUnreleased
                    }
                }

                Item { Layout.fillWidth: true }

                // Uninstall Button (Only visible when game is installed and not unreleased)
                Rectangle {
                    id: uninstallBtn
                    visible: detailSheet.isInstalled && !detailSheet.isUnreleased && !detailSheet.isDownloading
                    Layout.preferredWidth: detailSheet.confirmingUninstall ? 114 : 96
                    Layout.preferredHeight: 38
                    radius: 6
                    clip: true

                    color: detailSheet.confirmingUninstall ? 
                           (uninstallMouse.pressed ? "#7f1d1d" : (uninstallMouse.containsMouse ? "#991b1b" : "#450a0a")) :
                           (uninstallMouse.pressed ? "#231518" : (uninstallMouse.containsMouse ? "#2f1920" : "#1a161e"))
                    border.color: detailSheet.confirmingUninstall ? "#ef4444" : (uninstallMouse.containsMouse ? "#f87171" : "#4a242f")
                    border.width: 1

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Item {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: detailSheet.confirmingUninstall ? "⚠️" : "🗑️"
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            text: detailSheet.confirmingUninstall ? "Confirm?" : "Uninstall"
                            font.family: "monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: detailSheet.confirmingUninstall ? "#fee2e2" : (uninstallMouse.containsMouse ? "#fca5a5" : "#f87171")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: uninstallMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!detailSheet.confirmingUninstall) {
                                detailSheet.confirmingUninstall = true;
                                confirmTimer.restart();
                            } else {
                                detailSheet.confirmingUninstall = false;
                                confirmTimer.stop();
                                if (gameData && typeof arcadeBackend !== "undefined" && arcadeBackend.uninstallGame) {
                                    arcadeBackend.uninstallGame(gameData.id);
                                }
                            }
                        }
                    }
                }

                // Favorite / Pin to Desktop Button
                Rectangle {
                    id: footerFavBtn
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: favRow.implicitWidth + 24
                    radius: 6
                    readonly property bool isFav: gameData ? (detailSheet.favoritesList.indexOf(gameData.id) !== -1) : false
                    color: isFav ? (favMouse.containsMouse ? "#45122a" : "#2d0f1e") : (favMouse.containsMouse ? "#262638" : "#1a1a26")
                    border.color: isFav ? "#f43f5e" : (favMouse.containsMouse ? "#474760" : "#2e2e40")
                    border.width: 1

                    Row {
                        id: favRow
                        anchors.centerIn: parent
                        spacing: 7
                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: footerFavBtn.isFav ? "❤️" : "🤍"
                                font.pixelSize: 12
                            }
                        }
                        Text {
                            text: footerFavBtn.isFav ? "Favorited" : "Favorite"
                            font.pixelSize: 12
                            font.bold: true
                            color: footerFavBtn.isFav ? "#fb7185" : (favMouse.containsMouse ? "#FFFFFF" : "#94a3b8")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: favMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (gameData && typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.toggleFavorite) {
                                arcadeBackend.toggleFavorite(gameData.id);
                            }
                        }
                    }
                }

                // Secondary Close Button
                Rectangle {
                    id: closeGhostBtn
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 38
                    radius: 6
                    color: footerCloseMouse.pressed ? "#161622" : (footerCloseMouse.containsMouse ? "#262638" : "#1a1a26")
                    border.color: footerCloseMouse.containsMouse ? "#474760" : "#2e2e40"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        font.pixelSize: 12
                        font.bold: true
                        color: footerCloseMouse.containsMouse ? "#FFFFFF" : "#94a3b8"
                    }

                    MouseArea {
                        id: footerCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detailSheet.close()
                    }
                }

                // Primary Action Button (Play Now / Update / Install / Coming Soon)
                Rectangle {
                    id: primaryActionBtn
                    Layout.preferredWidth: detailSheet.isUnreleased ? 200 : (detailSheet.isDownloading ? 180 : (detailSheet.hasUpdate ? 185 : (detailSheet.isInstalled ? 150 : 210)))
                    Layout.preferredHeight: 38
                    radius: 6
                    clip: true

                    readonly property color accentCol: detailSheet.isUnreleased ? "#d97706" : (detailSheet.isDownloading ? "#0284c7" : (detailSheet.hasUpdate ? "#00f0ff" : (detailSheet.isInstalled ? (gameData ? gameData.grid_color : "#10b981") : "#3b82f6")))
                    readonly property bool isHovered: actionMouse.containsMouse && !detailSheet.isUnreleased && !detailSheet.isDownloading
                    readonly property bool isPressed: actionMouse.pressed && !detailSheet.isUnreleased && !detailSheet.isDownloading

                    color: detailSheet.isUnreleased ? "#1c1917" : (isPressed ? Qt.darker(accentCol, 1.4) : (isHovered ? Qt.darker(accentCol, 1.1) : Qt.darker(accentCol, 1.25)))
                    border.color: detailSheet.isUnreleased ? "#78350f" : (isHovered ? "#FFFFFF" : accentCol)
                    border.width: 1.5

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: detailSheet.isUnreleased ? "#451a03" : Qt.lighter(primaryActionBtn.accentCol, 1.5)
                        opacity: 0.6
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: detailSheet.isUnreleased ? "🔒" : (detailSheet.isDownloading ? "⏳" : (detailSheet.hasUpdate ? "🔄" : (detailSheet.isInstalled ? "▶" : "⬇")))
                                font.pixelSize: 12
                                color: detailSheet.isUnreleased ? "#f59e0b" : "#FFFFFF"
                            }
                        }

                        Text {
                            text: detailSheet.isUnreleased ? "COMING SOON" : (detailSheet.isDownloading ? "UPDATING..." : (detailSheet.hasUpdate ? ("UPDATE (v" + (gameData ? gameData.version : "") + ")") : (detailSheet.isInstalled ? "PLAY NOW" : ("GET (" + (gameData ? gameData.size : "") + ")"))))
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 1
                            color: detailSheet.isUnreleased ? "#f59e0b" : "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: !detailSheet.isUnreleased && !detailSheet.isDownloading
                        cursorShape: (detailSheet.isUnreleased || detailSheet.isDownloading) ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!detailSheet.isUnreleased && !detailSheet.isDownloading && gameData) {
                                if (detailSheet.hasUpdate || !detailSheet.isInstalled) {
                                    detailSheet.isDownloading = true;
                                    if (typeof arcadeBackend !== "undefined") {
                                        arcadeBackend.installGame(gameData.id);
                                    }
                                } else {
                                    detailSheet.playRequested(gameData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Entire Modal Body in a Unified ScrollView
        ScrollView {
            id: modalScroll
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footerBar.top
            clip: true
            contentWidth: modalScroll.width
            contentHeight: bodyWrapper.implicitHeight + 48
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Item {
                width: modalScroll.width
                implicitHeight: bodyWrapper.implicitHeight + 48

                Item {
                    id: bodyWrapper
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    implicitHeight: contentLayout.implicitHeight

                    // Responsive 2-column or 1-column layout
                    GridLayout {
                        id: contentLayout
                        width: parent.width
                        columns: contentBox.isNarrow ? 1 : 2
                        columnSpacing: 24
                        rowSpacing: 20

                        // 1. Screenshot Frame
                        Item {
                            Layout.preferredWidth: contentBox.isNarrow ? Math.min(360, parent.width) : Math.min(320, contentBox.width * 0.40)
                            Layout.preferredHeight: Math.min(Layout.preferredWidth * 1.25, 380)
                            Layout.alignment: contentBox.isNarrow ? Qt.AlignHCenter : Qt.AlignTop

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "#0c0c14"
                                border.color: gameData ? Qt.alpha(gameData.grid_color, 0.45) : "#334155"
                                border.width: 1.5
                                clip: true

                                // Continuous unbroken outer border overlay (z: 30 ensures top/bottom borders are never obscured)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: "transparent"
                                    border.color: gameData ? Qt.alpha(gameData.grid_color, 0.65) : "#334155"
                                    border.width: 1.5
                                    z: 30
                                }

                                // Header bar on monitor bezel
                                Rectangle {
                                    id: screenHeader
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 1.5
                                    anchors.leftMargin: 1.5
                                    anchors.rightMargin: 1.5
                                    height: 24
                                    radius: 9
                                    color: "#14141e"
                                    z: 5

                                    // Square off bottom corners
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 8
                                        color: "#14141e"
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: isUnreleased ? "#f59e0b" : "#22c55e"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isUnreleased ? "UNRELEASED PREVIEW" : "ACTUAL GAMEPLAY"
                                            font.family: "monospace"
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: isUnreleased ? "#fbbf24" : "#94a3b8"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "NATIVE QML"
                                        font.family: "monospace"
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: "#64748b"
                                    }
                                }

                                // Gameplay Screenshot Image
                                AnimatedImage {
                                    id: gameImg
                                    anchors.top: screenHeader.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    source: {
                                        if (typeof arcadeBackend !== "undefined" && arcadeBackend && gameData && gameData.folder) {
                                            var url = arcadeBackend.getScreenshotUrl(gameData.folder);
                                            if (url) return url;
                                        }
                                        return gameData ? ("../" + gameData.folder + "/screenshot.png") : "";
                                    }
                                    onStatusChanged: {
                                        if (status === AnimatedImage.Error && source.toString().indexOf("http") === 0) {
                                            if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getFallbackScreenshotUrl) {
                                                var fb = arcadeBackend.getFallbackScreenshotUrl(gameData ? gameData.folder : "");
                                                if (fb) source = fb;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#12121a"
                                        visible: gameImg.status === Image.Loading || gameImg.status === Image.Error

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "🎮"
                                                font.pixelSize: 24
                                                opacity: 0.5
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: gameImg.status === Image.Error ? "Gameplay Preview" : "Loading..."
                                                font.family: "monospace"
                                                font.pixelSize: 10
                                                color: "#64748b"
                                            }
                                        }
                                    }
                                }

                                // CRT scanlines
                                Canvas {
                                    anchors.fill: parent
                                    opacity: 0.06
                                    z: 6
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.fillStyle = "#000000";
                                        for (var y = 0; y < height; y += 4) {
                                            ctx.fillRect(0, y, width, 1.5);
                                        }
                                    }
                                }

                                // Unreleased "COMING SOON" overlay ribbon
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#99090912"
                                    visible: isUnreleased
                                    z: 8

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.82
                                        height: 36
                                        radius: 6
                                        color: "#f59e0b"
                                        border.color: "#d97706"
                                        border.width: 1.5
                                        rotation: -8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "COMING SOON"
                                            font.family: "monospace"
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.letterSpacing: 1
                                            color: "#18181b"
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Right: Game Info & Instructions
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 12

                            // Category badge & Ref
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    height: 22
                                    radius: 4
                                    Layout.preferredWidth: catText.implicitWidth + 14
                                    color: gameData ? Qt.alpha(gameData.grid_color, 0.25) : "#334155"
                                    border.color: gameData ? gameData.grid_color : "#475569"
                                    border.width: 1

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: gameData ? gameData.category.toUpperCase() : ""
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }

                                Rectangle {
                                    height: 22
                                    radius: 4
                                    Layout.preferredWidth: refText.implicitWidth + 14
                                    color: "#22222e"
                                    border.color: "#383848"
                                    border.width: 1

                                    Text {
                                        id: refText
                                        anchors.centerIn: parent
                                        text: gameData ? gameData.ref : ""
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#94a3b8"
                                    }
                                }

                                // Version Badge
                                Rectangle {
                                    height: 22
                                    radius: 4
                                    Layout.preferredWidth: verBadgeRow.implicitWidth + 14
                                    color: "#161926"
                                    border.color: "#3b4261"
                                    border.width: 1
                                    visible: Boolean(gameData && gameData.version)

                                    Row {
                                        id: verBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            text: (gameData && gameData.version) ? ("v" + gameData.version) : ""
                                            font.family: "monospace"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#93c5fd"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // Size Badge
                                Rectangle {
                                    height: 22
                                    radius: 4
                                    Layout.preferredWidth: sizeBadgeRow.implicitWidth + 16
                                    color: "#161e2e"
                                    border.color: "#38bdf8"
                                    border.width: 1
                                    visible: Boolean(gameData && gameData.size)

                                    Row {
                                        id: sizeBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: "💾"
                                            font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: (gameData && gameData.size) ? (gameData.size + " Install") : ""
                                            font.family: "monospace"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#38bdf8"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Title
                            Text {
                                text: gameData ? gameData.title : ""
                                font.pixelSize: 26
                                font.bold: true
                                color: "#FFFFFF"
                            }

                            // Tagline
                            Text {
                                text: gameData ? gameData.tagline : ""
                                font.pixelSize: 13
                                font.italic: true
                                color: "#94a3b8"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            // Description
                            Text {
                                text: gameData ? gameData.description : ""
                                font.pixelSize: 12
                                lineHeight: 1.35
                                color: "#cbd5e1"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            // What's New In This Update Card (Shown only when update is available)
                            Rectangle {
                                Layout.fillWidth: true
                                visible: detailSheet.hasUpdate && Boolean(gameData && gameData.changelog && gameData.changelog.length > 0)
                                implicitHeight: changelogCol.implicitHeight + 24
                                radius: 8
                                color: "#0c1824"
                                border.color: "#00f0ff"
                                border.width: 1.5

                                ColumnLayout {
                                    id: changelogCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 8

                                    RowLayout {
                                        spacing: 8
                                        Item {
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            Layout.alignment: Qt.AlignVCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "🔄"
                                                font.pixelSize: 13
                                            }
                                        }
                                        Text {
                                            text: "WHAT'S NEW IN v" + (gameData ? gameData.version : "")
                                            font.family: "monospace"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#00f0ff"
                                            font.letterSpacing: 1
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    Repeater {
                                        model: (gameData && gameData.changelog) ? gameData.changelog : []
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "★"
                                                font.pixelSize: 10
                                                color: "#38bdf8"
                                                Layout.alignment: Qt.AlignTop
                                            }
                                            Text {
                                                text: modelData
                                                font.pixelSize: 11
                                                lineHeight: 1.3
                                                color: "#f1f5f9"
                                                wrapMode: Text.WordWrap
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }

                            // How to Play & Controls Card (Naturally expanded, NO nested scroll trap!)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: instructionsCol.implicitHeight + 28
                                radius: 8
                                color: "#121218"
                                border.color: "#242432"
                                border.width: 1

                                ColumnLayout {
                                    id: instructionsCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 8

                                    Text {
                                        text: "HOW TO PLAY"
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#94a3b8"
                                        font.letterSpacing: 1
                                    }

                                    Repeater {
                                        model: gameData ? gameData.instructions : []
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "•"
                                                color: gameData ? gameData.grid_color : "#38bdf8"
                                                font.bold: true
                                                Layout.alignment: Qt.AlignTop
                                            }
                                            Text {
                                                text: modelData
                                                font.pixelSize: 12
                                                lineHeight: 1.25
                                                color: "#e2e8f0"
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    Item { height: 4 }

                                    Text {
                                        text: "CONTROLS"
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#94a3b8"
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        text: gameData && gameData.controls ? (gameData.controls.keyboard || gameData.controls.mouse || "") : ""
                                        font.pixelSize: 11
                                        lineHeight: 1.25
                                        color: "#cbd5e1"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Keyboard Shortcuts
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_Backspace) {
            detailSheet.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_P) {
            if (!detailSheet.isUnreleased && gameData) {
                detailSheet.playRequested(gameData.id);
                event.accepted = true;
            }
        }
    }
}
