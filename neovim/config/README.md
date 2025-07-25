# 💤 LazyVim Configuration

This is a customized [LazyVim](https://github.com/LazyVim/LazyVim) configuration synced from the [windows-config](https://github.com/ivankovnatsky/windows-config) repository.

## 🔄 Configuration Management

**⚠️ Important:** This directory is automatically synced from `windows-config\neovim\config\`. 

- **Source of Truth:** `windows-config\neovim\config\`
- **Active Config:** `%LOCALAPPDATA%\nvim\` (this directory)
- **Sync Command:** Run `windows-config\neovim\sync.ps1`

### Workflow:

1. Edit configs in `windows-config\neovim\config\`
2. Run `windows-config\neovim\sync.ps1` to sync changes
3. Test in Neovim
4. Commit changes to windows-config repo

## 📋 Prerequisites

Ensure these packages are installed via Scoop (included in `windows-config\packages\a3w\packages.json`):

- `neovim` - The editor itself
- `nodejs` - Required for many LSP servers and plugins
- `mingw` - C compiler for native extensions
- `git` - Version control
- `ripgrep` - Fast text search (already included)

## 🚀 Installation

1. Install prerequisites: `windows-config\packages\install.ps1`
2. Sync config: `windows-config\neovim\sync.ps1`
3. Start Neovim: `nvim`
4. Check health: `:LazyHealth`

## 📚 Documentation

Refer to the [LazyVim documentation](https://lazyvim.github.io/installation) for general usage and configuration options.
