@echo off
REM Abre el panel administrativo web de CrediSol en http://localhost:5500
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor.ps1"
