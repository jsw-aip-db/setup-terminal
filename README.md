# setup-terminal

A PowerShell script that sets up a **Starship**-powered terminal environment on Windows for both PowerShell and cmd.exe.

## What it does

| Step | Action |
|------|--------|
| 1 | Installs **Cascadia Code NF** (Nerd Font) for the current user |
| 2 | Installs **Starship** prompt via `winget` |
| 3 | Writes a default **starship.toml** config (if none exists) |
| 4 | Configures the **PowerShell profile** to initialize Starship |
| 5 | Installs **Clink** via `winget` (enables Starship in cmd.exe) |
| 6 | Configures **Clink** to load Starship at cmd.exe startup |
| 7 | Sets **CaskaydiaCove Nerd Font** as the default font in Windows Terminal |

## Requirements

- Windows 10/11
- [winget](https://aka.ms/winget) (comes pre-installed on Windows 11 and recent Windows 10 builds)
- PowerShell 5.1 or later
- Internet access (to download the font and packages)

> **No administrator rights required.** Everything is installed for the current user.

## Usage

```powershell
.\setup-terminal.ps1
```

The script is **idempotent** — safe to run multiple times. Already-completed steps are skipped.

## After running

- **PowerShell**: Starship activates automatically on next launch.
- **cmd.exe**: Make sure Clink auto-inject is enabled (it injects into cmd at startup).
- **Windows Terminal**: Relaunch to see the new font.
- **Customize Starship**: https://starship.rs/config/

## Links

- [Starship](https://starship.rs/)
- [Clink](https://chrisant996.github.io/clink/)
- [Nerd Fonts – Cascadia Code](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/CascadiaCode)
- [Windows Terminal](https://github.com/microsoft/terminal)
