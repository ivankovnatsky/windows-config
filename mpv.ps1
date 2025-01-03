$mpvConfig = @"
# Force seekable files even for HTTP streams
force-seekable=yes

# Prefer English audio and subtitles
alang=eng,en
slang=eng,en

# Use filesystem-based seeking (more accurate/reliable)
demuxer-seekable-cache=yes

# Other common useful settings
keep-open=yes                    # Don't close player after video ends
save-position-on-quit=yes       # Remember position when closing video
hwdec=auto                      # Enable hardware decoding
"@

# Create MPV config directory if it doesn't exist
$mpvConfigDir = "$HOME\scoop\persist\mpv\portable_config"
if (-not (Test-Path $mpvConfigDir)) {
    New-Item -ItemType Directory -Path $mpvConfigDir -Force
}

# Write the configuration
$mpvConfig | Out-File -FilePath "$mpvConfigDir\mpv.conf" -Encoding utf8
