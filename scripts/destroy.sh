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

cd "$REPO_ROOT"

if [[ -f "$K8S_MANIFEST" ]]; then
  kubectl delete -f "$K8S_MANIFEST" --ignore-not-found=true
fi

if [[ "$NO_AUTO_APPROVE" == "true" ]]; then
  terraform -chdir=terraform destroy
else
  terraform -chdir=terraform destroy -auto-approve
fi

echo "One-click destroy completed successfully."
