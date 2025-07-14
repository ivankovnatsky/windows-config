# Configuration for both Cursor and Windsurf editors
$editorConfig = @"
{
    "[nix]": {
        "editor.tabSize": 2
    },
    "diffEditor.ignoreTrimWhitespace": false,
    "diffEditor.renderSideBySide": false,
    "editor.lineNumbers": "relative",
    "editor.renderFinalNewline": "off",
    "editor.renderLineHighlight": "all",
    "extensions.autoCheckUpdates": false,
    "files.autoSave": "onFocusChange",
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "git.openRepositoryInParentFolders": "always",
    "scm.diffDecorations": "all",
    "update.mode": "none",
    "vim.relativeLineNumbers": true,
    "security.workspace.trust.enabled": false,
    "window.commandCenter": 1
}
"@

# Define editor configurations
$editors = @(
    @{
        Name = "Cursor"
        ConfigPath = "$HOME\AppData\Roaming\Cursor\User\settings.json"
        CliCommand = "cursor"
    },
    @{
        Name = "Windsurf"
        ConfigPath = "$HOME\AppData\Roaming\Windsurf\User\settings.json"
        CliCommand = "windsurf"
    }
)

# Extensions to install
$extensions = @(

)

# Process each editor
foreach ($editor in $editors) {
    $configDir = Split-Path $editor.ConfigPath -Parent
    
    if (Test-Path $configDir) {
        Write-Host "Configuring $($editor.Name)..." -ForegroundColor Green
        
        # Ensure the User directory exists
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Write configuration
        $editorConfig | Out-File -FilePath $editor.ConfigPath -Encoding utf8
        Write-Host "Configuration written to: $($editor.ConfigPath)" -ForegroundColor Cyan
        
        # Check if CLI command is available
        $cliAvailable = Get-Command $editor.CliCommand -ErrorAction SilentlyContinue
        if ($cliAvailable) {
            Write-Host "Installing extensions for $($editor.Name)..." -ForegroundColor Yellow
            foreach ($extension in $extensions) {
                Write-Host "Installing: $extension" -ForegroundColor Gray
                try {
                    Start-Process -FilePath $editor.CliCommand -ArgumentList "--install-extension $extension" -Wait -NoNewWindow
                    Write-Host "Installed: $extension" -ForegroundColor Green
                } catch {
                    Write-Host "Failed to install: $extension - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "CLI command '$($editor.CliCommand)' not found. Extensions not installed." -ForegroundColor Yellow
            Write-Host "You can install extensions manually or ensure the CLI is in your PATH." -ForegroundColor Gray
        }
    } else {
        Write-Host "$($editor.Name) directory not found: $configDir" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
