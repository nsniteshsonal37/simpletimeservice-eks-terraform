#!/usr/bin/env bash
set -euo pipefail

echo "Select Terraform deployment profile:"
echo "  1) dev"
echo "  2) prod"
read -r -p "Enter selection (1 or 2): " CHOICE

case "$CHOICE" in
  1) PROFILE="dev" ;;
  2) PROFILE="prod" ;;
  *)
    echo "Invalid selection. Please enter 1 or 2."
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_FILE="$REPO_ROOT/terraform/profiles/$PROFILE.tfvars"
TARGET_FILE="$REPO_ROOT/terraform/profile.auto.tfvars"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Profile file not found: $SOURCE_FILE"
  exit 1
fi

cp "$SOURCE_FILE" "$TARGET_FILE"

echo "Active Terraform profile set to '$PROFILE'."
echo "Wrote $TARGET_FILE"
echo "Run: terraform -chdir=terraform plan"
