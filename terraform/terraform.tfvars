aws_region         = "us-east-1"
project_name       = "simpletimeservice"
environment        = "prod"
vpc_cidr           = "10.0.0.0/16"
kubernetes_version = "1.31"
deployment_profile = "prod"

# To use lower-cost development defaults instead, use:
# deployment_profile = "dev"

# Optional explicit overrides (take precedence over profile defaults):
# node_instance_types = ["m6a.large"]
# node_capacity_type = "ON_DEMAND"
# node_desired_size  = 2
# node_min_size      = 2
# node_max_size      = 2
