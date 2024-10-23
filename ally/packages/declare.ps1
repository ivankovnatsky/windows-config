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
    foreach ($prop in $requiredProperties) {
        if (-not ($state.PSObject.Properties.Name -contains $prop) -or $null -eq $state.$prop) {
            $state | Add-Member -NotePropertyName $prop -NotePropertyValue @() -Force
        }
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
    Write-Host "Package details: $(ConvertTo-Json $package)" -ForegroundColor Yellow  # Debug output
    
    $outputFile = Join-Path $env:TEMP $package.fileName

    try {
        Write-Host "Downloading from: $($package.url)"
        & "$env:USERPROFILE\scoop\apps\wget\current\wget.exe" "$($package.url)" --output-document="$outputFile"
        if ($LASTEXITCODE -ne 0) {
            throw "wget failed with exit code $LASTEXITCODE"
        }
        
        if (Test-Path $outputFile) {
            Write-Host "Starting installation from: $outputFile"
            Start-Process -FilePath $outputFile -Wait -ArgumentList "/S"
            Remove-Item -Path $outputFile -Force
            return $true
        } else {
            throw "Downloaded file not found at: $outputFile"
        }
    } catch {
        Write-Error "Failed to install $($package.name): $_"
        return $false
    }
}

# Function to uninstall arbitrary package
function Uninstall-ArbitraryPackage($packageName) {
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $app = Get-ItemProperty $uninstallKeys | 
        Where-Object { $_.DisplayName -like "*$packageName*" } |
        Select-Object -First 1

    if ($app) {
        Write-Host "Uninstalling $($app.DisplayName)..." -ForegroundColor Cyan
        $uninstallString = $app.UninstallString

        Write-Host "Uninstall string: $uninstallString" -ForegroundColor Yellow

        if ($uninstallString -like '*.exe*') {
            # Parse the uninstall string to separate the executable and its arguments
            $uninstallPath = ($uninstallString -split '"')[1]
            $uninstallArgs = ($uninstallString -split '"')[2].Trim()

            Write-Host "Uninstall path: $uninstallPath" -ForegroundColor Yellow
            Write-Host "Uninstall args: $uninstallArgs" -ForegroundColor Yellow

            # Check if the file exists
            if (Test-Path $uninstallPath) {
                Write-Host "Uninstaller found at: $uninstallPath" -ForegroundColor Green
            } else {
                Write-Host "Uninstaller not found at: $uninstallPath" -ForegroundColor Red
                return $false
            }

            # Add silent uninstall argument if not present
            if ($uninstallArgs -notlike '*silent*' -and $uninstallArgs -notlike '*/S*') {
                $uninstallArgs += ' /S'
            }

            Write-Host "Executing: $uninstallPath $uninstallArgs" -ForegroundColor Yellow
            try {
                Start-Process -FilePath $uninstallPath -ArgumentList $uninstallArgs -Wait -NoNewWindow
                return $LASTEXITCODE -eq 0
            } catch {
                Write-Host "Error executing uninstaller: $_" -ForegroundColor Red
                return $false
            }
        } else {
            # Handle MSI uninstallation if needed
            Write-Host "Executing: msiexec.exe /x $($app.PSChildName) /qn" -ForegroundColor Yellow
            try {
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($app.PSChildName) /qn" -Wait -NoNewWindow
                return $LASTEXITCODE -eq 0
            } catch {
                Write-Host "Error executing MSI uninstaller: $_" -ForegroundColor Red
                return $false
            }
        }
    } else {
        Write-Host "Package $packageName not found." -ForegroundColor Yellow
        return $false
    }
}

# Function to install Node.js global package
function Install-NodejsPackage($package) {
    Write-Host "Installing Node.js global package: $package" -ForegroundColor Cyan
    npm install $package -g
    return $LASTEXITCODE -eq 0
}

# Function to uninstall Node.js global package
function Uninstall-NodejsPackage($package) {
    Write-Host "Uninstalling Node.js global package: $package" -ForegroundColor Cyan
    npm uninstall $package -g
    return $LASTEXITCODE -eq 0
}

# Main script
try {
    $packages = Get-PackagesFromJson $packagesFile
    $state = Get-StateFromJson $stateFile

    # Process all package types
    @('scoop', 'arbitrary', 'nodejs') | ForEach-Object {
        $packageType = $_
        Write-Host "Processing $packageType packages..." -ForegroundColor Cyan
        
        # Handle different package formats
        if ($packageType -eq 'arbitrary') {
            $desiredPackages = $packages.$packageType
            $installedPackages = $state.$packageType
            
            # Find packages to uninstall (installed but not in desired)
            $packagesToUninstall = $installedPackages | Where-Object {
                $installedName = $_.name
                -not ($desiredPackages | Where-Object { $_.name -eq $installedName })
            }
            
            # Handle installations
            foreach ($package in $desiredPackages) {
                if (-not ($installedPackages | Where-Object { $_.name -eq $package.name })) {
                    Write-Host "Installing $packageType package: $($package.name)" -ForegroundColor Yellow
                    $installResult = Install-ArbitraryPackage $package
                    if ($installResult) {
                        $state.$packageType += @{ 
                            name = $package.name
                            installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                    }
                }
            }
            
            # Handle uninstallations
            foreach ($package in $packagesToUninstall) {
                Write-Host "Uninstalling $packageType package: $($package.name)" -ForegroundColor Yellow
                $uninstallResult = Uninstall-ArbitraryPackage $package.name
                if ($uninstallResult) {
                    $state.$packageType = @($state.$packageType | Where-Object { $_.name -ne $package.name })
                }
            }
        } else {
            # Handle scoop and nodejs packages as before
            $desiredPackages = $packages.$packageType
            $installedPackages = $state.$packageType | ForEach-Object { $_.name }
            
            $packagesToInstall = $desiredPackages | Where-Object { $_ -notin $installedPackages }
            $packagesToUninstall = $installedPackages | Where-Object { $_ -notin $desiredPackages }
            
            foreach ($package in $packagesToInstall) {
                Write-Host "Installing $packageType package: $package" -ForegroundColor Yellow
                $installResult = switch ($packageType) {
                    'scoop' { Install-ScoopPackage $package }
                    'nodejs' { Install-NodejsPackage $package }
                }
                if ($installResult) {
                    $state.$packageType += @{ 
                        name = $package
                        installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
            }
            
            foreach ($package in $packagesToUninstall) {
                Write-Host "Uninstalling $packageType package: $package" -ForegroundColor Yellow
                $uninstallResult = switch ($packageType) {
                    'scoop' { Uninstall-ScoopPackage $package }
                    'nodejs' { Uninstall-NodejsPackage $package }
                }
                if ($uninstallResult) {
                    $state.$packageType = @($state.$packageType | Where-Object { $_.name -ne $package })
                }
            }
        }
    }

    # Update state file
    Update-StateFile $state

    Write-Host "All packages processed." -ForegroundColor Green
} catch {
    Write-Error "An error occurred during script execution: $_"
    Write-Error "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
