[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Pull,
    
    [Parameter()]
    [switch]$Clean,
    
    [Parameter()]
    [switch]$Serve,
    
    [Parameter()]
    [switch]$Help
)

$Models = @(
    "llama4:scout",
    "llama3.3:70b",
    "gemma3:27b",
    "gemma3:12b",
    "llama3.1:8b",
    "magistral:24b",
    "mistral-nemo:12b",
    "mistral-small3.2:24b",
    "gpt-oss:20b",
    "gpt-oss:120b"
)

function Show-Help {
    Write-Host "Ollama Management Script" -ForegroundColor Cyan
    Write-Host "Usage: .\ollama.ps1 [-Pull] [-Clean] [-Serve] [-Help]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Pull    - Download models" -ForegroundColor Green
    Write-Host "  -Serve   - Start Ollama server" -ForegroundColor Cyan
    Write-Host "  -Clean   - Remove ALL models" -ForegroundColor Red
    Write-Host "  -Help    - Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\ollama.ps1 -Pull" -ForegroundColor Gray
    Write-Host "  .\ollama.ps1 -Serve" -ForegroundColor Gray
    Write-Host "  .\ollama.ps1 -Clean" -ForegroundColor Gray
}

function Get-LocalIP {
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet" -ErrorAction SilentlyContinue).IPAddress
    if ($localIP) {
        return $localIP
    }
    return "127.0.0.1"
}

function Set-OllamaHost {
    $localIP = Get-LocalIP
    $env:OLLAMA_HOST = "http://${localIP}:11434"
    Write-Host "Using Ollama host: $env:OLLAMA_HOST" -ForegroundColor Cyan
}

function Test-OllamaInstalled {
    try {
        $null = Get-Command ollama -ErrorAction Stop
        return $true
    } catch {
        Write-Host "ERROR: Ollama is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Install with: scoop install ollama" -ForegroundColor Yellow
        return $false
    }
}

function Invoke-OllamaPull {
    Write-Host "Pulling models..." -ForegroundColor Cyan
    
    foreach ($model in $Models) {
        Write-Host "Pulling model: $model" -ForegroundColor Cyan
        ollama pull $model
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully pulled $model" -ForegroundColor Green
        } else {
            Write-Host "Failed to pull $model" -ForegroundColor Red
        }
        Write-Host ""
    }
}

function Invoke-OllamaClean {
    Write-Host "Cleaning all Ollama models..." -ForegroundColor Yellow
    
    # Get list of installed models
    $models = ollama list --format json 2>$null | ConvertFrom-Json
    
    if (-not $models -or $models.Count -eq 0) {
        Write-Host "No models to clean" -ForegroundColor Green
        return
    }
    
    Write-Host "Found $($models.Count) model(s) to remove:" -ForegroundColor Cyan
    foreach ($model in $models) {
        Write-Host "  - $($model.name)" -ForegroundColor White
    }
    
    $confirmation = Read-Host "Are you sure you want to remove ALL models? (y/N)"
    
    if ($confirmation -eq "y" -or $confirmation -eq "Y") {
        foreach ($model in $models) {
            Write-Host "Removing $($model.name)..." -ForegroundColor Yellow
            ollama rm $model.name
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Removed $($model.name)" -ForegroundColor Green
            } else {
                Write-Host "Failed to remove $($model.name)" -ForegroundColor Red
            }
        }
        Write-Host "Cleanup complete!" -ForegroundColor Green
    } else {
        Write-Host "Cleanup cancelled" -ForegroundColor Yellow
    }
}

function Invoke-OllamaServe {
    Write-Host "Starting Ollama server..." -ForegroundColor Cyan
    
    # Get local IP address
    $localIP = Get-LocalIP
    $env:OLLAMA_HOST = $localIP
    Write-Host "Server will listen on: $localIP" -ForegroundColor Green
    
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
    Write-Host ""
    
    ollama serve
}

# Main script logic
$commandCount = @($Pull, $Clean, $Serve, $Help).Where({$_}).Count

if ($Help) {
    Show-Help
    exit 0
}

if ($commandCount -gt 1) {
    Write-Host "ERROR: Only one command can be specified at a time" -ForegroundColor Red
    Show-Help
    exit 1
}

if (-not (Test-OllamaInstalled)) {
    exit 1
}

# Set OLLAMA_HOST for all operations except Help
if (-not $Help) {
    Set-OllamaHost
}

if ($Pull) {
    Invoke-OllamaPull
} elseif ($Clean) {
    Invoke-OllamaClean
} else {
    # Default to Serve if no arguments or -Serve specified
    Invoke-OllamaServe
}
