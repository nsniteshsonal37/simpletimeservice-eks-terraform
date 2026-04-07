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

variable "deployment_profile" {
  description = "Deployment profile used to choose sane defaults for node sizing and capacity."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.deployment_profile)
    error_message = "deployment_profile must be either dev or prod."
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

variable "ecr_repository_name" {
  description = "ECR repository name used for the application image."
  type        = string
  default     = "simpletimeservice"
}
