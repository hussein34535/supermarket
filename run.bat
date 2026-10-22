@echo off
title Clean The Supermarket
setlocal

set GODOT=tools\Godot_v4.5-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot not found in tools^. Download Godot 4.5+ and place the exe there.
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%~dp0."
