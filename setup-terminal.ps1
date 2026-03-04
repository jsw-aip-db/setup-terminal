#Requires -Version 5.1
<#
.SYNOPSIS
    Sets up a Starship-powered terminal environment for PowerShell and cmd.exe.

.DESCRIPTION
    - Installs Cascadia Code NF (Nerd Font) for the current user
    - Installs Starship prompt via winget
    - Configures the PowerShell profile to initialize Starship
    - Installs Clink via winget (enables Starship in cmd.exe)
    - Configures Clink to load Starship on cmd.exe startup
    - Sets CaskaydiaCove Nerd Font as the default font in Windows Terminal

.NOTES
    No administrator rights required. Safe to run multiple times (idempotent).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Done {
    param([string]$Message = 'Done.')
    Write-Host "    $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "    SKIP: $Message" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────
# 1. Prerequisites check
# ─────────────────────────────────────────────
Write-Step "Checking prerequisites"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget is not available. Please install the App Installer from the Microsoft Store and re-run."
    exit 1
}

Write-Done "winget is available."

# ─────────────────────────────────────────────
# 2. Install Cascadia Code NF (Nerd Font)
# ─────────────────────────────────────────────
Write-Step "Installing Cascadia Code NF font (current user)"

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir -Force | Out-Null }

# Check if already installed
$existingFonts = Get-Item "$fontDir\CaskaydiaCode*" -ErrorAction SilentlyContinue
if ($existingFonts) {
    Write-Skip "CaskaydiaCove Nerd Font files already present in $fontDir"
} else {
    # Fetch latest release tag from GitHub
    $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
    Write-Host "    Fetching latest Nerd Fonts release info..."
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $tag = $release.tag_name

    $zipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/CascadiaCode.zip"
    $zipPath = Join-Path $env:TEMP "CascadiaCode.zip"
    $extractPath = Join-Path $env:TEMP "CascadiaCode"

    Write-Host "    Downloading $zipUrl ..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "    Extracting..."
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Install only the NF (Nerd Font) variants, skip Windows-Compatible and Mono if desired
    $fontFiles = Get-ChildItem -Path $extractPath -Filter "*.ttf" | Where-Object { $_.Name -notlike "*WindowsCompatible*" }

    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    foreach ($font in $fontFiles) {
        $destFile = Join-Path $fontDir $font.Name
        Copy-Item -Path $font.FullName -Destination $destFile -Force

        # Register in per-user font registry
        $fontName = $font.BaseName -replace '-', ' '
        Set-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $destFile -Force
    }

    # Cleanup
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    Write-Done "Cascadia Code NF installed ($($fontFiles.Count) font files)."
}

# ─────────────────────────────────────────────
# 3. Install Starship via winget
# ─────────────────────────────────────────────
Write-Step "Installing Starship prompt"

$starshipInstalled = Get-Command starship -ErrorAction SilentlyContinue
if ($starshipInstalled) {
    Write-Skip "Starship is already installed at $($starshipInstalled.Source)"
} else {
    winget install --id Starship.Starship --scope user --silent --accept-package-agreements --accept-source-agreements
    Write-Done "Starship installed."
}

# ─────────────────────────────────────────────
# 4. Configure PowerShell profile
# ─────────────────────────────────────────────
Write-Step "Configuring PowerShell profile"

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE))    { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

$initLine = 'Invoke-Expression (&starship init powershell)'
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -match [regex]::Escape($initLine)) {
    Write-Skip "Starship init already present in $PROFILE"
} else {
    Add-Content -Path $PROFILE -Value "`n$initLine"
    Write-Done "Added Starship init to $PROFILE"
}

# ─────────────────────────────────────────────
# 5. Install Clink via winget
# ─────────────────────────────────────────────
Write-Step "Installing Clink (for Starship in cmd.exe)"

$clinkExe = Get-Command clink -ErrorAction SilentlyContinue
if ($clinkExe) {
    Write-Skip "Clink is already installed at $($clinkExe.Source)"
} else {
    winget install --id chrisant996.Clink --scope user --silent --accept-package-agreements --accept-source-agreements
    Write-Done "Clink installed."
}

# ─────────────────────────────────────────────
# 6. Configure Clink to load Starship
# ─────────────────────────────────────────────
Write-Step "Configuring Clink to use Starship"

$clinkDir = Join-Path $env:LOCALAPPDATA "clink"
if (-not (Test-Path $clinkDir)) { New-Item -ItemType Directory -Path $clinkDir -Force | Out-Null }

$starshipLua = Join-Path $clinkDir "starship.lua"
$luaContent = @'
-- Load Starship prompt in cmd.exe via Clink
load(io.popen('starship init cmd'):read("*a"))()
'@

if (Test-Path $starshipLua) {
    $existing = Get-Content $starshipLua -Raw
    if ($existing -match 'starship init cmd') {
        Write-Skip "Clink starship.lua already configured."
    } else {
        Add-Content -Path $starshipLua -Value "`n$luaContent"
        Write-Done "Appended Starship init to $starshipLua"
    }
} else {
    Set-Content -Path $starshipLua -Value $luaContent -Encoding UTF8
    Write-Done "Created $starshipLua"
}

# ─────────────────────────────────────────────
# 7. Set CaskaydiaCove Nerd Font in Windows Terminal
# ─────────────────────────────────────────────
Write-Step "Updating Windows Terminal default font"

$wtSettingsPath = $null

# Windows Terminal stable
$stableGlob = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
# Windows Terminal Preview
$previewGlob = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_*\LocalState\settings.json"

foreach ($glob in @($stableGlob, $previewGlob)) {
    $found = Get-Item $glob -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $wtSettingsPath = $found.FullName; break }
}

if (-not $wtSettingsPath) {
    Write-Skip "Windows Terminal settings.json not found. Skipping font configuration."
} else {
    Write-Host "    Found: $wtSettingsPath"

    # Read and parse JSON
    $json = Get-Content $wtSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $fontFace = "CaskaydiaCove Nerd Font"

    # Ensure profiles.defaults exists
    if (-not $json.profiles) {
        $json | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    if (-not $json.profiles.defaults) {
        $json.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    $defaults = $json.profiles.defaults

    # Windows Terminal uses a "font" object with a "face" property
    if (-not $defaults.font) {
        $defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue ([PSCustomObject]@{ face = $fontFace }) -Force
        Write-Done "Added font.face = '$fontFace'"
    } elseif ($defaults.font.face -eq $fontFace) {
        Write-Skip "Windows Terminal font is already set to '$fontFace'"
    } else {
        $defaults.font | Add-Member -NotePropertyName 'face' -NotePropertyValue $fontFace -Force
        Write-Done "Updated font.face to '$fontFace'"
    }

    # Write back with formatting
    $json | ConvertTo-Json -Depth 20 | Set-Content -Path $wtSettingsPath -Encoding UTF8
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
Write-Host "`n" + ("─" * 60) -ForegroundColor DarkGray
Write-Host "  Setup complete! Restart your terminals to apply changes." -ForegroundColor Green
Write-Host ("─" * 60) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tips:" -ForegroundColor White
Write-Host "   • PowerShell: Starship will activate automatically on next launch."
Write-Host "   • cmd.exe:    Make sure Clink auto-inject is enabled (runs at cmd startup)."
Write-Host "   • Windows Terminal: Font updated; relaunch WT to see the new font."
Write-Host "   • Customize Starship: https://starship.rs/config/" -ForegroundColor DarkCyan
Write-Host ""
