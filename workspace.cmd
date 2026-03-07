@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0scripts\workspace.ps1' %*"
