$cursorConfig = @"
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

$cursorConfig | Out-File -FilePath "$HOME\AppData\Roaming\Cursor\User\settings.json" -Encoding utf8 
