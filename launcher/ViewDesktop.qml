import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: desktopView
    anchors.fill: parent

    property var games: []
    property int selectedIndex: 0
    property var activeGame: (games && selectedIndex >= 0 && selectedIndex < games.length) ? games[selectedIndex] : null

    signal gameSelected(int index)
    signal gameLaunched(string gameId)
    signal detailRequested(var gameData)

    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && selectedIndex < games.length) {
            ensureVisible(selectedIndex);
        }
    }

    function ensureVisible(index) {
        var cols = Math.max(1, Math.floor((desktopScroll.width - 48 + 16) / (104 + 16)));
        var row = Math.floor(index / cols);
        var itemTop = 24 + row * (120 + 16);
        var itemBottom = itemTop + 120;
        var viewTop = desktopScroll.contentY;
        var viewHeight = desktopScroll.height;

        if (itemTop < viewTop) {
            desktopScroll.contentY = Math.max(0, itemTop - 24);
        } else if (itemBottom > (viewTop + viewHeight)) {
            desktopScroll.contentY = Math.max(0, itemBottom - viewHeight + 24);
        }
    }

    // --- Retro OS Desktop Wallpaper Surface ---
    Rectangle {
        anchors.fill: parent
        color: "#0d0f17"

        // Authentic CRT / Desktop Dot-Matrix Pattern
        Canvas {
            anchors.fill: parent
            opacity: 0.12
            onPaint: {
                var ctx = getContext("2d");
                ctx.fillStyle = "#ffffff";
                for (var x = 8; x < width; x += 16) {
                    for (var y = 8; y < height; y += 16) {
                        ctx.fillRect(x, y, 1.5, 1.5);
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // 1. DESKTOP ICON CANVAS
        // =====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: desktopScroll
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: desktopGrid.height + 60
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                WheelHandler {
                    target: desktopScroll
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        desktopScroll.flick(0, delta * 5);
                    }
                }

                // Dismiss selection on background click
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
                            root.restoreKeyboardFocus();
                        }
                    }
                }

                Flow {
                    id: desktopGrid
                    width: desktopScroll.width - 48
                    x: 24
                    y: 24
                    spacing: 16

                    Repeater {
                        model: desktopView.games

                        Item {
                            id: iconItem
                            width: 104
                            height: 120

                            readonly property bool isSelected: index === desktopView.selectedIndex
                            readonly property bool isHovered: iconMouse.containsMouse
                            readonly property bool installed: modelData ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(modelData.id) : true) : true
                            readonly property bool hasUpdate: modelData ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(modelData.id, modelData.version || "") : (typeof arcadeBackend !== "undefined" && arcadeBackend.hasGameUpdate ? arcadeBackend.hasGameUpdate(modelData.id, modelData.version || "") : false)) : false

                            // Selection Box Highlight
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: iconItem.isSelected ? "#1e293b" : (iconItem.isHovered ? "#151b28" : "transparent")
                                border.color: iconItem.isSelected ? themeAccent : (iconItem.isHovered ? "#334155" : "transparent")
                                border.width: 1
                                opacity: iconItem.isSelected ? 0.95 : (iconItem.isHovered ? 0.6 : 0)
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                width: parent.width - 12

                                // Icon Graphic
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 58
                                    height: 58

                                    // Icon Image
                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: 52
                                        height: 52
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false // Pixel crisp retro icons
                                        source: {
                                            if (!modelData) return "";
                                            if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                                return arcadeBackend.getDiskIconUrl(modelData.id);
                                            }
                                            return "../games/" + modelData.id + "/assets/disk_icon.png";
                                        }
                                    }

                                    // Installed / Update / Get Dot Indicator
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 2
                                        width: (iconItem.hasUpdate || !iconItem.installed) ? 14 : 10
                                        height: (iconItem.hasUpdate || !iconItem.installed) ? 14 : 10
                                        radius: (iconItem.hasUpdate || !iconItem.installed) ? 3 : 5
                                        color: iconItem.hasUpdate ? "#0284c7" : (iconItem.installed ? "#22c55e" : "#065f46")
                                        border.color: iconItem.hasUpdate ? "#38bdf8" : (iconItem.installed ? "#0a0a0f" : "#34d399")
                                        border.width: 1.5

                                        Text {
                                            anchors.centerIn: parent
                                            visible: iconItem.hasUpdate || !iconItem.installed
                                            text: iconItem.hasUpdate ? "🔄" : "⬇"
                                            font.pixelSize: 8
                                            color: "#FFFFFF"
                                        }
                                    }
                                }

                                // Desktop Icon Label
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: labelText.implicitHeight + 4
                                    radius: 3
                                    color: iconItem.isSelected ? themeAccent : "transparent"

                                    Text {
                                        id: labelText
                                        anchors.centerIn: parent
                                        width: parent.width - 4
                                        text: modelData ? modelData.title : ""
                                        font.pixelSize: 11
                                        font.bold: iconItem.isSelected
                                        color: iconItem.isSelected ? "#09090e" : (iconItem.isHovered ? "#FFFFFF" : "#e2e8f0")
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            MouseArea {
                                id: iconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    desktopView.gameSelected(index);
                                    if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
                                        root.restoreKeyboardFocus();
                                    }
                                }
                                onDoubleClicked: {
                                    desktopView.gameSelected(index);
                                    if (modelData) {
                                        desktopView.gameLaunched(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. DESKTOP STATUS & PREVIEW DOCK (Bottom Bar)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#111420"
            border.color: "#222738"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16

                // Mini thumbnail of active game
                Rectangle {
                    width: 30
                    height: 30
                    radius: 4
                    color: "#1a1f2e"
                    clip: true
                    visible: !!activeGame

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: {
                            if (!activeGame) return "";
                            if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                return arcadeBackend.getDiskIconUrl(activeGame.id);
                            }
                            return "../games/" + activeGame.id + "/assets/disk_icon.png";
                        }
                    }
                }

                // Active Game Summary
                Text {
                    text: activeGame ? (activeGame.title + " • " + activeGame.category + " • " + (activeGame.size || "")) : "Select an icon"
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#f1f5f9"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Quick Launch & Info Action Buttons
                RowLayout {
                    spacing: 8
                    visible: !!activeGame

                    Rectangle {
                        height: 28
                        width: 74
                        radius: 4
                        color: "#1c2235"
                        border.color: "#353f5c"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Details [Space]"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#94a3b8"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activeGame) desktopView.detailRequested(activeGame);
                            }
                        }
                    }

                    Rectangle {
                        id: taskbarPlayBtn
                        readonly property bool activeInstalled: activeGame ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(activeGame.id) : true) : true
                        readonly property bool activeHasUpdate: activeGame ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(activeGame.id, activeGame.version || "") : false) : false

                        height: 28
                        width: Math.max(90, taskbarBtnText.implicitWidth + 16)
                        radius: 4
                        color: taskbarPlayBtn.activeHasUpdate ? "#0284c7" : (taskbarPlayBtn.activeInstalled ? themeAccent : "#059669")
                        border.color: taskbarPlayBtn.activeHasUpdate ? "#38bdf8" : (taskbarPlayBtn.activeInstalled ? Qt.lighter(themeAccent, 1.3) : "#34d399")
                        border.width: 1

                        Text {
                            id: taskbarBtnText
                            anchors.centerIn: parent
                            text: taskbarPlayBtn.activeHasUpdate ? "🔄 Update [Enter]" : (taskbarPlayBtn.activeInstalled ? "▶ Play [Enter]" : ("⬇ Get (" + (activeGame && activeGame.size ? activeGame.size : "") + ") [Enter]"))
                            font.pixelSize: 11
                            font.bold: true
                            color: (taskbarPlayBtn.activeHasUpdate || !taskbarPlayBtn.activeInstalled) ? "#FFFFFF" : "#09090e"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activeGame) {
                                    if (!taskbarPlayBtn.activeInstalled || taskbarPlayBtn.activeHasUpdate) {
                                        desktopView.detailRequested(activeGame);
                                    } else {
                                        desktopView.gameLaunched(activeGame.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
