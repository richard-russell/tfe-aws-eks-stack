# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "aws_region" {
  type        = string
  description = "AWS region to deploy TFE."
}

variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix used for tagging and naming AWS resources. Must not contain 'tfe'."
}

variable "identity_token" {
  type      = string
  ephemeral = true
}

variable "role_arn" {
  type        = string
  description = "ARN of IAM role to assume via workload identity."
}

variable "common_tags" {
  type        = map(string)
  description = "Map of common tags for all taggable AWS resources."
  default     = {}
}

variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name (FQDN) of TFE instance."
}

# --- Upstream inputs from prereqs stack --- #
variable "upstream_networks" {
  description = "VPC and subnet IDs from prereqs stack."
  type = object({
    vpc_id             = string
    private_subnet_ids = optional(list(string))
    public_subnet_ids  = optional(list(string))
  })
}

variable "upstream_secrets" {
  description = "Secret ARNs from prereqs stack."
  type = object({
    tfe_license_secret_arn             = optional(string)
    tfe_encryption_password_secret_arn = optional(string)
    tfe_database_password_secret_arn   = optional(string)
    tfe_redis_password_secret_arn      = optional(string)
  })
}

variable "upstream_pki" {
  description = "TLS/PKI secret ARNs from prereqs stack."
  type = object({
    tfe_tls_privkey_secret_arn   = optional(string)
    tfe_tls_cert_secret_arn      = optional(string)
    tfe_tls_ca_bundle_secret_arn = optional(string)
  })
}
