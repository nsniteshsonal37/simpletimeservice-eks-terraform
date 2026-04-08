# ─────────────────────────────────────────────────────────────────────────────
# AWS Load Balancer Controller – IRSA and Helm release
#
# The LBC watches Ingress resources annotated with ingressClassName: alb and
# provisions an Application Load Balancer directly via the AWS API. This means
# Kubernetes Services stay as ClusterIP – no type: LoadBalancer needed.
# ─────────────────────────────────────────────────────────────────────────────

# IAM policy that allows the controller to manage EC2 and ELB resources.
resource "aws_iam_policy" "aws_lbc" {
  name        = "${local.cluster_name}-aws-lbc"
  description = "IAM policy for the AWS Load Balancer Controller on ${local.cluster_name}."
  policy      = file("${path.module}/iam/lbc-policy.json")

  tags = local.common_tags
}

# IAM role bound to the controller's Kubernetes service account via IRSA.
# The trust policy restricts assumption to exactly the controller's service
# account in kube-system, preventing privilege escalation from other pods.
resource "aws_iam_role" "aws_lbc" {
  name = "${local.cluster_name}-aws-lbc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:aud" = "sts.amazonaws.com"
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  role       = aws_iam_role.aws_lbc.name
  policy_arn = aws_iam_policy.aws_lbc.arn
}

# Install the AWS Load Balancer Controller via its official Helm chart.
# The controller creates an ALB for every Ingress with ingressClassName: alb.
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lbc_chart_version

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Annotate the service account with the IRSA role ARN so the controller
  # can call the AWS API without static credentials.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lbc.arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.aws_lbc,
  ]
}
