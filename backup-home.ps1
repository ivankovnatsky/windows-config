# Configuration
$sourceDir = "$env:USERPROFILE"  # Home directory
$backupRoot = [System.IO.Path]::GetTempPath()  # Temp directory
$backupFile = Join-Path $backupRoot "$env:USERNAME.zip"
$rcloneConfig = "$env:USERPROFILE\.config\rclone\rclone.conf"
$uploadPath = "Machines/$env:COMPUTERNAME/Users/$env:USERNAME.zip"

# Clean up any existing backup file
if (Test-Path $backupFile) {
    Write-Host "Removing existing backup file..."
    Remove-Item $backupFile -Force
}

function Create-Backup {
    Write-Host "Starting backup of home directory..."
    Write-Host "Backup will be saved to: $backupFile"

    try {
        # Check if 7z is available in PATH
        if (!(Get-Command "7z" -ErrorAction SilentlyContinue)) {
            throw "7z is not found in PATH. Please install 7-Zip first."
        }

        # Create the archive using 7-Zip
        Write-Host "Creating ZIP archive..."
        $excludes = @(
            "scoop",
            "AppData\Local\AMD",
            "Documents\My Music",
            "Documents\My Pictures",
            "Documents\My Videos"
        ) | ForEach-Object { "-xr!`"$_`"" }

        $arguments = @(
            "a",           # Add to archive
            "-tzip",       # ZIP format
            "-mx=5",       # Normal compression
            "-r",          # Recursive
            "-y",          # Say yes to all queries
            "-ssw",        # Compress files open for writing
            "`"$backupFile`"",  # Output file
            "`"$sourceDir\*`""  # Source directory
        ) + $excludes

        $process = Start-Process -FilePath "7z" -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        # Modified exit code handling
        switch ($process.ExitCode) {
            0 { Write-Host "Archive created successfully with no warnings." }
            1 { Write-Host "Archive created successfully with some files skipped." }
            2 { Write-Host "Some files could not be accessed (in use or permissions)." }
            default { throw "7-Zip failed with exit code $($process.ExitCode)" }
        }
        
        # Verify the archive was created
        if (Test-Path $backupFile) {
            $backupSize = (Get-Item $backupFile).Length / 1GB
            Write-Host "Backup completed successfully!"
            Write-Host "Backup archive size: $([math]::Round($backupSize, 2)) GB"
            return $true
        } else {
            throw "Failed to create backup archive"
        }
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Upload-Backup {
    Write-Host "Starting upload to Google Drive..."
    
    try {
        # Check if rclone is available in PATH
        if (!(Get-Command "rclone" -ErrorAction SilentlyContinue)) {
            throw "rclone is not found in PATH. Please install rclone first."
        }

        # Check if config exists
        if (!(Test-Path $rcloneConfig)) {
            throw "rclone config not found at: $rcloneConfig"
        }

        # Upload using rclone
        Write-Host "Uploading backup file..."
        $process = Start-Process -FilePath "rclone" -ArgumentList @(
            "--config",
            "`"$rcloneConfig`"",
            "--progress",
            "`"$backupFile`"",
            "drive_Crypt:$uploadPath"
        ) -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "rclone failed with exit code $($process.ExitCode)"
        }

        Write-Host "Upload completed successfully!"
        return $true
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
if (Create-Backup) {
    Write-Host "Starting upload process..."
    Upload-Backup
} else {
    Write-Host "Backup failed, skipping upload."
    exit 1
}
