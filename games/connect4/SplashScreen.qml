import QtQuick

Rectangle {
    id: splashScreen
    anchors.fill: parent
    color: "#121215"
    z: 1000
    visible: opacity > 0
    opacity: (typeof root !== "undefined" && root && root.splashEnabled !== undefined) ? (root.splashEnabled ? 1 : 0) : 1

    property Item focusTarget: null
    signal dismissed()

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
    }

    function dismiss() {
        if (splashTimer.running) splashTimer.stop();
        if (startupAnim.running) startupAnim.stop();
        splashScreen.opacity = 0;
        if (typeof root !== "undefined" && root && root.splashEnabled !== undefined) {
            root.splashEnabled = false;
        }
        if (focusTarget) {
            focusTarget.forceActiveFocus();
        }
        dismissed();
    }

    // Tap, click, or space to skip splash immediately
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: splashScreen.dismiss()
    }

    // Subtle CRT retro scanline overlay
    Canvas {
        anchors.fill: parent
        opacity: 0.10
        onPaint: {
            var ctx = getContext("2d");
            ctx.fillStyle = "#000000";
            for (var y = 0; y < height; y += 4) {
                ctx.fillRect(0, y, width, 1.5);
            }
        }
    }

    // Centered Badge Content
    Item {
        id: splashContent
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.90, 420)
        height: badgeFrame.height + 40

        // The Retro Emblem Badge Frame
        Rectangle {
            id: badgeFrame
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: splashContent.width
            height: width * (558 / 1024)
            radius: width * (60 / 1024)
            color: "#282829"
            border.color: "#ebdaad"
            border.width: Math.max(3, width * (22 / 1024))
            clip: true
            scale: 0.84
            opacity: 0

            // Responsive coordinate helpers inside 1024x558 badge space
            property real scaleX: width / 1024.0
            property real scaleY: height / 558.0
            property real stripeFullWidth: 874 * scaleX
            property real stripeHeight: Math.max(2, 18 * scaleY)
            property real stripeX: 75 * scaleX

            // 5 Retro Animated Horizontal Stripes (Balanced Spacing & Concentric Rounded Top Corners)
            Item {
                id: stripe1
                x: badgeFrame.stripeX
                y: 72 * badgeFrame.scaleY
                height: badgeFrame.stripeHeight
                width: 0
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: badgeFrame.stripeFullWidth
                    radius: 16 * badgeFrame.scaleY
                    color: "#e6458e"

                    // Square off bottom corners so only top corners remain rounded
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.5
                        color: parent.color
                    }
                }
            }
            Rectangle {
                id: stripe2
                x: badgeFrame.stripeX
                y: 98 * badgeFrame.scaleY
                height: badgeFrame.stripeHeight
                width: 0
                color: "#e03071"
            }
            Rectangle {
                id: stripe3
                x: badgeFrame.stripeX
                y: 124 * badgeFrame.scaleY
                height: badgeFrame.stripeHeight
                width: 0
                color: "#e85e14"
            }
            Rectangle {
                id: stripe4
                x: badgeFrame.stripeX
                y: 150 * badgeFrame.scaleY
                height: badgeFrame.stripeHeight
                width: 0
                color: "#ccab3c"
            }
            Rectangle {
                id: stripe5
                x: badgeFrame.stripeX
                y: 176 * badgeFrame.scaleY
                height: badgeFrame.stripeHeight
                width: 0
                radius: Math.max(1, 2 * badgeFrame.scaleY)
                color: "#429ad0"
            }

            // Vector Lettering (OMARCHY ARCADE)
            Image {
                id: splashLetters
                anchors.fill: parent
                source: "omarchy_arcade_text.svg"
                sourceSize.width: badgeFrame.width
                sourceSize.height: badgeFrame.height
                fillMode: Image.PreserveAspectFit
                opacity: 0
                scale: 1.08
            }

            // Diagonal Glint Sheen Animation
            Rectangle {
                id: glintBar
                width: badgeFrame.width * 0.28
                height: badgeFrame.height * 2.5
                anchors.verticalCenter: parent.verticalCenter
                x: -width * 2
                rotation: 22
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.45; color: "#35ffffff" }
                    GradientStop { position: 0.5; color: "#80ffffff" }
                    GradientStop { position: 0.55; color: "#35ffffff" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // Retro Console Prompt
        Text {
            id: consolePrompt
            anchors.top: badgeFrame.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: "◆ SYSTEM READY • OMARCHY ARCADE ◆"
            font.family: (Qt.platform.os === "osx") ? "Menlo" : "monospace"
            font.pixelSize: Math.max(9, Math.min(11, splashContent.width * 0.027))
            font.bold: true
            color: "#9e9eb0"
            opacity: 0
        }
    }

    // Console Startup Sequence Animation (~1.0s snappy console intro)
    SequentialAnimation {
        id: startupAnim
        running: splashScreen.opacity > 0

        // 1. Badge frame pops in (0 - 160ms)
        ParallelAnimation {
            NumberAnimation { target: badgeFrame; property: "scale"; to: 1.0; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: badgeFrame; property: "opacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: consolePrompt; property: "opacity"; to: 0.9; duration: 200; easing.type: Easing.OutQuad }
        }

        // 2. Cascade 5 stripes shooting across and letters punching in (160ms - 380ms)
        ParallelAnimation {
            NumberAnimation { target: stripe1; property: "width"; to: badgeFrame.stripeFullWidth; duration: 180; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 15 }
                NumberAnimation { target: stripe2; property: "width"; to: badgeFrame.stripeFullWidth; duration: 180; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: stripe3; property: "width"; to: badgeFrame.stripeFullWidth; duration: 180; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 45 }
                NumberAnimation { target: stripe4; property: "width"; to: badgeFrame.stripeFullWidth; duration: 180; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation { target: stripe5; property: "width"; to: badgeFrame.stripeFullWidth; duration: 180; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                ParallelAnimation {
                    NumberAnimation { target: splashLetters; property: "opacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                    NumberAnimation { target: splashLetters; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
                }
            }
        }

        // 3. Glint sheen sweeps across (380ms - 640ms)
        NumberAnimation {
            target: glintBar
            property: "x"
            from: -glintBar.width * 1.5
            to: badgeFrame.width + glintBar.width
            duration: 250
            easing.type: Easing.InOutQuad
        }

        // 4. Brief hold for the player to enjoy the emblem (~240ms)
        PauseAnimation { duration: 240 }

        // 5. Smooth dissolve to game (fade out to 0 opacity)
        ScriptAction { script: splashScreen.dismiss() }
    }

    // Safety fallback timer
    Timer {
        id: splashTimer
        interval: 1150
        running: splashScreen.opacity > 0
        onTriggered: splashScreen.dismiss()
    }
}
