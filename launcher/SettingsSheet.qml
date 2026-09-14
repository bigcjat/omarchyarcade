import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsSheet
    property bool isDarkMode: (typeof arcadeBackend !== "undefined" && arcadeBackend.isDarkMode !== undefined) ? arcadeBackend.isDarkMode : true
    property color themeBackground: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeBackground) ? arcadeBackend.themeColors.themeBackground : (isDarkMode ? "#111116" : "#eff1f5")
    property color themeSurface: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeSurface) ? arcadeBackend.themeColors.themeSurface : (isDarkMode ? "#181822" : "#ffffff")
    property color themeSurfaceLight: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeSurfaceLight) ? arcadeBackend.themeColors.themeSurfaceLight : (isDarkMode ? "#222230" : "#f1f5f9")
    property color themeBorder: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeBorder) ? arcadeBackend.themeColors.themeBorder : (isDarkMode ? "#2a2a38" : "#cbd5e1")
    property color themeText: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeText) ? arcadeBackend.themeColors.themeText : (isDarkMode ? "#ffffff" : "#0f172a")
    property color themeTextMuted: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeTextMuted) ? arcadeBackend.themeColors.themeTextMuted : (isDarkMode ? "#94a3b8" : "#64748b")
    property color themeAccent: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeAccent) ? arcadeBackend.themeColors.themeAccent : (isDarkMode ? "#00f0ff" : "#1e66f5")
    property color themeAccentAlt: (typeof arcadeBackend !== "undefined" && arcadeBackend.themeColors && arcadeBackend.themeColors.themeAccentAlt) ? arcadeBackend.themeColors.themeAccentAlt : (isDarkMode ? "#e6458e" : "#d20f39")

    function colorLuminance(col) {
        if (!col) return 0.2;
        var c = (typeof col === "string") ? Qt.color(col) : col;
        if (!c || c.r === undefined) {
            try { c = Qt.color(col); } catch (e) { return 0.2; }
        }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }
    property color themeAccentFg: colorLuminance(themeAccent) > 0.45 ? "#09090e" : "#ffffff"

    anchors.fill: parent
    color: isDarkMode ? "#e60a0a10" : "#800f172a"
    z: 210
    visible: opacity > 0
    opacity: 0

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    // State properties synced with backend
    property bool launchMuted: true
    property bool checkUpdatesOnLaunch: true
    property bool autoUpdateLauncher: false
    property bool autoUpdateGames: false
    property string themeMode: "auto"
    property string gameThemeMode: "match"

    // Keyboard Focus & Navigation
    property int focusedRow: 0
    property int maxRows: 6
    focus: true

    onFocusedRowChanged: ensureRowVisible(focusedRow)

    function open() {
        syncFromBackend();
        focusedRow = 0;
        opacity = 1;
        forceActiveFocus();
    }

    function close() {
        opacity = 0;
        if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
            root.restoreKeyboardFocus();
        }
    }

    function activateRow(row) {
        if (row === 0) {
            launchMuted = !launchMuted;
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setLaunchMuted(launchMuted);
        } else if (row === 1) {
            adjustSegmented(1, 1);
        } else if (row === 2) {
            adjustSegmented(2, 1);
        } else if (row === 3) {
            checkUpdatesOnLaunch = !checkUpdatesOnLaunch;
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setCheckUpdatesOnLaunch(checkUpdatesOnLaunch);
        } else if (row === 4) {
            autoUpdateLauncher = !autoUpdateLauncher;
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setAutoUpdateLauncher(autoUpdateLauncher);
        } else if (row === 5) {
            autoUpdateGames = !autoUpdateGames;
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setAutoUpdateGames(autoUpdateGames);
        }
    }

    function adjustSegmented(row, dir) {
        if (row === 1) {
            var modes = ["auto", "dark", "light"];
            var curIdx = modes.indexOf(themeMode);
            var nextIdx = (curIdx + dir + modes.length) % modes.length;
            themeMode = modes[nextIdx];
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setThemeMode(themeMode);
        } else if (row === 2) {
            var gameModes = ["match", "dark", "light"];
            var gIdx = gameModes.indexOf(gameThemeMode);
            var nextGIdx = (gIdx + dir + gameModes.length) % gameModes.length;
            gameThemeMode = gameModes[nextGIdx];
            if (typeof arcadeBackend !== "undefined") arcadeBackend.setGameThemeMode(gameThemeMode);
        }
    }

    function selectSegmentedOption(row, optIdx) {
        if (row === 1) {
            var modes = ["auto", "dark", "light"];
            if (optIdx >= 0 && optIdx < modes.length) {
                themeMode = modes[optIdx];
                if (typeof arcadeBackend !== "undefined") arcadeBackend.setThemeMode(themeMode);
            }
        } else if (row === 2) {
            var gameModes = ["match", "dark", "light"];
            if (optIdx >= 0 && optIdx < gameModes.length) {
                gameThemeMode = gameModes[optIdx];
                if (typeof arcadeBackend !== "undefined") arcadeBackend.setGameThemeMode(gameThemeMode);
            }
        }
    }

    function ensureRowVisible(row) {
        if (typeof settingsFlickable === "undefined" || !settingsFlickable) return;
        if (row <= 1) {
            settingsFlickable.contentY = 0;
        } else if (row === 2) {
            settingsFlickable.contentY = Math.min(settingsFlickable.contentHeight - settingsFlickable.height, 100);
        } else {
            settingsFlickable.contentY = Math.min(settingsFlickable.contentHeight - settingsFlickable.height, 240);
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_Backspace) {
            settingsSheet.close();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down || event.key === Qt.Key_J || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
            settingsSheet.focusedRow = (settingsSheet.focusedRow + 1) % settingsSheet.maxRows;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up || event.key === Qt.Key_K || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            settingsSheet.focusedRow = (settingsSheet.focusedRow - 1 + settingsSheet.maxRows) % settingsSheet.maxRows;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            settingsSheet.activateRow(settingsSheet.focusedRow);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            settingsSheet.adjustSegmented(settingsSheet.focusedRow, -1);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            settingsSheet.adjustSegmented(settingsSheet.focusedRow, 1);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_1 || event.key === Qt.Key_2 || event.key === Qt.Key_3) {
            var optIdx = event.key === Qt.Key_1 ? 0 : (event.key === Qt.Key_2 ? 1 : 2);
            settingsSheet.selectSegmentedOption(settingsSheet.focusedRow, optIdx);
            event.accepted = true;
            return;
        }
    }

    function syncFromBackend() {
        if (typeof arcadeBackend !== "undefined" && arcadeBackend) {
            launchMuted = arcadeBackend.getLaunchMuted();
            checkUpdatesOnLaunch = arcadeBackend.getCheckUpdatesOnLaunch();
            autoUpdateLauncher = arcadeBackend.getAutoUpdateLauncher();
            autoUpdateGames = arcadeBackend.getAutoUpdateGames();
            themeMode = arcadeBackend.getThemeMode();
            gameThemeMode = arcadeBackend.getGameThemeMode();
        }
    }

    Connections {
        target: (typeof arcadeBackend !== "undefined") ? arcadeBackend : null
        function onSettingsChanged() {
            settingsSheet.syncFromBackend();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: settingsSheet.close()
    }

    Rectangle {
        id: sheetContainer
        width: Math.min(parent.width - 40, 620)
        height: Math.min(parent.height - 40, 720)
        anchors.centerIn: parent
        color: settingsSheet.themeSurface
        radius: 12
        border.color: settingsSheet.themeBorder
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            // Stop clicks from bubbling to backdrop
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Row
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: settingsSheet.themeSurfaceLight
                border.color: settingsSheet.themeBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    Text {
                        text: "⚙️"
                        font.pixelSize: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Arcade Settings"
                            font.pixelSize: 18
                            font.bold: true
                            color: settingsSheet.themeText
                        }

                        Text {
                            text: "Preferences, Audio & Theming Controls"
                            font.pixelSize: 11
                            color: settingsSheet.themeTextMuted
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeMouse.containsMouse ? (settingsSheet.isDarkMode ? "#33ffffff" : "#220f172a") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 14
                            font.bold: true
                            color: settingsSheet.themeText
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsSheet.close()
                        }
                    }
                }
            }

            // Scrollable Content
            Flickable {
                id: settingsFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight + 40
                clip: true
                Behavior on contentY { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                ColumnLayout {
                    id: settingsColumn
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    spacing: 24

                    // -------------------------------------------------------------
                    // Section 1: Audio Preferences
                    // -------------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            spacing: 8
                            Text { text: "🔊"; font.pixelSize: 16 }
                            Text {
                                text: "Audio & Sound Preferences"
                                font.pixelSize: 14
                                font.bold: true
                                color: settingsSheet.themeText
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 0 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 0 ? 2 : 1
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: "Launch Games Muted"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: settingsSheet.themeText
                                    }

                                    Text {
                                        text: "Default audio state when starting titles. Toggle off to pass '--unmute' on launch."
                                        font.pixelSize: 11
                                        color: settingsSheet.themeTextMuted
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                // Toggle Switch
                                Rectangle {
                                    width: 48
                                    height: 26
                                    radius: 13
                                    color: settingsSheet.launchMuted ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#334155" : "#cbd5e1")
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: settingsSheet.launchMuted ? parent.width - width - 3 : 3
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var newVal = !settingsSheet.launchMuted;
                                            settingsSheet.launchMuted = newVal;
                                            if (typeof arcadeBackend !== "undefined") arcadeBackend.setLaunchMuted(newVal);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // -------------------------------------------------------------
                    // Section 2: Appearance & Theming
                    // -------------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        RowLayout {
                            spacing: 8
                            Text { text: "🎨"; font.pixelSize: 16 }
                            Text {
                                text: "Appearance & Theming"
                                font.pixelSize: 14
                                font.bold: true
                                color: settingsSheet.themeText
                            }
                        }

                        // Launcher Theme Mode
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 1 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 1 ? 2 : 1
                            radius: 8

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Launcher Appearance Mode"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: settingsSheet.themeText
                                        }
                                        Text {
                                            text: "Follows Omarchy OS theme (colors.toml) or locks to Dark / Light."
                                            font.pixelSize: 11
                                            color: settingsSheet.themeTextMuted
                                        }
                                    }
                                }

                                // 3-way Segmented Control
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "auto", label: "🌐 OS Theme (Auto)" },
                                            { id: "dark", label: "🌙 Always Dark" },
                                            { id: "light", label: "☀️ Always Light" }
                                        ]

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: settingsSheet.themeMode === modelData.id ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#222230" : "#e2e8f0")
                                            border.color: settingsSheet.themeMode === modelData.id ? settingsSheet.themeAccent : settingsSheet.themeBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: 11
                                                font.bold: settingsSheet.themeMode === modelData.id
                                                color: settingsSheet.themeMode === modelData.id ? settingsSheet.themeAccentFg : settingsSheet.themeText
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsSheet.themeMode = modelData.id;
                                                    if (typeof arcadeBackend !== "undefined") arcadeBackend.setThemeMode(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Game Theme Launch Mode
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 2 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 2 ? 2 : 1
                            radius: 8

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Game Launch Theme"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: settingsSheet.themeText
                                        }
                                        Text {
                                            text: "Forces games to launch with matching or explicit '--theme' CLI flags."
                                            font.pixelSize: 11
                                            color: settingsSheet.themeTextMuted
                                        }
                                    }
                                }

                                // 3-way Segmented Control
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "match", label: "🌐 Match Launcher" },
                                            { id: "dark", label: "🌙 Force Dark" },
                                            { id: "light", label: "☀️ Force Light" }
                                        ]

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: settingsSheet.gameThemeMode === modelData.id ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#222230" : "#e2e8f0")
                                            border.color: settingsSheet.gameThemeMode === modelData.id ? settingsSheet.themeAccent : settingsSheet.themeBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: 11
                                                font.bold: settingsSheet.gameThemeMode === modelData.id
                                                color: settingsSheet.gameThemeMode === modelData.id ? settingsSheet.themeAccentFg : settingsSheet.themeText
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsSheet.gameThemeMode = modelData.id;
                                                    if (typeof arcadeBackend !== "undefined") arcadeBackend.setGameThemeMode(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // -------------------------------------------------------------
                    // Section 3: Updates & Automation
                    // -------------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            spacing: 8
                            Text { text: "🔄"; font.pixelSize: 16 }
                            Text {
                                text: "Updates & Maintenance"
                                font.pixelSize: 14
                                font.bold: true
                                color: settingsSheet.themeText
                            }
                        }

                        // Check updates on launch
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 3 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 3 ? 2 : 1
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Check Updates on Startup"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: settingsSheet.themeText
                                    }
                                    Text {
                                        text: "Automatically verify catalog and launcher releases when Omarchy Arcade opens."
                                        font.pixelSize: 10
                                        color: settingsSheet.themeTextMuted
                                    }
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: settingsSheet.checkUpdatesOnLaunch ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#334155" : "#cbd5e1")
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: settingsSheet.checkUpdatesOnLaunch ? parent.width - width - 3 : 3
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var newVal = !settingsSheet.checkUpdatesOnLaunch;
                                            settingsSheet.checkUpdatesOnLaunch = newVal;
                                            if (typeof arcadeBackend !== "undefined") arcadeBackend.setCheckUpdatesOnLaunch(newVal);
                                        }
                                    }
                                }
                            }
                        }

                        // Auto-update launcher
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 4 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 4 ? 2 : 1
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Auto-Update Launcher"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: settingsSheet.themeText
                                    }
                                    Text {
                                        text: "Automatically apply new launcher versions in the background when available."
                                        font.pixelSize: 10
                                        color: settingsSheet.themeTextMuted
                                    }
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: settingsSheet.autoUpdateLauncher ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#334155" : "#cbd5e1")
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: settingsSheet.autoUpdateLauncher ? parent.width - width - 3 : 3
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var newVal = !settingsSheet.autoUpdateLauncher;
                                            settingsSheet.autoUpdateLauncher = newVal;
                                            if (typeof arcadeBackend !== "undefined") arcadeBackend.setAutoUpdateLauncher(newVal);
                                        }
                                    }
                                }
                            }
                        }

                        // Auto-update games
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            color: settingsSheet.themeSurfaceLight
                            border.color: settingsSheet.focusedRow === 5 ? settingsSheet.themeAccent : settingsSheet.themeBorder
                            border.width: settingsSheet.focusedRow === 5 ? 2 : 1
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Auto-Update Installed Games"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: settingsSheet.themeText
                                    }
                                    Text {
                                        text: "Automatically download and update installed titles when new releases are published."
                                        font.pixelSize: 10
                                        color: settingsSheet.themeTextMuted
                                    }
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: settingsSheet.autoUpdateGames ? settingsSheet.themeAccent : (settingsSheet.isDarkMode ? "#334155" : "#cbd5e1")
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: settingsSheet.autoUpdateGames ? parent.width - width - 3 : 3
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var newVal = !settingsSheet.autoUpdateGames;
                                            settingsSheet.autoUpdateGames = newVal;
                                            if (typeof arcadeBackend !== "undefined") arcadeBackend.setAutoUpdateGames(newVal);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer Shortcuts Hint
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: settingsSheet.themeSurfaceLight
                border.color: settingsSheet.themeBorder
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    RowLayout {
                        spacing: 4
                        Text { text: "↑/↓ or J/K"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: settingsSheet.themeAccent }
                        Text { text: "Navigate"; font.pixelSize: 10; color: settingsSheet.themeTextMuted }
                    }
                    Text { text: "•"; font.pixelSize: 10; color: settingsSheet.themeBorder }
                    RowLayout {
                        spacing: 4
                        Text { text: "Space/Enter"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: settingsSheet.themeAccent }
                        Text { text: "Toggle"; font.pixelSize: 10; color: settingsSheet.themeTextMuted }
                    }
                    Text { text: "•"; font.pixelSize: 10; color: settingsSheet.themeBorder }
                    RowLayout {
                        spacing: 4
                        Text { text: "←/→ or 1-3"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: settingsSheet.themeAccent }
                        Text { text: "Options"; font.pixelSize: 10; color: settingsSheet.themeTextMuted }
                    }
                    Text { text: "•"; font.pixelSize: 10; color: settingsSheet.themeBorder }
                    RowLayout {
                        spacing: 4
                        Text { text: "Esc"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: settingsSheet.themeAccent }
                        Text { text: "Close"; font.pixelSize: 10; color: settingsSheet.themeTextMuted }
                    }
                }
            }
        }
    }
}
