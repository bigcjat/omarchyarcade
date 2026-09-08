import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1080
    height: 740
    minimumWidth: 640
    minimumHeight: 480
    title: "Omarchy Arcade"
    color: themeBackground

    // --- Theme Tokens (Synchronized with Omarchy system palettes) ---
    property color themeBackground: "#111116"
    property color themeSurface: "#181822"
    property color themeSurfaceLight: "#222230"
    property color themeBorder: "#2d2d3d"
    property color themeText: "#f1f5f9"
    property color themeTextMuted: "#94a3b8"
    property color themeAccent: "#00f0ff"
    property color themeAccentAlt: "#e6458e"

    property bool splashEnabled: true
    property string selectedCategory: "LIBRARY"
    property string searchQuery: ""
    property string viewMode: "sidebar" // "grid", "carousel", "desktop", "sidebar"
    property var catalogData: []
    property var filteredGames: []
    property int focusedIndex: 0
    property string focusedGameTitle: ""

    onActiveFocusItemChanged: {
        if (!activeFocusItem && keyboardController) {
            keyboardController.forceActiveFocus();
        }
    }

    function restoreKeyboardFocus() {
        if (searchInput.activeFocus) {
            searchInput.focus = false;
        }
        if (keyboardController) {
            keyboardController.forceActiveFocus();
        }
    }

    Connections {
        target: (typeof arcadeBackend !== "undefined") ? arcadeBackend : null
        function onThemeChanged(colors) {
            if (colors.themeBackground) root.themeBackground = colors.themeBackground;
            if (colors.themeSurface) root.themeSurface = colors.themeSurface;
            if (colors.themeSurfaceLight) root.themeSurfaceLight = colors.themeSurfaceLight;
            if (colors.themeBorder) root.themeBorder = colors.themeBorder;
            if (colors.themeText) root.themeText = colors.themeText;
            if (colors.themeTextMuted) root.themeTextMuted = colors.themeTextMuted;
            if (colors.themeAccent) root.themeAccent = colors.themeAccent;
            if (colors.themeAccentAlt) root.themeAccentAlt = colors.themeAccentAlt;
        }
        function onGameLaunched(gameId) {
            detailSheet.close();
            root.hide();
        }
        function onGameInstalled(gameId) {
            if (detailSheet.gameData && detailSheet.gameData.id === gameId) {
                detailSheet.isDownloading = false;
                detailSheet.isInstalled = true;
            }
            root.refreshCategories();
            root.updateFilter();
            root.launchGame(gameId);
        }
        function onGameInstallFailed(gameId, errorMsg) {
            if (detailSheet.gameData && detailSheet.gameData.id === gameId) {
                detailSheet.isDownloading = false;
            }
            root.show();
            root.raise();
            root.requestActivate();
            keyboardController.forceActiveFocus();
        }
        function onGameFinished(gameId) {
            root.show();
            root.raise();
            root.requestActivate();
            keyboardController.forceActiveFocus();
        }
        function onGameLaunchFailed(gameId, errorMsg) {
            if (detailSheet.gameData && detailSheet.gameData.id === gameId) {
                detailSheet.isDownloading = false;
            }
            root.show();
            root.raise();
            root.requestActivate();
            keyboardController.forceActiveFocus();
        }
    }

    function updateFocusedGameTitle() {
        if (focusedIndex >= 0 && filteredGames && focusedIndex < filteredGames.length) {
            var g = filteredGames[focusedIndex];
            if (g && g.title) {
                var sz = g.size ? (" • " + g.size) : "";
                focusedGameTitle = g.title + sz + "  [" + (focusedIndex + 1) + "/" + filteredGames.length + "]";
                return;
            }
        }
        focusedGameTitle = "";
    }

    onFocusedIndexChanged: updateFocusedGameTitle()

    function cycleCategory(delta) {
        var curr = 0;
        for (var i = 0; i < categoryList.length; i++) {
            if (categoryList[i].name === selectedCategory) {
                curr = i;
                break;
            }
        }
        var next = (curr + delta + categoryList.length) % categoryList.length;
        selectedCategory = categoryList[next].name;
        focusedIndex = 0;
        ensureFocusedVisible();
    }

    function cycleViewMode() {
        var modes = ["grid", "carousel", "desktop", "sidebar"];
        var idx = modes.indexOf(viewMode);
        var next = (idx + 1) % modes.length;
        setViewMode(modes[next]);
    }

    function setViewMode(mode) {
        if (mode === viewMode) return;
        viewMode = mode;
        if (typeof arcadeBackend !== "undefined" && arcadeBackend.setViewMode) {
            arcadeBackend.setViewMode(mode);
        }
        ensureFocusedVisible();
        restoreKeyboardFocus();
    }

    function ensureFocusedVisible() {
        if (focusedIndex < 0 || focusedIndex >= filteredGames.length) return;
        if (viewMode === "grid") {
            var cols = Math.max(1, gridScroll.numCols);
            var row = Math.floor(focusedIndex / cols);
            var cardTop = 20 + row * (286 + 22);
            var cardBottom = cardTop + 286;
            var viewTop = gridScroll.contentItem.contentY;
            var viewHeight = gridScroll.height;

            if (cardTop < viewTop) {
                gridScroll.contentItem.contentY = Math.max(0, cardTop - 20);
            } else if (cardBottom > (viewTop + viewHeight)) {
                gridScroll.contentItem.contentY = Math.max(0, cardBottom - viewHeight + 20);
            }
        }
    }

    onFilteredGamesChanged: {
        if (filteredGames.length === 0) {
            focusedIndex = -1;
        } else if (focusedIndex < 0 || focusedIndex >= filteredGames.length) {
            focusedIndex = 0;
        }
        updateFocusedGameTitle();
    }

    function isInstalled(gameId) {
        if (!gameId) return false;
        if (typeof arcadeBackend !== "undefined" && arcadeBackend.isGameInstalled) {
            return arcadeBackend.isGameInstalled(gameId);
        }
        return true;
    }

    function getLibraryCount() {
        var n = 0;
        for (var i = 0; i < catalogData.length; i++) {
            var g = catalogData[i];
            if (g.status === "unreleased") continue;
            if (isInstalled(g.id)) {
                n++;
            }
        }
        return n;
    }

    property var categoryList: [
        { name: "LIBRARY", label: "💾 My Library (31)" },
        { name: "ALL", label: "🎮 All Games (31)" },
        { name: "ACTION ARCADE", label: "⚡ Action (10)" },
        { name: "PUZZLES & GRID LOGIC", label: "🧩 Puzzles (4)" },
        { name: "BLOCKS & MERGING", label: "🧱 Blocks (2)" },
        { name: "BOARD & TABLETOP", label: "♟️ Tabletop (7)" },
        { name: "CARDS & CASINO", label: "🃏 Cards (3)" },
        { name: "CASUAL AIM & PHYSICS", label: "🫧 Casual (2)" },
        { name: "WORD & TRIVIA", label: "🔤 Word (1)" },
        { name: "UNRELEASED", label: "⏳ Coming Soon (0)" }
    ]

    onSelectedCategoryChanged: updateFilter()
    onSearchQueryChanged: updateFilter()

    // Responsive collapse breakpoint
    readonly property bool isCompact: width < 760

    function getPlayableCount(catName) {
        var n = 0;
        for (var i = 0; i < catalogData.length; i++) {
            var g = catalogData[i];
            if (g.status === "unreleased") continue;
            if (catName === "ALL") {
                n++;
            } else if (catName === "BOARD & TABLETOP" && (g.category.toUpperCase().indexOf("BOARD") !== -1 || g.category.toUpperCase().indexOf("TABLETOP") !== -1)) {
                n++;
            } else if (g.category.toUpperCase() === catName) {
                n++;
            }
        }
        return n;
    }

    function getUnreleasedCount() {
        var n = 0;
        for (var i = 0; i < catalogData.length; i++) {
            if (catalogData[i].status === "unreleased") n++;
        }
        return n;
    }

    function refreshCategories() {
        categoryList = [
            { name: "LIBRARY", label: "💾 My Library (" + getLibraryCount() + ")" },
            { name: "ALL", label: "🎮 All Games (" + getPlayableCount("ALL") + ")" },
            { name: "ACTION ARCADE", label: "⚡ Action (" + getPlayableCount("ACTION ARCADE") + ")" },
            { name: "PUZZLES & GRID LOGIC", label: "🧩 Puzzles (" + getPlayableCount("PUZZLES & GRID LOGIC") + ")" },
            { name: "BLOCKS & MERGING", label: "🧱 Blocks (" + getPlayableCount("BLOCKS & MERGING") + ")" },
            { name: "BOARD & TABLETOP", label: "♟️ Tabletop (" + getPlayableCount("BOARD & TABLETOP") + ")" },
            { name: "CARDS & CASINO", label: "🃏 Cards (" + getPlayableCount("CARDS & CASINO") + ")" },
            { name: "CASUAL AIM & PHYSICS", label: "🫧 Casual (" + getPlayableCount("CASUAL AIM & PHYSICS") + ")" },
            { name: "WORD & TRIVIA", label: "🔤 Word (" + getPlayableCount("WORD & TRIVIA") + ")" },
            { name: "UNRELEASED", label: "⏳ Coming Soon (" + getUnreleasedCount() + ")" }
        ];
    }

    // Load Catalog Data on Startup
    Component.onCompleted: {
        if (typeof arcadeBackend !== "undefined" && arcadeBackend.getViewMode) {
            var savedMode = arcadeBackend.getViewMode();
            if (savedMode) root.viewMode = savedMode;
        }
        loadCatalog();
        keyboardController.forceActiveFocus();
    }

    function loadCatalog() {
        if (typeof arcadeBackend !== "undefined" && arcadeBackend.getCatalogJson) {
            try {
                var jsonStr = arcadeBackend.getCatalogJson();
                if (jsonStr && jsonStr.length > 2) {
                    var parsed = JSON.parse(jsonStr);
                    catalogData = parsed.games || [];
                    refreshCategories();
                    updateFilter();
                    return;
                }
            } catch(e) {
                console.log("[Arcade] Error parsing catalog from backend: " + e);
            }
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", "../catalog.json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.responseText) {
                    try {
                        var parsed = JSON.parse(xhr.responseText);
                        catalogData = parsed.games || [];
                        refreshCategories();
                        updateFilter();
                    } catch(e) {
                        console.log("Error parsing catalog.json: " + e);
                    }
                }
            }
        };
        xhr.send();
    }

    function updateFilter() {
        var query = searchQuery.trim().toLowerCase();
        var cat = selectedCategory;
        var list = [];

        for (var i = 0; i < catalogData.length; i++) {
            var g = catalogData[i];
            var isUnrel = (g.status === "unreleased");

            var matchesCat = false;
            if (cat === "LIBRARY") {
                matchesCat = !isUnrel && root.isInstalled(g.id);
            } else if (cat === "ALL") {
                // "ALL" displays released playable games (unreleased games are in COMING SOON)
                matchesCat = !isUnrel;
            } else if (cat === "UNRELEASED") {
                matchesCat = isUnrel;
            } else if (cat === "BOARD & TABLETOP") {
                matchesCat = !isUnrel && (g.category.toUpperCase().indexOf("BOARD") !== -1 || g.category.toUpperCase().indexOf("TABLETOP") !== -1);
            } else if (g.category.toUpperCase() === cat) {
                matchesCat = true;
            }

            var matchesSearch = (query === "" || 
                                 g.title.toLowerCase().indexOf(query) !== -1 || 
                                 g.category.toLowerCase().indexOf(query) !== -1 || 
                                 g.tagline.toLowerCase().indexOf(query) !== -1 ||
                                 g.ref.toLowerCase().indexOf(query) !== -1);

            // If user explicitly searches for a query, show matching games even if unreleased
            if (query !== "" && matchesSearch) {
                list.push(g);
            } else if (matchesCat && matchesSearch) {
                list.push(g);
            }
        }
        filteredGames = list;
    }

    // Launch game implementation
    function launchGame(gameId) {
        if (typeof arcadeBackend !== "undefined" && arcadeBackend) {
            arcadeBackend.launchGame(gameId);
        } else {
            console.log("Launching game: " + gameId);
        }
    }

    // --- Background Retro CRT Grid Pattern ---
    Canvas {
        anchors.fill: parent
        opacity: 0.05
        onPaint: {
            var ctx = getContext("2d");
            ctx.strokeStyle = "#FFFFFF";
            ctx.lineWidth = 1;
            for (var x = 0; x < width; x += 32) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
            }
            for (var y = 0; y < height; y += 32) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
            }
        }
    }

    // --- Main Layout ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // TOP TOOLBAR & HEADER
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: themeSurface
            border.color: themeBorder
            border.width: 1
            z: 20

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                // Canonical Retro Omarchy Arcade Brand Logo
                Item {
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: Math.round(42 * (1004 / 233))
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: headerLogoImg
                        anchors.fill: parent
                        source: "omarchy_arcade_logo.svg"
                        sourceSize.height: 84
                        sourceSize.width: Math.round(84 * (1004 / 233))
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            aboutModal.visible = true;
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // View Mode Switcher [Grid | Carousel | Desktop | Sidebar]
                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: viewSwitcherRow.implicitWidth + 8
                    radius: 8
                    color: themeBackground
                    border.color: themeBorder
                    border.width: 1

                    Row {
                        id: viewSwitcherRow
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                { id: "grid", icon: "⊞", label: "Grid", tooltip: "Floppy Grid (F1)" },
                                { id: "carousel", icon: "🎡", label: "Carousel", tooltip: "Stage & Carousel (F2)" },
                                { id: "desktop", icon: "🖥️", label: "Desktop", tooltip: "Desktop Icons (F3)" },
                                { id: "sidebar", icon: "📑", label: "Sidebar", tooltip: "Library List (F4)" }
                            ]

                            Rectangle {
                                width: root.isCompact ? 32 : (viewModeBtnText.implicitWidth + 26)
                                height: 28
                                radius: 6
                                color: root.viewMode === modelData.id ? themeAccent : (viewBtnMouse.containsMouse ? "#232332" : "transparent")
                                border.color: root.viewMode === modelData.id ? themeAccent : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 12
                                        color: root.viewMode === modelData.id ? "#09090e" : (viewBtnMouse.containsMouse ? "#FFFFFF" : "#94a3b8")
                                    }

                                    Text {
                                        id: viewModeBtnText
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: root.viewMode === modelData.id
                                        color: root.viewMode === modelData.id ? "#09090e" : (viewBtnMouse.containsMouse ? "#FFFFFF" : "#94a3b8")
                                        visible: !root.isCompact
                                    }
                                }

                                MouseArea {
                                    id: viewBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setViewMode(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // Search Box (Instant Type-to-Filter)
                Rectangle {
                    Layout.preferredWidth: root.isCompact ? 160 : 260
                    Layout.preferredHeight: 36
                    radius: 8
                    color: themeBackground
                    border.color: searchInput.activeFocus ? themeAccent : themeBorder
                    border.width: 1.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text { text: "🔍"; font.pixelSize: 12; opacity: 0.7 }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            selectByMouse: true
                            clip: true

                            Text {
                                text: root.isCompact ? "Search..." : "Search games (/ or Ctrl+F)..."
                                color: "#64748b"
                                font.pixelSize: 12
                                visible: !searchInput.text && !searchInput.activeFocus
                            }

                            onTextChanged: {
                                root.searchQuery = text;
                                root.updateFilter();
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    searchInput.text = "";
                                    root.searchQuery = "";
                                    root.updateFilter();
                                    root.restoreKeyboardFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.restoreKeyboardFocus();
                                    root.focusedIndex = 0;
                                    root.ensureFocusedVisible();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    root.restoreKeyboardFocus();
                                    event.accepted = true;
                                }
                            }
                        }

                        // Clear search button
                        Text {
                            visible: searchInput.text.length > 0
                            text: "✕"
                            font.pixelSize: 11
                            color: "#94a3b8"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    root.searchQuery = "";
                                    root.updateFilter();
                                    root.restoreKeyboardFocus();
                                }
                            }
                        }
                    }
                }

                // Help / About Button (Responsive Emoji Collapse)
                Button {
                    id: helpBtn
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: root.isCompact ? 36 : helpRow.implicitWidth + 20

                    background: Rectangle {
                        radius: 8
                        color: helpBtn.down ? themeSurfaceLight : (helpBtn.hovered ? "#262638" : "transparent")
                        border.color: themeBorder
                        border.width: 1
                    }

                    contentItem: Row {
                        id: helpRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "❓"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "About"
                            font.pixelSize: 12
                            font.bold: true
                            color: themeText
                            visible: !root.isCompact
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    onClicked: aboutModal.visible = true
                }
            }
        }

        // =====================================================================
        // CATEGORY FILTER PILLS BAR
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: "#14141c"
            border.color: themeBorder
            border.width: 1
            z: 10

            ScrollView {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                contentHeight: parent.height
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: root.categoryList

                        Rectangle {
                            height: 30
                            radius: 15
                            width: pillText.implicitWidth + 22
                            color: root.selectedCategory === modelData.name ? themeAccent : (pillMouse.containsMouse ? "#262638" : "#1a1a24")
                            border.color: root.selectedCategory === modelData.name ? themeAccent : (pillMouse.containsMouse ? "#3b3b50" : "#2a2a3a")
                            border.width: 1

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 12
                                font.bold: true
                                color: root.selectedCategory === modelData.name ? "#0a0a0f" : (pillMouse.containsMouse ? "#FFFFFF" : "#cbd5e1")
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedCategory = modelData.name;
                                    root.updateFilter();
                                    root.restoreKeyboardFocus();
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MAIN CONTENT VIEWS (Grid / Carousel / Desktop / Sidebar)
        // =====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 1. Grid View (Floppy Wall)
            ScrollView {
                id: gridScroll
                anchors.fill: parent
                clip: true
                visible: root.viewMode === "grid"
                contentWidth: gridScroll.width
                contentHeight: flowGrid.height + 60
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: root.restoreKeyboardFocus()
                }

                readonly property int cardWidth: 220
                readonly property int cardSpacing: 22
                readonly property int minMargin: 24

                // Calculate how many columns can fit with at least minMargin on each side
                readonly property int numCols: Math.max(1, Math.floor((gridScroll.width - (minMargin * 2) + cardSpacing) / (cardWidth + cardSpacing)))
                // Exact width for numCols cards
                readonly property int exactRowWidth: (numCols * cardWidth) + ((numCols - 1) * cardSpacing)

                // Flow Grid of Floppy Cards
                Flow {
                    id: flowGrid
                    width: gridScroll.exactRowWidth
                    // Strictly positive, never cut off on the left, perfectly centered
                    x: Math.max(gridScroll.minMargin, Math.floor((gridScroll.width - width) / 2))
                    y: 20
                    spacing: gridScroll.cardSpacing

                    Repeater {
                        id: cardRepeater
                        model: root.filteredGames

                        FloppyCard {
                            gameData: modelData
                            isFocused: (index === root.focusedIndex)
                            onClicked: {
                                root.focusedIndex = index;
                                detailSheet.open(modelData);
                            }
                        }
                    }
                }
            }

            // 2. Carousel / Stage View (Disks on bottom, details on top)
            ViewCarousel {
                id: carouselView
                anchors.fill: parent
                visible: root.viewMode === "carousel"
                games: root.filteredGames
                selectedIndex: root.focusedIndex
                onGameSelected: function(idx) {
                    root.focusedIndex = idx;
                }
                onGameLaunched: function(gameId) {
                    root.launchGame(gameId);
                }
                onDetailRequested: function(data) {
                    detailSheet.open(data);
                }
            }

            // 3. Retro Desktop Icons View
            ViewDesktop {
                id: desktopView
                anchors.fill: parent
                visible: root.viewMode === "desktop"
                games: root.filteredGames
                selectedIndex: root.focusedIndex
                onGameSelected: function(idx) {
                    root.focusedIndex = idx;
                }
                onGameLaunched: function(gameId) {
                    root.launchGame(gameId);
                }
                onDetailRequested: function(data) {
                    detailSheet.open(data);
                }
            }

            // 4. Sidebar Library List View
            ViewSidebar {
                id: sidebarView
                anchors.fill: parent
                visible: root.viewMode === "sidebar"
                games: root.filteredGames
                selectedIndex: root.focusedIndex
                onGameSelected: function(idx) {
                    root.focusedIndex = idx;
                }
                onGameLaunched: function(gameId) {
                    root.launchGame(gameId);
                }
                onDetailRequested: function(data) {
                    detailSheet.open(data);
                }
            }

            // Empty Search State
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: root.filteredGames.length === 0
                z: 50

                Text {
                    text: root.searchQuery.trim() !== "" ? "🔍" : (root.selectedCategory === "LIBRARY" ? "💾" : "🎮")
                    font.pixelSize: 36
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.searchQuery.trim() !== "" ? 
                          ("No games found matching '" + root.searchQuery + "'") : 
                          (root.selectedCategory === "LIBRARY" ? "No games installed in your library yet" : "No games found in this category")
                    font.pixelSize: 15
                    font.bold: true
                    color: "#94a3b8"
                    Layout.alignment: Qt.AlignHCenter
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searchQuery.trim() !== "" ? "Clear Search" : "Browse All Games"
                    onClicked: {
                        searchInput.text = "";
                        root.selectedCategory = "ALL";
                        root.updateFilter();
                    }
                }
            }
        }

        // =====================================================================
        // BOTTOM KEYBOARD NAVIGATION FOOTER BAR
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: "#101017"
            border.color: themeBorder
            border.width: 1
            z: 25

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 28; height: 18; radius: 4
                        color: "#1c1c28"; border.color: "#333348"; border.width: 1
                        Text { anchors.centerIn: parent; text: "1-9"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: themeAccent }
                    }
                    Text { text: "Categories"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
                }

                Text { text: "•"; font.pixelSize: 11; color: "#2d2d3d" }

                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 34; height: 18; radius: 4
                        color: "#1c1c28"; border.color: "#333348"; border.width: 1
                        Text { anchors.centerIn: parent; text: "HJKL"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: themeAccent }
                    }
                    Text { text: "Browse"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
                }

                Text { text: "•"; font.pixelSize: 11; color: "#2d2d3d" }

                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 44; height: 18; radius: 4
                        color: "#1c1c28"; border.color: "#333348"; border.width: 1
                        Text { anchors.centerIn: parent; text: "Enter"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: themeAccent }
                    }
                    Text { text: "Details"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
                }

                Text { text: "•"; font.pixelSize: 11; color: "#2d2d3d" }

                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 18; height: 18; radius: 4
                        color: "#1c1c28"; border.color: "#333348"; border.width: 1
                        Text { anchors.centerIn: parent; text: "/"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: themeAccent }
                    }
                    Text { text: "Search"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
                }

                Text { text: "•"; font.pixelSize: 11; color: "#2d2d3d" }

                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 18; height: 18; radius: 4
                        color: "#1c1c28"; border.color: "#333348"; border.width: 1
                        Text { anchors.centerIn: parent; text: "V"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: themeAccent }
                    }
                    Text { text: "View Mode"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
                }

                Item { Layout.fillWidth: true }

                Text {
                    id: statusGameText
                    Layout.alignment: Qt.AlignVCenter
                    text: root.focusedGameTitle
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: themeAccentAlt
                }
            }
        }
    }

    // =========================================================================
    // GAME DETAIL MODAL SHEET (Steam-Style Presentation Sheet)
    // =========================================================================
    GameDetailSheet {
        id: detailSheet
        onPlayRequested: function(gameId) {
            root.launchGame(gameId);
        }
    }

    // =========================================================================
    // ABOUT / CREDITS MODAL
    // =========================================================================
    Rectangle {
        id: aboutModal
        anchors.fill: parent
        color: "#e60a0a10"
        z: 300
        visible: false

        MouseArea { anchors.fill: parent; onClicked: aboutModal.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.90, 520)
            height: Math.min(parent.height * 0.85, 460)
            radius: 12
            color: "#181824"
            border.color: themeAccent
            border.width: 1.5

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                RowLayout {
                    spacing: 10
                    Text { text: "💾"; font.pixelSize: 26 }
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Omarchy Arcade"; font.pixelSize: 20; font.bold: true; color: "#FFFFFF" }
                        Text { text: "Version 1.0.0 • Pure QML & Offline Suite"; font.pixelSize: 11; color: themeAccent }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "✕"
                        font.pixelSize: 16
                        color: "#94a3b8"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: aboutModal.visible = false }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: themeBorder }

                Text {
                    text: "THE DEFINITIVE DESKTOP ARCADE"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: themeAccentAlt
                }

                Text {
                    text: "Built exclusively for the Omarchy Linux desktop environment, featuring zero network telemetry, instant sub-second launch, vector aesthetics, and tiling window manager optimization."
                    font.pixelSize: 12
                    color: "#cbd5e1"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: "#121218"
                    border.color: "#242432"
                    border.width: 1
                    Layout.margins: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text { text: "AUTHOR & CREDITS"; font.family: "monospace"; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
                        Text { text: "• Created by Chris Thompson (@bigcjat)"; font.pixelSize: 12; font.bold: true; color: "#FFFFFF" }
                        Text { text: "• Designed and developed with assistance from Google Gemini"; font.pixelSize: 12; color: "#94a3b8" }
                        Text { text: "• Offline Play — Zero DRM, Zero Cloud Sockets"; font.pixelSize: 12; color: "#22c55e" }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 6
                    color: aboutCloseMouse.pressed ? "#161622" : (aboutCloseMouse.containsMouse ? "#262638" : "#1a1a26")
                    border.color: aboutCloseMouse.containsMouse ? "#474760" : "#2e2e40"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        font.pixelSize: 12
                        font.bold: true
                        color: aboutCloseMouse.containsMouse ? "#FFFFFF" : "#cbd5e1"
                    }

                    MouseArea {
                        id: aboutCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutModal.visible = false
                    }
                }
            }
        }
    }

    // =========================================================================
    // CANONICAL RETRO STARTUP SPLASH SCREEN
    // =========================================================================
    SplashScreen {
        id: splashScreen
        focusTarget: keyboardController
        onDismissed: {
            root.restoreKeyboardFocus();
        }
    }

    // Primary Keyboard Navigation Engine
    Item {
        id: keyboardController
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (splashScreen.visible) {
                splashScreen.dismiss();
            }
            if (aboutModal.visible) {
                if (event.key === Qt.Key_Escape) {
                    aboutModal.visible = false;
                    root.restoreKeyboardFocus();
                    event.accepted = true;
                }
                return;
            }
            if (detailSheet.visible) {
                return;
            }
            if (searchInput.activeFocus) {
                if (event.key === Qt.Key_Escape) {
                    searchInput.text = "";
                    root.searchQuery = "";
                    root.updateFilter();
                    root.restoreKeyboardFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.restoreKeyboardFocus();
                    root.focusedIndex = 0;
                    root.ensureFocusedVisible();
                    event.accepted = true;
                }
                return;
            }

            // 1-9 directly select categories
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                var catIdx = event.key - Qt.Key_1;
                if (catIdx < root.categoryList.length) {
                    root.selectedCategory = root.categoryList[catIdx].name;
                    root.focusedIndex = 0;
                    root.ensureFocusedVisible();
                    root.restoreKeyboardFocus();
                    event.accepted = true;
                    return;
                }
            }

            // Bracket keys [ and ] or Tab / Shift+Tab to cycle categories
            if (event.key === Qt.Key_BracketLeft || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.cycleCategory(-1);
                root.restoreKeyboardFocus();
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_Tab) {
                root.cycleCategory(1);
                root.restoreKeyboardFocus();
                event.accepted = true;
                return;
            }

            // V key cycles view modes
            if (event.key === Qt.Key_V) {
                root.cycleViewMode();
                event.accepted = true;
                return;
            }

            // F1-F4 jump directly to view modes
            if (event.key === Qt.Key_F1) {
                root.setViewMode("grid");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_F2) {
                root.setViewMode("carousel");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_F3) {
                root.setViewMode("desktop");
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_F4) {
                root.setViewMode("sidebar");
                event.accepted = true;
                return;
            }

            var total = root.filteredGames.length;
            if (total === 0) return;

            // View-specific arrow & HJKL navigation
            if (root.viewMode === "sidebar") {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + 1);
                    event.accepted = true;
                    return;
                }
            } else if (root.viewMode === "carousel") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + 1);
                    event.accepted = true;
                    return;
                }
            } else if (root.viewMode === "desktop") {
                var dCols = Math.max(1, Math.floor((root.width - 48) / 120));
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + 1);
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - dCols);
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + dCols);
                    event.accepted = true;
                    return;
                }
            } else {
                var cols = Math.max(1, gridScroll.numCols);
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                    root.ensureFocusedVisible();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + 1);
                    root.ensureFocusedVisible();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.focusedIndex = Math.max(0, root.focusedIndex - cols);
                    root.ensureFocusedVisible();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.focusedIndex = Math.min(total - 1, root.focusedIndex + cols);
                    root.ensureFocusedVisible();
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.focusedIndex >= 0 && root.focusedIndex < total) {
                    var targetGame = root.filteredGames[root.focusedIndex];
                    if (root.viewMode === "carousel" || root.viewMode === "desktop" || root.viewMode === "sidebar") {
                        root.launchGame(targetGame.id);
                    } else {
                        detailSheet.open(targetGame);
                    }
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Space) {
                if (root.focusedIndex >= 0 && root.focusedIndex < total) {
                    detailSheet.open(root.filteredGames[root.focusedIndex]);
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Slash) {
                searchInput.forceActiveFocus();
                Qt.callLater(function() {
                    if (searchInput.text === "/") {
                        searchInput.text = "";
                    }
                    searchInput.selectAll();
                });
                event.accepted = true;
            } else if (event.key === Qt.Key_Question) {
                aboutModal.visible = true;
                event.accepted = true;
            }
        }
    }

    // Keyboard Navigation Shortcuts
    Shortcut {
        sequence: "/"
        enabled: !searchInput.activeFocus && !detailSheet.visible && !aboutModal.visible
        onActivated: {
            searchInput.forceActiveFocus();
            Qt.callLater(function() {
                if (searchInput.text === "/") {
                    searchInput.text = "";
                }
                searchInput.selectAll();
            });
        }
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !detailSheet.visible && !aboutModal.visible
        onActivated: {
            searchInput.forceActiveFocus();
            searchInput.selectAll();
        }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (aboutModal.visible) {
                aboutModal.visible = false;
                root.restoreKeyboardFocus();
            } else if (detailSheet.visible) {
                detailSheet.close();
                root.restoreKeyboardFocus();
            } else if (searchInput.activeFocus || searchInput.text.length > 0) {
                searchInput.text = "";
                root.searchQuery = "";
                root.updateFilter();
                root.restoreKeyboardFocus();
            } else {
                root.restoreKeyboardFocus();
            }
        }
    }
}
