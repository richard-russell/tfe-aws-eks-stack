variable "tfe_namespace" {
  type        = string
  description = "Kubernetes namespace where TFE will be deployed."
  default     = "tfe"
}

variable "tfe_license_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the TFE license."
}

variable "tfe_encryption_password_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the TFE encryption password."
}

variable "tfe_database_password_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the TFE database password."
}

variable "tfe_redis_password_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the TFE Redis password."
}

variable "tfe_tls_cert_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the base64-encoded TFE TLS certificate."
}

variable "tfe_tls_privkey_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the base64-encoded TFE TLS private key."
}

variable "tfe_tls_ca_bundle_secret_arn" {
  type        = string
  description = "ARN of Secrets Manager secret containing the base64-encoded TFE TLS CA bundle."
}
