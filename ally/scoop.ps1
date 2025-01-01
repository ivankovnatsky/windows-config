$scoopConfig = @"
{
    "aria2-enabled": false,
    "aria2-warning-enabled": false,
    "last_update": "2024-01-01T00:00:00.0000000+00:00",
    "SCOOP_REPO": "https://github.com/ScoopInstaller/Scoop",
    "SCOOP_BRANCH": "master"
}
"@

$scoopConfig | Out-File -FilePath "$HOME\.config\scoop\config.json" -Encoding utf8
