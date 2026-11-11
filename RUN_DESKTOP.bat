@echo off
rem Runs the game from source in a desktop window. Needs Godot 4.7:
rem put Godot .exe into the tools folder and rename it to godot.exe
if exist "%~dp0tools\godot.exe" (
  "%~dp0tools\godot.exe" --path "%~dp0"
) else (
  godot --path "%~dp0" || (echo Put Godot 4.7 exe into tools\godot.exe & pause)
)
