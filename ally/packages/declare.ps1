# Define paths
$packagesFile = Join-Path $PSScriptRoot "packages.json"
$stateFile = Join-Path $PSScriptRoot "state.json"

# Function to read packages from JSON file
function Get-PackagesFromJson($filePath) {
    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    return @{
        scoop = $content.scoop
        arbitrary = $content.arbitrary
        nodejs = $content.nodejs
    }
}

# Function to read state from JSON file
function Get-StateFromJson($filePath) {
    if (Test-Path $filePath) {
        try {
            $state = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        } catch {
            Write-Error "Failed to read or parse state file: $_"
            exit 1
        }
    } else {
        Write-Host "State file not found. Creating new state." -ForegroundColor Yellow
        $state = @{
            lastUpdated = $null
            scoop = @()
            arbitrary = @()
            nodejs = @()
        }
    }

    # Ensure all required properties exist and are arrays
    $requiredProperties = @('scoop', 'arbitrary', 'nodejs')
    $updated = $false
    foreach ($prop in $requiredProperties) {
        if (-not ($state.PSObject.Properties.Name -contains $prop) -or $null -eq $state.$prop) {
            $state | Add-Member -NotePropertyName $prop -NotePropertyValue @() -Force
            $updated = $true
        }
    }

    if ($updated) {
        $state | ConvertTo-Json -Depth 4 | Set-Content $filePath
        Write-Host "State file updated with missing properties." -ForegroundColor Yellow
    }

    return $state
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

# Function to install Node.js global package
function Install-NodejsPackage($package) {
    Write-Host "Installing Node.js global package: $package" -ForegroundColor Cyan
    npm install $package -g
    return $LASTEXITCODE -eq 0
}

# Main script
try {
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

    # Process Node.js global packages
    $desiredNodejsPackages = $packages.nodejs
    $installedNodejsPackages = $state.nodejs | ForEach-Object { $_.name }

    $nodejsPackagesToInstall = $desiredNodejsPackages | Where-Object { $_ -notin $installedNodejsPackages }

    foreach ($package in $nodejsPackagesToInstall) {
        if (Install-NodejsPackage $package) {
            $state.nodejs += @{ name = $package; installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        }
    }

    # Update state file
    Update-StateFile $state

    Write-Host "All packages processed." -ForegroundColor Green
} catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
