# Syncthing Startup Script
# Runs Syncthing with proper config path, log management, and startup shortcut

param(
    [switch]$Install,    # Install startup shortcut
    [switch]$Uninstall,  # Remove startup shortcut
    [switch]$Start       # Start Syncthing (default if no params)
)

$syncthingExe = "$env:USERPROFILE\scoop\apps\syncthing\current\syncthing.exe"
$configPath = "$env:USERPROFILE\scoop\apps\syncthing\current\config"
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupPath "Syncthing.lnk"

# Function to install startup shortcut
function Install-StartupShortcut {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Start"
        $Shortcut.WorkingDirectory = Split-Path $PSCommandPath
        $Shortcut.Description = "Syncthing with proper config path"
        $Shortcut.Save()
        Write-Host "Startup shortcut created: $shortcutPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to create startup shortcut: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to remove startup shortcut
function Remove-StartupShortcut {
    if (Test-Path $shortcutPath) {
        try {
            Remove-Item $shortcutPath -Force
            Write-Host "Startup shortcut removed: $shortcutPath" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Failed to remove startup shortcut: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Startup shortcut not found: $shortcutPath" -ForegroundColor Yellow
        return $true
    }
}

# Main script logic based on parameters
if ($Install) {
    Write-Host "Installing Syncthing startup shortcut..." -ForegroundColor Cyan
    $success = Install-StartupShortcut
    if ($success) {
        Write-Host "Syncthing will now start automatically on login" -ForegroundColor Green
    }
    if ($success) { exit 0 } else { exit 1 }
}
elseif ($Uninstall) {
    Write-Host "Removing Syncthing startup shortcut..." -ForegroundColor Cyan
    $success = Remove-StartupShortcut
    if ($success) { exit 0 } else { exit 1 }
}
else {
    # Default: Start Syncthing (either -Start parameter or no parameters)
    
    # Check if Syncthing is already running
    $existingProcess = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
    if ($existingProcess) {
        Write-Host "Syncthing is already running (PID: $($existingProcess.Id))" -ForegroundColor Green
        exit 0
    }
    
    # Verify Syncthing executable exists
    if (-not (Test-Path $syncthingExe)) {
        Write-Host "Syncthing executable not found: $syncthingExe" -ForegroundColor Red
        Write-Host "Make sure Syncthing is installed via Scoop" -ForegroundColor Yellow
        exit 1
    }
    
    # Verify config directory exists
    if (-not (Test-Path $configPath)) {
        Write-Host "Config directory not found: $configPath" -ForegroundColor Red
        Write-Host "Run Syncthing manually first to create initial config" -ForegroundColor Yellow
        exit 1
    }
    
    # Start Syncthing with proper config path
    Write-Host "Starting Syncthing..." -ForegroundColor Green
    Write-Host "Config path: $configPath" -ForegroundColor Cyan
    
    try {
        # Start Syncthing in background with specified config path
        $process = Start-Process -FilePath $syncthingExe `
            -ArgumentList "-home `"$configPath`" -no-browser" `
            -WindowStyle Hidden `
            -PassThru
        
        # Wait a moment to check if it started successfully
        Start-Sleep -Seconds 2
        
        if ($process.HasExited) {
            Write-Host "Syncthing failed to start. Check Syncthing logs for details." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Syncthing started successfully (PID: $($process.Id))" -ForegroundColor Green
            Write-Host "Web UI: http://localhost:8384" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Failed to start Syncthing: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
