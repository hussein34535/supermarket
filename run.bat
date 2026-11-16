@echo off
title Clean The Supermarket
setlocal
cd /d "%~dp0"

rem Keep the Godot exe OUTSIDE this folder. Godot 4.5 crashes with signal 11
rem when the executable sits anywhere inside the project tree.
set "GODOT=%USERPROFILE%\Tools\Godot45\Godot_v4.5-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%ProgramFiles%\Godot\Godot_v4.5-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.5 not found.
  echo Put Godot_v4.5-stable_win64.exe in %USERPROFILE%\Tools\Godot45\
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%~dp0."
