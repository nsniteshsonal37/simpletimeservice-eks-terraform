terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Helm provider authenticates to EKS via the AWS CLI token exec plugin.
# Requires `aws` CLI on PATH – the same requirement as kubectl.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

resource "aws_kms_key" "eks_cluster_encryption" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    { Name = "${local.cluster_name}-kms" }
  )
}

resource "aws_kms_alias" "eks_cluster_encryption" {
  name          = "alias/eks/${local.cluster_name}"
  target_key_id = aws_kms_key.eks_cluster_encryption.key_id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs
  create_kms_key                 = false
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
