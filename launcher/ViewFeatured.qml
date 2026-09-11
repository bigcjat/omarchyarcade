import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: featuredView
    objectName: "featuredView"
    anchors.fill: parent

    property var catalog: []
    signal gameLaunched(string gameId)
    signal detailRequested(var gameData)

    // Helper functions to resolve game data
    function getGameById(id) {
        if (!catalog) return null;
        for (var i = 0; i < catalog.length; i++) {
            if (catalog[i].id === id) return catalog[i];
        }
        return null;
    }

    readonly property var skyAceData: getGameById("skyace")

    readonly property var staffPicksList: {
        var list = [];
        var ids = ["skyace", "2048", "fold", "bytecity", "bidama", "nutssort"];
        for (var i = 0; i < ids.length; i++) {
            var g = getGameById(ids[i]);
            if (g) list.push(g);
        }
        return list;
    }

    readonly property var newestReleasesList: {
        if (!catalog || catalog.length === 0) return [];
        var sorted = catalog.slice().sort(function(a, b) {
            var da = a.date_added || "";
            var db = b.date_added || "";
            if (db !== da) return db.localeCompare(da);
            return (b.ref || "").localeCompare(a.ref || "");
        });
        return sorted.slice(0, 3);
    }

    // --- Ambient Background ---
    Rectangle {
        anchors.fill: parent
        color: typeof root !== "undefined" ? root.themeBackground : "#111116"

        // Subtle ambient glow from top
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: 400
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#150284c7" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // --- Main Scrollable Container ---
    Flickable {
        id: featuredScroll
        objectName: "featuredScroll"
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: vBar
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: vBar.pressed ? "#00f0ff" : (vBar.hovered ? "#80ffffff" : "#40ffffff")
            }
        }

        Column {
            id: contentCol
            width: Math.min(featuredScroll.width - 48, 1140)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 24
            spacing: 34

            // =====================================================================
            // 1. HERO SHOWCASE: SKY ACE PREMIERE
            // =====================================================================
            Rectangle {
                id: heroBox
                readonly property bool isCompact: heroBox.width < 720
                width: parent.width
                height: isCompact ? 270 : 310
                radius: 14
                color: "#161622"
                border.color: "#0284C7"
                border.width: 1.5
                clip: true

                // Background animated preview / video
                Item {
                    anchors.fill: parent

                    AnimatedImage {
                        id: heroPreviewAnim
                        anchors.fill: parent
                        source: {
                            if (typeof arcadeBackend !== "undefined" && arcadeBackend.getScreenshotUrl) {
                                return arcadeBackend.getScreenshotUrl("games/skyace");
                            }
                            return "../assets/previews/skyace.webp";
                        }
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        playing: true
                        opacity: 0.88
                    }

                    // Cinematic multi-stop gradient overlay for high text legibility
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#400a0e17" }
                            GradientStop { position: 0.45; color: "#800a0e17" }
                            GradientStop { position: 0.85; color: "#ea0c121e" }
                            GradientStop { position: 1.0; color: "#fc090d18" }
                        }
                    }

                    // Scanline / vignette effect
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#300284c7"
                        border.width: 1
                        radius: 14
                    }
                }

                // Hero Content Overlay (Top-Left Badge, Bottom Details)
                // Top Premiere Tag
                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 8

                    Rectangle {
                        height: 26
                        width: premiereText.implicitWidth + 20
                        radius: 13
                        color: "#0284C7"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "★"
                                font.pixelSize: 11
                                color: "#FFFFFF"
                            }
                            Text {
                                id: premiereText
                                text: "FEATURED PREMIERE"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }
                    }

                    Rectangle {
                        height: 26
                        width: refBadgeText.implicitWidth + 16
                        radius: 6
                        color: "#20000000"
                        border.color: "#800284c7"
                        border.width: 1

                        Text {
                            id: refBadgeText
                            anchors.centerIn: parent
                            text: "OA-039"
                            font.family: "Menlo, Consolas, monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#38bdf8"
                        }
                    }
                }

                // Bottom Hero Details Strip (Compact, doesn't take up excessive room)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: heroBox.isCompact ? 120 : 100
                    color: "#f0080b12"
                    border.color: "#1e293b"
                    border.width: 1

                    // Top accent border line
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#0284C7"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        spacing: 16

                        // Left Title & Meta details
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: "SKY ACE"
                                    font.pixelSize: heroBox.isCompact ? 20 : 24
                                    font.bold: true
                                    color: "#FFFFFF"
                                }

                                Rectangle {
                                    height: 18
                                    width: actionTag.implicitWidth + 12
                                    radius: 4
                                    color: "#1e3a8a"
                                    border.color: "#38bdf8"
                                    border.width: 1

                                    Text {
                                        id: actionTag
                                        anchors.centerIn: parent
                                        text: "Action Arcade"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#93c5fd"
                                    }
                                }

                                Rectangle {
                                    height: 18
                                    width: sizeTag.implicitWidth + 12
                                    radius: 4
                                    color: "#14532d"
                                    border.color: "#4ade80"
                                    border.width: 1

                                    Text {
                                        id: sizeTag
                                        anchors.centerIn: parent
                                        text: "40.6 MB"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#86efac"
                                    }
                                }
                            }

                            Text {
                                text: "194X Global Air War • 10 Theaters & Pre-Baked 3D Warbirds • Multi-Phase Fortress Bosses"
                                font.pixelSize: heroBox.isCompact ? 11 : 12
                                color: "#94a3b8"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Right Action Buttons (Play Now + Details)
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 10

                            // Play Now Primary Action Button
                            Rectangle {
                                width: playBtnText.implicitWidth + 34
                                height: 40
                                radius: 8
                                color: playBtnMouse.containsMouse ? "#38bdf8" : "#0284c7"
                                border.color: "#7dd3fc"
                                border.width: 1
                                scale: playBtnMouse.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: "▶"
                                        font.pixelSize: 13
                                        color: "#FFFFFF"
                                    }
                                    Text {
                                        id: playBtnText
                                        text: "PLAY NOW"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }

                                MouseArea {
                                    id: playBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        featuredView.gameLaunched("skyace");
                                    }
                                }
                            }

                            // Details Secondary Button
                            Rectangle {
                                width: detailBtnText.implicitWidth + 24
                                height: 40
                                radius: 8
                                color: detailBtnMouse.containsMouse ? "#2a2d3d" : "#1a1d2d"
                                border.color: "#3b4261"
                                border.width: 1
                                scale: detailBtnMouse.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }

                                Text {
                                    id: detailBtnText
                                    anchors.centerIn: parent
                                    text: "ⓘ DETAILS"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#cbd5e1"
                                }

                                MouseArea {
                                    id: detailBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (skyAceData) {
                                            featuredView.detailRequested(skyAceData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =====================================================================
            // 2. STAFF PICKS SECTION (6 Curated Games)
            // =====================================================================
            Column {
                width: parent.width
                spacing: 16

                // Section Header Row
                RowLayout {
                    width: parent.width

                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Text {
                                text: "⭐"
                                font.pixelSize: 18
                            }
                            Text {
                                text: "STAFF PICKS"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }
                        Text {
                            text: "Handcrafted retro arcade favorites curated by the team"
                            font.pixelSize: 12
                            color: "#94a3b8"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Scroll Navigation Arrow Buttons
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: leftArrMouse.containsMouse ? "#2a2d3d" : "#1a1d2d"
                            border.color: "#334155"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "◀"
                                font.pixelSize: 11
                                color: leftArrMouse.containsMouse ? "#00f0ff" : "#94a3b8"
                            }
                            MouseArea {
                                id: leftArrMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: staffFlickable.contentX = Math.max(0, staffFlickable.contentX - 250)
                            }
                        }
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: rightArrMouse.containsMouse ? "#2a2d3d" : "#1a1d2d"
                            border.color: "#334155"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                font.pixelSize: 11
                                color: rightArrMouse.containsMouse ? "#00f0ff" : "#94a3b8"
                            }
                            MouseArea {
                                id: rightArrMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: staffFlickable.contentX = Math.min(staffFlickable.contentWidth - staffFlickable.width, staffFlickable.contentX + 250)
                            }
                        }
                    }
                }

                // Horizontal Carousel / Row of Staff Pick Floppy Cards
                Flickable {
                    id: staffFlickable
                    width: parent.width
                    height: 300
                    contentWidth: staffRow.width
                    contentHeight: 300
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: staffRow
                        spacing: 20
                        padding: 6

                        Repeater {
                            model: featuredView.staffPicksList

                            FloppyCard {
                                gameData: modelData
                                isFocused: false
                                onClicked: {
                                    featuredView.detailRequested(modelData);
                                }
                            }
                        }
                    }
                }
            }

            // =====================================================================
            // 3. NEWEST RELEASES SHELF (3 Latest Games)
            // =====================================================================
            Column {
                width: parent.width
                spacing: 16

                // Section Header Row
                RowLayout {
                    width: parent.width

                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Text {
                                text: "🔥"
                                font.pixelSize: 18
                            }
                            Text {
                                text: "NEW RELEASES"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }
                        Text {
                            text: "The latest creations fresh out of the Omarchy Arcade lab"
                            font.pixelSize: 12
                            color: "#94a3b8"
                        }
                    }
                }

                // 3-Card Responsive Shelf
                Flow {
                    width: parent.width
                    spacing: 18

                    Repeater {
                        model: featuredView.newestReleasesList

                        Rectangle {
                            id: newReleaseCard
                            width: featuredView.width > 900 ? ((parent.width - 36) / 3) : (featuredView.width > 600 ? ((parent.width - 18) / 2) : parent.width)
                            height: 190
                            radius: 12
                            color: cardMouse.containsMouse ? "#1e2233" : "#161824"
                            border.color: cardMouse.containsMouse ? (modelData.grid_color || "#00f0ff") : "#282c3f"
                            border.width: cardMouse.containsMouse ? 1.5 : 1
                            scale: cardMouse.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            clip: true

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    featuredView.detailRequested(modelData);
                                }
                            }

                            // Ambient accent glow corner
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 140
                                height: 140
                                radius: 70
                                color: modelData.grid_color || "#00f0ff"
                                opacity: cardMouse.containsMouse ? 0.15 : 0.06
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                // Top Tag & Date Row
                                RowLayout {
                                    Layout.fillWidth: true

                                    Rectangle {
                                        height: 20
                                        width: newBadgeText.implicitWidth + 12
                                        radius: 4
                                        color: "#e11d48"

                                        Text {
                                            id: newBadgeText
                                            anchors.centerIn: parent
                                            text: "NEW"
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }

                                    Rectangle {
                                        height: 20
                                        width: refTagText.implicitWidth + 10
                                        radius: 4
                                        color: "#181e2b"
                                        border.color: "#334155"
                                        border.width: 1

                                        Text {
                                            id: refTagText
                                            anchors.centerIn: parent
                                            text: modelData.ref || ""
                                            font.family: "Menlo, monospace"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#94a3b8"
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: modelData.date_added || ""
                                        font.pixelSize: 11
                                        color: "#64748b"
                                    }
                                }

                                // Title & Tagline
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: modelData.title || ""
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.tagline || modelData.description || ""
                                        font.pixelSize: 11
                                        color: "#94a3b8"
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Bottom Actions Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: (modelData.size || "1.0 MB") + " • " + (modelData.category || "Arcade")
                                        font.pixelSize: 10
                                        color: "#64748b"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 80
                                        height: 28
                                        radius: 6
                                        color: playSmallMouse.containsMouse ? "#00f0ff" : "#182834"
                                        border.color: "#00f0ff"
                                        border.width: 1

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text {
                                                text: "▶"
                                                font.pixelSize: 10
                                                color: playSmallMouse.containsMouse ? "#09090e" : "#00f0ff"
                                            }
                                            Text {
                                                text: "PLAY"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: playSmallMouse.containsMouse ? "#09090e" : "#00f0ff"
                                            }
                                        }

                                        MouseArea {
                                            id: playSmallMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                featuredView.gameLaunched(modelData.id);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom breathing room
            Item {
                width: parent.width
                height: 20
            }
        }
    }
}
