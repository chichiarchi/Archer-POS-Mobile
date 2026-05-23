@echo off
title Archer POS v2 Setup
echo Starting Archer POS v2 Environment Setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_python.ps1"
pause
