<#
  firebase/scripts/setup_firebase.ps1

  Moved from scripts/setup_firebase.ps1 to live under firebase/ to keep
  Firebase-related helpers together.
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
