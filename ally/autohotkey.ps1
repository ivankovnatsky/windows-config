## Define constants and important variables
$StartupFolder = [Environment]::GetFolderPath('Startup')
$OldFilePath = Join-Path -Path $StartupFolder -ChildPath "kinput.ahk"
$NewFilePath = Join-Path -Path $StartupFolder -ChildPath "keyboard.ahk"

$AutoHotkeyPath = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"

## Rename the file if it exists, but handle the case where the new file already exists
if (Test-Path $OldFilePath) {
    if (Test-Path $NewFilePath) {
        Remove-Item -Path $NewFilePath -Force
        Write-Host "Removed existing keyboard.ahk file"
    }
    Rename-Item -Path $OldFilePath -NewName "keyboard.ahk" -Force
    Write-Host "Renamed existing file from kinput.ahk to keyboard.ahk"
} elseif (Test-Path $NewFilePath) {
    Write-Host "keyboard.ahk already exists, skipping rename"
} else {
    Write-Host "No existing kinput.ahk or keyboard.ahk found"
}

## Create the AutoHotkey v2 script content
$ScriptContent = @'
#Requires AutoHotkey v2.0

; Swap Alt and Win keys
LAlt::LWin
LWin::LAlt
RAlt::RWin
RWin::RAlt

; Original CapsLock remapping
CapsLock::Send("{Alt Down}{Shift Down}{Shift Up}{Alt Up}")
'@

## Write the content to the file
Set-Content -Path $NewFilePath -Value $ScriptContent -Force

## Output the result
Write-Host "AutoHotkey v2 script created at: $NewFilePath"

## Restart AutoHotkey with the new script
Write-Host "AutoHotkey Path: $AutoHotkeyPath"
Write-Host "Script Path: $NewFilePath"

if (Test-Path $AutoHotkeyPath) {
    # Stop any running instances of AutoHotkey
    $stoppedProcesses = Get-Process -Name "AutoHotkey*" -ErrorAction SilentlyContinue | Stop-Process -PassThru
    if ($stoppedProcesses) {
        Write-Host "Stopped $($stoppedProcesses.Count) AutoHotkey processes"
    } else {
        Write-Host "No running AutoHotkey processes found to stop"
    }
    
    # Debug: Check if the script file exists
    if (Test-Path $NewFilePath) {
        Write-Host "Script file found at: $NewFilePath"
        Write-Host "File contents:"
        Get-Content $NewFilePath
    } else {
        Write-Host "Error: Script file not found at $NewFilePath"
    }
    
    # Start AutoHotkey with the new script
    try {
        $process = Start-Process -FilePath $AutoHotkeyPath -ArgumentList "`"$NewFilePath`"" -PassThru -NoNewWindow
        Write-Host "AutoHotkey started with PID: $($process.Id)"
        Write-Host "Command line: $AutoHotkeyPath `"$NewFilePath`""
    } catch {
        Write-Host "Error starting AutoHotkey: $_"
    }
} else {
    Write-Host "AutoHotkey executable not found at $AutoHotkeyPath. Please check the path and update if necessary."
}

# Wait a moment to see if the process stays running
Start-Sleep -Seconds 2
$runningProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
if ($runningProcess) {
    Write-Host "AutoHotkey is still running after 2 seconds."
} else {
    Write-Host "AutoHotkey process has already exited. Check for errors."
}
