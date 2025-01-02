# Define constants for languages to install
$LANGUAGES_TO_INSTALL = @(
    "uk-UA",
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

# Main function to run all settings
function Initialize-Settings {
    Write-Host "Initializing Windows settings..." -ForegroundColor Cyan
    
    # Add settings functions here
    Add-Languages
    
    # Future settings can be added here
    # Set-SomeOtherSetting
    # Configure-AnotherThing
    
    Write-Host "Settings initialization complete!" -ForegroundColor Cyan
}

# Run the main function
Initialize-Settings 
