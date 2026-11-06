[Setup]
AppId={{8B546D15-62AB-4D2A-9F36-3FA22BC1A720}
AppName=SuEmby
AppVersion=0.1.0
DefaultDirName={autopf}\SuEmby
OutputDir=..\Output
OutputBaseFilename=SuEmby-Setup
ArchitecturesInstallIn64BitMode=x64
Compression=lzma2
SolidCompression=yes
[Files]
Source: "..\dist\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{autoprograms}\SuEmby"; Filename: "{app}\SuEmby.exe"
Name: "{autodesktop}\SuEmby"; Filename: "{app}\SuEmby.exe"
