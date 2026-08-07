# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

identity_token "aws" {
  audience = ["aws.workload.identity"]
}

upstream_input "tfe-eks-prereqs" {
  type   = "stack"
  source = "app.terraform.io/richard-russell-org/TFE/tfe-aws-eks-prereqs-stack"
}

locals {
  aws_region = "eu-west-1"
}

deployment "development" {
  inputs = {
    aws_region           = local.aws_region
    role_arn             = "arn:aws:iam::363715248670:role/tfc-workload-identity-richard-russell-org"
    identity_token       = identity_token.aws.jwt
    common_tags          = { owner = "Richard Russell", stack = "tfe-eks" }
    friendly_name_prefix = "eks"
    tfe_fqdn             = "eks-tfe.richard-russell.sbx.hashidemos.io"

    upstream_networks = upstream_input.tfe-eks-prereqs.development_networks
    upstream_secrets  = upstream_input.tfe-eks-prereqs.development_secrets
    upstream_pki      = upstream_input.tfe-eks-prereqs.development_pki
  }
}
