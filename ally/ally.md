# Ally

## Terminal

Install scoop:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

```powershell
scoop install git
scoop bucket add extas
```

This is needed once:

```powershell
scoop install windowsdesktop-runtime
scoop uninstall windowsdesktop-runtime
```

Enable hibernate

```powershell
powercfg /hibernate on
shutdown /h /t 0 -- Run hibernate
```

## Manual

* Increase scale to 200%
* Enable night shift
* Enable restore previous tabs and windows in Firefox
* Install MSI Afterburner manually

## Windows

* Change to Black Wallpaper
* Apply all Energy recommendations under System -> Power & Battery
  * Had to do that for all 3 power modes
* Create Black screenshot and set for lock screen
* Disabled all shenanigans, like weather and all (Widgets)
* Disabled task view -- ability to create desktops
* Disabled some startup apps in Task Manager
* Lower down mouse pointer speed
* Add a shortcut of Programs from Start Menu
* Added two fingers as sign-in security option
* Make sure Windows not asking password right away every time (15m timeout):
  https://answers.microsoft.com/en-us/windows/forum/all/after-sleep-windows-11-does-not-ask-for-password/ac527b5e-dd84-4edb-a435-03df82aca692.

## Drivers

* CalDigit TS4 -- https://downloads.caldigit.com/,

```powershell
cd ~\Downloads\
~\scoop\apps\wget\current\wget.exe https://downloads.caldigit.com/TS4/TS4-Windows-Ethernet-Driver.zip
```

## G-Helper

* Also used a feature to charge limit to 80%, this was before I figured option in MyASUS

## MyASUS

* Configured to limit battery charging to 80% (Battery Care Mode)

## General

* Logged in to live.com account
* Supplied asus.com email account for asus login, but probably did not login yet
* Using Armoury Crate logged in to Steam

## Taskbar 

* Disable Armoury Crate auto start, in fact it prevents normal restarts and
  sign outs, making the system stuck
* Disable Copilot preview in taskbar settings


## Armoury shit

(This is not the case anymore, so consider removing it when the real reason is found)

It seems it hangs on restarts, so probably these services are not the main cause.

```powershell
Set-Service -Name ArmouryCrateControlInterface -StartupType Manual -- Was Automatic
Set-Service -Name ArmouryCrateSEService -StartupType Manual -- Was Automatic and Running

net stop ArmouryCrateControlInterface
net stop ArmouryCrateSEService
```

Reverted back to using Crate again. 

* Disabled splash animation screen

## NextDNS

Under admin user:

https://github.com/nextdns/nextdns/wiki/Windows.

```powershell
nextdns.exe install `
  -config [redacted] `
  -report-client-info `
  -auto-activate
```

## BIOS

* Disabled startup sound -- https://www.reddit.com/r/ROGAlly/comments/1asfmp1/hot_tip_turn_off_the_startup_sound/

## TODO:

* Disable C-V in Windows-Terminal
* Add MSI Afterburner to scoop packages -- https://github.com/ScoopInstaller/Extras/issues/14186
   * Tweaked to show only FPS
      * Override group name, set dot symbol
      * Under show on-screen display tweak ... Options
        * Sizes library set both to 0%
        * Value alignment set Frame rate to default
* Optimize Windows components uninstall/disable services and other not needed stuff
* Configure Alt <-> Win key swap (Probably in autohotkey)
