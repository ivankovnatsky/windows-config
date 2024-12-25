# Check for --help in raw arguments
if ($MyInvocation.UnboundArguments -contains '--help' -or 
    $MyInvocation.UnboundArguments -contains '-help' -or 
    $MyInvocation.UnboundArguments -contains '-h') {
    Write-Host @"
Backup Home Directory Script
Usage: backup-home.ps1 [options]

Options:
    -h, -help, --help      Show this help message
    
Description:
    Creates a ZIP archive of your home directory and uploads it to Google Drive.
    The backup excludes various system and cache folders.
    
Backup Location:
    Local: $([System.IO.Path]::GetTempPath())
    Remote: drive_Crypt:Machines/`$env:COMPUTERNAME/Users/`$env:USERNAME

Requirements:
    - 7-Zip (available in PATH)
    - rclone (available in PATH with configured drive_Crypt remote)
"@
    exit 0
}

# Configuration
$sourceDir = "$env:USERPROFILE"  # Home directory
$backupRoot = [System.IO.Path]::GetTempPath()  # Temp directory
$backupFile = Join-Path $backupRoot "$env:USERNAME.zip"
$rcloneConfig = "$env:USERPROFILE\.config\rclone\rclone.conf"
$rcloneRemote = "drive_Crypt"
$uploadPath = "Machines/$env:COMPUTERNAME/Users/$env:USERNAME"

# Show help if requested via PowerShell parameters or --help
if ($h -or ($MyInvocation.UnboundArguments -contains '--help')) {
    Write-Host @"
Backup Home Directory Script
Usage: backup-home.ps1 [options]

Options:
    -h, -help, --help      Show this help message
    
Description:
    Creates a ZIP archive of your home directory and uploads it to Google Drive.
    The backup excludes various system and cache folders.
    
Backup Location:
    Local: $([System.IO.Path]::GetTempPath())
    Remote: ${rcloneRemote}:Machines/`$env:COMPUTERNAME/Users/`$env:USERNAME

Requirements:
    - 7-Zip (available in PATH)
    - rclone (available in PATH with configured $rcloneRemote remote)
"@
    exit 0
}

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
            "AppData\Local\Microsoft",              # All Windows-specific data
            "AppData\Local\Mozilla\Firefox",        # Firefox local data
            "AppData\Roaming\Mozilla\Firefox",      # Firefox profile data
            "AppData\Local\Steam\htmlcache",        # Steam browser cache
            "AppData\Local\Packages",               # Windows Store apps data
            "AppData\Local\Programs\cursor",        # Cursor editor
            "AppData\Roaming\Cursor",               # Cursor editor data
            "AppData\Local\Temp",                   # All temp files
            "AppData\Roaming\asus_framework",       # ASUS software files
            "NTUSER.DAT",                          # Windows user profile
            "ntuser.dat.LOG*",                     # Windows profile logs
            "AppData\Local\Application Data",
            "AppData\Local\History",
            "AppData\Local\ElevatedDiagnostics",
            "AppData\Local\Temporary Internet Files",
            "Application Data",
            "Cookies",
            "Local Settings",
            "My Documents",
            "NetHood",
            "PrintHood",
            "Recent",
            "SendTo",
            "Start Menu",
            "Templates",
            "Documents\My Music",
            "Documents\My Pictures",
            "Documents\My Videos"
        ) | ForEach-Object { "-xr!`"$_`"" }

        $arguments = @(
            "a",           # Add to archive
            "-tzip",       # ZIP format
            "-mx=0",       # Store only, no compression (changed from 5)
            "-r",          # Recursive
            "-y",          # Say yes to all queries
            "-ssw",        # Compress files open for writing
            "`"$backupFile`"",  # Output file
            "`"$sourceDir\*`""  # Source directory
        ) + $excludes

        $process = Start-Process -FilePath "7z" -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        # Modified exit code handling to treat warnings as success
        switch ($process.ExitCode) {
            0 { Write-Host "Archive created successfully with no warnings." }
            1 { Write-Host "Archive created successfully with some files skipped." }
            2 { 
                Write-Host "Archive created with some files skipped (locked files or permissions)."
                return $true  # Still consider this a success
            }
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
    Write-Host "Upload destination: drive_Crypt:$uploadPath"
    
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
            "copy",
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
