@echo off
rem Food Kiosk: avvia il server e apre il totem e l'area staff nel browser.
cd /d "%~dp0"

rem Avvia il server se non e' gia' in esecuzione, poi aspetta che risponda.
tasklist /fi "imagename eq FoodKioskServer.exe" | find /i "FoodKioskServer.exe" >nul
if errorlevel 1 start "Food Kiosk - server" /min "%~dp0server\bin\FoodKioskServer.exe"
echo Avvio del server Food Kiosk...
powershell -NoProfile -Command "for($i=0;$i -lt 40;$i++){try{Invoke-WebRequest -UseBasicParsing http://localhost:8080/api/health | Out-Null; exit 0}catch{Start-Sleep -Milliseconds 500}}; exit 1"
if errorlevel 1 (
  echo.
  echo Il server non risponde. Apri "Avvia server.bat" per vedere l'errore.
  pause
  exit /b 1
)

start "" http://localhost:8080/kiosk/
start "" http://localhost:8080/staff/
