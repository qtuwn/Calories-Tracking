# PowerShell helper to run the Node seed script against the local Firestore emulator
# Usage: .\scripts\seed_foods.ps1

$script = Join-Path $PSScriptRoot '..\functions\seed\seed_foods.js'
if (-not (Test-Path $script)) {
  Write-Error "Seed script not found: $script"
  exit 1
}

Write-Host "Running seed script against emulator..."
node $script --emulator
if ($LASTEXITCODE -ne 0) {
  Write-Error "Seed script failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}
Write-Host "Seeding complete."
