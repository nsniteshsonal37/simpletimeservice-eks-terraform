terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  profile_settings = {
    dev = {
      az_count = 1
    }
    prod = {
      az_count = 2
    }
  }

  selected_profile = local.profile_settings[var.deployment_profile]

  azs             = slice(data.aws_availability_zones.available.names, 0, local.selected_profile.az_count)
  public_subnets  = [for i in range(local.selected_profile.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(local.selected_profile.az_count) : cidrsubnet(var.vpc_cidr, 4, i + local.selected_profile.az_count)]

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
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

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

resource "aws_ecr_repository" "simpletimeservice" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "simpletimeservice" {
  repository = aws_ecr_repository.simpletimeservice.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the latest 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "prod", "dev", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
