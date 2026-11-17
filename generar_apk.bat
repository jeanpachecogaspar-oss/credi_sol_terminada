@echo off
REM Compila la APK de CrediSol y la deja con su nombre oficial: CrediSol-v<version>.apk
cd /d "%~dp0"
for /f "tokens=2 delims=: " %%v in ('findstr /b "version:" pubspec.yaml') do set VERSION_COMPLETA=%%v
for /f "tokens=1 delims=+" %%v in ("%VERSION_COMPLETA%") do set VERSION=%%v
echo Compilando CrediSol v%VERSION% ...
call flutter clean
call flutter pub get
call flutter build apk --release
if errorlevel 1 (
  echo.
  echo ERROR: no se pudo compilar. Revisa los mensajes de arriba.
  pause
  exit /b 1
)
copy /y "build\app\outputs\flutter-apk\app-release.apk" "CrediSol-v%VERSION%.apk" >nul
echo.
echo Listo: %CD%\CrediSol-v%VERSION%.apk
pause
