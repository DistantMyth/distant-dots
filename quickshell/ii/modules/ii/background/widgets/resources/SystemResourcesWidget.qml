import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "systemResources"
    
    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property bool showGraphs: Config.options.background.widgets.systemResources.showGraphs || false
    property var maxHistory: ResourceUsage.historyLength
    property var gpuUsageHistory: []
    property real currentGpuUsage: 0

    // Initialize gpuHistory array
    Component.onCompleted: {
        var arr = [];
        for (var i = 0; i < maxHistory; i++) arr.push(0);
        gpuUsageHistory = arr;
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            gpuProcess.running = true;
        }
    }

    Process {
        id: gpuProcess
        running: false
        command: ["bash", "-c", "if command -v nvidia-smi &> /dev/null; then nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits; elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then cat /sys/class/drm/card0/device/gpu_busy_percent; else echo 0; fi"]
        stdout: SplitParser {
            onRead: (line) => {
                var usage = parseFloat(line.trim());
                if (!isNaN(usage)) {
                    root.currentGpuUsage = usage;
                    var arr = [...root.gpuUsageHistory, usage / 100.0];
                    if (arr.length > root.maxHistory) arr.shift();
                    root.gpuUsageHistory = arr;
                }
            }
        }
    }

    StyledDropShadow {
        target: backgroundShape
    }

    Rectangle {
        id: backgroundShape
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colPrimaryContainer
        
        implicitWidth: 350
        implicitHeight: contentCol.implicitHeight + 40

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 40
            
            // Header
            Row {
                spacing: 15
                MaterialSymbol {
                    iconSize: 32
                    color: Appearance.colors.colOnPrimaryContainer
                    text: "memory"
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                    text: "System Resources"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Stats row
            Row {
                spacing: 30
                anchors.horizontalCenter: parent.horizontalCenter
                
                Column {
                    StyledText { text: "CPU"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(ResourceUsage.cpuUsage * 100) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
                Column {
                    StyledText { text: "RAM"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
                Column {
                    StyledText { text: "GPU"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(root.currentGpuUsage) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
            }

            // Canvas Graphs
            Canvas {
                id: graphCanvas
                width: parent.width
                height: 100
                visible: root.showGraphs

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // Draw a bezier-smoothed line from a history array (values 0..1)
                    const drawSmoothLine = (dataArray, color) => {
                        if (!dataArray || dataArray.length < 2) return;

                        ctx.beginPath();
                        ctx.strokeStyle = color;
                        ctx.lineWidth = 2;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        var n = dataArray.length;
                        var stepX = width / (n - 1);

                        // Map to canvas coordinates
                        var pts = [];
                        for (var i = 0; i < n; i++) {
                            pts.push({
                                x: i * stepX,
                                y: height - (dataArray[i] * (height - 4)) - 2   // leave 2px padding top/bottom
                            });
                        }

                        ctx.moveTo(pts[0].x, pts[0].y);

                        // Cubic bezier: control points are 1/3 and 2/3 between consecutive points
                        for (var j = 1; j < n; j++) {
                            var prev = pts[j - 1];
                            var curr = pts[j];
                            var cpx = (prev.x + curr.x) / 2;
                            ctx.bezierCurveTo(cpx, prev.y, cpx, curr.y, curr.x, curr.y);
                        }

                        ctx.stroke();
                    }

                    // GPU - Error/Red
                    drawSmoothLine(root.gpuUsageHistory, Appearance.colors.colError);
                    // RAM - Secondary
                    drawSmoothLine(ResourceUsage.memoryUsageHistory, Appearance.colors.colSecondary);
                    // CPU - Primary
                    drawSmoothLine(ResourceUsage.cpuUsageHistory, Appearance.colors.colPrimary);
                }

                Timer {
                    interval: 1000 // Update at 1fps
                    running: root.showGraphs
                    repeat: true
                    onTriggered: parent.requestPaint()
                }

                // Legend
                Row {
                    anchors.top: parent.bottom
                    anchors.topMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 15
                    Row {
                        spacing: 5
                        Rectangle { width: 10; height: 10; radius: 5; color: Appearance.colors.colPrimary; anchors.verticalCenter: parent.verticalCenter}
                        StyledText { text: "CPU"; font.pixelSize: 10; color: Appearance.colors.colOnPrimaryContainer }
                    }
                    Row {
                        spacing: 5
                        Rectangle { width: 10; height: 10; radius: 5; color: Appearance.colors.colSecondary; anchors.verticalCenter: parent.verticalCenter}
                        StyledText { text: "RAM"; font.pixelSize: 10; color: Appearance.colors.colOnPrimaryContainer }
                    }
                    Row {
                        spacing: 5
                        Rectangle { width: 10; height: 10; radius: 5; color: Appearance.colors.colError; anchors.verticalCenter: parent.verticalCenter}
                        StyledText { text: "GPU"; font.pixelSize: 10; color: Appearance.colors.colOnPrimaryContainer }
                    }
                }
            }

            Item {
                width: 1
                height: root.showGraphs ? 20 : 0 
                // Extra padding for legend
            }
        }
    }
}
