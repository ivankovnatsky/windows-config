# Terminal

```console
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

```console
scoop install git
scoop bucket add extas
```

This is needed once:

```console
scoop install windowsdesktop-runtime
scoop uninstall windowsdesktop-runtime
```

Enable hibernate

```console
powercfg /hibernate on
shutdown /h /t 0 -- Run hibernate
```

# Manual

* Increase scale to 200%
* Enable night shift
* Enable restore previous tabs and windows in Firefox
* Install MSI Afterburner manually

# Windows

* Change to Black Wallpaper
* Create Black screenshot and set for lock screen
* Disabled all shenenigans, like weather and all (Widgets)
* Disabled task view -- ability to create desktops
* Disabled some startup apps in Task Manager
* Lower down mouse pointer speed
* Added two fingers as sign-in security option
* Make sure Windows not asking password right away every time:
  https://answers.microsoft.com/en-us/windows/forum/all/after-sleep-windows-11-does-not-ask-for-password/ac527b5e-dd84-4edb-a435-03df82aca692.

TODO:

* Disable C-V in Windows-Terminal
* Add MSI Afterburner to scoop packages -- https://github.com/ScoopInstaller/Extras/issues/14186

# General

* Logged in to live.com account
* Supplied asus.com email account for asus login, but probably did not login yet
* Using Armoury Crate logged in to Steam

# Taskbar 

* Disable Armoury Crate auto start, in fact it prevents normal restarts and
  sign outs, making the system stuck
* Disable Copilot preview in taskbar settings


# Armoury shit

It seems hangs on restarts, so probably these services are not the main cause.

```console
Set-Service -Name ArmouryCrateControlInterface -StartupType Manual -- Was Automatic
Set-Service -Name ArmouryCrateSEService -StartupType Manual -- Was Automatic and Running

net stop ArmouryCrateControlInterface
net stop ArmouryCrateSEService
```

# NextDNS

Under admin user:

https://github.com/nextdns/nextdns/wiki/Windows.

```console
nextdns.exe install `
  -config [redacted] `
  -report-client-info `
  -auto-activate
```

# BIOS

* Disabled startup sound -- https://www.reddit.com/r/ROGAlly/comments/1asfmp1/hot_tip_turn_off_the_startup_sound/

# Autohotkey

```console
# Use environment variables to get the current user's AppData folder
$StartupFolder = [Environment]::GetFolderPath('Startup')
$FilePath = Join-Path -Path $StartupFolder -ChildPath "kinput.ahk"

# Create the AutoHotkey v2 script content
$ScriptContent = 'CapsLock::Send("{Alt Down}{Shift Down}{Shift Up}{Alt Up}")'

# Write the content to the file
Set-Content -Path $FilePath -Value $ScriptContent -Force

# Output the result
Write-Host "AutoHotkey v2 script created at: $FilePath"
```
