import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SuEmby 1.0

ApplicationWindow {
    id: root
    width: 1440
    height: 900
    minimumWidth: 1040
    minimumHeight: 680
    visible: true
    title: "SuEmby"
    color: "#0b0d12"
    property color primaryText: "#f5f6f8"
    property color secondaryText: "#9ca3b2"
    property var selectedItem: null
    property string currentTitle: "正在播放"
    property bool isLight: false
    property color canvas: isLight ? "#f3f5f8" : "#0b0d12"
    property color panel: isLight ? "#ffffff" : "#141720"
    property color subtlePanel: isLight ? "#e9edf3" : "#1c202b"
    property color ink: isLight ? "#18202d" : "#f5f6f8"
    property color muted: isLight ? "#697386" : "#9ca3b2"

    function loadSection(label) {
        sectionTitle.text = label
        searchBox.text = ""
        if (label === "电影") emby.load("Movie")
        else if (label === "电视剧" || label === "动漫") emby.load("Series")
        else emby.load("Movie")
    }
    function playItem(item) {
        if (!item || !item.id) return
        currentTitle = item.name
        emby.play(item.id)
    }
    function openDetails(item) {
        selectedItem = item
        detailsDialog.open()
    }
    function timeText(value) {
        var s = Math.max(0, Math.floor(value || 0))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
                      : m + ":" + (sec < 10 ? "0" : "") + sec
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 224
            Layout.fillHeight: true
            color: root.panel
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 18
                anchors.topMargin: 26
                anchors.bottomMargin: 20
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 11
                    Rectangle {
                        width: 38; height: 38; radius: 12
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#68a9ff" }
                            GradientStop { position: 1; color: "#7a6cff" }
                        }
                        Text { anchors.centerIn: parent; text: "S"; color: "white"; font.pixelSize: 21; font.bold: true }
                    }
                    Column {
                        spacing: 1
                        Text { text: "SuEmby"; color: root.ink; font.pixelSize: 18; font.bold: true }
                        Text { text: "YOUR MEDIA, YOUR WAY"; color: root.muted; font.pixelSize: 8; font.letterSpacing: 1.1 }
                    }
                }
                Item { height: 36 }
                Text { text: "媒体"; color: root.muted; font.pixelSize: 11; font.bold: true; leftPadding: 12 }
                Item { height: 10 }
                Repeater {
                    model: [
                        {label:"首页", symbol:"⌂"},
                        {label:"电影", symbol:"▣"},
                        {label:"电视剧", symbol:"▤"},
                        {label:"动漫", symbol:"✧"},
                        {label:"继续观看", symbol:"▷"},
                        {label:"收藏", symbol:"♡"}
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 11
                        color: sectionTitle.text === modelData.label ? (root.isLight ? "#e7efff" : "#202b40") : "transparent"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            Text {
                                width: 18; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.symbol
                                color: sectionTitle.text === modelData.label ? "#79aaff" : root.muted
                                font.pixelSize: 18
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: sectionTitle.text === modelData.label ? root.ink : root.muted
                                font.pixelSize: 13
                                font.weight: sectionTitle.text === modelData.label ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.label === "首页") root.loadSection("电影")
                                else root.loadSection(modelData.label)
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.isLight ? "#e6eaf0" : "#272b35"
                }
                Item { height: 14 }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: emby.userId.length ? "●" : "○"; color: emby.userId.length ? "#57d49a" : root.muted; font.pixelSize: 12 }
                    Text {
                        Layout.fillWidth: true
                        text: emby.userId.length ? "Emby 已连接" : "尚未连接服务器"
                        color: root.muted; font.pixelSize: 11; elide: Text.ElideRight
                    }
                }
                Item { height: 10 }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        Layout.fillWidth: true
                        text: emby.userId.length ? "切换账号" : "连接服务器"
                        onClicked: loginDialog.open()
                        background: Rectangle { radius: 10; color: root.subtlePanel }
                        contentItem: Text { text: parent.text; color: root.ink; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: root.isLight ? "☾" : "☼"
                        onClicked: root.isLight = !root.isLight
                        background: Rectangle { radius: 10; color: root.subtlePanel }
                        contentItem: Text { text: parent.text; color: root.ink; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.canvas
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 34
                anchors.rightMargin: 34
                anchors.topMargin: 22
                anchors.bottomMargin: 20
                spacing: 18
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        id: sectionTitle
                        text: "电影"
                        color: root.ink
                        font.pixelSize: 25
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 280
                        height: 40
                        radius: 12
                        color: root.panel
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            Text { text: "⌕"; color: root.muted; font.pixelSize: 22 }
                            TextField {
                                id: searchBox
                                Layout.fillWidth: true
                                placeholderText: "搜索影片、剧集…"
                                color: root.ink
                                placeholderTextColor: root.muted
                                background: Item {}
                                onAccepted: if (text.trim().length) emby.search(text.trim())
                            }
                            Text { text: "↵"; color: root.muted; font.pixelSize: 12 }
                        }
                    }
                    Button {
                        text: "⟳"
                        onClicked: emby.load("Movie")
                        background: Rectangle { radius: 11; color: root.panel }
                        contentItem: Text { text: parent.text; color: root.muted; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 310
                    clip: true
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: root.subtlePanel
                        Image {
                            anchors.fill: parent
                            source: emby.items.length && emby.items[0].hasBackdrop ? emby.items[0].backdrop : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            gradient: Gradient {
                                GradientStop { position: 0; color: root.isLight ? "#b8f3f5f8" : "#c0000000" }
                                GradientStop { position: 0.48; color: root.isLight ? "#e6f3f5f8" : "#a8000000" }
                                GradientStop { position: 1; color: root.isLight ? "#f3f5f8" : "#f00b0d12" }
                            }
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 30
                            anchors.bottomMargin: 27
                            width: Math.min(520, parent.width - 60)
                            spacing: 11
                            Rectangle {
                                width: 112; height: 25; radius: 13
                                color: "#343d50"
                                visible: emby.items.length > 0
                                Text { anchors.centerIn: parent; text: "最近加入片库"; color: "#c8d8f7"; font.pixelSize: 10; font.bold: true }
                            }
                            Text {
                                text: emby.items.length ? emby.items[0].name : (emby.userId.length ? "媒体库已就绪" : "你的私人影院")
                                color: root.ink
                                font.pixelSize: 31
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: emby.items.length ? ((emby.items[0].year ? emby.items[0].year + "  ·  " : "") + (emby.items[0].rating ? "★ " + Number(emby.items[0].rating).toFixed(1) + "  ·  " : "") + (emby.items[0].overview || ""))
                                                      : (emby.userId.length ? "从左侧选择分类，浏览 Emby 服务器中的影片。" : "连接你的 Emby 服务器，开始浏览个人媒体收藏。")
                                color: root.muted
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Row {
                                spacing: 10
                                Button {
                                    text: "▶  立即播放"
                                    enabled: emby.items.length > 0
                                    onClicked: root.playItem(emby.items[0])
                                    background: Rectangle { radius: 10; color: "#f5f6f8" }
                                    contentItem: Text { text: parent.text; color: "#171a20"; font.pixelSize: 12; font.bold: true; leftPadding: 14; rightPadding: 14; verticalAlignment: Text.AlignVCenter }
                                }
                                Button {
                                    text: "查看详情"
                                    enabled: emby.items.length > 0
                                    onClicked: root.openDetails(emby.items[0])
                                    background: Rectangle { radius: 10; color: "#88343a46"; border.color: "#526071"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: root.ink; font.pixelSize: 12; leftPadding: 12; rightPadding: 12; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: searchBox.text.length ? "搜索结果" : "最近添加"; color: root.ink; font.pixelSize: 17; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: emby.items.length ? emby.items.length + " 项" : ""; color: root.muted; font.pixelSize: 11 }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: posters
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 16
                        clip: true
                        model: emby.items
                        delegate: Item {
                            width: 166
                            height: posters.height
                            Column {
                                anchors.fill: parent
                                spacing: 8
                                Rectangle {
                                    width: parent.width
                                    height: Math.min(248, posters.height - 43)
                                    radius: 13
                                    color: root.subtlePanel
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#000000"
                                        opacity: posterHover.containsMouse ? 0.22 : 0
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 44; height: 44; radius: 22
                                        color: "#e9ffffff"
                                        opacity: posterHover.containsMouse ? 1 : 0
                                        Text { anchors.centerIn: parent; text: "▶"; color: "#172033"; font.pixelSize: 16 }
                                    }
                                    MouseArea {
                                        id: posterHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openDetails(modelData)
                                        onDoubleClicked: root.playItem(modelData)
                                    }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top
                                        anchors.margins: 8
                                        width: 39; height: 21; radius: 7
                                        color: "#b5000000"
                                        visible: modelData.rating > 0
                                        Text { anchors.centerIn: parent; text: "★ " + Number(modelData.rating).toFixed(1); color: "#ffe08a"; font.pixelSize: 9; font.bold: true }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: root.ink
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.year ? String(modelData.year) : ""
                                    color: root.muted
                                    font.pixelSize: 10
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: emby.items.length === 0
                            text: emby.userId.length ? "这里还没有内容，尝试切换分类或搜索。" : "连接服务器后，这里会显示你的媒体库内容。"
                            color: root.muted
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: loginDialog
        title: ""
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 430
        standardButtons: Dialog.NoButton
        background: Rectangle { radius: 18; color: root.panel; border.color: root.isLight ? "#e0e5ed" : "#2d3340" }
        header: Item { height: 0 }
        contentItem: ColumnLayout {
            spacing: 13
            Text { text: "连接 Emby"; color: root.ink; font.pixelSize: 22; font.bold: true }
            Text { text: "输入服务器地址和账号信息"; color: root.muted; font.pixelSize: 12 }
            TextField { id: serverField; Layout.fillWidth: true; placeholderText: "服务器地址，例如 http://192.168.1.10:8096" }
            TextField { id: userField; Layout.fillWidth: true; placeholderText: "用户名" }
            TextField { id: passwordField; Layout.fillWidth: true; placeholderText: "密码"; echoMode: TextInput.Password }
            Text { Layout.fillWidth: true; text: emby.error; color: "#ff777f"; wrapMode: Text.WordWrap; font.pixelSize: 11 }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: "取消"; onClicked: loginDialog.close() }
                Button {
                    text: "连接"
                    onClicked: { emby.login(serverField.text, userField.text, passwordField.text); loginDialog.close() }
                    background: Rectangle { radius: 9; color: "#4b86f7" }
                    contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 14; rightPadding: 14 }
                }
            }
        }
    }

    Dialog {
        id: detailsDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(root.width - 80, 820)
        height: Math.min(root.height - 80, 520)
        padding: 0
        background: Rectangle { radius: 18; color: root.panel; border.color: root.isLight ? "#e0e5ed" : "#2d3340"; clip: true }
        contentItem: Item {
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Image {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    source: root.selectedItem ? root.selectedItem.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 26
                    spacing: 12
                    Item { Layout.fillWidth: true
                        Text { anchors.right: parent.right; text: "×"; color: root.muted; font.pixelSize: 25 }
                        MouseArea { anchors.fill: parent; onClicked: detailsDialog.close() }
                    }
                    Text { Layout.fillWidth: true; text: root.selectedItem ? root.selectedItem.name : ""; color: root.ink; font.pixelSize: 25; font.bold: true; wrapMode: Text.WordWrap }
                    Text {
                        Layout.fillWidth: true
                        text: root.selectedItem ? ((root.selectedItem.year ? root.selectedItem.year + "   " : "") + (root.selectedItem.rating ? "★ " + Number(root.selectedItem.rating).toFixed(1) : "")) : ""
                        color: "#eac66a"; font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.selectedItem ? (root.selectedItem.overview || "服务器没有提供简介。") : ""
                        color: root.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 9; elide: Text.ElideRight; verticalAlignment: Text.AlignTop
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button { text: "关闭"; onClicked: detailsDialog.close() }
                        Button {
                            text: "▶  播放"
                            onClicked: { root.playItem(root.selectedItem); detailsDialog.close() }
                            background: Rectangle { radius: 9; color: "#4b86f7" }
                            contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 13; rightPadding: 13 }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: playerDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(root.width - 48, 1120)
        height: Math.min(root.height - 48, 700)
        padding: 0
        background: Rectangle { radius: 16; color: "#08090c"; border.color: "#323743"; clip: true }
        contentItem: Item {
            Rectangle {
                anchors.fill: parent
                color: "#08090c"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.currentTitle; color: "#f5f6f8"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "MPV"; color: "#8792a6"; font.pixelSize: 10; font.bold: true }
                        Button {
                            text: "×"
                            onClicked: playerDialog.close()
                            background: Rectangle { radius: 8; color: "#252a33" }
                            contentItem: Text { text: parent.text; color: "#e5e8ed"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: "#030406"
                        border.color: "#20242c"
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 50
                            spacing: 10
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "▶"; color: "#93b8ff"; font.pixelSize: 34 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.currentTitle; color: "#dce1eb"; font.pixelSize: 16; font.bold: true }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "正在通过 MPV 打开视频流"
                                color: "#777f8d"; font.pixelSize: 11
                            }
                        }
                    }
                    Slider {
                        id: seekSlider
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, mpv.duration)
                        value: mpv.position
                        onMoved: mpv.seek(value)
                        background: Rectangle {
                            x: seekSlider.leftPadding
                            y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                            width: seekSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#323743"
                            Rectangle { width: seekSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#6e9eff" }
                        }
                        handle: Rectangle { x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width); y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2; width: 12; height: 12; radius: 6; color: "#f2f5fb"; border.color: "#6e9eff" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.timeText(mpv.position) + " / " + root.timeText(mpv.duration); color: "#9ca3b2"; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Button { text: "−10"; onClicked: mpv.seek(Math.max(0, mpv.position - 10)) }
                        Button { text: "Ⅱ / ▶"; onClicked: mpv.pause() }
                        Button { text: "+10"; onClicked: mpv.seek(mpv.position + 10) }
                        Text { text: "音量"; color: "#9ca3b2"; font.pixelSize: 10; leftPadding: 12 }
                        Slider { id: volumeSlider; from: 0; to: 100; value: 80; Layout.preferredWidth: 110; onMoved: mpv.volume(value) }
                    }
                }
            }
        }
    }

    Player { id: mpv }
    Connections {
        target: emby
        function onLoggedIn() { root.loadSection("电影") }
        function onPlayUrl(url) { playerDialog.open(); mpv.play(url) }
    }
}
