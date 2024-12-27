# Configuration
$sourceDir = "$env:USERPROFILE"  # Home directory
$backupRoot = [System.IO.Path]::GetTempPath()  # Temp directory
$backupName = "$env:USERNAME"
$backupFile = Join-Path $backupRoot "$backupName.zip"
$extractDir = Join-Path $backupRoot $backupName  # New extraction directory
$rcloneConfig = "$env:USERPROFILE\.config\rclone\rclone.conf"
$rcloneRemote = "drive_Crypt"

# Get backup path from arguments
$backupPath = $args[0]

# Check for --help in raw arguments
if ($MyInvocation.UnboundArguments -contains '--help' -or 
    $MyInvocation.UnboundArguments -contains '-help' -or 
    $MyInvocation.UnboundArguments -contains '-h' -or
    $args.Count -eq 0) {
    Write-Host @"
Fetch Backup Script
Usage: fetch-backup.ps1 <backup-path>

Arguments:
    backup-path     Path on Google Drive where the backup is stored
                   Example: Machines/DESKTOP-123/Users/username

Options:
    -h, -help, --help      Show this help message
    
Description:
    Downloads a backup from Google Drive and extracts it to your home directory.
    The script will prompt for confirmation before overwriting any existing files.
    
Requirements:
    - rclone (available in PATH with configured drive_Crypt remote)
    - 7-Zip (available in PATH)

Example:
    .\fetch-backup.ps1 Machines/DESKTOP-123/Users/username

Available backups:
"@
    
    # List using rclone with same config as backup-home.ps1
    $process = Start-Process -FilePath "rclone" -ArgumentList @(
        "lsl",
        "--config",
        "`"$rcloneConfig`"",
        "${rcloneRemote}:"
    ) -NoNewWindow -Wait -PassThru
    
    exit 0
}

function Download-Backup {
    Write-Host "Starting download from Google Drive..."
    Write-Host "Source: ${rcloneRemote}:$backupPath"
    Write-Host "Destination: $backupFile"
    
    try {
        # Check if rclone is available
        if (!(Get-Command "rclone" -ErrorAction SilentlyContinue)) {
            throw "rclone is not found in PATH. Please install rclone first."
        }

        # Check if config exists
        if (!(Test-Path $rcloneConfig)) {
            throw "rclone config not found at: $rcloneConfig"
        }

        # Download using rclone
        Write-Host "Downloading backup file..."
        $process = Start-Process -FilePath "rclone" -ArgumentList @(
            "copyto",
            "--config",
            "`"$rcloneConfig`"",
            "--progress",
            "${rcloneRemote}:$backupPath",
            "`"$backupFile`""
        ) -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "rclone failed with exit code $($process.ExitCode)"
        }

        Write-Host "Download completed successfully!"
        return $true
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Extract-Backup {
    Write-Host "Starting backup extraction..."
    Write-Host "Source: $backupFile"
    Write-Host "Temporary extraction path: $extractDir"

    try {
        # Check if 7z is available
        if (!(Get-Command "7z" -ErrorAction SilentlyContinue)) {
            throw "7z is not found in PATH. Please install 7-Zip first."
        }

        # Verify backup file exists
        if (!(Test-Path $backupFile)) {
            throw "Backup file not found at: $backupFile"
        }

        # Create extraction directory if it doesn't exist
        if (!(Test-Path $extractDir)) {
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
        }

        # Extract the archive using 7-Zip
        Write-Host "Extracting ZIP archive to temporary location..."
        $process = Start-Process -FilePath "7z" -ArgumentList @(
            "x",           # Extract with full paths
            "-y",         # Yes to all queries
            "-o`"$extractDir`"",  # Output directory
            "`"$backupFile`""  # Input file
        ) -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "7-Zip failed with exit code $($process.ExitCode)"
        }

        Write-Host "`nExtraction completed successfully!"
        Write-Host "Files are extracted to: $extractDir"
        Write-Host "You can review the files and manually copy what you need."

        # Only clean up after successful extraction
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force
        }

        return $true
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
if (Download-Backup) {
    Write-Host "Starting extraction process..."
    Extract-Backup | Out-Null
} else {
    Write-Host "Download failed, skipping extraction."
    exit 1
} 
