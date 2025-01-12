# Define the source and destination paths
$sourceDir = (Join-Path $PSScriptRoot "config").TrimEnd('\')
$destDir = (Join-Path $env:LOCALAPPDATA "nvim").TrimEnd('\')

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
        # Get the relative path by removing the destination directory path
        $relativePath = $file.FullName.Substring($destDir.Length + 1)
        $sourceFile = Join-Path $sourceDir $relativePath
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
