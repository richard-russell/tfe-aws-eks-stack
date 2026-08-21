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
    eks_cluster_endpoint_public_access     = true
    eks_cluster_public_access_cidrs        = ["0.0.0.0/0"]
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

component "eks-auth" {
  source = "./eks-auth"

  inputs = {
    eks_cluster_name = component.tfe.eks_cluster_name
  }

  providers = {
    aws = provider.aws.this
  }

  depends_on = [component.tfe]
}

component "k8s-secrets" {
  source = "./k8s-secrets"

  inputs = {
    tfe_license_secret_arn             = var.upstream_secrets.tfe_license_secret_arn
    tfe_encryption_password_secret_arn = var.upstream_secrets.tfe_encryption_password_secret_arn
    tfe_database_password_secret_arn   = var.upstream_secrets.tfe_database_password_secret_arn
    tfe_redis_password_secret_arn      = var.upstream_secrets.tfe_redis_password_secret_arn
    tfe_tls_cert_secret_arn            = var.upstream_pki.tfe_tls_cert_secret_arn
    tfe_tls_privkey_secret_arn         = var.upstream_pki.tfe_tls_privkey_secret_arn
    tfe_tls_ca_bundle_secret_arn       = var.upstream_pki.tfe_tls_ca_bundle_secret_arn
  }

  providers = {
    aws        = provider.aws.this
    kubernetes = provider.kubernetes.this
  }

  depends_on = [component.tfe]
}

output "helm_overrides" {
  description = "Rendered Helm overrides values for the TFE operator chart. Equivalent to the module's generated helm_overrides_values.yaml."
  sensitive   = true
  value = <<-EOT
    replicaCount: 3
    tls:
      certificateSecret: tfe-certs
      caCertData: |
        ${indent(8, component.k8s-secrets.tfe_ca_bundle)}

    image:
      repository: images.releases.hashicorp.com
      name: hashicorp/terraform-enterprise
      tag: ${var.tfe_image_tag}

    serviceAccount:
      enabled: true
      name: tfe

    tfe:
      privateHttpPort: 8080
      privateHttpsPort: 8443
      metrics:
        enable: true
        httpPort: 9090
        httpsPort: 9091

    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
        service.beta.kubernetes.io/aws-load-balancer-security-groups: ${component.tfe.tfe_lb_security_group_id}
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "https"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/api/v1/health/readiness"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8443"
      type: LoadBalancer
      port: 443

    env:
      secretRefs:
        - name: tfe-secrets
      variables:
        TFE_HOSTNAME: ${var.tfe_fqdn}
        TFE_DATABASE_HOST: ${component.tfe.tfe_database_host}
        TFE_DATABASE_NAME: tfe
        TFE_DATABASE_USER: tfe
        TFE_DATABASE_PARAMETERS: sslmode=require
        TFE_OBJECT_STORAGE_TYPE: s3
        TFE_OBJECT_STORAGE_S3_BUCKET: ${component.tfe.s3_bucket_name}
        TFE_OBJECT_STORAGE_S3_REGION: eu-west-1
        TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE: "true"
        TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION: AES256
        TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION_KMS_KEY_ID: ""
        TFE_REDIS_HOST: ${component.tfe.elasticache_replication_group_primary_endpoint_address}
        TFE_REDIS_USE_AUTH: "true"
        TFE_REDIS_USE_TLS: "true"
    EOT
  type        = string
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

output "eks_cluster_endpoint" {
  value       = component.tfe.eks_cluster_endpoint
  type        = string
  description = "EKS cluster API endpoint."
}

output "eks_cluster_certificate_authority_data" {
  value       = component.tfe.eks_cluster_certificate_authority_data
  type        = string
  description = "Base64-encoded certificate authority data for the TFE EKS cluster."
}
