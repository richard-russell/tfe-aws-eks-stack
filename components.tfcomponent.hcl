# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  fqdn_parts = split(".", var.tfe_fqdn)
  zone_name  = join(".", slice(local.fqdn_parts, 1, length(local.fqdn_parts)))
}

component "tfe" {
  source  = "hashicorp/terraform-enterprise-eks-hvd/aws"
  version = "0.2.0"

  inputs = {
    friendly_name_prefix = var.friendly_name_prefix
    common_tags          = var.common_tags
    tfe_fqdn             = var.tfe_fqdn
    create_helm_overrides_file = false

    # --- Networking --- #
    vpc_id           = var.upstream_networks.vpc_id
    # EKS nodes in private subnets; public subnets used by K8s-managed load balancer
    eks_subnet_ids   = var.upstream_networks.private_subnet_ids
    rds_subnet_ids   = var.upstream_networks.private_subnet_ids
    redis_subnet_ids = var.upstream_networks.private_subnet_ids

    # --- EKS cluster --- #
    create_eks_cluster                     = true
    eks_cluster_endpoint_public_access     = false
    eks_nodegroup_instance_type            = "m7i.2xlarge"
    eks_nodegroup_scaling_config = {
      desired_size = 3
      max_size     = 3
      min_size     = 2
    }

    # --- IAM / IRSA --- #
    # Use Pod Identity (preferred over IRSA for new clusters)
    create_tfe_eks_pod_identity           = true
    create_aws_lb_controller_pod_identity = true

    # --- Secrets Manager --- #
    tfe_database_password_secret_arn   = var.upstream_secrets.tfe_database_password_secret_arn
    tfe_redis_password_secret_arn      = var.upstream_secrets.tfe_redis_password_secret_arn

    # --- Database --- #
    rds_skip_final_snapshot  = true
    rds_aurora_instance_class = "db.r6i.xlarge"
    rds_aurora_replica_count  = 1
    rds_aurora_engine_version = 16.8

    # --- Object storage --- #
    tfe_object_storage_s3_use_instance_profile = true

    # --- Redis --- #
    redis_node_type                  = "cache.m5.large"
    redis_multi_az_enabled           = true
    redis_automatic_failover_enabled = true
    redis_transit_encryption_enabled = true

    # --- TFE load balancer security group --- #
    create_tfe_lb_security_group      = true
    cidr_allow_ingress_tfe_443        = ["0.0.0.0/0"]
    cidr_allow_ingress_tfe_metrics_http  = ["10.1.0.0/16"]
    cidr_allow_ingress_tfe_metrics_https = ["10.1.0.0/16"]
  }

  providers = {
    aws   = provider.aws.this
    local = provider.local.this
    tls   = provider.tls.this
  }
}

output "tfe_url" {
  value       = component.tfe.tfe_url
  type        = string
  description = "URL to access TFE application based on value of `tfe_fqdn` input."
}

output "eks_cluster_name" {
  value       = component.tfe.eks_cluster_name
  type        = string
  description = "Name of the TFE EKS cluster."
}

output "s3_bucket_name" {
  value       = component.tfe.s3_bucket_name
  type        = string
  description = "Name of the TFE S3 object storage bucket."
}

output "tfe_database_host" {
  value       = component.tfe.tfe_database_host
  type        = string
  description = "RDS Aurora endpoint for TFE Helm chart values."
}
