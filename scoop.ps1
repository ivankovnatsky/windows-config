$scoopConfig = @"
{
    "aria2-enabled": true,
    "aria2-warning-enabled": false,
    "last_update":  "2025-07-16T20:45:11.7248964+03:00",
    "scoop_repo":  "https://github.com/ScoopInstaller/Scoop",
    "scoop_branch":  "master"
}
"@

$scoopConfig | Out-File -FilePath "$HOME\.config\scoop\config.json" -Encoding utf8
