# watcher.ps1

# Get the current directory to watch
$pathToWatch = Get-Location

# Create a FileSystemWatcher object
$watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
    Path = $pathToWatch.Path
    Filter = "*.*"  # Monitor all files
    IncludeSubdirectories = $true  # Enable recursive monitoring
    NotifyFilter = [System.IO.NotifyFilters]::FileName, [System.IO.NotifyFilters]::LastWrite
}

# Define the action to take when a change occurs
$action = {
    $details = $event.SourceEventArgs
    $ChangeType = $details.ChangeType
    $FullPath = $details.FullPath
    $currentTime = Get-Date

    # Debounce: Only proceed if it's been more than 2 seconds since the last run
    if (($currentTime - $lastRunTime).TotalSeconds -ge 2) {
        $script:lastRunTime = $currentTime

        Write-Host "Change detected: $FullPath was $ChangeType at $currentTime" -ForegroundColor Yellow

        # Attempt to execute main.ps1
        try {
            # Change to the script's directory
            Set-Location -Path (Split-Path -Path $FullPath -Parent)

            # Execute the main.ps1 script
            & ".\main.ps1"

            Write-Host "Executed main.ps1 successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to execute main.ps1: $_" -ForegroundColor Red
        }
    }
}

# Register event handlers
$handlers = @()
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action

# Start monitoring
$watcher.EnableRaisingEvents = $true

Write-Host "Watching for changes in $pathToWatch. Press CTRL+C to exit."

# Keep PowerShell responsive while monitoring
try {
    while ($true) {
        Wait-Event -Timeout 1  # Allow the script to process events
        Write-Host "." -NoNewline  # Indicate monitoring is active
    }
}

finally {
    # Cleanup
    $watcher.EnableRaisingEvents = $false
    $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
    $handlers | Remove-Job
    $watcher.Dispose()
    Write-Host "Monitoring stopped." -ForegroundColor Red
}
