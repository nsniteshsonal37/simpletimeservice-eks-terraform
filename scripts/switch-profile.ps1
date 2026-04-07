$ErrorActionPreference = "Stop"

Write-Host "Select Terraform deployment profile:"
Write-Host "  1) dev"
Write-Host "  2) prod"

$choice = Read-Host "Enter selection (1 or 2)"

$Profile = switch ($choice) {
    "1" { "dev" }
    "2" { "prod" }
    default { throw "Invalid selection. Please enter 1 or 2." }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$sourceFile = Join-Path $repoRoot "terraform\profiles\$Profile.tfvars"
$targetFile = Join-Path $repoRoot "terraform\profile.auto.tfvars"

if (-not (Test-Path $sourceFile)) {
    throw "Profile file not found: $sourceFile"
}

Copy-Item -Path $sourceFile -Destination $targetFile -Force

Write-Host "Active Terraform profile set to '$Profile'."
Write-Host "Wrote $targetFile"
Write-Host "Run: terraform -chdir=terraform plan"
