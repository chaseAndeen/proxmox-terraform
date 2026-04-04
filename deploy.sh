#!/usr/bin/env bash
# deploy.sh — thin wrapper that injects the Proxmox SSH key and forwards all
# args to Terraform for the given stack, or all stacks in sequence.
#
# Stacks are auto-initialized on first run — no need to run init manually.
#
# Usage: ./deploy.sh <stack|all> <terraform args>
#   e.g. ./deploy.sh all apply          # apply all stacks (standard workflow)
#        ./deploy.sh all plan           # plan all stacks
#        ./deploy.sh all destroy        # destroy all stacks
#        ./deploy.sh pbs destroy        # destroy a specific stack
#        ./deploy.sh all init -upgrade  # explicit init (e.g. provider upgrade)

set -euo pipefail
export AWS_PAGER=""

STACK="${1:?Usage: ./deploy.sh <stack|all> <terraform args>}"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  --profile InfraProvisioner \
  --region us-east-1)"

run_stack() {
  local stack="$1"
  shift
  echo "==> [$stack]"
  cd "${SCRIPT_DIR}/stacks/${stack}"
  if [[ ! -d ".terraform" && "${1:-}" != "init" ]]; then
    echo "    (.terraform not found — initializing)"
    terraform init
  fi
  terraform "$@"
}

if [[ "$STACK" == "all" ]]; then
  for stack_dir in "${SCRIPT_DIR}/stacks"/*/; do
    run_stack "$(basename "$stack_dir")" "$@"
  done
else
  run_stack "$STACK" "$@"
fi
