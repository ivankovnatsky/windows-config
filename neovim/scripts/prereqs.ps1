# Save this file as UTF-8 with BOM
function Test-Prerequisites {
    $prerequisites = @{
        "git" = "git --version"
        "nvim" = "nvim --version"
        "nodejs" = "node --version"
        "ripgrep" = "rg --version"
        "gcc" = "gcc --version"
    }

    $allPresent = $true

    foreach ($prereq in $prerequisites.GetEnumerator()) {
        Write-Host "Checking for $($prereq.Key)..." -NoNewline
        if (Test-Command $prereq.Value) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " MISSING" -ForegroundColor Red
            if ($prereq.Key -eq "gcc") {
                Write-Host "Please install a C compiler (gcc). You can get it from:" -ForegroundColor Yellow
                Write-Host "- MSYS2 (recommended): https://www.msys2.org/" -ForegroundColor Yellow
                Write-Host "- MinGW: https://www.mingw-w64.org/" -ForegroundColor Yellow
            }
            $allPresent = $false
        }
    }

    return $allPresent
}

function Test-Command($command) {
    try {
        Invoke-Expression $command | Out-Null
        return $true
    } catch {
        return $false
    }
}
