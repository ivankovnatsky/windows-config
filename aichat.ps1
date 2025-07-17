# Configure aichat with local Ollama/Llama integration
# Based on the Nix configuration but simplified for Windows with only local LLM

# Remove old config if it exists in wrong location
$oldConfigDir = "$env:USERPROFILE\.config\aichat"
if (Test-Path $oldConfigDir) {
    Remove-Item -Path $oldConfigDir -Recurse -Force
    Write-Host "Removed old config from: $oldConfigDir" -ForegroundColor Yellow
}

# Create aichat config directory in correct Windows location
$configDir = "$env:APPDATA\aichat"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    Write-Host "Created aichat config directory: $configDir" -ForegroundColor Green
}

# Create aichat configuration file
$configPath = Join-Path $configDir "config.yaml"

$configContent = @"
# ---- behavior ----
stream: true
save: true
save_session: true
highlight: true
keybindings: vi
editor: nvim

# ---- clients ----
clients:
  - type: openai-compatible
    name: ollama
    api_base: http://localhost:11434/v1
    models:
      - name: llama4:scout
        max_input_tokens: 13107
      - name: llama3.3:70b
        max_input_tokens: 13107
      - name: gemma3:27b
        max_input_tokens: 13107
      - name: gemma3:12b
        max_input_tokens: 13107
      - name: llama3.1:8b
        max_input_tokens: 13107
"@

# Write configuration to file with proper encoding
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.Encoding]::UTF8)
Write-Host "Created aichat config: $configPath" -ForegroundColor Green
