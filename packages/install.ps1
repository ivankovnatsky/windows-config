# Get hostname parameter or use system hostname
param(
    [string]$Hostname,
    [switch]$Force,
    [switch]$Help
)

# Function to display help information
function Show-Help {
    Write-Host "Usage: .\install.ps1 [-Hostname <hostname>] [-Force] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Hostname   : The hostname configuration to use (e.g., 'ally')" -ForegroundColor White
    Write-Host "                If not specified, your computer's hostname will be used automatically" -ForegroundColor White
    Write-Host "  -Force      : Skip confirmation prompts for uninstallation" -ForegroundColor White
    Write-Host "  -Help       : Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Available configurations:" -ForegroundColor Cyan
    $availableConfigs = Get-ChildItem -Path $PSScriptRoot -Directory | Select-Object -ExpandProperty Name
    foreach ($config in $availableConfigs) {
        Write-Host "  $config" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\install.ps1                     # Uses your computer's hostname" -ForegroundColor White
    Write-Host "  .\install.ps1 -Hostname ally      # Uses the 'ally' configuration" -ForegroundColor White
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}


# Check if hostname starts with -- (common mistake from command-line users)
if ($Hostname -and $Hostname.StartsWith('--')) {
    Write-Host "Error: Incorrect parameter format" -ForegroundColor Red
    Write-Host "You provided: '$Hostname'" -ForegroundColor Red
    Write-Host "PowerShell parameters use a dash prefix (-) not double-dash (--)" -ForegroundColor Yellow
    Write-Host ""
    Show-Help
    exit 1
}

# Check if Scoop is already installed
$scoopInstalled = Get-Command scoop -ErrorAction SilentlyContinue

# Only run admin tasks if Scoop isn't installed
if (!$scoopInstalled) {
    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        # Admin-only tasks
        Write-Host "Running admin tasks..." -ForegroundColor Cyan
        
        # Check current execution policy before trying to set it
        $currentPolicy = Get-ExecutionPolicy
        if ($currentPolicy -ne 'Bypass' -and $currentPolicy -ne 'Unrestricted') {
            Write-Host "Setting execution policy..." -ForegroundColor Cyan
            Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
        } else {
            Write-Host "Execution policy already set to $currentPolicy" -ForegroundColor Green
        }

        # Install runtime (needs admin)
        Write-Host "Installing .NET Desktop Runtime..." -ForegroundColor Cyan
        scoop install windowsdesktop-runtime
        scoop uninstall windowsdesktop-runtime
        
        exit # Exit admin context
    }

    # If we're not admin and Scoop isn't installed, start admin instance for admin tasks first
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
}

# Continue with non-admin tasks
Write-Host "Running non-admin tasks..." -ForegroundColor Cyan

# Install Scoop if not already installed
if (!$scoopInstalled) {
    Write-Host "Installing Scoop..." -ForegroundColor Cyan
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop is already installed." -ForegroundColor Green
}

# Check if git is installed via scoop
if (!(Test-Path "$env:USERPROFILE\scoop\apps\git")) {
    Write-Host "Installing git..." -ForegroundColor Cyan
    scoop install git
} else {
    Write-Host "Git is already installed via Scoop." -ForegroundColor Green
}

# Define required buckets
$requiredBuckets = @('extras', 'nerd-fonts', 'games')

# Check and add required buckets
foreach ($bucket in $requiredBuckets) {
    $bucketExists = scoop bucket list | Where-Object { $_ -match $bucket }
    if (!$bucketExists) {
        Write-Host "Adding $bucket bucket..." -ForegroundColor Cyan
        scoop bucket add $bucket
    } else {
        Write-Host "$bucket bucket is already added." -ForegroundColor Green
    }
}



# If no hostname is provided, use the system hostname
if (-not $Hostname) {
    $Hostname = $env:COMPUTERNAME.ToLower()
    Write-Host "No hostname provided, using system hostname: $Hostname" -ForegroundColor Yellow
}

# Define paths
$configDir = Join-Path $PSScriptRoot $Hostname

# If hostname-specific config doesn't exist, show error and help information, then exit
if (-not (Test-Path $configDir)) {
    Write-Host "Error: Configuration directory for hostname '$Hostname' not found." -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
}

$packagesFile = Join-Path $configDir "packages.json"
$stateFile = Join-Path $configDir "state.json"

Write-Host "Using configuration from: $configDir" -ForegroundColor Cyan

# Function to read packages from JSON file
function Get-PackagesFromJson($filePath) {
    if (-not (Test-Path $filePath)) {
        Write-Error "Package configuration file not found: $filePath"
        exit 1
    }
    
    try {
        $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        return @{
            scoop = $content.scoop
            arbitrary = $content.arbitrary
            copy = $content.copy
            winget = $content.winget
            msstore = $content.msstore
            nodejs = $content.nodejs
        }
    } catch {
        Write-Error "Failed to read or parse package configuration file: $_"
        exit 1
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
            copy = @()
            winget = @()
            msstore = @()
            nodejs = @()
        }
    }

    # Ensure all required properties exist and are arrays
    $requiredProperties = @('scoop', 'arbitrary', 'copy', 'winget', 'msstore', 'nodejs')
    foreach ($prop in $requiredProperties) {
        if (-not ($state.PSObject.Properties.Name -contains $prop) -or $null -eq $state.$prop) {
            $state | Add-Member -NotePropertyName $prop -NotePropertyValue @() -Force
        }
    }

    return $state
}

# Function to initialize state with existing packages
function Initialize-StateWithExisting {
    param($state)

    # Get existing scoop packages using export instead of list
    $existingScoopPackages = (scoop export | ConvertFrom-Json).apps | ForEach-Object {
        @{
            name = $_.Name
            installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Update state with existing packages if they're not already tracked
    foreach ($package in $existingScoopPackages) {
        if ($package -and -not ($state.scoop | Where-Object { $_.name -eq $package.name })) {
            $state.scoop += $package
        }
    }

    # Get existing winget packages (if winget is available)
    $existingWingetPackages = @()
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            $wingetList = winget list --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Parse winget output to find installed packages
                # This is a simplified approach - winget list output parsing can be complex
                $existingWingetPackages = @()
            }
        } catch {
            Write-Warning "Could not detect existing winget packages: $($_.Exception.Message)"
        }
    }

    # Update state with existing winget packages
    foreach ($package in $existingWingetPackages) {
        if ($package -and -not ($state.winget | Where-Object { $_.name -eq $package.name })) {
            $state.winget += $package
        }
    }

    return $state
}

# Function to update state file
function Update-StateFile($state) {
    # Safely add or update the lastUpdated property
    if ($state.PSObject.Properties.Name -contains 'lastUpdated') {
        $state.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } else {
        $state | Add-Member -NotePropertyName 'lastUpdated' -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
    }
    $state | ConvertTo-Json -Depth 4 | Set-Content $stateFile
}

# Function to install scoop package
function Install-ScoopPackage($package) {
    Write-Host "Installing Scoop package: $package" -ForegroundColor Cyan
    # Check if package is already installed
    $installed = (scoop export | ConvertFrom-Json).apps.Name -contains $package
    if ($installed) {
        Write-Host "Package $package is already installed" -ForegroundColor Green
        return $true
    }
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
        Write-Host "Downloading from: $($package.url)"
        & "$env:USERPROFILE\scoop\apps\wget\current\wget.exe" "$($package.url)" --output-document="$outputFile"
        if ($LASTEXITCODE -ne 0) {
            throw "wget failed with exit code $LASTEXITCODE"
        }
        
        if (Test-Path $outputFile) {
            Write-Host "Starting installation from: $outputFile"
            
            # Check if file is a ZIP archive
            if ($package.fileName -like "*.zip") {
                Write-Host "Opening ZIP file in Explorer for manual extraction and installation" -ForegroundColor Yellow
                Start-Process -FilePath "explorer.exe" -ArgumentList $outputFile
                Write-Host "Please extract and run the installer manually. Press any key when installation is complete..." -ForegroundColor Cyan
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Remove-Item -Path $outputFile -Force
                return $true
            }
            # Check if package should run interactively
            elseif ($package.interactive -eq $true) {
                Write-Host "Running interactive installation - please follow the installer prompts" -ForegroundColor Yellow
                Start-Process -FilePath $outputFile -Wait
            } else {
                # Default silent installation
                Start-Process -FilePath $outputFile -Wait -ArgumentList "/S"
            }
            
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

# Function to initialize winget sources
function Initialize-WingetSources {
    Write-Host "Initializing winget sources..." -ForegroundColor Cyan
    try {
        # Accept source agreements by running a simple list command
        $null = winget source list --accept-source-agreements 2>$null
        return $true
    } catch {
        Write-Warning "Could not initialize winget sources: $($_.Exception.Message)"
        return $false
    }
}

# Function to install winget package
function Install-WingetPackage($packageId) {
    Write-Host "Installing winget package: $packageId" -ForegroundColor Cyan
    try {
        # Check if winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "winget is not available. Please install App Installer from Microsoft Store."
            return $false
        }
        
        # Initialize sources if needed
        Initialize-WingetSources | Out-Null
        
        # Check if already installed
        $listResult = winget list --id $packageId --exact --accept-source-agreements 2>$null
        if ($LASTEXITCODE -eq 0 -and $listResult -match $packageId) {
            Write-Host "Package $packageId is already installed" -ForegroundColor Green
            return $true
        }
        
        # Install the package
        Write-Host "Installing $packageId from Microsoft Store..." -ForegroundColor Yellow
        winget install --id $packageId --accept-package-agreements --accept-source-agreements --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully installed $packageId" -ForegroundColor Green
            return $true
        } else {
            Write-Error "Failed to install $packageId (exit code: $LASTEXITCODE)"
            return $false
        }
    } catch {
        Write-Error "Failed to install winget package $packageId`: $($_.Exception.Message)"
        return $false
    }
}

# Function to uninstall winget package
function Uninstall-WingetPackage($packageId) {
    Write-Host "Uninstalling winget package: $packageId" -ForegroundColor Cyan
    try {
        # Check if winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "winget is not available. Cannot uninstall package."
            return $false
        }
        
        # Uninstall the package
        winget uninstall --id $packageId --silent
        return $LASTEXITCODE -eq 0
    } catch {
        Write-Error "Failed to uninstall winget package $packageId`: $($_.Exception.Message)"
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

# Function to install Microsoft Store package
function Install-MsStorePackage($packageId) {
    Write-Host "Installing Microsoft Store package: $packageId" -ForegroundColor Cyan
    try {
        # Open Microsoft Store page for the app
        Write-Host "Opening Microsoft Store for app ID: $packageId" -ForegroundColor Yellow
        Start-Process "ms-windows-store://pdp/?ProductId=$packageId"
        
        Write-Host "Microsoft Store opened. Please click 'Install' to proceed." -ForegroundColor Cyan
        Write-Host "Press any key after installation is complete..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        return $true
    } catch {
        Write-Error "Failed to open Microsoft Store for $packageId`: $($_.Exception.Message)"
        return $false
    }
}

# Function to uninstall Microsoft Store package
function Uninstall-MsStorePackage($packageId) {
    Write-Host "Uninstalling Microsoft Store package: $packageId" -ForegroundColor Cyan
    try {
        # Try to find the app by ProductId and uninstall via PowerShell
        $app = Get-AppxPackage | Where-Object { $_.PackageFullName -like "*$packageId*" -or $_.Name -like "*$packageId*" }
        if ($app) {
            Write-Host "Found app: $($app.Name)" -ForegroundColor Yellow
            Remove-AppxPackage -Package $app.PackageFullName
            Write-Host "App uninstalled successfully." -ForegroundColor Green
        } else {
            Write-Host "Microsoft Store app with ID $packageId not found or not installed" -ForegroundColor Yellow
        }
        
        # Wait for user confirmation like install does
        Write-Host "Press any key to confirm removal from package state..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        return $true  # Always return true to clean state after user confirmation
    } catch {
        Write-Error "Failed to uninstall Microsoft Store package $packageId`: $($_.Exception.Message)"
        # Still wait for user confirmation even on error
        Write-Host "Press any key to confirm removal from package state..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $true  # Return true to clean state
    }
}

# Function to install copy package
function Install-CopyPackage($package) {
    Write-Host "Copying package: $($package.name)" -ForegroundColor Cyan
    
    $outputFile = Join-Path $env:TEMP $package.fileName
    $binPath = Join-Path $env:USERPROFILE "Bin"
    
    try {
        # Create Bin directory if it doesn't exist
        if (-not (Test-Path $binPath)) {
            New-Item -ItemType Directory -Path $binPath -Force | Out-Null
        }

        $finalPath = Join-Path $binPath $package.fileName
        
        Write-Host "Downloading from: $($package.url)"
        & "$env:USERPROFILE\scoop\apps\wget\current\wget.exe" "$($package.url)" --output-document="$outputFile"
        if ($LASTEXITCODE -ne 0) {
            throw "wget failed with exit code $LASTEXITCODE"
        }
        
        if (Test-Path $outputFile) {
            Move-Item -Path $outputFile -Destination $finalPath -Force
            return $true
        } else {
            throw "Downloaded file not found at: $outputFile"
        }
    } catch {
        Write-Error "Failed to copy $($package.name): $_"
        return $false
    }
}

# Main script
try {
    $packages = Get-PackagesFromJson $packagesFile
    $state = Get-StateFromJson $stateFile
    $state = Initialize-StateWithExisting $state

    # Process all package types
    @('scoop', 'arbitrary', 'copy', 'winget', 'msstore', 'nodejs') | ForEach-Object {
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
            if ($packagesToUninstall.Count -gt 0) {
                if (-not $Force) {
                    Write-Host "The following $packageType packages will be uninstalled:" -ForegroundColor Yellow
                    foreach ($package in $packagesToUninstall) {
                        Write-Host "  - $($package.name)" -ForegroundColor Red
                    }
                    $confirmation = Read-Host "Do you want to continue? (y/N)"
                    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                        Write-Host "Uninstallation skipped." -ForegroundColor Cyan
                        continue
                    }
                }
                
                foreach ($package in $packagesToUninstall) {
                    Write-Host "Uninstalling $packageType package: $($package.name)" -ForegroundColor Yellow
                    $uninstallResult = Uninstall-ArbitraryPackage $package.name
                    if ($uninstallResult) {
                        $state.$packageType = @($state.$packageType | Where-Object { $_.name -ne $package.name })
                    }
                }
            }
        } elseif ($packageType -eq 'copy') {
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
                    $installResult = Install-CopyPackage $package
                    if ($installResult) {
                        $state.$packageType += @{ 
                            name = $package.name
                            installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                    }
                }
            }
            
            # Handle uninstallations (simply delete the file from Bin directory)
            if ($packagesToUninstall.Count -gt 0) {
                if (-not $Force) {
                    Write-Host "The following $packageType packages will be uninstalled:" -ForegroundColor Yellow
                    foreach ($package in $packagesToUninstall) {
                        Write-Host "  - $($package.name)" -ForegroundColor Red
                    }
                    $confirmation = Read-Host "Do you want to continue? (y/N)"
                    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                        Write-Host "Uninstallation skipped." -ForegroundColor Cyan
                        continue
                    }
                }
                
                foreach ($package in $packagesToUninstall) {
                    $binPath = Join-Path $env:USERPROFILE "Bin"
                    $filePath = Join-Path $binPath $package.fileName
                    if (Test-Path $filePath) {
                        Remove-Item -Path $filePath -Force
                        $state.$packageType = @($state.$packageType | Where-Object { $_.name -ne $package.name })
                    }
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
                    'winget' { Install-WingetPackage $package }
                    'msstore' { Install-MsStorePackage $package }
                    'nodejs' { Install-NodejsPackage $package }
                }
                if ($installResult) {
                    $state.$packageType += @{ 
                        name = $package
                        installedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
            }
            
            if ($packagesToUninstall.Count -gt 0) {
                if (-not $Force) {
                    Write-Host "The following $packageType packages will be uninstalled:" -ForegroundColor Yellow
                    foreach ($package in $packagesToUninstall) {
                        Write-Host "  - $package" -ForegroundColor Red
                    }
                    $confirmation = Read-Host "Do you want to continue? (y/N)"
                    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                        Write-Host "Uninstallation skipped." -ForegroundColor Cyan
                        continue
                    }
                }
                
                foreach ($package in $packagesToUninstall) {
                    Write-Host "Uninstalling $packageType package: $package" -ForegroundColor Yellow
                    $uninstallResult = switch ($packageType) {
                        'scoop' { Uninstall-ScoopPackage $package }
                        'winget' { Uninstall-WingetPackage $package }
                        'msstore' { Uninstall-MsStorePackage $package }
                        'nodejs' { Uninstall-NodejsPackage $package }
                    }
                    if ($uninstallResult) {
                        $state.$packageType = @($state.$packageType | Where-Object { $_.name -ne $package })
                    }
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
