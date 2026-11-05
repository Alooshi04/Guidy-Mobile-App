@echo off
REM Double-click to set up everything Guidy needs on this PC
REM (Git, Python, JDK + Android SDK, Flutter, backend packages).
REM Safe to run again. Options: -SkipBuild  -SkipEmulator
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1" %*
