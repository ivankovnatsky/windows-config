# Script variables
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$NvimPath = "$env:LOCALAPPDATA\nvim"
$NvimDataPath = "$env:LOCALAPPDATA\nvim-data"
$LazyVimStarterUrl = "https://github.com/LazyVim/starter"

# Import helper scripts
. "$ScriptPath\scripts\utils.ps1"
. "$ScriptPath\scripts\prereqs.ps1"
. "$ScriptPath\scripts\config.ps1"

function Install-LazyVim {
    Write-Host "Starting LazyVim installation..." -ForegroundColor Cyan

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Host "Prerequisites check failed. Please fix the issues above." -ForegroundColor Red
        return
    }

    # Check if LazyVim is already installed
    if (Test-Path "$NvimPath\lua\plugins") {
        Write-Host "LazyVim appears to be already installed in $NvimPath" -ForegroundColor Yellow
        Write-Host "To reinstall, please remove the existing configuration first." -ForegroundColor Yellow
        return
    }

    # Clone the starter configuration
    Write-Host "Cloning LazyVim starter..." -ForegroundColor Yellow
    try {
        git clone $LazyVimStarterUrl $NvimPath
        if (-not $?) { throw "Git clone failed" }
    } catch {
        Write-Host "Failed to clone LazyVim starter: $_" -ForegroundColor Red
        return
    }

    # Remove .git folder
    Write-Host "Cleaning up .git folder..." -ForegroundColor Yellow
    if (Test-Path "$NvimPath\.git") {
        try {
            Remove-Item "$NvimPath\.git" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove .git folder: $_" -ForegroundColor Red
        }
    }

    Write-Host "LazyVim installation completed!" -ForegroundColor Green
    Write-Host "You can now start Neovim by running: nvim" -ForegroundColor Cyan
    Write-Host "Tip: Run :LazyHealth after starting to check if everything is working correctly" -ForegroundColor Yellow
}

# Run installation
Install-LazyVim
