# https://www.reddit.com/r/PowerShell/comments/125nvon/adjust_power_mode_slider_in_windows_10/
# Power Mode Management Functions
function Get-Current-Power-Mode-ID {
    $function = @'
[DllImport("powrprof.dll", EntryPoint="PowerGetEffectiveOverlayScheme")]
public static extern int PowerGetEffectiveOverlayScheme(out Guid EffectiveOverlayGuid);
'@
    $power = Add-Type -MemberDefinition $function -Name "Power" -PassThru -Namespace System.Runtime.InteropServices
    $effectiveOverlayGuid = [Guid]::Empty
    $ret = $power::PowerGetEffectiveOverlayScheme([ref]$effectiveOverlayGuid)
    if ($ret -eq 0) {
        return $effectiveOverlayGuid
    } else {
        Write-Error "Failed to get the current power mode profile ID. Error code: $ret"
        return $null
    }
}

function Set-Power-Mode-By-GUID {
    param (
        [Guid]$guid
    )
    $function = @'
    [DllImport("powrprof.dll", EntryPoint="PowerSetActiveOverlayScheme")]
    public static extern int PowerSetActiveOverlayScheme(Guid OverlaySchemeGuid);
'@
    $power = Add-Type -MemberDefinition $function -Name "Power" -PassThru -Namespace MyNamespace.PowerModeManager
    $ret = $power::PowerSetActiveOverlayScheme($guid)
    if ($ret -ne 0) {
        Write-Error "Failed to set the power mode profile ID. Error code: $ret"
    }
}

# Define the known power mode GUIDs
$Global:PowerModes = @{
    "Best power efficiency" = [guid]"961cc777-2547-4f9d-8174-7d86181b8a7a"
    "Balanced"              = [guid]"00000000-0000-0000-0000-000000000000"
    "Best performance"      = [guid]"ded574b5-45a0-4f42-8737-46345c09c238"
}

function Set-Power-Mode {
    param (
        [ValidateSet('Best power efficiency', 'Balanced', 'Best performance')]
        [string]$Mode
    )
    $guid = $Global:PowerModes[$Mode]
    if ($guid) {
        Set-Power-Mode-By-GUID -guid $guid
        Write-Host "Power mode set to: $Mode"
    } else {
        Write-Error "Failed to find GUID for mode: $Mode"
    }
}

function Get-Current-Power-Mode {
    $currentModeGuid = Get-Current-Power-Mode-ID
    if ($null -eq $currentModeGuid) {
        return "Unknown"
    }
    $currentMode = $Global:PowerModes.GetEnumerator() | Where-Object { $_.Value -eq $currentModeGuid } | Select-Object -ExpandProperty Key
    if ($currentMode) {
        return $currentMode
    } else {
        Write-Warning "Unable to map GUID to a known power mode. Current GUID: $currentModeGuid"
        return "Unknown (GUID: $currentModeGuid)"
    }
}

function Get-Available-Power-Modes {
    $currentModeGuid = Get-Current-Power-Mode-ID
    
    foreach ($mode in $Global:PowerModes.Keys) {
        [PSCustomObject]@{
            Mode = $mode
            GUID = $Global:PowerModes[$mode]
            IsActive = $Global:PowerModes[$mode] -eq $currentModeGuid
        }
    }
}

function Show-Usage {
    Write-Host "Usage: $($MyInvocation.ScriptName) [command]"
    Write-Host "Commands:"
    Write-Host "  list                 List all available power modes (default if no command is provided)"
    Write-Host "  set <mode>           Set power mode (modes: efficiency/silent, balanced, performance)"
    Write-Host "  help                 Show this help message"
    Write-Host "  debug                Show current mode with additional debug information"
    Write-Host ""
    Write-Host "Note: 'silent' is an alias for 'efficiency' mode"
}

# Main script logic
$command = $args[0]
$mode = $args[1]

switch ($command) {
    "list" {
        Get-Available-Power-Modes | Format-Table
    }
    "set" {
        switch ($mode) {
            { $_ -in "efficiency", "silent" } { Set-Power-Mode -Mode "Best power efficiency" }
            "balanced" { Set-Power-Mode -Mode "Balanced" }
            "performance" { Set-Power-Mode -Mode "Best performance" }
            default {
                Write-Error "Invalid mode. Use 'efficiency' (or 'silent'), 'balanced', or 'performance'."
                Show-Usage
                exit 1
            }
        }
    }
    { $_ -in "help", "--help", "/?" } {
        Show-Usage
        exit 0
    }
    "debug" {
        $currentModeGuid = Get-Current-Power-Mode-ID
        $currentMode = Get-Current-Power-Mode
        Write-Host "Current power mode: $currentMode"
        Write-Host "Debug Information:"
        Write-Host "Current GUID: $currentModeGuid"
        Write-Host "Known GUIDs:"
        $Global:PowerModes.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)"
        }
    }
    "" {
        # Default behavior: show current mode and list available modes
        $currentMode = Get-Current-Power-Mode
        Write-Host "Current power mode: $currentMode"
        Write-Host ""
        Get-Available-Power-Modes | Format-Table
    }
    default {
        Write-Error "Unknown command: $command"
        Show-Usage
        exit 1
    }
}
