import QtQuick
import QtQuick.Controls

Rectangle {
    id: wrightRoot
    width: 440
    height: 180
    color: "#181825"
    radius: 12
    border.color: "#313244"
    border.width: 1
    visible: true
    z: 50

    property QtObject engine: null
    property var viewport: null

    signal openBudget()
    signal centerCity()

    // Determine Dr. Wright's mood expression from engine state
    readonly property string mood: {
        if (!engine) return "neutral";
        if (engine.funds < 0) return "panic";
        if (engine.approvalRating < 40 || engine.taxRate > 12) return "worried";
        if (engine.population > 2000 && engine.approvalRating >= 65) return "happy";
        return "neutral";
    }

    // Window Header Bar
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#1e1e2e"
        radius: 12

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 10
            color: "#1e1e2e"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text { text: "🧑‍🏫"; font.pixelSize: 12 }
            Text {
                text: "DR. WRIGHT • MAYORAL ADVISOR"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: "#cdd6f4"
            }
        }

        // Close/Minimize
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: closeMa.containsMouse ? "#f38ba8" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 10
                color: closeMa.containsMouse ? "#11111b" : "#6c7086"
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wrightRoot.visible = false
            }
        }
    }

    Row {
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 14

        // Vector Dr. Wright Portrait Frame
        Rectangle {
            width: 90
            height: 120
            radius: 8
            color: "#11111b"
            border.color: "#45475a"
            border.width: 1

            Canvas {
                id: portraitCanvas
                anchors.fill: parent
                anchors.margins: 4

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cx = width / 2;
                    var cy = height * 0.48;

                    // Suit Coat (Navy Blue)
                    ctx.fillStyle = "#1e3a5f";
                    ctx.beginPath();
                    ctx.moveTo(cx - 32, height);
                    ctx.lineTo(cx - 20, cy + 24);
                    ctx.lineTo(cx + 20, cy + 24);
                    ctx.lineTo(cx + 32, height);
                    ctx.closePath();
                    ctx.fill();

                    // White Shirt Collar
                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.moveTo(cx - 10, cy + 20);
                    ctx.lineTo(cx, cy + 32);
                    ctx.lineTo(cx + 10, cy + 20);
                    ctx.closePath();
                    ctx.fill();

                    // Red Bow Tie
                    ctx.fillStyle = "#e64553";
                    ctx.beginPath();
                    ctx.moveTo(cx - 10, cy + 28);
                    ctx.lineTo(cx + 10, cy + 36);
                    ctx.lineTo(cx + 10, cy + 28);
                    ctx.lineTo(cx - 10, cy + 36);
                    ctx.closePath();
                    ctx.fill();

                    // Head / Face
                    ctx.fillStyle = "#f5c2e7"; // Warm skin tone
                    ctx.beginPath();
                    ctx.arc(cx, cy, 18, 0, Math.PI * 2);
                    ctx.fill();

                    // Wild Hair (Dr. Wright's signature green/white hair)
                    ctx.fillStyle = "#a6e3a1";
                    // Hair tufts
                    ctx.beginPath();
                    ctx.arc(cx - 16, cy - 10, 11, 0, Math.PI * 2);
                    ctx.arc(cx + 16, cy - 10, 11, 0, Math.PI * 2);
                    ctx.arc(cx, cy - 18, 12, 0, Math.PI * 2);
                    ctx.fill();

                    // Big Round Spectacles
                    ctx.strokeStyle = "#fab387";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.arc(cx - 7, cy - 2, 6, 0, Math.PI * 2);
                    ctx.arc(cx + 7, cy - 2, 6, 0, Math.PI * 2);
                    ctx.stroke();

                    // Spectacle bridge
                    ctx.beginPath();
                    ctx.moveTo(cx - 1, cy - 2);
                    ctx.lineTo(cx + 1, cy - 2);
                    ctx.stroke();

                    // Eyes
                    ctx.fillStyle = "#11111b";
                    if (wrightRoot.mood === "panic") {
                        // Wide panic eyes
                        ctx.beginPath();
                        ctx.arc(cx - 7, cy - 2, 3, 0, Math.PI * 2);
                        ctx.arc(cx + 7, cy - 2, 3, 0, Math.PI * 2);
                        ctx.fill();
                    } else if (wrightRoot.mood === "happy") {
                        // Happy curved eyes (^_^)
                        ctx.strokeStyle = "#11111b";
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.arc(cx - 7, cy - 1, 3, Math.PI, 0);
                        ctx.arc(cx + 7, cy - 1, 3, Math.PI, 0);
                        ctx.stroke();
                    } else {
                        // Neutral eyes
                        ctx.fillRect(cx - 8, cy - 3, 2, 3);
                        ctx.fillRect(cx + 6, cy - 3, 2, 3);
                    }

                    // Bushy Mustache
                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.ellipse(cx - 5, cy + 7, 7, 3, 0, 0, Math.PI * 2);
                    ctx.ellipse(cx + 5, cy + 7, 7, 3, 0, 0, Math.PI * 2);
                    ctx.fill();

                    // Mouth
                    ctx.strokeStyle = "#11111b";
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    if (wrightRoot.mood === "panic") {
                        // Open screaming O mouth
                        ctx.fillStyle = "#e64553";
                        ctx.arc(cx, cy + 12, 4, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.stroke();
                    } else if (wrightRoot.mood === "happy") {
                        // Big smile
                        ctx.arc(cx, cy + 9, 5, 0, Math.PI);
                        ctx.stroke();
                    } else if (wrightRoot.mood === "worried") {
                        // Frown
                        ctx.arc(cx, cy + 13, 4, Math.PI, 0);
                        ctx.stroke();
                    }
                }
            }
        }

        // Speech Bubble & Advice Body
        Column {
            width: parent.width - 104
            spacing: 8

            Rectangle {
                width: parent.width
                height: 76
                radius: 8
                color: "#1e1e2e"
                border.color: "#313244"

                Text {
                    anchors.fill: parent
                    anchors.margins: 10
                    text: wrightRoot.engine ? wrightRoot.engine.advisorMessage : "Welcome, Mayor! Connect residential, commercial, and industrial zones with roads and power."
                    font.pixelSize: 11
                    lineHeight: 1.3
                    color: "#cdd6f4"
                    wrapMode: Text.WordWrap
                }
            }

            // Quick Mayoral Actions
            Row {
                spacing: 8
                Rectangle {
                    width: 100
                    height: 26
                    radius: 4
                    color: bActionMa.containsMouse ? "#89b4fa" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: "📊 City Budget"
                        font.pixelSize: 10
                        font.bold: true
                        color: bActionMa.containsMouse ? "#11111b" : "#cdd6f4"
                    }
                    MouseArea {
                        id: bActionMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wrightRoot.openBudget()
                    }
                }

                Rectangle {
                    width: 100
                    height: 26
                    radius: 4
                    color: cActionMa.containsMouse ? "#a6e3a1" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: "🎯 Center City"
                        font.pixelSize: 10
                        font.bold: true
                        color: cActionMa.containsMouse ? "#11111b" : "#cdd6f4"
                    }
                    MouseArea {
                        id: cActionMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wrightRoot.centerCity()
                    }
                }
            }
        }
    }

    onMoodChanged: {
        portraitCanvas.requestPaint();
    }
}
