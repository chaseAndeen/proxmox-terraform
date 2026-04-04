# proxmox-terraform

Terraform monorepo for provisioning Proxmox VMs. Each VM is a self-contained
stack under `stacks/` with independent state. A shared module under `modules/`
defines the common VM pattern. Full VM configuration is handled by `proxmox-playbook`.

---

## Structure

```
proxmox-terraform/
├── modules/
│   └── proxmox-vm/        # shared VM module
├── stacks/
│   ├── pbs/               # Proxmox Backup Server
│   └── svc-01/            # Services VM (Traefik + Authentik)
└── deploy.sh              # shared wrapper
```

Adding a new VM is a new directory under `stacks/` that calls the shared module.

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

### Proxmox requirements
- VM templates must exist — built by `packer-templates`:
  - `tpl-ubuntu-noble` (ID 9000) — used by svc-01
  - `tpl-debian-trixie` (ID 9001) — used by pbs
- `terraform-prov@pve` API token must exist in SSM — created by `proxmox-playbook`
- `ansible` service account must exist on `pve-01` — created by `proxmox-playbook bootstrap.yml`

---

## SSM Parameters required

| Parameter | Type | Description |
|---|---|---|
| `/infra/proxmox/terraform_token` | SecureString | Proxmox API token for `terraform-prov@pve` |
| `/infra/common/ansible_public_key` | String | `ansible` SSH public key — injected into VMs via cloud-init |
| `/infra/common/ansible_private_key` | SecureString | `ansible` SSH private key — fetched by `deploy.sh` for the Proxmox provider |

---

## Setup

```bash
git clone <repo-url>
cd proxmox-terraform

# Copy and fill in tfvars for each stack
cp stacks/pbs/terraform.tfvars.example stacks/pbs/terraform.tfvars
cp stacks/svc-01/terraform.tfvars.example stacks/svc-01/terraform.tfvars
# Edit each terraform.tfvars with your values
```

No manual `init` needed — stacks are automatically initialized on first run.

---

## Usage

`deploy.sh` fetches the Proxmox SSH key from SSM and passes all remaining
arguments to Terraform. Stacks that have not been initialized are automatically
initialized before the requested command runs.

```bash
# Standard workflow — plan and apply all stacks
./deploy.sh all plan
./deploy.sh all apply

# Target a specific stack
./deploy.sh pbs plan
./deploy.sh pbs apply

# Destroy stacks
./deploy.sh pbs destroy
./deploy.sh all destroy

# Explicit init (e.g. after a provider version bump)
./deploy.sh all init -upgrade
```

Each stack has independent state — applying or destroying one has no effect on the others.

---

## After deployment

Add provisioned hosts to `proxmox-playbook/inventory/hosts.yml`, then run
the corresponding playbook:

```bash
# PBS — installs PBS package, configures datastore, NFS, users, firewall
ansible-playbook -i inventory/hosts.yml playbooks/pbs.yml

# svc-01 — installs Docker, deploys Traefik and Authentik
ansible-playbook -i inventory/hosts.yml playbooks/svc.yml
```

---

## State management

Each stack maintains independent state in S3:

| Stack | State key |
|---|---|
| `pbs` | `pbs/terraform.tfstate` |
| `svc-01` | `svc-01/terraform.tfstate` |

S3 bucket: `kernelstack-terraform-state` — managed by `terraform-bootstrap`.
DynamoDB lock table: `kernelstack-terraform-locks`.

---

## Adding a new VM

1. Create `stacks/<name>/` with `providers.tf`, `data.tf`, `variables.tf`, `main.tf`, `outputs.tf`, and `terraform.tfvars`
2. Call `module "vm" { source = "../../modules/proxmox-vm" ... }` with VM-specific values
3. Set a unique backend `key` in `providers.tf`
4. Run `./deploy.sh all apply` — the new stack is detected, auto-initialized, and applied
