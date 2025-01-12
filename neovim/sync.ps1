# Define the source and destination paths
$sourceDir = (Join-Path $PSScriptRoot "config").TrimEnd('\')
$destDir = (Join-Path $env:LOCALAPPDATA "nvim").TrimEnd('\')

# Files to preserve in destination (won't be overwritten or deleted)
$preserveFiles = @(
    "lazy-lock.json"      # Package manager lock file
)

# Before sync, copy preserved files from dest to source if they exist
foreach ($file in $preserveFiles) {
    $destFile = Join-Path $destDir $file
    $sourceFile = Join-Path $sourceDir $file
    if (Test-Path $destFile) {
        if (Test-Path $sourceFile) {
            # Compare file hashes
            $destHash = (Get-FileHash $destFile).Hash
            $sourceHash = (Get-FileHash $sourceFile).Hash
            
            if ($destHash -ne $sourceHash) {
                Copy-Item -Path $destFile -Destination $sourceFile -Force
                Write-Host "Updated preserved file (changed): $file" -ForegroundColor Yellow
            } else {
                Write-Host "Skipped preserved file (unchanged): $file" -ForegroundColor Gray
            }
        } else {
            Copy-Item -Path $destFile -Destination $sourceFile -Force
            Write-Host "Copied new preserved file: $file" -ForegroundColor Green
        }
    }
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir
    Write-Host "Created destination directory: $destDir"
}

try {
    # Get list of all files in source
    $sourceFiles = Get-ChildItem -Path $sourceDir -Recurse -File

    # Compare and copy only changed files
    foreach ($sourceFile in $sourceFiles) {
        # Get the relative path by removing the source directory path
        $relativePath = $sourceFile.FullName.Substring($sourceDir.Length + 1)
        $destFile = Join-Path $destDir $relativePath
        
        # Create directory if it doesn't exist
        $destDirPath = Split-Path -Parent $destFile
        if (-not (Test-Path $destDirPath)) {
            New-Item -ItemType Directory -Path $destDirPath | Out-Null
        }

        if (-not (Test-Path $destFile)) {
            Copy-Item -Path $sourceFile.FullName -Destination $destFile -Force
            Write-Host "Added new file: $relativePath" -ForegroundColor Green
        }
        elseif ((Get-FileHash $sourceFile.FullName).Hash -ne (Get-FileHash $destFile).Hash) {
            Copy-Item -Path $sourceFile.FullName -Destination $destFile -Force
            Write-Host "Updated changed file: $relativePath" -ForegroundColor Yellow
        }
    }

    # Get list of all files in destination
    $destFiles = Get-ChildItem -Path $destDir -Recurse -File

    # Remove files that don't exist in source
    foreach ($file in $destFiles) {
        $relativePath = $file.FullName.Substring($destDir.Length + 1)
        $sourceFile = Join-Path $sourceDir $relativePath
        
        # Skip preserved files
        if ($preserveFiles | Where-Object { $relativePath -like $_ }) {
            continue
        }
        
        if (-not (Test-Path $sourceFile)) {
            Remove-Item $file.FullName -Force
            Write-Host "Removed orphaned file: $relativePath" -ForegroundColor Red
        }
    }

    Write-Host "`nSync completed successfully!" -ForegroundColor Green
} catch {
    Write-Error "Error syncing files: $_"
    exit 1
} 
