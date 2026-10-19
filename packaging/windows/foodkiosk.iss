; Inno Setup script for Food Kiosk. Built by build.ps1 -Installer, which
; passes SourceDir (the assembled package) and AppVersion.
#ifndef SourceDir
  #define SourceDir "..\..\dist\FoodKiosk"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6B0F7A52-2D7B-4C4B-9E0E-5F4D2C8A9B11}
AppName=Food Kiosk
AppVersion={#AppVersion}
AppPublisher=Food Kiosk
DefaultDirName={autopf}\Food Kiosk
DefaultGroupName=Food Kiosk
OutputBaseFilename=FoodKiosk-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
UninstallDisplayIcon={app}\totem\FoodKioskTotem.exe

[Languages]
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Tutto su questo PC (server, totem e staff)"
Name: "totem"; Description: "Totem self-service con server"
Name: "staff"; Description: "Postazione staff (cassa/cucina) con server"
Name: "custom"; Description: "Personalizzata"; Flags: iscustom

[Components]
Name: "server"; Description: "Server Food Kiosk (necessario)"; Types: full totem staff custom; Flags: fixed
Name: "totem"; Description: "App totem self-service"; Types: full totem
Name: "staff"; Description: "App staff: cassa, cucina, ritiro, menu, impostazioni"; Types: full staff

[Tasks]
Name: "desktopicons"; Description: "Icone sul desktop"
Name: "autostartserver"; Description: "Avvia il server all'accesso a Windows"
Name: "autostarttotem"; Description: "Avvia il totem a schermo intero all'accesso a Windows"; Components: totem; Flags: unchecked

[Dirs]
Name: "{commonappdata}\FoodKiosk"; Permissions: users-modify

[Files]
Source: "{#SourceDir}\server\*"; DestDir: "{app}\server"; Components: server; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\web\*"; DestDir: "{app}\web"; Components: server; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\Avvia demo.bat"; DestDir: "{app}"; Components: server; Flags: ignoreversion
Source: "{#SourceDir}\Avvia server.bat"; DestDir: "{app}"; Components: server; Flags: ignoreversion
Source: "{#SourceDir}\LEGGIMI.txt"; DestDir: "{app}"; Components: server; Flags: ignoreversion isreadme
Source: "{#SourceDir}\totem\*"; DestDir: "{app}\totem"; Components: totem; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\Avvia totem.bat"; DestDir: "{app}"; Components: totem; Flags: ignoreversion
Source: "{#SourceDir}\Avvia totem in finestra.bat"; DestDir: "{app}"; Components: totem; Flags: ignoreversion
Source: "{#SourceDir}\staff\*"; DestDir: "{app}\staff"; Components: staff; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\Avvia staff.bat"; DestDir: "{app}"; Components: staff; Flags: ignoreversion

[Icons]
Name: "{group}\Food Kiosk - Demo nel browser"; Filename: "{app}\Avvia demo.bat"; WorkingDir: "{app}"; IconFilename: "{app}\server\bin\FoodKioskServer.exe"
Name: "{group}\Food Kiosk - Server"; Filename: "{app}\Avvia server.bat"; WorkingDir: "{app}"; IconFilename: "{app}\server\bin\FoodKioskServer.exe"
Name: "{group}\Food Kiosk - Totem"; Filename: "{app}\Avvia totem.bat"; WorkingDir: "{app}"; IconFilename: "{app}\totem\FoodKioskTotem.exe"; Components: totem
Name: "{group}\Food Kiosk - Totem in finestra"; Filename: "{app}\Avvia totem in finestra.bat"; WorkingDir: "{app}"; IconFilename: "{app}\totem\FoodKioskTotem.exe"; Components: totem
Name: "{group}\Food Kiosk - Staff"; Filename: "{app}\Avvia staff.bat"; WorkingDir: "{app}"; IconFilename: "{app}\staff\FoodKioskStaff.exe"; Components: staff
Name: "{group}\Leggimi"; Filename: "{app}\LEGGIMI.txt"
Name: "{group}\Disinstalla Food Kiosk"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Food Kiosk - Demo"; Filename: "{app}\Avvia demo.bat"; WorkingDir: "{app}"; IconFilename: "{app}\server\bin\FoodKioskServer.exe"; Tasks: desktopicons
Name: "{autodesktop}\Food Kiosk - Totem"; Filename: "{app}\Avvia totem.bat"; WorkingDir: "{app}"; IconFilename: "{app}\totem\FoodKioskTotem.exe"; Tasks: desktopicons; Components: totem
Name: "{autodesktop}\Food Kiosk - Staff"; Filename: "{app}\Avvia staff.bat"; WorkingDir: "{app}"; IconFilename: "{app}\staff\FoodKioskStaff.exe"; Tasks: desktopicons; Components: staff
Name: "{commonstartup}\Food Kiosk - Server"; Filename: "{app}\server\bin\FoodKioskServer.exe"; WorkingDir: "{app}"; Flags: runminimized; Tasks: autostartserver
Name: "{commonstartup}\Food Kiosk - Totem"; Filename: "{app}\Avvia totem.bat"; WorkingDir: "{app}"; Flags: runminimized; Tasks: autostarttotem

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Food Kiosk server"" dir=in action=allow program=""{app}\server\bin\FoodKioskServer.exe"" enable=yes profile=private,domain"; Flags: runhidden
Filename: "{app}\Avvia demo.bat"; Description: "Prova subito la demo nel browser"; Flags: postinstall nowait skipifsilent shellexec

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Food Kiosk server"""; Flags: runhidden; RunOnceId: "FirewallRule"
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im FoodKioskServer.exe"; Flags: runhidden; RunOnceId: "StopServer"
