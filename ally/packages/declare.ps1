# Define paths
$packagesFile = Join-Path $PSScriptRoot "packages.json"
$stateFile = Join-Path $PSScriptRoot "state.json"

# Function to read packages from JSON file
function Get-PackagesFromJson($filePath) {
    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    return @{
        scoop = $content.scoop
        arbitrary = $content.arbitrary
    }
}

# Function to read state from JSON file
function Get-StateFromJson($filePath) {
    if (Test-Path $filePath) {
        return Get-Content -Path $filePath -Raw | ConvertFrom-Json
    }
    return @{
        lastUpdated = $null
        scoop = @()
        arbitrary = @()
    }
}

# Function to update state file
function Update-StateFile($state) {
    $state.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $state | ConvertTo-Json -Depth 4 | Set-Content $stateFile
}

# Function to install scoop package
function Install-ScoopPackage($package) {
    Write-Host "Installing Scoop package: $package" -ForegroundColor Cyan
    scoop install $package
    return $LASTEXITCODE -eq 0
}

# Function to uninstall scoop package
function Uninstall-ScoopPackage($package) {
    Write-Host "Uninstalling Scoop package: $package" -ForegroundColor Cyan
    scoop uninstall $package
    return $LASTEXITCODE -eq 0
}

# Function to install arbitrary package
function Install-ArbitraryPackage($package) {
    Write-Host "Installing arbitrary package: $($package.name)" -ForegroundColor Cyan
    $outputFile = Join-Path $env:TEMP $package.fileName

    try {
        Invoke-WebRequest -Uri $package.url -OutFile $outputFile
        Start-Process -FilePath $outputFile -Wait
        Remove-Item -Path $outputFile -Force
        return $true
    } catch {
        Write-Error "Failed to install $($package.name): $_"
        return $false
    }
}

# Main script
$packages = Get-PackagesFromJson $packagesFile
$state = Get-StateFromJson $stateFile

# Process Scoop packages
$desiredScoopPackages = $packages.scoop
$installedScoopPackages = $state.scoop | ForEach-Object { $_.name }

$scoopPackagesToInstall = $desiredScoopPackages | Where-Object { $_ -notin $installedScoopPackages }
$scoopPackagesToUninstall = $installedScoopPackages | Where-Object { $_ -notin $desiredScoopPackages }

foreach ($package in $scoopPackagesToInstall) {
    if (Install-ScoopPackage $package) {
        $state.scoop += @{ name = $package; installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    }
}

foreach ($package in $scoopPackagesToUninstall) {
    if (Uninstall-ScoopPackage $package) {
        $state.scoop = $state.scoop | Where-Object { $_.name -ne $package }
    }
}

# Process arbitrary packages
foreach ($package in $packages.arbitrary) {
    $installedPackage = $state.arbitrary | Where-Object { $_.name -eq $package.name }
    if (-not $installedPackage) {
        if (Install-ArbitraryPackage $package) {
            $state.arbitrary += @{ name = $package.name; installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        }
    }
}

# Update state file
Update-StateFile $state

Write-Host "All packages processed." -ForegroundColor Green
