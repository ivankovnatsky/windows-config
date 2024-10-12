# Define paths
$packagesFile = "packages.txt"
$stateFile = "state.txt"

# Function to read packages from a file and sort them
function Get-SortedPackagesFromFile($filePath) {
    return Get-Content -Path $filePath | 
           Where-Object { $_.Trim() -ne "" } | 
           ForEach-Object { $_.Trim() } | 
           Sort-Object
}

# Read and sort desired packages
$desiredPackages = Get-SortedPackagesFromFile $packagesFile
Write-Host "Desired packages: $($desiredPackages -join ', ')"

# Read and sort current state
if (Test-Path $stateFile) {
    $installedPackages = Get-SortedPackagesFromFile $stateFile
    Write-Host "Currently installed packages: $($installedPackages -join ', ')"
} else {
    $installedPackages = @()
    Write-Host "No state file found. Assuming no packages are installed."
}

# Determine packages to install and uninstall
$packagesToInstall = $desiredPackages | Where-Object { $_ -notin $installedPackages }
$packagesToUninstall = $installedPackages | Where-Object { $_ -notin $desiredPackages }

# Install missing packages
if ($packagesToInstall.Count -gt 0) {
    Write-Host "Installing packages: $($packagesToInstall -join ', ')"
    foreach ($package in $packagesToInstall) {
        scoop install $package
        if ($LASTEXITCODE -eq 0) {
            $installedPackages += $package
        } else {
            Write-Host "Failed to install $package" -ForegroundColor Red
        }
    }
}

# Uninstall extra packages
if ($packagesToUninstall.Count -gt 0) {
    Write-Host "Uninstalling packages: $($packagesToUninstall -join ', ')"
    foreach ($package in $packagesToUninstall) {
        scoop uninstall $package
        if ($LASTEXITCODE -eq 0) {
            $installedPackages = $installedPackages | Where-Object { $_ -ne $package }
        } else {
            Write-Host "Failed to uninstall $package" -ForegroundColor Red
        }
    }
}

# Update state file with sorted list
$installedPackages | Sort-Object | Set-Content $stateFile

if ($packagesToInstall.Count -eq 0 -and $packagesToUninstall.Count -eq 0) {
    Write-Host "All packages are up to date. No changes needed." -ForegroundColor Green
} else {
    Write-Host "Package synchronization complete." -ForegroundColor Green
}

# Final verification
$mismatchedPackages = Compare-Object ($desiredPackages | Sort-Object) ($installedPackages | Sort-Object)
if ($mismatchedPackages) {
    Write-Host "Warning: Discrepancy between desired packages and actual installed packages:" -ForegroundColor Yellow
    $mismatchedPackages | ForEach-Object {
        Write-Host "  $($_.InputObject) is $('in desired list' * ($_.SideIndicator -eq '<=')) $('actually installed' * ($_.SideIndicator -eq '=>'))" -ForegroundColor Yellow
    }
} else {
    Write-Host "All packages are in sync with the desired state." -ForegroundColor Green
}
