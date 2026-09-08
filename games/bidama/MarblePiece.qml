import QtQuick

Item {
    id: marbleRoot
    width: 58
    height: 58

    // Marble Types: "ramune", "matcha", "sakura", "yuzu", "asagao", "hanabi", "basalt"
    property string marbleType: "ramune"
    property real rollAngle: 0.0 // Rotation in radians along vertical rolling axis
    property real rollAngleX: 0.0 // Optional horizontal roll angle
    property bool showGlint: true
    property real specularStrength: 1.0
    property bool isShattering: false

    signal shatterFinished()

    onRollAngleChanged: canvas.requestPaint()
    onRollAngleXChanged: canvas.requestPaint()
    onMarbleTypeChanged: canvas.requestPaint()

    function triggerShatter() {
        isShattering = true;
        shatterAnim.restart();
    }

    // Shatter & Burst Animation
    SequentialAnimation {
        id: shatterAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: marbleContent; property: "scale"; from: 1.0; to: 1.30; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: shatterHalo; property: "opacity"; from: 0.0; to: 1.0; duration: 90 }
            NumberAnimation { target: shatterHalo; property: "scale"; from: 0.8; to: 1.6; duration: 220; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: marbleContent; property: "scale"; from: 1.30; to: 0.0; duration: 150; easing.type: Easing.InBack }
            NumberAnimation { target: marbleContent; property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
            NumberAnimation { target: shatterHalo; property: "opacity"; from: 1.0; to: 0.0; duration: 130 }
        }
        ScriptAction {
            script: {
                marbleRoot.isShattering = false;
                marbleContent.scale = 1.0;
                marbleContent.opacity = 1.0;
                shatterHalo.opacity = 0.0;
                shatterHalo.scale = 1.0;
                marbleRoot.shatterFinished();
            }
        }
    }

    // Expanding Golden Shatter Shockwave Halo
    Rectangle {
        id: shatterHalo
        anchors.centerIn: parent
        width: parent.width * 1.4
        height: parent.height * 1.4
        radius: width / 2.0
        color: "transparent"
        border.color: (marbleRoot.marbleType === "hanabi") ? "#f97316" : "#facc15"
        border.width: 3.5
        opacity: 0.0
        z: 30
    }

    // Particle Burst Canvas on Shatter
    Canvas {
        id: particleCanvas
        anchors.fill: parent
        anchors.margins: -24
        visible: marbleRoot.isShattering
        z: 35

        property var particles: []

        function initParticles() {
            particles = [];
            var count = 16;
            for (var i = 0; i < count; i++) {
                var angle = (i / count) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
                var speed = 2.5 + Math.random() * 3.5;
                particles.push({
                    x: width / 2.0,
                    y: height / 2.0,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed,
                    size: 2.5 + Math.random() * 3.5,
                    alpha: 1.0
                });
            }
            particleTimer.restart();
        }

        Timer {
            id: particleTimer
            interval: 16
            repeat: true
            running: marbleRoot.isShattering
            onTriggered: {
                var alive = false;
                for (var p = 0; p < particleCanvas.particles.length; p++) {
                    var pt = particleCanvas.particles[p];
                    pt.x += pt.vx;
                    pt.y += pt.vy;
                    pt.alpha -= 0.07;
                    if (pt.alpha > 0) alive = true;
                }
                particleCanvas.requestPaint();
                if (!alive) particleTimer.stop();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            for (var p = 0; p < particles.length; p++) {
                var pt = particles[p];
                if (pt.alpha > 0) {
                    ctx.fillStyle = "rgba(254, 240, 138, " + Math.max(0, pt.alpha).toFixed(2) + ")";
                    ctx.beginPath();
                    ctx.arc(pt.x, pt.y, pt.size, 0, Math.PI * 2);
                    ctx.fill();
                    // White core
                    ctx.fillStyle = "rgba(255, 255, 255, " + Math.max(0, pt.alpha).toFixed(2) + ")";
                    ctx.beginPath();
                    ctx.arc(pt.x, pt.y, pt.size * 0.5, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
    }

    Connections {
        target: shatterAnim
        function onStarted() {
            particleCanvas.initParticles();
        }
    }

    Item {
        id: marbleContent
        anchors.fill: parent

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Threaded

            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;
                var r = Math.min(w, h) * 0.46;
                var cx = w / 2.0;
                var cy = h / 2.0;

                ctx.clearRect(0, 0, w, h);

                var theta = -marbleRoot.rollAngle;
                var cosT = Math.cos(theta);
                var sinT = Math.sin(theta);

                var thetaX = marbleRoot.rollAngleX;
                var cosTX = Math.cos(thetaX);
                var sinTX = Math.sin(thetaX);

                function rotate3D(x0, y0, z0) {
                    var y1 = y0 * cosT - z0 * sinT;
                    var z1 = y0 * sinT + z0 * cosT;
                    var x2 = x0 * cosTX + z1 * sinTX;
                    var z2 = -x0 * sinTX + z1 * cosTX;
                    return { x: x2, y: y1, z: z2 };
                }

                // 1. BASALT RIVER STONE
                if (marbleRoot.marbleType === "basalt") {
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.clip();

                    var stoneGrad = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.35, r * 0.1, cx, cy, r);
                    stoneGrad.addColorStop(0.0, "#475569");
                    stoneGrad.addColorStop(0.6, "#1e293b");
                    stoneGrad.addColorStop(1.0, "#090d16");
                    ctx.fillStyle = stoneGrad;
                    ctx.fill();

                    var veinPoints = [
                        { x: -r * 0.8, y: -r * 0.3, z: 0 },
                        { x: -r * 0.4, y: -r * 0.1, z: r * 0.6 },
                        { x: 0, y: r * 0.1, z: r * 0.8 },
                        { x: r * 0.5, y: r * 0.3, z: r * 0.5 },
                        { x: r * 0.8, y: r * 0.6, z: 0 }
                    ];

                    ctx.beginPath();
                    var first = true;
                    for (var v = 0; v < veinPoints.length; v++) {
                        var vp = rotate3D(veinPoints[v].x, veinPoints[v].y, veinPoints[v].z);
                        if (vp.z > -r * 0.2) {
                            var alpha = Math.max(0.1, (vp.z + r * 0.2) / (r * 1.2));
                            ctx.strokeStyle = "rgba(241, 245, 249, " + (alpha * 0.75).toFixed(2) + ")";
                            ctx.lineWidth = 2.0 * alpha;
                            if (first) {
                                ctx.moveTo(cx + vp.x, cy + vp.y);
                                first = false;
                            } else {
                                ctx.lineTo(cx + vp.x, cy + vp.y);
                            }
                        }
                    }
                    ctx.stroke();

                    var pits = [
                        { x: -r * 0.3, y: -r * 0.4, z: r * 0.6, s: 3.5 },
                        { x: r * 0.35, y: -r * 0.2, z: r * 0.7, s: 4.0 },
                        { x: -r * 0.1, y: r * 0.3, z: r * 0.8, s: 2.8 },
                        { x: r * 0.2, y: r * 0.5, z: r * 0.5, s: 3.2 },
                        { x: -r * 0.5, y: r * 0.1, z: r * 0.4, s: 4.5 }
                    ];

                    for (var p = 0; p < pits.length; p++) {
                        var pt = rotate3D(pits[p].x, pits[p].y, pits[p].z);
                        if (pt.z > 0) {
                            var pAlpha = pt.z / r;
                            ctx.fillStyle = "rgba(10, 15, 25, " + (pAlpha * 0.85).toFixed(2) + ")";
                            ctx.beginPath();
                            ctx.arc(cx + pt.x, cy + pt.y, pits[p].s * (0.6 + 0.4 * pAlpha), 0, Math.PI * 2);
                            ctx.fill();
                            ctx.fillStyle = "rgba(148, 163, 184, " + (pAlpha * 0.35).toFixed(2) + ")";
                            ctx.beginPath();
                            ctx.arc(cx + pt.x - 0.8, cy + pt.y - 0.8, pits[p].s * 0.5, 0, Math.PI * 2);
                            ctx.fill();
                        }
                    }

                    var rimG = ctx.createRadialGradient(cx, cy, r * 0.75, cx, cy, r);
                    rimG.addColorStop(0.0, "rgba(0,0,0,0)");
                    rimG.addColorStop(1.0, "rgba(0,0,0,0.7)");
                    ctx.fillStyle = rimG;
                    ctx.fill();

                    ctx.restore();
                    return;
                }

                // GLASS MARBLES: CLIP TO SPHERE
                ctx.save();
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.clip();

                // 1. BASE TRANSLUCENT GLASS BODY
                var baseGrad = ctx.createRadialGradient(cx - r * 0.25, cy - r * 0.3, r * 0.1, cx, cy, r);
                if (marbleRoot.marbleType === "ramune") {
                    baseGrad.addColorStop(0.0, "#a5f3fc");
                    baseGrad.addColorStop(0.4, "#06b6d4");
                    baseGrad.addColorStop(0.85, "#0e7490");
                    baseGrad.addColorStop(1.0, "#083344");
                } else if (marbleRoot.marbleType === "matcha") {
                    baseGrad.addColorStop(0.0, "#bef264");
                    baseGrad.addColorStop(0.35, "#4ade80");
                    baseGrad.addColorStop(0.75, "#15803d");
                    baseGrad.addColorStop(1.0, "#052e16");
                } else if (marbleRoot.marbleType === "sakura") {
                    baseGrad.addColorStop(0.0, "#fce7f3");
                    baseGrad.addColorStop(0.4, "#f472b6");
                    baseGrad.addColorStop(0.8, "#db2777");
                    baseGrad.addColorStop(1.0, "#500724");
                } else if (marbleRoot.marbleType === "yuzu") {
                    baseGrad.addColorStop(0.0, "#fef08a");
                    baseGrad.addColorStop(0.35, "#facc15");
                    baseGrad.addColorStop(0.75, "#d97706");
                    baseGrad.addColorStop(1.0, "#451a03");
                } else if (marbleRoot.marbleType === "asagao") {
                    baseGrad.addColorStop(0.0, "#c4b5fd");
                    baseGrad.addColorStop(0.35, "#818cf8");
                    baseGrad.addColorStop(0.75, "#4338ca");
                    baseGrad.addColorStop(1.0, "#1e1b4b");
                } else if (marbleRoot.marbleType === "hanabi") {
                    baseGrad.addColorStop(0.0, "#ffedd5");
                    baseGrad.addColorStop(0.35, "#f97316");
                    baseGrad.addColorStop(0.75, "#991b1b");
                    baseGrad.addColorStop(1.0, "#450a0a");
                }
                ctx.fillStyle = baseGrad;
                ctx.fill();

                // 2. DISTINCT 3D INTERNAL ARTISTRY
                // RAMUNE
                if (marbleRoot.marbleType === "ramune") {
                    var ballCenter = rotate3D(0, r * 0.28, 0);
                    var ballR = r * 0.34 * (0.8 + 0.2 * (ballCenter.z / r + 1.0));
                    var ballAlpha = Math.max(0.2, (ballCenter.z + r) / (2.0 * r));

                    var ballGrad = ctx.createRadialGradient(
                        cx + ballCenter.x - ballR * 0.3,
                        cy + ballCenter.y - ballR * 0.3,
                        ballR * 0.1,
                        cx + ballCenter.x,
                        cy + ballCenter.y,
                        ballR
                    );
                    ballGrad.addColorStop(0.0, "rgba(255, 255, 255, " + (ballAlpha * 0.95).toFixed(2) + ")");
                    ballGrad.addColorStop(0.4, "rgba(165, 243, 252, " + (ballAlpha * 0.7).toFixed(2) + ")");
                    ballGrad.addColorStop(0.85, "rgba(6, 182, 212, " + (ballAlpha * 0.85).toFixed(2) + ")");
                    ballGrad.addColorStop(1.0, "rgba(8, 51, 68, " + (ballAlpha * 0.9).toFixed(2) + ")");

                    ctx.fillStyle = ballGrad;
                    ctx.beginPath();
                    ctx.arc(cx + ballCenter.x, cy + ballCenter.y, ballR, 0, Math.PI * 2);
                    ctx.fill();

                    var bubbles = [
                        { x: -r * 0.45, y: -r * 0.35, z: r * 0.4, bR: 2.5 },
                        { x: r * 0.4, y: -r * 0.2, z: r * 0.3, bR: 2.0 },
                        { x: -r * 0.25, y: r * 0.45, z: -r * 0.3, bR: 2.8 },
                        { x: r * 0.35, y: r * 0.4, z: r * 0.5, bR: 2.2 },
                        { x: 0, y: -r * 0.55, z: -r * 0.4, bR: 2.6 }
                    ];

                    for (var b = 0; b < bubbles.length; b++) {
                        var bp = rotate3D(bubbles[b].x, bubbles[b].y, bubbles[b].z);
                        var bAlpha = Math.max(0.15, (bp.z + r) / (2.0 * r));
                        var sz = bubbles[b].bR * (0.7 + 0.3 * (bp.z / r + 1.0));

                        ctx.fillStyle = "rgba(255, 255, 255, " + (bAlpha * 0.9).toFixed(2) + ")";
                        ctx.beginPath();
                        ctx.arc(cx + bp.x, cy + bp.y, sz, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
                // MATCHA
                else if (marbleRoot.marbleType === "matcha") {
                    var steps = 22;
                    var ribbonWidth = r * 0.32;

                    for (var strand = 0; strand < 2; strand++) {
                        var phase = strand * Math.PI;
                        var isWhite = (strand === 0);
                        var prevPt = null;

                        for (var s = 0; s <= steps; s++) {
                            var t = (s / steps) * Math.PI * 2.2 - Math.PI * 1.1;
                            var localY = (s / steps - 0.5) * r * 1.4;
                            var localR = Math.cos((s / steps - 0.5) * Math.PI) * r * 0.55;
                            var localX = Math.sin(t * 1.8 + phase) * localR;
                            var localZ = Math.cos(t * 1.8 + phase) * localR;

                            var pt = rotate3D(localX, localY, localZ);

                            if (prevPt !== null) {
                                var depthNorm = (pt.z + r) / (2.0 * r);
                                var alpha = Math.max(0.2, depthNorm * 0.95);
                                var strokeW = ribbonWidth * (0.4 + 0.6 * depthNorm);

                                ctx.beginPath();
                                ctx.moveTo(cx + prevPt.x, cy + prevPt.y);
                                ctx.lineTo(cx + pt.x, cy + pt.y);
                                ctx.strokeStyle = isWhite ? ("rgba(255, 255, 255, " + alpha.toFixed(2) + ")") : ("rgba(190, 242, 100, " + alpha.toFixed(2) + ")");
                                ctx.lineWidth = strokeW;
                                ctx.lineCap = "round";
                                ctx.stroke();
                            }
                            prevPt = pt;
                        }
                    }
                }
                // SAKURA
                else if (marbleRoot.marbleType === "sakura") {
                    var petals = [
                        { x: -r * 0.25, y: -r * 0.35, z: r * 0.35, rot: 0.4, s: 6 },
                        { x: r * 0.3, y: -r * 0.25, z: -r * 0.3, rot: -0.8, s: 7 },
                        { x: -r * 0.35, y: r * 0.25, z: r * 0.45, rot: 1.2, s: 6.5 },
                        { x: 0, y: -r * 0.1, z: r * 0.55, rot: 0.1, s: 7.5 }
                    ];

                    for (var pet = 0; pet < petals.length; pet++) {
                        var pp = rotate3D(petals[pet].x, petals[pet].y, petals[pet].z);
                        var pDepth = Math.max(0.15, (pp.z + r) / (2.0 * r));
                        var pScale = (0.6 + 0.4 * pDepth);

                        ctx.save();
                        ctx.translate(cx + pp.x, cy + pp.y);
                        ctx.rotate(petals[pet].rot + theta * 0.5);
                        ctx.scale(pScale, pScale);

                        ctx.fillStyle = "rgba(255, 241, 242, " + (pDepth * 0.92).toFixed(2) + ")";
                        ctx.beginPath();
                        ctx.ellipse(0, 0, petals[pet].s, petals[pet].s * 0.55, 0, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.restore();
                    }

                    var goldFlakes = [
                        { x: -r * 0.4, y: -r * 0.15, z: r * 0.5, s: 2.8 },
                        { x: r * 0.35, y: -r * 0.45, z: -r * 0.2, s: 2.5 },
                        { x: -r * 0.1, y: r * 0.45, z: r * 0.3, s: 3.0 },
                        { x: r * 0.4, y: 0.1, z: r * 0.6, s: 2.6 }
                    ];

                    for (var gf = 0; gf < goldFlakes.length; gf++) {
                        var gp = rotate3D(goldFlakes[gf].x, goldFlakes[gf].y, goldFlakes[gf].z);
                        var gDepth = Math.max(0.2, (gp.z + r) / (2.0 * r));
                        ctx.fillStyle = "rgba(251, 191, 36, " + (gDepth * 0.95).toFixed(2) + ")";
                        ctx.beginPath();
                        ctx.arc(cx + gp.x, cy + gp.y, goldFlakes[gf].s * (0.6 + 0.4 * gDepth), 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
                // YUZU
                else if (marbleRoot.marbleType === "yuzu") {
                    var helixSteps = 20;
                    var helixRadius = r * 0.40;

                    for (var hStrand = 0; hStrand < 2; hStrand++) {
                        var hPhase = hStrand * Math.PI;
                        var prevHp = null;

                        for (var hs = 0; hs <= helixSteps; hs++) {
                            var progress = hs / helixSteps;
                            var hAngle = progress * Math.PI * 3.5 + hPhase;
                            var hy = (progress - 0.5) * r * 1.5;
                            var hx = Math.cos(hAngle) * helixRadius;
                            var hz = Math.sin(hAngle) * helixRadius;

                            var hp = rotate3D(hx, hy, hz);

                            if (prevHp !== null) {
                                var hDepth = (hp.z + r) / (2.0 * r);
                                var hAlpha = Math.max(0.25, hDepth * 0.95);

                                ctx.beginPath();
                                ctx.moveTo(cx + prevHp.x, cy + prevHp.y);
                                ctx.lineTo(cx + hp.x, cy + hp.y);
                                ctx.strokeStyle = "rgba(234, 88, 12, " + hAlpha.toFixed(2) + ")";
                                ctx.lineWidth = 4.0 * (0.5 + 0.5 * hDepth);
                                ctx.lineCap = "round";
                                ctx.stroke();

                                ctx.beginPath();
                                ctx.moveTo(cx + prevHp.x, cy + prevHp.y);
                                ctx.lineTo(cx + hp.x, cy + hp.y);
                                ctx.strokeStyle = "rgba(254, 240, 138, " + (hAlpha * 0.85).toFixed(2) + ")";
                                ctx.lineWidth = 1.6 * (0.5 + 0.5 * hDepth);
                                ctx.stroke();
                            }
                            prevHp = hp;
                        }
                    }
                }
                // ASAGAO
                else if (marbleRoot.marbleType === "asagao") {
                    var coreCenter = rotate3D(0, 0, 0);
                    var coreGrad = ctx.createRadialGradient(cx + coreCenter.x, cy + coreCenter.y, 1, cx + coreCenter.x, cy + coreCenter.y, r * 0.35);
                    coreGrad.addColorStop(0.0, "rgba(244, 244, 245, 0.95)");
                    coreGrad.addColorStop(0.4, "rgba(168, 85, 247, 0.5)");
                    coreGrad.addColorStop(1.0, "rgba(49, 27, 146, 0.0)");
                    ctx.fillStyle = coreGrad;
                    ctx.beginPath();
                    ctx.arc(cx + coreCenter.x, cy + coreCenter.y, r * 0.35, 0, Math.PI * 2);
                    ctx.fill();

                    var starCount = 22;
                    for (var st = 0; st < starCount; st++) {
                        var sRadius = (st / starCount) * r * 0.65 + r * 0.08;
                        var sTheta = (st / starCount) * Math.PI * 4.0;
                        var sx = Math.cos(sTheta) * sRadius;
                        var sy = Math.sin(sTheta) * sRadius * 0.5;
                        var sz = Math.sin(sTheta) * sRadius * 0.866;

                        var sp = rotate3D(sx, sy, sz);
                        var sDepth = Math.max(0.15, (sp.z + r) / (2.0 * r));
                        var sSize = (1.5 + (st % 3) * 1.0) * (0.6 + 0.4 * sDepth);

                        var colorMod = st % 3;
                        var sColor = colorMod === 0 ? "rgba(56, 189, 248, " : (colorMod === 1 ? "rgba(232, 121, 249, " : "rgba(253, 224, 71, ");

                        ctx.fillStyle = sColor + (sDepth * 0.95).toFixed(2) + ")";
                        ctx.beginPath();
                        ctx.arc(cx + sp.x, cy + sp.y, sSize, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
                // HANABI
                else if (marbleRoot.marbleType === "hanabi") {
                    var rayCount = 10;
                    for (var ry = 0; ry < rayCount; ry++) {
                        var rayAngle = (ry / rayCount) * Math.PI * 2;
                        var rx = Math.cos(rayAngle) * r * 0.7;
                        var ryY = Math.sin(rayAngle) * r * 0.7;
                        var rz = 0;

                        var rayP = rotate3D(rx, ryY, rz);
                        var rDepth = Math.max(0.2, (rayP.z + r) / (2.0 * r));

                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(cx + rayP.x, cy + rayP.y);
                        ctx.strokeStyle = "rgba(253, 224, 71, " + (rDepth * 0.9).toFixed(2) + ")";
                        ctx.lineWidth = 2.5 * rDepth;
                        ctx.stroke();

                        ctx.fillStyle = "rgba(255, 255, 255, " + (rDepth * 0.95).toFixed(2) + ")";
                        ctx.beginPath();
                        ctx.arc(cx + rayP.x, cy + rayP.y, 2.5 * rDepth, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.arc(cx, cy, r * 0.25, 0, Math.PI * 2);
                    ctx.fill();
                }

                // 3. SPHERICAL SHADOW & CAUSTIC RIM
                var innerShade = ctx.createRadialGradient(cx, cy, r * 0.65, cx, cy, r);
                innerShade.addColorStop(0.0, "rgba(0, 0, 0, 0.0)");
                innerShade.addColorStop(0.8, "rgba(0, 0, 0, 0.35)");
                innerShade.addColorStop(1.0, "rgba(0, 0, 0, 0.75)");
                ctx.fillStyle = innerShade;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.fill();

                var causticBounce = ctx.createRadialGradient(cx + r * 0.25, cy + r * 0.35, r * 0.05, cx + r * 0.25, cy + r * 0.35, r * 0.55);
                causticBounce.addColorStop(0.0, "rgba(255, 255, 255, 0.35)");
                causticBounce.addColorStop(0.6, "rgba(255, 255, 255, 0.12)");
                causticBounce.addColorStop(1.0, "rgba(255, 255, 255, 0.0)");
                ctx.fillStyle = causticBounce;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.fill();

                // 4. SPECULAR HIGHLIGHT (STATIONARY ON SURFACE)
                if (marbleRoot.showGlint) {
                    var specGrad = ctx.createRadialGradient(
                        cx - r * 0.38,
                        cy - r * 0.42,
                        r * 0.03,
                        cx - r * 0.35,
                        cy - r * 0.38,
                        r * 0.45
                    );
                    specGrad.addColorStop(0.0, "rgba(255, 255, 255, " + (0.95 * marbleRoot.specularStrength).toFixed(2) + ")");
                    specGrad.addColorStop(0.25, "rgba(255, 255, 255, " + (0.65 * marbleRoot.specularStrength).toFixed(2) + ")");
                    specGrad.addColorStop(0.65, "rgba(255, 255, 255, " + (0.15 * marbleRoot.specularStrength).toFixed(2) + ")");
                    specGrad.addColorStop(1.0, "rgba(255, 255, 255, 0.0)");

                    ctx.save();
                    ctx.translate(cx - r * 0.36, cy - r * 0.40);
                    ctx.rotate(-0.5);
                    ctx.scale(1.2, 0.75);
                    ctx.fillStyle = specGrad;
                    ctx.beginPath();
                    ctx.arc(0, 0, r * 0.38, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();

                    ctx.fillStyle = "rgba(255, 255, 255, " + (0.98 * marbleRoot.specularStrength).toFixed(2) + ")";
                    ctx.beginPath();
                    ctx.arc(cx - r * 0.40, cy - r * 0.44, r * 0.06, 0, Math.PI * 2);
                    ctx.fill();

                    var secGlint = ctx.createRadialGradient(cx + r * 0.45, cy + r * 0.45, 1, cx + r * 0.45, cy + r * 0.45, r * 0.3);
                    secGlint.addColorStop(0.0, "rgba(255, 255, 255, 0.28)");
                    secGlint.addColorStop(1.0, "rgba(255, 255, 255, 0.0)");
                    ctx.fillStyle = secGlint;
                    ctx.beginPath();
                    ctx.arc(cx + r * 0.45, cy + r * 0.45, r * 0.3, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.restore();
            }
        }
    }
}
