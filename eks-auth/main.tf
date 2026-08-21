data "aws_eks_cluster_auth" "tfe" {
  name = var.eks_cluster_name
}

output "token" {
  value     = data.aws_eks_cluster_auth.tfe.token
  sensitive = true
}
