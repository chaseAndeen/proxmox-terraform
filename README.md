# proxmox-terraform

Terraform monorepo for Proxmox VM provisioning and service configuration. Each stack under `stacks/` has independent state. A shared module under `modules/` defines the common VM pattern.

---

## Structure

```
proxmox-terraform/
├── modules/
│   └── proxmox-vm/        # shared VM module
├── stacks/
│   ├── authentik-config/  # Authentik users, policies, providers, outpost (run after svc.yml)
│   ├── pbs/               # Proxmox Backup Server VM
│   └── svc-01/            # Services VM (Traefik + Authentik)
└── deploy.sh              # wrapper for proxmox stacks (pbs, svc-01)
```

---

## Prerequisites

### Dependencies
```bash
# Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# AWS CLI
aws sso login --profile InfraProvisioner
```

### Proxmox requirements (pbs, svc-01 stacks only)
- VM templates must exist — built by `packer-templates`:
  - `tpl-ubuntu-noble` (ID 9000) — used by svc-01
  - `tpl-debian-trixie` (ID 9001) — used by pbs
- `terraform-prov@pve` API token must exist in SSM — created by `proxmox-playbook`
- `ansible` service account must exist on `pve-01` — created by `proxmox-playbook bootstrap.yml`

### Authentik requirements (authentik-config stack only)
- `infra-playbook/svc.yml` must have run — Authentik must be up and reachable
- SSM parameter `/infra/svc/authentik/bootstrap_token` must exist (written by `svc.yml`)

---

## SSM Parameters

### Proxmox stacks (pbs, svc-01)

| Parameter | Type | Description |
|---|---|---|
| `/infra/proxmox/terraform_token` | SecureString | Proxmox API token for `terraform-prov@pve` |
| `/infra/common/ansible_public_key` | String | `ansible` SSH public key — injected into VMs via cloud-init |
| `/infra/common/ansible_private_key` | SecureString | `ansible` SSH private key — fetched by `deploy.sh` for the Proxmox provider |

### authentik-config stack

| Parameter | Type | Written by | Description |
|---|---|---|---|
| `/infra/svc/authentik/bootstrap_token` | SecureString | `svc.yml` | `akadmin` bootstrap API token — Terraform's only credential |

---

## Setup

```bash
git clone <repo-url>
cd proxmox-terraform

# Proxmox stacks
cp stacks/pbs/terraform.tfvars.example stacks/pbs/terraform.tfvars
cp stacks/svc-01/terraform.tfvars.example stacks/svc-01/terraform.tfvars

# Authentik stack
cp stacks/authentik-config/terraform.tfvars.example stacks/authentik-config/terraform.tfvars
# Edit authentik-config/terraform.tfvars — set admin_username, admin_name, admin_email
```

---

## Usage

### Proxmox stacks (pbs, svc-01)

`deploy.sh` fetches the Proxmox SSH key from SSM and passes all remaining arguments to Terraform. Stacks are auto-initialized on first run.

```bash
# Standard workflow
./deploy.sh all plan
./deploy.sh all apply

# Target a specific stack
./deploy.sh pbs plan
./deploy.sh pbs apply

# Destroy
./deploy.sh pbs destroy

# Explicit init (e.g. after a provider version bump)
./deploy.sh all init -upgrade
```

### authentik-config stack

Run directly with Terraform (not via deploy.sh — no Proxmox SSH key needed):

```bash
cd stacks/authentik-config
terraform init
terraform plan
terraform apply
```

---

## Deployment sequence

The `authentik-config` stack depends on `infra-playbook/svc.yml` having run first.
Full svc-01 deployment order:

```bash
# 1. Provision the VM
./deploy.sh svc-01 apply

# 2. Configure the VM (Docker, Traefik, Authentik)
cd <infra-playbook>
ansible-playbook -i inventory/hosts.yml playbooks/svc.yml

# 3. Configure Authentik (users, policies, forward auth)
cd <proxmox-terraform>/stacks/authentik-config
terraform init && terraform apply
```

### First-login account setup

On first `terraform apply`, a one-time password-reset link for your admin account is printed to stdout:

```
=== ADMIN ACCOUNT SETUP ===
One-time password reset link for "sysop":

https://authentik.svc.kernelstack.dev/if/flow/recovery-flow/?flow_token=...

===========================
```

1. Open the link and set a password
2. Log in to `https://authentik.svc.kernelstack.dev` — you will be prompted to enroll TOTP
3. Scan the QR code with your authenticator app and complete enrollment
4. The Traefik dashboard at `https://traefik.svc.kernelstack.dev` is now protected by forward auth

If you need to regenerate the link (e.g. it expired):
```bash
terraform taint null_resource.admin_recovery_link
terraform apply
```

---

## State management

Each stack maintains independent state in S3:

| Stack | State key |
|---|---|
| `authentik-config` | `authentik-config/terraform.tfstate` |
| `pbs` | `pbs/terraform.tfstate` |
| `svc-01` | `svc-01/terraform.tfstate` |

S3 bucket: `kernelstack-terraform-state` — managed by `terraform-bootstrap`.
DynamoDB lock table: `kernelstack-terraform-locks`.

---

## DR — authentik-config

After a full Authentik data wipe (NFS volume lost):

1. Run `infra-playbook/svc.yml` — redeploys Authentik with the existing SSM secrets (secret_key, postgres_password, bootstrap_token unchanged)
2. Run `terraform apply` in `stacks/authentik-config` — all resources are recreated from scratch; the embedded outpost and brand are found dynamically by stable identifiers, no imports needed
3. The recovery link for your admin account is printed during apply

---

## Adding a new VM

1. Create `stacks/<name>/` with `providers.tf`, `data.tf`, `variables.tf`, `main.tf`, `outputs.tf`, and `terraform.tfvars`
2. Call `module "vm" { source = "../../modules/proxmox-vm" ... }` with VM-specific values
3. Set a unique backend `key` in `providers.tf`
4. Run `./deploy.sh all apply` — the new stack is detected, auto-initialized, and applied
