# ─── Groups ───────────────────────────────────────────────────────────────────

resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
}

# ─── Admin User ───────────────────────────────────────────────────────────────

resource "authentik_user" "admin" {
  username = var.admin_username
  name     = var.admin_name
  email    = var.admin_email
  groups   = [authentik_group.admins.id]
}

# ─── Recovery Flow ────────────────────────────────────────────────────────────
# Minimal password-reset flow: prompt for new password → write it.
# Required for the admin recovery link API and any future user self-service recovery.

resource "authentik_stage_prompt_field" "recovery_new_password" {
  name      = "recovery-field-new-password"
  field_key = "password"
  label     = "New Password"
  type      = "password"
  required  = true
  order     = 0
}

resource "authentik_stage_prompt_field" "recovery_new_password_repeat" {
  name      = "recovery-field-new-password-repeat"
  field_key = "password_repeat"
  label     = "Repeat Password"
  type      = "password"
  required  = true
  order     = 1
}

resource "authentik_stage_prompt" "recovery_password" {
  name = "recovery-password-prompt"
  fields = [
    authentik_stage_prompt_field.recovery_new_password.id,
    authentik_stage_prompt_field.recovery_new_password_repeat.id,
  ]
}

resource "authentik_stage_user_write" "recovery" {
  name = "recovery-user-write"
}

resource "authentik_flow" "recovery" {
  name        = "Recovery"
  title       = "Reset your password"
  slug        = "recovery-flow"
  designation = "recovery"
}

resource "authentik_flow_stage_binding" "recovery_password" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_prompt.recovery_password.id
  order  = 0
}

resource "authentik_flow_stage_binding" "recovery_user_write" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_write.recovery.id
  order  = 10
}

# Set the recovery flow on the default brand. Uses API discovery by domain name
# so it works correctly after DR (brand UUID changes per install).
resource "null_resource" "brand_recovery_flow" {
  triggers = {
    recovery_flow_id = authentik_flow.recovery.uuid
  }

  provisioner "local-exec" {
    environment = {
      AUTHENTIK_URL    = var.authentik_url
      AWS_PROFILE      = var.aws_profile
      AWS_REGION       = var.aws_region
      RECOVERY_FLOW_ID = authentik_flow.recovery.uuid
    }
    command = <<-EOT
      AUTHENTIK_TOKEN=$(aws ssm get-parameter \
        --name "/infra/svc/authentik/bootstrap_token" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION")

      BRAND_UUID=$(curl -sf \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        "$AUTHENTIK_URL/api/v3/core/brands/?domain=authentik-default" \
        | jq -r '.results[0].brand_uuid')

      curl -sf -X PATCH \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"flow_recovery\": \"$RECOVERY_FLOW_ID\"}" \
        "$AUTHENTIK_URL/api/v3/core/brands/$BRAND_UUID/" > /dev/null
    EOT
  }

  depends_on = [authentik_flow.recovery]
}

# Generates a one-time password-reset link for the admin user and prints it to
# stdout on first apply. Token is fetched in-shell (not via environment block)
# so Terraform does not suppress the output. The link expires after use.
resource "null_resource" "admin_recovery_link" {
  triggers = {
    user_id = authentik_user.admin.id
  }

  provisioner "local-exec" {
    environment = {
      AUTHENTIK_URL = var.authentik_url
      USER_ID       = authentik_user.admin.id
      USERNAME      = var.admin_username
      AWS_PROFILE   = var.aws_profile
      AWS_REGION    = var.aws_region
    }
    command = <<-EOT
      AUTHENTIK_TOKEN=$(aws ssm get-parameter \
        --name "/infra/svc/authentik/bootstrap_token" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION")

      printf '\n=== ADMIN ACCOUNT SETUP ===\n'
      printf 'One-time password reset link for "%s":\n\n' "$USERNAME"
      curl -sf \
        -X POST \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        "$AUTHENTIK_URL/api/v3/core/users/$USER_ID/recovery/" \
        | jq -r '.link'
      printf '\n===========================\n\n'
    EOT
  }

  depends_on = [null_resource.brand_recovery_flow]
}

# ─── akadmin Lockdown ─────────────────────────────────────────────────────────
# akadmin is the Authentik-native IaC service account used exclusively by
# Terraform. It has no password and no MFA device — interactive login is
# blocked by policy. Authentication is only possible via the bootstrap API
# token managed by Ansible in SSM.

resource "authentik_policy_expression" "deny_akadmin_login" {
  name       = "deny-akadmin-interactive-login"
  expression = <<-EOT
    if request.user.username == "akadmin":
        ak_message("This account does not permit interactive login.")
        return False
    return True
  EOT
}

resource "authentik_policy_binding" "deny_akadmin_login" {
  target = data.authentik_flow.default_auth.id
  policy = authentik_policy_expression.deny_akadmin_login.id
  order  = 0
}

# ─── Traefik Dashboard Forward Auth ──────────────────────────────────────────

resource "authentik_provider_proxy" "traefik_dashboard" {
  name               = "traefik-dashboard"
  authorization_flow = data.authentik_flow.default_auth.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  mode               = "forward_single"
  external_host      = "https://${var.traefik_domain}"
}

resource "authentik_application" "traefik_dashboard" {
  name              = "Traefik Dashboard"
  slug              = "traefik-dashboard"
  protocol_provider = authentik_provider_proxy.traefik_dashboard.id
  meta_launch_url   = "https://${var.traefik_domain}"
  meta_description  = "Traefik reverse proxy dashboard"
}

# The embedded outpost runs inside the authentik-server container — no separate
# proxy container is needed. We assign providers via API rather than managing the
# outpost as a Terraform resource, because the embedded outpost UUID changes on
# every fresh Authentik install (DR/fresh deploy). Discovering it by its stable
# managed key is the only approach that works across all scenarios.
resource "null_resource" "embedded_outpost" {
  triggers = {
    provider_id    = authentik_provider_proxy.traefik_dashboard.id
    authentik_host = var.authentik_url
  }

  provisioner "local-exec" {
    environment = {
      AUTHENTIK_URL = var.authentik_url
      AWS_PROFILE   = var.aws_profile
      AWS_REGION    = var.aws_region
      PROVIDER_ID   = authentik_provider_proxy.traefik_dashboard.id
    }
    command = <<-EOT
      AUTHENTIK_TOKEN=$(aws ssm get-parameter \
        --name "/infra/svc/authentik/bootstrap_token" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION")

      OUTPOST_ID=$(curl -sf \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        "$AUTHENTIK_URL/api/v3/outposts/instances/?managed=goauthentik.io%2Foutposts%2Fembedded" \
        | jq -r '.results[0].pk')

      if [ -z "$OUTPOST_ID" ] || [ "$OUTPOST_ID" = "null" ]; then
        echo "ERROR: embedded outpost not found" >&2
        exit 1
      fi

      curl -sf -X PATCH \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"protocol_providers\": [$PROVIDER_ID], \"config\": {\"authentik_host\": \"$AUTHENTIK_URL\", \"authentik_host_insecure\": false, \"log_level\": \"info\"}}" \
        "$AUTHENTIK_URL/api/v3/outposts/instances/$OUTPOST_ID/" > /dev/null
    EOT
  }
}

# ─── 2FA Enforcement ──────────────────────────────────────────────────────────
# The setup stage handles device enrollment; the validate stage enforces it.
# Users without a TOTP device are redirected through the setup stage inline.

resource "authentik_stage_authenticator_totp" "setup" {
  name          = "totp-setup"
  friendly_name = "Set up TOTP Authenticator"
  digits        = 6
}

resource "authentik_stage_authenticator_validate" "totp" {
  name                  = "totp-validate-enforced"
  device_classes        = ["totp"]
  not_configured_action = "configure"
  configuration_stages  = [authentik_stage_authenticator_totp.setup.id]
}

# The goauthentik provider v2025.x sends not_configured_action and
# configuration_stages in separate PATCH requests; Authentik rejects the
# not_configured_action="configure" patch if stages are absent. This null_resource
# sends both fields atomically, and re-runs whenever either stage is recreated (DR).
resource "null_resource" "totp_configure_action" {
  triggers = {
    validate_stage_id = authentik_stage_authenticator_validate.totp.id
    setup_stage_id    = authentik_stage_authenticator_totp.setup.id
  }

  provisioner "local-exec" {
    environment = {
      AUTHENTIK_URL     = var.authentik_url
      AWS_PROFILE       = var.aws_profile
      AWS_REGION        = var.aws_region
      VALIDATE_STAGE_ID = authentik_stage_authenticator_validate.totp.id
      SETUP_STAGE_ID    = authentik_stage_authenticator_totp.setup.id
    }
    command = <<-EOT
      AUTHENTIK_TOKEN=$(aws ssm get-parameter \
        --name "/infra/svc/authentik/bootstrap_token" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION")

      curl -sf -X PATCH \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"not_configured_action\": \"configure\", \"configuration_stages\": [\"$SETUP_STAGE_ID\"]}" \
        "$AUTHENTIK_URL/api/v3/stages/authenticator/validate/$VALIDATE_STAGE_ID/" > /dev/null
    EOT
  }

  depends_on = [authentik_stage_authenticator_validate.totp]
}

resource "authentik_flow_stage_binding" "totp" {
  target = data.authentik_flow.default_auth.id
  stage  = authentik_stage_authenticator_validate.totp.id
  order  = 40
}
