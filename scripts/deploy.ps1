$ErrorActionPreference = "Stop"

param(
    [ValidateSet("dev", "prod")]
    [string]$Profile,
    [switch]$NoAutoApprove
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$terraformDir = Join-Path $repoRoot "terraform"
$k8sManifest = Join-Path $repoRoot "k8s\microservice.yml"

function Assert-CommandExists {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Assert-CommandExists "terraform"
Assert-CommandExists "aws"
Assert-CommandExists "kubectl"

if ($Profile) {
    $profileFile = Join-Path $terraformDir "profiles\$Profile.tfvars"
    $autoProfileFile = Join-Path $terraformDir "profile.auto.tfvars"

    if (-not (Test-Path $profileFile)) {
        throw "Profile file not found: $profileFile"
    }

    Copy-Item -Path $profileFile -Destination $autoProfileFile -Force
    Write-Host "Active Terraform profile set to '$Profile'."
}

Push-Location $repoRoot
try {
    terraform -chdir=terraform init
    terraform -chdir=terraform validate

    $applyArgs = @("-chdir=terraform", "apply")
    if (-not $NoAutoApprove) {
        $applyArgs += "-auto-approve"
    }

    terraform @applyArgs

    $region = terraform -chdir=terraform output -raw aws_region
    $clusterName = terraform -chdir=terraform output -raw cluster_name

    aws eks update-kubeconfig --region $region --name $clusterName

    kubectl apply -f $k8sManifest
    kubectl rollout status deployment/simpletimeservice --timeout=180s
    kubectl rollout status deployment/simpletimeservice-nginx --timeout=180s

    Write-Host "One-click deploy completed successfully."
    Write-Host "Run 'kubectl get pods' and 'kubectl get svc' to verify resources."
}
finally {
    Pop-Location
}
