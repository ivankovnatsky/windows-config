## Use environment variables to get the current user's AppData folder
$StartupFolder = [Environment]::GetFolderPath('Startup')
$FilePath = Join-Path -Path $StartupFolder -ChildPath "kinput.ahk"

## Create the AutoHotkey v2 script content
$ScriptContent = 'CapsLock::Send("{Alt Down}{Shift Down}{Shift Up}{Alt Up}")'

## Write the content to the file
Set-Content -Path $FilePath -Value $ScriptContent -Force

## Output the result
Write-Host "AutoHotkey v2 script created at: $FilePath"
