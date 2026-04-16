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

    configEntryName: "stats"

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property string githubUsername: Config.options.background.widgets.stats.githubUsername
    property string codeforcesUsername: Config.options.background.widgets.stats.codeforcesUsername
    property bool showGraphs: Config.options.background.widgets.stats.showGraphs || false
    
    // Default stats
    property int ghFollowers: 0
    property int ghRepos: 0
    property string cfRank: "--"
    property int cfRating: 0

    // Graph Data
    property var githubActivityArray: []
    property var cfActivityArray: []
    property int maxGithubActivity: 1
    property int maxCfActivity: 1
    
    function fetchGithub() {
        if (!githubUsername) return;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState === 4 && req.status === 200) {
                var data = JSON.parse(req.responseText);
                ghFollowers = data.followers || 0;
                ghRepos = data.public_repos || 0;
            }
        }
        req.open("GET", "https://api.github.com/users/" + githubUsername, true);
        req.send();

        // Fetch events for graph (last ~90 days up to 100 events)
        if (showGraphs) {
            var ereq = new XMLHttpRequest();
            ereq.onreadystatechange = function() {
                if (ereq.readyState === 4 && ereq.status === 200) {
                    var events = JSON.parse(ereq.responseText);
                    var dayBins = new Array(30).fill(0);
                    var maxVal = 0;
                    var now = new Date();
                    for (var i = 0; i < events.length; i++) {
                        var evDate = new Date(events[i].created_at);
                        var diffTime = Math.abs(now - evDate);
                        var diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
                        if (diffDays < 30) {
                            dayBins[29 - diffDays]++; // index 29 is today
                            if (dayBins[29 - diffDays] > maxVal) maxVal = dayBins[29 - diffDays];
                        }
                    }
                    maxGithubActivity = Math.max(1, maxVal);
                    githubActivityArray = dayBins;
                }
            }
            ereq.open("GET", "https://api.github.com/users/" + githubUsername + "/events/public?per_page=100", true);
            ereq.send();
        }
    }
    
    function fetchCodeforces() {
        if (!codeforcesUsername) return;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState === 4 && req.status === 200) {
                var data = JSON.parse(req.responseText);
                if (data.status === "OK" && data.result.length > 0) {
                    cfRank = data.result[0].rank || "--";
                    cfRating = data.result[0].rating || 0;
                }
            }
        }
        req.open("GET", "https://codeforces.com/api/user.info?handles=" + codeforcesUsername, true);
        req.send();

        // Fetch submissions for graph
        if (showGraphs) {
            var sreq = new XMLHttpRequest();
            sreq.onreadystatechange = function() {
                if (sreq.readyState === 4 && sreq.status === 200) {
                    var data = JSON.parse(sreq.responseText);
                    if (data.status === "OK") {
                        var subs = data.result;
                        var dayBins = new Array(30).fill(0);
                        var maxVal = 0;
                        var nowS = Date.now() / 1000;
                        for (var i = 0; i < subs.length; i++) {
                            var diffTime = nowS - subs[i].creationTimeSeconds;
                            var diffDays = Math.floor(diffTime / (60 * 60 * 24));
                            if (diffDays < 30) {
                                dayBins[29 - diffDays]++;
                                if (dayBins[29 - diffDays] > maxVal) maxVal = dayBins[29 - diffDays];
                            }
                        }
                        maxCfActivity = Math.max(1, maxVal);
                        cfActivityArray = dayBins;
                    }
                }
            }
            sreq.open("GET", "https://codeforces.com/api/user.status?handle=" + codeforcesUsername + "&from=1&count=200", true);
            sreq.send();
        }
    }

    Timer {
        interval: 600000 // 10 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchGithub();
            fetchCodeforces();
        }
    }
    
    onGithubUsernameChanged: fetchGithub()
    onCodeforcesUsernameChanged: fetchCodeforces()
    onShowGraphsChanged: {
        if (showGraphs) {
            fetchGithub();
            fetchCodeforces();
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
        
        implicitWidth: 320
        implicitHeight: contentCol.implicitHeight + 40

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 40
            
            // GitHub Row
            Row {
                spacing: 15
                MaterialSymbol {
                    iconSize: 40
                    color: Appearance.colors.colOnPrimaryContainer
                    text: "code" // GitHub icon placeholder
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    StyledText {
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "GitHub: " + (githubUsername || "Not set")
                    }
                    StyledText {
                        font.pixelSize: 14
                        color: Appearance.colors.colPrimary
                        text: ghFollowers + " Followers  •  " + ghRepos + " Repos"
                    }
                }
            }

            // Github Graph
            Canvas {
                width: parent.width
                height: root.showGraphs ? 40 : 0
                visible: root.showGraphs
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!root.githubActivityArray || root.githubActivityArray.length < 2) return;

                    ctx.beginPath();
                    ctx.strokeStyle = Appearance.colors.colSecondary;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    
                    var arr = root.githubActivityArray;
                    var stepX = width / (arr.length - 1);
                    ctx.moveTo(0, height - ((arr[0] / root.maxGithubActivity) * (height - 4)) - 2);
                    
                    for (var i = 1; i < arr.length; i++) {
                        var prevX = (i-1) * stepX;
                        var prevY = height - ((arr[i-1] / root.maxGithubActivity) * (height - 4)) - 2;
                        var currX = i * stepX;
                        var currY = height - ((arr[i] / root.maxGithubActivity) * (height - 4)) - 2;
                        var cpx = (prevX + currX) / 2;
                        ctx.bezierCurveTo(cpx, prevY, cpx, currY, currX, currY);
                    }
                    ctx.stroke();
                }
                
                Timer {
                    interval: 1000
                    running: root.showGraphs
                    repeat: true
                    onTriggered: parent.requestPaint()
                }
            }
            
            // Codeforces Row
            Row {
                spacing: 15
                MaterialSymbol {
                    iconSize: 40
                    color: Appearance.colors.colOnPrimaryContainer
                    text: "bar_chart" // Codeforces icon placeholder
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    StyledText {
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "Codeforces: " + (codeforcesUsername || "Not set")
                    }
                    StyledText {
                        font.pixelSize: 14
                        color: Appearance.colors.colPrimary
                        text: "Rating: " + cfRating + "  •  " + cfRank
                    }
                }
            }

            // Codeforces Graph
            Canvas {
                width: parent.width
                height: root.showGraphs ? 40 : 0
                visible: root.showGraphs
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!root.cfActivityArray || root.cfActivityArray.length < 2) return;

                    ctx.beginPath();
                    ctx.strokeStyle = Appearance.colors.colError;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    
                    var arr = root.cfActivityArray;
                    var stepX = width / (arr.length - 1);
                    ctx.moveTo(0, height - ((arr[0] / root.maxCfActivity) * (height - 4)) - 2);

                    for (var i = 1; i < arr.length; i++) {
                        var prevX = (i-1) * stepX;
                        var prevY = height - ((arr[i-1] / root.maxCfActivity) * (height - 4)) - 2;
                        var currX = i * stepX;
                        var currY = height - ((arr[i] / root.maxCfActivity) * (height - 4)) - 2;
                        var cpx = (prevX + currX) / 2;
                        ctx.bezierCurveTo(cpx, prevY, cpx, currY, currX, currY);
                    }
                    ctx.stroke();
                }

                Timer {
                    interval: 1000
                    running: root.showGraphs
                    repeat: true
                    onTriggered: parent.requestPaint()
                }
            }
        }
    }
}
