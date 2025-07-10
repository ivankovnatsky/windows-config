# a3w System Configuration

## Windows Installation

### Network Bypass

#### OOBE Network Requirement Bypass

- Windows could not connect to internet during installation (missing LAN drivers)
- Used bypass command to continue installation without network connection
- Command: `Shift + F10` → `oobe\bypassnro`
- Allows completing Windows setup offline

## BIOS Settings

### Memory Configuration

#### EXPO Profile

- Enabled to match RAM's maximum rated speed

### Security Settings

#### Secure Boot

- Disabled
- Changed from "Windows UEFI mode" to "Other OS"
- Removed all secure boot keys during initial Linux installation
- Required for dual-boot compatibility and Linux installation