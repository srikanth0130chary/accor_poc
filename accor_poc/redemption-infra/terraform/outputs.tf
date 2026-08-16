output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "points_ledger_table_name" {
  value = aws_dynamodb_table.points_ledger.name
}

output "app_irsa_role_arn" {
  description = "Pass this into k8s/serviceaccount.yaml as the eks.amazonaws.com/role-arn annotation"
  value       = module.redemption_app_irsa.iam_role_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
