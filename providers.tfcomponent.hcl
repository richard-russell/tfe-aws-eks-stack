# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 6.0"
  }

  local = {
    source  = "hashicorp/local"
    version = "~> 2.5"
  }

  tls = {
    source  = "hashicorp/tls"
    version = "~> 4.0"
  }

  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "~> 2.37"
  }
}

provider "local" "this" {}
provider "tls" "this" {}

provider "aws" "this" {
  config {
    region = var.aws_region

    assume_role_with_web_identity {
      role_arn           = var.role_arn
      web_identity_token = var.identity_token
    }

    default_tags {
      tags = var.common_tags
    }
  }
}

provider "kubernetes" "this" {
  config {
    host                   = component.tfe.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(component.tfe.eks_cluster_certificate_authority_data)
    token                  = component.eks-auth.token
  }
}
