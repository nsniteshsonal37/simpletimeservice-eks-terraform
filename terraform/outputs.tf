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

output "public_subnet_ids_csv" {
  description = "Public subnet IDs as a comma-separated string for pipeline consumption."
  value       = join(",", module.vpc.public_subnets)
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

output "deployment_profile" {
  description = "Deployment profile selected for this stack."
  value       = var.deployment_profile
}

output "environment" {
  description = "Environment name used for this stack."
  value       = var.environment
}

output "private_subnet_ids_csv" {
  description = "Private subnet IDs as a comma-separated string for pipeline consumption."
  value       = join(",", module.vpc.private_subnets)
}

output "dockerhub_image" {
  description = "DockerHub image used by the SimpleTimeService deployment."
  value       = var.dockerhub_image
}
