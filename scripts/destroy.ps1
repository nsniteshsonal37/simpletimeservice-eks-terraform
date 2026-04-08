param(
    [switch]$NoAutoApprove
)

$ErrorActionPreference = "Stop"

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

Write-Host "Starting destroy workflow..."
Write-Host "Repository root: $repoRoot"

if ($NoAutoApprove) {
    Write-Host "Terraform destroy mode: interactive approval"
}
elseif ($Host.Name -ne "ServerRemoteHost") {
    Write-Host "This will delete Kubernetes resources from $k8sManifest and run terraform destroy -auto-approve."
    $confirmation = Read-Host "Type DESTROY to continue"
    if ($confirmation -ne "DESTROY") {
        throw "Destroy cancelled."
    }

    Write-Host "Terraform destroy mode: auto-approve (confirmed)"
}
else {
    Write-Host "Terraform destroy mode: auto-approve"
}

Push-Location $repoRoot
try {
    if (Test-Path $k8sManifest) {
        Write-Host "Deleting Kubernetes manifest: $k8sManifest"
        kubectl delete -f $k8sManifest --ignore-not-found=true
    }

    $destroyArgs = @("-chdir=terraform", "destroy")
    if (-not $NoAutoApprove) {
        $destroyArgs += "-auto-approve"
    }

    if ($NoAutoApprove) {
        Write-Host "Running: terraform destroy"
    }
    else {
        Write-Host "Running: terraform destroy -auto-approve"
    }
    terraform @destroyArgs

    Write-Host "One-click destroy completed successfully."
}
finally {
    Pop-Location
}
