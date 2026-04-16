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

    configEntryName: "visualizer"

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property int numBars: Config.options.background.widgets.visualizer.bars
    property bool isVertical: Config.options.background.widgets.visualizer.vertical
    property string style: Config.options.background.widgets.visualizer.style

    property var amplitudeArray: []

    Component.onCompleted: {
        for(let i = 0; i < numBars; i++) {
            amplitudeArray.push(0);
        }
    }
    
    onNumBarsChanged: {
        var arr = [];
        for(let i = 0; i < numBars; i++) {
            arr.push(0);
        }
        amplitudeArray = arr;
        // restart process
        cavaProcess.running = false
        cavaProcess.running = true
    }

    // Config wrapper to run cava reading raw data
    // We just write a quick temp config to /tmp/quickshell_cava_config and run cava
    Process {
        id: createCavaConfig
        command: ["bash", "-c", "echo -e '[general]\nbars = " + root.numBars + "\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\n' > /tmp/quickshell_cava_config"]
        running: true
        onExited: {
            cavaProcess.running = true
        }
    }

    Process {
        id: cavaProcess
        running: false
        command: ["cava", "-p", "/tmp/quickshell_cava_config"]
        stdout: SplitParser {
            onRead: (line) => {
                var vals = line.split(';').map(function(s) { 
                    return parseInt(s, 10); 
                }).filter(function(v) { return !isNaN(v); });
                if (vals.length > 0) {
                    root.amplitudeArray = vals;
                }
            }
        }
    }

    Rectangle {
        id: backgroundShape
        anchors.fill: parent
        color: "transparent"
        
        implicitWidth: isVertical ? 200 : (numBars * 10 + 40)
        implicitHeight: isVertical ? (numBars * 10 + 40) : 200

        Item {
            anchors.fill: parent
            anchors.margins: 20
            
            // Base line for horizontal layout
            Rectangle {
                visible: !isVertical
                color: Appearance.colors.colPrimary
                height: 4
                width: parent.width
                anchors.bottom: parent.bottom
                radius: 2
            }

            // Base line for vertical layout
            Rectangle {
                visible: isVertical
                color: Appearance.colors.colPrimary
                width: 4
                height: parent.height
                anchors.left: parent.left
                radius: 2
            }

            // Bars layout
            Row {
                anchors.fill: parent
                spacing: 4
                visible: !isVertical && style === "bars"
                Repeater {
                    model: root.amplitudeArray
                    Rectangle {
                        width: parent.width / root.amplitudeArray.length - parent.spacing
                        height: Math.max(2, (modelData / 100) * parent.height)
                        anchors.bottom: parent.bottom
                        color: Appearance.colors.colPrimary
                        radius: 2
                        Behavior on height {
                            NumberAnimation { duration: 50; easing.type: Easing.OutSine }
                        }
                    }
                }
            }
            
            // Vertical bars layout
            Column {
                anchors.fill: parent
                spacing: 4
                visible: isVertical && style === "bars"
                Repeater {
                    model: root.amplitudeArray
                    Rectangle {
                        height: parent.height / root.amplitudeArray.length - parent.spacing
                        width: Math.max(2, (modelData / 100) * parent.width)
                        anchors.left: parent.left
                        color: Appearance.colors.colPrimary
                        radius: 2
                        Behavior on width {
                            NumberAnimation { duration: 50; easing.type: Easing.OutSine }
                        }
                    }
                }
            }
            
            // Wave Layout
            Canvas {
                anchors.fill: parent
                visible: style === "wave"
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.strokeStyle = Appearance.colors.colPrimary;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    
                    var arr = root.amplitudeArray;
                    if (arr.length < 2) return;
                    
                    if (!isVertical) {
                        var stepX = width / (arr.length - 1);
                        ctx.moveTo(0, height - (arr[0]/100)*height);
                        for(var i=1; i<arr.length; i++) {
                            var prevX = (i-1) * stepX;
                            var prevY = height - (arr[i-1]/100)*height;
                            var currX = i * stepX;
                            var currY = height - (arr[i]/100)*height;
                            var cpx = (prevX + currX) / 2;
                            ctx.bezierCurveTo(cpx, prevY, cpx, currY, currX, currY);
                        }
                    } else {
                        var stepY = height / (arr.length - 1);
                        ctx.moveTo((arr[0]/100)*width, 0);
                        for(var j=1; j<arr.length; j++) {
                            var prevY2 = (j-1) * stepY;
                            var prevX2 = (arr[j-1]/100)*width;
                            var currY2 = j * stepY;
                            var currX2 = (arr[j]/100)*width;
                            var cpy = (prevY2 + currY2) / 2;
                            ctx.bezierCurveTo(prevX2, cpy, currX2, cpy, currX2, currY2);
                        }
                    }
                    ctx.stroke();
                }
                
                Timer {
                    interval: 16
                    running: root.style === "wave"
                    repeat: true
                    onTriggered: parent.requestPaint()
                }
            }
        }
    }
}
