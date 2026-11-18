@echo off
rem Abre Gambito Arruinado directamente con Godot 4.7.2 (sin abrir el editor).
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo No encontre Godot 4.7.2 en: %GODOT%
  echo Abre el proyecto desde el editor de Godot y presiona F5.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0"
