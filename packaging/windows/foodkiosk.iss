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
Name: "autostartserver"; Description: "Avvia il server all'accesso a Windows (per i PC che servono cucina e cassa)"; Flags: unchecked
Name: "autostarttotem"; Description: "Avvia il totem a schermo intero all'accesso a Windows"; Components: totem; Flags: unchecked

[Dirs]
Name: "{commonappdata}\FoodKiosk"; Permissions: users-modify

[Files]
Source: "{#SourceDir}\server\*"; DestDir: "{app}\server"; Components: server; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\LEGGIMI.txt"; DestDir: "{app}"; Components: server; Flags: ignoreversion
Source: "{#SourceDir}\totem\*"; DestDir: "{app}\totem"; Components: totem; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\staff\*"; DestDir: "{app}\staff"; Components: staff; Flags: recursesubdirs ignoreversion

; The totem and staff apps start the server themselves (no window); the
; server icon is only for a PC that serves other devices.
[Icons]
Name: "{group}\Food Kiosk Totem"; Filename: "{app}\totem\FoodKioskTotem.exe"; WorkingDir: "{app}\totem"; Components: totem
Name: "{group}\Food Kiosk Totem in finestra"; Filename: "{app}\totem\FoodKioskTotem.exe"; Parameters: "--windowed"; WorkingDir: "{app}\totem"; Components: totem
Name: "{group}\Food Kiosk Staff"; Filename: "{app}\staff\FoodKioskStaff.exe"; WorkingDir: "{app}\staff"; Components: staff
Name: "{group}\Avvia solo il server"; Filename: "{app}\server\bin\FoodKioskServer.exe"; Parameters: "--background"; WorkingDir: "{app}\server\bin"; Flags: runminimized
Name: "{group}\Leggimi"; Filename: "{app}\LEGGIMI.txt"
Name: "{group}\Disinstalla Food Kiosk"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Food Kiosk Totem"; Filename: "{app}\totem\FoodKioskTotem.exe"; WorkingDir: "{app}\totem"; Tasks: desktopicons; Components: totem
Name: "{autodesktop}\Food Kiosk Totem in finestra"; Filename: "{app}\totem\FoodKioskTotem.exe"; Parameters: "--windowed"; WorkingDir: "{app}\totem"; Tasks: desktopicons; Components: totem
Name: "{autodesktop}\Food Kiosk Staff"; Filename: "{app}\staff\FoodKioskStaff.exe"; WorkingDir: "{app}\staff"; Tasks: desktopicons; Components: staff
Name: "{commonstartup}\Food Kiosk Server"; Filename: "{app}\server\bin\FoodKioskServer.exe"; Parameters: "--background"; WorkingDir: "{app}\server\bin"; Flags: runminimized; Tasks: autostartserver
Name: "{commonstartup}\Food Kiosk Totem"; Filename: "{app}\totem\FoodKioskTotem.exe"; WorkingDir: "{app}\totem"; Tasks: autostarttotem

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Food Kiosk server"" dir=in action=allow program=""{app}\server\bin\FoodKioskServer.exe"" enable=yes profile=private,domain"; Flags: runhidden
Filename: "{app}\totem\FoodKioskTotem.exe"; Parameters: "--windowed"; Description: "Apri subito il totem in una finestra"; Components: totem; Flags: postinstall nowait skipifsilent
Filename: "{app}\staff\FoodKioskStaff.exe"; Description: "Apri l'app staff"; Components: staff; Flags: postinstall nowait skipifsilent unchecked

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Food Kiosk server"""; Flags: runhidden; RunOnceId: "FirewallRule"
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im FoodKioskServer.exe"; Flags: runhidden; RunOnceId: "StopServer"
