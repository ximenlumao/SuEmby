import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SuEmby 1.0
ApplicationWindow{id:root;width:1200;height:780;visible:true;title:"SuEmby";color:"#111318";property color fg:"#f4f5f7"
header:ToolBar{RowLayout{anchors.fill:parent;Label{text:"SuEmby";font.pixelSize:24;font.bold:true;color:fg}Item{Layout.fillWidth:true}TextField{id:q;placeholderText:"搜索影片";onAccepted:emby.search(text)}Button{text:"连接服务器";onClicked:dlg.open()}}}
Dialog{id:dlg;title:"登录 Emby";modal:true;standardButtons:Dialog.Ok|Dialog.Cancel;Column{spacing:8;TextField{id:url;placeholderText:"http://服务器:8096"}TextField{id:user;placeholderText:"用户名"}TextField{id:pw;placeholderText:"密码";echoMode:TextInput.Password}Label{text:emby.error}}onAccepted:emby.login(url.text,user.text,pw.text)}
ColumnLayout{anchors.fill:parent;anchors.margins:24;RowLayout{Label{text:"媒体库";font.pixelSize:28;color:fg}Item{Layout.fillWidth:true}ComboBox{id:typ;model:["电影","电视剧","动漫"];onActivated:emby.load(index===0?"Movie":"Series")}}
GridView{Layout.fillWidth:true;Layout.fillHeight:true;cellWidth:200;cellHeight:310;model:emby.items;delegate:Item{width:185;height:295;Column{Image{width:175;height:245;fillMode:Image.PreserveAspectCrop;source:modelData.image}Label{text:modelData.name;color:fg;width:175;elide:Text.ElideRight}}MouseArea{anchors.fill:parent;onDoubleClicked:emby.play(modelData.id)}}}}
Dialog{id:playerDialog;modal:true;width:800;height:460;contentItem:Player{id:mpv;anchors.fill:parent}}
Connections{target:emby;function onLoggedIn(){emby.load()}function onPlayUrl(url){playerDialog.open();mpv.play(url)}}
}