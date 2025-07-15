# Temperature Monitor for Windows
# Monitors CPU, GPU, and system temperatures in console
# Records maximum temperatures and saves them to a log file
# Runs continuously every 2 seconds by default

# Configuration
$RefreshInterval = 2  # Refresh every 2 seconds
$Fahrenheit = $false  # Use Celsius by default
$LogFile = "$env:TEMP\temp-monitor-max.json"  # Log file for max temps

# Function to convert Kelvin to Celsius
function ConvertFrom-Kelvin {
    param([double]$Kelvin)
    return [math]::Round($Kelvin - 273.15, 1)
}

# Function to convert Celsius to Fahrenheit
function ConvertTo-Fahrenheit {
    param([double]$Celsius)
    return [math]::Round(($Celsius * 9/5) + 32, 1)
}

# Function to get CPU temperature
function Get-CPUTemperature {
    try {
        # Try WMI thermal zone first
        $thermalZones = Get-WmiObject -Namespace "root/WMI" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
        if ($thermalZones) {
            $temps = @()
            foreach ($zone in $thermalZones) {
                $tempC = ConvertFrom-Kelvin $zone.CurrentTemperature
                $temps += $tempC
            }
            return $temps | Measure-Object -Average | Select-Object -ExpandProperty Average
        }
        
        # Try OpenHardwareMonitor WMI if available
        $ohm = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class "Sensor" -Filter "SensorType='Temperature' AND Name LIKE '%CPU%'" -ErrorAction SilentlyContinue
        if ($ohm) {
            return ($ohm | Measure-Object -Property Value -Average).Average
        }
        
        return $null
    } catch {
        return $null
    }
}

# Function to get GPU temperature
function Get-GPUTemperature {
    try {
        # Try NVIDIA-SMI first
        $nvidiaSmi = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $result = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($result -and $result -match '^\d+$') {
                return [int]$result
            }
        }
        
        # Try OpenHardwareMonitor WMI
        $ohm = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class "Sensor" -Filter "SensorType='Temperature' AND (Name LIKE '%GPU%' OR Name LIKE '%Graphics%')" -ErrorAction SilentlyContinue
        if ($ohm) {
            return ($ohm | Measure-Object -Property Value -Average).Average
        }
        
        return $null
    } catch {
        return $null
    }
}

# Global variable for max temperatures
$script:maxTemps = @{}

# Function to load max temperatures from log file
function Import-MaxTemperatures {
    if (Test-Path $LogFile) {
        try {
            $content = Get-Content $LogFile -Raw | ConvertFrom-Json
            $script:maxTemps = @{}
            $content.PSObject.Properties | ForEach-Object {
                $script:maxTemps[$_.Name] = $_.Value
            }
            Write-Host "Loaded existing max temperatures from: $LogFile" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not parse existing log file. Starting with empty data." -ForegroundColor Yellow
            $script:maxTemps = @{}
        }
    } else {
        $script:maxTemps = @{}
    }
}

# Function to save max temperatures to log file
function Export-MaxTemperatures {
    try {
        $script:maxTemps | ConvertTo-Json -Depth 3 | Set-Content $LogFile
    } catch {
        Write-Host "Warning: Could not save max temperatures to log file." -ForegroundColor Yellow
    }
}

# Function to update max temperatures
function Update-MaxTemperatures {
    param(
        [hashtable]$CurrentTemps
    )
    
    $updated = $false
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    foreach ($sensor in $CurrentTemps.Keys) {
        $currentTemp = $CurrentTemps[$sensor]
        if ($currentTemp -ne $null) {
            if (-not $script:maxTemps.ContainsKey($sensor)) {
                $script:maxTemps[$sensor] = @{
                    MaxTemp = $currentTemp
                    Timestamp = $timestamp
                    Sensor = $sensor
                }
                Write-Host "New sensor: $sensor at ${currentTemp}C" -ForegroundColor Cyan
                $updated = $true
            } elseif ($currentTemp -gt $script:maxTemps[$sensor].MaxTemp) {
                $oldMax = $script:maxTemps[$sensor].MaxTemp
                $script:maxTemps[$sensor].MaxTemp = $currentTemp
                $script:maxTemps[$sensor].Timestamp = $timestamp
                Write-Host "New max for ${sensor}: ${currentTemp}C (was ${oldMax}C)" -ForegroundColor Yellow
                $updated = $true
            }
        }
    }
    
    if ($updated) {
        Export-MaxTemperatures
    }
    
    return $updated
}

# Function to get system info
function Get-SystemInfo {
    $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
    $gpu = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Microsoft*" } | Select-Object -First 1
    
    return @{
        CPU = $cpu.Name
        GPU = if ($gpu) { $gpu.Name } else { "Not detected" }
    }
}

# Function to display temperatures
function Show-Temperatures {
    $sysInfo = Get-SystemInfo
    $cpuTemp = Get-CPUTemperature
    $gpuTemp = Get-GPUTemperature
    
    # Collect current temperatures
    $currentTemps = @{}
    if ($cpuTemp) { $currentTemps["CPU"] = $cpuTemp }
    if ($gpuTemp) { $currentTemps["GPU"] = $gpuTemp }
    
    # Update max temperatures
    $null = Update-MaxTemperatures $currentTemps
    
    Write-Host "Every ${RefreshInterval}s: Temperature Monitor" -ForegroundColor Cyan
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "System Info:" -ForegroundColor Yellow
    Write-Host "  CPU: $($sysInfo.CPU)" -ForegroundColor White
    Write-Host "  GPU: $($sysInfo.GPU)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "CURRENT TEMPERATURES:" -ForegroundColor Yellow
    Write-Host ("-" * 50) -ForegroundColor Gray
    
    # CPU Temperature
    if ($cpuTemp) {
        $displayTemp = if ($Fahrenheit) { ConvertTo-Fahrenheit $cpuTemp } else { $cpuTemp }
        $unit = if ($Fahrenheit) { "F" } else { "C" }
        $color = if ($cpuTemp -gt 80) { "Red" } elseif ($cpuTemp -gt 70) { "Yellow" } else { "Green" }
        Write-Host "  CPU: $displayTemp$unit" -ForegroundColor $color
    } else {
        Write-Host "  CPU: Not available (WMI sensors not exposed)" -ForegroundColor Gray
    }
    
    # GPU Temperature
    if ($gpuTemp) {
        $displayTemp = if ($Fahrenheit) { ConvertTo-Fahrenheit $gpuTemp } else { $gpuTemp }
        $unit = if ($Fahrenheit) { "F" } else { "C" }
        $color = if ($gpuTemp -gt 85) { "Red" } elseif ($gpuTemp -gt 75) { "Yellow" } else { "Green" }
        Write-Host "  GPU: $displayTemp$unit" -ForegroundColor $color
    } else {
        Write-Host "  GPU: Not available" -ForegroundColor Gray
    }
    
    # Display maximum temperatures if any exist
    if ($script:maxTemps.Count -gt 0) {
        Write-Host ""
        Write-Host "MAXIMUM TEMPERATURES:" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host ("{0,-15} {1,-10} {2,-20}" -f "SENSOR", "MAX TEMP", "RECORDED AT") -ForegroundColor White
        Write-Host ("-" * 80) -ForegroundColor Gray
        
        # Sort by temperature (highest first)
        $sortedMaxTemps = $script:maxTemps.GetEnumerator() | Sort-Object { $_.Value.MaxTemp } -Descending
        
        foreach ($entry in $sortedMaxTemps) {
            $sensor = $entry.Key
            $data = $entry.Value
            $displayMaxTemp = if ($Fahrenheit) { ConvertTo-Fahrenheit $data.MaxTemp } else { $data.MaxTemp }
            $unit = if ($Fahrenheit) { "F" } else { "C" }
            
            $color = if ($data.MaxTemp -gt 85) { "Red" } elseif ($data.MaxTemp -gt 75) { "Yellow" } else { "Green" }
            Write-Host ("{0,-15} {1,8:F1}{2} {3,20}" -f $sensor, $displayMaxTemp, $unit, $data.Timestamp) -ForegroundColor $color
        }
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
    Write-Host "Max temperatures saved to: $LogFile" -ForegroundColor Gray
}

# Graceful exit handler
$script:exitRequested = $false

# Handle Ctrl+C gracefully
[Console]::TreatControlCAsInput = $false
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Host ""
    Write-Host "Monitoring stopped." -ForegroundColor Yellow
    Write-Host "Maximum temperatures saved to: $LogFile" -ForegroundColor Green
}

# Main execution
Write-Host "Starting temperature monitor..." -ForegroundColor Green
Write-Host "Note: CPU temps may not be available on modern systems (WMI limitations)" -ForegroundColor Yellow
Write-Host "Maximum temperatures will be saved to: $LogFile" -ForegroundColor Green
Write-Host ""

# Load existing max temperatures
Import-MaxTemperatures

# Main monitoring loop
try {
    while ($true) {
        Show-Temperatures
        Start-Sleep -Seconds $RefreshInterval
    }
} catch {
    Write-Host "\nMonitoring stopped." -ForegroundColor Yellow
}