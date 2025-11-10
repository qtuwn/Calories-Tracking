<#
  scripts/setup_firebase.ps1

  Helper to copy Firebase native config files from a local secure directory
  into the project. This keeps credentials out of version control and makes
  it easy for developers to set up their local machines.

  Usage:
    # Set environment variable to where you keep secret firebase files
    $env:FIREBASE_CONFIG_DIR = 'C:\Users\YOU\secure-configs\firebase'
    .\scripts\setup_firebase.ps1

  The script expects the following files in $FIREBASE_CONFIG_DIR:
    - google-services.json             (Android)
    - GoogleService-Info.plist         (iOS / macOS)

  The script will copy files into android/app/ and ios/ (and macos/) folders.
  It will NOT commit anything to git; ensure these files are not checked in.
#>

param()

function Copy-IfExists($src, $dest) {
    if (Test-Path $src) {
        Write-Host "Copying $src -> $dest"
        Copy-Item -Force $src -Destination $dest
    } else {
        Write-Host "[WARN] Not found: $src"
    }
}

$configDir = $env:FIREBASE_CONFIG_DIR
if (-not $configDir) {
    $configDir = Read-Host "Enter path to local Firebase config directory"
}

if (-not (Test-Path $configDir)) {
    Write-Error "Config directory does not exist: $configDir"
    exit 1
}

# Android
$androidSrc = Join-Path $configDir 'google-services.json'
$androidDest = 'android\app\google-services.json'
Copy-IfExists $androidSrc $androidDest

# iOS
$iosSrc = Join-Path $configDir 'GoogleService-Info.plist'
$iosDest = 'ios\Runner\GoogleService-Info.plist'
Copy-IfExists $iosSrc $iosDest

# macOS
$macSrc = Join-Path $configDir 'GoogleService-Info.plist'
$macDest = 'macos\Runner\GoogleService-Info.plist'
Copy-IfExists $macSrc $macDest

Write-Host "Done. Ensure these files are NOT added to git. .gitignore already excludes them in this project." -ForegroundColor Green
