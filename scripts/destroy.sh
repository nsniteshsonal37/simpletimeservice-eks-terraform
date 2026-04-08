#!/usr/bin/env bash
set -euo pipefail

NO_AUTO_APPROVE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-auto-approve)
      NO_AUTO_APPROVE="true"
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./scripts/destroy.sh [--no-auto-approve]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S_MANIFEST="$REPO_ROOT/k8s/microservice.yml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

require_cmd terraform
require_cmd kubectl

echo "Starting destroy workflow..."
echo "Repository root: $REPO_ROOT"

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  echo "Terraform destroy mode: interactive approval"
elif [[ -t 0 ]]; then
  echo "This will delete Kubernetes resources from $K8S_MANIFEST and run terraform destroy -auto-approve."
  read -r -p "Type DESTROY to continue: " destroy_confirmation
  if [[ "$destroy_confirmation" != "DESTROY" ]]; then
    echo "Destroy cancelled."
    exit 1
  fi
  echo "Terraform destroy mode: auto-approve (confirmed)"
else
  echo "Terraform destroy mode: auto-approve"
fi

cd "$REPO_ROOT"

if [[ -f "$K8S_MANIFEST" ]]; then
  echo "Deleting Kubernetes manifest: $K8S_MANIFEST"
  kubectl delete -f "$K8S_MANIFEST" --ignore-not-found=true
fi

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  echo "Running: terraform destroy"
  terraform -chdir=terraform destroy
else
  echo "Running: terraform destroy -auto-approve"
  terraform -chdir=terraform destroy -auto-approve
fi

echo "One-click destroy completed successfully."
