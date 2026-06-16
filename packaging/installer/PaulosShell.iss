#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef SourceRoot
  #define SourceRoot "..\.."
#endif

[Setup]
AppId={{D5D0D16F-0F78-4BE2-A5A4-0B5C6A72B11D}}
AppName=PaulosShell
AppVersion={#AppVersion}
AppVerName=PaulosShell {#AppVersion}
AppPublisher=dpaulos6
AppPublisherURL=https://github.com/dpaulos6/shell.dpaulos.pt
AppSupportURL=https://github.com/dpaulos6/shell.dpaulos.pt
AppUpdatesURL=https://github.com/dpaulos6/shell.dpaulos.pt/releases
DefaultDirName={userdocs}\PowerShell\Modules\PaulosShell
DefaultGroupName=PaulosShell
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
AllowCancelDuringInstall=yes
AppendDefaultDirName=no
OutputBaseFilename=PaulosShell-{#AppVersion}-Setup
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UninstallDisplayIcon={app}\PaulosShell.psd1
UninstallDisplayName=PaulosShell
VersionInfoVersion={#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
RestartIfNeededByRun=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceRoot}\src\PaulosShell\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Dirs]
Name: "{app}"
