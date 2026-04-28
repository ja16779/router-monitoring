@echo off
chcp 65001 >nul
title Optimizador del Sistema

echo ======================================
echo  OPTIMIZADOR DEL SISTEMA - Windows
echo ======================================
echo.

:: Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ⚠️  Este script requiere privilegios de Administrador
    echo    Solicitando elevacion...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo Iniciando PowerShell como Administrador...
echo.

:: Ejecutar el script de PowerShell
powershell -ExecutionPolicy Bypass -File "%~dp0optimize_system.ps1"

echo.
pause