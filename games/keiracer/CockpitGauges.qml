import QtQuick
import QtQuick.Controls

Rectangle {
    id: cockpit
    height: 70
    width: Math.min(parent.width - 20, 420)
    color: themeCardBg
    border.color: isShiftAlert ? themePink : themeBorder
    border.width: isShiftAlert ? 2 : 1
    radius: 12
    clip: true

    property real currentSpeed: 0
    property int currentRPM: 850
    property int currentGear: 1
    property int shiftRPM: 5600
    property int redlineRPM: 6800
    property int gaugeMaxRPM: 8000
    property int idleRPM: 850
    property real currentTimeLeft: 50.0

    property color themeCardBg: "#1e293b"
    property color themeAccent: "#00f0ff"
    property color themePink: "#ff007f"
    property color themeBorder: "#334155"
    property color themeFg: "#f8fafc"
    property color themeSubtext: "#94a3b8"
    property string monoFontFamily: "Menlo, Monaco, Consolas, monospace"

    readonly property bool isShiftAlert: currentRPM >= (shiftRPM - 150)
    readonly property bool isTimeAlert: currentTimeLeft < 10.0

    onCurrentSpeedChanged: gaugeCanvas.requestPaint()
    onCurrentRPMChanged: gaugeCanvas.requestPaint()
    onCurrentGearChanged: gaugeCanvas.requestPaint()
    onCurrentTimeLeftChanged: gaugeCanvas.requestPaint()
    onWidthChanged: gaugeCanvas.requestPaint()

    Canvas {
        id: gaugeCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var w = width;
            var h = height;
            var cy = h / 2;

            // Compute radius to fit all 4 dials nicely both horizontally and vertically
            var r = Math.min(28, Math.min((h - 14) / 2, (w - 36) / 8));

            // Dial Centers
            var cxSpeed = w * 0.14;
            var cxGear  = w * 0.38;
            var cxTach  = w * 0.62;
            var cxTimer = w * 0.86;

            var startAngle = 0.75 * Math.PI; // -135 deg
            var sweepAngle = 1.5 * Math.PI;  // 270 deg
            var endAngle   = startAngle + sweepAngle;

            // Helper function to draw an analog circular dial face
            function drawRoundDial(cx, valueFrac, strokeCol, needleCol, isTachGauge, redlineFrac) {
                // Outer bezel
                ctx.save();
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.fillStyle = "#090d16";
                ctx.fill();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = "#1e293b";
                ctx.stroke();

                // Background track arc
                ctx.beginPath();
                ctx.arc(cx, cy, r - 4, startAngle, endAngle);
                ctx.lineWidth = 3;
                ctx.strokeStyle = "#141c2e";
                ctx.stroke();

                // Redline arc zone (if tachometer)
                if (isTachGauge && redlineFrac < 1.0) {
                    var rStart = startAngle + sweepAngle * redlineFrac;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r - 4, rStart, endAngle);
                    ctx.lineWidth = 3.5;
                    ctx.strokeStyle = "#ef4444";
                    ctx.stroke();
                }

                // Active value arc
                if (valueFrac > 0.005) {
                    var activeEnd = startAngle + sweepAngle * Math.min(1.0, valueFrac);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r - 4, startAngle, activeEnd);
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = strokeCol;
                    ctx.stroke();
                }

                // Ticks (7 ticks)
                for (var i = 0; i <= 6; i++) {
                    var a = startAngle + (sweepAngle * (i / 6));
                    var inR = r - 8;
                    var outR = r - 4;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * inR, cy + Math.sin(a) * inR);
                    ctx.lineTo(cx + Math.cos(a) * outR, cy + Math.sin(a) * outR);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = (isTachGauge && (i / 6) >= redlineFrac) ? "#ef4444" : "#475569";
                    ctx.stroke();
                }

                // Needle
                var needleAngle = startAngle + sweepAngle * Math.max(0, Math.min(1.0, valueFrac));
                var nLen = r - 7;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx + Math.cos(needleAngle) * nLen, cy + Math.sin(needleAngle) * nLen);
                ctx.lineWidth = 2;
                ctx.strokeStyle = needleCol;
                ctx.stroke();

                // Center pivot cap
                ctx.beginPath();
                ctx.arc(cx, cy, 3, 0, Math.PI * 2);
                ctx.fillStyle = "#cbd5e1";
                ctx.fill();

                ctx.restore();
            }

            // =================================================================
            // 1. SPEEDOMETER DIAL
            // =================================================================
            var speedMph = Math.round(cockpit.currentSpeed * 0.621371);
            var maxMph = 110;
            var speedFrac = speedMph / maxMph;
            drawRoundDial(cxSpeed, speedFrac, cockpit.themeAccent, "#f43f5e", false, 1.0);

            // =================================================================
            // 2. GEAR POD (Circular Pod in Middle)
            // =================================================================
            ctx.save();
            ctx.beginPath();
            ctx.arc(cxGear, cy, r * 0.9, 0, Math.PI * 2);
            ctx.fillStyle = "#090d16";
            ctx.fill();
            ctx.lineWidth = cockpit.isShiftAlert ? 2 : 1.5;
            ctx.strokeStyle = cockpit.isShiftAlert ? "#ef4444" : cockpit.themeAccent;
            ctx.stroke();
            ctx.restore();

            // =================================================================
            // 3. TACHOMETER DIAL (RPM + Redline)
            // =================================================================
            var rpmMax = Math.max(1, cockpit.gaugeMaxRPM);
            var rpmFrac = Math.max(0, cockpit.currentRPM) / rpmMax;
            var redlineFrac = cockpit.redlineRPM / rpmMax;
            var tachColor = cockpit.isShiftAlert ? "#ef4444" : (rpmFrac >= redlineFrac ? "#ef4444" : cockpit.themeAccent);
            drawRoundDial(cxTach, rpmFrac, tachColor, cockpit.isShiftAlert ? "#ef4444" : "#facc15", true, redlineFrac);

            // =================================================================
            // 4. COUNTDOWN TIMER DIAL
            // =================================================================
            var timeTotal = 50.0;
            var timeFrac = Math.max(0, Math.min(timeTotal, cockpit.currentTimeLeft)) / timeTotal;
            var timerColor = cockpit.isTimeAlert ? "#ef4444" : cockpit.themeAccent;
            drawRoundDial(cxTimer, timeFrac, timerColor, timerColor, false, 1.0);
        }
    }

    // =========================================================================
    // DIGITAL LABELS & READOUT OVERLAYS (Crisp QML Text)
    // =========================================================================
    Item {
        anchors.fill: parent

        // 1. SPEED READOUT
        Item {
            x: parent.width * 0.14 - width / 2
            y: parent.height / 2 - height / 2
            width: 56
            height: 56

            Text {
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MPH"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 7
                font.weight: Font.Bold
                color: cockpit.themePink
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(cockpit.currentSpeed * 0.621371).toString()
                font.family: cockpit.monoFontFamily
                font.pixelSize: 13
                font.weight: Font.Black
                color: cockpit.themeFg
            }
        }

        // 2. GEAR READOUT
        Item {
            x: parent.width * 0.38 - width / 2
            y: parent.height / 2 - height / 2
            width: 48
            height: 48

            Text {
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GEAR"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 7
                font.weight: Font.Bold
                color: cockpit.themeSubtext
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 4
                text: cockpit.currentGear.toString()
                font.family: cockpit.monoFontFamily
                font.pixelSize: 18
                font.weight: Font.Black
                color: cockpit.isShiftAlert ? "#ef4444" : "#ffffff"
            }
        }

        // 3. TACHOMETER READOUT
        Item {
            x: parent.width * 0.62 - width / 2
            y: parent.height / 2 - height / 2
            width: 56
            height: 56

            Text {
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RPM"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 7
                font.weight: Font.Bold
                color: cockpit.isShiftAlert ? "#ef4444" : cockpit.themeSubtext
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                text: (cockpit.currentRPM / 1000).toFixed(1) + "k"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 11
                font.weight: Font.Black
                color: cockpit.isShiftAlert ? "#ef4444" : cockpit.themeFg
            }

            // Shift Light Beacon (Flashing dot above tach)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: -4
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                height: 6
                radius: 3
                color: cockpit.isShiftAlert ? "#ef4444" : "#1e293b"
                border.color: cockpit.isShiftAlert ? "#fca5a5" : "#334155"
                border.width: 1

                SequentialAnimation on opacity {
                    running: cockpit.isShiftAlert
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 80 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 80 }
                }
            }
        }

        // 4. TIMER READOUT
        Item {
            x: parent.width * 0.86 - width / 2
            y: parent.height / 2 - height / 2
            width: 56
            height: 56

            Text {
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                text: "TIME"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 7
                font.weight: Font.Bold
                color: cockpit.isTimeAlert ? "#ef4444" : cockpit.themeSubtext
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.max(0, Math.ceil(cockpit.currentTimeLeft)).toString() + "s"
                font.family: cockpit.monoFontFamily
                font.pixelSize: 12
                font.weight: Font.Black
                color: cockpit.isTimeAlert ? "#ef4444" : cockpit.themeFg
            }
        }
    }
}
