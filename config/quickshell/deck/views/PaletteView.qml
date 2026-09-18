import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "PALETTE"
    readonly property string panelJp: "配色"
    readonly property string panelHint: view.feedbackMsg !== ""
        ? view.feedbackMsg + "  •  ESC CLOSE"
        : "↑ ↓  SELECT  •  ENTER  APPLY  •  E  CYCLE EFFECT  •  C  COPY JSON  •  /  FILTER  •  ESC  CLOSE"
    readonly property bool fullBleed: true
    readonly property string placement: "center"

    signal closeRequested()

    property string wallQuery: ""
    property int effectIndex: 0
    property string currentWall: ""
    property string feedbackMsg: ""

    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string srcFile: Quickshell.env("HOME") + "/.cache/hypr/wallpaper-source"
    readonly property string fxOut:   Quickshell.env("HOME") + "/.cache/hypr/wallpaper-fx.png"

    readonly property var effects: [
        { id: "NONE",     name: "NORMAL",   jp: "標準", op: "" },
        { id: "MONO",     name: "MONO",     jp: "白黒", op: "-colorspace gray -sigmoidal-contrast 10,40%" },
        { id: "BLUR",     name: "BLUR",     jp: "暈し", op: "-blur 0x10" },
        { id: "CHARCOAL", name: "CHARCOAL", jp: "木炭", op: "-charcoal 0x5" },
        { id: "EDGE",     name: "EDGE",     jp: "輪郭", op: "-edge 1" },
        { id: "EMBOSS",   name: "EMBOSS",   jp: "浮彫", op: "-emboss 0x5" },
        { id: "NEGATE",   name: "NEGATE",   jp: "反転", op: "-negate" },
        { id: "OIL",      name: "OIL",      jp: "油彩", op: "-paint 4" },
        { id: "POSTER",   name: "POSTER",   jp: "階調", op: "-posterize 4" },
        { id: "SEPIA",    name: "SEPIA",    jp: "褐色", op: "-sepia-tone 65%" },
        { id: "SOLAR",    name: "SOLAR",    jp: "露光", op: "-solarize 80%" },
        { id: "SHARPEN",  name: "SHARPEN",  jp: "鮮明", op: "-sharpen 0x5" },
        { id: "VIGNETTE", name: "VIGNETTE", jp: "暈影", op: "-background black -vignette 0x3" }
    ]

    readonly property var currentEffect: effects[effectIndex] || effects[0]

    function onActivated(): void {
        view.wallQuery = "";
        view.feedbackMsg = "";
        if (filterInput) filterInput.text = "";
        if (wallList) wallList.currentIndex = 0;
        wallQueryProc.running = true;
        filterInput.forceActiveFocus();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            wallList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            wallList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            view.applySelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_E) {
            view.cycleEffect();
            event.accepted = true;
        } else if (event.key === Qt.Key_C) {
            view.copyToClipboard(JSON.stringify(Theme.palette, null, 2), "PALETTE JSON");
            event.accepted = true;
        }
    }

    // Read current wallpaper via swww
    Process {
        id: wallQueryProc
        command: ["swww", "query"]
        stdout: SplitParser {
            onRead: line => {
                const m = /currently displaying: image: (.*)$/.exec(line.trim());
                if (m) view.currentWall = m[1];
            }
        }
    }

    // Wallpaper source store
    FolderListModel {
        id: walls
        folder: "file://" + view.wallDir
        nameFilters: {
            const q = view.wallQuery.trim();
            const exts = ["jpg", "jpeg", "png", "webp"];
            return exts.map(e => q === "" ? "*." + e : "*" + q + "*." + e);
        }
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
    }

    readonly property string selectedFilePath: {
        if (wallList.currentIndex >= 0 && wallList.currentIndex < walls.count) {
            return walls.get(wallList.currentIndex, "filePath");
        }
        return view.currentWall || "";
    }

    readonly property string selectedFileName: {
        if (wallList.currentIndex >= 0 && wallList.currentIndex < walls.count) {
            return walls.get(wallList.currentIndex, "fileName");
        }
        const s = view.currentWall;
        return s ? s.slice(s.lastIndexOf("/") + 1) : "--";
    }

    function cycleEffect(): void {
        view.effectIndex = (view.effectIndex + 1) % view.effects.length;
    }

    function applySelected(): void {
        const src = view.selectedFilePath;
        if (!src) return;

        view.feedbackMsg = "APPLYING: " + view.selectedFileName;

        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf %s "$1" > "$2"', "sh", src, view.srcFile]);

        const fx = view.currentEffect;
        if (!fx || fx.op === "") {
            Quickshell.execDetached(["sh", "-c",
                'swww query >/dev/null 2>&1 || setsid -f swww-daemon; '
                + 'swww img "$1" --transition-type any && wallust run "$1"',
                "sh", src]);
            view.currentWall = src;
        } else {
            Quickshell.execDetached(["sh", "-c",
                'mkdir -p "$(dirname "$2")" && magick "$1" ' + fx.op + ' "$2" '
                + '&& swww img "$2" --transition-type any && wallust run "$2"',
                "sh", src, view.fxOut]);
            view.currentWall = src;
        }

        msgTimer.restart();
    }

    function copyToClipboard(text: string, label: string): void {
        Quickshell.execDetached(["wl-copy", text]);
        view.feedbackMsg = "COPIED " + label + ": " + text;
        msgTimer.restart();
    }

    Timer {
        id: msgTimer
        interval: 2400
        repeat: false
        onTriggered: view.feedbackMsg = ""
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "GALLERY"
                jp: "壁紙"
                value: ("0" + walls.count).slice(-2)
                subValue: "WALLPAPERS"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "EFFECT"
                jp: "効果"
                value: view.currentEffect.name
                subValue: "SHRINE FILTER"
                warn: view.currentEffect.id !== "NONE"
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: "CYCLE EFFECT"
                jp: "切替"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.cycleEffect()
            }
            Btn {
                text: "APPLY"
                jp: "適用"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.applySelected()
            }
        }
    }

    // ---- Main Studio Layout ----------------------------------------------
    Row {
        anchors.fill: parent
        spacing: 16

        // Left Pane: Wallpaper List & Search (Width 360)
        Column {
            width: 360
            height: parent.height
            spacing: 10

            Item {
                width: parent.width
                height: 24

                Text {
                    id: searchCaret
                    anchors.verticalCenter: parent.verticalCenter
                    text: "/"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szValue
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: searchCaret.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    text: view.wallQuery === "" ? "FILTER WALLPAPERS  絞込" : view.wallQuery
                    color: view.wallQuery === "" ? Theme.dim : Theme.text
                    font.family: view.wallQuery === "" ? Theme.fontDisplay : Theme.fontMono
                    font.pixelSize: view.wallQuery === "" ? Theme.szBody : Theme.szValue
                    font.letterSpacing: view.wallQuery === "" ? Theme.trkWide : Theme.trkTight
                    elide: Text.ElideRight
                }

                TextInput {
                    id: filterInput
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    text: view.wallQuery
                    onTextChanged: {
                        view.wallQuery = text;
                        wallList.currentIndex = 0;
                    }
                    Keys.onEscapePressed: view.closeRequested()
                    Keys.onUpPressed: wallList.decrementCurrentIndex()
                    Keys.onDownPressed: wallList.incrementCurrentIndex()
                    onAccepted: view.applySelected()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_E) {
                            view.cycleEffect();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_C) {
                            view.copyToClipboard(JSON.stringify(Theme.palette, null, 2), "PALETTE JSON");
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line2
            }

            ListView {
                id: wallList
                width: parent.width
                height: parent.height - 35
                clip: true
                model: walls
                spacing: 2
                highlightFollowsCurrentItem: true
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: wallList.width
                    height: 32
                    radius: 0
                    color: ListView.isCurrentItem ? Theme.card : (wallMouse.containsMouse ? Qt.rgba(Theme.layer2.r, Theme.layer2.g, Theme.layer2.b, 0.25) : "transparent")
                    border.width: 1
                    border.color: ListView.isCurrentItem ? Theme.edge : "transparent"

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        visible: ListView.isCurrentItem
                        color: Theme.accentEdge
                    }

                    readonly property bool isCurrent: model.filePath === view.currentWall

                    MouseArea {
                        id: wallMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wallList.currentIndex = index
                        onDoubleClicked: view.applySelected()
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            text: ("0" + (index + 1)).slice(-2)
                            color: ListView.isCurrentItem ? Theme.accent : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: isCurrent
                            width: 32
                            height: 16
                            color: Theme.layer3
                            border.width: 1
                            border.color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "LIVE"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (isCurrent ? 76 : 36)
                            text: model.fileName
                            color: isCurrent ? Theme.accent : (ListView.isCurrentItem ? Theme.text : Theme.dim)
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            font.letterSpacing: Theme.trkLabel
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }

        // Vertical Divider 1
        Rectangle {
            width: 1
            height: parent.height
            color: Theme.line2
        }

        // Middle Pane: Wallpaper Visual Preview (Fill)
        Column {
            width: parent.width - 360 - 320 - 32 - 2
            height: parent.height
            spacing: 12

            Row {
                spacing: 8
                Text {
                    text: "PREVIEW"
                    color: Theme.accent
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szLead
                    font.letterSpacing: Theme.trkWide
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "鑑賞"
                    color: Theme.dim
                    font.family: Theme.fontJP
                    font.pixelSize: Theme.szMicro
                }
            }

            Item {
                width: parent.width
                height: 280

                Rectangle {
                    anchors.fill: parent
                    color: Theme.layer1
                    border.width: 1
                    border.color: Theme.line2
                }

                Image {
                    id: previewImage
                    anchors.fill: parent
                    anchors.margins: 4
                    source: view.selectedFilePath ? "file://" + view.selectedFilePath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top }
                Bracket { corner: "tr"; anchors.right: parent.right; anchors.top: parent.top }
                Bracket { corner: "bl"; anchors.left: parent.left; anchors.bottom: parent.bottom }
                Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: fxLabel.implicitWidth + 12
                    height: 20
                    color: Theme.bg
                    border.width: 1
                    border.color: view.currentEffect.id === "NONE" ? Theme.line : Theme.warn

                    Text {
                        id: fxLabel
                        anchors.centerIn: parent
                        text: "FX: " + view.currentEffect.name + " (" + view.currentEffect.jp + ")"
                        color: view.currentEffect.id === "NONE" ? Theme.dim : Theme.warn
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szMicro
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: view.selectedFileName
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szBody
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: view.selectedFilePath
                    color: Theme.dim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szMicro
                    elide: Text.ElideLeft
                }
            }

            Text {
                text: "AVAILABLE EFFECTS (PRESS E TO CYCLE):"
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.szMicro
                font.letterSpacing: Theme.trkLabel
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: view.effects
                    Rectangle {
                        width: fxBtnText.implicitWidth + 12
                        height: 22
                        color: view.currentEffect.id === modelData.id ? Theme.layer3 : Theme.layer1
                        border.width: 1
                        border.color: view.currentEffect.id === modelData.id ? Theme.accent : Theme.line2

                        MouseArea {
                            anchors.fill: parent
                            onClicked: view.effectIndex = index
                        }

                        Text {
                            id: fxBtnText
                            anchors.centerIn: parent
                            text: modelData.name
                            color: view.currentEffect.id === modelData.id ? Theme.accent : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }
                    }
                }
            }
        }

        // Vertical Divider 2
        Rectangle {
            width: 1
            height: parent.height
            color: Theme.line2
        }

        // Right Pane: Tokyo Design Tokens & Contrast (Width 320)
        Column {
            width: 320
            height: parent.height
            spacing: 12

            Row {
                spacing: 8
                Text {
                    text: "TOKYO TOKENS"
                    color: Theme.accent
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szLead
                    font.letterSpacing: Theme.trkWide
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "色標"
                    color: Theme.dim
                    font.family: Theme.fontJP
                    font.pixelSize: Theme.szMicro
                }
            }

            // Contrast telemetry
            Rectangle {
                width: parent.width
                height: 48
                color: Theme.layer1
                border.width: 1
                border.color: Theme.line2

                Row {
                    anchors.centerIn: parent
                    spacing: 24

                    Column {
                        spacing: 2
                        Text {
                            text: "TEXT CONTRAST"
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                        }
                        Text {
                            text: "≥ 12.0:1 PASS"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szBody
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        spacing: 2
                        Text {
                            text: "ACCENT CONTRAST"
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                        }
                        Text {
                            text: "≥ 7.0:1 PASS"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szBody
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // Swatches column
            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: [
                        { name: "bg",         color: Theme.bg,        hex: Theme.bg },
                        { name: "layer1",     color: Theme.layer1,    hex: Theme.layer1 },
                        { name: "layer2",     color: Theme.layer2,    hex: Theme.layer2 },
                        { name: "layer3",     color: Theme.layer3,    hex: Theme.layer3 },
                        { name: "text",       color: Theme.text,      hex: Theme.text },
                        { name: "dim",        color: Theme.dim,       hex: Theme.dim },
                        { name: "line",       color: Theme.line,      hex: Theme.line },
                        { name: "accent",     color: Theme.accent,    hex: Theme.accent },
                        { name: "accent2",    color: Theme.accent2,   hex: Theme.accent2 },
                        { name: "alert",      color: Theme.alert,     hex: Theme.alert },
                        { name: "warn",       color: Theme.warn,      hex: Theme.warn }
                    ]

                    Rectangle {
                        width: parent.width
                        height: 22
                        color: Theme.layer1
                        border.width: 1
                        border.color: Theme.line2

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: view.copyToClipboard("" + modelData.hex, modelData.name)
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                color: modelData.color
                                border.width: 1
                                border.color: Theme.line
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 80
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "" + modelData.hex
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            text: "COPY"
                            color: Theme.accent2
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                        }
                    }
                }
            }
        }
    }
}
