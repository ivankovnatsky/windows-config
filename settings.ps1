[CmdletBinding()]
param(
    [switch]$Languages,
    [switch]$Taskbar,
    [switch]$Mouse,
    [switch]$Dark,
    [switch]$Wallpaper,
    [switch]$LockScreen,
    [switch]$All,
    [string]$WallpaperColor = "0 0 0"  # Default is black, format: "R G B"
)

# Define constants for languages to install
$LANGUAGES_TO_INSTALL = @(
    "uk-UA"
)

# Function to add language inputs
function Add-Languages {
    Write-Host "Adding language inputs..." -ForegroundColor Green

    try {
        $LanguageList = Get-WinUserLanguageList
        $ChangesNeeded = $false
        
        foreach ($LangCode in $LANGUAGES_TO_INSTALL) {
            # Check if language is already installed
            if ($LanguageList.LanguageTag -contains $LangCode) {
                Write-Host "$LangCode language is already installed!" -ForegroundColor Yellow
                continue
            }

            # Add language
            $LanguageList.Add($LangCode)
            $ChangesNeeded = $true
            Write-Host "Added $LangCode language to installation list" -ForegroundColor Green
        }

        if ($ChangesNeeded) {
            Set-WinUserLanguageList $LanguageList -Force
            Write-Host "Languages have been successfully added!" -ForegroundColor Green
            Write-Host "Note: You may need to log out and log back in for changes to take full effect." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Error: Failed to add language inputs" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# Function to configure taskbar settings
function Set-TaskbarSettings {
    Write-Host "Configuring taskbar settings..." -ForegroundColor Green
    
    try {
        # Disable Search icon/box on taskbar
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        
        # Disable Task View button
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        
        # Disable Widgets
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        
        Write-Host "Taskbar settings applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to configure taskbar settings" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Function to configure mouse settings
function Set-MouseSettings {
    Write-Host "Configuring mouse settings..." -ForegroundColor Green
    
    try {
        # Set mouse speed (range 1-20, default is 10)
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "5"
        Write-Host "Mouse settings applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to configure mouse settings" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Function to configure dark mode settings
function Set-DarkMode {
    Write-Host "Configuring dark mode settings..." -ForegroundColor Green
    
    try {
        # Enable dark mode for system
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
        
        # Enable dark mode for apps
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        
        Write-Host "Dark mode settings applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to configure dark mode settings" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Function to set dark wallpaper
function Set-DarkWallpaper {
    Write-Host "Setting background color..." -ForegroundColor Green
    
    try {
        # Validate color format
        if ($WallpaperColor -notmatch '^\d{1,3}\s+\d{1,3}\s+\d{1,3}$') {
            Write-Host "Error: Invalid color format. Use 'R G B' format (e.g., '0 0 0' for black, '255 255 255' for white)" -ForegroundColor Red
            return
        }
        
        # Set solid color as background
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallPaper" -Value ""
        Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value $WallpaperColor
        
        # Enable solid color background
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value $WallpaperColor
        
        Write-Host "Background color set to: $WallpaperColor" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to set background color" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Set-LockScreenSettings {
    Write-Host "Configuring lock screen settings..." -ForegroundColor Green
    
    try {
        # Disable Windows Spotlight (tips, suggestions)
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Value 0
        
        # Set solid color for lock screen
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableLogonBackgroundImage" -Value 1
        
        # Disable fun facts, tips, and tricks
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0
        
        Write-Host "Lock screen settings applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to configure lock screen settings" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Main function to run all settings
function Initialize-Settings {
    # If no parameters specified, show help
    if (-not ($Languages -or $Taskbar -or $Mouse -or $Dark -or $Wallpaper -or $LockScreen -or $All)) {
        Write-Host "Please specify which settings to initialize using these flags:" -ForegroundColor Cyan
        Write-Host "-Languages   : Configure language settings" -ForegroundColor Yellow
        Write-Host "-Taskbar    : Configure taskbar settings" -ForegroundColor Yellow
        Write-Host "-Mouse      : Configure mouse settings" -ForegroundColor Yellow
        Write-Host "-Dark       : Configure dark mode" -ForegroundColor Yellow
        Write-Host "-Wallpaper  : Set dark background color" -ForegroundColor Yellow
        Write-Host "-LockScreen : Configure lock screen settings" -ForegroundColor Yellow
        Write-Host "-All        : Apply all settings" -ForegroundColor Yellow
        return
    }

    Write-Host "Initializing Windows settings..." -ForegroundColor Cyan
    
    if ($All) {
        Add-Languages
        Set-TaskbarSettings
        Set-MouseSettings
        Set-DarkMode
        Set-DarkWallpaper
        Set-LockScreenSettings
    } else {
        if ($Languages) { Add-Languages }
        if ($Taskbar) { Set-TaskbarSettings }
        if ($Mouse) { Set-MouseSettings }
        if ($Dark) { Set-DarkMode }
        if ($Wallpaper) { Set-DarkWallpaper }
        if ($LockScreen) { Set-LockScreenSettings }
    }
    
    Write-Host "Settings initialization complete!" -ForegroundColor Cyan
    Write-Host "Note: Some settings may require a system restart to take full effect." -ForegroundColor Yellow
}

# Run the main function
Initialize-Settings 
