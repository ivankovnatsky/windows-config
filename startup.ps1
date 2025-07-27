# Startup Setup Script
# Creates startup shortcuts and automatically manages state

$stateFile = Join-Path $env:USERPROFILE ".config\windows-config\startup\state.json"
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

# Define desired startup programs (executable paths)
$desiredStartupPrograms = @(
)

# Define user startup items to disable (only user-level items, not system)
$disableStartupItems = @(
    "Microsoft Edge",
    "Microsoft OneDrive"
)

# Define existing startup items to enable (items already in registry but disabled)
$enableStartupItems = @(
    "Terminal"
)

# Generate the list of shortcut files to create
$desiredStartupFiles = @()
foreach ($exePath in $desiredStartupPrograms) {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
    $shortcutPath = Join-Path $startupPath "$exeName.lnk"
    $desiredStartupFiles += $shortcutPath
}

# Function to read state
function Get-StartupState {
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
function Save-StartupState($state) {
    $state | ConvertTo-Json -Depth 3 | Set-Content $stateFile
}

# Function to add file to state
function Add-FileToState($filePath) {
    $state = Get-StartupState
    if ($state.createdFiles -notcontains $filePath) {
        $state.createdFiles += $filePath
        Save-StartupState $state
        Write-Host "Tracked file: $filePath" -ForegroundColor Cyan
    }
}

# Function to clean tracked files
function Remove-TrackedFiles {
    $state = Get-StartupState
    $removedCount = 0
    
    foreach ($filePath in $state.createdFiles) {
        if (Test-Path $filePath) {
            try {
                Remove-Item $filePath -Force
                Write-Host "Removed: $filePath" -ForegroundColor Red
                $removedCount++
            } catch {
                Write-Warning "Failed to remove: $filePath"
            }
        }
    }
    
    if ($removedCount -gt 0) {
        Write-Host "Cleaned up $removedCount tracked files" -ForegroundColor Green
    }
}

# Function to enable existing disabled startup items we want
function Enable-DesiredStartupItems {
    Write-Host "Enabling desired startup items..." -ForegroundColor Green
    
    # Items to enable in StartupApproved registry
    $itemsToEnable = @()
    foreach ($item in $enableStartupItems) {
        $itemsToEnable += @{ Name = "$item*"; Description = $item }
    }
    
    # StartupApproved registry path (user-level only)
    $startupApprovedPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    )
    
    foreach ($regPath in $startupApprovedPaths) {
        if (Test-Path $regPath) {
            $regItems = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($regItems) {
                foreach ($itemToEnable in $itemsToEnable) {
                    # Find matching entries using wildcard
                    $matchingEntries = $regItems.PSObject.Properties | Where-Object { 
                        $_.Name -like $itemToEnable.Name -and $_.Name -notlike 'PS*' 
                    }
                    
                    foreach ($entry in $matchingEntries) {
                        if ($entry.Value) {
                            try {
                                $currentValue = $entry.Value
                                # Check if already enabled (first byte = 2 or 6)
                                if ($currentValue[0] -eq 2 -or $currentValue[0] -eq 6) {
                                    Write-Host "Already enabled: $($itemToEnable.Description)" -ForegroundColor Yellow
                                } elseif ($currentValue[0] -eq 3) {
                                    # Enable by setting first byte to 2 (keep rest of bytes intact)
                                    $enabledValue = $currentValue.Clone()
                                    $enabledValue[0] = 2
                                    Set-ItemProperty -Path $regPath -Name $entry.Name -Value $enabledValue -ErrorAction Stop
                                    Write-Host "Enabled: $($itemToEnable.Description)" -ForegroundColor Green
                                } else {
                                    Write-Host "Unknown status for $($itemToEnable.Description) (byte: $($currentValue[0]))" -ForegroundColor Yellow
                                }
                            } catch {
                                Write-Warning "Failed to enable $($itemToEnable.Description): $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }
    }
}

# Function to disable unwanted user startup items
function Disable-UnwantedStartupItems {
    Write-Host "Disabling unwanted user startup items..." -ForegroundColor Cyan
    
    # Items to disable in StartupApproved registry (only user-level items)
    $itemsToDisable = @(
        @{ Name = 'MicrosoftEdgeAutoLaunch*'; Description = 'Microsoft Edge Auto-launch' },
        @{ Name = 'OneDrive*'; Description = 'Microsoft OneDrive' },
        @{ Name = 'Mozilla-Firefox*'; Description = 'Mozilla Firefox' },
        @{ Name = 'Mobile*'; Description = 'Mobile devices' }
    )
    
    # StartupApproved registry path (user-level only, no admin required)
    $startupApprovedPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    )
    
    foreach ($regPath in $startupApprovedPaths) {
        if (Test-Path $regPath) {
            try {
                $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($items) {
                    foreach ($itemToDisable in $itemsToDisable) {
                        $matchingEntries = $items.PSObject.Properties | Where-Object { $_.Name -like $itemToDisable.Name }
                        foreach ($entry in $matchingEntries) {
                            try {
                                $currentValue = $entry.Value
                                # Check if already disabled (first byte = 3)
                                if ($currentValue[0] -eq 3) {
                                    Write-Host "Already disabled: $($itemToDisable.Description)" -ForegroundColor Yellow
                                } elseif ($currentValue[0] -eq 2 -or $currentValue[0] -eq 6) {
                                    # Disable by setting first byte to 3 (keep rest of bytes intact)
                                    $disabledValue = $currentValue.Clone()
                                    $disabledValue[0] = 3
                                    Set-ItemProperty -Path $regPath -Name $entry.Name -Value $disabledValue -ErrorAction Stop
                                    Write-Host "Disabled: $($itemToDisable.Description)" -ForegroundColor Red
                                } else {
                                    Write-Host "Unknown status for $($itemToDisable.Description) (byte: $($currentValue[0]))" -ForegroundColor Yellow
                                }
                            } catch {
                                Write-Warning "Failed to disable $($itemToDisable.Description): $($_.Exception.Message)"
                            }
                        }
                    }
                }
            } catch {
                # Registry path not accessible, skip
            }
        }
    }
    
    Write-Host ""
}

# Function to clean unwanted files
function Remove-UnwantedFiles {
    $state = Get-StartupState
    $removedCount = 0
    
    foreach ($filePath in $state.createdFiles) {
        # Check if this file is still in our desired list
        if ($desiredStartupFiles -notcontains $filePath) {
            if (Test-Path $filePath) {
                try {
                    Remove-Item $filePath -Force
                    Write-Host "Removed unwanted file: $filePath" -ForegroundColor Red
                    $removedCount++
                } catch {
                    Write-Warning "Failed to remove: $filePath"
                }
            }
        }
    }
    
    # Update state to only include desired files that still exist
    $newState = @{ createdFiles = @() }
    foreach ($desiredFile in $desiredStartupFiles) {
        if (Test-Path $desiredFile) {
            $newState.createdFiles += $desiredFile
        }
    }
    Save-StartupState $newState
    
    if ($removedCount -gt 0) {
        Write-Host "Cleaned up $removedCount unwanted files" -ForegroundColor Green
    }
}

# First, enable desired startup items that are already in registry but disabled
Enable-DesiredStartupItems

# Then, disable unwanted system startup items
Disable-UnwantedStartupItems

# Then, clean up any unwanted files
Remove-UnwantedFiles

# Create each desired startup file
foreach ($filePath in $desiredStartupFiles) {
    $fileName = Split-Path $filePath -Leaf
    
    # Skip if file already exists
    if (Test-Path $filePath) {
        Write-Host "$fileName already exists, skipping" -ForegroundColor Yellow
        continue
    }
    
    try {
        # Find the corresponding exe path for this shortcut
        $exeName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $targetPath = $desiredStartupPrograms | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) -eq $exeName }
        
        if ($targetPath -and (Test-Path $targetPath)) {
            # Create the shortcut
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($filePath)
            $Shortcut.TargetPath = $targetPath
            $Shortcut.Save()
            Write-Host "Created $fileName - $(Split-Path $targetPath -Leaf) will start with Windows" -ForegroundColor Green
        } else {
            Write-Host "Executable not found for $fileName, skipping" -ForegroundColor Yellow
            continue
        }
        
        # Track the created file
        Add-FileToState $filePath
        
    } catch {
        Write-Error "Failed to create $fileName`: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Startup configuration completed!" -ForegroundColor Green

# Function to show current startup status
function Show-StartupStatus {
    Write-Host ""
    Write-Host "Current Startup Status:" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    # Check StartupApproved registry for status
    $startupApprovedPaths = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Type = 'User' },
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Type = 'System' }
    )
    
    foreach ($regInfo in $startupApprovedPaths) {
        if (Test-Path $regInfo.Path) {
            try {
                $items = Get-ItemProperty -Path $regInfo.Path -ErrorAction SilentlyContinue
                if ($items) {
                    Write-Host ""
                    Write-Host "$($regInfo.Type) Startup Items:" -ForegroundColor Yellow
                    
                    $items.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | Sort-Object Name | ForEach-Object {
                        $bytes = $_.Value
                        # Windows uses different byte values for different states
                        if ($bytes[0] -eq 2 -or $bytes[0] -eq 6) { 
                            $status = "Enabled"
                            $statusColor = "Green"
                            $icon = "[+]"
                        } elseif ($bytes[0] -eq 3) { 
                            $status = "Disabled"
                            $statusColor = "Red"
                            $icon = "[-]"
                        } else { 
                            $status = "Unknown($($bytes[0]))"
                            $statusColor = "Yellow"
                            $icon = "[?]"
                        }
                        
                        # Clean up the name for display
                        $displayName = $_.Name
                        if ($displayName -like "MicrosoftEdgeAutoLaunch*") {
                            $displayName = "Microsoft Edge Auto-launch"
                        }
                        
                        Write-Host "  $icon $displayName`: $status" -ForegroundColor $statusColor
                    }
                }
            } catch {
                Write-Warning "Could not read $($regInfo.Type) startup items"
            }
        }
    }
    
    Write-Host ""
}

# Show current status
Show-StartupStatus
