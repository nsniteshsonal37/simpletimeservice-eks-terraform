param(
    [ValidateSet("dev", "prod")]
    [string]$Profile,
    [switch]$NoAutoApprove,
    [string]$AllowedCidr
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$terraformDir = Join-Path $repoRoot "terraform"
$pipelineExportFile = Join-Path $terraformDir "post-apply.env"

function Assert-CommandExists {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-TerraformOutputRaw {
    param([string]$Name)

    $value = terraform -chdir=terraform output -raw $Name
    if ($LASTEXITCODE -ne 0) {
        throw "failed to read terraform output: $Name"
    }

    return $value.Trim()
}

function Write-PipelineExports {
    param([string]$PublicUrl = "")

    $exports = [ordered]@{
        STS_AWS_REGION         = Get-TerraformOutputRaw -Name "aws_region"
        STS_EKS_CLUSTER_NAME   = Get-TerraformOutputRaw -Name "cluster_name"
        STS_CLUSTER_ENDPOINT   = Get-TerraformOutputRaw -Name "cluster_endpoint"
        STS_DEPLOYMENT_PROFILE = Get-TerraformOutputRaw -Name "deployment_profile"
        STS_ENVIRONMENT        = Get-TerraformOutputRaw -Name "environment"
        STS_VPC_ID             = Get-TerraformOutputRaw -Name "vpc_id"
        STS_PUBLIC_SUBNET_IDS  = Get-TerraformOutputRaw -Name "public_subnet_ids_csv"
        STS_PRIVATE_SUBNET_IDS = Get-TerraformOutputRaw -Name "private_subnet_ids_csv"
        STS_DOCKERHUB_IMAGE    = Get-TerraformOutputRaw -Name "dockerhub_image"
        STS_PUBLIC_URL         = $PublicUrl
    }

    $lines = foreach ($entry in $exports.GetEnumerator()) {
        '{0}={1}' -f $entry.Key, $entry.Value
    }

    Set-Content -Path $pipelineExportFile -Value $lines -Encoding ascii
    Write-Host "Pipeline exports written to: $pipelineExportFile"
}

Assert-CommandExists "terraform"

if (-not $Profile -and $Host.Name -ne "ServerRemoteHost") {
    Write-Host "Select Terraform apply profile:"
    Write-Host "Press 1 for dev"
    Write-Host "Press 2 for prod"
    Write-Host "Press Enter to keep current defaults"

    while (-not $Profile) {
        $choice = Read-Host "Enter choice [1/2]"
        switch ($choice) {
            "1" { $Profile = "dev" }
            "2" { $Profile = "prod" }
            "" { break }
            default { Write-Host "Invalid choice. Press 1 for dev, 2 for prod, or Enter to skip." }
        }
    }
}

if (-not $AllowedCidr -and $Host.Name -ne "ServerRemoteHost") {
    $AllowedCidr = Read-Host "Enter allowed CIDR for EKS API endpoint (for example 203.0.113.10/32), or press Enter to keep current/default"
}

if ($AllowedCidr -and $AllowedCidr -notmatch '^[0-9]{1,3}(\.[0-9]{1,3}){3}/([0-9]|[12][0-9]|3[0-2])$') {
    throw "Invalid CIDR format: $AllowedCidr"
}

Write-Host "Starting Terraform apply workflow..."
Write-Host "Repository root: $repoRoot"

if ($Profile) {
    $profileFile = Join-Path $terraformDir "profiles\$Profile.tfvars"
    $autoProfileFile = Join-Path $terraformDir "profile.auto.tfvars"

    if (-not (Test-Path $profileFile)) {
        throw "Profile file not found: $profileFile"
    }

    Copy-Item -Path $profileFile -Destination $autoProfileFile -Force
    Write-Host "Active Terraform profile set to '$Profile'."
}
else {
    Write-Host "Requested profile: none (using current terraform defaults)"
}

if ($NoAutoApprove) {
    Write-Host "Terraform apply mode: interactive approval"
}

$accessOverrideFile = Join-Path $terraformDir "access.auto.tfvars"
if ($AllowedCidr) {
    @(
        "cluster_endpoint_public_access = true"
        ('eks_public_access_cidrs = ["{0}"]' -f $AllowedCidr)
    ) | Set-Content -Path $accessOverrideFile -Encoding ascii
    Write-Host "Applied EKS API allowlist override: $AllowedCidr"
}
else {
    @(
        "cluster_endpoint_public_access = false"
        "eks_public_access_cidrs = []"
    ) | Set-Content -Path $accessOverrideFile -Encoding ascii
    Write-Host "EKS API endpoint set to private-only access."
}
else {
    Write-Host "Terraform apply mode: auto-approve"
}

Push-Location $repoRoot
try {
    Write-Host "Running: terraform init"
    terraform -chdir=terraform init
    Write-Host "Running: terraform validate"
    terraform -chdir=terraform validate

    if ($NoAutoApprove) {
        Write-Host "Running: terraform apply"
        terraform -chdir=terraform apply
    }
    else {
        Write-Host "Running: terraform apply -auto-approve"
        terraform -chdir=terraform apply -auto-approve
    }

    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed with exit code $LASTEXITCODE"
    }

    Write-PipelineExports
}
finally {
    Pop-Location
}
