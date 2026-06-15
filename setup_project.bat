@echo off
title EmmaSarmingStore v2 Setup
echo Starting EmmaSarmingStore v2 Environment Setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_python.ps1"
pause
