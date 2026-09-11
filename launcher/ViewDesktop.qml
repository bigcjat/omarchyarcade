import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: desktopView
    anchors.fill: parent

    property var catalog: []
    property var allGames: (catalog && catalog.length > 0) ? catalog : games
    property var games: []
    property var favoritesList: (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getFavorites) ? arcadeBackend.getFavorites() : []
    property string activeWallpaper: (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDesktopWallpaper) ? arcadeBackend.getDesktopWallpaper() : "matrix"
    
    // Active selection & open window state
    property var selectedItem: null // { type: "folder" | "game", data: ... }
    property var activeGame: (selectedItem && selectedItem.type === "game") ? selectedItem.data : (games && selectedIndex >= 0 && selectedIndex < games.length ? games[selectedIndex] : null)
    property int selectedIndex: 0

    property var openFolder: null // { id, label, cat, icon, color }
    property var folderGames: openFolder ? getGamesForCategory(openFolder.cat) : []
    property bool showWallpaperPicker: false

    signal gameSelected(int index)
    signal gameLaunched(string gameId)
    signal detailRequested(var gameData)

    Connections {
        target: (typeof arcadeBackend !== "undefined") ? arcadeBackend : null
        function onFavoritesChanged(favs) {
            desktopView.favoritesList = favs;
        }
        function onWallpaperChanged(wp) {
            desktopView.activeWallpaper = wp;
        }
    }

    // --- Category Folders Definition ---
    readonly property var desktopFolders: [
        { id: "action", label: "Action Arcade", cat: "ACTION ARCADE", icon: "📁", color: "#f59e0b" },
        { id: "puzzles", label: "Puzzles & Logic", cat: "PUZZLES & GRID LOGIC", icon: "📁", color: "#10b981" },
        { id: "tabletop", label: "Board & Tabletop", cat: "BOARD & TABLETOP", icon: "📁", color: "#8b5cf6" },
        { id: "cards", label: "Cards & Casino", cat: "CARDS & CASINO", icon: "📁", color: "#ef4444" },
        { id: "blocks", label: "Blocks & Merging", cat: "BLOCKS & MERGING", icon: "📁", color: "#06b6d4" },
        { id: "word", label: "Word & Trivia", cat: "WORD & TRIVIA", icon: "📁", color: "#3b82f6" },
        { id: "casual", label: "Casual & Physics", cat: "CASUAL AIM & PHYSICS", icon: "📁", color: "#ec4899" },
        { id: "all", label: "All Games", cat: "ALL", icon: "🎮", color: "#00f0ff" },
        { id: "library", label: "My Library", cat: "LIBRARY", icon: "💾", color: "#34d399" }
    ]

    function getGamesForCategory(cat) {
        var list = [];
        var src = (allGames && allGames.length > 0) ? allGames : games;
        if (!src) return list;
        for (var i = 0; i < src.length; i++) {
            var g = src[i];
            var isUnrel = (g.status === "unreleased");
            if (cat === "ALL") {
                if (!isUnrel) list.push(g);
            } else if (cat === "LIBRARY") {
                if (!isUnrel && (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(g.id) : true)) list.push(g);
            } else if (cat === "BOARD & TABLETOP") {
                if (!isUnrel && (g.category.toUpperCase().indexOf("BOARD") !== -1 || g.category.toUpperCase().indexOf("TABLETOP") !== -1)) list.push(g);
            } else if (g.category && g.category.toUpperCase() === cat) {
                if (!isUnrel) list.push(g);
            }
        }
        return list;
    }

    function getFavoriteGames() {
        var list = [];
        var src = (allGames && allGames.length > 0) ? allGames : games;
        if (!src || !favoritesList) return list;
        for (var i = 0; i < src.length; i++) {
            var g = src[i];
            if (favoritesList.indexOf(g.id) !== -1) {
                list.push(g);
            }
        }
        return list;
    }

    // =========================================================================
    // 1. DYNAMIC RETRO DESKTOP WALLPAPER SURFACE
    // =========================================================================
    Item {
        anchors.fill: parent

        // A. Classic Windows 95 Teal
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "teal"
            color: "#008080"
        }

        // B. CRT Dot Matrix
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "matrix"
            color: "#0d0f17"

            Canvas {
                anchors.fill: parent
                opacity: 0.16
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

        // C. Cyberpunk Vector Grid
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "cyber"
            color: "#080914"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.strokeStyle = "rgba(0, 240, 255, 0.12)";
                    ctx.lineWidth = 1;
                    // Horizontal lines
                    for (var y = 0; y < height; y += 32) {
                        ctx.beginPath();
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                        ctx.stroke();
                    }
                    // Vertical lines
                    for (var x = 0; x < width; x += 32) {
                        ctx.beginPath();
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                        ctx.stroke();
                    }
                }
            }
        }

        // D. Synthwave Sunset Gradient
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "sunset"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#140727" }
                GradientStop { position: 0.45; color: "#2e0854" }
                GradientStop { position: 0.8; color: "#9d174d" }
                GradientStop { position: 1.0; color: "#ea580c" }
            }
        }

        // E. Deep Space Starfield
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "starfield"
            color: "#05060f"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.fillStyle = "#ffffff";
                    // Deterministic pseudo-random stars
                    for (var i = 0; i < 90; i++) {
                        var sx = ((i * 137.5) % 1) * width;
                        var sy = ((i * 269.3) % 1) * height;
                        var sz = (i % 3 === 0) ? 2 : 1;
                        ctx.globalAlpha = 0.3 + (i % 5) * 0.14;
                        ctx.fillRect(sx, sy, sz, sz);
                    }
                }
            }
        }

        // F. Classic Cobalt Blue
        Rectangle {
            anchors.fill: parent
            visible: desktopView.activeWallpaper === "blue"
            color: "#1e3a8a"
        }
    }

    // =========================================================================
    // 2. MAIN DESKTOP LAYOUT (CANVAS + DOCK)
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: desktopScroll
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: desktopSurfaceCol.implicitHeight + 80
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                // Dismiss selection or open popups on background click
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        desktopView.selectedItem = null;
                        desktopView.showWallpaperPicker = false;
                        if (typeof root !== "undefined" && root.restoreKeyboardFocus) {
                            root.restoreKeyboardFocus();
                        }
                    }
                }

                ColumnLayout {
                    id: desktopSurfaceCol
                    width: desktopScroll.width - 48
                    x: 24
                    y: 20
                    spacing: 24

                    // ---------------------------------------------------------
                    // SECTION A: CATEGORY FOLDERS
                    // ---------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            spacing: 8
                            Text {
                                text: "📁 SYSTEM FOLDERS"
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: Qt.alpha("#ffffff", 0.75)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.alpha("#ffffff", 0.15)
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 16

                            Repeater {
                                model: desktopView.desktopFolders

                                Item {
                                    id: folderItem
                                    width: 104
                                    height: 110

                                    readonly property bool isSelected: desktopView.selectedItem && desktopView.selectedItem.type === "folder" && desktopView.selectedItem.data.id === modelData.id
                                    readonly property bool isHovered: folderMouse.containsMouse
                                    readonly property int count: desktopView.getGamesForCategory(modelData.cat).length

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: folderItem.isSelected ? Qt.alpha("#ffffff", 0.22) : (folderItem.isHovered ? Qt.alpha("#ffffff", 0.12) : "transparent")
                                        border.color: folderItem.isSelected ? "#00f0ff" : (folderItem.isHovered ? Qt.alpha("#ffffff", 0.3) : "transparent")
                                        border.width: 1
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        width: parent.width - 8

                                        // Big Retro Folder Graphic
                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 54
                                            height: 48

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 48
                                                height: 38
                                                radius: 4
                                                color: Qt.alpha(modelData.color, 0.85)
                                                border.color: Qt.lighter(modelData.color, 1.3)
                                                border.width: 1.5

                                                // Folder Tab
                                                Rectangle {
                                                    anchors.bottom: parent.top
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    width: 18
                                                    height: 6
                                                    radius: 2
                                                    color: Qt.alpha(modelData.color, 0.85)
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.icon
                                                    font.pixelSize: 18
                                                }
                                            }

                                            // Count Badge
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                height: 14
                                                radius: 4
                                                width: Math.max(16, countText.implicitWidth + 8)
                                                color: "#0a0a14"
                                                border.color: "#ffffff"
                                                border.width: 1

                                                Text {
                                                    id: countText
                                                    anchors.centerIn: parent
                                                    text: folderItem.count
                                                    font.family: "monospace"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: "#ffffff"
                                                }
                                            }
                                        }

                                        // Folder Label
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: folderLabelText.implicitHeight + 4
                                            radius: 3
                                            color: folderItem.isSelected ? "#00f0ff" : "transparent"

                                            Text {
                                                id: folderLabelText
                                                anchors.centerIn: parent
                                                width: parent.width - 4
                                                text: modelData.label
                                                font.pixelSize: 11
                                                font.bold: folderItem.isSelected
                                                color: folderItem.isSelected ? "#09090e" : "#ffffff"
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: folderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            desktopView.selectedItem = { type: "folder", data: modelData };
                                            desktopView.showWallpaperPicker = false;
                                        }
                                        onDoubleClicked: {
                                            desktopView.openFolder = modelData;
                                            desktopView.selectedItem = null;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // SECTION B: FAVORITES ON DESKTOP
                    // ---------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            spacing: 8
                            Text {
                                text: "❤️ PINNED FAVORITES ON DESKTOP"
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: Qt.alpha("#ffffff", 0.75)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.alpha("#ffffff", 0.15)
                            }
                        }

                        // When favorites exist
                        Flow {
                            Layout.fillWidth: true
                            spacing: 16
                            visible: desktopView.getFavoriteGames().length > 0

                            Repeater {
                                model: desktopView.getFavoriteGames()

                                Item {
                                    id: favItem
                                    width: 104
                                    height: 120

                                    readonly property bool isSelected: desktopView.selectedItem && desktopView.selectedItem.type === "game" && desktopView.selectedItem.data.id === modelData.id
                                    readonly property bool isHovered: favMouse.containsMouse
                                    readonly property bool installed: modelData ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(modelData.id) : true) : true
                                    readonly property bool hasUpdate: modelData ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(modelData.id, modelData.version || "") : false) : false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: favItem.isSelected ? Qt.alpha("#ffffff", 0.24) : (favItem.isHovered ? Qt.alpha("#ffffff", 0.12) : "transparent")
                                        border.color: favItem.isSelected ? "#ec4899" : (favItem.isHovered ? Qt.alpha("#ffffff", 0.3) : "transparent")
                                        border.width: 1
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        width: parent.width - 8

                                        // Icon Graphic
                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 56
                                            height: 56

                                            Image {
                                                anchors.centerIn: parent
                                                width: 50
                                                height: 50
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                source: {
                                                    if (!modelData) return "";
                                                    if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                                        return arcadeBackend.getDiskIconUrl(modelData.id);
                                                    }
                                                    return "../games/" + modelData.id + "/assets/disk_icon.png";
                                                }
                                            }

                                            // Glowing Heart Favorite Badge (Top-Right)
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: -2
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: "#2a0a18"
                                                border.color: "#ec4899"
                                                border.width: 1.5

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "❤️"
                                                    font.pixelSize: 10
                                                }
                                            }

                                            // Installed / Update / Get Dot (Bottom-Right)
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.margins: -2
                                                width: (favItem.hasUpdate || !favItem.installed) ? 14 : 10
                                                height: (favItem.hasUpdate || !favItem.installed) ? 14 : 10
                                                radius: (favItem.hasUpdate || !favItem.installed) ? 3 : 5
                                                color: favItem.hasUpdate ? "#0284c7" : (favItem.installed ? "#22c55e" : "#065f46")
                                                border.color: favItem.hasUpdate ? "#38bdf8" : (favItem.installed ? "#0a0a0f" : "#34d399")
                                                border.width: 1.5

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: favItem.hasUpdate || !favItem.installed
                                                    text: favItem.hasUpdate ? "🔄" : "⬇"
                                                    font.pixelSize: 8
                                                    color: "#FFFFFF"
                                                }
                                            }
                                        }

                                        // Title Label
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: favLabelText.implicitHeight + 4
                                            radius: 3
                                            color: favItem.isSelected ? "#ec4899" : "transparent"

                                            Text {
                                                id: favLabelText
                                                anchors.centerIn: parent
                                                width: parent.width - 4
                                                text: modelData ? modelData.title : ""
                                                font.pixelSize: 11
                                                font.bold: favItem.isSelected
                                                color: favItem.isSelected ? "#ffffff" : "#ffffff"
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: favMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            desktopView.selectedItem = { type: "game", data: modelData };
                                            desktopView.showWallpaperPicker = false;
                                        }
                                        onDoubleClicked: {
                                            if (modelData) {
                                                desktopView.gameLaunched(modelData.id);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // When no favorites yet: helpful hint card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            visible: desktopView.getFavoriteGames().length === 0
                            radius: 8
                            color: Qt.alpha("#000000", 0.3)
                            border.color: Qt.alpha("#ffffff", 0.2)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Text { text: "🤍"; font.pixelSize: 18 }
                                Text {
                                    text: "No favorite games pinned yet. Click the ❤️ Favorite button on any game to pin it directly to your desktop!"
                                    font.pixelSize: 12
                                    color: Qt.alpha("#ffffff", 0.7)
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 3. RETRO OS FOLDER WINDOW (Floating Window)
            // =================================================================
            Rectangle {
                id: folderWindow
                visible: desktopView.openFolder !== null
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 780)
                height: Math.min(parent.height - 40, 480)
                radius: 8
                color: "#121420"
                border.color: desktopView.openFolder ? desktopView.openFolder.color : "#3b82f6"
                border.width: 1.5
                clip: true
                z: 20

                // Window Drop Shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 12
                    color: "#000000"
                    opacity: 0.5
                    z: -1
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Window Title Bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: "#1a1d2e"
                        border.color: Qt.alpha("#ffffff", 0.1)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: desktopView.openFolder ? (desktopView.openFolder.icon + " " + desktopView.openFolder.label) : ""
                                font.family: "monospace"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }

                            Rectangle {
                                height: 18
                                radius: 4
                                Layout.preferredWidth: windowCountText.implicitWidth + 10
                                color: "#252b40"
                                Text {
                                    id: windowCountText
                                    anchors.centerIn: parent
                                    text: desktopView.folderGames.length + " games"
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    color: "#94a3b8"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Close Window Button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 4
                                color: winCloseMouse.containsMouse ? "#ef4444" : "#282e44"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: winCloseMouse.containsMouse ? "#ffffff" : "#94a3b8"
                                }

                                MouseArea {
                                    id: winCloseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: desktopView.openFolder = null
                                }
                            }
                        }
                    }

                    // Window Body (Grid of games inside folder)
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: folderGrid.implicitHeight + 32

                        Flow {
                            id: folderGrid
                            width: folderWindow.width - 40
                            x: 20
                            y: 16
                            spacing: 14

                            Repeater {
                                model: desktopView.folderGames

                                Item {
                                    width: 100
                                    height: 116

                                    readonly property bool isSelected: desktopView.selectedItem && desktopView.selectedItem.type === "game" && desktopView.selectedItem.data.id === modelData.id
                                    readonly property bool isHovered: winItemMouse.containsMouse
                                    readonly property bool isFav: desktopView.favoritesList.indexOf(modelData.id) !== -1
                                    readonly property bool installed: modelData ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(modelData.id) : true) : true
                                    readonly property bool hasUpdate: modelData ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(modelData.id, modelData.version || "") : false) : false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: isSelected ? "#2a374f" : (isHovered ? "#1b2234" : "transparent")
                                        border.color: isSelected ? "#00f0ff" : (isHovered ? "#334155" : "transparent")
                                        border.width: 1
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        width: parent.width - 8

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 50
                                            height: 50

                                            Image {
                                                anchors.centerIn: parent
                                                width: 46
                                                height: 46
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                source: {
                                                    if (!modelData) return "";
                                                    if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                                        return arcadeBackend.getDiskIconUrl(modelData.id);
                                                    }
                                                    return "../games/" + modelData.id + "/assets/disk_icon.png";
                                                }
                                            }

                                            // Favorite Heart Toggle Button
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: -4
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: isFav ? "#2a0a18" : (winFavMouse.containsMouse ? "#222538" : "transparent")
                                                border.color: isFav ? "#ec4899" : (winFavMouse.containsMouse ? "#64748b" : "transparent")
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: isFav ? "❤️" : "🤍"
                                                    font.pixelSize: 9
                                                    opacity: isFav ? 1.0 : (winFavMouse.containsMouse ? 0.8 : 0.0)
                                                }

                                                MouseArea {
                                                    id: winFavMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.toggleFavorite) {
                                                            arcadeBackend.toggleFavorite(modelData.id);
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: winLabelText.implicitHeight + 4
                                            radius: 3
                                            color: isSelected ? "#00f0ff" : "transparent"

                                            Text {
                                                id: winLabelText
                                                anchors.centerIn: parent
                                                width: parent.width - 4
                                                text: modelData ? modelData.title : ""
                                                font.pixelSize: 10
                                                font.bold: isSelected
                                                color: isSelected ? "#09090e" : "#ffffff"
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: winItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            desktopView.selectedItem = { type: "game", data: modelData };
                                        }
                                        onDoubleClicked: {
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
            }

            // =================================================================
            // 4. WALLPAPER PICKER POPOVER
            // =================================================================
            Rectangle {
                id: wallpaperPickerPopup
                visible: desktopView.showWallpaperPicker
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                width: 280
                height: 220
                radius: 8
                color: "#161928"
                border.color: "#3b82f6"
                border.width: 1.5
                z: 30

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "🖼️ DESKTOP WALLPAPER"
                            font.family: "monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "✕"
                            font.pixelSize: 12
                            color: "#94a3b8"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: desktopView.showWallpaperPicker = false
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#252b40" }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: [
                                { id: "teal", label: "Windows 95 Teal", previewCol: "#008080" },
                                { id: "matrix", label: "CRT Dot Matrix", previewCol: "#0d0f17" },
                                { id: "cyber", label: "Cyberpunk Grid", previewCol: "#080914" },
                                { id: "sunset", label: "Vaporwave Sunset", previewCol: "#9d174d" },
                                { id: "starfield", label: "Starfield Space", previewCol: "#05060f" },
                                { id: "blue", label: "Cobalt Blue", previewCol: "#1e3a8a" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 6
                                color: wpMouse.containsMouse ? "#242a42" : "#1a1f30"
                                border.color: desktopView.activeWallpaper === modelData.id ? "#00f0ff" : "#2f3854"
                                border.width: desktopView.activeWallpaper === modelData.id ? 2 : 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 4
                                        color: modelData.previewCol
                                        border.color: "#ffffff"
                                        border.width: 1
                                    }

                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 10
                                        font.bold: desktopView.activeWallpaper === modelData.id
                                        color: desktopView.activeWallpaper === modelData.id ? "#00f0ff" : "#cbd5e1"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: wpMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        desktopView.activeWallpaper = modelData.id;
                                        if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.setDesktopWallpaper) {
                                            arcadeBackend.setDesktopWallpaper(modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 5. DESKTOP TASKBAR DOCK (Bottom Bar)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#0f121d"
            border.color: "#202538"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Selected Item Mini Thumbnail
                Rectangle {
                    width: 28
                    height: 28
                    radius: 4
                    color: "#1a1f2e"
                    clip: true
                    visible: desktopView.selectedItem !== null

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        visible: desktopView.selectedItem && desktopView.selectedItem.type === "game"
                        source: {
                            if (!desktopView.selectedItem || desktopView.selectedItem.type !== "game") return "";
                            var gid = desktopView.selectedItem.data.id;
                            if (typeof arcadeBackend !== "undefined" && arcadeBackend && arcadeBackend.getDiskIconUrl) {
                                return arcadeBackend.getDiskIconUrl(gid);
                            }
                            return "../games/" + gid + "/assets/disk_icon.png";
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: desktopView.selectedItem && desktopView.selectedItem.type === "folder"
                        text: "📁"
                        font.pixelSize: 16
                    }
                }

                // Status Description Text
                Text {
                    text: {
                        if (desktopView.selectedItem) {
                            if (desktopView.selectedItem.type === "folder") {
                                return "📁 " + desktopView.selectedItem.data.label + " • " + desktopView.getGamesForCategory(desktopView.selectedItem.data.cat).length + " games";
                            } else {
                                return "🎮 " + desktopView.selectedItem.data.title + " • " + desktopView.selectedItem.data.category + " • " + (desktopView.selectedItem.data.size || "");
                            }
                        }
                        if (desktopView.openFolder) {
                            return "Viewing " + desktopView.openFolder.label;
                        }
                        return "🖥️ Desktop • Double-click a folder to open, or double-click a game to play";
                    }
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#cbd5e1"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Actions for Selected Item
                RowLayout {
                    spacing: 8
                    visible: desktopView.selectedItem !== null

                    // If folder selected: Open Folder button
                    Rectangle {
                        visible: desktopView.selectedItem && desktopView.selectedItem.type === "folder"
                        height: 28
                        width: 104
                        radius: 4
                        color: "#1c2235"
                        border.color: "#353f5c"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "📂 Open Folder"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#00f0ff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (desktopView.selectedItem && desktopView.selectedItem.type === "folder") {
                                    desktopView.openFolder = desktopView.selectedItem.data;
                                    desktopView.selectedItem = null;
                                }
                            }
                        }
                    }

                    // If game selected: Details & Play buttons
                    Rectangle {
                        visible: desktopView.selectedItem && desktopView.selectedItem.type === "game"
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
                                if (desktopView.selectedItem && desktopView.selectedItem.type === "game") {
                                    desktopView.detailRequested(desktopView.selectedItem.data);
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: desktopView.selectedItem && desktopView.selectedItem.type === "game"
                        readonly property var selGame: (desktopView.selectedItem && desktopView.selectedItem.type === "game") ? desktopView.selectedItem.data : null
                        readonly property bool installed: selGame ? (typeof root !== "undefined" && root.isInstalled ? root.isInstalled(selGame.id) : true) : true
                        readonly property bool hasUpdate: selGame ? (typeof root !== "undefined" && root.hasGameUpdate ? root.hasGameUpdate(selGame.id, selGame.version || "") : false) : false

                        height: 28
                        width: Math.max(90, taskbarBtnText.implicitWidth + 16)
                        radius: 4
                        color: hasUpdate ? "#0284c7" : (installed ? "#00f0ff" : "#059669")
                        border.color: hasUpdate ? "#38bdf8" : (installed ? "#67e8f9" : "#34d399")
                        border.width: 1

                        Text {
                            id: taskbarBtnText
                            anchors.centerIn: parent
                            text: parent.hasUpdate ? "🔄 Update" : (parent.installed ? "▶ Play" : ("⬇ Get (" + (parent.selGame && parent.selGame.size ? parent.selGame.size : "") + ")"))
                            font.pixelSize: 11
                            font.bold: true
                            color: (parent.hasUpdate || !parent.installed) ? "#FFFFFF" : "#09090e"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var g = parent.selGame;
                                if (g) {
                                    if (!parent.installed || parent.hasUpdate) {
                                        desktopView.detailRequested(g);
                                    } else {
                                        desktopView.gameLaunched(g.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Wallpaper Switcher Button (Right Corner)
                Rectangle {
                    height: 28
                    width: wpBtnText.implicitWidth + 16
                    radius: 4
                    color: desktopView.showWallpaperPicker ? "#2a3450" : (wpMouseBtn.containsMouse ? "#1c2235" : "#141824")
                    border.color: desktopView.showWallpaperPicker ? "#00f0ff" : "#2f3854"
                    border.width: 1

                    Row {
                        id: wpBtnText
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "🖼️"; font.pixelSize: 11 }
                        Text {
                            text: "Wallpaper"
                            font.pixelSize: 10
                            font.bold: true
                            color: desktopView.showWallpaperPicker ? "#00f0ff" : "#cbd5e1"
                        }
                    }

                    MouseArea {
                        id: wpMouseBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            desktopView.showWallpaperPicker = !desktopView.showWallpaperPicker;
                        }
                    }
                }
            }
        }
    }
}
