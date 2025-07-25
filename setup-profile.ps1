# Define local profile path
$documentsPath = [Environment]::GetFolderPath('MyDocuments')
$profilePath = Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

Write-Host "Setting up profile at: $profilePath"

# Create the profile directory if it doesn't exist
$profileDir = Split-Path $profilePath -Parent
Write-Host "Creating profile directory at: $profileDir"

if (!(Test-Path -Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force
    Write-Host "Created directory"
}

# Create the profile file if it doesn't exist
Write-Host "Creating profile file"
if (!(Test-Path -Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force
    Write-Host "Created profile file"
}

# Create the profile content with aliases and functions
$content = @"
# Git alias
Set-Alias -Name g -Value git

# Remove built-in cat alias and replace with bat
Remove-Item alias:cat -Force -ErrorAction SilentlyContinue
Set-Alias -Name cat -Value bat

# Remove built-in ls alias and replace with lsd
Remove-Item alias:ls -Force -ErrorAction SilentlyContinue
Set-Alias -Name ls -Value lsd

# Set environment variable for claude.cmd
`$env:CLAUDE_CODE_GIT_BASH_PATH = (Get-Command bash.exe -ErrorAction SilentlyContinue).Source

# Copy file content to clipboard function
function Copy-FileContentToClipboard {
    param (
        [string]`$FilePath
    )
    if (Test-Path `$FilePath) {
        Get-Content -Path `$FilePath | Set-Clipboard
        Write-Host "Copied content of '`$FilePath' to clipboard"
    } else {
        Write-Host "File not found: `$FilePath" -ForegroundColor Red
    }
}

# Create alias for easier usage
Set-Alias -Name eat -Value Copy-FileContentToClipboard

# Initialize Starship
Invoke-Expression (&starship init powershell)
"@

Set-Content -Path $profilePath -Value $content -Force
Write-Host "Wrote content to profile"

Write-Host "`nProfile content:"
Get-Content $profilePath

Write-Host "`nTrying to load profile..."
. $profilePath 
