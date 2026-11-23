@echo off
setlocal
set "engine=%TEMP%\ashen-godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%engine%" set "engine=godot"
start "" "%engine%" --path "%~dp0mobile" --resolution 1100x760 res://tools/pose_editor/editor.tscn -- --cuts
