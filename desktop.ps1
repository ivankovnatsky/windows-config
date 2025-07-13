# Desktop Setup Script
# Creates desktop utility scripts and automatically manages state

$stateFile = Join-Path $PSScriptRoot "desktop-state.json"
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Define what files this script should create
$desiredFiles = @(
    (Join-Path $desktopPath "reboot.bat"),
    (Join-Path $desktopPath "poweroff.bat"),
    (Join-Path $desktopPath "sleep.bat")
)

# Function to read state
function Get-DesktopState {
    if (Test-Path $stateFile) {
        try {
            return Get-Content $stateFile -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Invalid state file, creating new one"
            return @{ createdFiles = @() }
        }
    } else {
        return @{ createdFiles = @() }
    }
}

# Function to save state
function Save-DesktopState($state) {
    $state | ConvertTo-Json -Depth 3 | Set-Content $stateFile
}

# Function to add file to state
function Add-FileToState($filePath) {
    $state = Get-DesktopState
    if ($state.createdFiles -notcontains $filePath) {
        $state.createdFiles += $filePath
        Save-DesktopState $state
        Write-Host "Tracked file: $filePath" -ForegroundColor Cyan
    }
}

# Function to clean tracked files
function Remove-TrackedFiles {
    $state = Get-DesktopState
    $removedCount = 0
    
    foreach ($filePath in $state.createdFiles) {
        if (Test-Path $filePath) {
            try {
                Remove-Item $filePath -Force
                Write-Host "Removed: $filePath" -ForegroundColor Red
                $removedCount++
            } catch {
                Write-Warning "Failed to remove: $filePath - $($_.Exception.Message)"
            }
        } else {
            Write-Host "Already gone: $filePath" -ForegroundColor Gray
        }
    }
    
    # Clear state
    Save-DesktopState @{ createdFiles = @() }
    Write-Host "Cleaned $removedCount files and cleared state" -ForegroundColor Green
}

# Function to list tracked files
function Show-TrackedFiles {
    $state = Get-DesktopState
    if ($state.createdFiles.Count -eq 0) {
        Write-Host "No tracked files" -ForegroundColor Yellow
    } else {
        Write-Host "Tracked desktop files:" -ForegroundColor Cyan
        foreach ($filePath in $state.createdFiles) {
            $exists = Test-Path $filePath
            $status = if ($exists) { "[EXISTS]" } else { "[MISSING]" }
            $color = if ($exists) { "Green" } else { "Red" }
            Write-Host "  $status $filePath" -ForegroundColor $color
        }
    }
}

# Clean up files that are no longer desired
function Remove-UnwantedFiles {
    $state = Get-DesktopState
    $removedCount = 0
    
    foreach ($trackedFile in $state.createdFiles) {
        if ($desiredFiles -notcontains $trackedFile) {
            if (Test-Path $trackedFile) {
                try {
                    Remove-Item $trackedFile -Force
                    Write-Host "Removed unwanted file: $trackedFile" -ForegroundColor Red
                    $removedCount++
                } catch {
                    Write-Warning "Failed to remove: $trackedFile - $($_.Exception.Message)"
                }
            }
        }
    }
    
    # Update state to only include desired files that still exist
    $newState = @{ createdFiles = @() }
    foreach ($desiredFile in $desiredFiles) {
        if (Test-Path $desiredFile) {
            $newState.createdFiles += $desiredFile
        }
    }
    Save-DesktopState $newState
    
    if ($removedCount -gt 0) {
        Write-Host "Cleaned up $removedCount unwanted files" -ForegroundColor Green
    }
}

# First, clean up any unwanted files
Remove-UnwantedFiles

# Create each desired file
foreach ($filePath in $desiredFiles) {
    $fileName = Split-Path $filePath -Leaf
    
    # Skip if file already exists
    if (Test-Path $filePath) {
        Write-Host "$fileName already exists, skipping" -ForegroundColor Yellow
        continue
    }
    
    try {
        switch ($fileName) {
            "reboot.bat" {
                $content = @'
@echo off
echo Rebooting system now...
shutdown /r /t 0 /f
'@
                $content | Set-Content -Path $filePath -Encoding ASCII
                Write-Host "Created reboot.bat - Double-click to reboot system" -ForegroundColor Green
            }
            "poweroff.bat" {
                $content = @'
@echo off
echo Shutting down system now...
shutdown /s /t 0 /f
'@
                $content | Set-Content -Path $filePath -Encoding ASCII
                Write-Host "Created poweroff.bat - Double-click to shutdown system" -ForegroundColor Green
            }
            "sleep.bat" {
                $content = @'
@echo off
echo Putting system to sleep...
rundll32.exe powrprof.dll,SetSuspendState 0,1,0
'@
                $content | Set-Content -Path $filePath -Encoding ASCII
                Write-Host "Created sleep.bat - Double-click to put system to sleep" -ForegroundColor Green
            }
            

        }
        
        # Track the created file
        Add-FileToState $filePath
        
    } catch {
        Write-Error "Failed to create $fileName`: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Desktop utilities are ready! Script automatically manages file state." -ForegroundColor Green