# Script de Optimización del Sistema - Windows 10/11
# Requiere ejecución como Administrador

param(
    [switch]$CleanTemp,
    [switch]$OptimizeServices,
    [switch]$DiskCleanup,
    [switch]$NetworkTweak,
    [switch]$FullOptimize
)

# Verificar si se ejecuta como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "⚠️  Este script requiere privilegios de Administrador" -ForegroundColor Yellow
    Write-Host "   Por favor, ejecuta PowerShell como Administrador" -ForegroundColor Yellow
    exit 1
}

# Colores para output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

function Show-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "$Cyan========================================$Reset"
    Write-Host "$Cyan  $Title$Reset"
    Write-Host "$Cyan========================================$Reset"
    Write-Host ""
}

function Clean-TempFiles {
    Show-Header "LIMPIEZA DE ARCHIVOS TEMPORALES"
    
    $tempPaths = @(
        $env:TEMP,
        "$env:windir\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:windir\Prefetch"
    )
    
    $totalCleaned = 0
    $filesRemoved = 0
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $beforeSize = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { -not $_.PSIsContainer } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            $afterSize = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            
            $cleaned = $beforeSize - $afterSize
            $totalCleaned += $cleaned
            $filesRemoved++
            
            Write-Host "  $Green✓$Reset Limpio: $path ($([math]::Round($cleaned / 1MB, 2)) MB)"
        }
    }
    
    # Limpiar Windows Update cache
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "$Green✓ Total limpiado: $([math]::Round($totalCleaned / 1MB, 2)) MB$Reset"
}

function Optimize-WindowsServices {
    Show-Header "OPTIMIZACIÓN DE SERVICIOS"
    
    # Servicios que se pueden deshabilitar de forma segura
    $servicesToDisable = @(
        "DiagTrack",                    # Telemetría
        "dmwappushservice",             # WAP Push
        "MapsBroker",                   # Servicio de mapas
        "lfsvc",                        # Geolocalización
        "SharedAccess",                 # Internet Connection Sharing
        "WMPNetworkSvc",                # Windows Media Player Network
        "XblAuthManager",               # Xbox Live
        "XblGameSave",
        "XboxNetApiSvc",
        "Fax",                          # Fax
        "WpcMonSvc",                    # Parental controls
        "TabletInputService",           # Tablet (si no tienes)
        "RetailDemo",                   # Modo demo
        "WSearch"                       # Windows Search (opcional - comenta si lo usas)
    )
    
    foreach ($service in $servicesToDisable) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.StartType -ne 'Disabled') {
            try {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "  $Green✓$Reset Deshabilitado: $service"
            } catch {
                Write-Host "  $Yellow⚠$Reset No se pudo deshabilitar: $service"
            }
        }
    }
    
    # Optimizar superfetch/prefetch para SSD
    $physicalDisk = Get-PhysicalDisk | Where-Object {$_.BusType -eq 'NVMe' -or $_.BusType -eq 'SATA'}
    if ($physicalDisk.MediaType -eq 'SSD') {
        Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  $Green✓$Reset SysMain deshabilitado (optimizado para SSD)"
    }
}

function Optimize-Network {
    Show-Header "OPTIMIZACIÓN DE RED"
    
    # Configuraciones de red
    $networkSettings = @(
        "netsh int tcp set global autotuninglevel=normal",
        "netsh int tcp set global chimney=enabled",
        "netsh int tcp set global rss=enabled",
        "netsh int tcp set global netdma=enabled",
        "netsh int tcp set global dca=enabled",
        "netsh int tcp set global timestamps=disabled",
        "netsh int tcp set global ecncapability=enabled"
    )
    
    foreach ($setting in $networkSettings) {
        try {
            Invoke-Expression $setting 2>$null
            Write-Host "  $Green✓$Reset Aplicado: $setting"
        } catch {
            Write-Host "  $Yellow⚠$Reset Falló: $setting"
        }
    }
    
    # Flush DNS
    ipconfig /flushdns | Out-Null
    Write-Host "  $Green✓$Reset DNS cache limpiado"
    
    # Reset Winsock
    netsh winsock reset | Out-Null
    Write-Host "  $Green✓$Reset Winsock reseteado (requiere reinicio)"
}

function Invoke-DiskCleanup {
    Show-Header "LIMPIEZA DE DISCO"
    
    # Ejecutar limpieza de disco integrada
    $cleanMgr = "$env:SystemRoot\System32\cleanmgr.exe"
    if (Test-Path $cleanMgr) {
        # Configurar opciones de limpieza
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $itemsToClean = @(
            "Temporary Files",
            "Internet Cache Files",
            "Recycle Bin",
            "Temporary Setup Files",
            "Downloaded Program Files",
            "System error memory dump files",
            "Old ChkDsk files",
            "Previous Installations"
        )
        
        foreach ($item in $itemsToClean) {
            $itemPath = Join-Path $regPath $item
            if (Test-Path $itemPath) {
                Set-ItemProperty -Path $itemPath -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
            }
        }
        
        # Ejecutar en modo automatizado
        Start-Process -FilePath $cleanMgr -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
        Write-Host "  $Green✓$Reset Limpieza de disco completada"
    }
    
    # Analizar y optimizar unidades
    $drives = Get-Volume | Where-Object {$_.DriveLetter -ne $null -and $_.FileSystem -eq 'NTFS'}
    foreach ($drive in $drives) {
        $letter = $drive.DriveLetter
        Write-Host "  Analizando unidad $letter..."
        defrag "$($letter):" /A /U /V 2>$null | Out-Null
    }
}

function Show-SystemStatus {
    Show-Header "ESTADO DEL SISTEMA"
    
    # Información básica
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    
    Write-Host "  $Cyan Sistema:$Reset $($os.Caption) $($os.Version)"
    Write-Host "  $Cyan CPU:$Reset $($cpu.Name)"
    Write-Host "  $Cyan RAM:$Reset $([math]::Round($ram.Sum / 1GB, 2)) GB"
    Write-Host "  $Cyan Tiempo encendido:$Reset $($os.LastBootUpTime)"
    
    # Uso de disco
    Write-Host ""
    Write-Host "  $Cyan Uso de Disco:$Reset"
    Get-Volume | Where-Object {$_.DriveLetter -ne $null} | ForEach-Object {
        $usedPercent = [math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100, 1)
        $color = if ($usedPercent -gt 90) { $Red } elseif ($usedPercent -gt 70) { $Yellow } else { $Green }
        Write-Host "    Unidad $($_.DriveLetter): - $color$usedPercent% usado$Reset ($([math]::Round($_.SizeRemaining / 1GB, 2)) GB libres)"
    }
    
    # Memoria actual
    $memUsed = $ram.Sum - $os.FreePhysicalMemory * 1KB
    $memPercent = [math]::Round(($memUsed / $ram.Sum) * 100, 1)
    Write-Host ""
    Write-Host "  $Cyan Memoria en uso:$Reset $memPercent% ($([math]::Round($memUsed / 1GB, 2)) GB / $([math]::Round($ram.Sum / 1GB, 2)) GB)"
}

# Menú principal
function Show-Menu {
    Clear-Host
    Write-Host "$Cyan╔════════════════════════════════════════════════╗$Reset"
    Write-Host "$Cyan║     OPTIMIZADOR DEL SISTEMA - Windows 10/11  ║$Reset"
    Write-Host "$Cyan╚════════════════════════════════════════════════╝$Reset"
    Write-Host ""
    Write-Host "  $Green[1]$Reset Ver estado del sistema"
    Write-Host "  $Green[2]$Reset Limpiar archivos temporales"
    Write-Host "  $Green[3]$Reset Optimizar servicios de Windows"
    Write-Host "  $Green[4]$reset Limpiar disco"
    Write-Host "  $Green[5]$Reset Optimizar red"
    Write-Host "  $Green[6]$Reset Optimización COMPLETA (recomendado)"
    Write-Host "  $Red[0]$Reset Salir"
    Write-Host ""
}

# Lógica principal
if ($FullOptimize) {
    Show-SystemStatus
    Clean-TempFiles
    Optimize-WindowsServices
    Invoke-DiskCleanup
    Optimize-Network
    Write-Host ""
    Write-Host "$Green✓ Optimización completa finalizada!$Reset" -ForegroundColor Green
    Write-Host "   Se recomienda reiniciar el sistema." -ForegroundColor Yellow
} elseif ($CleanTemp) {
    Clean-TempFiles
} elseif ($OptimizeServices) {
    Optimize-WindowsServices
} elseif ($DiskCleanup) {
    Invoke-DiskCleanup
} elseif ($NetworkTweak) {
    Optimize-Network
} else {
    # Modo interactivo
    do {
        Show-Menu
        $choice = Read-Host "  Selecciona una opción"
        
        switch ($choice) {
            "1" { Show-SystemStatus; Pause }
            "2" { Clean-TempFiles; Pause }
            "3" { Optimize-WindowsServices; Pause }
            "4" { Invoke-DiskCleanup; Pause }
            "5" { Optimize-Network; Pause }
            "6" { 
                Write-Host "$Yellow Iniciando optimización completa...$Reset"
                Show-SystemStatus
                Clean-TempFiles
                Optimize-WindowsServices
                Invoke-DiskCleanup
                Optimize-Network
                Write-Host ""
                Write-Host "$Green✓ Optimización completa finalizada!$Reset"
                Write-Host "$Yellow Se recomienda reiniciar el sistema.$Reset"
                Pause 
            }
            "0" { break }
            default { Write-Host "$Red Opción inválida$Reset"; Start-Sleep -Seconds 1 }
        }
    } while ($choice -ne "0")
}

Write-Host ""
Write-Host "$Cyan Gracias por usar el Optimizador del Sistema$Reset"