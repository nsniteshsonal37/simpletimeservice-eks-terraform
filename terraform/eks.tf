module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access       = var.cluster_endpoint_private_access
  cluster_endpoint_public_access        = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs  = var.eks_public_access_cidrs
  create_kms_key                        = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks_cluster_encryption.arn
  }

  eks_managed_node_groups = {
    default = {
      # Profile-driven defaults come from deployment_profile (dev/prod).
      # Any node_* variable explicitly set will override profile defaults.
      instance_types = local.effective_node_instance_types
      capacity_type  = local.effective_node_capacity_type
      desired_size   = local.effective_node_desired_size
      min_size       = local.effective_node_min_size
      max_size       = local.effective_node_max_size
      subnet_ids     = module.vpc.private_subnets
    }
  }

  tags = local.common_tags
}