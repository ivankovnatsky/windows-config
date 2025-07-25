param(
    [switch]$Force,
    [switch]$Help,
    [switch]$Diff
)

# Function to display help information
function Show-Help {
    Write-Host "Usage: .\dotfiles-sync.ps1 [-Force] [-Help] [-Diff]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Force      : Skip confirmation prompts for file removal" -ForegroundColor White
    Write-Host "  -Help       : Show this help message" -ForegroundColor White
    Write-Host "  -Diff       : Show what changes would be made without syncing" -ForegroundColor White
    Write-Host ""
    Write-Host "Description:" -ForegroundColor Cyan
    Write-Host "  Syncs configuration files from dotfiles/ directory to your home directory" -ForegroundColor White
    Write-Host "  Maintains state in dotfiles-state.json to track deployments" -ForegroundColor White
    Write-Host "  Use -Diff to preview changes before running actual sync" -ForegroundColor White
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Define paths
$dotfilesDir = Join-Path $PSScriptRoot "dotfiles"
$stateFile = Join-Path $PSScriptRoot "dotfiles-state.json"

# Files to preserve in destination (won't be overwritten or deleted)
$preserveFiles = @(
    "AppData/Local/nvim/lazy-lock.json",
    "AppData/Local/nvim/lazyvim.json"
)

# Function to read state from JSON file
function Get-StateFromJson($filePath) {
    if (Test-Path $filePath) {
        try {
            $state = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        } catch {
            Write-Error "Failed to read or parse state file: $_"
            exit 1
        }
    } else {
        Write-Host "State file not found. Creating new state." -ForegroundColor Yellow
        $state = @{
            lastUpdated = $null
            deployedFiles = @()
        }
    }

    # Ensure required properties exist
    if (-not ($state.PSObject.Properties.Name -contains 'deployedFiles') -or $null -eq $state.deployedFiles) {
        $state | Add-Member -NotePropertyName 'deployedFiles' -NotePropertyValue @() -Force
    }

    return $state
}

# Function to update state file
function Update-StateFile($state) {
    if ($state.PSObject.Properties.Name -contains 'lastUpdated') {
        $state.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } else {
        $state | Add-Member -NotePropertyName 'lastUpdated' -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
    }
    $state | ConvertTo-Json -Depth 4 | Set-Content $stateFile
}

# Function to check if a file should be preserved
function Test-PreservedFile($relativePath) {
    return $preserveFiles | Where-Object { $relativePath -eq $_ }
}

# Function to sync preserved files from destination back to source
function Sync-PreservedFiles {
    foreach ($preservedFile in $preserveFiles) {
        $sourcePath = Join-Path $dotfilesDir $preservedFile
        $targetPath = Join-Path $env:USERPROFILE $preservedFile
        
        if (Test-Path $targetPath) {
            $sourceDir = Split-Path $sourcePath -Parent
            if (-not (Test-Path $sourceDir)) {
                New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
            }
            
            if (Test-Path $sourcePath) {
                # Compare file hashes
                $targetHash = (Get-FileHash $targetPath).Hash
                $sourceHash = (Get-FileHash $sourcePath).Hash
                
                if ($targetHash -ne $sourceHash) {
                    Copy-Item -Path $targetPath -Destination $sourcePath -Force
                    Write-Host "Updated preserved file from destination: $preservedFile" -ForegroundColor Yellow
                }
            } else {
                Copy-Item -Path $targetPath -Destination $sourcePath -Force
                Write-Host "Copied new preserved file from destination: $preservedFile" -ForegroundColor Green
            }
        }
    }
}

# Function to process file content (no template expansion needed anymore)
function Process-FileContent($content) {
    # Just return content as-is since we removed all template variables
    return $content
}

# Function to deploy a file
function Deploy-File($sourceFile, $targetFile) {
    try {
        # Create target directory if it doesn't exist
        $targetDir = Split-Path $targetFile -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # Read source content
        $content = Get-Content -Path $sourceFile -Raw -Encoding UTF8
        
        # Process content (no template expansion needed)
        $content = Process-FileContent $content
        
        # Write to target with UTF8 encoding
        $content | Out-File -FilePath $targetFile -Encoding utf8 -NoNewline
        
        Write-Host "Deployed: $sourceFile -> $targetFile" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to deploy $sourceFile -> $targetFile`: $_"
        return $false
    }
}

# Function to remove a deployed file
function Remove-DeployedFile($targetFile) {
    try {
        if (Test-Path $targetFile) {
            Remove-Item -Path $targetFile -Force
            Write-Host "Removed: $targetFile" -ForegroundColor Yellow
        }
        return $true
    } catch {
        Write-Error "Failed to remove $targetFile`: $_"
        return $false
    }
}

# Function to check if delta is available
function Test-DeltaAvailable {
    try {
        $null = Get-Command delta -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to show diff for a single file
function Show-FileDiff($sourceFile, $targetFile, $relativePath) {
    # Read and process source content
    $sourceContent = Get-Content -Path $sourceFile -Raw -Encoding UTF8
    $processedContent = Process-FileContent $sourceContent
    
    if (-not (Test-Path $targetFile)) {
        Write-Host "NEW FILE: $relativePath" -ForegroundColor Green
        Write-Host "Would be created with content from: $sourceFile" -ForegroundColor Gray
        return
    }
    
    # Read target content
    $targetContent = Get-Content -Path $targetFile -Raw -Encoding UTF8
    
    # Compare content
    if ($processedContent -eq $targetContent) {
        Write-Host "UNCHANGED: $relativePath" -ForegroundColor Gray
        return
    }
    
    Write-Host "MODIFIED: $relativePath" -ForegroundColor Yellow
    
    # Create temp files for comparison
    $tempSource = [System.IO.Path]::GetTempFileName()
    $tempTarget = [System.IO.Path]::GetTempFileName()
    
    try {
        $processedContent | Out-File -FilePath $tempSource -Encoding UTF8 -NoNewline
        $targetContent | Out-File -FilePath $tempTarget -Encoding UTF8 -NoNewline
        
        if (Test-DeltaAvailable) {
            Write-Host "Showing diff with delta:" -ForegroundColor Cyan
            & delta $tempTarget $tempSource --file-decoration-style="bold yellow box" --file-style="bold yellow" --line-numbers
        } else {
            Write-Host "Showing basic diff (install delta for better output):" -ForegroundColor Cyan
            $diff = Compare-Object (Get-Content $tempTarget) (Get-Content $tempSource) -IncludeEqual
            foreach ($line in $diff) {
                switch ($line.SideIndicator) {
                    "<=" { Write-Host "- $($line.InputObject)" -ForegroundColor Red }
                    "=>" { Write-Host "+ $($line.InputObject)" -ForegroundColor Green }
                    "==" { Write-Host "  $($line.InputObject)" -ForegroundColor Gray }
                }
            }
        }
    } finally {
        Remove-Item $tempSource -Force -ErrorAction SilentlyContinue
        Remove-Item $tempTarget -Force -ErrorAction SilentlyContinue
    }
}

# Function to run diff mode
function Invoke-DiffMode {
    Write-Host "Showing changes that would be made:" -ForegroundColor Cyan
    Write-Host ""
    
    $state = Get-StateFromJson $stateFile
    
    # Get all files in dotfiles directory
    $sourceFiles = Get-ChildItem -Path $dotfilesDir -Recurse -File
    $currentFiles = @()
    
    # Show diffs for each file
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($dotfilesDir.Length + 1)
        $targetFile = Join-Path $env:USERPROFILE $relativePath
        
        # Skip preserved files
        if (Test-PreservedFile $relativePath) {
            Write-Host "PRESERVED: $relativePath (managed separately)" -ForegroundColor Magenta
            continue
        }
        
        # Track current files
        $currentFiles += @{
            target = $targetFile
            relativePath = $relativePath
        }
        
        Show-FileDiff $sourceFile.FullName $targetFile $relativePath
        Write-Host ""
    }
    
    # Show files that would be removed
    $filesToRemove = $state.deployedFiles | Where-Object {
        $deployedTarget = $_.target
        $deployedRelativePath = $_.relativePath
        
        # Don't remove preserved files
        if (Test-PreservedFile $deployedRelativePath) {
            return $false
        }
        
        # Remove if no longer in current files
        -not ($currentFiles | Where-Object { $_.target -eq $deployedTarget })
    }
    
    if ($filesToRemove.Count -gt 0) {
        Write-Host "FILES TO BE REMOVED:" -ForegroundColor Red
        foreach ($file in $filesToRemove) {
            Write-Host "DELETE: $($file.relativePath)" -ForegroundColor Red
        }
    }
    
    Write-Host "Run without -Diff to apply these changes." -ForegroundColor Yellow
}

# Main script
try {
    if (-not (Test-Path $dotfilesDir)) {
        Write-Error "Dotfiles directory not found: $dotfilesDir"
        exit 1
    }

    # Run diff mode if requested
    if ($Diff) {
        Invoke-DiffMode
        exit 0
    }

    $state = Get-StateFromJson $stateFile
    
    Write-Host "Syncing dotfiles from: $dotfilesDir" -ForegroundColor Cyan
    
    # First, sync preserved files from destination back to source
    Sync-PreservedFiles
    
    # Get all files in dotfiles directory
    $sourceFiles = Get-ChildItem -Path $dotfilesDir -Recurse -File
    $currentFiles = @()
    
    # Deploy/update files
    foreach ($sourceFile in $sourceFiles) {
        # Calculate relative path from dotfiles directory
        $relativePath = $sourceFile.FullName.Substring($dotfilesDir.Length + 1)
        $targetFile = Join-Path $env:USERPROFILE $relativePath
        
        # Skip preserved files during deployment (they're handled separately)
        if (Test-PreservedFile $relativePath) {
            Write-Host "Skipped preserved file: $relativePath" -ForegroundColor Gray
            continue
        }
        
        # Track this file as current
        $currentFiles += @{
            source = $sourceFile.FullName
            target = $targetFile
            relativePath = $relativePath
        }
        
        # Check if file needs deployment
        $needsDeployment = $true
        $existingEntry = $state.deployedFiles | Where-Object { $_.target -eq $targetFile }
        
        if ($existingEntry -and (Test-Path $targetFile)) {
            # Compare file timestamps or force deployment
            $sourceDate = $sourceFile.LastWriteTime
            $targetDate = (Get-Item $targetFile).LastWriteTime
            
            if ($sourceDate -le $targetDate) {
                $needsDeployment = $false
                Write-Host "Up to date: $relativePath" -ForegroundColor Gray
            }
        }
        
        if ($needsDeployment) {
            $deployResult = Deploy-File $sourceFile.FullName $targetFile
            
            if ($deployResult) {
                # Update or add to state
                if ($existingEntry) {
                    $existingEntry.deployedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                } else {
                    $state.deployedFiles += @{
                        source = $sourceFile.FullName
                        target = $targetFile
                        relativePath = $relativePath
                        deployedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
            }
        }
    }
    
    # Find files to remove (deployed but no longer in source)
    # Exclude preserved files from removal
    $filesToRemove = $state.deployedFiles | Where-Object {
        $deployedTarget = $_.target
        $deployedRelativePath = $_.relativePath
        
        # Don't remove if it's a preserved file
        if (Test-PreservedFile $deployedRelativePath) {
            return $false
        }
        
        # Remove if no longer in current files
        -not ($currentFiles | Where-Object { $_.target -eq $deployedTarget })
    }
    
    if ($filesToRemove.Count -gt 0) {
        if (-not $Force) {
            Write-Host "The following files will be removed from your home directory:" -ForegroundColor Yellow
            foreach ($file in $filesToRemove) {
                Write-Host "  - $($file.relativePath)" -ForegroundColor Red
            }
            $confirmation = Read-Host "Do you want to continue? (y/N)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "File removal skipped." -ForegroundColor Cyan
            } else {
                # Remove files
                foreach ($file in $filesToRemove) {
                    $removeResult = Remove-DeployedFile $file.target
                    if ($removeResult) {
                        $state.deployedFiles = @($state.deployedFiles | Where-Object { $_.target -ne $file.target })
                    }
                }
            }
        } else {
            # Force removal without confirmation
            foreach ($file in $filesToRemove) {
                $removeResult = Remove-DeployedFile $file.target
                if ($removeResult) {
                    $state.deployedFiles = @($state.deployedFiles | Where-Object { $_.target -ne $file.target })
                }
            }
        }
    }
    
    # Update state file
    Update-StateFile $state
    
    Write-Host "Dotfiles sync completed." -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred during dotfiles sync: $_"
    Write-Error "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}