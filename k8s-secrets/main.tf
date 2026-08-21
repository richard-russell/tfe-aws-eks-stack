# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# --- Read secrets from AWS Secrets Manager --- #

data "aws_secretsmanager_secret_version" "tfe_license" {
  secret_id = var.tfe_license_secret_arn
}

data "aws_secretsmanager_secret_version" "tfe_encryption_password" {
  secret_id = var.tfe_encryption_password_secret_arn
}

data "aws_secretsmanager_secret_version" "tfe_database_password" {
  secret_id = var.tfe_database_password_secret_arn
}

data "aws_secretsmanager_secret_version" "tfe_redis_password" {
  secret_id = var.tfe_redis_password_secret_arn
}

data "aws_secretsmanager_secret_version" "tfe_tls_cert" {
  secret_id = var.tfe_tls_cert_secret_arn
}

data "aws_secretsmanager_secret_version" "tfe_tls_privkey" {
  secret_id = var.tfe_tls_privkey_secret_arn
}

# --- Kubernetes namespace --- #

resource "kubernetes_namespace" "tfe" {
  metadata {
    name = var.tfe_namespace
  }
}

# --- 1. Image pull secret --- #

resource "kubernetes_secret" "image_pull" {
  metadata {
    name      = "terraform-enterprise"
    namespace = kubernetes_namespace.tfe.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "images.releases.hashicorp.com" = {
          username = "terraform"
          password = data.aws_secretsmanager_secret_version.tfe_license.secret_string
          auth     = base64encode("terraform:${data.aws_secretsmanager_secret_version.tfe_license.secret_string}")
        }
      }
    })
  }
}

# --- 2. TFE configuration secrets --- #

resource "kubernetes_secret" "tfe_secrets" {
  metadata {
    name      = "tfe-secrets"
    namespace = kubernetes_namespace.tfe.metadata[0].name
  }

  type = "Opaque"

  data = {
    TFE_LICENSE             = data.aws_secretsmanager_secret_version.tfe_license.secret_string
    TFE_ENCRYPTION_PASSWORD = data.aws_secretsmanager_secret_version.tfe_encryption_password.secret_string
    TFE_DATABASE_PASSWORD   = data.aws_secretsmanager_secret_version.tfe_database_password.secret_string
    TFE_REDIS_PASSWORD      = data.aws_secretsmanager_secret_version.tfe_redis_password.secret_string
  }
}

# --- 3. TLS certificate and private key --- #

resource "kubernetes_secret" "tfe_certs" {
  metadata {
    name      = "tfe-certs"
    namespace = kubernetes_namespace.tfe.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = base64decode(data.aws_secretsmanager_secret_version.tfe_tls_cert.secret_string)
    "tls.key" = base64decode(data.aws_secretsmanager_secret_version.tfe_tls_privkey.secret_string)
  }
}
