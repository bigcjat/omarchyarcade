import QtQuick
import QtQuick.Controls
import ByteCity 1.0

ApplicationWindow {
    id: window
    title: "ByteCity • Omarchy Arcade"
    width: 1240
    height: 840
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    color: "#181825"

    property QtObject cityEngine: null

    // Classic Retro Top MenuBar (File, Options, Disasters, Windows, Speed)
    ClassicMenuBar {
        id: menuBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        engine: window.cityEngine
        viewport: viewport

        onOpenNewCity: {
            startGameModal.visible = true;
        }
        onOpenScenarios: {
            startGameModal.visible = true;
        }
        onToggleMiniMap: {
            miniMap.visible = !miniMap.visible;
        }
        onToggleBudget: {
            budgetModal.visible = !budgetModal.visible;
        }
        onToggleEval: {
            evalModal.visible = !evalModal.visible;
        }
        onToggleDisaster: {
            disasterModal.visible = !disasterModal.visible;
        }
    }

    // Top Navigation & Metrics Bar
    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: menuBar.bottom
        engine: window.cityEngine

        onBudgetClicked: budgetModal.visible = !budgetModal.visible
        onEvalClicked: evalModal.visible = !evalModal.visible
        onDisasterClicked: disasterModal.visible = !disasterModal.visible
        onCenterClicked: viewport.center_on_map()
        onMiniMapClicked: miniMap.visible = !miniMap.visible
        onSoundClicked: {
            if (window.cityEngine) {
                window.cityEngine.set_sound_muted(window.cityEngine.soundEnabled);
            }
        }
    }

    // Main 2.5D Isometric Vector Viewport
    CityViewport {
        id: viewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        engine: window.cityEngine
        selectedTool: palette.activeTool
        focus: true

        Component.onCompleted: {
            forceActiveFocus();
        }
    }

    // Left Construction Tool Palette
    ToolPalette {
        id: palette
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        onToolSelected: function(toolId) {
            viewport.selectedTool = toolId
            viewport.forceActiveFocus();
        }
    }

    // Floating Interactive MiniMap Overview Radar
    MiniMap {
        id: miniMap
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        engine: window.cityEngine
        viewport: viewport
        visible: true
    }

    // Floating Dr. Wright Mayoral Advisor Window
    DrWrightWindow {
        id: drWrightWindow
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 20
        engine: window.cityEngine
        viewport: viewport
        visible: true

        onOpenBudget: {
            budgetModal.visible = true;
        }
        onCenterCity: {
            viewport.center_on_map();
        }
    }

    // Modal Dimming Scrim
    Rectangle {
        id: modalScrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
        visible: budgetModal.visible || evalModal.visible || disasterModal.visible
        z: 90
        MouseArea {
            anchors.fill: parent
            onClicked: {
                budgetModal.visible = false
                evalModal.visible = false
                disasterModal.visible = false
                viewport.forceActiveFocus()
            }
        }
    }

    // Modal Overlays
    BudgetModal {
        id: budgetModal
        z: 95
        engine: window.cityEngine
        onClosed: {
            visible = false
            viewport.forceActiveFocus()
        }
    }

    EvaluationModal {
        id: evalModal
        z: 95
        engine: window.cityEngine
        onClosed: {
            visible = false
            viewport.forceActiveFocus()
        }
    }

    DisasterModal {
        id: disasterModal
        z: 95
        engine: window.cityEngine
        onClosed: {
            visible = false
            viewport.forceActiveFocus()
        }
    }

    // Start Game Modal (Shown at startup)
    StartGameModal {
        id: startGameModal
        objectName: "startGameModal"
        engine: window.cityEngine
        viewport: viewport
        visible: true

        onGameStarted: {
            viewport.forceActiveFocus();
        }
    }

    // Global Key Handlers
    Item {
        anchors.fill: parent
        focus: true
        Keys.forwardTo: [viewport]

        Keys.onPressed: function(event) {
            // Modals close on Escape
            if (event.key === Qt.Key_Escape) {
                if (budgetModal.visible || evalModal.visible || disasterModal.visible || startGameModal.visible) {
                    budgetModal.visible = false
                    evalModal.visible = false
                    disasterModal.visible = false
                    startGameModal.visible = false
                    viewport.forceActiveFocus()
                    event.accepted = true
                    return
                }
            }

            // Quick Hotkeys
            if (event.key === Qt.Key_H) {
                palette.activeTool = -1; // Hand tool
                viewport.selectedTool = -1;
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                miniMap.visible = !miniMap.visible;
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                budgetModal.visible = !budgetModal.visible;
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                if (window.cityEngine) {
                    window.cityEngine.set_speed(window.cityEngine.simSpeed === 0 ? 1 : 0);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_1) {
                palette.activeTool = 0; // Res
                viewport.selectedTool = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                palette.activeTool = 1; // Com
                viewport.selectedTool = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                palette.activeTool = 2; // Ind
                viewport.selectedTool = 2;
                event.accepted = true;
            } else if (event.key === Qt.Key_7) {
                palette.activeTool = 7; // Bulldoze
                viewport.selectedTool = 7;
                event.accepted = true;
            } else if (event.key === Qt.Key_9) {
                palette.activeTool = 9; // Road
                viewport.selectedTool = 9;
                event.accepted = true;
            }
        }
    }
}
