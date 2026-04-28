@echo off
:: netbox_sync.bat — Corre los scripts de NetBox periodicamente
:: Registrado en Task Scheduler

set SCRIPT_DIR=C:\Users\ja167\.local\bin
set LOG=%SCRIPT_DIR%\netbox_sync.log

echo. >> "%LOG%"
echo ============================================ >> "%LOG%"
echo %DATE% %TIME% — Iniciando sync >> "%LOG%"

:: Scan de IPs activas (IPAM)
echo [IPAM] Escaneando redes... >> "%LOG%"
python "%SCRIPT_DIR%\netbox_scan.py" >> "%LOG%" 2>&1

:: Dispositivos (solo si algo cambia — es idempotente)
echo [DCIM] Actualizando dispositivos... >> "%LOG%"
python "%SCRIPT_DIR%\netbox_routers.py" >> "%LOG%" 2>&1

echo %DATE% %TIME% — Sync completado >> "%LOG%"
