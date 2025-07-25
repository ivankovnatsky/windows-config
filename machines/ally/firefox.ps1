# Firefox Configuration Script
# Configures Firefox profile with basic settings

param(
    [string]$ProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles\27xy9lm8.default-release"
)

Write-Host "Configuring Firefox profile at: $ProfilePath"

# Ensure profile directory exists
if (-not (Test-Path $ProfilePath)) {
    Write-Error "Firefox profile directory not found: $ProfilePath"
    exit 1
}

# Create user.js file with basic configuration
$userJsContent = @"
// Enable vertical tabs
user_pref("sidebar.verticalTabs", true);

// Restore previous session (tabs and windows)
user_pref("browser.startup.page", 3);

// Enable Ctrl+Tab to cycle through recent tabs
user_pref("browser.ctrlTab.recentlyUsedOrder", true);
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
"@

$userJsPath = Join-Path $ProfilePath "user.js"
Write-Host "Writing user.js configuration to: $userJsPath"
$userJsContent | Out-File -FilePath $userJsPath -Encoding UTF8

Write-Host "Firefox configuration completed successfully!"
Write-Host "Restart Firefox for changes to take effect."