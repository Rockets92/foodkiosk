# Builds the Windows package: server, totem and staff apps, web builds and
# launchers in dist\FoodKiosk; with -Installer also dist\FoodKiosk-Setup.exe
# (needs Inno Setup 6). Requires Flutter (stable) with Visual Studio's
# "Desktop development with C++" workload.
param(
  [string]$Out = "dist\FoodKiosk",
  [switch]$Installer,
  [string]$Version = "1.0.0"
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root

function Run([string]$exe, [string[]]$arguments) {
  & $exe @arguments
  if ($LASTEXITCODE -ne 0) { throw "$exe $arguments failed ($LASTEXITCODE)" }
}

Run dart @('pub', 'get')
Push-Location server
Run dart @('build', 'cli', '-o', "$root\build\server")
Pop-Location

foreach ($app in 'kiosk', 'staff') {
  Push-Location "apps\$app"
  Run flutter @('pub', 'get')
  Run flutter @('build', 'windows', '--release')
  Run flutter @('build', 'web', '--release', "--base-href=/$app/", '--no-web-resources-cdn')
  Pop-Location
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force "$Out\web" | Out-Null
Copy-Item "build\server\bundle" "$Out\server" -Recurse
Rename-Item "$Out\server\bin\server.exe" "FoodKioskServer.exe"
Copy-Item "apps\kiosk\build\web" "$Out\web\kiosk" -Recurse
Copy-Item "apps\staff\build\web" "$Out\web\staff" -Recurse
Copy-Item "apps\kiosk\build\windows\x64\runner\Release" "$Out\totem" -Recurse
Copy-Item "apps\staff\build\windows\x64\runner\Release" "$Out\staff" -Recurse
Copy-Item "packaging\windows\launchers\*" $Out
Write-Host "Package ready in $Out"

if ($Installer) {
  $iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
  if (-not $iscc) { $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
  Run $iscc @("/DSourceDir=$root\$Out", "/DAppVersion=$Version", "/O$root\dist", "packaging\windows\foodkiosk.iss")
  Write-Host "Installer ready in dist\FoodKiosk-Setup.exe"
}
