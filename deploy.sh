#!/usr/bin/env bash
# deploy.sh — thin wrapper that injects the Proxmox SSH key and forwards all
# args to Terraform for the given stack, or all stacks in sequence.
#
# Stacks are auto-initialized on first run — backend.hcl is loaded automatically.
#
# Usage: ./deploy.sh <stack|all> <terraform args>
#   e.g. ./deploy.sh all apply          # apply all stacks (standard workflow)
#        ./deploy.sh all plan           # plan all stacks
#        ./deploy.sh all destroy        # destroy all stacks
#        ./deploy.sh pbs destroy        # destroy a specific stack
#        ./deploy.sh all init -upgrade  # explicit init (e.g. provider upgrade)
#
# Environment overrides:
#   AWS_PROFILE   — AWS CLI profile (default: InfraProvisioner)
#   AWS_REGION    — AWS region      (default: us-east-1)

set -euo pipefail
export AWS_PAGER=""

AWS_PROFILE="${AWS_PROFILE:-InfraProvisioner}"
AWS_REGION="${AWS_REGION:-us-east-1}"

STACK="${1:?Usage: ./deploy.sh <stack|all> <terraform args>}"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONFIG="${SCRIPT_DIR}/backend.hcl"

if [[ ! -f "$BACKEND_CONFIG" ]]; then
  echo "ERROR: backend.hcl not found at ${BACKEND_CONFIG}"
  echo "       Copy backend.hcl.example to backend.hcl and fill in your values."
  exit 1
fi

if [[ "$STACK" != "all" && ! -d "${SCRIPT_DIR}/stacks/${STACK}" ]]; then
  echo "ERROR: stack '${STACK}' not found. Available: all $(ls "${SCRIPT_DIR}/stacks/" | tr '\n' ' ')"
  exit 1
fi

export PROXMOX_VE_SSH_PRIVATE_KEY
PROXMOX_VE_SSH_PRIVATE_KEY="$(aws ssm get-parameter \
  --name "/infra/common/ansible_private_key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION")"

run_stack() {
  local stack="$1"
  shift
  echo "==> [$stack]"
  cd "${SCRIPT_DIR}/stacks/${stack}"
  if [[ "${1:-}" == "init" ]]; then
    shift
    terraform init -backend-config="$BACKEND_CONFIG" "$@"
  else
    if [[ ! -d ".terraform" ]]; then
      echo "    (.terraform not found — initializing)"
      terraform init -backend-config="$BACKEND_CONFIG"
    fi
    terraform "$@"
  fi
}

if [[ "$STACK" == "all" ]]; then
  for stack_dir in "${SCRIPT_DIR}/stacks"/*/; do
    run_stack "$(basename "$stack_dir")" "$@"
  done
else
  run_stack "$STACK" "$@"
fi
