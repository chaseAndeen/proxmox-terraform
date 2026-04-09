# proxmox-terraform

Terraform monorepo for Proxmox VM provisioning and service configuration. Each stack under `stacks/` has independent state. A shared module under `modules/` defines the common VM pattern.

---

## Structure

```
proxmox-terraform/
├── modules/
│   └── proxmox-vm/        # shared VM module
├── stacks/
│   ├── amp-01/            # AMP Management Node (ADS controller)
│   ├── amp-02/            # AMP Target Node (game server worker)
│   ├── authentik-config/  # Authentik users, policies, providers, outpost (run after svc.yml)
│   ├── pbs/               # Proxmox Backup Server VM
│   ├── svc-01/            # Services VM (Traefik + Authentik)
│   └── unifi/             # UniFi OS Server VM
└── deploy.sh              # wrapper for proxmox stacks (amp-01, amp-02, pbs, svc-01, unifi)
```

---

## Prerequisites

### Dependencies
```bash
# Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# AWS CLI — log in with the profile set in backend.hcl (default: InfraProvisioner)
aws sso login --profile <aws_profile>
```

### Proxmox requirements (amp-01, amp-02, pbs, svc-01, unifi stacks)
- VM templates must exist — built by `packer-templates`:
  - `tpl-ubuntu-noble` (ID 9000) — used by svc-01
  - `tpl-debian-trixie` (ID 9001) — used by amp-01, amp-02, pbs, unifi
- `terraform-prov@pve` API token must exist in SSM — created by `proxmox-playbook`
- `ansible` service account must exist on `pve-01` — created by `proxmox-playbook bootstrap.yml`

### Authentik requirements (authentik-config stack only)
- `infra-playbook/svc.yml` must have run — Authentik must be up and reachable
- SSM parameter `/infra/svc/authentik/bootstrap_token` must exist (written by `svc.yml`)

---

## SSM Parameters

### Proxmox stacks (amp-01, amp-02, pbs, svc-01, unifi)

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

# Backend config — shared S3 state backend settings
cp backend.hcl.example backend.hcl
# Edit backend.hcl — set bucket, region, profile, dynamodb_table

# Proxmox stacks
cp stacks/pbs/terraform.tfvars.example stacks/pbs/terraform.tfvars
cp stacks/svc-01/terraform.tfvars.example stacks/svc-01/terraform.tfvars
cp stacks/unifi/terraform.tfvars.example stacks/unifi/terraform.tfvars
cp stacks/amp-01/terraform.tfvars.example stacks/amp-01/terraform.tfvars
cp stacks/amp-02/terraform.tfvars.example stacks/amp-02/terraform.tfvars

# Authentik stack
cp stacks/authentik-config/terraform.tfvars.example stacks/authentik-config/terraform.tfvars
# Edit authentik-config/terraform.tfvars — set admin_username, admin_name, admin_email
```

---

## Usage

### Proxmox stacks (amp-01, amp-02, pbs, svc-01, unifi)

`deploy.sh` fetches the Proxmox SSH key from SSM and passes all remaining arguments to Terraform. Stacks are auto-initialized on first run. The backend config is loaded from `backend.hcl` automatically.

Override the AWS profile or region with environment variables if needed:
```bash
AWS_PROFILE=MyProfile AWS_REGION=us-west-2 ./deploy.sh pbs apply
```

```bash
# Standard workflow
./deploy.sh all plan
./deploy.sh all apply

# Target a specific stack
./deploy.sh pbs plan
./deploy.sh pbs apply
./deploy.sh unifi apply

# Destroy
./deploy.sh pbs destroy

# Explicit init (e.g. after a provider version bump)
./deploy.sh all init -upgrade
```

### authentik-config stack

Run directly with Terraform (not via deploy.sh — no Proxmox SSH key needed):

```bash
cd stacks/authentik-config
terraform init -backend-config=../../backend.hcl
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
One-time password reset link for "<admin_username>":

https://authentik.svc.<your-domain>/if/flow/recovery-flow/?flow_token=...

===========================
```

1. Open the link and set a password
2. Log in to `https://authentik.svc.<your-domain>` — you will be prompted to enroll TOTP
3. Scan the QR code with your authenticator app and complete enrollment
4. The Traefik dashboard at `https://traefik.svc.<your-domain>` is now protected by forward auth

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
| `amp-01` | `amp-01/terraform.tfstate` |
| `amp-02` | `amp-02/terraform.tfstate` |
| `authentik-config` | `authentik-config/terraform.tfstate` |
| `pbs` | `pbs/terraform.tfstate` |
| `svc-01` | `svc-01/terraform.tfstate` |
| `unifi` | `unifi/terraform.tfstate` |

S3 bucket and DynamoDB lock table are configured in `backend.hcl` — managed by `terraform-bootstrap`.

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
