output "vpc_id" {
  description = "VPC ID created for the EKS cluster."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS node group."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs created in the VPC."
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Public endpoint for the EKS API server."
  value       = module.eks.cluster_endpoint
}

output "aws_region" {
  description = "AWS region used for deployed resources."
  value       = var.aws_region
}

output "ecr_repository_url" {
  description = "ECR repository URI for the SimpleTimeService image."
  value       = aws_ecr_repository.simpletimeservice.repository_url
}
