# ─── SSM Secrets ──────────────────────────────────────────────────────────────
# Terraform always authenticates as akadmin via the bootstrap token.
# The token is managed by Ansible and permanently active in Authentik's env.

data "aws_ssm_parameter" "authentik_token" {
  name            = "/infra/svc/authentik/bootstrap_token"
  with_decryption = true
}

# ─── Authentik Built-in Flows ─────────────────────────────────────────────────

data "authentik_flow" "default_auth" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-invalidation-flow"
}
