#!/usr/bin/env bash
set -euo pipefail

PROFILE=""
NO_AUTO_APPROVE="false"

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
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./scripts/deploy.sh [--profile dev|prod] [--no-auto-approve]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"
K8S_MANIFEST="$REPO_ROOT/k8s/microservice.yml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

require_cmd terraform
require_cmd aws
require_cmd kubectl

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
fi

cd "$REPO_ROOT"

terraform -chdir=terraform init
terraform -chdir=terraform validate

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  terraform -chdir=terraform apply
else
  terraform -chdir=terraform apply -auto-approve
fi

REGION="$(terraform -chdir=terraform output -raw aws_region)"
CLUSTER_NAME="$(terraform -chdir=terraform output -raw cluster_name)"

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

kubectl apply -f "$K8S_MANIFEST"
kubectl rollout status deployment/simpletimeservice --timeout=180s
kubectl rollout status deployment/simpletimeservice-nginx --timeout=180s

echo "One-click deploy completed successfully."
echo "Run 'kubectl get pods' and 'kubectl get svc' to verify resources."
