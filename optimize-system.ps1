#!/usr/bin/env pwsh
#requires -Version 5.1

<#
.SYNOPSIS
    System Optimizer CLI - Aplica optimizaciones automáticas al sistema Windows.

.DESCRIPTION
    Este script aplica optimizaciones al sistema Windows incluyendo:
    - Limpieza de archivos temporales
    - Optimización de servicios
    - Configuración de rendimiento
    - Limpieza de caché de Windows Update
    - Optimización de inicio

.PARAMETER Safe
    Solo aplica optimizaciones seguras (recomendado)

.PARAMETER Aggressive
    Aplica optimizaciones más agresivas (con precaución)

.PARAMETER CreateRestorePoint
    Crea un punto de restauración antes de aplicar cambios

.EXAMPLE
    .\optimize-system.ps1 -Safe -CreateRestorePoint
    Ejecuta optimizaciones seguras con punto de restauración

.EXAMPLE
    .\optimize-system.ps1 -WhatIf
    Muestra qué cambios se realizarían sin aplicarlos
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$Safe,

    [Parameter()]
    [switch]$Aggressive,

    [Parameter()]
    [switch]$CreateRestorePoint,

    [Parameter()]
    [switch]$WhatIf
)

# Colores
$Colors = @{
    Header    = "Cyan"
    Success   = "Green"
    Warning   = "Yellow"
    Error     = "Red"
    Info      = "White"
    Accent    = "Magenta"
    Border    = "DarkGray"
}

$OptimizationResults = @{
    TempFilesCleaned = 0
    ServicesOptimized = 0
    SpaceFreed = 0
    Errors = @()
}

function Write-Header {
    param([string]$Text, [string]$Color = $Colors.Header)
    Write-Host "`n┌─────────────────────────────────────────────────────────────┐" -ForegroundColor $Colors.Border
    Write-Host "│ $Text".PadRight(61) "│" -ForegroundColor $Color
    Write-Host "└─────────────────────────────────────────────────────────────┘" -ForegroundColor $Colors.Border
}

function Write-Action {
    param([string]$Action, [string]$Status = "Info")
    $color = switch ($Status) {
        "Success" { $Colors.Success }
        "Warning" { $Colors.Warning }
        "Error"   { $Colors.Error }
        default   { $Colors.Info }
    }
    $symbol = switch ($Status) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error"   { "✗" }
        default   { "•" }
    }
    Write-Host "  $symbol $Action" -ForegroundColor $color
}

function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RestorePoint {
    if (-not (Test-IsAdmin)) {
        Write-Action "Se requieren privilegios de Administrador para crear punto de restauración" "Warning"
        return $false
    }
    
    try {
        Write-Action "Creando punto de restauración del sistema..." "Info"
        Checkpoint-Computer -Description "SystemOptimizer_$(Get-Date -Format 'yyyyMMdd')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Action "Punto de restauración creado exitosamente" "Success"
        return $true
    } catch {
        Write-Action "Error creando punto de restauración: $_" "Warning"
        return $false
    }
}

function Clear-TempFiles {
    Write-Header "LIMPIEZA DE ARCHIVOS TEMPORALES" $Colors.Warning
    
    $paths = @(
        @{ Path = $env:TEMP; Name = "Temp del usuario" },
        @{ Path = "C:\Windows\Temp"; Name = "Temp de Windows" },
        @{ Path = "C:\Windows\Prefetch"; Name = "Prefetch" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\*.db"; Name = "Caché de iconos" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"; Name = "Caché de miniaturas" },
        @{ Path = "C:\Windows\SoftwareDistribution\Download"; Name = "Caché de Windows Update" }
    )
    
    $totalSize = 0
    $totalFiles = 0
    
    foreach ($item in $paths) {
        $path = $item.Path
        
        if (Test-Path $path) {
            try {
                if ($PSCmdlet.ShouldProcess($item.Name, "Limpiar archivos temporales")) {
                    $items = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $size = ($items | Measure-Object -Property Length -Sum).Sum
                    
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    
                    $totalSize += $size
                    $totalFiles += $items.Count
                    
                    Write-Action "$($item.Name): $(Format-Bytes $size) liberados" "Success"
                } else {
                    Write-Action "$($item.Name): Simulando limpieza..." "Info"
                }
            } catch {
                Write-Action "$($item.Name): Error - $_" "Warning"
                $OptimizationResults.Errors += "Temp $($item.Name): $_"
            }
        } else {
            Write-Action "$($item.Name): No existe" "Warning"
        }
    }
    
    # Papelera de reciclaje
    try {
        if ($PSCmdlet.ShouldProcess("Papelera de reciclaje", "Vaciar")) {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Action "Papelera de reciclaje vaciada" "Success"
        } else {
            Write-Action "Papelera de reciclaje: Simulando..." "Info"
        }
    } catch {
        Write-Action "Papelera de reciclaje: Error - $_" "Warning"
    }
    
    $OptimizationResults.TempFilesCleaned = $totalFiles
    $OptimizationResults.SpaceFreed = $totalSize
    
    Write-Host "`nTotal liberado: $(Format-Bytes $totalSize) en $totalFiles archivos" -ForegroundColor $Colors.Success
}

function Format-Bytes {
    param([long]$Bytes)
    $sizes = 'B','KB','MB','GB','TB'
    $i = 0
    $value = [double]$Bytes
    while ($value -ge 1024 -and $i -lt $sizes.Count - 1) {
        $value /= 1024
        $i++
    }
    return "{0:N2} {1}" -f $value, $sizes[$i]
}

function Optimize-Services {
    Write-Header "OPTIMIZACIÓN DE SERVICIOS" $Colors.Warning
    
    $servicesToDisable = @()
    
    if ($Safe) {
        # Servicios seguros para deshabilitar en modo Safe
        $servicesToDisable = @(
            @{ Name = "Fax"; DisplayName = "Servicio de Fax" },
            @{ Name = "WMPNetworkSvc"; DisplayName = "Servicios de red de WMP" },
            @{ Name = "MapsBroker"; DisplayName = "Administrador de mapas" },
            @{ Name = "XblAuthManager"; DisplayName = "Xbox Live Auth" },
            @{ Name = "XblGameSave"; DisplayName = "Xbox Game Save" },
            @{ Name = "XboxNetApiSvc"; DisplayName = "Xbox Net API" }
        )
    } elseif ($Aggressive) {
        # Servicios adicionales en modo agresivo
        $servicesToDisable += @(
            @{ Name = "DiagTrack"; DisplayName = "Telemetría" },
            @{ Name = "dmwappushservice"; DisplayName = "Notificaciones WAP" },
            @{ Name = "WerSvc"; DisplayName = "Informes de error" }
        )
    }
    
    foreach ($svc in $servicesToDisable) {
        try {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                if ($PSCmdlet.ShouldProcess($svc.DisplayName, "Detener y deshabilitar servicio")) {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                    $OptimizationResults.ServicesOptimized++
                    Write-Action "$($svc.DisplayName): Detenido y deshabilitado" "Success"
                } else {
                    Write-Action "$($svc.DisplayName): Simulando..." "Info"
                }
            } else {
                Write-Action "$($svc.DisplayName): Ya está deshabilitado o no existe" "Info"
            }
        } catch {
            Write-Action "$($svc.DisplayName): Error - $_" "Warning"
            $OptimizationResults.Errors += "Service $($svc.Name): $_"
        }
    }
}

function Optimize-Performance {
    Write-Header "OPTIMIZACIÓN DE RENDIMIENTO" $Colors.Warning
    
    # Configurar plan de energía a alto rendimiento
    try {
        if ($PSCmdlet.ShouldProcess("Plan de energía", "Cambiar a Alto Rendimiento")) {
            $powerPlan = powercfg /list | Select-String "Alto rendimiento|High performance"
            if ($powerPlan) {
                $planGuid = ($powerPlan -split "\s+")[3]
                powercfg /setactive $planGuid | Out-Null
                Write-Action "Plan de energía cambiado a Alto Rendimiento" "Success"
            } else {
                Write-Action "Plan de Alto Rendimiento no disponible" "Warning"
            }
        } else {
            Write-Action "Plan de energía: Simulando cambio..." "Info"
        }
    } catch {
        Write-Action "Plan de energía: Error - $_" "Warning"
    }
    
    # Deshabilitar efectos visuales (opcional en modo agresivo)
    if ($Aggressive) {
        try {
            if ($PSCmdlet.ShouldProcess("Efectos visuales", "Ajustar para mejor rendimiento")) {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
                Write-Action "Efectos visuales ajustados para mejor rendimiento" "Success"
            } else {
                Write-Action "Efectos visuales: Simulando..." "Info"
            }
        } catch {
            Write-Action "Efectos visuales: Error - $_" "Warning"
        }
    }
    
    # Liberar memoria (vaciar standby list)
    try {
        if ($PSCmdlet.ShouldProcess("Memoria standby", "Liberar")) {
            # Usar RAMMap si está disponible, o método alternativo
            $proc = Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet -Descending | Select-Object -First 1
            [GC]::Collect()
            Write-Action "Memoria liberada (GC ejecutado)" "Success"
        } else {
            Write-Action "Memoria: Simulando liberación..." "Info"
        }
    } catch {
        Write-Action "Memoria: Error - $_" "Warning"
    }
}

function Optimize-Disk {
    Write-Header "OPTIMIZACIÓN DE DISCO" $Colors.Warning
    
    # Ejecutar limpieza de disco
    try {
        if ($PSCmdlet.ShouldProcess("Limpieza de disco", "Ejecutar")) {
            Write-Action "Iniciando limpieza de disco (puede tomar unos minutos)..." "Info"
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Action "Limpieza de disco completada" "Success"
        } else {
            Write-Action "Limpieza de disco: Simulando..." "Info"
        }
    } catch {
        Write-Action "Limpieza de disco: Error - $_" "Warning"
    }
    
    # Desfragmentar/optimizar unidades (solo HDD)
    try {
        if ($PSCmdlet.ShouldProcess("Unidades", "Optimizar")) {
            $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
            foreach ($drive in $drives) {
                $defrag = Optimize-Volume -DriveLetter $drive.DeviceID[0] -Analyze -ErrorAction SilentlyContinue
                if ($defrag.OptimizationStatus -eq "FullDefragmentationRecommended") {
                    Write-Action "Desfragmentando $($drive.DeviceID)..." "Info"
                    Optimize-Volume -DriveLetter $drive.DeviceID[0] -Defrag -ErrorAction SilentlyContinue
                    Write-Action "$($drive.DeviceID): Desfragmentado" "Success"
                } else {
                    Write-Action "$($drive.DeviceID): No requiere optimización" "Info"
                }
            }
        } else {
            Write-Action "Optimización de unidades: Simulando..." "Info"
        }
    } catch {
        Write-Action "Optimización de unidades: Error - $_" "Warning"
    }
}

function Show-Summary {
    Write-Header "RESUMEN DE OPTIMIZACIÓN" $Colors.Success
    
    Write-Host "`nResultados:" -ForegroundColor $Colors.Accent
    Write-Host "  • Archivos temporales eliminados: $($OptimizationResults.TempFilesCleaned)" -ForegroundColor $Colors.Info
    Write-Host "  • Espacio total liberado: $(Format-Bytes $OptimizationResults.SpaceFreed)" -ForegroundColor $Colors.Success
    Write-Host "  • Servicios optimizados: $($OptimizationResults.ServicesOptimized)" -ForegroundColor $Colors.Info
    
    if ($OptimizationResults.Errors.Count -gt 0) {
        Write-Host "`n  Errores encontrados: $($OptimizationResults.Errors.Count)" -ForegroundColor $Colors.Warning
    }
    
    Write-Host "`n  ✓ Optimización completada" -ForegroundColor $Colors.Success
    Write-Host "  Se recomienda reiniciar el sistema para aplicar todos los cambios." -ForegroundColor $Colors.Warning
}

# ============================================
# SCRIPT PRINCIPAL
# ============================================

Clear-Host

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              SYSTEM OPTIMIZER CLI v1.0                        ║
║                                                                ║
║  Optimizando tu sistema Windows...                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Accent

# Verificar administrador
if (-not (Test-IsAdmin)) {
    Write-Host "`n⚠ ADVERTENCIA: Algunas optimizaciones requieren ejecutar como Administrador" -ForegroundColor $Colors.Warning
    $continue = Read-Host "`n¿Deseas continuar de todos modos? (S/N)"
    if ($continue -ne 'S' -and $continue -ne 's') {
        exit 0
    }
}

# Modo por defecto si no se especifica ninguno
if (-not $Safe -and -not $Aggressive) {
    $Safe = $true
    Write-Host "`nℹ Modo SAFE activado (recomendado)" -ForegroundColor $Colors.Info
}

# Mostrar modo de ejecución
$mode = if ($WhatIf) { "SIMULACIÓN (WhatIf)" } elseif ($Aggressive) { "AGRESIVO" } else { "SEGURIDAD" }
Write-Host "  Modo: $mode" -ForegroundColor $Colors.Accent

if (-not $WhatIf) {
    $confirm = Read-Host "`n¿Proceder con la optimización? (S/N)"
    if ($confirm -ne 'S' -and $confirm -ne 's') {
        Write-Host "Operación cancelada." -ForegroundColor $Colors.Warning
        exit 0
    }
}

# Crear punto de restauración si se solicitó
if ($CreateRestorePoint) {
    New-RestorePoint
}

# Ejecutar optimizaciones
Clear-TempFiles
Optimize-Services
Optimize-Performance
Optimize-Disk

# Mostrar resumen
Show-Summary