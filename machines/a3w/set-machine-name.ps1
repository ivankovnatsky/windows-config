# Set Machine Name to a3w
# This script changes the computer name to "a3w"
# Requires Administrator privileges and a restart to take effect

param(
    [string]$ComputerName = "a3w",
    [switch]$Force
)

# Configuration
$NEW_COMPUTER_NAME = $ComputerName

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Attempting to restart with elevated permissions..." -ForegroundColor Yellow
    
    try {
        # Build the argument string to pass to the elevated process
        $argumentList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$($MyInvocation.MyCommand.Path)`""
        )
        
        # Add original parameters
        if ($ComputerName -ne "a3w") {
            $argumentList += "-ComputerName", "`"$ComputerName`""
        }
        if ($Force) {
            $argumentList += "-Force"
        }
        
        # Start elevated process
        Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -Verb RunAs -Wait
        exit 0
    }
    catch {
        Write-Error "Failed to restart with Administrator privileges: $($_.Exception.Message)"
        Write-Host "Please run PowerShell as Administrator manually and try again." -ForegroundColor Yellow
        exit 1
    }
}

$newComputerName = $NEW_COMPUTER_NAME
$currentComputerName = $env:COMPUTERNAME

Write-Host "Current computer name: $currentComputerName" -ForegroundColor Cyan
Write-Host "New computer name: $newComputerName" -ForegroundColor Green

# Check if the computer name is already set to a3w
if ($currentComputerName -eq $newComputerName) {
    Write-Host "Computer name is already set to '$newComputerName'. No changes needed." -ForegroundColor Green
    exit 0
}

# Confirm the change unless -Force is used
if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to change the computer name to '$newComputerName'? This will require a restart. (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

try {
    Write-Host "Changing computer name to '$newComputerName'..." -ForegroundColor Yellow
    
    # Rename the computer
    Rename-Computer -NewName $newComputerName -Force
    
    Write-Host "Computer name successfully changed to '$newComputerName'." -ForegroundColor Green
    Write-Host "A restart is required for the changes to take effect." -ForegroundColor Yellow
    
    # Ask if user wants to restart now
    if (-not $Force) {
        $restartConfirmation = Read-Host "Would you like to restart now? (y/N)"
        if ($restartConfirmation -eq 'y' -or $restartConfirmation -eq 'Y') {
            Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            Write-Host "Please restart your computer manually to complete the name change." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Error "Failed to change computer name: $($_.Exception.Message)"
    exit 1
}
