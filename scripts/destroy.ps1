$ErrorActionPreference = "Stop"

param(
    [switch]$NoAutoApprove
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$k8sManifest = Join-Path $repoRoot "k8s\microservice.yml"

function Assert-CommandExists {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Assert-CommandExists "terraform"
Assert-CommandExists "kubectl"

Push-Location $repoRoot
try {
    if (Test-Path $k8sManifest) {
        kubectl delete -f $k8sManifest --ignore-not-found=true
    }

    $destroyArgs = @("-chdir=terraform", "destroy")
    if (-not $NoAutoApprove) {
        $destroyArgs += "-auto-approve"
    }

    terraform @destroyArgs

    Write-Host "One-click destroy completed successfully."
}
finally {
    Pop-Location
}
