locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  profile_settings = {
    dev = {
      az_count = 2
    }
    prod = {
      az_count = 2
    }
  }

  selected_profile = local.profile_settings[var.deployment_profile]

  azs             = slice(data.aws_availability_zones.available.names, 0, local.selected_profile.az_count)
  public_subnets  = [for i in range(local.selected_profile.az_count) : cidrsubnet(var.vpc_cidr, 4, i * 2)]
  private_subnets = [for i in range(local.selected_profile.az_count) : cidrsubnet(var.vpc_cidr, 4, i * 2 + 1)]

  node_profiles = {
    dev = {
      node_instance_types = ["t3.medium"]
      node_capacity_type  = "SPOT"
      node_desired_size   = 1
      node_min_size       = 1
      node_max_size       = 1
    }
    prod = {
      node_instance_types = ["m6a.large"]
      node_capacity_type  = "ON_DEMAND"
      node_desired_size   = 2
      node_min_size       = 2
      node_max_size       = 2
    }
  }

  selected_node_profile = local.node_profiles[var.deployment_profile]

  effective_node_instance_types = var.node_instance_types != null ? var.node_instance_types : local.selected_node_profile.node_instance_types
  effective_node_capacity_type  = var.node_capacity_type != null ? var.node_capacity_type : local.selected_node_profile.node_capacity_type
  effective_node_desired_size   = var.node_desired_size != null ? var.node_desired_size : local.selected_node_profile.node_desired_size
  effective_node_min_size       = var.node_min_size != null ? var.node_min_size : local.selected_node_profile.node_min_size
  effective_node_max_size       = var.node_max_size != null ? var.node_max_size : local.selected_node_profile.node_max_size

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}