#!/usr/bin/env bash
set -euo pipefail

PROFILE=""
NO_AUTO_APPROVE="false"
ALLOWED_CIDR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --no-auto-approve)
      NO_AUTO_APPROVE="true"
      shift
      ;;
    --allowed-cidr)
      ALLOWED_CIDR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./scripts/apply.sh [--profile dev|prod] [--no-auto-approve] [--allowed-cidr <CIDR>]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"
PIPELINE_EXPORT_FILE="$TERRAFORM_DIR/post-apply.env"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

terraform_output_raw() {
  terraform -chdir=terraform output -raw "$1"
}

write_pipeline_exports() {
  local public_url="${1:-}"

  cat > "$PIPELINE_EXPORT_FILE" <<EOF
STS_AWS_REGION=$(terraform_output_raw aws_region)
STS_EKS_CLUSTER_NAME=$(terraform_output_raw cluster_name)
STS_CLUSTER_ENDPOINT=$(terraform_output_raw cluster_endpoint)
STS_DEPLOYMENT_PROFILE=$(terraform_output_raw deployment_profile)
STS_ENVIRONMENT=$(terraform_output_raw environment)
STS_VPC_ID=$(terraform_output_raw vpc_id)
STS_PUBLIC_SUBNET_IDS=$(terraform_output_raw public_subnet_ids_csv)
STS_PRIVATE_SUBNET_IDS=$(terraform_output_raw private_subnet_ids_csv)
STS_DOCKERHUB_IMAGE=$(terraform_output_raw dockerhub_image)
STS_PUBLIC_URL=$public_url
EOF

  echo "Pipeline exports written to: $PIPELINE_EXPORT_FILE"
}

require_cmd terraform

if [[ -z "$PROFILE" && -t 0 ]]; then
  echo "Select Terraform apply profile:"
  echo "Press 1 for dev"
  echo "Press 2 for prod"

  while true; do
    read -r -p "Enter choice [1/2] (or press Enter to keep current defaults): " profile_choice
    case "$profile_choice" in
      1)
        PROFILE="dev"
        break
        ;;
      2)
        PROFILE="prod"
        break
        ;;
      "")
        break
        ;;
      *)
        echo "Invalid choice. Press 1 for dev, 2 for prod, or Enter to skip."
        ;;
    esac
  done
fi

if [[ -z "$ALLOWED_CIDR" && -t 0 ]]; then
  read -r -p "Enter allowed CIDR for EKS API endpoint (for example 203.0.113.10/32), or press Enter to keep current/default: " ALLOWED_CIDR
fi

echo "Starting Terraform apply workflow..."
echo "Repository root: $REPO_ROOT"

if [[ -n "$PROFILE" ]]; then
  if [[ "$PROFILE" != "dev" && "$PROFILE" != "prod" ]]; then
    echo "Invalid profile: $PROFILE (expected dev or prod)"
    exit 1
  fi

  PROFILE_FILE="$TERRAFORM_DIR/profiles/$PROFILE.tfvars"
  AUTO_PROFILE_FILE="$TERRAFORM_DIR/profile.auto.tfvars"

  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "Profile file not found: $PROFILE_FILE"
    exit 1
  fi

  cp "$PROFILE_FILE" "$AUTO_PROFILE_FILE"
  echo "Active Terraform profile set to '$PROFILE'."
else
  echo "Requested profile: none (using current terraform defaults)"
fi

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  echo "Terraform apply mode: interactive approval"
else
  echo "Terraform apply mode: auto-approve"
fi

ACCESS_OVERRIDE_FILE="$TERRAFORM_DIR/access.auto.tfvars"
if [[ -n "$ALLOWED_CIDR" ]]; then
  printf 'cluster_endpoint_public_access = true\neks_public_access_cidrs = ["%s"]\n' "$ALLOWED_CIDR" > "$ACCESS_OVERRIDE_FILE"
  echo "Applied EKS API allowlist override: $ALLOWED_CIDR"
else
  printf 'cluster_endpoint_public_access = false\neks_public_access_cidrs = []\n' > "$ACCESS_OVERRIDE_FILE"
  echo "EKS API endpoint set to private-only access."
fi

cd "$REPO_ROOT"

echo "Running: terraform init"
terraform -chdir=terraform init
echo "Running: terraform validate"
terraform -chdir=terraform validate

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  echo "Running: terraform apply"
  terraform -chdir=terraform apply
else
  echo "Running: terraform apply -auto-approve"
  terraform -chdir=terraform apply -auto-approve
fi

write_pipeline_exports
