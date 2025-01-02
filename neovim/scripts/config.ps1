# UTF8 encoding for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Deploy-LazyVimConfig {
    Write-Host "Ready for custom configurations..." -ForegroundColor Yellow
    return $true
}
