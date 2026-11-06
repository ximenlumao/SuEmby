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
    property bool playPending: false
    property string feedbackText: ""
    property string lastMpvError: ""
    property bool isLight: false
    property color canvas: isLight ? "#f3f5f8" : "#0b0d12"
    property color panel: isLight ? "#ffffff" : "#141720"
    property color subtlePanel: isLight ? "#e9edf3" : "#1c202b"
    property color ink: isLight ? "#18202d" : "#f5f6f8"
    property color muted: isLight ? "#697386" : "#9ca3b2"

    component TactileButton: Button {
        id: control
        property bool accent: false
        implicitHeight: 40
        scale: down ? 0.96 : (hovered ? 1.025 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        background: Rectangle {
            radius: 11
            color: control.accent ? (control.down ? "#3567c2" : (control.hovered ? "#5b91f3" : "#4b82e8"))
                                  : (control.down ? "#343d4c" : (control.hovered ? "#2a3240" : "#202632"))
            border.width: control.hovered ? 1 : 0
            border.color: control.accent ? "#9bbcff" : "#4a566a"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Text {
            text: control.text
            color: "#f3f6fb"
            font.pixelSize: 12
            font.weight: control.accent ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            leftPadding: 12
            rightPadding: 12
        }
    }

    function loadSection(label) {
        sectionTitle.text = label
        searchBox.text = ""
        if (label === "首页") emby.loadHome()
        else if (label === "继续观看") emby.loadSpecial("resume")
        else if (label === "收藏") emby.loadSpecial("favorites")
    }
    function showFeedback(message) {
        feedbackText = message
        feedbackToast.open()
        feedbackTimer.restart()
    }
    function showEpisodes(item) {
        if (!item) return
        sectionTitle.text = item.name + " · 分集"
        detailsDialog.close()
        emby.loadSeriesEpisodes(item.id)
    }
    function loadLibrary(id, label, collectionType) {
        sectionTitle.text = label
        searchBox.text = ""
        emby.loadLibrary(id, collectionType)
    }
    function playItem(item) {
        if (!item || !item.id || playPending) return
        if (item.type === "Series") {
            openDetails(item)
            return
        }
        currentTitle = item.name
        playPending = true
        showFeedback("正在连接 Emby 并准备播放…")
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
                                root.loadSection(modelData.label)
                            }
                        }
                    }
                }
                Repeater {
                    model: emby.libraries
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 11
                        color: sectionTitle.text === modelData.name ? (root.isLight ? "#e7efff" : "#202b40") : "transparent"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            Text {
                                width: 18; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.type === "tvshows" ? "▤" : (modelData.type === "movies" ? "▣" : "◈")
                                color: sectionTitle.text === modelData.name ? "#79aaff" : root.muted
                                font.pixelSize: 17
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: sectionTitle.text === modelData.name ? root.ink : root.muted
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                width: 145
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadLibrary(modelData.id, modelData.name, modelData.type)
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
                    TactileButton {
                        Layout.fillWidth: true
                        text: emby.userId.length ? "切换账号" : "连接服务器"
                        onClicked: loginDialog.open()
                    }
                    TactileButton {
                        text: root.isLight ? "☾" : "☼"
                        onClicked: root.isLight = !root.isLight
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
                    TactileButton {
                        text: "↻"
                        onClicked: {
                            if (sectionTitle.text === "首页") root.loadSection("首页")
                            else if (emby.libraries.length) {
                                for (var i = 0; i < emby.libraries.length; ++i)
                                    if (emby.libraries[i].name === sectionTitle.text)
                                        root.loadLibrary(emby.libraries[i].id, emby.libraries[i].name, emby.libraries[i].type)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    visible: sectionTitle.text === "首页" && emby.libraries.length > 0
                    ListView {
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 9
                        clip: true
                        model: emby.libraries
                        delegate: Rectangle {
                            width: Math.max(112, libraryName.implicitWidth + 42)
                            height: 34
                            radius: 10
                            color: categoryHover.pressed ? "#34496a" : (categoryHover.containsMouse ? "#263348" : root.panel)
                            border.color: categoryHover.containsMouse ? "#587bad" : "#252b37"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: modelData.type === "tvshows" ? "▤" : (modelData.type === "movies" ? "▣" : "◈"); color: "#89b4ff"; font.pixelSize: 14 }
                                Text { id: libraryName; text: modelData.name; color: root.ink; font.pixelSize: 11; font.bold: true }
                            }
                            MouseArea {
                                id: categoryHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.loadLibrary(modelData.id, modelData.name, modelData.type)
                            }
                        }
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
                                TactileButton {
                                    accent: true
                                    text: root.playPending ? "正在连接…" : "▶  立即播放"
                                    enabled: emby.items.length > 0 && !root.playPending
                                    onClicked: root.playItem(emby.items[0])
                                }
                                TactileButton {
                                    text: "查看详情"
                                    enabled: emby.items.length > 0
                                    onClicked: root.openDetails(emby.items[0])
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: searchBox.text.length ? "搜索结果" : "最近添加"; color: root.ink; font.pixelSize: 17; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: emby.loading ? "正在加载…" : (emby.items.length ? emby.items.length + " 项" : ""); color: root.muted; font.pixelSize: 11 }
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
                                        scale: posterHover.containsMouse ? 1 : 0.92
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                        Text { anchors.centerIn: parent; text: modelData.type === "Series" ? "⋯" : "▶"; color: "#172033"; font.pixelSize: 16 }
                                    }
                                    MouseArea {
                                        id: posterHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openDetails(modelData)
                                    }
                                    MouseArea {
                                        anchors.centerIn: parent
                                        width: 54; height: 54
                                        visible: posterHover.containsMouse
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.playItem(modelData)
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: parent.pressed ? "#9bbcff" : (parent.containsMouse ? "#ffffff" : "#e9ffffff")
                                            border.color: "#c4d7ff"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: modelData.type === "Series" ? "⋯" : "▶"; color: "#172033"; font.pixelSize: 16 }
                                        }
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
            TextField {
                id: serverField; Layout.fillWidth: true; placeholderText: "服务器地址，例如 http://192.168.1.10:8096"
                color: root.ink; placeholderTextColor: root.muted; leftPadding: 14; rightPadding: 14; selectByMouse: true
                background: Rectangle { radius: 10; color: root.subtlePanel; border.width: serverField.activeFocus ? 1 : 0; border.color: "#6e9eff" }
            }
            TextField {
                id: userField; Layout.fillWidth: true; placeholderText: "用户名"
                color: root.ink; placeholderTextColor: root.muted; leftPadding: 14; rightPadding: 14; selectByMouse: true
                background: Rectangle { radius: 10; color: root.subtlePanel; border.width: userField.activeFocus ? 1 : 0; border.color: "#6e9eff" }
            }
            TextField {
                id: passwordField; Layout.fillWidth: true; placeholderText: "密码"; echoMode: TextInput.Password
                color: root.ink; placeholderTextColor: root.muted; leftPadding: 14; rightPadding: 14; selectByMouse: true
                background: Rectangle { radius: 10; color: root.subtlePanel; border.width: passwordField.activeFocus ? 1 : 0; border.color: "#6e9eff" }
            }
            Text { Layout.fillWidth: true; text: emby.error; color: "#ff777f"; wrapMode: Text.WordWrap; font.pixelSize: 11 }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                TactileButton { text: "取消"; onClicked: loginDialog.close() }
                TactileButton {
                    accent: true
                    text: "连接"
                    onClicked: emby.login(serverField.text, userField.text, passwordField.text)
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
                        TactileButton {
                            text: root.selectedItem && root.selectedItem.favorite ? "♥ 已收藏" : "♡ 收藏"
                            onClicked: if (root.selectedItem) {
                                root.selectedItem.favorite = !root.selectedItem.favorite
                                emby.setFavorite(root.selectedItem.id, root.selectedItem.favorite)
                            }
                        }
                        Item { Layout.fillWidth: true }
                        TactileButton {
                            visible: root.selectedItem && root.selectedItem.type === "Series"
                            text: "选择分集"
                            onClicked: root.showEpisodes(root.selectedItem)
                        }
                        TactileButton { text: "关闭"; onClicked: detailsDialog.close() }
                        TactileButton {
                            visible: !root.selectedItem || root.selectedItem.type !== "Series"
                            accent: true
                            text: root.playPending ? "正在连接…" : "▶  播放"
                            enabled: !root.playPending
                            onClicked: { root.playItem(root.selectedItem); if (root.selectedItem && root.selectedItem.type !== "Series") detailsDialog.close() }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: playerDialog
        modal: true
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: Overlay.overlay
        width: Math.min(root.width - 48, 1120)
        onClosed: {
            emby.stopPlayback(mpv.position, mpv.duration)
            mpv.stop()
        }
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
                        TactileButton {
                            text: "×"
                            Layout.preferredWidth: 42
                            onClicked: playerDialog.close()
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: "#030406"
                        border.color: "#20242c"
                        clip: true
                        MpvVideoItem {
                            id: videoSurface
                            anchors.fill: parent
                            player: mpv
                            active: playerDialog.visible
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            visible: !mpv.playing
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "▶"; color: "#93b8ff"; font.pixelSize: 34 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.currentTitle; color: "#dce1eb"; font.pixelSize: 16; font.bold: true }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: mpv.error.length ? "播放失败：" + mpv.error : (mpv.playing ? "正在打开视频流…" : "正在连接视频流…")
                                color: mpv.error.length ? "#ff8790" : "#a3adbd"
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                width: Math.min(520, root.width - 100)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                    Item {
                        id: seekBar
                        Layout.fillWidth: true
                        height: 24
                        property real preview: mpv.position
                        property bool dragging: false
                        property real ratio: mpv.duration > 0 ? Math.max(0, Math.min(1, (dragging ? preview : mpv.position) / mpv.duration)) : 0
                        function seekAt(x) {
                            if (mpv.duration <= 0 || width <= 0) return
                            preview = Math.max(0, Math.min(1, x / width)) * mpv.duration
                            mpv.seek(preview)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 5
                            radius: 3
                            color: "#303746"
                            Rectangle {
                                width: seekBar.width * seekBar.ratio
                                height: parent.height
                                radius: 3
                                color: "#6e9eff"
                            }
                        }
                        Rectangle {
                            width: 13; height: 13; radius: 7
                            x: Math.max(0, Math.min(parent.width - width, seekBar.width * seekBar.ratio - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            color: seekMouse.containsMouse || seekMouse.pressed ? "#ffffff" : "#d4e1ff"
                            border.color: "#6e9eff"
                            border.width: 2
                            scale: seekMouse.pressed ? 1.18 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                        MouseArea {
                            id: seekMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: { seekBar.dragging = true; seekBar.seekAt(mouse.x) }
                            onPositionChanged: if (pressed) seekBar.seekAt(mouse.x)
                            onReleased: {
                                seekBar.seekAt(mouse.x)
                                seekBar.dragging = false
                                emby.reportPlaybackProgress(seekBar.preview, mpv.duration, "TimeUpdate", mpv.paused)
                            }
                            onCanceled: seekBar.dragging = false
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: root.timeText(mpv.position) + "  /  " + root.timeText(mpv.duration)
                            color: "#aab2c1"
                            font.pixelSize: 11
                            font.family: "Segoe UI"
                        }
                        Item { Layout.fillWidth: true }
                        TactileButton {
                            text: "↶ 10"
                            onClicked: mpv.seek(Math.max(0, mpv.position - 10))
                        }
                        TactileButton {
                            accent: true
                            text: mpv.paused ? "▶  播放" : "Ⅱ  暂停"
                            onClicked: {
                                mpv.pause()
                                emby.reportPlaybackProgress(mpv.position, mpv.duration,
                                    mpv.paused ? "Pause" : "Unpause", mpv.paused)
                            }
                        }
                        TactileButton {
                            text: "10 ↷"
                            onClicked: mpv.seek(Math.min(mpv.duration, mpv.position + 10))
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "音量"; color: "#9ca8bb"; font.pixelSize: 11 }
                        Slider {
                            id: volumeSlider
                            from: 0; to: 100; value: 80
                            Layout.preferredWidth: 120
                            onMoved: mpv.volume(value)
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#303746"
                                Rectangle { width: volumeSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#829fe0" }
                            }
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 12; height: 12; radius: 6
                                color: "#e7edf8"
                                border.color: "#829fe0"
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Item { Layout.fillWidth: true }
                        Text { text: "音轨"; color: "#9ca8bb"; font.pixelSize: 11 }
                        ComboBox {
                            id: audioSelector
                            Layout.preferredWidth: 190
                            model: mpv.audioTracks
                            textRole: "label"
                            currentIndex: {
                                for (var i = 0; i < mpv.audioTracks.length; ++i)
                                    if (mpv.audioTracks[i].selected) return i
                                return mpv.audioTracks.length ? 0 : -1
                            }
                            onActivated: {
                                mpv.setAudioTrack(mpv.audioTracks[index].id)
                                emby.reportPlaybackProgress(mpv.position, mpv.duration, "AudioTrackChange", mpv.paused)
                            }
                            contentItem: Text {
                                leftPadding: 12; rightPadding: 30
                                text: audioSelector.displayText || "选择音轨"
                                color: "#e5eaf2"; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            }
                            background: Rectangle {
                                radius: 9; color: audioSelector.down ? "#303b4c" : "#1c222d"
                                border.color: audioSelector.hovered ? "#718bb8" : "#343c49"
                            }
                            delegate: ItemDelegate {
                                width: audioSelector.width
                                text: modelData.label
                                highlighted: audioSelector.highlightedIndex === index
                                contentItem: Text { text: parent.text; color: "#e8edf5"; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                background: Rectangle { color: parent.highlighted ? "#34445f" : "#171c25"; radius: 6 }
                            }
                            popup.background: Rectangle { radius: 10; color: "#171c25"; border.color: "#343c49" }
                        }
                        Text { text: "字幕"; color: "#9ca8bb"; font.pixelSize: 11 }
                        ComboBox {
                            id: subtitleSelector
                            Layout.preferredWidth: 210
                            model: mpv.subtitleTracks
                            textRole: "label"
                            currentIndex: {
                                for (var i = 0; i < mpv.subtitleTracks.length; ++i)
                                    if (mpv.subtitleTracks[i].selected) return i
                                return mpv.subtitleTracks.length ? 0 : -1
                            }
                            onActivated: {
                                mpv.setSubtitleTrack(mpv.subtitleTracks[index].id)
                                emby.reportPlaybackProgress(mpv.position, mpv.duration, "SubtitleTrackChange", mpv.paused)
                            }
                            contentItem: Text {
                                leftPadding: 12; rightPadding: 30
                                text: subtitleSelector.displayText || "选择字幕"
                                color: "#e5eaf2"; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            }
                            background: Rectangle {
                                radius: 9; color: subtitleSelector.down ? "#303b4c" : "#1c222d"
                                border.color: subtitleSelector.hovered ? "#718bb8" : "#343c49"
                            }
                            delegate: ItemDelegate {
                                width: subtitleSelector.width
                                text: modelData.label
                                highlighted: subtitleSelector.highlightedIndex === index
                                contentItem: Text { text: parent.text; color: "#e8edf5"; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                background: Rectangle { color: parent.highlighted ? "#34445f" : "#171c25"; radius: 6 }
                            }
                            popup.background: Rectangle { radius: 10; color: "#171c25"; border.color: "#343c49" }
                        }
                        Item { Layout.fillWidth: true }
                    }                }
            }
        }
    }

    Popup {
        id: feedbackToast
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: root.height - height - 24
        width: Math.min(520, root.width - 40)
        height: 50
        padding: 0
        closePolicy: Popup.NoAutoClose
        background: Rectangle { radius: 13; color: "#222a37"; border.color: "#46536a" }
        contentItem: Text {
            text: root.feedbackText
            color: "#f0f3f8"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            leftPadding: 14; rightPadding: 14
        }
    }
    Timer {
        id: feedbackTimer
        interval: 3600
        onTriggered: feedbackToast.close()
    }
    Player { id: mpv }
    Timer {
        interval: 10000
        repeat: true
        running: playerDialog.visible && mpv.playing && !mpv.paused
        onTriggered: emby.reportPlaybackProgress(mpv.position, mpv.duration, "TimeUpdate", mpv.paused)
    }
    Component.onCompleted: {
        serverField.text = emby.savedServer
        userField.text = emby.savedUsername
        passwordField.text = emby.savedPassword
        if (emby.savedServer.length && emby.savedPassword.length) emby.restoreSession()
        else loginDialog.open()
    }
    Connections {
        target: mpv
        function onChanged() {
            if (mpv.error.length && mpv.error !== root.lastMpvError) {
                root.lastMpvError = mpv.error
                root.playPending = false
                root.showFeedback("MPV 播放失败：" + mpv.error)
            }
            if (mpv.playing && mpv.duration > 0 && mpv.position >= mpv.duration - 1.2) {
                emby.stopPlayback(mpv.duration, mpv.duration)
                mpv.stop()
            }
        }
    }
    Connections {
        target: emby
        function onLoggedIn() {
            loginDialog.close()
            root.loadSection("首页")
        }
        function onErrorChanged() {
            if (root.playPending && emby.error.length) {
                root.playPending = false
                root.showFeedback("播放失败：" + emby.error)
            }
        }
        function onPlayUrl(url) {
            root.playPending = false
            playerDialog.open()
            mpv.play(url)
        }
    }
}
