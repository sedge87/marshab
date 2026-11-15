@echo off
rem The land editor (docs/terrain-design.md section 13): opens in your browser, on this PC only.
rem Close this window to stop it.
cd /d "%~dp0.."
python tools\region_editor.py %*
if errorlevel 1 pause
