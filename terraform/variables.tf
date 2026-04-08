variable "aws_region" {
  description = "AWS region where infrastructure will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for resource names."
  type        = string
  default     = "simpletimeservice"
}

variable "environment" {
  description = "Environment name appended to resources."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block used for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.31"
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway resources for private subnet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to use a single shared NAT gateway instead of one per AZ."
  type        = bool
  default     = true
}

variable "deployment_profile" {
  description = "Deployment profile used to choose sane defaults for node sizing and capacity."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.deployment_profile)
    error_message = "deployment_profile must be either dev or prod."
  }
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible. Set to true only with a restricted CIDR allowlist."
  type        = bool
  default     = false
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is privately accessible from within the VPC."
  type        = bool
  default     = true
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Whether the Terraform caller should automatically receive EKS cluster admin permissions."
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.eks_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Each eks_public_access_cidrs entry must be a valid CIDR block, for example 203.0.113.10/32."
  }

  validation {
    condition     = alltrue([for cidr in var.eks_public_access_cidrs : cidr != "0.0.0.0/0"])
    error_message = "0.0.0.0/0 is not allowed for eks_public_access_cidrs in zero-trust mode."
  }

  validation {
    condition     = var.cluster_endpoint_public_access ? length(var.eks_public_access_cidrs) > 0 : true
    error_message = "When cluster_endpoint_public_access is true, provide at least one restricted CIDR in eks_public_access_cidrs."
  }
}

variable "node_instance_types" {
  description = "Optional override for EKS node instance types. If null, values come from deployment_profile defaults."
  type        = list(string)
  default     = null
}

variable "node_capacity_type" {
  description = "Optional override for EKS managed node capacity type. If null, value comes from deployment_profile defaults."
  type        = string
  default     = null

  validation {
    condition     = var.node_capacity_type == null || contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type must be either SPOT, ON_DEMAND, or null."
  }
}

variable "node_desired_size" {
  description = "Optional override for desired number of EKS worker nodes. If null, value comes from deployment_profile defaults."
  type        = number
  default     = null
}

variable "node_min_size" {
  description = "Optional override for minimum number of EKS worker nodes. If null, value comes from deployment_profile defaults."
  type        = number
  default     = null
}

variable "node_max_size" {
  description = "Optional override for maximum number of EKS worker nodes. If null, value comes from deployment_profile defaults."
  type        = number
  default     = null
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before scheduled KMS key deletion is finalized."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "kms_enable_key_rotation" {
  description = "Whether automatic KMS key rotation is enabled for the EKS encryption key."
  type        = bool
  default     = true
}

variable "dockerhub_image" {
  description = "DockerHub image reference used by the application deployment."
  type        = string
  default     = "nsniteshsonal37/simpletimeservice:1.0.2"
}

variable "aws_lbc_chart_version" {
  description = "Helm chart version for the AWS Load Balancer Controller. Check https://github.com/aws/eks-charts for the latest release."
  type        = string
  default     = "1.8.1"
}
