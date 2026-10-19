@echo off
rem Food Kiosk: avvia il server in questa finestra (chiudila per fermarlo).
cd /d "%~dp0"
"%~dp0server\bin\FoodKioskServer.exe" %*
pause
