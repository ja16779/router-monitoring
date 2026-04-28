#!/usr/bin/env pwsh
#requires -Version 5.1

<#
.SYNOPSIS
    System Optimizer Analyzer CLI - Analyzes Windows system and generates optimization recommendations.

.DESCRIPTION
    This script analyzes the Windows system for improvement areas including:
    - Disk usage and temporary files
    - RAM consumption
    - High consumption processes
    - Startup programs
    - Unnecessary services
    - Pending updates
    - System errors

.PARAMETER Export
    Exports report to a file (JSON or HTML)

.PARAMETER Silent
    Runs in silent mode without showing progress in console

.PARAMETER Quick
    Performs only quick analysis (skips large file search)

.EXAMPLE
    .\system-analyzer.ps1
    Runs complete analysis and displays report in console

.EXAMPLE
    .\system-analyzer.ps1 -Export HTML -Quick
    Quick analysis and exports to HTML
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("JSON", "HTML")]
    [string]$Export,

    [Parameter()]
    [switch]$Silent,

    [Parameter()]
    [switch]$Quick
)

# Console color configuration
$Colors = @{
    Header      = "Cyan"
    Success     = "Green"
    Warning     = "Yellow"
    Error       = "Red"
    Info        = "White"
    Accent      = "Magenta"
    Border      = "DarkGray"
}

# Global variables
$Script:AnalysisResults = @{
    Timestamp   = Get-Date
    System      = @{}
    Disk        = @{}
    Memory      = @{}
    Processes   = @()
    Startup     = @()
    Services    = @()
    Updates     = @{}
    Events      = @()
    TempFiles   = @{}
    Recommendations = @()
}
$Script:TotalScore = 100

# ============================================
# UTILITY FUNCTIONS
# ============================================

function Write-Header {
    param([string]$Text, [string]$Color = $Colors.Header)
    Write-Host "`n=============================================================" -ForegroundColor $Colors.Border
    Write-Host " $Text" -ForegroundColor $Color
    Write-Host "=============================================================" -ForegroundColor $Colors.Border
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host "`n>> $Text" -ForegroundColor $Colors.Accent
    Write-Host "".PadRight(60, "-") -ForegroundColor $Colors.Border
}

function Write-Metric {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Status = "Info",
        [string]$Unit = ""
    )
    $color = switch ($Status) {
        "Good"  { $Colors.Success }
        "Warn"  { $Colors.Warning }
        "Bad"   { $Colors.Error }
        default { $Colors.Info }
    }
    $line = "  {0,-25}: {1,-20} {2}" -f $Label, "$Value$Unit", ""
    Write-Host $line -ForegroundColor $color
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

function Add-Recommendation {
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [ValidateSet("High", "Medium", "Low")]
        [string]$Priority = "Medium",
        
        [string]$Impact = "",
        
        [scriptblock]$Action = $null
    )
    
    $recommendation = [PSCustomObject]@{
        Category    = $Category
        Description = $Description
        Priority    = $Priority
        Impact      = $Impact
        Action      = $Action
    }
    
    $Script:AnalysisResults.Recommendations += $recommendation
    
    # Adjust score based on priority
    switch ($Priority) {
        "High"   { $Script:TotalScore -= 5 }
        "Medium" { $Script:TotalScore -= 3 }
        "Low"    { $Script:TotalScore -= 1 }
    }
}

function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================
# ANALYSIS: SYSTEM INFORMATION
# ============================================

function Get-SystemInfo {
    if (-not $Silent) { Write-SubHeader "System Information" }
    
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        
        $Script:AnalysisResults.System = @{
            ComputerName    = $computerSystem.Name
            Manufacturer    = $computerSystem.Manufacturer
            Model           = $computerSystem.Model
            OS              = $operatingSystem.Caption
            OSVersion       = $operatingSystem.Version
            Architecture    = $operatingSystem.OSArchitecture
            InstallDate     = $operatingSystem.InstallDate
            LastBootTime    = $operatingSystem.LastBootUpTime
            Uptime          = (Get-Date) - $operatingSystem.LastBootUpTime
            TotalMemoryGB   = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            Processor       = $processor.Name.Trim()
            Cores           = $processor.NumberOfCores
            LogicalProcessors = $processor.NumberOfLogicalProcessors
        }
        
        if (-not $Silent) {
            Write-Metric "Computer" $Script:AnalysisResults.System.ComputerName
            Write-Metric "Manufacturer" $Script:AnalysisResults.System.Manufacturer
            Write-Metric "Model" $Script:AnalysisResults.System.Model
            Write-Metric "Operating System" $Script:AnalysisResults.System.OS
            Write-Metric "Version" $Script:AnalysisResults.System.OSVersion
            Write-Metric "Architecture" $Script:AnalysisResults.System.Architecture
            Write-Metric "Processor" $Script:AnalysisResults.System.Processor -Status Info
            Write-Metric "Cores/Logical" "$($Script:AnalysisResults.System.Cores) / $($Script:AnalysisResults.System.LogicalProcessors)"
            Write-Metric "Total RAM" "$($Script:AnalysisResults.System.TotalMemoryGB) GB"
            Write-Metric "Uptime" "$($Script:AnalysisResults.System.Uptime.Days) days, $($Script:AnalysisResults.System.Uptime.Hours) hours"
        }
        
        # Check if old Windows 10/11
        if ($operatingSystem.Version -lt "10.0.19045" -and $operatingSystem.Caption -like "*Windows 10*") {
            Add-Recommendation -Category "System" `
                -Description "Your Windows 10 version is outdated. Consider updating to the latest version or upgrading to Windows 11." `
                -Priority "Medium" `
                -Impact "Security and performance improvements"
        }
        
    } catch {
        Write-Warning "Error getting system information: $_"
    }
}

# ============================================
# ANALYSIS: DISK AND STORAGE
# ============================================

function Get-DiskAnalysis {
    if (-not $Silent) { Write-SubHeader "Disk Analysis" }
    
    $diskInfo = @()
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    
    foreach ($drive in $drives) {
        $size = $drive.Size
        $free = $drive.FreeSpace
        $used = $size - $free
        $percentFree = [math]::Round(($free / $size) * 100, 2)
        
        $status = if ($percentFree -lt 10) { "Bad" } elseif ($percentFree -lt 20) { "Warn" } else { "Good" }
        
        $driveData = @{
            Drive       = $drive.DeviceID
            Size        = $size
            Free        = $free
            Used        = $used
            PercentFree = $percentFree
            Status      = $status
        }
        
        $diskInfo += $driveData
        
        if (-not $Silent) {
            Write-Metric "Drive $($drive.DeviceID)" "" $status
            Write-Host "    Size: $(Format-Bytes $size) | Free: $(Format-Bytes $free) | Used: $(Format-Bytes $used)" -ForegroundColor $Colors.Info
            Write-Host "    Free space: $percentFree %" -ForegroundColor $(if ($status -eq "Good") { $Colors.Success } elseif ($status -eq "Warn") { $Colors.Warning } else { $Colors.Error })
        }
        
        # Recommendation if disk is very full
        if ($percentFree -lt 10) {
            Add-Recommendation -Category "Storage" `
                -Description "Drive $($drive.DeviceID) has only $percentFree% free space. This severely affects performance." `
                -Priority "High" `
                -Impact "Freeing space will significantly improve performance"
        } elseif ($percentFree -lt 20) {
            Add-Recommendation -Category "Storage" `
                -Description "Drive $($drive.DeviceID) has $percentFree% free space. Consider freeing space." `
                -Priority "Medium" `
                -Impact "Better system stability"
        }
    }
    
    $Script:AnalysisResults.Disk = @{
        Drives = $diskInfo
    }
}

# ============================================
# ANALYSIS: RAM MEMORY
# ============================================

function Get-MemoryAnalysis {
    if (-not $Silent) { Write-SubHeader "Memory Analysis" }
    
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalRAM = $os.TotalVisibleMemorySize * 1KB
        $freeRAM = $os.FreePhysicalMemory * 1KB
        $usedRAM = $totalRAM - $freeRAM
        $percentUsed = [math]::Round(($usedRAM / $totalRAM) * 100, 2)
        
        $virtualMemory = Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue | 
            Select-Object -Property Name, CurrentUsage, PeakUsage, AllocatedBaseSize
        
        $Script:AnalysisResults.Memory = @{
            Total       = $totalRAM
            Used        = $usedRAM
            Free        = $freeRAM
            PercentUsed = $percentUsed
            VirtualMemory = $virtualMemory
        }
        
        $status = if ($percentUsed -gt 90) { "Bad" } elseif ($percentUsed -gt 75) { "Warn" } else { "Good" }
        
        if (-not $Silent) {
            Write-Metric "Total Memory" (Format-Bytes $totalRAM)
            Write-Metric "Used Memory" (Format-Bytes $usedRAM) $status
            Write-Metric "Free Memory" (Format-Bytes $freeRAM)
            Write-Metric "Percent Used" "$percentUsed %" $status
        }
        
        if ($percentUsed -gt 90) {
            Add-Recommendation -Category "Memory" `
                -Description "RAM usage is critical ($percentUsed%). Close unnecessary applications or consider expanding RAM." `
                -Priority "High" `
                -Impact "Will reduce slowness and freezing"
        } elseif ($percentUsed -gt 75) {
            Add-Recommendation -Category "Memory" `
                -Description "RAM usage is elevated ($percentUsed%)." `
                -Priority "Medium" `
                -Impact "Will improve multitasking capability"
        }
        
        # Virtual memory analysis
        if ($virtualMemory) {
            $totalPageFile = ($virtualMemory | Measure-Object -Property AllocatedBaseSize -Sum).Sum * 1MB
            $usedPageFile = ($virtualMemory | Measure-Object -Property CurrentUsage -Sum).Sum * 1MB
            
            if (-not $Silent) {
                Write-Metric "Virtual Memory Total" (Format-Bytes $totalPageFile)
                Write-Metric "Virtual Memory Used" (Format-Bytes $usedPageFile)
            }
            
            if ($usedPageFile -gt ($totalRAM * 0.5)) {
                Add-Recommendation -Category "Memory" `
                    -Description "Virtual memory usage is high. The system is using disk as extended memory." `
                    -Priority "Medium" `
                    -Impact "Will reduce SSD/HDD wear"
            }
        }
        
    } catch {
        Write-Warning "Error analyzing memory: $_"
    }
}

# ============================================
# ANALYSIS: HIGH CONSUMPTION PROCESSES
# ============================================

function Get-TopProcesses {
    if (-not $Silent) { Write-SubHeader "Top 10 Processes by Memory Usage" }
    
    try {
        $processes = Get-Process | 
            Sort-Object WorkingSet -Descending | 
            Select-Object -First 10 |
            Select-Object Name, Id, @{N="MemoryMB";E={[math]::Round($_.WorkingSet / 1MB, 2)}}, Path
        
        $Script:AnalysisResults.Processes = $processes
        
        if (-not $Silent) {
            $processes | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor $Colors.Info
        }
        
        # Detect suspicious high consumption processes
        $highMemory = $processes | Where-Object { $_.MemoryMB -gt 500 }
        foreach ($proc in $highMemory) {
            Add-Recommendation -Category "Processes" `
                -Description "Process '$($proc.Name)' consumes $($proc.MemoryMB) MB RAM. Verify if necessary." `
                -Priority "Low" `
                -Impact "Free RAM memory"
        }
        
    } catch {
        Write-Warning "Error analyzing processes: $_"
    }
}

# ============================================
# ANALYSIS: STARTUP PROGRAMS
# ============================================

function Get-StartupAnalysis {
    if (-not $Silent) { Write-SubHeader "Startup Programs" }
    
    try {
        $startupItems = @()
        
        # Registry: HKLM and HKCU Run
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        )
        
        foreach ($path in $regPaths) {
            if (Test-Path $path) {
                $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
                $hive = if ($path -like "HKLM:*") { "Machine" } else { "User" }
                foreach ($prop in $items.PSObject.Properties) {
                    if ($prop.Name -ne "PSPath" -and $prop.Name -ne "PSParentPath" -and 
                        $prop.Name -ne "PSChildName" -and $prop.Name -ne "PSDrive" -and
                        $prop.Name -ne "PSProvider" -and -not [string]::IsNullOrWhiteSpace($prop.Value)) {
                        $startupItems += [PSCustomObject]@{
                            Name     = $prop.Name
                            Command  = $prop.Value
                            Location = "Registry ($hive)"
                            Enabled  = $true
                        }
                    }
                }
            }
        }
        
        # Startup folder
        $startupFolders = @(
            [Environment]::GetFolderPath("Startup"),
            [Environment]::GetFolderPath("CommonStartup")
        )
        
        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                $folderName = if ($folder -like "*Common*") { "Common Startup" } else { "User Startup" }
                Get-ChildItem $folder -File | ForEach-Object {
                    $startupItems += [PSCustomObject]@{
                        Name     = $_.BaseName
                        Command  = $_.FullName
                        Location = "Folder ($folderName)"
                        Enabled  = $true
                    }
                }
            }
        }
        
        $Script:AnalysisResults.Startup = $startupItems
        
        if (-not $Silent) {
            if ($startupItems.Count -gt 0) {
                Write-Host "  Total startup programs: $($startupItems.Count)" -ForegroundColor $Colors.Warning
                $startupItems | Select-Object Name, Location | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor $Colors.Info
            } else {
                Write-Host "  No startup programs found." -ForegroundColor $Colors.Success
            }
        }
        
        # Recommendation if many startup programs
        if ($startupItems.Count -gt 10) {
            Add-Recommendation -Category "Startup" `
                -Description "You have $($startupItems.Count) programs configured to start automatically. Consider disabling unused ones." `
                -Priority "Medium" `
                -Impact "Will reduce system boot time"
        }
        
    } catch {
        Write-Warning "Error analyzing startup programs: $_"
    }
}

# ============================================
# ANALYSIS: SERVICES
# ============================================

function Get-ServicesAnalysis {
    if (-not $Silent) { Write-SubHeader "Services Analysis" }
    
    try {
        $services = Get-Service | Where-Object { $_.Status -eq "Running" }
        $runningCount = $services.Count
        
        # Services that could be disabled
        $optionalServices = @(
            "Fax", "WMPNetworkSvc", "MapsBroker", "WMPNetworkSvc",
            "XblAuthManager", "XblGameSave", "XboxNetApiSvc",
            "DiagTrack", "dmwappushservice", "WerSvc"
        )
        
        $foundOptional = $services | Where-Object { $optionalServices -contains $_.Name }
        
        $Script:AnalysisResults.Services = @{
            TotalRunning = $runningCount
            OptionalRunning = $foundOptional
        }
        
        if (-not $Silent) {
            Write-Metric "Running services" $runningCount
            
            if ($foundOptional) {
                Write-Host "`n  Optional services running:" -ForegroundColor $Colors.Warning
                $foundOptional | Select-Object Name, DisplayName | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor $Colors.Info
            }
        }
        
        if ($foundOptional -and $foundOptional.Count -gt 3) {
            Add-Recommendation -Category "Services" `
                -Description "There are $($foundOptional.Count) optional services running that could be disabled if not used." `
                -Priority "Low" `
                -Impact "Will free system resources"
        }
        
    } catch {
        Write-Warning "Error analyzing services: $_"
    }
}

# ============================================
# ANALYSIS: TEMPORARY FILES
# ============================================

function Get-TempFilesAnalysis {
    if (-not $Silent) { Write-SubHeader "Temporary Files Analysis" }
    
    $tempPaths = @{
        WindowsTemp     = $env:TEMP
        SystemTemp      = "C:\Windows\Temp"
        Prefetch        = "C:\Windows\Prefetch"
        Recent          = [Environment]::GetFolderPath("Recent")
        Cookies         = [Environment]::GetFolderPath("Cookies")
        InternetCache   = [Environment]::GetFolderPath("InternetCache")
    }
    
    $tempAnalysis = @{}
    $totalTempSize = 0
    
    foreach ($key in $tempPaths.Keys) {
        $path = $tempPaths[$key]
        if (Test-Path $path) {
            try {
                $size = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum
                $totalTempSize += $size
                
                $tempAnalysis[$key] = @{
                    Path = $path
                    Size = $size
                }
                
                if (-not $Silent) {
                    Write-Metric $key "$(Format-Bytes $size)"
                }
            } catch {
                $tempAnalysis[$key] = @{
                    Path = $path
                    Size = 0
                    Error = "Could not access"
                }
            }
        }
    }
    
    # Windows Update files
    $updateCache = "C:\Windows\SoftwareDistribution\Download"
    if (Test-Path $updateCache) {
        try {
            $updateSize = (Get-ChildItem $updateCache -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
            $totalTempSize += $updateSize
            
            $tempAnalysis["WindowsUpdateCache"] = @{
                Path = $updateCache
                Size = $updateSize
            }
            
            if (-not $Silent) {
                Write-Metric "Windows Update Cache" "$(Format-Bytes $updateSize)"
            }
        } catch {}
    }
    
    $Script:AnalysisResults.TempFiles = $tempAnalysis
    $Script:AnalysisResults.TotalTempSize = $totalTempSize
    
    if (-not $Silent) {
        Write-Host "`n  Total temporary files: $(Format-Bytes $totalTempSize)" -ForegroundColor $(if ($totalTempSize -gt 1GB) { $Colors.Warning } else { $Colors.Success })
    }
    
    if ($totalTempSize -gt 1GB) {
        Add-Recommendation -Category "Storage" `
            -Description "Temporary files occupy $(Format-Bytes $totalTempSize). You can safely free this space." `
            -Priority "Medium" `
            -Impact "Free $(Format-Bytes $totalTempSize) of disk space"
    } elseif ($totalTempSize -gt 500MB) {
        Add-Recommendation -Category "Storage" `
            -Description "Temporary files occupy $(Format-Bytes $totalTempSize)." `
            -Priority "Low" `
            -Impact "Free $(Format-Bytes $totalTempSize) of disk space"
    }
}

# ============================================
# ANALYSIS: WINDOWS UPDATES
# ============================================

function Get-WindowsUpdateAnalysis {
    if (-not $Silent) { Write-SubHeader "Windows Update Status" }
    
    try {
        # Require Windows Update module or use alternative
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        
        $pendingUpdates = $searchResult.Updates.Count
        
        $Script:AnalysisResults.Updates = @{
            PendingCount = $pendingUpdates
            Updates = @()
        }
        
        if ($pendingUpdates -gt 0) {
            $updates = $searchResult.Updates | Select-Object -First 5 Title, IsDownloaded
            $Script:AnalysisResults.Updates.Updates = $updates
            
            if (-not $Silent) {
                Write-Metric "Pending updates" $pendingUpdates "Warn"
                $updates | ForEach-Object {
                    $title = if ($_.Title.Length -gt 50) { $_.Title.Substring(0, 50) + "..." } else { $_.Title }
                    Write-Host "  - $title" -ForegroundColor $Colors.Info
                }
            }
            
            Add-Recommendation -Category "Updates" `
                -Description "There are $pendingUpdates pending updates to install." `
                -Priority "High" `
                -Impact "Will improve system security and stability"
        } else {
            if (-not $Silent) {
                Write-Metric "Pending updates" "0" "Good"
                Write-Host "  System is up to date." -ForegroundColor $Colors.Success
            }
        }
        
    } catch {
        if (-not $Silent) {
            Write-Host "  Could not check updates (possibly requires running as Administrator)" -ForegroundColor $Colors.Warning
        }
    }
}

# ============================================
# ANALYSIS: SYSTEM EVENTS
# ============================================

function Get-SystemEventsAnalysis {
    if (-not $Silent) { Write-SubHeader "Recent System Errors" }
    
    try {
        $startTime = (Get-Date).AddDays(-7)
        
        $errorEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Level = 1, 2  # Critical and Error
            StartTime = $startTime
        } -ErrorAction SilentlyContinue | Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message
        
        $appErrorEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            Level = 1, 2
            StartTime = $startTime
        } -ErrorAction SilentlyContinue | Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message
        
        $allErrors = @($errorEvents) + @($appErrorEvents) | Sort-Object TimeCreated -Descending | Select-Object -First 10
        
        $Script:AnalysisResults.Events = $allErrors
        
        if (-not $Silent) {
            if ($allErrors.Count -gt 0) {
                Write-Metric "Errors (last 7 days)" $allErrors.Count $(if ($allErrors.Count -gt 20) { "Warn" } else { "Info" })
                $allErrors | Select-Object -First 5 | Format-Table TimeCreated, LevelDisplayName, Id -AutoSize | Out-String | Write-Host -ForegroundColor $Colors.Info
            } else {
                Write-Host "  No critical recent errors found." -ForegroundColor $Colors.Success
            }
        }
        
        if ($allErrors.Count -gt 20) {
            Add-Recommendation -Category "System" `
                -Description "$($allErrors.Count) errors detected in the last 7 days. Review Event Viewer." `
                -Priority "Medium" `
                -Impact "Will help identify stability issues"
        }
        
    } catch {
        if (-not $Silent) {
            Write-Host "  Could not read system events (possibly requires running as Administrator)" -ForegroundColor $Colors.Warning
        }
    }
}

# ============================================
# GENERATE FINAL REPORT
# ============================================

function Show-FinalReport {
    Write-Header "SYSTEM OPTIMIZATION REPORT" $Colors.Accent
    
    # System score
    $score = [math]::Max(0, $Script:TotalScore)
    $scoreColor = if ($score -ge 80) { $Colors.Success } elseif ($score -ge 60) { $Colors.Warning } else { $Colors.Error }
    
    Write-Host "`n*************************************************************" -ForegroundColor $scoreColor
    Write-Host "*   SYSTEM SCORE: $score/100".PadRight(60) "*" -ForegroundColor White
    Write-Host "*************************************************************" -ForegroundColor $scoreColor
    
    $statusText = switch ($score) {
        {$_ -ge 80} { "Status: OPTIMAL - Your system is well optimized" }
        {$_ -ge 60} { "Status: REGULAR - There are areas for improvement" }
        default     { "Status: NEEDS OPTIMIZATION - Actions recommended" }
    }
    Write-Host "  $statusText`n" -ForegroundColor $scoreColor
    
    # Recommendations
    if ($Script:AnalysisResults.Recommendations.Count -gt 0) {
        Write-Header "PRIORITIZED RECOMMENDATIONS" $Colors.Warning
        
        $grouped = $Script:AnalysisResults.Recommendations | Group-Object Priority
        
        foreach ($group in ($grouped | Sort-Object { 
            switch ($_.Name) {
                "High"   { 1 }
                "Medium" { 2 }
                "Low"    { 3 }
            }
        })) {
            $priorityColor = switch ($group.Name) {
                "High"   { $Colors.Error }
                "Medium" { $Colors.Warning }
                "Low"    { $Colors.Info }
            }
            
            $priorityText = switch ($group.Name) {
                "High"   { "HIGH PRIORITY" }
                "Medium" { "MEDIUM PRIORITY" }
                "Low"    { "LOW PRIORITY" }
            }
            
            Write-Host "`n[$priorityText]" -ForegroundColor $priorityColor
            Write-Host "".PadRight(60, "=") -ForegroundColor $Colors.Border
            
            $counter = 1
            foreach ($rec in $group.Group) {
                Write-Host "  $counter. $($rec.Description)" -ForegroundColor White
                if ($rec.Impact) {
                    Write-Host "     -> Impact: $($rec.Impact)" -ForegroundColor $Colors.Success
                }
                $counter++
            }
        }
    } else {
        Write-Host "`n* No significant issues found. Your system is optimized!" -ForegroundColor $Colors.Success
    }
    
    # Summary
    Write-Header "QUICK SUMMARY" $Colors.Info
    Write-Host "  - Disk: $(($Script:AnalysisResults.Disk.Drives | Measure-Object).Count) drives analyzed" -ForegroundColor $Colors.Info
    Write-Host "  - Memory: $(Format-Bytes $Script:AnalysisResults.Memory.Used) / $(Format-Bytes $Script:AnalysisResults.Memory.Total)" -ForegroundColor $Colors.Info
    Write-Host "  - Startup programs: $($Script:AnalysisResults.Startup.Count)" -ForegroundColor $Colors.Info
    Write-Host "  - Running services: $($Script:AnalysisResults.Services.TotalRunning)" -ForegroundColor $Colors.Info
    Write-Host "  - Temporary files: $(Format-Bytes $Script:AnalysisResults.TotalTempSize)" -ForegroundColor $Colors.Info
    Write-Host "  - Pending updates: $($Script:AnalysisResults.Updates.PendingCount)" -ForegroundColor $Colors.Info
}

# ============================================
# EXPORT RESULTS
# ============================================

function Export-Results {
    param([string]$Format)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "SystemAnalysis_$timestamp"
    
    switch ($Format) {
        "JSON" {
            $exportPath = "$filename.json"
            $Script:AnalysisResults | ConvertTo-Json -Depth 10 | Out-File $exportPath -Encoding UTF8
            Write-Host "`n* Report exported to: $exportPath" -ForegroundColor $Colors.Success
        }
        "HTML" {
            $exportPath = "$filename.html"
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Analysis Report</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 40px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #569cd6; border-bottom: 2px solid #569cd6; padding-bottom: 10px; }
        h2 { color: #ce9178; margin-top: 30px; }
        .score { font-size: 48px; text-align: center; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .score-good { background: #1e4620; color: #4ec9b0; }
        .score-warn { background: #5c4e1e; color: #dcdcaa; }
        .score-bad { background: #5c1e1e; color: #f48771; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border: 1px solid #3c3c3c; }
        th { background: #252526; color: #569cd6; }
        tr:nth-child(even) { background: #252526; }
        .high { color: #f48771; font-weight: bold; }
        .medium { color: #dcdcaa; }
        .low { color: #6a9955; }
    </style>
</head>
<body>
    <h1>System Optimization Report</h1>
    <p>Generated: $($Script:AnalysisResults.Timestamp)</p>
    
    <div class="score $(if ($Script:TotalScore -ge 80) { 'score-good' } elseif ($Script:TotalScore -ge 60) { 'score-warn' } else { 'score-bad' })">
        System Score: $Script:TotalScore/100
    </div>
    
    <h2>System Information</h2>
    <table>
        <tr><th>Property</th><th>Value</th></tr>
        <tr><td>Computer Name</td><td>$($Script:AnalysisResults.System.ComputerName)</td></tr>
        <tr><td>Operating System</td><td>$($Script:AnalysisResults.System.OS)</td></tr>
        <tr><td>Processor</td><td>$($Script:AnalysisResults.System.Processor)</td></tr>
        <tr><td>Total Memory</td><td>$($Script:AnalysisResults.System.TotalMemoryGB) GB</td></tr>
    </table>
    
    <h2>Disk Usage</h2>
    <table>
        <tr><th>Drive</th><th>Total</th><th>Free</th><th>Used %</th></tr>
"@

            foreach ($drive in $Script:AnalysisResults.Disk.Drives) {
                $htmlContent += "<tr><td>$($drive.Drive)</td><td>$(Format-Bytes $drive.Size)</td><td>$(Format-Bytes $drive.Free)</td><td>$($drive.PercentFree)%</td></tr>`n"
            }

            $htmlContent += @"
    </table>
    
    <h2>Recommendations</h2>
    <table>
        <tr><th>Priority</th><th>Category</th><th>Description</th><th>Impact</th></tr>
"@

            foreach ($rec in $Script:AnalysisResults.Recommendations) {
                $priorityClass = $rec.Priority.ToLower()
                $htmlContent += "<tr class='$priorityClass'><td>$($rec.Priority)</td><td>$($rec.Category)</td><td>$($rec.Description)</td><td>$($rec.Impact)</td></tr>`n"
            }

            $htmlContent += @"
    </table>
</body>
</html>
"@

            $htmlContent | Out-File $exportPath -Encoding UTF8
            Write-Host "`n* Report exported to: $exportPath" -ForegroundColor $Colors.Success
        }
    }
}

# ============================================
# MAIN FUNCTION
# ============================================

function Start-SystemAnalysis {
    $startTime = Get-Date
    
    if (-not $Silent) {
        Clear-Host
        Write-Host @"
=============================================================
                                                            
          SYSTEM OPTIMIZER ANALYZER CLI v1.0               
                                                            
  Analyzing your system to identify improvement areas...    
                                                            
=============================================================
"@ -ForegroundColor $Colors.Accent
        
        Write-Host "`nStarting analysis..." -ForegroundColor $Colors.Info
        if (-not (Test-IsAdmin)) {
            Write-Host "* NOTE: Running as Administrator will provide more detailed information" -ForegroundColor $Colors.Warning
        }
    }
    
    # Execute analysis
    Get-SystemInfo
    Get-DiskAnalysis
    Get-MemoryAnalysis
    Get-TopProcesses
    Get-StartupAnalysis
    Get-ServicesAnalysis
    Get-TempFilesAnalysis
    Get-WindowsUpdateAnalysis
    Get-SystemEventsAnalysis
    
    # Show final report
    if (-not $Silent) {
        Show-FinalReport
        
        $duration = (Get-Date) - $startTime
        Write-Host "`nAnalysis completed in $($duration.Seconds) seconds" -ForegroundColor $Colors.Border
    }
    
    # Export if requested
    if ($Export) {
        Export-Results -Format $Export
    }
}

# Run analysis
Start-SystemAnalysis