# ─── AWS ──────────────────────────────────────────────────────────────────────

variable "aws_profile" {
  description = "AWS CLI profile for SSM access"
  type        = string
  default     = "InfraProvisioner"
}

variable "aws_region" {
  description = "AWS region for SSM lookups"
  type        = string
  default     = "us-east-1"
}

# ─── Authentik Connection ─────────────────────────────────────────────────────

variable "authentik_url" {
  description = "Base URL of the Authentik instance (e.g. https://authentik.svc.kernelstack.dev)"
  type        = string
}

# ─── Service Domains ─────────────────────────────────────────────────────────

variable "traefik_domain" {
  description = "Public hostname for the Traefik dashboard (e.g. traefik.svc.kernelstack.dev)"
  type        = string
}

# ─── Admin Account ────────────────────────────────────────────────────────────

variable "admin_username" {
  description = "Username for the primary admin account (e.g. jsmith, ops-admin)"
  type        = string
}

variable "admin_name" {
  description = "Display name for the primary admin account"
  type        = string
}

variable "admin_email" {
  description = "Email address for the primary admin account"
  type        = string
}
