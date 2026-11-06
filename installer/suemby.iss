[Setup]
AppId={{8B546D15-62AB-4D2A-9F36-3FA22BC1A720}
AppName=SuEmby
AppVersion=0.1.0
DefaultDirName={autopf}\SuEmby
OutputDir=..\Output
OutputBaseFilename=SuEmby-Setup
SetupIconFile=..\assets\suemby.ico
UninstallDisplayIcon={app}\SuEmby.exe
ArchitecturesInstallIn64BitMode=x64
Compression=lzma2
SolidCompression=yes
[Files]
Source: "..\dist\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{autoprograms}\SuEmby"; Filename: "{app}\SuEmby.exe"
Name: "{autodesktop}\SuEmby"; Filename: "{app}\SuEmby.exe"

[Code]
function IsSuEmbyRunning: Boolean;
begin
  Result := CheckForMutexes('Local\SuEmby.Running') or
    (FindWindowByWindowName('SuEmby') <> 0);
end;

function InitializeUninstall: Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  if IsSuEmbyRunning then
  begin
    if MsgBox('SuEmby 仍在运行。选择“是”强制关闭程序并继续卸载；选择“否”取消卸载，退出程序后再试。',
      mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      exit;
    end;
    Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM SuEmby.exe /T /F', '',
      SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if IsSuEmbyRunning then
    begin
      MsgBox('无法关闭 SuEmby。请手动退出程序后重新卸载。', mbError, MB_OK);
      Result := False;
    end;
  end;
end;
